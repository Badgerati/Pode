using namespace Pode.Utilities
using namespace Pode.Utilities.Logging

function Get-PodeLoggingTerminalMethod {
    return {
        param(
            [Parameter(Mandatory = $true)]
            [string]
            $MethodId,

            [Parameter(Mandatory = $true)]
            [string]
            $MethodType
        )

        if ($PodeContext.Server.Quiet) {
            return
        }

        # wait for the server to fully start
        Wait-PodeCancellationTokenRequest -Type Start

        try {
            $method = $PodeContext.Server.Logging.Methods[$MethodId]

            while (!(Test-PodeCancellationTokenRequest -Type Terminate)) {
                # check for suspension
                Test-PodeSuspensionToken

                try {
                    # try and get a log item collection
                    $logCol = $null
                    $found = $method.Queue.TryTake([ref]$logCol, $PodeContext.Tokens.Cancellation.Token)

                    if (!$found -or ($null -eq $logCol)) {
                        continue
                    }

                    $logCol | Convert-PodeLogItemToString | Protect-PodeLogItem | Out-PodeHost
                }
                catch [System.OperationCanceledException] {
                    $_ | Write-PodeErrorLog -Level Debug
                }
                catch {
                    $_ | Out-Default
                }
                finally {
                    if ($null -ne $logCol) {
                        $logCol.Dispose()
                    }
                }
            }
        }
        catch [System.OperationCanceledException] {
            $_ | Write-PodeErrorLog -Level Debug
        }
        catch {
            $_ | Out-Default
            throw
        }
    }
}

function Get-PodeLoggingFileMethod {
    return {
        param(
            [Parameter(Mandatory = $true)]
            [string]
            $MethodId,

            [Parameter(Mandatory = $true)]
            [string]
            $MethodType
        )

        # wait for the server to fully start
        Wait-PodeCancellationTokenRequest -Type Start

        try {
            $method = $PodeContext.Server.Logging.Methods[$MethodId]

            while (!(Test-PodeCancellationTokenRequest -Type Terminate)) {
                # check for suspension
                Test-PodeSuspensionToken

                try {
                    # try and get a log item
                    $logCol = $null
                    $found = $method.Queue.TryTake([ref]$logCol, $PodeContext.Tokens.Cancellation.Token)

                    if (!$found -or ($null -eq $logCol)) {
                        continue
                    }

                    # current date
                    $date = [DateTime]::Now.ToString('yyyy-MM-dd')

                    # do we need to reset the fileId?
                    if ($method.Arguments.Date -ine $date) {
                        $method.Arguments.Date = $date
                        $method.Arguments.FileId = 0
                    }

                    # get the fileId
                    if ($method.Arguments.FileId -eq 0) {
                        $path = [System.IO.Path]::Combine($method.Arguments.Path, "$($method.Arguments.Name)_$($date)_*.log")
                        $method.Arguments.FileId = (@(Get-ChildItem -Path $path)).Length
                        if ($method.Arguments.FileId -eq 0) {
                            $method.Arguments.FileId = 1
                        }
                    }

                    $id = "$($method.Arguments.FileId)".PadLeft(3, '0')
                    if ($method.Arguments.MaxSize -gt 0) {
                        $path = [System.IO.Path]::Combine($method.Arguments.Path, "$($method.Arguments.Name)_$($date)_$($id).log")
                        if ((Get-Item -Path $path -Force).Length -ge $method.Arguments.MaxSize) {
                            $method.Arguments.FileId++
                            $id = "$($method.Arguments.FileId)".PadLeft(3, '0')
                        }
                    }

                    # get the file to write to
                    $path = [System.IO.Path]::Combine($method.Arguments.Path, "$($method.Arguments.Name)_$($date)_$($id).log")

                    # write the item to the file
                    $logCol | Convert-PodeLogItemToString | Protect-PodeLogItem | Out-File -FilePath $path -Encoding utf8 -Append -Force

                    # if set, remove log files beyond days set (ensure this is only run once a day)
                    if (($method.Arguments.MaxDays -gt 0) -and ($method.Arguments.NextClearDown -le [DateTime]::Now.Date)) {
                        $date = [DateTime]::Now.Date.AddDays(-$method.Arguments.MaxDays)

                        $null = Get-ChildItem -Path $method.Arguments.Path -Filter "$($method.Arguments.Name)_*.log" -Force |
                            Where-Object { $_.CreationTime -lt $date } |
                            Remove-Item -Force

                        $method.Arguments.NextClearDown = [DateTime]::Now.Date.AddDays(1)
                    }
                }
                catch [System.OperationCanceledException] {
                    $_ | Write-PodeErrorLog -Level Debug
                }
                catch {
                    $_ | Out-Default
                }
                finally {
                    if ($null -ne $logCol) {
                        $logCol.Dispose()
                    }
                }
            }
        }
        catch [System.OperationCanceledException] {
            $_ | Write-PodeErrorLog -Level Debug
        }
        catch {
            $_ | Out-Default
        }
    }
}

function Get-PodeLoggingEventViewerMethod {
    return {
        param(
            [Parameter(Mandatory = $true)]
            [string]
            $MethodId,

            [Parameter(Mandatory = $true)]
            [string]
            $MethodType
        )

        # wait for the server to fully start
        Wait-PodeCancellationTokenRequest -Type Start

        try {
            $method = $PodeContext.Server.Logging.Methods[$MethodId]

            while (!(Test-PodeCancellationTokenRequest -Type Terminate)) {
                # check for suspension
                Test-PodeSuspensionToken

                try {
                    # try and get a log item
                    $logCol = $null
                    $found = $method.Queue.TryTake([ref]$logCol, $PodeContext.Tokens.Cancellation.Token)

                    if (!$found -or ($null -eq $logCol)) {
                        continue
                    }

                    foreach ($item in $logCol.Items) {
                        # get any overrides for this method
                        $override = Get-PodeLogOverride -LogEvent $item.Event

                        # convert log level - info if no level present
                        $entryType = ConvertTo-PodeEventViewerLevel -Level $item.Event.Level

                        # create log instance
                        $eventId = [int]$override.EventId
                        if ($eventId -eq 0) {
                            $eventId = $method.Arguments.ID
                        }

                        $entryInstance = [System.Diagnostics.EventInstance]::new($eventId, 0, $entryType)

                        # create event log
                        $entryLog = [System.Diagnostics.EventLog]::new()
                        $entryLog.Log = $method.Arguments.LogName
                        $entryLog.Source = $method.Arguments.Source

                        try {
                            $message = $item | Convert-PodeLogItemToString | Protect-PodeLogItem
                            $entryLog.WriteEvent($entryInstance, $message)
                        }
                        catch {
                            $_ | Write-PodeErrorLog -Level Debug
                        }
                    }
                }
                catch [System.OperationCanceledException] {
                    $_ | Write-PodeErrorLog -Level Debug
                }
                catch {
                    $_ | Out-Default
                }
                finally {
                    if ($null -ne $logCol) {
                        $logCol.Dispose()
                    }
                }
            }
        }
        catch [System.OperationCanceledException] {
            $_ | Write-PodeErrorLog -Level Debug
        }
        catch {
            $_ | Out-Default
            throw
        }
    }
}

function Get-PodeLoggingCustomMethod {
    return {
        param(
            [Parameter(Mandatory = $true)]
            [string]
            $MethodId,

            [Parameter(Mandatory = $true)]
            [string]
            $MethodType
        )

        # wait for the server to fully start
        Wait-PodeCancellationTokenRequest -Type Start

        try {
            $method = $PodeContext.Server.Logging.Methods[$MethodId]

            while (!(Test-PodeCancellationTokenRequest -Type Terminate)) {
                # check for suspension
                Test-PodeSuspensionToken

                try {
                    # try and get a log item
                    $logCol = $null
                    $found = $method.Queue.TryTake([ref]$logCol, $PodeContext.Tokens.Cancellation.Token)

                    if (!$found -or ($null -eq $logCol)) {
                        continue
                    }

                    # build scriptblock arguments based on the Log Method version
                    switch ($method.Version) {
                        1 {
                            $_args = @(, ($logCol.Items | Select-Object -ExpandProperty 'Data')) + @($method.Arguments) + @(, ($logCol.Items.Event | Select-Object -ExpandProperty 'Data'))
                        }

                        2 {
                            $_args = @(, $logCol.Items) + @($method.Arguments)
                        }
                    }

                    $null = Invoke-PodeScriptBlock `
                        -ScriptBlock $method.Custom.ScriptBlock `
                        -Arguments $_args `
                        -UsingVariables $method.Custom.UsingVariables `
                        -Splat
                }
                catch [System.OperationCanceledException] {
                    $_ | Write-PodeErrorLog -Level Debug
                }
                catch {
                    $_ | Out-Default
                }
                finally {
                    if ($null -ne $logCol) {
                        $logCol.Dispose()
                    }
                }
            }
        }
        catch [System.OperationCanceledException] {
            $_ | Write-PodeErrorLog -Level Debug
        }
        catch {
            $_ | Out-Default
            throw
        }
    }
}

function Get-PodeLoggingApiMethod {
    return {
        param(
            [Parameter(Mandatory = $true)]
            [string]
            $MethodId,

            [Parameter(Mandatory = $true)]
            [string]
            $MethodType
        )

        # wait for the server to fully start
        Wait-PodeCancellationTokenRequest -Type Start

        try {
            $method = $PodeContext.Server.Logging.Methods[$MethodId]

            while (!(Test-PodeCancellationTokenRequest -Type Terminate)) {
                # check for suspension
                Test-PodeSuspensionToken

                try {
                    # try and get a log item
                    $logCol = $null
                    $found = $method.Queue.TryTake([ref]$logCol, $PodeContext.Tokens.Cancellation.Token)

                    if (!$found -or ($null -eq $logCol)) {
                        continue
                    }

                    # get body
                    $body = Invoke-PodeScriptBlock `
                        -ScriptBlock $method.Arguments.Body.ScriptBlock `
                        -Arguments @((, $logCol.Items), $method.Arguments.Body.Arguments) `
                        -UsingVariables $method.Arguments.Body.UsingVariables `
                        -Splat -Return

                    if ([string]::IsNullOrWhiteSpace($body)) {
                        continue
                    }

                    if ($body -isnot [string]) {
                        # The body returned from the logging API body scriptblock is not a string
                        throw ($PodeLocale.loggingApiMethodBodyNotStringExceptionMessage)
                    }

                    $body = $body | Protect-PodeLogItem

                    # do we need to compress the body?
                    if ($method.Arguments.Compress) {
                        $body = [Pode.Utilities.PodeHelpers]::CompressString($body, [Pode.Utilities.PodeCompressionType]::Gzip)
                    }

                    # get headers
                    $headers = $method.Arguments.Headers.Value

                    if ($null -ne $method.Arguments.Headers.ScriptBlock) {
                        $addHeaders = Invoke-PodeScriptBlock `
                            -ScriptBlock $method.Arguments.Headers.ScriptBlock `
                            -Arguments @($body, $method.Arguments.Headers.Arguments) `
                            -UsingVariables $method.Arguments.Headers.UsingVariables `
                            -Splat -Return

                        if ($null -ne $addHeaders) {
                            if ($addHeaders -isnot [hashtable]) {
                                # The headers returned from the logging API headers scriptblock is not a hashtable
                                throw ($PodeLocale.loggingApiMethodHeadersNotHashtableExceptionMessage)
                            }

                            foreach ($key in $addHeaders.Keys) {
                                $headers[$key] = $addHeaders[$key]
                            }
                        }
                    }

                    # invoke the API
                    Invoke-RestMethod `
                        -Uri $method.Arguments.Url `
                        -Method $method.Arguments.Method `
                        -Headers $headers `
                        -Body $body `
                        -ContentType $method.Arguments.ContentType `
                        -SkipCertificateCheck:($method.Arguments.SkipCertificateCheck)
                }
                catch [System.OperationCanceledException] {
                    $_ | Write-PodeErrorLog -Level Debug
                }
                catch {
                    $_ | Out-Default
                }
                finally {
                    if ($null -ne $logCol) {
                        $logCol.Dispose()
                    }
                }
            }
        }
        catch [System.OperationCanceledException] {
            $_ | Write-PodeErrorLog -Level Debug
        }
        catch {
            $_ | Out-Default
            throw
        }
    }
}

function Get-PodeLoggingNetworkMethod {
    return {
        param(
            [Parameter(Mandatory = $true)]
            [string]
            $MethodId,

            [Parameter(Mandatory = $true)]
            [string]
            $MethodType
        )

        # wait for the server to fully start
        Wait-PodeCancellationTokenRequest -Type Start

        try {
            $method = $PodeContext.Server.Logging.Methods[$MethodId]

            $client = [Pode.Transport.Clients.PodeClientFactory]::Create(
                $method.Arguments.Transport,
                $method.Arguments.Server,
                $method.Arguments.Port,
                $method.Arguments.SkipCertificateCheck
            )
            $client.Connect()

            while (!(Test-PodeCancellationTokenRequest -Type Terminate)) {
                # check for suspension
                Test-PodeSuspensionToken

                try {
                    # try and get a log item
                    $logCol = $null
                    $found = $method.Queue.TryTake([ref]$logCol, $PodeContext.Tokens.Cancellation.Token)

                    if (!$found -or ($null -eq $logCol)) {
                        continue
                    }

                    # send each log item over the network
                    foreach ($item in $logCol.Items) {
                        $message = $item | Convert-PodeLogItemToString | Protect-PodeLogItem
                        $bytes = [System.Text.Encoding]::UTF8.GetBytes($message)
                        $client.Send($bytes)
                    }
                }
                catch [System.OperationCanceledException] {
                    $_ | Write-PodeErrorLog -Level Debug
                }
                catch {
                    $_ | Out-Default
                }
                finally {
                    if ($null -ne $logCol) {
                        $logCol.Dispose()
                    }
                }
            }
        }
        catch [System.OperationCanceledException] {
            $_ | Write-PodeErrorLog -Level Debug
        }
        catch {
            $_ | Out-Default
            throw
        }
        finally {
            if ($null -ne $client) {
                $client.Dispose()
            }
        }
    }
}

function New-PodeLogAzureWorkspaceMethod {
    [OutputType([string])]
    param(
        [Parameter()]
        [string]
        $Id,

        [Parameter(Mandatory = $true)]
        [string]
        $WorkspaceId,

        [Parameter(Mandatory = $true)]
        [string]
        $SharedKey,

        [Parameter(Mandatory = $true)]
        [string]
        $LogType,

        [Parameter()]
        [string]
        $Source,

        [Parameter()]
        [hashtable]
        $BatchInfo = $null,

        [switch]
        $SkipCertificateCheck
    )

    # build body scriptblock
    $bodyScriptBlock = {
        param($logItems, $options)

        # build array of events
        $events = @(foreach ($item in $logItems) {
                # build base event object
                $evt = @{
                    Data      = $item.Data
                    Level     = $item.Event.Level
                    Timestamp = $item.Event.Timestamp.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
                }

                # get any overrides for this method
                $override = Get-PodeLogOverride -LogEvent $item.Event

                # add source
                $source = Protect-PodeValue -Value $override.Source -Default $options.Source
                if (![string]::IsNullOrEmpty($source)) {
                    $evt.Source = $source
                }

                $evt
            })

        # convert to json and return
        return $events | ConvertTo-Json -Compress -Depth 10
    }

    # build headers scriptblock
    $headersScriptBlock = {
        param($body, $options)

        # the x-ms-date header
        $date = [datetime]::Now.ToString('R')

        # build signature string
        $contentLength = $body.Length
        $method = 'POST'
        $contentType = 'application/json'
        $dateHeader = "x-ms-date:$($date)"
        $urlPath = '/api/logs'
        $stringToSign = "$($method)`n$($contentLength)`n$($contentType)`n$($dateHeader)`n$($urlPath)"

        # build authorization header
        $bytesToSign = [System.Text.Encoding]::UTF8.GetBytes($stringToSign)
        $keyBytes = [System.Convert]::FromBase64String($options.SharedKey)
        $hmacsha256 = [System.Security.Cryptography.HMACSHA256]::new()
        $hmacsha256.Key = $keyBytes
        $signatureBytes = $hmacsha256.ComputeHash($bytesToSign)
        $signature = [System.Convert]::ToBase64String($signatureBytes)
        $authorizationHeader = "SharedKey $($options.WorkspaceId):$($signature)"

        return @{
            'Authorization' = $authorizationHeader
            'x-ms-date'     = $date
        }
    }

    # default headers
    $headers = @{
        'Log-Type'             = $LogType
        'time-generated-field' = 'Timestamp'
    }

    # add method to server
    $bodyArgs = @{
        Source = $Source
    }

    $headerArgs = @{
        SharedKey   = $SharedKey
        WorkspaceId = $WorkspaceId
    }

    return New-PodeLogApiMethod `
        -Id $Id `
        -Type 'Azure' `
        -BatchInfo $BatchInfo `
        -Url "https://$($WorkspaceId).ods.opinsights.azure.com/api/logs?api-version=2016-04-01" `
        -Headers $headers `
        -HeadersScriptBlock $headersScriptBlock `
        -HeadersArguments $headerArgs `
        -BodyScriptBlock $bodyScriptBlock `
        -BodyArguments $bodyArgs `
        -SkipCertificateCheck:$SkipCertificateCheck.IsPresent `
        -Compress
}

function New-PodeLogAzureDataCollectionMethod {
    [OutputType([string])]
    param(
        [Parameter()]
        [string]
        $Id,

        [Parameter(Mandatory = $true)]
        [string]
        $Endpoint,

        [Parameter(Mandatory = $true)]
        [string]
        $ImmutableId,

        [Parameter(Mandatory = $true)]
        [string]
        $StreamName,

        [Parameter(Mandatory = $true)]
        [string]
        $ClientId,

        [Parameter(Mandatory = $true)]
        [string]
        $ClientSecret,

        [Parameter(Mandatory = $true)]
        [string]
        $TenantId,

        [Parameter()]
        [string]
        $Source,

        [Parameter()]
        [hashtable]
        $BatchInfo = $null,

        [switch]
        $SkipCertificateCheck
    )

    # build body scriptblock
    $bodyScriptBlock = {
        param($logItems, $options)

        # build array of events
        $events = @(foreach ($item in $logItems) {
                # build base event object
                $evt = @{
                    Data          = $item.Data
                    Level         = $item.Event.Level
                    TimeGenerated = $item.Event.Timestamp.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
                }

                # get any overrides for this method
                $override = Get-PodeLogOverride -LogEvent $item.Event

                # add source
                $source = Protect-PodeValue -Value $override.Source -Default $options.Source
                if (![string]::IsNullOrEmpty($source)) {
                    $evt.Source = $source
                }

                $evt
            })

        # convert to json and return
        return $events | ConvertTo-Json -Compress -Depth 10
    }

    # build headers scriptblock
    $headersScriptBlock = {
        param($body, $options)

        # has the token expired? if so, generate a new one
        if ($options.Auth.ExpiryDate -lt [datetime]::Now.AddMinutes(-1)) {
            # build payload
            $payload = "client_id=$($options.Client.Id)"
            $payload += "&client_secret=$([System.Web.HttpUtility]::UrlEncode($options.Client.Secret))"
            $payload += "&scope=$([System.Web.HttpUtility]::UrlEncode('https://monitor.azure.com//.default'))"
            $payload += '&grant_type=client_credentials'

            # request token
            $uri = "https://login.microsoftonline.com/$($options.Client.TenantId)/oauth2/v2.0/token"
            $result = Invoke-RestMethod -Method Post -Uri $uri -Body $payload -ContentType 'application/x-www-form-urlencoded' -ErrorAction Stop

            # set token and new expiry
            $options.Auth.Token = $result.access_token
            $options.Auth.ExpiryDate = [datetime]::Now.AddSeconds($result.expires_in)
        }

        # return auth header
        return @{
            Authorization = "Bearer $($options.Auth.Token)"
        }
    }

    # add method to server
    $bodyArgs = @{
        Source = $Source
    }

    $headerArgs = @{
        Client = @{
            Id       = $ClientId
            Secret   = $ClientSecret
            TenantId = $TenantId
        }
        Auth   = @{
            Token      = $null
            ExpiryDate = [datetime]::MinValue
        }
    }

    return New-PodeLogApiMethod `
        -Id $Id `
        -Type 'Azure' `
        -BatchInfo $BatchInfo `
        -Url "$($Endpoint)/dataCollectionRules/$($ImmutableId)/streams/$($StreamName)?api-version=2023-01-01" `
        -HeadersScriptBlock $headersScriptBlock `
        -HeadersArguments $headerArgs `
        -BodyScriptBlock $bodyScriptBlock `
        -BodyArguments $bodyArgs `
        -SkipCertificateCheck:$SkipCertificateCheck.IsPresent `
        -Compress
}

function ConvertTo-PodeSyslogLevel {
    param(
        [Parameter()]
        [string]
        $Level
    )

    switch ($Level.ToLowerInvariant()) {
        'emergency' { return 0 }
        'alert' { return 1 }
        'critical' { return 2 }
        'error' { return 3 }
        'warning' { return 4 }
        'notice' { return 5 }
        'informational' { return 6 }
        'debug' { return 7 }
        default { return 6 } # default to informational
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

    if ($Level -iin @('emergency', 'alert', 'critical', 'error')) {
        return [System.Diagnostics.EventLogEntryType]::Error
    }

    if ($Level -iin @('warning', 'notice')) {
        return [System.Diagnostics.EventLogEntryType]::Warning
    }

    return [System.Diagnostics.EventLogEntryType]::Information
}

function ConvertTo-PodeSplunkLevel {
    param(
        [Parameter()]
        [string]
        $Level
    )

    if ([string]::IsNullOrWhiteSpace($Level)) {
        return 'info'
    }

    if ($Level -iin @('emergency', 'alert', 'critical')) {
        return 'critical'
    }

    if ($Level -ieq 'error') {
        return 'error'
    }

    if ($Level -iin @('warning', 'notice')) {
        return 'warning'
    }

    if ($Level -ieq 'debug') {
        return 'debug'
    }

    return 'info'
}

function ConvertTo-PodeDatadogLevel {
    param(
        [Parameter()]
        [string]
        $Level
    )

    if ([string]::IsNullOrWhiteSpace($Level)) {
        return 'INFO'
    }

    if ($Level -iin @('emergency', 'alert', 'critical', 'error')) {
        return 'ERROR'
    }

    if ($Level -iin @('warning', 'notice')) {
        return 'WARN'
    }

    if ($Level -ieq 'debug') {
        return 'DEBUG'
    }

    if ($Level -ieq 'verbose') {
        return 'TRACE'
    }

    return 'INFO'
}

function Get-PodeLoggingInbuiltSerialiseType {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Errors', 'Requests')]
        [string]
        $Type
    )

    switch ($Type.ToLowerInvariant()) {
        'requests' {
            return {
                param($data)
                $logType = Get-PodeLogType -Name ([PodeLogger]::REQUEST_LOG_TYPE_NAME)

                # are we dealing with common/combined?
                if ($logType.Metadata.Format -iin @('common', 'combined')) {
                    $method = Protect-PodeLogRequestItem -Value $data.Request.Method
                    $resource = Protect-PodeLogRequestItem -Value $data.Request.Resource
                    $protocol = Protect-PodeLogRequestItem -Value $data.Request.Protocol
                    $reqLine = "$($method) $($resource) $($protocol)"

                    $ip = Protect-PodeLogRequestItem -Value $data.Request.Host
                    $identifier = Protect-PodeLogRequestItem -Value $data.Request.Identifier
                    $user = Protect-PodeLogRequestItem -Value $data.Request.User
                    $date = $data.Date.ToString('dd/MMM/yyyy:HH:mm:ss zzz')
                    $statusCode = Protect-PodeLogRequestItem -Value $data.Response.Status.Code
                    $size = Protect-PodeLogRequestItem -Value $data.Response.Size

                    $baseMsg = "$($ip) $($identifier) $($user) [$($date)] `"$($reqLine)`" $($statusCode) $($size)"

                    if ($logType.Metadata.Format -ieq 'combined') {
                        $referrer = Protect-PodeLogRequestItem -Value $data.Request.Referrer
                        $userAgent = Protect-PodeLogRequestItem -Value $data.Request.UserAgent
                        $baseMsg = "$($baseMsg) `"$($referrer)`" `"$($userAgent)`""
                    }

                    return $baseMsg
                }

                # otherwise, we're dealing with W3C
                $builder = [System.Text.StringBuilder]::new()

                foreach ($field in $logType.Metadata.W3CFields) {
                    $value = switch ($field.Type) {
                        'Request' { $data.Request.Headers[$field.Name] }
                        'Response' { $data.Response.Headers[$field.Name] }
                        'Environment' { $data.Environment.Variables[$field.Name] }

                        'Standard' {
                            switch ($field.FieldName) {
                                'date' { $data.Date.ToString('yyyy-MM-dd') }
                                'time' { $data.Date.ToString('HH:mm:ss') }
                                'c-ip' { $data.Request.Host }
                                'cs-username' { $data.Request.User }
                                's-ip' { $data.Server.IP }
                                's-port' { $data.Server.Port }
                                's-computername' { $PodeContext.Server.ComputerName }
                                'cs-method' { $data.Request.Method }
                                'cs-uri-stem' { $data.Request.Resource }
                                'cs-uri-query' { $data.Request.Query }
                                'sc-status' { $data.Response.Status.Code }
                                'time-taken' { [long]$data.Duration.TotalMilliseconds }
                                'sc-bytes' { $data.Response.Size }
                                'cs-bytes' { $data.Request.Size }
                                'cs-version' { $data.Request.Protocol }
                                'cs-host' { $data.Request.Hostname }
                            }
                        }
                    }

                    $value = Protect-PodeLogRequestItem -Value $value -Encode
                    $null = $builder.Append($value).Append(' ')
                }

                return $builder.ToString()
            }
        }

        'errors' {
            return {
                param($data)
                $msg = @(foreach ($key in $data.Keys) {
                        "$($key): $($data[$key])"
                    }) -join "`n"

                return "$($msg)`n"
            }
        }
    }
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
            return {
                param(
                    [Pode.Utilities.Logging.IPodeLogEvent]
                    $logEvent
                )

                return [ordered]@{
                    Date        = $logEvent.Data.Date
                    Duration    = $logEvent.Data.Duration
                    Server      = [ordered]@{
                        IP   = $logEvent.Data.Server.IP
                        Port = $logEvent.Data.Server.Port
                    }
                    Environment = [ordered]@{
                        Variables = $logEvent.Data.Environment.Variables
                    }
                    Request     = [ordered]@{
                        Host       = $logEvent.Data.Host
                        Identifier = $logEvent.Data.RfcUserIdentity
                        User       = $logEvent.Data.User
                        Method     = $logEvent.Data.Request.Method
                        Hostname   = $logEvent.Data.Request.Hostname
                        Scheme     = $logEvent.Data.Request.Scheme
                        Resource   = $logEvent.Data.Request.Resource
                        Query      = $logEvent.Data.Request.Query
                        Protocol   = $logEvent.Data.Request.Protocol
                        Referrer   = $logEvent.Data.Request.Referrer
                        UserAgent  = $logEvent.Data.Request.Agent
                        Size       = $logEvent.Data.Request.Size
                        Headers    = $logEvent.Data.Request.Headers
                    }
                    Response    = [ordered]@{
                        Status  = [ordered]@{
                            Code        = $logEvent.Data.Response.StatusCode
                            Description = $logEvent.Data.Response.StatusDescription
                        }
                        Size    = $logEvent.Data.Response.Size
                        Headers = $logEvent.Data.Response.Headers
                    }
                }
            }
        }

        'errors' {
            return {
                param(
                    [Pode.Utilities.Logging.IPodeLogEvent]
                    $logEvent
                )

                return [ordered]@{
                    Date       = $logEvent.Data.Date.ToString('yyyy-MM-dd HH:mm:ss')
                    Level      = $logEvent.Data.Level
                    ThreadId   = $logEvent.Data.ThreadId
                    ContextId  = $logEvent.Data.ContextId
                    Server     = $logEvent.Data.Server
                    Kind       = $logEvent.Data.Kind
                    Category   = $logEvent.Data.Category
                    Message    = $logEvent.Data.Message
                    StackTrace = $logEvent.Data.StackTrace
                }
            }
        }
    }
}

function Protect-PodeLogRequestItem {
    param(
        [Parameter()]
        [object]
        $Value,

        [switch]
        $Encode
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        $Value = '-'
    }

    if ($Encode) {
        $Value = [uri]::EscapeUriString($Value)
    }

    return $Value
}

function Get-PodeLogType {
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    return $PodeContext.Server.Logging.Types[$Name]
}

function Get-PodeLogMethod {
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Id
    )

    return $PodeContext.Server.Logging.Methods[$Id]
}

function Test-PodeLogMethod {
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Id
    )

    return $PodeContext.Server.Logging.Methods.ContainsKey($Id)
}

function Get-PodeRequestLogW3CDefaultInfo {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    return New-PodeLogW3CInfo -Fields @(
        Add-PodeLogW3CField -Name 'date'
        Add-PodeLogW3CField -Name 'time'
        Add-PodeLogW3CField -Name 'c-ip'
        Add-PodeLogW3CField -Name 'cs-method'
        Add-PodeLogW3CField -Name 'cs-uri-stem'
        Add-PodeLogW3CField -Name 'cs-uri-query'
        Add-PodeLogW3CField -Name 'cs-username'
        Add-PodeLogW3CField -Name 'sc-status'
        Add-PodeLogW3CField -Name 'time-taken'
        Add-PodeLogW3CCustomField -Name 'User-Agent' -Type Request
        Add-PodeLogW3CCustomField -Name 'Referer' -Type Request
    )
}

function Write-PodeRequestLog {
    # do nothing if request logging isn't setup
    if (!$PodeContext.Server.Logging.Logger.IsRequestLoggingEnabled) {
        return
    }

    # http method
    $method = $null
    if (![string]::IsNullOrEmpty($WebEvent.Request.HttpMethod)) {
        $method = $WebEvent.Request.HttpMethod.ToUpperInvariant()
    }

    # hostname
    $hostname = $null
    if (![string]::IsNullOrEmpty($WebEvent.Request.Host)) {
        $hostname = $WebEvent.Request.Host.ToLowerInvariant()
    }

    # scheme
    $scheme = $null
    if (![string]::IsNullOrEmpty($WebEvent.Request.Handler.Scheme)) {
        $scheme = $WebEvent.Request.Handler.Scheme.ToLowerInvariant()
    }

    # duration
    $duration = [datetime]::UtcNow.Subtract($WebEvent.Timestamp)

    # query
    $query = (Protect-PodeValue -Value $WebEvent.Request.Url.Query -Default ([string]::Empty)).TrimStart('?')

    # protocol
    $protocol = "HTTP/$($WebEvent.Request.ProtocolVersion)"

    # response size
    $respSize = $null
    if ($WebEvent.Response.ContentLength64 -gt 0) {
        $respSize = $WebEvent.Response.ContentLength64
    }

    # loop through each request log type and add to the queue
    foreach ($logTypeName in $PodeContext.Server.Logging.Logger.RequestLogTypeNames) {
        $logType = Get-PodeLogType -Name $logTypeName

        # date/timestamp
        $timestamp = $WebEvent.Timestamp
        if (!$logType.Options.Formatting.AsUtc) {
            $timestamp = $timestamp.ToLocalTime()
        }

        # build a request object
        $item = @{
            Host            = $WebEvent.Request.Handler.RemoteEndPoint.Address.IPAddressToString
            RfcUserIdentity = $null
            User            = $null
            Date            = $timestamp
            UtcDate         = $WebEvent.Timestamp
            Duration        = $duration
            Server          = @{
                IP   = $WebEvent.Request.Handler.LocalEndPoint.Address.IPAddressToString
                Port = $WebEvent.Request.Handler.LocalEndPoint.Port
            }
            Environment     = @{
                Variables = @{}
            }
            Request         = @{
                Method   = $method
                Hostname = $hostname
                Scheme   = $scheme
                Resource = $WebEvent.Path
                Query    = $query
                Protocol = $protocol
                Referrer = $WebEvent.Request.UrlReferrer
                Agent    = $WebEvent.Request.UserAgent
                Size     = $WebEvent.Request.ContentLength
                Headers  = @{}
            }
            Response        = @{
                StatusCode        = $WebEvent.Response.StatusCode
                StatusDescription = $WebEvent.Response.StatusDescription
                Size              = $respSize
                Headers           = @{}
            }
        }

        # do we need to get the host address from req headers (if behind a reverse proxy)?
        $remoteIpHeaders = $logType.Metadata.RemoteIPHeader
        if (($null -ne $remoteIpHeaders) -and ($remoteIpHeaders.Count -gt 0)) {
            foreach ($header in $remoteIpHeaders) {
                if (Test-PodeHeader -Name $header) {
                    $item.Host = ((Get-PodeHeader -Name $header) -split ',')[0].Trim()
                    break
                }
            }
        }

        # set username - dot spaces
        if (Test-PodeAuthUser -IgnoreSession) {
            $userProps = $logType.Metadata.Username.Split('.')

            $user = $WebEvent.Auth.User
            foreach ($atom in $userProps) {
                $user = $user.($atom)
            }

            if (![string]::IsNullOrWhiteSpace($user)) {
                $item.User = $user -ireplace '\s+', '.'
            }
        }

        # for w3c format, we need to fetch req/resp headers, and server env vars
        if ($logType.Metadata.Format -ieq 'W3C') {
            foreach ($field in $logType.Metadata.W3CFields) {
                switch ($field.Type) {
                    'Request' {
                        if (Test-PodeHeader -Name $field.Name) {
                            $item.Request.Headers[$field.Name] = Get-PodeHeader -Name $field.Name
                        }
                    }

                    'Response' {
                        if (Test-PodeHeader -Name $field.Name -Response) {
                            $item.Response.Headers[$field.Name] = Get-PodeHeader -Name $field.Name -Response
                        }
                    }

                    'Environment' {
                        if (Test-PodeEnvironmentVariable -Name $field.Name) {
                            $item.Environment.Variables[$field.Name] = Get-PodeEnvironmentVariable -Name $field.Name
                        }
                    }
                }
            }
        }

        # add the item to be processed
        $PodeContext.Server.Logging.Logger.Add($logTypeName, [PodeLogLevel]::Informational, $item)
    }
}

function Add-PodeRequestLogEndware {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        $WebEvent
    )

    # do nothing if logging is disabled, or request logging isn't setup
    if (!$PodeContext.Server.Logging.Logger.IsRequestLoggingEnabled) {
        return
    }

    # add the request logging endware
    $WebEvent.OnEnd += @{
        Logic = {
            Write-PodeRequestLog
        }
    }
}

function Test-PodeLogTypesExist {
    if (($null -eq $PodeContext.Server.Logging) -or ($null -eq $PodeContext.Server.Logging.Types)) {
        return $false
    }

    return (($PodeContext.Server.Logging.Types.Count -gt 0) -or ($PodeContext.Server.Logging.Logger.IsEnabled))
}

function Start-PodeLoggingRunspace {
    # skip if there are no Log Types configured, or logging is disabled
    if (!(Test-PodeLogTypesExist)) {
        return
    }

    $script = {
        # Waits for the Pode server to fully start before proceeding with further operations.
        Wait-PodeCancellationTokenRequest -Type Start

        try {
            while (!(Test-PodeCancellationTokenRequest -Type Terminate)) {
                # check for suspension
                Test-PodeSuspensionToken

                try {
                    # try and remove an event from the queue, if none check batches then continue
                    $logEvent = $null
                    $found = $PodeContext.Server.Logging.Logger.TryTake([ref]$logEvent, $PodeContext.Tokens.Cancellation.Token)

                    if (!$found -or ($null -eq $logEvent)) {
                        Test-PodeLogTypeBatchTimeout
                        continue
                    }

                    # run the log item through the appropriate method
                    $logType = Get-PodeLogType -Name $logEvent.Type.Name
                    if ($null -eq $logType) {
                        continue
                    }

                    # transform the log item into a message item, unless the user wants the raw data to be passed to the Log Method
                    if ($logType.Raw) {
                        $result = $logEvent.Data
                    }
                    else {
                        # what version of the Log Type are we using? (v1 = data only, v2 = full log event)
                        switch ($logType.Version) {
                            1 {
                                $_args = @($logEvent.Data) + @($logType.Arguments)
                            }

                            2 {
                                $_args = @($logEvent) + @($logType.Arguments)
                            }
                        }

                        # transform the log event
                        $result = Invoke-PodeScriptBlock -ScriptBlock $logType.ScriptBlock -Arguments $_args -UsingVariables $logType.UsingVariables -Return -Splat
                    }

                    # little sleep if no transform result, to help lower cpu
                    if ($null -eq $result) {
                        Start-Sleep -Milliseconds 100
                        continue
                    }

                    # transform the result into a specified serialisation format (None just leaves "result" as it - no serialising)
                    switch ($logType.Options.Formatting.Serialise.Type) {
                        'Json' {
                            $result = $result | ConvertTo-Json -Depth 10 -Compress
                        }

                        'Xml' {
                            $result = $result | ConvertTo-PodeXml -Depth 10 -RootName $logType.Options.Formatting.Serialise.XmlRootName -Compress
                        }

                        'Yaml' {
                            $result = $result | ConvertTo-PodeYaml -Depth 10 -StringWrapLength 0
                        }

                        'Custom' {
                            $_args = @($result) + @($logEvent) + @($logType.Arguments)
                            $result = Invoke-PodeScriptBlock -ScriptBlock $logType.Options.Formatting.Serialise.ScriptBlock -Arguments $_args -UsingVariables $logType.Options.Formatting.Serialise.UsingVariables -Return -Splat
                        }
                    }

                    # is this the first log for the log type, if so do we have any log headers to send?
                    if (!$logType.SentFirstLog) {
                        foreach ($logHeader in $logType.Options.Formatting.Headers) {
                            if ([string]::IsNullOrEmpty($logHeader)) {
                                continue
                            }

                            # transform log header, and push to log methods
                            $logHeader = ConvertTo-PodeLogFormat -LogEvent $logEvent -LogType $logType -Message $logHeader -IsLogHeader
                            Push-PodeLogItem -LogEvent $logEvent -LogType $logType -Message $logHeader
                        }

                        $logType.SentFirstLog = $true
                    }

                    # transform the result to syslog or other log formats
                    $result = ConvertTo-PodeLogFormat -LogEvent $logEvent -LogType $logType -Message $result

                    # push Log Item to each Log Method for the Log Type
                    Push-PodeLogItem -LogEvent $logEvent -LogType $logType -Message $result

                    # small sleep to lower cpu usage when there are lots of logs to process
                    Start-Sleep -Milliseconds 100
                }
                catch [System.OperationCanceledException] {
                    $_ | Write-PodeErrorLog -Level Debug
                }
                catch {
                    $_ | Out-Default
                }
            }
        }
        catch [System.OperationCanceledException] {
            $_ | Write-PodeErrorLog -Level Debug
        }
        catch {
            $_ | Out-Default
            throw
        }
    }

    # create and start Log Method runspaces
    Write-Verbose 'Starting Log Method runspaces...'
    $null = $PodeContext.RunspacePools.Logs.Pool.SetMaxRunspaces($PodeContext.Server.Logging.Methods.Count + 1)

    foreach ($methodId in $PodeContext.Server.Logging.Methods.Keys) {
        $method = Get-PodeLogMethod -Id $methodId

        $params = @{
            Type        = 'Logs'
            Name        = "Method_$($method.Type)"
            ScriptBlock = $method.ScriptBlock
            Parameters  = @{
                MethodId   = $methodId
                MethodType = $method.Type
            }
            PassThru    = $true
        }

        $method.Runspace = Add-PodeRunspace @params
    }

    # start the log dispatcher runspace
    Write-Verbose 'Starting the Log Dispatcher runspace...'
    Add-PodeRunspace -Type Logs -Name 'Dispatcher' -ScriptBlock $script
    $PodeContext.Server.Logging.Running = $true
}

function ConvertTo-PodeLogFormat {
    param(
        [Parameter(Mandatory = $true)]
        [Pode.Utilities.Logging.IPodeLogEvent]
        $LogEvent,

        [Parameter(Mandatory = $true)]
        [hashtable]
        $LogType,

        [Parameter(Mandatory = $true)]
        $Message,

        [switch]
        $IsLogHeader
    )

    switch ($LogType.Options.Formatting.Log.Format) {
        'Syslog' {
            $params = @{
                Message   = $Message
                Level     = $LogEvent.Level
                Timestamp = $LogEvent.Timestamp
                AppName   = $LogType.Options.Formatting.SyslogInfo.AppName
                Tags      = $LogType.Options.Formatting.SyslogInfo.Tags
                Format    = $LogType.Options.Formatting.SyslogInfo.Format
                Facility  = $LogType.Options.Formatting.SyslogInfo.Facility
            }

            return ConvertTo-PodeSyslog @params
        }

        'Custom' {
            $params = @{
                ScriptBlock    = $LogType.Options.Formatting.Log.ScriptBlock
                Arguments      = @($Message, $LogEvent, $IsLogHeader.IsPresent) + @($LogType.Arguments)
                UsingVariables = $LogType.Options.Formatting.Log.UsingVariables
                Return         = $true
                Splat          = $true
            }

            return Invoke-PodeScriptBlock @params
        }

        default {
            return $Message
        }
    }
}

function Push-PodeLogItem {
    param(
        [Parameter(Mandatory = $true)]
        [Pode.Utilities.Logging.IPodeLogEvent]
        $LogEvent,

        [Parameter(Mandatory = $true)]
        [hashtable]
        $LogType,

        [Parameter(Mandatory = $true)]
        $Message
    )

    foreach ($logMethodId in $LogType.Method) {
        # get the log method we need to log to
        $logMethod = Get-PodeLogMethod -Id $logMethodId

        # check if this event doesn't have an override that ignores this log method
        $override = Get-PodeLogOverride -LogEvent $LogEvent -Id $logMethodId -Type $logMethod.Type
        if (($null -ne $override) -and $override.Ignore) {
            continue
        }

        # add current item to batch
        $batch = $logMethod.Batch
        $batch.Items.Add([Pode.Utilities.Logging.PodeLogItem]::new($Message, $LogEvent))

        # if the batch is full, send to Log Method and reset
        if ($batch.Items.IsFull) {
            $logMethod.Queue.Add($batch.Items)
            $batch.Items = [Pode.Utilities.Logging.PodeLogItemCollection]::new($batch.Items.MaxCount, $batch.Items.Timeout)
        }
    }
}

function Add-PodeLogMethodInternal {
    param(
        [Parameter()]
        [string]
        $Id,

        [Parameter()]
        [hashtable]
        $BatchInfo = $null,

        [Parameter(Mandatory = $true)]
        [hashtable]
        $Config
    )

    # generate an ID if not supplied
    if ([string]::IsNullOrWhiteSpace($Id)) {
        $Id = New-PodeGuid
    }

    # check if method already exists
    if (Test-PodeLogMethod -Id $Id) {
        # A Log Method with the same ID already exists
        throw ($PodeLocale.loggingMethodAlreadyDefinedExceptionMessage -f $Id)
    }

    # empty list of Log Types for later associations
    $Config.Types = @()

    # add batching info to metadata
    $Config.Batch = $BatchInfo | New-PodeLogBatchConfig

    # create queue for the method's log items
    $Config.Queue = [Pode.Utilities.Logging.PodeLogQueue[Pode.Utilities.Logging.IPodeLogItemCollection]]::new()

    # add method to server
    $PodeContext.Server.Logging.Methods[$Id] = $Config

    # extend runspace pool, and create runspace for the method - if logging is already running
    if ($PodeContext.Server.Logging.Running) {
        $null = $PodeContext.RunspacePools.Logs.Pool.SetMaxRunspaces($PodeContext.Server.Logging.Methods.Count + 1)

        $params = @{
            Type        = 'Logs'
            Name        = "Method_$($Config.Type)"
            ScriptBlock = $Config.ScriptBlock
            Parameters  = @{
                MethodId   = $Id
                MethodType = $Config.Type
            }
            PassThru    = $true
        }

        $Config.Runspace = Add-PodeRunspace @params
    }

    # return the method ID
    return $Id
}

function Add-PodeLogTypeInternal {
    [CmdletBinding(DefaultParameterSetName = 'ScriptBlock')]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true)]
        [string[]]
        $Method,

        [Parameter(Mandatory = $true, ParameterSetName = 'ScriptBlock')]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [ValidateSet('Emergency', 'Alert', 'Critical', 'Error', 'Warning', 'Notice', 'Informational', 'Verbose', 'Debug', '*')]
        [string[]]
        $Levels,

        [Parameter(ParameterSetName = 'ScriptBlock')]
        [object[]]
        $ArgumentList,

        [Parameter(ParameterSetName = 'ScriptBlock')]
        [ValidateSet(1, 2)]
        [int]
        $Version,

        [Parameter()]
        [Pode.Utilities.Logging.PodeLogFormat]
        $LogFormat = [Pode.Utilities.Logging.PodeLogFormat]::None,

        [Parameter()]
        [scriptblock]
        $LogScriptBlock,

        [Parameter()]
        [Pode.Utilities.Logging.PodeSerialiseFormat]
        $SerialiseFormat = [Pode.Utilities.Logging.PodeSerialiseFormat]::None,

        [Parameter()]
        [scriptblock]
        $SerialiseScriptBlock,

        [Parameter()]
        [hashtable]
        $SyslogInfo,

        [Parameter()]
        [string]
        $XmlRootName,

        [Parameter()]
        [hashtable]
        $Metadata,

        [Parameter()]
        [string[]]
        $LogHeader,

        [Parameter()]
        [hashtable]
        $Options,

        [switch]
        $AsUtc,

        [Parameter(ParameterSetName = 'Raw')]
        [switch]
        $Raw
    )

    # ensure the name doesn't already exist
    if ($PodeContext.Server.Logging.Types.ContainsKey($Name)) {
        # Log Method already defined
        throw ($PodeLocale.loggingMethodAlreadyDefinedExceptionMessage -f $Name)
    }

    # ensure the log methods exists
    foreach ($methodId in $Method) {
        if (!(Test-PodeLogMethod -Id $methodId)) {
            # The supplied Log Method for Custom Logging doesn't exist
            throw ($PodeLocale.loggingMethodDoesNotExistExceptionMessage -f $methodId)
        }
    }

    # all errors?
    if ($Levels -contains '*') {
        $Levels = @('Emergency', 'Alert', 'Critical', 'Error', 'Warning', 'Notice', 'Informational', 'Verbose', 'Debug')
    }

    # default metadata
    if ($null -eq $Metadata) {
        $Metadata = @{}
    }

    # default log formatter
    if (!$PSBoundParameters.ContainsKey('LogFormat')) {
        $LogFormat = Protect-PodeValue -Value (Get-PodeLogDefaultFormat) -Default $LogFormat -EnumType ([PodeLogFormat])
    }

    # do we need default syslog info?
    if (($LogFormat -eq [PodeLogFormat]::Syslog) -and ($null -eq $SyslogInfo)) {
        $SyslogInfo = New-PodeLogSyslogInfo
    }

    # are we using a custom log scriptblock?
    if ($LogFormat -eq [PodeLogFormat]::Custom) {
        if ($null -eq $LogScriptBlock) {
            # A non-empty ScriptBlock is required for the Custom log format
            throw ($PodeLocale.nonEmptyScriptBlockRequiredForCustomLogExceptionMessage)
        }

        $LogScriptBlock, $logUsingVars = Convert-PodeScopedVariables -ScriptBlock $LogScriptBlock -PSSession $PSCmdlet.SessionState
    }

    # default serialise formatter
    if (!$PSBoundParameters.ContainsKey('SerialiseFormat')) {
        $SerialiseFormat = Protect-PodeValue -Value (Get-PodeLogDefaultSerialiseFormat) -Default $SerialiseFormat -EnumType ([PodeSerialiseFormat])
    }

    # if custom serialisation, ensure we have a scriptblock, and check for scoped vars in scriptblock
    if ($SerialiseFormat -eq [PodeSerialiseFormat]::Custom) {
        if ($null -eq $SerialiseScriptBlock) {
            # A non-empty ScriptBlock is required for the Custom logging serialisation format
            throw ($PodeLocale.nonEmptyScriptBlockRequiredForCustomSerialisationExceptionMessage)
        }

        $SerialiseScriptBlock, $serialiseUsingVars = Convert-PodeScopedVariables -ScriptBlock $SerialiseScriptBlock -PSSession $PSCmdlet.SessionState
    }

    # check for scoped vars in scriptblock
    if ($PSCmdlet.ParameterSetName -eq 'ScriptBlock') {
        $ScriptBlock, $usingVars = Convert-PodeScopedVariables -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState
    }

    # build log type options
    if ($null -eq $Options) {
        $Options = @{}
    }

    $_opts = @{
        Formatting = @{
            Log        = @{
                Format         = $LogFormat
                ScriptBlock    = $LogScriptBlock
                UsingVariables = $logUsingVars
            }
            SyslogInfo = $SyslogInfo
            Serialise  = @{
                Type           = $SerialiseFormat
                ScriptBlock    = $SerialiseScriptBlock
                UsingVariables = $serialiseUsingVars
                XmlRootName    = Protect-PodeValue -Value $XmlRootName -Default 'Log'
            }
            Headers    = $LogHeader
            AsUtc      = $AsUtc.IsPresent
        }
    }
    $_opts += $Options

    # add custom Log Method to server, associated with the supplied Log Method(s)
    $PodeContext.Server.Logging.Types[$Name] = @{
        Name           = $Name
        Method         = $Method
        ScriptBlock    = $ScriptBlock
        UsingVariables = $usingVars
        Levels         = $Levels
        Raw            = $Raw.IsPresent
        Version        = $Version
        SentFirstLog   = $false
        Metadata       = $Metadata
        Options        = $_opts
        Arguments      = $ArgumentList
    }

    # then associate the supplied Log Method(s) with the custom Log Type
    foreach ($methodId in $Method) {
        Register-PodeLogTypeToMethod -TypeName $Name -MethodId $methodId
    }

    # return the type with all info just created
    return $PodeContext.Server.Logging.Types[$Name]
}

function Register-PodeLogTypeToMethod {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $TypeName,

        [Parameter(Mandatory = $true)]
        [string]
        $MethodId
    )

    $method = Get-PodeLogMethod -Id $MethodId

    if ($method.Types -inotcontains $TypeName) {
        $method.Types += $TypeName
    }
}

function Unregister-PodeLogTypeFromMethod {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $TypeName,

        [Parameter(Mandatory = $true)]
        [string]
        $MethodId
    )

    $method = Get-PodeLogMethod -Id $MethodId
    $method.Types = @($method.Types | Where-Object { $_ -ine $TypeName })
}

function Unregister-PodeLogMethodFromType {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $TypeName,

        [Parameter(Mandatory = $true)]
        [string]
        $MethodId
    )

    $type = Get-PodeLogType -Name $TypeName
    $type.Method = @($type.Method | Where-Object { $_ -ine $MethodId })
}

function Test-PodeLogTypeBatchTimeout {
    # check each Log Type, and see if its batch needs to be outputted due to timeout
    foreach ($logType in $PodeContext.Server.Logging.Types.Values) {
        foreach ($logMethodId in $logType.Method) {
            $logMethod = Get-PodeLogMethod -Id $logMethodId
            $batch = $logMethod.Batch

            # do nothing if the batch timeout hasn't been reached
            if (!$batch.Items.HasTimedOut) {
                continue
            }

            # send batch to Log Method and reset batch
            $logMethod.Queue.Add($batch.Items)

            # reset the batch
            $batch.Items = [Pode.Utilities.Logging.PodeLogItemCollection]::new($batch.Items.MaxCount, $batch.Items.Timeout)
        }
    }
}

function New-PodeLogBatchConfig {
    param(
        [Parameter(ValueFromPipeline = $true)]
        [hashtable]
        $BatchInfo = $null
    )

    if ($null -eq $BatchInfo) {
        $BatchInfo = New-PodeLogBatchInfo
    }

    return @{
        Items = [PodeLogItemCollection]::new($BatchInfo.Size, $BatchInfo.Timeout)
    }
}

function Close-PodeLogging {
    # Dispose of the logs to process collection
    if ($null -ne $PodeContext.Server.Logging.Logger) {
        $PodeContext.Server.Logging.Logger.Dispose()
        $PodeContext.Server.Logging.Logger = $null
    }

    # Dispose Log Method queues
    foreach ($method in $PodeContext.Server.Logging.Methods.Values) {
        if ($null -ne $method.Queue) {
            $method.Queue.Dispose()
            $method.Queue = $null
        }
    }
}

function Get-PodeLoggingContextId {
    if ($null -ne $WebEvent) {
        return $WebEvent.ContextId
    }

    if ($null -ne $SignalEvent) {
        return $SignalEvent.ContextId
    }

    if ($null -ne $script:SmtpEvent) {
        return $script:SmtpEvent.ContextId
    }

    if ($null -ne $TcpEvent) {
        return $TcpEvent.ContextId
    }

    return [string]::Empty
}