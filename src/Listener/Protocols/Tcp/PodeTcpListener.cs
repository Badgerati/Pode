using System.Threading;
using Pode.Adapters.Listeners;
using Pode.Adapters;
using Pode.Utilities.Logging;

namespace Pode.Protocols.Tcp
{
    public class PodeTcpListener : PodeListener
    {
        public PodeTcpListener(IPodeLogger logger, CancellationToken cancellationToken = default)
            : base(PodeAdapterType.Tcp, logger, cancellationToken) { }
    }
}