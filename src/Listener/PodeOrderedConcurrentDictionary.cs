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
            _sortedDictionary = new SortedDictionary<TKey, TValue>(keyComparer ?? Comparer<TKey>.Default);
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

        // Adds or updates an item in the dictionary using value factories
        public TValue AddOrUpdate(TKey key, Func<TKey, TValue> addValueFactory, Func<TKey, TValue, TValue> updateValueFactory)
        {
            TValue result = _concurrentDictionary.AddOrUpdate(key, addValueFactory, updateValueFactory);

            lock (_lock)
            {
                _sortedDictionary[key] = result;
            }

            return result;
        }

        // Attempts to add a key-value pair if the key does not already exist
        public bool TryAdd(TKey key, TValue value)
        {
            // Try to add to the ConcurrentDictionary first
            if (_concurrentDictionary.TryAdd(key, value))
            {
                // If successful, add to the SortedDictionary inside a lock
                lock (_lock)
                {
                    _sortedDictionary[key] = value;
                }
                return true;
            }

            return false; // If the key already exists, return false
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

        // Attempts to update the value of the specified key if it matches a specified comparison value
        public bool TryUpdate(TKey key, TValue newValue, TValue comparisonValue)
        {
            if (_concurrentDictionary.TryUpdate(key, newValue, comparisonValue))
            {
                lock (_lock)
                {
                    _sortedDictionary[key] = newValue;
                }
                return true;
            }

            return false;
        }

        // Gets or adds a value by key
        public TValue GetOrAdd(TKey key, TValue value)
        {
            TValue result = _concurrentDictionary.GetOrAdd(key, value);

            lock (_lock)
            {
                if (!_sortedDictionary.ContainsKey(key))
                {
                    _sortedDictionary[key] = result;
                }
            }

            return result;
        }

        public TValue GetOrAdd(TKey key, Func<TKey, TValue> valueFactory)
        {
            TValue result = _concurrentDictionary.GetOrAdd(key, valueFactory);

            lock (_lock)
            {
                if (!_sortedDictionary.ContainsKey(key))
                {
                    _sortedDictionary[key] = result;
                }
            }

            return result;
        }

        // Clears the dictionary
        public void Clear()
        {
            _concurrentDictionary.Clear();
            lock (_lock)
            {
                _sortedDictionary.Clear();
            }
        }

        // Checks if the dictionary contains the specified key
        public bool ContainsKey(TKey key)
        {
            return _concurrentDictionary.ContainsKey(key);
        }

        // Converts the dictionary to an array of key-value pairs
        public KeyValuePair<TKey, TValue>[] ToArray()
        {
            return _concurrentDictionary.ToArray();
        }

        // Indexer to support [] access in PowerShell
        public TValue this[TKey key]
        {
            get
            {
                if (_concurrentDictionary.TryGetValue(key, out TValue value))
                {
                    return value;
                }
                throw new KeyNotFoundException($"The key '{key}' was not found in the dictionary.");
            }
            set
            {
                AddOrUpdate(key, value);
            }
        }

        // Returns ordered keys
        public IEnumerable<TKey> Keys
        {
            get
            {
                lock (_lock)
                {
                    // Return a copy of the keys to maintain thread safety
                    return new List<TKey>(_sortedDictionary.Keys);
                }
            }
        }

        // Returns ordered values
        public IEnumerable<TValue> Values
        {
            get
            {
                lock (_lock)
                {
                    // Return a copy of the values to maintain thread safety
                    return new List<TValue>(_sortedDictionary.Values);
                }
            }
        }

        // Returns the count of items in the dictionary
        public int Count
        {
            get { return _concurrentDictionary.Count; }
        }

        // Checks if the dictionary is empty
        public bool IsEmpty
        {
            get { return _concurrentDictionary.IsEmpty; }
        }
    }
}