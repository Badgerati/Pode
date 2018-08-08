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

        [Parameter()]
        [string]
        $Name,

        [Parameter()]
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
        $PodeSession = New-PodeSession -ScriptBlock $ScriptBlock -Port $Port -IP $IP -Threads $Threads `
            -Interval $Interval -ServerRoot $MyInvocation.PSScriptRoot -ServerType $ServerType `
            -DisableLogging:$DisableLogging -FileMonitor:$FileMonitor

        # set ad efault port for the server type
        Set-PodePortForServerType

        # parse ip:port to listen on (if both have been supplied)
        if (!(Test-Empty $IP) -or $PodeSession.IP.Port -gt 0) {
            listen -IPPort "$($IP):$($PodeSession.IP.Port)" -Type $PodeSession.ServerType
        }

        # set it so ctrl-c can terminate
        [Console]::TreatControlCAsInput = $true

        # start the file monitor for interally restarting
        Start-PodeFileMonitor

        # start the server
        Start-PodeServer

        # sit here waiting for termination (unless it's one-off script)
        if ($PodeSession.ServerType -ine 'script') {
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
        Invoke-ScriptBlock -ScriptBlock $PodeSession.ScriptBlock

        # start runspace for timers
        Start-TimerRunspace

        # start runspace for schedules
        Start-ScheduleRunspace

        # start the appropriate server
        switch ($PodeSession.ServerType.ToUpperInvariant())
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
                Write-Host "Looping logic every $($PodeSession.Interval)secs" -ForegroundColor Yellow

                while ($true) {
                    if ($PodeSession.Tokens.Cancellation.IsCancellationRequested) {
                        Close-Pode -Exit
                    }

                    Start-Sleep -Seconds $PodeSession.Interval
                    Invoke-ScriptBlock -ScriptBlock $PodeSession.ScriptBlock
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
        $PodeSession.Routes.Keys.Clone() | ForEach-Object {
            $PodeSession.Routes[$_].Clear()
        }

        $PodeSession.Handlers.Keys.Clone() | ForEach-Object {
            $PodeSession.Handlers[$_] = $null
        }

        $PodeSession.Timers.Clear()
        $PodeSession.Schedules.Clear()
        $PodeSession.Loggers.Clear()

        # clear up view engine
        $PodeSession.ViewEngine.Clear()

        # clear up shared state
        $PodeSession.SharedState.Clear()

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
    if ($PodeSession.IP.Port -gt 0) {
        return
    }

    switch ($PodeSession.ServerType.ToUpperInvariant())
    {
        'SMTP' {
            $PodeSession.IP.Port = 25
        }

        'HTTP' {
            $PodeSession.IP.Port = 8080
        }

        'HTTPS' {
            $PodeSession.IP.Port = 8443
        }
    }
}