using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;

namespace Pode
{
    public class PodeListener : IDisposable
    {
        private IList<PodeSocket> Sockets;
        public bool IsListening { get; private set; }
        public bool ErrorLoggingEnabled { get; set; }

        private BlockingCollection<PodeContext> Contexts;

        public PodeListener()
        {
            Sockets = new List<PodeSocket>();
            Contexts = new BlockingCollection<PodeContext>();
        }

        public void Add(PodeSocket socket)
        {
            socket.BindListener(this);
            Sockets.Add(socket);
        }

        public PodeContext GetContext(CancellationToken cancellationToken)
        {
            return Contexts.Take(cancellationToken);
        }

        public Task<PodeContext> GetContextAsync(CancellationToken cancellationToken)
        {
            return Task.Factory.StartNew(() => GetContext(cancellationToken), cancellationToken);
        }

        public void AddContext(PodeRequest request, PodeResponse response)
        {
            lock (Contexts)
            {
                Contexts.Add(new PodeContext(request, response));
            }
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
            IsListening = false;

            for (var i = Sockets.Count - 1; i >= 0; i--)
            {
                Sockets[i].Dispose();
            }

            Sockets.Clear();
        }
    }
}