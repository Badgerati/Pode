using System;

namespace Pode
{
    public class PodeContext : IDisposable
    {
        public PodeRequest Request { get; private set; }
        public PodeResponse Response { get; private set; }
        public DateTime Timestamp { get; private set; }

        public PodeContext(PodeRequest request, PodeResponse response)
        {
            Request = request;
            Response = response;
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