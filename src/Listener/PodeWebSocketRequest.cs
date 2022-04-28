using System;
using System.Text;
using System.IO;

namespace Pode
{
    public class PodeWebSocketRequest : IDisposable
    {

        public PodeWebSocket WebSocket {get; private set; }
        public byte[] RawBody { get; private set; }

        private string _body = string.Empty;
        public string Body
        {
            get
            {
                if (RawBody != default(byte[]) && RawBody.Length > 0)
                {
                    _body = Encoding.UTF8.GetString(RawBody);
                }

                return _body;
            }
        }

        public PodeWebSocketRequest(PodeWebSocket webSocket, MemoryStream bytes)
        {
            WebSocket = webSocket;
            RawBody = bytes.ToArray();
        }

        public void Dispose()
        {
            RawBody = default(byte[]);
            _body = string.Empty;
        }

    }
}