namespace Pode
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
        SslError,
        Timeout
    }
}