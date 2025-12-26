using System;
using System.Globalization;
using System.IO;
using System.Net;
using System.Text;
using System.Threading.Tasks;
using Pode.Sockets;
using Pode.Requests;
using Pode.Utilities;

namespace Pode.Responses
{
    public class PodeResponse : IDisposable
    {
        public PodeResponseHeaders Headers { get; private set; }
        public int StatusCode = 200;
        public bool SendChunked = false;
        public MemoryStream OutputStream { get; private set; }
        public bool IsDisposed { get; private set; }

        public PodeContext Context { get; private set; }
        private PodeRequest Request { get => Context.Request; }

        public bool SentHeaders { get; private set; }
        public bool SentBody { get; private set; }
        public bool Sent
        {
            get => SentHeaders && SentBody;
        }

        private string _statusDesc = string.Empty;
        public string StatusDescription
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
            get => $"{((PodeHttpRequest)Request).Protocol} {StatusCode} {StatusDescription}{PodeHelpers.NEW_LINE}";
        }

        public PodeResponse(PodeContext context)
        {
            Headers = new PodeResponseHeaders();
            OutputStream = new MemoryStream();
            Context = context;
        }

        public async Task Send()
        {
            if (Sent || IsDisposed || (SentHeaders && Context.IsSSE))
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

        public async Task SendTimeout()
        {
            if (SentHeaders || IsDisposed)
            {
                return;
            }

            PodeHelpers.WriteErrorMessage($"Sending response timed-out", Context.Listener, PodeLoggingLevel.Verbose, Context);
            StatusCode = 408;

            try
            {
                await SendHeaders(true).ConfigureAwait(false);
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

        private async Task SendHeaders(bool timeout)
        {
            if (SentHeaders)
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
            SentHeaders = await Write(PodeHelpers.Encoding.GetBytes(BuildHeaders(Headers)));
        }

        private async Task SendBody(bool timeout)
        {
            if (SentBody || Context.IsSSE)
            {
                return;
            }

            // stream response output
            if (!timeout)
            {
                await Request.Write(OutputStream, Context.Listener.CancellationToken).ConfigureAwait(false);
            }

            SentBody = true;
        }

        public async Task Flush()
        {
            await Request.Flush().ConfigureAwait(false);
        }

        public async Task SendSSEHeaders(string clientId, string name, string group, bool allowAllOrigins)
        {
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

            // send initial headers
            await Send().ConfigureAwait(false);
        }

        public async Task SendWebSocketHeaders(string clientId, string name, string group, string acceptHandshakeKey)
        {
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

            // send initial headers
            await Send().ConfigureAwait(false);
        }

        public async Task<bool> WriteLine(string message, bool flush = false)
        {
            return await Write(PodeHelpers.Encoding.GetBytes($"{message}{PodeHelpers.NEW_LINE}"), flush).ConfigureAwait(false);
        }

        // write a byte array to the actual client stream
        public async Task<bool> Write(byte[] buffer, bool flush = false)
        {
            return await Request.Write(buffer, Context.Listener.CancellationToken, flush);
        }

        public void WriteFile(string path)
        {
            WriteFile(new FileInfo(path));
        }

        public void WriteFile(FileSystemInfo file)
        {
            if (IsDisposed)
            {
                return;
            }

            if (!(file is FileInfo fileInfo) || !fileInfo.Exists)
            {
                throw new FileNotFoundException($"File not found: {file.FullName}");
            }

            ContentLength64 = fileInfo.Length;
            using (var fileStream = fileInfo.OpenRead())
            {
                fileStream.CopyTo(OutputStream);
            }
        }

        private void SetDefaultHeaders()
        {
            // ensure content length (remove for 1xx responses, ensure added otherwise)
            if (StatusCode < 200 || Context.IsSSE)
            {
                Headers.Remove("Content-Length");
            }
            else
            {
                if (ContentLength64 == 0)
                {
                    ContentLength64 = OutputStream.Length > 0 ? OutputStream.Length : 0;
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
            if (!Context.IsKeepAlive && !Context.IsWebSocket && !Context.IsSSE)
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

        public void Dispose()
        {
            if (IsDisposed)
            {
                return;
            }

            IsDisposed = true;

            if (OutputStream != default(MemoryStream))
            {
                OutputStream.Dispose();
                OutputStream = default;
            }

            GC.SuppressFinalize(this);
            PodeHelpers.WriteErrorMessage($"Response disposed", Context.Listener, PodeLoggingLevel.Verbose, Context);
        }
    }
}