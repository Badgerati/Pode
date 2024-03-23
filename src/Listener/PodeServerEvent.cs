using System;
using System.Linq;

namespace Pode
{
    public class PodeServerEvent : IDisposable
    {
        public PodeContext Context { get; private set; }
        public string Name { get; private set; }
        public string Group { get; private set; }
        public string ClientId { get; private set; }
        public DateTime Timestamp { get; private set; }

        public PodeServerEvent(PodeContext context, string name, string group, string clientId)
        {
            Context = context;
            Name = name;
            Group = group;
            ClientId = clientId;
            Timestamp = DateTime.UtcNow;
        }

        public bool IsForGroup(string[] groups)
        {
            if (groups == default(string[]) || groups.Length == 0)
            {
                return true;
            }

            if (string.IsNullOrEmpty(Group))
            {
                return false;
            }

            return groups.Any(x => x.Equals(Group, StringComparison.OrdinalIgnoreCase));
        }

        public void Dispose()
        {
            Context.Dispose(true);
        }
    }
}