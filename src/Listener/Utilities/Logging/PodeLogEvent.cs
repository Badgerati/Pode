using System;
using System.Collections;

namespace Pode.Utilities.Logging
{
    public class PodeLogEvent : IPodeLogEvent
    {
        public string Name { get; private set; }
        public PodeLogLevel Level { get; private set; }
        public DateTime Timestamp { get; private set; } = DateTime.Now;
        public Hashtable Metadata { get; private set; }
        public object Data { get; private set; }

        public PodeLogEvent(string name, PodeLogLevel level, object data, Hashtable metadata = null)
        {
            if (string.IsNullOrEmpty(name))
            {
                throw new ArgumentException("Log item name cannot be null or empty.", nameof(name));
            }

            Name = name;
            Level = level;
            Data = data;
            Metadata = metadata ?? new Hashtable(StringComparer.InvariantCultureIgnoreCase);
        }
    }
}