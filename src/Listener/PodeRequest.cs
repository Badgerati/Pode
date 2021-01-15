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
        private const int _bufferSize = 16384; //8192;
        protected AsyncCallback AsyncReadCallback;

        private void ReadCallback(IAsyncResult ares)
        {
            var req = (PodeRequest)ares.AsyncState;

            var read = InputStream.EndRead(ares);
            if (read < _bufferSize - 29) {
                Console.WriteLine($"READ: {read} -- {_bufferStream.ToArray().Length} -- {_bufferStream.ToArray().LastOrDefault()}");
            }
            
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

            // System.Threading.Thread.Sleep(10);
            // System.Threading.Thread.Sleep(10);
            // System.Threading.Thread.Sleep(10);
            // System.Threading.Thread.Sleep(10);
            // if (read == _bufferSize || Socket.Available > 0)
            if (Socket.Available > 0 || !ValidateInput(_bufferStream.ToArray()))
            {
                // InputStream.BeginRead(_buffer, 0, _bufferSize, AsyncReadCallback, this);
                Console.WriteLine($"BR1 -- {Socket.Available}");
                BeginRead();
            }
            else
            {
                var bytes = _bufferStream.ToArray();
                Console.WriteLine($"BYTES: {bytes.Length}");
                if (!Parse(bytes))
                {
                    bytes = default(byte[]);
                    _bufferStream.Dispose();
                    _bufferStream = new MemoryStream();
                    Console.WriteLine("BR2");
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
                Console.WriteLine("RECEIVING!");
                // AsyncReadCallback = new AsyncCallback(ReadCallback);
                // InputStream.BeginRead(_buffer, 0, _bufferSize, AsyncReadCallback, this);
                BeginRead();




                // var allBytes = default(byte[]);
                // var task = default(Task<int>);
                // var bytes = default(byte[]);
                // var count = 0;

                // using (var buffer = new MemoryStream())
                // {
                    // while ((count = Socket.Available) > 0)
                    // {
                        // if (count > 8192)
                        // {
                        //     count = 8192;
                        // }

                        // bytes = new byte[count];
                        // task = InputStream.ReadAsync(bytes, 0, count);
                        // task.Wait(Context.Listener.CancellationToken);

                        // Console.WriteLine($"COUNT: {count}");
                        // Console.WriteLine($"READ: {task.Result}");

                    //     buffer.WriteAsync(bytes, 0, task.Result).Wait(Context.Listener.CancellationToken);
                    // }

                    // allBytes = buffer.GetBuffer();

                    // if (allBytes[allBytes.Length - 1] == (byte)0)
                    // {
                    //     var index = Array.IndexOf(allBytes, (byte)0);
                    //     allBytes = allBytes.Take(index).ToArray();
                    // }
                // }

                // Parse(allBytes);
                // allBytes = default(byte[]);
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
        }
    }
}