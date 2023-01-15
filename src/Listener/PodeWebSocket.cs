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
        public PodeReceiver Receiver { get; private set; }
        public string Name { get; private set; }
        public Uri URL { get; private set; }
        public string ContentType { get; private set; }
        public bool IsConnected
        {
            get => (WebSocket != default(ClientWebSocket) && WebSocket.State == WebSocketState.Open);
        }

        private ClientWebSocket WebSocket;

        public PodeWebSocket(string name, string url, string contentType)
        {
            Name = name;
            URL = new Uri(url);

            ContentType = string.IsNullOrWhiteSpace(contentType)
                ? "application/json"
                : contentType;
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
                Disconnect(PodeWebSocketCloseFrom.Client);
                WebSocket.Dispose();
            }

            WebSocket = new ClientWebSocket();
            WebSocket.Options.KeepAliveInterval = TimeSpan.FromSeconds(60);

            await WebSocket.ConnectAsync(URL, Receiver.CancellationToken);
            await Task.Factory.StartNew(Receive, Receiver.CancellationToken, TaskCreationOptions.LongRunning, TaskScheduler.Default);
        }

        public void Reconnect(string url)
        {
            if (!string.IsNullOrWhiteSpace(url))
            {
                URL = new Uri(url);
            }

            Disconnect(PodeWebSocketCloseFrom.Client);
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
                        Disconnect(PodeWebSocketCloseFrom.Server);
                        break;
                    }

                    bufferStream.Position = 0;

                    if (bufferStream.Length > 0)
                    {
                        Receiver.AddWebSocketRequest(new PodeWebSocketRequest(this, bufferStream));
                    }

                    bufferStream.Dispose();
                    bufferStream = new MemoryStream();
                }
            }
            catch (TaskCanceledException) {}
            catch (WebSocketException ex)
            {
                PodeHelpers.WriteException(ex, Receiver, PodeLoggingLevel.Debug);
                Dispose();
            }
            finally
            {
                bufferStream.Dispose();
                bufferStream = default(MemoryStream);
                buffer = default(ArraySegment<byte>);
            }
        }

        public void Send(string message, WebSocketMessageType type = WebSocketMessageType.Text)
        {
            if (!IsConnected)
            {
                return;
            }

            WebSocket.SendAsync(new ArraySegment<byte>(Encoding.UTF8.GetBytes(message)), type, true, Receiver.CancellationToken).Wait();
        }

        public void Disconnect(PodeWebSocketCloseFrom closeFrom)
        {
            if (WebSocket == default(ClientWebSocket))
            {
                return;
            }

            if (IsConnected)
            {
                PodeHelpers.WriteErrorMessage($"Closing client web socket: {Name}", Receiver, PodeLoggingLevel.Verbose);

                // only close output in client closing
                if (closeFrom == PodeWebSocketCloseFrom.Client)
                {
                    WebSocket.CloseOutputAsync(WebSocketCloseStatus.Empty, string.Empty, CancellationToken.None).Wait();
                }

                // if the server is closing, or client and netcore, then close properly
                if (closeFrom == PodeWebSocketCloseFrom.Server || !PodeHelpers.IsNetFramework)
                {
                    WebSocket.CloseAsync(WebSocketCloseStatus.NormalClosure, string.Empty, CancellationToken.None).Wait();
                }

                PodeHelpers.WriteErrorMessage($"Closed client web socket: {Name}", Receiver, PodeLoggingLevel.Verbose);
            }

            WebSocket.Dispose();
            WebSocket = default(ClientWebSocket);
            PodeHelpers.WriteErrorMessage($"Disconnected client web socket: {Name}", Receiver, PodeLoggingLevel.Verbose);
        }

        public void Dispose()
        {
            Disconnect(PodeWebSocketCloseFrom.Client);
        }
    }
}