using System;
using System.Threading;
using System.Threading.Tasks;
using Pode.Requests.Exceptions;
using Pode.Utilities;

namespace Pode.Requests.Strategies
{
    public class PodeTcpRequestStrategy : PodeRequestStrategy
    {
        public byte[] RawBody { get; private set; }

        private string _body = string.Empty;
        public string Body
        {
            get
            {
                if (RawBody != default(byte[]) && RawBody.Length > 0)
                {
                    _body = PodeHelpers.Encoding.GetString(RawBody).Trim();
                }

                return _body;
            }
        }

        public override bool CloseImmediately
        {
            get => IsDisposed || RawBody == default(byte[]) || RawBody.Length == 0;
        }

        public PodeTcpRequestStrategy()
            : base()
        {
            IsKeepAlive = true;
            IsResettable = true;
            Type = PodeProtocolType.Tcp;
        }

        public override bool Validate(byte[] bytes)
        {
            // we need more bytes!
            if (bytes.Length < (Handler.Context.PodeSocket.CRLFMessageEnd ? 2 : 1))
            {
                return false;
            }

            // expect to end with <CR><LF>?
            if (Handler.Context.PodeSocket.CRLFMessageEnd)
            {
                return bytes[bytes.Length - 2] == PodeHelpers.CARRIAGE_RETURN_BYTE
                    && bytes[bytes.Length - 1] == PodeHelpers.NEW_LINE_BYTE;
            }

            return true;
        }

        public override Task<bool> Parse(byte[] bytes, CancellationToken cancellationToken)
        {
            // check if the request is cancelled
            cancellationToken.ThrowIfCancellationRequested();

            // set the raw body
            RawBody = bytes;

            // return that we're done
            return Task.FromResult(true);
        }

        public override void Reset()
        {
            PodeHelpers.WriteErrorMessage($"Request reset", Handler.Context.Listener, PodeLoggingLevel.Verbose, Handler.Context);
            _body = string.Empty;
            RawBody = default;
        }

        public void Close()
        {
            Handler.Context.Dispose(true);
        }

        public override void PartialDispose() { }

        /// <summary>
        /// Dispose managed and unmanaged resources.
        /// </summary>
        /// <param name="disposing">Indicates if the method is called explicitly or by garbage collection.</param>
        public override void Dispose(bool disposing)
        {
            if (IsDisposed)
            {
                return;
            }

            if (disposing)
            {
                // Custom cleanup logic for PodeTcpRequest
                RawBody = default;
                _body = string.Empty;
            }

            // Call the base Dispose to clean up other resources
            base.Dispose(disposing);
        }
    }
}