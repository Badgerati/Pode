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
    public class PodeHttpRequest : PodeRequest
    {
        public string HttpMethod { get; private set; }
        public NameValueCollection QueryString { get; private set; }
        public string Protocol { get; private set; }
        public string ProtocolVersion { get; private set; }
        public string ContentType { get; private set; }
        public Encoding ContentEncoding { get; private set; }
        public string UserAgent { get; private set; }
        public string UrlReferrer { get; private set; }
        public Uri Url { get; private set; }
        public Hashtable Headers { get; private set; }
        public string Body { get; private set; }
        public byte[] RawBody { get; private set; }
        public string Host { get; private set; }
        public PodeWebSocket WebSocket { get; set; }

        private bool _isWebSocket = false;
        public bool IsWebSocket
        {
            get => (_isWebSocket || WebSocket != default(PodeWebSocket));
        }

        public override bool CloseImmediately
        {
            get => (string.IsNullOrWhiteSpace(HttpMethod)
                || (IsWebSocket && !HttpMethod.Equals("GET", StringComparison.InvariantCultureIgnoreCase)));
        }

        public PodeHttpRequest(Socket socket)
            : base(socket)
        {
            Protocol = "HTTP/1.1";
        }

        public PodeClientSignal NewClientSignal()
        {
            return new PodeClientSignal(WebSocket, Body);
        }

        protected void ParseWebSocket(byte[] bytes)
        {
            var dataLength = bytes[1] - 128;
            var offset = 0;
            //var totalLength = 0;

            if (dataLength < 126)
            {
                offset = 2;
                //totalLength = dataLength + 6;
            }
            else if (dataLength == 126)
            {
                dataLength = BitConverter.ToInt16(new byte[] { bytes[3], bytes[2] }, 0);
                offset = 4;
                //totalLength = dataLength + 8;
            }
            else
            {
                dataLength = (int)BitConverter.ToInt64(new byte[] { bytes[9], bytes[8], bytes[7], bytes[6], bytes[5], bytes[4], bytes[3], bytes[2] }, 0);
                offset = 10;
                //totalLength = dataLength + 14;
            }

            var key = new byte[] { bytes[offset], bytes[offset + 1], bytes[offset + 2], bytes[offset + 3] };
            offset += 4;

            //var count = 0;
            var decoded = new byte[dataLength];
            // for (var i = offset; i < totalLength; i++)
            // {
            //     bytes[i] = (byte)(bytes[i] ^ key[count % 4]);
            //     count++;
            // }
            for (var i = 0; i < dataLength; ++i)
            {
                decoded[i] = (byte)(bytes[offset + i] ^ key[i % 4]);
            }

            RawBody = bytes;
            //Body = Encoding.GetString(bytes, offset, dataLength);
            Body = Encoding.GetString(decoded);
            Console.WriteLine(Body);


            //TODO: here, or in a PodeWsRequest class?
            // https://developer.mozilla.org/en-US/docs/Web/API/WebSockets_API/Writing_WebSocket_server
            // https://stackoverflow.com/questions/10200910/creating-a-hello-world-websocket-example
        }

        protected override void Parse(byte[] bytes)
        {
            // if there are no bytes, return (0 bytes read means we can close the socket)
            if (bytes.Length == 0)
            {
                HttpMethod = string.Empty;
                return;
            }

            // check if websocket, and parse
            if (IsWebSocket)
            {
                ParseWebSocket(bytes);
                return;
            }

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
            else
            {
                QueryString = default(NameValueCollection);
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

            // is web-socket?
            _isWebSocket = Headers.ContainsKey("Sec-WebSocket-Key");

            // keep-alive?
            IsKeepAlive = (_isWebSocket ||
                (Headers.ContainsKey("Connection")
                    && $"{Headers["Connection"]}".Equals("keep-alive", StringComparison.InvariantCultureIgnoreCase)));

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
    }
}