using System;
using Pode.Protocols.Common.Requests;

namespace Pode.Protocols.Http
{
    public class PodeHttpRequestException : PodeRequestException
    {
        private const int ClientErrorStatusCode = 400;
        private const int TimeoutStatusCode = 408;
        private const int ServerErrorStatusCode = 500;
        private const int ProxyErrorStatusCode = 502;


        public PodeHttpRequestException(string message, int statusCode)
            : base(message, statusCode) { }

        public PodeHttpRequestException(Exception exception, int statusCode)
            : base(exception, statusCode) { }

        public PodeHttpRequestException(string message, PodeRequestStatusType statusType)
            : base(message, statusType) { }

        public PodeHttpRequestException(Exception exception, PodeRequestStatusType statusType)
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