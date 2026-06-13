using System;
using System.Threading;

namespace Pode.Utilities.Logging
{
    public interface IPodeLogQueue<T> : IDisposable
    {
        bool IsDisposed { get; }
        int Count { get; }

        void Add(T logItem);
        bool TryTake(out T logItem, CancellationToken cancellationToken);
    }
}