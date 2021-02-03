using System;
using System.Collections.Generic;

namespace Pode
{
    public class PodeResponseHeaders
    {
        public object this[string name]
        {
            get => (Headers.ContainsKey(name) ? Headers[name][0] : string.Empty);
            set => Set(name, value);
        }

        public int Count => Headers.Count;
        public ICollection<string> Keys => Headers.Keys;

        private IDictionary<string, IList<object>> Headers;

        public PodeResponseHeaders()
        {
            Headers = new Dictionary<string, IList<object>>(StringComparer.InvariantCultureIgnoreCase);
        }

        public bool ContainsKey(string name)
        {
            return Headers.ContainsKey(name);
        }

        public IList<object> Get(string name)
        {
            return Headers.ContainsKey(name) ? Headers[name] : default(IList<object>);
        }

        public void Set(string name, object value)
        {
            if (!Headers.ContainsKey(name))
            {
                Headers.Add(name, new List<object>());
            }

            Headers[name].Clear();
            Headers[name].Add(value);
        }

        public void Add(string name, object value)
        {
            if (!Headers.ContainsKey(name))
            {
                Headers.Add(name, new List<object>());
            }

            Headers[name].Add(value);
        }

        public void Remove(string name)
        {
            if (Headers.ContainsKey(name))
            {
                Headers.Remove(name);
            }
        }

        public void Clear()
        {
            Headers.Clear();
        }

    }
}