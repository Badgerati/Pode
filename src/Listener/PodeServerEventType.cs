namespace Pode
{
    /// <summary>
    /// Represents the types of events a Pode server can trigger or respond to.
    /// </summary>
    public enum PodeServerEventType
    {
        /// <summary>
        /// Triggered when the server starts.
        /// </summary>
        Start,

        /// <summary>
        /// Triggered when the server is initializing.
        /// </summary>
        Starting,

        /// <summary>
        /// Triggered when the server terminates.
        /// </summary>
        Terminate,

        /// <summary>
        /// Triggered when the server begins the restart process.
        /// </summary>
        Restarting,

        /// <summary>
        /// Triggered when the server completes the restart process.
        /// </summary>
        Restart,

        /// <summary>
        /// Triggered when a user opens a web page pointing to the first HTTP/HTTPS endpoint.
        /// </summary>
        Browser,

        /// <summary>
        /// Triggered when the server crashes unexpectedly.
        /// </summary>
        Crash,

        /// <summary>
        /// Triggered when the server stops.
        /// </summary>
        Stop,

        /// <summary>
        /// Indicates that the server is running (retained for backward compatibility).
        /// </summary>
        Running,

        /// <summary>
        /// Triggered when the server begins the suspension process.
        /// </summary>
        Suspending,

        /// <summary>
        /// Triggered when the server completes the suspension process.
        /// </summary>
        Suspend,

        /// <summary>
        /// Triggered when the server resumes operation after suspension.
        /// </summary>
        Resume,

        /// <summary>
        /// Triggered when the server is enabled.
        /// </summary>
        Enable,

        /// <summary>
        /// Triggered when the server is disabled.
        /// </summary>
        Disable
    }
}
