using System;
using System.Collections;
using System.Collections.Generic;
using System.Threading;
using Pode.Protocols.Common.Requests;
using Pode.Utilities.Structures;

namespace Pode.Utilities.Logging
{
    public interface IPodeLogger : IDisposable
    {
        bool IsDisposed { get; }
        int Count { get; }

        PodeConcurrentSet<string> ErrorLogTypeNames { get; }
        PodeConcurrentSet<string> RequestLogTypeNames { get; }

        bool IsEnabled { get; set; }
        bool IsRequestLoggingEnabled { get; }
        bool IsErrorLoggingEnabled { get; }

        void RegisterType(IPodeLogType logType);
        void UnregisterType(string name);

        void Add(string logTypeName, PodeLogLevel level, object data, Hashtable metadata = null, List<Hashtable> overrides = null);
        void AddException(Exception exception, string contextId, PodeLogLevel level, Hashtable metadata = null, List<Hashtable> overrides = null, int threadId = 0);
        void AddException(string message, string contextId, PodeLogLevel level, PodeRequestExceptionKind kind = PodeRequestExceptionKind.Server, Hashtable metadata = null, List<Hashtable> overrides = null, int threadId = 0);
        void AddException(string category, string message, string stackTrace, string contextId, PodeLogLevel level, PodeRequestExceptionKind kind = PodeRequestExceptionKind.Server, Hashtable metadata = null, List<Hashtable> overrides = null, int threadId = 0);
        bool TryTake(out IPodeLogEvent logEvent, CancellationToken cancellationToken);
        void Reset();
    }
}