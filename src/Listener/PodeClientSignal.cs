using System;

namespace Pode
{
    public class PodeClientSignal : IDisposable
    {
        public PodeSignal Signal { get; private set; }
        public string Message { get; private set; }
        public DateTime Timestamp { get; private set; }
        public PodeListener Listener { get; private set; }

        public PodeClientSignal(PodeSignal signal, string message, PodeListener listener)
        {
            Signal = signal;
            Message = message;
            Timestamp = DateTime.UtcNow;
            Listener = listener;
        }

        public void Dispose()
        {
            Listener.RemoveProcessingClientSignal(this);
        }
    }
}