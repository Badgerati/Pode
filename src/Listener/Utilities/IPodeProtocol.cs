namespace Pode.Utilities
{
    public interface IPodeProtocol
    {
        PodeProtocolType Type { get; }

        bool IsHttp { get; }
        bool IsWebSocket { get; }
        bool IsSmtp { get; }
        bool IsTcp { get; }
        bool IsUnknown { get; }
    }
}