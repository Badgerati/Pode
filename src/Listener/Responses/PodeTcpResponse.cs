using Pode.Sockets.Contexts;
using Pode.Utilities;

namespace Pode.Responses
{
    public class PodeTcpResponse : PodeResponse
    {
        public PodeTcpResponse(PodeContext context)
            : base(context)
        {
            Type = PodeProtocolType.Tcp;
        }
    }
}