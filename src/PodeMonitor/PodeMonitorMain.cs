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

namespace PodeMonitor
{
    /// <summary>
    /// Entry point for the Pode service. Handles platform-specific configurations and signal-based operations.
    /// </summary>
    public static partial class Program
    {
        // Platform-dependent signal registration (for linux/macOS)
        [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
        private delegate void SignalHandler(int signum);

        [LibraryImport("libc", EntryPoint = "signal")]
        private static partial int Signal(int signum, SignalHandler handler);

        private const int SIGTSTP = 20; // Signal for pause
        private const int SIGCONT = 18; // Signal for continue
        private const int SIGHUP = 1;  // Signal for restart
        private const int SIGTERM = 15; // Signal for gracefully terminate a process.

        private static PodeMonitorWorker _workerInstance; // Global instance for managing worker operations
        private static bool _terminating = false;
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

            serviceName = config.GetSection("PodeMonitorWorker:Name").Value ?? serviceName;
            string logFilePath = config.GetSection("PodeMonitorWorker:logFilePath").Value ?? "PodeMonitorService.log";

            // Initialize logger
            PodeMonitorLogger.Initialize(logFilePath, LogLevel.INFO);

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
                PodeMonitorLogger.Log(LogLevel.WARN, "PodeMonitor", Environment.ProcessId, "Unsupported platform. Exiting.");
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
                    services.Configure<PodeMonitorWorkerOptions>(context.Configuration.GetSection("PodeMonitorWorker"));

                    // Register PodeMonitor
                    services.AddSingleton<PodeMonitor>(serviceProvider =>
                    {
                        var options = serviceProvider.GetRequiredService<IOptions<PodeMonitorWorkerOptions>>().Value;
                        PodeMonitorLogger.Log(LogLevel.INFO, "PodeMonitor", Environment.ProcessId, "Initializing PodeMonitor with options: {0}", JsonSerializer.Serialize(options));
                        return new PodeMonitor(options);
                    });

                    // Register PodeMonitorWorker and track the instance
                    services.AddSingleton(provider =>
                    {
                        var logger = provider.GetRequiredService<ILogger<PodeMonitorWorker>>();
                        var monitor = provider.GetRequiredService<PodeMonitor>();
                        var worker = new PodeMonitorWorker(logger, monitor);
                        _workerInstance = worker; // Track the instance globally
                        return worker;
                    });

                    // Add PodeMonitorWorker as a hosted service
                    services.AddHostedService(provider => provider.GetRequiredService<PodeMonitorWorker>());

                    // Register IPausableHostedService
                    services.AddSingleton<IPausableHostedService>(provider => provider.GetRequiredService<PodeMonitorWorker>());
                });
        }

#if ENABLE_LIFECYCLE_OPERATIONS
        /// <summary>
        /// Configures the Pode service for linux, including signal handling.
        /// </summary>
        /// <param name="builder">The host builder.</param>
        [SupportedOSPlatform("linux")]
        private static void ConfigureLinux(IHostBuilder builder)
        {
            // Handle linux signals for pause, resume, and restart
            Signal(SIGTSTP, HandleSignalStop);
            Signal(SIGCONT, HandleSignalContinue);
            Signal(SIGHUP, HandleSignalRestart);
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
            Signal(SIGTSTP, HandleSignalStop);
            Signal(SIGCONT, HandleSignalContinue);
            Signal(SIGHUP, HandleSignalRestart);
            Signal(SIGTERM, HandleSignalTerminate);
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
            var service = new PodeMonitorWindowsService(host, serviceName);
            ServiceBase.Run(service);
        }

        private static void HandleSignalStop(int signum)
        {
            if(!_terminating){
                PodeMonitorLogger.Log(LogLevel.INFO, "PodeMonitor", Environment.ProcessId, "SIGTSTP received. Pausing service.");
                HandlePause();
            }
        }

        private static void HandleSignalTerminate(int signum)
        {
            PodeMonitorLogger.Log(LogLevel.INFO, "PodeMonitor", Environment.ProcessId, "SIGTERM received. Stopping service.");
            _terminating=true;
            HandleStop();
        }

        private static void HandleSignalContinue(int signum)
        {
            PodeMonitorLogger.Log(LogLevel.INFO, "PodeMonitor", Environment.ProcessId, "SIGCONT received. Resuming service.");
            HandleContinue();
        }

        private static void HandleSignalRestart(int signum)
        {
            PodeMonitorLogger.Log(LogLevel.INFO, "PodeMonitor", Environment.ProcessId, "SIGHUP received. Restarting service.");
            HandleRestart();
        }

        private static void HandlePause() => _workerInstance?.OnPause();
        private static void HandleContinue() => _workerInstance?.OnContinue();
        private static void HandleRestart() => _workerInstance?.Restart();
        private static void HandleStop() => _workerInstance?.Shutdown();
#else
        [SupportedOSPlatform("linux")]
        private static void ConfigureLinux(IHostBuilder builder) => builder.UseSystemd().Build().Run();

        [SupportedOSPlatform("macOS")]
        private static void ConfigureMacOS(IHostBuilder builder) => builder.Build().Run();

        [SupportedOSPlatform("windows")]
        private static void ConfigureWindows(IHostBuilder builder, string serviceName) =>
                   builder.UseWindowsService().Build().Run();
#endif
    }
}
