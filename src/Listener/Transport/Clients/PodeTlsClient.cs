using System.Net.Security;
using System.Security.Authentication;

namespace Pode.Transport.Clients
{
    public class PodeTlsClient : PodeTcpClient
    {
        private readonly bool SkipCertificateValidation;

        public PodeTlsClient(string server, int port, bool skipCertificateValidation = false)
            : base(server, port)
        {
            SkipCertificateValidation = skipCertificateValidation;
        }

        protected override void SetStream()
        {
            base.SetStream();

            Stream = SkipCertificateValidation
                ? new SslStream(Stream, false, (sender, certificate, chain, sslPolicyErrors) => true)
                : new SslStream(Stream, false);

#if NETCOREAPP2_1_OR_GREATER
            ((SslStream)Stream).AuthenticateAsClient(Server, null, SslProtocols.Tls12 | SslProtocols.Tls13, false);
#else
            ((SslStream)Stream).AuthenticateAsClient(Server, null, SslProtocols.Tls12, false);
#endif
        }
    }
}