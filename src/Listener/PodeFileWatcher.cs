using System.Collections.Generic;
using System.IO;
using Pode.FileSystemWatcher;

namespace Pode
{
    public class PodeFileWatcher
    {
        public PodeWatcher Watcher;
        private RecoveringFileSystemWatcher FileWatcher;

        public string Name { get; private set; }
        public ISet<PodeFileWatcherChangeType> EventsRegistered { get; private set; }

        public PodeFileWatcher(string name, string path, bool includeSubdirectories, int internalBufferSize, NotifyFilters notifyFilters)
        {
            Name = name;

            FileWatcher = new RecoveringFileSystemWatcher(path);
            FileWatcher.IncludeSubdirectories = includeSubdirectories;
            FileWatcher.InternalBufferSize = internalBufferSize;
            FileWatcher.NotifyFilter = notifyFilters;

            EventsRegistered = new HashSet<PodeFileWatcherChangeType>();
            RegisterEvent(PodeFileWatcherChangeType.Errored);
        }

        public void BindWatcher(PodeWatcher watcher)
        {
            Watcher = watcher;
        }

        public void RegisterEvent(PodeFileWatcherChangeType type)
        {
            EventsRegistered.Add(type);
        }

        public void Start()
        {
            foreach (var evt in EventsRegistered)
            {
                switch (evt)
                {
                    case PodeFileWatcherChangeType.Created:
                        FileWatcher.Created += FileEventHandler;
                        break;

                    case PodeFileWatcherChangeType.Changed:
                        FileWatcher.Changed += FileEventHandler;
                        break;

                    case PodeFileWatcherChangeType.Deleted:
                        FileWatcher.Deleted += FileEventHandler;
                        break;

                    case PodeFileWatcherChangeType.Existed:
                        FileWatcher.Existed += FileEventHandler;
                        break;

                    case PodeFileWatcherChangeType.Renamed:
                        FileWatcher.Renamed += FileEventHandler;
                        break;

                    case PodeFileWatcherChangeType.Errored:
                        FileWatcher.Error += FileErrorEventHandler;
                        break;
                }
            }

            FileWatcher.EnableRaisingEvents = true;
        }

        public void Dispose()
        {
            if (FileWatcher != default(RecoveringFileSystemWatcher))
            {
                FileWatcher.Dispose();
            }
        }

        private void FileEventHandler(object _, FileSystemEventArgs e)
        {
            Watcher.AddFileEvent(new PodeFileEvent(this, e));
        }

        private void FileErrorEventHandler(object _, FileWatcherErrorEventArgs e)
        {
            PodeHelpers.WriteException(e.Error, Watcher);
        }
    }
}