#State
# RestartRequest
# Restarting
# Restarted
# Starting
# Running
# StoppingRequest
# Stopping
# Stopped
# Undefined

function Enable-PodeWatchdog {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0, ParameterSetName = 'Script')]
        [scriptblock]
        $ScriptBlock,

        [Parameter(Mandatory = $true, ParameterSetName = 'File')]
        [string]
        $FilePath,

        [switch]
        $DisableMonitoring,

        [switch]
        $FileMonitoring,

        [int]
        $Interval = 10
    )

    # Check which parameter set is being used and take appropriate action
    if ($PSCmdlet.ParameterSetName -ieq 'File') {
        $FilePath = Get-PodeRelativePath -Path $FilePath -Resolve -TestPath -JoinRoot -RootPath $MyInvocation.PSScriptRoot

        # if not already supplied, set root path
        if ([string]::IsNullOrWhiteSpace($RootPath)) {
            if ($CurrentPath) {
                $RootPath = $PWD.Path
            }
            else {
                $RootPath = Split-Path -Parent -Path $FilePath
            }
        }

        # Construct the argument string for the file execution
        $arguments = "-NoProfile -Command `"& {
            `$global:PodeWatchdog = `$args[0] | ConvertFrom-Json;
            . `"$FilePath`"
        }`""

    }
    else {
        # ParameterSet: 'Script'
        # Serialize the scriptblock to a string for passing to the new process
        $scriptBlockString = $ScriptBlock.ToString()

        $arguments = "-NoProfile -Command `"& {
            `$PodeWatchdog = `$args[0] | ConvertFrom-Json;
             & { $scriptBlockString }
        }`""


    }

    $scriptBlock = {
        write-podehost 'starting Pipeserver ...'
        $pipeServer = $PodeContext.Server.Watchdog.PipeServer
        try {
            # Create a StreamReader to read the incoming message
            $reader = [System.IO.StreamReader]::new($pipeServer)
            while ($true) {
                #  Write-PodeHost 'Waiting for client connection...'

                # Wait for the client connection
                $pipeServer.WaitForConnection()
                #     Write-PodeHost 'Client connected.'
                try {
                    # Create a StreamReader to read the incoming message from the connected client
                    $reader = [System.IO.StreamReader]::new($pipeServer)

                    while ($pipeServer.IsConnected) {
                        # Read the next message, which contains the serialized hashtable
                        $receivedData = $reader.ReadLine()

                        # Check if data was received
                        if ($receivedData) {
                            Write-PodeHost "Server Received data: $receivedData"

                            # Deserialize the received JSON string back into a hashtable
                            $PodeContext.Server.Watchdog.ProcessInfo = $receivedData | ConvertFrom-Json

                        }
                        else {
                            Write-PodeHost 'No data received from client. Waiting for more data...'
                        }
                    }
                    Write-PodeHost 'Client disconnected. Waiting for a new connection...'
                }
                catch {
                    $_ | Write-PodeErrorLog
                    write-podehost "Error reading from pipe: $_"
                    $pipeServer.Disconnect()
                    Start-Sleep -Seconds 1
                }
            }
        }
        finally {
            # Clean up after client disconnection
            Write-PodeHost 'Cleaning up resources...'
            $reader.Dispose()
            # Disconnect the pipe server to reset it for the next client

        }

    }

    $pipename = "$($PID)_Watchdog"
    $PodeContext.Server.Watchdog = [System.Collections.Concurrent.ConcurrentDictionary[string, PSObject]]::new()
    $PodeContext.Server.Watchdog['Shell'] = $(if ($PSVersionTable.PSVersion -gt [version]'6.0') { 'pwsh' } else { 'powershell' })
    $PodeContext.Server.Watchdog['Arguments'] = $null
    $PodeContext.Server.Watchdog['Process'] = $null
    $PodeContext.Server.Watchdog['Status'] = 'Starting'
    $PodeContext.Server.Watchdog['PipeName'] = $pipename
    $PodeContext.Server.Watchdog['PreSharedKey'] = (New-PodeGuid)
    $PodeContext.Server.Watchdog['PipeServer'] = [System.IO.Pipes.NamedPipeServerStream]::new($pipeName, [System.IO.Pipes.PipeDirection]::InOut, 2, [System.IO.Pipes.PipeTransmissionMode]::Message, [System.IO.Pipes.PipeOptions]::Asynchronous)
    $PodeContext.Server.Watchdog['ScriptBlock'] = $scriptBlock
    $PodeContext.Server.Watchdog['Type'] = 'Server'
    $PodeContext.Server.Watchdog['Runspace'] = $null
    $PodeContext.Server.Watchdog['Interval'] = $Interval
    # Create a persistent StreamWriter for writing messages and store it in the context
    $PodeContext.Server.Watchdog['PipeWriter'] = [System.IO.StreamWriter]::new($PodeContext.Server.Watchdog.PipeServer)
    # $PodeContext.Server.Watchdog['PipeWriter'].AutoFlush = $true  # Enable auto-flush to send data immediately
    $PodeContext.Server.Watchdog['ProcessInfo'] = $null



    $PodeWatchdog = @{
        DisableTermination = $true
        Quiet              = $false
        EnableMonitoring   = !$DisableMonitoring.IsPresent
        PreSharedKey       = $PodeContext.Server.Watchdog.PreSharedKey
        Type               = 'Client'
        PipeName           = $pipename
        Interval           = $Interval
    }

    # Serialize the hashtable to a JSON string
    $jsonConfig = $PodeWatchdog | ConvertTo-Json -Compress

    # Escape double quotes for passing the JSON string as a command-line argument
    $escapedJsonConfig = $jsonConfig.Replace('"', '\"')

    $PodeContext.Server.Watchdog.Arguments = "$arguments  '$escapedJsonConfig'"

    if ($FileMonitoring.IsPresent) {
        if ($PSCmdlet.ParameterSetName -ieq 'File') {
            Add-PodeFileWatcher -Path (get-item $FilePath).DirectoryName -Exclude '*.log' -ScriptBlock {
                "[$($FileEvent.Type)]: $($FileEvent.FullPath)" | Out-Default
                $PodeContext.Server.Watchdog.Status = 'Restarting'
            }
        }
    }
}


function Stop-PodeWatchdog {
    param ()
    if ($PodeContext.Server.containsKey('Watchdog')) {
        write-podehost 'Stopping watchdog'
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
                Open-PodeWatchdogRunPool
                $null = Start-PodeWatchdogProcess
            }
        }
    }
}

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
}





function Start-PodeWatchdogHearthbeat {
    write-podehost  $PodeContext.Server.Watchdog -explode



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




            $scriptBlock = {
                Write-PodeHost 'Start client receiver'
                $PodeContext.Server.Watchdog['PipeReader'] = [System.IO.StreamReader]::new($PodeContext.Server.Watchdog.PipeClient)
                $readTask = $null
                while ($true) {
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
            Open-PodeWatchdogRunPool

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





function Open-PodeWatchdogRunPool {
    if ($null -eq $PodeContext.RunspacePools.Watchdog ) {
        $PodeContext.RunspacePools.Watchdog = @{
            Pool  = [runspacefactory]::CreateRunspacePool(1, 1, $PodeContext.RunspaceState, $Host)
            State = 'Open'
        }
        $PodeContext.RunspacePools.Watchdog.Pool.Open()
    }

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

function Get-PodeWatchdogInfo {
    [CmdletBinding(DefaultParameterSetName = 'HashTable')]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet('Status', 'Requests', 'Listeners', 'Signals')]
        [string] $Type = 'Status'
    )
    if ( $null -ne $PodeContext.Server.Watchdog -and $null -ne $PodeContext.Server.Watchdog['ProcessInfo']) {
        $processInfo = $PodeContext.Server.Watchdog['ProcessInfo']
        switch ($Type) {
            'Status' {
                return  @{
                    Pid           = $processInfo.Pid
                    CurrentUptime = $processInfo.CurrentUptime
                    TotalUptime   = $processInfo.TotalUptime
                    RestartCount  = $processInfo.RestartCount
                }
            }
            'Requests' {
                return   $processInfo.Metrics.Requests

            }
            'Listeners' {
                return   $processInfo.Listeners
            }

            'Signals' {
                return   $processInfo.Metrics.Signals
            }

        }
    }
}


function Set-PodeWatchState {
    param (
        [Parameter(Mandatory = $false)]
        [ValidateSet('Stop', 'Restart', 'Start')]
        [string]
        $State = 'Stop'
    )
    switch ($State) {
        'Stop' { return Stop-PodeWatchdogProcess }
        'Restart' { return Restart-PodeWatchdogProcess }
        'Start' { return Start-PodeWatchdogProcess }
    }
}
