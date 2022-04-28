using System;
using System.Linq;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;

namespace Pode
{
    public class PodeListener : IDisposable
    {
        public IDictionary<string, PodeSignal> Signals { get; private set; }
        public bool IsListening { get; private set; }
        public bool IsDisposed { get; private set; }
        public bool ErrorLoggingEnabled { get; set; }
        public string[] ErrorLoggingLevels { get; set; }
        public CancellationToken CancellationToken { get; private set; }

        private IList<PodeSocket> Sockets;

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

        public PodeListener(CancellationToken cancellationToken = default(CancellationToken))
        {
            CancellationToken = cancellationToken == default(CancellationToken)
                ? cancellationToken
                : (new CancellationTokenSource()).Token;

            IsDisposed = false;

            Sockets = new List<PodeSocket>();
            Signals = new Dictionary<string, PodeSignal>();

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

        public void Start()
        {
            foreach (var socket in Sockets)
            {
                socket.Listen();
                socket.Start();
            }

            IsListening = true;
        }

        public void Dispose()
        {
            // stop listening
            IsListening = false;

            // shutdown the sockets
            for (var i = Sockets.Count - 1; i >= 0; i--)
            {
                Sockets[i].Dispose();
            }

            Sockets.Clear();

            // close existing contexts
            foreach (var _context in Contexts.ToArray())
            {
                _context.Dispose(true);
            }

            Contexts.Clear();

            // close connected signals
            foreach (var _signal in Signals.Values)
            {
                _signal.Context.Dispose(true);
            }

            Signals.Clear();

            // disposed
            IsDisposed = true;
        }
    }
}