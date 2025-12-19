using System;
using System.Collections;

namespace Pode
{
    public class PodeClientConnectionEvent : IDisposable
    {
        public PodeClientConnection Connection { get; private set; }
        public PodeClientConnectionEventType EventType { get; private set; }
        public DateTime Timestamp { get; private set; }

        public PodeClientConnectionEvent(PodeClientConnection connection, PodeClientConnectionEventType eventType)
        {
            Connection = connection;
            EventType = eventType;
            Timestamp = DateTime.UtcNow;
        }

        public Hashtable ToHashtable()
        {
            var ht = Connection.ToHashtable();
            ht["EventType"] = EventType.ToString();
            ht["Timestamp"] = Timestamp;
            return ht;
        }

        public void Dispose()
        {
            Connection = null;
            GC.SuppressFinalize(this);
        }
    }
}