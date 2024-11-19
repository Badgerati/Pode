using System;

namespace PodeMonitor
{
    /// <summary>
    /// Configuration options for the PodeMonitorWorker service.
    /// These options determine how the worker operates, including paths, parameters, and retry policies.
    /// </summary>
    public class PodeMonitorWorkerOptions
    {

        /// <summary>
        /// The name of the service.
        /// </summary>
        public string Name { get; set; }

        /// <summary>
        /// The path to the PowerShell script that the worker will execute.
        /// </summary>
        public string ScriptPath { get; set; }

        /// <summary>
        /// The path to the PowerShell executable (pwsh).
        /// </summary>
        public string PwshPath { get; set; }

        /// <summary>
        /// Additional parameters to pass to the PowerShell process.
        /// Default is an empty string.
        /// </summary>
        public string ParameterString { get; set; } = "";

        /// <summary>
        /// The path to the log file where output from the PowerShell process will be written.
        /// Default is an empty string (no logging).
        /// </summary>
        public string LogFilePath { get; set; } = "";

        /// <summary>
        /// Indicates whether the PowerShell process should run in quiet mode, suppressing output.
        /// Default is true.
        /// </summary>
        public bool Quiet { get; set; } = true;

        /// <summary>
        /// Indicates whether termination of the PowerShell process is disabled.
        /// Default is true.
        /// </summary>
        public bool DisableTermination { get; set; } = true;

        /// <summary>
        /// The maximum time to wait (in milliseconds) for the PowerShell process to shut down.
        /// Default is 30,000 milliseconds (30 seconds).
        /// </summary>
        public int ShutdownWaitTimeMs { get; set; } = 30000;

        /// <summary>
        /// The maximum number of retries to start the PowerShell process before giving up.
        /// Default is 3 retries.
        /// </summary>
        public int StartMaxRetryCount { get; set; } = 3;

        /// <summary>
        /// The delay (in milliseconds) between retry attempts to start the PowerShell process.
        /// Default is 5,000 milliseconds (5 seconds).
        /// </summary>
        public int StartRetryDelayMs { get; set; } = 5000;

        /// <summary>
        /// Provides a string representation of the configured options for debugging or logging purposes.
        /// </summary>
        /// <returns>A string containing all configured options and their values.</returns>
        public override string ToString()
        {
            return $"Name: {Name}, ScriptPath: {ScriptPath}, PwshPath: {PwshPath}, ParameterString: {ParameterString}, " +
                    $"LogFilePath: {LogFilePath}, Quiet: {Quiet}, DisableTermination: {DisableTermination}, " +
                    $"ShutdownWaitTimeMs: {ShutdownWaitTimeMs}, StartMaxRetryCount: {StartMaxRetryCount}, " +
                    $"StartRetryDelayMs: {StartRetryDelayMs}";
        }
    }
}
