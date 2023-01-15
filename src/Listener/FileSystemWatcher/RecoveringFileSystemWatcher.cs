using System;
using System.ComponentModel;
using System.IO;
using System.Threading;

// A tweaked version of the FileSystemWatcher from https://github.com/petermeinl/LeanWork.IO.FileSystem.Watcher
namespace Pode.FileSystemWatcher
{
    public class RecoveringFileSystemWatcher : BufferingFileSystemWatcher
    {
        public TimeSpan DirectoryMonitorInterval = TimeSpan.FromMinutes(5);
        public TimeSpan DirectoryRetryInterval = TimeSpan.FromSeconds(5);
        private System.Threading.Timer _monitorTimer = null;
        private bool _isRecovering = false;


        public RecoveringFileSystemWatcher()
            : base() { }

        public RecoveringFileSystemWatcher(string path)
            : base(path, "*.*") { }

        public RecoveringFileSystemWatcher(string path, string filter)
            : base(path, filter) { }


        // To allow consumer to cancel default error handling
        private EventHandler<FileWatcherErrorEventArgs> _onErrorHandler = null;
        public new event EventHandler<FileWatcherErrorEventArgs> Error
        {
            add { _onErrorHandler += value; }
            remove { _onErrorHandler -= value; }
        }

        public new bool EnableRaisingEvents
        {
            get { return base.EnableRaisingEvents; }
            set
            {
                if (value == EnableRaisingEvents)
                {
                    return;
                }

                base.EnableRaisingEvents = value;
                if (EnableRaisingEvents)
                {
                    base.Error += BufferingFileSystemWatcher_Error;
                    Start();
                }
                else
                {
                    base.Error -= BufferingFileSystemWatcher_Error;
                }
            }
        }

        private void Start()
        {
            try
            {
                _monitorTimer = new System.Threading.Timer(_monitorTimer_Elapsed);

                Disposed += (_, __) =>
                {
                    _monitorTimer.Dispose();
                };

                RestartIfNecessary(TimeSpan.Zero);
            }
            catch (Exception)
            {
                throw;
            }
        }

        private void _monitorTimer_Elapsed(object state)
        {
            try
            {
                if (!Directory.Exists(Path))
                {
                    throw new DirectoryNotFoundException($"Directory not found {Path}");
                }
                else
                {
                    if (!EnableRaisingEvents)
                    {
                        EnableRaisingEvents = true;
                    }

                    RestartIfNecessary(DirectoryMonitorInterval);
                }
            }
            catch (Exception ex) when (ex is FileNotFoundException || ex is DirectoryNotFoundException)
            {
                // Handles race condition too: Path loses accessibility between .Exists() and .EnableRaisingEvents 
                if (ExceptionWasHandledByCaller(ex))
                {
                    return;
                }

                if (!_isRecovering)
                {
                    _isRecovering = true;
                }

                EnableRaisingEvents = false;
                _isRecovering = true;
                RestartIfNecessary(DirectoryRetryInterval);
            }
            catch (Exception)
            {
                throw;
            }
        }

        private void RestartIfNecessary(TimeSpan delay)
        {
            try
            {
                _monitorTimer.Change(delay, Timeout.InfiniteTimeSpan);
            }
            catch (ObjectDisposedException) { } // ignore timer disposed     
        }

       private void BufferingFileSystemWatcher_Error(object sender, ErrorEventArgs e)
        {
            // These exceptions have the same HResult
            var NetworkNameNoLongerAvailable = -2147467259; // occurs on network outage
            var AccessIsDenied = -2147467259; // occurs after directory was deleted

            var ex = e.GetException();
            if (ExceptionWasHandledByCaller(e.GetException()))
            {
                return;
            }

            // The base FSW does set .EnableRaisingEvents=False AFTER raising OnError()
            EnableRaisingEvents = false;

            if (ex is InternalBufferOverflowException || ex is EventQueueOverflowException)
            {
                RestartIfNecessary(DirectoryRetryInterval);
            }
            else if (ex is Win32Exception && (ex.HResult == NetworkNameNoLongerAvailable | ex.HResult == AccessIsDenied))
            {
                RestartIfNecessary(DirectoryRetryInterval);
            }
            else
            {
                throw ex;
            }
        }

        private bool ExceptionWasHandledByCaller(Exception ex)
        {
            // Allow consumer to handle error
            if (_onErrorHandler != null)
            {
                var e = new FileWatcherErrorEventArgs(ex);
                InvokeHandler(_onErrorHandler, e);
                return e.Handled;
            }
            else
            {
                return false;
            }
        }

        private void InvokeHandler(EventHandler<FileWatcherErrorEventArgs> eventHandler, FileWatcherErrorEventArgs e)
        {
            if (eventHandler != null)
            {
                if (SynchronizingObject != null && this.SynchronizingObject.InvokeRequired)
                {
                    SynchronizingObject.BeginInvoke(eventHandler, new object[] { this, e });
                }
                else
                {
                    eventHandler(this, e);
                }
            }
        }
    }
}