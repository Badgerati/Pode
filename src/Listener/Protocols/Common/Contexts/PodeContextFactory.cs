using System;
using System.Net.Sockets;
using Pode.Adapters.Listeners;
using Pode.Utilities;
using Pode.Transport.Sockets;
using Pode.Protocols.Http;
using Pode.Protocols.Smtp;
using Pode.Protocols.Tcp;

namespace Pode.Protocols.Common.Contexts
{
    public static class PodeContextFactory
    {
        public static IPodeContext Create(PodeProtocolType type, Socket socket, PodeSocket podeSocket, IPodeListener listener)
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