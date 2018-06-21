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
        $Http,

        [switch]
        $Https,

        [switch]
        $DisableTermination,

        [switch]
        $DisableLogging
    )

    # ensure the session is clean
    $PodeSession = $null

    # if an ip address was passed, ensure it's valid
    if (!(Test-Empty $IP) -and !(Test-IPAddress $IP)) {
        throw "Invalid IP address has been supplied: $($IP)"
    }

    try {
        # create session object
        $PodeSession = New-PodeSession -ServerRoot $MyInvocation.PSScriptRoot -DisableLogging:$DisableLogging

        # parse ip:port to listen on (if both have been supplied)
        if (!(Test-Empty $IP) -or $Port -gt 0) {
            listen "$($IP):$($Port)"
        }

        # set it so ctrl-c can terminate
        [Console]::TreatControlCAsInput = $true

        # run the server logic
        . $ScriptBlock

        # if smtp/https is passed, and no port - force port to 25/443
        if ($PodeSession.Port -eq 0) {
            if ($Smtp) {
                $PodeSession.Port = 25
            }

            elseif ($Https) {
                $PodeSession.Port = 443
            }

            elseif ($Http -or (!$Tcp -and !$Smtp -and !$Https)) {
                $PodeSession.Port = 80
            }
        }

        # validate port passed
        if ($PodeSession.Port -lt 0) {
            throw "Port cannot be negative: $($PodeSession.Port)"
        }

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
        elseif ($Http -or $Https -or $PodeSession.Port -gt 0) {
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
                    . $ScriptBlock
                }
            }
        }
    }
    finally {
        # clean the runspaces and tokens
        Close-Pode
        $PodeSession = $null
    }
}