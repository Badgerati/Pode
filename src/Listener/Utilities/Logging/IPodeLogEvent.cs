using System;
using System.Collections;

namespace Pode.Utilities.Logging
{
    public interface IPodeLogEvent
    {
        string Name { get; }
        PodeLogLevel Level { get; }
        DateTime Timestamp { get; }
        Hashtable Metadata { get; }
        object Data { get; }
    }
}