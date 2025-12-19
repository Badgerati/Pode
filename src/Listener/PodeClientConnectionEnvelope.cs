namespace Pode
{
    public class PodeClientConnectionEnvelope
    {
        public string Message { get; private set; }

        public PodeClientConnectionEnvelope(string message)
        {
            Message = message ?? string.Empty;
        }
    }
}