using System;

namespace Pode
{
    public class PodeSignal
    {
        public PodeContext Context { get; private set; }
        public string Path { get; private set; }
        public string ClientId { get; private set; }
        public DateTime Timestamp { get; private set; }

        public PodeSignal(PodeContext context, string path, string clientId)
        {
            Context = context;
            Path = path;
            ClientId = clientId;
            Timestamp = DateTime.UtcNow;
        }
    }
}