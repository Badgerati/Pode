using System;
using System.Collections;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Net;
using System.Text;
using System.Threading.Tasks;

namespace Pode
{
    public class PodeResponse : IDisposable
    {
        protected const int MAX_FRAME_SIZE = 8192;

        public PodeResponseHeaders Headers { get; private set; }
        public int StatusCode = 200;
        public bool SendChunked = false;
        public MemoryStream OutputStream { get; private set; }
        public bool IsDisposed { get; private set; }

        private PodeContext Context;
        private PodeRequest Request { get => Context.Request; }

        public PodeSseScope SseScope { get; private set; } = PodeSseScope.None;
        public bool SseEnabled
        {
            get => SseScope != PodeSseScope.None;
        }

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

        private static readonly UTF8Encoding Encoding = new UTF8Encoding();

        public PodeResponse(PodeContext context)
        {
            Headers = new PodeResponseHeaders();
            OutputStream = new MemoryStream();
            Context = context;
        }
        
        //Clone constructor
        public PodeResponse(PodeResponse other)
        {
            // Copy the status code and other scalar values
            StatusCode = other.StatusCode;
            SendChunked = other.SendChunked;
            IsDisposed = other.IsDisposed;
            SseScope = other.SseScope;
            SentHeaders = other.SentHeaders;
            SentBody = other.SentBody;
            _statusDesc = other._statusDesc;

            // Create a new memory stream and copy the content of the other stream
            OutputStream = new MemoryStream();
            other.OutputStream.CopyTo(OutputStream);

            // Copy the headers (assuming PodeResponseHeaders supports cloning or deep copy)
            Headers = new PodeResponseHeaders();
            foreach (var key in other.Headers.Keys)
            {
                Headers.Set(key, other.Headers[key]);
            }

            // Copy the context and request, or create new instances if necessary (context should probably be reused)
            Context = other.Context;
        }


        public async Task Send()
        {
            if (Sent || IsDisposed || (SentHeaders && SseEnabled))
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
            if (SentHeaders || !Request.InputStream.CanWrite)
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
            var buffer = Encoding.GetBytes(BuildHeaders(Headers));
            await Request.InputStream.WriteAsync(buffer, 0, buffer.Length, Context.Listener.CancellationToken).ConfigureAwait(false);
            buffer = default;
            SentHeaders = true;
        }

        private async Task SendBody(bool timeout)
        {
            if (SentBody || SseEnabled || !Request.InputStream.CanWrite)
            {
                return;
            }

            // stream response output
            if (!timeout && OutputStream.Length > 0)
            {
                await Task.Run(() => OutputStream.WriteTo(Request.InputStream), Context.Listener.CancellationToken).ConfigureAwait(false);
            }

            SentBody = true;
        }

        public async Task Flush()
        {
            if (Request.InputStream.CanWrite)
            {
                await Request.InputStream.FlushAsync().ConfigureAwait(false);
            }
        }

        public async Task<string> SetSseConnection(PodeSseScope scope, string clientId, string name, string group, int retry, bool allowAllOrigins, string asyncRouteTaskId = null)
        {
            // do nothing for no scope
            if (scope == PodeSseScope.None)
            {
                return null;
            }

            // cancel timeout
            Context.CancelTimeout();
            SseScope = scope;

            // set appropriate SSE headers
            Headers.Clear();
            ContentType = "text/event-stream";
            Headers.Add("Cache-Control", "no-cache");
            Headers.Add("Connection", "keep-alive");

            if (allowAllOrigins)
            {
                Headers.Add("Access-Control-Allow-Origin", "*");
            }

            // generate clientId
            if (string.IsNullOrEmpty(clientId))
            {
                clientId = PodeHelpers.NewGuid();
            }

            Headers.Set("X-Pode-Sse-Client-Id", clientId);
            Headers.Set("X-Pode-Sse-Name", name);

            if (!string.IsNullOrEmpty(group))
            {
                Headers.Set("X-Pode-Sse-Group", group);
            }

            // send headers, and open event
            await Send().ConfigureAwait(false);
            await SendSseRetry(retry).ConfigureAwait(false);
            string sseEvent = (string.IsNullOrEmpty(asyncRouteTaskId)) ?
            $"{{\"clientId\":\"{clientId}\",\"group\":\"{group}\",\"name\":\"{name}\"}}" :
            $"{{\"clientId\":\"{clientId}\",\"group\":\"{group}\",\"name\":\"{name}\",\"asyncRouteTaskId\":\"{asyncRouteTaskId}\"}}";

            await SendSseEvent("pode.open", sseEvent).ConfigureAwait(false);

            // if global, cache connection in listener
            if (scope == PodeSseScope.Global)
            {
                Context.Listener.AddSseConnection(new PodeServerEvent(Context, name, group, clientId));
            }

            // return clientId
            return clientId;
        }

        public async Task CloseSseConnection()
        {
            await SendSseEvent("pode.close", string.Empty).ConfigureAwait(false);
        }

        public async Task SendSseEvent(string eventType, string data, string id = null)
        {
            if (!string.IsNullOrEmpty(id))
            {
                await WriteLine($"id: {id}").ConfigureAwait(false);
            }

            if (!string.IsNullOrEmpty(eventType))
            {
                await WriteLine($"event: {eventType}").ConfigureAwait(false);
            }

            await WriteLine($"data: {data}{PodeHelpers.NEW_LINE}", true).ConfigureAwait(false);
        }

        public async Task SendSseRetry(int retry)
        {
            if (retry <= 0)
            {
                return;
            }

            await WriteLine($"retry: {retry}", true).ConfigureAwait(false);
        }

        public async Task SendSignal(PodeServerSignal signal)
        {
            if (!string.IsNullOrEmpty(signal.Value))
            {
                await Write(signal.Value).ConfigureAwait(false);
            }
        }

        public async Task Write(string message, bool flush = false)
        {
            // simple messages
            if (!Context.IsWebSocket)
            {
                await Write(Encoding.GetBytes(message), flush).ConfigureAwait(false);
            }

            // web socket message
            else
            {
                await WriteFrame(message, PodeWsOpCode.Text, flush).ConfigureAwait(false);
            }
        }

        public async Task WriteFrame(string message, PodeWsOpCode opCode = PodeWsOpCode.Text, bool flush = false)
        {
            if (IsDisposed)
            {
                return;
            }

            var msgBytes = Encoding.GetBytes(message);
            var msgLength = msgBytes.Length;
            var offset = 0;
            var firstFrame = true;

            while (offset < msgLength || (msgLength == 0 && firstFrame))
            {
                var frameSize = Math.Min(msgLength - offset, MAX_FRAME_SIZE);
                var frame = new byte[frameSize];
                Array.Copy(msgBytes, offset, frame, 0, frameSize);

                // fin bit and op code
                var isFinal = offset + frameSize >= msgLength;
                var finBit = (byte)(isFinal ? 0x80 : 0x00);
                var opCodeByte = (byte)(firstFrame ? opCode : PodeWsOpCode.Continuation);

                // build the frame buffer
                var buffer = new List<byte> { (byte)(finBit | opCodeByte) };

                if (frameSize < 126)
                {
                    buffer.Add((byte)((byte)0x00 | (byte)frameSize));
                }
                else if (frameSize <= UInt16.MaxValue)
                {
                    buffer.Add((byte)((byte)0x00 | (byte)126));
                    buffer.Add((byte)((frameSize >> 8) & (byte)255));
                    buffer.Add((byte)(frameSize & (byte)255));
                }
                else
                {
                    buffer.Add((byte)((byte)0x00 | (byte)127));
                    buffer.Add((byte)((frameSize >> 56) & (byte)255));
                    buffer.Add((byte)((frameSize >> 48) & (byte)255));
                    buffer.Add((byte)((frameSize >> 40) & (byte)255));
                    buffer.Add((byte)((frameSize >> 32) & (byte)255));
                    buffer.Add((byte)((frameSize >> 24) & (byte)255));
                    buffer.Add((byte)((frameSize >> 16) & (byte)255));
                    buffer.Add((byte)((frameSize >> 8) & (byte)255));
                    buffer.Add((byte)(frameSize & (byte)255));
                }

                // add the payload
                buffer.AddRange(frame);

                // send
                await Write(buffer.ToArray(), flush).ConfigureAwait(false);
                offset += frameSize;
                firstFrame = false;
            }
        }

        public async Task WriteLine(string message, bool flush = false)
        {
            await Write(Encoding.GetBytes($"{message}{PodeHelpers.NEW_LINE}"), flush).ConfigureAwait(false);
        }

        public async Task Write(byte[] buffer, bool flush = false)
        {
            if (Request.IsDisposed || !Request.InputStream.CanWrite)
            {
                return;
            }

            try
            {
#if NETCOREAPP2_1_OR_GREATER
                await Request.InputStream.WriteAsync(buffer.AsMemory(), Context.Listener.CancellationToken).ConfigureAwait(false);
#else
                await Request.InputStream.WriteAsync(buffer, 0, buffer.Length, Context.Listener.CancellationToken).ConfigureAwait(false);
#endif

                if (flush)
                {
                    await Flush().ConfigureAwait(false);
                }
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
        }

        private void SetDefaultHeaders()
        {
            // ensure content length (remove for 1xx responses, ensure added otherwise)
            if (StatusCode < 200 || SseEnabled)
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
            if (!Context.IsKeepAlive && !Context.IsWebSocket && !SseEnabled)
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

            PodeHelpers.WriteErrorMessage($"Response disposed", Context.Listener, PodeLoggingLevel.Verbose, Context);
        }
    }
}