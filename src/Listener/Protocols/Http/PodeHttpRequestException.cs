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


        // is the exception a timeout status code
        public override bool IsTimeout => StatusCode == TimeoutStatusCode;

        // is the exception a client error status code
        public override bool IsClientError => StatusCode >= 400 && StatusCode < 500;

        // is the exception a server error status code
        public override bool IsServerError => StatusCode >= 500 && StatusCode < 600;


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
    }
}