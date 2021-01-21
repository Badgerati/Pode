using System;
using System.Collections.Generic;
using System.IO;
using System.Net;
using System.Net.Http;
using System.Net.Security;
using System.Net.Sockets;
using System.Security.Authentication;
using System.Security.Cryptography.X509Certificates;
using System.Text;
using System.Linq;
using System.Threading.Tasks;

namespace Pode
{
    public class PodeRequest : IDisposable
    {
        public EndPoint RemoteEndPoint { get; private set; }
        public bool IsSsl { get; private set; }
        public bool IsKeepAlive { get; protected set; }
        public virtual bool CloseImmediately { get => false; }

        public Stream InputStream { get; private set; }
        public X509Certificate2 ClientCertificate { get; private set; }
        public SslPolicyErrors ClientCertificateErrors { get; private set; }
        public HttpRequestException Error { get; private set; }

        private Socket Socket;
        protected PodeContext Context;
        protected static UTF8Encoding Encoding = new UTF8Encoding();

        public PodeRequest(Socket socket)
        {
            Socket = socket;
            RemoteEndPoint = socket.RemoteEndPoint;
        }

        public PodeRequest(PodeRequest request)
        {
            IsSsl = request.IsSsl;
            InputStream = request.InputStream;
            IsKeepAlive = request.IsKeepAlive;
            Socket = request.Socket;
            RemoteEndPoint = Socket.RemoteEndPoint;
            Error = request.Error;
            Context = request.Context;
        }

        public void Open(X509Certificate certificate, SslProtocols protocols, bool allowClientCertificate)
        {
            // ssl or not?
            IsSsl = (certificate != default(X509Certificate));

            // open the socket's stream
            InputStream = new NetworkStream(Socket, true);
            if (!IsSsl)
            {
                // if not ssl, use the main network stream
                return;
            }

            // otherwise, convert the stream to an ssl stream
            var ssl = new SslStream(InputStream, false, new RemoteCertificateValidationCallback(ValidateCertificateCallback));
            ssl.AuthenticateAsServerAsync(certificate, allowClientCertificate, protocols, false).Wait(Context.Listener.CancellationToken);
            InputStream = ssl;
        }

        private bool ValidateCertificateCallback(object sender, X509Certificate certificate, X509Chain chain, SslPolicyErrors sslPolicyErrors)
        {
            ClientCertificateErrors = sslPolicyErrors;

            ClientCertificate = certificate == default(X509Certificate)
                ? default(X509Certificate2)
                : new X509Certificate2(certificate);

            return true;
        }

        private byte[] _buffer;
        private MemoryStream _bufferStream;
        private const int _bufferSize = 16384;
        protected AsyncCallback AsyncReadCallback;

        private void ReadCallback(IAsyncResult ares)
        {
            var req = (PodeRequest)ares.AsyncState;

            var read = InputStream.EndRead(ares);
            if (read == 0)
            {
                _bufferStream.Dispose();
                Context.EndReceive(true);
                return;
            }

            if (read > 0)
            {
                _bufferStream.Write(_buffer, 0, read);
            }

            if (Socket.Available > 0 || !ValidateInput(_bufferStream.ToArray()))
            {
                BeginRead();
            }
            else
            {
                var bytes = _bufferStream.ToArray();
                if (!Parse(bytes))
                {
                    bytes = default(byte[]);
                    _bufferStream.Dispose();
                    _bufferStream = new MemoryStream();
                    BeginRead();
                }
                else
                {
                    _bufferStream.Dispose();
                    bytes = default(byte[]);
                    Context.EndReceive(false);
                }
            }
        }

        protected void BeginRead()
        {
            if (AsyncReadCallback == null)
            {
                AsyncReadCallback = new AsyncCallback(ReadCallback);
            }

            InputStream.BeginRead(_buffer, 0, _bufferSize, AsyncReadCallback, this);
        }

        public void Receive()
        {
            try
            {
                Error = default(HttpRequestException);

                _buffer = new byte[_bufferSize];
                _bufferStream = new MemoryStream();
                BeginRead();
            }
            catch (HttpRequestException httpex)
            {
                Error = httpex;
            }
            catch (Exception ex)
            {
                PodeHelpers.WriteException(ex);
                Error = new HttpRequestException(ex.Message, ex);
                Error.Data.Add("PodeStatusCode", 400);
            }
        }

        protected virtual bool Parse(byte[] bytes)
        {
            throw new NotImplementedException();
        }

        protected virtual bool ValidateInput(byte[] bytes)
        {
            return true;
        }

        public void SetContext(PodeContext context)
        {
            Context = context;
        }

        public virtual void Dispose()
        {
            if (Socket != default(Socket))
            {
                PodeSocket.CloseSocket(Socket);
            }

            if (InputStream != default(Stream))
            {
                Console.WriteLine("Input Disposed");
                InputStream.Dispose();
            }
        }
    }
}