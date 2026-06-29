using System;
using System.Collections.Generic;

namespace Pode.Utilities.Logging
{
    public class PodeLogItemCollection : IPodeLogItemCollection
    {
        public IList<IPodeLogItem> Items { get; private set; }
        public DateTime Timestamp { get; private set; }
        public int Count => Items.Count;
        public int MaxCount { get; private set; } = 1;
        public int Timeout { get; private set; } = 0;

        public bool HasTimedOut
        {
            get
            {
                if (Count <= 0 || Timeout <= 0)
                {
                    return false;
                }

                return Timestamp.AddSeconds(Timeout) <= DateTime.UtcNow;
            }
        }

        public bool IsFull
        {
            get
            {
                if (Count <= 0 || MaxCount <= 0)
                {
                    return false;
                }

                return Count >= MaxCount;
            }
        }

        public PodeLogItemCollection() : this(1, 0) { }

        public PodeLogItemCollection(int maxCount, int timeout)
        {
            Items = new List<IPodeLogItem>();
            MaxCount = maxCount;
            Timeout = timeout;
            Timestamp = DateTime.UtcNow;
        }

        public void Add(IPodeLogItem item)
        {
            Items.Add(item);
            Timestamp = DateTime.UtcNow;
        }

        public override string ToString()
        {
            return string.Join(Environment.NewLine, Items);
        }

        public void Dispose()
        {
            Items.Clear();
            GC.SuppressFinalize(this);
        }
    }
}