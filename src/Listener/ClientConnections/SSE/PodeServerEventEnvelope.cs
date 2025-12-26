namespace Pode.ClientConnections.SSE
{
    public class PodeServerEventEnvelope : PodeClientConnectionEnvelope
    {
        public string ID { get; private set; }
        public string EventType { get; private set; }

        public PodeServerEventEnvelope(string message, string eventType, string id = null)
            : base(message)
        {
            ID = id;
            EventType = eventType;
        }
    }
}