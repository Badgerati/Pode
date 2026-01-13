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

.PARAMETER Name
    If specified, is used as base name for the runspace.

.EXAMPLE
    Add-PodeRunspace -Type 'Tasks' -ScriptBlock {
        # Your script code here
    }
#>
function Add-PodeRunspace {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Main', 'Signals', 'Schedules', 'Gui', 'Web', 'Smtp', 'Tcp', 'Tasks', 'WebSockets', 'Files', 'Timers')]
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
        $Name = 'Generic'
    )

    try {
        # Define the script block to open the runspace and set its state.
        $openRunspaceScript = {
            param([string]$Type, [string]$Name, [bool]$NoProfile)
            try {
                # Set the runspace name.
                Set-PodeCurrentRunspaceName -Name $Name

                # Set runspace location to server root
                Set-Location $PodeContext.Server.Root

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

        # create the name and increment the last Id for the type
        $rsId = ++$PodeContext.RunspacePools[$Type].LastId
        $rsName = "Pode_$($Type)_$($Name)_$($rsId)"

        # Add the script block and parameters to the pipeline.
        $null = $ps.AddScript($openRunspaceScript)
        $null = $ps.AddParameters(@{
                Type      = $Type
                Name      = $rsName
                NoProfile = $NoProfile.IsPresent
            })

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
                Name     = $Name
                Id       = $rsId
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
    Closes and disposes of the Pode runspaces, listeners, consumers, watchers, and optionally runspace pools.

.DESCRIPTION
    This function checks and waits for all Listeners, Consumers, and Watchers to be disposed of
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
            # Close the Terminate cancellation token to dispose the Listeners
            Write-Verbose 'Closing the Terminate cancellation token to dispose the Listeners'
            Close-PodeCancellationTokenRequest -Type Terminate

            # Wait until all Listeners, Consumers, and Watchers are disposed, and there are no client connection events.
            Write-Verbose 'Waiting until all Listeners and Events are disposed'
            $count = 0
            $continue = $false

            # Attempts to dispose of resources for up to 10 seconds.
            while ($count -lt 10) {
                Write-Verbose "Dispose attempt: $($count + 1)"
                Start-Sleep -Seconds 1
                $count++
                $continue = $false

                # Check each listener, consumer, and watcher; if any are not disposed, continue waiting.
                foreach ($listener in $PodeContext.Listeners) {
                    if (($listener.ClientConnectionEvents.Count -gt 0) -or !$listener.IsDisposed) {
                        Write-Verbose "-> [Listener]: $($listener.Type) - Disposed: $($listener.IsDisposed) - Client Connections: $($listener.ClientConnectionEvents.Count)"
                        $continue = $true
                        break
                    }
                }

                foreach ($consumer in $PodeContext.Consumers) {
                    if (!$consumer.IsDisposed) {
                        Write-Verbose "-> [Consumer]: $($consumer.Type) - Disposed: $($consumer.IsDisposed)"
                        $continue = $true
                        break
                    }
                }

                foreach ($watcher in $PodeContext.Watchers) {
                    if (!$watcher.IsDisposed) {
                        Write-Verbose "-> [Watcher]: $($watcher.Type) - Disposed: $($watcher.IsDisposed)"
                        $continue = $true
                        break
                    }
                }

                # If non-disposed resources exist, continue waiting.
                if ($continue) {
                    continue
                }

                break
            }

            Write-Verbose 'All Listeners disposed'

            # now close the Cancellation token
            Write-Verbose 'Closing the Cancellation cancellation token'
            Close-PodeCancellationTokenRequest -Type Cancellation

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
    Resets the name of the current Pode runspace by modifying its structure.

.DESCRIPTION
    The `Reset-PodeRunspaceName` function updates the name of the current runspace if it begins with "Pode_".
    It replaces the portion of the name after the second underscore with "waiting" while retaining the final number.
    Additionally, it prepends an underscore (`_`) to the modified name.

.PARAMETER None
    This function does not take any parameters.

.NOTES
    - The function assumes the current runspace follows the naming convention "Pode_*".
    - If the current runspace name does not start with "Pode_", no changes are made.
    - Useful for managing or resetting runspace names in Pode applications.

.EXAMPLE
    # Example 1: Current runspace name is Pode_Tasks_Test_1
    Reset-PodeRunspaceName
    # After execution: Runspace name becomes _Pode_Tasks_waiting_1

    # Example 2: Current runspace name is NotPode_Runspace
    Reset-PodeRunspaceName
    # No changes are made because the name does not start with "Pode_".

.EXAMPLE
    # Example 3: Runspace with custom name
    Reset-PodeRunspaceName
    # Before: Pode_CustomRoute_Process_5
    # After:  _Pode_CustomRoute_waiting_5

.OUTPUTS
    None.

#>
function Reset-PodeRunspaceName {
    # Get the current runspace
    $currentRunspace = [System.Management.Automation.Runspaces.Runspace]::DefaultRunspace

    # Check if the runspace name starts with 'Pode_'
    if (!$currentRunspace.Name.StartsWith('Pode_')) {
        return
    }

    # Update the runspace name with the required format
    $currentRunspace.Name = "_$($currentRunspace.Name -replace '^(Pode_[^_]+_).+?(_\d+)$', '${1}idle${2}')"
}

function Get-PodeRunspace {
    param(
        [Parameter()]
        [ValidateSet('Main', 'Signals', 'Schedules', 'Gui', 'Web', 'Smtp', 'Tcp', 'Tasks', 'WebSockets', 'Files', 'Timers')]
        [string]
        $Type = $null,

        [Parameter()]
        [string]
        $Name = $null
    )

    $runspaces = $PodeContext.Runspaces

    # find the runspaces by type, if specified
    if (![string]::IsNullOrEmpty($Type)) {
        $runspaces = @(foreach ($rs in $runspaces) {
                if ($rs.Pool -ieq $Type) {
                    $rs
                }
            })
    }

    # filter by name, if specified
    if (![string]::IsNullOrEmpty($Name)) {
        $runspaces = @(foreach ($rs in $runspaces) {
                if ($rs.Name -ieq $Name) {
                    $rs
                }
            })
    }

    # return the runspaces
    return $runspaces
}

function Test-PodeRunspace {
    param(
        [Parameter()]
        [ValidateSet('Main', 'Signals', 'Schedules', 'Gui', 'Web', 'Smtp', 'Tcp', 'Tasks', 'WebSockets', 'Files', 'Timers')]
        [string]
        $Type = $null,

        [Parameter()]
        [string]
        $Name = $null
    )

    return (Get-PodeRunspace -Type $Type -Name $Name).Count -gt 0
}