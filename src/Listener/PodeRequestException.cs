using System;
using System.Net.Http;

namespace Pode
{
    public class PodeRequestException : HttpRequestException
    {
        // the status code of the exception
#if NETCOREAPP2_1_OR_GREATER
        public new int StatusCode { get; private set; } = 400;
#else
        public int StatusCode { get; private set; } = 400;
#endif

        // is the exception a timeout status code (408?
        public bool IsTimeout => StatusCode == 408;

        // is the exception a client error status code (4xx)?
        public bool IsClientError => StatusCode >= 400 && StatusCode < 500;

        // is the exception a server error status code (5xx)?
        public bool IsServerError => StatusCode >= 500 && StatusCode < 600;

        // the logging level of the exception
        public PodeLoggingLevel LoggingLevel => IsClientError ? PodeLoggingLevel.Debug : PodeLoggingLevel.Error;


        // constructors
        public PodeRequestException(int statusCode = default)
            : this(string.Empty, null, statusCode) { }

        public PodeRequestException(string message, int statusCode = default)
            : this(message, null, statusCode) { }

        public PodeRequestException(Exception exception, int statusCode = default)
            : this(exception.Message, exception, statusCode) { }

        public PodeRequestException(string message, Exception innerException, int statusCode = default)
            : base(message, innerException)
        {
            if (statusCode > 0)
            {
                StatusCode = statusCode;
            }
        }

    }
}