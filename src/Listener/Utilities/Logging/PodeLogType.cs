using System;
using System.Collections.Generic;

namespace Pode.Utilities.Logging
{
    public class PodeLogType
    {
        public string Name { get; private set; }
        public HashSet<PodeLogLevel> Levels { get; private set; }

        public PodeLogType(string name, HashSet<PodeLogLevel> levels)
        {
            if (string.IsNullOrEmpty(name))
            {
                throw new ArgumentException("Log type name cannot be null or empty.", nameof(name));
            }

            Name = name;
            Levels = levels;
        }

        public bool IsLevelEnabled(PodeLogLevel level)
        {
            return Levels.Contains(level);
        }
    }
}