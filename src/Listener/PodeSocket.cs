using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Net;
using System.Linq;
using System.Net.Sockets;
using System.Security.Authentication;
using System.Security.Cryptography.X509Certificates;

namespace Pode
{
    public class PodeSocket : IDisposable
    {
        public IPAddress IPAddress { get; private set; }
        public List<string> Hostnames { get; private set; }
        public int Port { get; private set; }
        public IPEndPoint Endpoint { get; private set; }
        public X509Certificate Certificate { get; private set; }
        public bool AllowClientCertificate { get; private set; }
        public SslProtocols Protocols { get; private set; }
        public Socket Socket { get; private set; }

        private ConcurrentQueue<SocketAsyncEventArgs> AcceptConnections;
        private ConcurrentQueue<SocketAsyncEventArgs> ReceiveConnections;
        private IDictionary<string, Socket> PendingSockets;

        private PodeListener Listener;

        public bool IsSsl
        {
            get => (Certificate != default(X509Certificate));
        }

        public int ReceiveTimeout
        {
            get => Socket.ReceiveTimeout;
            set => Socket.ReceiveTimeout = value;
        }

        public bool HasHostnames => Hostnames.Any();

        public PodeSocket(IPAddress ipAddress, int port, SslProtocols protocols, X509Certificate certificate = null, bool allowClientCertificate = false)
        {
            IPAddress = ipAddress;
            Port = port;
            Certificate = certificate;
            AllowClientCertificate = allowClientCertificate;
            Protocols = protocols;
            Hostnames = new List<string>();
            Endpoint = new IPEndPoint(ipAddress, port);

            AcceptConnections = new ConcurrentQueue<SocketAsyncEventArgs>();
            ReceiveConnections = new ConcurrentQueue<SocketAsyncEventArgs>();
            PendingSockets = new Dictionary<string, Socket>();

            Socket = new Socket(Endpoint.AddressFamily, SocketType.Stream, ProtocolType.Tcp);
            Socket.ReceiveTimeout = 100;
            Socket.NoDelay = true;
        }

        public void BindListener(PodeListener listener)
        {
            Listener = listener;
        }

        public void Listen()
        {
            Socket.Bind(Endpoint);
            Socket.Listen(int.MaxValue);
        }

        public void Start()
        {
            var args = default(SocketAsyncEventArgs);
            if (!AcceptConnections.TryDequeue(out args))
            {
                args = NewAcceptConnection();
            }

            args.AcceptSocket = default(Socket);
            args.UserToken = this;
            var raised = false;

            try
            {
                raised = Socket.AcceptAsync(args);
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
            var raised = false;

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
                if (Listener.ErrorLoggingEnabled)
                {
                    PodeHelpers.WriteException(ex, Listener);
                }
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
            var socket = (PodeSocket)args.UserToken;
            var error = args.SocketError;

            // start the socket again
            socket.Start();

            // close socket if not successful, or if listener is stopped - close now!
            if ((accepted == default(Socket)) || (error != SocketError.Success) || (!Listener.IsListening))
            {
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
            if ((received == default(Socket)) || (error != SocketError.Success) || (!Listener.IsListening))
            {
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
                // add context to be processed?
                // var process = true;

                // deal with context
                context.Receive();

                // if we need to exit now, dispose and exit
                // if (context.CloseImmediately)
                // {
                //     PodeHelpers.WriteException(context.Request.Error, Listener);
                //     context.Dispose(true);
                //     process = false;
                // }

                // if it's a websocket, upgrade it, then add context back for re-receiving
                // else if (context.IsWebSocket && !context.IsWebSocketUpgraded)
                // {
                //     context.UpgradeWebSocket();
                //     process = false;
                //     context.Dispose();
                // }

                // if it's an email, re-receive unless processable
                // else if (context.IsSmtp)
                // {
                //     if (!context.SmtpRequest.CanProcess)
                //     {
                //         process = false;
                //         context.Dispose();
                //     }
                // }

                // if it's http and awaiting the body
                // else if (context.IsHttp)
                // {
                //     if (context.HttpRequest.AwaitingBody)
                //     {
                //         process = false;
                //         context.Dispose();
                //     }
                // }

                // add the context for processing
                // if (process)
                // {
                //     if (context.IsWebSocket)
                //     {
                //         Listener.AddClientSignal(context.WsRequest.NewClientSignal());
                //         context.Dispose();
                //     }
                //     else
                //     {
                //         Listener.AddContext(context);
                //     }
                // }
            }
            catch (Exception ex)
            {
                PodeHelpers.WriteException(ex, Listener);
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
                    PodeHelpers.WriteException(context.Request.Error, Listener);
                    context.Dispose(true);
                    process = false;
                }

                // if it's a websocket, upgrade it, then add context back for re-receiving
                else if (context.IsWebSocket && !context.IsWebSocketUpgraded)
                {
                    context.UpgradeWebSocket();
                    process = false;
                    context.Dispose();
                }

                // if it's an email, re-receive unless processable
                else if (context.IsSmtp)
                {
                    if (!context.SmtpRequest.CanProcess)
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
                        Listener.AddClientSignal(context.WsRequest.NewClientSignal());
                        context.Dispose();
                    }
                    else
                    {
                        Listener.AddContext(context);
                    }
                }
            }
            catch (Exception ex)
            {
                PodeHelpers.WriteException(ex, Listener);
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
            var args = default(SocketAsyncEventArgs);

            if (!ReceiveConnections.TryDequeue(out args))
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
            CloseSocket(Socket);

            // close receiving contexts/sockets
            try
            {
                var _sockets = PendingSockets.Values.ToArray();
                for (var i = 0; i < _sockets.Length; i++)
                {
                    CloseSocket(_sockets[i]);
                }
            }
            catch (Exception ex)
            {
                PodeHelpers.WriteException(ex);
            }
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
            return (Endpoint.ToString() == _socket.Endpoint.ToString() && Port == _socket.Port);
        }
    }
}