using System;

namespace Pode
{
    public class PodeSignalFrame
    {
        public bool IsFinalFrame { get; private set; }
        public PodeWsOpCode OpCode { get; private set; }
        public bool IsMasked { get; private set; }
        public int PayloadLength { get; private set; }
        public int Offset { get; private set; }
        public byte[] MaskingKey { get; private set; }
        public int Length { get; private set; }

        public bool AwaitingBody
        {
            get
            {
                return Length < Offset + PayloadLength;
            }
        }

        public PodeSignalFrame(byte[] bytes)
        {
            // total length of the frame currently supplied
            Length = bytes.Length;

            // parse the first 2 bytes of the frame
            IsFinalFrame = (bytes[0] & 0b10000000) != 0;
            PayloadLength = bytes[1] & 0b01111111;
            IsMasked = (bytes[1] & 0b10000000) != 0;
            OpCode = (PodeWsOpCode)(bytes[0] & 0b00001111);

            // calculate the payload offset
            Offset = 2;
            if (PayloadLength == 126)
            {
                Offset += 2;
                PayloadLength = BitConverter.ToUInt16(new byte[] { bytes[3], bytes[2] }, 0);
            }
            else if (PayloadLength >= 127)
            {
                Offset += 8;
                PayloadLength = (int)BitConverter.ToUInt64(new byte[] { bytes[9], bytes[8], bytes[7], bytes[6], bytes[5], bytes[4], bytes[3], bytes[2] }, 0);
            }

            // calculate the masking key
            MaskingKey = default;
            if (IsMasked)
            {
                MaskingKey = new byte[] { bytes[Offset], bytes[Offset + 1], bytes[Offset + 2], bytes[Offset + 3] };
                Offset += 4;
            }
        }

        public void Update(byte[] bytes)
        {
            Length = bytes.Length;
        }

        public byte[] Decode(byte[] bytes)
        {
            if (AwaitingBody)
            {
                throw new InvalidOperationException("Frame is not complete");
            }

            // decode the payload
            var payload = new byte[PayloadLength];
            for (var i = 0; i < PayloadLength; i++)
            {
                payload[i] = IsMasked
                    ? (byte)(bytes[Offset + i] ^ MaskingKey[i % 4])
                    : bytes[Offset + i];
            }

            return payload;
        }

        public static bool ValidateHeader(byte[] bytes)
        {
            // if the length is less than 2, we can't parse the header - missing code/length
            if (bytes == default || bytes.Length < 2)
            {
                return false;
            }

            // length offset
            var length = bytes[1] & 0b01111111;

            var offset = 2;
            if (length == 126)
            {
                offset += 2;
            }
            else if (length >= 127)
            {
                offset += 8;
            }

            // mask offset
            var isMasked = (bytes[1] & 0b10000000) != 0;
            if (isMasked)
            {
                offset += 4;
            }

            // do we have enough bytes for the header?
            return bytes.Length >= offset;
        }
    }
}