using System;
using System.Collections;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Net;
using System.Threading;

namespace Pode.Utilities.Logging
{
    public class PodeLogger : IDisposable
    {
        public const string REQUEST_LOG_TYPE_NAME = "__pode_log_requests__";
        public const string ERROR_LOG_TYPE_NAME = "__pode_log_errors__";

        private readonly BlockingCollection<PodeLogItem> Queue;
        private readonly Dictionary<string, PodeLogType> LogTypes;

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
            LogTypes = new Dictionary<string, PodeLogType>();
            Queue = new BlockingCollection<PodeLogItem>();
        }

        public void RegisterType(PodeLogType logType)
        {
            if (IsDisposed || !IsEnabled)
            {
                return;
            }

            LogTypes.Add(logType.Name, logType);
        }

        public void UnregisterType(PodeLogType logType)
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

            Add(new PodeLogItem(name, level, item));
        }

        public void Add(PodeLogItem logItem)
        {
            if (IsDisposed || !IsEnabled)
            {
                return;
            }

            // does the log type exist?
            if (!LogTypes.TryGetValue(logItem.Name, out PodeLogType logType))
            {
                return;
            }

            // is the log level enabled for the log type?
            if (!logType.IsLevelEnabled(logItem.Level))
            {
                return;
            }

            // add the log item to the queue
            Queue.Add(logItem);
        }

        public void AddException(Exception exception, PodeLogLevel level, int threadId = -1)
        {
            if (exception == null)
            {
                return;
            }

            AddException(exception.Source, exception.Message, exception.StackTrace, level, threadId);
        }

        public void AddException(string category, string message, string stackTrace, PodeLogLevel level, int threadId = -1)
        {
            if (IsDisposed || !IsEnabled)
            {
                return;
            }

            // does the log type exist?
            if (!LogTypes.TryGetValue(ERROR_LOG_TYPE_NAME, out PodeLogType logType))
            {
                return;
            }

            // is the log level enabled for the log type?
            if (!logType.IsLevelEnabled(level))
            {
                return;
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
                { "ThreadId", threadId == -1 ? Environment.CurrentManagedThreadId : threadId }
            };

            // add the log item to the queue
            Queue.Add(new PodeLogItem(ERROR_LOG_TYPE_NAME, level, item));
        }

        public bool TryTake(out PodeLogItem logItem, CancellationToken cancellationToken)
        {
            if (IsDisposed || !IsEnabled)
            {
                logItem = null;
                return false;
            }

            return Queue.TryTake(out logItem, 5000, cancellationToken);
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