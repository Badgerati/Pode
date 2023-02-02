using System.Collections.Generic;
using System.Threading;
using System.Linq;
using System.Threading.Tasks;

namespace Pode
{
    public class PodeWatcher : PodeConnector
    {
        private IList<PodeFileWatcher> FileWatchers;

        public PodeItemQueue<PodeFileEvent> FileEvents { get; private set; }

        public PodeWatcher(CancellationToken cancellationToken = default(CancellationToken))
            : base(cancellationToken)
        {
            FileWatchers = new List<PodeFileWatcher>();
            FileEvents = new PodeItemQueue<PodeFileEvent>();
        }

        public void AddFileWatcher(PodeFileWatcher watcher)
        {
            watcher.BindWatcher(this);
            FileWatchers.Add(watcher);
        }

        public Task<PodeFileEvent> GetFileEventAsync(CancellationToken cancellationToken = default(CancellationToken))
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

            FileEvents.Clear();
            PodeHelpers.WriteErrorMessage($"Closed file events", this, PodeLoggingLevel.Verbose);
        }
    }
}