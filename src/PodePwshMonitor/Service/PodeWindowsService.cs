using System;
using System.IO;
using System.ServiceProcess;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using System.Runtime.Versioning;
using System.Diagnostics;

namespace Pode.Service
{
    /// <summary>
    /// Represents a Windows service that integrates with a Pode host and supports lifecycle operations such as start, stop, pause, continue, and restart.
    /// </summary>
    [SupportedOSPlatform("windows")]
    public class PodeWindowsService : ServiceBase
    {
        private readonly IHost _host; // The Pode host instance
        private const int CustomCommandRestart = 128; // Custom command for SIGHUP-like restart

        /// <summary>
        /// Initializes a new instance of the PodeWindowsService class.
        /// </summary>
        /// <param name="host">The host instance managing the Pode application.</param>
        /// <param name="serviceName">The name of the Windows service.</param>
        public PodeWindowsService(IHost host, string serviceName)
        {
            _host = host ?? throw new ArgumentNullException(nameof(host), "Host cannot be null.");
            CanPauseAndContinue = true; // Enable support for pause and continue operations
            ServiceName = serviceName ?? throw new ArgumentNullException(nameof(serviceName), "Service name cannot be null."); // Dynamically set the service name
        }

        /// <summary>
        /// Handles the service start operation. Initializes the Pode host and starts its execution.
        /// </summary>
        /// <param name="args">Command-line arguments passed to the service.</param>
        protected override void OnStart(string[] args)
        {
            PodePwshLogger.Log(LogLevel.INFO, "Server", Environment.ProcessId, "Service starting...");
            try
            {
                base.OnStart(args); // Call the base implementation
                _host.StartAsync().Wait(); // Start the Pode host asynchronously and wait for it to complete
                PodePwshLogger.Log(LogLevel.INFO, "Server", Environment.ProcessId, "Service started successfully.");
            }
            catch (Exception ex)
            {
                // Log the exception to the custom log
                PodePwshLogger.Log(LogLevel.ERROR, ex, "Service startup failed.");

                // Write critical errors to the Windows Event Log
                EventLog.WriteEntry(ServiceName, $"Critical failure during service startup: {ex.Message}\n{ex.StackTrace}",
                    EventLogEntryType.Error);

                // Rethrow the exception to signal failure to the Windows Service Manager
                throw;
            }
        }

        /// <summary>
        /// Handles the service stop operation. Gracefully stops the Pode host.
        /// </summary>
        protected override void OnStop()
        {
            PodePwshLogger.Log(LogLevel.INFO, "Server", Environment.ProcessId, "Service stopping...");
            base.OnStop(); // Call the base implementation
            _host.StopAsync().Wait(); // Stop the Pode host asynchronously and wait for it to complete
            PodePwshLogger.Log(LogLevel.INFO, "Server", Environment.ProcessId, "Service stopped successfully.");
        }

        /// <summary>
        /// Handles the service pause operation. Pauses the Pode host by invoking IPausableHostedService.
        /// </summary>
        protected override void OnPause()
        {
            PodePwshLogger.Log(LogLevel.INFO, "Server", Environment.ProcessId, "Service pausing...");
            base.OnPause(); // Call the base implementation

            // Retrieve the IPausableHostedService instance from the service container
            var service = _host.Services.GetService(typeof(IPausableHostedService));
            if (service != null)
            {
                PodePwshLogger.Log(LogLevel.DEBUG, "Server", Environment.ProcessId, $"Resolved IPausableHostedService: {service.GetType().FullName}");
                ((IPausableHostedService)service).OnPause(); // Invoke the pause operation
            }
            else
            {
                PodePwshLogger.Log(LogLevel.ERROR, "Server", Environment.ProcessId, "Error: Failed to resolve IPausableHostedService.");
            }
        }

        /// <summary>
        /// Handles the service resume operation. Resumes the Pode host by invoking IPausableHostedService.
        /// </summary>
        protected override void OnContinue()
        {
            PodePwshLogger.Log(LogLevel.INFO, "Server", Environment.ProcessId, "Service resuming...");
            base.OnContinue(); // Call the base implementation

            // Retrieve the IPausableHostedService instance from the service container
            var service = _host.Services.GetService(typeof(IPausableHostedService));
            if (service != null)
            {
                PodePwshLogger.Log(LogLevel.DEBUG, "Server", Environment.ProcessId, $"Resolved IPausableHostedService: {service.GetType().FullName}");
                ((IPausableHostedService)service).OnContinue(); // Invoke the resume operation
            }
            else
            {
                PodePwshLogger.Log(LogLevel.ERROR, "Server", Environment.ProcessId, "Error: Failed to resolve IPausableHostedService.");
            }
        }

        /// <summary>
        /// Handles custom control commands sent to the service. Supports a SIGHUP-like restart operation.
        /// </summary>
        /// <param name="command">The custom command number.</param>
        protected override void OnCustomCommand(int command)
        {
            if (command == CustomCommandRestart)
            {
                PodePwshLogger.Log(LogLevel.INFO, "Server", Environment.ProcessId, "Custom restart command received. Restarting service...");
                var service = _host.Services.GetService(typeof(IPausableHostedService));
                if (service != null)
                {
                    ((IPausableHostedService)service).Restart(); // Trigger the restart operation
                }
                else
                {
                    PodePwshLogger.Log(LogLevel.ERROR, "Server", Environment.ProcessId, "Error: Failed to resolve IPausableHostedService for restart.");
                }
            }
            else
            {
                base.OnCustomCommand(command); // Handle other custom commands
            }
        }
    }
}
