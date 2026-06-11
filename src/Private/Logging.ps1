function Get-PodeLoggingTerminalMethod {
    return {
        param(
            [Parameter(Mandatory = $true)]
            [string]
            $MethodId
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
                    # try and get a log item
                    $log = $null
                    $found = $method.Queue.TryTake([ref]$log, 5000, $PodeContext.Tokens.Cancellation.Token)

                    if (!$found -or ($null -eq $log)) {
                        continue
                    }

                    # check if it's an array from batching
                    if ($log.Items -is [array]) {
                        $log.Items = $log.Items -join [System.Environment]::NewLine
                    }

                    # protect then write
                    $log.Items = ($log.Items | Protect-PodeLogItem)
                    $log.Items.ToString() | Out-PodeHost
                }
                catch [System.OperationCanceledException] {
                    $_ | Write-PodeErrorLog -Level Debug
                }
                catch {
                    $_ | Write-PodeErrorLog
                }
            }
        }
        catch [System.OperationCanceledException] {
            $_ | Write-PodeErrorLog -Level Debug
        }
        catch {
            $_ | Write-PodeErrorLog
            throw $_.Exception
        }
    }
}

function Get-PodeLoggingFileMethod {
    return {
        param(
            [Parameter(Mandatory = $true)]
            [string]
            $MethodId
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
                    $log = $null
                    $found = $method.Queue.TryTake([ref]$log, 5000, $PodeContext.Tokens.Cancellation.Token)

                    if (!$found -or ($null -eq $log)) {
                        continue
                    }

                    # check if it's an array from batching
                    if ($log.Items -is [array]) {
                        $log.Items = $log.Items -join [System.Environment]::NewLine
                    }

                    # mask values
                    $log.Items = $log.Items | Protect-PodeLogItem

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
                    $log.Items.ToString() | Out-File -FilePath $path -Encoding utf8 -Append -Force

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
                    $_ | Write-PodeErrorLog
                }
            }
        }
        catch [System.OperationCanceledException] {
            $_ | Write-PodeErrorLog -Level Debug
        }
        catch {
            $_ | Write-PodeErrorLog
        }
    }
}

function Get-PodeLoggingEventViewerMethod {
    return {
        param(
            [Parameter(Mandatory = $true)]
            [string]
            $MethodId
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
                    $log = $null
                    $found = $method.Queue.TryTake([ref]$log, 5000, $PodeContext.Tokens.Cancellation.Token)

                    if (!$found -or ($null -eq $log)) {
                        continue
                    }

                    # check if it's an array from batching
                    if ($log.Items -isnot [array]) {
                        $log.Items = @($log.Items)
                    }

                    if ($log.RawItems -isnot [array]) {
                        $log.RawItems = @($log.RawItems)
                    }

                    for ($i = 0; $i -lt $log.Items.Length; $i++) {
                        # convert log level - info if no level present
                        $entryType = ConvertTo-PodeEventViewerLevel -Level $log.RawItems[$i].Level

                        # create log instance
                        $entryInstance = [System.Diagnostics.EventInstance]::new($method.Arguments.ID, 0, $entryType)

                        # create event log
                        $entryLog = [System.Diagnostics.EventLog]::new()
                        $entryLog.Log = $method.Arguments.LogName
                        $entryLog.Source = $method.Arguments.Source

                        try {
                            $message = ($log.Items[$i] | Protect-PodeLogItem)
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
                    $_ | Write-PodeErrorLog
                }
            }
        }
        catch [System.OperationCanceledException] {
            $_ | Write-PodeErrorLog -Level Debug
        }
        catch {
            $_ | Write-PodeErrorLog
            throw $_.Exception
        }
    }
}

function Get-PodeLoggingCustomMethod {
    return {
        param(
            [Parameter(Mandatory = $true)]
            [string]
            $MethodId
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
                    $log = $null
                    $found = $method.Queue.TryTake([ref]$log, 5000, $PodeContext.Tokens.Cancellation.Token)

                    if (!$found -or ($null -eq $log)) {
                        continue
                    }

                    # invoke the custom scriptblock
                    $_args = @(, $log.Items) + @($method.Arguments) + @(, $log.RawItems)
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
                    $_ | Write-PodeErrorLog
                }
            }
        }
        catch [System.OperationCanceledException] {
            $_ | Write-PodeErrorLog -Level Debug
        }
        catch {
            $_ | Write-PodeErrorLog
            throw $_.Exception
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

function Get-PodeRequestLogTypeName {
    return '__pode_log_requests__'
}

function Get-PodeErrorLogTypeName {
    return '__pode_log_errors__'
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

function Test-PodeLogTypeEnabled {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    return $PodeContext.Server.Logging.Enabled -and $PodeContext.Server.Logging.Types.ContainsKey($Name)
}

function Get-PodeLogTypeLogLevel {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    return (Get-PodeLogType -Name $Name).Levels
}

function Test-PodeErrorLogTypeEnabled {
    return (Test-PodeLogTypeEnabled -Name (Get-PodeErrorLogTypeName))
}

function Test-PodeRequestLogTypeEnabled {
    return (Test-PodeLogTypeEnabled -Name (Get-PodeRequestLogTypeName))
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
    $name = Get-PodeRequestLogTypeName
    if (!(Test-PodeLogTypeEnabled -Name $name)) {
        return
    }

    # build a request object
    $item = @{
        Host            = $Request.Handler.RemoteEndPoint.Address.IPAddressToString
        RfcUserIdentity = '-'
        User            = '-'
        Date            = [DateTime]::Now.ToString('dd/MMM/yyyy:HH:mm:ss zzz')
        UtcDate         = [DateTime]::UtcNow
        Request         = @{
            Method   = $Request.HttpMethod.ToUpperInvariant()
            Hostname = $Request.Host.ToLowerInvariant()
            Scheme   = $Request.Handler.Scheme.ToLowerInvariant()
            Resource = $Path
            Query    = (Protect-PodeValue -Value $Request.Url.Query -Default '-').TrimStart('?')
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
        $userProps = (Get-PodeLogType -Name $name).Properties.Username.Split('.')

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
    $name = Get-PodeRequestLogTypeName
    if (!(Test-PodeLogTypeEnabled -Name $name)) {
        return
    }

    # add the request logging endware
    $WebEvent.OnEnd += @{
        Logic = {
            Write-PodeRequestLog -Request $WebEvent.Request -Response $WebEvent.Response -Path $WebEvent.Path
        }
    }
}

function Test-PodeLogTypesExist {
    if (($null -eq $PodeContext.Server.Logging) -or ($null -eq $PodeContext.Server.Logging.Types)) {
        return $false
    }

    return (($PodeContext.Server.Logging.Types.Count -gt 0) -or ($PodeContext.Server.Logging.Enabled))
}

function Start-PodeLoggingRunspace {
    # skip if there are no log types configured, or logging is disabled
    if (!(Test-PodeLogTypesExist)) {
        return
    }

    $script = {
        # Waits for the Pode server to fully start before proceeding with further operations.
        Wait-PodeCancellationTokenRequest -Type Start

        try {
            while (!(Test-PodeCancellationTokenRequest -Type Terminate)) {

                # Check for suspension token and wait for the debugger to reset if active
                Test-PodeSuspensionToken

                try {
                    # try and remove an item from the queue, if none check batches then continue
                    $log = $null
                    $found = $PodeContext.LogsToProcess.TryTake([ref]$log, 5000, $PodeContext.Tokens.Cancellation.Token)

                    if (!$found -or ($null -eq $log)) {
                        Test-PodeLogTypeBatchTimeout
                        continue
                    }

                    # run the log item through the appropriate method
                    $logType = Get-PodeLogType -Name $log.Name
                    $now = [datetime]::Now

                    # transform the log item into a writeable format
                    $_args = @($log.Item) + @($logType.Arguments)
                    $result = @(Invoke-PodeScriptBlock -ScriptBlock $logType.ScriptBlock -Arguments $_args -UsingVariables $logType.UsingVariables -Return -Splat)
                    if ($null -eq $result) {
                        Start-Sleep -Milliseconds 100
                        continue
                    }

                    # loop through each log method available to the log type
                    foreach ($logMethodId in $logType.Method) {
                        $logMethod = Get-PodeLogMethod -Id $logMethodId
                        $batch = $logMethod.Batch

                        if ($batch.Size -gt 1) {
                            # add current item to batch
                            $batch.Items += $result
                            $batch.RawItems += $log.Item
                            $batch.LastUpdate = $now

                            # if the current amount of items matches the batch, send to log method and reset batch
                            if ($batch.Items.Length -ge $batch.Size) {
                                #TODO: add item/rawItem to method queue
                                $logMethod.Queue.Add(@{
                                        Items    = $batch.Items
                                        RawItems = $batch.RawItems
                                    })
                                # Invoke-PodeLogMethod -Method $logMethod -Item $batch.Items -RawItem $batch.RawItems
                                $batch.Items = @()
                                $batch.RawItems = @()
                            }
                        }

                        # send log item to log method
                        else {
                            #TODO: add item/rawItem to method queue
                            $logMethod.Queue.Add(@{
                                    Items    = $result
                                    RawItems = $log.Item
                                })
                            # Invoke-PodeLogMethod -Method $logMethod -Item $result -RawItem $log.Item
                        }
                    }

                    # small sleep to lower cpu usage when there are lots of logs to process
                    Start-Sleep -Milliseconds 100
                }
                catch [System.OperationCanceledException] {
                    $_ | Write-PodeErrorLog -Level Debug
                }
                catch {
                    $_ | Write-PodeErrorLog
                }
            }
        }
        catch [System.OperationCanceledException] {
            $_ | Write-PodeErrorLog -Level Debug
        }
        catch {
            $_ | Write-PodeErrorLog
            throw $_.Exception
        }
    }

    # create and start log method runspaces
    Write-Verbose 'Starting log method runspaces...'
    $null = $PodeContext.RunspacePools.Logs.Pool.SetMaxRunspaces($PodeContext.Server.Logging.Methods.Count + 1)

    foreach ($methodId in $PodeContext.Server.Logging.Methods.Keys) {
        $method = Get-PodeLogMethod -Id $methodId
        $method.Runspace = Add-PodeRunspace -Type Logs -Name "Method_$($method.Type)" -ScriptBlock $method.ScriptBlock -Parameters @{ MethodId = $methodId } -PassThru
    }

    # start the log dispatcher runspace
    Write-Verbose 'Starting the Log Dispatcher runspace...'
    Add-PodeRunspace -Type Logs -Name 'Dispatcher' -ScriptBlock $script
}

function Add-PodeLogMethod {
    param(
        [Parameter()]
        [string]
        $Id,

        [Parameter()]
        [hashtable]
        $BatchInfo = $null,

        [Parameter(Mandatory = $true)]
        [hashtable]
        $Metadata
    )

    # generate an ID if not supplied
    if ([string]::IsNullOrWhiteSpace($Id)) {
        $Id = New-PodeGuid
    }

    # check if method already exists
    if (Test-PodeLogMethod -Id $Id) {
        #TODO: A logging method with the same ID already exists
        throw ($PodeLocale.loggingMethodAlreadyDefinedExceptionMessage -f $Id)
    }

    # add batching info to metadata
    $Metadata.Batch = $BatchInfo | New-PodeLogBatchConfig

    # create queue for the method's log items
    $Metadata.Queue = [System.Collections.Concurrent.BlockingCollection[hashtable]]::new()

    # add method to server
    $PodeContext.Server.Logging.Methods[$Id] = $Metadata

    # return the method ID
    return $Id
}

function Test-PodeLogTypeBatchTimeout {
    $now = [datetime]::Now

    # check each log Type, and see if its batch needs to be outputted due to timeout
    foreach ($logType in $PodeContext.Server.Logging.Types.Values) {
        foreach ($logMethodId in $logType.Method) {
            $logMethod = Get-PodeLogMethod -Id $logMethodId
            $batch = $logMethod.Batch

            # do nothing if not batching, or no items
            if (($batch.Size -le 1) -or ($batch.Timeout -le 0) -or ($batch.Items.Length -eq 0)) {
                continue
            }

            # do nothing if the batch timeout hasn't been reached
            if (($null -eq $batch.LastUpdate) -or ($batch.LastUpdate.AddSeconds($batch.Timeout) -gt $now)) {
                continue
            }

            # send batch to log method and reset batch
            #TODO: add item/rawItem to method queue
            $logMethod.Queue.Add(@{
                    Items    = $batch.Items
                    RawItems = $batch.RawItems
                })
            # Invoke-PodeLogMethod -Method $logMethod -Item $batch.Items -RawItem $batch.RawItems
            $batch.Items = @()
            $batch.RawItems = @()
        }
    }
}

# function Invoke-PodeLogMethod {
#     param(
#         [Parameter(Mandatory = $true)]
#         [hashtable]
#         $Method,

#         [Parameter(Mandatory = $true)]
#         [object[]]
#         $Item,

#         [Parameter()]
#         [object[]]
#         $RawItem
#     )

#     $_args = @(, $Item) + @($Method.Arguments) + @(, $RawItem)
#     $null = Invoke-PodeScriptBlock -ScriptBlock $Method.ScriptBlock -Arguments $_args -UsingVariables $Method.UsingVariables -Splat
# }

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
        Size       = $BatchInfo.Size
        Timeout    = $BatchInfo.Timeout
        LastUpdate = $null
        Items      = @()
        RawItems   = @()
    }
}

function Close-PodeLogging {
    # Dispose of the logs to process collection
    if ($null -ne $PodeContext.LogsToProcess) {
        $PodeContext.LogsToProcess.Dispose()
        $PodeContext.LogsToProcess = $null
    }

    # Dispose log method queues
    foreach ($method in $PodeContext.Server.Logging.Methods.Values) {
        if ($null -ne $method.Queue) {
            $method.Queue.Dispose()
            $method.Queue = $null
        }
    }
}