using System;
using System.Collections;
using System.IO;
using System.Net.Http;
using System.Net.Sockets;
using System.Security.Cryptography;
using System.Threading;
using System.Threading.Tasks;

namespace Pode
{
    public class PodeContext : PodeProtocol, IDisposable
    {
        public string ID { get; private set; }
        public PodeRequest Request { get; private set; }
        public PodeResponse Response { get; private set; }
        public PodeListener Listener { get; private set; }
        public Socket Socket { get; private set; }
        public PodeSocket PodeSocket { get; private set; }
        public DateTime Timestamp { get; private set; }
        public Hashtable Data { get; private set; }
        public string EndpointName => PodeSocket.Name;

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

        public bool CloseImmediately => State == PodeContextState.Error
                || State == PodeContextState.Closing
                || State == PodeContextState.Timeout
                || Request.CloseImmediately;

        public new bool IsWebSocket => base.IsWebSocket || (IsUnknown && PodeSocket.IsWebSocket);
        public bool IsWebSocketUpgraded => IsWebSocket && Request is PodeSignalRequest;
        public new bool IsSmtp => base.IsSmtp || (IsUnknown && PodeSocket.IsSmtp);
        public new bool IsHttp => base.IsHttp || (IsUnknown && PodeSocket.IsHttp);

        public PodeSmtpRequest SmtpRequest => (PodeSmtpRequest)Request;
        public PodeHttpRequest HttpRequest => (PodeHttpRequest)Request;
        public PodeSignalRequest SignalRequest => (PodeSignalRequest)Request;

        public bool IsKeepAlive => (Request.IsKeepAlive && Response.SseScope != PodeSseScope.Local) || Response.SseScope == PodeSseScope.Global;
        public bool IsErrored => State == PodeContextState.Error || State == PodeContextState.SslError;
        public bool IsTimeout => State == PodeContextState.Timeout;
        public bool IsClosed => State == PodeContextState.Closed;
        public bool IsOpened => State == PodeContextState.Open;

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
        }

        public async Task Initialise()
        {
            NewResponse();
            await NewRequest().ConfigureAwait(false);
        }

        private void TimeoutCallback(object state)
        {
            if (Response.SseEnabled || Request.IsWebSocket)
            {
                return;
            }

            ContextTimeoutToken.Cancel();
            State = PodeContextState.Timeout;

            Response.StatusCode = 408;
            Request.Error = new HttpRequestException("Request timeout");
            Request.Error.Data.Add("PodeStatusCode", 408);

            Dispose();
        }

        private void NewResponse()
        {
            Response = new PodeResponse(this);
        }

        private async Task NewRequest()
        {
            // create a new request
            switch (PodeSocket.Type)
            {
                case PodeProtocolType.Smtp:
                    Request = new PodeSmtpRequest(Socket, PodeSocket, this);
                    break;

                case PodeProtocolType.Tcp:
                    Request = new PodeTcpRequest(Socket, PodeSocket, this);
                    break;

                default:
                    Request = new PodeHttpRequest(Socket, PodeSocket, this);
                    break;
            }

            // attempt to open the request stream
            try
            {
                await Request.Open(CancellationToken.None).ConfigureAwait(false);
                State = PodeContextState.Open;
            }
            catch (AggregateException aex)
            {
                PodeHelpers.HandleAggregateException(aex, Listener, PodeLoggingLevel.Debug, true);
                State = Request.InputStream == default(Stream)
                    ? PodeContextState.Error
                    : PodeContextState.SslError;
            }
            catch (Exception ex)
            {
                PodeLogger.WriteException(ex, Listener, PodeLoggingLevel.Debug);
                State = Request.InputStream == default(Stream)
                    ? PodeContextState.Error
                    : PodeContextState.SslError;
            }

            // if request is SMTP or TCP, send ACK if available
            if (IsOpened)
            {
                if (PodeSocket.IsSmtp)
                {
                    await SmtpRequest.SendAck().ConfigureAwait(false);
                }
                else if (PodeSocket.IsTcp && !string.IsNullOrWhiteSpace(PodeSocket.AcknowledgeMessage))
                {
                    await Response.WriteLine(PodeSocket.AcknowledgeMessage, true).ConfigureAwait(false);
                }
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

                // - only allow tcp
                case PodeProtocolType.Tcp:
                    if (!Request.IsTcp)
                    {
                        throw new HttpRequestException("Request is not Tcp");
                    }

                    Type = PodeProtocolType.Tcp;
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

        public void CancelTimeout()
        {
            TimeoutTimer.Dispose();
        }

        public async Task Receive()
        {
            try
            {
                // start timeout
                ContextTimeoutToken = new CancellationTokenSource();
                TimeoutTimer = new Timer(TimeoutCallback, null, Listener.RequestTimeout * 1000, Timeout.Infinite);

                // start receiving
                State = PodeContextState.Receiving;
                try
                {
                    PodeLogger.WriteErrorMessage($"Receiving request", Listener, PodeLoggingLevel.Verbose, this);
                    var close = await Request.Receive(ContextTimeoutToken.Token).ConfigureAwait(false);
                    SetContextType();
                    await EndReceive(close).ConfigureAwait(false);
                }
                catch (OperationCanceledException) { }
            }
            catch (Exception ex)
            {
                PodeLogger.WriteException(ex, Listener, PodeLoggingLevel.Debug);
                State = PodeContextState.Error;
                await PodeSocket.HandleContext(this).ConfigureAwait(false);
            }
        }

        public async Task EndReceive(bool close)
        {
            State = close ? PodeContextState.Closing : PodeContextState.Received;
            if (close)
            {
                Response.StatusCode = 400;
            }

            await PodeSocket.HandleContext(this).ConfigureAwait(false);
        }

        public void StartReceive()
        {
            NewResponse();
            State = PodeContextState.Receiving;
            PodeSocket.StartReceive(this);
            PodeLogger.WriteErrorMessage($"Socket listening", Listener, PodeLoggingLevel.Verbose, this);
        }

        public async Task UpgradeWebSocket(string clientId = null)
        {
            PodeLogger.WriteErrorMessage($"Upgrading Websocket", Listener, PodeLoggingLevel.Verbose, this);

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
            await Response.Send().ConfigureAwait(false);

            // add open web socket to listener
            var signal = new PodeSignal(this, HttpRequest.Url.AbsolutePath, clientId);
            Request = new PodeSignalRequest(HttpRequest, signal);
            Listener.AddSignal(SignalRequest.Signal);
            PodeLogger.WriteErrorMessage($"Websocket upgraded", Listener, PodeLoggingLevel.Verbose, this);
        }

        public void Dispose()
        {
            Dispose(Request.Error != default(HttpRequestException));
        }

        public void Dispose(bool force)
        {
            lock (_lockable)
            {
                PodeLogger.WriteErrorMessage($"Disposing Context", Listener, PodeLoggingLevel.Verbose, this);
                Listener.RemoveProcessingContext(this);

                if (IsClosed)
                {
                    PodeSocket.RemovePendingSocket(Socket);
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
                        _awaitingBody = HttpRequest.AwaitingBody && !IsErrored && !IsTimeout;
                    }

                    // only send a response if Http
                    if (IsHttp && State != PodeContextState.SslError && !_awaitingBody)
                    {
                        if (IsTimeout)
                        {
                            Response.SendTimeout().Wait();
                        }
                        else
                        {
                            Response.Send().Wait();
                        }
                    }

                    // if it was smtp, and it was processable, RESET!
                    if (IsSmtp && Request.IsProcessable)
                    {
                        SmtpRequest.Reset();
                    }

                    // dispose of request if not KeepAlive, and not waiting for body
                    if (!_awaitingBody && (!IsKeepAlive || force))
                    {
                        State = PodeContextState.Closed;

                        if (Response.SseEnabled)
                        {
                            Response.CloseSseConnection().Wait();
                        }

                        Request.Dispose();
                    }

                    if (!IsWebSocket || force)
                    {
                        Response.Dispose();
                    }
                }
                catch { }

                // if keep-alive, or awaiting body, setup for re-receive
                if ((_awaitingBody || (IsKeepAlive && !IsErrored && !IsTimeout && !Response.SseEnabled)) && !force)
                {
                    PodeLogger.WriteErrorMessage($"Re-receiving Request", Listener, PodeLoggingLevel.Verbose, this);
                    StartReceive();
                }
                else
                {
                    PodeSocket.RemovePendingSocket(Socket);
                }
            }
        }
    }
}