<#
.SYNOPSIS
    Starts the internal Pode server, initializing configurations, middleware, routes, and runspaces.

.DESCRIPTION
    This function sets up and starts the internal Pode server. It initializes the server's configurations, routes, middleware, runspace pools, logging, and schedules. It also handles different server modes, such as normal, service, or serverless (Azure Functions, AWS Lambda). The function ensures all necessary components are ready and operational before triggering the server's start.

.PARAMETER Request
    Provides request data for serverless execution scenarios.

.PARAMETER Browse
    A switch to enable browsing capabilities for HTTP servers.

.EXAMPLE
    Start-PodeInternalServer
        Starts the Pode server in the normal mode with all necessary components initialized.

.EXAMPLE
    Start-PodeInternalServer -Request $RequestData
        Starts the Pode server in serverless mode, passing the required request data.

.EXAMPLE
    Start-PodeInternalServer -Browse
        Starts the Pode HTTP server with browsing capabilities enabled.

.NOTES
    - This function is used to start the Pode server, either initially or after a restart.
    - Handles specific setup for serverless types like Azure Functions and AWS Lambda.
    - This is an internal function used within the Pode framework and is subject to change in future releases.
#>
function Start-PodeInternalServer {
    param(
        [Parameter()]
        $Request,

        [switch]
        $Browse
    )

    try {
        $null = Test-PodeVersionPwshEOL -ReportUntested

        #Show starting console
        Show-PodeConsoleInfo -ShowTopSeparator

        # run start event hooks
        Invoke-PodeEvent -Type Starting

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

        # run starting event hooks
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

            if ($PodeContext.Server.EndpointsInfo) {
                # Re-order the endpoints
                $PodeContext.Server.EndpointsInfo = Get-PodeSortedEndpointsInfo -EndpointsInfo $PodeContext.Server.EndpointsInfo

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
            else {
                Write-Verbose 'No Endpoints defined.'
            }
        }


        # set the start time of the server (start and after restart)
        $PodeContext.Metrics.Server.StartTime = [datetime]::UtcNow

        # Trigger the start
        Close-PodeCancellationTokenRequest -Type Start

        Show-PodeConsoleInfo

        # run running event hooks
        Invoke-PodeEvent -Type Running


    }
    catch {
        throw
    }
}

<#
.SYNOPSIS
    Restarts the internal Pode server by clearing all configurations, contexts, and states, and reinitializing the server.

.DESCRIPTION
    This function performs a comprehensive restart of the internal Pode server. It resets all contexts, clears caches, schedules, timers, middleware, and security configurations, and reinitializes the server state. It also reloads the server configuration if enabled and increments the server restart count.

.EXAMPLE
    Restart-PodeInternalServer
        Restarts the Pode server, clearing all configurations and states before starting it again.
.NOTES
    - This function is called internally to restart the Pode server gracefully.
    - Handles cancellation tokens, clean-up processes, and reinitialization.
    - This is an internal function used within the Pode framework and is subject to change in future releases.
#>
function Restart-PodeInternalServer {

    if (!$PodeContext.Tokens.Restart.IsCancellationRequested) {
        return
    }

    try {
        Reset-PodeCancellationToken -Type Start
        # inform restart
        # Restarting server...
        Show-PodeConsoleInfo

        # run restarting event hooks
        Invoke-PodeEvent -Type Restarting

        # cancel the session token
        Close-PodeCancellationTokenRequest -Type Cancellation, Terminate

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
        Reset-PodeCancellationToken -Type Cancellation, Restart, Suspend, Resume, Terminate, Disable

        # if the configuration is enable reload it
        if ( $PodeContext.Server.Configuration.Enabled) {
            # reload the configuration
            $PodeContext.Server.Configuration = Open-PodeConfiguration -Context $PodeContext -ConfigFile $PodeContext.Server.Configuration.ConfigFile
        }

        # restart the server
        $PodeContext.Metrics.Server.RestartCount++

        Start-PodeInternalServer

        # run restarting event hooks
        Invoke-PodeEvent -Type Restart
    }
    catch {
        $_ | Write-PodeErrorLog
        throw $_.Exception
    }
}

<#
.SYNOPSIS
    Determines whether the Pode server should remain open based on its configuration and active components.

.DESCRIPTION
    The `Test-PodeServerKeepOpen` function evaluates the current server state and configuration
    to decide whether to keep the Pode server running. It considers the existence of timers,
    schedules, file watchers, service mode, and server types to make this determination.

    - If any timers, schedules, or file watchers are active, the server remains open.
    - If the server is not running as a service and is either serverless or has no types defined,
      the server will close.
    - In other cases, the server will stay open.

 .NOTES
    This is an internal function used within the Pode framework and is subject to change in future releases.
#>
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

<#
.SYNOPSIS
    Suspends the Pode server and its associated runspaces.

.DESCRIPTION
    This function suspends the Pode server by pausing all associated runspaces and ensuring they enter a debug state.
    It triggers the 'Suspend' event, updates the server's suspension status, and provides progress and feedback during the suspension process.
    This is primarily used internally by the Pode framework to handle server suspension.

.PARAMETER Timeout
    The maximum time, in seconds, to wait for each runspace to be suspended before timing out.
    The default timeout is 30 seconds.

.EXAMPLE
    Suspend-PodeServerInternal -Timeout 60
    # Suspends the Pode server with a timeout of 60 seconds.

.NOTES
    This is an internal function used within the Pode framework and is subject to change in future releases.
#>
function Suspend-PodeServerInternal {
    param(
        [int]
        $Timeout = 30
    )

    # Exit early if no suspension request is pending or if the server is already suspended.
    if (!(Test-PodeCancellationTokenRequest -Type Suspend) -or (Test-PodeServerState -State Suspended)) {
        return
    }

    try {
        # Display suspension initiation message in the console.
        Show-PodeConsoleInfo

        # Trigger the 'Suspending' event for the server.
        Invoke-PodeEvent -Type Suspending

        # Retrieve all Pode-related runspaces for tasks and schedules.
        $runspaces = Get-Runspace | Where-Object { $_.Name -like 'Pode_Tasks_*' -or $_.Name -like 'Pode_Schedules_*' }

        # Iterate over each runspace to initiate suspension.
        $runspaces | Foreach-Object {
            $originalName = $_.Name
            $startTime = [DateTime]::UtcNow
            $elapsedTime = 0

            # Activate debug mode on the runspace to suspend it.
            Enable-RunspaceDebug -BreakAll -Runspace $_

            while (! $_.Debugger.InBreakpoint) {
                # Calculate elapsed suspension time.
                $elapsedTime = ([DateTime]::UtcNow - $startTime).TotalSeconds

                # Exit loop if the runspace is already completed.
                if ($_.Name.StartsWith('_')) {
                    Write-Verbose "$originalName runspace has been completed."
                    break
                }

                # Handle timeout scenario and raise an error if exceeded.
                if ($elapsedTime -ge $Timeout) {
                    $errorMsg = "$($_.Name) failed to suspend (Timeout reached after $Timeout seconds)."
                    Write-PodeHost $errorMsg -ForegroundColor Red
                    throw $errorMsg
                }

                # Pause briefly before rechecking the runspace state.
                Start-Sleep -Milliseconds 200
            }
        }
    }
    catch {
        # Log any errors encountered during suspension.
        $_ | Write-PodeErrorLog

        # Force a resume action to ensure server continuity.
        Set-PodeResumeToken
    }
    finally {
        # Reset cancellation token if a cancellation request was made.
        if ($PodeContext.Tokens.Cancellation.IsCancellationRequested) {
            Reset-PodeCancellationToken -Type Cancellation
        }

        # Trigger the 'Suspend' event for the server.
        Invoke-PodeEvent -Type Suspend

        # Brief pause before refreshing console output.
        Start-Sleep -Seconds 1

        # Refresh the console and display updated information.
        Show-PodeConsoleInfo
    }
}

<#
.SYNOPSIS
    Resumes the Pode server from a suspended state.

.DESCRIPTION
    This function resumes the Pode server, ensuring all associated runspaces are restored to their normal execution state.
    It triggers the 'Resume' event, updates the server's status, and clears the console for a refreshed view.
    The function also provides timeout handling and progress feedback during the resumption process.

.PARAMETER Timeout
    The maximum time, in seconds, to wait for each runspace to exit its suspended state before timing out.
    The default timeout is 30 seconds.

.EXAMPLE
    Resume-PodeServerInternal
    # Resumes the Pode server after being suspended.

.NOTES
    This is an internal function used within the Pode framework and may change in future releases.
#>
function Resume-PodeServerInternal {

    param(
        [int]
        $Timeout = 30
    )

    # Exit early if no resumption request is pending.
    if (!(Test-PodeCancellationTokenRequest -Type Resume)) {
        return
    }

    try {
        # Display resumption initiation message in the console.
        Show-PodeConsoleInfo

        # Trigger the 'Resuming' event for the server.
        Invoke-PodeEvent -Type Resuming

        # Pause briefly to allow processes to stabilize.
        Start-Sleep -Seconds 1

        # Retrieve all runspaces currently in a suspended (debug) state.
        $runspaces = Get-Runspace | Where-Object { ($_.Name -like 'Pode_Tasks_*' -or $_.Name -like 'Pode_Schedules_*') -and $_.Debugger.InBreakpoint }

        # Iterate over each suspended runspace to restore normal execution.
        $runspaces | ForEach-Object {
            # Track the start time for timeout calculations.
            $startTime = [DateTime]::UtcNow
            $elapsedTime = 0

            # Disable debug mode on the runspace to resume it.
            Disable-RunspaceDebug -Runspace $_

            while ($_.Debugger.InBreakpoint) {
                # Calculate the elapsed time since resumption started.
                $elapsedTime = ([DateTime]::UtcNow - $startTime).TotalSeconds

                # Handle timeout scenario and raise an error if exceeded.
                if ($elapsedTime -ge $Timeout) {
                    $errorMsg = "$($_.Name) failed to resume (Timeout reached after $Timeout seconds)."
                    Write-PodeHost $errorMsg -ForegroundColor Red
                    throw $errorMsg
                }

                # Pause briefly before rechecking the runspace state.
                Start-Sleep -Milliseconds 200
            }
        }

        # Pause briefly before refreshing the console view.
        Start-Sleep -Seconds 1
    }
    catch {
        # Log any errors encountered during the resumption process.
        $_ | Write-PodeErrorLog

        # Force a restart action to recover the server.
        Close-PodeCancellationTokenRequest -Type Restart
    }
    finally {
        # Reset the resume cancellation token for future suspension/resumption cycles.
        Reset-PodeCancellationToken -Type Resume

        # Trigger the 'Resume' event for the server.
        Invoke-PodeEvent -Type Resume

        # Clear the console and display refreshed header information.
        Show-PodeConsoleInfo
    }
}

<#
.SYNOPSIS
    Enables new requests by removing the access limit rule that blocks requests when the Pode Watchdog service is active.

.DESCRIPTION
    This function checks if the access limit rule associated with the Pode Watchdog client is present, and if so, it removes it to allow new requests.
    This effectively re-enables access to the service by removing the request blocking.

.NOTES
    This function is used internally to manage Watchdog monitoring and may change in future releases of Pode.
#>
function Enable-PodeServerInternal {

    # Check if the Watchdog middleware exists and remove it if found to allow new requests
    if (!(Test-PodeServerState -State Running) -or (Test-PodeServerIsEnabled) ) {
        return
    }

    # Trigger the 'Enable' event for the server.
    Invoke-PodeEvent -Type Enable

    # remove the access limit rule
    Remove-PodeLimitRateRule -Name $PodeContext.Server.AllowedActions.DisableSettings.LimitRuleName
}

<#
.SYNOPSIS
    Disables new requests by adding an access limit rule that blocks incoming requests when the Pode Watchdog service is active.

.DESCRIPTION
    This function adds an access limit rule to the Pode server to block new incoming requests while the Pode Watchdog client is active.
    It responds to all new requests with a 503 Service Unavailable status and sets a 'Retry-After' header, indicating when the service will be available again.

.NOTES
    This function is used internally to manage Watchdog monitoring and may change in future releases of Pode.
#>
function Disable-PodeServerInternal {
    if (!(Test-PodeServerState -State Running) -or (!( Test-PodeServerIsEnabled)) ) {
        return
    }

    # Trigger the 'Enable' event for the server.
    Invoke-PodeEvent -Type Disable

    # add a rate limit rule to block new requests, returning a 503 Service Unavailable status
    $limitName = $PodeContext.Server.AllowedActions.DisableSettings.LimitRuleName
    $duration = $PodeContext.Server.AllowedActions.DisableSettings.RetryAfter * 1000

    Add-PodeLimitRateRule -Name $limitName -Limit 0 -Duration $duration -StatusCode 503 -Priority ([int]::MaxValue) -Component @(
        New-PodeLimitIPComponent -Group
    )
}

function Test-PodeServerIsEnabled {
    return !(Test-PodeLimitRateRule -Name $PodeContext.Server.AllowedActions.DisableSettings.LimitRuleName)
}