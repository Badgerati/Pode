using System;
using System.IO;

namespace Pode
{
    public class PodeFormFile
    {
        public string ContentType { get; private set; }
        public string FileName { get; private set; }
        public string Name { get; private set; }
        public byte[] Bytes { get; private set; }

        public PodeFormFile(string fileName, byte[] bytes, string name, string contentType)
        {
            ContentType = contentType;
            FileName = fileName;
            Name = name;
            Bytes = bytes;
        }
    }
}