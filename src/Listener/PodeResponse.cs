using System;
using System.Collections;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Net.Http;
using System.Security.Cryptography;
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
        private PodeListener Listener { get => Context.Listener; }

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
                // skip this for web sockets
                if (Request.IsWebSocket)
                {
                    return;
                }

                // start building the response message
                var message = HttpResponseLine;

                // default headers
                SetDefaultHeaders();

                // write the response headers
                message += BuildHeaders(Headers);

                // stream response output
                var buffer = Encoding.GetBytes(message);
                Request.InputStream.WriteAsync(buffer, 0, buffer.Length).Wait();
                OutputStream.WriteTo(Request.InputStream);
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

        public void Write(string message)
        {
            var msgBytes = Encoding.GetBytes(message);

            // simple messages
            if (!Request.IsWebSocket)
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
                Request.InputStream.WriteAsync(buffer, 0, buffer.Length).Wait();
            }
            catch (IOException) { }
            catch (Exception ex)
            {
                PodeHelpers.WriteException(ex);
                throw;
            }
        }

        public void UpgradeWebSocket(string clientId)
        {
            //websocket
            if (!Request.IsWebSocket)
            {
                throw new HttpRequestException("Cannot upgrade a non-websocket request");
            }

            // set the status of the response
            StatusCode = 101;
            StatusDescription = "Switching Protocols";

            // get the socket key from the request
            var socketKey = $"{Request.Headers["Sec-WebSocket-Key"]}".Trim();

            // make the socket accept hash
            var crypto = SHA1.Create();
            var socketHash = Convert.ToBase64String(crypto.ComputeHash(System.Text.Encoding.UTF8.GetBytes($"{socketKey}{PodeHelpers.WEB_SOCKET_MAGIC_KEY}")));

            // compile the headers
            var headers = new Hashtable();
            headers.Add("Connection", "Upgrade");
            headers.Add("Upgrade", "websocket");
            headers.Add("Sec-WebSocket-Accept", socketHash);

            if (!string.IsNullOrWhiteSpace(clientId))
            {
                headers.Add("X-Pode-ClientId", clientId);
            }

            // build the message
            var message = HttpResponseLine;

            // add the headers
            message += BuildHeaders(headers);

            // stream response output (but do not close)
            var buffer = Encoding.GetBytes(message);
            Request.InputStream.WriteAsync(buffer, 0, buffer.Length).Wait();

            // add open web socket to listener
            lock (Listener.WebSockets)
            {
                var websocket = new PodeWebSocket(Context, Request.Url.AbsolutePath, clientId);

                if (Listener.WebSockets.ContainsKey(clientId))
                {
                    Listener.WebSockets[clientId] = websocket;
                }
                else
                {
                    Listener.WebSockets.Add(clientId, websocket);
                }
            }
        }

        private void SetDefaultHeaders()
        {
            // ensure content length
            if (ContentLength64 == 0 && OutputStream.Length > 0)
            {
                ContentLength64 = OutputStream.Length;
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

            // close the connection (TODO: implement keep-alive)
            if (Headers.ContainsKey("Connection"))
            {
                Headers.Remove("Connection");
            }

            Headers.Add("Connection", "close");
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