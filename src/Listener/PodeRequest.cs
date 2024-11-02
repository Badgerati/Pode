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
    /// <summary>
    /// Represents an incoming request in Pode, handling different protocols, SSL/TLS upgrades, and client communication.
    /// </summary>
    public class PodeRequest : PodeProtocol, IDisposable
    {
        // Endpoint information for remote and local addresses
        public EndPoint RemoteEndPoint { get; private set; }
        public EndPoint LocalEndPoint { get; private set; }

        // SSL/TLS properties
        public bool IsSsl { get; private set; }
        public bool SslUpgraded { get; private set; }
        public bool IsKeepAlive { get; protected set; }

        // Flags indicating request characteristics and handling status
        public virtual bool CloseImmediately { get => false; }
        public virtual bool IsProcessable { get => true; }

        // Input stream for incoming request data
        public Stream InputStream { get; private set; }

        // Certificate properties
        public X509Certificate Certificate { get; private set; }
        public bool AllowClientCertificate { get; private set; }
        public PodeTlsMode TlsMode { get; private set; }
        public X509Certificate2 ClientCertificate { get; set; }
        public SslPolicyErrors ClientCertificateErrors { get; set; }
        public SslProtocols Protocols { get; private set; }

        // Error handling for request processing
        public HttpRequestException Error { get; set; }
        public bool IsAborted => Error != default(HttpRequestException);
        public bool IsDisposed { get; private set; }

        // Address and Scheme properties for the request
        public virtual string Address => Context.PodeSocket.HasHostnames
                ? $"{Context.PodeSocket.Hostname}:{((IPEndPoint)LocalEndPoint).Port}"
                : $"{((IPEndPoint)LocalEndPoint).Address}:{((IPEndPoint)LocalEndPoint).Port}";

        public virtual string Scheme => SslUpgraded ? $"{Context.PodeSocket.Type}s" : $"{Context.PodeSocket.Type}";

        // Socket and Context associated with the request
        private Socket Socket;
        protected PodeContext Context;

        // Encoding and buffer for handling incoming data
        protected static UTF8Encoding Encoding = new UTF8Encoding();
        private byte[] Buffer;
        private MemoryStream BufferStream;
        private const int BufferSize = 16384;

        /// <summary>
        /// Initializes a new instance of the PodeRequest class.
        /// </summary>
        /// <param name="socket">The socket used for communication.</param>
        /// <param name="podeSocket">The PodeSocket managing this request.</param>
        /// <param name="context">The PodeContext associated with this request.</param>
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

        /// <summary>
        /// Initializes a new instance of the PodeRequest class by copying properties from another request.
        /// </summary>
        /// <param name="request">The PodeRequest to copy properties from.</param>
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

        /// <summary>
        /// Opens the socket stream, upgrading to SSL/TLS if necessary.
        /// </summary>
        /// <param name="cancellationToken">Token to monitor for cancellation requests.</param>
        /// <returns>A Task representing the async operation.</returns>
        public async Task Open(CancellationToken cancellationToken)
        {
            InputStream = new NetworkStream(Socket, true);
            if (!IsSsl || TlsMode == PodeTlsMode.Explicit)
            {
                // If not SSL, use the main network stream
                return;
            }

            // Upgrade to SSL if necessary
            await UpgradeToSSL(cancellationToken).ConfigureAwait(false);
        }

        /// <summary>
        /// Upgrades the current connection to SSL/TLS.
        /// </summary>
        /// <param name="cancellationToken">Token to monitor for cancellation requests.</param>
        /// <returns>A Task representing the async operation.</returns>
        public async Task UpgradeToSSL(CancellationToken cancellationToken)
        {
            if (SslUpgraded)
            {
                return; // Already upgraded
            }

            // Create an SSL stream for secure communication
            var ssl = new SslStream(InputStream, false, new RemoteCertificateValidationCallback(ValidateCertificateCallback));

            using (cancellationToken.Register(() => ssl.Dispose()))
            {
                try
                {
                    // Authenticate the SSL stream
                    await ssl.AuthenticateAsServerAsync(Certificate, AllowClientCertificate, Protocols, false).ConfigureAwait(false);

                    // Set InputStream to the upgraded SSL stream
                    InputStream = ssl;
                    SslUpgraded = true;
                }
                catch (OperationCanceledException ex) { PodeLogger.LogException(ex, Context.Listener, PodeLoggingLevel.Verbose); }
                catch (IOException ex) { PodeLogger.LogException(ex, Context.Listener, PodeLoggingLevel.Verbose); }
                catch (ObjectDisposedException ex) { PodeLogger.LogException(ex, Context.Listener, PodeLoggingLevel.Verbose); }
                catch (Exception ex)
                {
                    PodeLogger.LogException(ex, Context.Listener, PodeLoggingLevel.Error);
                    Error = new HttpRequestException(ex.Message, ex);
                    Error.Data.Add("PodeStatusCode", 502);
                }
            }
        }

        /// <summary>
        /// Callback to validate client certificates during the SSL handshake.
        /// </summary>
        /// <param name="sender">The sender of the callback.</param>
        /// <param name="certificate">The client certificate to validate.</param>
        /// <param name="chain">The chain of the certificate.</param>
        /// <param name="sslPolicyErrors">Any SSL policy errors found.</param>
        /// <returns>True if the certificate is valid; otherwise, false.</returns>
        private bool ValidateCertificateCallback(object sender, X509Certificate certificate, X509Chain chain, SslPolicyErrors sslPolicyErrors)
        {
            ClientCertificateErrors = sslPolicyErrors;

            ClientCertificate = certificate == default(X509Certificate)
                ? default
                : new X509Certificate2(certificate);

            return true;
        }

        /// <summary>
        /// Receives data from the input stream and processes it.
        /// </summary>
        /// <param name="cancellationToken">Token to monitor for cancellation requests.</param>
        /// <returns>A Task representing the async operation, with a boolean indicating whether the connection should be closed.</returns>
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
#if NETCOREAPP2_1_OR_GREATER
                        // Read data from the input stream
                        var read = await InputStream.ReadAsync(Buffer.AsMemory(0, BufferSize), cancellationToken).ConfigureAwait(false);
                        if (read <= 0)
                        {
                            break;
                        }

                        // Write the data to the buffer stream
                        await BufferStream.WriteAsync(Buffer.AsMemory(0, read), cancellationToken).ConfigureAwait(false);
#else
                        // Read data from the input stream
                        var read = await InputStream.ReadAsync(Buffer, 0, BufferSize, cancellationToken).ConfigureAwait(false);
                        if (read <= 0)
                        {
                            break;
                        }

                        // Write the data to the buffer stream
                        await BufferStream.WriteAsync(Buffer, 0, read, cancellationToken).ConfigureAwait(false);
#endif

                        // Validate and parse the data if available
                        if (Socket.Available > 0 || !ValidateInput(BufferStream.ToArray()))
                        {
                            continue;
                        }

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
            catch (OperationCanceledException ex)
            {
                PodeLogger.LogException(ex, Context.Listener, PodeLoggingLevel.Verbose);
            }
            catch (IOException ex)
            {
                PodeLogger.LogException(ex, Context.Listener, PodeLoggingLevel.Verbose);
            }
            catch (HttpRequestException httpex)
            {
                PodeLogger.LogException(httpex, Context.Listener, PodeLoggingLevel.Error);
                Error = httpex;
            }
            catch (Exception ex)
            {
                PodeLogger.LogException(ex, Context.Listener, PodeLoggingLevel.Error);
                Error = new HttpRequestException(ex.Message, ex);
                Error.Data.Add("PodeStatusCode", 400);
            }
            finally
            {
                PartialDispose();
            }

            return false;
        }

        /// <summary>
        /// Reads data from the input stream until the specified bytes are found.
        /// </summary>
        /// <param name="checkBytes">The bytes to check for in the input stream.</param>
        /// <param name="cancellationToken">Token to monitor for cancellation requests.</param>
        /// <returns>A Task representing the async operation, with a string containing the data read.</returns>
        public async Task<string> Read(byte[] checkBytes, CancellationToken cancellationToken)
        {
            var buffer = new byte[BufferSize];
            using (var bufferStream = new MemoryStream())
            {
                while (true)
                {
#if NETCOREAPP2_1_OR_GREATER
                    // Read data from the input stream
                    var read = await InputStream.ReadAsync(buffer.AsMemory(0, BufferSize), cancellationToken).ConfigureAwait(false);
                    if (read <= 0)
                    {
                        break;
                    }

                    // Write the data to the buffer stream
                    await bufferStream.WriteAsync(buffer.AsMemory(0, read), cancellationToken).ConfigureAwait(false);
#else
                    // Read data from the input stream
                    var read = await InputStream.ReadAsync(buffer, 0, BufferSize, cancellationToken).ConfigureAwait(false);
                    if (read <= 0)
                    {
                        break;
                    }

                    // Write the data to the buffer stream
                    await bufferStream.WriteAsync(buffer, 0, read, cancellationToken).ConfigureAwait(false);
#endif
                    // Validate the input data
                    if (Socket.Available > 0 || !PodeRequest.ValidateInputInternal(bufferStream.ToArray(), checkBytes))
                    {
                        continue;
                    }

                    break;
                }

                return Encoding.GetString(bufferStream.ToArray()).Trim();
            }
        }

        /// <summary>
        /// Validates the input bytes against the specified check bytes.
        /// </summary>
        /// <param name="bytes">The bytes to validate.</param>
        /// <param name="checkBytes">The bytes to check against.</param>
        /// <returns>True if validation is successful, otherwise false.</returns>
        private static bool ValidateInputInternal(byte[] bytes, byte[] checkBytes)
        {
            if (bytes.Length == 0)
            {
                return false; // Need more bytes
            }

            if (checkBytes == default(byte[]) || checkBytes.Length == 0)
            {
                return true; // No specific bytes to check
            }

            if (bytes.Length < checkBytes.Length)
            {
                return false; // Not enough bytes
            }

            // Check if the input ends with checkBytes
            for (var i = 0; i < checkBytes.Length; i++)
            {
                if (bytes[bytes.Length - (checkBytes.Length - i)] != checkBytes[i])
                {
                    return false;
                }
            }

            return true;
        }

        /// <summary>
        /// Parses the received bytes. This method should be implemented in derived classes.
        /// </summary>
        /// <param name="bytes">The bytes to parse.</param>
        /// <param name="cancellationToken">Token to monitor for cancellation requests.</param>
        /// <returns>A Task representing the async operation, returning true if parsing was successful.</returns>
        /// <exception cref="NotImplementedException">Thrown when called directly from PodeRequest.</exception>
        protected virtual Task<bool> Parse(byte[] bytes, CancellationToken cancellationToken)
        {
            throw new NotImplementedException();
        }

        /// <summary>
        /// Validates the incoming input bytes. Can be overridden by derived classes.
        /// </summary>
        /// <param name="bytes">The bytes to validate.</param>
        /// <returns>True if validation is successful, otherwise false.</returns>
        protected virtual bool ValidateInput(byte[] bytes)
        {
            return true;
        }

        /// <summary>
        /// Partially disposes resources used during request processing.
        /// </summary>
        public virtual void PartialDispose()
        {
            if (BufferStream != default(MemoryStream))
            {
                BufferStream.Dispose();
                BufferStream = default;
            }

            Buffer = default;
        }

        /// <summary>
        /// Disposes of the request and its associated resources.
        /// </summary>
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
            PodeLogger.LogMessage($"Request disposed", Context.Listener, PodeLoggingLevel.Verbose, Context);
        }
    }
}
