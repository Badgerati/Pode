using System;
using System.IO;
namespace PodeMonitor
{
    public static class PipeNameGenerator
    {
        private const int MaxUnixPathLength = 104; // Max length for Unix domain sockets on macOS
        private const string UnixTempDir = "/tmp"; // Short temporary directory for Unix systems

        public static string GeneratePipeName()
        {
            // Generate a unique name based on a GUID
            string uniqueId = Guid.NewGuid().ToString("N").Substring(0, 8);

            if (OperatingSystem.IsWindows())
            {
                // Use Windows named pipe format
                return $"PodePipe_{uniqueId}";
            }
            else if (OperatingSystem.IsLinux() || OperatingSystem.IsMacOS())
            {
                // Use Unix domain socket format with a shorter temp directory
                //string pipePath = Path.Combine(UnixTempDir, $"PodePipe_{uniqueId}");
                string pipePath = $"PodePipe_{uniqueId}";

                // Ensure the path is within the allowed length for Unix domain sockets
                if (pipePath.Length > MaxUnixPathLength)
                {
                    throw new InvalidOperationException($"Generated pipe path exceeds the maximum length of {MaxUnixPathLength} characters: {pipePath}");
                }

                return pipePath;
            }
            else
            {
                throw new PlatformNotSupportedException("Unsupported operating system for pipe name generation.");
            }
        }
    }
}
