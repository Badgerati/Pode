using System.Linq;
using System.Collections.Generic;

namespace Pode
{
    public class PodeFormData
    {
        public string Key { get; private set; }

        private IList<string> _values;
        public string[] Values => _values.ToArray();

        public int Count => _values.Count;
        public bool IsSingular => _values.Count == 1;
        public bool IsEmpty => _values.Count == 0;

        public PodeFormData(string key, string value)
        {
            Key = key;

            _values = new List<string>
            {
                value
            };
        }

        public void AddValue(string value)
        {
            _values.Add(value);
        }
    }
}