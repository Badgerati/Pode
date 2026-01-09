using System;
using System.Net.Sockets;
using System.Threading.Tasks;
using Pode.Requests.Exceptions;
using Pode.Responses;
using Pode.Connectors;
using Pode.ClientConnections;
using Pode.ClientConnections.Signals;
using Pode.ClientConnections.SSE;
using Pode.Utilities;
using Pode.Requests.Strategies;

namespace Pode.Sockets.Contexts
{
    /// <summary>
    /// Represents the context for a Pode request, including state management, request handling, and response processing.
    /// </summary>
    public class PodeHttpContext : PodeContext, IDisposable
    {
        // The SSE client connection, if applicable.
        public PodeServerEvent SSE { get; private set; }

        // The WebSocket signal, if applicable.
        public PodeSignal Signal { get; private set; }

        // Determines if the context is associated with a WebSocket connection.
        public bool IsWebSocketUpgraded => Signal != default;

        // Determines if this context is associated with an SSE connection.
        public bool IsSSEUpgraded => SSE != default;

        // Determines if the connection should be kept alive.
        public override bool IsKeepAlive
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

                return base.IsKeepAlive;
            }
        }

        /// <summary>
        /// Initializes a new PodeHttpContext with the given socket, PodeSocket, and listener.
        /// </summary>
        /// <param name="socket">The socket used for the current connection.</param>
        /// <param name="podeSocket">The PodeSocket managing this context.</param>
        /// <param name="listener">The PodeListener associated with this context.</param>
        public PodeHttpContext(Socket socket, PodeSocket podeSocket, PodeListener listener)
            : base(socket, podeSocket, listener)
        {
            DefaultErrorStatusCode = 500;
        }

        /// <summary>
        /// Callback for handling request timeouts.
        /// </summary>
        /// <param name="state">An object containing state information for the callback.</param>
        protected override void TimeoutCallback(object state)
        {
            if (IsSSEUpgraded || IsWebSocketUpgraded)
            {
                PodeHelpers.WriteErrorMessage("Timeout ignored due to SSE/WebSocket", Listener, PodeLoggingLevel.Debug, this);
                return;
            }

            base.TimeoutCallback(state);
        }

        protected override void NewTimeoutTimer()
        {
            if (IsWebSocketUpgraded)
            {
                return;
            }

            base.NewTimeoutTimer();
        }

        /// <summary>
        /// Creates a new response object.
        /// </summary>
        protected override void NewResponse()
        {
            Response = new PodeHttpResponse(this);
        }

        /// <summary>
        /// Creates a new request object.
        /// </summary>
        /// <returns>A Task representing the async operation.</returns>
        protected override void NewRequest()
        {
            base.NewRequest();
            Request.SetStrategy(new PodeHttpRequestStrategy());
        }

        /// <summary>
        /// Ends the receiving process and handles the context based on whether it should be closed.
        /// </summary>
        /// <param name="close">Whether the context should be closed after receiving.</param>
        /// <returns>A Task representing the async operation.</returns>
        protected override async Task EndReceive(bool close)
        {
            if (close)
            {
                Response.StatusCode = 400;
            }

            await base.EndReceive(close).ConfigureAwait(false);
        }

        protected override async Task<bool> HandleRequestType()
        {
            if (!IsWebSocketUpgraded
                && !PodeSocket.NoAutoUpgradeWebSockets
                && Request.GetStrategy<PodeHttpRequestStrategy>().IsEligibleForWebSocketUpgrade)
            {
                await UpgradeToWebSocket(PodeClientConnectionScope.Global, string.Empty, Request.GetStrategy<PodeHttpRequestStrategy>().Url.AbsolutePath, string.Empty, Listener.TrackClientConnectionEvents).ConfigureAwait(false);
                return false;
            }

            return await base.HandleRequestType().ConfigureAwait(false);
        }

        protected override void Process()
        {
            if (IsWebSocketUpgraded)
            {
                PodeHelpers.WriteErrorMessage($"Received client signal", Listener, PodeLoggingLevel.Verbose, this);
                Listener.AddClientSignal(Request.GetStrategy<PodeSignalRequestStrategy>().NewClientSignal());
                Dispose();
            }
            else
            {
                base.Process();
            }
        }

        protected override void StartReceive()
        {
            if (IsSSEUpgraded)
            {
                return;
            }

            StartReceive(!IsWebSocketUpgraded);
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

            // ensure the HTTP method is GET or POST
            if (Request.GetStrategy<PodeHttpRequestStrategy>().HttpMethod != "GET" && Request.GetStrategy<PodeHttpRequestStrategy>().HttpMethod != "POST")
            {
                throw new PodeHttpRequestException("SSE upgrade requests must use the GET or POST HTTP method", 405);
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
                throw new PodeHttpRequestException("SSE client connection failed to open, connection could be closed/disposed", 421);
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

            // ensure the HTTP method is GET
            if (Request.GetStrategy<PodeHttpRequestStrategy>().HttpMethod != "GET")
            {
                throw new PodeHttpRequestException("WebSocket upgrade requests must use the GET HTTP method", 405);
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
                throw new PodeHttpRequestException("WebSocket client connection failed to open, connection could be closed/disposed", 421);
            }

            // add it to the listener
            Listener.AddSignalConnection(Signal);

            // set the request to be a SignalRequest
            var httpStrategy = Request.GetStrategy<PodeHttpRequestStrategy>();
            Request.SetStrategy(new PodeSignalRequestStrategy(httpStrategy, Signal));
            httpStrategy.Dispose();

            // return the Signal
            PodeHelpers.WriteErrorMessage($"WebSocket upgraded for client {clientId}", Listener, PodeLoggingLevel.Verbose, this);
            return Signal;
        }

        protected override void DisposeCleanUp()
        {
            SSE?.Dispose();
            SSE = null;

            Signal?.Dispose();
            Signal = null;
        }
    }
}