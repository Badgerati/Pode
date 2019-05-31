function Get-PodeLogger
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name
    )

    return $PodeContext.Server.Logging.Methods[$Name]
}

function Add-PodeLogEndware
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $WebEvent
    )

    # don't setup logging if not configured
    if ($PodeContext.Server.Logging.Disabled -or (Get-PodeCount $PodeContext.Server.Logging.Methods) -eq 0) {
        return
    }

    # add the logging endware
    $WebEvent.OnEnd += {
        param($s)
        $obj = New-PodeLogObject -Request $s.Request -Path $s.Path
        Add-PodeLogObject -LogObject $obj -Response $s.Response
    }
}

function New-PodeLogObject
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $Request,

        [Parameter()]
        [string]
        $Path
    )

    return @{
        'Host' = $Request.RemoteEndPoint.Address.IPAddressToString;
        'RfcUserIdentity' = '-';
        'User' = '-';
        'Date' = [DateTime]::Now.ToString('dd/MMM/yyyy:HH:mm:ss zzz');
        'Request' = @{
            'Method' = $Request.HttpMethod.ToUpperInvariant();
            'Resource' = $Path;
            'Protocol' = "HTTP/$($Request.ProtocolVersion)";
            'Referrer' = $Request.UrlReferrer;
            'Agent' = $Request.UserAgent;
        };
        'Response' = @{
            'StatusCode' = '-';
            'StatusDescription' = '-';
            'Size' = '-';
        };
    }
}

function Add-PodeLogObject
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $LogObject,

        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $Response
    )

    if ($PodeContext.Server.Logging.Disabled -or (Get-PodeCount $PodeContext.Server.Logging.Methods) -eq 0) {
        return
    }

    $LogObject.Response.StatusCode = $Response.StatusCode
    $LogObject.Response.StatusDescription = $Response.StatusDescription

    if ($Response.ContentLength64 -gt 0) {
        $LogObject.Response.Size = $Response.ContentLength64
    }

    $PodeContext.RequestsToLog.Add($LogObject) | Out-Null
}

function Start-PodeLoggerRunspace
{
    if ((Get-PodeCount $PodeContext.Server.Logging.Methods) -eq 0) {
        return
    }

    $script = {
        # simple safegaurd function to set blank field to a dash(-)
        function sg($value) {
            if (Test-Empty $value) {
                return '-'
            }

            return $value
        }

        # convert a log request into a Combined Log Format string
        function Get-RequestString($req) {
            $url = "$(sg $req.Request.Method) $(sg $req.Request.Resource) $(sg $req.Request.Protocol)"
            return "$(sg $req.Host) $(sg $req.RfcUserIdentity) $(sg $req.User) [$(sg $req.Date)] `"$($url)`" $(sg $req.Response.StatusCode) $(sg $req.Response.Size) `"$(sg $req.Request.Referrer)`" `"$(sg $req.Request.Agent)`""
        }

        # helper variables for files
        $_files_next_run = [DateTime]::Now.Date

        # main logic loop
        while ($true)
        {
            # if there are no requests to log, just sleep
            if ((Get-PodeCount $PodeContext.RequestsToLog) -eq 0) {
                Start-Sleep -Seconds 1
                continue
            }

            # safetly pop off the first log request from the array
            $r = $null

            lock $PodeContext.RequestsToLog {
                $r = $PodeContext.RequestsToLog[0]
                $PodeContext.RequestsToLog.RemoveAt(0) | Out-Null
            }

            # convert the request into a log string
            $str = (Get-RequestString $r)

            # apply log request to supplied loggers
            $PodeContext.Server.Logging.Methods.Keys | ForEach-Object {
                switch ($_.ToLowerInvariant())
                {
                    'terminal' {
                        $str | Out-Default
                    }

                    'file' {
                        $details = $PodeContext.Server.Logging.Methods[$_]
                        $date = [DateTime]::Now.ToString('yyyy-MM-dd')

                        # generate path to log path and date file
                        if ($null -eq $details -or (Test-Empty $details.Path)) {
                            $path = (Join-PodeServerRoot 'logs' "$($date).log" )
                        }
                        else {
                            $path = (Join-Path $details.Path "$($date).log")
                        }

                        # append log to file
                        $str | Out-File -FilePath $path -Encoding utf8 -Append -Force

                        # if set, remove log files beyond days set (ensure this is only run once a day)
                        if ($null -ne $details -and [int]$details.MaxDays -gt 0 -and $_files_next_run -lt [DateTime]::Now) {
                            $date = [DateTime]::Now.AddDays(-$details.MaxDays)

                            Get-ChildItem -Path $path -Filter '*.log' -Force |
                                Where-Object { $_.CreationTime -lt $date } |
                                Remove-Item $_ -Force | Out-Null

                            $_files_next_run = [DateTime]::Now.Date.AddDays(1)
                        }
                    }

                    { $_ -ilike 'custom_*' } {
                        Invoke-ScriptBlock -ScriptBlock $PodeContext.Server.Logging.Methods[$_] -Arguments @{
                            'Log' = $r;
                            'Lockable' = $PodeContext.Lockable;
                        }
                    }
                }
            }

            # small sleep to lower cpu usage
            Start-Sleep -Milliseconds 100
        }
    }

    Add-PodeRunspace -Type 'Main' -ScriptBlock $script
}

function Logger
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [Alias('n')]
        [string]
        $Name,

        [Parameter()]
        [Alias('d')]
        [object]
        $Details = $null,

        [switch]
        [Alias('c')]
        $Custom
    )

    # is logging disabled, or serverless?
    if ($PodeContext.Server.Logging.Disabled -or $PodeContext.Server.IsServerless) {
        Write-Host "Logging has been disabled for $($Name)" -ForegroundColor DarkCyan
        return
    }

    # set the logger as custom if flag is passed
    if ($Name -inotlike 'custom_*' -and $Custom) {
        $Name = "custom_$($Name)"
    }

    # lowercase the name
    $Name = $Name.ToLowerInvariant()

    # ensure the logger doesn't already exist
    if ($PodeContext.Server.Logging.Methods.ContainsKey($Name)) {
        throw "Logger called $($Name) already exists"
    }

    # ensure the details are of a correct type (inbuilt=hashtable, custom=scriptblock)
    $type = (Get-PodeType $Details)

    if ($Name -ilike 'custom_*') {
        if ($null -eq $Details) {
            throw 'For custom loggers, a ScriptBlock is required'
        }

        if ($type.Name -ine 'scriptblock') {
            throw "Custom logger details should be a ScriptBlock, but got: $($type.Name)"
        }
    }
    else {
        if ($null -ne $Details -and $type.Name -ine 'hashtable') {
            throw "Inbuilt logger details should be a HashTable, but got: $($type.Name)"
        }
    }

    # add the logger, along with any given details (hashtable/scriptblock)
    $PodeContext.Server.Logging.Methods[$Name] = $Details

    # if a file logger, create base directory (file is a dummy file, and won't be created)
    if ($Name -ieq 'file') {
        # has a specific logging path been supplied?
        if ($null -eq $Details -or (Test-Empty $Details.Path)) {
            $path = (Split-Path -Parent -Path (Join-PodeServerRoot 'logs' 'tmp.txt'))
        }
        else {
            $path = $Details.Path
        }

        Write-Host "Log Path: $($path)" -ForegroundColor DarkCyan
        New-Item -Path $path -ItemType Directory -Force | Out-Null
    }
}