using System;
using System.Collections.Concurrent;
using System.Collections;

namespace Pode
{
    public static class PodeLogger
    {
        private static bool _enabled;
        private static ConcurrentQueue<Hashtable> _queue;

        // Static property to enable or disable logging
        public static bool Enabled
        {
            get => _enabled;
            set
            {
                _enabled = value;
                if (_enabled)
                {
                    _queue = new ConcurrentQueue<Hashtable>();
                }
                else
                {
                    _queue = null;
                }
            }
        }

        // Property to get the count of items in the queue
        public static int Count
        {
            get => _queue != null ? _queue.Count : 0;
        }

        // Method to add a Hashtable to the queue
        public static void Enqueue(Hashtable table)
        {
            if (_queue != null)
            {
                _queue.Enqueue(table);
            }
        }

        // Method to try and dequeue a Hashtable from the queue
        public static bool TryDequeue(out Hashtable table)
        {
            if (_queue != null)
            {
                return _queue.TryDequeue(out table);
            }
            table = null;
            return false;
        }

        // Method to dequeue a Hashtable from the queue
        public static Hashtable Dequeue()
        {
            if (_queue != null && _queue.TryDequeue(out Hashtable table))
            {
                return table;
            }
            return null;
        }

        // Method to clear the queue
        public static void Clear()
        {
            if (_queue != null)
            {
                if (_queue != null)
                {
                    while (_queue.TryDequeue(out _)) { }
                }
            }
        }


    }
}
