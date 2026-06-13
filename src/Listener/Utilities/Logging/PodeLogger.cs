using System;
using System.Collections;
using System.Collections.Generic;
using System.Net;
using System.Threading;

namespace Pode.Utilities.Logging
{
    public class PodeLogger : IPodeLogger
    {
        public const string REQUEST_LOG_TYPE_NAME = "__pode_log_requests__";
        public const string ERROR_LOG_TYPE_NAME = "__pode_log_errors__";

        private readonly PodeLogQueue<IPodeLogEvent> Queue;
        private readonly Dictionary<string, IPodeLogType> LogTypes;

        public bool IsDisposed { get; private set; } = false;
        public int Count => Queue.Count;

        private bool _isEnabled = true;
        public bool IsEnabled
        {
            get => !IsDisposed && _isEnabled;
            set => _isEnabled = value;
        }

        public bool IsRequestLoggingEnabled => IsEnabled && (LogTypes?.ContainsKey(REQUEST_LOG_TYPE_NAME) ?? false);
        public bool IsErrorLoggingEnabled => IsEnabled && (LogTypes?.ContainsKey(ERROR_LOG_TYPE_NAME) ?? false);

        public PodeLogger()
        {
            LogTypes = new Dictionary<string, IPodeLogType>();
            Queue = new PodeLogQueue<IPodeLogEvent>();
        }

        public void RegisterType(IPodeLogType logType)
        {
            if (IsDisposed || !IsEnabled)
            {
                return;
            }

            LogTypes.Add(logType.Name, logType);
        }

        public void UnregisterType(IPodeLogType logType)
        {
            if (IsDisposed || !IsEnabled)
            {
                return;
            }

            LogTypes.Remove(logType.Name);
        }

        public void Add(string name, PodeLogLevel level, object item)
        {
            if (IsDisposed || !IsEnabled)
            {
                return;
            }

            Add(new PodeLogEvent(name, level, item));
        }

        public void Add(IPodeLogEvent logEvent)
        {
            if (IsDisposed || !IsEnabled)
            {
                return;
            }

            // does the log type exist?
            if (!LogTypes.TryGetValue(logEvent.Name, out IPodeLogType logType))
            {
                return;
            }

            // is the log level enabled for the log type?
            if (!logType.IsLevelEnabled(logEvent.Level))
            {
                return;
            }

            // add the log event to the queue
            Queue.Add(logEvent);
        }

        public void AddException(Exception exception, string contextId, PodeLogLevel level, int threadId = 0)
        {
            if (exception == null)
            {
                return;
            }

            AddException(exception.Source, exception.Message, exception.StackTrace, contextId, level, threadId);
        }

        public void AddException(string message, string contextId, PodeLogLevel level, int threadId = 0)
        {
            AddException(string.Empty, message, string.Empty, contextId, level, threadId);
        }

        public void AddException(string category, string message, string stackTrace, string contextId, PodeLogLevel level, int threadId = 0)
        {
            if (IsDisposed || !IsEnabled)
            {
                return;
            }

            // does the log type exist?
            if (!LogTypes.TryGetValue(ERROR_LOG_TYPE_NAME, out IPodeLogType logType))
            {
                return;
            }

            // is the log level enabled for the log type?
            if (!logType.IsLevelEnabled(level))
            {
                return;
            }

            // set a category to calling class and method if not set
            if (string.IsNullOrWhiteSpace(category))
            {
                var diag = new System.Diagnostics.StackTrace();
                if (diag.FrameCount > 3)
                {
                    var frame = diag.GetFrame(3);
                    var method = frame.GetMethod();
                    var className = method.DeclaringType?.Name;
                    var methodName = method.Name;
                    category = $"{className}.{methodName}";
                }
            }

            // convert the exception to a log item
            var item = new Hashtable(StringComparer.InvariantCultureIgnoreCase)
            {
                { "Category", category },
                { "Message", message },
                { "StackTrace", stackTrace },
                { "Server", Dns.GetHostName() },
                { "Level", level.ToString() },
                { "Date", DateTime.Now },
                { "ThreadId", threadId == 0 ? Environment.CurrentManagedThreadId : threadId },
                { "ContextId", contextId }
            };

            // add the log event to the queue
            Queue.Add(new PodeLogEvent(ERROR_LOG_TYPE_NAME, level, item));
        }

        public bool TryTake(out IPodeLogEvent logEvent, CancellationToken cancellationToken)
        {
            if (IsDisposed || !IsEnabled)
            {
                logEvent = null;
                return false;
            }

            return Queue.TryTake(out logEvent, cancellationToken);
        }

        public void Dispose()
        {
            if (IsDisposed)
            {
                return;
            }
            IsDisposed = true;
            IsEnabled = false;

            // dispose the queue
            Queue.Dispose();

            // clear the log types
            LogTypes.Clear();

            // suppress finalization
            GC.SuppressFinalize(this);
        }
    }
}