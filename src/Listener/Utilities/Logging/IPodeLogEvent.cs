using System;
using System.Collections;

namespace Pode.Utilities.Logging
{
    public interface IPodeLogEvent
    {
        IPodeLogType Type { get; }
        PodeLogLevel Level { get; }
        DateTime Timestamp { get; }
        Hashtable Metadata { get; }
        Hashtable Overrides { get; }
        object Data { get; }

        Hashtable GetOverride(string id, string type);
    }
}