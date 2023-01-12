using System;
using System.IO;

namespace Pode
{
    public class PodeFileEvent : IDisposable
    {
        public PodeFileWatcher FileWatcher { get; private set; }
        public PodeFileWatcherChangeType ChangeType { get; private set; }
        public string Name { get; private set; }
        public string FullPath { get; private set; }
        public string OldName { get; private set; }
        public string OldFullPath { get; private set; }

        public PodeFileEvent(PodeFileWatcher watcher, FileSystemEventArgs e)
        {
            FileWatcher = watcher;
            ChangeType = MapChangeType(e.ChangeType);
            Name = e.Name;
            FullPath = e.FullPath;

            if (ChangeType == PodeFileWatcherChangeType.Renamed)
            {
                var re = e as RenamedEventArgs;
                OldName = re.OldName;
                OldFullPath = re.OldFullPath;
            }
        }

        private PodeFileWatcherChangeType MapChangeType(WatcherChangeTypes type)
        {
            switch (type)
            {
                case WatcherChangeTypes.All:
                    return PodeFileWatcherChangeType.Existed;
                case WatcherChangeTypes.Changed:
                    return PodeFileWatcherChangeType.Changed;
                case WatcherChangeTypes.Created:
                    return PodeFileWatcherChangeType.Created;
                case WatcherChangeTypes.Deleted:
                    return PodeFileWatcherChangeType.Deleted;
                case WatcherChangeTypes.Renamed:
                    return PodeFileWatcherChangeType.Renamed;
                default:
                    return PodeFileWatcherChangeType.Errored;
            }
        }

        public void Dispose()
        {
            FileWatcher.Watcher.RemoveProcessingFileEvent(this);
            FileWatcher = null;
        }
    }
}