using System;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Configuration;


namespace Pode.Services
{
    public class Program
    {
        public static void Main(string[] args)
        {
            var customConfigFile = args.Length > 0 ? args[0] : "srvsettings.json"; // Custom config file from args or default

            var builder = Host.CreateDefaultBuilder(args)
                .ConfigureAppConfiguration((context, config) =>
                {
                    config.AddJsonFile(customConfigFile, optional: false, reloadOnChange: true);
                })
                .ConfigureServices((context, services) =>
                {
                    // Bind configuration to PodePwshWorkerOptions
                    services.Configure<PodePwshWorkerOptions>(context.Configuration.GetSection("PodePwshWorker"));

                    // Add your worker service
                    services.AddHostedService<PodePwshWorker>();
                });

            // Check if running on Linux and use Systemd
            if (OperatingSystem.IsLinux())
            {
                builder.UseSystemd();
            }
            // Check if running on Windows and use Windows Service
            else if (OperatingSystem.IsWindows())
            {
                builder.UseWindowsService();
            }
             else if (OperatingSystem.IsMacOS())
            {
                // No specific macOS service manager, it runs under launchd
            }

            builder.Build().Run();
        }
    }
}
