namespace PodeMonitor
{
    /// <summary>
    /// Enum representing possible states of the Pode service.
    /// </summary>
    public enum PodeMonitorServiceState
    {
        Unknown,    // State is unknown

        /// <summary>
        /// The server has been completely Stopped and is no longer running.
        /// </summary>
        Stopped,

        /// <summary>
        /// The server is in the process of Stopping and shutting down its operations.
        /// </summary>
        Stopping,

        /// <summary>
        /// The server is resuming from a suspended state and is starting to run again.
        /// </summary>
        Resuming,

        /// <summary>
        /// The server is in the process of suspending its operations.
        /// </summary>
        Suspending,

        /// <summary>
        /// The server is currently suspended and not processing any requests.
        /// </summary>
        Suspended,

        /// <summary>
        /// The server is in the process of restarting its operations.
        /// </summary>
        Restarting,

        /// <summary>
        /// The server is starting its operations.
        /// </summary>
        Starting,

        /// <summary>
        /// The server is running and actively processing requests.
        /// </summary>
        Running
    }

}