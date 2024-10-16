using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

namespace PodePwshMonitorService
{
    public class Program
    {
        public static void Main(string[] args)
        {
            Host.CreateDefaultBuilder(args)
                .UseWindowsService()  // For running as a Windows service
                .ConfigureServices(services =>
                {
                    services.AddHostedService<PodeWorker>(); // Add your worker service here
                })
                .Build()
                .Run();
        }
    }
}
