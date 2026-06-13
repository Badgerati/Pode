using System;

namespace Pode.Utilities.Logging
{
    public class PodeLogItem
    {
        public string Name { get; private set; }
        public PodeLogLevel Level { get; private set; }
        public object Item { get; private set; }

        public PodeLogItem(string name, PodeLogLevel level, object item)
        {
            if (string.IsNullOrEmpty(name))
            {
                throw new ArgumentException("Log item name cannot be null or empty.", nameof(name));
            }

            Name = name;
            Level = level;
            Item = item;
        }
    }
}