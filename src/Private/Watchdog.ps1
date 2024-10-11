



function Test-PodeWatchDogEnabled {
    return $PodeContext.Server.containsKey('Watchdog')
}

function Stop-PodeWatchdogMonitoredProcess {
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [int] $Timeout = 10,

        [switch]
        $Force
    )

    if (!(Test-PodeWatchdog -Name $Name)) {
        return
    }

    $watchdog = $PodeContext.Server.Watchdog.Server[$Name]

    if ($force.IsPresent) {
        if ($null -ne $watchdog.Process) {
            $stoppedProcess = Get-Process -Id $watchdog.Process.Id  -ErrorAction SilentlyContinue
            if ($null -ne $stoppedProcess) {
                $watchdog.Status = 'Stopping'
                $stoppedProcess = Stop-Process -Id $watchdog.Process.Id -PassThru  -ErrorAction SilentlyContinue
                if ($null -eq $stoppedProcess) {
                    return $false
                }
            }
            $watchdog.Process = $null
            $watchdog.Status = 'Stopped'
            return $true
        }
        else {
            Write-PodeHost  'No watchdog process found'
        }

        return $true
    }
    try {
        # Check if the pipe client is still connected before writing
        if ($watchdog.PipeServer.IsConnected) {
            # Write the serialized JSON data to the pipe using the persistent StreamWriter
            $watchdog.PipeWriter.WriteLine('shutdown')

            # Manually flush the StreamWriter to ensure the data is sent immediately
            $watchdog.PipeWriter.Flush()

            $watchdog.Status = 'Stopping'
        }
        else {
            throw 'Pipe connection lost. Waiting for client to reconnect ...'
        }

        $i = 0
        $process = Get-Process -Id $watchdog.Process.Id -ErrorAction SilentlyContinue
        while ($null -ne $process) {
            Start-Sleep -Seconds 2
            $process = Get-Process -Id $watchdog.Process.Id -ErrorAction SilentlyContinue
            $i++
            if ($i -gt $Timeout) {
                Write-PodeHost  'Stop-PodeWatchdogMonitoredProcess timeout reached'
                return $false
            }
        }
        $watchdog.Process = $null
        $watchdog.Status = 'Stopped'
        return $true

    }
    catch {
        # Handle any exceptions during the write operation
        $_ | Write-PodeErrorLog
        return $false
    }
}

function Restart-PodeWatchdogMonitoredProcess {
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    if (!(Test-PodeWatchdog -Name $Name)) {
        return
    }

    $watchdog = $PodeContext.Server.Watchdog.Server[$Name]

    try {
        # Check if the pipe client is still connected before writing
        if ($watchdog.PipeServer.IsConnected) {
            $restartCount = $watchdog['ProcessInfo'].RestartCount
            $watchdog['ProcessInfo'] = $null
            # Write the serialized JSON data to the pipe using the persistent StreamWriter
            $watchdog.PipeWriter.WriteLine('restart')

            # Manually flush the StreamWriter to ensure the data is sent immediately
            $watchdog.PipeWriter.Flush()

            $watchdog.Status = 'Restarting'
        }
        else {
            throw 'Pipe connection lost. Waiting for client to reconnect ...'

        }
        Start-Sleep 5
        while ($null -eq $watchdog['ProcessInfo'] ) {
            Start-Sleep 1
        }
        return ($watchdog['ProcessInfo'].RestartCount -eq $restartCount + 1)
    }
    catch {
        # Handle any exceptions during the write operation
        $_ | Write-PodeErrorLog
        return $false
    }
}


function Start-PodeWatchdogMonitoredProcess {
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    if (!(Test-PodeWatchdog -Name $Name)) {
        return
    }

    $watchdog = $PodeContext.Server.Watchdog.Server[$Name]

    if ($null -eq $watchdog.Process ) {
        $watchdog.Status = 'Starting'
        $watchdog.Process = Start-Process -FilePath  $watchdog.Shell -ArgumentList $watchdog.Arguments -NoNewWindow -PassThru

        $watchdog.RestartCount += 1

        write-podehost $watchdog.Process -explode
        if (!$watchdog.Process.HasExited) {
            $watchdog.Status = 'Running'
            return $true
        }
        else {
            $watchdog.Status = 'Stopped'
        }
    }
    return $false
}

function Start-PodeWatchdogRunspace {
    foreach ($watchdog in $PodeContext.Server.Watchdog.Server.Values) {
        Start-PodeWatchdogMonitoredProcess -Name $watchdog.Name
        $watchdog.Runspace = Add-PodeRunspace -Type 'Watchdog' -ScriptBlock ( $watchdog.ScriptBlock) -Parameters @{'WatchdogName' = $watchdog.Name } -PassThru
    }
}

function Stop-PodeWatchdogRunspace {
    foreach ($watchdog in $PodeContext.Server.Watchdog.Server.Values ) {
        $watchdog.Enabled = $false
        if ((Stop-PodeWatchdogMonitoredProcess -Name $watchdog.Name -Timeout 10)) {
            $watchdog.Status = 'Stopped'
        }
        else {
            $watchdog.Status = 'Undefined'
        }
        if ($null -ne $watchdog.PipeWriter) {
            try {
                $watchdog.PipeWriter.Dispose()
            }
            catch {
                $_ | Write-PodeErrorLog -Level Verbose
            }
        }
        if ($null -ne $watchdog.PipeServer) {
            try {
                if ($watchdog.PipeServer.IsConnected()) {
                    $watchdog.PipeServer.Disconnect()
                }
            }
            catch {
                $_ | Write-PodeErrorLog -Level Verbose
            }
            try {
                $watchdog.PipeServer.Dispose()
            }
            catch {
                $_ | Write-PodeErrorLog -Level Verbose
            }

        }
    }
}


function Stop-PodeWatchdog {
    param ()
    if ($PodeContext.Server.containsKey('Watchdog')) {
        write-podehost 'Stopping watchdog'

        if ($PodeContext.Server.Watchdog.containsKey('Client')) {
            Stop-PodeWatchdogHearthbeat
        }
        if ($PodeContext.Server.Watchdog.containsKey('Server')) {
            Stop-PodeWatchdogRunspace
        }
    }
}

function Start-PodeWatchdog {
    param ()
    if ($PodeContext.Server.containsKey('Watchdog')) {
        if ($PodeContext.Server.Watchdog.containsKey('Client')) {
            write-podehost 'Starting Client watchdog'
            Start-PodeWatchdogHearthbeat
        }

        if ($PodeContext.Server.Watchdog.containsKey('Server')) {
            write-podehost 'Starting Server watchdog'
            Start-PodeWatchdogRunspace
        }
    }
}

#Client


function Start-PodeWatchdogHearthbeat {


    $scriptBlock = {
        Write-PodeHost 'Start client receiver'
        $watchdog = $PodeContext.Server.Watchdog.Client
        $watchdog['PipeReader'] = [System.IO.StreamReader]::new($watchdog.PipeClient)
        $readTask = $null
        while ($watchdog.Enabled) {
            try {
                if ($null -eq $readTask) {
                    # Use ReadLineAsync() to asynchronously read data from the server without blocking
                    $readTask = $watchdog.PipeReader.ReadLineAsync()
                }

                # Wait for the read task to complete with a timeout to avoid indefinite blocking
                #   $timeout = [System.Threading.Tasks.Task]::Delay(10000)  # 10 seconds timeout
                #     [System.Threading.Tasks.Task]::WhenAny($readTask, $timeout) | Out-Null

                if ($readTask.Status -eq [System.Threading.Tasks.TaskStatus]::RanToCompletion -and $readTask.Result) {
                    $serverMessage = $readTask.Result

                    if ($serverMessage) {
                        Write-PodeHost "Received command from server: $serverMessage"

                        # Handle server commands
                        switch ($serverMessage) {
                            'shutdown' {
                                Write-PodeHost 'Server requested shutdown. Closing client...'
                                Close-PodeServer
                                break  # Exit the loop and stop the client
                            }
                            'restart' {
                                Write-PodeHost 'Server requested restart. Restarting client...'
                                Restart-PodeServer  # Restart the watchdog
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
                else {

                    #  Write-PodeHost 'Read operation timed out or was not completed successfully.'
                }
                Start-Sleep -Seconds 1
            }
            catch {
                Write-PodeHost "Error reading command from server: $_"
                Start-Sleep -Seconds 1  # Sleep for a second before retrying in case of an error
            }
        }
    }

    try {
        $watchdog = $PodeContext.Server.Watchdog.Client
        $watchdog['PipeClient'] = [System.IO.Pipes.NamedPipeClientStream]::new('.',
            $watchdog.PipeName, [System.IO.Pipes.PipeDirection]::InOut, [System.IO.Pipes.PipeOptions]::Asynchronous)
        # Attempt to connect to the server with a timeout
        $watchdog.PipeClient.Connect(60000)  # Timeout in milliseconds (60 seconds)
        Write-PodeHost 'Connected to the watchdog pipe server.'

        # Create a persistent StreamWriter for writing messages and store it in the context
        $watchdog['PipeWriter'] = [System.IO.StreamWriter]::new($watchdog.PipeClient)
        $watchdog['PipeWriter'].AutoFlush = $true  # Enable auto-flush to send data immediately
        $watchdog['Enabled'] = $true
        $watchdog['Runspace'] = Add-PodeRunspace -Type 'Watchdog' -ScriptBlock ( $scriptBlock) -PassThru

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
            $name = Get-PodeErrorLoggingName

            Write-PodeLog -Name $name -InputObject $jsonData

            Write-PodeHost $jsonData
            try {
                # Check if the pipe client is still connected before writing
                if ($watchdog.PipeClient.IsConnected) {
                    # Write the serialized JSON data to the pipe using the persistent StreamWriter
                    $watchdog.PipeWriter.WriteLine($jsonData)
                }
                else {
                    Write-PodeHost 'Pipe connection lost. Attempting to reconnect...'
                    Write-PodeLog -Name $name -InputObject 'Pipe connection lost. Attempting to reconnect...'
                    # Attempt to reconnect
                    $watchdog.PipeClient.Connect(60000)  # Timeout in milliseconds
                    Write-PodeHost 'Reconnected to the watchdog pipe server.'

                    # Retry writing the JSON data after reconnecting
                    $watchdog.PipeWriter.WriteLine($jsonData)
                }
            }
            catch {
                # Handle any exceptions during the write operation
                $_ | Write-PodeErrorLog
                Close-PodeServer
            }


        }
    }
    catch [TimeoutException] {
        $_ | Write-PodeErrorLog
        Close-PodeServer
    }

}



function Stop-PodeWatchdogHearthbeat {
    $watchdog = $PodeContext.Server.Watchdog.Client

    Remove-PodeTimer -Name '__pode_watchdog_client__'

    $watchdog.Enabled = $false
    if ($null -ne $watchdog.PipeClient) {
        if ($null -ne $watchdog.PipeReader) {
            try {
                $watchdog.PipeReader.Dispose()
            }
            catch {
                $_ | Write-PodeErrorLog -Level Verbose
            }
        }
        if ($null -ne $watchdog.PipeWriter) {
            try {
                $watchdog.PipeWriter.Dispose()
            }
            catch {
                $_ | Write-PodeErrorLog -Level Verbose
            }
        }
        if ($watchdog.PipeClient.IsConnected) {
            $watchdog.PipeClient.Disconnect()
        }
        try {
            $watchdog.PipeClient.Dispose()
        }
        catch {
            $_ | Write-PodeErrorLog -Level Verbose
        }
    }
}

function Get-WatchdogRunspaceCount {
    $totalWatchdogRunspaces = 0
    if ($PodeContext.Server.Watchdog.containsKey('Client')) {
        $totalWatchdogRunspaces += 1
    }
    if ($PodeContext.Server.Watchdog.containsKey('Server')) {
        $totalWatchdogRunspaces += $PodeContext.Server.Watchdog.Server.Count
    }
    return $totalWatchdogRunspaces
}