using System;
using System.Collections;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Text;

namespace Pode
{
    public class PodeResponse : IDisposable
    {
        public PodeResponseHeaders Headers { get; private set; }
        public int StatusCode = 200;
        public string StatusDescription = "OK";
        public bool SendChunked = false;
        public MemoryStream OutputStream { get; private set; }

        private PodeContext Context;
        private PodeRequest Request { get => Context.Request; }

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
            try
            {
                // start building the response message
                var message = HttpResponseLine;

                // default headers
                SetDefaultHeaders();

                // write the response headers
                message += BuildHeaders(Headers);

                // stream response output
                var buffer = Encoding.GetBytes(message);
                Request.InputStream.WriteAsync(buffer, 0, buffer.Length).Wait(Context.Listener.CancellationToken);

                if (OutputStream.Length > 0)
                {
                    OutputStream.WriteTo(Request.InputStream);
                }
            }
            catch (OperationCanceledException) {}
            catch (IOException) {}
            catch (Exception ex)
            {
                PodeHelpers.WriteException(ex);
                throw;
            }
            finally
            {
                Request.InputStream.Flush();
            }
        }

        public void SendSignal(PodeServerSignal signal)
        {
            Write(signal.Value);
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
            var msgBytes = Encoding.GetBytes($"{message}{PodeHelpers.NEW_LINE}");
            Write(msgBytes, flush);
        }

        public void Write(byte[] buffer, bool flush = false)
        {
            try
            {
                Request.InputStream.WriteAsync(buffer, 0, buffer.Length).Wait(Context.Listener.CancellationToken);

                if (flush)
                {
                    Request.InputStream.Flush();
                }
            }
            catch (OperationCanceledException) {}
            catch (IOException) {}
            catch (Exception ex)
            {
                PodeHelpers.WriteException(ex);
                throw;
            }
        }

        private void SetDefaultHeaders()
        {
            // ensure content length
            if (ContentLength64 == 0)
            {
                ContentLength64 = (OutputStream.Length > 0 ? OutputStream.Length : 0);
            }

            // set the date
            if (Headers.ContainsKey("Date"))
            {
                Headers.Remove("Date");
            }

            Headers.Add("Date", DateTime.UtcNow.ToString("r", CultureInfo.InvariantCulture));

            // set the server
            if (!Headers.ContainsKey("Server"))
            {
                Headers.Add("Server", "Pode");
            }

            // set context/socket ID
            if (Headers.ContainsKey("X-Pode-ContextId"))
            {
                Headers.Remove("X-Pode-ContextId");
            }

            Headers.Add("X-Pode-ContextId", Context.ID);

            // close the connection, only if request didn't specify keep-alive
            if (!Context.IsKeepAlive && !Context.IsWebSocket)
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
            if (headers.Count == 0)
            {
                return PodeHelpers.NEW_LINE;
            }

            var str = string.Empty;

            foreach (var key in headers.Keys)
            {
                var values = headers.Get(key);
                foreach (var value in values)
                {
                    str += $"{key}: {value}{PodeHelpers.NEW_LINE}";
                }
            }

            str += PodeHelpers.NEW_LINE;
            return str;
        }

        public void SetContext(PodeContext context)
        {
            Context = context;
        }

        public void Dispose()
        {
            if (OutputStream != default(MemoryStream))
            {
                Console.WriteLine("Output Disposed");
                OutputStream.Dispose();
            }
        }
    }
}