using System;
using Pode.Protocols.Common.Requests;

namespace Pode.Protocols.Smtp
{
    public class PodeSmtpRequestException : PodeRequestException
    {
        private const int ClientErrorStatusCode = 451;
        private const int TimeoutStatusCode = 450;
        private const int ServerErrorStatusCode = 554;
        private const int ProxyErrorStatusCode = 554;


        public PodeSmtpRequestException(string message, int statusCode)
            : base(message, statusCode) { }

        public PodeSmtpRequestException(Exception exception, int statusCode)
            : base(exception, statusCode) { }

        public PodeSmtpRequestException(string message, PodeRequestStatusType statusType)
            : base(message, statusType) { }

        public PodeSmtpRequestException(Exception exception, PodeRequestStatusType statusType)
            : base(exception, statusType) { }


        protected override int GetStatusCode(PodeRequestStatusType statusType)
        {
            switch (statusType)
            {
                case PodeRequestStatusType.ClientError:
                    return ClientErrorStatusCode;
                case PodeRequestStatusType.Timeout:
                    return TimeoutStatusCode;
                case PodeRequestStatusType.ServerError:
                    return ServerErrorStatusCode;
                case PodeRequestStatusType.ProxyError:
                    return ProxyErrorStatusCode;
                default:
                    throw new ArgumentOutOfRangeException(nameof(statusType), statusType, null);
            }
        }

        protected override PodeRequestExceptionKind GetKind(int statusCode)
        {
            if (statusCode == TimeoutStatusCode)
            {
                return PodeRequestExceptionKind.Timeout;
            }

            if (statusCode >= 400 && statusCode < 500)
            {
                return PodeRequestExceptionKind.Client;
            }

            return PodeRequestExceptionKind.Server;
        }
    }
}