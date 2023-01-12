using System;

// A better FileSystemWatcher from https://github.com/petermeinl/LeanWork.IO.FileSystem.Watcher
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