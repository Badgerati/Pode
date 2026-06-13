using System.Threading;
using Pode.Adapters.Listeners;
using Pode.Adapters;
using Pode.Utilities.Logging;

namespace Pode.Protocols.Smtp
{
    public class PodeSmtpListener : PodeListener
    {
        public PodeSmtpListener(IPodeLogger logger, CancellationToken cancellationToken = default)
            : base(PodeAdapterType.Smtp, logger, cancellationToken) { }
    }
}