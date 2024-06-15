function Get-PodeLoggingTerminalMethod {
    return {
        param($item, $options)

        if ($PodeContext.Server.Quiet) {
            return
        }

        # check if it's an array from batching
        if ($item -is [array]) {
            $item = ($item -join [System.Environment]::NewLine)
        }

        # protect then write
        $item = ($item | Protect-PodeLogItem)
        $item.ToString() | Out-PodeHost
    }
}

function Get-PodeLoggingFileMethod {
    return {
        param($item, $options)

        # check if it's an array from batching
        if ($item -is [array]) {
            $item = ($item -join [System.Environment]::NewLine)
        }

        # mask values
        $item = ($item | Protect-PodeLogItem)

        # variables
        $date = [DateTime]::Now.ToString('yyyy-MM-dd')

        # do we need to reset the fileId?
        if ($options.Date -ine $date) {
            $options.Date = $date
            $options.FileId = 0
        }

        # get the fileId
        if ($options.FileId -eq 0) {
            $path = [System.IO.Path]::Combine($options.Path, "$($options.Name)_$($date)_*.log")
            $options.FileId = (@(Get-ChildItem -Path $path)).Length
            if ($options.FileId -eq 0) {
                $options.FileId = 1
            }
        }

        $id = "$($options.FileId)".PadLeft(3, '0')
        if ($options.MaxSize -gt 0) {
            $path = [System.IO.Path]::Combine($options.Path, "$($options.Name)_$($date)_$($id).log")
            if ((Get-Item -Path $path -Force).Length -ge $options.MaxSize) {
                $options.FileId++
                $id = "$($options.FileId)".PadLeft(3, '0')
            }
        }

        # get the file to write to
        $path = [System.IO.Path]::Combine($options.Path, "$($options.Name)_$($date)_$($id).log")

        # write the item to the file
        $item.ToString() | Out-File -FilePath $path -Encoding utf8 -Append -Force

        # if set, remove log files beyond days set (ensure this is only run once a day)
        if (($options.MaxDays -gt 0) -and ($options.NextClearDown -lt [DateTime]::Now.Date)) {
            $date = [DateTime]::Now.Date.AddDays(-$options.MaxDays)

            $null = Get-ChildItem -Path $options.Path -Filter '*.log' -Force |
                Where-Object { $_.CreationTime -lt $date } |
                Remove-Item $_ -Force

            $options.NextClearDown = [DateTime]::Now.Date.AddDays(1)
        }
    }
}

<#
.SYNOPSIS
Handles the sending of log messages to a Syslog server using various transport protocols.

.DESCRIPTION
This function defines the logic for sending log messages to a Syslog server using different transport protocols including UDP, TCP, TLS, Splunk, and VMware LogInsight.
It supports both RFC 3164 and RFC 5424 formats and includes error handling based on user-defined actions.

.PARAMETER item
The log item to be sent to the Syslog server.

.PARAMETER options
A hashtable containing options for the Syslog message including Transport, Server, Port, Hostname, Source, TlsProtocols, SkipCertificateCheck, RFC3164, Token, Id, and FailureAction.

.EXAMPLE
Send a log message using UDP transport:
$logMethod = Get-PodeLoggingSysLogMethod
$logMethod.Invoke('This is a log message', @{ Transport = 'UDP'; Server = 'syslog.example.com'; Port = 514 })

.EXAMPLE
Send a log message using TLS transport with certificate validation:
$logMethod = Get-PodeLoggingSysLogMethod
$logMethod.Invoke('This is a secure log message', @{ Transport = 'TLS'; Server = 'syslog.example.com'; Port = 6514; TlsProtocols = [System.Security.Authentication.SslProtocols]::Tls12 })

.EXAMPLE
Send a log message to Splunk:
$logMethod = Get-PodeLoggingSysLogMethod
$logMethod.Invoke('This is a Splunk log message', @{ Transport = 'Splunk'; Server = 'splunk.example.com'; Port = 8088; Token = 'your-splunk-token' })

.EXAMPLE
Send a log message to Log Insight:
$logMethod = Get-PodeLoggingSysLogMethod
$logMethod.Invoke('This is a Log Insight message', @{ Transport = 'LogInsight'; Server = 'loginsight.example.com'; Port = 9000; Id = 'your-agent-id' })

.NOTES
This is an internal function and may change in future releases of Pode.
#>
function Get-PodeLoggingSysLogMethod {
    return {
        param($item, $options)

        function HandleFailure {
            param($message, $FailureAction)
            switch ($FailureAction.ToLowerInvariant()) {
                'ignore' {
                    # Do nothing and continue
                }
                'report' {
                    # Report on console and continue
                    Write-PodeHost $message
                }
                'halt' {
                    # Report on console and halt
                    Write-PodeHost $message
                    Close-PodeServer
                }
            }
        }

        # Mask values
        $item = ($item | Protect-PodeLogItem)
        if (('UDP' , 'TCP' , 'TLS') -contains $options.Transport) {
            $processId = $PID

            # Define the facility and severity
            $facility = 1 # User-level messages
            $severity = 6 # Informational
            $priority = ($facility * 8) + $severity

            # Determine the syslog message format
            if ($options.RFC3164) {
                # Set the max message length per RFC 3164 section 4.1
                $MaxLength = 1024
                # Assemble the full syslog formatted Message
                $timestamp = (Get-Date).ToString('MMM dd HH:mm:ss')
                $fullSyslogMessage = "<$priority>$timestamp $($options.Hostname) $($options.Source)[$processId]: $item"
            }
            else {
                # Assemble the full syslog formatted Message
                $fullSyslogMessage = "<$priority>1 $(Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.ffffffK') $($options.Hostname) $($options.Source) $processId - - $item"

                # Set the max message length per RFC 5424 section 6.1
                $MaxLength = 2048
            }

            # Ensure that the message is not too long
            if ($fullSyslogMessage.Length -gt $MaxLength) {
                $fullSyslogMessage = $fullSyslogMessage.Substring(0, $MaxLength)
            }

            # Convert the message to a byte array
            $byteMessage = [Text.Encoding]::UTF8.GetBytes($fullSyslogMessage)
        }

        # Determine the transport protocol and send the message
        switch ($options.Transport) {
            'UDP' {
                $udpClient = New-Object System.Net.Sockets.UdpClient
                try {
                    # Send the message to the syslog server
                    $udpClient.Send($byteMessage, $byteMessage.Length, $options.Server, $options.Port)
                }
                catch {
                    HandleFailure  "Failed to send UDP message: $_" $options.FailureAction
                }
                finally {
                    # Close the UDP client
                    $udpClient.Close()
                }
            }
            'TCP' {
                try {
                    # Create a TCP client for non-secure communication
                    $tcpClient = New-Object System.Net.Sockets.TcpClient
                    $tcpClient.Connect($options.Server, $options.Port)
                    $networkStream = $tcpClient.GetStream()

                    # Send the message
                    $networkStream.Write($byteMessage, 0, $byteMessage.Length)
                    $networkStream.Flush()
                }
                catch {
                    HandleFailure  "Failed to send TCP message: $_" $options.FailureAction
                }
                finally {
                    # Close the TCP client
                    if ($networkStream) { $networkStream.Close() }
                    if ($tcpClient) { $tcpClient.Close() }
                }
            }
            'TLS' {
                try {
                    # Create a TCP client for secure communication
                    $tcpClient = New-Object System.Net.Sockets.TcpClient
                    $tcpClient.Connect($options.Server, $options.Port)

                    $sslStream = if ($options.SkipCertificateCheck) {
                        New-Object System.Net.Security.SslStream($tcpClient.GetStream(), $false, { $true })
                    }
                    else {
                        New-Object System.Net.Security.SslStream($tcpClient.GetStream(), $false)
                    }

                    # Define the TLS protocol version
                    $tlsProtocol = if ($options.TlsProtocols) {
                        $options.TlsProtocols
                    }
                    else {
                        [System.Security.Authentication.SslProtocols]::Tls12  # Default to TLS 1.2
                    }

                    # Authenticate as client with specific TLS protocol
                    $sslStream.AuthenticateAsClient($options.Server, $null, $tlsProtocol, $false)

                    # Send the message
                    $sslStream.Write($byteMessage)
                    $sslStream.Flush()
                }
                catch {
                    HandleFailure  "Failed to send secure TLS message: $_" $options.FailureAction
                }
                finally {
                    # Close the TCP client
                    if ($sslStream) { $sslStream.Close() }
                    if ($tcpClient) { $tcpClient.Close() }
                }
            }
            'Splunk' {
                # Construct the Splunk API URL
                $url = "http://$($options.Server):$($options.Port)/services/collector"
                $headers = @{
                    'Authorization' = "Splunk $($options.Token)"
                }

                $unixEpochTime = [math]::Round((Get-Date).ToUniversalTime().Subtract((Get-Date '1970-01-01')).TotalSeconds)
                $Body = ConvertTo-Json -InputObject @{event = $item; host = $options.Hostname ; time = $unixEpochTime } -Compress

                try {
                    Invoke-RestMethod -Uri $splunkUrl -Method Post -Headers $headers -Body $body -ContentType 'application/json'
                }
                catch {
                    HandleFailure  "Failed to send log to Splunk: $_" $options.FailureAction
                }
            }
            'LogInsight' {

                # Construct the Log Insight API URL
                $url = "http://$($options.Server):$($options.Port)/api/v1/messages/ingest/$($options.Id)"

                # Define the message payload
                $payload = @{
                    messages = @(
                        @{
                            text      = $item
                            timestamp = [math]::Round((Get-Date).ToUniversalTime().Subtract((Get-Date '1970-01-01')).TotalMilliseconds)
                        }
                    )
                }

                # Convert payload to JSON
                $body = $payload | ConvertTo-Json   -Compress

                # Send the message to Log Insight
                try {
                    Invoke-RestMethod -Uri $url -Method Post -Body $body -ContentType 'application/json'
                }
                catch {
                    HandleFailure  "Failed to send log to LogInsight: $_" $options.FailureAction
                }
            }
        }
    }
}

function Get-PodeLoggingEventViewerMethod {
    return {
        param($item, $options, $rawItem)

        if ($item -isnot [array]) {
            $item = @($item)
        }

        if ($rawItem -isnot [array]) {
            $rawItem = @($rawItem)
        }

        for ($i = 0; $i -lt $item.Length; $i++) {
            # convert log level - info if no level present
            $entryType = ConvertTo-PodeEventViewerLevel -Level $rawItem[$i].Level

            # create log instance
            $entryInstance = [System.Diagnostics.EventInstance]::new($options.ID, 0, $entryType)

            # create event log
            $entryLog = [System.Diagnostics.EventLog]::new()
            $entryLog.Log = $options.LogName
            $entryLog.Source = $options.Source

            try {
                $message = ($item[$i] | Protect-PodeLogItem)
                $entryLog.WriteEvent($entryInstance, $message)
            }
            catch {
                $_ | Write-PodeErrorLog -Level Debug
            }
        }
    }
}

function ConvertTo-PodeEventViewerLevel {
    param(
        [Parameter()]
        [string]
        $Level
    )

    if ([string]::IsNullOrWhiteSpace($Level)) {
        return [System.Diagnostics.EventLogEntryType]::Information
    }

    if ($Level -ieq 'error') {
        return [System.Diagnostics.EventLogEntryType]::Error
    }

    if ($Level -ieq 'warning') {
        return [System.Diagnostics.EventLogEntryType]::Warning
    }

    return [System.Diagnostics.EventLogEntryType]::Information
}

function Get-PodeLoggingInbuiltType {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Errors', 'Requests')]
        [string]
        $Type
    )

    switch ($Type.ToLowerInvariant()) {
        'requests' {
            $script = {
                param($item, $options)

                # just return the item if Raw is set
                if ($options.Raw) {
                    return $item
                }

                function sg($value) {
                    if ([string]::IsNullOrWhiteSpace($value)) {
                        return '-'
                    }

                    return $value
                }

                # build the url with http method
                $url = "$(sg $item.Request.Method) $(sg $item.Request.Resource) $(sg $item.Request.Protocol)"

                # build and return the request row
                return "$(sg $item.Host) $(sg $item.RfcUserIdentity) $(sg $item.User) [$(sg $item.Date)] `"$($url)`" $(sg $item.Response.StatusCode) $(sg $item.Response.Size) `"$(sg $item.Request.Referrer)`" `"$(sg $item.Request.Agent)`""
            }
        }

        'errors' {
            $script = {
                param($item, $options)

                # do nothing if the error level isn't present
                if (@($options.Levels) -inotcontains $item.Level) {
                    return
                }

                # just return the item if Raw is set
                if ($options.Raw) {
                    return $item
                }

                # build the exception details
                $row = @(
                    "Date: $($item.Date.ToString('yyyy-MM-dd HH:mm:ss'))",
                    "Level: $($item.Level)",
                    "ThreadId: $($item.ThreadId)",
                    "Server: $($item.Server)",
                    "Category: $($item.Category)",
                    "Message: $($item.Message)",
                    "StackTrace: $($item.StackTrace)"
                )

                # join the details and return
                return "$($row -join "`n")`n"
            }
        }
    }

    return $script
}

function Get-PodeRequestLoggingName {
    return '__pode_log_requests__'
}

function Get-PodeErrorLoggingName {
    return '__pode_log_errors__'
}

<#
.SYNOPSIS
    Retrieves a Pode logger by name.

.DESCRIPTION
    This function allows you to retrieve a Pode logger by specifying its name. It returns the logger object associated with the given name.

.PARAMETER Name
    The name of the Pode logger to retrieve.

.OUTPUTS
    A Pode logger object.

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function Get-PodeLogger {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    return $PodeContext.Server.Logging.Types[$Name]
}

function Test-PodeLoggerEnabled {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    return ($PodeContext.Server.Logging.Enabled -and $PodeContext.Server.Logging.Types.ContainsKey($Name))
}

<#
.SYNOPSIS
    Gets the error logging levels for Pode.

.DESCRIPTION
    This function retrieves the error logging levels configured for Pode. It returns an array of available error levels.

.PARAMETER Name
    The name of the Pode logger to retrieve.

.OUTPUTS
    An array of error logging levels.

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function Get-PodeErrorLoggingLevel {
    return (Get-PodeLogger -Name (Get-PodeErrorLoggingName)).Arguments.Levels
}

function Test-PodeErrorLoggingEnabled {
    return (Test-PodeLoggerEnabled -Name (Get-PodeErrorLoggingName))
}

function Test-PodeRequestLoggingEnabled {
    return (Test-PodeLoggerEnabled -Name (Get-PodeRequestLoggingName))
}

function Write-PodeRequestLog {
    param(
        [Parameter(Mandatory = $true)]
        $Request,

        [Parameter(Mandatory = $true)]
        $Response,

        [Parameter()]
        [string]
        $Path
    )

    # do nothing if logging is disabled, or request logging isn't setup
    $name = Get-PodeRequestLoggingName
    if (!(Test-PodeLoggerEnabled -Name $name)) {
        return
    }

    # build a request object
    $item = @{
        Host            = $Request.RemoteEndPoint.Address.IPAddressToString
        RfcUserIdentity = '-'
        User            = '-'
        Date            = [DateTime]::Now.ToString('dd/MMM/yyyy:HH:mm:ss zzz')
        Request         = @{
            Method   = $Request.HttpMethod.ToUpperInvariant()
            Resource = $Path
            Protocol = "HTTP/$($Request.ProtocolVersion)"
            Referrer = $Request.UrlReferrer
            Agent    = $Request.UserAgent
        }
        Response        = @{
            StatusCode        = $Response.StatusCode
            StatusDescription = $Response.StatusDescription
            Size              = '-'
        }
    }

    # set size if >0
    if ($Response.ContentLength64 -gt 0) {
        $item.Response.Size = $Response.ContentLength64
    }

    # set username - dot spaces
    if (Test-PodeAuthUser -IgnoreSession) {
        $userProps = (Get-PodeLogger -Name $name).Properties.Username.Split('.')

        $user = $WebEvent.Auth.User
        foreach ($atom in $userProps) {
            $user = $user.($atom)
        }

        if (![string]::IsNullOrWhiteSpace($user)) {
            $item.User = $user -ireplace '\s+', '.'
        }
    }

    # add the item to be processed
    $null = $PodeContext.LogsToProcess.Add(@{
            Name = $name
            Item = $item
        })
}

function Add-PodeRequestLogEndware {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        $WebEvent
    )

    # do nothing if logging is disabled, or request logging isn't setup
    $name = Get-PodeRequestLoggingName
    if (!(Test-PodeLoggerEnabled -Name $name)) {
        return
    }

    # add the request logging endware
    $WebEvent.OnEnd += @{
        Logic = {
            Write-PodeRequestLog -Request $WebEvent.Request -Response $WebEvent.Response -Path $WebEvent.Path
        }
    }
}

function Test-PodeLoggersExist {
    if (($null -eq $PodeContext.Server.Logging) -or ($null -eq $PodeContext.Server.Logging.Types)) {
        return $false
    }

    return (($PodeContext.Server.Logging.Types.Count -gt 0) -or ($PodeContext.Server.Logging.Enabled))
}

function Start-PodeLoggingRunspace {
    # skip if there are no loggers configured, or logging is disabled
    if (!(Test-PodeLoggersExist)) {
        return
    }

    $script = {
        while (!$PodeContext.Tokens.Cancellation.IsCancellationRequested) {
            # if there are no logs to process, just sleep for a few seconds - but after checking the batch
            if ($PodeContext.LogsToProcess.Count -eq 0) {
                Test-PodeLoggerBatch
                Start-Sleep -Seconds 5
                continue
            }

            # safely pop off the first log from the array
            $log = (Lock-PodeObject -Return -Object $PodeContext.LogsToProcess -ScriptBlock {
                    $log = $PodeContext.LogsToProcess[0]
                    $null = $PodeContext.LogsToProcess.RemoveAt(0)
                    return $log
                })

            # run the log item through the appropriate method
            $logger = Get-PodeLogger -Name $log.Name
            $now = [datetime]::Now

            # if the log is null, check batch then sleep and skip
            if ($null -eq $log) {
                Start-Sleep -Milliseconds 100
                continue
            }

            # convert to log item into a writable format
            $rawItems = $log.Item
            $_args = @($log.Item) + @($logger.Arguments)
            $result = @(Invoke-PodeScriptBlock -ScriptBlock $logger.ScriptBlock -Arguments $_args -UsingVariables $logger.UsingVariables -Return -Splat)

            # check batching
            $batch = $logger.Method.Batch
            if ($batch.Size -gt 1) {
                # add current item to batch
                $batch.Items += $result
                $batch.RawItems += $log.Item
                $batch.LastUpdate = $now

                # if the current amount of items matches the batch, write
                $result = $null
                if ($batch.Items.Length -ge $batch.Size) {
                    $result = $batch.Items
                    $rawItems = $batch.RawItems
                }

                # if we're writing, reset the items
                if ($null -ne $result) {
                    $batch.Items = @()
                    $batch.RawItems = @()
                }
            }

            # send the writable log item off to the log writer
            if ($null -ne $result) {
                $_args = @(, $result) + @($logger.Method.Arguments) + @(, $rawItems)
                $null = Invoke-PodeScriptBlock -ScriptBlock $logger.Method.ScriptBlock -Arguments $_args -UsingVariables $logger.Method.UsingVariables -Splat
            }

            # small sleep to lower cpu usage
            Start-Sleep -Milliseconds 100
        }
    }

    Add-PodeRunspace -Type Main -ScriptBlock $script
}

<#
.SYNOPSIS
    Tests whether Pode logger batches need to be written.

.DESCRIPTION
    This function checks each Pode logger and determines if its batch needs to be written. It evaluates the batch size, timeout, and last update timestamp to decide whether to process the batch and write the log entries.

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function Test-PodeLoggerBatch {
    $now = [datetime]::Now

    # check each logger, and see if its batch needs to be written
    foreach ($logger in $PodeContext.Server.Logging.Types.Values) {
        $batch = $logger.Method.Batch
        if (($batch.Size -gt 1) -and ($batch.Items.Length -gt 0) -and ($batch.Timeout -gt 0) `
                -and ($null -ne $batch.LastUpdate) -and ($batch.LastUpdate.AddSeconds($batch.Timeout) -le $now)
        ) {
            $result = $batch.Items
            $rawItems = $batch.RawItems

            $batch.Items = @()
            $batch.RawItems = @()

            $_args = @(, $result) + @($logger.Method.Arguments) + @(, $rawItems)
            $null = Invoke-PodeScriptBlock -ScriptBlock $logger.Method.ScriptBlock -Arguments $_args -UsingVariables $logger.Method.UsingVariables -Splat
        }
    }
}