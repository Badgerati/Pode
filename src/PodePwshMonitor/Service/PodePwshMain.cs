using System;
using System.IO;
using System.ServiceProcess;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Configuration;
using System.Text.Json;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using System.Diagnostics;


namespace Pode.Service
{
    public static class Program
    {
        public static void Main(string[] args)
        {
            var customConfigFile = args.Length > 0 ? args[0] : "srvsettings.json"; // Custom config file from args or default


            // Retrieve the service name from the configuration
            string serviceName = "PodeService";
            var config = new ConfigurationBuilder()
                .AddJsonFile(customConfigFile, optional: false, reloadOnChange: true)
                .Build();
            serviceName = config.GetSection("PodePwshWorker:Name").Value ?? serviceName;
            PodePwshLogger.Initialize(config.GetSection("PodePwshWorker:logFilePath").Value ?? "PodePwshMonitorService.log", LogLevel.INFO);

            var builder = Host.CreateDefaultBuilder(args)
                 .ConfigureAppConfiguration((context, config) =>
                 {
                     // Load configuration from the specified JSON file
                     config.AddJsonFile(customConfigFile, optional: false, reloadOnChange: true);
                 })
                 .ConfigureServices((context, services) =>
                 {
                     // Bind the PodePwshWorkerOptions section from configuration
                     services.Configure<PodePwshWorkerOptions>(context.Configuration.GetSection("PodePwshWorker"));

                     // Add the PodePwshWorker as a hosted service
                     services.AddHostedService<PodePwshWorker>();

#if WINDOWS
                    // Register PodePwshMonitor as a singleton with proper error handling
                    services.AddSingleton<PodePwshMonitor>(serviceProvider =>
                    {
                        try
                        {
                            // Retrieve worker options from the service provider
                            var options = serviceProvider.GetRequiredService<IOptions<PodePwshWorkerOptions>>().Value;

                            // Log the options for debugging
                            PodePwshLogger.Log(LogLevel.INFO,"Server","Initializing PodePwshMonitor with options: {0}", JsonSerializer.Serialize(options));

                            // Return the configured PodePwshMonitor instance
                            return new PodePwshMonitor(options);
                        }
                        catch (Exception ex)
                        {
                            // Log and write critical errors to the Event Log
                            PodePwshLogger.Log(LogLevel.ERROR,ex, "Failed to initialize PodePwshMonitor.");


                            throw; // Rethrow to terminate the application
                        }
                    });

                    // Register IPausableHostedService for handling pause and continue operations
                    services.AddSingleton<IPausableHostedService, PodePwshWorker>();
#endif
                 });


            // Check if running on Linux and use Systemd
            if (OperatingSystem.IsLinux())
            {
                builder.UseSystemd();
                builder.Build().Run();
            }
            // Check if running on Windows and use Windows Service
            else if (OperatingSystem.IsWindows())
            {
                //builder.UseWindowsService();
                // Windows-specific logic for CanPauseAndContinue
#if WINDOWS
                using var host = builder.Build();
                var service = new PodeWindowsService(host,serviceName);
                ServiceBase.Run(service);
#else
                builder.UseWindowsService();
                builder.Build().Run();
#endif
            }
            else if (OperatingSystem.IsMacOS())
            {
                // No specific macOS service manager, it runs under launchd
                builder.Build().Run();
            }
            else
            {
                // Fallback for unsupported platforms
                PodePwshLogger.Log(LogLevel.WARN, "Server", "Unsupported platform. Exiting.");
                return;
            }

        }
    }
}
