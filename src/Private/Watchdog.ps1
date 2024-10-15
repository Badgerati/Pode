<#
.SYNOPSIS
    Checks if the Pode Watchdog service is enabled for either the client or server.

.DESCRIPTION
    This internal function checks whether the Pode Watchdog service is enabled by verifying if the 'Watchdog' key exists in the `PodeContext.Server`.
    It can check specifically for the client or server component, or both, based on the provided parameter set.

.PARAMETER Client
    Checks if the Pode Watchdog client component is enabled.

.PARAMETER Server
    Checks if the Pode Watchdog server component is enabled.

.OUTPUTS
    [boolean]
        Returns $true if the Watchdog service is enabled for the requested component (client or server), otherwise returns $false.

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function Test-PodeWatchDogEnabled {
    [CmdletBinding(DefaultParameterSetName = 'Builtin')]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'Client')]
        [switch]
        $Client,

        [Parameter(Mandatory = $true, ParameterSetName = 'Server')]
        [switch]
        $Server
    )

    # Check if the Watchdog Client is enabled
    if ($Client.IsPresent) {
        return $PodeContext.Server.containsKey('Watchdog') -and $PodeContext.Server.Watchdog.containsKey('Client')
    }

    # Check if the Watchdog Server is enabled
    if ($Server.IsPresent) {
        return $PodeContext.Server.containsKey('Watchdog') -and $PodeContext.Server.Watchdog.containsKey('Server')
    }

    # Check if any Watchdog component is enabled
    return $PodeContext.Server.containsKey('Watchdog')
}

<#
.SYNOPSIS
    Stops a monitored process managed by a Pode Watchdog service.

.DESCRIPTION
    This internal function attempts to stop a monitored process managed by a Pode Watchdog.
    It supports both graceful shutdowns through inter-process communication (IPC) via pipes and forced termination.

.PARAMETER Name
    The name of the Watchdog service managing the monitored process.

.PARAMETER Timeout
    The timeout period (in seconds) to wait for the process to shut down gracefully before returning a failure.
    Default is 30 seconds.

.PARAMETER Force
    If specified, the process will be forcibly terminated without a graceful shutdown.

.OUTPUTS
    [boolean]
        Returns $true if the process was stopped successfully, otherwise $false.

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function Stop-PodeWatchdogMonitoredProcess {
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [int]
        $Timeout = 30,

        [switch]
        $Force
    )

    # If the Watchdog with the specified name is not found, exit the function
    if (!(Test-PodeWatchdog -Name $Name)) {
        return
    }

    # Retrieve the Watchdog instance from the Pode context
    $watchdog = $PodeContext.Server.Watchdog.Server[$Name]

    # If the Force switch is specified, forcibly terminate the process
    if ($Force.IsPresent) {
        if (@('Stopping', 'Stopped') -icontains $watchdog.ProcessInfo.Status ) {
            Write-PodeWatchdogLog -Watchdog $watchdog -Message "Cannot Terminate a process in $($watchdog.ProcessInfo.Status) state."
            return $false
        }
        if ($null -ne $watchdog.Process) {
            Write-PodeWatchdogLog -Watchdog $watchdog -Message "Try to stop the process forcefully using the process ID($($watchdog.Process.Id))"
            # Try to stop the process forcefully using its ID
            $stoppedProcess = Get-Process -Id $watchdog.Process.Id -ErrorAction SilentlyContinue
            if ($null -ne $stoppedProcess) {
                $watchdog.ProcessInfo.Status = 'Stopping'
                $stoppedProcess = Stop-Process -Id $watchdog.Process.Id -PassThru -ErrorAction SilentlyContinue
                if ($null -eq $stoppedProcess) {
                    return $false  # Return false if the process could not be stopped
                }
            }
            # Clear the process information and update the status to 'Stopped'
            $watchdog.Process = $null
            $watchdog.ProcessInfo.Status = 'Stopped'
            return $true
        }
        else {
            Write-PodeWatchdogLog -Watchdog $watchdog -Message 'No watchdog process found'  # Log if no process is found for the Watchdog
        }

        return $false
    }

    try {
        if ( $watchdog.ProcessInfo.Status -ne 'Running' ) {
            Write-PodeWatchdogLog -Watchdog $watchdog -Message 'Cannot stop a process that is not in running state.'
            return $false
        }
        # Attempt graceful shutdown via pipe communication
        if (! (Send-PodeWatchdogMessage -Name $Name -Command 'shutdown')) {
            return $false
        }
        # Wait for the process to exit within the specified timeout
        $counter = 0
        $process = Get-Process -Id $watchdog.Process.Id -ErrorAction SilentlyContinue
        while ($null -ne $process) {
            Start-Sleep -Seconds 1
            $process = Get-Process -Id $watchdog.Process.Id -ErrorAction SilentlyContinue
            $counter++
            if ($counter -ge $Timeout) {
                Write-PodeWatchdogLog -Watchdog $watchdog -Message 'Stop-PodeWatchdogMonitoredProcess timeout reached'  # Log timeout
                return $false
            }
        }

        # Clear process information and update status upon successful shutdown
        $watchdog.Process = $null
        return $true
    }
    catch {
        # Log any errors that occur during the shutdown process
        $_ | Write-PodeWatchdogLog -Watchdog $watchdog
        return $false
    }
}


<#
.SYNOPSIS
    Restarts a monitored process managed by a Pode Watchdog service.

.DESCRIPTION
    This internal function sends a restart command to a monitored process managed by a Pode Watchdog service via inter-process communication (IPC) using pipes.
    It waits for the process to restart and verifies that the restart was successful by checking the restart count.

.PARAMETER Name
    The name of the Watchdog service managing the monitored process.

.PARAMETER Timeout
    The timeout period (in seconds) to wait for the process to restart gracefully before returning a failure.
    Default is 30 seconds.

.OUTPUTS
    [bool]
        Returns $true if the process was restarted successfully, otherwise $false.

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function Restart-PodeWatchdogMonitoredProcess {
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [int]
        $Timeout = 30
    )

    # If the Watchdog with the specified name is not found, exit the function
    if (!(Test-PodeWatchdog -Name $Name)) {
        return
    }

    # Retrieve the Watchdog instance from the Pode context
    $watchdog = $PodeContext.Server.Watchdog.Server[$Name]

    try {
        if ( $watchdog.ProcessInfo.Status -ne 'Running' ) {
            Write-PodeWatchdogLog -Watchdog $watchdog -Message 'Cannot restart a process that is not in running state.'
            return $false
        }
        
        $restartCount = $watchdog.ProcessInfo.RestartCount
        # Attempt to restart the monitored process via pipe communication
        if (! (Send-PodeWatchdogMessage -Name $Name -Command 'Restart')) {
            return $false
        }

        # Initialize counter for the first check (Running)
        $counter = 0
        # Wait for the monitored process to update its process info after restarting
        while ($watchdog.ProcessInfo.Status -eq 'Running' -and $counter -lt $Timeout) {
            Start-Sleep 1
            $counter++

            # Exit the loop if timeout is reached
            if ($counter -ge $Timeout) {
                Write-PodeWatchdogLog -Watchdog $watchdog -Message  "Timeout ($Timeout secs) reached while waiting for the process to stop running."
                return $false
            }
        }

        # Wait for the process to stop restarting
        while ($watchdog.ProcessInfo.Status -eq 'Restarting' -and $counter -lt $Timeout) {
            Start-Sleep 1
            $counter++

            # Exit the loop if timeout is reached
            if ($counter -ge $Timeout) {
                Write-PodeWatchdogLog -Watchdog $watchdog -Message  "Timeout ($Timeout secs) reached while waiting for the process to stop running."
                return $false
            }
        }

        # Verify that the restart count has incremented, indicating a successful restart
        return ($watchdog.ProcessInfo.RestartCount -eq ($restartCount + 1))
    }
    catch {
        # Log any errors that occur during the restart process
        $_ | Write-PodeWatchdogLog -Watchdog $watchdog
        return $false
    }
}

<#
.SYNOPSIS
    Starts a monitored process managed by a Pode Watchdog service.

.DESCRIPTION
    This internal function starts the process that is monitored by the specified Pode Watchdog service.
    It uses the configured shell and arguments stored in the Watchdog context to start the process and updates the Watchdog's status accordingly.

.PARAMETER Name
    The name of the Watchdog service managing the monitored process.

.OUTPUTS
    [bool]
        Returns $true if the process was started successfully, otherwise $false.

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function Start-PodeWatchdogMonitoredProcess {
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    # If the Watchdog with the specified name is not found, exit the function
    if (!(Test-PodeWatchdog -Name $Name)) {
        return
    }

    # Retrieve the Watchdog instance from the Pode context
    $watchdog = $PodeContext.Server.Watchdog.Server[$Name]

    if ( $watchdog.ProcessInfo.Status -ne 'Stopped') {
        Write-PodeWatchdogLog -Watchdog $watchdog -Message "Cannot start a process in $($watchdog.ProcessInfo.Status) state."
        return $false
    }

    # Check if the monitored process is not already running
    if ($null -eq $watchdog.Process) {
        $watchdog.ProcessInfo.Status = 'Starting'

        # Start the monitored process using the shell and arguments from the Watchdog context
        $watchdog.Process = Start-Process -FilePath $watchdog.Shell -ArgumentList $watchdog.Arguments -NoNewWindow -PassThru

        $watchdog.ProcessInfo.Pid = $watchdog.Process.Id
        $watchdog.ProcessInfo.Accessible = $false

        # Increment the restart count
        $watchdog.RestartCount = $watchdog.RestartCount + 1


        # Output the process information for debugging purposes
        Write-PodeWatchdogLog -Watchdog $watchdog -Message ((
                $watchdog.Process | Select-Object @{Name = 'NPM(K)'; Expression = { $_.NPM } },
                @{Name = 'PM(M)'; Expression = { [math]::round($_.PM / 1MB, 2) } },
                @{Name = 'WS(M)'; Expression = { [math]::round($_.WS / 1MB, 2) } },
                @{Name = 'CPU(s)'; Expression = { [math]::round($_.CPU, 2) } },
                Id, SI, ProcessName
            ) -join ',')

        # Check if the process was successfully started and is running
        if (!$watchdog.Process.HasExited) {
            return $true
        }
        else {
            # If the process has already exited, mark the status as 'Stopped'
            $watchdog.ProcessInfo.Status = 'Stopped'
        }
    }

    # Return false if the process could not be started or was already running
    return $false
}

<#
.SYNOPSIS
    Starts the runspaces for all active Pode Watchdog services.

.DESCRIPTION
    This internal function iterates through all active Watchdog services in the Pode context, starts their monitored processes, and initializes a runspace for each Watchdog using the provided script block.

.OUTPUTS
    None

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function Start-PodeWatchdogRunspace {
    # Iterate through each Watchdog service in the Pode context
    foreach ($name in $PodeContext.Server.Watchdog.Server.Keys) {
        $watchdog = $PodeContext.Server.Watchdog.Server[$name]
        Write-PodeWatchdogLog -Watchdog $watchdog -Message "Starting Watchdog $name"
        # Start the monitored process for the Watchdog
        $null = Start-PodeWatchdogMonitoredProcess -Name $name

        # Initialize a runspace for the Watchdog using the provided ScriptBlock
        $watchdog.Runspace = Add-PodeRunspace -Type 'Watchdog' `
            -ScriptBlock ($watchdog.ScriptBlock) `
            -Parameters @{'WatchdogName' = $watchdog.Name } `
            -PassThru
        Write-PodeWatchdogLog -Watchdog $watchdog -Message "Watchdog $name started"
    }

}


<#
.SYNOPSIS
    Stops the runspaces and monitored processes for all active Pode Watchdog services.

.DESCRIPTION
    This internal function iterates through all active Watchdog services in the Pode context, stops their monitored processes, disables their runspaces, and cleans up any resources such as pipe servers and writers.

.OUTPUTS
    None

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function Stop-PodeWatchdogRunspace {

    # Iterate through each Watchdog service in the Pode context
    foreach ($name in $PodeContext.Server.Watchdog.Server.Keys) {
        $watchdog = $PodeContext.Server.Watchdog.Server[$name]
        # Disable the Watchdog service
        $watchdog.Enabled = $false
        # Disable autorestart
        $watchdog.AutoRestart.Enabled = $false


        # Attempt to stop the monitored process and update the status accordingly
        $null = Stop-PodeWatchdogMonitoredProcess -Name $name -Timeout 60

        # Clean up the PipeWriter if it exists
        if ($null -ne $watchdog.PipeWriter) {
            try {
                $watchdog.PipeWriter.Dispose()
            }
            catch {
                $_ | Write-PodeWatchdogLog -Watchdog $watchdog -Level Verbose  # Log errors during disposal of PipeWriter
            }
        }

        # Clean up the PipeServer if it exists
        if ($null -ne $watchdog.PipeServer) {
            try {
                # Disconnect the PipeServer if it is still connected
                if ($watchdog.PipeServer.IsConnected()) {
                    $watchdog.PipeServer.Disconnect()
                }
            }
            catch {
                $_ | Write-PodeWatchdogLog -Watchdog $watchdog -Level Verbose  # Log errors during disconnection of PipeServer
            }

            # Dispose of the PipeServer
            try {
                $watchdog.PipeServer.Dispose()
            }
            catch {
                $_ | Write-PodeWatchdogLog -Watchdog $watchdog -Level Verbose  # Log errors during disposal of PipeServer
            }
        }
    }
}

<#
.SYNOPSIS
    Stops the Pode Watchdog service, including both client and server components.

.DESCRIPTION
    This internal function checks if the Pode Watchdog service is running and stops both the client (heartbeat) and server (runspace) components if they exist.

.OUTPUTS
    None

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function Stop-PodeWatchdog {

    # Check if the Watchdog service exists in the Pode context
    if ($PodeContext.Server.containsKey('Watchdog')) {
        #    Write-PodeWatchdogLog -Watchdog $watchdog -Message 'Stopping watchdog'

        # Stop the Watchdog client (heartbeat) if it exists
        if ($PodeContext.Server.Watchdog.containsKey('Client')) {
            Stop-PodeWatchdogHearthbeat
        }

        # Stop the Watchdog server (runspace) if it exists
        if ($PodeContext.Server.Watchdog.containsKey('Server')) {
            Stop-PodeWatchdogRunspace
        }
    }
}

<#
.SYNOPSIS
    Starts the Pode Watchdog service, including both client and server components.

.DESCRIPTION
    This internal function checks if the Pode Watchdog service is running and starts both the client (heartbeat) and server (runspace) components if they exist.

.OUTPUTS
    None

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function Start-PodeWatchdog {

    # Check if the Watchdog service exists in the Pode context
    if ($PodeContext.Server.containsKey('Watchdog')) {

        # Start the Watchdog client (heartbeat) if it exists
        if ($PodeContext.Server.Watchdog.containsKey('Client')) {
            #    Write-PodeWatchdogLog -Watchdog $watchdog -Message 'Starting Client watchdog'
            Start-PodeWatchdogHearthbeat
        }

        # Start the Watchdog server (runspace) if it exists
        if ($PodeContext.Server.Watchdog.containsKey('Server')) {
            #    Write-PodeWatchdogLog -Watchdog $watchdog -Message 'Starting Server watchdog'
            Start-PodeWatchdogRunspace
        }
    }
}

<#
.SYNOPSIS
    Sends a command to the monitored process via the Pode Watchdog pipe.

.DESCRIPTION
    This function sends a specified command to the monitored process through the Watchdog pipe communication. It ensures the command is delivered immediately via the PipeWriter.
    If the pipe is disconnected, the function logs the failure and returns $false.

    .PARAMETER Name
    The name of the Watchdog service managing the monitored process.

.PARAMETER Command
    The command to be sent to the monitored process. This could be commands like 'restart', 'shutdown', etc.

.OUTPUTS
    [boolean]
        Returns $true if the command was successfully sent via the pipe, otherwise returns $false if the connection was lost.

.EXAMPLE
    Send-PodeWatchdogMessage -Name 'Watcher01' -Command 'restart'

    Sends a 'restart' command to the monitored process through the Watchdog pipe.

.NOTES
    This function is used for communication with monitored processes in Pode and may change in future releases of Pode.
#>
function Send-PodeWatchdogMessage {
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true)]
        [string]
        $Command
    )
    # Retrieve the Watchdog instance from the Pode context
    $watchdog = $PodeContext.Server.Watchdog.Server[$Name]

    # Attempt to send the command to the monitored process via pipe communication
    if ($watchdog.PipeServer.IsConnected) {

        Write-PodeWatchdogLog -Watchdog $watchdog -Message "Send the command '$Command' to the monitored process via the PipeWriter."
        # Send the command to the monitored process via the PipeWriter
        $watchdog.PipeWriter.WriteLine($Command)
        $watchdog.PipeWriter.Flush()  # Ensure the message is sent immediately
        return $true
    }
    else {
        Write-PodeWatchdogLog -Watchdog $watchdog -Message "Pipe connection lost. Command '$Command' cannot be delivered."
        return $false
    }
}

<#
.SYNOPSIS
    Retrieves the total number of active Pode Watchdog runspaces.

.DESCRIPTION
    This internal function calculates the total number of active Watchdog runspaces by counting both the client and server components of the Pode Watchdog service.
    The function is used to update the number of running threads in `$PodeContext.Threads['Watchdog']`.

.OUTPUTS
    [int]
        Returns the total count of active Watchdog runspaces.

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function Get-PodeWatchdogRunspaceCount {
    # Initialize the total runspace count
    $totalWatchdogRunspaces = 0

    # Check if the Watchdog client exists and add 1 to the total count
    if ($PodeContext.Server.Watchdog.containsKey('Client')) {
        $totalWatchdogRunspaces += 1
    }

    # Check if the Watchdog server exists and add the count of server runspaces
    if ($PodeContext.Server.Watchdog.containsKey('Server')) {
        $totalWatchdogRunspaces += $PodeContext.Server.Watchdog.Server.Count
    }

    # Return the total number of Watchdog runspaces
    return $totalWatchdogRunspaces
}

<#
.SYNOPSIS
    Returns the script block for initializing and running the Pode Watchdog PipeServer.

.DESCRIPTION
    This function returns a script block that initializes the Pode Watchdog PipeServer and manages communication between the server and the monitored process.
    It handles the creation of the PipeServer, sending and receiving messages through pipes, managing process information, and restarting the monitored process based on the AutoRestart settings.

.OUTPUTS
    [scriptblock]
        A script block that initializes and runs the Watchdog PipeServer.

.NOTES
    This function is used internally to manage Watchdog server communication and may change in future releases of Pode.
#>
function Get-PodeWatchdogPipeServerScriptBlock {
    # Main script block to initialize and run the Watchdog PipeServer
    return [scriptblock] {
        param (
            [string]
            $WatchdogName
        )

        Write-PodeWatchdogLog -Watchdog $watchdog -Message "Starting PipeServer $WatchdogName..."
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
                    Write-PodeWatchdogLog -Watchdog $watchdog -Message 'New PipeServer instance created and stored in Watchdog context.'

                    # Initialize the StreamWriter when PipeServer is set
                    $watchdog['PipeWriter'] = [System.IO.StreamWriter]::new($watchdog['PipeServer'])
                    Write-PodeWatchdogLog -Watchdog $watchdog -Message 'New PipeWriter instance created and stored in Watchdog context.'
                }

                $pipeServer = $watchdog['PipeServer']
                Write-PodeWatchdogLog -Watchdog $watchdog -Message 'PipeServer created and waiting for connection...'
                $pipeServer.WaitForConnection()
                Write-PodeWatchdogLog -Watchdog $watchdog -Message 'Client connected.'

                # Create a StreamReader to read messages from the client
                $reader = [System.IO.StreamReader]::new($pipeServer)

                while ($pipeServer.IsConnected) {
                    try {
                        # Read the next message from the client
                        $receivedData = $reader.ReadLine()

                        if ($null -ne $receivedData) {
                            Write-PodeWatchdogLog -Watchdog $watchdog -Message "Server Received data: $receivedData"
                            # Deserialize received JSON string into a hashtable
                            $watchdog.ProcessInfo = $receivedData | ConvertFrom-Json

                            # Handle AutoRestart settings based on uptime and restart count
                            if ($watchdog.AutoRestart.RestartCount -gt 0 -and $watchdog.ProcessInfo.CurrentUptime -ge $watchdog.AutoRestart.ResetFailCountAfter) {
                                Write-PodeWatchdogLog -Watchdog $watchdog -Message 'Process uptime exceeds threshold. Resetting fail counter.'
                                $watchdog.AutoRestart.RestartCount = 0
                            }
                        }
                        else {
                            Write-PodeWatchdogLog -Watchdog $watchdog -Message 'No data received from client. Waiting for more data...'
                        }
                    }
                    catch {
                        Write-PodeWatchdogLog -Watchdog $watchdog -Message "Error reading from client: $_"
                        $pipeServer.Disconnect()  # Disconnect to allow reconnection
                        Start-Sleep -Seconds 1
                    }
                }

                # Client disconnected, clean up
                Write-PodeWatchdogLog -Watchdog $watchdog -Message 'Client disconnected. Waiting for a new connection...'
            }
            catch {
                Write-PodeWatchdogLog -Watchdog $watchdog -Message "Error with the pipe server: $_"
            }
            finally {
                if ($watchdog.Enabled) {
                    # Handle monitored process state reporting and AutoRestart logic
                    $reportedStatus = $watchdog.ProcessInfo.Status
                    if ($reportedStatus -eq 'Running') {
                        if ($null -eq (Get-Process -Id $watchdog.Process.Id -ErrorAction SilentlyContinue)) {
                            $watchdog.ProcessInfo.Status = 'Stopped'
                            $watchdog.ProcessInfo.Accessible = $false
                            $watchdog.ProcessInfo.Pid = ''
                            $watchdog.Process = $null
                        }
                        else {
                            $processInfo.Status = 'Undefined'
                            $watchdog.Process = $null
                        }
                    }

                    Write-PodeWatchdogLog -Watchdog $watchdog -Message "Monitored process was reported to be $reportedStatus."

                    if ($watchdog.AutoRestart.Enabled) {
                        if ($reportedStatus -eq 'Running') {
                            if ($watchdog.AutoRestart.RestartCount -le $watchdog.AutoRestart.MaxNumberOfRestarts) {
                                Write-PodeWatchdogLog -Watchdog $watchdog -Message "Waiting $($watchdog.AutoRestart.RestartServiceAfter) seconds before restarting the monitored process"
                                Start-Sleep -Seconds $watchdog.AutoRestart.RestartServiceAfter

                                Write-PodeWatchdogLog -Watchdog $watchdog -Message 'Restarting the monitored process...'
                                if (Stop-PodeWatchdogMonitoredProcess -Name $watchdog.Name -Force) {
                                    Start-PodeWatchdogMonitoredProcess -Name $watchdog.Name
                                    $watchdog.AutoRestart.RestartCount += 1
                                    Write-PodeWatchdogLog -Watchdog $watchdog -Message "Monitored process (ID: $($watchdog.Process.Id)) restarted ($($watchdog.AutoRestart.RestartCount) time(s)) successfully."
                                }
                                else {
                                    Write-PodeWatchdogLog -Watchdog $watchdog -Message 'Failed to restart the monitored process.'
                                }
                            }
                            else {
                                Write-PodeWatchdogLog -Watchdog $watchdog -Message 'The monitored process restart count reached the max number of restarts allowed.'
                            }
                        }
                        else {
                            Write-PodeWatchdogLog -Watchdog $watchdog -Message "Restart not required as the monitored process was not in 'running' state ($($watchdog.ProcessInfo.Status))."
                        }
                    }
                    else {
                        Write-PodeWatchdogLog -Watchdog $watchdog -Message 'AutoRestart is disabled. Nothing to do.'
                    }
                }

                # Ensure cleanup of resources
                Write-PodeWatchdogLog -Watchdog $watchdog -Message 'Cleaning up resources...'
                if ($null -ne $reader) { $reader.Dispose() }
                if ($null -ne $pipeServer -and $pipeServer.IsConnected) {
                    $pipeServer.Disconnect()  # Ensure server is disconnected
                }

                # Release resources and reinitialize PipeServer
                Write-PodeWatchdogLog -Watchdog $watchdog -Message 'Releasing resources and setting PipeServer to null.'
                if ($null -ne $watchdog['PipeWriter']) {
                    $watchdog['PipeWriter'].Dispose()  # Dispose existing PipeWriter
                    $watchdog['PipeWriter'] = $null
                }

                if ($null -ne $pipeServer) {
                    $pipeServer.Dispose()  # Dispose existing PipeServer
                    $watchdog['PipeServer'] = $null  # Set to null for reinitialization
                }
            }
        }

        Write-PodeWatchdogLog -Watchdog $watchdog -Message 'Stopping PipeServer...'
    }
}


<#
.SYNOPSIS
    Displays startup information for the Pode Watchdog service.

.DESCRIPTION
    This function outputs the status and details of the active Pode Watchdog service, including information about monitored processes.
    It checks if the Watchdog service is enabled for the server, and if it is, prints a formatted table showing key process metrics such as memory usage, CPU usage, and process IDs.
    This function helps in visually confirming that the Watchdog service is active and monitoring processes as expected.

.PARAMETER None
    This function does not take any parameters.

.NOTES
    This function is intended for internal use within the Pode Watchdog system to display startup messages.
#>

function Write-PodeWatchdogStartupMessage {
    # Check if the Watchdog service is enabled for the server
    if ((Test-PodeWatchDogEnabled -Server)) {

        # Print a blank line and indicate that the Watchdog is active
        Write-PodeHost
        Write-PodeHost 'Watchdog [Active]' -ForegroundColor Cyan

        # If more than one process is monitored, adjust the message for plural
        if ($PodeContext.Server.Watchdog.Server.Count -gt 1) {
            Write-PodeHost 'Monitored processes:' -ForegroundColor Yellow
        }
        else {
            Write-PodeHost 'Monitored process:' -ForegroundColor Yellow
        }

        # Print the header for the process information table
        Write-PodeHost "`tName`tNPM(K)`tPM(M)`tWS(M)`tCPU(s)`tId`tSI`tSBlock`tFile" -ForegroundColor Yellow

        # Loop through each monitored process in the Watchdog's server context
        foreach ($name in $PodeContext.Server.Watchdog.Server.Keys) {
            $watchdog = $PodeContext.Server.Watchdog.Server[$name]
            $process = $watchdog.Process
            $scriptblock = [string]::IsNullOrEmpty($watchdog.FilePath)
            if ($scriptblock) {
                $fileName = ''
            }
            else {
                $fileName = Split-Path -Path $watchdog.FilePath -Leaf
            }

            # Print process metrics: Name, NPM, PM, WS, CPU, Process Id, Session Id, ScriptBlock, FileName
            Write-PodeHost "`t$name`t$($process.NPM)`t$([math]::round($process.PM / 1MB, 2))`t$([math]::round($process.WS / 1MB, 2))`t$([math]::round($process.CPU, 2))`t$($process.Id)`t$($process.SI)`t$scriptblock`t$filename" -ForegroundColor Yellow
        }
    }
}


<#
.SYNOPSIS
    Temporary function in place to log messages.

.DESCRIPTION
    This function is used by the Watchdog script to log messages. It takes a single parameter, $Message, which is a string that contains the message to be logged.

.OUTPUTS
    [none]

.NOTES
    This function will be replace by a more robust one when https://github.com/Badgerati/Pode/pull/1387 will be merged.
#>

function Write-PodeWatchdogLog {
    [CmdletBinding(DefaultParameterSetName = 'Message')]
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.Concurrent.ConcurrentDictionary[string, PSObject]]
        $Watchdog,

        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = 'Exception')]
        [System.Exception]
        $Exception,

        [Parameter(ParameterSetName = 'Exception')]
        [switch]
        $CheckInnerException,

        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = 'Error')]
        [System.Management.Automation.ErrorRecord]
        $ErrorRecord,

        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = 'Message')]
        [string]
        $Message,

        [string]
        $Level = 'Informational',

        [string]
        $Tag = '-',

        [Parameter()]
        [int]
        $ThreadId

    )
    Process {
        switch ($PSCmdlet.ParameterSetName.ToLowerInvariant()) {

            'message' {
                $logItem = @{
                    Name = $Watchdog.Name
                    Date = (Get-Date).ToUniversalTime()
                    Item = @{
                        Level   = $Level
                        Message = $Message
                        Tag     = $Tag
                    }
                }
                break
            }
            'custom' {
                $logItem = @{
                    Name = $Watchdog.Name
                    Date = (Get-Date).ToUniversalTime()
                    Item = @{
                        Level   = $Level
                        Message = $Message
                        Tag     = $Tag
                    }
                }
                break
            }
            'exception' {
                $logItem = @{
                    Name = $Watchdog.Name
                    Date = (Get-Date).ToUniversalTime()
                    Item = @{
                        Category   = $Exception.Source
                        Message    = $Exception.Message
                        StackTrace = $Exception.StackTrace
                        Level      = $Level
                    }
                }
                Write-PodeErrorLog -Level $Level -CheckInnerException:$CheckInnerException -Exception $Exception
            }

            'error' {
                $logItem = @{
                    Name = $Watchdog.Name
                    Date = (Get-Date).ToUniversalTime()
                    Item = @{
                        Category   = $ErrorRecord.CategoryInfo.ToString()
                        Message    = $ErrorRecord.Exception.Message
                        StackTrace = $ErrorRecord.ScriptStackTrace
                        Level      = $Level
                    }
                }
                Write-PodeErrorLog -Level $Level -ErrorRecord $ErrorRecord
            }
        }

        $lpath = Get-PodeRelativePath -Path './logs' -JoinRoot
        $logItem | ConvertTo-Json -Compress -Depth 5 | Add-Content "$lpath/watchdog-$($Watchdog.Name).log"

    }
}
