using System;
using System.Net.Sockets;

namespace Pode.Transport.Clients
{
    public class PodeUdpClient : IPodeClient
    {
        public string Server { get; private set; }
        public int Port { get; private set; }
        public bool IsConnected { get; private set; } = false;

        private UdpClient Client;

        public PodeUdpClient(string server, int port)
        {
            Server = server;
            Port = port;
            Client = new UdpClient();
        }

        public void Connect()
        {
            if (IsConnected)
            {
                return;
            }

            Client.Connect(Server, Port);
            IsConnected = true;
        }

        public void Disconnect()
        {
            IsConnected = false;
            Client?.Close();
        }

        public void Send(byte[] data)
        {
            Client?.Send(data, data.Length);
        }

        public void Dispose()
        {
            Disconnect();
            Client?.Dispose();
            Client = null;
            GC.SuppressFinalize(this);
        }
    }
}