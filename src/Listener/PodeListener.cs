using System;
using System.Linq;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;

namespace Pode
{
    public class PodeListener : IDisposable
    {
        public IDictionary<string, PodeWebSocket> WebSockets { get; private set; }
        public bool IsListening { get; private set; }
        public bool IsDisposed { get; private set; }
        public bool ErrorLoggingEnabled { get; set; }
        public string[] ErrorLoggingLevels { get; set; }
        public CancellationToken CancellationToken { get; private set; }

        private IList<PodeSocket> Sockets;

        public PodeListenerQueue<PodeContext> Contexts { get; private set; }
        public PodeListenerQueue<PodeServerSignal> ServerSignals { get; private set; }
        public PodeListenerQueue<PodeClientSignal> ClientSignals { get; private set; }

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
            WebSockets = new Dictionary<string, PodeWebSocket>();

            Contexts = new PodeListenerQueue<PodeContext>();
            ServerSignals = new PodeListenerQueue<PodeServerSignal>();
            ClientSignals = new PodeListenerQueue<PodeClientSignal>();
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

        public void AddWebSocket(PodeWebSocket webSocket)
        {
            lock (WebSockets)
            {
                if (WebSockets.ContainsKey(webSocket.ClientId))
                {
                    WebSockets[webSocket.ClientId] = webSocket;
                }
                else
                {
                    WebSockets.Add(webSocket.ClientId, webSocket);
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

            // close connected web sockets
            foreach (var _socket in WebSockets.Values)
            {
                _socket.Context.Dispose(true);
            }

            // disposed
            IsDisposed = true;
        }
    }

    public class PodeListenerQueue<T>
    {
        private BlockingCollection<T> Items;
        private List<T> ProcessingItems;

        public int Count { get => Items.Count + ProcessingItems.Count; }
        public int QueuedCount { get => Items.Count; }
        public int ProcessingCount { get => ProcessingItems.Count; }

        public PodeListenerQueue()
        {
            Items = new BlockingCollection<T>();
            ProcessingItems = new List<T>();
        }

        public T Get(CancellationToken cancellationToken = default(CancellationToken))
        {
            var item = (cancellationToken == default(CancellationToken)
                ? Items.Take()
                : Items.Take(cancellationToken));

            lock (ProcessingItems)
            {
                ProcessingItems.Add(item);
            }

            return item;
        }

        public Task<T> GetAsync(CancellationToken cancellationToken = default(CancellationToken))
        {
            return (cancellationToken == default(CancellationToken)
                ? Task.Factory.StartNew(() => Get())
                : Task.Factory.StartNew(() => Get(cancellationToken), cancellationToken));
        }

        public void Add(T item)
        {
            lock (Items)
            {
                Items.Add(item);
            }
        }

        public void RemoveProcessing(T item)
        {
            lock (ProcessingItems)
            {
                ProcessingItems.Remove(item);
            }
        }

        public T[] ToArray()
        {
            return Items.ToArray();
        }
    }
}