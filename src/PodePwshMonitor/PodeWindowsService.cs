#if WINDOWS
using System;
using Microsoft.Extensions.Hosting;
using System.ServiceProcess;
using System.Runtime.Versioning;

namespace Pode.Services
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
            Program.Log("Service starting...");
            base.OnStart(args);
            _host.StartAsync().Wait();
            Program.Log("Service started successfully.");
        }

        protected override void OnStop()
        {
            Program.Log("Service stopping...");
            base.OnStop();
            _host.StopAsync().Wait();
            Program.Log("Service stopped successfully.");
        }

        protected override void OnPause()
        {
            Program.Log("Service pausing...");
            base.OnPause();
            var service = _host.Services.GetService(typeof(IPausableHostedService));
            if (service != null)
            {
                Program.Log($"Resolved IPausableHostedService: {service.GetType().FullName}");
                ((IPausableHostedService)service).OnPause();
            }
            else
            {
                Program.Log("Error:Failed to resolve IPausableHostedService.");
            }
        }

        protected override void OnContinue()
        {
            Program.Log("Service resuming...");
            base.OnContinue();
            var service = _host.Services.GetService(typeof(IPausableHostedService));
            if (service != null)
            {
                Program.Log($"Resolved IPausableHostedService: {service.GetType().FullName}");
                ((IPausableHostedService)service).OnContinue();
            }
            else
            {
                 Program.Log("Error:Failed to resolve IPausableHostedService.");
            }
        }
    }
}
#endif