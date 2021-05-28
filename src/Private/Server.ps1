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

        # if iis, setup global middleware to validate token
        Initialize-PodeIISMiddleware

        # get the server's script and invoke it - to set up routes, timers, middleware, etc
        $_script = $PodeContext.Server.Logic
        if (Test-PodePath -Path $PodeContext.Server.LogicPath -NoStatus) {
            $_script = Convert-PodeFileToScriptBlock -FilePath $PodeContext.Server.LogicPath
        }

        Invoke-PodeScriptBlock -ScriptBlock $_script -NoNewClosure

        # load any modules/snapins
        Import-PodeSnapinsIntoRunspaceState
        Import-PodeModulesIntoRunspaceState

        # load any functions
        Import-PodeFunctionsIntoRunspaceState -ScriptBlock $_script

        # start the runspace pools for web, schedules, etc
        New-PodeRunspacePools
        Open-PodeRunspacePools

        # create timer/schedules for auto-restarting
        New-PodeAutoRestartServer

        if (!$PodeContext.Server.IsServerless -and ($PodeContext.Server.Types.Length -gt 0))
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

        # - service
        if ($PodeContext.Server.IsService) {
            Start-PodeServiceServer
        }

        # - serverless
        elseif ($PodeContext.Server.IsServerless) {
            switch ($PodeContext.Server.ServerlessType.ToUpperInvariant())
            {
                'AZUREFUNCTIONS' {
                    Start-PodeAzFuncServer -Data $Request
                }

                'AWSLAMBDA' {
                    Start-PodeAwsLambdaServer -Data $Request
                }
            }
        }

        # - normal
        else {
            foreach ($_type in $PodeContext.Server.Types) {
                switch ($_type.ToUpperInvariant())
                {
                    'SMTP' {
                        $endpoints += (Start-PodeSmtpServer)
                    }

                    'TCP' {
                        $endpoints += (Start-PodeTcpServer)
                    }

                    'HTTP' {
                        $endpoints += (Start-PodeWebServer -Browse:$Browse)
                    }

                    'WS' {
                        $endpoints += (Start-PodeSignalServer)
                    }
                }
            }
        }

        # set the start time of the server (start and after restart)
        $PodeContext.Metrics.Server.StartTime = [datetime]::UtcNow

        # state what endpoints are being listened on
        if ($endpoints.Length -gt 0) {
            Write-PodeHost "Listening on the following $($endpoints.Length) endpoint(s) [$($PodeContext.Threads.General) thread(s)]:" -ForegroundColor Yellow
            $endpoints | ForEach-Object {
                Write-PodeHost "`t- $($_)" -ForegroundColor Yellow
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
        Write-PodeHost 'Restarting server...' -NoNewline -ForegroundColor Cyan

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

        $PodeContext.Server.Views.Clear()
        $PodeContext.Timers.Clear()
        $PodeContext.Schedules.Clear()
        $PodeContext.Server.Logging.Types.Clear()

        # auto-importers
        $PodeContext.Server.AutoImport.Modules.ExportList = @()
        $PodeContext.Server.AutoImport.Snapins.ExportList = @()
        $PodeContext.Server.AutoImport.Functions.ExportList = @()

        # clear middle/endware
        $PodeContext.Server.Middleware = @()
        $PodeContext.Server.Endware = @()

        # clear misc
        $PodeContext.Server.BodyParsers.Clear()

        # clear endpoints
        $PodeContext.Server.Endpoints.Clear()
        $PodeContext.Server.EndpointsMap.Clear()
        $PodeContext.Server.FindRouteEndpoint = $false

        # clear openapi
        $PodeContext.Server.OpenAPI = Get-PodeOABaseObject

        # clear the sockets
        $PodeContext.Server.WebSockets.Listener = $null
        $PodeContext.Listeners = @()

        # set view engine back to default
        $PodeContext.Server.ViewEngine = @{
            Type = 'html'
            Extension = 'html'
            ScriptBlock = $null
            UsingVariables = $null
            IsDynamic = $false
        }

        # clear up cookie sessions
        $PodeContext.Server.Sessions.Clear()

        # clear up authentication methods
        $PodeContext.Server.Authentications.Clear()

        # clear up shared state
        $PodeContext.Server.State.Clear()

        # reset type if smtp/tcp
        $PodeContext.Server.Types = @()

        # recreate the session tokens
        Close-PodeDisposable -Disposable $PodeContext.Tokens.Cancellation
        $PodeContext.Tokens.Cancellation = New-Object System.Threading.CancellationTokenSource

        Close-PodeDisposable -Disposable $PodeContext.Tokens.Restart
        $PodeContext.Tokens.Restart = New-Object System.Threading.CancellationTokenSource

        # reload the configuration
        $PodeContext.Server.Configuration = Open-PodeConfiguration -Context $PodeContext

        Write-PodeHost " Done" -ForegroundColor Green

        # restart the server
        $PodeContext.Metrics.Server.RestartCount++
        Start-PodeInternalServer
    }
    catch {
        $_ | Write-PodeErrorLog
        throw $_.Exception
    }
}