using System;
using System.IO;
using System.ServiceProcess;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Configuration;
using System.Text.Json;
using Microsoft.Extensions.Options;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Runtime.Versioning;
using Microsoft.Extensions.Logging;

namespace Pode.Service
{
    /// <summary>
    /// Entry point for the Pode service. Handles platform-specific configurations and signal-based operations.
    /// </summary>
    public static partial class Program
    {
         // Platform-dependent signal registration (for Linux/macOS)
        [LibraryImport("libc", EntryPoint = "signal")]
        private static partial int Signal(int signum, Action<int> handler);


        private const int SIGSTOP = 19; // Signal for pause
        private const int SIGCONT = 18; // Signal for continue
        private const int SIGHUP = 1;  // Signal for restart
        private static PodePwshWorker _workerInstance; // Global instance for managing worker operations

        /// <summary>
        /// Entry point for the Pode service.
        /// </summary>
        /// <param name="args">Command-line arguments.</param>
        public static void Main(string[] args)
        {
            string customConfigFile = args.Length > 0 ? args[0] : "srvsettings.json"; // Default config file
            string serviceName = "PodeService";

            // Load configuration
            IConfigurationRoot config = new ConfigurationBuilder()
                .AddJsonFile(customConfigFile, optional: false, reloadOnChange: true)
                .Build();

            serviceName = config.GetSection("PodePwshWorker:Name").Value ?? serviceName;
            string logFilePath = config.GetSection("PodePwshWorker:logFilePath").Value ?? "PodePwshMonitorService.log";

            // Initialize logger
            PodePwshLogger.Initialize(logFilePath, LogLevel.INFO);

            // Configure host builder
            var builder = CreateHostBuilder(args, customConfigFile);

            // Platform-specific logic
            if (OperatingSystem.IsLinux())
            {
                ConfigureLinux(builder);
            }
            else if (OperatingSystem.IsWindows())
            {
                ConfigureWindows(builder, serviceName);
            }
            else if (OperatingSystem.IsMacOS())
            {
                ConfigureMacOS(builder);
            }
            else
            {
                PodePwshLogger.Log(LogLevel.WARN, "Server", Environment.ProcessId, "Unsupported platform. Exiting.");
            }
        }

        /// <summary>
        /// Creates and configures the host builder for the Pode service.
        /// </summary>
        /// <param name="args">Command-line arguments.</param>
        /// <param name="customConfigFile">Path to the custom configuration file.</param>
        /// <returns>The configured host builder.</returns>
        private static IHostBuilder CreateHostBuilder(string[] args, string customConfigFile)
        {
            return Host.CreateDefaultBuilder(args)
                .ConfigureAppConfiguration(config =>
                {
                    config.AddJsonFile(customConfigFile, optional: false, reloadOnChange: true);
                })
                .ConfigureServices((context, services) =>
                {
                    services.Configure<PodePwshWorkerOptions>(context.Configuration.GetSection("PodePwshWorker"));

                    // Register PodePwshMonitor
                    services.AddSingleton<PodePwshMonitor>(serviceProvider =>
                    {
                        var options = serviceProvider.GetRequiredService<IOptions<PodePwshWorkerOptions>>().Value;
                        PodePwshLogger.Log(LogLevel.INFO, "Server", Environment.ProcessId, "Initializing PodePwshMonitor with options: {0}", JsonSerializer.Serialize(options));
                        return new PodePwshMonitor(options);
                    });

                    // Register PodePwshWorker and track the instance
                    services.AddSingleton(provider =>
                    {
                        var logger = provider.GetRequiredService<ILogger<PodePwshWorker>>();
                        var monitor = provider.GetRequiredService<PodePwshMonitor>();
                        var worker = new PodePwshWorker(logger, monitor);
                        _workerInstance = worker; // Track the instance globally
                        return worker;
                    });

                    // Add PodePwshWorker as a hosted service
                    services.AddHostedService(provider => provider.GetRequiredService<PodePwshWorker>());

                    // Register IPausableHostedService
                    services.AddSingleton<IPausableHostedService>(provider => provider.GetRequiredService<PodePwshWorker>());
                });
        }

#if ENABLE_LIFECYCLE_OPERATIONS
        /// <summary>
        /// Configures the Pode service for Linux, including signal handling.
        /// </summary>
        /// <param name="builder">The host builder.</param>
        [SupportedOSPlatform("Linux")]
        private static void ConfigureLinux(IHostBuilder builder)
        {
            // Handle Linux signals for pause, resume, and restart
            _ = Signal(SIGSTOP, _ => HandlePause());
            _ = Signal(SIGCONT, _ => HandleContinue());
            _ = Signal(SIGHUP, _ => HandleRestart());

            builder.UseSystemd();
            builder.Build().Run();
        }

        /// <summary>
        /// Configures the Pode service for macOS, including signal handling.
        /// </summary>
        /// <param name="builder">The host builder.</param>
        [SupportedOSPlatform("macOS")]
        private static void ConfigureMacOS(IHostBuilder builder)
        {
            // Use launchd for macOS
            _ = Signal(SIGSTOP, _ => HandlePause());
            _ = Signal(SIGCONT, _ => HandleContinue());
            _ = Signal(SIGHUP, _ => HandleRestart());

            builder.Build().Run();
        }

        /// <summary>
        /// Configures the Pode service for Windows, enabling pause and continue support.
        /// </summary>
        /// <param name="builder">The host builder.</param>
        /// <param name="serviceName">The name of the service.</param>
        [SupportedOSPlatform("windows")]
        private static void ConfigureWindows(IHostBuilder builder, string serviceName)
        {
            using var host = builder.Build();
            var service = new PodeWindowsService(host, serviceName);
            ServiceBase.Run(service);

        }

        /// <summary>
        /// Handles the pause signal by pausing the Pode service.
        /// </summary>
        private static void HandlePause()
        {
            if (_workerInstance == null)
            {
                PodePwshLogger.Log(LogLevel.ERROR, "Server", Environment.ProcessId, "Pause requested, but _workerInstance is null.");
                return;
            }
            PodePwshLogger.Log(LogLevel.INFO, "Server", Environment.ProcessId, "Pausing service...");
            _workerInstance?.OnPause();
        }

        /// <summary>
        /// Handles the continue signal by resuming the Pode service.
        /// </summary>
        private static void HandleContinue()
        {
            if (_workerInstance == null)
            {
                PodePwshLogger.Log(LogLevel.ERROR, "Server", Environment.ProcessId, "Continue requested, but _workerInstance is null.");
                return;
            }
            PodePwshLogger.Log(LogLevel.INFO, "Server", Environment.ProcessId, "Resuming service...");
            _workerInstance?.OnContinue();
        }

        /// <summary>
        /// Handles the restart signal by restarting the Pode service.
        /// </summary>
        private static void HandleRestart()
        {
            if (_workerInstance == null)
            {
                PodePwshLogger.Log(LogLevel.ERROR, "Server", Environment.ProcessId, "Restart requested, but _workerInstance is null.");
                return;
            }
            PodePwshLogger.Log(LogLevel.INFO, "Server", Environment.ProcessId, "Restarting service...");
            _workerInstance?.Restart();
        }

        /// <summary>
        /// Performs cleanup operations before service termination.
        /// </summary>
        private static void Cleanup()
        {
            PodePwshLogger.Log(LogLevel.INFO, "Server", Environment.ProcessId, "Performing cleanup...");
            // Cleanup logic
        }
#else
        /// <summary>
        /// Configures the Pode service for Linux, including signal handling.
        /// </summary>
        /// <param name="builder">The host builder.</param>
        [SupportedOSPlatform("Linux")]
        private static void ConfigureLinux(IHostBuilder builder)
        {
            builder.UseSystemd();
            builder.Build().Run();
        }

        /// <summary>
        /// Configures the Pode service for macOS, including signal handling.
        /// </summary>
        /// <param name="builder">The host builder.</param>
        [SupportedOSPlatform("macOS")]
        private static void ConfigureMacOS(IHostBuilder builder)
        {
            builder.Build().Run();
        }

        /// <summary>
        /// Configures the Pode service for Windows, enabling pause and continue support.
        /// </summary>
        /// <param name="builder">The host builder.</param>
        /// <param name="serviceName">The name of the service.</param>
        private static void ConfigureWindows(IHostBuilder builder, string serviceName)
        {
            builder.UseWindowsService();
            builder.Build().Run();
        }

#endif
    }
}
