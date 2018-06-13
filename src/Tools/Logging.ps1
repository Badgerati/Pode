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
        while ($true)
        {
            # if there are no requests to log, just sleep
            if (($requests | Measure-Object).Count -eq 0) {
                Start-Sleep -Seconds 1
                continue
            }

            # loop through each of the requests, and invoke the loggers
            $request = $null

            lock $requests {
                $request = $requests[0]
                $requests.RemoveAt(0) | Out-Null
            }

            $loggers.Keys | ForEach-Object {
                switch ($_.ToLowerInvariant())
                {
                    'terminal' {
                        $request.Message | Out-Default
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
    if (($PodeSession.Loggers | Measure-Object).Count -eq 1) {
        Start-LoggerRunspace
    }
}