using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Linq;
using System.Text.RegularExpressions;
using System.Net.Http;

namespace Pode
{
    public class PodeForm : IDisposable
    {
        public IList<PodeFormFile> Files { get; private set; }
        public IList<PodeFormData> Data { get; private set; }
        public string Boundary { get; private set; }

        private static readonly Regex BoundaryRegex = new Regex("boundary=\"?(?<boundary>.+?)\"?$");
        private static readonly Regex HeaderRegex = new Regex("^(?<name>.*?)\\:\\s+(?<value>.*?)$");

        public PodeForm()
        {
            Files = new List<PodeFormFile>();
            Data = new List<PodeFormData>();
        }

        public void Dispose()
        {
            // dispose all file streams
            foreach (var file in Files)
            {
                file.Dispose();
            }
        }

        public static PodeForm Parse(byte[] bytes, string contentType, Encoding contentEncoding)
        {
            var form = new PodeForm();

            // do nothing if there are no bytes to parse
            if (bytes == default(byte[]) || bytes.Length == 0)
            {
                return form;
            }

            // convert to bytes to lines of bytes
            var lines = PodeHelpers.ConvertToByteLines(bytes);

            // get the boundary
            var match = BoundaryRegex.Match(contentType);
            if (match.Success)
            {
                form.Boundary = match.Groups["boundary"].Value;
            }
            else
            {
                throw new HttpRequestException("No multipart/form-data boundary found");
            }

            // get the boundary start/end
            var boundaryStart = $"--{form.Boundary}";
            var boundaryEnd = $"{boundaryStart}--";

            var boundaryLineIndexes = new List<int>();
            for (var i = 0; i < lines.Count; i++)
            {
                if (IsLineBoundary(lines[i], boundaryStart, contentEncoding) || IsLineBoundary(lines[i], boundaryEnd, contentEncoding))
                {
                    boundaryLineIndexes.Add(i);
                }
            }

            // now parse the lines for data/files
            return ParseHttp(form, lines, boundaryLineIndexes, contentEncoding);
        }

        private static PodeForm ParseHttp(PodeForm form, List<byte[]> lines, List<int> boundaryLineIndexes, Encoding contentEncoding)
        {
            var currentLineIndex = 0;
            var currentLine = string.Empty;
            var fields = new Dictionary<string, string>(StringComparer.InvariantCultureIgnoreCase);
            var headers = new Dictionary<string, string>(StringComparer.InvariantCultureIgnoreCase);

            // loop through all boundary sections and parse them
            for (var i = 0; i < (boundaryLineIndexes.Count - 1); i++)
            {
                // reset fields and headers
                fields.Clear();
                headers.Clear();

                // what's the starting line index for the current boundary?
                currentLineIndex = boundaryLineIndexes[i] + 1;

                // parse headers until we see a blank line
                while (!string.IsNullOrWhiteSpace((currentLine = GetLineString(lines[currentLineIndex], contentEncoding))))
                {
                    currentLineIndex++;

                    // parse the header name=value pair
                    var match = HeaderRegex.Match(currentLine);
                    if (match.Success)
                    {
                        headers.Add(match.Groups["name"].Value, match.Groups["value"].Value);
                    }
                }

                // bump to next line, past the blank line
                currentLineIndex++;

                // get the content disposition fields
                if (!headers.ContainsKey("Content-Disposition"))
                {
                    throw new HttpRequestException("No Content-Disposition found in multipart/form-data");
                }

                // foreach (var line in disposition.Split(';'))
                foreach (var line in headers["Content-Disposition"].Split(';'))
                {
                    var atoms = line.Split('=');
                    if (atoms.Length == 2)
                    {
                        fields.Add(atoms[0].Trim(), atoms[1].Trim(' ', '"'));
                    }
                }

                // is this just a regular data field?
                if (!fields.ContainsKey("filename"))
                {
                    // add the data item as name=value
                    form.Data.Add(new PodeFormData(fields["name"], GetLineString(lines[currentLineIndex], contentEncoding)));
                }

                // otherwise it's a file field
                else
                {
                    // add a data item for mapping name=filename
                    var currentData = form.Data.FirstOrDefault(x => x.Key == fields["name"]);
                    if (currentData == default(PodeFormData))
                    {
                        form.Data.Add(new PodeFormData(fields["name"], fields["filename"]));
                    }
                    else
                    {
                        currentData.AddValue(fields["filename"]);
                    }

                    // do we actually have a filename?
                    if (string.IsNullOrWhiteSpace(fields["filename"]))
                    {
                        continue;
                    }

                    // parse the file contents, and create a stream for the payload
                    var fileBytesLength = 0;
                    var stream = new MemoryStream();

                    for (var j = currentLineIndex; j <= (boundaryLineIndexes[i + 1] - 1); j++)
                    {
                        fileBytesLength = lines[j].Length;
                        if (j == (boundaryLineIndexes[i + 1] - 1))
                        {
                            if (lines[j][fileBytesLength - 1] == PodeHelpers.NEW_LINE_BYTE)
                            {
                                fileBytesLength--;
                            }

                            if (lines[j][fileBytesLength - 1] == PodeHelpers.CARRIAGE_RETURN_BYTE)
                            {
                                fileBytesLength--;
                            }
                        }

                        stream.Write(lines[j], 0, fileBytesLength);
                    }

                    // add a file item for filename=stream [+name/content-type]
                    form.Files.Add(new PodeFormFile(fields["filename"], stream, fields["name"], headers["Content-Type"].Trim()));
                }
            }

            return form;
        }

        private static string GetLineString(byte[] bytes, Encoding contentEncoding)
        {
            return contentEncoding.GetString(bytes).Trim(PodeHelpers.NEW_LINE_ARRAY);
        }

        private static bool IsLineBoundary(byte[] bytes, string boundary, Encoding contentEncoding)
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

            return (contentEncoding.GetString(bytes).StartsWith(boundary));
        }

        public static bool IsLineBoundary(string line, string boundary)
        {
            if (string.IsNullOrEmpty(line))
            {
                return false;
            }

            return line.StartsWith(boundary);
        }
    }
}