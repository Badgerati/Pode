using System;
using Pode.Utilities.Logging;

namespace Pode.Protocols.Common.Requests
{
    public abstract class PodeRequestException : Exception
    {
        // the status code of the exception
        public int StatusCode { get; private set; } = 0;

        // the type of the exception
        public PodeRequestExceptionKind Kind { get; private set; } = PodeRequestExceptionKind.Server;

        // is the exception a timeout status code
        public bool IsTimeout => Kind == PodeRequestExceptionKind.Timeout;

        // is the exception a client error status code
        public bool IsClientError => Kind == PodeRequestExceptionKind.Client;

        // is the exception a server error status code
        public bool IsServerError => Kind == PodeRequestExceptionKind.Server;

        // the logging level of the exception
        public PodeLogLevel LoggingLevel => Kind == PodeRequestExceptionKind.Client ? PodeLogLevel.Debug : PodeLogLevel.Error;


        // constructors
        protected PodeRequestException(string message, int statusCode)
            : this(message, null, statusCode) { }

        protected PodeRequestException(Exception exception, int statusCode)
            : this(exception.Message, exception, statusCode) { }

        private PodeRequestException(string message, Exception innerException, int statusCode)
            : base(message, innerException)
        {
            if (statusCode > 0)
            {
                StatusCode = statusCode;
            }

            Kind = GetKind(StatusCode);
        }

        protected PodeRequestException(string message, PodeRequestStatusType statusType)
            : this(message, null, statusType) { }

        protected PodeRequestException(Exception exception, PodeRequestStatusType statusType)
            : this(exception.Message, exception, statusType) { }

        private PodeRequestException(string message, Exception innerException, PodeRequestStatusType statusType)
            : base(message, innerException)
        {
            StatusCode = GetStatusCode(statusType);
            Kind = GetKind(StatusCode);
        }


        protected abstract int GetStatusCode(PodeRequestStatusType statusType);
        protected abstract PodeRequestExceptionKind GetKind(int statusCode);
    }
}