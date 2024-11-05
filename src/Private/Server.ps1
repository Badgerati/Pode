function Start-PodeInternalServer {
    param(
        [Parameter()]
        $Request,

        [switch]
        $Browse
    )

    try {
        # Check if the running version of Powershell is EOL
        Write-PodeHost "Pode $(Get-PodeVersion) (PID: $($PID)) " -ForegroundColor Cyan -NoNewline

        if($PodeContext.Metrics.Server.RestartCount -gt 0){
            Write-PodeHost  "[Restarting]" -ForegroundColor Cyan
        }else{
            Write-PodeHost  "[Initializing]" -ForegroundColor Cyan
        }

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
        $PodeContext.Server.EndpointsInfo = @()

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
                        $PodeContext.Server.EndpointsInfo += (Start-PodeSmtpServer)
                    }

                    'TCP' {
                        $PodeContext.Server.EndpointsInfo += (Start-PodeTcpServer)
                    }

                    'HTTP' {
                        $PodeContext.Server.EndpointsInfo += (Start-PodeWebServer -Browse:$Browse)
                    }
                }
            }

            # now go back through, and wait for each server type's runspace pool to be ready
            foreach ($pool in ($PodeContext.Server.EndpointsInfo.Pool | Sort-Object -Unique)) {
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

        Show-ConsoleInfo -ClearHost -ShowHeader

    }
    catch {
        throw
    }
}


function Show-ConsoleInfo {
    param(
        [switch]
        $ClearHost,

        [switch]
        $ShowHeader
    )

    if ( $ClearHost ) {
        Clear-Host
    }
    if ($ShowHeader) {
        $status = $(if ($PodeContext.Server.Suspended) { 'Suspended' } else { 'Running' })
        Write-PodeHost "Pode $(Get-PodeVersion) (PID: $($PID)) [$status]" -ForegroundColor Cyan
    }

    if (!$PodeContext.Server.Suspended) {
        # state what endpoints are being listened on
        Show-PodeEndPointConsoleInfo

        # state the OpenAPI endpoints for each definition
        Show-PodeOAConsoleInfo
    }

    if (! $PodeContext.Server.DisableTermination) {
        $resumeOrSuspend = $(if ($PodeContext.Server.Suspended) { 'Resume' } else { 'Suspend' })
        Write-PodeHost
        Write-PodeHost 'Server Control Commands:' -ForegroundColor Green
        Write-PodeHost '    Ctrl+C   : Gracefully terminate the server.' -ForegroundColor Cyan
        Write-PodeHost '    Ctrl+R   : Restart the server and reload configurations.' -ForegroundColor Cyan
        Write-PodeHost "    Ctrl+U   : $resumeOrSuspend the server." -ForegroundColor Cyan

        if ($PodeContext.Server.Debug.Dump.Enabled) {
            Write-PodeHost '    Ctrl+D   : Generate a diagnostic dump for debugging purposes.' -ForegroundColor Cyan
        }
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

        Close-PodeDisposable -Disposable $PodeContext.Tokens.Dump
        $PodeContext.Tokens.Dump = [System.Threading.CancellationTokenSource]::new()

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

function Suspend-Server {
    param(
        [int]
        $Timeout = 30
    )
    try {
          # inform suspend
        # Suspending server...
        Write-PodeHost 'Suspending server...'  -ForegroundColor Cyan
        Invoke-PodeEvent -Type Suspend
        $PodeContext.Server.Suspended = $true
        $runspaces = Get-Runspace -name 'Pode_*'
        foreach ($r in $runspaces) {
            try {
                [Pode.Embedded.DebuggerHandler]::AttachDebugger($r, $false)
                # Suspend
                Enable-RunspaceDebug -BreakAll -Runspace $r

                Write-PodeHost "Waiting for $($r.Name) to be suspended ." -NoNewLine -ForegroundColor Yellow

                # Initialize the timer
                $startTime = [DateTime]::UtcNow

                # Wait for the event to be triggered or timeout
                while (! [Pode.Embedded.DebuggerHandler]::IsEventTriggered()) {
                    Start-Sleep -Milliseconds 1000
                    Write-PodeHost '.' -NoNewLine

                    if (([DateTime]::UtcNow - $startTime).TotalSeconds -ge $Timeout) {
                        Write-PodeHost "Failed (Timeout reached after $Timeout seconds.)" -ForegroundColor Red
                        return
                    }
                }
                Write-PodeHost 'Done' -ForegroundColor Green
            }
            finally {
                [Pode.Embedded.DebuggerHandler]::DetachDebugger($r)
            }

        }
        start-sleep -seconds 5
        Show-ConsoleInfo -ClearHost -ShowHeader
    }
    catch {
        $_ | Write-PodeErrorLog
    }
    finally {
        Close-PodeDisposable -Disposable $PodeContext.Tokens.SuspendResume
        $PodeContext.Tokens.SuspendResume = [System.Threading.CancellationTokenSource]::new()
    }
}


function Resume-Server {
    try {
         # inform resume
        # Resuming server...
        Write-PodeHost 'Resuming server...' -NoNewline -ForegroundColor Cyan

        Invoke-PodeEvent -Type Resume
        $PodeContext.Server.Suspended = $false
        Start-Sleep 5
        $runspaces = Get-Runspace -name 'Pode_*'
        foreach ($r in $runspaces) {
            # Disable debugging for the runspace. This ensures that the runspace returns to its normal execution state.
            Disable-RunspaceDebug -Runspace $r
        }
        Write-PodeHost 'Done' -ForegroundColor Green
        Start-Sleep 1
        Show-ConsoleInfo -ClearHost -ShowHeader
    }
    finally {
        Close-PodeDisposable -Disposable $PodeContext.Tokens.SuspendResume
        $PodeContext.Tokens.SuspendResume = [System.Threading.CancellationTokenSource]::new()
    }

}


