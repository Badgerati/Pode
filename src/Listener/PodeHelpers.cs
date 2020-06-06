using System;

namespace Pode
{
    public class PodeHelpers
    {

        public const string WEB_SOCKET_MAGIC_KEY = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";
        public const string NEW_LINE = "\r\n";
        public const string NEW_LINE_UNIX = "\n";

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
    }
}