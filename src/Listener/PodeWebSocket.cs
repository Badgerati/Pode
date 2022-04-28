using System;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Net.WebSockets;
using _WebSocket = System.Net.WebSockets.WebSocket;
using System.IO;
using System.Threading;

namespace Pode
{
    public class PodeWebSocket : IDisposable
    {
        public string Name { get; private set; }
        public Uri URL { get; private set; }
        public bool IsConnected
        {
            get => (WebSocket != default(ClientWebSocket) && WebSocket.State == WebSocketState.Open);
        }

        private ClientWebSocket WebSocket;
        private PodeReceiver Receiver;

        public PodeWebSocket(string name, string url)
        {
            Name = name;
            URL = new Uri(url);
        }

        public void BindReceiver(PodeReceiver receiver)
        {
            Receiver = receiver;
        }

        public async void Connect()
        {
            if (IsConnected)
            {
                return;
            }

            if (WebSocket != default(ClientWebSocket))
            {
                WebSocket.Dispose();
            }

            WebSocket = new ClientWebSocket();
            await WebSocket.ConnectAsync(URL, Receiver.CancellationToken);
            await Task.Factory.StartNew(Receive, Receiver.CancellationToken, TaskCreationOptions.LongRunning, TaskScheduler.Default);
        }

        public void Reconnect(string url)
        {
            if (!string.IsNullOrWhiteSpace(url))
            {
                URL = new Uri(url);
            }

            Disconnect();
            Connect();
        }

        public async void Receive()
        {
            var result = default(WebSocketReceiveResult);
            var buffer = _WebSocket.CreateClientBuffer(1024, 1024);
            var bufferStream = new MemoryStream();

            try
            {
                while (!Receiver.CancellationToken.IsCancellationRequested && IsConnected)
                {
                    do
                    {
                        result = await WebSocket.ReceiveAsync(buffer, Receiver.CancellationToken);
                        if (result.MessageType != WebSocketMessageType.Close)
                        {
                            bufferStream.Write(buffer.ToArray(), 0, result.Count);
                        }
                    }
                    while (!result.EndOfMessage && IsConnected);

                    if (result.MessageType == WebSocketMessageType.Close)
                    {
                        break;
                    }

                    bufferStream.Position = 0;
                    Receiver.AddWebSocketRequest(new PodeWebSocketRequest(this, bufferStream));
                    bufferStream.Dispose();
                    bufferStream = new MemoryStream();
                }
            }
            catch (TaskCanceledException) {}
            catch (WebSocketException)
            {
                Dispose();
            }
            finally
            {
                bufferStream.Dispose();
                bufferStream = default(MemoryStream);
                buffer = default(ArraySegment<byte>);
            }
        }

        public void Send(string message)
        {
            if (WebSocket.State != WebSocketState.Open)
            {
                return;
            }

            WebSocket.SendAsync(new ArraySegment<byte>(Encoding.UTF8.GetBytes(message)), WebSocketMessageType.Binary, true, Receiver.CancellationToken).Wait();
        }

        public void Disconnect()
        {
            if (WebSocket == default(ClientWebSocket))
            {
                return;
            }

            if (IsConnected)
            {
                WebSocket.CloseOutputAsync(WebSocketCloseStatus.Empty, string.Empty, CancellationToken.None).Wait();
                WebSocket.CloseAsync(WebSocketCloseStatus.NormalClosure, string.Empty, CancellationToken.None).Wait();
            }

            WebSocket.Dispose();
            WebSocket = default(ClientWebSocket);
        }

        public void Dispose()
        {
            Disconnect();
        }
    }
}