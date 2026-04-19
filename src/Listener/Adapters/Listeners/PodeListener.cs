using System.Linq;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using Pode.Transport.Sockets;
using Pode.Utilities;
using Pode.Protocols.Common.Contexts;

namespace Pode.Adapters.Listeners
{
    public abstract class PodeListener : PodeAdapter, IPodeListener
    {
        private readonly List<PodeSocket> Sockets;
        public PodeItemQueue<PodeContext> Contexts { get; private set; }

        private int _requestTimeout = 30;
        public int RequestTimeout
        {
            get => _requestTimeout;
            set
            {
                _requestTimeout = value <= 0 ? 30 : value;
            }
        }

        private const int DEFAULT_MAX_REQUEST_BODY_SIZE = 104857600; // 100MB
        private int _requestBodySize = DEFAULT_MAX_REQUEST_BODY_SIZE;
        public int RequestBodySize
        {
            get => _requestBodySize;
            set
            {
                _requestBodySize = value <= 0 ? DEFAULT_MAX_REQUEST_BODY_SIZE : value;
            }
        }

        private bool _showServerDetails = true;
        public bool ShowServerDetails
        {
            get => _showServerDetails;
            set
            {
                _showServerDetails = value;
            }
        }

        public PodeListener(PodeAdapterType type, CancellationToken cancellationToken = default)
            : base(type, cancellationToken)
        {
            Sockets = new List<PodeSocket>();
            Contexts = new PodeItemQueue<PodeContext>();
        }

        public void Add(PodeSocket socket)
        {
            var foundSocket = Sockets.FirstOrDefault(x => x.Equals(socket));
            if (foundSocket == default(PodeSocket))
            {
                Bind(socket);
            }
            else
            {
                foundSocket.Merge(socket);
                socket = null;
            }
        }

        private void Bind(PodeSocket socket)
        {
            socket.BindListener(this);
            Sockets.Add(socket);
        }

        public PodeContext GetContext(CancellationToken cancellationToken = default)
        {
            return Contexts.Get(cancellationToken);
        }

        public Task<PodeContext> GetContextAsync(CancellationToken cancellationToken = default)
        {
            return Contexts.GetAsync(cancellationToken);
        }

        public void AddContext(PodeContext context)
        {
            Contexts.Add(context);
        }

        public void RemoveProcessingContext(PodeContext context)
        {
            Contexts.RemoveProcessing(context);
        }

        public override void Start()
        {
            foreach (var socket in Sockets)
            {
                socket.Listen();
                socket.Start();
            }

            base.Start();
        }

        protected override void Close()
        {
            // close existing contexts
            PodeHelpers.WriteErrorMessage($"Closing contexts", this, PodeLoggingLevel.Verbose);
            foreach (var _context in Contexts.ToArray())
            {
                _context.Dispose(true);
            }

            Contexts.Dispose();
            PodeHelpers.WriteErrorMessage($"Closed contexts", this, PodeLoggingLevel.Verbose);

            // shutdown the sockets
            PodeHelpers.WriteErrorMessage($"Closing sockets", this, PodeLoggingLevel.Verbose);
            for (var i = Sockets.Count - 1; i >= 0; i--)
            {
                Sockets[i].Dispose();
            }

            Sockets.Clear();
            PodeHelpers.WriteErrorMessage($"Closed sockets", this, PodeLoggingLevel.Verbose);
        }
    }
}