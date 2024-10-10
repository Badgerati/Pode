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
        while ($PodeContext.Server.Watchdog.Enabled) {
            try {
                # Create a StreamReader to read the incoming message
                $reader = [System.IO.StreamReader]::new($pipeServer)
                while ($PodeContext.Server.Watchdog.Enabled) {
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
                $pipeServer.Disconnect()
            }
            catch {
                $_ | Write-PodeErrorLog
                write-podehost "Error  pipe: $_"
            }
            finally {
                # Clean up after client disconnection
                Write-PodeHost 'Cleaning up resources...'
                $reader.Dispose()
                # Disconnect the pipe server to reset it for the next client
                $pipeServer.Disconnect()
            }
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
    $PodeContext.Server.Watchdog['Enabled'] = $true



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
