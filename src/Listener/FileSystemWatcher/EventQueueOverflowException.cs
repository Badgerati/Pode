using System;

// A tweaked version of the FileSystemWatcher from https://github.com/petermeinl/LeanWork.IO.FileSystem.Watcher
namespace Pode.FileSystemWatcher
{
    class EventQueueOverflowException : Exception
    {
        public EventQueueOverflowException()
            : base() { }

        public EventQueueOverflowException(string message)
            : base(message) { }
    }
}