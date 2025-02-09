using System;
using System.Collections;
using System.Collections.Generic;
using System.Net.Http;
using System.Net.Sockets;
using System.Text.RegularExpressions;
using System.Linq;
using System.Globalization;
using _Encoding = System.Text.Encoding;
using System.IO;
using System.Threading.Tasks;
using System.Threading;

namespace Pode
{
    public class PodeSmtpRequest : PodeRequest
    {
        public string ContentType { get; private set; }
        public string ContentEncoding { get; private set; }
        public string Boundary { get; private set; }
        public Hashtable Headers { get; private set; }
        public List<PodeSmtpAttachment> Attachments { get; private set; }
        public string Body { get; private set; }
        public byte[] RawBody { get; private set; }
        public string Subject { get; private set; }
        public bool IsUrgent { get; private set; }
        public string From { get; private set; }
        public IList<string> To { get; private set; }
        public PodeSmtpCommand Command { get; private set; }
        public PodeSmtpStartType StartType { get; private set; }

        public override bool CloseImmediately
        {
            get => Command == PodeSmtpCommand.None || Command == PodeSmtpCommand.Quit;
        }

        private bool _canProcess = false;
        public override bool IsProcessable
        {
            get => !CloseImmediately && _canProcess;
        }

        public PodeSmtpRequest(Socket socket, PodeSocket podeSocket, PodeContext context)
            : base(socket, podeSocket, context)
        {
            _canProcess = false;
            IsKeepAlive = true;
            Command = PodeSmtpCommand.None;
            To = new List<string>();
            Type = PodeProtocolType.Smtp;
        }

        private static bool IsCommand(string content, string command)
        {
            if (string.IsNullOrWhiteSpace(content))
            {
                return false;
            }

            return content.StartsWith(command, true, CultureInfo.InvariantCulture);
        }

        public async Task SendAck()
        {
            var ack = string.IsNullOrWhiteSpace(Context.PodeSocket.AcknowledgeMessage)
                ? $"{Context.PodeSocket.Hostname} -- Pode Proxy Server"
                : Context.PodeSocket.AcknowledgeMessage;

            await Context.Response.WriteLine($"220 {ack}", true).ConfigureAwait(false);
        }

        protected override bool ValidateInput(byte[] bytes)
        {
            // we need more bytes!
            if (bytes.Length == 0)
            {
                return false;
            }

            // for data, we need to wait till it ends with a '.<CR><LF>'
            if (Command == PodeSmtpCommand.Data)
            {
                if (bytes.Length < 3)
                {
                    return false;
                }

                return bytes[bytes.Length - 3] == PodeHelpers.PERIOD_BYTE
                    && bytes[bytes.Length - 2] == PodeHelpers.CARRIAGE_RETURN_BYTE
                    && bytes[bytes.Length - 1] == PodeHelpers.NEW_LINE_BYTE;
            }

            return true;
        }

        protected override async Task<bool> Parse(byte[] bytes, CancellationToken cancellationToken)
        {
            // if there are no bytes, return (0 bytes read means we can close the socket)
            if (bytes.Length == 0)
            {
                Command = PodeSmtpCommand.None;
                return true;
            }

            // get the raw string for headers
            var content = Encoding.GetString(bytes, 0, bytes.Length);

            // empty
            if (string.IsNullOrWhiteSpace(content))
            {
                Command = PodeSmtpCommand.None;
                await Context.Response.WriteLine("501 Invalid command received", true).ConfigureAwait(false);
                return true;
            }

            // quit
            if (IsCommand(content, "QUIT"))
            {
                Command = PodeSmtpCommand.Quit;
                await Context.Response.WriteLine("221 OK", true).ConfigureAwait(false);
                return true;
            }

            // ensure starttls is sent for explicit tls
            if (StartType == PodeSmtpStartType.Ehlo && TlsMode == PodeTlsMode.Explicit && !SslUpgraded && !IsCommand(content, "STARTTLS"))
            {
                Command = PodeSmtpCommand.None;
                await Context.Response.WriteLine("530 Must issue a STARTTLS command first", true).ConfigureAwait(false);
                return true;
            }

            // helo
            if (IsCommand(content, "HELO"))
            {
                Command = PodeSmtpCommand.Helo;
                StartType = PodeSmtpStartType.Helo;
                await Context.Response.WriteLine("250 OK", true).ConfigureAwait(false);
                return true;
            }

            // ehlo
            if (IsCommand(content, "EHLO"))
            {
                Command = PodeSmtpCommand.Ehlo;
                StartType = PodeSmtpStartType.Ehlo;
                await Context.Response.WriteLine($"250-{Context.PodeSocket.Hostname} hello there", true).ConfigureAwait(false);

                if (TlsMode == PodeTlsMode.Explicit && !SslUpgraded)
                {
                    await Context.Response.WriteLine("250-STARTTLS", true).ConfigureAwait(false);
                }

                await Context.Response.WriteLine("250 OK", true).ConfigureAwait(false);
                return true;
            }

            // starttls
            if (IsCommand(content, "STARTTLS"))
            {
                if (TlsMode != PodeTlsMode.Explicit)
                {
                    Command = PodeSmtpCommand.None;
                    await Context.Response.WriteLine("501 SMTP server not running on Explicit TLS for the STARTTLS command", true).ConfigureAwait(false);
                    return true;
                }

                Reset();
                Command = PodeSmtpCommand.StartTls;
                await Context.Response.WriteLine("220 Ready to start TLS").ConfigureAwait(false);
                await UpgradeToSSL(cancellationToken).ConfigureAwait(false);
                return true;
            }

            // reset
            if (IsCommand(content, "RSET"))
            {
                Reset();
                Command = PodeSmtpCommand.Reset;
                await Context.Response.WriteLine("250 OK", true).ConfigureAwait(false);
                return true;
            }

            // noop
            if (IsCommand(content, "NOOP"))
            {
                Command = PodeSmtpCommand.NoOp;
                await Context.Response.WriteLine("250 OK", true).ConfigureAwait(false);
                return true;
            }

            // to
            if (IsCommand(content, "RCPT TO"))
            {
                Command = PodeSmtpCommand.RcptTo;
                await Context.Response.WriteLine("250 OK", true).ConfigureAwait(false);
                To.Add(ParseEmail(content));
                return true;
            }

            // from
            if (IsCommand(content, "MAIL FROM"))
            {
                Command = PodeSmtpCommand.MailFrom;
                await Context.Response.WriteLine("250 OK", true).ConfigureAwait(false);
                From = ParseEmail(content);
                return true;
            }

            // data
            if (IsCommand(content, "DATA"))
            {
                Command = PodeSmtpCommand.Data;
                await Context.Response.WriteLine("354 Start mail input; end with <CR><LF>.<CR><LF>", true).ConfigureAwait(false);
                return true;
            }

            // check prior command
            switch (Command)
            {
                case PodeSmtpCommand.Data:
                    _canProcess = true;
                    await Context.Response.WriteLine("250 OK", true).ConfigureAwait(false);
                    RawBody = bytes;
                    Attachments = new List<PodeSmtpAttachment>();

                    // parse the headers
                    Headers = ParseHeaders(content);
                    Subject = Headers["Subject"]?.ToString();
                    IsUrgent = $"{Headers["Priority"]}".Equals("urgent", StringComparison.InvariantCultureIgnoreCase) || $"{Headers["Importance"]}".Equals("high", StringComparison.InvariantCultureIgnoreCase);
                    ContentEncoding = $"{Headers["Content-Transfer-Encoding"]}";

                    ContentType = $"{Headers["Content-Type"]}";
                    if (!string.IsNullOrEmpty(Boundary) && !ContentType.Contains("boundary="))
                    {
                        ContentType = ContentType.TrimEnd(';');
                        ContentType += $"; boundary={Boundary}";
                    }

                    // check if body is valid and parse, else error
                    if (IsBodyValid(content))
                    {
                        // parse the body
                        Body = ConvertBodyType(ConvertBodyEncoding(ParseBody(content), ContentEncoding), ContentType);

                        // if we have a boundary, get attachments/body
                        if (!string.IsNullOrWhiteSpace(Boundary))
                        {
                            ParseBoundary();
                        }
                    }
                    else
                    {
                        Command = PodeSmtpCommand.None;
                        await Context.Response.WriteLine("501 Invalid DATA received", true).ConfigureAwait(false);
                        return true;
                    }
                    break;

                default:
                    throw new PodeRequestException("Invalid SMTP command");
            }

            return true;
        }

        public void Reset()
        {
            PodeHelpers.WriteErrorMessage($"Request reset", Context.Listener, PodeLoggingLevel.Verbose, Context);

            _canProcess = false;
            Headers = new Hashtable(StringComparer.InvariantCultureIgnoreCase);
            From = string.Empty;
            To = new List<string>();
            Body = string.Empty;
            RawBody = default;
            Command = PodeSmtpCommand.None;
            ContentType = string.Empty;
            ContentEncoding = string.Empty;
            Subject = string.Empty;
            IsUrgent = false;
            StartType = PodeSmtpStartType.None;

            if (Attachments != default(List<PodeSmtpAttachment>))
            {
                foreach (var attachment in Attachments)
                {
                    attachment.Dispose();
                }
            }

            Attachments = new List<PodeSmtpAttachment>();
        }

        private static string ParseEmail(string value)
        {
            var parts = value.Split(':');
            if (parts.Length > 1)
            {
                return parts[1].Trim().Trim('<', '>', ' ');
            }

            return string.Empty;
        }

        private Hashtable ParseHeaders(string value)
        {
            var headers = new Hashtable(StringComparer.InvariantCultureIgnoreCase);

            var lines = value.Split(new string[] { PodeHelpers.NEW_LINE }, StringSplitOptions.None);
            var match = default(Match);
            var previousHeader = string.Empty;

            foreach (var line in lines)
            {
                if (string.IsNullOrWhiteSpace(line))
                {
                    break;
                }

                // header
                match = Regex.Match(line, "^(?<name>.*?)\\:\\s+(?<value>.*?)$");
                if (match.Success)
                {
                    previousHeader = match.Groups["name"].Value;
                    if (headers.ContainsKey(previousHeader))
                    {
                        if (!(headers[previousHeader] is List<object>))
                        {
                            headers[previousHeader] = new List<object>() { headers[previousHeader] };
                        }

                        ((List<object>)headers[previousHeader]).Add(match.Groups["value"].Value);
                    }
                    else
                    {
                        headers.Add(previousHeader, match.Groups["value"].Value);
                    }
                }
                else
                {
                    match = Regex.Match(line, "^(?<name>.*?)\\:\\s+");
                    if (!match.Success)
                    {
                        if (headers[previousHeader] is List<object>)
                        {
                            var values = (List<object>)headers[previousHeader];
                            values[values.Count - 1] += line;
                        }
                        else
                        {
                            headers[previousHeader] += line;
                        }
                    }
                }

                // boundary line
                match = Regex.Match(line, "^\\s*boundary=\"?(?<boundary>.+?)\"?$");
                if (match.Success)
                {
                    Boundary = match.Groups["boundary"].Value;
                }
            }

            return headers;
        }

        private static bool IsBodyValid(string value)
        {
            var lines = value.Split(new string[] { PodeHelpers.NEW_LINE }, StringSplitOptions.None);
            return Array.LastIndexOf(lines, ".") > -1;
        }

        private void ParseBoundary()
        {
            var lines = Body.Split(new string[] { PodeHelpers.NEW_LINE }, StringSplitOptions.None);
            var boundaryStart = $"--{Boundary}";
            var boundaryEnd = $"{boundaryStart}--";

            var boundaryLineIndexes = new List<int>();
            for (var i = 0; i < lines.Length; i++)
            {
                if (PodeForm.IsLineBoundary(lines[i], boundaryStart) || PodeForm.IsLineBoundary(lines[i], boundaryEnd))
                {
                    boundaryLineIndexes.Add(i);
                }
            }

            var boundaryIndex = 0;
            var nextBoundaryIndex = 0;

            for (var i = 0; i < (boundaryLineIndexes.Count - 1); i++)
            {
                boundaryIndex = boundaryLineIndexes[i];
                nextBoundaryIndex = boundaryLineIndexes[i + 1];

                // get the boundary headers
                var boundaryBody = string.Join(PodeHelpers.NEW_LINE, PodeHelpers.Subset(lines, boundaryIndex + 1, nextBoundaryIndex + 1));
                var headers = ParseHeaders(boundaryBody);

                var contentType = $"{headers["Content-Type"]}";
                var contentEncoding = $"{headers["Content-Transfer-Encoding"]}";

                // get the boundary
                var body = ParseBody(boundaryBody, Boundary);
                var bodyBytes = ConvertBodyEncoding(body, contentEncoding);

                // file or main body?
                var contentDisposition = $"{headers["Content-Disposition"]}";
                if (!string.IsNullOrEmpty(contentDisposition) && contentDisposition.ToLowerInvariant().Contains("attachment"))
                {
                    var match = Regex.Match(contentType, "name=(?<name>.+)");
                    var name = match.Groups["name"].Value.Trim('"');

                    var stream = new MemoryStream();
                    stream.Write(bodyBytes, 0, bodyBytes.Length);
                    var attachment = new PodeSmtpAttachment(name, stream, contentType, contentEncoding);
                    Attachments.Add(attachment);
                }
                else
                {
                    Body = ConvertBodyType(bodyBytes, contentType);
                }
            }
        }

        private static string ParseBody(string value, string boundary = null)
        {
            // split the message up
            var lines = value.Split(new string[] { PodeHelpers.NEW_LINE }, StringSplitOptions.None);

            // what's the end char?
            var useBoundary = !string.IsNullOrEmpty(boundary);
            var endChar = useBoundary ? $"--{boundary}" : ".";
            var trimCount = useBoundary ? 1 : 2;

            // get the index of the first blank line, and last dot
            var indexOfBlankLine = Array.IndexOf(lines, string.Empty);

            var indexOfLastDot = Array.LastIndexOf(lines, endChar);
            if (indexOfLastDot == -1 && useBoundary)
            {
                indexOfLastDot = Array.LastIndexOf(lines, $"{endChar}--");
            }

            // get the body
            var bodyLines = lines.Skip(indexOfBlankLine + 1).Take(indexOfLastDot - indexOfBlankLine - trimCount);
            var body = string.Join(PodeHelpers.NEW_LINE, bodyLines);

            // if there's no body, return
            if (indexOfLastDot == -1 || string.IsNullOrWhiteSpace(body))
            {
                return string.Empty;
            }

            return body;
        }

        private static byte[] ConvertBodyEncoding(string body, string contentEncoding)
        {
            switch (contentEncoding.ToLowerInvariant())
            {
                case "base64":
                    return Convert.FromBase64String(body);

                case "quoted-printable":
                    var match = default(Match);
                    while ((match = Regex.Match(body, "(?<code>=(?<hex>[0-9A-F]{2}))")).Success)
                    {
                        body = body.Replace(match.Groups["code"].Value, $"{(char)Convert.ToInt32(match.Groups["hex"].Value, 16)}");
                    }

                    return _Encoding.UTF8.GetBytes(body);

                default:
                    return _Encoding.UTF8.GetBytes(body);
            }
        }

        private static string ConvertBodyType(byte[] bytes, string contentType)
        {
            if (bytes == default(byte[]) || bytes.Length == 0)
            {
                return string.Empty;
            }

            contentType = contentType.ToLowerInvariant();

            // utf-7
            if (contentType.Contains("utf-7"))
            {
                return _Encoding.UTF7.GetString(bytes);
            }

            // utf-8
            else if (contentType.Contains("utf-8"))
            {
                return _Encoding.UTF8.GetString(bytes);
            }

            // utf-16
            else if (contentType.Contains("utf-16"))
            {
                return _Encoding.Unicode.GetString(bytes);
            }

            // utf-32
            else if (contentType.Contains("utf32"))
            {
                return _Encoding.UTF32.GetString(bytes);
            }

            // default (ascii)
            else
            {
                return _Encoding.ASCII.GetString(bytes);
            }
        }

        /// <summary>
        /// Dispose managed and unmanaged resources.
        /// </summary>
        /// <param name="disposing">Indicates if the method is called explicitly or by garbage collection.</param>
        protected override void Dispose(bool disposing)
        {
            if (IsDisposed) return;
            
            if (disposing)
            {
                // Custom cleanup logic for PodeSmtpRequest
                RawBody = default;
                Body = string.Empty;

                if (Attachments != null)
                {
                    foreach (var attachment in Attachments)
                    {
                        attachment.Dispose();
                    }

                    Attachments = null;
                }
            }

            // Call the base Dispose to clean up other resources
            base.Dispose(disposing);
        }
    }
}