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
        function sg($value) {
            if (Test-Empty $value) {
                return '-'
            }

            return $value
        }

        function Get-RequestString($req) {
            return "$(sg $req.Host) $(sg $req.RfcUserIdentity) $(sg $req.User) [$(sg $req.Date)] `"$(sg $req.Request.Method) $(sg $req.Request.Resource) $(sg $req.Request.Protocol)`" $(sg $req.Response.StatusCode) $(sg $req.Response.Size) `"$(sg $req.Request.Referrer)`" `"$(sg $req.Request.Agent)`""
        }

        while ($true)
        {
            # if there are no requests to log, just sleep
            if (($requests | Measure-Object).Count -eq 0) {
                Start-Sleep -Seconds 1
                continue
            }

            # loop through each of the requests, and invoke the loggers
            $r = $null

            lock $requests {
                $r = $requests[0]
                $requests.RemoveAt(0) | Out-Null
            }

            # convert the request into a log string
            $str = (Get-RequestString $r)

            # apply request to loggers
            $loggers.Keys | ForEach-Object {
                switch ($_.ToLowerInvariant())
                {
                    'terminal' {
                        $str | Out-Default
                    }

                    'file' {
                        $path = (Join-ServerRoot 'logs' 'log.txt' -Root $root)
                        $str | Out-File -FilePath $path -Encoding utf8 -Append -Force
                    }
                }
            }

            # small sleep to lower cpu usage
            Start-Sleep -Milliseconds 100
        }
    }

    Add-PodeRunspace $script
}

function Logger
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name
    )

    # is logging disabled?
    if ($PodeSession.DisableLogging) {
        Write-Host "Logging has been disabled for $($Name)" -ForegroundColor DarkBlue
        return
    }

    # lower the name
    $Name = $Name.ToLowerInvariant()

    # ensure the logger doesn't already exist
    if ($PodeSession.Loggers.ContainsKey($Name)) {
        throw "Logger called $($Name) already exists"
    }

    # add the logger
    $PodeSession.Loggers[$Name] = @{}

    # if a file logger, create base directory
    if ($Name -ieq 'file') {
        $path = (Split-Path -Parent -Path (Join-ServerRoot 'logs' 'tmp.txt'))
        New-Item -Path $path -ItemType Directory -Force | Out-Null
    }

    # if this is the first logger, start the logging runspace
    if ($PodeSession.Loggers.Count -eq 1) {
        Start-LoggerRunspace
    }
}