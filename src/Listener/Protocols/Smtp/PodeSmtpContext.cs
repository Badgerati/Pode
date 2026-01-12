using System;
using System.Net.Sockets;
using System.Threading.Tasks;
using Pode.Adapters.Listeners;
using Pode.Transport.Sockets;
using Pode.Protocols.Common.Contexts;

namespace Pode.Protocols.Smtp
{
    /// <summary>
    /// Represents the context for a Pode SMTP request, including state management, request handling, and response processing.
    /// </summary>
    public class PodeSmtpContext : PodeContext, IDisposable
    {
        /// <summary>
        /// Initializes a new PodeSmtpContext with the given socket, PodeSocket, and listener.
        /// </summary>
        /// <param name="socket">The socket used for the current connection.</param>
        /// <param name="podeSocket">The PodeSocket managing this context.</param>
        /// <param name="listener">The PodeListener associated with this context.</param>
        public PodeSmtpContext(Socket socket, PodeSocket podeSocket, IPodeListener listener)
            : base(socket, podeSocket, listener)
        {
            DefaultErrorStatusCode = 554;
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
        /// Creates a new response.
        /// </summary>
        protected override void NewResponse()
        {
            Response = new PodeSmtpResponse(this);
        }

        /// <summary>
        /// Creates a new request.
        /// </summary>
        /// <returns>A Task representing the async operation.</returns>
        protected override void NewRequest()
        {
            base.NewRequest();
            Request.SetStrategy(new PodeSmtpRequestStrategy());
        }

        /// <summary>
        /// Ends the receiving process and handles the context based on whether it should be closed.
        /// </summary>
        /// <param name="close">Whether the context should be closed after receiving.</param>
        /// <returns>A Task representing the async operation.</returns>
        protected override async Task EndReceive(bool close)
        {
            if (close)
            {
                Response.StatusCode = 421;
                Response.StatusDescription = "Closing connection due to connection issue or erroneous data";
            }

            await base.EndReceive(close).ConfigureAwait(false);
        }
    }
}