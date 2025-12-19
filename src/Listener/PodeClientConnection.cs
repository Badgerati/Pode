using System;
using System.Collections;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;

namespace Pode
{
    public class PodeClientConnection : IDisposable
    {
        public PodeClientConnectionType ConnectionType { get; private set; }
        public PodeContext Context { get; private set; }
        public string Name { get; private set; }
        public string Group { get; private set; }
        public string ClientId { get; private set; }
        public PodeClientConnectionScope Scope { get; private set; } = PodeClientConnectionScope.None;
        public DateTime Timestamp { get; private set; }
        public DateTime LastActivity { get; protected set; }
        public bool IsDisposed { get; private set; }
        public bool IsClosed { get; protected set; }
        public bool TrackEvents { get; private set; } = false;

        // Convenience properties for scope
        public bool IsLocal => Scope == PodeClientConnectionScope.Local;
        public bool IsGlobal => Scope == PodeClientConnectionScope.Global;

        // Timer used for pinging the client connection
        private Timer PingTimer = null;

        // Objects used for thread-safety
        protected object Lockable { get; private set; } = new object();
        protected SemaphoreSlim Semaphore { get; private set; } = new SemaphoreSlim(1, 1);

        public PodeClientConnection(PodeClientConnectionType type, PodeContext context, string name, string group, string clientId, PodeClientConnectionScope scope, bool trackEvents)
        {
            ConnectionType = type;
            Context = context;
            Name = name;
            Group = group;
            ClientId = clientId;
            Scope = scope;
            Timestamp = DateTime.UtcNow;
            LastActivity = DateTime.UtcNow;
            TrackEvents = trackEvents;

            PingTimer = new Timer(PingCallback, null, TimeSpan.FromSeconds(60), TimeSpan.FromSeconds(60));
        }

        private async void PingCallback(object state)
        {
            if (IsDisposed)
            {
                return;
            }

            // if LastActivity is older than 59 seconds, ping the client - 59s to allow for 1s of leeway so we can ping every 60s
            if (DateTime.UtcNow - LastActivity < TimeSpan.FromSeconds(59))
            {
                return;
            }

            PodeHelpers.WriteErrorMessage($"Pinging client connection, ClientId: {ClientId}", Context?.Listener, PodeLoggingLevel.Debug, Context);

            if (await Ping().ConfigureAwait(false))
            {
                // LastActivity = DateTime.UtcNow;
                PodeHelpers.WriteErrorMessage($"Ping successful for client connection, ClientId: {ClientId}", Context?.Listener, PodeLoggingLevel.Debug, Context);
            }
            else
            {
                PodeHelpers.WriteErrorMessage($"Ping failed for client connection, ClientId: {ClientId}", Context?.Listener, PodeLoggingLevel.Debug, Context);
            }
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

        public virtual async Task<bool> Open()
        {
            await Task.CompletedTask;
            LastActivity = DateTime.UtcNow;
            return true;
        }

        public virtual async Task Close()
        {
            IsClosed = true;

            if (!IsDisposed)
            {
                Dispose();
            }

            await Task.CompletedTask;
        }

        public virtual async Task<bool> Send(PodeClientConnectionEnvelope envelope)
        {
            await Task.CompletedTask;
            LastActivity = DateTime.UtcNow;
            return true;
        }

        public virtual void Activity()
        {
            LastActivity = DateTime.UtcNow;
        }

        protected virtual async Task<bool> Ping()
        {
            await Task.CompletedTask;
            throw new NotImplementedException("Ping method is not implemented.");
        }

        public virtual Hashtable ToHashtable()
        {
            return new Hashtable(StringComparer.InvariantCultureIgnoreCase)
            {
                { "ConnectionType", ConnectionType.ToString() },
                { "Name", Name },
                { "Group", Group },
                { "ClientId", ClientId },
                { "Scope", Scope.ToString() },
                { "Timestamp", Timestamp },
                { "LastActivity", LastActivity },
                { "IsDisposed", IsDisposed },
                { "IsClosed", IsClosed }
            };
        }

        public virtual void Dispose()
        {
            if (IsDisposed)
            {
                return;
            }

            IsDisposed = true;

            if (!IsClosed)
            {
                Close().Wait();
            }

            PingTimer?.Dispose();
            PingTimer = null;

            Context?.Dispose(true);
            Context = null;

            Semaphore?.Dispose();
            Semaphore = null;

            GC.Collect();
            GC.SuppressFinalize(this);
        }
    }
}