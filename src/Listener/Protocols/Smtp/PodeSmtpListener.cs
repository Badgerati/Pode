using System.Threading;
using Pode.Adapters.Listeners;
using Pode.Adapters;

namespace Pode.Protocols.Smtp
{
    public class PodeSmtpListener : PodeListener
    {
        public PodeSmtpListener(CancellationToken cancellationToken = default)
            : base(PodeAdapterType.Smtp, cancellationToken) { }
    }
}