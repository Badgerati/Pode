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
            -Threads $Threads `
            -Interval $Interval `
            -ServerRoot $MyInvocation.PSScriptRoot `
            -DisableLogging:$DisableLogging `
            -FileMonitor:$FileMonitor

        # for legacy support, create initial listener from Server parameters
        if (@('http', 'https', 'smtp', 'tcp') -icontains $serverType) {
            listen "$($IP):$($Port)" $serverType
        }

        # set it so ctrl-c can terminate
        [Console]::TreatControlCAsInput = $true

        # start the file monitor for interally restarting
        Start-PodeFileMonitor

        # start the server
        Start-PodeServer

        # at this point, if it's just a one-one off script, return
        if ([string]::IsNullOrWhiteSpace($PodeSession.Server.Type)) {
            return
        }

        # sit here waiting for termination or cancellation
        while (!(Test-TerminationPressed -Key $key) -and !($PodeSession.Tokens.Cancellation.IsCancellationRequested)) {
            Start-Sleep -Seconds 1

            # get the next key presses
            $key = Get-ConsoleKey

            # check for internal restart
            if (($PodeSession.Tokens.Restart.IsCancellationRequested) -or (Test-RestartPressed -Key $key)) {
                Restart-PodeServer
            }
        }

        Write-Host 'Terminating...' -NoNewline -ForegroundColor Yellow
        $PodeSession.Tokens.Cancellation.Cancel()
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
        # setup temp drives for internal dirs
        Add-PodePSInbuiltDrives

        # run the logic
        Invoke-ScriptBlock -ScriptBlock $PodeSession.Server.Logic -NoNewClosure

        $_type = $PodeSession.Server.Type.ToUpperInvariant()
        if (![string]::IsNullOrWhiteSpace($_type))
        {
            # start runspace for timers
            Start-TimerRunspace

            # start runspace for schedules
            Start-ScheduleRunspace

            # start runspace for gui
            Start-GuiRunspace
        }

        # start the appropriate server
        switch ($_type)
        {
            'SMTP' {
                Start-SmtpServer
            }

            'TCP' {
                Start-TcpServer
            }

            { $_ -ieq 'HTTP' -or $_ -ieq 'HTTPS' } {
                Start-WebServer
            }

            'SERVICE' {
                Start-ServiceServer
            }
        }
    }
    catch {
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

        # remove all of the pode temp drives
        Remove-PodePSDrives

        # clear up timers, schedules and loggers
        $PodeSession.Server.Routes.Keys.Clone() | ForEach-Object {
            $PodeSession.Server.Routes[$_].Clear()
        }

        $PodeSession.Server.Handlers.Keys.Clone() | ForEach-Object {
            $PodeSession.Server.Handlers[$_] = $null
        }

        $PodeSession.Timers.Clear()
        $PodeSession.Schedules.Clear()
        $PodeSession.Server.Logging.Methods.Clear()

        # clear middle/endware
        $PodeSession.Server.Middleware = @()
        $PodeSession.Server.Endware = @()

        # clear up view engine
        $PodeSession.Server.ViewEngine.Clear()

        # clear up cookie sessions
        $PodeSession.Server.Cookies.Session.Clear()

        # clear up authentication methods
        $PodeSession.Server.Authentications.Clear()

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

    return ([string]::Empty)
}