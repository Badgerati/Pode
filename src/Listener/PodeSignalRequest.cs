using System;
using System.Net.WebSockets;
using System.Threading;
using System.Threading.Tasks;

namespace Pode
{
    public class PodeSignalRequest : PodeRequest
    {
        public PodeWsOpCode OpCode { get; private set; }
        public string Body { get; private set; }
        public byte[] RawBody { get; private set; }
        public PodeSignal Signal { get; private set; }
        public Uri Url { get; private set; }
        public string Host { get; private set; }
        public int ContentLength { get; private set; }

        private WebSocketCloseStatus _closeStatus = WebSocketCloseStatus.Empty;
        public WebSocketCloseStatus CloseStatus
        {
            get => _closeStatus;
        }

        private string _closeDescription = string.Empty;
        public string CloseDescription
        {
            get => _closeDescription;
        }

        public override bool CloseImmediately
        {
            get => OpCode == PodeWsOpCode.Close;
        }

        public override bool IsProcessable
        {
            get => !CloseImmediately && OpCode != PodeWsOpCode.Pong && OpCode != PodeWsOpCode.Ping && !string.IsNullOrEmpty(Body);
        }

        public PodeSignalRequest(PodeHttpRequest request, PodeSignal signal)
            : base(request)
        {
            Signal = signal;
            IsKeepAlive = true;
            Type = PodeProtocolType.Ws;

            var _proto = IsSsl ? "wss" : "ws";
            Host = request.Host;
            Url = new Uri($"{_proto}://{request.Url.Authority}{request.Url.PathAndQuery}");
        }

        public PodeClientSignal NewClientSignal()
        {
            return new PodeClientSignal(Signal, Body, Context.Listener);
        }

        protected override async Task<bool> Parse(byte[] bytes, CancellationToken cancellationToken)
        {
            // get the length and op-code
            var dataLength = bytes[1] - 128;
            OpCode = (PodeWsOpCode)(bytes[0] & 0b00001111);
            var offset = 0;

            // set the offset relevant to the data's length
            if (dataLength < 126)
            {
                offset = 2;
            }
            else if (dataLength == 126)
            {
                dataLength = BitConverter.ToInt16(new byte[] { bytes[3], bytes[2] }, 0);
                offset = 4;
            }
            else
            {
                dataLength = (int)BitConverter.ToInt64(new byte[] { bytes[9], bytes[8], bytes[7], bytes[6], bytes[5], bytes[4], bytes[3], bytes[2] }, 0);
                offset = 10;
            }

            // read in the mask
            var mask = new byte[] { bytes[offset], bytes[offset + 1], bytes[offset + 2], bytes[offset + 3] };
            offset += 4;

            // build the decoded message
            var decoded = new byte[dataLength];
            for (var i = 0; i < dataLength; ++i)
            {
                decoded[i] = (byte)(bytes[offset + i] ^ mask[i % 4]);
            }

            // set the raw/body
            RawBody = bytes;
            ContentLength = RawBody.Length;
            Body = Encoding.GetString(decoded);

            // determine action based on code
            switch (OpCode)
            {
                // get the close status and description
                case PodeWsOpCode.Close:
                    _closeStatus = WebSocketCloseStatus.Empty;
                    _closeDescription = string.Empty;

                    if (dataLength >= 2)
                    {
                        Array.Reverse(decoded, 0, 2);
                        var code = (int)BitConverter.ToUInt16(decoded, 0);

                        _closeStatus = Enum.IsDefined(typeof(WebSocketCloseStatus), code)
                            ? (WebSocketCloseStatus)code
                            : WebSocketCloseStatus.Empty;

                        var descCount = dataLength - 2;
                        if (descCount > 0)
                        {
                            _closeDescription = Encoding.GetString(decoded, 2, descCount);
                        }
                    }
                    break;

                // send back a pong
                case PodeWsOpCode.Ping:
                    await Context.Response.WriteFrame(string.Empty, PodeWsOpCode.Pong).ConfigureAwait(false);
                    break;
            }

            return true;
        }

        /*   public override void Dispose()
           {
               // send close frame
               if (!IsDisposed)
               {
                   PodeHelpers.WriteErrorMessage($"Closing Websocket", Context.Listener, PodeLoggingLevel.Verbose, Context);
                   Context.Response.WriteFrame(string.Empty, PodeWsOpCode.Close).Wait();
               }

               // remove client, and dispose
               Context.Listener.Signals.Remove(Signal.ClientId);
               base.Dispose();
           }*/
           
        /// <summary>
        /// Dispose managed and unmanaged resources.
        /// </summary>
        /// <param name="disposing">Indicates if the method is called explicitly or by garbage collection.</param>
        protected override void Dispose(bool disposing)
        {
            if (disposing && !IsDisposed)
            {
                // Send close frame
                PodeHelpers.WriteErrorMessage($"Closing Websocket", Context.Listener, PodeLoggingLevel.Verbose, Context);

                // Wait for the close frame to be sent
                Context.Response.WriteFrame(string.Empty, PodeWsOpCode.Close).Wait();

                // Remove the client signal
                Context.Listener.Signals.Remove(Signal.ClientId);
            }

            // Call the base Dispose to clean up other resources
            base.Dispose(disposing);
        }

    }
}