function Get-PodeLogger
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name
    )

    return $PodeSession.Loggers[$Name]
}

function Start-LoggerRunspace
{
    if (($PodeSession.Loggers | Measure-Object).Count -eq 0) {
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
            if (($PodeSession.RequestsToLog | Measure-Object).Count -eq 0) {
                Start-Sleep -Seconds 1
                continue
            }

            # safetly pop off the first log request from the array
            $r = $null

            lock $PodeSession.RequestsToLog {
                $r = $PodeSession.RequestsToLog[0]
                $PodeSession.RequestsToLog.RemoveAt(0) | Out-Null
            }

            # convert the request into a log string
            $str = (Get-RequestString $r)

            # apply log request to supplied loggers
            $PodeSession.Loggers.Keys | ForEach-Object {
                switch ($_.ToLowerInvariant())
                {
                    'terminal' {
                        $str | Out-Default
                    }

                    'file' {
                        $details = $PodeSession.Loggers[$_]
                        $date = [DateTime]::Now.ToString('yyyy-MM-dd')

                        # generate path to log path and date file
                        if ($null -eq $details -or (Test-Empty $details.Path)) {
                            $path = (Join-ServerRoot 'logs' "$($date).log" ) #-Root $PodeSession.ServerRoot)
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
                        Invoke-ScriptBlock -ScriptBlock $PodeSession.Loggers[$_] -Arguments @{
                            'Log' = $r;
                            'Lockable' = $PodeSession.Lockable;
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
        [string]
        $Name,

        [Parameter()]
        [object]
        $Details = $null
    )

    # is logging disabled?
    if ($PodeSession.DisableLogging) {
        Write-Host "Logging has been disabled for $($Name)" -ForegroundColor DarkCyan
        return
    }

    # lower the name
    $Name = $Name.ToLowerInvariant()

    # ensure the logger doesn't already exist
    if ($PodeSession.Loggers.ContainsKey($Name)) {
        throw "Logger called $($Name) already exists"
    }

    # ensure the details are of a correct type (inbuilt=hashtable, custom=scriptblock)
    $type = (Get-Type $Details)

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
    $PodeSession.Loggers[$Name] = $Details

    # if a file logger, create base directory (file is a dummy file, and won't be created)
    if ($Name -ieq 'file') {
        # has a specific logging path been supplied?
        if ($null -eq $Details -or (Test-Empty $Details.Path)) {
            $path = (Split-Path -Parent -Path (Join-ServerRoot 'logs' 'tmp.txt'))
        }
        else {
            $path = $Details.Path
        }

        Write-Host "Log Path: $($path)" -ForegroundColor DarkCyan
        New-Item -Path $path -ItemType Directory -Force | Out-Null
    }

    # if this is the first logger, start the logging runspace
    if ($PodeSession.Loggers.Count -eq 1) {
        Start-LoggerRunspace
    }
}