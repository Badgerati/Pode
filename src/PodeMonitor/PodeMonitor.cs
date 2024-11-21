using System;
using System.Diagnostics;
using System.IO;
using System.IO.Pipes;
using System.Threading;

namespace PodeMonitor
{
    /// <summary>
    /// The PodeMonitor class monitors and controls the execution of a Pode PowerShell process.
    /// It communicates with the Pode process using named pipes.
    /// </summary>
    public class PodeMonitor
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

        // Thread-safe variable to track the service state
        private volatile bool _suspended; // Volatile ensures the latest value is visible to all threads

        public bool Suspended
        {
            get => _suspended; // Safe to read from multiple threads
            private set => _suspended = value; // Written by only one thread
        }

        // Thread-safe variable to track the service state
        private volatile bool _starting; // Volatile ensures the latest value is visible to all threads

        public bool Starting
        {
            get => _starting; // Safe to read from multiple threads
            private set => _starting = value; // Written by only one thread
        }

        // Thread-safe variable to track the service state
        private volatile bool _running; // Volatile ensures the latest value is visible to all threads

        public bool Running
        {
            get => _running; // Safe to read from multiple threads
            private set => _running = value; // Written by only one thread
        }


        /// <summary>
        /// Initializes a new instance of the PodeMonitor class.
        /// </summary>
        /// <param name="options">The configuration options for the PodeMonitorWorker.</param>
        public PodeMonitor(PodeMonitorWorkerOptions options)
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
            _pipeName = PipeNameGenerator.GeneratePipeName();
            PodeMonitorLogger.Log(LogLevel.INFO, "PodeMonitor", Environment.ProcessId, $"Initialized PodeMonitor with pipe name: {_pipeName}");
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
                        PodeMonitorLogger.Log(LogLevel.INFO, "PodeMonitor", Environment.ProcessId, "Pode process is Alive.");
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
                    //_powerShellProcess.OutputDataReceived += (sender, args) => PodeMonitorLogger.Log(LogLevel.INFO, "Pode", _powerShellProcess.Id, args.Data);

                    // Subscribe to output and error streams
                    _powerShellProcess.OutputDataReceived += (sender, args) =>
                    {
                        // Log the received message
                        if (!string.IsNullOrEmpty(args.Data))
                        {
                            PodeMonitorLogger.Log(LogLevel.INFO, "Pode", _powerShellProcess.Id, args.Data);

                            // Check if the message starts with "Service State:"
                            if (args.Data.StartsWith("Service State: ", StringComparison.OrdinalIgnoreCase))
                            {
                                // Extract the state value and update the static variable
                                string state = args.Data.Substring("Service State: ".Length).Trim().ToLowerInvariant();

                                if (state == "running")
                                {
                                    Suspended = false;
                                    Starting = false;
                                    Running = true;
                                    PodeMonitorLogger.Log(LogLevel.INFO, "PodeMonitor", Environment.ProcessId, "Service state updated to: Running.");
                                }
                                else if (state == "suspended")
                                {
                                    Suspended = true;
                                    Starting = false;
                                    Running = false;
                                    PodeMonitorLogger.Log(LogLevel.INFO, "PodeMonitor", Environment.ProcessId, "Service state updated to: Suspended.");
                                }
                                else if (state == "starting")
                                {
                                    Suspended = false;
                                    Starting = true;
                                    Running = false;
                                    PodeMonitorLogger.Log(LogLevel.INFO, "PodeMonitor", Environment.ProcessId, "Service state updated to: Restarting.");
                                }
                                else
                                {
                                    PodeMonitorLogger.Log(LogLevel.WARN, "PodeMonitor", Environment.ProcessId, $"Unknown service state: {state}");
                                }
                            }
                        }
                    };
                    _powerShellProcess.ErrorDataReceived += (sender, args) => PodeMonitorLogger.Log(LogLevel.ERROR, "Pode", _powerShellProcess.Id, args.Data);

                    // Start the process
                    _powerShellProcess.Start();
                    _powerShellProcess.BeginOutputReadLine();
                    _powerShellProcess.BeginErrorReadLine();

                    // Log the process start time
                    _lastLogTime = DateTime.Now;
                    PodeMonitorLogger.Log(LogLevel.INFO, "PodeMonitor", Environment.ProcessId, "Pode process started successfully.");
                }
                catch (Exception ex)
                {
                    // Log any errors during process start
                    PodeMonitorLogger.Log(LogLevel.ERROR, "PodeMonitor", Environment.ProcessId, $"Failed to start Pode process: {ex.Message}");
                    PodeMonitorLogger.Log(LogLevel.DEBUG, ex);
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
                    PodeMonitorLogger.Log(LogLevel.INFO, "PodeMonitor", Environment.ProcessId, "Pode process is not running.");
                    return;
                }

                try
                {
                    if (InitializePipeClient()) // Ensure pipe client is initialized
                    {
                        // Send shutdown message and wait for process exit
                        SendPipeMessage("shutdown");

                        PodeMonitorLogger.Log(LogLevel.INFO, "PodeMonitor", Environment.ProcessId, $"Waiting for {_shutdownWaitTimeMs} milliseconds for Pode process to exit...");
                        WaitForProcessExit(_shutdownWaitTimeMs);

                        // If process does not exit gracefully, forcefully terminate
                        if (!_powerShellProcess.HasExited)
                        {
                            PodeMonitorLogger.Log(LogLevel.WARN, "PodeMonitor", Environment.ProcessId, "Pode process did not terminate gracefully, killing process.");
                            _powerShellProcess.Kill();
                        }

                        PodeMonitorLogger.Log(LogLevel.INFO, "PodeMonitor", Environment.ProcessId, "Pode process stopped successfully.");
                    }
                }
                catch (Exception ex)
                {
                    // Log errors during stop process
                    PodeMonitorLogger.Log(LogLevel.ERROR, "PodeMonitor", Environment.ProcessId, $"Error stopping Pode process: {ex.Message}");
                    PodeMonitorLogger.Log(LogLevel.DEBUG, ex);
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
                        PodeMonitorLogger.Log(LogLevel.INFO, "PodeMonitor", Environment.ProcessId, $"{command.ToUpper()} command sent to Pode process.");
                    }
                }
                catch (Exception ex)
                {
                    // Log errors during command execution
                    PodeMonitorLogger.Log(LogLevel.ERROR, "PodeMonitor", Environment.ProcessId, $"Error executing {command} command: {ex.Message}");
                    PodeMonitorLogger.Log(LogLevel.DEBUG, ex);
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
                PodeMonitorLogger.Log(LogLevel.INFO, "PodeMonitor", Environment.ProcessId, "Connecting to pipe server...");
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
                PodeMonitorLogger.Log(LogLevel.ERROR, "PodeMonitor", Environment.ProcessId, $"Error sending message to pipe: {ex.Message}");
                PodeMonitorLogger.Log(LogLevel.DEBUG, ex);
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
