using System;

namespace Pode
{
    /// <summary>
    /// Represents a server signal used by Pode that includes signal details and associated listener management.
    /// </summary>
    public class PodeServerSignal : IDisposable
    {
        private bool _disposed = false;

        /// <summary>
        /// Gets the value of the server signal.
        /// </summary>
        public string Value { get; private set; }

        /// <summary>
        /// Gets the path associated with the signal.
        /// </summary>
        public string Path { get; private set; }

        /// <summary>
        /// Gets the client identifier that originated the signal.
        /// </summary>
        public string ClientId { get; private set; }

        /// <summary>
        /// Gets the timestamp when the signal was created (in UTC).
        /// </summary>
        public DateTime Timestamp { get; private set; }

        /// <summary>
        /// Gets the listener associated with processing the signal.
        /// </summary>
        public PodeListener Listener { get; private set; }

        /// <summary>
        /// Initializes a new instance of the <see cref="PodeServerSignal"/> class.
        /// </summary>
        /// <param name="value">The value representing the signal.</param>
        /// <param name="path">The path associated with the signal request.</param>
        /// <param name="clientId">The unique identifier of the client.</param>
        /// <param name="listener">The listener managing the server signal.</param>
        public PodeServerSignal(string value, string path, string clientId, PodeListener listener)
        {
            Value = value;
            Path = path;
            ClientId = clientId;
            Timestamp = DateTime.UtcNow;
            Listener = listener;
        }

        /// <summary>
        /// Releases the unmanaged and optionally managed resources used by the <see cref="PodeServerSignal"/> instance.
        /// </summary>
        /// <param name="disposing">
        /// If set to <c>true</c>, both managed and unmanaged resources are disposed; if <c>false</c>, only unmanaged resources are disposed.
        /// </param>
        protected virtual void Dispose(bool disposing)
        {
            if (!_disposed)
            {
                if (disposing)
                {
                    // Dispose managed resources.
                    Listener?.RemoveProcessingServerSignal(this);
                }
                // Clean up unmanaged resources here if there are any.

                _disposed = true;
            }
        }

        /// <summary>
        /// Performs application-defined tasks associated with freeing, releasing, or resetting unmanaged resources.
        /// </summary>
        /// <remarks>
        /// This method calls <see cref="Dispose(bool)"/> with <c>true</c> and suppresses the finalization
        /// of the object, preventing any derived class finalizers from running unnecessarily.
        /// </remarks>
        public void Dispose()
        {
            Dispose(true);
            GC.SuppressFinalize(this);
        }
    }
}
