using System;
using System.Collections.Generic;

namespace Pode
{
    public class PodeFormData
    {
        public string Key { get; private set; }
        public string Value { get; private set; }

        public PodeFormData(string key, string value)
        {
            Key = key;
            Value = value;
        }
    }
}