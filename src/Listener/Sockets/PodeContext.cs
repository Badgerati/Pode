using System;
using System.Collections;
using System.IO;
using System.Net.Sockets;
using System.Threading;
using System.Threading.Tasks;
using Pode.Requests;
using Pode.Responses;
using Pode.Connectors;
using Pode.ClientConnections;
using Pode.ClientConnections.Signals;
using Pode.ClientConnections.SSE;
using Pode.Utilities;

namespace Pode.Sockets
{
    /// <summary>
    /// Represents the context for a Pode request, including state management, request handling, and response processing.
    /// </summary>
    public class PodeContext : IDisposable
    {
        // Unique identifier for the context.
        public string ID { get; private set; }

        // Represents the incoming request.
        public PodeRequest Request { get; private set; }

        // Represents the outgoing response.
        public PodeResponse Response { get; private set; }

        // Listener associated with the context.
        public PodeListener Listener { get; private set; }

        // The socket for the current connection.
        public Socket Socket { get; private set; }

        // The Pode socket associated with the context.
        public PodeSocket PodeSocket { get; private set; }

        // Timestamp when the context was created.
        public DateTime Timestamp { get; private set; }

        // Data storage for request-specific metadata.
        public Hashtable Data { get; private set; }

        // The SSE client connection, if applicable.
        public PodeServerEvent SSE { get; private set; }

        // The WebSocket signal, if applicable.
        public PodeSignal Signal { get; private set; }

        // The name of the endpoint associated with the socket.
        public string EndpointName => PodeSocket.Name;

        // Object used for thread-safety.
        protected readonly object Lockable = new object();

        // Flag indicating whether the context has been disposed.
        protected bool IsDisposed = false;

        // State of the context.
        private PodeContextState _state;
        public PodeContextState State
        {
            get => _state;
            private set
            {
                // Only allow changing from Timeout if transitioning to Closed or Error.
                if (_state != PodeContextState.Timeout || value == PodeContextState.Closed || value == PodeContextState.Error)
                {
                    _state = value;
                }
            }
        }

        // Determines if the context should be closed immediately.
        public bool CloseImmediately => State == PodeContextState.Error
                || State == PodeContextState.Closing
                || State == PodeContextState.Timeout
                || (Request?.CloseImmediately ?? true);

        // Determines if the context is associated with a WebSocket connection.
        public bool IsWebSocketUpgraded => Request is PodeSignalRequest && Signal != default;

        // Determines if this context is associated with an SSE connection.
        public bool IsSSEUpgraded => Request is PodeHttpRequest && SSE != default;

        // Strongly typed request properties for different protocols.
        public PodeSmtpRequest SmtpRequest => (PodeSmtpRequest)Request;
        public PodeHttpRequest HttpRequest => (PodeHttpRequest)Request;
        public PodeSignalRequest SignalRequest => (PodeSignalRequest)Request;

        // Determines if the connection should be kept alive.
        public virtual bool IsKeepAlive
        {
            get
            {
                if (IsSSEUpgraded)
                {
                    return SSE?.IsGlobal ?? false;
                }

                if (IsWebSocketUpgraded)
                {
                    return Signal?.IsGlobal ?? false;
                }

                return Request?.IsKeepAlive ?? false;
            }
        }

        // Flags for different context states.
        public bool IsErrored => State == PodeContextState.Error;
        public bool IsTimeout => State == PodeContextState.Timeout;
        public bool IsClosed => State == PodeContextState.Closed;
        public bool IsOpened => State == PodeContextState.Open;

        // Token and timer for managing request timeouts.
        public CancellationTokenSource ContextTimeoutToken { get; private set; }
        private Timer TimeoutTimer = null;

        /// <summary>
        /// Initializes a new PodeContext with the given socket, PodeSocket, and listener.
        /// </summary>
        /// <param name="socket">The socket used for the current connection.</param>
        /// <param name="podeSocket">The PodeSocket managing this context.</param>
        /// <param name="listener">The PodeListener associated with this context.</param>
        public PodeContext(Socket socket, PodeSocket podeSocket, PodeListener listener)
        {
            ID = PodeHelpers.NewGuid();
            Socket = socket;
            PodeSocket = podeSocket;
            Listener = listener;
            Timestamp = DateTime.UtcNow;
            Data = new Hashtable(StringComparer.InvariantCultureIgnoreCase);
            State = PodeContextState.New;
        }

        /// <summary>
        /// Initializes the request and response for the context.
        /// </summary>
        /// <returns>A Task representing the async operation.</returns>
        public virtual async Task Initialise()
        {
            NewResponse();
            await NewRequest().ConfigureAwait(false);

            if (IsOpened)
            {
                await Response.Acknowledge(PodeSocket.AcknowledgeMessage).ConfigureAwait(false);
            }
        }

        /// <summary>
        /// Callback for handling request timeouts.
        /// </summary>
        /// <param name="state">An object containing state information for the callback.</param>
        private void TimeoutCallback(object state)
        {
            try
            {
                PodeHelpers.WriteErrorMessage("TimeoutCallback triggered", Listener, PodeLoggingLevel.Debug, this);

                if (IsSSEUpgraded || IsWebSocketUpgraded)
                {
                    PodeHelpers.WriteErrorMessage("Timeout ignored due to SSE/WebSocket", Listener, PodeLoggingLevel.Debug, this);
                    return;
                }

                PodeHelpers.WriteErrorMessage($"Request timeout reached: {Listener.RequestTimeout} seconds", Listener, PodeLoggingLevel.Warning, this);

                ContextTimeoutToken.Cancel();
                State = PodeContextState.Timeout;

                Response.StatusCode = 408;
                Request.Error = new PodeRequestException($"Request timeout [ContextId: {this.ID}]", 408);

                Dispose();
                PodeHelpers.WriteErrorMessage($"Request timeout reached: Dispose", Listener, PodeLoggingLevel.Debug, this);
            }
            catch (Exception ex)
            {
                PodeHelpers.WriteErrorMessage($"Exception in TimeoutCallback: {ex}", Listener, PodeLoggingLevel.Error);
            }
        }

        /// <summary>
        /// Creates a new response object based on the socket type.
        /// </summary>
        protected virtual void NewResponse()
        {
            switch (PodeSocket.Type)
            {
                case PodeProtocolType.Smtp:
                    Response = new PodeSmtpResponse(this);
                    break;

                case PodeProtocolType.Tcp:
                    Response = new PodeTcpResponse(this);
                    break;

                default:
                    Response = new PodeHttpResponse(this);
                    break;
            }
        }

        /// <summary>
        /// Creates a new request object based on the socket type.
        /// </summary>
        /// <returns>A Task representing the async operation.</returns>
        protected virtual async Task NewRequest()
        {
            // Create a new request based on the socket type.
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

            // Attempt to open the request stream.
            await Request.Open(CancellationToken.None).ConfigureAwait(false);
            State = Request.State == PodeStreamState.Open
                ? PodeContextState.Open
                : PodeContextState.Error;
        }

        /// <summary>
        /// Cancels the request timeout by disposing of the timeout timer.
        /// </summary>
        public void CancelTimeout()
        {
            TimeoutTimer?.Dispose();
            TimeoutTimer = null;
        }

        /// <summary>
        /// Handles receiving data for the current request.
        /// </summary>
        /// <returns>A Task representing the async operation.</returns>
        public async Task Receive()
        {
            try
            {
                // Start timeout - unless receiving a WebSocket request.
                ContextTimeoutToken = new CancellationTokenSource();
                if (!IsWebSocketUpgraded)
                {
                    //TODO: make this a virtual NewTimeoutTimer - in PodeHttpContext we check IsWebSocketUpgraded before calling base
                    TimeoutTimer = new Timer(TimeoutCallback, null, Listener.RequestTimeout * 1000, Timeout.Infinite);
                }

                // Start receiving data.
                State = PodeContextState.Receiving;

                try
                {
                    PodeHelpers.WriteErrorMessage($"Receiving request", Listener, PodeLoggingLevel.Verbose, this);
                    var close = await Request.Receive(ContextTimeoutToken.Token).ConfigureAwait(false);
                    await EndReceive(close).ConfigureAwait(false);
                }
                catch (Exception ex) when (ex is IOException || ex is SocketException)
                {
                    // ignore if listener is closing, else re-throw
                    if (Listener.IsConnected)
                    {
                        throw;
                    }
                }
                catch (OperationCanceledException ex) when (ContextTimeoutToken.IsCancellationRequested)
                {
                    PodeHelpers.WriteErrorMessage("Request timed out during receive operation", Listener, PodeLoggingLevel.Warning, this);
                    State = PodeContextState.Timeout;  // Explicitly set the state to Timeout
                    Request.Error = new PodeRequestException("Request timed out", ex, 408);
                }
            }
            catch (Exception ex)
            {
                PodeHelpers.WriteException(ex, Listener, PodeLoggingLevel.Debug);
                State = PodeContextState.Error;
                await Handle().ConfigureAwait(false);
            }
        }

        /// <summary>
        /// Ends the receiving process and handles the context based on whether it should be closed.
        /// </summary>
        /// <param name="close">Whether the context should be closed after receiving.</param>
        /// <returns>A Task representing the async operation.</returns>
        public async Task EndReceive(bool close)
        {
            State = close ? PodeContextState.Closing : PodeContextState.Received;
            if (close)
            {
                Response.StatusCode = 400;
            }

            await Handle().ConfigureAwait(false);
        }

        private async Task Handle()
        {
            try
            {
                // Determine if the context should be processed.
                var process = true;

                // If the context should be closed immediately, dispose it.
                if (CloseImmediately)
                {
                    // Check if the request is aborted with a non-StatusCode of 408 (Request Timeout).
                    if (Request?.IsAborted ?? false)
                    {
                        PodeHelpers.WriteException(Request.Error, Listener, Request.Error.LoggingLevel);
                    }

                    Dispose(true);
                    process = false;
                }
                else if (Request.IsHttp && HttpRequest.IsEligibleForWebSocketUpgrade) // Handle WebSocket upgrade and context disposal.
                {
                    if (!PodeSocket.NoAutoUpgradeWebSockets && !IsWebSocketUpgraded)
                    {
                        await UpgradeToWebSocket(PodeClientConnectionScope.Global, string.Empty, HttpRequest.Url.AbsolutePath, string.Empty, Listener.TrackClientConnectionEvents).ConfigureAwait(false);
                        process = false;
                        Dispose();
                    }
                    else if (!Request.IsProcessable)
                    {
                        process = false;
                        Dispose();
                    }
                }
                else if (Request.IsSmtp) // Handle SMTP context disposal.
                {
                    if (!Request.IsProcessable)
                    {
                        process = false;
                        Dispose();
                    }
                }
                else if (Request.IsHttp) // Handle HTTP context disposal if awaiting body.
                {
                    if (HttpRequest.AwaitingBody)
                    {
                        process = false;
                        Dispose();
                    }
                }

                // Add the context for processing.
                if (process)
                {
                    if (IsWebSocketUpgraded)
                    {
                        PodeHelpers.WriteErrorMessage($"Received client signal", Listener, PodeLoggingLevel.Verbose, this);
                        Listener.AddClientSignal(SignalRequest.NewClientSignal());
                        Dispose();
                    }
                    else
                    {
                        PodeHelpers.WriteErrorMessage($"Received request", Listener, PodeLoggingLevel.Verbose, this);
                        Listener.AddContext(this);
                    }
                }
            }
            catch (Exception ex)
            {
                // Log any exceptions that occur while handling the context.
                PodeHelpers.WriteException(ex, Listener);
            }
        }

        /// <summary>
        /// Starts receiving data by creating a new response and setting the state.
        /// </summary>
        public void StartReceive()
        {
            if (!IsWebSocketUpgraded)
            {
                NewResponse();
            }

            State = PodeContextState.Receiving;
            PodeSocket.StartReceive(this);
            PodeHelpers.WriteErrorMessage($"Socket listening", Listener, PodeLoggingLevel.Verbose, this);
        }

        /// <summary>
        /// Upgrades the connection to a Server-Sent Events (SSE) connection.
        /// </summary>
        public async Task<PodeServerEvent> UpgradeToSSE(PodeClientConnectionScope scope, string clientId, string name, string group, bool trackEvents, int retry, bool allowAllOrigins)
        {
            // if no scope, skip. If SSE already upgraded, skip
            if (scope == PodeClientConnectionScope.None || IsSSEUpgraded)
            {
                return null;
            }

            PodeHelpers.WriteErrorMessage($"Upgrading SSE", Listener, PodeLoggingLevel.Verbose, this);

            // ensure it's an HTTP request
            if (!Request.IsHttp)
            {
                throw new PodeRequestException("Cannot upgrade a non-HTTP request to SSE", 412);
            }

            // ensure the HTTP method is GET or POST
            if (HttpRequest.HttpMethod != "GET" && HttpRequest.HttpMethod != "POST")
            {
                throw new PodeRequestException("SSE upgrade requests must use the GET or POST HTTP method", 405);
            }

            // cancel the timeout timer before upgrading
            CancelTimeout();

            // ensure we have a clientId
            if (string.IsNullOrWhiteSpace(clientId))
            {
                clientId = PodeHelpers.NewGuid();
            }

            // setup the SSE client connection, and open it
            SSE = new PodeServerEvent(this, name, group, clientId, scope, trackEvents, retry, allowAllOrigins);
            if (!await SSE.Open().ConfigureAwait(false))
            {
                throw new PodeRequestException("SSE client connection failed to open, connection could be closed/disposed", 421);
            }

            // add it to the listener
            Listener.AddSseConnection(SSE);

            // return the SSE connection
            PodeHelpers.WriteErrorMessage($"SSE upgraded for client {clientId}", Listener, PodeLoggingLevel.Verbose, this);
            return SSE;
        }

        /// <summary>
        /// Upgrades the connection to a WebSocket.
        /// </summary>
        public async Task<PodeSignal> UpgradeToWebSocket(PodeClientConnectionScope scope, string clientId, string name, string group, bool trackEvents)
        {
            // if no scope, skip. If WebSocket already upgraded, skip
            if (scope == PodeClientConnectionScope.None || IsWebSocketUpgraded)
            {
                return null;
            }

            PodeHelpers.WriteErrorMessage($"Upgrading Websocket", Listener, PodeLoggingLevel.Verbose, this);

            // ensure it's an HTTP request
            if (!Request.IsHttp)
            {
                throw new PodeRequestException("Cannot upgrade a non-HTTP request to WebSocket", 412);
            }

            // ensure the HTTP method is GET
            if (HttpRequest.HttpMethod != "GET")
            {
                throw new PodeRequestException("WebSocket upgrade requests must use the GET HTTP method", 405);
            }

            // Cancel the timeout timer before upgrading.
            CancelTimeout();

            // ensure we have a clientId
            if (string.IsNullOrWhiteSpace(clientId))
            {
                clientId = PodeHelpers.NewGuid();
            }

            // setup the WebSocket client connection, and open it
            Signal = new PodeSignal(this, name, group, clientId, scope, trackEvents);
            if (!await Signal.Open().ConfigureAwait(false))
            {
                throw new PodeRequestException("WebSocket client connection failed to open, connection could be closed/disposed", 421);
            }

            // add it to the listener
            Listener.AddSignalConnection(Signal);

            // set the request to be a SignalRequest
            Request = new PodeSignalRequest(HttpRequest, Signal);

            // return the Signal
            PodeHelpers.WriteErrorMessage($"WebSocket upgraded for client {clientId}", Listener, PodeLoggingLevel.Verbose, this);
            return Signal;
        }

        /// <summary>
        /// Disposes of the resources used by the context.
        /// </summary>
        public void Dispose()
        {
            Dispose(Request?.Error != default(PodeRequestException));
            GC.SuppressFinalize(this);
        }

        /// <summary>
        /// Disposes of the resources used by the context, with an option to force disposal.
        /// </summary>
        /// <param name="force">Whether to force the disposal of resources.</param>
        public void Dispose(bool force)
        {
            if (IsDisposed)
            {
                return;
            }

            lock (Lockable)
            {
                PodeHelpers.WriteErrorMessage($"Disposing Context", Listener, PodeLoggingLevel.Verbose, this);
                Listener.RemoveProcessingContext(this);

                if (IsClosed)
                {
                    if (!IsDisposed)
                    {
                        IsDisposed = true;
                        PodeSocket.RemovePendingSocket(Socket);

                        SSE?.Dispose();
                        SSE = null;

                        Signal?.Dispose();
                        Signal = null;

                        Request?.Dispose();
                        Request = null;

                        Response?.Dispose();
                        Response = null;

                        DisposeTimeoutResources();
                    }

                    return;
                }

                var _awaitingBody = false;

                try
                {
                    // Dispose timeout resources
                    DisposeTimeoutResources();

                    // Set error status code if context is errored.
                    if (IsErrored)
                    {
                        Response.StatusCode = Request.IsAborted ? Request.Error.StatusCode : 500;
                    }

                    // Determine if the HTTP request is awaiting more data.
                    if (Request.IsHttp)
                    {
                        _awaitingBody = HttpRequest.AwaitingBody && !IsErrored && !IsTimeout;
                    }

                    // Send response if HTTP and not awaiting body.
                    if (Request.IsOpen && !_awaitingBody)
                    {
                        if (IsTimeout)
                        {
                            Response.Timeout().Wait();
                        }
                        else
                        {
                            Response.Send().Wait();
                        }
                    }

                    // Reset SMTP request if it was processable.
                    if (Request.IsSmtp && Request.IsProcessable)
                    {
                        SmtpRequest.Reset();
                    }

                    // Dispose of request and response if not keep-alive or forced.
                    if (!_awaitingBody && (!IsKeepAlive || force))
                    {
                        State = PodeContextState.Closed;
                        IsDisposed = true;

                        SSE?.Dispose();
                        SSE = null;

                        Signal?.Dispose();
                        Signal = null;

                        Request?.Dispose();
                        Request = null;
                    }

                    if (Response.UpgradeStatus == PodeResponseUpgradeStatus.None || force)
                    {
                        Response?.Dispose();
                        Response = null;
                    }
                }
                catch (Exception ex)
                {
                    PodeHelpers.WriteException(ex, Listener, PodeLoggingLevel.Error);
                }
                finally
                {
                    // Handle re-receiving or socket clean-up.
                    if ((_awaitingBody || (IsKeepAlive && !IsErrored && !IsTimeout && !IsSSEUpgraded)) && !force)
                    {
                        PodeHelpers.WriteErrorMessage($"Re-receiving Request", Listener, PodeLoggingLevel.Verbose, this);
                        StartReceive();
                    }
                    else
                    {
                        PodeSocket.RemovePendingSocket(Socket);
                    }
                }
            }
        }

        /// <summary>
        /// Disposes timeout-related resources.
        /// </summary>
        private void DisposeTimeoutResources()
        {
            ContextTimeoutToken?.Dispose();
            ContextTimeoutToken = null;

            TimeoutTimer?.Dispose();
            TimeoutTimer = null;
        }
    }
}