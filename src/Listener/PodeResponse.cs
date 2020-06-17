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
        public Hashtable Headers { get; private set; }
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
                if (Headers.ContainsKey("Content-Length"))
                {
                    Headers["Content-Length"] = value;
                }
                else
                {
                    Headers.Add("Content-Length", value);
                }
            }
        }

        public string ContentType
        {
            get => $"{Headers["Content-Type"]}";
            set
            {
                if (Headers.ContainsKey("Content-Type"))
                {
                    Headers["Content-Type"] = value;
                }
                else
                {
                    Headers.Add("Content-Type", value);
                }
            }
        }

        public string HttpResponseLine
        {
            get => $"{Request.Protocol} {StatusCode} {StatusDescription}{PodeHelpers.NEW_LINE}";
        }

        private static UTF8Encoding Encoding = new UTF8Encoding();

        public PodeResponse()
        {
            Headers = new Hashtable();
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
            catch (IOException) { }
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

        public void SendSignal(PodeSignal signal)
        {
            Write(signal.Value);
        }

        public void Write(string message)
        {
            var msgBytes = Encoding.GetBytes(message);

            // simple messages
            if (!Context.IsWebSocket)
            {
                Write(msgBytes);
                return;
            }

            // web socket message
            var buffer = new List<byte>() { (byte)((byte)0x80 | (byte)1) };

            var lengthByte = (byte)(msgBytes.Length < 126
                ? msgBytes.Length
                : (msgBytes.Length <= UInt16.MaxValue ? 126 : 127));

            buffer.Add((byte)((byte)0x00 | (byte)lengthByte));
            buffer.AddRange(msgBytes);

            Write(buffer.ToArray());
        }

        public void Write(byte[] buffer)
        {
            try
            {
                Request.InputStream.WriteAsync(buffer, 0, buffer.Length).Wait(Context.Listener.CancellationToken);
            }
            catch (IOException) { }
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

        private string BuildHeaders(Hashtable headers)
        {
            if (headers.Count == 0)
            {
                return PodeHelpers.NEW_LINE;
            }

            var str = string.Empty;

            foreach (var key in headers.Keys)
            {
                if (headers[key] is object[])
                {
                    foreach (var value in (object[])headers[key])
                    {
                        str += $"{key}: {value}{PodeHelpers.NEW_LINE}";
                    }
                }
                else
                {
                    str += $"{key}: {headers[key]}{PodeHelpers.NEW_LINE}";
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
                OutputStream.Dispose();
            }
        }
    }
}