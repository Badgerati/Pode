using System.Collections.Generic;
using System.Linq;

namespace Pode.Utilities
{
    public class PodeConcurrentSet<T> : IEnumerable<T>
    {
        private readonly HashSet<T> Items = new HashSet<T>();
        private readonly object Lock = new object();

        public PodeConcurrentSet() { }

        public int Count
        {
            get
            {
                lock (Lock)
                {
                    return Items.Count;
                }
            }
        }

        public bool TryAdd(T item)
        {
            lock (Lock)
            {
                return Items.Add(item);
            }
        }

        public bool TryRemove(T item, out T removedItem)
        {
            lock (Lock)
            {
                var removed = Items.Remove(item);
                removedItem = removed ? item : default;
                return removed;
            }
        }

        public bool Contains(T item)
        {
            lock (Lock)
            {
                return Items.Contains(item);
            }
        }

        public void Clear()
        {
            lock (Lock)
            {
                Items.Clear();
            }
        }

        public T[] ToArray()
        {
            lock (Lock)
            {
                return Items.ToArray();
            }
        }

        public IEnumerator<T> GetEnumerator()
        {
            lock (Lock)
            {
                return ((IReadOnlyList<T>)Items.ToArray()).GetEnumerator();
            }
        }

        System.Collections.IEnumerator System.Collections.IEnumerable.GetEnumerator()
        {
            return GetEnumerator();
        }
    }
}