using System;
using System.IO;

namespace Pode
{
    public class PodeSmtpAttachment : IDisposable
    {
        public string Name { get; private set; }
        public string ContentType { get; private set; }
        public string ContentEncoding { get; private set; }
        public byte[] Bytes => _stream.ToArray();

        private MemoryStream _stream;

        public PodeSmtpAttachment(string name, MemoryStream stream, string contentType, string contentEncoding)
        {
            Name = name;
            ContentType = contentType;
            ContentEncoding = contentEncoding;
            _stream = stream;
        }

        public void Save(string path, bool addNameToPath = true)
        {
            if (addNameToPath)
            {
                path = Path.Combine(path, Name);
            }

            using (var file = new FileStream(path, FileMode.Create, FileAccess.Write, FileShare.None))
            {
                _stream.WriteTo(file);
            }
        }

        public void Dispose()
        {
            _stream.Dispose();
        }
    }
}