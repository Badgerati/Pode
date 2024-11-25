# Watchdog

The Pode Watchdog feature allows you to monitor and manage processes or scripts running within your Pode server. It provides the ability to track the status of a process, log important events, and interact with the process, including via REST API endpoints.

## Features
- **Process Monitoring**: Continuously track the status, uptime, and performance of processes running under the Pode Watchdog.
- **File Monitoring with Automatic Restart**: Automatically restart a monitored process when changes are detected in files it depends on, such as configuration or critical files.
- **Process Control**: Control the monitored processes through REST API commands such as restart, stop, or reset.
- **Logging**: Watchdog supports logging of important events and errors, which can be useful for auditing and debugging.
- **Automatic Restarts**: If a monitored process crashes unexpectedly, Pode Watchdog will automatically restart it to ensure it remains active.

### How It Works
Pode Watchdog monitors processes or files as configured in your Pode server. Once a process is being monitored, you can interact with it using commands or REST API endpoints. Watchdog continuously tracks the process and ensures it remains active by automatically restarting it when necessary—especially when critical files change.

### Typical Use Cases
1. **Process Monitoring**: Monitor long-running scripts or background services and ensure they are continuously running.
2. **File Monitoring with Automatic Restart**: Watch for changes in key files, such as configuration files, and restart the process automatically when changes are detected.
3. **Automatic Restarts**: Ensure critical processes automatically restart if they crash or when monitored files are modified.
4. **Remote Control**: Use API endpoints to control processes remotely—start, stop, reset, or restart them.

---

### Enabling Pode Watchdog
To begin using the Pode Watchdog feature, specify the process or file you wish to monitor. Here’s an example to monitor a script file and automatically restart the process when the file changes:

```powershell
Enable-PodeWatchdog -FilePath './scripts/myProcess.ps1' -FileMonitoring -FileExclude '*.log' -Name 'myProcessWatchdog'
```

- `-FilePath`: Specifies the path to the script or process you want to monitor.
- `-FileMonitoring`: Enables file monitoring to track changes to the specified file.
- `-FileExclude`: Excludes certain files (e.g., `.log` files) from triggering a restart.
- `-Name`: Assigns a unique identifier for this Watchdog instance.

### **Monitoring**
You can monitor process metrics, such as status, uptime, or other performance data, using the `Get-PodeWatchdogProcessMetric` cmdlet.

### **Controlling the Watchdog**
Pode Watchdog provides full control over monitored processes using the `Set-PodeWatchdogProcessState` cmdlet, allowing you to restart, stop, start, or reset the process.

---

### **Example Usage with RESTful Integration**

Here’s an example of how to set up a Pode server with Watchdog and expose REST API routes to monitor and control the process:

```powershell
Start-PodeServer {
    # Define an HTTP endpoint
    Add-PodeEndpoint -Address localhost -Port 8082 -Protocol Http

    # Path to the monitored script
    $filePath = "./scripts/myProcess.ps1"

    # Set up Watchdog logging
    New-PodeLoggingMethod -File -Name 'watchdog' -MaxDays 4 | Enable-PodeErrorLogging

    # Enable Watchdog monitoring for the process
    Enable-PodeWatchdog -FilePath $filePath -FileMonitoring -FileExclude '*.log' -Name 'myProcessWatchdog'

    # Route to check process status
    Add-PodeRoute -Method Get -Path '/monitor/status' -ScriptBlock {
        Write-PodeJsonResponse -Value (Get-PodeWatchdogProcessMetric -Name 'myProcessWatchdog' -Type Status)
    }

    # Route to restart the process
    Add-PodeRoute -Method Post -Path '/cmd/restart' -ScriptBlock {
        Write-PodeJsonResponse -Value @{success = (Set-PodeWatchdogProcessState -Name 'myProcessWatchdog' -State Restart)}
    }
}
```

In this example:
- Pode Watchdog is configured to monitor a script (`myProcess.ps1`).
- The Pode server exposes REST API routes to check the process status (`/monitor/status`) and restart the process (`/cmd/restart`).

