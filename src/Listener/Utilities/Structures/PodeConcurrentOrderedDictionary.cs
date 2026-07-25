using System;
using System.Collections;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Collections.Specialized;
using System.Linq;

namespace Pode.Utilities.Structures
{
    public class PodeConcurrentOrderedDictionary<K, V> : IEnumerable<KeyValuePair<K, V>>
    {
        private readonly ConcurrentDictionary<K, V> Items = new ConcurrentDictionary<K, V>(
            typeof(K) == typeof(string) ? (IEqualityComparer<K>)StringComparer.InvariantCultureIgnoreCase : EqualityComparer<K>.Default
        );

        private readonly OrderedDictionary OrderedKeys = new OrderedDictionary(
            typeof(K) == typeof(string) ? (IEqualityComparer)StringComparer.InvariantCultureIgnoreCase : EqualityComparer<K>.Default
        );

        private volatile K[] OrderedKeysCache = Array.Empty<K>();
        private volatile bool IsDirty = false;

        private readonly object Lock = new object();

        public PodeConcurrentOrderedDictionary() { }

        public int Count
        {
            get
            {
                return Items.Count;
            }
        }

        public K[] Keys => GetOrderedKeys();

        public V[] Values
        {
            get
            {
                return GetOrderedKeys().Select(k => Items.TryGetValue(k, out var value) ? value : default).ToArray();
            }
        }

        public V this[K key]
        {
            get
            {
                if (Items.TryGetValue(key, out var value))
                {
                    return value;
                }

                return default;
            }
            set
            {
                lock (Lock)
                {
                    if (Items.TryAdd(key, value))
                    {
                        OrderedKeys.Add(key, true);
                    }
                    else
                    {
                        Items[key] = value;
                    }

                    IsDirty = true;
                }
            }
        }

        public bool TryAdd(K key, V value)
        {
            lock (Lock)
            {
                if (!Items.TryAdd(key, value))
                {
                    return false;
                }

                OrderedKeys.Add(key, true);
                IsDirty = true;
                return true;
            }
        }

        public bool TryRemove(K key, out V removedValue)
        {
            lock (Lock)
            {
                var removed = Items.TryRemove(key, out var value);
                if (!removed)
                {
                    removedValue = default;
                    return removed;
                }

                removedValue = value;
                OrderedKeys.Remove(key);
                IsDirty = true;
                return removed;
            }
        }

        public bool Contains(K key)
        {
            return Items.ContainsKey(key);
        }

        public void Clear()
        {
            lock (Lock)
            {
                Items.Clear();
                OrderedKeys.Clear();
                IsDirty = true;
            }
        }

        public KeyValuePair<K, V>[] ToArray()
        {
            return GetOrderedKeys().Select(k => new KeyValuePair<K, V>(k, Items.TryGetValue(k, out var value) ? value : default)).ToArray();
        }

        public IEnumerator<KeyValuePair<K, V>> GetEnumerator()
        {
            return ((IReadOnlyList<KeyValuePair<K, V>>)ToArray()).GetEnumerator();
        }

        System.Collections.IEnumerator System.Collections.IEnumerable.GetEnumerator()
        {
            return GetEnumerator();
        }

        public override int GetHashCode()
        {
            return Items.GetHashCode();
        }

        public override bool Equals(object obj)
        {
            return obj is PodeConcurrentOrderedDictionary<K, V> other && Items.SequenceEqual(other.Items);
        }

        public override string ToString()
        {
            return Items.ToString();
        }

        private K[] GetOrderedKeys()
        {
            // return the cached ordered keys if not dirty
            if (!IsDirty)
            {
                return OrderedKeysCache;
            }

            // otherwise, rebuild the ordered keys cache
            lock (Lock)
            {
                // ensure still dirty, else return
                if (!IsDirty)
                {
                    return OrderedKeysCache;
                }

                OrderedKeysCache = OrderedKeys.Keys.Cast<K>().ToArray();
                IsDirty = false;
            }

            return OrderedKeysCache;
        }
    }
}