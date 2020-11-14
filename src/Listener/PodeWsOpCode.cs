namespace Pode
{
    public enum PodeWsOpCode
    {
        Fragment = 0,
        Text = 1,
        Binary = 2,
        Close = 8,
        Ping = 9,
        Pong = 10
    }
}