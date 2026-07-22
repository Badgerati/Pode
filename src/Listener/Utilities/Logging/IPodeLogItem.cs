namespace Pode.Utilities.Logging
{
    public interface IPodeLogItem
    {
        object Data { get; }
        IPodeLogEvent Event { get; }

        string ToString();
    }
}