using System;
using System.Net.Sockets;
using System.Threading.Tasks;
using Pode.Responses;
using Pode.Connectors;
using Pode.Requests.Strategies;

namespace Pode.Sockets.Contexts
{
    /// <summary>
    /// Represents the context for a Pode request, including state management, request handling, and response processing.
    /// </summary>
    public class PodeTcpContext : PodeContext, IDisposable
    {
        /// <summary>
        /// Initializes a new PodeTcpContext with the given socket, PodeSocket, and listener.
        /// </summary>
        /// <param name="socket">The socket used for the current connection.</param>
        /// <param name="podeSocket">The PodeSocket managing this context.</param>
        /// <param name="listener">The PodeListener associated with this context.</param>
        public PodeTcpContext(Socket socket, PodeSocket podeSocket, PodeListener listener)
            : base(socket, podeSocket, listener)
        {
        }

        /// <summary>
        /// Initializes the request and response for the context.
        /// </summary>
        /// <returns>A Task representing the async operation.</returns>
        public override async Task Initialise()
        {
            await base.Initialise().ConfigureAwait(false);

            if (IsOpened)
            {
                await Response.Acknowledge(PodeSocket.AcknowledgeMessage).ConfigureAwait(false);
            }
        }

        /// <summary>
        /// Creates a new response object.
        /// </summary>
        protected override void NewResponse()
        {
            Response = new PodeTcpResponse(this);
        }

        /// <summary>
        /// Creates a new request object.
        /// </summary>
        /// <returns>A Task representing the async operation.</returns>
        protected override void NewRequest()
        {
            base.NewRequest();
            Request.SetStrategy(new PodeTcpRequestStrategy());
        }
    }
}