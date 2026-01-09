using System;
using System.Collections;
using System.Net.Sockets;
using System.Threading;
using System.Threading.Tasks;
using Pode.Responses;
using Pode.Connectors;
using Pode.Requests;

namespace Pode.Sockets.Contexts
{
    /// <summary>
    /// Represents the context for a Pode request, including state management, request handling, and response processing.
    /// </summary>
    public interface IPodeContext : IDisposable
    {
        // Unique identifier for the context.
        string ID { get; }

        // Represents the incoming request.
        PodeRequestHandler Request { get; }

        // Represents the outgoing response.
        PodeResponse Response { get; }

        // Listener associated with the context.
        PodeListener Listener { get; }

        // The socket for the current connection.
        Socket Socket { get; }

        // The Pode socket associated with the context.
        PodeSocket PodeSocket { get; }

        // Timestamp when the context was created.
        DateTime Timestamp { get; }

        // Data storage for request-specific metadata.
        Hashtable Data { get; }

        int DefaultErrorStatusCode { get; }

        // The name of the endpoint associated with the socket.
        string EndpointName { get; }

        // Flag indicating whether the context has been disposed.
        bool IsDisposed { get; }

        // State of the context.
        PodeContextState State { get; }

        // Determines if the context should be closed immediately.
        bool CloseImmediately { get; }

        // Determines if the connection should be kept alive.
        bool IsKeepAlive { get; }

        // Flags for different context states.
        bool IsErrored { get; }
        bool IsTimeout { get; }
        bool IsClosed { get; }
        bool IsOpened { get; }

        // Token and timer for managing request timeouts.
        CancellationTokenSource ContextTimeoutToken { get; }

        /// <summary>
        /// Initializes the request and response for the context.
        /// </summary>
        /// <returns>A Task representing the async operation.</returns>
        Task Initialise();

        /// <summary>
        /// Cancels the request timeout by disposing of the timeout timer.
        /// </summary>
        void CancelTimeout();

        /// <summary>
        /// Handles receiving data for the current request.
        /// </summary>
        /// <returns>A Task representing the async operation.</returns>
        Task Receive();

        /// <summary>
        /// Disposes of the resources used by the context, with an option to force disposal.
        /// </summary>
        /// <param name="force">Whether to force the disposal of resources.</param>
        void Dispose(bool force);
    }
}