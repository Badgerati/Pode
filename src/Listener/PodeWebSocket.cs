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
            get => WebSocket != default(ClientWebSocket) && WebSocket.State == WebSocketState.Open;
        }

        private ClientWebSocket WebSocket;

        public PodeWebSocket(string name, string url, string contentType, PodeReceiver receiver)
        {
            Name = name;
            URL = new Uri(url);
            Receiver = receiver;

            ContentType = string.IsNullOrWhiteSpace(contentType)
                ? "application/json"
                : contentType;
        }

        public async Task Connect()
        {
            if (IsConnected)
            {
                return;
            }

            if (WebSocket != default(ClientWebSocket))
            {
                await Disconnect(PodeWebSocketCloseFrom.Client).ConfigureAwait(false);
                WebSocket.Dispose();
            }

            WebSocket = new ClientWebSocket();
            WebSocket.Options.KeepAliveInterval = TimeSpan.FromSeconds(60);

            await WebSocket.ConnectAsync(URL, Receiver.CancellationToken).ConfigureAwait(false);
            await Task.Factory.StartNew(Receive, Receiver.CancellationToken, TaskCreationOptions.LongRunning, TaskScheduler.Default).ConfigureAwait(false);
        }

        public async Task Reconnect(string url)
        {
            if (!string.IsNullOrWhiteSpace(url))
            {
                URL = new Uri(url);
            }

            await Disconnect(PodeWebSocketCloseFrom.Client).ConfigureAwait(false);
            await Connect().ConfigureAwait(false);
        }

        public async Task Receive()
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
                        result = await WebSocket.ReceiveAsync(buffer, Receiver.CancellationToken).ConfigureAwait(false);
                        if (result.MessageType != WebSocketMessageType.Close)
                        {
                            bufferStream.Write(buffer.ToArray(), 0, result.Count);
                        }
                    }
                    while (!result.EndOfMessage && IsConnected);

                    if (result.MessageType == WebSocketMessageType.Close)
                    {
                        await Disconnect(PodeWebSocketCloseFrom.Server).ConfigureAwait(false);
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
            catch (OperationCanceledException) { }
            catch (IOException) { }
            catch (WebSocketException ex)
            {
                PodeHelpers.WriteException(ex, Receiver, PodeLoggingLevel.Debug);
                Dispose();
            }
            finally
            {
                if (bufferStream != default)
                {
                    bufferStream.Dispose();
                    bufferStream = default;
                }

                buffer = default;
            }
        }

        public async Task Send(string message, WebSocketMessageType type = WebSocketMessageType.Text)
        {
            if (!IsConnected)
            {
                return;
            }

            await WebSocket.SendAsync(new ArraySegment<byte>(Encoding.UTF8.GetBytes(message)), type, true, Receiver.CancellationToken).ConfigureAwait(false);
        }

        public async Task Disconnect(PodeWebSocketCloseFrom closeFrom)
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
                    await WebSocket.CloseOutputAsync(WebSocketCloseStatus.Empty, string.Empty, CancellationToken.None).ConfigureAwait(false);
                }

                // if the server is closing, or client and netcore, then close properly
                if (closeFrom == PodeWebSocketCloseFrom.Server || !PodeHelpers.IsNetFramework)
                {
                    await WebSocket.CloseAsync(WebSocketCloseStatus.NormalClosure, string.Empty, CancellationToken.None).ConfigureAwait(false);
                }

                PodeHelpers.WriteErrorMessage($"Closed client web socket: {Name}", Receiver, PodeLoggingLevel.Verbose);
            }

            WebSocket.Dispose();
            WebSocket = default;
            PodeHelpers.WriteErrorMessage($"Disconnected client web socket: {Name}", Receiver, PodeLoggingLevel.Verbose);
        }

        public void Dispose()
        {
            Disconnect(PodeWebSocketCloseFrom.Client).Wait();
        }
    }
}