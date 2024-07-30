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
        param($MethodId)

        ([System.Management.Automation.Runspaces.Runspace]::DefaultRunspace).Name = "LoggingTerminalMethod_$MethodId"

        if ($PodeContext.Server.Quiet) {
            return
        }

        $log = @{}
        while (!$PodeContext.Tokens.Cancellation.IsCancellationRequested) {
            Start-Sleep -Milliseconds 100

            if ($PodeContext.Server.Logging.Method[$MethodId].Queue.TryDequeue([ref]$log)) {
                if ($null -ne $log) {
                    $item = $log.item
                    # check if it's an array from batching
                    if ($item -is [array]) {
                        $item = ($item -join [System.Environment]::NewLine)
                    }

                    # protect then write
                    $item = ($item | Protect-PodeLogItem)
                    $item.ToString() | Out-PodeHost
                }
            }
        }
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
        param($MethodId)

        # Set the name of the default runspace
        ([System.Management.Automation.Runspaces.Runspace]::DefaultRunspace).Name = "LoggingFileMethod_$MethodId"
        $log = @{}
        while (!$PodeContext.Tokens.Cancellation.IsCancellationRequested) {
            Start-Sleep -Milliseconds 100

            if ($PodeContext.Server.Logging.Method[$MethodId].Queue.TryDequeue([ref]$log)) {
                if ($null -ne $log) {

                    try {
                        $item = $log.item
                        $options = $log.options

                        # Check if the item is an array from batching
                        if ($item -is [array]) {
                            $item = ($item -join [System.Environment]::NewLine)
                        }

                        # Mask values
                        $item = ($item | Protect-PodeLogItem)

                        # Variables
                        $date = [DateTime]::Now.ToString('yyyy-MM-dd')

                        # Reset the fileId if the date has changed
                        if ($options.Date -ine $date) {
                            $options.Date = $date
                            $options.FileId = 0
                        }

                        # Get the fileId if it hasn't been set
                        if ($options.FileId -eq 0) {
                            $path = [System.IO.Path]::Combine($options.Path, "$($options.Name)_$($date)_*.log")
                            $options.FileId = (@(Get-ChildItem -Path $path)).Length
                            if ($options.FileId -eq 0) {
                                $options.FileId = 1
                            }
                        }

                        $id = "$($options.FileId)".PadLeft(3, '0')

                        # Check if file size exceeds MaxSize and increment fileId if necessary
                        if ($options.MaxSize -gt 0) {
                            $path = [System.IO.Path]::Combine($options.Path, "$($options.Name)_$($date)_$($id).log")
                            if ((Get-Item -Path $path -Force).Length -ge $options.MaxSize) {
                                $options.FileId++
                                $id = "$($options.FileId)".PadLeft(3, '0')
                            }
                        }

                        # Get the file to write to
                        $path = [System.IO.Path]::Combine($options.Path, "$($options.Name)_$($date)_$($id).log")

                        # Write the item to the file
                        $item.ToString() | Out-File -FilePath $path -Encoding utf8 -Append -Force

                        # Remove log files beyond the MaxDays retention period, ensuring this runs once a day
                        if (($options.MaxDays -gt 0) -and ($options.NextClearDown -lt [DateTime]::Now.Date)) {
                            $date = [DateTime]::Now.Date.AddDays(-$options.MaxDays)

                            $null = Get-ChildItem -Path $options.Path -Filter '*.log' -Force |
                                Where-Object { $_.CreationTime -lt $date } |
                                Remove-Item $_ -Force

                            $options.NextClearDown = [DateTime]::Now.Date.AddDays(1)
                        }
                    }
                    catch {
                        Invoke-PodeHandleFailure -Message "Failed to log a message: $_" -FailureAction $options.FailureAction
                    }
                }
            }
        }
    }
}


<#
.SYNOPSIS
    Handles the sending of log messages to a Syslog server using various transport protocols.

.DESCRIPTION
    This function defines the logic for sending log messages to a Syslog server using different transport protocols including UDP, TCP, TLS, Splunk, and VMware LogInsight.
    It supports both RFC 3164 and RFC 5424 formats and includes error handling based on user-defined actions.

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function Get-PodeLoggingSysLogMethod {
    return {
        param($MethodId)

        # Helper function to sanitize and return a default value if the input is null or whitespace
        function sg($value) {
            if ([string]::IsNullOrWhiteSpace($value)) {
                return '-'
            }
            return $value
        }

        # Set the name of the default runspace
        ([System.Management.Automation.Runspaces.Runspace]::DefaultRunspace).Name = "LoggingSysLogMethod_$MethodId"
        $log = @{}
        $socketCreated = $false
        try {
            while (!$PodeContext.Tokens.Cancellation.IsCancellationRequested) {
                Start-Sleep -Milliseconds 100

                if ($PodeContext.Server.Logging.Method[$MethodId].Queue.TryDequeue([ref]$log)) {
                    $item = $log.item
                    $options = $log.options
                    $rawItem = $log.rawItem
                    if ($item -isnot [array]) {
                        $item = @($item)
                    }

                    if ($rawItem -isnot [array]) {
                        $rawItem = @($rawItem)
                    }

                    # Create the socket if it hasn't been created already
                    if (!$socketCreated) {
                        switch ($options.Transport.ToUpperInvariant()) {
                            'UDP' {
                                $udpClient = New-Object System.Net.Sockets.UdpClient
                            }
                            'TCP' {
                                # Create a TCP client for non-secure communication
                                $tcpClient = New-Object System.Net.Sockets.TcpClient
                                $tcpClient.Connect($options.Server, $options.Port)
                                $networkStream = $tcpClient.GetStream()
                            }
                            'TLS' {
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
                            }
                            default {
                                $udpClient = New-Object System.Net.Sockets.UdpClient
                            }
                        }
                        $socketCreated = $true
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
                                $message = $item[$i] | ConvertTo-Json -Compress -Depth 2 -ErrorAction SilentlyContinue
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
                                # Assemble the full syslog formatted message
                                $timestamp = $rawItem[$i].Date.ToString('MMM dd HH:mm:ss')
                                $fullSyslogMessage = "<$priority>$timestamp $($PodeContext.Server.ComputerName) $($options.Source)[$processId]: $message"
                                break
                            }
                            'RFC5424' {
                                $processId = $PID
                                $timestamp = $rawItem[$i].Date.ToString('yyyy-MM-ddTHH:mm:ss.ffffffK')

                                # Assemble the full syslog formatted message
                                $fullSyslogMessage = "<$priority>1 $timestamp $($PodeContext.Server.ComputerName) $($options.Source) $processId - - $message"

                                # Set the max message length per RFC 5424 section 6.1
                                $MaxLength = 2048

                                break
                            }
                            default {
                                # The Syslog protocol can use only RFC3164 or RFC5424.
                                throw ($PodeLocale.syslogProtocolExceptionMessage)
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
                                try {
                                    # Send the message to the syslog server
                                    $udpClient.Send($byteMessage, $byteMessage.Length, $options.Server, $options.Port)
                                }
                                catch {
                                    Invoke-PodeHandleFailure -Message "Failed to send UDP message: $_" -FailureAction $options.FailureAction
                                }
                            }
                            'TCP' {
                                try {
                                    # Send the message
                                    $networkStream.Write($byteMessage, 0, $byteMessage.Length)
                                    $networkStream.Flush()
                                }
                                catch {
                                    Invoke-PodeHandleFailure -Message "Failed to send TCP message: $_" -FailureAction $options.FailureAction
                                }
                            }
                            'TLS' {
                                try {
                                    # Send the message
                                    $sslStream.Write($byteMessage)
                                    $sslStream.Flush()
                                }
                                catch {
                                    Invoke-PodeHandleFailure -Message "Failed to send secure TLS message: $_" -FailureAction $options.FailureAction
                                }
                            }
                        }
                    }
                }
            }
        }
        finally {
            # Close the sockets and cleanup
            switch ($options.Transport.ToUpperInvariant()) {
                'UDP' {
                    # Close the UDP client
                    if ($udpClient) {
                        $udpClient.Close()
                    }
                }
                'TCP' {
                    # Close the TCP client
                    if ($networkStream) { $networkStream.Close() }
                    if ($tcpClient) { $tcpClient.Close() }
                }
                'TLS' {
                    # Close the TCP client
                    if ($sslStream) { $sslStream.Close() }
                    if ($tcpClient) { $tcpClient.Close() }
                }
            }
            $socketCreated = $false
        }
    }
}
<#
.SYNOPSIS
Defines the method for sending log messages to a Restful API endpoint.

.DESCRIPTION
This internal function handles the sending of log messages to Restful API endpoints for platforms like Splunk and Log Insight. It formats log messages, manages headers, and includes error handling based on user-defined actions.

.NOTES
This is an internal function and may change in future releases of Pode.
#>
function Get-PodeLoggingRestfulMethod {
    return {
        param($MethodId)

        # Set the name of the default runspace
        ([System.Management.Automation.Runspaces.Runspace]::DefaultRunspace).Name = "LoggingRestfulMethod_$MethodId"
        $log = @{}
        while (!$PodeContext.Tokens.Cancellation.IsCancellationRequested) {
            Start-Sleep -Milliseconds 100

            if ($PodeContext.Server.Logging.Method[$MethodId].Queue.TryDequeue([ref]$log)) {
                if ($null -ne $log) {
                    $item = $log.item
                    $options = $log.options
                    $rawItem = $log.rawItem

                    # Ensure item and rawItem are arrays
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

                            # Set the headers for Splunk
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
                            }

                            $body = $items -join ' '

                            # Send the message to Splunk
                            try {
                                Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $body -SkipCertificateCheck:$options.SkipCertificateCheck
                            }
                            catch {
                                Invoke-PodeHandleFailure -Message "Failed to send log to Splunk: $_" -FailureAction $options.FailureAction
                            }

                            break
                        }

                        'LogInsight' {
                            # Construct the Log Insight API URL
                            $url = "$($options.BaseUrl)/api/v1/messages/ingest/$($options.Id)"

                            # Set the headers for Log Insight
                            $headers = @{
                                'Content-Type' = 'application/json'
                            }
                            $messages = @()
                            for ($i = 0; $i -lt $item.Length; $i++) {
                                $messages += @{
                                    text      = ($item[$i] | Protect-PodeLogItem)
                                    timestamp = [math]::Round(($rawItem[$i].Date).ToUniversalTime().Subtract(([datetime]::UnixEpoch)).TotalSeconds)
                                }
                            }

                            # Define the message payload
                            $payload = @{
                                messages = $messages
                            }

                            # Convert payload to JSON
                            $body = $payload | ConvertTo-Json -Compress

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
        }
    }
}

<#
.SYNOPSIS
Defines the method for sending log messages to the Windows Event Viewer.

.DESCRIPTION
This internal function handles the sending of log messages to the Windows Event Viewer, converting log levels and creating event log entries. It includes error handling based on user-defined actions.

.NOTES
This is an internal function and may change in future releases of Pode.
#>
function Get-PodeLoggingEventViewerMethod {
    return {
        param($MethodId)

        # Set the name of the default runspace
        ([System.Management.Automation.Runspaces.Runspace]::DefaultRunspace).Name = "LoggingEventViewerMethod_$MethodId"
        $log = @{}
        while (!$PodeContext.Tokens.Cancellation.IsCancellationRequested) {
            Start-Sleep -Milliseconds 100

            if ($PodeContext.Server.Logging.Method[$MethodId].Queue.TryDequeue([ref]$log)) {
                if ($null -ne $log) {
                    $item = $log.item
                    $options = $log.options
                    $rawItem = $log.rawItem

                    # Ensure item and rawItem are arrays
                    if ($item -isnot [array]) {
                        $item = @($item)
                    }

                    if ($rawItem -isnot [array]) {
                        $rawItem = @($rawItem)
                    }

                    for ($i = 0; $i -lt $item.Length; $i++) {
                        # Convert log level to Event Viewer entry type - default to 'Information' if no level present
                        $entryType = ConvertTo-PodeEventViewerLevel -Level $rawItem[$i].Level

                        # Create EventInstance for the log entry
                        $entryInstance = [System.Diagnostics.EventInstance]::new($options.ID, 0, $entryType)

                        # Create EventLog object and set the log name and source
                        $entryLog = [System.Diagnostics.EventLog]::new()
                        $entryLog.Log = $options.LogName
                        $entryLog.Source = $options.Source

                        try {
                            # Mask values and write the event to the Event Viewer
                            $message = ($item[$i] | Protect-PodeLogItem)
                            $entryLog.WriteEvent($entryInstance, $message)
                        }
                        catch {
                            Invoke-PodeHandleFailure -Message "Failed to write an Event Viewer message: $_" -FailureAction $options.FailureAction
                        }
                    }
                }
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

<#
.SYNOPSIS
Gets the script block for a specified inbuilt logging type.

.DESCRIPTION
This function returns a script block that formats log entries for a specified inbuilt logging type in Pode. The supported types are 'Errors', 'Requests', 'General', and 'Main'. Each type has its own formatting logic.

.PARAMETER Type
The type of logging to get the script block for. Must be one of 'Errors', 'Requests', 'General', or 'Main'.

.EXAMPLE
$script = Get-PodeLoggingInbuiltType -Type 'Requests'

.EXAMPLE
$script = Get-PodeLoggingInbuiltType -Type 'Errors'
#>
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

                # Just return the item if Raw is set
                if ($options.Raw) {
                    return $item
                }

                # Helper function to sanitize and return a default value if the input is null or whitespace
                function sg($value) {
                    if ([string]::IsNullOrWhiteSpace($value)) {
                        return '-'
                    }
                    return $value
                }

                switch ($options.LogFormat.ToLowerInvariant()) {
                    'extended' {
                        return "$($item.Date.ToString('yyyy-MM-dd')) $($item.Date.ToString('HH:mm:ss')) $(sg $item.Host) $(sg $item.User) $(sg $item.Request.Method) $(sg $item.Request.Resource) $(sg $item.Request.Query) $(sg $item.Response.StatusCode) $(sg $item.Response.Size) `"$(sg $item.Request.Agent)`""
                    }
                    'common' {
                        # Build the URL with HTTP method
                        $url = "$(sg $item.Request.Method) $(sg $item.Request.Resource) $(sg $item.Request.Protocol)"
                        $date = [regex]::Replace(($item.Date.ToString('dd/MMM/yyyy:HH:mm:ss zzz')), '([+-]\d{2}):(\d{2})', '$1$2')
                        return "$(sg $item.Host) $(sg $item.RfcUserIdentity) $(sg $item.User) [$date] `"$($url)`" $(sg $item.Response.StatusCode) $(sg $item.Response.Size)"
                    }
                    'json' {
                        return "{`"time`": `"$($item.Date.ToString('yyyy-MM-ddTHH:mm:ssK'))`",`"remote_ip`": `"$(sg $item.Host)`",`"user`": `"$(sg $item.User)`",`"method`": `"$(sg $item.Request.Method)`",`"uri`": `"$(sg $item.Request.Resource)`",`"query`": `"$(sg $item.Request.Query)`",`"status`": $(sg $item.Response.StatusCode),`"response_size`": $(sg $item.Response.Size),`"user_agent`": `"$(sg $item.Request.Agent)`"}"
                    }
                    # Combined is the default
                    default {
                        # Build the URL with HTTP method
                        $url = "$(sg $item.Request.Method) $(sg $item.Request.Resource) $(sg $item.Request.Protocol)"
                        $date = [regex]::Replace(($item.Date.ToString('dd/MMM/yyyy:HH:mm:ss zzz')), '([+-]\d{2}):(\d{2})', '$1$2')
                        # Build and return the request row
                        return "$(sg $item.Host) $(sg $item.RfcUserIdentity) $(sg $item.User) [$date] `"$($url)`" $(sg $item.Response.StatusCode) $(sg $item.Response.Size) `"$(sg $item.Request.Referrer)`" `"$(sg $item.Request.Agent)`""
                    }
                }
                return $item
            }
        }

        'errors' {
            $script = {
                param($item, $options)

                # Do nothing if the error level isn't present
                if (@($options.Levels) -inotcontains $item.Level) {
                    return
                }

                # Just return the item if Raw is set
                if ($options.Raw) {
                    return $item
                }

                # Build the exception details
                $row = @(
                    "Date: $($item.Date.ToString($options.DataFormat))",
                    "Level: $($item.Level)",
                    "ThreadId: $($item.ThreadId)",
                    "Server: $($item.Server)",
                    "Category: $($item.Category)",
                    "Message: $($item.Message)",
                    "StackTrace: $($item.StackTrace)"
                )

                # Join the details and return
                return "$($row -join "`n")`n"
            }
        }

        'general' {
            $script = {
                param($item, $options)

                # Do nothing if the error level isn't present
                if (@($options.Levels) -inotcontains $item.Level) {
                    return
                }

                # Just return the item if Raw is set
                if ($options.Raw) {
                    return $item
                }

                return "[$($item.Date.ToString($options.DataFormat))] $($item.Level) $( $item.Tag) $($item.ThreadId) $($item.Message)"
            }
        }

        'main' {
            $script = {
                param($item, $options)

                # Just return the item if Raw is set
                if ($options.Raw) {
                    return $item
                }

                return "[$($item.Date.ToString($options.DataFormat))] $($item.Level) $( $item.Tag) $($item.ThreadId) $($item.Message)"
            }
        }
    }

    return $script
}

<#
.SYNOPSIS
Gets the name of the request logger.

.DESCRIPTION
This function returns the name of the logger used for logging requests in Pode.

.RETURNS
[string] - The name of the request logger.

.EXAMPLE
Get-PodeRequestLoggingName
#>
function Get-PodeRequestLoggingName {
    # Return the name of the request logger
    return '__pode_log_requests__'
}

<#
.SYNOPSIS
Gets the name of the error logger.

.DESCRIPTION
This function returns the name of the logger used for logging errors in Pode.

.RETURNS
[string] - The name of the error logger.

.EXAMPLE
Get-PodeErrorLoggingName
#>
function Get-PodeErrorLoggingName {
    # Return the name of the error logger
    return '__pode_log_errors__'
}

<#
.SYNOPSIS
Gets the name of the main logger.

.DESCRIPTION
This function returns the name of the main logger used in Pode.

.RETURNS
[string] - The name of the main logger.

.EXAMPLE
Get-PodeMainLoggingName
#>
function Get-PodeMainLoggingName {
    # Return the name of the main logger
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

    return $PodeContext.Server.Logging.Type[$Name]
}

<#
.SYNOPSIS
Tests if a specified logger is a standard logger.

.DESCRIPTION
This function checks if the specified logger is configured as a standard logger in the Pode context.

.PARAMETER Name
The name of the logger to test.

.OUTPUTS
[bool] - Returns $true if the logger is a standard logger, otherwise $false.

.EXAMPLE
Test-PodeStandardLogger -Name 'MyLogger'
#>
function Test-PodeStandardLogger {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    # Check if the specified logger is a standard logger
    return $PodeContext.Server.Logging.Type[$Name].Standard
}

<#
.SYNOPSIS
Tests if a specified logger is enabled.

.DESCRIPTION
This function checks if the specified logger is enabled by testing if logging is enabled in the Pode context and if the logger exists.

.PARAMETER Name
The name of the logger to test.

.EXAMPLE
Test-PodeLoggerEnabled -Name 'MyLogger'
#>
function Test-PodeLoggerEnabled {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    # Check if logging is enabled and if the specified logger exists
    return ($PodeContext.Server.Logging.Enabled -and $PodeContext.Server.Logging.Type.ContainsKey($Name))
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

<#
.SYNOPSIS
Tests if error logging is enabled.

.DESCRIPTION
This function checks if error logging is enabled by testing the logger configuration for error logging.

.EXAMPLE
Test-PodeErrorLoggingEnabled
#>
function Test-PodeErrorLoggingEnabled {
    # Get the name of the error logger and test if it is enabled
    return (Test-PodeLoggerEnabled -Name (Get-PodeErrorLoggingName))
}

<#
.SYNOPSIS
Tests if request logging is enabled.

.DESCRIPTION
This function checks if request logging is enabled by testing the logger configuration for request logging.

.EXAMPLE
Test-PodeRequestLoggingEnabled
#>
function Test-PodeRequestLoggingEnabled {
    # Get the name of the request logger and test if it is enabled
    return (Test-PodeLoggerEnabled -Name (Get-PodeRequestLoggingName))
}


<#
.SYNOPSIS
Writes a log entry for a Pode web request.

.DESCRIPTION
This function writes a log entry for a Pode web request. It logs details about the request and response, including method, resource, status code, and user information. The log entry is enqueued for processing if logging is enabled.

.PARAMETER Request
The Pode web request object.

.PARAMETER Response
The Pode web response object.

.PARAMETER Path
The path of the request.

.EXAMPLE
Write-PodeRequestLog -Request $webEvent.Request -Response $webEvent.Response -Path $webEvent.Path
#>
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

    # Do nothing if logging is disabled, or request logging isn't set up
    $name = Get-PodeRequestLoggingName
    if (!(Test-PodeLoggerEnabled -Name $name)) {
        return
    }

    # Determine the current date and time, respecting the AsUTC setting
    if ($PodeContext.Server.Logging.Type[$Name].Method.Arguments.AsUTC) {
        $date = [datetime]::UtcNow
    }
    else {
        $date = [datetime]::Now
    }

    # Build a request object
    $item = @{
        Host            = $Request.RemoteEndPoint.Address.IPAddressToString
        RfcUserIdentity = '-'
        User            = '-'
        Date            = $date
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

    # Set size if >0
    if ($Response.ContentLength64 -gt 0) {
        $item.Response.Size = $Response.ContentLength64
    }

    # Set username - dot spaces
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

    # Add the item to be processed
    $null = $PodeContext.Server.Logging.LogsToProcess.Enqueue(@{
            Name = $name
            Item = $item
        })
}


<#
.SYNOPSIS
Adds request logging endware to a Pode web event.

.DESCRIPTION
This function adds endware to a Pode web event for logging request and response details. It checks if request logging is enabled and configured before attaching the logging logic to the web event's end handler.

.PARAMETER WebEvent
The Pode web event to which the logging endware will be added.

.EXAMPLE
Add-PodeRequestLogEndware -WebEvent $webEvent
#>
function Add-PodeRequestLogEndware {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        $WebEvent
    )

    # Do nothing if logging is disabled, or request logging isn't set up
    $name = Get-PodeRequestLoggingName
    if (!(Test-PodeLoggerEnabled -Name $name)) {
        return
    }

    # Add the request logging endware
    $WebEvent.OnEnd += @{
        Logic = {
            Write-PodeRequestLog -Request $WebEvent.Request -Response $WebEvent.Response -Path $WebEvent.Path
        }
    }
}

<#
.SYNOPSIS
Tests if any loggers are configured or if logging is enabled.

.DESCRIPTION
This function checks if any loggers are configured or if logging is enabled within the Pode context. It returns a boolean value indicating the presence of configured loggers or the status of logging.

.EXAMPLE
Test-PodeLoggersExist
#>
function Test-PodeLoggersExist {
    # Check if the logging context or logging types are null
    if (($null -eq $PodeContext.Server.Logging) -or ($null -eq $PodeContext.Server.Logging.Type)) {
        return $false
    }

    # Return true if there are any logging types configured or if logging is enabled
    return (($PodeContext.Server.Logging.Type.Count -gt 0) -or ($PodeContext.Server.Logging.Enabled))
}

<#
.SYNOPSIS
Starts the Pode logger dispatcher which processes and dispatches log entries.

.DESCRIPTION
This function initializes and starts a logger dispatcher runspace that processes log entries from a queue and dispatches them to the appropriate logging methods. It handles batching of log entries and ensures that log entries are processed in a timely manner.

.EXAMPLE
Start-PodeLoggerDispatcher
#>
function Start-PodeLoggerDispatcher {
    # Skip if there are no loggers configured, or logging is disabled
    if (!(Test-PodeLoggersExist)) {
        return
    }

    $scriptBlock = {
        ([System.Management.Automation.Runspaces.Runspace]::DefaultRunspace).Name = 'LoggerDispatcher'
        $log = @{}
        # Wait for the server to start before processing logs
        if ( Wait-PodeServerToStart) {
            while (!$PodeContext.Tokens.Cancellation.IsCancellationRequested) {
                # Check if the log queue has reached its limit
                if ($PodeContext.Server.Logging.LogsToProcess.Count -ge $PodeContext.Server.Logging.QueueLimit) {
                    Invoke-PodeHandleFailure -Message "Reached the log Queue Limit of $($PodeContext.Server.Logging.QueueLimit)" -FailureAction $logger.Method.Arguments.FailureAction
                }

                # Try to dequeue a log entry
                if ($PodeContext.Server.Logging.LogsToProcess.TryDequeue([ref]$log)) {
                    # If the log is null, check batch then sleep and skip
                    if ($null -eq $log) {
                        Start-Sleep -Milliseconds 100
                        continue
                    }

                    # Run the log item through the appropriate method
                    $logger = $PodeContext.Server.Logging.Type[$log.Name]
                    $now = [datetime]::Now

                    # Convert the log item into a writable format
                    $rawItem = $log.Item
                    $_args = @($log.Item) + @($logger.Arguments)

                    $item = @(Invoke-PodeScriptBlock -ScriptBlock $logger.ScriptBlock -Arguments $_args -UsingVariables $logger.UsingVariables -Return -Splat)

                    # Check batching
                    $batch = $logger.Method.Batch
                    if ($batch.Size -gt 1) {
                        # Add current item to batch
                        $batch.Items += $item
                        $batch.RawItems += $log.Item
                        $batch.LastUpdate = $now

                        # If the current amount of items matches the batch size, write
                        $item = $null
                        if ($batch.Items.Length -ge $batch.Size) {
                            $item = $batch.Items
                            $rawItem = $batch.RawItems
                        }

                        # If we're writing, reset the items
                        if ($null -ne $item) {
                            $batch.Items = @()
                            $batch.RawItems = @()
                        }
                    }

                    # Send the writable log item off to the log writer
                    if ($null -ne $item) {
                        foreach ($method in $logger.Method) {
                            if ($method.NoRunspace) {
                                # Legacy for custom methods
                            #    $null = Invoke-PodeScriptBlock -ScriptBlock $PodeContext.Server.Logging.Method[$method.Id].ScriptBlock -Arguments $_args -UsingVariables $method.UsingVariables -Splat
                                $_args = @(, $item) + @($method.Arguments) + @(, $rawItem)
                                $null = Invoke-PodeScriptBlock -ScriptBlock $logger.Method.ScriptBlock -Arguments $_args -UsingVariables $logger.Method.UsingVariables -Splat
                            }
                            else {
                                $_args = @{
                                    item    = $item
                                    options = $method.Arguments
                                    rawItem = $rawItem
                                }
                                $PodeContext.Server.Logging.Method[$method.Id].Queue.Enqueue($_args)
                            }
                        }
                    }

                    # Small sleep to lower CPU usage
                    Start-Sleep -Milliseconds 100
                }
                else {
                    # Check the logger batch
                    Test-PodeLoggerBatch
                    Start-Sleep -Seconds 5
                }
            }
        }
    }

    # Retrieve unique method IDs
    $uniqueMethodIds = ($PodeContext.Server.Logging.Type.values.Method.Id | Select-Object -Unique)
    if ($uniqueMethodIds.Count -gt 0) {
        # Set maximum runspaces for the logs pool
        if ($PodeContext.RunspacePools['logs'].Pool.SetMaxRunspaces($uniqueMethodIds.Count + 1)) {
            foreach ($methodId in $uniqueMethodIds) {
                if ($null -ne $PodeContext.Server.Logging.Method[$methodId]) {
                    $PodeContext.Server.Logging.Method[$methodId].Queue = [System.Collections.Concurrent.ConcurrentQueue[hashtable]]::new()
                    $PodeContext.Server.Logging.Method[$methodId].Runspace = Add-PodeRunspace -PassThru -Type Logs -ScriptBlock $PodeContext.Server.Logging.Method[$methodId].ScriptBlock -Parameters @{ MethodId = $methodId }
                }
            }
        }
    }

    # Add the logger dispatcher runspace
    Add-PodeRunspace -Type Logs -ScriptBlock $scriptBlock
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
    foreach ($logger in $PodeContext.Server.Logging.Type.Values) {
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

<#
.SYNOPSIS
    Writes an entry to the Pode trace log.

.DESCRIPTION
    Writes an entry to the Pode trace log. The entry can be based on either an operation and its parameters or a custom message.
    This function handles the formatting of log entries and enqueues them for processing.

.PARAMETER Operation
    The operation being logged.

.PARAMETER Parameters
    A hashtable of parameters associated with the operation.

.PARAMETER Message
    A custom message to log.

.EXAMPLE
    Write-PodeTraceLog -Operation 'Remove-PodeLogger' -Parameters @{ Name = 'LogName' }

.EXAMPLE
    Write-PodeTraceLog -Message 'Custom log message.'
#>
function Write-PodeTraceLog {
    [CmdletBinding(DefaultParameterSetName = 'Parameter')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Parameter')]
        [string]
        $Operation,

        [Parameter(Mandatory, ParameterSetName = 'Parameter')]
        [hashtable]
        $Parameters,

        [Parameter(Mandatory, ParameterSetName = 'Message')]
        [string]
        $Message
    )

    # Do nothing if logging is disabled, or error logging isn't set up
    $name = Get-PodeMainLoggingName
    if (!(Test-PodeLoggerEnabled -Name $name)) {
        return
    }

    # Determine the parameter set and build the log message
    switch ($PSCmdlet.ParameterSetName.ToLowerInvariant()) {
        'parameter' {
            $Message = if ($Parameters) {
                $paramString = ($Parameters.GetEnumerator() | ForEach-Object {
                        if ($_.Value -is [scriptblock]) {
                            "$($_.Key)=<ScriptBlock>"
                        }
                        elseif ($_.Key -eq 'ArgumentList') {
                            "$($_.Key)=<ArgumentList>"
                        }
                        elseif ($_.Key -eq 'Route') {
                            "$($_.Key)={ Path : `"$($_.Value.Path -join ',')`" ,Method : `"$($_.Value.Method -join ',')`" }"
                        }
                        elseif ($_.Key -eq 'ExternalDoc') {
                            "$($_.Key)=$($_.Value|ConvertTo-Json -Compress)"
                        }
                        elseif ($_.Key -eq 'Scheme') {
                            "$($_.Key)={ Name : `"$($_.Value.Name)`" , Scheme : `"$($_.Value.Scheme)`" }"
                        }
                        elseif ($_.Key -eq 'InputObject') {
                            "$($_.Key)=<InputObject>"
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
            break
        }
        'Message' {
            $Operation = '-'
            $Parameters = @{}
            break
        }
    }

    # Determine the current date and time, respecting the AsUTC setting
    if ($PodeContext.Server.Logging.Type[$Name].Method.Arguments.AsUTC) {
        $date = [datetime]::UtcNow
    }
    else {
        $date = [datetime]::Now
    }

    # Build the log item
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

    # Add the log item to the processing queue
    $null = $PodeContext.Server.Logging.LogsToProcess.Enqueue(@{
            Name = $name
            Item = $item
        })
}