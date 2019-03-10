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

        [Parameter()]
        [Alias('fme')]
        [string[]]
        $FileMonitorExclude,

        [Parameter()]
        [Alias('fmi')]
        [string[]]
        $FileMonitorInclude,

        [switch]
        $Smtp,

        [switch]
        $Tcp,

        [switch]
        $Http,

        [switch]
        $Https,

        [switch]
        [Alias('dt')]
        $DisableTermination,

        [switch]
        [Alias('dl')]
        $DisableLogging,

        [switch]
        [Alias('fm')]
        $FileMonitor
    )

    # ensure the session is clean
    $PodeContext = $null

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

        # create main context object
        $PodeContext = New-PodeContext -ScriptBlock $ScriptBlock `
            -Threads $Threads `
            -Interval $Interval `
            -ServerRoot $MyInvocation.PSScriptRoot `
            -FileMonitorExclude $FileMonitorExclude `
            -FileMonitorInclude $FileMonitorInclude `
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
        if ([string]::IsNullOrWhiteSpace($PodeContext.Server.Type)) {
            return
        }

        # sit here waiting for termination/cancellation, or to restart the server
        while (!(Test-TerminationPressed -Key $key) -and !($PodeContext.Tokens.Cancellation.IsCancellationRequested)) {
            Start-Sleep -Seconds 1

            # get the next key presses
            $key = Get-ConsoleKey

            # check for internal restart
            if (($PodeContext.Tokens.Restart.IsCancellationRequested) -or (Test-RestartPressed -Key $key)) {
                Restart-PodeServer
            }
        }

        Write-Host 'Terminating...' -NoNewline -ForegroundColor Yellow
        $PodeContext.Tokens.Cancellation.Cancel()
    }
    finally {
        # clean the runspaces and tokens
        Close-Pode -Exit

        # clean the session
        $PodeContext = $null
    }
}

function Start-PodeServer
{
    try
    {
        # create timer/schedules for auto-restarting
        New-PodeAutoRestartServer

        # setup temp drives for internal dirs
        Add-PodePSInbuiltDrives

        # create the runspace state, execute the server logic, and start the runspaces
        New-PodeRunspaceState
        Invoke-ScriptBlock -ScriptBlock $PodeContext.Server.Logic -NoNewClosure
        New-PodeRunspacePools

        $_type = $PodeContext.Server.Type.ToUpperInvariant()
        if (![string]::IsNullOrWhiteSpace($_type))
        {
            # start runspace for loggers
            Start-LoggerRunspace

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
        $PodeContext.Tokens.Cancellation.Cancel()

        # close all current runspaces
        Close-PodeRunspaces -ClosePool

        # remove all of the pode temp drives
        Remove-PodePSDrives

        # clear up timers, schedules and loggers
        $PodeContext.Server.Routes.Keys.Clone() | ForEach-Object {
            $PodeContext.Server.Routes[$_].Clear()
        }

        $PodeContext.Server.Handlers.Keys.Clone() | ForEach-Object {
            $PodeContext.Server.Handlers[$_] = $null
        }

        $PodeContext.Timers.Clear()
        $PodeContext.Schedules.Clear()
        $PodeContext.Server.Logging.Methods.Clear()

        # clear middle/endware
        $PodeContext.Server.Middleware = @()
        $PodeContext.Server.Endware = @()

        # set view engine back to default
        $PodeContext.Server.ViewEngine = @{
            'Engine' = 'html';
            'Extension' = 'html';
            'Script' = $null;
        }

        # clear up cookie sessions
        $PodeContext.Server.Cookies.Session.Clear()

        # clear up authentication methods
        $PodeContext.Server.Authentications.Clear()

        # clear up shared state
        $PodeContext.Server.State.Clear()

        # recreate the session tokens
        dispose $PodeContext.Tokens.Cancellation
        $PodeContext.Tokens.Cancellation = New-Object System.Threading.CancellationTokenSource

        dispose $PodeContext.Tokens.Restart
        $PodeContext.Tokens.Restart = New-Object System.Threading.CancellationTokenSource

        # reload the configuration
        $PodeContext.Server.Configuration = Open-PodeConfiguration -Context $PodeContext

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