using System;
using System.Collections;
using System.IO;
using System.Net.Sockets;
using System.Threading;
using System.Threading.Tasks;
using Pode.Protocols.Common.Requests;
using Pode.Protocols.Common.Responses;
using Pode.Adapters.Listeners;
using Pode.Utilities;
using Pode.Transport.Sockets;

namespace Pode.Protocols.Common.Contexts
{
    /// <summary>
    /// Represents the context for a Pode request, including state management, request handling, and response processing.
    /// </summary>
    public class PodeContext : IPodeContext, IDisposable
    {
        // Unique identifier for the context.
        public string ID { get; private set; }

        // Represents the incoming request.
        public PodeRequestHandler Request { get; private set; }

        // Represents the outgoing response.
        public PodeResponse Response { get; protected set; }

        // Listener associated with the context.
        public IPodeListener Listener { get; private set; }

        // The socket for the current connection.
        public Socket Socket { get; private set; }

        // The Pode socket associated with the context.
        public PodeSocket PodeSocket { get; private set; }

        // Timestamp when the context was created.
        public DateTime Timestamp { get; private set; }

        // Data storage for request-specific metadata.
        public Hashtable Data { get; private set; }

        public int DefaultErrorStatusCode { get; protected set; } = 0;

        // The name of the endpoint associated with the socket.
        public string EndpointName => PodeSocket.Name;

        // Object used for thread-safety.
        protected readonly object Lockable = new object();

        // Flag indicating whether the context has been disposed.
        public bool IsDisposed { get; private set; } = false;

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

        // Determines if the connection should be kept alive.
        public virtual bool IsKeepAlive
        {
            get
            {
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
        protected PodeContext(Socket socket, PodeSocket podeSocket, IPodeListener listener)
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
            NewRequest();
            await OpenRequest().ConfigureAwait(false);
        }

        /// <summary>
        /// Retrieves the listener associated with the context, cast to the specified type.
        /// </summary>
        public T GetListener<T>() where T : IPodeListener
        {
            return (T)Listener;
        }

        /// <summary>
        /// Callback for handling request timeouts.
        /// </summary>
        /// <param name="state">An object containing state information for the callback.</param>
        protected virtual void TimeoutCallback(object state)
        {
            try
            {
                PodeHelpers.WriteErrorMessage("TimeoutCallback triggered", Listener, PodeLoggingLevel.Debug, this);
                PodeHelpers.WriteErrorMessage($"Request timeout reached: {Listener.RequestTimeout} seconds", Listener, PodeLoggingLevel.Warning, this);

                ContextTimeoutToken.Cancel();
                State = PodeContextState.Timeout;

                Request.Timeout();
                Response.StatusCode = Request.Error.StatusCode;

                Dispose();
                PodeHelpers.WriteErrorMessage($"Request timeout reached: Dispose", Listener, PodeLoggingLevel.Debug, this);
            }
            catch (Exception ex)
            {
                PodeHelpers.WriteErrorMessage($"Exception in TimeoutCallback: {ex}", Listener, PodeLoggingLevel.Error);
            }
        }

        protected virtual void NewTimeoutTimer()
        {
            TimeoutTimer = new Timer(TimeoutCallback, null, Listener.RequestTimeout * 1000, Timeout.Infinite);
        }

        /// <summary>
        /// Creates a new response object based on the socket type.
        /// </summary>
        protected virtual void NewResponse()
        {
            throw new NotImplementedException();
        }

        /// <summary>
        /// Creates a new request object based on the socket type.
        /// </summary>
        /// <returns>A Task representing the async operation.</returns>
        protected virtual void NewRequest()
        {
            Request = new PodeRequestHandler(Socket, PodeSocket, this);
        }

        private async Task OpenRequest()
        {
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
                NewTimeoutTimer();

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
                catch (OperationCanceledException) when (ContextTimeoutToken.IsCancellationRequested)
                {
                    PodeHelpers.WriteErrorMessage("Request timed out during receive operation", Listener, PodeLoggingLevel.Warning, this);
                    State = PodeContextState.Timeout;  // Explicitly set the state to Timeout
                    Request.Timeout();
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
        protected virtual async Task EndReceive(bool close)
        {
            State = close ? PodeContextState.Closing : PodeContextState.Received;
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

                // is the request processable?
                else if (!Request.IsProcessable)
                {
                    process = false;
                    Dispose();
                }

                // else, handle upgrades and special cases
                else
                {
                    process = await HandleRequestType().ConfigureAwait(false);
                    if (!process)
                    {
                        Dispose();
                    }
                }

                // Add the context for processing.
                if (process)
                {
                    Process();
                }
            }
            catch (Exception ex)
            {
                // Log any exceptions that occur while handling the context.
                PodeHelpers.WriteException(ex, Listener);
            }
        }

        protected virtual async Task<bool> HandleRequestType()
        {
            await Task.CompletedTask.ConfigureAwait(false);
            return true;
        }

        protected virtual void Process()
        {
            PodeHelpers.WriteErrorMessage($"Received request", Listener, PodeLoggingLevel.Verbose, this);
            Listener.AddContext(this);
        }

        /// <summary>
        /// Starts receiving data by creating a new response and setting the state.
        /// </summary>
        protected virtual void StartReceive()
        {
            StartReceive(true);
        }

        protected void StartReceive(bool newResponse)
        {
            PodeHelpers.WriteErrorMessage($"Re-receiving Request", Listener, PodeLoggingLevel.Verbose, this);

            // if (!IsWebSocketUpgraded)
            if (newResponse)
            {
                NewResponse();
            }

            State = PodeContextState.Receiving;
            PodeSocket.StartReceive(this);
            PodeHelpers.WriteErrorMessage($"Socket listening", Listener, PodeLoggingLevel.Verbose, this);
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

                        DisposeCleanUp();

                        Request?.Dispose();
                        Request = null;

                        Response?.Dispose();
                        Response = null;

                        DisposeTimeoutResources();
                    }

                    return;
                }

                var _awaitingContent = false;

                try
                {
                    // Dispose timeout resources
                    DisposeTimeoutResources();

                    // Set error status code if context is errored.
                    if (IsErrored)
                    {
                        Response.StatusCode = Request.IsAborted ? Request.Error.StatusCode : DefaultErrorStatusCode;
                    }

                    // Determine if the request is awaiting more data.
                    _awaitingContent = Request.AwaitingContent && !IsErrored && !IsTimeout;

                    // Send response if HTTP and not awaiting content.
                    if (Request.IsOpen && !_awaitingContent)
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

                    // Reset request if it's allowed, and was processable.
                    if (Request.IsResettable && Request.IsProcessable)
                    {
                        Request.Reset();
                    }

                    // Dispose of request and response if not keep-alive or forced.
                    if (!_awaitingContent && (!IsKeepAlive || force))
                    {
                        State = PodeContextState.Closed;
                        IsDisposed = true;

                        DisposeCleanUp();

                        Request?.Dispose();
                        Request = null;
                    }

                    if (Response.ConnectionUpgradeStatus == PodeUpgradeStatus.None || force)
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
                    if ((_awaitingContent || (IsKeepAlive && !IsErrored && !IsTimeout)) && !force)
                    {
                        StartReceive();
                    }
                    else
                    {
                        PodeSocket.RemovePendingSocket(Socket);
                    }
                }
            }
        }

        protected virtual void DisposeCleanUp()
        {
            // Placeholder for any additional cleanup logic needed during disposal.
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