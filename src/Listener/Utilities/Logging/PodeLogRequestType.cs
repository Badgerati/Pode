using System.Collections.Generic;

namespace Pode.Utilities.Logging
{
    public class PodeLogRequestType : PodeLogType
    {
        public PodeLogRequestType(string name, bool asUtc)
            : base(name, new HashSet<PodeLogLevel>() { PodeLogLevel.Informational }, asUtc)
        { }
    }
}