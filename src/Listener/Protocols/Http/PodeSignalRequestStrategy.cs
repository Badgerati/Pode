using System;
using System.IO;
using System.Net.WebSockets;
using System.Threading;
using System.Threading.Tasks;
using Pode.Utilities;
using Pode.Protocols.Common.Requests;
using Pode.Protocols.Http.Client.Signals;

namespace Pode.Protocols.Http
{
    /// <summary>
    /// Represents a WebSocket signal request. Inherits from PodeRequest to leverage the base connection
    /// and stream handling, and implements WebSocket-specific logic like frame parsing, op-code handling,
    /// and resource cleanup.
    /// </summary>
    public class PodeSignalRequestStrategy : PodeRequestStrategy
    {
        // The WebSocket operation code extracted from the incoming frame.
        public PodeSignalOpCode OpCode { get; private set; }

        // The decoded message body as a string.
        public string Body { get; private set; }

        // The stream used to read the message body.
        private MemoryStream BodyStream;

        // The raw data received (entire WebSocket frame).
        public byte[] RawBody { get; private set; }

        // The signal object associated with this request.
        public PodeSignal Signal { get; private set; }

        // The URL constructed from the original HTTP request.
        public Uri Url { get; private set; }

        // The Host header from the original HTTP request.
        public string Host { get; private set; }

        // Total length of the content/body.
        public int ContentLength { get; private set; }

        public WebSocketCloseStatus CloseStatus { get; private set; } = WebSocketCloseStatus.Empty;
        public string CloseDescription { get; private set; } = string.Empty;

        // Indicates whether the connection should be closed immediately.
        // For WebSocket, this is true if the received op-code is 'Close'.
        public override bool CloseImmediately
        {
            get => OpCode == PodeSignalOpCode.Close;
        }

        // Determines if the request is processable.
        // It excludes control frames (Ping/Pong) and ensures that a non-empty body exists.
        public override bool IsProcessable
        {
            get => base.IsProcessable && OpCode != PodeSignalOpCode.Pong && OpCode != PodeSignalOpCode.Ping && !string.IsNullOrEmpty(Body);
        }

        // The current frame being processed.
        private PodeSignalFrame CurrentFrame { get; set; } = default;

        /// <summary>
        /// Overrides the base Buffer property to always return a new buffer.
        /// This ensures that every time a buffer is needed for parsing a WebSocket frame,
        /// a fresh array is allocated, avoiding any residual data from previous operations.
        /// Although this introduces a small allocation overhead, it ensures data integrity
        /// for WebSocket communication.
        /// </summary>
        public override byte[] Buffer
        {
            get
            {
                return new byte[PodeHelpers.MAX_BUFFER_SIZE];
            }
        }

        /// <summary>
        /// Constructs a new PodeSignalRequestStrategy with an associated signal.
        /// Sets up the connection as a WebSocket request, preserving the original host and URL details.
        /// </summary>
        /// <param name="handler">The request handler managing this request.</param>
        /// <param name="url">The original request URL.</param>
        /// <param name="host">The Host header from the original request.</param>
        /// <param name="signal">The PodeSignal associated with this request.</param>
        public PodeSignalRequestStrategy(PodeHttpRequestStrategy httpStrategy, PodeSignal signal)
            : base()
        {
            Signal = signal;
            IsKeepAlive = true;

            // Set protocol type to WebSocket.
            Type = PodeProtocolType.Ws;

            // Determine the protocol prefix based on SSL usage.
            var _proto = httpStrategy.Handler.IsSsl ? "wss" : "ws";
            Host = httpStrategy.Host;

            // Build the WebSocket URL from the original request's authority and path/query.
            Url = new Uri($"{_proto}://{httpStrategy.Url.Authority}{httpStrategy.Url.PathAndQuery}");
        }

        /// <summary>
        /// Creates a new client signal object from this request.
        /// This allows further processing of the signal within the Pode framework.
        /// </summary>
        /// <returns>A new PodeClientSignal instance.</returns>
        public PodeClientSignal NewClientSignal()
        {
            return new PodeClientSignal(Signal, Body);
        }

        public override bool Validate(byte[] bytes)
        {
            // if we have a current frame, update it with the new bytes and check if it's still awaiting a body
            if (CurrentFrame != default)
            {
                CurrentFrame.Update(bytes);
                return !CurrentFrame.AwaitingContent;
            }

            // otherwise, make sure we have enough bytes to parse the header
            if (!PodeSignalFrame.ValidateHeader(bytes))
            {
                return false;
            }

            // create initial frame
            CurrentFrame = new PodeSignalFrame(bytes);
            return !CurrentFrame.AwaitingContent;
        }

        /// <summary>
        /// Parses the raw WebSocket frame bytes.
        /// This method extracts the frame's operation code, decodes the payload using the masking key,
        /// and handles control frames (e.g., Close, Ping) accordingly.
        /// </summary>
        /// <param name="bytes">The raw bytes of the WebSocket frame.</param>
        /// <param name="cancellationToken">Cancellation token to cancel the operation if needed.</param>
        /// <returns>True if parsing is successful.</returns>
        public override async Task<bool> Parse(byte[] bytes, CancellationToken cancellationToken)
        {
            // if there are no bytes, return (0 bytes read means we can close the socket)
            if (bytes == default || bytes.Length == 0 || CurrentFrame == default)
            {
                return true;
            }

            // set the body stream
            if (BodyStream == default)
            {
                BodyStream = new MemoryStream();
            }

            // set the OpCode from the current frame
            if (CurrentFrame.OpCode != PodeSignalOpCode.Continuation)
            {
                OpCode = CurrentFrame.OpCode;
            }

            try
            {
                // Decode the message by applying the mask to each byte of the payload.
                var decoded = CurrentFrame.Decode(bytes);

                // handle continuation final frames, and build the body stream
                await PodeHelpers.WriteTo(BodyStream, decoded, 0, decoded.Length, cancellationToken).ConfigureAwait(false);
                if (!CurrentFrame.IsFinalFrame)
                {
                    // returning false tells the receiver to wait for more frames
                    return false;
                }
            }
            catch (Exception ex)
            {
                // Log the error and return false to indicate failure.
                PodeHelpers.WriteErrorMessage($"Error decoding WebSocket frame: {ex.Message}", Handler.Context.Listener, PodeLoggingLevel.Error, Handler.Context);
                throw;
            }
            finally
            {
                CurrentFrame = default;
            }

            // Store the raw frame and set the content length.
            RawBody = BodyStream.ToArray();
            if (BodyStream != default)
            {
                BodyStream.Dispose();
                BodyStream = default;
            }

            ContentLength = RawBody.Length;
            Body = PodeHelpers.Encoding.GetString(RawBody);

            // Process the frame based on its operation code.
            switch (OpCode)
            {
                // For a Close frame, extract the close status and description.
                case PodeSignalOpCode.Close:
                    CloseStatus = WebSocketCloseStatus.Empty;
                    CloseDescription = string.Empty;

                    if (ContentLength >= 2)
                    {
                        // Reverse the first two bytes to correctly interpret the close code.
                        Array.Reverse(RawBody, 0, 2);
                        var code = (int)BitConverter.ToUInt16(RawBody, 0);

                        // Validate and assign the close status.
                        CloseStatus = Enum.IsDefined(typeof(WebSocketCloseStatus), code)
                            ? (WebSocketCloseStatus)code
                            : WebSocketCloseStatus.Empty;

                        var descCount = ContentLength - 2;
                        if (descCount > 0)
                        {
                            // Extract the close description text, if available.
                            CloseDescription = PodeHelpers.Encoding.GetString(RawBody, 2, descCount);
                        }
                    }
                    break;

                // For a Ping frame, send back a Pong frame.
                case PodeSignalOpCode.Ping:
                    await Signal.Pong().ConfigureAwait(false);
                    break;

                // For a Pong frame, do nothing.
                case PodeSignalOpCode.Pong:
                    break;
            }

            Signal.Activity();
            return true;
        }

        public override void Reset() { }
        public override void PartialDispose() { }

        /// <summary>
        /// Disposes of managed and unmanaged resources used by the PodeSignalRequest.
        /// In addition to base cleanup, it sends a WebSocket Close frame and removes the client signal.
        /// </summary>
        /// <param name="disposing">Indicates whether the method is called explicitly or by the garbage collector.</param>
        public override void Dispose(bool disposing)
        {
            if (IsDisposed)
            {
                return;
            }

            if (disposing)
            {
                // Log a message indicating the WebSocket is being closed.
                PodeHelpers.WriteErrorMessage($"Closing Websocket", Handler.Context.Listener, PodeLoggingLevel.Verbose, Handler.Context);
                Signal.Close().Wait();
            }

            // Call the base class Dispose to clean up other resources.
            base.Dispose(disposing);
        }
    }
}
