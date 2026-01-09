using System;
using System.Globalization;
using System.IO;
using System.Net;
using System.Text;
using System.Threading.Tasks;
using Pode.Requests.Strategies;
using Pode.Sockets.Contexts;
using Pode.Utilities;

namespace Pode.Responses
{
    public class PodeHttpResponse : PodeResponse
    {
        public PodeResponseHeaders Headers { get; private set; }
        public MemoryStream OutputStream { get; private set; }

        public bool IsHeadersSent { get; private set; }
        public bool IsBodySent { get; private set; }

        public override int StatusCode { get; set; } = 200;

        private string _statusDesc = string.Empty;
        public override string StatusDescription
        {
            get
            {
                if (string.IsNullOrWhiteSpace(_statusDesc) && Enum.IsDefined(typeof(HttpStatusCode), StatusCode))
                {
                    return ((HttpStatusCode)StatusCode).ToString();
                }

                return _statusDesc;
            }
            set => _statusDesc = value;
        }

        public long ContentLength64
        {
            get
            {
                if (!Headers.ContainsKey("Content-Length"))
                {
                    return 0;
                }

                return long.Parse($"{Headers["Content-Length"]}");
            }
            set
            {
                Headers.Set("Content-Length", value);
            }
        }

        public string ContentType
        {
            get => $"{Headers["Content-Type"]}";
            set => Headers.Set("Content-Type", value);
        }

        public string HttpResponseLine
        {
            get => $"{Request.GetStrategy<PodeHttpRequestStrategy>().Protocol} {StatusCode} {StatusDescription}{PodeHelpers.NEW_LINE}";
        }

        public PodeHttpResponse(PodeContext context)
            : base(context)
        {
            Headers = new PodeResponseHeaders();
            OutputStream = new MemoryStream();
            Type = PodeProtocolType.Http;
        }

        public override async Task Send()
        {
            if (IsSent || ConnectionUpgradeStatus == PodeUpgradeStatus.Completed || IsDisposed)
            {
                return;
            }

            PodeHelpers.WriteErrorMessage($"Sending response", Context.Listener, PodeLoggingLevel.Verbose, Context);

            try
            {
                await SendHeaders(Context.IsTimeout).ConfigureAwait(false);
                await SendBody(Context.IsTimeout).ConfigureAwait(false);
                PodeHelpers.WriteErrorMessage($"Response sent", Context.Listener, PodeLoggingLevel.Verbose, Context);
            }
            catch (OperationCanceledException) { }
            catch (IOException) { }
            catch (AggregateException aex)
            {
                PodeHelpers.HandleAggregateException(aex, Context.Listener);
            }
            catch (Exception ex)
            {
                PodeHelpers.WriteException(ex, Context.Listener);
                throw;
            }
            finally
            {
                await Flush().ConfigureAwait(false);
            }
        }

        public override async Task Timeout()
        {
            if (IsSent || ConnectionUpgradeStatus == PodeUpgradeStatus.Completed || IsDisposed)
            {
                return;
            }

            PodeHelpers.WriteErrorMessage($"Sending response timed-out", Context.Listener, PodeLoggingLevel.Verbose, Context);
            StatusCode = 408;

            try
            {
                await SendHeaders(true).ConfigureAwait(false);
                IsSent = true;
                PodeHelpers.WriteErrorMessage($"Response timed-out sent", Context.Listener, PodeLoggingLevel.Verbose, Context);
            }
            catch (OperationCanceledException) { }
            catch (IOException) { }
            catch (AggregateException aex)
            {
                PodeHelpers.HandleAggregateException(aex, Context.Listener);
            }
            catch (Exception ex)
            {
                PodeHelpers.WriteException(ex, Context.Listener);
                throw;
            }
            finally
            {
                await Flush().ConfigureAwait(false);
            }
        }

        public override async Task Acknowledge(string message)
        {
            // no-op for HTTP
            await Task.CompletedTask.ConfigureAwait(false);
        }

        public override async Task WriteFile(FileSystemInfo file)
        {
            if (IsSent || IsDisposed)
            {
                return;
            }

            var fileInfo = PodeHelpers.FileExists(file);
            ContentLength64 = fileInfo.Length;

            using (var fileStream = fileInfo.OpenRead())
            {
                await PodeHelpers.CopyFileTo(fileStream, OutputStream, Context.Listener.CancellationToken).ConfigureAwait(false);
            }
        }

        public async Task UpgradeToSSE(string clientId, string name, string group, bool allowAllOrigins)
        {
            ConnectionUpgradeStatus = PodeUpgradeStatus.InProgress;

            // clear headers, we only need the SSE headers
            Headers.Clear();

            // set appropriate SSE headers
            ContentType = "text/event-stream";
            Headers.Add("Cache-Control", "no-cache");
            Headers.Add("Connection", "keep-alive");

            if (allowAllOrigins)
            {
                Headers.Add("Access-Control-Allow-Origin", "*");
            }

            // set Pode specific SSE headers
            Headers.Set("X-Pode-Sse-Client-Id", clientId);
            Headers.Set("X-Pode-Sse-Name", name);

            if (!string.IsNullOrWhiteSpace(group))
            {
                Headers.Set("X-Pode-Sse-Group", group);
            }

            // send initial headers, and dispose output stream as we won't be using it
            PartialDispose();
            await Send().ConfigureAwait(false);
            ConnectionUpgradeStatus = PodeUpgradeStatus.Completed;
        }

        public async Task UpgradeToWebSocket(string clientId, string name, string group, string acceptHandshakeKey)
        {
            ConnectionUpgradeStatus = PodeUpgradeStatus.InProgress;

            // set the status code and description
            StatusCode = 101;
            StatusDescription = "Switching Protocols";

            // clear headers, we only need the WebSocket headers
            Headers.Clear();

            // set appropriate WebSocket headers
            Headers.Add("Upgrade", "websocket");
            Headers.Add("Connection", "Upgrade");
            Headers.Add("Sec-WebSocket-Accept", acceptHandshakeKey);

            // set Pode specific WebSocket headers
            Headers.Set("X-Pode-Signal-Client-Id", clientId);
            Headers.Set("X-Pode-Signal-Name", name);

            if (!string.IsNullOrWhiteSpace(group))
            {
                Headers.Set("X-Pode-Signal-Group", group);
            }

            // send initial headers, and dispose output stream as we won't be using it
            PartialDispose();
            await Send().ConfigureAwait(false);
            ConnectionUpgradeStatus = PodeUpgradeStatus.Completed;
        }

        private async Task SendBody(bool timeout)
        {
            if (IsBodySent || OutputStream == default)
            {
                return;
            }

            // stream response output
            if (!timeout)
            {
                await Request.Write(OutputStream, Context.Listener.CancellationToken).ConfigureAwait(false);
            }

            IsBodySent = true;
        }

        private async Task SendHeaders(bool timeout)
        {
            if (IsHeadersSent)
            {
                return;
            }

            // default headers
            if (timeout)
            {
                Headers.Clear();
            }

            SetDefaultHeaders();

            // stream response output
            IsHeadersSent = await Write(PodeHelpers.Encoding.GetBytes(BuildHeaders(Headers)));
        }

        private void SetDefaultHeaders()
        {
            // ensure content length (remove for 1xx responses, ensure added otherwise)
            if (StatusCode < 200 || ConnectionUpgradeStatus != PodeUpgradeStatus.None)
            {
                Headers.Remove("Content-Length");
            }
            else
            {
                if (ContentLength64 == 0)
                {
                    ContentLength64 = OutputStream?.Length > 0 ? OutputStream.Length : 0;
                }
            }

            // set the date
            if (Headers.ContainsKey("Date"))
            {
                Headers.Remove("Date");
            }

            Headers.Add("Date", DateTime.UtcNow.ToString("r", CultureInfo.InvariantCulture));

            // set the server if allowed
            if (Context.Listener.ShowServerDetails)
            {
                if (!Headers.ContainsKey("Server"))
                {
                    Headers.Add("Server", "Pode");
                }
            }
            else
            {
                if (Headers.ContainsKey("Server"))
                {
                    Headers.Remove("Server");
                }
            }

            // set context/socket ID
            if (Headers.ContainsKey("X-Pode-ContextId"))
            {
                Headers.Remove("X-Pode-ContextId");
            }

            Headers.Add("X-Pode-ContextId", Context.ID);

            // close the connection, only if request didn't specify keep-alive
            if (!Context.IsKeepAlive && ConnectionUpgradeStatus == PodeUpgradeStatus.None)
            {
                if (Headers.ContainsKey("Connection"))
                {
                    Headers.Remove("Connection");
                }

                Headers.Add("Connection", "close");
            }
        }

        private string BuildHeaders(PodeResponseHeaders headers)
        {
            var builder = new StringBuilder();
            builder.Append(HttpResponseLine);

            foreach (var key in headers.Keys)
            {
                foreach (var value in headers.Get(key))
                {
                    builder.Append($"{key}: {value}{PodeHelpers.NEW_LINE}");
                }
            }

            builder.Append(PodeHelpers.NEW_LINE);
            return builder.ToString();
        }

        private void PartialDispose()
        {
            if (OutputStream != default(MemoryStream))
            {
                OutputStream.Dispose();
                OutputStream = default;
            }
        }

        public override void Dispose()
        {
            if (IsDisposed)
            {
                return;
            }

            PartialDispose();

            base.Dispose();
            GC.SuppressFinalize(this);
        }
    }
}