function Start-PodeInternalServer {
    param(
        [Parameter()]
        $Request,

        [switch]
        $Browse
    )

    try {
        Show-PodeConsoleInfo

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

        # Trigger the start
        $PodeContext.Tokens.Start.Cancel()

        # set the start time of the server (start and after restart)
        $PodeContext.Metrics.Server.StartTime = [datetime]::UtcNow

        # run running event hooks
        Invoke-PodeEvent -Type Running

        Show-PodeConsoleInfo

    }
    catch {
        throw
    }
}

<#
.SYNOPSIS
    Displays Pode server information on the console, including version, PID, status, endpoints, and control commands.

.DESCRIPTION
    The Show-PodeConsoleInfo function displays key information about the current Pode server instance.
    It optionally clears the console before displaying server details such as version, process ID (PID), and running status.
    If the server is running, it also displays information about active endpoints and OpenAPI definitions.
    Additionally, it provides server control commands like restart, suspend.

.PARAMETER ClearHost
    Clears the console screen before displaying server information.

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function Show-PodeConsoleInfo {
    param(
        [switch]
        $ClearHost,

        [switch]
        $Force
    )

    $serverState = (Get-PodeServerState)

    if (!$PodeContext) { return }

    $headerColor = $PodeContext.Server.Console.Colors.Header
    $helpColor = $PodeContext.Server.Console.Colors.Help


    if ($PodeContext.Server.Console.Quiet -and !$Force) {
        return
    }


    if ($ClearHost -or $PodeContext.Server.Console.ClearHost) {
        Clear-Host
    }

    switch ($serverState) {
        'Suspended' {
            $status = $Podelocale.suspendedMessage
            $showHelp = (!$PodeContext.Server.Console.DisableConsoleInput -and $PodeContext.Server.Console.ShowHelp)
            $noHeaderNewLine = !$showHelp
            $ctrlH = !$showHelp
            break
        }
        'Restarting' {
            $status = $Podelocale.restartingMessage
            $showHelp = $false
            $noHeaderNewLine = $true
            $ctrlH = $false
            break
        }
        'Starting' {
            $status = $Podelocale.startingMessage
            $showHelp = $false
            $noHeaderNewLine = $true
            $ctrlH = $false
            break
        }
        'Running' {
            $status = $Podelocale.runningMessage
            $showHelp = (!$PodeContext.Server.Console.DisableConsoleInput -and $PodeContext.Server.Console.ShowHelp)
            $noHeaderNewLine = !$showHelp
            $ctrlH = !$showHelp
            break
        }
        'Terminating' {
            $status = $Podelocale.terminatingMessage
            $showHelp = $false
            $noHeaderNewLine = $true
            $ctrlH = $false
            break
        }
        'Terminated' {
            $status = 'Terminated'
            $showHelp = $false
            $noHeaderNewLine = $false
            $ctrlH = $false
            break
        }
        default {
            return
        }
    }

    Write-PodeHost "`rPode $(Get-PodeVersion) (PID: $($PID)) [$status] " -ForegroundColor $headerColor -Force:$Force -NoNewLine:$noHeaderNewLine
    if ($ctrlH ) {
        Write-PodeHost '- Ctrl+H for the Command List'  -ForegroundColor $headerColor -Force:$Force
    }

    if ($serverState -eq 'Running') {
        if ($PodeContext.Server.Console.ShowEndpoints) {
            # state what endpoints are being listened on
            Show-PodeEndPointConsoleInfo -Force:$Force
        }
        if ($PodeContext.Server.Console.ShowOpenAPI) {
            # state the OpenAPI endpoints for each definition
            Show-PodeOAConsoleInfo -Force:$Force
        }
    }

    if ($showHelp) {
        $resumeOrSuspend = $(if ($serverState -eq 'Suspended') { $Podelocale.ResumeServerMessage } else { $Podelocale.SuspendServerMessage })
        Write-PodeHost -Force:$Force
        Write-PodeHost $Podelocale.ServerControlCommandsTitle -ForegroundColor Green -Force:$Force
        Write-PodeHost "    Ctrl+C   : $($Podelocale.GracefullyTerminateMessage)" -ForegroundColor $helpColor -Force:$Force
        Write-PodeHost "    Ctrl+R   : $($Podelocale.RestartServerMessage)" -ForegroundColor $helpColor -Force:$Force
        Write-PodeHost "    Ctrl+U   : $resumeOrSuspend" -ForegroundColor $helpColor -Force:$Force

        if ((Get-PodeEndpointUrl) -and ($serverState -ne 'Suspended') ) {
            Write-PodeHost "    Ctrl+B   : $($Podelocale.OpenHttpEndpointMessage)" -ForegroundColor $helpColor -Force:$Force
        }

        Write-PodeHost '    ----' -ForegroundColor $helpColor -Force:$Force
        Write-PodeHost '    Ctrl+H   : Hide this help' -ForegroundColor $helpColor -Force:$Force
        Write-PodeHost "    Ctrl+E   : $(if($PodeContext.Server.Console.ShowEndpoints){'Hide'}else{'Show'}) Endpoints" -ForegroundColor $helpColor -Force:$Force
        if (Test-PodeOAEnabled) {
            Write-PodeHost "    Ctrl+O   : $(if($PodeContext.Server.Console.ShowOpenAPI){'Hide'}else{'Show'}) OpenAPI" -ForegroundColor $helpColor -Force:$Force
        }
        Write-PodeHost '    Ctrl+L   : Clear the Console' -ForegroundColor $helpColor -Force:$Force

        Write-PodeHost "    Ctrl+T   : $(if($PodeContext.Server.Console.Quiet){'Disable'}else{'Enable'}) Quiet Mode" -ForegroundColor $helpColor -Force:$Force
    }
}

function Restart-PodeInternalServer {

    if (!$PodeContext.Tokens.Restart.IsCancellationRequested) {
        return
    }

    try {
        Reset-PodeCancellationToken -Type Start
        # inform restart
        # Restarting server...
        #  Write-PodeHost $PodeLocale.restartingServerMessage -NoNewline -ForegroundColor Yellow
        Show-PodeConsoleInfo
        # run restart event hooks
        Invoke-PodeEvent -Type Restart

        # cancel the session token
        $PodeContext.Tokens.Cancellation.Cancel()
        $PodeContext.Tokens.Terminate.Cancel()

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
        Reset-PodeCancellationToken -Type Cancellation, Restart, Suspend, Resume, Terminate

        # reload the configuration
        $PodeContext.Server.Configuration = Open-PodeConfiguration -Context $PodeContext

        # done message
        #     Write-PodeHost $PodeLocale.doneMessage -ForegroundColor Green

        # restart the server
        $PodeContext.Metrics.Server.RestartCount++

        # reset tokens if needed
        if ( $PodeContext.Tokens.Cancellation.IsCancellationRequested) {
            Reset-PodeCancellationToken -Type Cancellation
        }
        if ( $PodeContext.Tokens.Suspend.IsCancellationRequested) {
            Reset-PodeCancellationToken -Type Suspend
        }

        Start-PodeInternalServer
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
    This function is primarily used internally by Pode to manage the server lifecycle.
    It helps ensure the server remains active only when necessary based on its current state.


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
    Suspends the Pode server and its runspaces.

.DESCRIPTION
    This function suspends the Pode server by pausing all associated runspaces and ensuring they enter a debug state.
    It triggers the 'Suspend' event, updates the server's suspended status, and provides feedback during the suspension process.

.PARAMETER Timeout
    The maximum time, in seconds, to wait for each runspace to be suspended before timing out. Default is 30 seconds.

.EXAMPLE
    Suspend-PodeServerInternal -Timeout 60
    # Suspends the Pode server with a timeout of 60 seconds.

.NOTES
    This is an internal function used within the Pode framework.
    It may change in future releases.

#>
function Suspend-PodeServerInternal {
    param(
        [int]
        $Timeout = 30
    )

    # Check if the cancellation for suspend tokens is not requested.
    # If not, exit the current scope early.
    if (!$PodeContext.Tokens.Suspend.IsCancellationRequested) {
        return
    }

    try {

        # Inform user that the server is suspending
        $suspendActivityId = (Get-Random)
        # Inform user that the server is suspending

        Write-Progress -Activity $PodeLocale.SuspendingMessage `
            -Status 'Invoke Suspend Event' `
            -PercentComplete 3 `
            -Id $suspendActivityId
        # Trigger the Suspend event
        Invoke-PodeEvent -Type Suspend

        start-sleep 1
        try {
            Write-Progress -Activity $PodeLocale.SuspendingMessage `
                -Status $PodeLocale.suspendingRunspaceMessage `
                -PercentComplete 5 `
                -Id $suspendActivityId

            # Retrieve all runspaces related to Pode ordered by name so the Main runspace are the first to be suspended (To avoid the process hunging)
            $runspaces = Get-Runspace | Where-Object { $_.Name -like 'Pode_Tasks_*' -or $_.Name -like 'Pode_Schedules_*' } | Sort-Object Name

            # Initialize the master progress bar
            $runspaceCount = $runspaces.Count
            $currentRunspaceIndex = 0
            $masterActivityId = (Get-Random) # Unique ID for master progress

            $runspaces | Foreach-Object {
                $originalName = $_.Name
                # Initialize progress bar variables
                $startTime = [DateTime]::UtcNow
                $elapsedTime = 0
                $childActivityId = (Get-Random) # Unique ID for child progress bar
                # Update master progress bar
                $currentRunspaceIndex++
                $masterPercentComplete = [math]::Round(($currentRunspaceIndex / $runspaceCount) * 100)

                Write-Progress -Activity $PodeLocale.suspendingRunspaceMessage `
                    -Status "[$($currentRunspaceIndex)/$($runspaceCount)]: $($_.Name)" `
                    -PercentComplete $masterPercentComplete `
                    -Id $masterActivityId `
                    -ParentId $suspendActivityId

                Write-Progress -Activity $PodeLocale.SuspendingMessage `
                    -Status $PodeLocale.suspendingRunspaceMessage -PercentComplete ($masterPercentComplete - 5) `
                    -Id $suspendActivityId

                # Suspend the runspace
                Enable-RunspaceDebug -BreakAll -Runspace $_
                try {
                    # Initial progress bar display
                    Write-Progress -Activity "$($PodeLocale.suspendingRunspaceMessage) $($_.Name)" `
                        -Status  $PodeLocale.waitingforSuspendingMessage `
                        -PercentComplete 0 -Id $childActivityId -ParentId $masterActivityId

                    while (! $_.debugger.InBreakpoint) {
                        # Update elapsed time and progress
                        $elapsedTime = ([DateTime]::UtcNow - $startTime).TotalSeconds
                        $percentComplete = [math]::Min(($elapsedTime / $Timeout) * 100, 100)

                        Write-Progress -Activity "$($PodeLocale.suspendingRunspaceMessage) $($_.Name)" `
                            -Status $PodeLocale.suspendingRunspaceMessage `
                            -PercentComplete $percentComplete `
                            -Id $childActivityId `
                            -ParentId $masterActivityId

                        if ($_.Name.StartsWith('_')) {
                            Write-Progress -Completed -Id $childActivityId -ParentId $masterActivityId
                            Write-Verbose "$originalName runspace has beed completed"
                            break
                        }
                        # Check for timeout
                        if ($elapsedTime -ge $Timeout) {
                            Write-Progress -Completed -Id $childActivityId -ParentId $masterActivityId
                            Write-Verbose "$($_.Name) failed (Timeout reached after $Timeout seconds.)"
                            break
                        }

                        Start-Sleep -Milliseconds 1000
                    }
                }
                catch {
                    $_ | Write-PodeErrorLog
                }
                finally {
                    # Completion message
                    Write-Progress -Completed -Id $childActivityId -ParentId $masterActivityId
                    Write-Progress -Activity $PodeLocale.SuspendingMessage `
                        -Status $PodeLocale.suspendingRunspaceMessage -PercentComplete 100 -Id $suspendActivityId

                    Start-Sleep -Milliseconds 1000
                }
            }
        }
        catch {
            $_ | Write-PodeErrorLog
        }
        finally {
            # Clear master progress bar once all runspaces are processed
            Write-Progress -Activity $PodeLocale.suspendingRunspaceMessage -Completed -Id $masterActivityId -ParentId $suspendActivityId
        }

    }
    catch {
        # Log any errors that occur
        $_ | Write-PodeErrorLog
    }
    finally {
        # Clear master progress bar once all suspension is completed
        Write-Progress -Activity $PodeLocale.SuspendingMessage -Completed -Id $suspendActivityId
        if ( $PodeContext.Tokens.Cancellation.IsCancellationRequested) {
            Reset-PodeCancellationToken -Type Cancellation
        }

        # Short pause before refreshing the console
        Start-Sleep -Seconds 1

        # Clear the host and display header information
        Show-PodeConsoleInfo
    }
}


<#
.SYNOPSIS
    Resumes the Pode server from a suspended state.

.DESCRIPTION
    This function resumes the Pode server, ensuring all associated runspaces are restored to their normal execution state.
    It triggers the 'Resume' event, updates the server's suspended status, and clears the host for a refreshed console view.

.PARAMETER Timeout
    The maximum time, in seconds, to wait for each runspace to be recovered before timing out. Default is 30 seconds.

.EXAMPLE
    Resume-PodeServerInternal
    # Resumes the Pode server after a suspension.

.NOTES
    This is an internal function used within the Pode framework.
    It may change in future releases.

#>
function Resume-PodeServerInternal {

    param(
        [int]
        $Timeout = 30
    )

    # Check if the cancellation for resuming tokens is not requested.
    # If not, exit the current scope early.
    if (!$PodeContext.Tokens.Resume.IsCancellationRequested) {
        return
    }

    try {
        # Inform user that the server is suspending
        $ResumingActivityId = (Get-Random)
        # Inform user that the server is suspending

        Write-Progress -Activity $PodeLocale.ResumingMessage `
            -Status 'Invoke Resume Event' `
            -PercentComplete 3 `
            -Id $ResumingActivityId
        # Trigger the Resume event
        Invoke-PodeEvent -Type Resume

        start-sleep 1
        try {
            Write-Progress -Activity $PodeLocale.ResumingMessage `
                -Status $PodeLocale.resumingRunspaceMessage `
                -PercentComplete 5 `
                -Id $ResumingActivityId

            # Disable debugging for each runspace to restore normal execution
            $runspaces = Get-Runspace | Where-Object { $_.Debugger.InBreakpoint }

            # Initialize the master progress bar
            $runspaceCount = $runspaces.Count
            $currentRunspaceIndex = 0
            $masterActivityId = (Get-Random) # Unique ID for master progress

            $runspaces | Foreach-Object {
                # Initialize progress bar variables
                $startTime = [DateTime]::UtcNow
                $elapsedTime = 0
                $childActivityId = (Get-Random) # Unique ID for child progress bar
                # Update master progress bar
                $currentRunspaceIndex++
                $masterPercentComplete = [math]::Round(($currentRunspaceIndex / $runspaceCount) * 100)

                Write-Progress -Activity $PodeLocale.resumingRunspaceMessage `
                    -Status "[$($currentRunspaceIndex)/$($runspaceCount)]: $($_.Name)" `
                    -PercentComplete $masterPercentComplete `
                    -Id $masterActivityId `
                    -ParentId $ResumingActivityId

                Write-Progress -Activity $PodeLocale.ResumingMessage `
                    -Status $PodeLocale.resumingRunspaceMessage -PercentComplete ($masterPercentComplete - 5) `
                    -Id $ResumingActivityId

                # Resume the runspace
                Disable-RunspaceDebug -Runspace $_
                try {
                    # Initial progress bar display
                    Write-Progress -Activity "$($PodeLocale.resumingRunspaceMessage) $($_.Name)" `
                        -Status $PodeLocale.waitingforResumingMessage `
                        -PercentComplete 0 -Id $childActivityId -ParentId $masterActivityId

                    while (  $_.debugger.InBreakpoint) {
                        # Update elapsed time and progress
                        $elapsedTime = ([DateTime]::UtcNow - $startTime).TotalSeconds
                        $percentComplete = [math]::Min(($elapsedTime / $Timeout) * 100, 100)

                        Write-Progress -Activity "$($PodeLocale.resumingRunspaceMessage) $($_.Name)" `
                            -Status ($PodeLocale.resumingRunspaceMessage) `
                            -PercentComplete $percentComplete `
                            -Id $childActivityId `
                            -ParentId $masterActivityId

                        # Check for timeout
                        if ($elapsedTime -ge $Timeout) {
                            Write-Progress -Completed -Id $childActivityId -ParentId $masterActivityId
                            Write-Verbose "$($_.Name) failed (Timeout reached after $Timeout seconds.)"
                            break
                        }

                        Start-Sleep -Milliseconds 1000
                    }

                }
                catch {
                    $_ | Write-PodeErrorLog
                }
                finally {
                    # Completion message
                    Write-Progress -Completed -Id $childActivityId -ParentId $masterActivityId
                    Write-Progress -Activity $PodeLocale.ResumingMessage `
                        -Status $PodeLocale.resumingRunspaceMessage -PercentComplete 100 -Id $ResumingActivityId

                    Start-Sleep -Milliseconds 1000
                }
            }
        }
        catch {
            $_ | Write-PodeErrorLog
        }
        finally {
            # Clear master progress bar once all runspaces are processed
            Write-Progress -Activity $PodeLocale.resumingRunspaceMessage -Completed -Id $masterActivityId -ParentId $ResumingActivityId
        }

        # Short pause before refreshing the console
        Start-Sleep -Seconds 1

        # Clear the host and display header information
        Show-PodeConsoleInfo
    }
    catch {
        # Log any errors that occur
        $_ | Write-PodeErrorLog
    }
    finally {
        # Clear master progress bar once all suspension is completed
        Write-Progress -Activity $PodeLocale.ResumingMessage -Completed -Id $ResumingActivityId

        # Reinitialize the CancellationTokenSource for future suspension/resumption
        Reset-PodeCancellationToken -Type  Resume
    }
}



