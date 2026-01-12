using System.Threading;
using Pode.Adapters.Listeners;
using Pode.Adapters;

namespace Pode.Protocols.Tcp
{
    public class PodeTcpListener : PodeListener
    {
        public PodeTcpListener(CancellationToken cancellationToken = default)
            : base(PodeAdapterType.Tcp, cancellationToken) { }
    }
}