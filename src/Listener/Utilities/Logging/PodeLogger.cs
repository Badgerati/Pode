using System;
using System.Collections;
using System.Collections.Concurrent;
using System.Collections.Generic;
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
        public PodeConcurrentSet<string> ErrorLogTypeNames { get; private set; }
        public PodeConcurrentSet<string> RequestLogTypeNames { get; private set; }

        public bool IsDisposed { get; private set; } = false;
        public int Count => Queue.Count;

        private bool _isEnabled = true;
        public bool IsEnabled
        {
            get => !IsDisposed && _isEnabled;
            set => _isEnabled = value;
        }

        public bool IsRequestLoggingEnabled => IsEnabled && RequestLogTypeNames?.Count > 0;
        public bool IsErrorLoggingEnabled => IsEnabled && ErrorLogTypeNames?.Count > 0;

        public PodeLogger()
        {
            LogTypes = new ConcurrentDictionary<string, IPodeLogType>();
            ErrorLogTypeNames = new PodeConcurrentSet<string>();
            RequestLogTypeNames = new PodeConcurrentSet<string>();
            Queue = new PodeLogQueue<IPodeLogEvent>();
        }

        public void RegisterType(IPodeLogType logType)
        {
            if (IsDisposed || !IsEnabled)
            {
                return;
            }

            LogTypes.TryAdd(logType.Name, logType);

            // register as error log type
            if (logType is PodeLogErrorType)
            {
                ErrorLogTypeNames.TryAdd(logType.Name);
            }

            // else register as request log type
            else if (logType is PodeLogRequestType)
            {
                RequestLogTypeNames.TryAdd(logType.Name);
            }
        }

        public void UnregisterType(string name)
        {
            if (IsDisposed || !IsEnabled)
            {
                return;
            }

            LogTypes.TryRemove(name, out _);
            ErrorLogTypeNames.TryRemove(name, out _);
            RequestLogTypeNames.TryRemove(name, out _);
        }

        public void Add(string logTypeName, PodeLogLevel level, object data, Hashtable metadata = null, List<Hashtable> overrides = null)
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
            Queue.Add(new PodeLogEvent(logType, level, data, metadata, overrides));
        }

        public void AddException(Exception exception, string contextId, PodeLogLevel level, Hashtable metadata = null, List<Hashtable> overrides = null, int threadId = 0)
        {
            if (exception == null)
            {
                return;
            }

            var kind = exception is PodeRequestException podeRequestException
                ? podeRequestException.Kind
                : PodeRequestExceptionKind.Server;

            AddException(exception.Source, exception.Message, exception.StackTrace, contextId, level, kind, metadata, overrides, threadId);
        }

        public void AddException(string message, string contextId, PodeLogLevel level, PodeRequestExceptionKind kind = PodeRequestExceptionKind.Server, Hashtable metadata = null, List<Hashtable> overrides = null, int threadId = 0)
        {
            AddException(string.Empty, message, string.Empty, contextId, level, kind, metadata, overrides, threadId);
        }

        public void AddException(string category, string message, string stackTrace, string contextId, PodeLogLevel level, PodeRequestExceptionKind kind = PodeRequestExceptionKind.Server, Hashtable metadata = null, List<Hashtable> overrides = null, int threadId = 0)
        {
            if (IsDisposed || !IsEnabled || !IsErrorLoggingEnabled)
            {
                return;
            }

            // default "<none>" values where not set
            stackTrace = string.IsNullOrWhiteSpace(stackTrace) ? "<none>" : stackTrace;
            message = string.IsNullOrWhiteSpace(message) ? "<none>" : message;
            contextId = string.IsNullOrWhiteSpace(contextId) ? "<none>" : contextId;

            // set the threadId to the current thread if not set
            threadId = threadId == 0 ? Environment.CurrentManagedThreadId : threadId;

            // timestamp (will be converted to UTC by the log type if required)
            var timestamp = DateTime.Now;

            // loop through all registered error log types, and queue exception for each
            foreach (var logTypeName in ErrorLogTypeNames)
            {
                // does the Log Type exist?
                if (!LogTypes.TryGetValue(logTypeName, out var logType))
                {
                    continue;
                }

                // is the log level enabled for the Log Type?
                if (!logType.IsLevelEnabled(level))
                {
                    continue;
                }

                // is error kind enabled?
                if (logType is PodeLogErrorType errorLogType && !errorLogType.IsKindEnabled(kind))
                {
                    continue;
                }

                // set a category to calling class and method if not set (will only be set on first log type)
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
                    { "Level", level },
                    { "Kind", kind },
                    { "Date", logType.GetTimestamp(timestamp) },
                    { "ThreadId", threadId },
                    { "ContextId", contextId }
                };

                // add the log event to the queue
                Queue.Add(new PodeLogEvent(logType, level, item, metadata, overrides));
            }
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
            ErrorLogTypeNames.Clear();
            RequestLogTypeNames.Clear();
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
            ErrorLogTypeNames.Clear();
            RequestLogTypeNames.Clear();

            // suppress finalization
            GC.SuppressFinalize(this);
        }
    }
}