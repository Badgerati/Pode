namespace Pode.Protocols.Common.Contexts
{
    public enum PodeContextState
    {
        New,
        Open,
        Receiving,
        Received,
        Closing,
        Closed,
        Error,
        Timeout
    }
}