using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using Pode.Utilities;
using Pode.Protocols.File;
using Pode.Utilities.Logging;

namespace Pode.Adapters.Watchers
{
    public class PodeWatcher : PodeAdapter
    {
        private readonly List<PodeFileWatcher> FileWatchers;

        public PodeItemQueue<PodeFileEvent> FileEvents { get; private set; }

        public PodeWatcher(PodeAdapterType type, IPodeLogger logger, CancellationToken cancellationToken = default)
            : base(type, logger, cancellationToken)
        {
            FileWatchers = new List<PodeFileWatcher>();
            FileEvents = new PodeItemQueue<PodeFileEvent>();
        }

        public void AddFileWatcher(PodeFileWatcher watcher)
        {
            watcher.BindWatcher(this);
            FileWatchers.Add(watcher);
        }

        public Task<PodeFileEvent> GetFileEventAsync(CancellationToken cancellationToken = default)
        {
            return FileEvents.GetAsync(cancellationToken);
        }

        public void AddFileEvent(PodeFileEvent fileEvent)
        {
            FileEvents.Add(fileEvent);
        }

        public void RemoveProcessingFileEvent(PodeFileEvent fileEvent)
        {
            FileEvents.RemoveProcessing(fileEvent);
        }

        public override void Start()
        {
            foreach (var watcher in FileWatchers)
            {
                watcher.Start();
            }

            base.Start();
        }

        protected override void Close()
        {
            // dispose watchers
            PodeHelpers.WriteErrorMessage($"Closing file watchers", PodeLogLevel.Verbose);

            foreach (var _watcher in FileWatchers.ToArray())
            {
                _watcher.Dispose();
            }

            FileWatchers.Clear();
            PodeHelpers.WriteErrorMessage($"Closed file watchers", PodeLogLevel.Verbose);

            // dispose existing file events
            PodeHelpers.WriteErrorMessage($"Closing file events", PodeLogLevel.Verbose);

            foreach (var _evt in FileEvents.ToArray())
            {
                _evt.Dispose();
            }

            FileEvents.Dispose();
            PodeHelpers.WriteErrorMessage($"Closed file events", PodeLogLevel.Verbose);
        }
    }
}