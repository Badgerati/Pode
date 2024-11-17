using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using System;
using System.IO;
using System.Threading;
using System.Threading.Tasks;

namespace Pode.Service
{
    /// <summary>
    /// Manages the lifecycle of the Pode PowerShell process, supporting start, stop, pause, and resume operations.
    /// Implements IPausableHostedService for handling pause and resume operations.
    /// </summary>
    public sealed class PodePwshWorker : BackgroundService, IPausableHostedService
    {
        // Logger instance for logging informational and error messages
        private readonly ILogger<PodePwshWorker> _logger;

        // Instance of PodePwshMonitor to manage the Pode PowerShell process
        private readonly PodePwshMonitor _pwshMonitor;

        // Tracks whether the worker is currently paused
        private volatile bool _isPaused;

        // Delay in milliseconds to prevent rapid consecutive operations
        private readonly int _delayMs = 5000;

        /// <summary>
        /// Initializes a new instance of the PodePwshWorker class.
        /// </summary>
        /// <param name="logger">Logger instance for logging messages and errors.</param>
        /// <param name="pwshMonitor">Instance of PodePwshMonitor for managing the PowerShell process.</param>
        public PodePwshWorker(ILogger<PodePwshWorker> logger, PodePwshMonitor pwshMonitor)
        {
            _logger = logger; // Assign the logger
            _pwshMonitor = pwshMonitor; // Assign the shared PodePwshMonitor instance
            _logger.LogInformation("PodePwshWorker initialized with shared PodePwshMonitor.");
        }

        /// <summary>
        /// The main execution loop for the worker.
        /// Monitors and restarts the Pode PowerShell process if needed.
        /// </summary>
        /// <param name="stoppingToken">Cancellation token to signal when the worker should stop.</param>
        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            PodePwshLogger.Log(LogLevel.INFO, "Server", "PodePwshWorker running at: {0}", DateTimeOffset.Now);
            int retryCount = 0; // Tracks the number of retries in case of failures

            while (!stoppingToken.IsCancellationRequested)
            {
                if (_isPaused)
                {
                    PodePwshLogger.Log(LogLevel.INFO, "Server", "Worker is paused. Waiting...");
                    await Task.Delay(1000, stoppingToken); // Wait while paused
                    continue;
                }

                try
                {
                    retryCount = 0; // Reset retry count on success

                    // Start the Pode PowerShell process
                    _pwshMonitor.StartPowerShellProcess();
                }
                catch (Exception ex)
                {
                    retryCount++;
                    PodePwshLogger.Log(LogLevel.ERROR, ex, "Error in ExecuteAsync: {0}. Retry {1}/{2}", ex.Message, retryCount, _pwshMonitor.StartMaxRetryCount);

                    // If retries exceed the maximum, log and exit the loop
                    if (retryCount >= _pwshMonitor.StartMaxRetryCount)
                    {
                        PodePwshLogger.Log(LogLevel.CRITICAL, "Maximum retry count reached. Exiting monitoring loop.");
                        break;
                    }

                    // Delay before retrying
                    await Task.Delay(_pwshMonitor.StartRetryDelayMs, stoppingToken);
                }

                // Add a delay between iterations
                await Task.Delay(10000, stoppingToken);
            }

            PodePwshLogger.Log(LogLevel.INFO, "Server", "Monitoring loop has stopped.");
        }

        /// <summary>
        /// Stops the Pode PowerShell process gracefully.
        /// </summary>
        /// <param name="stoppingToken">Cancellation token to signal when the stop should occur.</param>
        public override async Task StopAsync(CancellationToken stoppingToken)
        {
            PodePwshLogger.Log(LogLevel.INFO, "Server", "Service is stopping at: {0}", DateTimeOffset.Now);

            try
            {
                _pwshMonitor.StopPowerShellProcess(); // Stop the PowerShell process
            }
            catch (Exception ex)
            {
                PodePwshLogger.Log(LogLevel.ERROR, ex, "Error stopping PowerShell process: {0}", ex.Message);
            }

            await base.StopAsync(stoppingToken); // Wait for the base StopAsync to complete

            PodePwshLogger.Log(LogLevel.INFO, "Server", "Service stopped successfully at: {0}", DateTimeOffset.Now);
        }

        /// <summary>
        /// Restarts the Pode PowerShell process by sending a restart command.
        /// </summary>
        public void RestartAsync()
        {
            PodePwshLogger.Log(LogLevel.INFO, "Server", "Service restarting at: {0}", DateTimeOffset.Now);

            try
            {
                _pwshMonitor.RestartPowerShellProcess(); // Restart the process
                PodePwshLogger.Log(LogLevel.INFO, "Server", "Restart message sent via pipe at: {0}", DateTimeOffset.Now);
            }
            catch (Exception ex)
            {
                PodePwshLogger.Log(LogLevel.ERROR, ex, "Error during restart: {0}", ex.Message);
            }
        }

        /// <summary>
        /// Pauses the Pode PowerShell process and adds a delay to ensure stable operation.
        /// </summary>
        public void OnPause()
        {
            PodePwshLogger.Log(LogLevel.INFO, "Server", "Pause command received at: {0}", DateTimeOffset.Now);

            try
            {
                _pwshMonitor.SuspendPowerShellProcess(); // Send pause command to the process
                _isPaused = true; // Update the paused state

                PodePwshLogger.Log(LogLevel.INFO, "Server", "Suspend message sent via pipe at: {0}", DateTimeOffset.Now);

                AddOperationDelay("Pause"); // Delay to ensure stability
            }
            catch (Exception ex)
            {
                PodePwshLogger.Log(LogLevel.ERROR, ex, "Error during pause: {0}", ex.Message);
            }
        }

        /// <summary>
        /// Resumes the Pode PowerShell process and adds a delay to ensure stable operation.
        /// </summary>
        public void OnContinue()
        {
            PodePwshLogger.Log(LogLevel.INFO, "Server", "Continue command received at: {0}", DateTimeOffset.Now);

            try
            {
                _pwshMonitor.ResumePowerShellProcess(); // Send resume command to the process
                _isPaused = false; // Update the paused state

                PodePwshLogger.Log(LogLevel.INFO, "Server", "Resume message sent via pipe at: {0}", DateTimeOffset.Now);

                AddOperationDelay("Resume"); // Delay to ensure stability
            }
            catch (Exception ex)
            {
                PodePwshLogger.Log(LogLevel.ERROR, ex, "Error during continue: {0}", ex.Message);
            }
        }

        /// <summary>
        /// Adds a delay to ensure that rapid consecutive operations are prevented.
        /// </summary>
        /// <param name="operation">The name of the operation (e.g., "Pause" or "Resume").</param>
        private void AddOperationDelay(string operation)
        {
            PodePwshLogger.Log(LogLevel.DEBUG, "Server", "{0} operation completed. Adding delay of {1} ms.", operation, _delayMs);
            Thread.Sleep(_delayMs); // Introduce a delay
        }
    }
}
