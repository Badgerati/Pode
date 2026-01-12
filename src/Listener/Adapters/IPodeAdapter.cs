using System;
using System.Threading;

namespace Pode.Adapters
{
    public interface IPodeAdapter : IDisposable
    {
        bool IsConnected { get; }
        bool IsDisposed { get; }
        bool ErrorLoggingEnabled { get; set; }
        string[] ErrorLoggingLevels { get; set; }
        CancellationToken CancellationToken { get; }
        PodeAdapterType Type { get; }

        void Start();
    }
}