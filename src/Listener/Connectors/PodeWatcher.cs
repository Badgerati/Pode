using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using Pode.FileSystemWatcher;
using Pode.Utilities;

namespace Pode.Connectors
{
    public class PodeWatcher : PodeConnector
    {
        private readonly List<PodeFileWatcher> FileWatchers;

        public PodeItemQueue<PodeFileEvent> FileEvents { get; private set; }

        public PodeWatcher(PodeConnectorType type, CancellationToken cancellationToken = default)
            : base(type, cancellationToken)
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
            PodeHelpers.WriteErrorMessage($"Closing file watchers", this, PodeLoggingLevel.Verbose);

            foreach (var _watcher in FileWatchers.ToArray())
            {
                _watcher.Dispose();
            }

            FileWatchers.Clear();
            PodeHelpers.WriteErrorMessage($"Closed file watchers", this, PodeLoggingLevel.Verbose);

            // dispose existing file events
            PodeHelpers.WriteErrorMessage($"Closing file events", this, PodeLoggingLevel.Verbose);

            foreach (var _evt in FileEvents.ToArray())
            {
                _evt.Dispose();
            }

            FileEvents.Dispose();
            PodeHelpers.WriteErrorMessage($"Closed file events", this, PodeLoggingLevel.Verbose);
        }
    }
}