using System;
using System.IO;
using System.ServiceProcess;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Configuration;
using System.Text.Json;
using Microsoft.Extensions.Logging;


namespace Pode.Services
{
    public static class Program
    {
        private static string logFilePath;
        public static void Main(string[] args)
        {
            var customConfigFile = args.Length > 0 ? args[0] : "srvsettings.json"; // Custom config file from args or default


            // Retrieve the service name from the configuration
            string serviceName = "PodeService";
            var config = new ConfigurationBuilder()
                .AddJsonFile(customConfigFile, optional: false, reloadOnChange: true)
                .Build();
            serviceName = config.GetSection("PodePwshWorker:Name").Value ?? serviceName;
            logFilePath = config.GetSection("PodePwshWorker:logFilePath").Value ?? "PodePwshMonitorService.log";


            // Configure the host builder
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

#if WINDOWS
                    services.AddSingleton<IPausableHostedService, PodePwshWorker>(); // Registers the interface
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
                Console.WriteLine("Unsupported platform. Exiting.");
                return;
            }

        }

        public static void Log(string message, params object[] args)
        {
            if (!string.IsNullOrEmpty(message))
            {
                try
                {
                    // Format the message with the provided arguments
                    var formattedMessage = string.Format(message, args);

                    // Write log entry to file, create the file if it doesn't exist
                    using StreamWriter writer = new(logFilePath, true);
                    if (formattedMessage.Contains("[Client]"))
                    {
                        writer.WriteLine($"{DateTime.Now:yyyy-MM-dd HH:mm:ss} - {formattedMessage}");
                    }
                    else
                    {
                        writer.WriteLine($"{DateTime.Now:yyyy-MM-dd HH:mm:ss} - [Server] - {formattedMessage}");
                    }

                }
                catch (Exception ex)
                {
                    Console.WriteLine($"Failed to log to file: {ex.Message}");
                }
            }
        }


        public static void Log(Exception exception, string message = null, params object[] args)
        {
            if (exception == null && string.IsNullOrEmpty(message))
            {
                return; // Nothing to log
            }

            try
            {
                // Format the message if provided
                var logMessage = string.Empty;

                if (!string.IsNullOrEmpty(message))
                {
                    logMessage = string.Format(message, args);
                }

                // Add exception details if provided
                if (exception != null)
                {
                    logMessage += $"{Environment.NewLine}Exception: {exception.GetType().Name}";
                    logMessage += $"{Environment.NewLine}Message: {exception.Message}";
                    logMessage += $"{Environment.NewLine}Stack Trace: {exception.StackTrace}";

                    // Include inner exception details if any
                    var innerException = exception.InnerException;
                    while (innerException != null)
                    {
                        logMessage += $"{Environment.NewLine}Inner Exception: {innerException.GetType().Name}";
                        logMessage += $"{Environment.NewLine}Message: {innerException.Message}";
                        logMessage += $"{Environment.NewLine}Stack Trace: {innerException.StackTrace}";
                        innerException = innerException.InnerException;
                    }
                }

                // Write log entry to file
                using StreamWriter writer = new(logFilePath, true);
                if (logMessage.Contains("[Client]"))
                {
                    writer.WriteLine($"{DateTime.Now:yyyy-MM-dd HH:mm:ss} - {logMessage}");
                }
                else
                {
                    writer.WriteLine($"{DateTime.Now:yyyy-MM-dd HH:mm:ss} - [Server] - {logMessage}");
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Failed to log to file: {ex.Message}");
            }
        }
    }
}
