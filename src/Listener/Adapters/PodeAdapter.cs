using System;
using System.Threading;

namespace Pode.Adapters
{
    public abstract class PodeAdapter : IPodeAdapter
    {
        public bool IsConnected { get; private set; }
        public bool IsDisposed { get; private set; }
        public bool ErrorLoggingEnabled { get; set; }
        public string[] ErrorLoggingLevels { get; set; }
        public CancellationToken CancellationToken { get; private set; }
        public PodeAdapterType Type { get; private set; }

        public PodeAdapter(PodeAdapterType type, CancellationToken cancellationToken = default)
        {
            Type = type;

            CancellationToken = cancellationToken == default
                ? cancellationToken
                : new CancellationTokenSource().Token;

            IsDisposed = false;
        }

        public virtual void Start()
        {
            IsConnected = true;
        }

        protected abstract void Close();

        public void Dispose()
        {
            // stop connecting
            IsConnected = false;

            // close
            Close();

            // disposed
            IsDisposed = true;
            GC.SuppressFinalize(this);
        }
    }
}