using System;
using System.Security.Cryptography;

namespace Pode
{
    public class PodeHelpers
    {

        public static readonly string[] HTTP_METHODS = new string[] { "DELETE", "GET", "HEAD", "MERGE", "OPTIONS", "PATCH", "POST", "PUT", "TRACE" };
        public const string WEB_SOCKET_MAGIC_KEY = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";
        public const string NEW_LINE = "\r\n";
        public const string NEW_LINE_UNIX = "\n";
        public const int BYTE_SIZE = sizeof(byte);

        public static void WriteException(Exception ex, PodeListener listener = default(PodeListener))
        {
            if (ex == default(Exception))
            {
                return;
            }

            if (listener != default(PodeListener) && !listener.ErrorLoggingEnabled)
            {
                return;
            }

            Console.WriteLine(ex.Message);
            Console.WriteLine(ex.StackTrace);
        }

        public static string NewGuid(int length = 16)
        {
            using (var rnd = RandomNumberGenerator.Create())
            {
                var bytes = new byte[length];
                rnd.GetBytes(bytes);
                return (new Guid(bytes)).ToString();
            }
        }

        public static byte[] Slice(byte[] array, int startIndex, int count = 0)
        {
            if (count <= 0 || startIndex + count > array.Length)
            {
                count = array.Length - startIndex;
            }

            var newArray = new byte[count];
            Buffer.BlockCopy(array, startIndex * BYTE_SIZE, newArray, 0, count * BYTE_SIZE);
            return newArray;
        }

        public static byte[] Concat(byte[] array1, byte[] array2)
        {
            if (array1.Length == 0)
            {
                return array2;
            }

            if (array2.Length == 0)
            {
                return array1;
            }

            var newArray = new byte[array1.Length + array2.Length];
            Buffer.BlockCopy(array1, 0, newArray, 0, array1.Length * BYTE_SIZE);
            Buffer.BlockCopy(array2, 0, newArray, array1.Length * BYTE_SIZE, array2.Length * BYTE_SIZE);
            return newArray;
        }
    }
}