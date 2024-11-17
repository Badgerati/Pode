using System;
using System.Diagnostics;
using System.IO;
using System.IO.Pipes;
using System.Threading;

namespace Pode.Service
{
    /// <summary>
    /// The PodePwshMonitor class monitors and controls the execution of a Pode PowerShell process.
    /// It communicates with the Pode process using named pipes.
    /// </summary>
    public class PodePwshMonitor
    {
        private readonly object _syncLock = new(); // Synchronization lock for thread safety
        private Process _powerShellProcess; // PowerShell process instance
        private NamedPipeClientStream _pipeClient; // Named pipe client for communication

        // Configuration properties
        private readonly string _scriptPath; // Path to the Pode script
        private readonly string _parameterString; // Parameters to pass to the script
        private readonly string _pwshPath; // Path to the PowerShell executable
        private readonly bool _quiet; // Whether the process runs in quiet mode
        private readonly bool _disableTermination; // Whether termination is disabled
        private readonly int _shutdownWaitTimeMs; // Timeout for shutting down the process
        private readonly string _pipeName; // Name of the pipe for interprocess communication

        private DateTime _lastLogTime; // Last log timestamp

        public int StartMaxRetryCount { get; } // Maximum retries to start the process
        public int StartRetryDelayMs { get; } // Delay between retries in milliseconds

        /// <summary>
        /// Initializes a new instance of the PodePwshMonitor class.
        /// </summary>
        /// <param name="options">The configuration options for the PodePwshWorker.</param>
        public PodePwshMonitor(PodePwshWorkerOptions options)
        {
            // Initialize configuration properties from options
            _scriptPath = options.ScriptPath;
            _pwshPath = options.PwshPath;
            _parameterString = options.ParameterString;
            _quiet = options.Quiet;
            _disableTermination = options.DisableTermination;
            _shutdownWaitTimeMs = options.ShutdownWaitTimeMs;
            StartMaxRetryCount = options.StartMaxRetryCount;
            StartRetryDelayMs = options.StartRetryDelayMs;

            // Generate a unique pipe name for communication
            _pipeName = $"PodePipe_{Guid.NewGuid()}";
            PodePwshLogger.Log(LogLevel.INFO, "Server", $"Initialized PodePwshMonitor with pipe name: {_pipeName}");
        }

        /// <summary>
        /// Starts the Pode PowerShell process.
        /// If the process is already running, logs its status.
        /// </summary>
        public void StartPowerShellProcess()
        {
            lock (_syncLock) // Ensure thread-safe access
            {
                // Check if the process is already running
                if (_powerShellProcess != null && !_powerShellProcess.HasExited)
                {
                    // Log if the process is alive and log threshold is met
                    if ((DateTime.Now - _lastLogTime).TotalMinutes >= 5)
                    {
                        PodePwshLogger.Log(LogLevel.INFO, "Server", "Pode process is Alive.");
                        _lastLogTime = DateTime.Now;
                    }
                    return;
                }

                try
                {
                    // Configure the PowerShell process
                    _powerShellProcess = new Process
                    {
                        StartInfo = new ProcessStartInfo
                        {
                            FileName = _pwshPath,
                            Arguments = BuildCommand(),
                            RedirectStandardOutput = true, // Redirect standard output
                            RedirectStandardError = true, // Redirect standard error
                            UseShellExecute = false, // Do not use shell execution
                            CreateNoWindow = true // Prevent creating a new window
                        }
                    };

                    // Subscribe to output and error streams
                    _powerShellProcess.OutputDataReceived += (sender, args) => PodePwshLogger.Log(LogLevel.INFO, "Pode", args.Data);
                    _powerShellProcess.ErrorDataReceived += (sender, args) => PodePwshLogger.Log(LogLevel.ERROR, "Pode", args.Data);

                    // Start the process
                    _powerShellProcess.Start();
                    _powerShellProcess.BeginOutputReadLine();
                    _powerShellProcess.BeginErrorReadLine();

                    // Log the process start time
                    _lastLogTime = DateTime.Now;
                    PodePwshLogger.Log(LogLevel.INFO, "Server", "Pode process started successfully.");
                }
                catch (Exception ex)
                {
                    // Log any errors during process start
                    PodePwshLogger.Log(LogLevel.ERROR, "Server", $"Failed to start Pode process: {ex.Message}");
                    PodePwshLogger.Log(LogLevel.DEBUG, ex);
                }
            }
        }

        /// <summary>
        /// Stops the Pode PowerShell process gracefully.
        /// If the process does not terminate gracefully, it will be forcefully terminated.
        /// </summary>
        public void StopPowerShellProcess()
        {
            lock (_syncLock) // Ensure thread-safe access
            {
                if (_powerShellProcess == null || _powerShellProcess.HasExited)
                {
                    PodePwshLogger.Log(LogLevel.INFO, "Server", "Pode process is not running.");
                    return;
                }

                try
                {
                    if (InitializePipeClient()) // Ensure pipe client is initialized
                    {
                        // Send shutdown message and wait for process exit
                        SendPipeMessage("shutdown");

                        PodePwshLogger.Log(LogLevel.INFO, "Server", $"Waiting for {_shutdownWaitTimeMs} milliseconds for Pode process to exit...");
                        WaitForProcessExit(_shutdownWaitTimeMs);

                        // If process does not exit gracefully, forcefully terminate
                        if (!_powerShellProcess.HasExited)
                        {
                            PodePwshLogger.Log(LogLevel.WARN, "Server", "Pode process did not terminate gracefully, killing process.");
                            _powerShellProcess.Kill();
                        }

                        PodePwshLogger.Log(LogLevel.INFO, "Server", "Pode process stopped successfully.");
                    }
                }
                catch (Exception ex)
                {
                    // Log errors during stop process
                    PodePwshLogger.Log(LogLevel.ERROR, "Server", $"Error stopping Pode process: {ex.Message}");
                    PodePwshLogger.Log(LogLevel.DEBUG, ex);
                }
                finally
                {
                    // Clean up resources
                    CleanupResources();
                }
            }
        }

        /// <summary>
        /// Sends a suspend command to the Pode process via named pipe.
        /// </summary>
        public void SuspendPowerShellProcess()
        {
            ExecutePipeCommand("suspend");
        }

        /// <summary>
        /// Sends a resume command to the Pode process via named pipe.
        /// </summary>
        public void ResumePowerShellProcess()
        {
            ExecutePipeCommand("resume");
        }

        /// <summary>
        /// Sends a restart command to the Pode process via named pipe.
        /// </summary>
        public void RestartPowerShellProcess()
        {
            ExecutePipeCommand("restart");
        }

        /// <summary>
        /// Executes a command by sending it to the Pode process via named pipe.
        /// </summary>
        /// <param name="command">The command to execute (e.g., "suspend", "resume", "restart").</param>
        private void ExecutePipeCommand(string command)
        {
            lock (_syncLock) // Ensure thread-safe access
            {
                try
                {
                    if (InitializePipeClient()) // Ensure pipe client is initialized
                    {
                        SendPipeMessage(command);
                        PodePwshLogger.Log(LogLevel.INFO, "Server", $"{command.ToUpper()} command sent to Pode process.");
                    }
                }
                catch (Exception ex)
                {
                    // Log errors during command execution
                    PodePwshLogger.Log(LogLevel.ERROR, "Server", $"Error executing {command} command: {ex.Message}");
                    PodePwshLogger.Log(LogLevel.DEBUG, ex);
                }
                finally
                {
                    // Clean up pipe client after sending the command
                    CleanupPipeClient();
                }
            }
        }

        /// <summary>
        /// Builds the PowerShell command to execute the Pode process.
        /// </summary>
        /// <returns>The PowerShell command string.</returns>
        private string BuildCommand()
        {
            string podeServiceJson = $"{{\\\"DisableTermination\\\": {_disableTermination.ToString().ToLower()}, \\\"Quiet\\\": {_quiet.ToString().ToLower()}, \\\"PipeName\\\": \\\"{_pipeName}\\\"}}";
            return $"-NoProfile -Command \"& {{ $global:PodeService = '{podeServiceJson}' | ConvertFrom-Json; . '{_scriptPath}' {_parameterString} }}\"";
        }

        /// <summary>
        /// Initializes the named pipe client for communication with the Pode process.
        /// </summary>
        /// <returns>True if the pipe client is successfully initialized and connected; otherwise, false.</returns>
        private bool InitializePipeClient()
        {
            if (_pipeClient == null)
            {
                _pipeClient = new NamedPipeClientStream(".", _pipeName, PipeDirection.InOut);
            }

            if (!_pipeClient.IsConnected)
            {
                PodePwshLogger.Log(LogLevel.INFO, "Server", "Connecting to pipe server...");
                _pipeClient.Connect(10000); // Connect with a timeout of 10 seconds
            }

            return _pipeClient.IsConnected;
        }

        /// <summary>
        /// Sends a message to the Pode process via named pipe.
        /// </summary>
        /// <param name="message">The message to send.</param>
        private void SendPipeMessage(string message)
        {
            try
            {
                using var writer = new StreamWriter(_pipeClient) { AutoFlush = true };
                writer.WriteLine(message); // Write the message to the pipe
            }
            catch (Exception ex)
            {
                PodePwshLogger.Log(LogLevel.ERROR, "Server", $"Error sending message to pipe: {ex.Message}");
                PodePwshLogger.Log(LogLevel.DEBUG, ex);
            }
        }

        /// <summary>
        /// Waits for the Pode process to exit within the specified timeout period.
        /// </summary>
        /// <param name="timeout">The timeout period in milliseconds.</param>
        private void WaitForProcessExit(int timeout)
        {
            int waited = 0;
            while (!_powerShellProcess.HasExited && waited < timeout)
            {
                Thread.Sleep(200); // Check every 200ms
                waited += 200;
            }
        }

        /// <summary>
        /// Cleans up resources associated with the Pode process and named pipe client.
        /// </summary>
        private void CleanupResources()
        {
            _powerShellProcess?.Dispose();
            _powerShellProcess = null;

            CleanupPipeClient();
        }

        /// <summary>
        /// Cleans up the named pipe client.
        /// </summary>
        private void CleanupPipeClient()
        {
            _pipeClient?.Dispose();
            _pipeClient = null;
        }
    }
}
