<#
.SYNOPSIS
    Adds a new runspace to Pode with the specified type and script block.

.DESCRIPTION
    The `Add-PodeRunspace` function creates a new PowerShell runspace within Pode
    based on the provided type and script block. This function allows for additional
    customization through parameters, output streaming, and runspace management options.

.PARAMETER Type
    The type of runspace to create. Accepted values are:
    'Main', 'Signals', 'Schedules', 'Gui', 'Web', 'Smtp', 'Tcp', 'Tasks',
    'WebSockets', 'Files', 'Timers'.

.PARAMETER ScriptBlock
    The script block to execute within the runspace. This script block will be
    added to the runspace's pipeline.

.PARAMETER Parameters
    Optional parameters to pass to the script block.

.PARAMETER OutputStream
    A PSDataCollection object to handle output streaming for the runspace.

.PARAMETER Forget
    If specified, the pipeline's output will not be stored or remembered.

.PARAMETER NoProfile
    If specified, the runspace will not load any modules or profiles.

.PARAMETER PassThru
    If specified, returns the pipeline and handler for custom processing.

.EXAMPLE
    Add-PodeRunspace -Type 'Tasks' -ScriptBlock {
        # Your script code here
    }
#>

function Add-PodeRunspace {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Type,

        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        $Parameters,

        [Parameter()]
        [System.Management.Automation.PSDataCollection[psobject]]
        $OutputStream = $null,

        [switch]
        $Forget,

        [switch]
        $NoProfile,

        [switch]
        $PassThru,

        [string]
        $Name,

        [string]
        $Id = '1'
    )

    try {
        # Define the script block to open the runspace and set its state.
        $openRunspaceScript = {
            param($Type, $Name, $NoProfile)
            try {
                # Set the runspace name.
                Set-PodeCurrentRunspaceName -Name $Name

                if (!$NoProfile) {
                    # Import necessary internal Pode modules for the runspace.
                    Import-PodeModulesInternal

                    # Add required PowerShell drives.
                    Add-PodePSDrivesInternal
                }

                # Mark the runspace as 'Ready' to process requests.
                $PodeContext.RunspacePools[$Type].State = 'Ready'
            }
            catch {
                # Handle errors, setting the runspace state to 'Error' if applicable.
                if ($PodeContext.RunspacePools[$Type].State -ieq 'waiting') {
                    $PodeContext.RunspacePools[$Type].State = 'Error'
                }

                # Output the error details to the default stream and rethrow.
                $_ | Out-Default
                $_.ScriptStackTrace | Out-Default
                throw
            }
        }

        # Create a PowerShell pipeline.
        $ps = [powershell]::Create()
        $ps.RunspacePool = $PodeContext.RunspacePools[$Type].Pool

        # Add the script block and parameters to the pipeline.
        $null = $ps.AddScript($openRunspaceScript)
        $null = $ps.AddParameters(
            @{
                'Type'      = $Type
                'Name'      = "Pode_$($Type)_$($Name)_$($Id)"
                'NoProfile' = $NoProfile.IsPresent
            }
        )

        # Add the main script block to the pipeline.
        $null = $ps.AddScript($ScriptBlock)

        # Add any provided parameters to the script block.
        if (!(Test-PodeIsEmpty $Parameters)) {
            $Parameters.Keys | ForEach-Object {
                $null = $ps.AddParameter($_, $Parameters[$_])
            }
        }

        # Begin invoking the pipeline, with or without output streaming.
        if ($null -eq $OutputStream) {
            $pipeline = $ps.BeginInvoke()
        }
        else {
            $pipeline = $ps.BeginInvoke($OutputStream, $OutputStream)
        }

        # Handle forgetting, returning, or storing the pipeline.
        if ($Forget) {
            $null = $pipeline
        }
        elseif ($PassThru) {
            return @{
                Pipeline = $ps
                Handler  = $pipeline
            }
        }
        else {
            $PodeContext.Runspaces += @{
                Pool     = $Type
                Pipeline = $ps
                Handler  = $pipeline
                Stopped  = $false
            }
        }
    }
    catch {
        # Log and throw any exceptions encountered during execution.
        $_ | Write-PodeErrorLog
        throw $_.Exception
    }
}

<#
.SYNOPSIS
    Closes and disposes of the Pode runspaces, listeners, receivers, watchers, and optionally runspace pools.

.DESCRIPTION
    This function checks and waits for all Listeners, Receivers, and Watchers to be disposed of
    before proceeding to close and dispose of the runspaces and optionally the runspace pools.
    It ensures a clean shutdown by managing the disposal of resources in a specified order.
    The function handles serverless and regular server environments differently, skipping
    disposal actions in serverless contexts.

.PARAMETER ClosePool
    Specifies whether to close and dispose of the runspace pools along with the runspaces.
    This is optional and should be specified if the pools need to be explicitly closed.

.EXAMPLE
    Close-PodeRunspace -ClosePool
    This example closes all runspaces and their associated pools, ensuring that all resources are properly disposed of.

.OUTPUTS
    None
    Outputs from this function are primarily internal state changes and verbose logging.
#>
function Close-PodeRunspace {
    param(
        [switch]
        $ClosePool
    )

    # Early return if server is serverless, as disposal is not required.
    if ($PodeContext.Server.IsServerless) {
        return
    }

    try {
        # Only proceed if there are runspaces to dispose of.
        if (!(Test-PodeIsEmpty $PodeContext.Runspaces)) {
            Write-Verbose 'Waiting until all Listeners are disposed'

            $count = 0
            $continue = $false
            # Attempts to dispose of resources for up to 10 seconds.
            while ($count -le 10) {
                Start-Sleep -Seconds 1
                $count++

                $continue = $false
                # Check each listener, receiver, and watcher; if any are not disposed, continue waiting.
                foreach ($listener in $PodeContext.Listeners) {
                    if (!$listener.IsDisposed) {
                        $continue = $true
                        break
                    }
                }

                foreach ($receiver in $PodeContext.Receivers) {
                    if (!$receiver.IsDisposed) {
                        $continue = $true
                        break
                    }
                }

                foreach ($watcher in $PodeContext.Watchers) {
                    if (!$watcher.IsDisposed) {
                        $continue = $true
                        break
                    }
                }
                # If undisposed resources exist, continue waiting.
                if ($continue) {
                    continue
                }

                break
            }

            Write-Verbose 'All Listeners disposed'

            # now dispose runspaces
            Write-Verbose 'Disposing Runspaces'
            $runspaceErrors = @(foreach ($item in $PodeContext.Runspaces) {
                    if ($item.Stopped) {
                        continue
                    }

                    try {
                        # only do this, if the pool is in error
                        if ($PodeContext.RunspacePools[$item.Pool].State -ieq 'error') {
                            $item.Pipeline.EndInvoke($item.Handler)
                        }
                    }
                    catch {
                        "$($item.Pool) runspace failed to load: $($_.Exception.InnerException.Message)"
                    }

                    Close-PodeDisposable -Disposable $item.Pipeline
                    $item.Stopped = $true
                })

            # dispose of schedule runspaces
            if ($PodeContext.Schedules.Processes.Count -gt 0) {
                foreach ($key in $PodeContext.Schedules.Processes.Keys.Clone()) {
                    Close-PodeScheduleInternal -Process $PodeContext.Schedules.Processes[$key]
                }
            }

            # dispose of task runspaces
            if ($PodeContext.Tasks.Processes.Count -gt 0) {
                foreach ($key in $PodeContext.Tasks.Processes.Keys.Clone()) {
                    Close-PodeTaskInternal -Process $PodeContext.Tasks.Processes[$key]
                }
            }

            $PodeContext.Runspaces = @()
            Write-Verbose 'Runspaces disposed'
        }

        # close/dispose the runspace pools
        if ($ClosePool) {
            Close-PodeRunspacePool
        }

        # Check for and throw runspace errors if any occurred during disposal.
        if (($null -ne $runspaceErrors) -and ($runspaceErrors.Length -gt 0)) {
            foreach ($err in $runspaceErrors) {
                if ($null -eq $err) {
                    continue
                }

                throw $err
            }
        }

        # garbage collect
        Invoke-PodeGC
    }
    catch {
        $_ | Write-PodeErrorLog
        throw $_.Exception
    }
}

<#
.SYNOPSIS
    Opens and initializes runspace pools for various Pode components.

.DESCRIPTION
    This function opens and initializes runspace pools for different Pode components, such as timers, schedules, web endpoints, web sockets, SMTP, TCP, and more. It asynchronously opens the pools and waits for them to be in the 'Opened' state. If any pool fails to open, it reports an error.

.OUTPUTS
    Opens and initializes runspace pools for various Pode components.
#>
function Open-PodeRunspacePool {
    if ($PodeContext.Server.IsServerless) {
        return
    }

    $start = [datetime]::Now
    Write-Verbose 'Opening RunspacePools'

    # open pools async
    foreach ($key in $PodeContext.RunspacePools.Keys) {
        $item = $PodeContext.RunspacePools[$key]
        if ($null -eq $item) {
            continue
        }

        $item.Pool.ThreadOptions = [System.Management.Automation.Runspaces.PSThreadOptions]::ReuseThread
        $item.Pool.CleanupInterval = [timespan]::FromMinutes(5)
        $item.Result = $item.Pool.BeginOpen($null, $null)
    }

    # wait for them all to open
    $queue = @($PodeContext.RunspacePools.Keys)

    while ($queue.Length -gt 0) {
        foreach ($key in $queue) {
            $item = $PodeContext.RunspacePools[$key]
            if ($null -eq $item) {
                $queue = ($queue | Where-Object { $_ -ine $key })
                continue
            }

            if ($item.Pool.RunspacePoolStateInfo.State -iin @('Opened', 'Broken')) {
                $queue = ($queue | Where-Object { $_ -ine $key })
                Write-Verbose "RunspacePool for $($key): $($item.Pool.RunspacePoolStateInfo.State) [duration: $(([datetime]::Now - $start).TotalSeconds)s]"
            }
        }

        if ($queue.Length -gt 0) {
            Start-Sleep -Milliseconds 100
        }
    }

    # report errors for failed pools
    foreach ($key in $PodeContext.RunspacePools.Keys) {
        $item = $PodeContext.RunspacePools[$key]
        if ($null -eq $item) {
            continue
        }

        if ($item.Pool.RunspacePoolStateInfo.State -ieq 'broken') {
            $item.Pool.EndOpen($item.Result) | Out-Default
            throw ($PodeLocale.failedToOpenRunspacePoolExceptionMessage -f $key) #"Failed to open RunspacePool: $($key)"
        }
    }

    Write-Verbose "RunspacePools opened [duration: $(([datetime]::Now - $start).TotalSeconds)s]"
}

<#
.SYNOPSIS
    Closes and disposes runspace pools for various Pode components.

.DESCRIPTION
    This function closes and disposes runspace pools for different Pode components, such as timers, schedules, web endpoints, web sockets, SMTP, TCP, and more. It asynchronously closes the pools and waits for them to be in the 'Closed' state. If any pool fails to close, it reports an error.

.OUTPUTS
    Closes and disposes runspace pools for various Pode components.
#>
function Close-PodeRunspacePool {
    if ($PodeContext.Server.IsServerless -or ($null -eq $PodeContext.RunspacePools)) {
        return
    }

    $start = [datetime]::Now
    Write-Verbose 'Closing RunspacePools'

    # close pools async
    foreach ($key in $PodeContext.RunspacePools.Keys) {
        $item = $PodeContext.RunspacePools[$key]
        if (($null -eq $item) -or ($item.Pool.IsDisposed)) {
            continue
        }

        $item.Result = $item.Pool.BeginClose($null, $null)
    }

    # wait for them all to close
    $queue = @($PodeContext.RunspacePools.Keys)

    while ($queue.Length -gt 0) {
        foreach ($key in $queue) {
            $item = $PodeContext.RunspacePools[$key]
            if ($null -eq $item) {
                $queue = ($queue | Where-Object { $_ -ine $key })
                continue
            }

            if ($item.Pool.RunspacePoolStateInfo.State -iin @('Closed', 'Broken')) {
                $queue = ($queue | Where-Object { $_ -ine $key })
                Write-Verbose "RunspacePool for $($key): $($item.Pool.RunspacePoolStateInfo.State) [duration: $(([datetime]::Now - $start).TotalSeconds)s]"
            }
        }

        if ($queue.Length -gt 0) {
            Start-Sleep -Milliseconds 100
        }
    }

    # report errors for failed pools
    foreach ($key in $PodeContext.RunspacePools.Keys) {
        $item = $PodeContext.RunspacePools[$key]
        if ($null -eq $item) {
            continue
        }

        if ($item.Pool.RunspacePoolStateInfo.State -ieq 'broken') {
            $item.Pool.EndClose($item.Result) | Out-Default
            # Failed to close RunspacePool
            throw ($PodeLocale.failedToCloseRunspacePoolExceptionMessage -f $key)
        }
    }

    # dispose pools
    foreach ($key in $PodeContext.RunspacePools.Keys) {
        $item = $PodeContext.RunspacePools[$key]
        if (($null -eq $item) -or ($item.Pool.IsDisposed)) {
            continue
        }

        Close-PodeDisposable -Disposable $item.Pool
    }

    Write-Verbose "RunspacePools closed [duration: $(([datetime]::Now - $start).TotalSeconds)s]"
}



<#
.SYNOPSIS
    Initializes a new Pode runspace state with the necessary modules and shared variables.

.DESCRIPTION
    This function creates an initial PowerShell session state for a Pode runspace.
    It imports the Pode modules and sets up a shared state context containing relevant
    variables like PodeLocale, PodeContext, and others for proper runspace isolation.

.PARAMETER None
    No parameters are required for this function.

.NOTES
    This function is designed to be used in Pode-based applications where runspaces
    are necessary for handling parallel execution with access to the Pode context.
    Variables added to the state are accessible inside the runspace.

.EXAMPLE
    New-PodeRunspaceState
    Initializes the Pode runspace state with the required modules and variables.
#>
function New-PodeRunspaceState {
    # Create the initial session state for the runspace
    $state = [initialsessionstate]::CreateDefault()

    # Import Pode modules: DataPath for core functionality and InternalPath for internal operations
    $state.ImportPSModule($PodeContext.Server.PodeModule.DataPath)
    $state.ImportPSModule($PodeContext.Server.PodeModule.InternalPath)

    # load the vars into the share state
    $session = New-PodeStateContext -Context $PodeContext

    $variables = @(
        # PodeLocale stores the localization settings for Pode
        [System.Management.Automation.Runspaces.SessionStateVariableEntry]::new('PodeLocale', $PodeLocale, $null),

        # PodeContext stores the current Pode session context
        [System.Management.Automation.Runspaces.SessionStateVariableEntry]::new('PodeContext', $session, $null),

        # Console refers to the current host for the PowerShell session
        [System.Management.Automation.Runspaces.SessionStateVariableEntry]::new('Console', $Host, $null),

        # PODE_SCOPE_RUNSPACE is a flag indicating the runspace scope is in use
        [System.Management.Automation.Runspaces.SessionStateVariableEntry]::new('PODE_SCOPE_RUNSPACE', $true, $null)
    )
    # Add each variable to the session state to make them available in the runspace
    foreach ($var in $variables) {
        $state.Variables.Add($var)
    }
    # Store the constructed runspace state in the Pode context
    $PodeContext.RunspaceState = $state
}

<#
.SYNOPSIS
    Creates a new runspace pool with specified minimum and maximum runspaces.

.DESCRIPTION
    This function wraps the .NET `[runspacefactory]::CreateRunspacePool` method to create a new runspace pool.
    It allows specifying the minimum and maximum number of runspaces, as well as the runspace state.
    This function also automatically passes the current host context to the runspace pool.

.PARAMETER MinRunspaces
    The minimum number of runspaces in the pool. This value determines the initial number of runspaces created when the pool is opened.

.PARAMETER MaxRunspaces
    The maximum number of runspaces allowed in the pool. This value limits the total number of concurrent runspaces in the pool.

.PARAMETER RunspaceState
    The state of the runspace, typically determined by the context in which the runspace pool is being created. This parameter is passed directly to the `CreateRunspacePool` method.

.OUTPUTS
    System.Management.Automation.Runspaces.RunspacePool
    Returns a `RunspacePool` object representing the created runspace pool.

.EXAMPLE
    $runspacePool = New-PodeRunspacePoolNetWrapper -MinRunspaces 1 -MaxRunspaces 5 -RunspaceState $state
    # Creates a new runspace pool with a minimum of 1 runspace, a maximum of 5 runspaces, and a specific runspace state.

.NOTES
    This function is a wrapper around the `[runspacefactory]::CreateRunspacePool` method and is used to simplify the creation of runspace pools in Pode scripts.
    This is an internal function and may change in future releases of Pode.

.LINK
    https://docs.microsoft.com/en-us/dotnet/api/system.management.automation.runspaces.runspacefactory.createrunspacepool
#>
function New-PodeRunspacePoolNetWrapper {
    param (
        [Parameter()]
        [int]$MinRunspaces = 1,
        [Parameter(Mandatory = $true)]
        [int]$MaxRunspaces,
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.Runspaces.InitialSessionState]$RunspaceState
    )
    return [runspacefactory]::CreateRunspacePool($MinRunspaces, $MaxRunspaces, $RunspaceState, $Host)
}


