using System;

namespace Pode
{
    public class PodeHelpers
    {

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