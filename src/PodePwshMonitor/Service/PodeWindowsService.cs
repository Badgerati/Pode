#if WINDOWS
using System;
using Microsoft.Extensions.Hosting;
using System.ServiceProcess;
using System.Runtime.Versioning;
using System.Diagnostics;


namespace Pode.Service
{
    [SupportedOSPlatform("windows")]
    public class PodeWindowsService : ServiceBase
    {
        private readonly IHost _host;


        public PodeWindowsService(IHost host, string serviceName )
        {
            _host = host;
            CanPauseAndContinue = true;
            ServiceName = serviceName; // Dynamically set the service name
        }

        protected override void OnStart(string[] args)
        {
            Logger.Log(LogLevel.INFO,"Server","Service starting...");
            try{
                base.OnStart(args);
                _host.StartAsync().Wait();
                Logger.Log(LogLevel.INFO,"Server","Service started successfully.");}
            catch (Exception ex)
            {
                 // Log the exception details to your custom log file
                Logger.Log(LogLevel.ERROR,ex, "Service startup failed.");

                // Optionally write to the Windows Event Viewer for critical errors
                EventLog.WriteEntry(ServiceName, $"Critical failure during service startup: {ex.Message}\n{ex.StackTrace}",
                    EventLogEntryType.Error);

                // Rethrow the exception to signal failure to the Windows Service Manager
                throw;
            }
        }

        protected override void OnStop()
        {
            Logger.Log(LogLevel.INFO,"Server","Service stopping...");
            base.OnStop();
            _host.StopAsync().Wait();
            Logger.Log(LogLevel.INFO,"Server","Service stopped successfully.");
        }

        protected override void OnPause()
        {
            Logger.Log(LogLevel.INFO,"Server","Service pausing...");
            base.OnPause();
            var service = _host.Services.GetService(typeof(IPausableHostedService));
            if (service != null)
            {
                Logger.Log(LogLevel.DEBUG,"Server",$"Resolved IPausableHostedService: {service.GetType().FullName}");
                ((IPausableHostedService)service).OnPause();
            }
            else
            {
                Logger.Log(LogLevel.ERROR,"Server","Error:Failed to resolve IPausableHostedService.");
            }
        }

        protected override void OnContinue()
        {
            Logger.Log(LogLevel.INFO,"Server","Service resuming...");
            base.OnContinue();
            var service = _host.Services.GetService(typeof(IPausableHostedService));
            if (service != null)
            {
                Logger.Log(LogLevel.DEBUG,"Server",$"Resolved IPausableHostedService: {service.GetType().FullName}");
                ((IPausableHostedService)service).OnContinue();
            }
            else
            {
                 Logger.Log(LogLevel.ERROR,"Server","Error:Failed to resolve IPausableHostedService.");
            }
        }
    }
}
#endif