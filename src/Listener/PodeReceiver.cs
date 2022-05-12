using System;
using System.Linq;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;

namespace Pode
{
    public class PodeReceiver : IDisposable
    {
        public bool IsReceiving { get; private set; }
        public bool IsDisposed { get; private set; }
        public bool ErrorLoggingEnabled { get; set; }
        public string[] ErrorLoggingLevels { get; set; }
        public CancellationToken CancellationToken { get; private set; }

        private IDictionary<string, PodeWebSocket> WebSockets;

        public PodeItemQueue<PodeWebSocketRequest> Requests { get; private set; }

        public PodeReceiver(CancellationToken cancellationToken = default(CancellationToken))
        {
            CancellationToken = cancellationToken == default(CancellationToken)
                ? cancellationToken
                : (new CancellationTokenSource()).Token;

            WebSockets = new Dictionary<string, PodeWebSocket>();
            Requests = new PodeItemQueue<PodeWebSocketRequest>();

            IsReceiving = true;
            IsDisposed = false;
        }

        public void ConnectWebSocket(string name, string url)
        {
            lock (WebSockets)
            {
                if (WebSockets.ContainsKey(name))
                {
                    throw new Exception($"WebSocket connection with name {name} already defined");
                }

                var socket = new PodeWebSocket(name, url);
                socket.BindReceiver(this);
                socket.Connect();
                WebSockets.Add(name, socket);
            }
        }

        public PodeWebSocket GetWebSocket(string name)
        {
            return (WebSockets.ContainsKey(name) ? WebSockets[name] : default(PodeWebSocket));
        }

        public void DisconnectWebSocket(string name)
        {
            lock (WebSockets)
            {
                if (!WebSockets.ContainsKey(name))
                {
                    return;
                }

                WebSockets[name].Dispose();
            }
        }

        public void RemoveWebSocket(string name)
        {
            lock (WebSockets)
            {
                if (!WebSockets.ContainsKey(name))
                {
                    return;
                }

                WebSockets[name].Dispose();
                WebSockets.Remove(name);
            }
        }

        public void AddWebSocketRequest(PodeWebSocketRequest request)
        {
            Requests.Add(request);
        }

        public PodeWebSocketRequest GetWebSocketRequest(CancellationToken cancellationToken = default(CancellationToken))
        {
            return Requests.Get(cancellationToken);
        }

        public Task<PodeWebSocketRequest> GetWebSocketRequestAsync(CancellationToken cancellationToken = default(CancellationToken))
        {
            return Requests.GetAsync(cancellationToken);
        }

        public void Dispose()
        {
            // stop receiving
            IsReceiving = false;

            // disconnect websockets
            foreach (var _webSocket in WebSockets.Values)
            {
                _webSocket.Dispose();
            }

            WebSockets.Clear();

            // close existing websocket requests
            foreach (var _req in Requests.ToArray())
            {
                _req.Dispose();
            }

            Requests.Clear();

            // disposed
            IsDisposed = true;
        }
    }
}