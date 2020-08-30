using System;

namespace Pode
{
    public class PodeClientSignal
    {
        public PodeWebSocket WebSocket { get; private set; }
        public string Message { get; private set; }
        public DateTime Timestamp { get; private set; }

        public PodeClientSignal(PodeWebSocket webSocket, string message)
        {
            WebSocket = webSocket;
            Message = message;
            Timestamp = DateTime.UtcNow;
        }
    }
}