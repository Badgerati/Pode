using System;
using System.Collections.Concurrent;
using System.Threading;

namespace Pode.Utilities.Logging
{
    public class PodeLogQueue<T> : IPodeLogQueue<T>
    {
        private readonly BlockingCollection<T> Queue;

        public bool IsDisposed { get; private set; } = false;
        public int Count => Queue.Count;

        public PodeLogQueue()
        {
            Queue = new BlockingCollection<T>();
        }

        public void Add(T logItem)
        {
            if (IsDisposed)
            {
                return;
            }

            // add the log item to the queue
            Queue.Add(logItem);
        }

        public bool TryTake(out T logItem, CancellationToken cancellationToken)
        {
            if (IsDisposed)
            {
                logItem = default;
                return false;
            }

            return Queue.TryTake(out logItem, 5000, cancellationToken);
        }

        public void Dispose()
        {
            if (IsDisposed)
            {
                return;
            }
            IsDisposed = true;

            // dispose the queue
            Queue.Dispose();

            // suppress finalization
            GC.SuppressFinalize(this);
        }
    }
}