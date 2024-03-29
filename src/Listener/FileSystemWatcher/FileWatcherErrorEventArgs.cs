using System;
using System.ComponentModel;

// A tweaked version of the FileSystemWatcher from https://github.com/petermeinl/LeanWork.IO.FileSystem.Watcher
namespace Pode.FileSystemWatcher
{
    public class FileWatcherErrorEventArgs : HandledEventArgs
    {
        public readonly Exception Error;

        public FileWatcherErrorEventArgs(Exception exception)
        {
            this.Error = exception;
        }
    }
}