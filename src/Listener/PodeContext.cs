using System;

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

        public void Dispose()
        {
            // send the response, and then close the request/response
            try
            {
                Response.Send();
                Request.Dispose();
                Response.Dispose();
            }
            catch {}
        }
    }
}