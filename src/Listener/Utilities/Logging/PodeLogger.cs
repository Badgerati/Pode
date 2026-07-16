using System;
using System.Collections;
using System.Collections.Concurrent;
using System.Net;
using System.Threading;
using Pode.Protocols.Common.Requests;

namespace Pode.Utilities.Logging
{
    public class PodeLogger : IPodeLogger
    {
        public const string REQUEST_LOG_TYPE_NAME = "__pode_log_requests__";
        public const string ERROR_LOG_TYPE_NAME = "__pode_log_errors__";

        private readonly PodeLogQueue<IPodeLogEvent> Queue;
        private readonly ConcurrentDictionary<string, IPodeLogType> LogTypes;

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
            LogTypes = new ConcurrentDictionary<string, IPodeLogType>();
            Queue = new PodeLogQueue<IPodeLogEvent>();
        }

        public void RegisterType(IPodeLogType logType)
        {
            if (IsDisposed || !IsEnabled)
            {
                return;
            }

            LogTypes.TryAdd(logType.Name, logType);
        }

        public void UnregisterType(string name)
        {
            if (IsDisposed || !IsEnabled)
            {
                return;
            }

            LogTypes.TryRemove(name, out _);
        }

        public void Add(string logTypeName, PodeLogLevel level, object data, Hashtable metadata = null)
        {
            if (IsDisposed || !IsEnabled)
            {
                return;
            }

            // does the Log Type exist?
            if (!LogTypes.TryGetValue(logTypeName, out var logType))
            {
                return;
            }

            // is the log level enabled for the Log Type?
            if (!logType.IsLevelEnabled(level))
            {
                return;
            }

            // add the log event to the queue
            Queue.Add(new PodeLogEvent(logType, level, data, metadata));
        }

        public void AddException(Exception exception, string contextId, PodeLogLevel level, Hashtable metadata = null, int threadId = 0)
        {
            if (exception == null)
            {
                return;
            }

            var kind = exception is PodeRequestException podeRequestException
                ? podeRequestException.Kind
                : PodeRequestExceptionKind.Server;

            AddException(exception.Source, exception.Message, exception.StackTrace, contextId, level, kind, metadata, threadId);
        }

        public void AddException(string message, string contextId, PodeLogLevel level, PodeRequestExceptionKind kind = PodeRequestExceptionKind.Server, Hashtable metadata = null, int threadId = 0)
        {
            AddException(string.Empty, message, string.Empty, contextId, level, kind, metadata, threadId);
        }

        public void AddException(string category, string message, string stackTrace, string contextId, PodeLogLevel level, PodeRequestExceptionKind kind = PodeRequestExceptionKind.Server, Hashtable metadata = null, int threadId = 0)
        {
            if (IsDisposed || !IsEnabled)
            {
                return;
            }

            // does the Log Type exist?
            if (!LogTypes.TryGetValue(ERROR_LOG_TYPE_NAME, out var logType))
            {
                return;
            }

            // is the log level enabled for the Log Type?
            if (!logType.IsLevelEnabled(level))
            {
                return;
            }

            // is error kind enabled?
            if (logType is PodeLogErrorType errorLogType && !errorLogType.IsKindEnabled(kind))
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

            // default "<none>" values where not set
            stackTrace = string.IsNullOrWhiteSpace(stackTrace) ? "<none>" : stackTrace;
            message = string.IsNullOrWhiteSpace(message) ? "<none>" : message;
            contextId = string.IsNullOrWhiteSpace(contextId) ? "<none>" : contextId;

            // convert the exception to a log item
            var item = new Hashtable(StringComparer.InvariantCultureIgnoreCase)
            {
                { "Category", category },
                { "Message", message },
                { "StackTrace", stackTrace },
                { "Server", Dns.GetHostName() },
                { "Level", level.ToString() },
                { "Kind", kind.ToString() },
                { "Date", logType.GetTimestamp() },
                { "ThreadId", threadId == 0 ? Environment.CurrentManagedThreadId : threadId },
                { "ContextId", contextId }
            };

            // add the log event to the queue
            Queue.Add(new PodeLogEvent(logType, level, item, metadata));
        }

        public bool TryTake(out IPodeLogEvent logEvent, CancellationToken cancellationToken)
        {
            if (IsDisposed || !IsEnabled)
            {
                logEvent = null;
                return false;
            }

            var found = Queue.TryTake(out var _event, cancellationToken);

            if (!found || string.IsNullOrEmpty(_event?.Type?.Name) || !LogTypes.ContainsKey(_event?.Type?.Name))
            {
                logEvent = null;
                return false;
            }

            logEvent = _event;
            return found;
        }

        public void Reset()
        {
            if (IsDisposed)
            {
                return;
            }

            // clear Log Types
            LogTypes.Clear();
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

            // clear the Log Types
            LogTypes.Clear();

            // suppress finalization
            GC.SuppressFinalize(this);
        }
    }
}