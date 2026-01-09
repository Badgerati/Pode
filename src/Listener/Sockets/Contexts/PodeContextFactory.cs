using System;
using System.Net.Sockets;
using Pode.Connectors;
using Pode.Utilities;

namespace Pode.Sockets.Contexts
{
    public static class PodeContextFactory
    {
        public static IPodeContext Create(PodeProtocolType type, Socket socket, PodeSocket podeSocket, PodeListener listener)
        {
            switch (type)
            {
                case PodeProtocolType.Http:
                case PodeProtocolType.Ws:
                case PodeProtocolType.HttpAndWs:
                    return new PodeHttpContext(socket, podeSocket, listener);

                case PodeProtocolType.Smtp:
                    return new PodeSmtpContext(socket, podeSocket, listener);

                case PodeProtocolType.Tcp:
                    return new PodeTcpContext(socket, podeSocket, listener);

                default:
                    throw new NotSupportedException($"The protocol type '{type}' is not supported.");
            }
        }
    }
}