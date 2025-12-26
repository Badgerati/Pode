using System;
using Pode.Connectors;
using Pode.ClientConnections.Signals;

namespace Pode.Requests.Signals
{
    public class PodeClientSignal : IDisposable
    {
        public PodeSignal Signal { get; private set; }
        public string Message { get; private set; }
        public DateTime Timestamp { get; private set; }
        public PodeListener Listener => Signal.Context.Listener;

        public PodeClientSignal(PodeSignal signal, string message)
        {
            Signal = signal;
            Message = message;
            Timestamp = DateTime.UtcNow;
        }

        public void Dispose()
        {
            Listener?.RemoveProcessingClientSignal(this);
            GC.SuppressFinalize(this);
        }
    }
}