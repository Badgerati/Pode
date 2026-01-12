namespace Pode.Protocols.Http.Client.Signals
{
    public class PodeSignalEnvelope : PodeClientConnectionEnvelope
    {
        public PodeSignalOpCode OpCode { get; private set; }

        public PodeSignalEnvelope(string message, PodeSignalOpCode opCode = PodeSignalOpCode.Text)
            : base(message)
        {
            OpCode = opCode;
        }
    }
}