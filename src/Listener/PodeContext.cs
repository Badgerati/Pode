using System;
using System.Collections;
using System.IO;
using System.Net.Http;
using System.Net.Sockets;
using System.Security.Cryptography;
using System.Threading;

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
        public PodeContextType Type { get; private set; }

        private object _lockable = new object();

        private PodeContextState _state;
        public PodeContextState State
        {
            get => _state;
            private set
            {
                if (_state != PodeContextState.Timeout || value == PodeContextState.Closed)
                {
                    _state = value;
                }
            }
        }

        public bool CloseImmediately
        {
            get => (State == PodeContextState.Error
                || State == PodeContextState.Closing
                || State == PodeContextState.Timeout
                || Request.CloseImmediately);
        }

        public bool IsWebSocket
        {
            get => ((Type == PodeContextType.WebSocket)); // || (Type == PodeContextType.Unknown && Listener.Type == PodeListenerType.WebSocket));
        }

        public bool IsWebSocketUpgraded
        {
            get => (IsWebSocket && Request is PodeWsRequest);
        }

        public bool IsSmtp
        {
            get => ((Type == PodeContextType.Smtp) || (Type == PodeContextType.Unknown && Listener.Type == PodeListenerType.Smtp));
        }

        public bool IsHttp
        {
            get => ((Type == PodeContextType.Http) || (Type == PodeContextType.Unknown && Listener.Type == PodeListenerType.Http));
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

        public bool IsTimeout
        {
            get => (State == PodeContextState.Timeout);
        }

        public bool IsClosed
        {
            get => (State == PodeContextState.Closed);
        }

        public CancellationTokenSource ContextTimeoutToken { get; private set; }
        private Timer TimeoutTimer;

        public PodeContext(Socket socket, PodeSocket podeSocket, PodeListener listener)
        {
            ID = PodeHelpers.NewGuid();
            Socket = socket;
            PodeSocket = podeSocket;
            Listener = listener;
            Timestamp = DateTime.UtcNow;
            Data = new Hashtable(StringComparer.InvariantCultureIgnoreCase);

            Type = PodeContextType.Unknown;
            State = PodeContextState.New;

            NewResponse();
            NewRequest();
        }

        private void TimeoutCallback(object state)
        {
            ContextTimeoutToken.Cancel();
            State = PodeContextState.Timeout;

            Response.StatusCode = 408;
            Request.Error = new HttpRequestException("Request timeout");
            Request.Error.Data.Add("PodeStatusCode", 408);

            this.Dispose();
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
                //TODO: could we make this based on the socket type? then listener can be "anything"
                // and it's based on the socket?
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
            catch (Exception ex)
            {
                PodeHelpers.WriteException(ex, Listener, PodeLoggingLevel.Debug);
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
            //TODO: like above, could we remove listener type and just using socket type?
            switch (Listener.Type)
            {
                // - only allow smtp
                case PodeListenerType.Smtp:
                    var _reqSmtp = SmtpRequest;
                    Type = PodeContextType.Smtp;
                    break;

                // - only allow web-socket
                // case PodeListenerType.WebSocket:
                //     if (!HttpRequest.IsWebSocket)
                //     {
                //         throw new HttpRequestException("Request is not for a WebSocket");
                //     }

                //     Type = PodeContextType.WebSocket;
                //     break;

                // - only allow http
                case PodeListenerType.Http:
                    // if (HttpRequest.IsWebSocket)
                    // {
                    //     throw new HttpRequestException("Request is not Http");
                    // }

                    switch (PodeSocket.Type)
                    {
                        case PodeSocketType.Http:
                            if (HttpRequest.IsWebSocket)
                            {
                                throw new HttpRequestException("Request is not Http");
                            }

                            Type = PodeContextType.Http;
                            break;

                        case PodeSocketType.Ws:
                            if (!HttpRequest.IsWebSocket)
                            {
                                throw new HttpRequestException("Request is not for a WebSocket");
                            }

                            Type = PodeContextType.WebSocket;
                            break;

                        case PodeSocketType.HttpAndWs:
                            Type = HttpRequest.IsWebSocket
                                ? PodeContextType.WebSocket
                                : PodeContextType.Http;
                            break;

                        default:
                            throw new HttpRequestException("Request is not for Http or a WebSocket");
                    }

                    //TODO: ensure the socket allows http, ws, or both
                    // Type = HttpRequest.IsWebSocket
                    //     ? PodeContextType.WebSocket
                    //     : PodeContextType.Http;
                    break;
            }
        }

        public void RenewTimeoutToken()
        {
            ContextTimeoutToken = new CancellationTokenSource();
        }

        public async void Receive()
        {
            try
            {
                // start timeout
                TimeoutTimer = new Timer(TimeoutCallback, null, Listener.RequestTimeout * 1000, Timeout.Infinite);

                // start receiving
                State = PodeContextState.Receiving;
                try
                {
                    var close = await Request.Receive(ContextTimeoutToken.Token);
                    SetContextType();
                    EndReceive(close);
                }
                catch (OperationCanceledException) {}
            }
            catch (Exception ex)
            {
                PodeHelpers.WriteException(ex, Listener, PodeLoggingLevel.Debug);
                State = PodeContextState.Error;
                PodeSocket.HandleContext(this);
            }
        }

        public void EndReceive(bool close)
        {
            State = close ? PodeContextState.Closing : PodeContextState.Received;
            if (close)
            {
                Response.StatusCode = 400;
            }

            PodeSocket.HandleContext(this);
        }

        public void StartReceive()
        {
            NewResponse();
            State = PodeContextState.Receiving;
            PodeSocket.StartReceive(this);
            PodeHelpers.WriteErrorMessage($"Socket listening", Listener, PodeLoggingLevel.Verbose, this);
        }

        public void UpgradeWebSocket(string clientId = null)
        {
            PodeHelpers.WriteErrorMessage($"Uprading Websocket", Listener, PodeLoggingLevel.Verbose, this);

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

            var wsRequest = new PodeWsRequest(HttpRequest, webSocket);
            Request = wsRequest;

            Listener.AddWebSocket(WsRequest.WebSocket);
            PodeHelpers.WriteErrorMessage($"Websocket upgraded", Listener, PodeLoggingLevel.Verbose, this);
        }

        public void Dispose()
        {
            Dispose(Request.Error != default(HttpRequestException));
        }

        public void Dispose(bool force)
        {
            lock (_lockable)
            {
                if (IsClosed)
                {
                    Request.Dispose();
                    Response.Dispose();
                    ContextTimeoutToken.Dispose();
                    TimeoutTimer.Dispose();
                    return;
                }

                var _awaitingBody = false;

                // send the response and close, only close request if not keep alive
                try
                {
                    // dispose timeout token
                    ContextTimeoutToken.Dispose();
                    TimeoutTimer.Dispose();

                    // error or timeout?
                    if (IsErrored)
                    {
                        Response.StatusCode = 500;
                    }

                    // are we awaiting for more info?
                    if (IsHttp)
                    {
                        _awaitingBody = (HttpRequest.AwaitingBody && !IsErrored && !IsTimeout);
                    }

                    // only send a response if Http
                    if (IsHttp && State != PodeContextState.SslError && !_awaitingBody)
                    {
                        if (IsTimeout)
                        {
                            Response.SendTimeout();
                        }
                        else
                        {
                            Response.Send();
                        }
                    }

                    // if it was smtp, and it was processable, RESET!
                    if (IsSmtp && SmtpRequest.CanProcess)
                    {
                        SmtpRequest.Reset();
                    }

                    // dispose of request if not KeepAlive, and not waiting for body
                    if (!_awaitingBody && (!IsKeepAlive || force))
                    {
                        State = PodeContextState.Closed;
                        Request.Dispose();
                    }

                    if (!IsWebSocket || force)
                    {
                        Response.Dispose();
                    }
                }
                catch {}

                // if keep-alive, or awaiting body, setup for re-receive
                if ((_awaitingBody || (IsKeepAlive && !IsErrored && !IsTimeout)) && !force)
                {
                    StartReceive();
                }
            }
        }
    }
}