/*
 * PodePwshMonitorService
 *
 * This service monitors and controls the execution of a Pode process using named pipes for communication.
 *
 * SC Command Reference for Managing Windows Services:
 *
 * Install Service:
 * sc create PodePwshMonitorService binPath= "C:\path\to\your\service\PodePwshMonitorService.exe" start= auto
 *
 * Start Service:
 * sc start PodePwshMonitorService
 *
 * Stop Service:
 * sc stop PodePwshMonitorService
 *
 * Delete Service:
 * sc delete PodePwshMonitorService
 *
 * Query Service Status:
 * sc query PodePwshMonitorService
 *
 * Configure Service to Restart on Failure:
 * sc failure PodePwshMonitorService reset= 0 actions= restart/60000
 *
 * Example for running the service:
 * sc start PodePwshMonitorService
 * sc stop PodePwshMonitorService
 * sc delete PodePwshMonitorService
 *
 */
using System;
using Microsoft.Extensions.Hosting;
using System.Diagnostics;
using System.IO;
using System.IO.Pipes;
using System.Threading.Tasks;
using System.Threading;
using Microsoft.Extensions.Options;

namespace Pode.Service
{
    public class PodePwshMonitor
    {
        private Process _powerShellProcess;
        private readonly string _scriptPath;
        private readonly string _parameterString;
        private string _pwshPath;
        private readonly bool _quiet;
        private readonly bool _disableTermination;
        private readonly int _shutdownWaitTimeMs;
        private string _pipeName;
        private NamedPipeClientStream _pipeClient;  // Changed to client stream
        private DateTime _lastLogTime;

        public int StartMaxRetryCount { get; private set; } // Maximum number of retries before breaking
        public int StartRetryDelayMs { get; private set; } // Delay between retries in milliseconds

        public PodePwshMonitor(PodePwshWorkerOptions options)
        {
            Console.WriteLine("logFilePath{0}", options.LogFilePath);
            // Initialize fields with constructor arguments
            _scriptPath = options.ScriptPath;                      // Path to the Pode script to be executed
            _pwshPath = options.PwshPath;                          // Path to the Pode executable (pwsh)
            _parameterString = options.ParameterString;            // Additional parameters to pass to the script (if any)
            _disableTermination = options.DisableTermination;      // Flag to disable termination of the service
            _quiet = options.Quiet;                                // Flag to suppress output for a quieter service
            _shutdownWaitTimeMs = options.ShutdownWaitTimeMs;      // Maximum wait time before forcefully shutting down the process
            StartMaxRetryCount = options.StartMaxRetryCount;
            StartRetryDelayMs = options.StartRetryDelayMs;

            // Dynamically generate a unique PipeName for communication
            _pipeName = $"PodePipe_{Guid.NewGuid()}";      // Generate a unique pipe name to avoid conflicts
        }


        public void StartPowerShellProcess()
        {
            if (_powerShellProcess == null || _powerShellProcess.HasExited)
            {
                try
                {
                    // Define the Pode process
                    _powerShellProcess = new Process
                    {
                        StartInfo = new ProcessStartInfo
                        {
                            FileName = _pwshPath,           // Set the Pode executable path (pwsh)
                            RedirectStandardOutput = true,  // Redirect standard output
                            RedirectStandardError = true,   // Redirect standard error
                            UseShellExecute = false,        // Do not use shell execution
                            CreateNoWindow = true           // Do not create a new window
                        }
                    };
                    Logger.Log(LogLevel.INFO, "Server", $"Starting ...");
                    // Properly escape double quotes within the JSON string
                    string podeServiceJson = $"{{\\\"DisableTermination\\\": {_disableTermination.ToString().ToLower()}, \\\"Quiet\\\": {_quiet.ToString().ToLower()}, \\\"PipeName\\\": \\\"{_pipeName}\\\"}}";
                    Logger.Log(LogLevel.INFO, "Server", $"Pode path {_pwshPath}");
                    Logger.Log(LogLevel.INFO, "Server", $"PodeService content:");
                    Logger.Log(LogLevel.INFO, "Server", $"DisableTermination\t= {_disableTermination.ToString().ToLower()}");
                    Logger.Log(LogLevel.INFO, "Server", $"Quiet\t= {_quiet.ToString().ToLower()}");
                    Logger.Log(LogLevel.INFO, "Server", $"PipeName\t= {_pipeName}");
                    // Build the Pode command with NoProfile and global variable initialization
                    string command = $"-NoProfile -Command \"& {{ $global:PodeService = '{podeServiceJson}' | ConvertFrom-Json; . '{_scriptPath}' {_parameterString} }}\"";

                    Logger.Log(LogLevel.INFO, "Server", $"Starting Pode process with command: {command}");

                    // Set the arguments for the Pode process
                    _powerShellProcess.StartInfo.Arguments = command;

                    // Start the process
                    _powerShellProcess.Start();

                    // Log output and error asynchronously
                    _powerShellProcess.OutputDataReceived += (sender, args) => Logger.Log(LogLevel.INFO, "Server", args.Data);
                    _powerShellProcess.ErrorDataReceived += (sender, args) => Logger.Log(LogLevel.INFO, "Server", args.Data);
                    _powerShellProcess.BeginOutputReadLine();
                    _powerShellProcess.BeginErrorReadLine();

                    _lastLogTime = DateTime.Now;
                    Logger.Log(LogLevel.INFO, "Server", "Pode process started successfully.");
                }
                catch (Exception ex)
                {
                    Logger.Log(LogLevel.ERROR, "Server", $"Failed to start Pode process: {ex.Message}");
                    Logger.Log(LogLevel.DEBUG, ex);
                }
            }
            else
            {
                // Log only if more than a minute has passed since the last log
                if ((DateTime.Now - _lastLogTime).TotalMinutes >= 5)
                {
                    Logger.Log(LogLevel.INFO, "Server", "Pode process is Alive.");
                    _lastLogTime = DateTime.Now;
                }
            }
        }

        public void StopPowerShellProcess()
        {
            try
            {
                _pipeClient = new NamedPipeClientStream(".", _pipeName, PipeDirection.InOut);
                Logger.Log(LogLevel.INFO, "Server", $"Connecting to the pipe server using pipe: {_pipeName}");

                // Connect to the Pode pipe server
                _pipeClient.Connect(10000);  // Wait for up to 10 seconds for the connection

                if (_pipeClient.IsConnected)
                {
                    // Send shutdown message and wait for the process to exit
                    SendPipeMessage("shutdown");
                    Logger.Log(LogLevel.INFO, "Server", $"Waiting up to {_shutdownWaitTimeMs} milliseconds for the Pode process to exit...");

                    // Timeout logic
                    int waited = 0;
                    int interval = 200; // Check every 200ms

                    while (!_powerShellProcess.HasExited && waited < _shutdownWaitTimeMs)
                    {
                        Thread.Sleep(interval);
                        waited += interval;
                    }

                    if (_powerShellProcess.HasExited)
                    {
                        Logger.Log(LogLevel.INFO, "Server", "Pode process has been shutdown gracefully.");
                    }
                    else
                    {
                        Logger.Log(LogLevel.WARN, "Server", $"Pode process did not exit in {_shutdownWaitTimeMs} milliseconds.");
                    }
                }
                else
                {
                    Logger.Log(LogLevel.ERROR, "Server", $"Failed to connect to the Pode pipe server using pipe: {_pipeName}");
                }

                // Forcefully kill the process if it's still running
                if (_powerShellProcess != null && !_powerShellProcess.HasExited)
                {
                    try
                    {
                        _powerShellProcess.Kill();
                        Logger.Log(LogLevel.INFO, "Server", "Pode process killed successfully.");
                    }
                    catch (Exception ex)
                    {
                        Logger.Log(LogLevel.ERROR, "Server", $"Error killing Pode process: {ex.Message}");
                        Logger.Log(LogLevel.DEBUG, ex);
                    }
                }
            }
            catch (Exception ex)
            {
                Logger.Log(LogLevel.ERROR, "Server", $"Error stopping Pode process: {ex.Message}");
                Logger.Log(LogLevel.DEBUG, ex);

            }
            finally
            {
                // Set _powerShellProcess to null only if it's still not null
                if (_powerShellProcess != null)
                {
                    _powerShellProcess?.Dispose();
                    _powerShellProcess = null;
                }
                // Clean up the pipe client
                if (_pipeClient != null)
                {
                    _pipeClient?.Dispose();
                    _pipeClient = null;
                }
                Logger.Log(LogLevel.DEBUG, "Server", "Pode process and pipe client disposed.");
                Logger.Log(LogLevel.INFO, "Server", "Done.");
            }
        }

        public void RestartPowerShellProcess()
        {
            // Simply send the restart message, no need to stop and start again
            if (_pipeClient != null && _pipeClient.IsConnected)
            {
                SendPipeMessage("restart"); // Inform Pode about the restart
                Logger.Log(LogLevel.INFO, "Server", "Restart message sent to PowerShell.");
            }
        }

        public void SuspendPowerShellProcess()
        {
            try
            {
                _pipeClient = new NamedPipeClientStream(".", _pipeName, PipeDirection.InOut);
                Logger.Log(LogLevel.INFO, "Server", $"Connecting to the pipe server using pipe: {_pipeName}");

                // Connect to the Pode pipe server
                _pipeClient.Connect(20000);  // Wait for up to 10 seconds for the connection
                                             // Simply send the restart message, no need to stop and start again
                if (_pipeClient.IsConnected)
                {
                    SendPipeMessage("suspend"); // Inform Pode about the restart
                    Logger.Log(LogLevel.INFO, "Server", "Suspend message sent to PowerShell.");
                }
            }
            catch (Exception ex)
            {
                Logger.Log(LogLevel.ERROR, "Server", $"Error suspending Pode process: {ex.Message}");
                Logger.Log(LogLevel.DEBUG, ex);
            }
            finally
            {
                // Clean up the pipe client
                if (_pipeClient != null)
                {
                    _pipeClient?.Dispose();
                    _pipeClient = null;
                }
                Logger.Log(LogLevel.DEBUG, "Server", "Pode process and pipe client disposed.");
                Logger.Log(LogLevel.INFO, "Server", "Done.");
            }
        }

        public void ResumePowerShellProcess()
        {
            try
            {
                _pipeClient = new NamedPipeClientStream(".", _pipeName, PipeDirection.InOut);
                Logger.Log(LogLevel.INFO, "Server", $"Connecting to the pipe server using pipe: {_pipeName}");

                // Connect to the Pode pipe server
                _pipeClient.Connect(10000);  // Wait for up to 10 seconds for the connection
                                             // Simply send the restart message, no need to stop and start again
                if (_pipeClient != null && _pipeClient.IsConnected)
                {
                    SendPipeMessage("resume"); // Inform Pode about the restart
                    Logger.Log(LogLevel.INFO, "Server", "Resume message sent to PowerShell.");
                }
            }
            catch (Exception ex)
            {
                Logger.Log(LogLevel.ERROR, "Server", $"Error resuming Pode process: {ex.Message}");
                Logger.Log(LogLevel.DEBUG, ex);
            }
            finally
            {
                // Clean up the pipe client
                if (_pipeClient != null)
                {
                    _pipeClient?.Dispose();
                    _pipeClient = null;
                }
                Logger.Log(LogLevel.DEBUG, "Server", "Pode process and pipe client disposed.");
                Logger.Log(LogLevel.INFO, "Server", "Done.");
            }
        }

        private void SendPipeMessage(string message)
        {
            Logger.Log(LogLevel.INFO, "Server", "SendPipeMessage: {0}", message);

            // Write the message to the pipe

            if (_pipeClient == null)
            {
                Logger.Log(LogLevel.ERROR, "Server", "Pipe client is not initialized, cannot send message.");
                return;
            }

            if (!_pipeClient.IsConnected)
            {
                Logger.Log(LogLevel.ERROR, "Server", "Pipe client is not connected, cannot send message.");
                return;
            }

            try
            {
                // Send the message using the pipe client stream
                using var writer = new StreamWriter(_pipeClient, leaveOpen: true); // leaveOpen to keep the pipe alive for multiple writes
                writer.AutoFlush = true;
                writer.WriteLine(message);
                Logger.Log(LogLevel.INFO, "Server", $"Message sent to PowerShell: {message}");
            }
            catch (Exception ex)
            {
                Logger.Log(LogLevel.ERROR, "Server", $"Failed to send message to PowerShell: {ex.Message}");
                Logger.Log(LogLevel.DEBUG, ex);
            }
        }

    }
}
