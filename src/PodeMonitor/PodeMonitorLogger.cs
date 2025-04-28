using System;
using System.IO;
using System.Text.RegularExpressions;

namespace PodeMonitor
{

    /// <summary>
    /// A thread-safe logger for PodeMonitor that supports log rotation, exception logging, and log level filtering.
    /// </summary>
    public static partial class PodeMonitorLogger
    {
        private static readonly object _logLock = new(); // Ensures thread-safe writes
        private static string _logFilePath = "PodeService.log"; // Default log file path
        private static PodeLogLevel _minLogLevel = PodeLogLevel.INFO;   // Default minimum log level
        private const long DefaultMaxFileSize = 10 * 1024 * 1024; // Default max file size: 10 MB

        [GeneratedRegex(@"\x1B\[[0-9;]*[a-zA-Z]")]
        private static partial Regex AnsiRegex();

        /// <summary>
        /// Initializes the logger with a custom log file path and minimum log level.
        /// Validates the path, ensures the log file exists, and sets up log rotation.
        /// </summary>
        /// <param name="filePath">Path to the log file.</param>
        /// <param name="level">Minimum log level to record.</param>
        /// <param name="maxFileSizeInBytes">Maximum log file size in bytes before rotation.</param>
        public static void Initialize(string filePath, PodeLogLevel level, long maxFileSizeInBytes = DefaultMaxFileSize)
        {
            try
            {
                // Set the log file path and validate it
                if (!string.IsNullOrWhiteSpace(filePath))
                {
                    ValidateLogPath(filePath);
                    _logFilePath = filePath;
                }

                _minLogLevel = level;

                // Ensure the log file exists
                if (!File.Exists(_logFilePath))
                {
                    using (File.Create(_logFilePath)) { };
                }

                // Perform log rotation if necessary
                RotateLogFile(maxFileSizeInBytes);

                // Log initialization success
                Log(PodeLogLevel.INFO, "PodeMonitor", Environment.ProcessId,
                    "Logger initialized. LogFilePath: {0}, MinLogLevel: {1}, MaxFileSize: {2} bytes", _logFilePath, _minLogLevel, maxFileSizeInBytes);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Failed to initialize logger: {ex.Message}");
            }
        }

        /// <summary>
        /// Logs a message to the log file with the specified log level, context, and optional arguments.
        /// </summary>
        /// <param name="level">Log level.</param>
        /// <param name="context">Context of the log (e.g., "PodeMonitor").</param>
        /// <param name="pid">Process ID to include in the log.</param>
        /// <param name="message">Message to log.</param>
        /// <param name="args">Optional arguments for formatting the message.</param>
        public static void Log(PodeLogLevel level, string context, int pid, string message = "", params object[] args)
        {
            if (level < _minLogLevel || string.IsNullOrEmpty(message))
            {
                return; // Skip logging for levels below the minimum or empty messages
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
                Console.WriteLine($"Failed to log to file:");
                Console.WriteLine($"{context} - {message}");
                Console.WriteLine($"Error: {ex.Message}");
            }
        }

        /// <summary>
        /// Logs an exception and an optional message to the log file.
        /// Includes exception stack trace and inner exception details.
        /// </summary>
        /// <param name="level">Log level.</param>
        /// <param name="exception">Exception to log.</param>
        /// <param name="message">Optional message to include.</param>
        /// <param name="args">Optional arguments for formatting the message.</param>
        public static void Log(PodeLogLevel level, Exception exception, string message = null, params object[] args)
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

                // Construct the log entry
                string logEntry = $"{timestamp} [PID:{Environment.ProcessId}] [{level}] [PodeMonitor] {logMessage}";

                // Thread-safe log file write
                lock (_logLock)
                {
                    using StreamWriter writer = new(_logFilePath, true);
                    writer.WriteLine(logEntry);
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Failed to log exception to file: {ex.Message}");
            }
        }

        /// <summary>
        /// Ensures log rotation by renaming old logs when the current log file exceeds the specified size.
        /// </summary>
        /// <param name="maxFileSizeInBytes">Maximum size of the log file in bytes before rotation.</param>
        private static void RotateLogFile(long maxFileSizeInBytes)
        {
            lock (_logLock)
            {
                FileInfo logFile = new(_logFilePath);
                if (logFile.Exists && logFile.Length > maxFileSizeInBytes)
                {
                    string rotatedFilePath = $"{_logFilePath}.{DateTime.UtcNow:yyyyMMddHHmmss}";
                    File.Move(_logFilePath, rotatedFilePath);
                }
            }
        }

        /// <summary>
        /// Validates the log file path to ensure it is writable.
        /// Creates the directory if it does not exist.
        /// </summary>
        /// <param name="filePath">Path to validate.</param>
        private static void ValidateLogPath(string filePath)
        {
            string directory = Path.GetDirectoryName(filePath);

            if (string.IsNullOrWhiteSpace(directory))
            {
                throw new ArgumentException("Invalid log file path: Directory cannot be determined.");
            }

            if (!Directory.Exists(directory))
            {
                Directory.CreateDirectory(directory);
            }

            try
            {
                string testFilePath = Path.Combine(directory, "test_write.log");
                using (var stream = File.Create(testFilePath))
                {
                    stream.WriteByte(0);
                }
                File.Delete(testFilePath);
            }
            catch (Exception ex)
            {
                throw new IOException($"Log directory is not writable: {directory}", ex);
            }
        }
    }
}
