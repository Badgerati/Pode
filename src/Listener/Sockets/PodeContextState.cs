namespace Pode.Sockets
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