using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using System;
using System.IO;
using System.Threading;
using System.Threading.Tasks;

namespace Pode.Service
{
    public sealed class PodePwshWorker : BackgroundService, IPausableHostedService
    {
        private readonly ILogger<PodePwshWorker> _logger;
        private PodePwshMonitor _pwshMonitor;

        private volatile bool _isPaused;

        private int _delayMs = 5000; // 5 seconds delay

        public PodePwshWorker(ILogger<PodePwshWorker> logger, PodePwshMonitor pwshMonitor)
        {
            _logger = logger;
            _pwshMonitor = pwshMonitor; // Shared instance
            _logger.LogInformation("PodePwshWorker initialized with shared PodePwshMonitor.");
        }


        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            PodePwshLogger.Log(LogLevel.INFO, "Server", "PodePwshWorker running at: {0}", DateTimeOffset.Now);

            int retryCount = 0;

            while (!stoppingToken.IsCancellationRequested)
            {
                if (_isPaused)
                {
                    PodePwshLogger.Log(LogLevel.INFO, "Server", "Worker is paused. Waiting...");
                    await Task.Delay(1000, stoppingToken); // Pause handling
                    continue;
                }
                try
                {
                    // Reset retry count on successful execution
                    retryCount = 0;

                    // Start the PowerShell process
                    _pwshMonitor.StartPowerShellProcess();

                }
                catch (Exception ex)
                {
                    retryCount++;
                    PodePwshLogger.Log(LogLevel.ERROR, ex, "An error occurred in ExecuteAsync: {0}. Retry {1}/{2}", ex.Message, retryCount, _pwshMonitor.StartMaxRetryCount);

                    // Check if maximum retries have been reached
                    if (retryCount >= _pwshMonitor.StartMaxRetryCount)
                    {
                        PodePwshLogger.Log(LogLevel.CRITICAL, "Maximum retry count reached. Breaking the monitoring loop.");
                        break; // Exit the loop
                    }

                    // Wait for a while before retrying
                    try
                    {
                        await Task.Delay(_pwshMonitor.StartRetryDelayMs, stoppingToken);
                    }
                    catch (OperationCanceledException)
                    {
                        PodePwshLogger.Log(LogLevel.WARN, "Server", "Operation canceled during retry delay.");
                        break; // Exit the loop if the operation is canceled
                    }
                }
                // Wait before the next monitoring iteration
                await Task.Delay(10000, stoppingToken);
            }

            PodePwshLogger.Log(LogLevel.INFO, "Server", "Monitoring loop has stopped.");
        }


        public override async Task StopAsync(CancellationToken stoppingToken)
        {
            PodePwshLogger.Log(LogLevel.INFO, "Server", "Service is stopping at: {0}", DateTimeOffset.Now);
            try
            {
                _pwshMonitor.StopPowerShellProcess();
            }
            catch (Exception ex)
            {
                PodePwshLogger.Log(LogLevel.ERROR, ex, "Error while stopping PowerShell process: {message}", ex.Message);
            }
            // Wait for the base StopAsync to complete
            await base.StopAsync(stoppingToken);

            PodePwshLogger.Log(LogLevel.INFO, "Server", "Service stopped successfully at: {0}", DateTimeOffset.Now);

        }

        // Custom RestartAsync method that sends a restart message via pipe
        public void RestartAsync()
        {
            PodePwshLogger.Log(LogLevel.INFO, "Server", "Service is restarting at: {0}", DateTimeOffset.Now);
            try
            {
                // Send the 'restart' message using the pipe
                _pwshMonitor.RestartPowerShellProcess();

                PodePwshLogger.Log(LogLevel.INFO, "Server", "Restart message sent via pipe at: {0}", DateTimeOffset.Now);

            }
            catch (Exception ex)
            {
                PodePwshLogger.Log(LogLevel.ERROR, ex, "An error occurred during restart: {message}", ex.Message);
            }
        }


        public void OnPause()
        {
            PodePwshLogger.Log(LogLevel.INFO, "Server", "Pause command received at: {0}", DateTimeOffset.Now);

            try
            {
                _pwshMonitor.SuspendPowerShellProcess();
                _isPaused = true;
                PodePwshLogger.Log(LogLevel.INFO, "Server", "Suspend message sent via pipe at: {0}", DateTimeOffset.Now);

                // Add delay to prevent rapid consecutive operations
                PodePwshLogger.Log(LogLevel.DEBUG, "Server", "Delaying for {0} ms to ensure stable operation.", _delayMs);
                Thread.Sleep(_delayMs);
            }
            catch (Exception ex)
            {
                PodePwshLogger.Log(LogLevel.ERROR, ex, "Error occurred while suspending PowerShell process: {message}", ex.Message);
            }
        }

        public void OnContinue()
        {
            PodePwshLogger.Log(LogLevel.INFO, "Server", "Continue command received at: {0}", DateTimeOffset.Now);

            try
            {
                _pwshMonitor.ResumePowerShellProcess();
                _isPaused = false;
                PodePwshLogger.Log(LogLevel.INFO, "Server", "Resume message sent via pipe at: {0}", DateTimeOffset.Now);

                // Add delay to prevent rapid consecutive operations
                PodePwshLogger.Log(LogLevel.DEBUG, "Server", "Delaying for {0} ms to ensure stable operation.", _delayMs);
                Thread.Sleep(_delayMs);
            }
            catch (Exception ex)
            {
                PodePwshLogger.Log(LogLevel.ERROR, ex, "Error occurred while resuming PowerShell process: {message}", ex.Message);
            }
        }
    }
}
