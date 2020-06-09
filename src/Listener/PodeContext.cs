using System;
using System.Net.Http;

namespace Pode
{
    public class PodeContext : IDisposable
    {
        public PodeRequest Request { get; private set; }
        public PodeResponse Response { get; private set; }
        public PodeListener Listener { get; private set; }
        public DateTime Timestamp { get; private set; }

        public PodeContext(PodeRequest request, PodeResponse response, PodeListener listener)
        {
            Request = request;
            Request.SetContext(this);

            Response = response;
            Response.SetContext(this);

            Listener = listener;
            Timestamp = DateTime.UtcNow;
        }

        private void NewResponse()
        {
            Response = new PodeResponse();
            Response.SetContext(this);
        }

        public void Dispose()
        {
            Dispose(Request.Error != default(HttpRequestException));
        }

        public void Dispose(bool force)
        {
            // send the response and close, only close request if not keep alive
            try
            {
                Response.Send();
                Response.Dispose();

                if (!Request.IsKeepAlive || force)
                {
                    Request.Dispose();
                }
            }
            catch {}

            // if keep-alive, setup for re-receive
            if (Request.IsKeepAlive && !force)
            {
                NewResponse();
                Request.StartReceive();
            }
        }
    }
}