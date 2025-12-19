namespace Pode
{
    public class PodeSignalEnvelope : PodeClientConnectionEnvelope
    {
        public PodeWsOpCode OpCode { get; private set; }

        public PodeSignalEnvelope(string message, PodeWsOpCode opCode = PodeWsOpCode.Text)
            : base(message)
        {
            OpCode = opCode;
        }
    }
}