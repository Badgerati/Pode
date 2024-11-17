
using System;
using System.IO;

namespace Pode.Service
{
    using System;
    using System.IO;

    public enum LogLevel
    {
        DEBUG,    // Detailed information for debugging purposes
        INFO,     // General operational information
        WARN,     // Warning messages for potential issues
        ERROR,    // Error messages for failures
        CRITICAL  // Critical errors indicating severe failures
    }

    public static class PodePwshLogger
    {
        private static readonly object _logLock = new();
        private static string logFilePath = "PodeService.log"; // Default log file path
        private static LogLevel minLogLevel = LogLevel.INFO;   // Default minimum log level

        /// <summary>
        /// Initializes the logger with a custom log file path and minimum log level.
        /// </summary>
        /// <param name="filePath">Path to the log file.</param>
        /// <param name="level">Minimum log level to record.</param>
        public static void Initialize(string filePath, LogLevel level)
        {
            if (!string.IsNullOrWhiteSpace(filePath))
            {
                logFilePath = filePath;
            }

            minLogLevel = level;

            try
            {
                // Create the log file if it doesn't exist
                if (!File.Exists(logFilePath))
                {
                    using (File.Create(logFilePath)) { }
                }

                Log(LogLevel.INFO, "Server", "Logger initialized. LogFilePath: {0}, MinLogLevel: {1}", logFilePath, minLogLevel);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Failed to initialize logger: {ex.Message}");
            }
        }

        public static void Log(LogLevel level, string context , string message = "", params object[] args)
        {
            if (level < minLogLevel || string.IsNullOrEmpty(message))
            {
                return; // Skip logging for levels below the minimum log level
            }

            try
            {
                // Format the message with the provided arguments
                var formattedMessage = string.Format(message, args);

                // Get the current time in ISO 8601 format in GMT/UTC
                string timestamp = DateTime.UtcNow.ToString("yyyy-MM-ddTHH:mm:ss.fffZ");

                // Get the current process ID
                int pid = Environment.ProcessId;

                // Build the log entry
                string logEntry = $"{timestamp} [PID:{pid}] [{level}] [{context}] {formattedMessage}";

                // Thread-safe write to log file
                lock (_logLock)
                {
                    using StreamWriter writer = new(logFilePath, true);
                    writer.WriteLine(logEntry);
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Failed to log to file: {ex.Message}");
            }
        }


        public static void Log(LogLevel level, Exception exception, string message = null, params object[] args)
        {
            if (level < minLogLevel)
            {
                return; // Skip logging for levels below the minimum log level
            }

            if (exception == null && string.IsNullOrEmpty(message))
            {
                return; // Nothing to log
            }

            try
            {
                // Get the current time in ISO 8601 format in GMT/UTC
                string timestamp = DateTime.UtcNow.ToString("yyyy-MM-ddTHH:mm:ss.fffZ");

                // Format the message if provided
                var logMessage = string.Empty;

                if (!string.IsNullOrEmpty(message))
                {
                    logMessage = string.Format(message, args);
                }

                // Add exception details
                if (exception != null)
                {
                    logMessage += $"{Environment.NewLine}Exception: {exception.GetType().Name}";
                    logMessage += $"{Environment.NewLine}Message: {exception.Message}";
                    logMessage += $"{Environment.NewLine}Stack Trace: {exception.StackTrace}";

                    // Include inner exception details if any
                    var innerException = exception.InnerException;
                    while (innerException != null)
                    {
                        logMessage += $"{Environment.NewLine}Inner Exception: {innerException.GetType().Name}";
                        logMessage += $"{Environment.NewLine}Message: {innerException.Message}";
                        logMessage += $"{Environment.NewLine}Stack Trace: {innerException.StackTrace}";
                        innerException = innerException.InnerException;
                    }
                }

                // Get the current process ID
                int pid = Environment.ProcessId;

                // Build the log entry
                string logEntry = $"{timestamp} [PID:{pid}] [{level}] [Server] {logMessage}";

                // Thread-safe write to log file
                lock (_logLock)
                {
                    using StreamWriter writer = new(logFilePath, true);
                    writer.WriteLine(logEntry);
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Failed to log to file: {ex.Message}");
            }
        }
    }
}