using System;
using System.Net.WebSockets;

namespace Pode
{
    public class PodeWsRequest : PodeRequest
    {
        public PodeWsOpCode OpCode { get; private set; }
        public string Body { get; private set; }
        public byte[] RawBody { get; private set; }
        public PodeWebSocket WebSocket { get; private set; }
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
            get => (OpCode == PodeWsOpCode.Close);
        }

        public PodeWsRequest(PodeHttpRequest request, PodeWebSocket webSocket)
            : base(request)
        {
            WebSocket = webSocket;
            IsKeepAlive = true;

            var _proto = (IsSsl ? "wss" : "ws");
            Host = request.Host;
            Url = new Uri($"{_proto}://{request.Url.Authority}{request.Url.PathAndQuery}");
        }

        public PodeClientSignal NewClientSignal()
        {
            return new PodeClientSignal(WebSocket, Body);
        }

        protected override bool Parse(byte[] bytes)
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

            // get the close status and description
            if (OpCode == PodeWsOpCode.Close)
            {
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
            }

            // send back a pong
            if (OpCode == PodeWsOpCode.Ping)
            {
                Context.Response.WriteFrame(string.Empty, PodeWsOpCode.Pong);
            }

            return true;
        }

        public override void Dispose()
        {
            // send close frame, remove client, and dispose
            Context.Response.WriteFrame(string.Empty, PodeWsOpCode.Close);
            Context.Listener.WebSockets.Remove(WebSocket.ClientId);
            base.Dispose();
        }

    }
}