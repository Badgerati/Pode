using System;
using System.Collections.Generic;

namespace Pode.Utilities.Logging
{
    public class PodeLogType : IPodeLogType
    {
        public string Name { get; private set; }
        public HashSet<PodeLogLevel> Levels { get; private set; }
        public bool AsUtc { get; private set; }

        public PodeLogType(string name, HashSet<PodeLogLevel> levels, bool asUtc)
        {
            if (string.IsNullOrEmpty(name))
            {
                throw new ArgumentException("Log Type name cannot be null or empty.", nameof(name));
            }

            Name = name;
            Levels = levels;
            AsUtc = asUtc;
        }

        public bool IsLevelEnabled(PodeLogLevel level)
        {
            return Levels.Contains(level);
        }

        public DateTime GetTimestamp(DateTime? timestamp = null)
        {
            var ts = timestamp ?? DateTime.Now;
            return AsUtc ? ts.ToUniversalTime() : ts;
        }
    }
}