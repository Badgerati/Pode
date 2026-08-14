namespace Pode.Utilities.Logging
{
    public class PodeLogItem : IPodeLogItem
    {
        public object Data { get; private set; }
        public IPodeLogEvent Event { get; private set; }

        public PodeLogItem(object data, IPodeLogEvent logEvent)
        {
            Data = data;
            Event = logEvent;
        }

        public override string ToString()
        {
            return Data?.ToString() ?? string.Empty;
        }
    }
}