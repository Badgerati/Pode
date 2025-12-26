using System.Linq;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using Pode.Sockets;
using Pode.ClientConnections;
using Pode.ClientConnections.Signals;
using Pode.ClientConnections.SSE;
using Pode.Requests.Signals;
using Pode.Utilities;

namespace Pode.Connectors
{
    public class PodeListener : PodeConnector
    {
        private readonly List<PodeSocket> Sockets;
        public PodeClientConnectionNestedMap<PodeSignal> Signals { get; private set; }
        public PodeClientConnectionNestedMap<PodeServerEvent> ServerEvents { get; private set; }
        public PodeItemQueue<PodeContext> Contexts { get; private set; }
        public PodeItemQueue<PodeClientConnectionEvent> ClientConnectionEvents { get; private set; }
        public PodeItemQueue<PodeClientSignal> ClientSignals { get; private set; }

        private int _requestTimeout = 30;
        public int RequestTimeout
        {
            get => _requestTimeout;
            set
            {
                _requestTimeout = value <= 0 ? 30 : value;
            }
        }

        private const int DEFAULT_MAX_REQUEST_BODY_SIZE = 104857600; // 100MB
        private int _requestBodySize = DEFAULT_MAX_REQUEST_BODY_SIZE;
        public int RequestBodySize
        {
            get => _requestBodySize;
            set
            {
                _requestBodySize = value <= 0 ? DEFAULT_MAX_REQUEST_BODY_SIZE : value;
            }
        }

        private bool _showServerDetails = true;
        public bool ShowServerDetails
        {
            get => _showServerDetails;
            set
            {
                _showServerDetails = value;
            }
        }

        private bool _trackClientConnectionEvents = false;
        public bool TrackClientConnectionEvents
        {
            get => _trackClientConnectionEvents;
            set
            {
                _trackClientConnectionEvents = value;
            }
        }

        public PodeListener(PodeConnectorType type, CancellationToken cancellationToken = default)
            : base(type, cancellationToken)
        {
            Sockets = new List<PodeSocket>();
            Signals = new PodeClientConnectionNestedMap<PodeSignal>(this);
            ServerEvents = new PodeClientConnectionNestedMap<PodeServerEvent>(this);

            Contexts = new PodeItemQueue<PodeContext>();
            ClientConnectionEvents = new PodeItemQueue<PodeClientConnectionEvent>(trackProcessing: false);
            ClientSignals = new PodeItemQueue<PodeClientSignal>();
        }

        public void Add(PodeSocket socket)
        {
            var foundSocket = Sockets.FirstOrDefault(x => x.Equals(socket));
            if (foundSocket == default(PodeSocket))
            {
                Bind(socket);
            }
            else
            {
                foundSocket.Merge(socket);
                socket = null;
            }
        }

        private void Bind(PodeSocket socket)
        {
            socket.BindListener(this);
            Sockets.Add(socket);
        }

        public PodeContext GetContext(CancellationToken cancellationToken = default)
        {
            return Contexts.Get(cancellationToken);
        }

        public Task<PodeContext> GetContextAsync(CancellationToken cancellationToken = default)
        {
            return Contexts.GetAsync(cancellationToken);
        }

        public void AddContext(PodeContext context)
        {
            Contexts.Add(context);
        }

        public void RemoveProcessingContext(PodeContext context)
        {
            Contexts.RemoveProcessing(context);
        }

        public void AddSignalConnection(PodeSignal signal)
        {
            Signals.Add(signal);
        }

        public void RemoveSignalConnection(PodeSignal signal)
        {
            Signals.Remove(signal);
        }

        public void SendSignalMessage(string name, string[] groups, string[] clientIds, string message)
        {
            Signals.Send(name, groups, clientIds, new PodeSignalEnvelope(message));
        }

        public void CloseSignalConnection(string name, string[] groups, string[] clientIds)
        {
            Signals.Close(name, groups, clientIds);
        }

        public PodeSignal GetSignalConnection(string name, string[] groups, string clientId)
        {
            return Signals.Get(name, groups, clientId);
        }

        public bool TestSignalConnectionExists(string name, string[] groups, string clientId)
        {
            return Signals.Exists(name, groups, clientId);
        }

        public void AddSseConnection(PodeServerEvent sse)
        {
            ServerEvents.Add(sse);
        }

        public void RemoveSseConnection(PodeServerEvent sse)
        {
            ServerEvents.Remove(sse);
        }

        public void SendSseEvent(string name, string[] groups, string[] clientIds, string eventType, string data, string id = null)
        {
            ServerEvents.Send(name, groups, clientIds, new PodeServerEventEnvelope(data, eventType, id));
        }

        public void CloseSseConnection(string name, string[] groups, string[] clientIds)
        {
            ServerEvents.Close(name, groups, clientIds);
        }

        public PodeServerEvent GetSseConnection(string name, string[] groups, string clientId)
        {
            return ServerEvents.Get(name, groups, clientId);
        }

        public bool TestSseConnectionExists(string name, string[] groups, string clientId)
        {
            return ServerEvents.Exists(name, groups, clientId);
        }

        public PodeClientConnectionEvent GetClientConnectionEvent(CancellationToken cancellationToken = default)
        {
            return ClientConnectionEvents.Get(cancellationToken);
        }

        public Task<PodeClientConnectionEvent> GetClientConnectionEventAsync(CancellationToken cancellationToken = default)
        {
            return ClientConnectionEvents.GetAsync(cancellationToken);
        }

        public void AddClientConnectionEvent(PodeClientConnection connection, PodeClientConnectionEventType type)
        {
            if (!connection.TrackEvents)
            {
                return;
            }

            ClientConnectionEvents.Add(new PodeClientConnectionEvent(connection, type));
        }

        public PodeClientSignal GetClientSignal(CancellationToken cancellationToken = default)
        {
            return ClientSignals.Get(cancellationToken);
        }

        public Task<PodeClientSignal> GetClientSignalAsync(CancellationToken cancellationToken = default)
        {
            return ClientSignals.GetAsync(cancellationToken);
        }

        public void AddClientSignal(PodeClientSignal signal)
        {
            ClientSignals.Add(signal);
        }

        public void RemoveProcessingClientSignal(PodeClientSignal signal)
        {
            ClientSignals.RemoveProcessing(signal);
        }

        public override void Start()
        {
            foreach (var socket in Sockets)
            {
                socket.Listen();
                socket.Start();
            }

            base.Start();
        }

        protected override void Close()
        {
            // close existing contexts
            PodeHelpers.WriteErrorMessage($"Closing contexts", this, PodeLoggingLevel.Verbose);
            foreach (var _context in Contexts.ToArray())
            {
                _context.Dispose(true);
            }

            Contexts.Dispose();
            PodeHelpers.WriteErrorMessage($"Closed contexts", this, PodeLoggingLevel.Verbose);

            // close connected signals
            PodeHelpers.WriteErrorMessage($"Closing signals", this, PodeLoggingLevel.Verbose);
            foreach (var _signal in Signals.ToArray())
            {
                _signal.Dispose();
            }

            Signals.Dispose();
            PodeHelpers.WriteErrorMessage($"Closed signals", this, PodeLoggingLevel.Verbose);

            // close connected server events
            PodeHelpers.WriteErrorMessage($"Closing server events", this, PodeLoggingLevel.Verbose);
            foreach (var _sse in ServerEvents.ToArray())
            {
                _sse.Dispose();
            }

            ServerEvents.Dispose();
            PodeHelpers.WriteErrorMessage($"Closed server events", this, PodeLoggingLevel.Verbose);

            // shutdown the sockets
            PodeHelpers.WriteErrorMessage($"Closing sockets", this, PodeLoggingLevel.Verbose);
            for (var i = Sockets.Count - 1; i >= 0; i--)
            {
                Sockets[i].Dispose();
            }

            Sockets.Clear();
            PodeHelpers.WriteErrorMessage($"Closed sockets", this, PodeLoggingLevel.Verbose);
        }
    }
}