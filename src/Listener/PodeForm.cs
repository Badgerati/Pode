using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Linq;

namespace Pode
{
    public class PodeForm : IDisposable
    {
        public IList<PodeFormFile> Files { get; private set; }
        public IList<PodeFormData> Data { get; private set; }

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

            // get the boundary start/end
            var parts = contentType.Split(';');
            var boundaryStart = $"--{parts[1].Split('=')[1].Trim()}";
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
            var boundaryLineIndex = 0;
            var disposition = string.Empty;
            var fields = new Dictionary<string, string>();

            // loop through all boundary sections and parse them
            for (var i = 0; i < (boundaryLineIndexes.Count - 1); i++)
            {
                fields.Clear();

                // get the content disposition and data headers
                boundaryLineIndex = boundaryLineIndexes[i];
                disposition = contentEncoding.GetString(lines[boundaryLineIndex + 1]).Trim(PodeHelpers.NEW_LINE_ARRAY);

                foreach (var line in disposition.Split(';'))
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
                    form.Data.Add(new PodeFormData(fields["name"], contentEncoding.GetString(lines[boundaryLineIndex + 3]).Trim(PodeHelpers.NEW_LINE_ARRAY)));
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
                    if (!string.IsNullOrWhiteSpace(fields["filename"]))
                    {
                        // parse the file contents, and create a stream for the payload
                        var fileContentType = contentEncoding.GetString(lines[boundaryLineIndex + 2]).Trim(PodeHelpers.NEW_LINE_ARRAY);
                        var fileBytesLength = 0;
                        var stream = new MemoryStream();

                        for (var j = (boundaryLineIndex + 4); j <= (boundaryLineIndexes[i + 1] - 1); j++)
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
                        form.Files.Add(new PodeFormFile(fields["filename"], stream, fields["name"], fileContentType.Split(':')[1].Trim()));
                    }
                }
            }

            return form;
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