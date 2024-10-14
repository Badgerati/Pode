<#
.SYNOPSIS
    Waits for active web sessions to close before proceeding with shutdown or restart.

.DESCRIPTION
    This function blocks all incoming requests by adding a middleware that responds with a 503 Service Unavailable status, along with a 'Retry-After' header to inform clients when to retry their requests.
    It continuously checks for any active sessions and waits for them to finish. If the sessions do not close within the defined timeout period, the function exits and proceeds with the shutdown or restart process.

.PARAMETER Timeout
    The timeout is handled by `$PodeContext.Server.Watchdog.Client.ServiceUnavailableTimeout`, which defines the maximum time (in seconds) the function will wait for all sessions to close before exiting.

.PARAMETER RetryAfter
    The retry interval is managed by `$PodeContext.Server.Watchdog.Client.ServiceUnavailableRetryAfter`, which defines the value of the 'Retry-After' header (in seconds) that is sent in the 503 response.

.EXAMPLE
    Wait-PodeWatchdogSessionEnd

    Blocks new incoming requests, waits for active sessions to close, and exits when all sessions are closed or when the timeout is reached.

.NOTES
    This function is typically used during shutdown or restart operations in Pode to ensure that all active sessions are completed before the server is stopped or restarted.
#>
function Wait-PodeWatchdogSessionEnd {
    try {
        # Add middleware to block new requests and respond with 503 Service Unavailable
        Enable-PodeWatchdogMonitored

        $previousOpenSessions = 0
        $startTime = [datetime]::Now

        write-PodeHost "Context count= $($PodeContext.Server.Signals.Listener.Contexts.Count)"
        while ($PodeContext.Server.Signals.Listener.Contexts.Count -gt 0) {
            if ($previousOpenSessions -ne $PodeContext.Server.Signals.Listener.Contexts.Count) {
                Write-PodeHost "Waiting for the end of $($PodeContext.Server.Signals.Listener.Contexts.Count) sessions"
                $previousOpenSessions = $PodeContext.Server.Signals.Listener.Contexts.Count
            }
            # Check if timeout is reached
            if (([datetime]::Now - $startTime).TotalSeconds -ge $PodeContext.Server.Watchdog.Client.GracefulShutdownTimeout) {
                Write-PodeHost "Timeout reached after $($PodeContext.Server.Watchdog.Client.GracefulShutdownTimeout) seconds, exiting..."
                break
            }

            Start-Sleep -Milliseconds 200
        }
    }
    catch {
        Write-PodeHost  $_
    }
    finally {
        # Remove middleware to block new requests and respond with 503 Service Unavailable
        Disable-PodeWatchdogMonitored
    }
}

<#
.SYNOPSIS
    Enables new requests by removing the middleware that blocks requests when the Pode Watchdog service is active.

.DESCRIPTION
    This function checks if the middleware associated with the Pode Watchdog client is present, and if so, it removes it to allow new requests.
    This effectively re-enables access to the service by removing the request blocking.

.NOTES
    This function is used internally to manage Watchdog monitoring and may change in future releases of Pode.
#>
function Enable-PodeWatchdogMonitored {
    $watchdog = $PodeContext.Server.Watchdog.Client

    # Check if the Watchdog middleware exists and remove it if found to allow new requests
    if (Test-PodeMiddleware -Name $watchdog.PipeName) {
        Remove-PodeMiddleware -Name $watchdog.PipeName
        $watchdog.Accessible = $true
    }
}

<#
.SYNOPSIS
    Disables new requests by adding middleware that blocks incoming requests when the Pode Watchdog service is active.

.DESCRIPTION
    This function adds middleware to the Pode server to block new incoming requests while the Pode Watchdog client is active.
    It responds to all new requests with a 503 Service Unavailable status and sets a 'Retry-After' header, indicating when the service will be available again.

.NOTES
    This function is used internally to manage Watchdog monitoring and may change in future releases of Pode.
#>
function Disable-PodeWatchdogMonitored {
    $watchdog = $PodeContext.Server.Watchdog.Client

    if (!(Test-PodeMiddleware -Name  $watchdog.PipeName)) {
        # Add middleware to block new requests and respond with 503 Service Unavailable
        Add-PodeMiddleware -Name  $watchdog.PipeName -ScriptBlock {
            # Set HTTP response header for retrying after a certain time (RFC7231)
            Set-PodeHeader -Name 'Retry-After' -Value $PodeContext.Server.Watchdog.Client.ServiceRecoveryTime

            # Set HTTP status to 503 Service Unavailable
            Set-PodeResponseStatus -Code 503

            # Stop further processing
            return $false
        }
        $watchdog.Accessible = $false
    }
}

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

                # Check if the read task has completed
                if ($readTask.Status -eq [System.Threading.Tasks.TaskStatus]::RanToCompletion -and $readTask.Result) {
                    $serverMessage = $readTask.Result

                    if ($serverMessage) {
                        Write-PodeHost "Received command from server: $serverMessage"

                        # Handle server commands like shutdown and restart
                        switch ($serverMessage) {
                            'shutdown' {
                                # Exit the loop and stop Pode Server
                                Write-PodeHost 'Server requested shutdown. Closing client...'
                                Set-PodeWatchdogHearthbeatStatus -Status 'Stopping' -Force
                                Wait-PodeWatchdogSessionEnd
                                Close-PodeServer
                                break
                            }
                            'restart' {
                                # Exit the loop and restart Pode Server
                                Write-PodeHost 'Server requested restart. Restarting client...'
                                Set-PodeWatchdogHearthbeatStatus -Status 'Restarting' -Force
                                Wait-PodeWatchdogSessionEnd
                                Restart-PodeServer
                                break
                            }
                            'disable' {
                                Write-PodeHost 'Server requested service to be refuse any new access.'
                                Disable-PodeWatchdogMonitored
                                break
                            }
                            'enable' {
                                Write-PodeHost 'Server requested service to be enable new access.'
                                Enable-PodeWatchdogMonitored
                                break
                            }

                            default {
                                Write-PodeHost "Unknown command received: $serverMessage"
                            }
                        }
                    }
                    # Reset the readTask after processing a message
                    $readTask = $null
                }
                elseif ($readTask.Status -eq [System.Threading.Tasks.TaskStatus]::Faulted) {
                    Write-PodeHost "Read operation faulted: $($readTask.Exception.Message)"
                    $readTask = $null  # Reset in case of fault
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
        $watchdog['Accessible'] = $true

        # Start the runspace for the client receiver
        $watchdog['Runspace'] = Add-PodeRunspace -Type 'Watchdog' -ScriptBlock ($scriptBlock) -PassThru

        # Add a timer to send periodic updates to the server
        Add-PodeTimer -Name '__pode_watchdog_client__' -Interval $watchdog.Interval -OnStart -ScriptBlock {
            Send-PodeWatchdogData
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
    Sends the current status and metrics of the Pode Watchdog client to the server.

.DESCRIPTION
    This function collects various metrics and status data from the Pode Watchdog client, such as uptime, restart count, and active listeners.
    It serializes the data into JSON format and sends it to the server using a pipe. If the pipe connection is lost, the function attempts to reconnect and retry sending the data.

.OUTPUTS
    Sends serialized JSON data containing the current Watchdog status, uptime, restart count, metrics, and listeners.

.NOTES
    This function logs the data being sent and handles reconnection attempts if the pipe connection is lost.

.EXAMPLE
    Send-PodeWatchdogData

    Sends the current Watchdog status and metrics to the server and handles any connection issues.
#>
function Send-PodeWatchdogData {
    $watchdog = $PodeContext.Server.Watchdog.Client

    # Collect and serialize Watchdog data to JSON format
    $jsonData = [ordered]@{
        Status        = $watchdog.Status
        Accessible    = $watchdog.Accessible
        Pid           = $PID
        CurrentUptime = (Get-PodeServerUptime)
        TotalUptime   = (Get-PodeServerUptime -Total)
        RestartCount  = (Get-PodeServerRestartCount)
        Metrics       = $PodeContext.Metrics
        Listeners     = $PodeContext.Server.Signals.Listener.Contexts
    } | ConvertTo-Json -Compress -Depth 4

    # Log and send the data to the server
    Write-PodeHost "Sending watchdog data: $jsonData"

    try {
        # Check if the pipe client is still connected before writing
        if ($watchdog.PipeClient.IsConnected) {
            # Write the serialized JSON data to the pipe
            $watchdog.PipeWriter.WriteLine($jsonData)
        }
        else {
            Write-PodeHost 'Pipe connection lost. Attempting to reconnect...'
            Write-PodeLog -Name $name -InputObject 'Pipe connection lost. Attempting to reconnect...'

            # Attempt to reconnect to the pipe client
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

    if ($PodeContext.Server.Watchdog.Client.Status -ne 'Restarting') {
        # Watchdog client has stopped, updating status to 'Stopped'
        Set-PodeWatchdogHearthbeatStatus -Status 'Stopped'
    }

    # Remove the timer associated with the Watchdog client
    Remove-PodeTimer -Name '__pode_watchdog_client__'



    # Send the last heartbeat to the watchdog server
    Send-PodeWatchdogData

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
    Sets the status of the Pode Watchdog heartbeat for the client component.

.DESCRIPTION
    This function updates the status of the Pode Watchdog client heartbeat. It allows you to specify the current state of the Watchdog, such as 'Starting', 'Restarting', 'Running', 'Stopped', etc.

.PARAMETER Status
    Specifies the new status for the Pode Watchdog client heartbeat. Must be one of the following values:
    - 'Starting'
    - 'Restarting'
    - 'Running'
    - 'Undefined'
    - 'Stopping'
    - 'Stopped'
    - 'Offline'

.PARAMETER Force
    Specifies whether to force to send the update of the Pode Watchdog client's heartbeat status to the server.

.EXAMPLE
    Set-PodeWatchdogHearthbeatStatus -Status 'Running'

    This command sets the Watchdog client's heartbeat status to 'Running'.

.NOTES
    This function checks if the Pode Watchdog client is enabled before updating the status.
    This is an internal function and may change in future releases of Pode.
#>
function Set-PodeWatchdogHearthbeatStatus {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Starting', 'Restarting', 'Running', 'Undefined', 'Stopping', 'Stopped', 'Offline')]
        [String]
        $Status,

        [switch]
        $Force
    )

    # Check if the Watchdog Client is enabled before updating the status
    if ((Test-PodeWatchDogEnabled -Client)) {
        $PodeContext.Server.Watchdog.Client.Status = $Status
        if ($Force.IsPresent) {
            Send-PodeWatchdogData
        }
    }
}

