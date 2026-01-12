using System;
using System.Net.Mail;
using System.Threading.Tasks;
using Pode.Utilities;
using Pode.Protocols.Common.Responses;

namespace Pode.Protocols.Smtp
{
    public class PodeSmtpResponse : PodeResponse
    {
        private string _statusDesc = string.Empty;
        public override string StatusDescription
        {
            get
            {
                if (string.IsNullOrWhiteSpace(_statusDesc) && Enum.IsDefined(typeof(SmtpStatusCode), StatusCode))
                {
                    return ((SmtpStatusCode)StatusCode).ToString();
                }

                return _statusDesc;
            }
            set => _statusDesc = value;
        }

        public PodeSmtpResponse(PodeSmtpContext context)
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