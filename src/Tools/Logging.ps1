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
        function Get-ResponseString($req) {
            return "$($req.Host) $($req.Ident) $($req.User) [$($req.Date)] `"$($req.Request.Method) $($req.Request.Resource) $($req.Request.Protocol)`" $($req.Response.StatusCode) $($req.Response.Size)"
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

            $loggers.Keys | ForEach-Object {
                switch ($_.ToLowerInvariant())
                {
                    'terminal' {
                        (Get-ResponseString $r) | Out-Default
                    }

                    'file' {
                        (Get-ResponseString $r) | Out-File -FilePath 'C:\Projects\Pode\examples\logs.log' -Encoding utf8 -Append -Force
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

    # lower the name
    $Name = $Name.ToLowerInvariant()

    # ensure the logger doesn't already exist
    if ($PodeSession.Loggers.ContainsKey($Name)) {
        throw "Logger called $($Name) already exists"
    }

    # add the logger
    $PodeSession.Loggers[$Name] = @{}

    # if this is the first logger, start the logging runspace
    if ($PodeSession.Loggers.Count -eq 1) {
        Start-LoggerRunspace
    }
}