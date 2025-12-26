using System;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using System.IO;
using Pode.Connectors;
using Pode.Utilities;

namespace Pode.ClientConnections
{
    public class PodeClientConnectionNestedMap<T> : PodeItemNestedMap<T> where T : PodeClientConnection
    {
        private readonly PodeListener Listener = null;

        private long _processingCount = 0;
        public long ProcessingCount
        {
            get => _processingCount;
        }

        public PodeClientConnectionNestedMap(PodeListener listener)
            : base()
        {
            Listener = listener ?? throw new ArgumentNullException(nameof(listener));
        }

        public T Get(string name, string[] groups, string clientId)
        {
            var conn = Get(name, clientId);
            if (conn == default)
            {
                return default;
            }

            return conn.IsForGroup(groups)
                ? conn
                : default;
        }

        public void Add(T conn)
        {
            if (IsDisposed)
            {
                return;
            }

            // add the connection to the map if not a local connection
            if (!conn.IsLocal)
            {
                Add(conn.Name, conn.ClientId, conn);
            }

            // trigger the connected event
            Listener.AddClientConnectionEvent(conn, PodeClientConnectionEventType.Connect);
        }

        public bool Remove(T conn)
        {
            if (!Remove(conn.Name, conn.ClientId))
            {
                return false;
            }

            PodeHelpers.WriteErrorMessage($"Removed {conn.ConnectionType} client connection, ClientId: {conn.ClientId}, Name: {conn.Name}, Group: {conn.Group}", Listener, PodeLoggingLevel.Debug, conn.Context);
            Listener.AddClientConnectionEvent(conn, PodeClientConnectionEventType.Disconnect);
            return true;
        }

        public void Send(string name, string[] groups, string[] clientIds, PodeClientConnectionEnvelope envelope)
        {
            // check if disposed, or if the name doesn't exist
            if (IsDisposed || !Exists(name, out var connections))
            {
                return;
            }

            // increment the number of processing messages
            Interlocked.Increment(ref _processingCount);

            Task.Run(async () =>
            {
                try
                {
                    // if no client IDs specified, get all
                    if (clientIds == default(string[]) || clientIds.Length == 0)
                    {
                        clientIds = connections.Keys.ToArray();
                    }

                    // loop through each client ID, sending the message if group matches
                    foreach (var clientId in clientIds)
                    {
                        if (!connections.TryGetValue(clientId, out var conn))
                        {
                            continue;
                        }

                        // send the message if group matches
                        if (conn.IsForGroup(groups))
                        {
                            await conn.Send(envelope).ConfigureAwait(false);
                        }
                    }
                }
                catch (Exception ex) when (ex is OperationCanceledException || ex is IOException || ex is ObjectDisposedException)
                {
                    PodeHelpers.WriteException(ex, Listener, PodeLoggingLevel.Verbose);
                }
                catch (Exception ex)
                {
                    PodeHelpers.WriteException(ex, Listener, PodeLoggingLevel.Error);
                }
                finally
                {
                    Interlocked.Decrement(ref _processingCount);
                }
            }, Listener.CancellationToken);
        }

        public void Close(string name, string[] groups, string[] clientIds)
        {
            // check if disposed, or if the name doesn't exist
            if (IsDisposed || !Exists(name, out var connections))
            {
                return;
            }

            Task.Run(async () =>
            {
                try
                {
                    // if no client IDs specified, get all
                    if (clientIds == default(string[]) || clientIds.Length == 0)
                    {
                        clientIds = connections.Keys.ToArray();
                    }

                    // loop through each client ID, closing the connection if group matches
                    foreach (var clientId in clientIds)
                    {
                        if (!connections.TryGetValue(clientId, out var conn))
                        {
                            continue;
                        }

                        // close the connection
                        if (conn.IsForGroup(groups))
                        {
                            await conn.Close().ConfigureAwait(false);
                        }
                    }
                }
                catch (Exception ex) when (ex is OperationCanceledException || ex is IOException || ex is ObjectDisposedException)
                {
                    PodeHelpers.WriteException(ex, Listener, PodeLoggingLevel.Verbose);
                }
                catch (Exception ex)
                {
                    PodeHelpers.WriteException(ex, Listener, PodeLoggingLevel.Error);
                }
            }, Listener.CancellationToken);
        }

        public bool Exists(string name, string[] groups, string clientId)
        {
            if (IsDisposed || !Exists(name, out var connections))
            {
                return false;
            }

            if (string.IsNullOrEmpty(clientId))
            {
                return true;
            }

            if (!connections.TryGetValue(clientId, out var conn))
            {
                return false;
            }

            return conn.IsForGroup(groups);
        }

        public string[] GetGroups(string name)
        {
            if (IsDisposed || !Exists(name, out var connections))
            {
                return Array.Empty<string>();
            }

            return connections.Values
                .Select(x => x.Group)
                .Where(g => !string.IsNullOrEmpty(g))
                .Distinct(StringComparer.InvariantCultureIgnoreCase)
                .ToArray();
        }

        public string[] GetClientIds(string name, string[] groups)
        {
            if (IsDisposed || !Exists(name, out var connections))
            {
                return Array.Empty<string>();
            }

            // if no groups, return all clientIds
            if (groups == default(string[]) || groups.Length == 0)
            {
                return connections.Keys.ToArray();
            }

            // else, filter connections by group and get client IDs
            return connections.Values
                .Where(c => c.IsForGroup(groups))
                .Select(c => c.ClientId)
                .ToArray();
        }
    }
}