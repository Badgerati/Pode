using System;
using System.IO;
using System.Net.Sockets;

namespace Pode.Transport.Clients
{
    public class PodeTcpClient : IPodeClient
    {
        public string Server { get; private set; }
        public int Port { get; private set; }
        public bool IsConnected { get; private set; } = false;

        private TcpClient Client;
        protected Stream Stream;

        public PodeTcpClient(string server, int port)
        {
            Server = server;
            Port = port;
            Client = new TcpClient();
        }

        public void Connect()
        {
            if (IsConnected)
            {
                return;
            }

            Client.Connect(Server, Port);
            SetStream();
            IsConnected = true;
        }

        protected virtual void SetStream()
        {
            Stream = Client.GetStream();
        }

        public void Disconnect()
        {
            IsConnected = false;
            Client?.Close();
            Stream?.Close();
            Stream?.Dispose();
            Stream = null;
        }

        public void Send(byte[] data)
        {
            Stream?.Write(data, 0, data.Length);
            Stream?.Flush();
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