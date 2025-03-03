using System;
using System.Collections.Generic;

namespace Pode
{
    /// <summary>
    /// Represents a collection of response headers that supports multiple values per header.
    /// </summary>
    public class PodeResponseHeaders
    {
        /// <summary>
        /// Gets or sets the first value of the specified header.
        /// </summary>
        /// <param name="name">The name of the header.</param>
        public object this[string name]
        {
            get => Headers.TryGetValue(name, out IList<object> value) ? value[0] : string.Empty;
            set => Set(name, value);
        }

        /// <summary>
        /// Gets the number of headers.
        /// </summary>
        public int Count => Headers.Count;

        /// <summary>
        /// Gets the collection of header names.
        /// </summary>
        public ICollection<string> Keys => Headers.Keys;

        private IDictionary<string, IList<object>> Headers;

        public PodeResponseHeaders()
        {
            Headers = new Dictionary<string, IList<object>>(StringComparer.InvariantCultureIgnoreCase);
        }

        /// <summary>
        /// Determines whether the collection contains the specified header.
        /// </summary>
        public bool ContainsKey(string name)
        {
            return Headers.ContainsKey(name);
        }

        /// <summary>
        /// Gets the list of values associated with the specified header.
        /// </summary>
        public IList<object> Get(string name)
        {
            return Headers.TryGetValue(name, out IList<object> value) ? value : default(IList<object>);
        }

        /// <summary>
        /// Sets the specified header to the provided value, replacing any existing values.
        /// </summary>
        public void Set(string name, object value)
        {
            if (!Headers.TryGetValue(name, out var list))
            {
                list = new List<object>();
                Headers[name] = list;
            }

            Headers[name].Clear();
            Headers[name].Add(value);
        }

        /// <summary>
        /// Adds a value to the specified header, preserving any existing values.
        /// </summary>
        public void Add(string name, object value)
        {
            if (!Headers.TryGetValue(name, out var list))
            {
                list = new List<object>();
                Headers[name] = list;
            }

            list.Add(value);
        }

        /// <summary>
        /// Removes the specified header.
        /// </summary>
        public void Remove(string name)
        {
            if (Headers.ContainsKey(name))
            {
                Headers.Remove(name);
            }
        }

        /// <summary>
        /// Clears all headers.
        /// </summary>
        public void Clear()
        {
            Headers.Clear();
        }

    }
}