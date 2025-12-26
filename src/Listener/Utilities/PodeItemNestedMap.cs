using System;
using System.Linq;
using System.Collections.Concurrent;

namespace Pode.Utilities
{
    public class PodeItemNestedMap<T>
    {
        private ConcurrentDictionary<string, ConcurrentDictionary<string, T>> Items = default;
        protected bool IsDisposed { get; private set; } = false;

        public int TotalCount { get => Items.Values.Sum(dict => dict.Count); }

        public string[] Keys { get => Items.Keys.ToArray(); }
        public string[] AllSubKeys { get => Items.Values.SelectMany(dict => dict.Keys).ToArray(); }

        public ConcurrentDictionary<string, T>[] Values { get => Items.Values.ToArray(); }
        public T[] AllSubValues { get => Items.Values.SelectMany(dict => dict.Values).ToArray(); }

        public PodeItemNestedMap()
        {
            Items = new ConcurrentDictionary<string, ConcurrentDictionary<string, T>>();
        }

        public T Get(string key, string subKey)
        {
            if (IsDisposed
                || !Items.TryGetValue(key, out var subDict)
                || !subDict.TryGetValue(subKey, out var item))
            {
                return default;
            }

            return item;
        }

        public void Add(string key, string subKey, T item)
        {
            if (IsDisposed)
            {
                return;
            }

            // add the primary key if it doesn't exist
            if (!Items.TryGetValue(key, out var subDict))
            {
                subDict = new ConcurrentDictionary<string, T>();
                Items.TryAdd(key, subDict);
            }

            // add the sub-key and item
            if (subDict.TryGetValue(subKey, out var existingItem))
            {
                if (existingItem is IDisposable disposable)
                {
                    disposable.Dispose();
                }

                subDict.TryRemove(subKey, out _);
                subDict.TryAdd(subKey, item);
            }
            else
            {
                subDict.TryAdd(subKey, item);
            }
        }

        public bool Remove(string key, string subKey)
        {
            if (IsDisposed || !Items.TryGetValue(key, out var subDict))
            {
                return false;
            }

            return subDict.TryRemove(subKey, out _);
        }

        public bool Exists(string key, out ConcurrentDictionary<string, T> item)
        {
            if (IsDisposed)
            {
                item = default;
                return false;
            }

            return Items.TryGetValue(key, out item);
        }

        public bool Exists(string key, string subKey, out T item)
        {
            if (IsDisposed
                || string.IsNullOrEmpty(subKey)
                || !Items.TryGetValue(key, out var subDict))
            {
                item = default;
                return false;
            }

            return subDict.TryGetValue(subKey, out item);
        }

        public int Count(string key)
        {
            if (IsDisposed || !Items.TryGetValue(key, out var subDict))
            {
                return 0;
            }

            return subDict.Count;
        }

        public string[] GetSubKeys(string key)
        {
            if (IsDisposed || !Items.TryGetValue(key, out var subDict))
            {
                return Array.Empty<string>();
            }

            return subDict.Keys.ToArray();
        }

        public T[] GetSubValues(string key)
        {
            if (IsDisposed || !Items.TryGetValue(key, out var subDict))
            {
                return default;
            }

            return subDict.Values.ToArray();
        }

        public T[] ToArray()
        {
            if (IsDisposed)
            {
                return Array.Empty<T>();
            }

            return Items.Values.SelectMany(dict => dict.Values).ToArray();
        }

        public void Dispose()
        {
            if (IsDisposed)
            {
                return;
            }

            IsDisposed = true;

            Items.Clear();
            Items = null;
        }
    }
}