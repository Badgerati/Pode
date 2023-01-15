using System;
using System.Collections.Concurrent;
using System.ComponentModel;
using System.IO;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;

// A tweaked version of the FileSystemWatcher from https://github.com/petermeinl/LeanWork.IO.FileSystem.Watcher
namespace Pode.FileSystemWatcher
{
    public class BufferingFileSystemWatcher : Component
    {
        public PodeItemQueue<string> Contexts { get; private set; }
        public Task<string> GetContextAsync(CancellationToken cancellationToken = default(CancellationToken))
        {
            return Contexts.GetAsync(cancellationToken);
        }


        private System.IO.FileSystemWatcher _containedFSW = null;
        private FileSystemEventHandler _onExistedHandler = null;
        private FileSystemEventHandler _onAllChangesHandler = null;
        private FileSystemEventHandler _onCreatedHandler = null;
        private FileSystemEventHandler _onChangedHandler = null;
        private FileSystemEventHandler _onDeletedHandler = null;
        private RenamedEventHandler _onRenamedHandler = null;
        private ErrorEventHandler _onErrorHandler = null;
        private BlockingCollection<FileSystemEventArgs> _fileSystemEventBuffer = null;
        private CancellationTokenSource _cancellationTokenSource = null;

        public bool EnableRaisingEvents
        {
            get
            {
                return _containedFSW.EnableRaisingEvents;
            }
            set
            {
                if (_containedFSW.EnableRaisingEvents == value)
                {
                    return;
                }

                StopRaisingBufferedEvents();
                _cancellationTokenSource = new CancellationTokenSource();

                // We EnableRaisingEvents, before NotifyExistingFiles
                //   to prevent missing any events
                //   accepting more duplicates (which may occur anyway).
                _containedFSW.EnableRaisingEvents = value;
                if (value)
                {
                    RaiseBufferedEventsUntilCancelled();
                }
            }
        }

        public string Filter
        {
            get { return _containedFSW.Filter; }
            set { _containedFSW.Filter = value; }
        }

        public bool IncludeSubdirectories
        {
            get { return _containedFSW.IncludeSubdirectories; }
            set { _containedFSW.IncludeSubdirectories = value; }
        }

        public int InternalBufferSize
        {
            get { return _containedFSW.InternalBufferSize; }
            set { _containedFSW.InternalBufferSize = value; }
        }

        public NotifyFilters NotifyFilter
        {
            get { return _containedFSW.NotifyFilter; }
            set { _containedFSW.NotifyFilter = value; }
        }

        public string Path
        {
            get { return _containedFSW.Path; }
            set { _containedFSW.Path = value; }
        }

        public ISynchronizeInvoke SynchronizingObject
        {
            get { return _containedFSW.SynchronizingObject; }
            set { _containedFSW.SynchronizingObject = value; }
        }

        public override ISite Site
        {
            get { return _containedFSW.Site; }
            set { _containedFSW.Site = value; }
        }

        public bool OrderByOldestFirst { get; set; } = false;

        private int _eventQueueSize = int.MaxValue;
        public int EventQueueCapacity
        {
            get { return _eventQueueSize; }
            set { _eventQueueSize = value; }
        }

        public int Count
        {
            get { return _fileSystemEventBuffer.Count; }
        }


        public BufferingFileSystemWatcher()
        {
            _containedFSW = new System.IO.FileSystemWatcher();
            Contexts = new PodeItemQueue<string>();
        }

        public BufferingFileSystemWatcher(string path)
        {
            _containedFSW = new System.IO.FileSystemWatcher(path, "*.*");
            Contexts = new PodeItemQueue<string>();
        }

        public BufferingFileSystemWatcher(string path, string filter)
        {
            _containedFSW = new System.IO.FileSystemWatcher(path, filter);
            Contexts = new PodeItemQueue<string>();
        }


        public event FileSystemEventHandler Existed
        {
            add { _onExistedHandler += value; }
            remove { _onExistedHandler -= value; }
        }

        public event FileSystemEventHandler All
        {
            add
            {
                if (_onAllChangesHandler == null)
                {
                    _containedFSW.Created += BufferEvent;
                    _containedFSW.Changed += BufferEvent;
                    _containedFSW.Renamed += BufferEvent;
                    _containedFSW.Deleted += BufferEvent;
                }

                _onAllChangesHandler += value;
            }
            remove
            {
                _containedFSW.Created -= BufferEvent;
                _containedFSW.Changed -= BufferEvent;
                _containedFSW.Renamed -= BufferEvent;
                _containedFSW.Deleted -= BufferEvent;
                _onAllChangesHandler -= value;
            }
        }

        //- The _fsw events add to the buffer.
        //- The public events raise from the buffer to the consumer.
        public event FileSystemEventHandler Created
        {
            add
            {
                if (_onCreatedHandler == null)
                {
                    _containedFSW.Created += BufferEvent;
                }

                _onCreatedHandler += value;
            }
            remove
            {
                _containedFSW.Created -= BufferEvent;
                _onCreatedHandler -= value;
            }
        }

        public event FileSystemEventHandler Changed
        {
            add
            {
                if (_onChangedHandler == null)
                {
                    _containedFSW.Changed += BufferEvent;
                }

                _onChangedHandler += value;
            }
            remove
            {
                _containedFSW.Changed -= BufferEvent;
                _onChangedHandler -= value;
            }
        }

        public event FileSystemEventHandler Deleted
        {
            add
            {
                if (_onDeletedHandler == null)
                {
                    _containedFSW.Deleted += BufferEvent;
                }

                _onDeletedHandler += value;
            }
            remove
            {
                _containedFSW.Deleted -= BufferEvent;
                _onDeletedHandler -= value;
            }
        }

        public event RenamedEventHandler Renamed
        {
            add
            {
                if (_onRenamedHandler == null)
                {
                    _containedFSW.Renamed += BufferEvent;
                }

                _onRenamedHandler += value;
            }
            remove
            {
                _containedFSW.Renamed -= BufferEvent;
                _onRenamedHandler -= value;
            }
        }

        public event ErrorEventHandler Error
        {
            add
            {
                if (_onErrorHandler == null)
                {
                    _containedFSW.Error += BufferingFileSystemWatcher_Error;
                }

                _onErrorHandler += value;
            }
            remove
            {
                if (_onErrorHandler == null)
                {
                    _containedFSW.Error -= BufferingFileSystemWatcher_Error;
                }

                _onErrorHandler -= value;
            }
        }


        private string _lastFilePath = string.Empty;
        private DateTime _lastDateTime = DateTime.MinValue;

        private void BufferEvent(object _, FileSystemEventArgs e)
        {
            // prevent duplicate change events
            if (e.ChangeType == WatcherChangeTypes.Changed)
            {
                lock (_lastFilePath)
                {
                    if (e.FullPath == _lastFilePath && _lastDateTime.AddMilliseconds(500) > DateTime.UtcNow)
                    {
                        return;
                    }

                    _lastFilePath = e.FullPath;
                    _lastDateTime = DateTime.UtcNow;
                }
            }

            // add event to buffer
            if (!_fileSystemEventBuffer.TryAdd(e))
            {
                var ex = new EventQueueOverflowException($"Event queue size {_fileSystemEventBuffer.BoundedCapacity} events exceeded.");
                InvokeHandler(_onErrorHandler, new ErrorEventArgs(ex));
            }
        }

        private void StopRaisingBufferedEvents(object _ = null, EventArgs __ = null)
        {
            _cancellationTokenSource?.Cancel();
            _fileSystemEventBuffer = new BlockingCollection<FileSystemEventArgs>(_eventQueueSize);
        }


        private void BufferingFileSystemWatcher_Error(object sender, ErrorEventArgs e)
        {
            InvokeHandler(_onErrorHandler, e);
        }

        private void RaiseBufferedEventsUntilCancelled()
        {
            Task.Run(() =>
            {
                try
                {
                    if (_onExistedHandler != null || _onAllChangesHandler != null)
                    {
                        NotifyExistingFiles();
                    }

                    foreach (var e in _fileSystemEventBuffer.GetConsumingEnumerable(_cancellationTokenSource.Token))
                    {
                        if (_onAllChangesHandler != null)
                        {
                            InvokeHandler(_onAllChangesHandler, e);
                        }
                        else
                        {
                            switch (e.ChangeType)
                            {
                                case WatcherChangeTypes.Created:
                                    InvokeHandler(_onCreatedHandler, e);
                                    break;
                                case WatcherChangeTypes.Changed:
                                    InvokeHandler(_onChangedHandler, e);
                                    break;
                                case WatcherChangeTypes.Deleted:
                                    InvokeHandler(_onDeletedHandler, e);
                                    break;
                                case WatcherChangeTypes.Renamed:
                                    InvokeHandler(_onRenamedHandler, e as RenamedEventArgs);
                                    break;
                            }
                        }
                    }
                }
                catch (OperationCanceledException) { }
                catch (Exception ex)
                {
                    BufferingFileSystemWatcher_Error(this, new ErrorEventArgs(ex));
                }
            });
        }

        private void NotifyExistingFiles()
        {
            var searchSubDirectoriesOption = (IncludeSubdirectories ? SearchOption.AllDirectories : SearchOption.TopDirectoryOnly);

            var files = new DirectoryInfo(Path).GetFiles(Filter, searchSubDirectoriesOption);
            if (OrderByOldestFirst)
            {
                files = files.OrderBy(x => x.LastWriteTimeUtc).ToArray();
            }

            foreach (var file in files)
            {
                InvokeHandler(_onExistedHandler, new FileSystemEventArgs(WatcherChangeTypes.All, file.DirectoryName, file.Name));
                InvokeHandler(_onAllChangesHandler, new FileSystemEventArgs(WatcherChangeTypes.All, file.DirectoryName, file.Name));
            }
        }

        private void InvokeHandler(FileSystemEventHandler eventHandler, FileSystemEventArgs e)
        {
            if (eventHandler != null)
            {
                if (_containedFSW.SynchronizingObject != null && this._containedFSW.SynchronizingObject.InvokeRequired)
                {
                    _containedFSW.SynchronizingObject.BeginInvoke(eventHandler, new object[] { this, e });
                }
                else
                {
                    eventHandler(this, e);
                }
            }
        }

        private void InvokeHandler(RenamedEventHandler eventHandler, RenamedEventArgs e)
        {
            if (eventHandler != null)
            {
                if (_containedFSW.SynchronizingObject != null && this._containedFSW.SynchronizingObject.InvokeRequired)
                {
                    _containedFSW.SynchronizingObject.BeginInvoke(eventHandler, new object[] { this, e });
                }
                else
                {
                    eventHandler(this, e);
                }
            }
        }

        private void InvokeHandler(ErrorEventHandler eventHandler, ErrorEventArgs e)
        {
            if (eventHandler != null)
            {
                if (_containedFSW.SynchronizingObject != null && this._containedFSW.SynchronizingObject.InvokeRequired)
                {
                    _containedFSW.SynchronizingObject.BeginInvoke(eventHandler, new object[] { this, e });
                }
                else
                {
                    eventHandler(this, e);
                }
            }
        }


        protected override void Dispose(bool disposing)
        {
            if (disposing)
            {
                _cancellationTokenSource?.Cancel();
                _containedFSW?.Dispose();
                _fileSystemEventBuffer?.Dispose();

                _onExistedHandler = null;
                _onAllChangesHandler = null;
                _onCreatedHandler = null;
                _onChangedHandler = null;
                _onDeletedHandler = null;
                _onRenamedHandler = null;
                _onErrorHandler = null;
            }

            base.Dispose(disposing);
        }
    }
}