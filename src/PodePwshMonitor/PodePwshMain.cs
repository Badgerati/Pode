using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Configuration;
using System;

namespace Pode.Services
{
    public class Program
    {
        public static void Main(string[] args)
        {
            var customConfigFile = args.Length > 0 ? args[0] : "srvsettings.json"; // Custom config file from args or default

            try
            {
                Host.CreateDefaultBuilder(args)
                    .UseWindowsService()  // For running as a Windows service
                    .ConfigureAppConfiguration((context, config) =>
                    {
                        config.AddJsonFile(customConfigFile, optional: false, reloadOnChange: true);
                    })
                    .ConfigureServices((context, services) =>
                    {
                        services.Configure<PodePwshWorkerOptions>(context.Configuration.GetSection("PodePwshWorker"));
                        services.AddHostedService<PodePwshWorker>();
                    })
                    .Build()
                    .Run();
            }
            catch (Exception ex)
            {
                Console.WriteLine($"An error occurred: {ex.Message}");
            }
        }
    }
}
