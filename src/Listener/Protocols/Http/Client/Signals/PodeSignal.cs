using System;
using System.Collections.Generic;
using System.IO;
using System.Security.Cryptography;
using System.Threading.Tasks;
using Pode.Utilities;

namespace Pode.Protocols.Http.Client.Signals
{
    public class PodeSignal : PodeClientConnection
    {
        protected const int MAX_FRAME_SIZE = 8192;

        public PodeSignal(PodeHttpContext context, string name, string group, string clientId, PodeClientConnectionScope scope, bool trackEvents)
            : base(PodeClientConnectionType.Signal, context, name, group, clientId, scope, trackEvents)
        { }

        public override async Task<bool> Open()
        {
            if (IsDisposed || IsClosed)
            {
                return false;
            }

            // generate the handshake key
            if (!Request.Headers.ContainsKey("Sec-WebSocket-Key"))
            {
                throw new PodeHttpRequestException("WebSocket upgrade request is invalid, missing Sec-WebSocket-Key header", 412);
            }

            var handshakeKey = $"{Request.Headers["Sec-WebSocket-Key"]}".Trim();

            // Create the socket accept hash.
#if NETCOREAPP2_1_OR_GREATER
            var acceptHandshakeKey = Convert.ToBase64String(SHA1.HashData(System.Text.Encoding.UTF8.GetBytes($"{handshakeKey}{PodeHelpers.WEB_SOCKET_MAGIC_KEY}")));
#else
            var crypto = SHA1.Create();
            var acceptHandshakeKey = Convert.ToBase64String(crypto.ComputeHash(System.Text.Encoding.UTF8.GetBytes($"{handshakeKey}{PodeHelpers.WEB_SOCKET_MAGIC_KEY}")));
#endif

            // send WebSocket headers
            await Response.UpgradeToWebSocket(ClientId, Name, Group, acceptHandshakeKey).ConfigureAwait(false);
            return await base.Open().ConfigureAwait(false);
        }

        public override async Task Close()
        {
            if (IsClosed)
            {
                return;
            }

            await Send(new PodeSignalEnvelope(string.Empty, PodeSignalOpCode.Close)).ConfigureAwait(false);
            await base.Close().ConfigureAwait(false);
        }

        public async Task<bool> Send(string message)
        {
            return await Send(new PodeSignalEnvelope(message)).ConfigureAwait(false);
        }

        public override async Task<bool> Send(PodeClientConnectionEnvelope envelope)
        {
            if (envelope == null)
            {
                return true;
            }

            if (!(envelope is PodeSignalEnvelope signalEnvelope))
            {
                throw new ArgumentException("Envelope must be of type PodeSignalEnvelope", nameof(envelope));
            }

            if (!await SendFrame(signalEnvelope.Message, signalEnvelope.OpCode).ConfigureAwait(false))
            {
                return false;
            }

            return await base.Send(envelope).ConfigureAwait(false);
        }

        public async Task Pong()
        {
            await Send(new PodeSignalEnvelope(string.Empty, PodeSignalOpCode.Pong)).ConfigureAwait(false);
        }

        protected override async Task<bool> Ping()
        {
            return await Send(new PodeSignalEnvelope(string.Empty, PodeSignalOpCode.Ping)).ConfigureAwait(false);
        }

        private async Task<bool> SendFrame(string message, PodeSignalOpCode opCode = PodeSignalOpCode.Text, bool flush = false)
        {
            // return false (no message sent), if already closed/disposed
            if (IsClosed)
            {
                return false;
            }

            // wait for the semaphore to be available
            await Semaphore.WaitAsync().ConfigureAwait(false);

            try
            {
                // check again, if closed, return false (no message sent)
                if (IsClosed)
                {
                    return false;
                }

                // prepare the message bytes and send in frames
                var msgBytes = PodeHelpers.Encoding.GetBytes(message);
                var msgLength = msgBytes.Length;
                var offset = 0;
                var firstFrame = true;

                while (offset < msgLength || (msgLength == 0 && firstFrame))
                {
                    var frameSize = Math.Min(msgLength - offset, MAX_FRAME_SIZE);
                    var frame = new byte[frameSize];
                    Array.Copy(msgBytes, offset, frame, 0, frameSize);

                    // fin bit and op code
                    var isFinal = offset + frameSize >= msgLength;
                    var finBit = (byte)(isFinal ? 0x80 : 0x00);
                    var opCodeByte = (byte)(firstFrame ? opCode : PodeSignalOpCode.Continuation);

                    // build the frame buffer
                    var buffer = new List<byte> { (byte)(finBit | opCodeByte) };

                    if (frameSize < 126)
                    {
                        buffer.Add((byte)((byte)0x00 | (byte)frameSize));
                    }
                    else if (frameSize <= UInt16.MaxValue)
                    {
                        buffer.Add((byte)((byte)0x00 | (byte)126));
                        buffer.Add((byte)((frameSize >> 8) & (byte)255));
                        buffer.Add((byte)(frameSize & (byte)255));
                    }
                    else
                    {
                        buffer.Add((byte)((byte)0x00 | (byte)127));
                        buffer.Add((byte)((frameSize >> 56) & (byte)255));
                        buffer.Add((byte)((frameSize >> 48) & (byte)255));
                        buffer.Add((byte)((frameSize >> 40) & (byte)255));
                        buffer.Add((byte)((frameSize >> 32) & (byte)255));
                        buffer.Add((byte)((frameSize >> 24) & (byte)255));
                        buffer.Add((byte)((frameSize >> 16) & (byte)255));
                        buffer.Add((byte)((frameSize >> 8) & (byte)255));
                        buffer.Add((byte)(frameSize & (byte)255));
                    }

                    // add the payload
                    buffer.AddRange(frame);

                    // attempt to write the frame, if false is returned then error
                    if (!await Context.Response.Write(buffer.ToArray(), flush).ConfigureAwait(false))
                    {
                        throw new IOException($"Failed to send WebSocket {opCode} frame, client connection is closed");
                    }

                    // increment offset and set first frame to false
                    offset += frameSize;
                    firstFrame = false;
                }

                // message sent successfully
                return true;
            }
            catch (IOException ex)
            {
                // mark as closed, log, dispose
                IsClosed = true;
                PodeHelpers.WriteException(ex, Context?.Listener, PodeLoggingLevel.Debug);
                Dispose();
            }
            catch (Exception)
            {
                // mark as closed, dispose - other code paths already log
                IsClosed = true;
                Dispose();
            }
            finally
            {
                // release the semaphore
                Semaphore?.Release();
            }

            return false;
        }

        public override void Dispose()
        {
            if (IsDisposed)
            {
                return;
            }

            lock (Lockable)
            {
                if (IsDisposed)
                {
                    return;
                }

                HttpListener.RemoveSignalConnection(this);
                base.Dispose();
                GC.SuppressFinalize(this);
            }
        }
    }
}