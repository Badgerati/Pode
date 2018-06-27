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

        [switch]
        $Smtp,

        [switch]
        $Tcp,

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
    if (!(Test-IPAddress $IP)) {
        throw "Invalid IP address has been supplied: $($IP)"
    }

    try {
        # get the current server type
        $serverType = Get-PodeServerType -Port $Port -Interval $Interval -Smtp:$Smtp -Tcp:$Tcp -Https:$Https

        # create session object
        $PodeSession = New-PodeSession -ScriptBlock $ScriptBlock -Port $Port -IP $IP `
            -Interval $Interval -ServerRoot $MyInvocation.PSScriptRoot -ServerType $ServerType `
            -DisableLogging:$DisableLogging -FileMonitor:$FileMonitor

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
                if (Test-PodeEnvServerRestart) {
                    Restart-PodeServer
                }
            }

            Write-Host 'Terminating...' -NoNewline
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
    # run the logic
    . ($PodeSession.ScriptBlock)

    # start runspace for timers
    Start-TimerRunspace

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
                . ($PodeSession.ScriptBlock)
            }
        }
    }
}

function Restart-PodeServer
{
    try
    {
        Write-Host 'Restarting server...' -NoNewline -ForegroundColor Cyan

        # cancel the session token
        $PodeSession.Tokens.Cancellation.Cancel()

        # close all current runspaces
        Close-PodeRunspaces

        # clear up timers and loggers
        $PodeSession.Routes.Keys.Clone() | ForEach-Object {
            $PodeSession.Routes[$_].Clear()
        }

        $PodeSession.Handlers.Keys.Clone() | ForEach-Object {
            $PodeSession.Handlers[$_] = $null
        }

        $PodeSession.Timers.Clear()
        $PodeSession.Loggers.Clear()

        # clear up view engine
        $PodeSession.ViewEngine.Clear()

        # clear up shared state
        $PodeSession.SharedState.Clear()

        # recreate the session token
        $PodeSession.Tokens.Cancellation.Dispose()
        $PodeSession.Tokens.Cancellation = New-Object System.Threading.CancellationTokenSource

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
        [ValidateNotNull()]
        [int]
        $Port = 0,

        [Parameter()]
        [ValidateNotNull()]
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