using System;
using Pode.Utilities;

namespace Pode.Requests.Exceptions
{
    public abstract class PodeRequestException : Exception
    {
        // the status code of the exception
        public int StatusCode { get; private set; } = 0;

        // is the exception a timeout status code
        public virtual bool IsTimeout => false;

        // is the exception a client error status code
        public virtual bool IsClientError => false;

        // is the exception a server error status code
        public virtual bool IsServerError => false;

        // the logging level of the exception
        public PodeLoggingLevel LoggingLevel => IsClientError ? PodeLoggingLevel.Debug : PodeLoggingLevel.Error;


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
        }

        protected PodeRequestException(string message, PodeRequestStatusType statusType)
            : this(message, null, statusType) { }

        protected PodeRequestException(Exception exception, PodeRequestStatusType statusType)
            : this(exception.Message, exception, statusType) { }

        private PodeRequestException(string message, Exception innerException, PodeRequestStatusType statusType)
            : base(message, innerException)
        {
            StatusCode = GetStatusCode(statusType);
        }


        protected abstract int GetStatusCode(PodeRequestStatusType statusType);
    }
}