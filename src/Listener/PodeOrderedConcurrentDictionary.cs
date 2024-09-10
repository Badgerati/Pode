using System;
using System.Collections.Concurrent;
using System.Collections.Generic;

namespace Pode
{
    public class PodeOrderedConcurrentDictionary<TKey, TValue>
    {
        private readonly ConcurrentDictionary<TKey, TValue> _concurrentDictionary;
        private readonly SortedDictionary<TKey, TValue> _sortedDictionary;
        private readonly object _lock = new object();

        // Constructor accepting a custom key comparer
        public PodeOrderedConcurrentDictionary(IComparer<TKey> keyComparer = null)
        {
            _concurrentDictionary = new ConcurrentDictionary<TKey, TValue>();
            _sortedDictionary = new SortedDictionary<TKey, TValue>(keyComparer);
        }

        // Adds or updates an item in the dictionary
        public void AddOrUpdate(TKey key, TValue value)
        {
            _concurrentDictionary[key] = value; // Thread-safe operation for the ConcurrentDictionary

            lock (_lock) // Lock to ensure the SortedDictionary remains thread-safe
            {
                _sortedDictionary[key] = value;
            }
        }

        // Tries to get a value by key
        public bool TryGetValue(TKey key, out TValue value)
        {
            return _concurrentDictionary.TryGetValue(key, out value);
        }

        // Tries to remove a key-value pair
        public bool TryRemove(TKey key, out TValue value)
        {
            var removed = _concurrentDictionary.TryRemove(key, out value);

            if (removed)
            {
                lock (_lock)
                {
                    _sortedDictionary.Remove(key);
                }
            }

            return removed;
        }

        // Returns ordered keys
        public IEnumerable<TKey> OrderedKeys
        {
            get
            {
                lock (_lock)
                {
                    return new List<TKey>(_sortedDictionary.Keys);
                }
            }
        }

        // Returns ordered values
        public IEnumerable<TValue> OrderedValues
        {
            get
            {
                lock (_lock)
                {
                    return new List<TValue>(_sortedDictionary.Values);
                }
            }
        }
    }
}