using System.Net.Sockets;

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
            get => (IsDisposed || RawBody == default(byte[]) || RawBody.Length == 0);
        }

        public PodeTcpRequest(Socket socket, PodeSocket podeSocket)
            : base(socket, podeSocket)
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
                return (bytes[bytes.Length - 2] == (byte)13
                    && bytes[bytes.Length - 1] == (byte)10);
            }

            return true;
        }

        protected override bool Parse(byte[] bytes)
        {
            RawBody = bytes;

            // if there are no bytes, return (0 bytes read means we can close the socket)
            if (bytes.Length == 0)
            {
                return true;
            }

            return true;
        }

        public void Reset()
        {
            PodeLogger.WriteErrorMessage($"Request reset", Context.Listener, PodeLoggingLevel.Verbose, Context);
            _body = string.Empty;
            RawBody = default(byte[]);
        }

        public void Close()
        {
            Context.Dispose(true);
        }

        public override void Dispose()
        {
            RawBody = default(byte[]);
            _body = string.Empty;
            base.Dispose();
        }
    }
}