using System;

namespace Pode.Protocols.Common.Requests
{
    public class PodeEmptyRequestException : PodeRequestException
    {
        public PodeEmptyRequestException(string message, int statusCode)
            : base(message, statusCode) { }

        public PodeEmptyRequestException(Exception exception, int statusCode)
            : base(exception, statusCode) { }

        public PodeEmptyRequestException(string message, PodeRequestStatusType statusType)
            : base(message, statusType) { }

        public PodeEmptyRequestException(Exception exception, PodeRequestStatusType statusType)
            : base(exception, statusType) { }


        protected override int GetStatusCode(PodeRequestStatusType statusType)
        {
            return 0;
        }
    }
}