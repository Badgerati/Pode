using System;
using System.Net;
using System.Net.Sockets;
using System.Threading;
using System.Threading.Tasks;

namespace Pode
{
    public class PodeEndpoint : IDisposable
    {
        public IPAddress IPAddress { get; private set; }
        public int Port { get; private set; }
        public IPEndPoint Endpoint { get; private set; }
        public Socket Socket { get; private set; }
        public PodeSocket PodeSocket { get; private set; }
        public bool DualMode { get; private set; }
        public bool IsDisposed { get; private set; }

        public int ReceiveTimeout
        {
            get => Socket.ReceiveTimeout;
            set => Socket.ReceiveTimeout = value;
        }

        public PodeEndpoint(PodeSocket socket, IPAddress ipAddress, int port, bool dualMode)
        {
            IsDisposed = false;
            PodeSocket = socket;
            IPAddress = ipAddress;
            Port = port;
            Endpoint = new IPEndPoint(ipAddress, port);

            Socket = new Socket(Endpoint.AddressFamily, SocketType.Stream, ProtocolType.Tcp)
            {
                ReceiveTimeout = 100,
                NoDelay = true
            };

            if (dualMode && Endpoint.AddressFamily == AddressFamily.InterNetworkV6)
            {
                DualMode = true;
                Socket.DualMode = true;
                Socket.SetSocketOption(SocketOptionLevel.IPv6, SocketOptionName.IPv6Only, false);
            }
            else
            {
                DualMode = false;
            }
        }

        public void Listen()
        {
            Socket.Bind(Endpoint);
            Socket.Listen(int.MaxValue);
        }

        public bool Accept(SocketAsyncEventArgs args)
        {
            return IsDisposed ? throw new ObjectDisposedException("PodeEndpoint disposed") : Socket.AcceptAsync(args);
        }

        public void Dispose()
        {
            IsDisposed = true;
            PodeSocket.CloseSocket(Socket);
            Socket = default;
        }

        public new bool Equals(object obj)
        {
            var _endpoint = (PodeEndpoint)obj;
            return Endpoint.ToString() == _endpoint.Endpoint.ToString() && Port == _endpoint.Port;
        }
    }
}