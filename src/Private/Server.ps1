function Start-PodeInternalServer
{
    param (
        [Parameter()]
        $Request,

        [switch]
        $Browse
    )

    try
    {
        # setup temp drives for internal dirs
        Add-PodePSInbuiltDrives

        # create the runspace state, execute the server logic, and start the runspaces
        New-PodeRunspaceState
        Invoke-PodeScriptBlock -ScriptBlock $PodeContext.Server.Logic -NoNewClosure
        New-PodeRunspacePools

        # create timer/schedules for auto-restarting
        New-PodeAutoRestartServer

        $_type = $PodeContext.Server.Type.ToUpperInvariant()
        if (![string]::IsNullOrWhiteSpace($_type) -and !$PodeContext.Server.IsServerless)
        {
            # start runspace for loggers
            Start-PodeLoggingRunspace

            # start runspace for timers
            Start-PodeTimerRunspace

            # start runspace for schedules
            Start-PodeScheduleRunspace

            # start runspace for gui
            Start-PodeGuiRunspace
        }

        # start the appropriate server
        switch ($_type)
        {
            'SMTP' {
                Start-PodeSmtpServer
            }

            'TCP' {
                Start-PodeTcpServer
            }

            { $_ -ieq 'HTTP' -or $_ -ieq 'HTTPS' } {
                Start-PodeWebServer -Browse:$Browse
            }

            'SERVICE' {
                Start-PodeServiceServer
            }

            'AZUREFUNCTIONS' {
                Start-PodeAzFuncServer -Data $Request
            }

            'AWSLAMBDA' {
                Start-PodeAwsLambdaServer -Data $Request
            }
        }
    }
    catch {
        throw $_.Exception
    }
}

function Restart-PodeInternalServer
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
            $PodeContext.Server.Handlers[$_].Clear()
        }

        $PodeContext.Timers.Clear()
        $PodeContext.Schedules.Clear()
        $PodeContext.Server.Logging.Types.Clear()

        # clear middle/endware
        $PodeContext.Server.Middleware = @()
        $PodeContext.Server.Endware = @()

        # set view engine back to default
        $PodeContext.Server.ViewEngine = @{
            Type = 'html'
            Extension = 'html'
            Script = $null
            IsDynamic = $false
        }

        # clear up cookie sessions
        $PodeContext.Server.Cookies.Session.Clear()

        # clear up authentication methods
        $PodeContext.Server.Authentications.Clear()

        # clear up shared state
        $PodeContext.Server.State.Clear()

        # recreate the session tokens
        Close-PodeDisposable -Disposable $PodeContext.Tokens.Cancellation
        $PodeContext.Tokens.Cancellation = New-Object System.Threading.CancellationTokenSource

        Close-PodeDisposable -Disposable $PodeContext.Tokens.Restart
        $PodeContext.Tokens.Restart = New-Object System.Threading.CancellationTokenSource

        # reload the configuration
        $PodeContext.Server.Settings = Open-PodeConfiguration -Context $PodeContext

        Write-Host " Done" -ForegroundColor Green

        # restart the server
        Start-PodeInternalServer
    }
    catch {
        $_ | Write-PodeErrorLog
        throw $_.Exception
    }
}