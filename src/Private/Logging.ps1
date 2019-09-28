function Get-PodeLoggingTerminalMethod
{
    return {
        param($item, $options)
        $item = ($item | Protect-PodeLogItem)
        $item.ToString() | Out-Default
    }
}

function Get-PodeLoggingFileMethod
{
    return {
        param($item, $options)

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
            $path = (Join-Path $options.Path "$($options.Name)_$($date)_*.log")
            $options.FileId = (@(Get-ChildItem -Path $path)).Length
            if ($options.FileId -eq 0) {
                $options.FileId = 1
            }
        }

        $id = "$($options.FileId)".PadLeft(3, '0')
        if ($options.MaxSize -gt 0) {
            $path = (Join-Path $options.Path "$($options.Name)_$($date)_$($id).log")
            if ((Get-Item -Path $path -Force).Length -ge $options.MaxSize) {
                $options.FileId++
                $id = "$($options.FileId)".PadLeft(3, '0')
            }
        }

        # get the file to write to
        $path = (Join-Path $options.Path "$($options.Name)_$($date)_$($id).log")

        # write the item to the file
        $item.ToString() | Out-File -FilePath $path -Encoding utf8 -Append -Force

        # if set, remove log files beyond days set (ensure this is only run once a day)
        if (($options.MaxDays -gt 0) -and ($options.NextClearDown -lt [DateTime]::Now.Date)) {
            $date = [DateTime]::Now.Date.AddDays(-$options.MaxDays)

            Get-ChildItem -Path $options.Path -Filter '*.log' -Force |
                Where-Object { $_.CreationTime -lt $date } |
                Remove-Item $_ -Force | Out-Null

            $options.NextClearDown = [DateTime]::Now.Date.AddDays(1)
        }
    }
}

function Get-PodeLoggingInbuiltType
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet('Errors', 'Requests')]
        [string]
        $Type
    )

    switch ($Type.ToLowerInvariant())
    {
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

function Get-PodeRequestLoggingName
{
    return '__pode_log_requests__'
}

function Get-PodeErrorLoggingName
{
    return '__pode_log_errors__'
}

function Get-PodeLogger
{
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Name
    )

    return $PodeContext.Server.Logging.Types[$Name]
}

function Test-PodeLoggerEnabled
{
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Name
    )

    return ($PodeContext.Server.Logging.Enabled -and $PodeContext.Server.Logging.Types.ContainsKey($Name))
}

function Write-PodeRequestLog
{
    param (
        [Parameter(Mandatory=$true)]
        $Request,

        [Parameter(Mandatory=$true)]
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
        Host = $Request.RemoteEndPoint.Address.IPAddressToString
        RfcUserIdentity = '-'
        User = '-'
        Date = [DateTime]::Now.ToString('dd/MMM/yyyy:HH:mm:ss zzz')
        Request = @{
            Method = $Request.HttpMethod.ToUpperInvariant()
            Resource = $Path
            Protocol = "HTTP/$($Request.ProtocolVersion)"
            Referrer = $Request.UrlReferrer
            Agent = $Request.UserAgent
        }
        Response = @{
            StatusCode = $Response.StatusCode
            StatusDescription = $Response.StatusDescription
            Size = '-'
        }
    }

    if ($Response.ContentLength64 -gt 0) {
        $item.Response.Size = $Response.ContentLength64
    }

    # add the item to be processed
    $PodeContext.LogsToProcess.Add(@{
        Name = $name
        Item = $item
    }) | Out-Null
}

function Add-PodeRequestLogEndware
{
    param (
        [Parameter(Mandatory=$true)]
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
            param($e)
            Write-PodeRequestLog -Request $e.Request -Response $e.Response -Path $e.Path
        }
    }
}

function Start-PodeLoggingRunspace
{
    # skip if there are no loggers configured, or logging is disabled
    if (($PodeContext.Server.Logging.Types.Count -eq 0) -or (!$PodeContext.Server.Logging.Enabled)) {
        return
    }

    $script = {
        while ($true)
        {
            # if there are no logs to process, just sleep few a few seconds
            if ($PodeContext.LogsToProcess.Count -eq 0) {
                Start-Sleep -Seconds 5
                continue
            }

            # safetly pop off the first log from the array
            $log = (Lock-PodeObject -Return -Object $PodeContext.LogsToProcess -ScriptBlock {
                $log = $PodeContext.LogsToProcess[0]
                $PodeContext.LogsToProcess.RemoveAt(0) | Out-Null
                return $log
            })

            if ($null -ne $log) {
                # run the log item through the appropriate method, then through the storage script
                $logger = Get-PodeLogger -Name $log.Name

                $result = @(Invoke-PodeScriptBlock -ScriptBlock $logger.ScriptBlock -Arguments (@($log.Item) + @($logger.Arguments)) -Return -Splat)
                Invoke-PodeScriptBlock -ScriptBlock $logger.Method.ScriptBlock -Arguments (@($result) + @($logger.Method.Arguments)) -Splat
            }

            # small sleep to lower cpu usage
            Start-Sleep -Milliseconds 100
        }
    }

    Add-PodeRunspace -Type 'Main' -ScriptBlock $script
}