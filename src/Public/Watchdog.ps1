
<#
.SYNOPSIS
    Enables a Pode Watchdog service to monitor a script or file for changes and control its lifecycle.

.DESCRIPTION
    Configures and starts a Pode Watchdog service to monitor either a script block or a file path.
    The Watchdog service can monitor files or directories for changes, and it provides automatic process restarts when needed.
    Additionally, the service supports graceful shutdowns and recovery after restarts.

.PARAMETER Name
    The name of the Watchdog service.

.PARAMETER ScriptBlock
    The script block to be executed and monitored by the Watchdog service.
    This parameter is mandatory when using the 'Script' or 'ScriptMonitoring' parameter sets.

.PARAMETER FilePath
    The path to the file to be executed and monitored by the Watchdog service.
    This parameter is mandatory when using the 'File' or 'FileMonitoring' parameter sets.

.PARAMETER FileMonitoring
    Enables monitoring of a file or directory for changes. This can be used with either scripts or files.

.PARAMETER FileExclude
    An array of file patterns to exclude from the monitoring process.
    For example: '*.log' to exclude all log files.
    This is only applicable when 'FileMonitoring' is enabled.

.PARAMETER FileInclude
    An array of file patterns to include in the monitoring process.
    Default is '*.*', which includes all files.
    This is only applicable when 'FileMonitoring' is enabled.

.PARAMETER MonitoredPath
    The directory path to monitor for changes.
    This parameter is mandatory when 'FileMonitoring' is enabled and can be used to define the root directory to watch.

.PARAMETER Interval
    The time interval, in seconds, for checking the Watchdog's state.
    Default is 10 seconds.

.PARAMETER NoAutostart
    Disables automatic restart of the monitored process when it stops or encounters an error.

.PARAMETER MinRestartInterval
    The minimum time interval, in minutes, between restarts of the monitored process.
    Default is 3 minutes.

.PARAMETER GracefulShutdownTimeout
    Defines the maximum time, in seconds, the service waits for active sessions to close during a graceful shutdown.
    If sessions remain open after this time, the service forces shutdown.
    Default is 30 seconds.

.PARAMETER ServiceRecoveryTime
    Defines the time, in seconds, that the service indicates to clients when it will be available again after a restart.
    This value is used in the 'Retry-After' header when responding with a 503 status.
    Default is 60 seconds.

.EXAMPLE
    Enable-PodeWatchdog -FilePath $filePath -FileMonitoring -FileExclude '*.log' -Name 'MyWatch01'

    This example sets up a Watchdog named 'MyWatch01' to monitor changes in the specified file while excluding any log files from monitoring.

.NOTES
    Possible Monitored Process States:
    - Restarting
    - Starting
    - Running
    - Stopping
    - Stopped
    - Undefined
#>
function Enable-PodeWatchdog {
    [CmdletBinding(DefaultParameterSetName = 'Script')]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true, ParameterSetName = 'Script')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ScriptMonitoring')]
        [scriptblock]
        $ScriptBlock,

        [Parameter(Mandatory = $true, ParameterSetName = 'File')]
        [Parameter(Mandatory = $true, ParameterSetName = 'FileMonitoring')]
        [string]
        $FilePath,

        [Parameter(Mandatory = $true, ParameterSetName = 'ScriptMonitoring')]
        [Parameter(Mandatory = $true, ParameterSetName = 'FileMonitoring')]
        [switch]
        $FileMonitoring,

        [Parameter(Mandatory = $false, ParameterSetName = 'ScriptMonitoring')]
        [Parameter(Mandatory = $false, ParameterSetName = 'FileMonitoring')]
        [string[]]
        $FileExclude,

        [Parameter(Mandatory = $false, ParameterSetName = 'ScriptMonitoring')]
        [Parameter(Mandatory = $false, ParameterSetName = 'FileMonitoring')]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $FileInclude = '*.*',

        [Parameter(Mandatory = $false, ParameterSetName = 'FileMonitoring')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ScriptMonitoring')]
        [string]
        $MonitoredPath,

        [int]
        $Interval = 10,

        [switch]
        $NoAutostart,

        [int]
        $MinRestartInterval = 3,

        [int]
        $GracefulShutdownTimeout = 30,

        [int]
        $ServiceRecoveryTime = 60
    )

    # Check which parameter set is being used and adjust accordingly
    if ($PSCmdlet.ParameterSetName -ieq 'File' -or $PSCmdlet.ParameterSetName -ieq 'FileMonitoring') {
        # Resolve file path and determine root path
        $FilePath = Get-PodeRelativePath -Path $FilePath -Resolve -TestPath -JoinRoot -RootPath $MyInvocation.PSScriptRoot

        # Determine root path if not supplied
        if ([string]::IsNullOrWhiteSpace($RootPath)) {
            if ($CurrentPath) {
                $RootPath = $PWD.Path
            }
            else {
                $RootPath = Split-Path -Parent -Path $FilePath
            }
        }

        # Construct arguments for file execution
        $arguments = "-NoProfile -Command `"& {
            `$global:PodeWatchdog = `$args[0] | ConvertFrom-Json;
            . `"$FilePath`"
        }`""
    }
    else {
        # For 'Script' parameter set: serialize the scriptblock for execution
        $scriptBlockString = $ScriptBlock.ToString()
        $arguments = "-NoProfile -Command `"& {
            `$PodeWatchdog = `$args[0] | ConvertFrom-Json;
             & { $scriptBlockString }
        }`""
    }

    # Main script block to initialize and run the Watchdog PipeServer
    $scriptBlock = {
        param (
            [string]
            $WatchdogName
        )

        Write-PodeHost "Starting PipeServer $WatchdogName..."
        $watchdog = $PodeContext.Server.Watchdog.Server[$WatchdogName]

        # Main loop to maintain the server state
        while ($watchdog.Enabled) {
            try {
                # Check if PipeServer is null and create a new instance if needed
                if ($null -eq $watchdog['PipeServer']) {
                    $pipeName = $watchdog.PipeName
                    $watchdog['PipeServer'] = [System.IO.Pipes.NamedPipeServerStream]::new(
                        $pipeName,
                        [System.IO.Pipes.PipeDirection]::InOut,
                        2,
                        [System.IO.Pipes.PipeTransmissionMode]::Message,
                        [System.IO.Pipes.PipeOptions]::None
                    )
                    Write-PodeHost 'New PipeServer instance created and stored in Watchdog context.'

                    # Create a new StreamWriter and store it back in the Watchdog context
                    $watchdog['PipeWriter'] = [System.IO.StreamWriter]::new($watchdog['PipeServer'])
                    Write-PodeHost 'New PipeWriter instance created and stored in Watchdog context.'
                }

                $pipeServer = $watchdog['PipeServer']
                Write-PodeHost 'PipeServer created and waiting for connection...'
                $pipeServer.WaitForConnection()
                Write-PodeHost 'Client connected.'

                # Create a StreamReader to read messages from the client
                $reader = [System.IO.StreamReader]::new($pipeServer)

                while ($pipeServer.IsConnected) {
                    try {
                        # Read the next message from the client
                        $receivedData = $reader.ReadLine()

                        if ($null -ne $receivedData) {
                            Write-PodeHost "Server Received data: $receivedData"
                            # Deserialize received JSON string into a hashtable
                            $watchdog.ProcessInfo = $receivedData | ConvertFrom-Json
                        }
                        else {
                            Write-PodeHost 'No data received from client. Waiting for more data...'
                        }
                    }
                    catch {
                        Write-PodeHost "Error reading from client: $_"
                        $pipeServer.Disconnect()  # Disconnect to allow reconnection
                        Start-Sleep -Seconds 1
                    }
                }

                # Client disconnected, clean up
                Write-PodeHost 'Client disconnected. Waiting for a new connection...'
                $pipeServer.Disconnect()  # Disconnect to reset the state
            }
            catch {
                Write-PodeHost "Error with the pipe server: $_"

                # Release resources and reinitialize PipeServer
                Write-PodeHost 'Releasing resources and setting PipeServer to null.'
                if ($null -ne $watchdog['PipeWriter']) {
                    $watchdog['PipeWriter'].Dispose()  # Dispose existing PipeWriter
                    $watchdog['PipeWriter'] = $null
                }

                if ($null -ne $pipeServer) {
                    $pipeServer.Dispose()  # Dispose existing PipeServer
                    $watchdog['PipeServer'] = $null  # Set to null for reinitialization
                }

                if ($watchdog.Autostart) {
                    Write-PodeHost 'Restarting the watchdog process...'
                    if (Stop-PodeWatchdogMonitoredProcess -Name $watchdog.Name -Force) {
                        Start-PodeWatchdogMonitoredProcess -Name $watchdog.Name
                    }
                    else {
                        Write-PodeHost 'Failed to restart the watchdog process.'
                    }
                }
                else {
                    Write-PodeHost 'Autostart disabled...'
                }
            }
            finally {
                # Ensure cleanup of resources
                Write-PodeHost 'Cleaning up resources...'
                if ($null -ne $reader) { $reader.Dispose() }
                if ($null -ne $pipeServer -and $pipeServer.IsConnected) {
                    $pipeServer.Disconnect()  # Ensure server is disconnected
                }
            }
        }

        Write-PodeHost 'Stopping PipeServer...'
    }

    # Generate a unique PipeName for the Watchdog
    $pipename = "$Name_$(New-PodeGuid)"
    if ($null -eq $PodeContext.Server.Watchdog) {
        $PodeContext.Server.Watchdog = @{
            Server = @{}
        }
    }

    # Create a hashtable for Watchdog configurations
    $PodeWatchdog = @{
        DisableTermination      = $true
        Quiet                   = $true
        PipeName                = $pipename
        Interval                = $Interval
        GracefulShutdownTimeout = $GracefulShutdownTimeout
        ServiceRecoveryTime     = $ServiceRecoveryTime
    }

    # Serialize and escape the JSON configuration
    $escapedJsonConfig = ($PodeWatchdog | ConvertTo-Json -Compress).Replace('"', '\"')

    # Initialize Watchdog context with parameters
    $watchdog = [System.Collections.Concurrent.ConcurrentDictionary[string, PSObject]]::new()
    $watchdog['Name'] = $Name
    $watchdog['Shell'] = (Get-Process -Id $PID).Path
    $watchdog['Arguments'] = "$arguments  '$escapedJsonConfig'"
    $watchdog['Status'] = 'Starting'
    $watchdog['PipeName'] = $pipename
    $watchdog['ScriptBlock'] = $scriptBlock
    $watchdog['Interval'] = $Interval
    $watchdog['Enabled'] = $true
    $watchdog['Autostart'] = ! $NoAutostart.IsPresent
    $watchdog['FilePath'] = $FilePath
    $watchdog['RestartCount'] = -1
    $watchdog['MinRestartInterval'] = $MinRestartInterval
    $watchdog['Runspace'] = $null
    $watchdog['PipeServer'] = $null
    $watchdog['PipeWriter'] = $null
    $watchdog['ProcessInfo'] = $null
    $watchdog['Process'] = $null

    # Add Watchdog to the server context
    $PodeContext.Server.Watchdog.Server[$Name] = $watchdog

    # Set up file monitoring if specified
    if ($FileMonitoring.IsPresent) {
        if ($MonitoredPath) {
            if (Test-Path -Path $MonitoredPath -PathType Container) {
                $path = $MonitoredPath
            }
            else {
                throw ($PodeLocale.pathNotExistExceptionMessage -f $path)
            }
        }
        else {
            $path = (Get-Item $FilePath).DirectoryName
        }

        Add-PodeFileWatcher -Path $path -Exclude $FileExclude -Include $FileInclude -ArgumentList $Name -ScriptBlock {
            param($Name)
            $watchdog = $PodeContext.Server.Watchdog.Server[$Name]
            Write-PodeHost  "File [$($FileEvent.Type)]: $($FileEvent.FullPath) changed"
            if (((Get-Date) - ($watchdog.Process.StartTime)).TotalMinutes -gt $watchdog.MinRestartInterval ) {
                if ( $watchdog.FilePath -eq $FileEvent.FullPath) {
                    Write-PodeHost 'Force a cold restart'
                    Set-PodeWatchdogProcessState -State ColdRestart
                }
                else {
                    Write-PodeHost 'Force a restart'
                    Set-PodeWatchdogProcessState -State Restart
                }
            }
            else {
                Write-PodeHost "Less than $($watchdog.MinRestartInterval) minutes are passed since last restart."
            }
        }
    }
}



<#
.SYNOPSIS
    Checks if a Pode Watchdog service is enabled and running.

.DESCRIPTION
    Tests if a specified Watchdog service, identified by its name, is currently active and monitored by Pode.
    If no name is specified, the function will check if any Watchdog client is active in the context.

.PARAMETER Name
    The name of the Watchdog service to check.
    If not provided, the function will test for any active Watchdog clients.

.OUTPUTS
    Returns a boolean value indicating whether the specified Watchdog service (or any client) is active.

.EXAMPLE
    Test-PodeWatchdog -Name 'MyWatch01'

    This example checks if a Watchdog named 'MyWatch01' is active and running.
#>
function Test-PodeWatchdog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]
        $Name
    )

    # Return a boolean value based on the state of the Watchdog context
    return (
        # Check if the Watchdog context is initialized
        ($null -ne $PodeContext.Server.Watchdog) -and
        (
            (
                # Check if a specific Watchdog service is being monitored
                $PodeContext.Server.Watchdog.Server -and
                (![string]::IsNullOrEmpty($Name)) -and
                $PodeContext.Server.Watchdog.Server.ContainsKey($Name)
            ) -or (
                # If no name is provided, check if any Watchdog client is active
                ([string]::IsNullOrEmpty($Name)) -and
                $PodeContext.Server.Watchdog.Client
            )
        )
    )
}
<#
.SYNOPSIS
    Retrieves information about a monitored process managed by a Pode Watchdog.

.DESCRIPTION
    This function returns metrics and details regarding a monitored process that is being managed by a specified Pode Watchdog service.
    The information can be filtered based on the provided type, such as the process status, request metrics, active listeners, or signal metrics.

.PARAMETER Name
    The name of the Watchdog service monitoring the process.

.PARAMETER Type
    Specifies the type of information to retrieve:
        - 'Status': Returns the current status of the monitored process, such as Pid, Current Uptime, Total Uptime, and Restart Count.
        - 'Requests': Returns metrics related to requests processed by the monitored process.
        - 'Listeners': Returns the list of listeners active for the monitored process.
        - 'Signals': Returns metrics related to signals processed by the monitored process.
    If not specified, all available information regarding the monitored process will be returned.

.OUTPUTS
    Returns a hashtable containing the requested information about the monitored process.

.EXAMPLE
    Get-PodeWatchdogProcessMetric -Name 'MyWatch01' -Type 'Status'

    This example retrieves the current status of the monitored process managed by the Watchdog named 'MyWatch01', including its PID, uptime, and restart count.
#>
function Get-PodeWatchdogProcessMetric {
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Status', 'Requests', 'Listeners', 'Signals')]
        [string] $Type
    )

    # Check if the specified Watchdog service is active and managing a process
    if ((Test-PodeWatchdog -Name $Name)) {
        $watchdog = $PodeContext.Server.Watchdog.Server[$Name]

        # Ensure that process information is available for the monitored process
        if ($null -ne $watchdog.ProcessInfo) {
            $processInfo = $watchdog.ProcessInfo

            # Retrieve specific information based on the Type parameter
            switch ($Type) {
                'Status' {
                    # Return a hashtable with status metrics about the monitored process
                    return @{
                        Pid           = $processInfo.Pid
                        CurrentUptime = $processInfo.CurrentUptime
                        TotalUptime   = $processInfo.TotalUptime
                        RestartCount  = $processInfo.RestartCount
                    }
                }
                'Requests' {
                    # Return metrics related to requests handled by the monitored process
                    return $processInfo.Metrics.Requests
                }
                'Listeners' {
                    # Return a list of active listeners for the monitored process
                    return $processInfo.Listeners
                }
                'Signals' {
                    # Return metrics related to signals processed by the monitored process
                    return $processInfo.Metrics.Signals
                }
                default {
                    # If no specific Type is provided, return the complete process information
                    return $processInfo
                }
            }
        }
        else {
            Write-PodeHost 'ProcessInfo is empty'  # Log that no process information is available for the monitored process
        }
    }

    # Log if the specified Watchdog is not monitoring any process
    Write-PodeHost "$Name is not a monitored process by any Watchdog"

    return $null
}



<#
.SYNOPSIS
    Sets the state of a monitored process managed by a Pode Watchdog service.

.DESCRIPTION
    Changes the state of the specified monitored process managed by a Pode Watchdog service.
    The state can be set to 'Stop', 'Restart', 'Start', 'Halt', or 'Reset' to control the process's execution.
    This function allows for stopping, restarting, starting, halting (forcing stop), and resetting the monitored process while considering the Watchdog's autostart settings.

.PARAMETER Name
    The name of the Watchdog service managing the monitored process.
    This parameter is mandatory.

.PARAMETER State
    Specifies the desired state for the monitored process:
        - 'Stop': Stops the monitored process and disables autostart.
        - 'Restart': Restarts the monitored process.
        - 'Start': Starts the monitored process.
        - 'Halt': Forces the monitored process to stop and disables autostart.
        - 'Reset': Stops the monitored process, restarts it, and restores the original autostart setting.
    Default value is 'Stop'.

.OUTPUTS
    Returns a boolean value indicating whether the state change was successful.

.EXAMPLE
    Set-PodeWatchdogProcessState -Name 'MyWatch01' -State 'Restart'

    This example restarts the monitored process managed by the Watchdog named 'MyWatch01'.
#>
function Set-PodeWatchdogProcessState {
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Stop', 'Restart', 'Start', 'Halt', 'Reset')]
        [string]
        $State = 'Stop'
    )

    # Check if the specified Watchdog is active and managing a process
    if ((Test-PodeWatchdog -Name $Name)) {
        $watchdog = $PodeContext.Server.Watchdog.Server[$Name]

        # Change the state of the monitored process based on the specified $State value
        switch ($State) {
            'Stop' {
                # Stop the monitored process and disable autostart
                $watchdog.Autostart = $false
                return Stop-PodeWatchdogMonitoredProcess -Name $Name
            }
            'Restart' {
                # Restart the monitored process
                $watchdog.Autostart = $false
                $result = Restart-PodeWatchdogMonitoredProcess -Name $Name
                return $result
            }
            'Start' {
                # Start the monitored process
                return Start-PodeWatchdogMonitoredProcess -Name $Name
            }
            'Halt' {
                # Force stop the monitored process and disable autostart
                $watchdog.Autostart = $false
                return Stop-PodeWatchdogMonitoredProcess -Name $Name -Force
            }
            'Reset' {
                # Reset the monitored process: stop, restart, and restore autostart setting
                $autostart = $watchdog.Autostart
                $watchdog.Autostart = $false

                if ((Stop-PodeWatchdogMonitoredProcess -Name $Name -Force)) {
                    $result = Start-PodeWatchdogMonitoredProcess -Name $Name
                    if ($result) {
                        $watchdog.Autostart = $autostart
                    }
                    return $result
                }
            }
        }
    }

    # Return $false if the specified Watchdog or monitored process is not found
    return $false
}
