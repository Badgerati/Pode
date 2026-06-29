namespace Pode.Transport.Clients
{
    public static class PodeClientFactory
    {
        public static IPodeClient Create(PodeClientType type, string server, int port, bool skipCertificateValidation = false)
        {
            IPodeClient client = default;

            switch (type)
            {
                case PodeClientType.Udp:
                    client = new PodeUdpClient(server, port);
                    break;

                case PodeClientType.Tcp:
                    client = new PodeTcpClient(server, port);
                    break;

                case PodeClientType.Tls:
                    client = new PodeTlsClient(server, port, skipCertificateValidation);
                    break;
            }

            return client;
        }
    }
}