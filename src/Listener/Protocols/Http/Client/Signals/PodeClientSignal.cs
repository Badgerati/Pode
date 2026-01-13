using System;

namespace Pode.Protocols.Http.Client.Signals
{
    public class PodeClientSignal : IDisposable
    {
        public PodeSignal Signal { get; private set; }
        public string Message { get; private set; }
        public DateTime Timestamp { get; private set; }
        public PodeHttpListener Listener => Signal.Context.GetListener<PodeHttpListener>();

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