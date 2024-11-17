/*
 * PodePwshMonitorService
 *
 * This service monitors and controls the execution of a PowerShell process using named pipes for communication.
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

namespace Pode.Services
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

        // private static string _logFilePath; // Path to log file

        public PodePwshMonitor(string scriptPath, string pwshPath, string parameterString = "", string logFilePath = ".\\PodePwshMonitorService.log", bool quiet = true, bool disableTermination = true, int shutdownWaitTimeMs = 30000)
        {
            Console.WriteLine("logFilePath{0}", logFilePath);
            // Initialize fields with constructor arguments
            _scriptPath = scriptPath;                      // Path to the PowerShell script to be executed
            _pwshPath = pwshPath;                          // Path to the PowerShell executable (pwsh)
            _parameterString = parameterString;            // Additional parameters to pass to the script (if any)
            _disableTermination = disableTermination;      // Flag to disable termination of the service
            _quiet = quiet;                                // Flag to suppress output for a quieter service
            _shutdownWaitTimeMs = shutdownWaitTimeMs;      // Maximum wait time before forcefully shutting down the process
                                                           //   _logFilePath = logFilePath ?? ".\\PodePwshMonitorService.log"; // Default to local file if none provided

            // Dynamically generate a unique PipeName for communication
            _pipeName = $"PodePipe_{Guid.NewGuid()}";      // Generate a unique pipe name to avoid conflicts
        }

        public void StartPowerShellProcess()
        {
            if (_powerShellProcess == null || _powerShellProcess.HasExited)
            {
                try
                {
                    // Define the PowerShell process
                    _powerShellProcess = new Process
                    {
                        StartInfo = new ProcessStartInfo
                        {
                            FileName = _pwshPath,           // Set the PowerShell executable path (pwsh)
                            RedirectStandardOutput = true,  // Redirect standard output
                            RedirectStandardError = true,   // Redirect standard error
                            UseShellExecute = false,        // Do not use shell execution
                            CreateNoWindow = true           // Do not create a new window
                        }
                    };
                    Program.Log($"Starting ...");
                    // Properly escape double quotes within the JSON string
                    string podeServiceJson = $"{{\\\"DisableTermination\\\": {_disableTermination.ToString().ToLower()}, \\\"Quiet\\\": {_quiet.ToString().ToLower()}, \\\"PipeName\\\": \\\"{_pipeName}\\\"}}";
                    Program.Log($"Powershell path {_pwshPath}");
                    Program.Log($"PodeService content:");
                    Program.Log($"DisableTermination\t= {_disableTermination.ToString().ToLower()}");
                    Program.Log($"Quiet\t= {_quiet.ToString().ToLower()}");
                    Program.Log($"PipeName\t= {_pipeName}");
                    // Build the PowerShell command with NoProfile and global variable initialization
                    string command = $"-NoProfile -Command \"& {{ $global:PodeService = '{podeServiceJson}' | ConvertFrom-Json; . '{_scriptPath}' {_parameterString} }}\"";

                    Program.Log($"Starting PowerShell process with command: {command}");

                    // Set the arguments for the PowerShell process
                    _powerShellProcess.StartInfo.Arguments = command;

                    // Start the process
                    _powerShellProcess.Start();

                    // Log output and error asynchronously
                    _powerShellProcess.OutputDataReceived += (sender, args) => Program.Log(args.Data);
                    _powerShellProcess.ErrorDataReceived += (sender, args) => Program.Log(args.Data);
                    _powerShellProcess.BeginOutputReadLine();
                    _powerShellProcess.BeginErrorReadLine();

                    _lastLogTime = DateTime.Now;
                    Program.Log("PowerShell process started successfully.");
                }
                catch (Exception ex)
                {
                    Program.Log($"Failed to start PowerShell process: {ex.Message}");
                }
            }
            else
            {
                // Log only if more than a minute has passed since the last log
                if ((DateTime.Now - _lastLogTime).TotalMinutes >= 1)
                {
                    Program.Log("PowerShell process is already running.");
                    _lastLogTime = DateTime.Now;
                }
            }
        }

        public void StopPowerShellProcess()
        {
            try
            {
                _pipeClient = new NamedPipeClientStream(".", _pipeName, PipeDirection.InOut);
                Program.Log($"Connecting to the pipe server using pipe: {_pipeName}");

                // Connect to the PowerShell pipe server
                _pipeClient.Connect(10000);  // Wait for up to 10 seconds for the connection

                if (_pipeClient.IsConnected)
                {
                    // Send shutdown message and wait for the process to exit
                    SendPipeMessage("shutdown");
                    Program.Log($"Waiting up to {_shutdownWaitTimeMs} milliseconds for the PowerShell process to exit...");

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
                        Program.Log("PowerShell process has been shutdown gracefully.");
                    }
                    else
                    {
                        Program.Log($"PowerShell process did not exit in {_shutdownWaitTimeMs} milliseconds.");
                    }
                }
                else
                {
                    Program.Log($"Failed to connect to the PowerShell pipe server using pipe: {_pipeName}");
                }

                // Forcefully kill the process if it's still running
                if (_powerShellProcess != null && !_powerShellProcess.HasExited)
                {
                    try
                    {
                        _powerShellProcess.Kill();
                        Program.Log("PowerShell process killed successfully.");
                    }
                    catch (Exception ex)
                    {
                        Program.Log($"Error killing PowerShell process: {ex.Message}");
                    }
                }
            }
            catch (Exception ex)
            {
                Program.Log($"Error stopping PowerShell process: {ex.Message}");
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
                Program.Log("PowerShell process and pipe client disposed.");
                Program.Log("Done.");
            }
        }

        public void RestartPowerShellProcess()
        {
            // Simply send the restart message, no need to stop and start again
            if (_pipeClient != null && _pipeClient.IsConnected)
            {
                SendPipeMessage("restart"); // Inform PowerShell about the restart
                Program.Log("Restart message sent to PowerShell.");
            }
        }

        public void SuspendPowerShellProcess()
        {
            try
            {
                _pipeClient = new NamedPipeClientStream(".", _pipeName, PipeDirection.InOut);
                Program.Log($"Connecting to the pipe server using pipe: {_pipeName}");

                // Connect to the PowerShell pipe server
                _pipeClient.Connect(10000);  // Wait for up to 10 seconds for the connection
                                             // Simply send the restart message, no need to stop and start again
                if (_pipeClient != null && _pipeClient.IsConnected)
                {
                    Program.Log("maybe I'm here too.");
                    SendPipeMessage("suspend"); // Inform PowerShell about the restart
                    Program.Log("Suspend message sent to PowerShell.");
                }
            }
            catch (Exception ex)
            {
                Program.Log(ex, $"Error suspending PowerShell process");
            }
            finally
            {
                // Clean up the pipe client
                if (_pipeClient != null)
                {
                    _pipeClient?.Dispose();
                    _pipeClient = null;
                }
                Program.Log("PowerShell process and pipe client disposed.");
                Program.Log("Done.");
            }
        }

        public void ResumePowerShellProcess()
        {
            try
            {
                _pipeClient = new NamedPipeClientStream(".", _pipeName, PipeDirection.InOut);
                Program.Log($"Connecting to the pipe server using pipe: {_pipeName}");

                // Connect to the PowerShell pipe server
                _pipeClient.Connect(10000);  // Wait for up to 10 seconds for the connection
                                             // Simply send the restart message, no need to stop and start again
                if (_pipeClient != null && _pipeClient.IsConnected)
                {
                    SendPipeMessage("resume"); // Inform PowerShell about the restart
                    Program.Log("Resume message sent to PowerShell.");
                }
            }
            catch (Exception ex)
            {
                Program.Log(ex, $"Error resuming PowerShell process");
            }
            finally
            {
                // Clean up the pipe client
                if (_pipeClient != null)
                {
                    _pipeClient?.Dispose();
                    _pipeClient = null;
                }
                Program.Log("PowerShell process and pipe client disposed.");
                Program.Log("Done.");
            }
        }

        private void SendPipeMessage(string message)
        {
            Program.Log("SendPipeMessage: {0}", message);

            // Write the message to the pipe

            if (_pipeClient == null)
            {
                Program.Log("Pipe client is not initialized, cannot send message.");
                return;
            }

            if (!_pipeClient.IsConnected)
            {
                Program.Log("Pipe client is not connected, cannot send message.");
                return;
            }

            try
            {
                // Send the message using the pipe client stream
                using var writer = new StreamWriter(_pipeClient, leaveOpen: true); // leaveOpen to keep the pipe alive for multiple writes
                writer.AutoFlush = true;
                writer.WriteLine(message);
                Program.Log($"Message sent to PowerShell: {message}");
            }
            catch (Exception ex)
            {
                Program.Log($"Failed to send message to PowerShell: {ex.Message}");
            }
        }

    }
}
