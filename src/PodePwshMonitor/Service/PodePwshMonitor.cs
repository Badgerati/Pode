using System;
using System.Diagnostics;
using System.IO;
using System.IO.Pipes;
using System.Threading;

namespace Pode.Service
{
    public class PodePwshMonitor
    {
        private readonly object _syncLock = new(); // Synchronization lock for thread safety
        private Process _powerShellProcess;
        private NamedPipeClientStream _pipeClient;

        private readonly string _scriptPath;
        private readonly string _parameterString;
        private readonly string _pwshPath;
        private readonly bool _quiet;
        private readonly bool _disableTermination;
        private readonly int _shutdownWaitTimeMs;
        private readonly string _pipeName;

        private DateTime _lastLogTime;

        public int StartMaxRetryCount { get; }
        public int StartRetryDelayMs { get; }

        public PodePwshMonitor(PodePwshWorkerOptions options)
        {
            _scriptPath = options.ScriptPath;
            _pwshPath = options.PwshPath;
            _parameterString = options.ParameterString;
            _quiet = options.Quiet;
            _disableTermination = options.DisableTermination;
            _shutdownWaitTimeMs = options.ShutdownWaitTimeMs;
            StartMaxRetryCount = options.StartMaxRetryCount;
            StartRetryDelayMs = options.StartRetryDelayMs;

            _pipeName = $"PodePipe_{Guid.NewGuid()}";
            Logger.Log(LogLevel.INFO, "Server", $"Initialized PodePwshMonitor with pipe name: {_pipeName}");
        }

        public void StartPowerShellProcess()
        {
            lock (_syncLock)
            {
                if (_powerShellProcess != null && !_powerShellProcess.HasExited)
                {
                    // Log only if more than a minute has passed since the last log
                    if ((DateTime.Now - _lastLogTime).TotalMinutes >= 5)
                    {
                        Logger.Log(LogLevel.INFO, "Server", "Pode process is Alive.");
                        _lastLogTime = DateTime.Now;
                    }
                    return;
                }

                try
                {
                    _powerShellProcess = new Process
                    {
                        StartInfo = new ProcessStartInfo
                        {
                            FileName = _pwshPath,
                            Arguments = BuildCommand(),
                            RedirectStandardOutput = true,
                            RedirectStandardError = true,
                            UseShellExecute = false,
                            CreateNoWindow = true
                        }
                    };

                    _powerShellProcess.OutputDataReceived += (sender, args) => Logger.Log(LogLevel.INFO, "Server", args.Data);
                    _powerShellProcess.ErrorDataReceived += (sender, args) => Logger.Log(LogLevel.ERROR, "Server", args.Data);

                    _powerShellProcess.Start();
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
        }

        public void StopPowerShellProcess()
        {
            lock (_syncLock)
            {
                if (_powerShellProcess == null || _powerShellProcess.HasExited)
                {
                    Logger.Log(LogLevel.INFO, "Server", "Pode process is not running.");
                    return;
                }

                try
                {
                    if (InitializePipeClient())
                    {
                        SendPipeMessage("shutdown");

                        Logger.Log(LogLevel.INFO, "Server", $"Waiting for {_shutdownWaitTimeMs} milliseconds for Pode process to exit...");
                        WaitForProcessExit(_shutdownWaitTimeMs);

                        if (!_powerShellProcess.HasExited)
                        {
                            Logger.Log(LogLevel.WARN, "Server", "Pode process did not terminate gracefully, killing process.");
                            _powerShellProcess.Kill();
                        }

                        Logger.Log(LogLevel.INFO, "Server", "Pode process stopped successfully.");
                    }
                }
                catch (Exception ex)
                {
                    Logger.Log(LogLevel.ERROR, "Server", $"Error stopping Pode process: {ex.Message}");
                    Logger.Log(LogLevel.DEBUG, ex);
                }
                finally
                {
                    CleanupResources();
                }
            }
        }

        public void SuspendPowerShellProcess()
        {
            ExecutePipeCommand("suspend");
        }

        public void ResumePowerShellProcess()
        {
            ExecutePipeCommand("resume");
        }

        public void RestartPowerShellProcess()
        {
            ExecutePipeCommand("restart");
        }

        private void ExecutePipeCommand(string command)
        {
            lock (_syncLock)
            {
                try
                {
                    if (InitializePipeClient())
                    {
                        SendPipeMessage(command);
                        Logger.Log(LogLevel.INFO, "Server", $"{command.ToUpper()} command sent to Pode process.");
                    }
                }
                catch (Exception ex)
                {
                    Logger.Log(LogLevel.ERROR, "Server", $"Error executing {command} command: {ex.Message}");
                    Logger.Log(LogLevel.DEBUG, ex);
                }
                finally
                {
                    CleanupPipeClient();
                }
            }
        }

        private string BuildCommand()
        {
            string podeServiceJson = $"{{\\\"DisableTermination\\\": {_disableTermination.ToString().ToLower()}, \\\"Quiet\\\": {_quiet.ToString().ToLower()}, \\\"PipeName\\\": \\\"{_pipeName}\\\"}}";
            return $"-NoProfile -Command \"& {{ $global:PodeService = '{podeServiceJson}' | ConvertFrom-Json; . '{_scriptPath}' {_parameterString} }}\"";
        }

        private bool InitializePipeClient()
        {
            if (_pipeClient == null)
            {
                _pipeClient = new NamedPipeClientStream(".", _pipeName, PipeDirection.InOut);
            }

            if (!_pipeClient.IsConnected)
            {
                Logger.Log(LogLevel.INFO, "Server", "Connecting to pipe server...");
                _pipeClient.Connect(10000);
            }

            return _pipeClient.IsConnected;
        }

        private void SendPipeMessage(string message)
        {
            try
            {
                using var writer = new StreamWriter(_pipeClient) { AutoFlush = true };
                writer.WriteLine(message);
            }
            catch (Exception ex)
            {
                Logger.Log(LogLevel.ERROR, "Server", $"Error sending message to pipe: {ex.Message}");
                Logger.Log(LogLevel.DEBUG, ex);
            }
        }

        private void WaitForProcessExit(int timeout)
        {
            int waited = 0;
            while (!_powerShellProcess.HasExited && waited < timeout)
            {
                Thread.Sleep(200); // Check every 200ms
                waited += 200;
            }
        }

        private void CleanupResources()
        {
            _powerShellProcess?.Dispose();
            _powerShellProcess = null;

            CleanupPipeClient();
        }

        private void CleanupPipeClient()
        {
            _pipeClient?.Dispose();
            _pipeClient = null;
        }

    }
}
