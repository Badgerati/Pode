using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;

namespace Pode
{
    public class PodeItemQueue<T>
    {
        private BlockingCollection<T> Items;
        private List<T> ProcessingItems;

        public int Count { get => Items.Count + ProcessingItems.Count; }
        public int QueuedCount { get => Items.Count; }
        public int ProcessingCount { get => ProcessingItems.Count; }

        public PodeItemQueue()
        {
            Items = new BlockingCollection<T>();
            ProcessingItems = new List<T>();
        }

        public T Get(CancellationToken cancellationToken = default)
        {
            var item = Items.Take(cancellationToken == default ? CancellationToken.None : cancellationToken);

            lock (ProcessingItems)
            {
                ProcessingItems.Add(item);
            }

            return item;
        }

        public Task<T> GetAsync(CancellationToken cancellationToken = default)
        {
            return cancellationToken == default
                ? Task.Factory.StartNew(() => Get())
                : Task.Factory.StartNew(() => Get(cancellationToken), cancellationToken);
        }

        public void Add(T item)
        {
            lock (Items)
            {
                Items.Add(item);
            }
        }

        public void RemoveProcessing(T item)
        {
            lock (ProcessingItems)
            {
                ProcessingItems.Remove(item);
            }
        }

        public T[] ToArray()
        {
            return Items.ToArray();
        }

        public void Clear()
        {
            Items = new BlockingCollection<T>();
            ProcessingItems = new List<T>();
        }
    }
}