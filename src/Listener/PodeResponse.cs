using System;
using System.Collections;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Net;
using System.Text;

namespace Pode
{
    public class PodeResponse : IDisposable
    {
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

        private static UTF8Encoding Encoding = new UTF8Encoding();

        public PodeResponse()
        {
            Headers = new PodeResponseHeaders();
            OutputStream = new MemoryStream();
        }

        public void Send()
        {
            if (Sent || IsDisposed || (SentHeaders && SseEnabled))
            {
                return;
            }

            PodeHelpers.WriteErrorMessage($"Sending response", Context.Listener, PodeLoggingLevel.Verbose, Context);

            try
            {
                SendHeaders(Context.IsTimeout);
                SendBody(Context.IsTimeout);
                PodeHelpers.WriteErrorMessage($"Response sent", Context.Listener, PodeLoggingLevel.Verbose, Context);
            }
            catch (OperationCanceledException) {}
            catch (IOException) {}
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
                Flush();
            }
        }

        public void SendTimeout()
        {
            if (SentHeaders || IsDisposed)
            {
                return;
            }

            PodeHelpers.WriteErrorMessage($"Sending response timed-out", Context.Listener, PodeLoggingLevel.Verbose, Context);
            StatusCode = 408;

            try
            {
                SendHeaders(true);
                PodeHelpers.WriteErrorMessage($"Response timed-out sent", Context.Listener, PodeLoggingLevel.Verbose, Context);
            }
            catch (OperationCanceledException) {}
            catch (IOException) {}
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
                Flush();
            }
        }

        private void SendHeaders(bool timeout)
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
            Request.InputStream.WriteAsync(buffer, 0, buffer.Length).Wait(Context.Listener.CancellationToken);
            buffer = default(byte[]);
            SentHeaders = true;
        }

        private void SendBody(bool timeout)
        {
            if (SentBody || SseEnabled || !Request.InputStream.CanWrite)
            {
                return;
            }

            // stream response output
            if (!timeout && OutputStream.Length > 0)
            {
                OutputStream.WriteTo(Request.InputStream);
            }

            SentBody = true;
        }

        public void Flush()
        {
            if (Request.InputStream.CanWrite)
            {
                Request.InputStream.Flush();
            }
        }

        public string SetSseConnection(PodeSseScope scope, string clientId, string name, string group, int retry, bool allowAllOrigins)
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
            Send();
            SendSseRetry(retry);
            SendSseEvent("pode.open", $"{{\"clientId\":\"{clientId}\",\"group\":\"{group}\",\"name\":\"{name}\"}}");

            // if global, cache connection in listener
            if (scope == PodeSseScope.Global)
            {
                Context.Listener.AddSseConnection(new PodeServerEvent(Context, name, group, clientId));
            }

            // return clientId
            return clientId;
        }

        public void CloseSseConnection()
        {
            SendSseEvent("pode.close", string.Empty);
        }

        public void SendSseEvent(string eventType, string data, string id = null)
        {
            if (!string.IsNullOrEmpty(id))
            {
                WriteLine($"id: {id}");
            }

            if (!string.IsNullOrEmpty(eventType))
            {
                WriteLine($"event: {eventType}");
            }

            WriteLine($"data: {data}{PodeHelpers.NEW_LINE}", true);
        }

        public void SendSseRetry(int retry)
        {
            if (retry <= 0)
            {
                return;
            }

            WriteLine($"retry: {retry}", true);
        }

        public void SendSignal(PodeServerSignal signal)
        {
            if (!string.IsNullOrEmpty(signal.Value))
            {
                Write(signal.Value);
            }
        }

        public void Write(string message, bool flush = false)
        {
            // simple messages
            if (!Context.IsWebSocket)
            {
                Write(Encoding.GetBytes(message), flush);
            }

            // web socket message
            else
            {
                WriteFrame(message, PodeWsOpCode.Text, flush);
            }
        }

        public void WriteFrame(string message, PodeWsOpCode opCode = PodeWsOpCode.Text, bool flush = false)
        {
            if (IsDisposed)
            {
                return;
            }

            var msgBytes = Encoding.GetBytes(message);
            var buffer = new List<byte>() { (byte)((byte)0x80 | (byte)opCode) };

            if (msgBytes.Length < 126)
            {
                buffer.Add((byte)((byte)0x00 | (byte)msgBytes.Length));
            }
            else if (msgBytes.Length <= UInt16.MaxValue)
            {
                buffer.Add((byte)((byte)0x00 | (byte)126));
                buffer.Add((byte)((msgBytes.Length >> 8) & (byte)255));
                buffer.Add((byte)(msgBytes.Length & (byte)255));
            }
            else
            {
                buffer.Add((byte)((byte)0x00 | (byte)127));
                buffer.Add((byte)((msgBytes.Length >> 56) & (byte)255));
                buffer.Add((byte)((msgBytes.Length >> 48) & (byte)255));
                buffer.Add((byte)((msgBytes.Length >> 40) & (byte)255));
                buffer.Add((byte)((msgBytes.Length >> 32) & (byte)255));
                buffer.Add((byte)((msgBytes.Length >> 24) & (byte)255));
                buffer.Add((byte)((msgBytes.Length >> 16) & (byte)255));
                buffer.Add((byte)((msgBytes.Length >> 8) & (byte)255));
                buffer.Add((byte)(msgBytes.Length & (byte)255));
            }

            buffer.AddRange(msgBytes);
            Write(buffer.ToArray(), flush);
        }

        public void WriteLine(string message, bool flush = false)
        {
            Write(Encoding.GetBytes($"{message}{PodeHelpers.NEW_LINE}"), flush);
        }

        public void Write(byte[] buffer, bool flush = false)
        {
            if (Request.IsDisposed || !Request.InputStream.CanWrite)
            {
                return;
            }

            try
            {
                Request.InputStream.WriteAsync(buffer, 0, buffer.Length).Wait(Context.Listener.CancellationToken);

                if (flush)
                {
                    Flush();
                }
            }
            catch (OperationCanceledException) {}
            catch (IOException) {}
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
                    ContentLength64 = (OutputStream.Length > 0 ? OutputStream.Length : 0);
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

        public void SetContext(PodeContext context)
        {
            Context = context;
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
                OutputStream = default(MemoryStream);
            }

            PodeHelpers.WriteErrorMessage($"Response disposed", Context.Listener, PodeLoggingLevel.Verbose, Context);
        }
    }
}