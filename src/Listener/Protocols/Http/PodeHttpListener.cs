using System.Threading;
using System.Threading.Tasks;
using Pode.Utilities;
using Pode.Adapters.Listeners;
using Pode.Protocols.Http.Client;
using Pode.Protocols.Http.Client.Sse;
using Pode.Protocols.Http.Client.Signals;
using Pode.Adapters;

namespace Pode.Protocols.Http
{
    public class PodeHttpListener : PodeListener
    {
        public PodeClientConnectionNestedMap<PodeSignal> Signals { get; private set; }
        public PodeClientConnectionNestedMap<PodeServerEvent> ServerEvents { get; private set; }
        public PodeItemQueue<PodeClientConnectionEvent> ClientConnectionEvents { get; private set; }
        public PodeItemQueue<PodeClientSignal> ClientSignals { get; private set; }

        private bool _trackClientConnectionEvents = false;
        public bool TrackClientConnectionEvents
        {
            get => _trackClientConnectionEvents;
            set
            {
                _trackClientConnectionEvents = value;
            }
        }

        public PodeHttpListener(CancellationToken cancellationToken = default)
            : base(PodeAdapterType.Web, cancellationToken)
        {
            Signals = new PodeClientConnectionNestedMap<PodeSignal>(this);
            ServerEvents = new PodeClientConnectionNestedMap<PodeServerEvent>(this);
            ClientConnectionEvents = new PodeItemQueue<PodeClientConnectionEvent>(trackProcessing: false);
            ClientSignals = new PodeItemQueue<PodeClientSignal>();
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

        protected override void Close()
        {
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

            // call base close
            base.Close();
        }
    }
}