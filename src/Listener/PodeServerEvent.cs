using System;

namespace Pode
{
    public class PodeServerEvent : IDisposable
    {
        public PodeContext Context { get; private set; }
        public string Name { get; private set; }
        public string ClientId { get; private set; }
        public DateTime Timestamp { get; private set; }

        public PodeServerEvent(PodeContext context, string name, string clientId)
        {
            Context = context;
            Name = name;
            ClientId = clientId;
            Timestamp = DateTime.UtcNow;
        }

        public void Dispose()
        {
            Context.Dispose(true);
        }
    }
}