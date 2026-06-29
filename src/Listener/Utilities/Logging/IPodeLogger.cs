using System;
using System.Collections;
using System.Threading;

namespace Pode.Utilities.Logging
{
    public interface IPodeLogger : IDisposable
    {
        bool IsDisposed { get; }
        int Count { get; }

        bool IsEnabled { get; set; }
        bool IsRequestLoggingEnabled { get; }
        bool IsErrorLoggingEnabled { get; }

        void RegisterType(IPodeLogType logType);
        void UnregisterType(string name);

        void Add(IPodeLogEvent logEvent);
        void AddException(Exception exception, string contextId, PodeLogLevel level, Hashtable metadata = null, int threadId = 0);
        void AddException(string message, string contextId, PodeLogLevel level, Hashtable metadata = null, int threadId = 0);
        void AddException(string category, string message, string stackTrace, string contextId, PodeLogLevel level, Hashtable metadata = null, int threadId = 0);
        bool TryTake(out IPodeLogEvent logEvent, CancellationToken cancellationToken);
        void Reset();
    }
}