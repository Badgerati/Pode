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
        /// Triggered when the server terminates.
        /// </summary>
        Terminate,

        /// <summary>
        /// Triggered when the server restarts.
        /// </summary>
        Restart,

        /// <summary>
        /// Triggered when the user opens a web page to point to the first HTTP/HTTPS endpoint.
        /// </summary>
        Browser,

        /// <summary>
        /// Triggered when the server crashes.
        /// </summary>
        Crash,

        /// <summary>
        /// Triggered when the server stops.
        /// </summary>
        Stop,

        /// <summary>
        /// Indicates the server is running (retained for backward compatibility).
        /// </summary>
        Running,

        /// <summary>
        /// Triggered when the server is suspended.
        /// </summary>
        Suspend,

        /// <summary>
        /// Triggered when the server resumes.
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
