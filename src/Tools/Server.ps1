function Server
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [ValidateNotNull()]
        [int]
        $Port = 0,

        [Parameter()]
        [ValidateNotNull()]
        [int]
        $Interval = 0,

        [Parameter()]
        [string]
        $IP,

        [switch]
        $Smtp,

        [switch]
        $Tcp,

        [switch]
        $Https,

        [switch]
        $DisableTermination,

        [switch]
        $DisableLogging
    )

    # ensure the session is clean
    $PodeSession = $null

    # if smtp is passed, and no port - force port to 25
    if ($Port -eq 0 -and $Smtp) {
        $Port = 25
    }

    # validate port passed
    if ($Port -lt 0) {
        throw "Port cannot be negative: $($Port)"
    }

    # if an ip address was passed, ensure it's valid
    if (!(Test-IPAddress $IP)) {
        throw "Invalid IP address has been supplied: $($IP)"
    }

    try {
        # create session object
        $PodeSession = New-PodeSession -Port $Port -IP $IP `
            -ServerRoot $MyInvocation.PSScriptRoot -DisableLogging:$DisableLogging

        # set it so ctrl-c can terminate
        [Console]::TreatControlCAsInput = $true

        # run the logic
        & $ScriptBlock

        # start runspace for timers
        Start-TimerRunspace

        # start runspace to monitor for terminating server
        if (!$DisableTermination -and ![Console]::IsInputRedirected) {
            Start-TerminationListener
        }

        # run logic for a smtp server
        if ($Smtp) {
            Start-SmtpServer
        }

        # run logic for a tcp server
        elseif ($Tcp) {
            Start-TcpServer
        }

        # if there's a port, run a web server
        elseif ($Port -gt 0) {
            Start-WebServer -Https:$Https
        }

        # otherwise, run logic
        else {
            # are we running this logic in an interval loop?
            if ($Interval -gt 0) {
                Write-Host "Looping logic every $($Interval)secs" -ForegroundColor Yellow

                while ($true) {
                    if ($PodeSession.CancelToken.IsCancellationRequested) {
                        Close-Pode -Exit
                    }

                    Start-Sleep -Seconds $Interval
                    & $ScriptBlock
                }
            }
        }
    }
    catch {
        $Error[0] | Out-Default
        throw $_.Exception
    }
    finally {
        # clean the runspaces and tokens
        Close-Pode
        $PodeSession = $null
    }
}