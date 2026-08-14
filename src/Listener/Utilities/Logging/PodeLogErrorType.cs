using System.Collections.Generic;
using Pode.Protocols.Common.Requests;

namespace Pode.Utilities.Logging
{
    public class PodeLogErrorType : PodeLogType
    {
        public HashSet<PodeRequestExceptionKind> Kinds { get; private set; }

        public PodeLogErrorType(string name, HashSet<PodeLogLevel> levels, HashSet<PodeRequestExceptionKind> kinds, bool asUtc)
            : base(name, levels, asUtc)
        {
            Kinds = kinds;
        }

        public bool IsKindEnabled(PodeRequestExceptionKind kind)
        {
            return Kinds.Contains(kind);
        }
    }
}