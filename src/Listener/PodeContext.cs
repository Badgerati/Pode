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

        public bool CloseImmediately
        {
            get => (State == PodeContextState.Error || State == PodeContextState.Closing || Request.CloseImmediately);
        }

        public bool IsWebSocket
        {
            get => (Type == PodeContextType.WebSocket);
        }

        public bool IsWebSocketUpgraded
        {
            get => (IsWebSocket && Request is PodeWsRequest);
        }

        public bool IsSmtp
        {
            get => (Type == PodeContextType.Smtp);
        }

        public bool IsHttp
        {
            get => (Type == PodeContextType.Http);
        }

        public PodeSmtpRequest SmtpRequest
        {
            get => (PodeSmtpRequest)Request;
        }

        public PodeHttpRequest HttpRequest
        {
            get => (PodeHttpRequest)Request;
        }

        public PodeWsRequest WsRequest
        {
            get => (PodeWsRequest)Request;
        }

        public bool IsKeepAlive
        {
            get => (Request.IsKeepAlive);
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
            switch (Listener.Type)
            {
                case PodeListenerType.Smtp:
                    Request = new PodeSmtpRequest(Socket);
                    break;

                default:
                    Request = new PodeHttpRequest(Socket);
                    break;
            }

            Request.SetContext(this);

            // attempt to open the request stream
            try
            {
                Request.Open(PodeSocket.Certificate, PodeSocket.Protocols, PodeSocket.AllowClientCertificate);
                State = PodeContextState.Open;
            }
            catch
            {
                State = (Request.InputStream == default(Stream)
                    ? PodeContextState.Error
                    : PodeContextState.SslError);
            }

            // if request is SMTP, send ACK
            if (Listener.Type == PodeListenerType.Smtp)
            {
                SmtpRequest.SendAck();
            }
        }

        private void SetContextType()
        {
            if (Type != PodeContextType.Unknown)
            {
                return;
            }

            // depending on listener type, either:
            switch (Listener.Type)
            {
                // - only allow smtp
                case PodeListenerType.Smtp:
                    var _reqSmtp = SmtpRequest;
                    Type = PodeContextType.Smtp;
                    break;

                // - only allow web-socket
                case PodeListenerType.WebSocket:
                    if (!HttpRequest.IsWebSocket)
                    {
                        throw new HttpRequestException("Request is not for a WebSocket");
                    }

                    Type = PodeContextType.WebSocket;
                    break;

                // - only allow http
                case PodeListenerType.Http:
                    if (HttpRequest.IsWebSocket)
                    {
                        throw new HttpRequestException("Request is not Http");
                    }

                    Type = PodeContextType.Http;
                    break;
            }
        }

        public void Receive()
        {
            try
            {
                State = PodeContextState.Receiving;
                Request.Receive();
                SetContextType();
            }
            catch
            {
                State = PodeContextState.Error;
            }
        }

        public void EndReceive(bool close)
        {
            PodeSocket.HandleContext(this);
            State = close ? PodeContextState.Closing : PodeContextState.Received;
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
            var socketKey = $"{HttpRequest.Headers["Sec-WebSocket-Key"]}".Trim();

            // make the socket accept hash
            var crypto = SHA1.Create();
            var socketHash = Convert.ToBase64String(crypto.ComputeHash(System.Text.Encoding.UTF8.GetBytes($"{socketKey}{PodeHelpers.WEB_SOCKET_MAGIC_KEY}")));

            // compile the headers
            Response.Headers.Clear();
            Response.Headers.Set("Connection", "Upgrade");
            Response.Headers.Set("Upgrade", "websocket");
            Response.Headers.Set("Sec-WebSocket-Accept", socketHash);

            if (!string.IsNullOrWhiteSpace(clientId))
            {
                Response.Headers.Set("X-Pode-ClientId", clientId);
            }

            // send message to upgrade web socket
            Response.Send();

            // add open web socket to listener
            var webSocket = new PodeWebSocket(this, HttpRequest.Url.AbsolutePath, clientId);

            var wsRequest = new PodeWsRequest(HttpRequest);
            wsRequest.WebSocket = webSocket;
            Request = wsRequest;

            Listener.AddWebSocket(WsRequest.WebSocket);
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

                // only send a response if Http
                if (IsHttp && State != PodeContextState.SslError && !HttpRequest.AwaitingBody)
                {
                    Response.Send();
                }

                // if it was smtp, and it was processable, RESET!
                if (IsSmtp && SmtpRequest.CanProcess)
                {
                    SmtpRequest.Reset();
                }

                // dispose of request if not KeepAlive, and not waiting for body
                if (((IsHttp && !HttpRequest.AwaitingBody) || !IsHttp) && (!IsKeepAlive || force))
                {
                    State = PodeContextState.Closed;
                    Request.Dispose();
                }

                Response.Dispose();
            }
            catch {}

            // if keep-alive, or awaiting body, setup for re-receive
            if (((IsHttp && HttpRequest.AwaitingBody) || IsKeepAlive) && !force)
            {
                StartReceive();
            }
        }
    }
}