using System;
using System.Linq;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;

namespace Pode
{
    public class PodeReceiver : PodeConnector
    {
        private IDictionary<string, PodeWebSocket> WebSockets;

        public PodeItemQueue<PodeWebSocketRequest> Requests { get; private set; }

        public PodeReceiver(CancellationToken cancellationToken = default(CancellationToken))
            : base(cancellationToken)
        {
            WebSockets = new Dictionary<string, PodeWebSocket>();
            Requests = new PodeItemQueue<PodeWebSocketRequest>();
            Start();
        }

        public void ConnectWebSocket(string name, string url, string contentType)
        {
            lock (WebSockets)
            {
                if (WebSockets.ContainsKey(name))
                {
                    throw new Exception($"WebSocket connection with name {name} already defined");
                }

                var socket = new PodeWebSocket(name, url, contentType);
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

        protected override void Close()
        {
            // disconnect websockets
            PodeHelpers.WriteErrorMessage($"Closing client web sockets", this, PodeLoggingLevel.Verbose);

            foreach (var _webSocket in WebSockets.Values.ToArray())
            {
                _webSocket.Dispose();
            }

            WebSockets.Clear();
            PodeHelpers.WriteErrorMessage($"Closed client web sockets", this, PodeLoggingLevel.Verbose);

            // close existing websocket requests
            PodeHelpers.WriteErrorMessage($"Closing client web sockets requests", this, PodeLoggingLevel.Verbose);

            foreach (var _req in Requests.ToArray())
            {
                _req.Dispose();
            }

            Requests.Clear();
            PodeHelpers.WriteErrorMessage($"Closed client web requests", this, PodeLoggingLevel.Verbose);
        }
    }
}