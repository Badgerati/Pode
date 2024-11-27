using System;
using System.Collections.Concurrent;
using System.Diagnostics;
using System.IO;
using System.IO.Pipes;
using System.Threading;

namespace PodeMonitor
{
    /// <summary>
    /// Enum representing possible states of the Pode service.
    /// </summary>
    public enum ServiceState
    {
        Unknown,    // State is unknown
        Running,    // Service is running
        Suspended,  // Service is suspended
        Starting,    // Service is starting
        Stopping    // Service is stopping
    }

    /// <summary>
    /// Class responsible for managing and monitoring the Pode PowerShell process.
    /// Provides functionality for starting, stopping, suspending, resuming, and restarting the process.
    /// Communicates with the Pode process via named pipes.
    /// </summary>
    public class PodeMonitor
    {
        private readonly object _syncLock = new(); // Synchronization lock for thread safety
        private Process _powerShellProcess;       // PowerShell process instance
        private NamedPipeClientStream _pipeClient; // Named pipe client for inter-process communication

        // Configuration properties
        private readonly string _scriptPath;      // Path to the Pode script
        private readonly string _parameterString; // Parameters passed to the script
        private readonly string _pwshPath;        // Path to the PowerShell executable
        private readonly bool _quiet;            // Indicates whether the process runs in quiet mode
        private readonly bool _disableTermination; // Indicates whether termination is disabled
        private readonly int _shutdownWaitTimeMs; // Timeout for shutting down the process
        private readonly string _pipeName;        // Name of the named pipe for communication
        private readonly string _stateFilePath; // Path to the service state file

        private DateTime _lastLogTime;           // Tracks the last time the process logged activity

        public int StartMaxRetryCount { get; }   // Maximum number of retries for starting the process
        public int StartRetryDelayMs { get; }   // Delay between retries in milliseconds

        private volatile ServiceState _state;


        public ServiceState State { get => _state; set => _state = value; }

        public bool DisableTermination { get => _disableTermination; }


        /// <summary>
        /// Initializes a new instance of the <see cref="PodeMonitor"/> class with the specified configuration options.
        /// </summary>
        /// <param name="options">Configuration options for the PodeMonitor.</param>
        public PodeMonitor(PodeMonitorWorkerOptions options)
        {
            // Initialize configuration properties
            _scriptPath = options.ScriptPath;
            _pwshPath = options.PwshPath;
            _parameterString = options.ParameterString;
            _quiet = options.Quiet;
            _disableTermination = options.DisableTermination;
            _shutdownWaitTimeMs = options.ShutdownWaitTimeMs;
            StartMaxRetryCount = options.StartMaxRetryCount;
            StartRetryDelayMs = options.StartRetryDelayMs;

            // Generate a unique pipe name
            _pipeName = PipeNameGenerator.GeneratePipeName();
            PodeMonitorLogger.Log(PodeLogLevel.INFO, "PodeMonitor", Environment.ProcessId, $"Initialized PodeMonitor with pipe name: {_pipeName}");
            // Define the state file path only for Linux/macOS
            if (OperatingSystem.IsLinux() || OperatingSystem.IsMacOS())
            {

                string homeDirectory = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
                string stateDirectory = OperatingSystem.IsLinux()
                    ? "/run/podemonitor"
                    : OperatingSystem.IsMacOS()
                        ? Path.Combine(homeDirectory, "Library", "LaunchAgents", "PodeMonitor")
                        : throw new PlatformNotSupportedException("The current platform is not supported for setting the state directory.");
                try
                {
                    if (!Directory.Exists(stateDirectory))
                    {
                        Directory.CreateDirectory(stateDirectory);
                    }
                }
                catch (Exception ex)
                {
                    PodeMonitorLogger.Log(PodeLogLevel.ERROR, "PodeMonitor", Environment.ProcessId,
                        $"Failed to create state directory at {stateDirectory}: {ex.Message}");
                    throw;
                }

                // Define the state file path (default to /var/tmp for Linux/macOS)
                _stateFilePath = Path.Combine(stateDirectory, $"{Environment.ProcessId}.state");


                PodeMonitorLogger.Log(PodeLogLevel.INFO, "PodeMonitor", Environment.ProcessId, $"Initialized PodeMonitor with pipe name: {_pipeName} and state file: {_stateFilePath}");
            }
        }

        /// <summary>
        /// Starts the Pode PowerShell process. If the process is already running, logs its status.
        /// </summary>
        public void StartPowerShellProcess()
        {
            lock (_syncLock)
            {
                if (_powerShellProcess != null && !_powerShellProcess.HasExited)
                {
                    if ((DateTime.Now - _lastLogTime).TotalMinutes >= 5)
                    {
                        PodeMonitorLogger.Log(PodeLogLevel.INFO, "PodeMonitor", Environment.ProcessId, "Pode process is Alive.");
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
                            RedirectStandardOutput = true, // Redirect standard output for logging
                            RedirectStandardError = true, // Redirect standard error for logging
                            UseShellExecute = false,      // Run without using shell execution
                            CreateNoWindow = true         // Prevent the creation of a window
                        }
                    };

                    // Subscribe to the output stream for logging and state parsing
                    _powerShellProcess.OutputDataReceived += (sender, args) =>
                    {
                        if (!string.IsNullOrEmpty(args.Data))
                        {
                            PodeMonitorLogger.Log(PodeLogLevel.INFO, "Pode", _powerShellProcess.Id, args.Data);
                            ParseServiceState(args.Data);
                        }
                    };

                    // Subscribe to the error stream for logging errors
                    _powerShellProcess.ErrorDataReceived += (sender, args) =>
                    {
                        PodeMonitorLogger.Log(PodeLogLevel.ERROR, "Pode", _powerShellProcess.Id, args.Data);
                    };

                    // Start the process and begin reading the output/error streams
                    _powerShellProcess.Start();
                    _powerShellProcess.BeginOutputReadLine();
                    _powerShellProcess.BeginErrorReadLine();

                    _lastLogTime = DateTime.Now;
                    PodeMonitorLogger.Log(PodeLogLevel.INFO, "PodeMonitor", Environment.ProcessId, "Pode process started successfully.");
                }
                catch (Exception ex)
                {
                    PodeMonitorLogger.Log(PodeLogLevel.ERROR, "PodeMonitor", Environment.ProcessId, $"Failed to start Pode process: {ex.Message}");
                    PodeMonitorLogger.Log(PodeLogLevel.DEBUG, ex);
                }
            }
        }

        /// <summary>
        /// Stops the Pode PowerShell process gracefully. If it does not terminate, it is forcefully killed.
        /// </summary>
        public void StopPowerShellProcess()
        {
            lock (_syncLock)
            {
                if (_powerShellProcess == null || (_powerShellProcess.HasExited && Process.GetProcessById(_powerShellProcess.Id) == null))
                {
                    PodeMonitorLogger.Log(PodeLogLevel.INFO, "PodeMonitor", Environment.ProcessId, "Pode process is not running.");
                    return;
                }

                try
                {
                    if (InitializePipeClientWithRetry())
                    {
                        SendPipeMessage("shutdown");
                        PodeMonitorLogger.Log(PodeLogLevel.INFO, "PodeMonitor", Environment.ProcessId, $"Waiting for {_shutdownWaitTimeMs} milliseconds for Pode process to exit...");
                        WaitForProcessExit(_shutdownWaitTimeMs);

                        if (_powerShellProcess != null && !_powerShellProcess.HasExited)
                        {
                            PodeMonitorLogger.Log(PodeLogLevel.WARN, "PodeMonitor", Environment.ProcessId, $"Pode process has exited:{_powerShellProcess.HasExited} Id:{_powerShellProcess.Id}");

                            PodeMonitorLogger.Log(PodeLogLevel.WARN, "PodeMonitor", Environment.ProcessId, "Pode process did not terminate gracefully. Killing process.");
                            _powerShellProcess.Kill();
                        }

                        PodeMonitorLogger.Log(PodeLogLevel.INFO, "PodeMonitor", Environment.ProcessId, "Pode process stopped successfully.");
                    }
                }
                catch (Exception ex)
                {
                    PodeMonitorLogger.Log(PodeLogLevel.ERROR, "PodeMonitor", Environment.ProcessId, $"Error stopping Pode process: {ex.Message}");
                    PodeMonitorLogger.Log(PodeLogLevel.DEBUG, ex);
                }
                finally
                {
                    CleanupResources();
                }
            }
        }

        /// <summary>
        /// Sends a suspend command to the Pode process via named pipe.
        /// </summary>
        public void SuspendPowerShellProcess() => ExecutePipeCommand("suspend");

        /// <summary>
        /// Sends a resume command to the Pode process via named pipe.
        /// </summary>
        public void ResumePowerShellProcess() => ExecutePipeCommand("resume");

        /// <summary>
        /// Sends a restart command to the Pode process via named pipe.
        /// </summary>
        public void RestartPowerShellProcess() => ExecutePipeCommand("restart");



        /// <summary>
        /// Executes a command by sending it to the Pode process via named pipe.
        /// </summary>
        /// <param name="command">The command to execute (e.g., "suspend", "resume", "restart").</param>
        private void ExecutePipeCommand(string command)
        {
            lock (_syncLock)
            {
                try
                {
                    if (InitializePipeClientWithRetry())
                    {
                        SendPipeMessage(command);
                        PodeMonitorLogger.Log(PodeLogLevel.INFO, "PodeMonitor", Environment.ProcessId, $"{command.ToUpper()} command sent to Pode process.");
                    }
                }
                catch (Exception ex)
                {
                    PodeMonitorLogger.Log(PodeLogLevel.ERROR, "PodeMonitor", Environment.ProcessId, $"Error executing {command} command: {ex.Message}");
                    PodeMonitorLogger.Log(PodeLogLevel.DEBUG, ex);
                }
                finally
                {
                    CleanupPipeClient();
                }
            }
        }

        /// <summary>
        /// Parses the service state from the provided output message and updates the state variables.
        /// </summary>
        /// <param name="output">The output message containing the service state.</param>
        private void ParseServiceState(string output)
        {
            if (string.IsNullOrWhiteSpace(output)) return;

            if (output.StartsWith("Service State: ", StringComparison.OrdinalIgnoreCase))
            {
                string state = output["Service State: ".Length..].Trim().ToLowerInvariant();

                switch (state)
                {
                    case "running":
                        UpdateServiceState(ServiceState.Running);
                        break;
                    case "suspended":
                        UpdateServiceState(ServiceState.Suspended);
                        break;
                    case "starting":
                        UpdateServiceState(ServiceState.Starting);
                        break;
                    case "stopping":
                        UpdateServiceState(ServiceState.Stopping);
                        break;
                    default:
                        PodeMonitorLogger.Log(PodeLogLevel.WARN, "PodeMonitor", Environment.ProcessId, $"Unknown service state: {state}");
                        UpdateServiceState(ServiceState.Unknown);
                        break;
                }
            }
        }

        /// <summary>
        /// Updates the internal state variables based on the provided service state.
        /// </summary>
        /// <param name="state">The new service state.</param>
        private void UpdateServiceState(ServiceState state)
        {
            _state = state;
            PodeMonitorLogger.Log(PodeLogLevel.INFO, "PodeMonitor", Environment.ProcessId, $"Service state updated to: {state}");
            // Write the state to the state file only on Linux/macOS
            if (OperatingSystem.IsLinux() || OperatingSystem.IsMacOS())
            {
                // Write the state to the state file
                WriteServiceStateToFile(state);
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
        /// Initializes the named pipe client with a retry mechanism.
        /// </summary>
        /// <param name="maxRetries">The maximum number of retries for connection.</param>
        /// <returns>True if the pipe client is successfully connected; otherwise, false.</returns>
        private bool InitializePipeClientWithRetry(int maxRetries = 3)
        {
            int attempts = 0;

            while (attempts < maxRetries)
            {
                try
                {
                    if (_pipeClient == null)
                    {
                        _pipeClient = new NamedPipeClientStream(".", _pipeName, PipeDirection.InOut);
                    }

                    if (!_pipeClient.IsConnected)
                    {
                        PodeMonitorLogger.Log(PodeLogLevel.INFO, "PodeMonitor", Environment.ProcessId, $"Connecting to pipe server (Attempt {attempts + 1})...");
                        _pipeClient.Connect(10000); // Timeout of 10 seconds
                    }

                    return _pipeClient.IsConnected;
                }
                catch (Exception ex)
                {
                    PodeMonitorLogger.Log(PodeLogLevel.ERROR, "PodeMonitor", Environment.ProcessId, $"Pipe connection attempt {attempts + 1} failed: {ex.Message}");
                }

                attempts++;
                Thread.Sleep(1000);
            }

            return false;
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
                writer.WriteLine(message);
            }
            catch (Exception ex)
            {
                PodeMonitorLogger.Log(PodeLogLevel.ERROR, "PodeMonitor", Environment.ProcessId, $"Error sending message to pipe: {ex.Message}");
                PodeMonitorLogger.Log(PodeLogLevel.DEBUG, ex);
            }
        }

        /// <summary>
        /// Waits for the Pode process to exit within the specified timeout.
        /// </summary>
        /// <param name="timeout">The timeout period in milliseconds.</param>
        private void WaitForProcessExit(int timeout)
        {
            int waited = 0;
            while (!_powerShellProcess.HasExited && waited < timeout)
            {
                Thread.Sleep(200);
                waited += 200;
            }
        }


        /// <summary>
        /// Writes the current service state to the state file.
        /// </summary>
        /// <param name="state">The service state to write.</param>
        private void WriteServiceStateToFile(ServiceState state)
        {
            lock (_syncLock) // Ensure thread-safe access
            {
                try
                {
                    File.WriteAllText(_stateFilePath, state.ToString().ToLowerInvariant());
                    PodeMonitorLogger.Log(PodeLogLevel.DEBUG, "PodeMonitor", Environment.ProcessId, $"Service state written to file: {_stateFilePath}");
                }
                catch (Exception ex)
                {
                    PodeMonitorLogger.Log(PodeLogLevel.ERROR, "PodeMonitor", Environment.ProcessId, $"Failed to write service state to file: {ex.Message}");
                }
            }
        }

        /// <summary>
        /// Deletes the service state file during cleanup.
        /// </summary>
        private void DeleteServiceStateFile()
        {
            lock (_syncLock) // Ensure thread-safe access
            {
                try
                {
                    if (File.Exists(_stateFilePath))
                    {
                        File.Delete(_stateFilePath);
                        PodeMonitorLogger.Log(PodeLogLevel.INFO, "PodeMonitor", Environment.ProcessId, $"Service state file deleted: {_stateFilePath}");
                    }
                }
                catch (Exception ex)
                {
                    PodeMonitorLogger.Log(PodeLogLevel.ERROR, "PodeMonitor", Environment.ProcessId, $"Failed to delete service state file: {ex.Message}");
                }
            }
        }

        /// <summary>
        /// Cleans up resources associated with the Pode process and the pipe client.
        /// </summary>
        private void CleanupResources()
        {
            _powerShellProcess?.Dispose();
            _powerShellProcess = null;

            CleanupPipeClient();

            if (OperatingSystem.IsLinux() || OperatingSystem.IsMacOS())
            {
                DeleteServiceStateFile();
            }
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