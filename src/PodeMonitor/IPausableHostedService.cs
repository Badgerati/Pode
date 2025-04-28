namespace PodeMonitor
{
    /// <summary>
    /// Defines a contract for a hosted service that supports pausing and resuming.
    /// </summary>
    public interface IPausableHostedService
    {
        /// <summary>
        /// Pauses the hosted service.
        /// This method is called when the service receives a pause command.
        /// </summary>
        void OnPause();

        /// <summary>
        /// Resumes the hosted service.
        /// This method is called when the service receives a continue command after being paused.
        /// </summary>
        void OnContinue();



        void Restart();

        public PodeMonitorServiceState State { get; }
    }
}
