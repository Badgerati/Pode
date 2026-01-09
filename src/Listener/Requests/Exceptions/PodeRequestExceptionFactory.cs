using System;
using Pode.Utilities;

namespace Pode.Requests.Exceptions
{
    public static class PodeRequestExceptionFactory
    {
        public static PodeRequestException Create(PodeProtocolType type, string message, int statusCode)
        {
            switch (type)
            {
                case PodeProtocolType.Http:
                case PodeProtocolType.HttpAndWs:
                    return new PodeHttpRequestException(message, statusCode);

                case PodeProtocolType.Smtp:
                    return new PodeSmtpRequestException(message, statusCode);

                case PodeProtocolType.Ws:
                case PodeProtocolType.Tcp:
                    return new PodeEmptyRequestException(message, statusCode);

                default:
                    throw new NotSupportedException($"The protocol type '{type}' is not supported.");
            }
        }

        public static PodeRequestException Create(PodeProtocolType type, Exception exception, int statusCode)
        {
            switch (type)
            {
                case PodeProtocolType.Http:
                case PodeProtocolType.HttpAndWs:
                    return new PodeHttpRequestException(exception, statusCode);

                case PodeProtocolType.Smtp:
                    return new PodeSmtpRequestException(exception, statusCode);

                case PodeProtocolType.Ws:
                case PodeProtocolType.Tcp:
                    return new PodeEmptyRequestException(exception, statusCode);

                default:
                    throw new NotSupportedException($"The protocol type '{type}' is not supported.");
            }
        }

        public static PodeRequestException Create(PodeProtocolType type, string message, PodeRequestStatusType statusType)
        {
            switch (type)
            {
                case PodeProtocolType.Http:
                case PodeProtocolType.HttpAndWs:
                    return new PodeHttpRequestException(message, statusType);

                case PodeProtocolType.Smtp:
                    return new PodeSmtpRequestException(message, statusType);

                case PodeProtocolType.Ws:
                case PodeProtocolType.Tcp:
                    return new PodeEmptyRequestException(message, statusType);

                default:
                    throw new NotSupportedException($"The protocol type '{type}' is not supported.");
            }
        }

        public static PodeRequestException Create(PodeProtocolType type, Exception exception, PodeRequestStatusType statusType)
        {
            switch (type)
            {
                case PodeProtocolType.Http:
                case PodeProtocolType.HttpAndWs:
                    return new PodeHttpRequestException(exception, statusType);

                case PodeProtocolType.Smtp:
                    return new PodeSmtpRequestException(exception, statusType);

                case PodeProtocolType.Ws:
                case PodeProtocolType.Tcp:
                    return new PodeEmptyRequestException(exception, statusType);

                default:
                    throw new NotSupportedException($"The protocol type '{type}' is not supported.");
            }
        }
    }
}