namespace Pode
{
    public enum PodeContextState
    {
        New,
        Open,
        Receiving,
        Received,
        Closed,
        Error,
        SslError
    }
}