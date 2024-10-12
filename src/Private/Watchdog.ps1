


<#
.SYNOPSIS
    Checks if the Pode Watchdog service is enabled.

.DESCRIPTION
    This internal function checks whether the Pode Watchdog service is enabled by verifying if the 'Watchdog' key exists in the PodeContext.Server.

.OUTPUTS
    [boolean]
        Returns $true if the Watchdog service is enabled, otherwise returns $false.

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function Test-PodeWatchDogEnabled {
    # Check if the Watchdog service is enabled by verifying if the 'Watchdog' key exists in the PodeContext.Server.
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
    Default is 10 seconds.

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
        [int] $Timeout = 10,

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
        if ($null -ne $watchdog.Process) {
            # Try to stop the process forcefully using its ID
            $stoppedProcess = Get-Process -Id $watchdog.Process.Id -ErrorAction SilentlyContinue
            if ($null -ne $stoppedProcess) {
                $watchdog.Status = 'Stopping'
                $stoppedProcess = Stop-Process -Id $watchdog.Process.Id -PassThru -ErrorAction SilentlyContinue
                if ($null -eq $stoppedProcess) {
                    return $false  # Return false if the process could not be stopped
                }
            }
            # Clear the process information and update the status to 'Stopped'
            $watchdog.Process = $null
            $watchdog.Status = 'Stopped'
            return $true
        }
        else {
            Write-PodeHost 'No watchdog process found'  # Log if no process is found for the Watchdog
        }

        return $true
    }

    try {
        # Attempt graceful shutdown via pipe communication
        if ($watchdog.PipeServer.IsConnected) {
            # Send 'shutdown' signal to the process via the PipeWriter
            $watchdog.PipeWriter.WriteLine('shutdown')
            $watchdog.PipeWriter.Flush()  # Ensure the message is sent immediately

            $watchdog.Status = 'Stopping'
        }
        else {
            throw 'Pipe connection lost. Waiting for client to reconnect ...'
        }

        # Wait for the process to exit within the specified timeout
        $i = 0
        $process = Get-Process -Id $watchdog.Process.Id -ErrorAction SilentlyContinue
        while ($null -ne $process) {
            Start-Sleep -Seconds 2
            $process = Get-Process -Id $watchdog.Process.Id -ErrorAction SilentlyContinue
            $i++
            if ($i -gt $Timeout) {
                Write-PodeHost 'Stop-PodeWatchdogMonitoredProcess timeout reached'  # Log timeout
                return $false
            }
        }

        # Clear process information and update status upon successful shutdown
        $watchdog.Process = $null
        $watchdog.Status = 'Stopped'
        return $true
    }
    catch {
        # Log any errors that occur during the shutdown process
        $_ | Write-PodeErrorLog
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
        $Name
    )

    # If the Watchdog with the specified name is not found, exit the function
    if (!(Test-PodeWatchdog -Name $Name)) {
        return
    }

    # Retrieve the Watchdog instance from the Pode context
    $watchdog = $PodeContext.Server.Watchdog.Server[$Name]

    try {
        # Attempt to restart the monitored process via pipe communication
        if ($watchdog.PipeServer.IsConnected) {
            $restartCount = $watchdog['ProcessInfo'].RestartCount
            $watchdog['ProcessInfo'] = $null  # Clear process info to detect restart

            # Send 'restart' command to the monitored process via the PipeWriter
            $watchdog.PipeWriter.WriteLine('restart')
            $watchdog.PipeWriter.Flush()  # Ensure the message is sent immediately

            $watchdog.Status = 'Restarting'
        }
        else {
            throw 'Pipe connection lost. Waiting for client to reconnect ...'
        }

        # Wait for the monitored process to update its process info after restarting
        Start-Sleep 5
        while ($null -eq $watchdog['ProcessInfo']) {
            Start-Sleep 1
        }

        # Verify that the restart count has incremented, indicating a successful restart
        return ($watchdog['ProcessInfo'].RestartCount -eq $restartCount + 1)
    }
    catch {
        # Log any errors that occur during the restart process
        $_ | Write-PodeErrorLog
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

    # Check if the monitored process is not already running
    if ($null -eq $watchdog.Process) {
        $watchdog.Status = 'Starting'

        # Start the monitored process using the shell and arguments from the Watchdog context
        $watchdog.Process = Start-Process -FilePath $watchdog.Shell -ArgumentList $watchdog.Arguments -NoNewWindow -PassThru

        # Increment the restart count
        $watchdog.RestartCount += 1

        # Output the process information for debugging purposes
        write-podehost $watchdog.Process -explode

        # Check if the process was successfully started and is running
        if (!$watchdog.Process.HasExited) {
            $watchdog.Status = 'Running'
            return $true
        }
        else {
            # If the process has already exited, mark the status as 'Stopped'
            $watchdog.Status = 'Stopped'
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
    foreach ($watchdog in $PodeContext.Server.Watchdog.Server.Values) {
        # Start the monitored process for the Watchdog
        Start-PodeWatchdogMonitoredProcess -Name $watchdog.Name

        # Initialize a runspace for the Watchdog using the provided ScriptBlock
        $watchdog.Runspace = Add-PodeRunspace -Type 'Watchdog' `
            -ScriptBlock ($watchdog.ScriptBlock) `
            -Parameters @{'WatchdogName' = $watchdog.Name } `
            -PassThru
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
    foreach ($watchdog in $PodeContext.Server.Watchdog.Server.Values) {
        # Disable the Watchdog service
        $watchdog.Enabled = $false

        # Attempt to stop the monitored process and update the status accordingly
        if ((Stop-PodeWatchdogMonitoredProcess -Name $watchdog.Name -Timeout 10)) {
            $watchdog.Status = 'Stopped'
        }
        else {
            $watchdog.Status = 'Undefined'
        }

        # Clean up the PipeWriter if it exists
        if ($null -ne $watchdog.PipeWriter) {
            try {
                $watchdog.PipeWriter.Dispose()
            }
            catch {
                $_ | Write-PodeErrorLog -Level Verbose  # Log errors during disposal of PipeWriter
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
                $_ | Write-PodeErrorLog -Level Verbose  # Log errors during disconnection of PipeServer
            }

            # Dispose of the PipeServer
            try {
                $watchdog.PipeServer.Dispose()
            }
            catch {
                $_ | Write-PodeErrorLog -Level Verbose  # Log errors during disposal of PipeServer
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
        write-podehost 'Stopping watchdog'

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
            write-podehost 'Starting Client watchdog'
            Start-PodeWatchdogHearthbeat
        }

        # Start the Watchdog server (runspace) if it exists
        if ($PodeContext.Server.Watchdog.containsKey('Server')) {
            write-podehost 'Starting Server watchdog'
            Start-PodeWatchdogRunspace
        }
    }
}

# Client

<#
.SYNOPSIS
    Starts the Pode Watchdog client heartbeat and establishes communication with the server.

.DESCRIPTION
    This internal function initiates the Pode Watchdog client by connecting to the server via a named pipe, starting a timer for sending periodic updates, and handling commands such as shutdown and restart.

.OUTPUTS
    None

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function Start-PodeWatchdogHearthbeat {

    # Define the script block that runs the client receiver and listens for commands from the server
    $scriptBlock = {
        Write-PodeHost 'Start client receiver'
        $watchdog = $PodeContext.Server.Watchdog.Client
        $watchdog['PipeReader'] = [System.IO.StreamReader]::new($watchdog.PipeClient)
        $readTask = $null
        while ($watchdog.Enabled) {
            try {
                if ($null -eq $readTask) {
                    # Asynchronously read data from the server without blocking
                    $readTask = $watchdog.PipeReader.ReadLineAsync()
                }

                if ($readTask.Status -eq [System.Threading.Tasks.TaskStatus]::RanToCompletion -and $readTask.Result) {
                    $serverMessage = $readTask.Result

                    if ($serverMessage) {
                        Write-PodeHost "Received command from server: $serverMessage"

                        # Handle server commands like shutdown and restart
                        switch ($serverMessage) {
                            'shutdown' { # Exit the loop and stop Pode Server
                                Write-PodeHost 'Server requested shutdown. Closing client...'
                                Close-PodeServer
                                break
                            }
                            'restart' { # Exit the loop and restart Pode Server
                                Write-PodeHost 'Server requested restart. Restarting client...'
                                Restart-PodeServer
                                break
                            }
                            default {
                                Write-PodeHost "Unknown command received: $serverMessage"
                            }
                        }
                    }
                }
                elseif ($readTask.Status -eq [System.Threading.Tasks.TaskStatus]::Faulted) {
                    Write-PodeHost "Read operation faulted: $($readTask.Exception.Message)"
                }
                Start-Sleep -Seconds 1
            }
            catch {
                Write-PodeHost "Error reading command from server: $_"
                Start-Sleep -Seconds 1 # Sleep for a second before retrying in case of an error
            }
        }
    }

    try {
        # Initialize the Watchdog client and connect to the server's pipe
        $watchdog = $PodeContext.Server.Watchdog.Client
        $watchdog['PipeClient'] = [System.IO.Pipes.NamedPipeClientStream]::new('.', $watchdog.PipeName, [System.IO.Pipes.PipeDirection]::InOut, [System.IO.Pipes.PipeOptions]::Asynchronous)
        $watchdog.PipeClient.Connect(60000)  # Timeout of 60 seconds to connect
        Write-PodeHost 'Connected to the watchdog pipe server.'

        # Create a persistent StreamWriter for writing messages to the server
        $watchdog['PipeWriter'] = [System.IO.StreamWriter]::new($watchdog.PipeClient)
        $watchdog['PipeWriter'].AutoFlush = $true # Enable auto-flush to send data immediately
        $watchdog['Enabled'] = $true

        # Start the runspace for the client receiver
        $watchdog['Runspace'] = Add-PodeRunspace -Type 'Watchdog' -ScriptBlock ($scriptBlock) -PassThru

        # Add a timer to send periodic updates to the server
        Add-PodeTimer -Name '__pode_watchdog_client__' -Interval $watchdog.Interval -OnStart -ScriptBlock {
            $watchdog = $PodeContext.Server.Watchdog.Client
            $jsonData = [ordered]@{
                Pid           = $PID
                CurrentUptime = (Get-PodeServerUptime)
                TotalUptime   = (Get-PodeServerUptime -Total)
                RestartCount  = (Get-PodeServerRestartCount)
                Metrics       = $PodeContext.Metrics
                Listeners     = $PodeContext.Server.Signals.Listener.Contexts
            } | ConvertTo-Json -Compress -Depth 4

            # Log and send the data to the server
            Write-PodeHost $jsonData

            try {
                # Check if the pipe client is still connected before writing
                if ($watchdog.PipeClient.IsConnected) {
                    # Write the serialized JSON data to the pipe
                    $watchdog.PipeWriter.WriteLine($jsonData)
                }
                else {
                    Write-PodeHost 'Pipe connection lost. Attempting to reconnect...'
                    Write-PodeLog -Name $name -InputObject 'Pipe connection lost. Attempting to reconnect...'
                    $watchdog.PipeClient.Connect(60000)  # Retry connection
                    Write-PodeHost 'Reconnected to the watchdog pipe server.'

                    # Retry sending the JSON data
                    $watchdog.PipeWriter.WriteLine($jsonData)
                }
            }
            catch {
                # Log errors and close the client on failure
                $_ | Write-PodeErrorLog
                Close-PodeServer
            }
        }
    }
    catch [TimeoutException] {
        # Handle timeout exceptions and close the server if connection fails
        $_ | Write-PodeErrorLog
        Close-PodeServer
    }
}

<#
.SYNOPSIS
    Stops the Pode Watchdog client heartbeat and cleans up associated resources.

.DESCRIPTION
    This internal function stops the Pode Watchdog client by removing its timer, disabling it, and cleaning up resources such as the PipeClient, PipeReader, and PipeWriter.

.OUTPUTS
    None

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function Stop-PodeWatchdogHearthbeat {
    # Retrieve the Watchdog client from the Pode context
    $watchdog = $PodeContext.Server.Watchdog.Client

    # Remove the timer associated with the Watchdog client
    Remove-PodeTimer -Name '__pode_watchdog_client__'

    # Disable the Watchdog client
    $watchdog.Enabled = $false

    # Check if the PipeClient exists and clean up its resources
    if ($null -ne $watchdog.PipeClient) {

        # Dispose of the PipeReader if it exists
        if ($null -ne $watchdog.PipeReader) {
            try {
                $watchdog.PipeReader.Dispose()
            }
            catch {
                $_ | Write-PodeErrorLog -Level Verbose  # Log any errors during PipeReader disposal
            }
        }

        # Dispose of the PipeWriter if it exists
        if ($null -ne $watchdog.PipeWriter) {
            try {
                $watchdog.PipeWriter.Dispose()
            }
            catch {
                $_ | Write-PodeErrorLog -Level Verbose  # Log any errors during PipeWriter disposal
            }
        }

        # Disconnect the PipeClient if it is still connected
        if ($watchdog.PipeClient.IsConnected) {
            $watchdog.PipeClient.Disconnect()
        }

        # Dispose of the PipeClient itself
        try {
            $watchdog.PipeClient.Dispose()
        }
        catch {
            $_ | Write-PodeErrorLog -Level Verbose  # Log any errors during PipeClient disposal
        }
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
function Get-WatchdogRunspaceCount {
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