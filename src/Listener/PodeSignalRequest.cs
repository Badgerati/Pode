using System;
using System.IO;
using System.Net.WebSockets;
using System.Threading;
using System.Threading.Tasks;

namespace Pode
{
    /// <summary>
    /// Represents a WebSocket signal request. Inherits from PodeRequest to leverage the base connection
    /// and stream handling, and implements WebSocket-specific logic like frame parsing, op-code handling,
    /// and resource cleanup.
    /// </summary>
    public class PodeSignalRequest : PodeRequest
    {
        // The WebSocket operation code extracted from the incoming frame.
        public PodeWsOpCode OpCode { get; private set; }

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

        // Private field to hold the WebSocket close status.
        private WebSocketCloseStatus _closeStatus = WebSocketCloseStatus.Empty;

        // Public property exposing the close status.
        public WebSocketCloseStatus CloseStatus
        {
            get => _closeStatus;
        }

        // Private field to hold the close description.
        private string _closeDescription = string.Empty;

        // Public property exposing the close description.
        public string CloseDescription
        {
            get => _closeDescription;
        }

        // Indicates whether the connection should be closed immediately.
        // For WebSocket, this is true if the received op-code is 'Close'.
        public override bool CloseImmediately
        {
            get => OpCode == PodeWsOpCode.Close;
        }

        // Determines if the request is processable.
        // It excludes control frames (Ping/Pong) and ensures that a non-empty body exists.
        public override bool IsProcessable
        {
            get => !CloseImmediately && OpCode != PodeWsOpCode.Pong && OpCode != PodeWsOpCode.Ping && !string.IsNullOrEmpty(Body);
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
        protected override byte[] Buffer
        {
            get
            {
                return new byte[MAX_BUFFER_SIZE];
            }
        }

        /// <summary>
        /// Constructs a new PodeSignalRequest from an existing HTTP request and an associated signal.
        /// Sets up the connection as a WebSocket request, preserving the original host and URL details.
        /// </summary>
        /// <param name="request">The original HTTP request.</param>
        /// <param name="signal">The associated PodeSignal.</param>
        public PodeSignalRequest(PodeHttpRequest request, PodeSignal signal)
            : base(request) // Copy base request properties from the HTTP request.
        {
            Signal = signal;
            IsKeepAlive = true;

            // Set protocol type to WebSocket.
            Type = PodeProtocolType.Ws;

            // Determine the protocol prefix based on SSL usage.
            var _proto = IsSsl ? "wss" : "ws";
            Host = request.Host;

            // Build the WebSocket URL from the original request's authority and path/query.
            Url = new Uri($"{_proto}://{request.Url.Authority}{request.Url.PathAndQuery}");
        }

        /// <summary>
        /// Creates a new client signal object from this request.
        /// This allows further processing of the signal within the Pode framework.
        /// </summary>
        /// <returns>A new PodeClientSignal instance.</returns>
        public PodeClientSignal NewClientSignal()
        {
            return new PodeClientSignal(Signal, Body, Context.Listener);
        }

        protected override bool ValidateInput(byte[] bytes)
        {
            // if we have a current frame, update it with the new bytes and check if it's still awaiting a body
            if (CurrentFrame != default)
            {
                CurrentFrame.Update(bytes);
                return !CurrentFrame.AwaitingBody;
            }

            // otherwise, make sure we have enough bytes to parse the header
            if (!PodeSignalFrame.ValidateHeader(bytes))
            {
                return false;
            }

            // create initial frame
            CurrentFrame = new PodeSignalFrame(bytes);
            return !CurrentFrame.AwaitingBody;
        }

        /// <summary>
        /// Parses the raw WebSocket frame bytes.
        /// This method extracts the frame's operation code, decodes the payload using the masking key,
        /// and handles control frames (e.g., Close, Ping) accordingly.
        /// </summary>
        /// <param name="bytes">The raw bytes of the WebSocket frame.</param>
        /// <param name="cancellationToken">Cancellation token to cancel the operation if needed.</param>
        /// <returns>True if parsing is successful.</returns>
        protected override async Task<bool> Parse(byte[] bytes, CancellationToken cancellationToken)
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
            if (CurrentFrame.OpCode != PodeWsOpCode.Continuation)
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
                PodeLogger.LogMessage($"Error decoding WebSocket frame: {ex.Message}", Context.Listener, PodeLoggingLevel.Error, Context);
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
            Body = Encoding.GetString(RawBody);

            // Process the frame based on its operation code.
            switch (OpCode)
            {
                // For a Close frame, extract the close status and description.
                case PodeWsOpCode.Close:
                    _closeStatus = WebSocketCloseStatus.Empty;
                    _closeDescription = string.Empty;

                    if (ContentLength >= 2)
                    {
                        // Reverse the first two bytes to correctly interpret the close code.
                        Array.Reverse(RawBody, 0, 2);
                        var code = (int)BitConverter.ToUInt16(RawBody, 0);

                        // Validate and assign the close status.
                        _closeStatus = Enum.IsDefined(typeof(WebSocketCloseStatus), code)
                            ? (WebSocketCloseStatus)code
                            : WebSocketCloseStatus.Empty;

                        var descCount = ContentLength - 2;
                        if (descCount > 0)
                        {
                            // Extract the close description text, if available.
                            _closeDescription = Encoding.GetString(RawBody, 2, descCount);
                        }
                    }
                    break;

                // For a Ping frame, send back a Pong frame.
                case PodeWsOpCode.Ping:
                    await Context.Response.WriteFrame(string.Empty, PodeWsOpCode.Pong).ConfigureAwait(false);
                    break;
            }

            return true;
        }

        /// <summary>
        /// Disposes of managed and unmanaged resources used by the PodeSignalRequest.
        /// In addition to base cleanup, it sends a WebSocket Close frame and removes the client signal.
        /// </summary>
        /// <param name="disposing">Indicates whether the method is called explicitly or by the garbage collector.</param>
        protected override void Dispose(bool disposing)
        {
            if (IsDisposed) return;

            if (disposing)
            {
                // Log a message indicating the WebSocket is being closed.
                PodeLogger.LogMessage($"Closing Websocket", Context.Listener, PodeLoggingLevel.Verbose, Context);

                // Send a Close frame to the client and wait for the operation to complete.
                Context.Response.WriteFrame(string.Empty, PodeWsOpCode.Close).Wait();

                // Remove the associated client signal from the listener's collection.
                Context.Listener.Signals.Remove(Signal.ClientId);
            }

            // Call the base class Dispose to clean up other resources.
            base.Dispose(disposing);
        }
    }
}
