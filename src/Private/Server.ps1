function Start-PodeInternalServer {
    param(
        [Parameter()]
        $Request,

        [switch]
        $Browse
    )

    try {
        # Check if the running version of Powershell is EOL
        Write-PodeHost "Pode $(Get-PodeVersion) (PID: $($PID))" -ForegroundColor Cyan
        $null = Test-PodeVersionPwshEOL -ReportUntested

        # setup temp drives for internal dirs
        Add-PodePSInbuiltDrive

        # setup inbuilt scoped vars
        Add-PodeScopedVariablesInbuilt

        # create the shared runspace state
        New-PodeRunspaceState

        # if iis, setup global middleware to validate token
        Initialize-PodeIISMiddleware

        # load any secret vaults
        Import-PodeSecretVaultsIntoRegistry

        # get the server's script and invoke it - to set up routes, timers, middleware, etc
        $_script = $PodeContext.Server.Logic
        if (Test-PodePath -Path $PodeContext.Server.LogicPath -NoStatus) {
            $_script = Convert-PodeFileToScriptBlock -FilePath $PodeContext.Server.LogicPath
        }

        $_script = Convert-PodeScopedVariables -ScriptBlock $_script -Exclude Session, Using
        $null = Invoke-PodeScriptBlock -ScriptBlock $_script -NoNewClosure -Splat

        #Validate OpenAPI definitions
        Test-PodeOADefinitionInternal

        # load any modules/snapins
        Import-PodeSnapinsIntoRunspaceState
        Import-PodeModulesIntoRunspaceState

        # load any functions
        Import-PodeFunctionsIntoRunspaceState -ScriptBlock $_script

        # run start event hooks
        Invoke-PodeEvent -Type Start

        # start timer for task housekeeping
        Start-PodeTaskHousekeeper

        # start the cache housekeeper
        Start-PodeCacheHousekeeper

        # create timer/schedules for auto-restarting
        New-PodeAutoRestartServer

        # start the runspace pools for web, schedules, etc
        New-PodeRunspacePool
        Open-PodeRunspacePool

        if (!$PodeContext.Server.IsServerless) {
            # start runspace for loggers
            Start-PodeLoggingRunspace

            # start runspace for schedules
            Start-PodeScheduleRunspace

            # start runspace for timers
            Start-PodeTimerRunspace

            # start runspace for gui
            Start-PodeGuiRunspace

            # start runspace for websockets
            Start-PodeWebSocketRunspace

            # start runspace for file watchers
            Start-PodeFileWatcherRunspace
        }

        # start the appropriate server
        $endpoints = @()

        # - service
        if ($PodeContext.Server.IsService) {
            Start-PodeServiceServer
        }

        # - serverless
        elseif ($PodeContext.Server.IsServerless) {
            switch ($PodeContext.Server.ServerlessType.ToUpperInvariant()) {
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
                switch ($_type.ToUpperInvariant()) {
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
                    throw ($PodeLocale.runspacePoolFailedToLoadExceptionMessage -f $pool) #"$($pool) RunspacePool failed to load"
                }
            }
        }

        # set the start time of the server (start and after restart)
        $PodeContext.Metrics.Server.StartTime = [datetime]::UtcNow

        # run running event hooks
        Invoke-PodeEvent -Type Running

        # state what endpoints are being listened on
        if ($endpoints.Length -gt 0) {

            # Listening on the following $endpoints.Length endpoint(s) [$PodeContext.Threads.General thread(s)]
            Write-PodeHost ($PodeLocale.listeningOnEndpointsMessage -f $endpoints.Length, $PodeContext.Threads.General) -ForegroundColor Yellow
            $endpoints | ForEach-Object {
                $flags = @()
                if ($_.DualMode) {
                    $flags += 'DualMode'
                }

                if ($flags.Length -eq 0) {
                    $flags = [string]::Empty
                }
                else {
                    $flags = "[$($flags -join ',')]"
                }

                Write-PodeHost "`t- $($_.Url) $($flags)" -ForegroundColor Yellow
            }
            # state the OpenAPI endpoints for each definition
            foreach ($key in  $PodeContext.Server.OpenAPI.Definitions.keys) {
                $bookmarks = $PodeContext.Server.OpenAPI.Definitions[$key].hiddenComponents.bookmarks
                if ( $bookmarks) {
                    Write-PodeHost
                    if (!$OpenAPIHeader) {
                        # OpenAPI Info
                        Write-PodeHost $PodeLocale.openApiInfoMessage -ForegroundColor Yellow
                        $OpenAPIHeader = $true
                    }
                    Write-PodeHost " '$key':" -ForegroundColor Yellow

                    if ($bookmarks.route.count -gt 1 -or $bookmarks.route.Endpoint.Name) {
                        # Specification
                        Write-PodeHost "   - $($PodeLocale.specificationMessage):" -ForegroundColor Yellow
                        foreach ($endpoint in   $bookmarks.route.Endpoint) {
                            Write-PodeHost "     . $($endpoint.Protocol)://$($endpoint.Address)$($bookmarks.openApiUrl)" -ForegroundColor Yellow
                        }
                        # Documentation
                        Write-PodeHost "   - $($PodeLocale.documentationMessage):" -ForegroundColor Yellow
                        foreach ($endpoint in   $bookmarks.route.Endpoint) {
                            Write-PodeHost "     . $($endpoint.Protocol)://$($endpoint.Address)$($bookmarks.path)" -ForegroundColor Yellow
                        }
                    }
                    else {
                        # Specification
                        Write-PodeHost "   - $($PodeLocale.specificationMessage):" -ForegroundColor Yellow
                        $endpoints | ForEach-Object {
                            $url = [System.Uri]::new( [System.Uri]::new($_.Url), $bookmarks.openApiUrl)
                            Write-PodeHost "     . $url" -ForegroundColor Yellow
                        }
                        Write-PodeHost "   - $($PodeLocale.documentationMessage):" -ForegroundColor Yellow
                        $endpoints | ForEach-Object {
                            $url = [System.Uri]::new( [System.Uri]::new($_.Url), $bookmarks.path)
                            Write-PodeHost "     . $url" -ForegroundColor Yellow
                        }
                    }
                }
            }
        }
    }
    catch {
        throw
    }
}

function Restart-PodeInternalServer {
    try {
        # inform restart
        # Restarting server...
        Write-PodeHost $PodeLocale.restartingServerMessage -NoNewline -ForegroundColor Cyan

        # run restart event hooks
        Invoke-PodeEvent -Type Restart

        # cancel the session token
        $PodeContext.Tokens.Cancellation.Cancel()

        # close all current runspaces
        Close-PodeRunspace -ClosePool

        # remove all of the pode temp drives
        Remove-PodePSDrive

        # clear-up modules
        $PodeContext.Server.Modules.Clear()

        # clear up timers, schedules and loggers
        Clear-PodeHashtableInnerKey -InputObject $PodeContext.Server.Routes
        Clear-PodeHashtableInnerKey -InputObject $PodeContext.Server.Handlers
        Clear-PodeHashtableInnerKey -InputObject $PodeContext.Server.Events

        if ($null -ne $PodeContext.Server.Verbs) {
            $PodeContext.Server.Verbs.Clear()
        }

        $PodeContext.Server.Views.Clear()
        $PodeContext.Timers.Items.Clear()
        $PodeContext.Server.Logging.Types.Clear()

        # clear schedules
        $PodeContext.Schedules.Items.Clear()
        $PodeContext.Schedules.Processes.Clear()

        # clear tasks
        $PodeContext.Tasks.Items.Clear()
        $PodeContext.Tasks.Processes.Clear()

        # clear file watchers
        $PodeContext.Fim.Items.Clear()

        # auto-importers
        Reset-PodeAutoImportConfiguration

        # clear middle/endware
        $PodeContext.Server.Middleware = @()
        $PodeContext.Server.Endware = @()

        # clear body parsers
        $PodeContext.Server.BodyParsers.Clear()

        # clear security headers
        $PodeContext.Server.Security.Headers.Clear()
        Clear-PodeHashtableInnerKey -InputObject $PodeContext.Server.Security.Cache

        # clear endpoints
        $PodeContext.Server.Endpoints.Clear()
        $PodeContext.Server.EndpointsMap.Clear()

        # clear openapi
        $PodeContext.Server.OpenAPI = Initialize-PodeOpenApiTable -DefaultDefinitionTag $PodeContext.Server.Configuration.Web.OpenApi.DefaultDefinitionTag
        # clear the sockets
        $PodeContext.Server.Signals.Enabled = $false
        $PodeContext.Server.Signals.Listener = $null
        $PodeContext.Server.Http.Listener = $null
        $PodeContext.Listeners = @()
        $PodeContext.Receivers = @()
        $PodeContext.Watchers = @()

        # set view engine back to default
        $PodeContext.Server.ViewEngine = @{
            Type           = 'html'
            Extension      = 'html'
            ScriptBlock    = $null
            UsingVariables = $null
            IsDynamic      = $false
        }

        # clear up cookie sessions
        $PodeContext.Server.Sessions.Clear()

        # clear up authentication methods
        $PodeContext.Server.Authentications.Methods.Clear()
        $PodeContext.Server.Authorisations.Methods.Clear()

        # clear up shared state
        $PodeContext.Server.State.Clear()

        # clear scoped variables
        $PodeContext.Server.ScopedVariables.Clear()

        # clear cache
        $PodeContext.Server.Cache.Items.Clear()
        $PodeContext.Server.Cache.Storage.Clear()

        # clear up secret vaults/cache
        Unregister-PodeSecretVaultsInternal -ThrowError
        $PodeContext.Server.Secrets.Vaults.Clear()
        $PodeContext.Server.Secrets.Keys.Clear()

        # dispose mutex/semaphores
        Clear-PodeLockables
        Clear-PodeMutexes
        Clear-PodeSemaphores

        # clear up output
        $PodeContext.Server.Output.Variables.Clear()

        # reset type if smtp/tcp
        $PodeContext.Server.Types = @()

        # recreate the session tokens
        Close-PodeDisposable -Disposable $PodeContext.Tokens.Cancellation
        $PodeContext.Tokens.Cancellation = [System.Threading.CancellationTokenSource]::new()

        Close-PodeDisposable -Disposable $PodeContext.Tokens.Restart
        $PodeContext.Tokens.Restart = [System.Threading.CancellationTokenSource]::new()

        # reload the configuration
        $PodeContext.Server.Configuration = Open-PodeConfiguration -Context $PodeContext

        # done message
        Write-PodeHost $PodeLocale.doneMessage -ForegroundColor Green

        # restart the server
        $PodeContext.Metrics.Server.RestartCount++
        Start-PodeInternalServer
    }
    catch {
        $_ | Write-PodeErrorLog
        throw $_.Exception
    }
}

function Test-PodeServerKeepOpen {
    # if we have any timers/schedules/fim - keep open
    if ((Test-PodeTimersExist) -or (Test-PodeSchedulesExist) -or (Test-PodeFileWatchersExist)) {
        return $true
    }

    # if not a service, and not any type/serverless - close server
    if (!$PodeContext.Server.IsService -and (($PodeContext.Server.Types.Length -eq 0) -or $PodeContext.Server.IsServerless)) {
        return $false
    }

    # keep server open
    return $true
}