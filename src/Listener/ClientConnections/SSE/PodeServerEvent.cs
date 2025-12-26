using System;
using System.Collections;
using System.IO;
using System.Threading.Tasks;
using Pode.Sockets;
using Pode.Utilities;

namespace Pode.ClientConnections.SSE
{
    public class PodeServerEvent : PodeClientConnection
    {
        public bool AllowAllOrigins { get; private set; }
        public int Retry { get; private set; }
        public string LastEventId { get; set; }

        public PodeServerEvent(PodeContext context, string name, string group, string clientId, PodeClientConnectionScope scope, bool trackEvents, int retry, bool allowAllOrigins)
            : base(PodeClientConnectionType.SSE, context, name, group, clientId, scope, trackEvents)
        {
            Retry = retry;
            AllowAllOrigins = allowAllOrigins;
            LastEventId = $"{context.HttpRequest.Headers["Last-Event-ID"]}".Trim();
        }

        public override async Task<bool> Open()
        {
            if (IsDisposed || IsClosed)
            {
                return false;
            }

            // send SSE headers
            await Context.Response.SendSSEHeaders(ClientId, Name, Group, AllowAllOrigins).ConfigureAwait(false);

            // send retry event
            if (!await SendRetry().ConfigureAwait(false))
            {
                return false;
            }

            // send open event
            var data = $"{{\"clientId\":\"{ClientId}\",\"group\":\"{Group}\",\"name\":\"{Name}\"}}";
            if (!await Send(new PodeServerEventEnvelope(data, "pode.open")).ConfigureAwait(false))
            {
                return false;
            }

            return await base.Open().ConfigureAwait(false);
        }

        public override async Task Close()
        {
            if (IsClosed)
            {
                return;
            }

            await Send(new PodeServerEventEnvelope(string.Empty, "pode.close")).ConfigureAwait(false);
            await base.Close().ConfigureAwait(false);
        }

        public async Task<bool> Send(string eventType, string data, string id = null)
        {
            return await Send(new PodeServerEventEnvelope(data, eventType, id)).ConfigureAwait(false);
        }

        public override async Task<bool> Send(PodeClientConnectionEnvelope envelope)
        {
            if (IsClosed)
            {
                return false;
            }

            if (!(envelope is PodeServerEventEnvelope sseEnvelope))
            {
                throw new ArgumentException("Envelope must be of type PodeServerEventEnvelope", nameof(envelope));
            }

            // attempt to send ID
            if (!string.IsNullOrEmpty(sseEnvelope.ID))
            {
                if (!await SendEvent($"id: {sseEnvelope.ID}").ConfigureAwait(false))
                {
                    return false;
                }
            }

            // attempt to send event type
            if (!string.IsNullOrEmpty(sseEnvelope.EventType))
            {
                if (!await SendEvent($"event: {sseEnvelope.EventType}").ConfigureAwait(false))
                {
                    return false;
                }
            }

            // attempt to send data
            if (!await SendEvent($"data: {sseEnvelope.Message}{PodeHelpers.NEW_LINE}", true).ConfigureAwait(false))
            {
                return false;
            }

            return await base.Send(envelope).ConfigureAwait(false);
        }

        public async Task<bool> SendRetry()
        {
            if (Retry <= 0)
            {
                return true;
            }

            return await SendEvent($"retry: {Retry}", true).ConfigureAwait(false);
        }

        protected override async Task<bool> Ping()
        {
            return await Send(new PodeServerEventEnvelope(string.Empty, "pode.ping")).ConfigureAwait(false);
        }

        private async Task<bool> SendEvent(string message, bool flush = false)
        {
            // return false (no message sent), if no message or if closed
            if (string.IsNullOrEmpty(message) || IsClosed)
            {
                return false;
            }

            // wait for the semaphore to be available
            await Semaphore.WaitAsync().ConfigureAwait(false);

            try
            {
                // check again, if closed, return false (no message sent)
                if (IsClosed)
                {
                    return false;
                }

                // attempt to write the message, if false is returned then error
                if (!await Context.Response.WriteLine(message, flush).ConfigureAwait(false))
                {
                    throw new IOException($"Failed to send SSE event '{message.Split(':')[0]}', client connection is closed");
                }

                // message sent successfully
                return true;
            }
            catch (IOException ex)
            {
                // mark as closed, log, dispose
                IsClosed = true;
                PodeHelpers.WriteException(ex, Context?.Listener, PodeLoggingLevel.Debug);
                Dispose();
            }
            catch (Exception)
            {
                // mark as closed, dispose - other code paths already log
                IsClosed = true;
                Dispose();
            }
            finally
            {
                // release the semaphore
                Semaphore?.Release();
            }

            return false;
        }

        public override Hashtable ToHashtable()
        {
            var ht = base.ToHashtable();
            ht["RetryDuration"] = Retry;
            ht["AllowAllOrigins"] = AllowAllOrigins;
            ht["LastEventId"] = LastEventId;
            return ht;
        }

        public override void Dispose()
        {
            if (IsDisposed)
            {
                return;
            }

            lock (Lockable)
            {
                if (IsDisposed)
                {
                    return;
                }

                Context.Listener.RemoveSseConnection(this);
                base.Dispose();
                GC.SuppressFinalize(this);
            }
        }
    }
}