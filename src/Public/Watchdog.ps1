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
        Write-PodeHost 'Starting PipeServer...'

        # Start the main loop for the server
        while ($PodeContext.Server.Watchdog.Enabled) {
            try {
                # Check if PipeServer is null and create a new instance if needed
                if ($null -eq $PodeContext.Server.Watchdog['PipeServer']) {
                    $pipeName = $PodeContext.Server.Watchdog.PipeName
                    $PodeContext.Server.Watchdog['PipeServer'] = [System.IO.Pipes.NamedPipeServerStream]::new(
                        $pipeName,
                        [System.IO.Pipes.PipeDirection]::InOut,
                        2,
                        [System.IO.Pipes.PipeTransmissionMode]::Message,
                        [System.IO.Pipes.PipeOptions]::None
                    )
                    Write-PodeHost 'New PipeServer instance created and stored in Watchdog context.'

                    # Create a new StreamWriter and store it back in the Watchdog context
                    $PodeContext.Server.Watchdog['PipeWriter'] = [System.IO.StreamWriter]::new($PodeContext.Server.Watchdog['PipeServer'])
                  #  $PodeContext.Server.Watchdog['PipeWriter'].AutoFlush = $true  # Enable auto-flush for immediate writes
                    Write-PodeHost 'New PipeWriter instance created and stored in Watchdog context.'
                }

                $pipeServer = $PodeContext.Server.Watchdog['PipeServer']
                Write-PodeHost 'PipeServer created and waiting for connection...'
                $pipeServer.WaitForConnection()
                Write-PodeHost 'Client connected.'

                # Create a StreamReader to read messages from the client
                $reader = [System.IO.StreamReader]::new($pipeServer)

                while ($pipeServer.IsConnected) {
                    try {
                        # Read the next message, which contains the serialized hashtable
                        $receivedData = $reader.ReadLine()

                        # Check if data was received
                        if ($null -ne $receivedData) {
                            Write-PodeHost "Server Received data: $receivedData"
                            # Deserialize the received JSON string back into a hashtable
                            $PodeContext.Server.Watchdog.ProcessInfo = $receivedData | ConvertFrom-Json
                        }
                        else {
                            Write-PodeHost 'No data received from client. Waiting for more data...'
                        }
                    }
                    catch {
                        Write-PodeHost "Error reading from client: $_"
                        $pipeServer.Disconnect()  # Disconnect the server to allow reconnection
                        Start-Sleep -Seconds 1
                    }
                }

                # Client disconnected, clean up
                Write-PodeHost 'Client disconnected. Waiting for a new connection...'
                $pipeServer.Disconnect()  # Disconnect to reset the state and wait for new connection
            }
            catch {
                Write-PodeHost "Error with the pipe server: $_"

                # Set PipeServer to null to trigger reinitialization in the next loop
                Write-PodeHost 'Releasing resources and setting PipeServer to null.'
                if ($null -ne $PodeContext.Server.Watchdog['PipeWriter']) {
                    $PodeContext.Server.Watchdog['PipeWriter'].Dispose()  # Dispose of the existing PipeWriter
                    $PodeContext.Server.Watchdog['PipeWriter'] = $null
                }

                if ($null -ne $pipeServer) {
                    $pipeServer.Dispose()  # Dispose of the existing PipeServer
                    $PodeContext.Server.Watchdog['PipeServer'] = $null  # Set to null for reinitialization in the main loop
                }
            }
            finally {
                # Clean up resources
                Write-PodeHost 'Cleaning up resources...'
                if ($null -ne $reader) { $reader.Dispose() }
                if ($null -ne $pipeServer -and $pipeServer.IsConnected) {
                    $pipeServer.Disconnect()  # Ensure the server is disconnected before next iteration
                }
            }
        }

        Write-PodeHost 'Stopping PipeServer...'
    }


    $pipename = "$($PID)_Watchdog"
    $PodeContext.Server.Watchdog = [System.Collections.Concurrent.ConcurrentDictionary[string, PSObject]]::new()
    $PodeContext.Server.Watchdog['Shell'] = $(if ($PSVersionTable.PSVersion -gt [version]'6.0') { 'pwsh' } else { 'powershell' })
    $PodeContext.Server.Watchdog['Arguments'] = $null
    $PodeContext.Server.Watchdog['Process'] = $null
    $PodeContext.Server.Watchdog['Status'] = 'Starting'
    $PodeContext.Server.Watchdog['PipeName'] = $pipename
    $PodeContext.Server.Watchdog['PreSharedKey'] = (New-PodeGuid)
    #  $PodeContext.Server.Watchdog['PipeServer'] = [System.IO.Pipes.NamedPipeServerStream]::new($pipeName, [System.IO.Pipes.PipeDirection]::InOut, 2, [System.IO.Pipes.PipeTransmissionMode]::Message, [System.IO.Pipes.PipeOptions]::Asynchronous)
    $PodeContext.Server.Watchdog['ScriptBlock'] = $scriptBlock
    $PodeContext.Server.Watchdog['Type'] = 'Server'
    $PodeContext.Server.Watchdog['Runspace'] = $null
    $PodeContext.Server.Watchdog['Interval'] = $Interval
    $PodeContext.Server.Watchdog['PipeServer'] = $null
    $PodeContext.Server.Watchdog['PipeWriter'] = $null
    # Create a persistent StreamWriter for writing messages and store it in the context
    #   $PodeContext.Server.Watchdog['PipeWriter'] = [System.IO.StreamWriter]::new($PodeContext.Server.Watchdog.PipeServer)
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
        [ValidateSet('Stop', 'Restart', 'Start','Kill')]
        [string]
        $State = 'Stop'
    )
    switch ($State) {
        'Stop' { return Stop-PodeWatchdogProcess }
        'Restart' { return Restart-PodeWatchdogProcess }
        'Start' { return Start-PodeWatchdogProcess }
        'Kill'  { return Stop-PodeWatchdogProcess -Force}
    }
}
