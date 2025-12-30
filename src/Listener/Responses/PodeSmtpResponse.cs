using System.Threading.Tasks;
using Pode.Sockets;
using Pode.Utilities;

namespace Pode.Responses
{
    public class PodeSmtpResponse : PodeResponse
    {
        public PodeSmtpResponse(PodeContext context)
            : base(context)
        {
            Type = PodeProtocolType.Smtp;
        }

        public override async Task Timeout()
        {
            StatusCode = 421;
            StatusDescription = "Timeout - closing connection";
            await base.Timeout().ConfigureAwait(false);
        }

        public override async Task Acknowledge(string message)
        {
            message = string.IsNullOrWhiteSpace(message)
                ? $"{Context.PodeSocket.Hostname} -- Pode Proxy Server"
                : message;

            await base.Acknowledge($"220 {message}").ConfigureAwait(false);
        }
    }
}