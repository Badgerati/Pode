using System;
using System.Collections;
using System.Collections.Generic;
using System.Collections.Specialized;
using System.IO;
using System.Net;
using System.Net.Http;
using System.Net.Security;
using System.Net.Sockets;
using System.Security.Authentication;
using System.Security.Cryptography.X509Certificates;
using System.Text;
using System.Text.RegularExpressions;
using System.Web;
using System.Linq;

namespace Pode
{
    public class PodeRequest : IDisposable
    {
        public string HttpMethod { get; private set; }
        public NameValueCollection QueryString { get; private set; }
        public string Protocol { get; private set; }
        public string ProtocolVersion { get; private set; }
        public EndPoint RemoteEndPoint { get; private set; }
        public string ContentType { get; private set; }
        public Encoding ContentEncoding { get; private set; }
        public string UserAgent { get; private set; }
        public string UrlReferrer { get; private set; }
        public Uri Url { get; private set; }
        public Hashtable Headers { get; private set; }
        public string Body { get; private set; }
        public byte[] RawBody { get; private set; }
        public string Host { get; private set; }
        public bool IsSsl { get; private set; }

        public Stream InputStream { get; private set; }
        public HttpRequestException Error { get; private set; }

        public Socket Socket;
        private PodeContext Context;
        private static UTF8Encoding Encoding = new UTF8Encoding();

        public PodeRequest(Socket socket)
        {
            Socket = socket;
            RemoteEndPoint = socket.RemoteEndPoint;
        }

        public void Open(X509Certificate certificate, SslProtocols protocols)
        {
            // ssl or not?
            IsSsl = (certificate != default(X509Certificate));

            // open the socket's stream
            var stream = new NetworkStream(Socket, true);
            if (!IsSsl)
            {
                // if not ssl, use the main network stream
                InputStream = stream;
                return;
            }

            // otherwise, convert the stream to an ssl stream
            var ssl = new SslStream(stream, false, new RemoteCertificateValidationCallback(ValidateCertificateCallback));
            ssl.AuthenticateAsServer(certificate, false, protocols, false);
            InputStream = ssl;
        }

        private bool ValidateCertificateCallback(object sender, X509Certificate certificate, X509Chain chain, SslPolicyErrors sslPolicyErrors)
        {
            if (certificate == default(X509Certificate))
            {
                return true;
            }

            return (sslPolicyErrors != SslPolicyErrors.None);
        }

        public void Receive()
        {
            try
            {
                Error = default(HttpRequestException);

                var allBytes = new List<byte>();
                if (IsSsl)
                {
                    try
                    {
                        // the stream gets reset on ssl upgrade
                        Socket.Receive(new byte[0]);
                    }
                    catch
                    {
                        var err = new HttpRequestException();
                        err.Data.Add("PodeStatusCode", 408);
                        throw err;
                    }
                }

                while (Socket.Available > 0)
                {
                    var bytes = new byte[Socket.Available];
                    InputStream.ReadAsync(bytes, 0, Socket.Available).Wait();
                    allBytes.AddRange(bytes);
                }

                Parse(allBytes.ToArray());
            }
            catch (HttpRequestException httpex)
            {
                Error = httpex;
            }
            catch (Exception ex)
            {
                Error = new HttpRequestException(ex.Message, ex);
                Error.Data.Add("PodeStatusCode", 400);
            }
        }

        private void Parse(byte[] bytes)
        {
            // get the raw string for headers
            var content = Encoding.GetString(bytes, 0, bytes.Length);

            // split the lines on newline
            var newline = (content.Contains(PodeHelpers.NEW_LINE) ? PodeHelpers.NEW_LINE : PodeHelpers.NEW_LINE_UNIX);
            var reqLines = content.Split(new string[] { newline }, StringSplitOptions.None);

            // first line is method/url
            var reqMeta = Regex.Split(reqLines[0].Trim(), "\\s+");
            if (reqMeta.Length != 3)
            {
                throw new HttpRequestException($"Invalid request line: {reqLines[0]} [{reqMeta.Length}]");
            }

            // http method
            HttpMethod = reqMeta[0].Trim();
            if (Array.IndexOf(PodeHelpers.HTTP_METHODS, HttpMethod) == -1)
            {
                throw new HttpRequestException($"Invalid request HTTP method: {HttpMethod}");
            }

            // query string
            var reqQuery = reqMeta[1].Trim();
            if (!string.IsNullOrWhiteSpace(reqQuery))
            {
                var qmIndex = reqQuery.IndexOf("?");
                QueryString = HttpUtility.ParseQueryString(qmIndex > 0 ? reqQuery.Substring(qmIndex) : reqQuery);
            }

            // http protocol version
            Protocol = (reqMeta[2] ?? "HTTP/1.1").Trim();
            if (!Protocol.StartsWith("HTTP/"))
            {
                throw new HttpRequestException($"Invalid request version: {Protocol}");
            }

            ProtocolVersion = Regex.Split(Protocol, "/")[1];

            // headers
            Headers = new Hashtable();

            var bodyIndex = 0;
            var h_index = 0;
            var h_line = string.Empty;
            var h_name = string.Empty;
            var h_value = string.Empty;

            for (var i = 1; i <= reqLines.Length - 1; i++)
            {
                h_line = reqLines[i].Trim();
                if (string.IsNullOrWhiteSpace(h_line))
                {
                    bodyIndex = i + 1;
                    break;
                }

                h_index = h_line.IndexOf(":");
                h_name = h_line.Substring(0, h_index).Trim();
                h_value = h_line.Substring(h_index + 1).Trim();
                Headers.Add(h_name, h_value);
            }

            // get the content length
            var strContentLength = $"{Headers["Content-Length"]}";
            if (string.IsNullOrWhiteSpace(strContentLength))
            {
                strContentLength = "0";
            }

            var contentLength = int.Parse(strContentLength);

            // get transfer encoding, see if chunked
            var transferEncoding = $"{Headers["Transfer-Encoding"]}";
            var isChunked = (!string.IsNullOrWhiteSpace(transferEncoding) && transferEncoding.Contains("chunked"));

            // if chunked, and we have a content-length, fail
            if (isChunked && contentLength > 0)
            {
                throw new HttpRequestException($"Cannot supply a Content-Length and a chunked Transfer-Encoding");
            }

            // set the body
            Body = string.Join(newline, reqLines.Skip(bodyIndex));

            // get the start index for raw bytes
            var start = reqLines.Take(bodyIndex).Sum(x => x.Length) + ((bodyIndex) * newline.Length);

            // parse for chunked
            if (isChunked)
            {
                var c_length = -1;
                var c_index = 0;
                var c_hexBytes = default(IEnumerable<byte>);
                var c_rawBytes = new List<byte>();
                var c_hex = string.Empty;

                while (c_length != 0)
                {
                    // get index of newline char, read start>index bytes as HEX for length
                    c_index = Array.IndexOf(bytes, (byte)newline[0], start);
                    c_hexBytes = bytes.Skip(start).Take(c_index - start);

                    c_hex = string.Empty;
                    foreach (var b in c_hexBytes)
                    {
                        c_hex += (char)b;
                    }

                    // if no length, continue
                    c_length = Convert.ToInt32(c_hex, 16);
                    if (c_length == 0)
                    {
                        continue;
                    }

                    // read those X hex bytes from (newline index + newline length)
                    start = c_index + newline.Length;
                    c_rawBytes.AddRange(bytes.Skip(start).Take(c_length));

                    // skip bytes for ending newline, and set new start
                    start = (start + c_length - 1) + newline.Length + 1;
                }

                RawBody = c_rawBytes.ToArray();
            }

            // else use content length
            else if (contentLength > 0)
            {
                RawBody = bytes.Skip(start).Take(contentLength).ToArray();
            }

            // else just read all
            else
            {
                RawBody = bytes.Skip(start).ToArray();
            }

            // set values from headers
            Host = $"{Headers["Host"]}";
            UrlReferrer = $"{Headers["Referer"]}";
            UserAgent = $"{Headers["User-Agent"]}";
            ContentType = $"{Headers["Content-Type"]}";
            //TODO: shouldnt transfer-encoding and accept-encoding be here?

            // set content encoding
            ContentEncoding = System.Text.Encoding.UTF8;
            if (!string.IsNullOrWhiteSpace(ContentType))
            {
                var atoms = ContentType.Split(';');
                foreach (var atom in atoms)
                {
                    if (atom.Trim().ToLowerInvariant().StartsWith("charset"))
                    {
                        ContentEncoding = System.Text.Encoding.GetEncoding((atom.Split('=')[1].Trim()));
                        break;
                    }
                }
            }

            // build required URI details
            var _proto = (IsSsl ? "https" : "http");
            Url = new Uri($"{_proto}://{Host}{reqQuery}");
        }

        public void SetContext(PodeContext context)
        {
            Context = context;
        }

        public void Dispose()
        {
            if (Socket != default(Socket))
            {
                PodeSocket.CloseSocket(Socket);
            }
        }
    }
}