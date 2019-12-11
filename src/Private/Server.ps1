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

        # create the shared runspace state
        New-PodeRunspaceState

        # get the server's script and invoke it - to set up routes, timers, middleware, etc
        $_script = $PodeContext.Server.Logic
        if (Test-PodePath -Path $PodeContext.Server.LogicPath -NoStatus) {
            $_script = Convert-PodeFileToScriptBlock -FilePath $PodeContext.Server.LogicPath
        }

        Invoke-PodeScriptBlock -ScriptBlock $_script -NoNewClosure

        # start the runspace pools for web, schedules, etc
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
        $endpoints = @()

        switch ($_type)
        {
            'SMTP' {
                $endpoints += (Start-PodeSmtpServer)
            }

            'TCP' {
                $endpoints += (Start-PodeTcpServer)
            }

            { ($_ -ieq 'HTTP') -or ($_ -ieq 'HTTPS') } {
                $endpoints += (Start-PodeWebServer -Browse:$Browse)
            }

            'PODE' {
                $endpoints += (Start-PodeSocketServer -Browse:$Browse)
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

        # start web sockets if enabled
        if ($PodeContext.Server.WebSockets.Enabled) {
            $endpoints += (Start-PodeSignalServer)
        }

        # state what endpoints are being listened on
        if ($endpoints.Length -gt 0) {
            Write-Host "Listening on the following $($endpoints.Length) endpoint(s) [$($PodeContext.Threads) thread(s)]:" -ForegroundColor Yellow
            $endpoints | ForEach-Object {
                Write-Host "`t- $($_)" -ForegroundColor Yellow
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

        # clear misc
        $PodeContext.Server.BodyParsers.Clear()

        # clear endpoints
        $PodeContext.Server.Endpoints = @()

        # clear the sockets
        $PodeContext.Server.Sockets.Listeners = @()
        $PodeContext.Server.Sockets.Queues.Connections = [System.Collections.Concurrent.ConcurrentQueue[System.Net.Sockets.SocketAsyncEventArgs]]::new()

        # clear the websockets
        $PodeContext.Server.WebSockets.Listeners = @()
        $PodeContext.Server.WebSockets.Queues.Sockets.Clear()
        $PodeContext.Server.WebSockets.Queues.Connections = [System.Collections.Concurrent.ConcurrentQueue[System.Net.Sockets.SocketAsyncEventArgs]]::new()

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
        $PodeContext.Server.Configuration = Open-PodeConfiguration -Context $PodeContext

        Write-Host " Done" -ForegroundColor Green

        # restart the server
        Start-PodeInternalServer
    }
    catch {
        $_ | Write-PodeErrorLog
        throw $_.Exception
    }
}