using System;

namespace Pode.Transport.Clients
{
    public interface IPodeClient : IDisposable
    {
        string Server { get; }
        int Port { get; }
        bool IsConnected { get; }

        void Connect();
        void Disconnect();
        void Send(byte[] data);
    }
}