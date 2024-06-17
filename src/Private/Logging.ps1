<#
.SYNOPSIS
Defines the method for writing log messages to the terminal.

.DESCRIPTION
This internal function handles writing log messages to the terminal.
It checks if the server is in quiet mode and protects sensitive information before outputting the log messages.

.PARAMETER item
The log item to be written to the terminal.

.PARAMETER options
A hashtable containing options for the terminal logging method.

.NOTES
This is an internal function and may change in future releases of Pode.
#>
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

<#
.SYNOPSIS
Defines the method for writing log messages to a file.

.DESCRIPTION
This internal function handles writing log messages to a file, managing file rotation based on size and date, and removing old log files beyond a specified retention period.
It includes error handling based on user-defined actions.

.PARAMETER item
The log item to be written to the file.

.PARAMETER options
A hashtable containing options for the file logging method including Path, Name, MaxDays, MaxSize, Date, FileId, and FailureAction.

.NOTES
This is an internal function and may change in future releases of Pode.
#>
function Get-PodeLoggingFileMethod {
    return {
        param($item, $options)
        try {
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
        catch {
            Invoke-PodeHandleFailure -Message "Failed to Log a message: $_" -FailureAction $options.FailureAction
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

.PARAMETER rawItem
The raw log item, used to determine the log level.

.NOTES
This is an internal function and may change in future releases of Pode.
#>
function Get-PodeLoggingSysLogMethod {
    return {
        param($item, $options, $rawItem)

        function sg($value) {
            if ([string]::IsNullOrWhiteSpace($value)) {
                return '-'
            }

            return $value
        }

        if ($item -isnot [array]) {
            $item = @($item)
        }

        if ($rawItem -isnot [array]) {
            $rawItem = @($rawItem)
        }

        for ($i = 0; $i -lt $item.Length; $i++) {
            # Mask values
            if ($rawItem[$i].Message) {
                if ($rawItem[$i].StackTrace) {
                    $message = "$($rawItem[$i].Level.ToUpperInvariant()): $($rawItem[$i].Message | Protect-PodeLogItem). Exception Type: $($rawItem[$i].Category). Stack Trace: $($rawItem[$i].StackTrace)"
                }
                else {
                    $message = ($rawItem[$i].Message | Protect-PodeLogItem)
                }
            }
            else {
                if ($item[$i] -is [hashtable]) {
                    $message = "{`"time`": `"$($item.Date.ToString('yyyy-MM-ddTHH:mm:ssK'))`",`"remote_ip`": `"$(sg $item.Host)`",`"user`": `"$(sg $item.User)`",`"method`": `"$(sg $item.Request.Method)`",`"uri`": `"$(sg $item.Request.Resource)`",`"query`": `"$(sg $item.Request.Query)`",`"status`": $(sg $item.Response.StatusCode),`"response_size`": $(sg $item.Response.Size),`"user_agent`": `"$(sg $item.Request.Agent)`"}"
                }
                else {
                    $message = ($item[$i] | Protect-PodeLogItem)
                }
            }

            # Map $Level to syslog severity
            switch ($rawItem[$i].Level) {
                'emergency' { $severity = 0; break }
                'alert' { $severity = 1; break }
                'critical' { $severity = 2; break }
                'error' { $severity = 3; break }
                'warning' { $severity = 4; break }
                'notice' { $severity = 5; break }
                'info' { $severity = 6; break }
                'informational' { $severity = 6; break }
                'debug' { $severity = 7; break }
                default { $severity = 6 } # Default to Informational
            }

            # Define the facility and severity
            $facility = 1 # User-level messages
            $priority = ($facility * 8) + $severity

            # Determine the syslog message format
            switch ($options.SyslogProtocol.ToUpperInvariant()) {
                'RFC3164' {
                    # Set the max message length per RFC 3164 section 4.1
                    $MaxLength = 1024
                    # Assemble the full syslog formatted Message
                    $timestamp = $rawItem[$i].Date.ToString('MMM dd HH:mm:ss')
                    $fullSyslogMessage = "<$priority>$timestamp $($PodeContext.Server.ComputerName) $($options.Source)[$processId]: $message"
                    break
                }
                'RFC5424' {
                    $processId = $PID
                    $timestamp = $rawItem[$i].Date.ToString('yyyy-MM-ddTHH:mm:ss.ffffffK')
                    # Assemble the full syslog formatted Message
                    $fullSyslogMessage = "<$priority>1 $timestamp $($PodeContext.Server.ComputerName) $($options.Source) $processId - - $message"

                    # Set the max message length per RFC 5424 section 6.1
                    $MaxLength = 2048
                    break
                }
                default {
                    throw "Unsupported Syslog protocol: $($options.SyslogProtocol)"
                }
            }

            # Ensure that the message is not too long
            if ($fullSyslogMessage.Length -gt $MaxLength) {
                $fullSyslogMessage = $fullSyslogMessage.Substring(0, $MaxLength)
            }

            # Convert the message to a byte array
            $byteMessage = $($options.Encoding).GetBytes($fullSyslogMessage)

            # Determine the transport protocol and send the message
            switch ($options.Transport.ToUpperInvariant()) {
                'UDP' {
                    $udpClient = New-Object System.Net.Sockets.UdpClient
                    try {
                        # Send the message to the syslog server
                        $udpClient.Send($byteMessage, $byteMessage.Length, $options.Server, $options.Port)
                    }
                    catch {
                        Invoke-PodeHandleFailure -Message "Failed to send UDP message: $_" -FailureAction $options.FailureAction
                    }
                    finally {
                        # Close the UDP client
                        if ($udpClient) {
                            $udpClient.Close()
                        }
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
                        Invoke-PodeHandleFailure -Message "Failed to send TCP message: $_" -FailureAction $options.FailureAction
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
                        Invoke-PodeHandleFailure -Message "Failed to send secure TLS message: $_" -FailureAction $options.FailureAction
                    }
                    finally {
                        # Close the TCP client
                        if ($sslStream) { $sslStream.Close() }
                        if ($tcpClient) { $tcpClient.Close() }
                    }
                }
            }
        }
    }
}

<#
.SYNOPSIS
Defines the method for sending log messages to a Restful API endpoint.

.DESCRIPTION
This internal function handles the sending of log messages to Restful API endpoints for platforms like Splunk and Log Insight. It formats log messages, manages headers, and includes error handling based on user-defined actions.

.PARAMETER item
The log item to be sent to the Restful API endpoint.

.PARAMETER options
A hashtable containing options for the Restful API message including BaseUrl, Platform, Token, Id, Hostname, Source, and FailureAction.

.PARAMETER rawItem
The raw log item, used to determine additional fields such as log level and timestamp.

.NOTES
This is an internal function and may change in future releases of Pode.
#>
function Get-PodeLoggingRestfulMethod {
    return {
        param($item, $options, $rawItem)

        if ($item -isnot [array]) {
            $item = @($item)
        }

        if ($rawItem -isnot [array]) {
            $rawItem = @($rawItem)
        }

        # Determine the transport protocol and send the message
        switch ($options.Platform) {
            'Splunk' {
                # Construct the Splunk API URL
                $url = "$($options.BaseUrl)/services/collector"

                $headers = @{
                    'Authorization' = "Splunk $($options.Token)"
                    'Content-Type'  = 'application/json'
                }

                $items = @()
                for ($i = 0; $i -lt $item.Length; $i++) {
                    # Mask values
                    $message = ($item[$i] | Protect-PodeLogItem)
                    if ([string]::IsNullOrWhiteSpace($rawItem[$i].Level)) {
                        $severity = 'INFO'
                    }
                    else {
                        $severity = $rawItem[$i].Level.ToUpperInvariant()
                    }
                    $items += ConvertTo-Json -Compress -InputObject @{
                        event  = $message
                        host   = $PodeContext.Server.ComputerName
                        source = $options.source
                        time   = [math]::Round(($rawItem[$i].Date).ToUniversalTime().Subtract(([datetime]::UnixEpoch)).TotalSeconds)
                        fields = @{
                            severity = $severity
                        }
                    }

                    $Body = $items -join ' '

                    try {
                        Invoke-RestMethod -Uri $splunkUrl -Method Post -Headers $headers -Body $body -SkipCertificateCheck:$options.SkipCertificateCheck
                    }
                    catch {
                        Invoke-PodeHandleFailure -Message "Failed to send log to Splunk: $_" -FailureAction $options.FailureAction
                    }

                    break
                }
            }

            'LogInsight' {
                # Construct the Log Insight API URL
                $url = "$($options.BaseUrl)/api/v1/messages/ingest/$($options.Id)"

                $headers = @{
                    'Content-Type' = 'application/json'
                }
                $messages = @()
                for ($i = 0; $i -lt $item.Length; $i++) {
                    $messages += @{
                        text      = $message
                        timestamp = [math]::Round(($rawItem[$i].Date).ToUniversalTime().Subtract(([datetime]::UnixEpoch)).TotalSeconds)
                    }
                }
                # Define the message payload
                $payload = @{
                    messages = $messages
                }

                # Convert payload to JSON
                $body = $payload | ConvertTo-Json   -Compress

                # Send the message to Log Insight
                try {
                    Invoke-RestMethod -Uri $url -Method Post -Body $body -Headers $headers -SkipCertificateCheck:$options.SkipCertificateCheck
                }
                catch {
                    Invoke-PodeHandleFailure -Message "Failed to send log to LogInsight: $_" -FailureAction $options.FailureAction
                }

                break
            }
        }
    }
}



<#
.SYNOPSIS
Defines the method for sending log messages to the Windows Event Viewer.

.DESCRIPTION
This internal function handles the sending of log messages to the Windows Event Viewer, converting log levels and creating event log entries. It includes error handling based on user-defined actions.

.PARAMETER item
The log item to be sent to the Event Viewer.

.PARAMETER options
A hashtable containing options for the Event Viewer message including LogName, Source, ID, and FailureAction.

.PARAMETER rawItem
The raw log item, used to determine the log level.

.NOTES
This is an internal function and may change in future releases of Pode.
#>
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
                Invoke-PodeHandleFailure -Message "Failed to write an Event Viewer message: $_" -FailureAction $options.FailureAction
            }
        }
    }
}
<#
.SYNOPSIS
Converts a log level string to a corresponding EventLogEntryType.

.DESCRIPTION
This internal function converts a provided log level string to the corresponding `System.Diagnostics.EventLogEntryType` enumeration value.
It defaults to `Information` if the level is empty or unrecognized.

.PARAMETER Level
The log level string to be converted (e.g., 'error', 'warning').

.RETURNS
Returns a `System.Diagnostics.EventLogEntryType` enumeration value corresponding to the provided log level.

.NOTES
This is an internal function and may change in future releases of Pode.
#>
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
        [ValidateSet('Errors', 'Requests', 'General', 'Main')]
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

                switch ($options.LogFormat.ToLowerInvariant()) {
                    'extended' {
                        return "$($item.Date.ToString('yyyy-MM-dd')) $($item.Date.ToString('HH:mm:ss')) $(sg $item.Host) $(sg $item.User) $(sg $item.Request.Method) $(sg $item.Request.Resource) $(sg $item.Request.Query)  $(sg $item.Response.StatusCode) $(sg $item.Response.Size) `"$(sg $item.Request.Agent)`""
                    }
                    'combined' {
                        # build the url with http method
                        $url = "$(sg $item.Request.Method) $(sg $item.Request.Resource) $(sg $item.Request.Protocol)"
                        $date = [regex]::Replace(($item.Date.ToString('dd/MMM/yyyy:HH:mm:ss zzz')), '([+-]\d{2}):(\d{2})', '$1$2')
                        # build and return the request row
                        return "$(sg $item.Host) $(sg $item.RfcUserIdentity) $(sg $item.User) [$date] `"$($url)`" $(sg $item.Response.StatusCode) $(sg $item.Response.Size) `"$(sg $item.Request.Referrer)`" `"$(sg $item.Request.Agent)`""

                    }
                    'common' {
                        # build the url with http method
                        $url = "$(sg $item.Request.Method) $(sg $item.Request.Resource) $(sg $item.Request.Protocol)"
                        $date = [regex]::Replace(($item.Date.ToString('dd/MMM/yyyy:HH:mm:ss zzz')), '([+-]\d{2}):(\d{2})', '$1$2')
                        return "$(sg $item.Host) $(sg $item.RfcUserIdentity) $(sg $item.User) [$date] `"$($url)`" $(sg $item.Response.StatusCode) $(sg $item.Response.Size)"
                    }
                    'json' {
                        return "{`"time`": `"$($item.Date.ToString('yyyy-MM-ddTHH:mm:ssK'))`",`"remote_ip`": `"$(sg $item.Host)`",`"user`": `"$(sg $item.User)`",`"method`": `"$(sg $item.Request.Method)`",`"uri`": `"$(sg $item.Request.Resource)`",`"query`": `"$(sg $item.Request.Query)`",`"status`": $(sg $item.Response.StatusCode),`"response_size`": $(sg $item.Response.Size),`"user_agent`": `"$(sg $item.Request.Agent)`"}"
                    }
                }
                return $item
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
                    "Date: $($item.Date.ToString($options.DataFormat))",
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
        'general' {
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

                return "[$($item.Date.ToString($options.DataFormat))] $($item.Level) $( $item.Tag) $($item.ThreadId) $($item.Message)"
            }
        }
        'main' {
            $script = {
                param($item, $options)
                # just return the item if Raw is set
                if ($options.Raw) {
                    return $item
                }
                return "[$($item.Date.ToString($options.DataFormat))] $($item.Level) $( $item.Tag) $($item.ThreadId) $($item.Message)"
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

function Get-PodeMainLoggingName {
    return '__pode_log_main__'
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



function Test-PodeStandardLogger {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    return $PodeContext.Server.Logging.Types[$Name].Standard
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

    if ($PodeContext.Server.Logging.Types[$Name].Method.Arguments.AsUTC) {
        $date = [datetime]::UtcNow
    }
    else {
        $date = [datetime]::Now
    }

    # build a request object
    $item = @{
        Host            = $Request.RemoteEndPoint.Address.IPAddressToString
        RfcUserIdentity = '-'
        User            = '-'
        Date            = $Date
        Request         = @{
            Method   = $Request.HttpMethod.ToUpperInvariant()
            Resource = $Path
            Protocol = "HTTP/$($Request.ProtocolVersion)"
            Referrer = $Request.UrlReferrer
            Agent    = $Request.UserAgent
            Query    = ($Request.url -split '\?')[1]
        }
        Response        = @{
            StatusCode        = $Response.StatusCode
            StatusDescription = $Response.StatusDescription
            Size              = '-'
        }
        Level           = 'info'
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


function Write-PodeMainLog {
    [CmdletBinding()]
    param(
        [string]
        $Operation,

        [hashtable]
        $Parameters
    )

    # do nothing if logging is disabled, or error logging isn't setup
    $name = Get-PodeMainLoggingName
    if (!(Test-PodeLoggerEnabled -Name $name)) {
        return
    }
    $Message = if ($Parameters) {
        $paramString = ($Parameters.GetEnumerator() | ForEach-Object {
                if ($_.Value -is [scriptblock]) {
                    "$($_.Key)=<ScriptBlock>"
                }
                elseif ($_.Key -eq 'Route') {
                    "$($_.Key)={ Path : `"$($_.Value.Path -join ',')`" ,Method : `"$($_.Value.Method -join ',')`" }"
                }
                else {
                    "$($_.Key)=$($_.Value)"
                }
            }) -join ', '

        "Operation $Operation invoked with parameters: $paramString"
    }
    else {
        "Operation $Operation invoked with no parameters"
    }

    if ($PodeContext.Server.Logging.Types[$Name].Method.Arguments.AsUTC) {
        $date = [datetime]::UtcNow
    }
    else {
        $date = [datetime]::Now
    }

    # build   object for what we need
    $item = @{
        Parameters = $Parameters
        Message    = $Message
        Operation  = $Operation
        Level      = 'Info'
        Server     = $PodeContext.Server.ComputerName
        Tag        = 'Main'
        Date       = $date
        ThreadId   = [System.Threading.Thread]::CurrentThread.ManagedThreadId
    }

    # add the item to be processed
    $null = $PodeContext.LogsToProcess.Add(@{
            Name = $name
            Item = $item
        })


}