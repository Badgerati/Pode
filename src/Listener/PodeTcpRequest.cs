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
            PodeLogger.LogMessage($"Request reset", Context.Listener, PodeLoggingLevel.Verbose, Context);
            _body = string.Empty;
            RawBody = default;
        }

        public void Close()
        {
            Context.Dispose(true);
        }

        public override void Dispose()
        {
            RawBody = default;
            _body = string.Empty;
            base.Dispose();
        }
    }
}