using System;

namespace Pode
{
    public class PodeClientSignal : IDisposable
    {
        public PodeWebSocket WebSocket { get; private set; }
        public string Message { get; private set; }
        public DateTime Timestamp { get; private set; }
        public PodeListener Listener { get; private set; }

        public PodeClientSignal(PodeWebSocket webSocket, string message, PodeListener listener)
        {
            WebSocket = webSocket;
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