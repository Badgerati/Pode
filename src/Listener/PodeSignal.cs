using System;

namespace Pode
{
    public class PodeSignal
    {
        public string Value { get; private set; }
        public string Path { get; private set; }
        public string ClientId { get; private set; }
        public DateTime Timestamp { get; private set; }

        public PodeSignal(string value, string path, string clientId)
        {
            Value = value;
            Path = path;
            ClientId = clientId;
            Timestamp = DateTime.UtcNow;
        }
    }
}