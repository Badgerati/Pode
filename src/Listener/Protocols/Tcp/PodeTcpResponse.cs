using Pode.Utilities;
using Pode.Protocols.Common.Responses;

namespace Pode.Protocols.Tcp
{
    public class PodeTcpResponse : PodeResponse
    {
        public PodeTcpResponse(PodeTcpContext context)
            : base(context)
        {
            Type = PodeProtocolType.Tcp;
        }
    }
}