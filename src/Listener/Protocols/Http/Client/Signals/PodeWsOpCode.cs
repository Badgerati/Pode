namespace Pode.Protocols.Http.Client.Signals
{
    public enum PodeSignalOpCode
    {
        Continuation = 0,
        Text = 1,
        Binary = 2,
        Close = 8,
        Ping = 9,
        Pong = 10
    }
}