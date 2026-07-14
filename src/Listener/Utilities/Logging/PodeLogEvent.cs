using System;
using System.Collections;

namespace Pode.Utilities.Logging
{
    public class PodeLogEvent : IPodeLogEvent
    {
        public IPodeLogType Type { get; private set; }
        public PodeLogLevel Level { get; private set; }
        public DateTime Timestamp { get; private set; }
        public Hashtable Metadata { get; private set; }
        public object Data { get; private set; }

        public PodeLogEvent(IPodeLogType type, PodeLogLevel level, object data, Hashtable metadata = null)
        {
            Type = type ?? throw new ArgumentNullException(nameof(type), "Log item type cannot be null.");
            Level = level;
            Data = data;
            Metadata = metadata ?? new Hashtable(StringComparer.InvariantCultureIgnoreCase);
            Timestamp = type.GetTimestamp();
        }
    }
}