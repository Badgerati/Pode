using System;
using System.Collections;
using System.IO;
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
        public PodeContextType Type { get; private set; }
        public bool IsKeepAlive { get; private set; }

        public bool CloseImmediately
        {
            get => (State == PodeContextState.Error
                || string.IsNullOrWhiteSpace(Request.HttpMethod)
                || (IsWebSocket && !Request.HttpMethod.Equals("GET", StringComparison.InvariantCultureIgnoreCase)));
        }

        public bool IsWebSocket
        {
            get => (Type == PodeContextType.WebSocket);
        }

        public bool IsErrored
        {
            get => (State == PodeContextState.Error || State == PodeContextState.SslError);
        }


        public PodeContext(Socket socket, PodeSocket podeSocket, PodeListener listener)
        {
            ID = PodeHelpers.NewGuid();
            Socket = socket;
            PodeSocket = podeSocket;
            Listener = listener;
            Timestamp = DateTime.UtcNow;
            Data = new Hashtable();

            Type = PodeContextType.Unknown;
            State = PodeContextState.New;

            NewResponse();
            NewRequest();
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
                State = (Request.InputStream == default(Stream)
                    ? PodeContextState.Error
                    : PodeContextState.SslError);
            }
        }

        private void SetContextType()
        {
            if (Type != PodeContextType.Unknown)
            {
                return;
            }

            // web socket
            if (Request.Headers != default(Hashtable) && Request.Headers.ContainsKey("Sec-WebSocket-Key"))
            {
                Type = PodeContextType.WebSocket;
                return;
            }

            // http
            Type = PodeContextType.Http;
        }

        public void Receive()
        {
            try
            {
                State = PodeContextState.Receiving;
                Request.Receive();
                State = PodeContextState.Received;

                IsKeepAlive = (Request.Headers != default(Hashtable)
                    && Request.Headers.ContainsKey("Connection")
                    && $"{Request.Headers["Connection"]}".Equals("keep-alive", StringComparison.InvariantCultureIgnoreCase));
            }
            catch
            {
                State = PodeContextState.Error;
            }

            SetContextType();
        }

        public void StartReceive()
        {
            NewResponse();
            State = PodeContextState.Receiving;
            PodeSocket.StartReceive(this);
        }

        public void UpgradeWebSocket(string clientId = null)
        {
            // websocket
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
                if (IsErrored)
                {
                    Response.StatusCode = 500;
                }

                if (State != PodeContextState.SslError)
                {
                    Response.Send();
                }

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