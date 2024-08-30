using System;
using System.Net.Sockets;
using System.Threading;
using System.Threading.Tasks;

namespace Pode
{
    public class PodeTcpRequest : PodeRequest
    {
        public byte[] RawBody { get; private set; }

        private string _body = string.Empty;
        public string Body
        {
            get
            {
                if (RawBody != default(byte[]) && RawBody.Length > 0)
                {
                    _body = Encoding.GetString(RawBody).Trim();
                }

                return _body;
            }
        }

        public override bool CloseImmediately
        {
            get => IsDisposed || RawBody == default(byte[]) || RawBody.Length == 0;
        }

        public PodeTcpRequest(Socket socket, PodeSocket podeSocket, PodeContext context)
            : base(socket, podeSocket, context)
        {
            IsKeepAlive = true;
            Type = PodeProtocolType.Tcp;
        }

        protected override bool ValidateInput(byte[] bytes)
        {
            // we need more bytes!
            if (bytes.Length < (Context.PodeSocket.CRLFMessageEnd ? 2 : 1))
            {
                return false;
            }

            // expect to end with <CR><LF>?
            if (Context.PodeSocket.CRLFMessageEnd)
            {
                return bytes[bytes.Length - 2] == PodeHelpers.CARRIAGE_RETURN_BYTE
                    && bytes[bytes.Length - 1] == PodeHelpers.NEW_LINE_BYTE;
            }

            return true;
        }

        protected override Task<bool> Parse(byte[] bytes, CancellationToken cancellationToken)
        {
            // check if the request is cancelled
            cancellationToken.ThrowIfCancellationRequested();

            // set the raw body
            RawBody = bytes;

            // return that we're done
            return Task.FromResult(true);
        }

        public void Reset()
        {
            PodeLogger.WriteErrorMessage($"Request reset", Context.Listener, PodeLoggingLevel.Verbose, Context);
            _body = string.Empty;
            RawBody = default;
        }

        public void Close()
        {
            Context.Dispose(true);
        }

        public override void Dispose()
        {
            // Reset or clear fields
            RawBody = null;  // Set to null if it's a reference type, to avoid unexpected behavior
            _body = string.Empty;

            // Call base Dispose to ensure inherited resources are cleaned up
            base.Dispose();

            // Suppress finalization if there's a finalizer
            GC.SuppressFinalize(this);
        }
    }
}