using System;
using System.IO;
using System.Net;
using System.Net.Security;
using System.Net.Sockets;
using System.Security.Authentication;
using System.Security.Cryptography.X509Certificates;
using System.Threading;
using System.Threading.Tasks;
using Pode.Requests.Strategies;
using Pode.Requests.Exceptions;
using Pode.Sockets;
using Pode.Sockets.Contexts;
using Pode.Utilities;

namespace Pode.Requests
{
    /// <summary>
    /// Represents an incoming request handler in Pode, handling different protocols, SSL/TLS upgrades, and client communication.
    /// </summary>
    public class PodeRequestHandler : IDisposable
    {
        // Endpoint information for remote and local addresses
        public EndPoint RemoteEndPoint { get; private set; }
        public EndPoint LocalEndPoint { get; private set; }

        // SSL/TLS properties
        public bool IsSsl { get; private set; }
        public bool SslUpgraded => SslUpgradeStatus == PodeUpgradeStatus.Completed;
        public PodeUpgradeStatus SslUpgradeStatus { get; private set; } = PodeUpgradeStatus.None;
        public bool IsKeepAlive => Strategy?.IsKeepAlive ?? false;

        // Flags indicating request characteristics and handling status
        public bool CloseImmediately => Strategy?.CloseImmediately ?? true;
        public bool IsProcessable => Strategy?.IsProcessable ?? false;
        public bool IsResettable => Strategy?.IsResettable ?? false;
        public bool AwaitingContent => Strategy?.AwaitingContent ?? false;

        // Input stream for incoming request data
        public Stream InputStream { get; private set; }
        public PodeStreamState State { get; private set; }
        public bool IsOpen => State == PodeStreamState.Open;
        public bool IsWriteable => InputStream != null && InputStream.CanWrite;
        public bool IsReadable => InputStream != null && InputStream.CanRead;

        // Certificate properties
        public X509Certificate Certificate { get; private set; }
        public bool AllowClientCertificate { get; private set; }
        public PodeTlsMode TlsMode { get; private set; }
        public X509Certificate2 ClientCertificate { get; set; }
        public SslPolicyErrors ClientCertificateErrors { get; set; }
        public SslProtocols Protocols { get; private set; }

        // Flags indicating request processing status
        public PodeRequestException Error { get; private set; }
        public bool IsAborted => Error != default;
        public bool IsDisposed { get; private set; }

        // Address and Scheme properties for the request
        public string Address => Context.PodeSocket.HasHostnames
            ? $"{Context.PodeSocket.Hostname}:{((IPEndPoint)LocalEndPoint).Port}"
            : $"{((IPEndPoint)LocalEndPoint).Address}:{((IPEndPoint)LocalEndPoint).Port}";

        public string Scheme => (SslUpgraded ? $"{Strategy.Type}s" : $"{Strategy.Type}").ToLower();

        // Socket and Context associated with the request
        private Socket Socket;
        private IPodeRequestStrategy Strategy;
        public IPodeContext Context { get; private set; }

        // A fixed buffer used to temporarily store data read from the input stream.
        // This buffer is readonly to prevent reassignment and reduce memory allocations.
        private byte[] Buffer => Strategy?.Buffer;
        private MemoryStream BufferStream;

        /// <summary>
        /// Initializes a new instance of the PodeRequest class.
        /// </summary>
        /// <param name="socket">The socket used for communication.</param>
        /// <param name="podeSocket">The PodeSocket managing this request.</param>
        /// <param name="context">The Context associated with this request.</param>
        public PodeRequestHandler(Socket socket, PodeSocket podeSocket, IPodeContext context)
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

        public void SetStrategy(IPodeRequestStrategy strategy)
        {
            strategy.Handler = this;
            Strategy = strategy;
        }

        public T GetStrategy<T>() where T : IPodeRequestStrategy
        {
            return (T)Strategy;
        }

        public IPodeRequestStrategy GetStrategy()
        {
            return Strategy;
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
                    PodeHelpers.WriteException(ex, Context.Listener, PodeLoggingLevel.Debug);
                }

                State = PodeStreamState.Error;
                Error = Strategy.CreateException(ex.Message, PodeRequestStatusType.ProxyError);
            }
        }

        /// <summary>
        /// Upgrades the current connection to SSL/TLS.
        /// </summary>
        /// <param name="cancellationToken">Token to monitor for cancellation requests.</param>
        /// <returns>A Task representing the async operation.</returns>
        public async Task UpgradeToSSL(CancellationToken cancellationToken)
        {
            if (SslUpgradeStatus == PodeUpgradeStatus.Completed || IsDisposed)
            {
                State = PodeStreamState.Open;
                return; // Already upgraded
            }

            // Create an SSL stream for secure communication
            SslUpgradeStatus = PodeUpgradeStatus.InProgress;
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
                SslUpgradeStatus = PodeUpgradeStatus.Completed;
                State = PodeStreamState.Open;
            }
            catch (Exception ex) when (ex is OperationCanceledException || ex is IOException || ex is ObjectDisposedException)
            {
                PodeHelpers.WriteException(ex, Context.Listener, PodeLoggingLevel.Verbose);
                ssl?.Dispose();
                State = PodeStreamState.Error;
                SslUpgradeStatus = PodeUpgradeStatus.Failed;
                Error = Strategy.CreateException(ex, PodeRequestStatusType.ServerError);
            }
            catch (AuthenticationException ex)
            {
                PodeHelpers.WriteException(ex, Context.Listener, PodeLoggingLevel.Debug);
                ssl?.Dispose();
                State = PodeStreamState.Error;
                SslUpgradeStatus = PodeUpgradeStatus.Failed;
                Error = Strategy.CreateException(ex, PodeRequestStatusType.ClientError);
            }
            catch (Exception ex)
            {
                PodeHelpers.WriteException(ex, Context.Listener, PodeLoggingLevel.Error);
                ssl?.Dispose();
                State = PodeStreamState.Error;
                SslUpgradeStatus = PodeUpgradeStatus.Failed;
                Error = Strategy.CreateException(ex, PodeRequestStatusType.ProxyError);
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

                        // Read data from the input stream
#if NETCOREAPP2_1_OR_GREATER
                        int read = await InputStream.ReadAsync(localBuffer.AsMemory(0, PodeHelpers.MAX_BUFFER_SIZE), cancellationToken).ConfigureAwait(false);
#else
                        int read = await InputStream.ReadAsync(localBuffer, 0, PodeHelpers.MAX_BUFFER_SIZE, cancellationToken).ConfigureAwait(false);
#endif

                        // Check for end of stream
                        if (read <= 0)
                        {
                            break;
                        }

                        // Write the data to the buffer stream
#if NETCOREAPP2_1_OR_GREATER
                        await BufferStream.WriteAsync(localBuffer.AsMemory(0, read), cancellationToken).ConfigureAwait(false);
#else
                        await BufferStream.WriteAsync(localBuffer, 0, read, cancellationToken).ConfigureAwait(false);
#endif

                        // Validate and parse the data if available
                        if (Socket.Available > 0 || !Strategy.Validate(BufferStream.ToArray()))
                        {
                            continue;
                        }

                        if (!await Strategy.Parse(BufferStream.ToArray(), cancellationToken).ConfigureAwait(false))
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
                PodeHelpers.WriteException(ex, Context.Listener, PodeLoggingLevel.Verbose);
            }
            catch (IOException ex)
            {
                if (Context.Listener.IsConnected)
                {
                    PodeHelpers.WriteException(ex, Context.Listener, PodeLoggingLevel.Debug);
                }
            }
            catch (ObjectDisposedException ex)
            {
                if (Context.Listener.IsConnected)
                {
                    PodeHelpers.WriteException(ex, Context.Listener, PodeLoggingLevel.Debug);
                }
            }
            catch (NullReferenceException ex)
            {
                if (Context.Listener.IsConnected)
                {
                    PodeHelpers.WriteException(ex, Context.Listener, PodeLoggingLevel.Error);
                    Error = Strategy.CreateException(ex, PodeRequestStatusType.ServerError);
                }
            }
            catch (PodeRequestException ex)
            {
                PodeHelpers.WriteException(ex, Context.Listener, PodeLoggingLevel.Error);
                Error = ex;
            }
            catch (Exception ex)
            {
                PodeHelpers.WriteException(ex, Context.Listener, PodeLoggingLevel.Error);
                Error = Strategy.CreateException(ex, PodeRequestStatusType.ServerError);
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
                    var read = await InputStream.ReadAsync(localBuffer.AsMemory(0, PodeHelpers.MAX_BUFFER_SIZE), cancellationToken).ConfigureAwait(false);
                    if (read <= 0)
                    {
                        break;
                    }

                    // Write the data to the buffer stream
                    await bufferStream.WriteAsync(localBuffer.AsMemory(0, read), cancellationToken).ConfigureAwait(false);
#else
                    // Read data from the input stream
                    var read = await InputStream.ReadAsync(localBuffer, 0, PodeHelpers.MAX_BUFFER_SIZE, cancellationToken).ConfigureAwait(false);
                    if (read <= 0)
                    {
                        break;
                    }

                    // Write the data to the buffer stream
                    await bufferStream.WriteAsync(localBuffer, 0, read, cancellationToken).ConfigureAwait(false);
#endif
                    // Validate the input data
                    if (Socket.Available > 0 || !Validate(bufferStream.ToArray(), checkBytes))
                    {
                        continue;
                    }

                    break;
                }

                return PodeHelpers.Encoding.GetString(bufferStream.ToArray()).Trim();
            }
        }

        public void Timeout()
        {
            var contextId = Context?.ID;
            var message = string.IsNullOrEmpty(contextId)
                ? "The request has timed out"
                : $"The request for context '{contextId}' has timed out";

            Error = Strategy.CreateException(message, PodeRequestStatusType.Timeout);
        }

        /// <summary>
        /// Validates the input bytes against the specified check bytes.
        /// </summary>
        /// <param name="bytes">The bytes to validate.</param>
        /// <param name="checkBytes">The bytes to check against.</param>
        /// <returns>True if validation is successful, otherwise false.</returns>
        private static bool Validate(byte[] bytes, byte[] checkBytes)
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

        public void Reset()
        {
            if (!IsResettable)
            {
                return;
            }

            Strategy?.Reset();
        }

        public async Task Flush()
        {
            if (IsDisposed || !IsWriteable)
            {
                return;
            }

            await InputStream.FlushAsync().ConfigureAwait(false);
        }

        public async Task Write(FileStream stream, CancellationToken cancellationToken)
        {
            if (IsDisposed || !IsWriteable || stream == default || stream.Length == 0)
            {
                return;
            }

            await PodeHelpers.CopyFileTo(stream, InputStream, cancellationToken).ConfigureAwait(false);
        }

        public async Task Write(MemoryStream stream, CancellationToken cancellationToken)
        {
            if (IsDisposed || !IsWriteable || stream == default || stream.Length == 0)
            {
                return;
            }

            await Task.Run(() =>
            {
                stream.WriteTo(InputStream);
            }, cancellationToken).ConfigureAwait(false);
        }

        public async Task<bool> Write(byte[] buffer, CancellationToken cancellationToken, bool flush = false)
        {
            if (IsDisposed || !IsWriteable || buffer == default || buffer.Length == 0)
            {
                return false;
            }

            try
            {
#if NETCOREAPP2_1_OR_GREATER
                await InputStream.WriteAsync(buffer.AsMemory(), cancellationToken).ConfigureAwait(false);
#else
                await InputStream.WriteAsync(buffer, 0, buffer.Length, cancellationToken).ConfigureAwait(false);
#endif

                if (flush)
                {
                    await Flush().ConfigureAwait(false);
                }

                return true;
            }
            catch (OperationCanceledException)
            {
                return false;
            }
            catch (IOException)
            {
                return false;
            }
            catch (AggregateException aex)
            {
                PodeHelpers.HandleAggregateException(aex, Context.Listener);
                return false;
            }
            catch (Exception ex)
            {
                PodeHelpers.WriteException(ex, Context.Listener);
                throw;
            }
        }

        /// <summary>
        /// Partially disposes resources used during request processing.
        /// </summary>
        public void PartialDispose()
        {
            try
            {
                Strategy?.PartialDispose();

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
                PodeHelpers.WriteException(ex, Context.Listener, PodeLoggingLevel.Error);
            }
        }

        /// <summary>
        /// Dispose managed and unmanaged resources.
        /// </summary>
        /// <param name="disposing">Indicates if disposing is called manually or by garbage collection.</param>
        protected void Dispose(bool disposing)
        {
            if (IsDisposed)
            {
                return;
            }

            IsDisposed = true;

            if (disposing)
            {
                Strategy?.Dispose(disposing);

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
                PodeHelpers.WriteErrorMessage($"Request disposed", Context.Listener, PodeLoggingLevel.Verbose, Context);
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
