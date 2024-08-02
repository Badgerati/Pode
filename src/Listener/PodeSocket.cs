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

namespace Pode
{
    public class PodeSocket : PodeProtocol, IDisposable
    {
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

        private ConcurrentQueue<SocketAsyncEventArgs> AcceptConnections;
        private ConcurrentQueue<SocketAsyncEventArgs> ReceiveConnections;
        private IDictionary<string, Socket> PendingSockets;

        private PodeListener Listener;

        public bool IsSsl
        {
            get => Certificate != default(X509Certificate);
        }

        private int _receiveTimeout;
        public int ReceiveTimeout
        {
            get => _receiveTimeout;
            set
            {
                _receiveTimeout = value;
                foreach (var ep in Endpoints)
                {
                    ep.ReceiveTimeout = value;
                }
            }
        }

        public bool HasHostnames => Hostnames.Any();

        public string Hostname
        {
            get => HasHostnames ? Hostnames[0] : Endpoints[0].IPAddress.ToString();
        }

        public PodeSocket(string name, IPAddress[] ipAddress, int port, SslProtocols protocols, PodeProtocolType type, X509Certificate certificate = null, bool allowClientCertificate = false, PodeTlsMode tlsMode = PodeTlsMode.Implicit, bool dualMode = false)
            : base(type)
        {
            Name = name;
            Certificate = certificate;
            AllowClientCertificate = allowClientCertificate;
            TlsMode = tlsMode;
            Protocols = protocols;
            Hostnames = new List<string>();
            DualMode = dualMode;

            AcceptConnections = new ConcurrentQueue<SocketAsyncEventArgs>();
            ReceiveConnections = new ConcurrentQueue<SocketAsyncEventArgs>();
            PendingSockets = new Dictionary<string, Socket>();
            Endpoints = new List<PodeEndpoint>();

            foreach (var addr in ipAddress)
            {
                Endpoints.Add(new PodeEndpoint(this, addr, port, dualMode));
            }
        }

        public void BindListener(PodeListener listener)
        {
            Listener = listener;
        }

        public void Listen()
        {
            foreach (var ep in Endpoints)
            {
                ep.Listen();
            }
        }

        public void Start()
        {
            foreach (var ep in Endpoints)
            {
                StartEndpoint(ep);
            }
        }

        private void StartEndpoint(PodeEndpoint endpoint)
        {
            if (endpoint.IsDisposed)
            {
                return;
            }

            if (!AcceptConnections.TryDequeue(out SocketAsyncEventArgs args))
            {
                args = NewAcceptConnection();
            }

            args.AcceptSocket = default;
            args.UserToken = endpoint;
            bool raised;

            try
            {
                raised = endpoint.AcceptAsync(args);
            }
            catch (ObjectDisposedException)
            {
                return;
            }

            if (!raised)
            {
                ProcessAccept(args);
            }
        }

        private void StartReceive(Socket acceptedSocket)
        {
            var context = new PodeContext(acceptedSocket, this, Listener);
            if (context.IsErrored)
            {
                context.Dispose(true);
                return;
            }

            StartReceive(context);
        }

        public void StartReceive(PodeContext context)
        {
            var args = GetReceiveConnection();
            args.AcceptSocket = context.Socket;
            args.UserToken = context;
            StartReceive(args);
        }

        private void StartReceive(SocketAsyncEventArgs args)
        {
            args.SetBuffer(new byte[0], 0, 0);
            bool raised;

            try
            {
                AddPendingSocket(args.AcceptSocket);
                raised = args.AcceptSocket.ReceiveAsync(args);
            }
            catch (ObjectDisposedException)
            {
                return;
            }
            catch (Exception ex)
            {
                PodeLogger.WriteException(ex, Listener);
                throw;
            }

            if (!raised)
            {
                ProcessReceive(args);
            }
        }

        private void ProcessAccept(SocketAsyncEventArgs args)
        {
            // get details
            var accepted = args.AcceptSocket;
            var endpoint = (PodeEndpoint)args.UserToken;
            var error = args.SocketError;

            // start the socket again
            StartEndpoint(endpoint);

            // close socket if not successful, or if listener is stopped - close now!
            if ((accepted == default(Socket)) || (error != SocketError.Success) || (!Listener.IsConnected))
            {
                if (error != SocketError.Success)
                {
                    PodeLogger.WriteErrorMessage($"Closing accepting socket: {error}", Listener, PodeLoggingLevel.Debug);
                }

                // close socket
                if (accepted != default(Socket))
                {
                    accepted.Close();
                }
            }

            // valid connection
            else
            {
                // start receive
                StartReceive(args.AcceptSocket);
            }

            // add args back to connections
            ClearSocketAsyncEvent(args);
            AcceptConnections.Enqueue(args);
        }

        private void ProcessReceive(SocketAsyncEventArgs args)
        {
            // get details
            var received = args.AcceptSocket;
            var context = (PodeContext)args.UserToken;
            var error = args.SocketError;

            // remove the socket from pending
            RemovePendingSocket(received);

            // close socket if not successful, or if listener is stopped - close now!
            if ((received == default(Socket)) || (error != SocketError.Success) || (!Listener.IsConnected))
            {
                if (error != SocketError.Success)
                {
                    PodeLogger.WriteErrorMessage($"Closing receiving socket: {error}", Listener, PodeLoggingLevel.Debug);
                }

                // close socket
                if (received != default(Socket))
                {
                    received.Close();
                }

                // close the context
                context.Dispose(true);

                // add args back to connections
                ClearSocketAsyncEvent(args);
                ReceiveConnections.Enqueue(args);
                return;
            }

            try
            {
                context.RenewTimeoutToken();
                Task.Factory.StartNew(() => context.Receive(), context.ContextTimeoutToken.Token);
            }
            catch (OperationCanceledException) { }
            catch (IOException) { }
            catch (AggregateException aex)
            {
                PodeHelpers.HandleAggregateException(aex, Listener, PodeLoggingLevel.Error, true);
            }
            catch (Exception ex)
            {
                PodeLogger.WriteException(ex, Listener);
            }

            // add args back to connections
            ClearSocketAsyncEvent(args);
            ReceiveConnections.Enqueue(args);
        }

        public void HandleContext(PodeContext context)
        {
            try
            {
                // add context to be processed?
                var process = true;

                // if we need to exit now, dispose and exit
                if (context.CloseImmediately)
                {
                    PodeLogger.WriteException(context.Request.Error, Listener);
                    context.Dispose(true);
                    process = false;
                }

                // if it's a websocket, upgrade it, then add context back for re-receiving
                else if (context.IsWebSocket)
                {
                    if (!context.IsWebSocketUpgraded)
                    {
                        context.UpgradeWebSocket();
                        process = false;
                        context.Dispose();
                    }
                    else if (!context.Request.IsProcessable)
                    {
                        process = false;
                        context.Dispose();
                    }
                }

                // if it's an email, re-receive unless processable
                else if (context.IsSmtp)
                {
                    if (!context.Request.IsProcessable)
                    {
                        process = false;
                        context.Dispose();
                    }
                }

                // if it's http and awaiting the body
                else if (context.IsHttp)
                {
                    if (context.HttpRequest.AwaitingBody)
                    {
                        process = false;
                        context.Dispose();
                    }
                }

                // add the context for processing
                if (process)
                {
                    if (context.IsWebSocket)
                    {
                        PodeLogger.WriteErrorMessage($"Received client signal", Listener, PodeLoggingLevel.Verbose, context);
                        Listener.AddClientSignal(context.SignalRequest.NewClientSignal());
                        context.Dispose();
                    }
                    else
                    {
                        PodeLogger.WriteErrorMessage($"Received request", Listener, PodeLoggingLevel.Verbose, context);
                        Listener.AddContext(context);
                    }
                }
            }
            catch (Exception ex)
            {
                PodeLogger.WriteException(ex, Listener);
            }
        }

        private SocketAsyncEventArgs NewAcceptConnection()
        {
            lock (AcceptConnections)
            {
                var args = new SocketAsyncEventArgs();
                args.Completed += new EventHandler<SocketAsyncEventArgs>(Accept_Completed);
                return args;
            }
        }

        private SocketAsyncEventArgs NewReceiveConnection()
        {
            lock (ReceiveConnections)
            {
                var args = new SocketAsyncEventArgs();
                args.Completed += new EventHandler<SocketAsyncEventArgs>(Receive_Completed);
                return args;
            }
        }

        private SocketAsyncEventArgs GetReceiveConnection()
        {
            if (!ReceiveConnections.TryDequeue(out SocketAsyncEventArgs args))
            {
                args = NewReceiveConnection();
            }

            return args;
        }

        private void Accept_Completed(object sender, SocketAsyncEventArgs e)
        {
            ProcessAccept(e);
        }

        private void Receive_Completed(object sender, SocketAsyncEventArgs e)
        {
            ProcessReceive(e);
        }

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

        private void RemovePendingSocket(Socket socket)
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

        public bool CheckHostname(string hostname)
        {
            if (!HasHostnames)
            {
                return true;
            }

            var _name = hostname.Split(':')[0];
            return Hostnames.Any(x => x.Equals(_name, StringComparison.InvariantCultureIgnoreCase));
        }

        public void Dispose()
        {
            // close endpoints
            foreach (var ep in Endpoints)
            {
                ep.Dispose();
            }

            Endpoints.Clear();

            // close receiving contexts/sockets
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
                PodeLogger.WriteException(ex, Listener);
            }
        }

        public void Merge(PodeSocket socket)
        {
            // check for extra hostnames
            if (socket.HasHostnames)
            {
                Hostnames.AddRange(socket.Hostnames);
            }

            socket.Dispose();
        }

        public static void CloseSocket(Socket socket)
        {
            // if connected, shut it down
            if (socket.Connected)
            {
                socket.Shutdown(SocketShutdown.Both);
            }

            // dispose
            socket.Close();
            socket.Dispose();
        }

        private void ClearSocketAsyncEvent(SocketAsyncEventArgs e)
        {
            e.AcceptSocket = default(Socket);
            e.UserToken = default(object);
        }

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