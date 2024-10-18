using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using System;
using System.IO;
using System.Threading;
using System.Threading.Tasks;

namespace Pode.Services
{
    public class PodePwshWorker : BackgroundService
    {
        private readonly ILogger<PodePwshWorker> _logger;
        private PodePwshMonitor _pwshMonitor;

        public PodePwshWorker(ILogger<PodePwshWorker> logger, IOptions<PodePwshWorkerOptions> options)
        {
            _logger = logger;

            // Get options from configuration
            var workerOptions = options.Value;
            // Print options to console
            Console.WriteLine("Worker options: ");
            Console.WriteLine(workerOptions.ToString());

            _pwshMonitor = new PodePwshMonitor(
                workerOptions.ScriptPath,
                workerOptions.PwshPath,
                workerOptions.ParameterString,
                workerOptions.LogFilePath,
                workerOptions.Quiet,
                workerOptions.DisableTermination,
                workerOptions.ShutdownWaitTimeMs
            );
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            _logger.LogInformation("PodePwshWorker  running at: {time}", DateTimeOffset.Now);

            while (!stoppingToken.IsCancellationRequested)
            {
                _pwshMonitor.StartPowerShellProcess();
                await Task.Delay(10000, stoppingToken); // Monitor every 10 seconds
            }
        }

        public override Task StopAsync(CancellationToken stoppingToken)
        {
            _logger.LogInformation("Service is stopping at: {time}", DateTimeOffset.Now);
            _pwshMonitor.StopPowerShellProcess();
            return base.StopAsync(stoppingToken);
        }

        // Custom RestartAsync method that sends a restart message via pipe
        public Task RestartAsync()
        {
            _logger.LogInformation("Service is restarting at: {time}", DateTimeOffset.Now);

            // Send the 'restart' message using the pipe
            _pwshMonitor.RestartPowerShellProcess();

            _logger.LogInformation("Restart message sent via pipe at: {time}", DateTimeOffset.Now);
            return Task.CompletedTask;
        }
    }
}
