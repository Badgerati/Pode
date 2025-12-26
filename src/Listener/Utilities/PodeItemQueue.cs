using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;

namespace Pode.Utilities
{
    public class PodeItemQueue<T>
    {
        private BlockingCollection<T> Items = default;
        private List<T> ProcessingItems = default;
        private readonly bool TrackProcessing = true;
        private bool IsDisposed = false;

        public int Count { get => Items.Count + ProcessingItems.Count; }
        public int QueuedCount { get => Items.Count; }
        public int ProcessingCount { get => ProcessingItems.Count; }

        public PodeItemQueue(bool trackProcessing = true)
        {
            Items = new BlockingCollection<T>();
            TrackProcessing = trackProcessing;
            ProcessingItems = new List<T>();
        }

        public T Get(CancellationToken cancellationToken = default)
        {
            if (IsDisposed)
            {
                return default;
            }

            var item = Items.Take(cancellationToken == default ? CancellationToken.None : cancellationToken);
            AddProcessing(item);
            return item;
        }

        public Task<T> GetAsync(CancellationToken cancellationToken = default)
        {
            if (IsDisposed)
            {
                return Task.FromResult(default(T));
            }

            return cancellationToken == default
                ? Task.Factory.StartNew(() => Get())
                : Task.Factory.StartNew(() => Get(cancellationToken), cancellationToken);
        }

        public void Add(T item)
        {
            if (IsDisposed)
            {
                return;
            }

            lock (Items)
            {
                Items.Add(item);
            }
        }

        public void AddProcessing(T item)
        {
            if (!TrackProcessing || IsDisposed)
            {
                return;
            }

            lock (ProcessingItems)
            {
                ProcessingItems.Add(item);
            }
        }

        public void RemoveProcessing(T item)
        {
            if (!TrackProcessing || IsDisposed)
            {
                return;
            }

            lock (ProcessingItems)
            {
                ProcessingItems.Remove(item);
            }
        }

        public T[] ToArray()
        {
            if (IsDisposed)
            {
                return Array.Empty<T>();
            }

            return Items.ToArray();
        }

        public void Dispose()
        {
            if (IsDisposed)
            {
                return;
            }

            IsDisposed = true;

            Items.Dispose();
            Items = null;

            ProcessingItems.Clear();
            ProcessingItems = null;
        }
    }
}