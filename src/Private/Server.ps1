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

        # run start event hooks
        Invoke-PodeEvent -Type Start

        # start timer for task housekeeping
        Start-PodeTaskHousekeeper

        # create timer/schedules for auto-restarting
        New-PodeAutoRestartServer

        # start the runspace pools for web, schedules, etc
        New-PodeRunspacePools
        Open-PodeRunspacePools

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

            # start runspace for websockets
            Start-PodeWebSocketRunspace
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
            # start each server type
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
                }
            }

            # now go back through, and wait for each server type's runspace pool to be ready
            foreach ($pool in ($endpoints.Pool | Sort-Object -Unique)) {
                $start = [datetime]::Now
                Write-Verbose "Waiting for the $($pool) RunspacePool to be Ready"

                # wait
                while ($PodeContext.RunspacePools[$pool].State -ieq 'Waiting') {
                    Start-Sleep -Milliseconds 100
                }

                Write-Verbose "$($pool) RunspacePool $($PodeContext.RunspacePools[$pool].State) [duration: $(([datetime]::Now - $start).TotalSeconds)s]"

                # errored?
                if ($PodeContext.RunspacePools[$pool].State -ieq 'error') {
                    throw "$($pool) RunspacePool failed to load"
                }
            }
        }

        # set the start time of the server (start and after restart)
        $PodeContext.Metrics.Server.StartTime = [datetime]::UtcNow

        # state what endpoints are being listened on
        if ($endpoints.Length -gt 0) {
            Write-PodeHost "Listening on the following $($endpoints.Length) endpoint(s) [$($PodeContext.Threads.General) thread(s)]:" -ForegroundColor Yellow
            $endpoints | ForEach-Object {
                Write-PodeHost "`t- $($_.Url)" -ForegroundColor Yellow
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

        # run restart event hooks
        Invoke-PodeEvent -Type Restart

        # cancel the session token
        $PodeContext.Tokens.Cancellation.Cancel()

        # close all current runspaces
        Close-PodeRunspaces -ClosePool

        # remove all of the pode temp drives
        Remove-PodePSDrives

        # clear-up modules
        $PodeContext.Server.Modules.Clear()

        # clear up timers, schedules and loggers
        $PodeContext.Server.Routes | Clear-PodeHashtableInnerKeys
        $PodeContext.Server.Handlers | Clear-PodeHashtableInnerKeys
        $PodeContext.Server.Verbs | Clear-PodeHashtableInnerKeys
        $PodeContext.Server.Events | Clear-PodeHashtableInnerKeys

        $PodeContext.Server.Views.Clear()
        $PodeContext.Timers.Items.Clear()
        $PodeContext.Server.Logging.Types.Clear()

        # clear schedules
        $PodeContext.Schedules.Items.Clear()
        $PodeContext.Schedules.Processes.Clear()

        # clear tasks
        $PodeContext.Tasks.Items.Clear()
        $PodeContext.Tasks.Results.Clear()

        # auto-importers
        $PodeContext.Server.AutoImport.Modules.ExportList = @()
        $PodeContext.Server.AutoImport.Snapins.ExportList = @()
        $PodeContext.Server.AutoImport.Functions.ExportList = @()

        # clear middle/endware
        $PodeContext.Server.Middleware = @()
        $PodeContext.Server.Endware = @()

        # clear body parsers
        $PodeContext.Server.BodyParsers.Clear()

        # clear security headers
        $PodeContext.Server.Security.Headers.Clear()
        $PodeContext.Server.Security.Cache | Clear-PodeHashtableInnerKeys

        # clear endpoints
        $PodeContext.Server.Endpoints.Clear()
        $PodeContext.Server.EndpointsMap.Clear()
        $PodeContext.Server.FindEndpoints = @{
            Route = $false
            Smtp  = $false
            Tcp   = $false
        }

        # clear openapi
        $PodeContext.Server.OpenAPI = Get-PodeOABaseObject

        # clear the sockets
        $PodeContext.Server.Signals.Enabled = $false
        $PodeContext.Server.Signals.Listener = $null
        $PodeContext.Listeners = @()
        $PodeContext.Receivers = @()

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

        # clear up output
        $PodeContext.Server.Output.Variables.Clear()

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