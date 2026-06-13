using System;
using System.Threading;
using Pode.Utilities;
using Pode.Utilities.Logging;

namespace Pode.Adapters
{
    public abstract class PodeAdapter : IPodeAdapter
    {
        public bool IsConnected { get; private set; }
        public bool IsDisposed { get; private set; }
        public CancellationToken CancellationToken { get; private set; }
        public PodeAdapterType Type { get; private set; }

        public PodeAdapter(PodeAdapterType type, IPodeLogger logger, CancellationToken cancellationToken = default)
        {
            Type = type;
            PodeHelpers.SetLogger(logger);

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