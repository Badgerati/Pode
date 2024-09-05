using System;
using System.IO;
using System.Net;
using System.Net.Http;
using System.Net.Security;
using System.Net.Sockets;
using System.Security.Authentication;
using System.Security.Cryptography.X509Certificates;
using System.Text;
using System.Threading.Tasks;
using System.Threading;

namespace Pode
{
    public class PodeRequest : PodeProtocol, IDisposable
    {
        public EndPoint RemoteEndPoint { get; private set; }
        public EndPoint LocalEndPoint { get; private set; }
        public bool IsSsl { get; private set; }
        public bool SslUpgraded { get; private set; }
        public bool IsKeepAlive { get; protected set; }
        public virtual bool CloseImmediately { get => false; }
        public virtual bool IsProcessable { get => true; }

        public Stream InputStream { get; private set; }
        public X509Certificate Certificate { get; private set; }
        public bool AllowClientCertificate { get; private set; }
        public PodeTlsMode TlsMode { get; private set; }
        public X509Certificate2 ClientCertificate { get; set; }
        public SslPolicyErrors ClientCertificateErrors { get; set; }
        public SslProtocols Protocols { get; private set; }
        public HttpRequestException Error { get; set; }
        public bool IsAborted => Error != default(HttpRequestException);
        public bool IsDisposed { get; private set; }

        public virtual string Address => Context.PodeSocket.HasHostnames
                ? $"{Context.PodeSocket.Hostname}:{((IPEndPoint)LocalEndPoint).Port}"
                : $"{((IPEndPoint)LocalEndPoint).Address}:{((IPEndPoint)LocalEndPoint).Port}";

        public virtual string Scheme => SslUpgraded ? $"{Context.PodeSocket.Type}s" : $"{Context.PodeSocket.Type}";

        private Socket Socket;
        protected PodeContext Context;
        protected static UTF8Encoding Encoding = new UTF8Encoding();

        private byte[] Buffer;
        private MemoryStream BufferStream;
        private const int BufferSize = 16384;

        public PodeRequest(Socket socket, PodeSocket podeSocket, PodeContext context)
        {
            Socket = socket;
            RemoteEndPoint = socket.RemoteEndPoint;
            LocalEndPoint = socket.LocalEndPoint;
            TlsMode = podeSocket.TlsMode;
            Certificate = podeSocket.Certificate;
            IsSsl = Certificate != default(X509Certificate);
            AllowClientCertificate = podeSocket.AllowClientCertificate;
            Protocols = podeSocket.Protocols;
            Context = context;
        }

        public PodeRequest(PodeRequest request)
        {
            IsSsl = request.IsSsl;
            InputStream = request.InputStream;
            IsKeepAlive = request.IsKeepAlive;
            Socket = request.Socket;
            RemoteEndPoint = Socket.RemoteEndPoint;
            LocalEndPoint = Socket.LocalEndPoint;
            Error = request.Error;
            Context = request.Context;
            Certificate = request.Certificate;
            AllowClientCertificate = request.AllowClientCertificate;
            Protocols = request.Protocols;
            TlsMode = request.TlsMode;
        }

        public async Task Open(CancellationToken cancellationToken)
        {
            // open the socket's stream
            InputStream = new NetworkStream(Socket, true);
            if (!IsSsl || TlsMode == PodeTlsMode.Explicit)
            {
                // if not ssl, use the main network stream
                return;
            }

            // otherwise, convert the stream to an ssl stream
            await UpgradeToSSL(cancellationToken).ConfigureAwait(false);
        }

        public async Task UpgradeToSSL(CancellationToken cancellationToken)
        {
            // if we've already upgraded, return
            if (SslUpgraded)
            {
                return;
            }

            // create the ssl stream
            var ssl = new SslStream(InputStream, false, new RemoteCertificateValidationCallback(ValidateCertificateCallback));

            using (cancellationToken.Register(() => ssl.Dispose()))
            {
                try
                {
                    // authenticate the stream
                    await ssl.AuthenticateAsServerAsync(Certificate, AllowClientCertificate, Protocols, false).ConfigureAwait(false);

                    // if we've upgraded, set the stream
                    InputStream = ssl;
                    SslUpgraded = true;
                }
                catch (OperationCanceledException) { }
                catch (IOException) { }
                catch (ObjectDisposedException) { }
                catch (Exception ex)
                {
                    PodeLogger.WriteException(ex, Context.Listener, PodeLoggingLevel.Error);
                    Error = new HttpRequestException(ex.Message, ex);
                    Error.Data.Add("PodeStatusCode", 502);
                }
            }
        }

        private bool ValidateCertificateCallback(object sender, X509Certificate certificate, X509Chain chain, SslPolicyErrors sslPolicyErrors)
        {
            ClientCertificateErrors = sslPolicyErrors;

            ClientCertificate = certificate == default(X509Certificate)
                ? default
                : new X509Certificate2(certificate);

            return true;
        }

        public async Task<bool> Receive(CancellationToken cancellationToken)
        {
            try
            {
                Error = default;

                Buffer = new byte[BufferSize];
                using (BufferStream = new MemoryStream())
                {
                    var close = true;

                    while (true)
                    {
                        // read the input stream
                        var read = await InputStream.ReadAsync(Buffer, 0, BufferSize, cancellationToken).ConfigureAwait(false);
                        if (read <= 0)
                        {
                            break;
                        }

                        // write the buffer to the stream
                        await BufferStream.WriteAsync(Buffer, 0, read, cancellationToken).ConfigureAwait(false);

                        // if we have more data, or the input is invalid, continue
                        if (Socket.Available > 0 || !ValidateInput(BufferStream.ToArray()))
                        {
                            continue;
                        }

                        // parse the buffer
                        if (!await Parse(BufferStream.ToArray(), cancellationToken).ConfigureAwait(false))
                        {
                            BufferStream.SetLength(0);
                            continue;
                        }

                        close = false;
                        break;
                    }

                    return close;
                }
            }
            catch (OperationCanceledException) { }
            catch (IOException) { }
            catch (HttpRequestException httpex)
            {
                PodeLogger.WriteException(httpex, Context.Listener, PodeLoggingLevel.Error);
                Error = httpex;
            }
            catch (Exception ex)
            {
                PodeLogger.WriteException(ex, Context.Listener, PodeLoggingLevel.Error);
                Error = new HttpRequestException(ex.Message, ex);
                Error.Data.Add("PodeStatusCode", 400);
            }
            finally
            {
                PartialDispose();
            }

            return false;
        }

        public async Task<string> Read(byte[] checkBytes, CancellationToken cancellationToken)
        {
            var buffer = new byte[BufferSize];
            using (var bufferStream = new MemoryStream())
            {
                while (true)
                {
                    // read the input stream
                    var read = await InputStream.ReadAsync(buffer, 0, BufferSize, cancellationToken).ConfigureAwait(false);
                    if (read <= 0)
                    {
                        break;
                    }

                    // write the buffer to the stream
                    await bufferStream.WriteAsync(buffer, 0, read, cancellationToken).ConfigureAwait(false);

                    // if we have more data, or the input is invalid, continue
                    if (Socket.Available > 0 || !ValidateInputInternal(bufferStream.ToArray(), checkBytes))
                    {
                        continue;
                    }

                    break;
                }

                return Encoding.GetString(bufferStream.ToArray()).Trim();
            }
        }

        private bool ValidateInputInternal(byte[] bytes, byte[] checkBytes)
        {
            // we need more bytes!
            if (bytes.Length == 0)
            {
                return false;
            }

            // do we have any checkBytes?
            if (checkBytes == default(byte[]) || checkBytes.Length == 0)
            {
                return true;
            }

            // check bytes against checkBytes length
            if (bytes.Length < checkBytes.Length)
            {
                return false;
            }

            // expect to end with checkBytes?
            for (var i = 0; i < checkBytes.Length; i++)
            {
                if (bytes[bytes.Length - (checkBytes.Length - i)] != checkBytes[i])
                {
                    return false;
                }
            }

            return true;
        }

        protected virtual Task<bool> Parse(byte[] bytes, CancellationToken cancellationToken)
        {
            throw new NotImplementedException();
        }

        protected virtual bool ValidateInput(byte[] bytes)
        {
            return true;
        }

        public virtual void PartialDispose()
        {
            if (BufferStream != default(MemoryStream))
            {
                BufferStream.Dispose();
                BufferStream = default;
            }

            Buffer = default;
        }

        public virtual void Dispose()
        {
            if (IsDisposed)
            {
                return;
            }

            IsDisposed = true;

            if (Socket != default(Socket))
            {
                PodeSocket.CloseSocket(Socket);
            }

            if (InputStream != default(Stream))
            {
                InputStream.Dispose();
                InputStream = default;
            }

            PartialDispose();
            PodeLogger.WriteErrorMessage($"Request disposed", Context.Listener, PodeLoggingLevel.Verbose, Context);
        }
    }
}