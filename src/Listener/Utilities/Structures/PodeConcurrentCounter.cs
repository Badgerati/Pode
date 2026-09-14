using System.Threading;

namespace Pode.Utilities.Structures
{
    public class PodeConcurrentCounter
    {
        private int _value = 0;
        public int Value => _value;

        public PodeConcurrentCounter() { }


        public int Add(int amount = 1)
        {
            return Interlocked.Add(ref _value, amount);
        }

        public int Subtract(int amount = 1)
        {
            return Interlocked.Add(ref _value, -amount);
        }

        public int Increment()
        {
            return Interlocked.Increment(ref _value);
        }

        public int Decrement()
        {
            return Interlocked.Decrement(ref _value);
        }

        public void Reset()
        {
            Interlocked.Exchange(ref _value, 0);
        }
    }
}