using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using System;
using System.IO;
using System.Threading;
using System.Threading.Tasks;

namespace Pode.Services
{
    public sealed  class PodePwshWorker : BackgroundService, IPausableHostedService
    {
        private readonly ILogger<PodePwshWorker> _logger;
        private PodePwshMonitor _pwshMonitor;
        private readonly int maxRetryCount; // Maximum number of retries before breaking
        private readonly int retryDelayMs; // Delay between retries in milliseconds

        private volatile bool _isPaused;

        public PodePwshWorker(ILogger<PodePwshWorker> logger, IOptions<PodePwshWorkerOptions> options)
        {
            _logger = logger;

            // Get options from configuration
            var workerOptions = options.Value;
            // Print options to console
            Program.Log("Worker options: ");
            Program.Log(workerOptions.ToString());

            _pwshMonitor = new PodePwshMonitor(
                workerOptions.ScriptPath,
                workerOptions.PwshPath,
                workerOptions.ParameterString,
                workerOptions.LogFilePath,
                workerOptions.Quiet,
                workerOptions.DisableTermination,
                workerOptions.ShutdownWaitTimeMs
            );

            maxRetryCount = workerOptions.StartMaxRetryCount;
            retryDelayMs = workerOptions.StartRetryDelayMs;

           Program.Log("PodePwshWorker initialized with options: {@Options}", workerOptions);

        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
           Program.Log("PodePwshWorker running at: {0}", DateTimeOffset.Now);

            int retryCount = 0;

            while (!stoppingToken.IsCancellationRequested)
            {
                if (_isPaused)
                {
                   Program.Log("Worker is paused. Waiting...");
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
                   Program.Log(ex, "An error occurred in ExecuteAsync: {0}. Retry {1}/{2}", ex.Message, retryCount, maxRetryCount);

                    // Check if maximum retries have been reached
                    if (retryCount >= maxRetryCount)
                    {
                        _logger.LogCritical("Maximum retry count reached. Breaking the monitoring loop.");
                        break; // Exit the loop
                    }

                    // Wait for a while before retrying
                    try
                    {
                        await Task.Delay(retryDelayMs, stoppingToken);
                    }
                    catch (OperationCanceledException)
                    {
                       Program.Log("Operation canceled during retry delay.");
                        break; // Exit the loop if the operation is canceled
                    }
                }
                // Wait before the next monitoring iteration
                await Task.Delay(10000, stoppingToken);
            }

           Program.Log("Monitoring loop has stopped.");
        }


        public override async Task StopAsync(CancellationToken stoppingToken)
        {
           Program.Log("Service is stopping at: {0}", DateTimeOffset.Now);
            try
            {
                _pwshMonitor.StopPowerShellProcess();
            }
            catch (Exception ex)
            {
                Program.Log(ex, "Error while stopping PowerShell process: {message}", ex.Message);
            }
            // Wait for the base StopAsync to complete
            await base.StopAsync(stoppingToken);

           Program.Log("Service stopped successfully at: {0}", DateTimeOffset.Now);

        }

        // Custom RestartAsync method that sends a restart message via pipe
        public void RestartAsync()
        {
           Program.Log("Service is restarting at: {0}", DateTimeOffset.Now);
            try
            {
                // Send the 'restart' message using the pipe
                _pwshMonitor.RestartPowerShellProcess();

               Program.Log("Restart message sent via pipe at: {0}", DateTimeOffset.Now);

            }
            catch (Exception ex)
            {
                Program.Log(ex, "An error occurred during restart: {message}", ex.Message);
            }
        }


        public void OnPause()
        {
           Program.Log("Pause command received at: {0}", DateTimeOffset.Now);

            try
            {
                _pwshMonitor.SuspendPowerShellProcess();
                _isPaused = true;
               Program.Log("Suspend message sent via pipe at: {0}", DateTimeOffset.Now);
            }
            catch (Exception ex)
            {
                Program.Log(ex, "Error occurred while suspending PowerShell process: {message}", ex.Message);
            }
        }

        public void OnContinue()
        {
           Program.Log("Continue command received at: {0}", DateTimeOffset.Now);

            try
            {
                _pwshMonitor.ResumePowerShellProcess();
                _isPaused = false;
               Program.Log("Resume message sent via pipe at: {0}", DateTimeOffset.Now);
            }
            catch (Exception ex)
            {
                Program.Log(ex, "Error occurred while resuming PowerShell process: {message}", ex.Message);
            }
        }
    }
}
