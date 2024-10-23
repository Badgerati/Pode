using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using System.Reflection;
using System.Runtime.Versioning;
using System.Collections;
using System.Diagnostics.CodeAnalysis;
using System.Threading;
using System.Threading.Tasks;
using System.Text;
using System.IO.Compression;

namespace Pode
{
    public static class PodeHelpers
    {
        public static readonly string[] HTTP_METHODS = new string[] { "CONNECT", "DELETE", "GET", "HEAD", "MERGE", "OPTIONS", "PATCH", "POST", "PUT", "TRACE" };
        public const string WEB_SOCKET_MAGIC_KEY = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";
        public readonly static char[] NEW_LINE_ARRAY = new char[] { '\r', '\n' };
        public readonly static char[] SPACE_ARRAY = new char[] { ' ' };
        public const string NEW_LINE = "\r\n";
        public const string NEW_LINE_UNIX = "\n";
        public const int BYTE_SIZE = sizeof(byte);
        public const byte NEW_LINE_BYTE = 10;
        public const byte CARRIAGE_RETURN_BYTE = 13;
        public const byte DASH_BYTE = 45;
        public const byte PERIOD_BYTE = 46;

        private static string _dotnet_version = string.Empty;
        private static bool _is_net_framework = false;
        public static bool IsNetFramework
        {
            get
            {
                if (string.IsNullOrWhiteSpace(_dotnet_version))
                {
                    _dotnet_version = Assembly.GetEntryAssembly()?.GetCustomAttribute<TargetFrameworkAttribute>()?.FrameworkName ?? "Framework";
                    _is_net_framework = _dotnet_version.Equals("Framework", StringComparison.InvariantCultureIgnoreCase);
                }

                return _is_net_framework;
            }
        }



        public static void HandleAggregateException(AggregateException aex, PodeConnector connector = default(PodeConnector), PodeLoggingLevel level = PodeLoggingLevel.Error, bool handled = false)
        {
            try
            {
                aex.Handle((ex) =>
                {
                    if (ex is IOException || ex is OperationCanceledException)
                    {
                        return true;
                    }

                    PodeLogger.WriteException(ex, connector, level);
                    return false;
                });
            }
            catch
            {
                if (!handled)
                {
                    throw;
                }
            }
        }



        public static string NewGuid(int length = 16)
        {
            using (var rnd = RandomNumberGenerator.Create())
            {
                var bytes = new byte[length];
                rnd.GetBytes(bytes);
                return new Guid(bytes).ToString();
            }
        }

        public static async Task WriteTo(MemoryStream stream, byte[] array, int startIndex, int count, CancellationToken cancellationToken)
        {
            // Validate startIndex and count to avoid unnecessary work
            if (startIndex < 0 || startIndex > array.Length)
            {
                throw new ArgumentOutOfRangeException(nameof(startIndex));
            }

            if (count <= 0 || startIndex + count > array.Length)
            {
                count = array.Length - startIndex;
            }

            // Perform the asynchronous write operation
            if (count > 0)
            {
                await stream.WriteAsync(array, startIndex, count, cancellationToken).ConfigureAwait(false);
            }
        }

        public static byte[] Slice(byte[] array, int startIndex, int count = 0)
        {
            // Validate startIndex and adjust count if needed
            if (startIndex < 0 || startIndex > array.Length)
            {
                throw new ArgumentOutOfRangeException(nameof(startIndex));
            }

            // If count is zero or less, or exceeds the array bounds, adjust it
            if (count <= 0 || startIndex + count > array.Length)
            {
                count = array.Length - startIndex;
            }

            // If the count is zero, return an empty array
            if (count == 0)
            {
                return Array.Empty<byte>();
            }

            var newArray = new byte[count];
            Buffer.BlockCopy(array, startIndex * BYTE_SIZE, newArray, 0, count * BYTE_SIZE);
            return newArray;
        }

        public static byte[] Concat(byte[] array1, byte[] array2)
        {
            if (array1 == default(byte[]) || array1.Length == 0)
            {
                return array2;
            }

            if (array2 == default(byte[]) || array2.Length == 0)
            {
                return array1;
            }

            var newArray = new byte[array1.Length + array2.Length];
            Buffer.BlockCopy(array1, 0, newArray, 0, array1.Length * BYTE_SIZE);
            Buffer.BlockCopy(array2, 0, newArray, array1.Length * BYTE_SIZE, array2.Length * BYTE_SIZE);
            return newArray;
        }

        public static List<byte[]> ConvertToByteLines(byte[] bytes)
        {
            var lines = new List<byte[]>();
            var index = 0;
            var nextIndex = 0;

            while ((nextIndex = Array.IndexOf(bytes, NEW_LINE_BYTE, index)) > 0)
            {
                lines.Add(Slice(bytes, index, (nextIndex - index) + 1));
                index = nextIndex + 1;
            }

            return lines;
        }

        public static T[] Subset<T>(T[] array, int startIndex, int endIndex)
        {
            var count = endIndex - startIndex;
            var newArray = new T[count];
            Array.Copy(array, startIndex, newArray, 0, count);
            return newArray;
        }

        public static List<T> Subset<T>(List<T> list, int startIndex, int endIndex)
        {
            return Subset(list.ToArray(), startIndex, endIndex).ToList<T>();
        }

        public static byte[] ConvertStreamToBytes(Stream stream)
        {
            // we need to copy the stream to a memory stream and then return the bytes
            using (var memory = new MemoryStream())
            {
                stream.CopyTo(memory);
                return memory.ToArray();
            }
        }

        public static string ConvertBytesToString(byte[] bytes, bool removeNewLines = false)
        {
            // return empty string if no bytes
            if (bytes == default(byte[]) || bytes.Length == 0)
            {
                return string.Empty;
            }

            // convert the bytes to a string
            var str = Encoding.UTF8.GetString(bytes);

            // remove new lines if needed
            if (removeNewLines)
            {
                return str.Trim(NEW_LINE_ARRAY);
            }

            return str;
        }

        public static string ReadStreamToEnd(Stream stream, Encoding encoding = default)
        {
            // return empty string if no stream
            if (stream == default(Stream))
            {
                return string.Empty;
            }

            // set the encoding if not provided
            if (encoding == default(Encoding))
            {
                encoding = Encoding.UTF8;
            }

            // read the stream to the end
            using (var reader = new StreamReader(stream, encoding))
            {
                return reader.ReadToEnd();
            }
        }

        // decompress bytes into either a gzip or deflate stream, and return the string
        public static string DecompressBytes(byte[] bytes, PodeCompressionType type, Encoding encoding = default)
        {
            var stream = CompressStream(new MemoryStream(bytes), type, CompressionMode.Decompress);
            return ReadStreamToEnd(stream, encoding);
        }

        // compress bytes into either a gzip or deflate stream, and return the bytes
        public static byte[] CompressBytes(byte[] bytes, PodeCompressionType type)
        {
            var ms = new MemoryStream();

            using (var stream = CompressStream(ms, type, CompressionMode.Compress))
            {
                stream.Write(bytes, 0, bytes.Length);
            }

            ms.Position = 0;
            return ms.ToArray();
        }

        // compress stream into either a gzip or deflate stream
        public static Stream CompressStream(Stream stream, PodeCompressionType type, CompressionMode mode)
        {
            var leaveOpen = mode == CompressionMode.Compress;

            switch (type)
            {
                case PodeCompressionType.Gzip:
                    return new GZipStream(stream, mode, leaveOpen);

                case PodeCompressionType.Deflate:
                    return new DeflateStream(stream, mode, leaveOpen);

                default:
                    return stream;
            }
        }
    }
}