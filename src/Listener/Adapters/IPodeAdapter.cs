using System;
using System.Threading;

namespace Pode.Adapters
{
    public interface IPodeAdapter : IDisposable
    {
        bool IsConnected { get; }
        bool IsDisposed { get; }
        CancellationToken CancellationToken { get; }
        PodeAdapterType Type { get; }

        void Start();
    }
}