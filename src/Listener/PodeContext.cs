using System;
using System.Collections;
using System.IO;
using System.Net.Http;
using System.Net.Sockets;
using System.Security.Cryptography;
using System.Threading;

namespace Pode
{
    public class PodeContext : PodeProtocol, IDisposable
    {
        public string ID { get; private set; }
        public PodeRequest Request { get; private set; }
        public PodeResponse Response { get; private set; }
        public PodeListener Listener { get; private set; }
        public Socket Socket { get; private set; }
        public PodeSocket PodeSocket { get; private set;}
        public DateTime Timestamp { get; private set; }
        public Hashtable Data { get; private set; }

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

        public new bool IsWebSocket
        {
            get => (base.IsWebSocket || (base.IsUnknown && PodeSocket.IsWebSocket));
        }

        public bool IsWebSocketUpgraded
        {
            get => (IsWebSocket && Request is PodeWsRequest);
        }

        public new bool IsSmtp
        {
            get => (base.IsSmtp || (base.IsUnknown && PodeSocket.IsSmtp));
        }

        public new bool IsHttp
        {
            get => (base.IsHttp || (base.IsUnknown && PodeSocket.IsHttp));
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

        public bool IsOpened
        {
            get => (State == PodeContextState.Open);
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

            Type = PodeProtocolType.Unknown;
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
            switch (PodeSocket.Type)
            {
                case PodeProtocolType.Smtp:
                    Request = new PodeSmtpRequest(Socket, PodeSocket);
                    break;

                default:
                    Request = new PodeHttpRequest(Socket, PodeSocket);
                    break;
            }

            Request.SetContext(this);

            // attempt to open the request stream
            try
            {
                Request.Open();
                State = PodeContextState.Open;
            }
            catch (AggregateException aex)
            {
                PodeHelpers.HandleAggregateException(aex, Listener, PodeLoggingLevel.Debug, true);
                State = (Request.InputStream == default(Stream)
                    ? PodeContextState.Error
                    : PodeContextState.SslError);
            }
            catch (Exception ex)
            {
                PodeHelpers.WriteException(ex, Listener, PodeLoggingLevel.Debug);
                State = (Request.InputStream == default(Stream)
                    ? PodeContextState.Error
                    : PodeContextState.SslError);
            }

            // if request is SMTP, send ACK
            if (IsOpened && PodeSocket.IsSmtp)
            {
                SmtpRequest.SendAck();
            }
        }

        private void SetContextType()
        {
            if (!IsUnknown && !(base.IsHttp && Request.IsWebSocket))
            {
                return;
            }

            // depending on socket type, either:
            switch (PodeSocket.Type)
            {
                // - only allow smtp
                case PodeProtocolType.Smtp:
                    if (!Request.IsSmtp)
                    {
                        throw new HttpRequestException("Request is not Smtp");
                    }

                    Type = PodeProtocolType.Smtp;
                    break;

                // - only allow http
                case PodeProtocolType.Http:
                    if (Request.IsWebSocket)
                    {
                        throw new HttpRequestException("Request is not Http");
                    }

                    Type = PodeProtocolType.Http;
                    break;

                // - only allow web-socket
                case PodeProtocolType.Ws:
                    if (!Request.IsWebSocket)
                    {
                        throw new HttpRequestException("Request is not for a WebSocket");
                    }

                    Type = PodeProtocolType.Ws;
                    break;

                // - allow http and web-socket
                case PodeProtocolType.HttpAndWs:
                    Type = Request.IsWebSocket ? PodeProtocolType.Ws : PodeProtocolType.Http;
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
                Listener.RemoveProcessingContext(this);

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