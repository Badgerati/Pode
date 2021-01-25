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
using System.Globalization;
using _Encoding = System.Text.Encoding;

namespace Pode
{
    public class PodeSmtpRequest : PodeRequest
    {
        public string ContentType { get; private set; }
        public string ContentEncoding { get; private set; }
        public Hashtable Headers { get; private set; }
        public string Body { get; private set; }
        public string RawBody { get; private set; }
        public string Subject { get; private set; }
        public bool IsUrgent { get; private set; }
        public string From { get; private set; }
        public IList<string> To { get; private set; }
        public string Command { get; private set; }
        public bool CanProcess { get; private set; }

        public override bool CloseImmediately
        {
            get => (string.IsNullOrWhiteSpace(Command) || Command.Equals("QUIT", StringComparison.InvariantCultureIgnoreCase));
        }

        public PodeSmtpRequest(Socket socket)
            : base(socket)
        {
            CanProcess = false;
            IsKeepAlive = true;
            To = new List<string>();
        }

        private bool IsCommand(string content, string command)
        {
            return content.StartsWith(command, true, CultureInfo.InvariantCulture);
        }

        public void SendAck()
        {
            Context.Response.WriteLine($"220 {Context.PodeSocket.Hostnames[0]} -- Pode Proxy Server", true);
        }

        protected override void Parse(byte[] bytes)
        {
            // if there are no bytes, return (0 bytes read means we can close the socket)
            if (bytes.Length == 0)
            {
                Command = string.Empty;
                return;
            }

            // get the raw string for headers
            var content = Encoding.GetString(bytes, 0, bytes.Length);

            // empty
            if (string.IsNullOrWhiteSpace(content))
            {
                Command = string.Empty;
                Context.Response.WriteLine("501 Invalid command received", true);
                return;
            }

            // quit
            if (IsCommand(content, "QUIT"))
            {
                Command = "QUIT";
                return;
            }

            // helo
            if (IsCommand(content, "EHLO") || IsCommand(content, "HELO"))
            {
                Command = "EHLO";
                Context.Response.WriteLine("250 OK", true);
                return;
            }

            // to
            if (IsCommand(content, "RCPT TO"))
            {
                Command = "RCPT TO";
                Context.Response.WriteLine("250 OK", true);
                To.Add(ParseEmail(content));
                return;
            }

            // from
            if (IsCommand(content, "MAIL FROM"))
            {
                Command = "MAIL FROM";
                Context.Response.WriteLine("250 OK", true);
                From = ParseEmail(content);
                return;
            }

            // data
            if (IsCommand(content, "DATA"))
            {
                Command = "DATA";
                Context.Response.WriteLine("354 Start mail input; end with <CR><LF>.<CR><LF>", true);
                return;
            }

            // check prior command
            switch (Command.ToUpperInvariant())
            {
                case "DATA":
                    Context.Response.WriteLine("250 OK", true);
                    RawBody = content;
                    ParseHeaders(content);
                    Subject = $"{Headers["Subject"]}";
                    IsUrgent = ($"{Headers["Priority"]}".Equals("urgent", StringComparison.InvariantCultureIgnoreCase) || $"{Headers["Importance"]}".Equals("high", StringComparison.InvariantCultureIgnoreCase));
                    ContentType = $"{Headers["Content-Type"]}";
                    ContentEncoding = $"{Headers["Content-Transfer-Encoding"]}";

                    if (IsBodyValid(content))
                    {
                        ParseBody(content);
                    }
                    else
                    {
                        Command = string.Empty;
                        Context.Response.WriteLine("501 Invalid DATA received", true);
                        return;
                    }

                    CanProcess = true;
                    break;

                default:
                    throw new HttpRequestException();
            }
        }

        public void Reset()
        {
            CanProcess = false;
            Headers = new Hashtable(StringComparer.InvariantCultureIgnoreCase);
            From = string.Empty;
            To = new List<string>();
            Body = string.Empty;
            RawBody = string.Empty;
            Command = string.Empty;
            ContentType = string.Empty;
            ContentEncoding = string.Empty;
            Subject = string.Empty;
            IsUrgent = false;
        }

        private string ParseEmail(string value)
        {
            var parts = value.Split(':');
            if (parts.Length > 1)
            {
                return parts[1].Trim().Trim('<', '>', ' ');
            }

            return string.Empty;
        }

        private void ParseHeaders(string value)
        {
            Headers = new Hashtable(StringComparer.InvariantCultureIgnoreCase);

            var lines = value.Split(new string[] { PodeHelpers.NEW_LINE }, StringSplitOptions.None);
            var match = default(Match);

            foreach (var line in lines)
            {
                if (string.IsNullOrWhiteSpace(line))
                {
                    break;
                }

                match = Regex.Match(line, "^(?<name>.*?)\\:\\s+(?<value>.*?)$");
                if (match.Success)
                {
                    Headers.Add(match.Groups["name"].Value, match.Groups["value"].Value);
                }
            }
        }

        private bool IsBodyValid(string value)
        {
            var lines = value.Split(new string[] { PodeHelpers.NEW_LINE }, StringSplitOptions.None);
            return (Array.LastIndexOf(lines, ".") > -1);
        }

        private void ParseBody(string value)
        {
            Body = string.Empty;

            // split the message up
            var lines = value.Split(new string[] { PodeHelpers.NEW_LINE }, StringSplitOptions.None);

            // get the index of the first blank line, and last dot
            var indexOfBlankLine = Array.IndexOf(lines, string.Empty);
            var indexOfLastDot = Array.LastIndexOf(lines, ".");

            // get the body
            var bodyLines = lines.Skip(indexOfBlankLine + 1).Take(indexOfLastDot - indexOfBlankLine - 2);
            var body = string.Join(PodeHelpers.NEW_LINE, bodyLines);

            // if there's no body, return
            if (indexOfLastDot == -1 || string.IsNullOrWhiteSpace(body))
            {
                Body = body;
                return;
            }

            // decode body based on encoding
            var bodyBytes = default(byte[]);

            switch (ContentEncoding.ToLowerInvariant())
            {
                case "base64":
                    bodyBytes = Convert.FromBase64String(body);
                    break;

                case "quoted-printable":
                    var match = default(Match);
                    while ((match = Regex.Match(body, "(?<code>=(?<hex>[0-9A-F]{2}))")).Success)
                    {
                        body = (body.Replace(match.Groups["code"].Value, $"{(char)Convert.ToInt32(match.Groups["hex"].Value, 16)}"));
                    }
                    break;
            }

            // if body bytes set, convert to string based on type
            if (bodyBytes != default(byte[]))
            {
                var type = ContentType.ToLowerInvariant();

                // utf-7
                if (type.Contains("utf-7"))
                {
                    body = _Encoding.UTF7.GetString(bodyBytes);
                }

                // utf-8
                else if (type.Contains("utf-8"))
                {
                    body = _Encoding.UTF8.GetString(bodyBytes);
                }

                // utf-16
                else if (type.Contains("utf-16"))
                {
                    body = _Encoding.Unicode.GetString(bodyBytes);
                }

                // utf-32
                else if (type.Contains("utf32"))
                {
                    body = _Encoding.UTF32.GetString(bodyBytes);
                }

                // default (ascii)
                else
                {
                    body = _Encoding.ASCII.GetString(bodyBytes);
                }
            }

            // set body
            Body = body;
        }
    }
}