function Server
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [ValidateNotNull()]
        [Alias('p')]
        [int]
        $Port = 0,

        [Parameter()]
        [ValidateNotNull()]
        [Alias('i')]
        [int]
        $Interval = 0,

        [Parameter()]
        [string]
        $IP,

        [Parameter()]
        [Alias('n')]
        [string]
        $Name,

        [Parameter()]
        [Alias('t')]
        [int]
        $Threads = 1,

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
        $DisableLogging,

        [switch]
        $FileMonitor
    )

    # ensure the session is clean
    $PodeSession = $null

    # validate port passed
    if ($Port -lt 0) {
        throw "Port cannot be negative: $($Port)"
    }

    # if an ip address was passed, ensure it's valid
    if (!(Test-Empty $IP) -and !(Test-IPAddress $IP)) {
        throw "Invalid IP address has been supplied: $($IP)"
    }

    try {
        # get the current server type
        $serverType = Get-PodeServerType -Port $Port -Interval $Interval -Smtp:$Smtp -Tcp:$Tcp -Https:$Https

        # create session object
        $PodeSession = New-PodeSession -ScriptBlock $ScriptBlock `
            -Port $Port `
            -IP $IP `
            -Threads $Threads `
            -Interval $Interval `
            -ServerRoot $MyInvocation.PSScriptRoot `
            -ServerType $ServerType `
            -DisableLogging:$DisableLogging `
            -FileMonitor:$FileMonitor

        # set a default port for the server type
        Set-PodePortForServerType

        # parse ip:port to listen on (if both have been supplied)
        if (!(Test-Empty $IP) -or $PodeSession.Server.IP.Port -gt 0) {
            listen -IPPort "$($IP):$($PodeSession.Server.IP.Port)" -Type $PodeSession.Server.Type
        }

        # set it so ctrl-c can terminate
        [Console]::TreatControlCAsInput = $true

        # start the file monitor for interally restarting
        Start-PodeFileMonitor

        # start the server
        Start-PodeServer

        # sit here waiting for termination (unless it's one-off script)
        if ($PodeSession.Server.Type -ine 'script') {
            while (!(Test-TerminationPressed)) {
                Start-Sleep -Seconds 1

                # check for internal restart
                if ($PodeSession.Tokens.Restart.IsCancellationRequested) {
                    Restart-PodeServer
                }
            }

            Write-Host 'Terminating...' -NoNewline -ForegroundColor Yellow
            $PodeSession.Tokens.Cancellation.Cancel()
        }
    }
    finally {
        # clean the runspaces and tokens
        Close-Pode -Exit

        # clean the session
        $PodeSession = $null
    }
}

function Start-PodeServer
{
    try
    {
        # run the logic
        Invoke-ScriptBlock -ScriptBlock $PodeSession.Server.Logic

        # start runspace for timers
        Start-TimerRunspace

        # start runspace for schedules
        Start-ScheduleRunspace

        # start the appropriate server
        switch ($PodeSession.Server.Type.ToUpperInvariant())
        {
            'SMTP' {
                Start-SmtpServer
            }

            'TCP' {
                Start-TcpServer
            }

            'HTTP' {
                Start-WebServer
            }

            'HTTPS' {
                Start-WebServer -Https
            }

            'SERVICE' {
                Write-Host "Looping logic every $($PodeSession.Server.Interval)secs" -ForegroundColor Yellow

                while ($true) {
                    if ($PodeSession.Tokens.Cancellation.IsCancellationRequested) {
                        Close-Pode -Exit
                    }

                    Start-Sleep -Seconds $PodeSession.Server.Interval
                    Invoke-ScriptBlock -ScriptBlock $PodeSession.Server.Logic
                }
            }
        }
    }
    catch {
        $Error[0] | Out-Default
        throw $_.Exception
    }
}

function Restart-PodeServer
{
    try
    {
        # inform restart
        Write-Host 'Restarting server...' -NoNewline -ForegroundColor Cyan

        # cancel the session token
        $PodeSession.Tokens.Cancellation.Cancel()

        # close all current runspaces
        Close-PodeRunspaces

        # clear up timers, schedules and loggers
        $PodeSession.Server.Routes.Keys.Clone() | ForEach-Object {
            $PodeSession.Server.Routes[$_].Clear()
        }

        $PodeSession.Server.Handlers.Keys.Clone() | ForEach-Object {
            $PodeSession.Server.Handlers[$_] = $null
        }

        $PodeSession.Timers.Clear()
        $PodeSession.Schedules.Clear()
        $PodeSession.Loggers.Clear()

        # clear middle/endware
        $PodeSession.Server.Middleware.Clear()
        $PodeSession.Server.Endware.Clear()

        # clear up view engine
        $PodeSession.Server.ViewEngine.Clear()

        # clear up cookie sessions
        $PodeSession.Server.Cookies.Session.Clear()

        # clear up shared state
        $PodeSession.Server.State.Clear()

        # recreate the session tokens
        dispose $PodeSession.Tokens.Cancellation
        $PodeSession.Tokens.Cancellation = New-Object System.Threading.CancellationTokenSource

        dispose $PodeSession.Tokens.Restart
        $PodeSession.Tokens.Restart = New-Object System.Threading.CancellationTokenSource

        Write-Host " Done" -ForegroundColor Green

        # restart the server
        Start-PodeServer
    }
    catch {
        $Error[0] | Out-Default
        throw $_.Exception
    }
}

function Get-PodeServerType
{
    param (
        [Parameter()]
        [int]
        $Port = 0,

        [Parameter()]
        [int]
        $Interval = 0,

        [switch]
        $Smtp,

        [switch]
        $Tcp,

        [switch]
        $Https
    )

    if ($Smtp) {
        return 'SMTP'
    }

    if ($Tcp) {
        return 'TCP'
    }

    if ($Https) {
        return 'HTTPS'
    }

    if ($Port -gt 0) {
        return 'HTTP'
    }

    if ($Interval -gt 0) {
        return 'SERVICE'
    }

    return 'SCRIPT'
}

function Set-PodePortForServerType
{
    if ($PodeSession.Server.IP.Port -gt 0) {
        return
    }

    switch ($PodeSession.Server.Type.ToUpperInvariant())
    {
        'SMTP' {
            $PodeSession.Server.IP.Port = 25
        }

        'HTTP' {
            $PodeSession.Server.IP.Port = 8080
        }

        'HTTPS' {
            $PodeSession.Server.IP.Port = 8443
        }
    }
}