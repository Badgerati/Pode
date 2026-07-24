using System.Collections.Generic;
using System.Linq;

namespace Pode.Utilities.Structures
{
    public class PodeConcurrentList<T> : IEnumerable<T>
    {
        private readonly List<T> Items = new List<T>();
        private readonly object Lock = new object();

        public PodeConcurrentList() { }

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

        public T this[int index]
        {
            get
            {
                lock (Lock)
                {
                    return Items[index];
                }
            }
            set
            {
                lock (Lock)
                {
                    Items[index] = value;
                }
            }
        }

        public bool TryAdd(T item, bool unique = false)
        {
            lock (Lock)
            {
                if (unique && Items.Contains(item))
                {
                    return false;
                }

                Items.Add(item);
                return true;
            }
        }

        public bool TryInsert(int index, T item, bool unique = false)
        {
            lock (Lock)
            {
                if (unique && Items.Contains(item))
                {
                    return false;
                }

                if (index < 0 || index > Items.Count)
                {
                    return false;
                }

                Items.Insert(index, item);
                return true;
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

        public bool TryRemoveAt(int index, out T removedItem)
        {
            lock (Lock)
            {
                if (index < 0 || index >= Items.Count)
                {
                    removedItem = default;
                    return false;
                }

                removedItem = Items[index];
                Items.RemoveAt(index);
                return true;
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

        public int IndexOf(T item)
        {
            lock (Lock)
            {
                return Items.IndexOf(item);
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

        public override int GetHashCode()
        {
            lock (Lock)
            {
                return Items.GetHashCode();
            }
        }

        public override bool Equals(object obj)
        {
            lock (Lock)
            {
                return obj is PodeConcurrentList<T> other && Items.SequenceEqual(other.Items);
            }
        }

        public override string ToString()
        {
            lock (Lock)
            {
                return Items.ToString();
            }
        }
    }
}