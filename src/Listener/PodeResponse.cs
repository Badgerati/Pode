using System;
using System.Collections;
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
        public MemoryStream OutputStream { get; private set; }

        private PodeRequest Request;

        public long ContentLength64
        {
            get { return long.Parse($"{Headers["Content-Length"]}"); }
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
            get { return $"{Headers["Content-Type"]}"; }
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

        private static UTF8Encoding Encoding = new UTF8Encoding();

        public PodeResponse(PodeRequest request)
        {
            Request = request;
            Headers = new Hashtable();
            OutputStream = new MemoryStream();
        }

        public void Send()
        {
            try
            {
                var newline = "\r\n";
                var message = $"{Request.Protocol} {StatusCode} {StatusDescription}{newline}";

                // default headers
                ForceDefaultHeaders();

                // write the response headers
                if (Headers.Count > 0)
                {
                    foreach (var key in Headers.Keys)
                    {
                        if (Headers[key] is object[])
                        {
                            foreach (var value in (object[])Headers[key])
                            {
                                message += $"{key}: {value}{newline}";
                            }
                        }
                        else
                        {
                            message += $"{key}: {Headers[key]}{newline}";
                        }
                    }
                }

                message += newline;

                // stream response output
                var buffer = Encoding.GetBytes(message);
                Request.InputStream.WriteAsync(buffer, 0, buffer.Length).Wait();
                OutputStream.WriteTo(Request.InputStream);
                Request.InputStream.Flush();
            }
            catch (IOException) { }
            catch (Exception ex)
            {
                Console.WriteLine(ex.Message);
                Console.WriteLine(ex.StackTrace);
                throw;
            }
            finally
            {
                Request.InputStream.Flush();
            }
        }

        //TODO:
        public void UpgradeSocket()
        {
            //websocket
        }

        private void ForceDefaultHeaders()
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

        public void Dispose()
        {
            if (OutputStream != default(MemoryStream))
            {
                OutputStream.Dispose();
            }
        }
    }
}