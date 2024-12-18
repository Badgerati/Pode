using System;
using System.Runtime.InteropServices;

namespace Pode
{
    public static class NativeMethods
    {
        // Constants for standard handles
        public const int STD_INPUT_HANDLE = -10;
        public const int STD_OUTPUT_HANDLE = -11;
        public const int STD_ERROR_HANDLE = -12;

        // Import the GetStdHandle function from kernel32.dll
        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern IntPtr GetStdHandle(int nStdHandle);

        // Helper method to check if a handle is valid
        public static bool IsHandleValid(int handleType)
        {
            IntPtr handle = GetStdHandle(handleType);
            return handle != IntPtr.Zero;
        }
    }
}
