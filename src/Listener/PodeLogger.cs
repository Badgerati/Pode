using System;
using System.Collections.Concurrent;
using System.Collections;
using System.Linq;
using System.Text.RegularExpressions;

namespace Pode
{
    public static class PodeLogger
    {
        // Static fields to control logging and store log entries in a thread-safe queue
        private static bool _enabled;
        private static ConcurrentQueue<Hashtable> _queue;

        /// <summary>
        /// Enables or disables writing logs to the console.
        /// </summary>
        public static bool Terminal { get; set; }

        /// <summary>
        /// Enables or disables logging. Initializes or clears the queue based on the value.
        /// </summary>
        public static bool Enabled
        {
            get => _enabled;
            set
            {
                _enabled = value;
                if (_enabled)
                {
                    // Initializes the queue for logging
                    _queue = new ConcurrentQueue<Hashtable>();
                }
                else
                {
                    // Clears the queue if logging is disabled
                    _queue = null;
                }
            }
        }

        /// <summary>
        /// Gets the count of items in the log queue.
        /// </summary>
        public static int Count => _queue != null ? _queue.Count : 0;

        /// <summary>
        /// Adds a log entry to the queue.
        /// </summary>
        /// <param name="table">The log entry as a Hashtable.</param>
        public static void Enqueue(Hashtable table)
        {
            if (_queue != null)
            {
                _queue.Enqueue(table);
            }
        }

        /// <summary>
        /// Attempts to dequeue a log entry from the queue.
        /// </summary>
        /// <param name="table">The dequeued log entry.</param>
        /// <returns>True if a log entry was dequeued, false otherwise.</returns>
        public static bool TryDequeue(out Hashtable table)
        {
            if (_queue != null)
            {
                return _queue.TryDequeue(out table);
            }
            table = null;
            return false;
        }

        /// <summary>
        /// Dequeues a log entry from the queue. Returns null if the queue is empty.
        /// </summary>
        /// <returns>The dequeued log entry as a Hashtable.</returns>
        public static Hashtable Dequeue()
        {
            if (_queue != null && _queue.TryDequeue(out Hashtable table))
            {
                return table;
            }
            return null;
        }

        /// <summary>
        /// Clears all entries from the log queue.
        /// </summary>
        public static void Clear()
        {
            if (_queue != null)
            {
                while (_queue.TryDequeue(out _)) { }
            }
        }

        /// <summary>
        /// Logs an exception by adding it to the queue and optionally writing it to the console.
        /// </summary>
        /// <param name="ex">The exception to log.</param>
        /// <param name="connector">Optional PodeConnector to control logging based on settings.</param>
        /// <param name="level">The logging level (default is Error).</param>
        public static void LogException(Exception ex, PodeConnector connector = default(PodeConnector), PodeLoggingLevel level = PodeLoggingLevel.Error)
        {
            if (ex == null)
            {
                return;
            }

            // Exit if logging is disabled or the logging level isn’t configured in the connector
            if (connector != null && (!connector.ErrorLoggingEnabled || !connector.ErrorLoggingLevels.Contains(level.ToString(), StringComparer.InvariantCultureIgnoreCase)))
            {
                return;
            }

            // If Terminal logging is enabled, output exception details to the console
            if (Terminal)
            {
                Console.WriteLine($"[{level}] {ex.GetType().Name}: {ex.Message}");
                Console.WriteLine(ex.StackTrace);

                if (ex.InnerException != null)
                {
                    Console.WriteLine($"[{level}] {ex.InnerException.GetType().Name}: {ex.InnerException.Message}");
                    Console.WriteLine(ex.InnerException.StackTrace);
                }
            }

            // Add the exception to the log queue if logging is enabled
            if (Enabled)
            {
                Hashtable logEntry = new Hashtable
                {
                    ["Name"] = "Listener",
                    ["Item"] = ex
                };

                Enqueue(logEntry);
            }
        }

        /// <summary>
        /// Logs a message by adding it to the queue and optionally writing it to the console.
        /// </summary>
        /// <param name="message">The message to log.</param>
        /// <param name="connector">Optional PodeConnector to control logging based on settings.</param>
        /// <param name="level">The logging level (default is Error).</param>
        /// <param name="context">Optional PodeContext to include context ID in the log entry.</param>
        public static void LogMessage(string message, PodeConnector connector = default(PodeConnector), PodeLoggingLevel level = PodeLoggingLevel.Error, PodeContext context = default(PodeContext))
        {
            // Exit if message is empty or whitespace
            if (string.IsNullOrWhiteSpace(message))
            {
                return;
            }

            // Exit if logging is disabled or the level isn’t configured in the connector
            if (connector != null && (!connector.ErrorLoggingEnabled || !connector.ErrorLoggingLevels.Contains(level.ToString(), StringComparer.InvariantCultureIgnoreCase)))
            {
                return;
            }

            // If Terminal logging is enabled, output message to the console, including context ID if provided
            if (Terminal)
            {
                if (context == null)
                {
                    Console.WriteLine($"[{level}]: {message}");
                }
                else
                {
                    Console.WriteLine($"[{level}]: [ContextId: {context.ID}] {message}");
                }
            }

            // Add the log message to the log queue if logging is enabled
            if (Enabled)
            {
                Hashtable logEntry = new Hashtable
                {
                    ["Name"] = "Listener",
                    ["Item"] = new Hashtable
                    {
                        ["Message"] = message,
                        ["Level"] = level,
                        ["ThreadId"] = Environment.CurrentManagedThreadId
                    }
                };

                // Add the context ID to the log entry if a context is provided
                if (context != null)
                {
                    ((Hashtable)logEntry["Item"])["TargetObject"] = context.ID;
                }

                Enqueue(logEntry);
            }
        }

        /// <summary>
        /// Masks sensitive information in a log item based on specified regex patterns.
        /// </summary>
        /// <param name="item">The log item to mask.</param>
        /// <param name="masking">A Hashtable containing masking patterns and a mask character.</param>
        /// <returns>The masked log item as a string.</returns>
        public static string ProtectLogItem(string item, Hashtable masking)
        {
            // Exit if there are no masking patterns
            if (masking == null || masking.Count == 0)
            {
                return item;
            }

            // Retrieve the mask character and patterns from the masking hashtable
            string mask = masking["Mask"].ToString();
            object[] patterns = (object[])masking["Patterns"];

            // Apply each regex pattern to the log item
            foreach (string regexPattern in patterns.Cast<string>())
            {
                Regex regex = new Regex(regexPattern, RegexOptions.IgnoreCase);
                Match match = regex.Match(item);

                if (match.Success)
                {
                    // Check for keep_before and keep_after groups in the match to retain surrounding text
                    if (match.Groups["keep_before"].Success && match.Groups["keep_after"].Success)
                    {
                        item = regex.Replace(item, $"{match.Groups["keep_before"].Value}{mask}{match.Groups["keep_after"].Value}");
                    }
                    else if (match.Groups["keep_before"].Success)
                    {
                        item = regex.Replace(item, $"{match.Groups["keep_before"].Value}{mask}");
                    }
                    else if (match.Groups["keep_after"].Success)
                    {
                        item = regex.Replace(item, $"{mask}{match.Groups["keep_after"].Value}");
                    }
                    else
                    {
                        item = regex.Replace(item, mask);
                    }
                }
            }

            return item;
        }
    }
}
