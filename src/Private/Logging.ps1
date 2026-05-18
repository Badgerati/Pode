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
        if (($options.MaxDays -gt 0) -and ($options.NextClearDown -le [DateTime]::Now.Date)) {
            $date = [DateTime]::Now.Date.AddDays(-$options.MaxDays)

            $null = Get-ChildItem -Path $options.Path -Filter "$($options.Name)_*.log" -Force |
                Where-Object { $_.CreationTime -lt $date } |
                Remove-Item -Force

            $options.NextClearDown = [DateTime]::Now.Date.AddDays(1)
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

function Test-PodeLogTypeEnabled {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    return ($PodeContext.Server.Logging.Enabled -and $PodeContext.Server.Logging.Types.ContainsKey($Name))
}

function Get-PodeErrorLoggingLevel {
    return (Get-PodeLogType -Name (Get-PodeErrorLogTypeName)).Arguments.Levels
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

                    # convert to log item into a writeable format
                    $_args = @($log.Item) + @($logType.Arguments)
                    $result = @(Invoke-PodeScriptBlock -ScriptBlock $logType.ScriptBlock -Arguments $_args -UsingVariables $logType.UsingVariables -Return -Splat)
                    if ($null -eq $result) {
                        Start-Sleep -Milliseconds 100
                        continue
                    }

                    # loop through each log method available to the log type
                    foreach ($logMethod in $logType.Method) {
                        $batch = $logMethod.Batch

                        if ($batch.Size -gt 1) {
                            # add current item to batch
                            $batch.Items += $result
                            $batch.RawItems += $log.Item
                            $batch.LastUpdate = $now

                            # if the current amount of items matches the batch, send to log method and reset batch
                            if ($batch.Items.Length -ge $batch.Size) {
                                Invoke-PodeLogMethod -Method $logMethod -Item $batch.Items -RawItem $batch.RawItems
                                $batch.Items = @()
                                $batch.RawItems = @()
                            }
                        }

                        # send log item to log method
                        else {
                            Invoke-PodeLogMethod -Method $logMethod -Item $result -RawItem $log.Item
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

    Write-Verbose 'Starting the Logging runspace...'
    Add-PodeRunspace -Type Main -Name 'Logging' -ScriptBlock $script
}

function Test-PodeLogTypeBatchTimeout {
    $now = [datetime]::Now

    # check each log Type, and see if its batch needs to be outputted due to timeout
    foreach ($logType in $PodeContext.Server.Logging.Types.Values) {
        foreach ($logMethod in $logType.Method) {
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
            Invoke-PodeLogMethod -Method $logMethod -Item $batch.Items -RawItem $batch.RawItems
            $batch.Items = @()
            $batch.RawItems = @()
        }
    }
}

function Invoke-PodeLogMethod {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]
        $Method,

        [Parameter(Mandatory = $true)]
        [object[]]
        $Item,

        [Parameter()]
        [object[]]
        $RawItem
    )

    $_args = @(, $Item) + @($Method.Arguments) + @(, $RawItem)
    $null = Invoke-PodeScriptBlock -ScriptBlock $Method.ScriptBlock -Arguments $_args -UsingVariables $Method.UsingVariables -Splat
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
        Size       = $BatchInfo.Size
        Timeout    = $BatchInfo.Timeout
        LastUpdate = $null
        Items      = @()
        RawItems   = @()
    }
}