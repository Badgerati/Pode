using System;
using System.IO;
using System.Net;
using System.Net.Security;
using System.Net.Sockets;
using System.Security.Authentication;
using System.Security.Cryptography.X509Certificates;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

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
        public virtual bool CloseImmediately => false;
        public virtual bool IsProcessable => true;
        // Input stream for incoming request data
        public Stream InputStream { get; private set; }
        public PodeStreamState State { get; private set; }
        public bool IsOpen => State == PodeStreamState.Open;

        // Certificate properties
        public X509Certificate Certificate { get; private set; }
        public bool AllowClientCertificate { get; private set; }
        public PodeTlsMode TlsMode { get; private set; }
        public X509Certificate2 ClientCertificate { get; set; }
        public SslPolicyErrors ClientCertificateErrors { get; set; }
        public SslProtocols Protocols { get; private set; }
        public PodeRequestException Error { get; set; }
        public bool IsAborted => Error != default(PodeRequestException);
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
        protected static readonly UTF8Encoding Encoding = new UTF8Encoding();

        // A fixed buffer used to temporarily store data read from the input stream.
        // This buffer is readonly to prevent reassignment and reduce memory allocations.
        private byte[] _buffer;

        private MemoryStream BufferStream;
        protected const int BufferSize = 16384;

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
            State = PodeStreamState.New;
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
            State = request.State;
        }

        /// <summary>
        /// Opens the socket stream, upgrading to SSL/TLS if necessary.
        /// </summary>
        /// <param name="cancellationToken">Token to monitor for cancellation requests.</param>
        /// <returns>A Task representing the async operation.</returns>
        public async Task Open(CancellationToken cancellationToken)
        {
            try
            {
                // Open the input stream for the socket
                InputStream = new NetworkStream(Socket, true);

                // Upgrade to SSL if necessary
                if (!IsSsl || TlsMode == PodeTlsMode.Explicit)
                {
                    // If not SSL, use the main network stream
                    State = PodeStreamState.Open;
                    return;
                }

                // Upgrade to SSL if necessary
                await UpgradeToSSL(cancellationToken).ConfigureAwait(false);
            }
            catch (Exception ex)
            {
                if (ex is AggregateException)
                {
                    PodeHelpers.HandleAggregateException(ex as AggregateException, Context.Listener, PodeLoggingLevel.Debug, true);
                }
                else
                {
                    PodeLogger.LogException(ex, Context.Listener, PodeLoggingLevel.Debug);
                }

                State = PodeStreamState.Error;
                Error = new PodeRequestException(ex, 502);
            }
        }


        /// <summary>
        /// Upgrades the current connection to SSL/TLS.
        /// </summary>
        /// <param name="cancellationToken">Token to monitor for cancellation requests.</param>
        /// <returns>A Task representing the async operation.</returns>
        public async Task UpgradeToSSL(CancellationToken cancellationToken)
        {
            if (SslUpgraded || IsDisposed)
            {
                State = PodeStreamState.Open;
                return; // Already upgraded
            }

            // Create an SSL stream for secure communication
            var ssl = new SslStream(InputStream, false, ValidateCertificateCallback);

            // Authenticate the SSL stream, handling cancellation and exceptions
            try
            {
                using (cancellationToken.Register(() =>
                {
                    if (!IsDisposed)
                    {
                        ssl?.Dispose();
                    }
                }))
                {

                    // Authenticate the SSL stream
                    await ssl.AuthenticateAsServerAsync(Certificate, AllowClientCertificate, Protocols, false)
                        .ConfigureAwait(false);
                }

                // Set InputStream to the upgraded SSL stream
                InputStream = ssl;
                SslUpgraded = true;
                State = PodeStreamState.Open;
            }
            catch (Exception ex) when (ex is OperationCanceledException || ex is IOException || ex is ObjectDisposedException)
            {
                PodeLogger.LogException(ex, Context.Listener, PodeLoggingLevel.Verbose);
                ssl?.Dispose();
                State = PodeStreamState.Error;
                Error = new PodeRequestException(ex, 500);
            }

            catch (AuthenticationException ex)
            {
                PodeLogger.LogException(ex, Context.Listener, PodeLoggingLevel.Debug);
                ssl?.Dispose();
                State = PodeStreamState.Error;
                Error = new PodeRequestException(ex, 400);
            }
            catch (Exception ex)
            {
                PodeLogger.LogException(ex, Context.Listener, PodeLoggingLevel.Error);
                ssl?.Dispose();
                State = PodeStreamState.Error;
                Error = new PodeRequestException(ex, 502);
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
        /// Provides access to a buffer. The buffer is allocated only when first requested,
        /// saving memory if it is never needed.
        /// This property is virtual to allow derived classes to override the buffer allocation behavior.
        /// </summary>
        protected virtual byte[] Buffer
        {
            get
            {
                if (_buffer == null)
                {
                    _buffer = new byte[BufferSize];
                }
                return _buffer;
            }
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
                if (State != PodeStreamState.Open || InputStream == null)
                {
                    return false;
                }

                Error = null;
                var localBuffer = Buffer;
                using (BufferStream = new MemoryStream())
                {
                    var close = true;

                    while (true)
                    {
                        if (InputStream == null || cancellationToken.IsCancellationRequested || IsDisposed)
                        {
                            break;
                        }

                        int read = 0;
                        try
                        {
                            // Read data from the input stream
#if NETCOREAPP2_1_OR_GREATER
                            read = await InputStream.ReadAsync(localBuffer.AsMemory(0, BufferSize), cancellationToken).ConfigureAwait(false);
#else
                            read = await InputStream.ReadAsync(localBuffer, 0, BufferSize, cancellationToken).ConfigureAwait(false);
#endif
                        }
                        catch (Exception ex) when (ex is IOException || ex is ObjectDisposedException)
                        {
                            PodeLogger.LogException(ex, Context.Listener, PodeLoggingLevel.Debug);
                            break;
                        }
                        if (read <= 0)
                        {
                            break;
                        }

#if NETCOREAPP2_1_OR_GREATER
                        await BufferStream.WriteAsync(localBuffer.AsMemory(0, read), cancellationToken).ConfigureAwait(false);
#else
                        await BufferStream.WriteAsync(localBuffer, 0, read, cancellationToken).ConfigureAwait(false);
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
            catch (PodeRequestException ex)
            {
                PodeLogger.LogException(ex, Context.Listener, PodeLoggingLevel.Error);
                Error = ex;
            }
            catch (Exception ex)
            {
                PodeLogger.LogException(ex, Context.Listener, PodeLoggingLevel.Error);
                Error = new PodeRequestException(ex, 500);
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
            // Check if the stream is open
            if (State != PodeStreamState.Open)
            {
                return string.Empty;
            }

            // Read data from the input stream until the check bytes are found
             var localBuffer = Buffer;
            using (var bufferStream = new MemoryStream())
            {
                while (true)
                {
#if NETCOREAPP2_1_OR_GREATER
                    // Read data from the input stream
                    var read = await InputStream.ReadAsync(localBuffer.AsMemory(0, BufferSize), cancellationToken).ConfigureAwait(false);
                    if (read <= 0)
                    {
                        break;
                    }

                    // Write the data to the buffer stream
                    await bufferStream.WriteAsync(localBuffer.AsMemory(0, read), cancellationToken).ConfigureAwait(false);
#else
                    // Read data from the input stream
                    var read = await InputStream.ReadAsync(localBuffer, 0, BufferSize, cancellationToken).ConfigureAwait(false);
                    if (read <= 0)
                    {
                        break;
                    }

                    // Write the data to the buffer stream
                    await bufferStream.WriteAsync(localBuffer, 0, read, cancellationToken).ConfigureAwait(false);
#endif
                    // Validate the input data
                    if (Socket.Available > 0 || !ValidateInputInternal(bufferStream.ToArray(), checkBytes))
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
            try
            {
                if (BufferStream != default(MemoryStream))
                {
                    BufferStream.Dispose();
                    BufferStream = default;
                }

                // Clear the contents of the Buffer array
                if (Buffer != null)
                {
                    Array.Clear(Buffer, 0, Buffer.Length);
                }

            }
            catch (Exception ex)
            {
                PodeLogger.LogException(ex, Context.Listener, PodeLoggingLevel.Error);
            }
        }

        /// <summary>
        /// Dispose managed and unmanaged resources.
        /// </summary>
        /// <param name="disposing">Indicates if disposing is called manually or by garbage collection.</param>
        protected virtual void Dispose(bool disposing)
        {
            if (IsDisposed) return;

            IsDisposed = true;

            if (disposing)
            {
                if (InputStream != default(Stream))
                {
                    State = PodeStreamState.Closed;
                    InputStream.Dispose();
                    InputStream = default;
                }

                if (Socket != default(Socket))
                {
                    PodeSocket.CloseSocket(Socket);
                    Socket = default;
                }

                PartialDispose();
                PodeLogger.LogMessage($"Request disposed", Context.Listener, PodeLoggingLevel.Verbose, Context);
            }
        }

        /// <summary>
        /// Disposes of the request and its associated resources.
        /// </summary>
        public void Dispose()
        {
            Dispose(true);
            GC.SuppressFinalize(this);
        }
    }
}
