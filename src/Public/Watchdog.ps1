<#
.SYNOPSIS
    Enables a Pode Watchdog service to monitor a script or file for changes and control its lifecycle.

.DESCRIPTION
    Configures and starts a Pode Watchdog service to monitor either a script block or a file path.
    The Watchdog service can monitor files or directories for changes and automatically restart the monitored process when needed.
    Additionally, it supports automatic process restarts based on a set of conditions, graceful shutdowns, and recovery times after restarts.
    A hashtable of parameters can also be passed to the script block or file being monitored.

.PARAMETER Name
    The name of the Watchdog service.

.PARAMETER ScriptBlock
    The script block to be executed and monitored by the Watchdog service.
    This parameter is mandatory when using the 'Script' or 'ScriptMonitoring' parameter sets.

.PARAMETER FilePath
    The path to the file to be executed and monitored by the Watchdog service.
    This parameter is mandatory when using the 'File' or 'FileMonitoring' parameter sets.

.PARAMETER Parameters
    A hashtable of parameters to pass to the script block or file.
    The keys of the hashtable represent the parameter names, and the values represent the parameter values.
    These parameters are dynamically passed to the script block or file when the Watchdog invokes them.

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
    Disables the automatic restart of the monitored process when it stops or encounters an error.

.PARAMETER RestartServiceAfter
    Defines the time, in seconds, before the service attempts to restart the monitored process after a failure.
    Default is 60 seconds.

.PARAMETER MaxNumberOfRestarts
    Specifies the maximum number of times the Watchdog is allowed to restart the monitored process in case of repeated failures.
    Default is 5 restarts.

.PARAMETER ResetFailCountAfter
    The time, in minutes, after which the failure restart count will be reset if the process has been running continuously without issues.
    Default is 5 minutes.

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

.EXAMPLE
    Enable-PodeWatchdog -ScriptBlock { Start-Sleep -Seconds 30 } -Name 'MyScriptWatchdog' -Parameter @{WaitTime=30}

    This example sets up a Watchdog to monitor a script block that sleeps for 30 seconds, passing the parameter 'WaitTime' with a value of 30 to the script block.

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

        [Parameter(Mandatory = $false, ParameterSetName = 'File')]
        [Parameter(Mandatory = $false, ParameterSetName = 'FileMonitoring')]
        [hashtable]
        $Parameters,

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

        [int ]
        $RestartServiceAfter = 60,

        [int]
        $MaxNumberOfRestarts = 5,

        [int]
        $ResetFailCountAfter = 5,

        [int]
        $GracefulShutdownTimeout = 30,

        [int]
        $ServiceRecoveryTime = 60
    )

    if ($Parameters) {
        # Convert the hashtable into a string with parameters
        $parameterString = ($Parameters.GetEnumerator() | ForEach-Object { if ($_.Value -is [string]) {
                    # Escape single quotes by replacing ' with ''
                    $escapedValue = $_.Value -replace "'", "''"
                    "-$($_.Key) '$escapedValue'"
                }
                else {
                    "-$($_.Key) $($_.Value)"
                }
            }) -join ' '
    }
    else {
        $parameterString = ''
    }

    # Check which parameter set is being used and adjust accordingly
    if ($PSCmdlet.ParameterSetName -ieq 'File' -or $PSCmdlet.ParameterSetName -ieq 'FileMonitoring') {
        # Resolve file path and determine root path
        $FilePath = Get-PodeRelativePath -Path $FilePath -Resolve -TestPath -JoinRoot -RootPath $MyInvocation.PSScriptRoot

        # Construct arguments for file execution
        $arguments = "-NoProfile -Command `"& {
            `$global:PodeWatchdog = `$args[0] | ConvertFrom-Json;
            . `"$FilePath`" $parameterString
        }`""
    }
    else {
        # For 'Script' parameter set: serialize the scriptblock for execution
        $scriptBlockString = $ScriptBlock.ToString()
        $arguments = "-NoProfile -Command `"& {
            `$PodeWatchdog = `$args[0] | ConvertFrom-Json;
             & { $scriptBlockString } $parameterString
        }`""
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
    $watchdog['PipeName'] = $pipename
    $watchdog['ScriptBlock'] = Get-PodeWatchdogPipeServerScriptBlock
    $watchdog['Interval'] = $Interval
    $watchdog['Enabled'] = $true
    $watchdog['FilePath'] = $FilePath
    $watchdog['RestartCount'] = -1
    $watchdog['AutoRestart'] = [System.Collections.Concurrent.ConcurrentDictionary[string, PSObject]]::new()
    $watchdog.AutoRestart['Enabled'] = ! $NoAutostart.IsPresent
    $watchdog.AutoRestart['RestartServiceAfter'] = $RestartServiceAfter
    $watchdog.AutoRestart['MaxNumberOfRestarts'] = $MaxNumberOfRestarts
    $watchdog.AutoRestart['ResetFailCountAfter'] = $ResetFailCountAfter * 60000 #in milliseconds
    $watchdog.AutoRestart['RestartCount'] = 0

    $watchdog['Runspace'] = $null
    $watchdog['PipeServer'] = $null
    $watchdog['PipeWriter'] = $null
    $watchdog['ProcessInfo'] = [ordered]@{Status = 'Stopped'; Accessible = $false; Pid = '' }
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
                        Status        = $processInfo.Status
                        Accessible    = $processInfo.Accessible
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
                    return $processInfo
                }
            }
        }
        else {
            Write-PodeHost 'ProcessInfo is empty'  # Log that no process information is available for the monitored process
        }
    }
    else {
        # Log if the specified Watchdog is not monitoring any process
        Write-PodeHost "$Name is not a monitored process by any Watchdog"
    }

    return $null
}


<#
.SYNOPSIS
    Sets the state of a monitored process managed by a Pode Watchdog service.

.DESCRIPTION
    This function allows for controlling the execution state of a process being monitored by a Pode Watchdog service.
    You can stop, start, restart, terminate, reset, disable, or enable the monitored process. The function checks if the specified Watchdog service is active and managing a process before performing the requested state change.
    It integrates with the Watchdog's autorestart and communication features to ensure smooth state transitions.

.PARAMETER Name
    The name of the Watchdog service managing the monitored process. This parameter is mandatory.

.PARAMETER State
    Specifies the desired state for the monitored process:
        - 'Stop': Stops the monitored process.
        - 'Restart': Restarts the monitored process.
        - 'Start': Starts the monitored process.
        - 'Terminate': Forces the monitored process to stop.
        - 'Reset': Stops and restarts the monitored process.
        - 'Disable': Disables new requests by sending a command to the Watchdog.
        - 'Enable': Enables new requests by sending a command to the Watchdog.
    Default value is 'Stop'.

.OUTPUTS
    [boolean]
        Returns a boolean value indicating whether the state change was successful.

.EXAMPLE
    Set-PodeWatchdogProcessState -Name 'MyWatch01' -State 'Restart'

    This example restarts the monitored process managed by the Watchdog named 'MyWatch01'.

.EXAMPLE
    Set-PodeWatchdogProcessState -Name 'MyWatch01' -State 'Disable'

    This example disables new requests for the monitored process managed by the Watchdog named 'MyWatch01', sending a 'disable' command.

.NOTES
    This function interacts with the Pode Watchdog services and may change in future releases.
#>
function Set-PodeWatchdogProcessState {
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Stop', 'Restart', 'Start', 'Terminate', 'Reset', 'Disable', 'Enable')]
        [string]
        $State = 'Stop'
    )

    # Check if the specified Watchdog is active and managing a process
    if ((Test-PodeWatchdog -Name $Name)) {

        # Change the state of the monitored process based on the specified $State value
        switch ($State) {
            'Stop' {
                # Stop the monitored process
                return Stop-PodeWatchdogMonitoredProcess -Name $Name
            }
            'Restart' {
                # Restart the monitored process
                return Restart-PodeWatchdogMonitoredProcess -Name $Name
            }
            'Start' {
                # Start the monitored process
                return Start-PodeWatchdogMonitoredProcess -Name $Name
            }
            'Terminate' {
                # Force stop the monitored process
                return Stop-PodeWatchdogMonitoredProcess -Name $Name -Force
            }
            'Reset' {
                # Reset the monitored process: stop, restart
                if ((Stop-PodeWatchdogMonitoredProcess -Name $Name -Force)) {
                    return Start-PodeWatchdogMonitoredProcess -Name $Name
                }
            }
            'Disable' {
                # Attempt to disable the service via pipe communication
                return (Send-PodeWatchdogMessage -Name $Name -Command 'disable')
            }
            'Enable' {
                # Attempt to enable the service via pipe communication
                return (Send-PodeWatchdogMessage -Name $Name -Command 'enable')
            }
        }
    }

    # Return $false if the specified Watchdog or monitored process is not found
    return $false
}


<#
.SYNOPSIS
    Enables the AutoRestart feature for a specified Pode Watchdog service.

.DESCRIPTION
    This function enables the AutoRestart feature for the specified Watchdog service, ensuring that the service automatically restarts the monitored process if it stops.

.PARAMETER Name
    The name of the Watchdog service for which to enable AutoRestart.
#>
function Enable-PodeWatchdogAutoRestart {
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    # Check if the specified Watchdog service is active and managing a process
    if ((Test-PodeWatchdog -Name $Name)) {
        Write-PodeHost 'AutoRestart feature is Enabled'
        $PodeContext.Server.Watchdog.Server[$Name].AutoRestart.Enabled = $true
    }
}



<#
.SYNOPSIS
    Disables the AutoRestart feature for a specified Pode Watchdog service.

.DESCRIPTION
    This function disables the AutoRestart feature for the specified Watchdog service, preventing the service from automatically restarting the monitored process if it stops.

.PARAMETER Name
    The name of the Watchdog service for which to disable AutoRestart.
#>
function Disable-PodeWatchdogAutoRestart {
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    # Check if the specified Watchdog service is active and managing a process
    if ((Test-PodeWatchdog -Name $Name)) {
        Write-PodeHost 'AutoRestart feature is Disabled'
        $PodeContext.Server.Watchdog.Server[$Name].AutoRestart.Enabled = $false
    }
}


