using System;
using System.Net;
using System.Threading;
using System.Threading.Tasks;
using System.Security.Cryptography.X509Certificates;
using Pode.Utilities;
using Pode.Protocols.Common.Contexts;

namespace Pode.Protocols.Common.Requests
{
    /// <summary>
    /// Represents an incoming request in Pode, handling different protocols, SSL/TLS upgrades, and client communication.
    /// </summary>
    public interface IPodeRequestStrategy : IPodeProtocol, IDisposable
    {
        // The request handler reference
        PodeRequestHandler Handler { get; set; }

        // Should the request stay open for further processing?
        bool IsKeepAlive { get; }

        // The buffer to use for reading data
        byte[] Buffer { get; }

        // Flags indicating request characteristics and handling status
        bool CloseImmediately { get; }
        bool IsProcessable { get; }
        bool IsResettable { get; }
        bool AwaitingContent { get; }

        // Disposal status
        bool IsDisposed { get; }

        // Methods for parsing, validating, and resetting the request
        Task<bool> Parse(byte[] bytes, CancellationToken cancellationToken);
        bool Validate(byte[] bytes);
        void Reset();

        // Utility methods
        T GetContext<T>() where T : IPodeContext;
        PodeRequestException CreateException(string message, int statusCode);
        PodeRequestException CreateException(string message, PodeRequestStatusType statusType);
        PodeRequestException CreateException(Exception exception, int statusCode);
        PodeRequestException CreateException(Exception exception, PodeRequestStatusType statusType);

        // Disposal methods
        void PartialDispose();
        void Dispose(bool disposing);

        // Legacy references from Handler
        X509Certificate2 ClientCertificate { get; set; }
        EndPoint RemoteEndPoint { get; }
        EndPoint LocalEndPoint { get; }
        string Address { get; }
        string Scheme { get; }
        Task UpgradeToSSL(CancellationToken cancellationToken);
    }
}
