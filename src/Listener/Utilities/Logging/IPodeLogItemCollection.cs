using System;
using System.Collections.Generic;

namespace Pode.Utilities.Logging
{
    public interface IPodeLogItemCollection : IDisposable
    {
        IList<IPodeLogItem> Items { get; }
        DateTime Timestamp { get; }
        int Count { get; }
        int MaxCount { get; }
        int Timeout { get; }
        bool HasTimedOut { get; }
        bool IsFull { get; }

        void Add(IPodeLogItem item);
        string ToString();
    }
}