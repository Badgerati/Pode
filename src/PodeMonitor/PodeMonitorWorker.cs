using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using System;
using System.IO;
using System.Threading;
using System.Threading.Tasks;

namespace PodeMonitor
{
    /// <summary>
    /// Manages the lifecycle of the Pode PowerShell process, supporting start, stop, pause, and resume operations.
    /// Implements IPausableHostedService for handling pause and resume operations.
    /// </summary>
    public sealed class PodeMonitorWorker : BackgroundService, IPausableHostedService
    {
        // Logger instance for logging informational and error messages
        private readonly ILogger<PodeMonitorWorker> _logger;

        // Instance of PodeMonitor to manage the Pode PowerShell process
        private readonly PodeMonitor _pwshMonitor;

        // Delay in milliseconds to prevent rapid consecutive operations
        private readonly int _delayMs = 5000;

        private bool _terminating=false;

       private bool  _suspended=false;

        private bool _running=false;
        /// <summary>
        /// Initializes a new instance of the PodeMonitorWorker class.
        /// </summary>
        /// <param name="logger">Logger instance for logging messages and errors.</param>
        /// <param name="pwshMonitor">Instance of PodeMonitor for managing the PowerShell process.</param>
        public PodeMonitorWorker(ILogger<PodeMonitorWorker> logger, PodeMonitor pwshMonitor)
        {
            _logger = logger; // Assign the logger
            _pwshMonitor = pwshMonitor; // Assign the shared PodeMonitor instance
            _logger.LogInformation("PodeMonitorWorker initialized with shared PodeMonitor.");
        }

        /// <summary>
        /// The main execution loop for the worker.
        /// Monitors and restarts the Pode PowerShell process if needed.
        /// </summary>
        /// <param name="stoppingToken">Cancellation token to signal when the worker should stop.</param>
        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            PodeMonitorLogger.Log(LogLevel.INFO, "PodeMonitor", Environment.ProcessId, "PodeMonitorWorker running at: {0}", DateTimeOffset.Now);
            int retryCount = 0; // Tracks the number of retries in case of failures

            while (!stoppingToken.IsCancellationRequested)
            {
                try
                {
                    retryCount = 0; // Reset retry count on success

                    // Start the Pode PowerShell process
                    _pwshMonitor.StartPowerShellProcess();
                    _running=true;
                }
                catch (Exception ex)
                {
                    retryCount++;
                    PodeMonitorLogger.Log(LogLevel.ERROR, ex, "Error in ExecuteAsync: {0}. Retry {1}/{2}", ex.Message, retryCount, _pwshMonitor.StartMaxRetryCount);

                    // If retries exceed the maximum, log and exit the loop
                    if (retryCount >= _pwshMonitor.StartMaxRetryCount)
                    {
                        PodeMonitorLogger.Log(LogLevel.CRITICAL, "PodeMonitor", Environment.ProcessId, "Maximum retry count reached. Exiting monitoring loop.");
                        break;
                    }

                    // Delay before retrying
                    await Task.Delay(_pwshMonitor.StartRetryDelayMs, stoppingToken);
                }

                // Add a delay between iterations
                await Task.Delay(10000, stoppingToken);
            }

            PodeMonitorLogger.Log(LogLevel.INFO, "PodeMonitor", Environment.ProcessId, "Monitoring loop has stopped.");
        }

        /// <summary>
        /// Stops the Pode PowerShell process gracefully.
        /// </summary>
        /// <param name="stoppingToken">Cancellation token to signal when the stop should occur.</param>
        public override async Task StopAsync(CancellationToken stoppingToken)
        {
            Shutdown();

            await base.StopAsync(stoppingToken); // Wait for the base StopAsync to complete

            PodeMonitorLogger.Log(LogLevel.INFO, "PodeMonitor", Environment.ProcessId, "Service stopped successfully at: {0}", DateTimeOffset.Now);
        }


        /// <summary>
        /// Shutdown the Pode PowerShell process by sending a shutdown command.
        /// </summary>
        public void Shutdown()
        {
            if((! _terminating )&& _running){

            _terminating=true;
            PodeMonitorLogger.Log(LogLevel.INFO, "PodeMonitor", Environment.ProcessId, "Service is stopping at: {0}", DateTimeOffset.Now);

            try
            {
                _pwshMonitor.StopPowerShellProcess(); // Stop the process
                  _running=false;
                PodeMonitorLogger.Log(LogLevel.INFO, "PodeMonitor", Environment.ProcessId, "Stop message sent via pipe at: {0}", DateTimeOffset.Now);
            }
            catch (Exception ex)
            {
                PodeMonitorLogger.Log(LogLevel.ERROR, ex, "Error stopping PowerShell process: {0}", ex.Message);
            }}
        }

        /// <summary>
        /// Restarts the Pode PowerShell process by sending a restart command.
        /// </summary>
        public void Restart()
        {
            if((! _terminating )&& _running){

                PodeMonitorLogger.Log(LogLevel.INFO, "PodeMonitor", Environment.ProcessId, "Service restarting at: {0}", DateTimeOffset.Now);

                try
                {
                    _pwshMonitor.RestartPowerShellProcess(); // Restart the process
                    PodeMonitorLogger.Log(LogLevel.INFO, "PodeMonitor", Environment.ProcessId, "Restart message sent via pipe at: {0}", DateTimeOffset.Now);
                }
                catch (Exception ex)
                {
                    PodeMonitorLogger.Log(LogLevel.ERROR, ex, "Error during restart: {0}", ex.Message);
                }
            }
        }

        /// <summary>
        /// Pauses the Pode PowerShell process and adds a delay to ensure stable operation.
        /// </summary>
        public void OnPause()
        {
              if((! _terminating )&& _running){
            PodeMonitorLogger.Log(LogLevel.INFO, "PodeMonitor", Environment.ProcessId, "Pause command received at: {0}", DateTimeOffset.Now);

            try
            {
                _pwshMonitor.SuspendPowerShellProcess(); // Send pause command to the process
_suspended=true;
                PodeMonitorLogger.Log(LogLevel.INFO, "PodeMonitor", Environment.ProcessId, "Suspend message sent via pipe at: {0}", DateTimeOffset.Now);

                AddOperationDelay("Pause"); // Delay to ensure stability
            }
            catch (Exception ex)
            {
                PodeMonitorLogger.Log(LogLevel.ERROR, ex, "Error during pause: {0}", ex.Message);
            }
              }
        }

        /// <summary>
        /// Resumes the Pode PowerShell process and adds a delay to ensure stable operation.
        /// </summary>
        public void OnContinue()
        {
            if((! _terminating )&& _suspended){
                PodeMonitorLogger.Log(LogLevel.INFO, "PodeMonitor", Environment.ProcessId, "Continue command received at: {0}", DateTimeOffset.Now);

                try
                {
                    _pwshMonitor.ResumePowerShellProcess(); // Send resume command to the process

_suspended=false;
                    PodeMonitorLogger.Log(LogLevel.INFO, "PodeMonitor", Environment.ProcessId, "Resume message sent via pipe at: {0}", DateTimeOffset.Now);

                    AddOperationDelay("Resume"); // Delay to ensure stability
                }
                catch (Exception ex)
                {
                    PodeMonitorLogger.Log(LogLevel.ERROR, ex, "Error during continue: {0}", ex.Message);
                }
            }
        }

        /// <summary>
        /// Adds a delay to ensure that rapid consecutive operations are prevented.
        /// </summary>
        /// <param name="operation">The name of the operation (e.g., "Pause" or "Resume").</param>
        private void AddOperationDelay(string operation)
        {
            PodeMonitorLogger.Log(LogLevel.DEBUG, "PodeMonitor", Environment.ProcessId, "{0} operation completed. Adding delay of {1} ms.", operation, _delayMs);
            Thread.Sleep(_delayMs); // Introduce a delay
        }
    }
}
