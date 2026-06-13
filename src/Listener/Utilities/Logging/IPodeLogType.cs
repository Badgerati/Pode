using System.Collections.Generic;

namespace Pode.Utilities.Logging
{
    public interface IPodeLogType
    {
        string Name { get; }
        HashSet<PodeLogLevel> Levels { get; }

        bool IsLevelEnabled(PodeLogLevel level);
    }
}