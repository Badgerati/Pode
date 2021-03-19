using System;
using System.IO;

namespace Pode
{
    public class PodeFormFile : IDisposable
    {
        public string ContentType { get; private set; }
        public string FileName { get; private set; }
        public string Name { get; private set; }
        public byte[] Bytes => _stream.ToArray();

        private MemoryStream _stream;

        public PodeFormFile(string fileName, MemoryStream stream, string name, string contentType)
        {
            ContentType = contentType;
            FileName = fileName;
            Name = name;
            _stream = stream;
        }

        public void Save(string path)
        {
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