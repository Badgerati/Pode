using System;

namespace Pode
{
    public class PodeServerSignal : IDisposable
    {
        public string Value { get; private set; }
        public string Path { get; private set; }
        public string ClientId { get; private set; }
        public DateTime Timestamp { get; private set; }
        public PodeListener Listener { get; private set; }

        public PodeServerSignal(string value, string path, string clientId, PodeListener listener)
        {
            Value = value;
            Path = path;
            ClientId = clientId;
            Timestamp = DateTime.UtcNow;
            Listener = listener;
        }

        public void Dispose()
        {
            Listener.RemoveProcessingServerSignal(this);
        }
    }
}