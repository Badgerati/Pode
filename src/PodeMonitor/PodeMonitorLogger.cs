using System;
using System.IO;
using System.Text.RegularExpressions;

namespace PodeMonitor
{
    public enum LogLevel
    {
        DEBUG,    // Detailed information for debugging purposes
        INFO,     // General operational information
        WARN,     // Warning messages for potential issues
        ERROR,    // Error messages for failures
        CRITICAL  // Critical errors indicating severe failures
    }

    public static partial class PodeMonitorLogger
    {
        private static readonly object _logLock = new(); // Ensures thread-safe writes
        private static string _logFilePath = "PodeService.log"; // Default log file path
        private static LogLevel _minLogLevel = LogLevel.INFO;   // Default minimum log level

        [GeneratedRegex(@"\x1B\[[0-9;]*[a-zA-Z]")]
        private static partial Regex AnsiRegex();

        /// <summary>
        /// Initializes the logger with a custom log file path and minimum log level.
        /// </summary>
        /// <param name="filePath">Path to the log file.</param>
        /// <param name="level">Minimum log level to record.</param>
        public static void Initialize(string filePath, LogLevel level)
        {
            try
            {
                // Update the log file path and minimum log level
                if (!string.IsNullOrWhiteSpace(filePath))
                {
                    _logFilePath = filePath;
                }

                _minLogLevel = level;

                // Ensure the log file exists
                if (!File.Exists(_logFilePath))
                {
                    using (File.Create(_logFilePath)) { };
                }

                // Log initialization success
                Log(LogLevel.INFO, "PodeMonitor", Environment.ProcessId,
                    "Logger initialized. LogFilePath: {0}, MinLogLevel: {1}", _logFilePath, _minLogLevel);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Failed to initialize logger: {ex.Message}");
            }
        }

        /// <summary>
        /// Logs a message to the log file with the specified log level and context.
        /// </summary>
        /// <param name="level">Log level.</param>
        /// <param name="context">Context of the log (e.g., "PodeMonitor").</param>
        /// <param name="pid">Process ID to include in the log.</param>
        /// <param name="message">Message to log.</param>
        /// <param name="args">Optional arguments for formatting the message.</param>
        public static void Log(LogLevel level, string context, int pid, string message = "", params object[] args)
        {
            if (level < _minLogLevel || string.IsNullOrEmpty(message))
            {
                return; // Skip logging for levels below the minimum log level or empty messages
            }

            try
            {
                // Sanitize the message to remove ANSI escape codes
                string sanitizedMessage = AnsiRegex().Replace(message, string.Empty);

                // Format the sanitized message
                string formattedMessage = string.Format(sanitizedMessage, args);

                // Get the current time in ISO 8601 format (UTC)
                string timestamp = DateTime.UtcNow.ToString("yyyy-MM-ddTHH:mm:ss.fffZ");

                // Construct the log entry
                string logEntry = $"{timestamp} [PID:{pid}] [{level}] [{context}] {formattedMessage}";

                // Thread-safe log file write
                lock (_logLock)
                {
                    using StreamWriter writer = new(_logFilePath, true);
                    writer.WriteLine(logEntry);
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Failed to log to file: {ex.Message}");
            }
        }

        /// <summary>
        /// Logs an exception and an optional message to the log file.
        /// </summary>
        /// <param name="level">Log level.</param>
        /// <param name="exception">Exception to log.</param>
        /// <param name="message">Optional message to include.</param>
        /// <param name="args">Optional arguments for formatting the message.</param>
        public static void Log(LogLevel level, Exception exception, string message = null, params object[] args)
        {
            if (level < _minLogLevel || (exception == null && string.IsNullOrEmpty(message)))
            {
                return; // Skip logging if the level is below the minimum or there's nothing to log
            }

            try
            {
                // Get the current time in ISO 8601 format (UTC)
                string timestamp = DateTime.UtcNow.ToString("yyyy-MM-ddTHH:mm:ss.fffZ");

                // Format the message if provided
                string logMessage = string.Empty;
                if (!string.IsNullOrEmpty(message))
                {
                    // Sanitize the message to remove ANSI escape codes
                    string sanitizedMessage = AnsiRegex().Replace(message, string.Empty);
                    logMessage = string.Format(sanitizedMessage, args);
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

                // Construct the log entry
                string logEntry = $"{timestamp} [PID:{pid}] [{level}] [PodeMonitor] {logMessage}";

                // Thread-safe log file write
                lock (_logLock)
                {
                    using StreamWriter writer = new(_logFilePath, true);
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
