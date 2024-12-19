using System;
using System.Runtime.InteropServices;

namespace Pode
{
    public static class NativeMethods
    {
        // Constants for standard Windows handles
        public const int STD_INPUT_HANDLE = -10;
        public const int STD_OUTPUT_HANDLE = -11;
        public const int STD_ERROR_HANDLE = -12;


          // Constants for standard UNIX file descriptors
        public const int STDIN_FILENO = 0;
        public const int STDOUT_FILENO = 1;
        public const int STDERR_FILENO = 2;


        // Import the GetStdHandle function from kernel32.dll
        [DllImport("kernel32.dll", SetLastError = true)]
        [System.Diagnostics.CodeAnalysis.SuppressMessage("Interoperability", "SYSLIB1054:Use 'LibraryImportAttribute' instead of 'DllImportAttribute' to generate P/Invoke marshalling code at compile time", Justification = "<Pending>")]
        private static extern IntPtr GetStdHandle(int nStdHandle);

        // Helper method to check if a handle is valid
        public static bool IsHandleValid(int handleType)
        {
            IntPtr handle = GetStdHandle(handleType);
            return handle != IntPtr.Zero;
        }


        // Import the isatty function from libc
        [DllImport("libc")]
        private static extern int isatty(int fd);

        // Method to check if a file descriptor is a terminal
        public static bool IsTerminal(int fileDescriptor)
        {
            return isatty(fileDescriptor) == 1;
        }
    }

}
