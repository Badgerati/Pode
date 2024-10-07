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
        $pipeServer = $PodeContext.Server.Watchdog.PipeServer

        try {
            # Create a StreamReader to read the incoming message
            $reader = [System.IO.StreamReader]::new($pipeServer)
            while ($true) {
                Write-PodeHost 'Waiting for client connection...'

                # Wait for the client connection
                $pipeServer.WaitForConnection()
                try {
                    # Create a StreamReader to read the incoming message
                    $reader = [System.IO.StreamReader]::new($pipeServer)
                    # Read the first line, which should be the pre-shared key
                    $receivedKey = $reader.ReadLine()
                    if ($receivedKey -eq $preSharedKey) {
                        # The client is verified; proceed to read the actual data
                        Write-PodeHost 'Client verified successfully!'

                        # Read the next message, which contains the serialized hashtable
                        $receivedData = $reader.ReadLine()
                        if ($receivedData) {
                            # Deserialize the received JSON string back into a hashtable
                            $hashtable = $receivedData | ConvertFrom-Json
                            Write-PodeHost 'Received hashtable:'
                            Write-PodeHost $hashtable -Explode
                        }
                        else {
                            Write-PodeHost 'No data received from client.'
                        }
                    }
                    else {
                        Write-PodeHost 'Client verification failed. Disconnecting...'
                    }
                }
                catch {
                    Write-PodeHost "Error reading from pipe: $_"
                }
                Write-PodeHost 'Nothing here on the server'
            }
        }
        finally {
            # Clean up
            $reader.Dispose()
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
        PipeServer        = [System.IO.Pipes.NamedPipeServerStream]::new($pipeName, [System.IO.Pipes.PipeDirection]::In, 1)
        ScriptBlock       = $scriptBlock
        Runspace          = $null
        Interval          = $Interval
    }
    write-podehost  $PodeContext.Server.Watchdog.Arguments

    $PodeWatchdog = @{
        DisableTermination = $true
        Quiet              = $false
        EnableMonitoring   = !$DisableMonitoring.IsPresent
        MonitoringPort     = $MonitoringPort
        MonitoringAddress  = $MonitoringAddress
        PreSharedKey       = $PodeContext.Server.Watchdog.PreSharedKey
        IsMonitored        = $true
        PipeName           = $pipename
        Interval           = $Interval
    }

    # Serialize the hashtable to a JSON string
    $jsonConfig = $PodeWatchdog | ConvertTo-Json -Compress

    # Escape double quotes for passing the JSON string as a command-line argument
    $escapedJsonConfig = $jsonConfig.Replace('"', '\"')

    $PodeContext.Server.Watchdog.Arguments = "$arguments  '$escapedJsonConfig'"


    Open-PodeWatchdogRunPool


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
        if ($PodeContext.Server.Watchdog.IsMonitored) {
            $PodeContext.Server.Watchdog.PipeClient.Dispose()
        }
        else {
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

function Start-PodeWatchdog {
    param ()
    write-podehost 'starting watchdog'
    if ($PodeContext.Server.containsKey('Watchdog')) {
        if ($PodeContext.Server.Watchdog.IsMonitored) {
            Start-PodeWatchdogHearthbeat
            Set-PodeWatchdogEndpoint -Address $PodeContext.Server.Watchdog.MonitoringAddress -Port $PodeContext.Server.Watchdog.MonitoringPort
        }
        else {
            $watchdog = $PodeContext.Server.Watchdog
            if ($null -eq $PodeContext.Server.Watchdog.Process ) {
                $watchdog.Status = 'Starting'
                $watchdog.Process = Start-Process -FilePath  $watchdog.Shell -ArgumentList $watchdog.Arguments -NoNewWindow -PassThru

                $watchdog.Runspace = Add-PodeRunspace -Type 'Watchdog' -ScriptBlock ( $watchdog.ScriptBlock)

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

    if ($PodeContext.Server.containsKey('Watchdog') -and $PodeContext.Server.Watchdog.IsMonitored) {
        # Create a named pipe client and connect to the server
        $PodeContext.Server.Watchdog.PipeClient = [System.IO.Pipes.NamedPipeClientStream]::new('.', $PodeContext.Server.Watchdog.PipeName, [System.IO.Pipes.PipeDirection]::Out)
        $PodeContext.Server.Watchdog.PipeClient.Connect()

        Add-PodeTimer -Name '__pode_watchdog_client__' -Interval $PodeContext.Server.Watchdog.Interval -ScriptBlock {

            $jsonData = [ordered]@{
                Pid           = $PID
                CurrentUptime = (Get-PodeServerUptime)
                TotalUptime   = (Get-PodeServerUptime -Total)
                RestartCount  = (Get-PodeServerRestartCount)
            } | ConvertTo-Json

            write-podehost $jsonData
            # Create a StreamWriter to send messages to the server
            $writer = [System.IO.StreamWriter]::new( $PodeContext.Server.Watchdog.PipeClient)

            # Send the pre-shared key for client verification
            $writer.WriteLine($PodeContext.Server.Watchdog.PreSharedKey)
            $writer.Flush()

            # Send the serialized hashtable data
            $writer.WriteLine($jsonData)
            $writer.Flush()

            # Clean up
            $writer.Dispose()
            # $pipeClient.Dispose()
        }
    }
}





function Open-PodeWatchdogRunPool {
    if (!$PodeContext.RunspacePools.containsKey('Watchdog') ) {
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
