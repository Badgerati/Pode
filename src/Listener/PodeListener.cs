using System;
using System.Linq;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;

namespace Pode
{
    public class PodeListener : PodeConnector
    {
        private IList<PodeSocket> Sockets;

        public IDictionary<string, PodeSignal> Signals { get; private set; }
        public IDictionary<string, IDictionary<string, PodeServerEvent>> ServerEvents { get; private set; }
        public PodeItemQueue<PodeContext> Contexts { get; private set; }
        public PodeItemQueue<PodeServerSignal> ServerSignals { get; private set; }
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

        private int _requestBodySize = 104857600; // 100MB
        public int RequestBodySize
        {
            get => _requestBodySize;
            set
            {
                _requestBodySize = value <= 0 ? 104857600 : value;
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

        public PodeListener(CancellationToken cancellationToken = default(CancellationToken))
            : base(cancellationToken)
        {
            Sockets = new List<PodeSocket>();
            Signals = new Dictionary<string, PodeSignal>();
            ServerEvents = new Dictionary<string, IDictionary<string, PodeServerEvent>>();

            Contexts = new PodeItemQueue<PodeContext>();
            ServerSignals = new PodeItemQueue<PodeServerSignal>();
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
            }
        }

        private void Bind(PodeSocket socket)
        {
            socket.BindListener(this);
            Sockets.Add(socket);
        }

        public PodeContext GetContext(CancellationToken cancellationToken = default(CancellationToken))
        {
            return Contexts.Get(cancellationToken);
        }

        public Task<PodeContext> GetContextAsync(CancellationToken cancellationToken = default(CancellationToken))
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

        public void AddSignal(PodeSignal signal)
        {
            lock (Signals)
            {
                if (Signals.ContainsKey(signal.ClientId))
                {
                    Signals[signal.ClientId] = signal;
                }
                else
                {
                    Signals.Add(signal.ClientId, signal);
                }
            }
        }

        public void AddSseConnection(PodeServerEvent sse)
        {
            lock (ServerEvents)
            {
                // add sse name
                if (!ServerEvents.ContainsKey(sse.Name))
                {
                    ServerEvents.Add(sse.Name, new Dictionary<string, PodeServerEvent>());
                }

                // add sse connection
                if (ServerEvents[sse.Name].ContainsKey(sse.ClientId))
                {
                    ServerEvents[sse.Name][sse.ClientId]?.Dispose();
                    ServerEvents[sse.Name][sse.ClientId] = sse;
                }
                else
                {
                    ServerEvents[sse.Name].Add(sse.ClientId, sse);
                }
            }
        }

        public void SendSseEvent(string name, string[] groups, string[] clientIds, string eventType, string data, string id = null)
        {
            Task.Factory.StartNew(() =>
            {
                if (!ServerEvents.ContainsKey(name))
                {
                    return;
                }

                if (clientIds == default(string[]) || clientIds.Length == 0)
                {
                    clientIds = ServerEvents[name].Keys.ToArray();
                }

                foreach (var clientId in clientIds)
                {
                    if (!ServerEvents[name].ContainsKey(clientId))
                    {
                        continue;
                    }

                    if (ServerEvents[name][clientId].IsForGroup(groups))
                    {
                        ServerEvents[name][clientId].Context.Response.SendSseEvent(eventType, data, id);
                    }
                }
            }, CancellationToken);
        }

        public void CloseSseConnection(string name, string[] groups, string[] clientIds)
        {
            Task.Factory.StartNew(() =>
            {
                if (!ServerEvents.ContainsKey(name))
                {
                    return;
                }

                if (clientIds == default(string[]) || clientIds.Length == 0)
                {
                    clientIds = ServerEvents[name].Keys.ToArray();
                }

                foreach (var clientId in clientIds)
                {
                    if (!ServerEvents[name].ContainsKey(clientId))
                    {
                        continue;
                    }

                    if (ServerEvents[name][clientId].IsForGroup(groups))
                    {
                        ServerEvents[name][clientId].Context.Response.CloseSseConnection();
                    }
                }
            }, CancellationToken);
        }

        public bool TestSseConnectionExists(string name, string clientId)
        {
            // check name
            if (!ServerEvents.ContainsKey(name))
            {
                return false;
            }

            // check clientId
            if (!string.IsNullOrEmpty(clientId) && !ServerEvents[name].ContainsKey(clientId))
            {
                return false;
            }

            // exists
            return true;
        }

        public PodeServerSignal GetServerSignal(CancellationToken cancellationToken = default(CancellationToken))
        {
            return ServerSignals.Get(cancellationToken);
        }

        public Task<PodeServerSignal> GetServerSignalAsync(CancellationToken cancellationToken = default(CancellationToken))
        {
            return ServerSignals.GetAsync(cancellationToken);
        }

        public void AddServerSignal(string value, string path, string clientId)
        {
            ServerSignals.Add(new PodeServerSignal(value, path, clientId, this));
        }

        public void RemoveProcessingServerSignal(PodeServerSignal signal)
        {
            ServerSignals.RemoveProcessing(signal);
        }

        public PodeClientSignal GetClientSignal(CancellationToken cancellationToken = default(CancellationToken))
        {
            return ClientSignals.Get(cancellationToken);
        }

        public Task<PodeClientSignal> GetClientSignalAsync(CancellationToken cancellationToken = default(CancellationToken))
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
            // shutdown the sockets
            PodeHelpers.WriteErrorMessage($"Closing sockets", this, PodeLoggingLevel.Verbose);
            for (var i = Sockets.Count - 1; i >= 0; i--)
            {
                Sockets[i].Dispose();
            }

            Sockets.Clear();
            PodeHelpers.WriteErrorMessage($"Closed sockets", this, PodeLoggingLevel.Verbose);

            // close existing contexts
            PodeHelpers.WriteErrorMessage($"Closing contexts", this, PodeLoggingLevel.Verbose);
            foreach (var _context in Contexts.ToArray())
            {
                _context.Dispose(true);
            }

            Contexts.Clear();
            PodeHelpers.WriteErrorMessage($"Closed contexts", this, PodeLoggingLevel.Verbose);

            // close connected signals
            PodeHelpers.WriteErrorMessage($"Closing signals", this, PodeLoggingLevel.Verbose);
            foreach (var _signal in Signals.Values.ToArray())
            {
                _signal.Dispose();
            }

            Signals.Clear();
            PodeHelpers.WriteErrorMessage($"Closed signals", this, PodeLoggingLevel.Verbose);

            // close connected server events
            PodeHelpers.WriteErrorMessage($"Closing server events", this, PodeLoggingLevel.Verbose);
            foreach (var _sseName in ServerEvents.Values.ToArray())
            {
                foreach (var _sse in _sseName.Values.ToArray())
                {
                    _sse.Dispose();
                }

                _sseName.Clear();
            }

            ServerEvents.Clear();
            PodeHelpers.WriteErrorMessage($"Closed server events", this, PodeLoggingLevel.Verbose);
        }
    }
}