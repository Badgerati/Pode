using System;
using System.Linq;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using Pode.Utilities;
using Pode.Protocols.WebSockets;

namespace Pode.Adapters.Consumers
{
    public class PodeConsumer : PodeAdapter
    {
        private readonly IDictionary<string, PodeWebSocket> WebSockets;

        public PodeItemQueue<PodeWebSocketRequest> Requests { get; private set; }

        public PodeConsumer(PodeAdapterType type, CancellationToken cancellationToken = default)
            : base(type, cancellationToken)
        {
            WebSockets = new Dictionary<string, PodeWebSocket>();
            Requests = new PodeItemQueue<PodeWebSocketRequest>();
            Start();
        }

        public async Task ConnectWebSocket(string name, string url, string contentType)
        {
            var socket = default(PodeWebSocket);

            lock (WebSockets)
            {
                if (WebSockets.ContainsKey(name))
                {
                    throw new Exception($"WebSocket connection with name {name} already defined");
                }

                socket = new PodeWebSocket(name, url, contentType, this);
                WebSockets.Add(name, socket);
            }

            await socket.Connect().ConfigureAwait(false);
        }

        public PodeWebSocket GetWebSocket(string name)
        {
            return WebSockets.TryGetValue(name, out PodeWebSocket value) ? value : default;
        }

        public void DisconnectWebSocket(string name)
        {
            lock (WebSockets)
            {
                if (!WebSockets.TryGetValue(name, out PodeWebSocket value))
                {
                    return;
                }

                value.Dispose();
            }
        }

        public void RemoveWebSocket(string name)
        {
            lock (WebSockets)
            {
                if (!WebSockets.TryGetValue(name, out PodeWebSocket value))
                {
                    return;
                }

                value.Dispose();
                WebSockets.Remove(name);
            }
        }

        public void AddWebSocketRequest(PodeWebSocketRequest request)
        {
            Requests.Add(request);
        }

        public void RemoveProcessingWebSocketRequest(PodeWebSocketRequest request)
        {
            Requests.RemoveProcessing(request);
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

            Requests.Dispose();
            PodeHelpers.WriteErrorMessage($"Closed client web requests", this, PodeLoggingLevel.Verbose);
        }
    }
}