using System;
using System.Collections;
using System.Collections.Generic;

namespace Pode.Utilities.Logging
{
    public class PodeLogEvent : IPodeLogEvent
    {
        public IPodeLogType Type { get; private set; }
        public PodeLogLevel Level { get; private set; }
        public DateTime Timestamp { get; private set; }
        public Hashtable Metadata { get; private set; }
        public Hashtable Overrides { get; private set; }
        public object Data { get; private set; }

        public PodeLogEvent(IPodeLogType type, PodeLogLevel level, object data, Hashtable metadata = null, List<Hashtable> overrides = null)
        {
            Type = type ?? throw new ArgumentNullException(nameof(type), "Log item type cannot be null.");
            Level = level;
            Data = data;
            Metadata = metadata ?? new Hashtable(StringComparer.InvariantCultureIgnoreCase);
            Timestamp = type.GetTimestamp();
            SetOverrides(overrides);
        }

        private void SetOverrides(List<Hashtable> overrides)
        {
            Overrides = new Hashtable(StringComparer.InvariantCultureIgnoreCase);
            if (overrides == default)
            {
                return;
            }

            foreach (var item in overrides)
            {
                if (item == null || !item.ContainsKey("Id"))
                {
                    continue;
                }

                Overrides[item["Id"]] = item;
            }
        }

        public Hashtable GetOverride(string id, string type)
        {
            if (string.IsNullOrEmpty(id) && string.IsNullOrEmpty(type))
            {
                return null;
            }

            if (Overrides.ContainsKey(id))
            {
                return Overrides[id] as Hashtable;
            }

            if (Overrides.ContainsKey(type))
            {
                return Overrides[type] as Hashtable;
            }

            return null;
        }
    }
}