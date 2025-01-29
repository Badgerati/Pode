/// <summary>
/// Represents the various states a Pode server can be in.
/// </summary>
namespace Pode
{
    /// <summary>
    /// Enum for defining the states of the Pode server.
    /// </summary>
    public enum PodeServerState
    {
        /// <summary>
        /// The server has been completely terminated and is no longer running.
        /// </summary>
        Terminated,

        /// <summary>
        /// The server is in the process of terminating and shutting down its operations.
        /// </summary>
        Terminating,

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
