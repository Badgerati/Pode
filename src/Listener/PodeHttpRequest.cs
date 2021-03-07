using System;
using System.Collections;
using System.Collections.Generic;
using System.Collections.Specialized;
using System.Net.Http;
using System.Net.Sockets;
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
        public int ContentLength { get; private set; }
        public Encoding ContentEncoding { get; private set; }
        public string TransferEncoding { get; private set; }
        public string UserAgent { get; private set; }
        public string UrlReferrer { get; private set; }
        public Uri Url { get; private set; }
        public Hashtable Headers { get; private set; }
        public string Body { get; private set; }
        public byte[] RawBody { get; private set; }
        public string Host { get; private set; }
        public bool AwaitingBody { get; private set; }
        public PodeForm Form { get; private set; }

        private bool IsRequestLineValid { get; set; }

        private bool _isWebSocket = false;
        public bool IsWebSocket
        {
            get => _isWebSocket;
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

        protected override bool ValidateInput(byte[] bytes)
        {
            // we need more bytes!
            if (bytes.Length == 0)
            {
                return false;
            }

            // wait until we have the rest of the payload
            if (AwaitingBody)
            {
                return (bytes.Length >= (ContentLength - RawBody.Length));
            }

            var lf = (byte)10;
            var previousIndex = -1;
            var index = Array.IndexOf(bytes, lf);

            // do we have a request line yet?
            if (index == -1)
            {
                return false;
            }

            // is the request line valid?
            if (!IsRequestLineValid)
            {
                var reqLine = Encoding.GetString(bytes, 0, index).Trim();
                var reqMeta = Regex.Split(reqLine, "\\s+");
                if (reqMeta.Length != 3)
                {
                    throw new HttpRequestException($"Invalid request line: {reqLine} [{reqMeta.Length}]");
                }

                IsRequestLineValid = true;
            }

            // check if we have all the headers
            while (true)
            {
                previousIndex = index;
                index = Array.IndexOf(bytes, lf, index + 1);

                if (index - previousIndex <= 2)
                {
                    if (index - previousIndex == 1)
                    {
                        break;
                    }

                    if (bytes[previousIndex + 1] == (byte)13)
                    {
                        break;
                    }
                }

                if (index == bytes.Length - 1)
                {
                    break;
                }

                if (index == -1)
                {
                    return false;
                }
            }

            // we're valid!
            IsRequestLineValid = false;
            return true;
        }

        protected override bool Parse(byte[] bytes)
        {
            // if there are no bytes, return (0 bytes read means we can close the socket)
            if (bytes.Length == 0)
            {
                HttpMethod = string.Empty;
                return true;
            }

            // get the raw string for headers
            var content = Encoding.GetString(bytes, 0, bytes.Length);

            // new line char, and req lines
            var newline = (content.Contains(PodeHelpers.NEW_LINE) ? PodeHelpers.NEW_LINE : PodeHelpers.NEW_LINE_UNIX);
            var reqLines = content.Split(new string[] { newline }, StringSplitOptions.None);
            content = string.Empty;

            // parse the headers, unless we're waiting for the body
            var bodyIndex = 0;
            if (!AwaitingBody)
            {
                bodyIndex = ParseHeaders(reqLines, newline);
            }

            // parse the body
            ParseBody(bytes, reqLines, newline, bodyIndex);
            AwaitingBody = (ContentLength > 0 && RawBody.Length < ContentLength);

            // cleanup
            reqLines = default(string[]);
            return (!AwaitingBody);
        }

        private int ParseHeaders(string[] reqLines, string newline)
        {
            // reset raw body
            RawBody = default(byte[]);

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
            Headers = new Hashtable(StringComparer.InvariantCultureIgnoreCase);
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

            // build required URI details
            var _proto = (IsSsl ? "https" : "http");
            Host = $"{Headers["Host"]}";
            Url = new Uri($"{_proto}://{Host}{reqQuery}");

            // check the host header
            if (!Context.PodeSocket.CheckHostname(Host))
            {
                throw new HttpRequestException($"Invalid request Host: {Host}");
            }

            // get the content length
            var strContentLength = $"{Headers["Content-Length"]}";
            if (string.IsNullOrWhiteSpace(strContentLength))
            {
                strContentLength = "0";
            }

            ContentLength = int.Parse(strContentLength);

            // set the transfer encoding
            TransferEncoding = $"{Headers["Transfer-Encoding"]}";

            // set other default headers
            UrlReferrer = $"{Headers["Referer"]}";
            UserAgent = $"{Headers["User-Agent"]}";
            ContentType = $"{Headers["Content-Type"]}";

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

            // is web-socket?
            _isWebSocket = Headers.ContainsKey("Sec-WebSocket-Key");

            // keep-alive?
            IsKeepAlive = (_isWebSocket ||
                (Headers.ContainsKey("Connection")
                    && $"{Headers["Connection"]}".Equals("keep-alive", StringComparison.InvariantCultureIgnoreCase)));

            // return index where body starts in req
            return bodyIndex;
        }

        private void ParseBody(byte[] bytes, string[] reqLines, string newline, int bodyIndex)
        {
            var isChunked = (!string.IsNullOrWhiteSpace(TransferEncoding) && TransferEncoding.Contains("chunked"));

            // if chunked, and we have a content-length, fail
            if (isChunked && ContentLength > 0)
            {
                throw new HttpRequestException($"Cannot supply a Content-Length and a chunked Transfer-Encoding");
            }

            // get the start index for raw bytes
            var start = reqLines.Take(bodyIndex).Sum(x => x.Length) + ((bodyIndex) * newline.Length);
            var hasBody = (RawBody != default(byte[]));

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
                    c_hexBytes = PodeHelpers.Slice(bytes, start, c_index - start);

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
                    c_rawBytes.AddRange(PodeHelpers.Slice(bytes, start, c_length));

                    // skip bytes for ending newline, and set new start
                    start = (start + c_length - 1) + newline.Length + 1;
                }

                RawBody = hasBody
                    ? PodeHelpers.Concat(RawBody, c_rawBytes.ToArray())
                    : c_rawBytes.ToArray();
            }

            // else use content length
            else if (ContentLength > 0)
            {
                RawBody = hasBody
                    ? PodeHelpers.Concat(RawBody, PodeHelpers.Slice(bytes, start, ContentLength))
                    : PodeHelpers.Slice(bytes, start, ContentLength);
            }

            // else just read all
            else
            {
                RawBody = hasBody
                    ? PodeHelpers.Concat(RawBody, PodeHelpers.Slice(bytes, start))
                    : PodeHelpers.Slice(bytes, start);
            }

            // set the body
            Body = Encoding.GetString(RawBody);
        }

        public void ParseFormData()
        {
            Form = new PodeForm();

            if (RawBody.Length == 0)
            {
                return;
            }

            var lines = PodeHelpers.ConvertToByteLines(RawBody);

            var parts = ContentType.Split(';');
            var boundaryStart = $"--{parts[1].Split('=')[1].Trim()}";
            var boundaryEnd = $"{boundaryStart}--";

            var boundaryLineIndexes = new List<int>();
            for (var i = 0; i < lines.Count; i++)
            {
                if (IsLineBoundary(lines[i], boundaryStart) || IsLineBoundary(lines[i], boundaryEnd))
                {
                    boundaryLineIndexes.Add(i);
                }
            }

            var boundaryLineIndex = 0;
            var disposition = string.Empty;
            var fields = new Dictionary<string, string>();

            for (var i = 0; i < (boundaryLineIndexes.Count - 1); i++)
            {
                fields.Clear();

                boundaryLineIndex = boundaryLineIndexes[i];
                disposition = ContentEncoding.GetString(lines[boundaryLineIndex + 1]).Trim(PodeHelpers.NEW_LINE_ARRAY);

                foreach (var line in disposition.Split(';'))
                {
                    var atoms = line.Split('=');
                    if (atoms.Length == 2)
                    {
                        fields.Add(atoms[0].Trim(), atoms[1].Trim(' ', '"'));
                    }
                }

                if (!fields.ContainsKey("filename"))
                {
                    Form.Data.Add(new PodeFormData(fields["name"], ContentEncoding.GetString(lines[boundaryLineIndex + 3]).Trim(PodeHelpers.NEW_LINE_ARRAY)));
                }

                if (fields.ContainsKey("filename"))
                {
                    Form.Data.Add(new PodeFormData(fields["name"], fields["filename"]));

                    if (!string.IsNullOrWhiteSpace(fields["filename"]))
                    {
                        var contentType = ContentEncoding.GetString(lines[boundaryLineIndex + 2]).Trim(PodeHelpers.NEW_LINE_ARRAY);

                        var fileBytes = default(byte[]);
                        for (var j = (boundaryLineIndex + 4); j <= (boundaryLineIndexes[i + 1] - 1); j++)
                        {
                            fileBytes = PodeHelpers.Concat(fileBytes, lines[j]);
                        }

                        var fileBytesLength = fileBytes.Length - 1;
                        if (fileBytes[fileBytesLength] == PodeHelpers.NEW_LINE_BYTE)
                        {
                            fileBytesLength--;
                        }

                        if (fileBytes[fileBytesLength] == PodeHelpers.CARRIAGE_RETURN_BYTE)
                        {
                            fileBytesLength--;
                        }

                        fileBytes = PodeHelpers.Slice(fileBytes, 0, fileBytesLength + 1);

                        Form.Files.Add(new PodeFormFile(fields["filename"], fileBytes, fields["name"], contentType.Split(':')[1].Trim()));
                    }
                }
            }
        }

        private bool IsLineBoundary(byte[] bytes, string boundary)
        {
            if (bytes.Length == 0)
            {
                return false;
            }

            if (bytes[0] != PodeHelpers.DASH_BYTE && bytes[bytes.Length - 1] != PodeHelpers.DASH_BYTE)
            {
                return false;
            }

            if ((bytes.Length - boundary.Length) > 3)
            {
                return false;
            }

            return (ContentEncoding.GetString(bytes).StartsWith(boundary));
        }

        public override void Dispose()
        {
            RawBody = default(byte[]);
            Body = string.Empty;
            base.Dispose();
        }
    }
}