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

        [int]
        $MonitoringPort = 5051,

        [string]
        $MonitoringAddress = 'localhost',

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

        # Create a StreamReader to read the incoming message
        $reader = [System.IO.StreamReader]::new($pipeServer)
        while ($true) {
            Write-PodeHost 'Waiting for client connection...'

            # Wait for the client connection
            $pipeServer.WaitForConnection()
            Write-PodeHost 'Client connected.'
            try {
                # Create a StreamReader to read the incoming message from the connected client
                $reader = [System.IO.StreamReader]::new($pipeServer)

                while ($pipeServer.IsConnected) {
                    # Read the next message, which contains the serialized hashtable
                    $receivedData = $reader.ReadLine()

                    # Check if data was received
                    if ($receivedData) {
                        Write-PodeHost "Received data: $receivedData"

                        # Deserialize the received JSON string back into a hashtable
                        $hashtable = $receivedData | ConvertFrom-Json
                        Write-PodeHost 'Received hashtable:'
                        Write-PodeHost $hashtable -Explode
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
    $PodeContext.Server.Watchdog = @{
        Shell             = $(if ($PSVersionTable.PSVersion -gt [version]'6.0') { 'pwsh' } else { 'powershell' })
        Arguments         = $null
        Process           = $null
        MonitoringPort    = $MonitoringPort
        MonitoringAddress = $MonitoringAddress
        Status            = 'Starting'
        PipeName          = $pipename
        PreSharedKey      = (New-PodeGuid)
        PipeServer        = [System.IO.Pipes.NamedPipeServerStream]::new($pipeName, [System.IO.Pipes.PipeDirection]::InOut, 2, [System.IO.Pipes.PipeTransmissionMode]::Message, [System.IO.Pipes.PipeOptions]::Asynchronous)
        ScriptBlock       = $scriptBlock
        Type              = 'Server'
        Runspace          = $null
        Interval          = $Interval
    }

    $PodeWatchdog = @{
        DisableTermination = $true
        Quiet              = $true
        EnableMonitoring   = !$DisableMonitoring.IsPresent
        MonitoringPort     = $MonitoringPort
        MonitoringAddress  = $MonitoringAddress
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
    write-podehost 'Stopping watchdog'
    if ($PodeContext.Server.containsKey('Watchdog')) {
        switch ($PodeContext.Server.Watchdog.Type) {
            'Client' {
                if ($null -ne $PodeContext.Server.Watchdog.PipeClient) {
                    $PodeContext.Server.Watchdog.PipeClient.Dispose()
                }
                if ($null -ne $PodeContext.Server.Watchdog.PipeWriter) {
                    $PodeContext.Server.Watchdog.PipeWriter.Dispose()
                }
            }
            'Server' {
                if ($null -ne $PodeContext.Server.Watchdog.PipeServer) {
                    $PodeContext.Server.Watchdog.PipeServer.Dispose()

                    $PodeContext.Server.Watchdog.Status = 'Stopping'
                    if (Stop-PodeWatchdogProcess) {
                        $PodeContext.Server.Watchdog.Status = 'Exited'
                    }
                    else {
                        $PodeContext.Server.Watchdog.Status = 'Undefined'
                    }
                }
            }
        }
    }
}

function Start-PodeWatchdog {
    param ()
    write-podehost 'starting watchdog'
    if ($PodeContext.Server.containsKey('Watchdog')) {
        switch ($PodeContext.Server.Watchdog.Type) {
            'Client' {
                Start-PodeWatchdogHearthbeat
                Set-PodeWatchdogEndpoint -Address $PodeContext.Server.Watchdog.MonitoringAddress -Port $PodeContext.Server.Watchdog.MonitoringPort
            }
            'Server' {
                $watchdog = $PodeContext.Server.Watchdog
                if ($null -eq $PodeContext.Server.Watchdog.Process ) {
                    $watchdog.Status = 'Starting'


                    Open-PodeWatchdogRunPool

                    $watchdog.Process = Start-Process -FilePath  $watchdog.Shell -ArgumentList $watchdog.Arguments -NoNewWindow -PassThru

                    $watchdog.Runspace = Add-PodeRunspace -Type 'Watchdog' -ScriptBlock ( $watchdog.ScriptBlock)   -PassThru

                    if (!$watchdog.Process.HasExited) {
                        $watchdog.Status = 'Running'
                    }
                    else {
                        $watchdog.Status = 'Offline'
                    }
                }
            }
        }
    }
}



function Set-PodeWatchdogEndpoint {
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $Address,

        [Parameter(Mandatory = $true)]
        [int]
        $Port
    )
    if (Get-PodeEndpoint -Name '_watchdog_monitor_endpoint') {
        return
    }

    Add-PodeEndpoint -Address $Address -Port $Port -Protocol Http -Name '_watchdog_monitor_endpoint'
    <#  Add-PodeRoute -PassThru -Method Get -Path '/listeners' -EndpointName '_watchdog_monitor_endpoint' -ScriptBlock {
        Write-PodeJsonResponse -StatusCode 200 -Value $PodeContext.Server.Signals.Listener.Contexts
    }

    Add-PodeRoute -PassThru -Method Get -Path '/requests' -EndpointName '_watchdog_monitor_endpoint' -ScriptBlock {
        $r = Get-PodeServerRequestMetric
        Write-PodeJsonResponse -StatusCode 200 -Value $r
    }
#>
    Add-PodeRoute  -Method 'Post' -Path '/close' -ScriptBlock {
        Close-PodeServer
        Write-PodeJsonResponse -StatusCode 200 -Value @{'status' = 'offline' }
    }

    <#    Add-PodeRoute -PassThru -Method Get -Path '/status' -EndpointName '_watchdog_monitor_endpoint' -ScriptBlock {

        Write-PodeJsonResponse -StatusCode 200 -Value ([ordered]@{
                Pid           = $PID
                CurrentUptime = (Get-PodeServerUptime)
                TotalUptime   = (Get-PodeServerUptime -Total)
                RestartCount  = (Get-PodeServerRestartCount)
            }
        )
    }#>
}


function Start-PodeWatchdogHearthbeat {

    if ($PodeContext.Server.containsKey('Watchdog') -and $PodeContext.Server.Watchdog.Type -eq 'Client') {
        # Create a named pipe client and connect to the server
        try {
            $PodeContext.Server.Watchdog.PipeClient = [System.IO.Pipes.NamedPipeClientStream]::new('.', $PodeContext.Server.Watchdog.PipeName, [System.IO.Pipes.PipeDirection]::InOut, [System.IO.Pipes.PipeOptions]::Asynchronous)
            # Attempt to connect to the server with a timeout
            $PodeContext.Server.Watchdog.PipeClient.Connect(60000)  # Timeout in milliseconds (60 seconds)
            Write-PodeHost 'Connected to the watchdog pipe server.'

            # Create a persistent StreamWriter for writing messages and store it in the context
            $PodeContext.Server.Watchdog.PipeWriter = [System.IO.StreamWriter]::new($PodeContext.Server.Watchdog.PipeClient)
            $PodeContext.Server.Watchdog.PipeWriter.AutoFlush = $true  # Enable auto-flush to send data immediately


            Add-PodeTimer -Name '__pode_watchdog_client__' -Interval $PodeContext.Server.Watchdog.Interval -ScriptBlock {

                $jsonData = [ordered]@{
                    Pid           = $PID
                    CurrentUptime = (Get-PodeServerUptime)
                    TotalUptime   = (Get-PodeServerUptime -Total)
                    RestartCount  = (Get-PodeServerRestartCount)
                } | ConvertTo-Json
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
                if ($PodeContext.Server.Watchdog.Status -eq 'Restarting') {
                    write-podehost 'start Restarting '
                    for ($i = 0; $i -lt 10 ; $i++) {
                        Start-Sleep -Seconds 5
                        $request = Get-PodeWatchdogInfo -Type 'Requests'
                        if ($request) {
                            break
                        }
                    }
                    Stop-PodeWatchdogProcess
                    Start-PodeWatchdogProcess

                }
            }
            else {
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

function Stop-PodeWatchdogProcess {
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [int]
        $Timeout = 10, # Timeout in seconds for the HTTP request

        [int]
        $RetryCount = 3        # Number of times to retry the request in case of failure
    )
    return
    # Construct the URI for the REST call using $PodeWatchdog global settings
    $uri = "http://$($PodeContext.Server.Watchdog.MonitoringAddress):$($PodeContext.Server.Watchdog.MonitoringPort)/close"

    Write-Verbose "Attempting to stop Pode server at $uri"
    Write-podehost "Attempting to stop Pode server at $uri"

    # Retry logic with a loop
    for ($attempt = 1; $attempt -le $RetryCount; $attempt++) {
        try {
            Write-Verbose "Attempt $attempt of $RetryCount..."

            # Invoke the REST method to shut down the Pode server
            $response = Invoke-RestMethod -Uri $uri -Method 'Post' -TimeoutSec $Timeout -ErrorAction Stop

            # Check if the response indicates success
            if ($response.status -eq 'offline') {
                Write-Output 'Process has been successfully stopped via REST call.'
                return $true  # Return success
            }
            else {
                Write-Warning "Unexpected response from server: $response"
            }
        }
        catch [System.Net.WebException] {
            # Handle HTTP-specific errors like timeout, connection issues, etc.
            Write-Warning "Attempt $attempt failed: $($_.Exception.Message)"
        }
        catch {
            # Catch any other exceptions
            Write-Error "An error occurred while trying to stop the Pode server: $_"
        }

        # If not successful, wait before retrying
        Start-Sleep -Seconds 2
    }

    # If retries are exhausted, return failure
    Write-Error "Failed to stop the Pode server after $RetryCount attempts."
    return $false
}


function Get-PodeWatchdogInfo {
    [CmdletBinding(DefaultParameterSetName = 'HashTable')]
    [OutputType([string])]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet('Status', 'Requests', 'Listeners')]
        [string] $Type = 'Status',

        [Parameter(  ParameterSetName = 'Raw')]
        [switch]
        $Raw,

        [Parameter( ParameterSetName = 'HashTable')]
        [switch]
        $AsHashTable
    )
    try {
        $uri = "http://$($PodeContext.Server.Watchdog.MonitoringAddress):$($PodeContext.Server.Watchdog.MonitoringPort)/$($Type.ToLower())"
        $result = Invoke-WebRequest -Uri $uri -Method Get
        if ($result.StatusCode -eq 200) {
            if ($Raw.IsPresent) {
                return $result.Content
            }
            return $result.Content | ConvertFrom-Json -AsHashtable:$AsHashTable
        }
    }
    catch {
        if ($type -eq 'Status') {
            if ($Raw.IsPresent) {
                return '{"Status" : "Offline"}'
            }
            if ($AsHashTable.IsPresent) {
                return @{ 'Status' = 'Offline' }
            }
            return [PSCustomObject]@{ Status = 'Offline' }
        }
    }
}
