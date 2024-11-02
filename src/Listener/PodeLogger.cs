using System;
using System.Collections.Concurrent;
using System.Collections;
using System.Linq;

namespace Pode
{
    public static class PodeLogger
    {
        // Static fields to store the logging status and the queue of log entries
        private static bool _enabled;
        private static ConcurrentQueue<Hashtable> _queue;

        // Static property to enable or disable writing logs to the console
        public static bool Terminal { get; set; }


        // Static property to enable or disable logging
        public static bool Enabled
        {
            get => _enabled;
            set
            {
                _enabled = value;
                if (_enabled)
                {
                    // Initialize the queue if logging is enabled
                    _queue = new ConcurrentQueue<Hashtable>();
                }
                else
                {
                    // Clear the queue if logging is disabled
                    _queue = null;
                }
            }
        }

        // Property to get the count of items in the queue
        public static int Count
        {
            get => _queue != null ? _queue.Count : 0;
        }

        // Method to add a Hashtable to the queue
        public static void Enqueue(Hashtable table)
        {
            if (_queue != null)
            {
                _queue.Enqueue(table);
            }
        }

        // Method to try and dequeue a Hashtable from the queue
        public static bool TryDequeue(out Hashtable table)
        {
            if (_queue != null)
            {
                return _queue.TryDequeue(out table);
            }
            table = null;
            return false;
        }

        // Method to dequeue a Hashtable from the queue
        public static Hashtable Dequeue()
        {
            if (_queue != null && _queue.TryDequeue(out Hashtable table))
            {
                return table;
            }
            return null;
        }

        // Method to clear the queue
        public static void Clear()
        {
            if (_queue != null)
            {
                if (_queue != null)
                {
                    while (_queue.TryDequeue(out _)) { }
                }
            }
        }
        // Method to log an exception
        public static void LogException(Exception ex, PodeConnector connector = default(PodeConnector), PodeLoggingLevel level = PodeLoggingLevel.Error)
        {
            if (ex == default(Exception))
            {
                return;
            }

            // Return if logging is disabled, or if the level isn't being logged
            if (connector != default(PodeConnector) && (!connector.ErrorLoggingEnabled || !connector.ErrorLoggingLevels.Contains(level.ToString(), StringComparer.InvariantCultureIgnoreCase)))
            {
                return;
            }

            // Write the exception to the console if Terminal is enabled
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

        // Method to log a message
        public static void LogMessage(string message, PodeConnector connector = default(PodeConnector), PodeLoggingLevel level = PodeLoggingLevel.Error, PodeContext context = default(PodeContext))
        {
            // Do nothing if the message is empty or whitespace
            if (string.IsNullOrWhiteSpace(message))
            {
                return;
            }

            // Return if logging is disabled, or if the level isn't being logged
            if (connector != default(PodeConnector) && (!connector.ErrorLoggingEnabled || !connector.ErrorLoggingLevels.Contains(level.ToString(), StringComparer.InvariantCultureIgnoreCase)))
            {
                return;
            }

            // Write the message to the console if Terminal is enabled
            if (Terminal)
            {
                if (context == default(PodeContext))
                {
                    Console.WriteLine($"[{level}]: {message}");
                }
                else
                {
                    Console.WriteLine($"[{level}]: [ContextId: {context.ID}] {message}");
                }
            }

            // Add the error message to the log queue if logging is enabled
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

                if (context != null)
                {
                    ((Hashtable)logEntry["Item"])["TargetObject"] = context.ID;
                }

                Enqueue(logEntry);
            }
        }
    }
}
