namespace Pode.Utilities
{
    public class PodeProtocol : IPodeProtocol
    {
        public PodeProtocolType Type { get; protected set; }

        public bool IsHttp
        {
            get => Type == PodeProtocolType.Http || Type == PodeProtocolType.HttpAndWs;
        }

        public bool IsWebSocket
        {
            get => Type == PodeProtocolType.Ws || Type == PodeProtocolType.HttpAndWs;
        }

        public bool IsSmtp
        {
            get => Type == PodeProtocolType.Smtp;
        }

        public bool IsTcp
        {
            get => Type == PodeProtocolType.Tcp;
        }

        public bool IsUnknown
        {
            get => Type == PodeProtocolType.Unknown;
        }

        public PodeProtocol(PodeProtocolType type = PodeProtocolType.Unknown)
        {
            Type = type;
        }
    }
}