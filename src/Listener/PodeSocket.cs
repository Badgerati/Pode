using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Net;
using System.Linq;
using System.Net.Sockets;
using System.Security.Authentication;
using System.Security.Cryptography.X509Certificates;
using System.Threading.Tasks;
using System.IO;
using System.Net.Http;

namespace Pode
{
    /// <summary>
    /// Represents a PodeSocket, managing communication, incoming connections, and context handling.
    /// </summary>
    public class PodeSocket : PodeProtocol, IDisposable
    {
        // Properties related to socket configuration and certificates.
        public string Name { get; private set; }
        public List<string> Hostnames { get; private set; }
        public IList<PodeEndpoint> Endpoints { get; private set; }
        public X509Certificate Certificate { get; private set; }
        public bool AllowClientCertificate { get; private set; }
        public SslProtocols Protocols { get; private set; }
        public PodeTlsMode TlsMode { get; private set; }
        public string AcknowledgeMessage { get; set; }
        public bool CRLFMessageEnd { get; set; }
        public bool DualMode { get; private set; }

        // Queue for handling connections asynchronously.
        private ConcurrentQueue<SocketAsyncEventArgs> AcceptConnections;

        // Dictionary to keep track of pending socket connections.
        private IDictionary<string, Socket> PendingSockets;

        // Listener associated with the current PodeSocket.
        private PodeListener Listener;

        // Property to determine if the socket is using SSL.
        public bool IsSsl => Certificate != default(X509Certificate);

        // Timeout for receiving data on the socket.
        private int _receiveTimeout;
        public int ReceiveTimeout
        {
            get => _receiveTimeout;
            set
            {
                _receiveTimeout = value;
                foreach (var ep in Endpoints)
                {
                    ep.ReceiveTimeout = value; // Set receive timeout on all endpoints.
                }
            }
        }

        // Property to determine if hostnames are set.
        public bool HasHostnames => Hostnames.Any();
        public string Hostname => HasHostnames ? Hostnames[0] : Endpoints[0].IPAddress.ToString();

        /// <summary>
        /// Initializes a new instance of the PodeSocket class.
        /// </summary>
        /// <param name="name">The name of the socket.</param>
        /// <param name="ipAddress">The IP addresses associated with the socket.</param>
        /// <param name="port">The port on which the socket listens.</param>
        /// <param name="protocols">The SSL protocols to be used.</param>
        /// <param name="type">The protocol type.</param>
        /// <param name="certificate">The SSL certificate (optional).</param>
        /// <param name="allowClientCertificate">Indicates whether client certificates are allowed.</param>
        /// <param name="tlsMode">The TLS mode to use.</param>
        /// <param name="dualMode">Whether to enable IPv4 and IPv6 dual mode.</param>
        public PodeSocket(string name, IPAddress[] ipAddress, int port, SslProtocols protocols, PodeProtocolType type, X509Certificate certificate = null, bool allowClientCertificate = false, PodeTlsMode tlsMode = PodeTlsMode.Implicit, bool dualMode = false)
            : base(type)
        {
            // Initialize properties.
            Name = name;
            Certificate = certificate;
            AllowClientCertificate = allowClientCertificate;
            TlsMode = tlsMode;
            Protocols = protocols;
            Hostnames = new List<string>();
            DualMode = dualMode;

            AcceptConnections = new ConcurrentQueue<SocketAsyncEventArgs>();
            PendingSockets = new Dictionary<string, Socket>();
            Endpoints = new List<PodeEndpoint>();

            // Create PodeEndpoint instances for each provided IP address.
            foreach (var addr in ipAddress)
            {
                Endpoints.Add(new PodeEndpoint(this, addr, port, dualMode));
            }
        }

        /// <summary>
        /// Binds a PodeListener to the current socket.
        /// </summary>
        /// <param name="listener">The listener to bind.</param>
        public void BindListener(PodeListener listener)
        {
            Listener = listener;
        }

        /// <summary>
        /// Binds the socket to all available endpoints.
        /// </summary>
        public void Listen()
        {
            foreach (var ep in Endpoints)
            {
                ep.Listen(); // Start listening on each endpoint.
            }
        }

        /// <summary>
        /// Starts listening for connections on all endpoints.
        /// </summary>
        public void Start()
        {
            foreach (var ep in Endpoints)
            {
                // Start each endpoint in a new task, running asynchronously.
                _ = Task.Run(() => StartEndpoint(ep), Listener.CancellationToken);
            }
        }

        /// <summary>
        /// Starts listening for connections on a specific endpoint.
        /// </summary>
        /// <param name="endpoint">The endpoint to start listening on.</param>
        private void StartEndpoint(PodeEndpoint endpoint)
        {
            // Exit if the endpoint is disposed or if cancellation is requested.
            if (endpoint.IsDisposed || Listener.CancellationToken.IsCancellationRequested)
            {
                return;
            }

            // Attempt to retrieve an available SocketAsyncEventArgs from the queue, or create a new one if unavailable.
            if (!AcceptConnections.TryDequeue(out SocketAsyncEventArgs args))
            {
                args = NewAcceptConnection();
            }

            // Set properties for accepting a connection.
            args.AcceptSocket = default;
            args.UserToken = endpoint;

            bool raised;

            try
            {
                // Start accepting a new connection.
                raised = endpoint.Accept(args);
            }
            catch (ObjectDisposedException)
            {
                return;
            }

            // If the operation completed synchronously, process the accepted connection.
            if (!raised)
            {
                ProcessAccept(args);
            }
        }

        /// <summary>
        /// Starts receiving data from an accepted socket.
        /// </summary>
        /// <param name="acceptedSocket">The accepted socket.</param>
        /// <returns>A Task representing the async operation.</returns>
        private async Task StartReceive(Socket acceptedSocket)
        {
            // Add the socket to pending sockets.
            AddPendingSocket(acceptedSocket);

            // Create the context for the connection.
            var context = new PodeContext(acceptedSocket, this, Listener);
            PodeHelpers.WriteErrorMessage($"Opening Receive", Listener, PodeLoggingLevel.Verbose, context);

            // Initialize the context.
            await context.Initialise().ConfigureAwait(false);
            if (context.IsErrored)
            {
                context.Dispose(true);
                return;
            }

            // Start receiving data.
            StartReceive(context);
        }

        /// <summary>
        /// Starts receiving data for a specific context.
        /// </summary>
        /// <param name="context">The context to start receiving for.</param>
        public void StartReceive(PodeContext context)
        {
            PodeHelpers.WriteErrorMessage($"Starting Receive", Listener, PodeLoggingLevel.Verbose, context);

            try
            {
                // Run the receive operation asynchronously in a new task.
                _ = Task.Run(async () => await context.Receive().ConfigureAwait(false), Listener.CancellationToken);
            }
            catch (OperationCanceledException ex) { PodeHelpers.WriteException(ex, Listener, PodeLoggingLevel.Verbose); } // Handle cancellation.
            catch (IOException ex) { PodeHelpers.WriteException(ex, Listener, PodeLoggingLevel.Verbose); } // Handle I/O exceptions.
            catch (AggregateException aex)
            {
                // Handle aggregated exceptions.
                PodeHelpers.HandleAggregateException(aex, Listener, PodeLoggingLevel.Error, true);
                context.Socket.Close();
            }
            catch (Exception ex)
            {
                // Handle any other exceptions.
                PodeHelpers.WriteException(ex, Listener);
                context.Socket.Close();
            }
        }

        /// <summary>
        /// Processes an accepted connection.
        /// </summary>
        /// <param name="args">The SocketAsyncEventArgs containing the connection details.</param>
        private void ProcessAccept(SocketAsyncEventArgs args)
        {
            // Get details about the accepted connection.
            var accepted = args.AcceptSocket;
            var endpoint = (PodeEndpoint)args.UserToken;
            var error = args.SocketError;

            // Start accepting new connections for the endpoint.
            StartEndpoint(endpoint);

            // If the connection was not successful or the listener is stopped, close the socket.
            if ((accepted == default(Socket)) || (error != SocketError.Success) || (!Listener.IsConnected))
            {
                if (error != SocketError.Success)
                {
                    PodeHelpers.WriteErrorMessage($"Closing accepting socket: {error}", Listener, PodeLoggingLevel.Debug);
                }

                // Close socket if it was accepted but there's an error.
                if (accepted != default(Socket))
                {
                    accepted.Close();
                }
            }
            else
            {
                // Start receiving data from the accepted connection.
                try
                {
                    _ = Task.Run(async () => await StartReceive(accepted), Listener.CancellationToken).ConfigureAwait(false);
                }
                catch (OperationCanceledException ex) { PodeHelpers.WriteException(ex, Listener, PodeLoggingLevel.Verbose); }
                catch (IOException ex) { PodeHelpers.WriteException(ex, Listener, PodeLoggingLevel.Verbose); }
                catch (AggregateException aex)
                {
                    PodeHelpers.HandleAggregateException(aex, Listener, PodeLoggingLevel.Error, true);
                }
                catch (Exception ex)
                {
                    PodeHelpers.WriteException(ex, Listener);
                }
            }

            // Add the SocketAsyncEventArgs back to the queue for reuse.
            ClearSocketAsyncEvent(args);
            AcceptConnections.Enqueue(args);
        }

        /// <summary>
        /// Handles the context, processing and disposing it if needed.
        /// </summary>
        /// <param name="context">The PodeContext representing the connection context.</param>
        public async Task HandleContext(PodeContext context)
        {
            try
            {
                // Determine if the context should be processed.
                var process = true;

                // If the context should be closed immediately, dispose it.
                if (context.CloseImmediately)
                {
                    // Check if the error is not an HttpRequestException with a PodeStatusCode 408 (Request Timeout).
                    if (!(context.Request.Error is HttpRequestException httpRequestException) ||
                        ((int)httpRequestException.Data["PodeStatusCode"] != 408))
                    {
                        PodeHelpers.WriteException(context.Request.Error, Listener);
                    }
                    context.Dispose(true);
                    process = false;
                }
                else if (context.IsWebSocket) // Handle WebSocket upgrade and context disposal.
                {
                    if (!context.IsWebSocketUpgraded)
                    {
                        await context.UpgradeWebSocket().ConfigureAwait(false);
                        process = false;
                        context.Dispose();
                    }
                    else if (!context.Request.IsProcessable)
                    {
                        process = false;
                        context.Dispose();
                    }
                }
                else if (context.IsSmtp) // Handle SMTP context disposal.
                {
                    if (!context.Request.IsProcessable)
                    {
                        process = false;
                        context.Dispose();
                    }
                }
                else if (context.IsHttp) // Handle HTTP context disposal if awaiting body.
                {
                    if (context.HttpRequest.AwaitingBody)
                    {
                        process = false;
                        context.Dispose();
                    }
                }

                // Add the context for processing.
                if (process)
                {
                    if (context.IsWebSocket)
                    {
                        PodeHelpers.WriteErrorMessage($"Received client signal", Listener, PodeLoggingLevel.Verbose, context);
                        Listener.AddClientSignal(context.SignalRequest.NewClientSignal());
                        context.Dispose();
                    }
                    else
                    {
                        PodeHelpers.WriteErrorMessage($"Received request", Listener, PodeLoggingLevel.Verbose, context);
                        Listener.AddContext(context);
                    }
                }
            }
            catch (Exception ex)
            {
                // Log any exceptions that occur while handling the context.
                PodeHelpers.WriteException(ex, Listener);
            }
        }

        /// <summary>
        /// Creates a new instance of SocketAsyncEventArgs for accepting connections.
        /// </summary>
        /// <returns>A new SocketAsyncEventArgs instance.</returns>
        private SocketAsyncEventArgs NewAcceptConnection()
        {
            lock (AcceptConnections)
            {
                var args = new SocketAsyncEventArgs();
                args.Completed += new EventHandler<SocketAsyncEventArgs>(Accept_Completed);
                return args;
            }
        }

        /// <summary>
        /// Handles the completion of an accept operation.
        /// </summary>
        /// <param name="sender">The object that triggered the event.</param>
        /// <param name="e">The SocketAsyncEventArgs with the connection details.</param>
        private void Accept_Completed(object sender, SocketAsyncEventArgs e)
        {
            ProcessAccept(e);
        }

        /// <summary>
        /// Adds a socket to the list of pending sockets.
        /// </summary>
        /// <param name="socket">The socket to add.</param>
        private void AddPendingSocket(Socket socket)
        {
            lock (PendingSockets)
            {
                var socketId = socket.GetHashCode().ToString();
                if (!PendingSockets.ContainsKey(socketId))
                {
                    PendingSockets.Add(socketId, socket);
                }
            }
        }

        /// <summary>
        /// Removes a socket from the list of pending sockets.
        /// </summary>
        /// <param name="socket">The socket to remove.</param>
        public void RemovePendingSocket(Socket socket)
        {
            lock (PendingSockets)
            {
                var socketId = socket.GetHashCode().ToString();
                if (PendingSockets.ContainsKey(socketId))
                {
                    PendingSockets.Remove(socketId);
                }
            }
        }

        /// <summary>
        /// Checks if a given hostname matches the socket's hostnames.
        /// </summary>
        /// <param name="hostname">The hostname to check.</param>
        /// <returns>True if the hostname matches, otherwise false.</returns>
        public bool CheckHostname(string hostname)
        {
            if (!HasHostnames)
            {
                return true;
            }

            var _name = hostname.Split(':')[0];
            return Hostnames.Any(x => x.Equals(_name, StringComparison.InvariantCultureIgnoreCase));
        }

        /// <summary>
        /// Disposes of the resources used by the PodeSocket.
        /// </summary>
        public void Dispose()
        {
            try
            {
                // Close all endpoints.
                foreach (var ep in Endpoints)
                {
                    ep.Dispose();
                }

                Endpoints.Clear();

                // Close all pending sockets.
                try
                {
                    var _sockets = PendingSockets.Values.ToArray();
                    for (var i = 0; i < _sockets.Length; i++)
                    {
                        CloseSocket(_sockets[i]);
                    }

                    PendingSockets.Clear();
                }
                catch (Exception ex)
                {
                    PodeHelpers.WriteException(ex, Listener);
                }
            }
            finally
            {
                GC.SuppressFinalize(this);
            }
        }

        /// <summary>
        /// Merges another PodeSocket's properties into the current socket.
        /// </summary>
        /// <param name="socket">The PodeSocket to merge from.</param>
        public void Merge(PodeSocket socket)
        {
            // Merge hostnames if present.
            if (socket.HasHostnames)
            {
                Hostnames.AddRange(socket.Hostnames);
            }

            socket.Dispose();
        }

        /// <summary>
        /// Closes a socket connection.
        /// </summary>
        /// <param name="socket">The socket to close.</param>
        public static void CloseSocket(Socket socket)
        {
            // If connected, shut down the socket.
            if (socket.Connected)
            {
                socket.Shutdown(SocketShutdown.Both);
            }

            // Dispose of the socket.
            socket.Close();
            socket.Dispose();
        }

        /// <summary>
        /// Clears the SocketAsyncEventArgs instance for reuse.
        /// </summary>
        /// <param name="e">The SocketAsyncEventArgs instance to clear.</param>
        private static void ClearSocketAsyncEvent(SocketAsyncEventArgs e)
        {
            e.AcceptSocket = default;
            e.UserToken = default;
        }

        /// <summary>
        /// Determines if the provided object is equal to the current PodeSocket.
        /// </summary>
        /// <param name="obj">The object to compare with.</param>
        /// <returns>True if equal, otherwise false.</returns>
        public new bool Equals(object obj)
        {
            var _socket = (PodeSocket)obj;
            foreach (var ep in Endpoints)
            {
                foreach (var _oEp in _socket.Endpoints)
                {
                    if (!ep.Equals(_oEp))
                    {
                        return false;
                    }
                }
            }

            return true;
        }
    }
}
