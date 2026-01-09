using System;
using System.Net;
using System.Security.Cryptography.X509Certificates;
using System.Threading;
using System.Threading.Tasks;
using Pode.Requests.Exceptions;
using Pode.Sockets.Contexts;
using Pode.Utilities;

namespace Pode.Requests.Strategies
{
    /// <summary>
    /// Represents an incoming request in Pode, handling different protocols, SSL/TLS upgrades, and client communication.
    /// </summary>
    public abstract class PodeRequestStrategy : PodeProtocol, IPodeRequestStrategy, IDisposable
    {
        // The request handler reference
        public PodeRequestHandler Handler { get; set; }

        // Should the request stay open for further processing?
        public bool IsKeepAlive { get; protected set; }

        /// <summary>
        /// Provides access to a buffer. The buffer is allocated only when first requested,
        /// saving memory if it is never needed.
        /// This property is virtual to allow derived classes to override the buffer allocation behavior.
        /// </summary>
        private byte[] _buffer;
        public virtual byte[] Buffer
        {
            get
            {
                if (_buffer == null)
                {
                    _buffer = new byte[PodeHelpers.MAX_BUFFER_SIZE];
                }

                return _buffer;
            }
        }

        // Flags indicating request characteristics and handling status
        public virtual bool CloseImmediately => false;
        public virtual bool IsProcessable => !CloseImmediately;
        public virtual bool IsResettable { get; protected set; } = false;
        public bool AwaitingContent { get; protected set; } = false;

        // Disposal status
        public bool IsDisposed { get; private set; }

        // Creates a new PodeRequestStrategy with the specified handler.
        protected PodeRequestStrategy() { }

        /// <summary>
        /// Parses the received bytes. This method should be implemented in derived classes.
        /// </summary>
        /// <param name="bytes">The bytes to parse.</param>
        /// <param name="cancellationToken">Token to monitor for cancellation requests.</param>
        /// <returns>A Task representing the async operation, returning true if parsing was successful.</returns>
        /// <exception cref="NotImplementedException">Thrown when called directly from PodeRequest.</exception>
        public abstract Task<bool> Parse(byte[] bytes, CancellationToken cancellationToken);

        /// <summary>
        /// Validates the incoming input bytes. Can be overridden by derived classes.
        /// </summary>
        /// <param name="bytes">The bytes to validate.</param>
        /// <returns>True if validation is successful, otherwise false.</returns>
        public abstract bool Validate(byte[] bytes);

        /// <summary>
        /// Resets the request state. Can be overridden by derived classes.
        /// </summary>
        public abstract void Reset();

        /// <summary>
        /// Gets the context associated with the request handler.
        /// </summary>
        public T GetContext<T>() where T : IPodeContext
        {
            return (T)Handler.Context;
        }

        /// <summary>
        /// Creates a PodeRequestException with the specified message and status code.
        /// </summary>
        public PodeRequestException CreateException(string message, int statusCode)
        {
            return PodeRequestExceptionFactory.Create(Type, message, statusCode);
        }

        /// <summary>
        /// Creates a PodeRequestException with the specified message and status type.
        /// </summary>
        public PodeRequestException CreateException(string message, PodeRequestStatusType statusType)
        {
            return PodeRequestExceptionFactory.Create(Type, message, statusType);
        }

        /// <summary>
        /// Creates a PodeRequestException with the specified exception and status code.
        /// </summary>
        public PodeRequestException CreateException(Exception exception, int statusCode)
        {
            return PodeRequestExceptionFactory.Create(Type, exception, statusCode);
        }

        /// <summary>
        /// Creates a PodeRequestException with the specified exception and status type.
        /// </summary>
        public PodeRequestException CreateException(Exception exception, PodeRequestStatusType statusType)
        {
            return PodeRequestExceptionFactory.Create(Type, exception, statusType);
        }

        /// <summary>
        /// Partially disposes resources used during request processing.
        /// </summary>
        public abstract void PartialDispose();

        /// <summary>
        /// Dispose managed and unmanaged resources.
        /// </summary>
        /// <param name="disposing">Indicates if disposing is called manually or by garbage collection.</param>
        public virtual void Dispose(bool disposing)
        {
            if (IsDisposed)
            {
                return;
            }

            IsDisposed = true;

            if (disposing)
            {
                PodeHelpers.WriteErrorMessage($"Request Strategy disposed", Handler.Context.Listener, PodeLoggingLevel.Verbose, Handler.Context);
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

        // Legacy references from Handler
        public X509Certificate2 ClientCertificate
        {
            get => Handler.ClientCertificate;
            set => Handler.ClientCertificate = value;
        }

        public EndPoint RemoteEndPoint => Handler.RemoteEndPoint;
        public EndPoint LocalEndPoint => Handler.LocalEndPoint;
        public string Address => Handler.Address;
        public string Scheme => Handler.Scheme;

        public async Task UpgradeToSSL(CancellationToken cancellationToken)
        {
            await Handler.UpgradeToSSL(cancellationToken);
        }
    }
}
