



function Test-PodeWatchDogEnabled {
    return $PodeContext.Server.containsKey('Watchdog')
}

function Start-PodeWatchdogHousekeeper {
    Add-PodeTimer -Name '__pode_watchdog_housekeeper__' -Interval 10 -ScriptBlock {
        try {

            $process = Get-Process -Id $PodeContext.Server.Watchdog.Process.Id -ErrorAction SilentlyContinue
            if ($process) {
                if ($PodeContext.Server.Watchdog.Status -eq 'RestartRequest') {
                    $PodeContext.Server.Watchdog.Status = 'Restarting'
                    write-podehost 'start Restarting '

                    Restart-PodeWatchdogProcess

                }
            }
            else {
                $PodeContext.Server.Watchdog.Status = 'Stopped'
                write-podehost 'Process is not running'
                write-podehost 'Restarting....'
                Start-PodeWatchdogProcess
            }
        }
        catch {
            $_ | Write-PodeErrorLog
        }
    }
}


function Wait-PodeWatchdogProcessStateChange {
    param ([Parameter(Mandatory = $false)]
        [ValidateSet('Offline', 'Online')]
        $NewState = 'Offline',
        [int]
        $Timeout = 10
    )


    $process = Get-Process -Id $PodeContext.Server.Watchdog.Process.Id -ErrorAction SilentlyContinue

    $i = 0
    while ((($NewState -eq 'Online') -and ($null -eq $process)) -or
        (($NewState -eq 'Offline') -and ($null -ne $process))
    ) {
        Start-Sleep -Seconds 2
        $process = Get-Process -Id $PodeContext.Server.Watchdog.Process.Id -ErrorAction SilentlyContinue
        $i++
        if ($i -gt $Timeout) {
            return $false
        }
    }

}


function Stop-PodeWatchdogProcess {
    try {
        # Check if the pipe client is still connected before writing
        if ($PodeContext.Server.Watchdog.PipeServer.IsConnected) {
            # Write the serialized JSON data to the pipe using the persistent StreamWriter
            $PodeContext.Server.Watchdog.PipeWriter.WriteLine('shutdown')

            # Manually flush the StreamWriter to ensure the data is sent immediately
            $PodeContext.Server.Watchdog.PipeWriter.Flush()

            $PodeContext.Server.Watchdog.Status = 'Stopping'
        }
        else {
            throw 'Pipe connection lost. Waiting for client to reconnect ...'
        }
        return (Wait-PodeWatchdogProcessStateChange -NewState 'Offline')

    }
    catch {
        # Handle any exceptions during the write operation
        $_ | Write-PodeErrorLog
        return $false
    }
}

function Restart-PodeWatchdogProcess {
    try {
        # Check if the pipe client is still connected before writing
        if ($PodeContext.Server.Watchdog.PipeServer.IsConnected) {

            # Write the serialized JSON data to the pipe using the persistent StreamWriter
            $PodeContext.Server.Watchdog.PipeWriter.WriteLine('restart')

            # Manually flush the StreamWriter to ensure the data is sent immediately
            $PodeContext.Server.Watchdog.PipeWriter.Flush()

            $PodeContext.Server.Watchdog.Status = 'Restarting'
        }
        else {
            throw 'Pipe connection lost. Waiting for client to reconnect ...'

        }

        if (Wait-PodeWatchdogProcessStateChange -NewState 'Offline') {
            return (Wait-PodeWatchdogProcessStateChange -NewState 'Online')
        }
        return $false
    }
    catch {
        # Handle any exceptions during the write operation
        $_ | Write-PodeErrorLog

    }
}


function Start-PodeWatchdogProcess {
    $watchdog = $PodeContext.Server.Watchdog
    if ($null -eq $PodeContext.Server.Watchdog.Process ) {
        $watchdog.Status = 'Starting'
        $watchdog.Process = Start-Process -FilePath  $watchdog.Shell -ArgumentList $watchdog.Arguments -NoNewWindow -PassThru

        $watchdog.Runspace = Add-PodeRunspace -Type 'Watchdog' -ScriptBlock ( $watchdog.ScriptBlock) -PassThru

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




function Stop-PodeWatchdog {
    param ()
    if ($PodeContext.Server.containsKey('Watchdog')) {
        write-podehost 'Stopping watchdog'
        $PodeContext.Server.Watchdog.Enabled = $false
        switch ($PodeContext.Server.Watchdog.Type) {
            'Client' {
                if ($null -ne $PodeContext.Server.Watchdog.PipeWriter) {
                    try {
                        $PodeContext.Server.Watchdog.PipeWriter.Dispose()
                    }
                    catch {
                        $_ | Write-PodeErrorLog -Level Verbose
                    }
                }
                if ($null -ne $PodeContext.Server.Watchdog.PipeClient) {
                    try {
                        $PodeContext.Server.Watchdog.PipeClient.Dispose()
                    }
                    catch {
                        $_ | Write-PodeErrorLog -Level Verbose
                    }
                }
            }
            'Server' {
                $PodeContext.Server.Watchdog.Status = 'StoppingRequest'
                if (Stop-PodeWatchdogProcess) {
                    $PodeContext.Server.Watchdog.Status = 'Stopped'
                }
                else {
                    $PodeContext.Server.Watchdog.Status = 'Undefined'
                }
                if ($null -ne $PodeContext.Server.Watchdog.PipeWriter) {
                    try {
                        $PodeContext.Server.Watchdog.PipeWriter.Dispose()
                    }
                    catch {
                        $_ | Write-PodeErrorLog -Level Verbose
                    }
                }
                if ($null -ne $PodeContext.Server.Watchdog.PipeServer) {
                    try {
                        if ($PodeContext.Server.Watchdog.PipeServer.IsConnected()) {
                            $PodeContext.Server.Watchdog.PipeServer.Disconnect()
                        }
                    }
                    catch {
                        $_ | Write-PodeErrorLog -Level Verbose
                    }
                    try {
                        $PodeContext.Server.Watchdog.PipeServer.Dispose()
                    }
                    catch {
                        $_ | Write-PodeErrorLog -Level Verbose
                    }

                }
            }
        }
    }
}

function Start-PodeWatchdog {
    param ()
    if ($PodeContext.Server.containsKey('Watchdog')) {
        switch ($PodeContext.Server.Watchdog.Type) {
            'Client' {
                write-podehost 'Starting Client watchdog'
                Start-PodeWatchdogHearthbeat
            }
            'Server' {
                write-podehost 'Starting Server watchdog'
                $null = Start-PodeWatchdogProcess
            }
        }
    }
}
<#
function Stop-PodeWatchdog {
    param ()
    if ($PodeContext.Server.containsKey('Watchdog')) {
        switch ($PodeContext.Server.Watchdog.Type) {
            'Client' {
                write-podehost 'Stopping Client watchdog'
                Stop-PodeWatchdogHearthbeat

            }
            'Server' {
                write-podehost 'Stopping Server watchdog'

                $null = Stop-PodeWatchdogProcess
            }
        }
    }
}#>




#Client

function Stop-PodeWatchdogHearthbeat {
    param ( )
    Remove-PodeTimer -Name '__pode_watchdog_client__'
    if ($PodeContext.Server.Watchdog.PipeClient.IsConnected) {
        $PodeContext.Server.Watchdog.PipeClient.Disconnect()
    }

    $PodeContext.Server.Watchdog.PipeReader.Dispose()
    $PodeContext.Server.Watchdog.PipeWriter.Dispose()


}
function Start-PodeWatchdogHearthbeat {

    if ($PodeContext.Server.containsKey('Watchdog') -and $PodeContext.Server.Watchdog.Type -eq 'Client') {
        # Create a named pipe client and connect to the server
        try {
            $PodeContext.Server.Watchdog['PipeClient'] = [System.IO.Pipes.NamedPipeClientStream]::new('.',
                $PodeContext.Server.Watchdog.PipeName, [System.IO.Pipes.PipeDirection]::InOut, [System.IO.Pipes.PipeOptions]::Asynchronous)
            # Attempt to connect to the server with a timeout
            $PodeContext.Server.Watchdog.PipeClient.Connect(60000)  # Timeout in milliseconds (60 seconds)
            Write-PodeHost 'Connected to the watchdog pipe server.'

            # Create a persistent StreamWriter for writing messages and store it in the context
            $PodeContext.Server.Watchdog['PipeWriter'] = [System.IO.StreamWriter]::new($PodeContext.Server.Watchdog.PipeClient)
            $PodeContext.Server.Watchdog['PipeWriter'].AutoFlush = $true  # Enable auto-flush to send data immediately
            $PodeContext.Server.Watchdog['Enabled'] = $true



            $scriptBlock = {
                Write-PodeHost 'Start client receiver'
                $PodeContext.Server.Watchdog['PipeReader'] = [System.IO.StreamReader]::new($PodeContext.Server.Watchdog.PipeClient)
                $readTask = $null
                while ($PodeContext.Server.Watchdog.Enabled) {
                    try {
                        if ($null -eq $readTask) {
                            # Use ReadLineAsync() to asynchronously read data from the server without blocking
                            $readTask = $PodeContext.Server.Watchdog.PipeReader.ReadLineAsync()
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

            $PodeContext.Server.Watchdog['Runspace'] = Add-PodeRunspace -Type 'Watchdog' -ScriptBlock ( $scriptBlock) -PassThru

            Add-PodeTimer -Name '__pode_watchdog_client__' -Interval $PodeContext.Server.Watchdog.Interval -OnStart -ScriptBlock {

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
                    if ($PodeContext.Server.Watchdog.PipeClient.IsConnected) {
                        # Write the serialized JSON data to the pipe using the persistent StreamWriter
                        $PodeContext.Server.Watchdog.PipeWriter.WriteLine($jsonData)
                    }
                    else {
                        Write-PodeHost 'Pipe connection lost. Attempting to reconnect...'
                        Write-PodeLog -Name $name -InputObject 'Pipe connection lost. Attempting to reconnect...'
                        # Attempt to reconnect
                        $PodeContext.Server.Watchdog.PipeClient.Connect(60000)  # Timeout in milliseconds
                        Write-PodeHost 'Reconnected to the watchdog pipe server.'

                        # Retry writing the JSON data after reconnecting
                        $PodeContext.Server.Watchdog.PipeWriter.WriteLine($jsonData)
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
}
