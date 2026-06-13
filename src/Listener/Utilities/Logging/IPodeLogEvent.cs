namespace Pode.Utilities.Logging
{
    public interface IPodeLogEvent
    {
        string Name { get; }
        PodeLogLevel Level { get; }
        object Item { get; }
    }
}