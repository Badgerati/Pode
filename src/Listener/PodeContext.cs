using System;
using System.Collections;
using System.Net.Http;
using System.Net.Sockets;
using System.Security.Cryptography;

namespace Pode
{
    public class PodeContext : IDisposable
    {
        public string ID { get; private set; }
        public PodeRequest Request { get; private set; }
        public PodeResponse Response { get; private set; }
        public PodeListener Listener { get; private set; }
        public Socket Socket { get; private set; }
        public PodeSocket PodeSocket { get; private set;}
        public DateTime Timestamp { get; private set; }
        public Hashtable Data { get; private set; }
        public PodeContextState State { get; private set; }

        public bool CloseImmediately
        {
            get => (State == PodeContextState.Error || string.IsNullOrWhiteSpace(Request.HttpMethod));
        }

        public bool IsWebSocket
        {
            get => (Request.Headers != default(Hashtable) && Request.Headers.ContainsKey("Sec-WebSocket-Key"));
        }

        public bool IsKeepAlive
        {
            get => (Request.Headers != default(Hashtable)
                && Request.Headers.ContainsKey("Connection")
                && $"{Request.Headers["Connection"]}".Equals("keep-alive", StringComparison.InvariantCultureIgnoreCase));
        }

        public PodeContext(Socket socket, PodeSocket podeSocket, PodeListener listener)
        {
            ID = PodeHelpers.NewGuid();
            Socket = socket;
            PodeSocket = podeSocket;
            Listener = listener;
            Timestamp = DateTime.UtcNow;
            Data = new Hashtable();
            State = PodeContextState.New;

            NewRequest();
            NewResponse();
        }

        private void NewResponse()
        {
            Response = new PodeResponse();
            Response.SetContext(this);
        }

        private void NewRequest()
        {
            // create a new request
            Request = new PodeRequest(Socket);
            Request.SetContext(this);

            // attempt to open the request stream
            try
            {
                Request.Open(PodeSocket.Certificate, PodeSocket.Protocols);
                State = PodeContextState.Open;
            }
            catch
            {
                State = PodeContextState.Error;
            }

            // attempt to receive data from the request stream
            Receive();
        }

        public void Receive()
        {
            try
            {
                State = PodeContextState.Receiving;
                Request.Receive();
                State = PodeContextState.Received;
            }
            catch
            {
                State = PodeContextState.Error;
            }
        }

        public void StartReceive()
        {
            NewResponse();
            State = PodeContextState.Receiving;
            PodeSocket.StartReceive(this);
        }

        public void UpgradeWebSocket(string clientId = null)
        {
            //websocket
            if (!IsWebSocket)
            {
                throw new HttpRequestException("Cannot upgrade a non-websocket request");
            }

            // set a default clientId
            if (string.IsNullOrWhiteSpace(clientId))
            {
                clientId = PodeHelpers.NewGuid();
            }

            // set the status of the response
            Response.StatusCode = 101;
            Response.StatusDescription = "Switching Protocols";

            // get the socket key from the request
            var socketKey = $"{Request.Headers["Sec-WebSocket-Key"]}".Trim();

            // make the socket accept hash
            var crypto = SHA1.Create();
            var socketHash = Convert.ToBase64String(crypto.ComputeHash(System.Text.Encoding.UTF8.GetBytes($"{socketKey}{PodeHelpers.WEB_SOCKET_MAGIC_KEY}")));

            // compile the headers
            Response.Headers.Clear();
            Response.Headers.Add("Connection", "Upgrade");
            Response.Headers.Add("Upgrade", "websocket");
            Response.Headers.Add("Sec-WebSocket-Accept", socketHash);

            if (!string.IsNullOrWhiteSpace(clientId))
            {
                Response.Headers.Add("X-Pode-ClientId", clientId);
            }

            // send message to upgrade web socket
            Response.Send();

            // add open web socket to listener
            Listener.AddWebSocket(new PodeWebSocket(this, Request.Url.AbsolutePath, clientId));
        }

        public void Dispose()
        {
            Dispose(Request.Error != default(HttpRequestException));
        }

        public void Dispose(bool force)
        {
            // send the response and close, only close request if not keep alive
            try
            {
                Response.Send();
                Response.Dispose();

                if (!IsKeepAlive || force)
                {
                    State = PodeContextState.Closed;
                    Request.Dispose();
                }
            }
            catch {}

            // if keep-alive, setup for re-receive
            if (IsKeepAlive && !force)
            {
                StartReceive();
            }
        }
    }
}