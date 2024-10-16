using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using System;
using System.Diagnostics;
using System.IO;
using System.Threading;
using System.Threading.Tasks;
namespace PodePwshMonitorService
{
    public class PodeWorker : BackgroundService
    {
        private readonly ILogger<PodeWorker> _logger;
        private PodePwshMonitor _pwshMonitor;

        public PodeWorker(ILogger<PodeWorker> logger)
        {
            _logger = logger;
            string scriptPath = @"C:\Users\m_dan\Documents\GitHub\Pode\examples\HelloWorld\HelloWorld.ps1"; // Update with your script path
            string pwshPath = @"C:\Program Files\PowerShell\7\pwsh.exe"; // Update with your PowerShell path
            _pwshMonitor = new PodePwshMonitor(scriptPath, pwshPath,"", false);
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            _logger.LogInformation("PodeWorker running at: {time}", DateTimeOffset.Now);

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
    }
}