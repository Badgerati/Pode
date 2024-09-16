function Add-PodeRunspaceNameToScriptblock {
    param (
        [ScriptBlock]$ScriptBlock,
        [string]$Name
    )

    # Convert the scriptblock to a string
    $scriptBlockString = $ScriptBlock.ToString()
    if ($scriptBlockString.contains('Set-PodeCurrentRunspaceName')) {
        Write-PodeHost "'Set-PodeCurrentRunspaceName' already there"
    }
    # Check for a param block and insert the desired line after it
    $pattern = '(\s*param\s*\([^\)]*\)\s*)' #'(\{\s*|\s*)param\s*\([^\)]*\)\s*'

    # Check for a param block and insert the desired line after it
    if ($scriptBlockString -match $pattern) {
        # Insert Set-PodeCurrentRunspaceName after the param block
        $modifiedScriptBlockString = $scriptBlockString -replace $pattern,"`${1}Set-PodeCurrentRunspaceName -Name '$Name'`n"
    }
    else {
        # If no param block is found, add Set-PodeCurrentRunspaceName at the beginning
        $modifiedScriptBlockString = "Set-PodeCurrentRunspaceName -Name `"$Name`"`n$scriptBlockString"
    }

    # Convert the modified string back into a scriptblock
    return [ScriptBlock]::Create($modifiedScriptBlockString)
}

<#
.SYNOPSIS
    Opens a runspace for Pode server operations based on the specified type.

.DESCRIPTION
    This function initializes a runspace for Pode server tasks by importing necessary
    modules, adding PowerShell drives, and setting the state of the runspace pool to 'Ready'.
    If an error occurs during the initialization, the state is adjusted to 'Error' if it
    was previously set to 'waiting', and the error details are outputted.

.PARAMETER Type
    The type of the runspace pool to open. This parameter only accepts predefined values,
    ensuring the runspace pool corresponds to a supported server operation type. The valid
    types are: Main, Signals, Schedules, Gui, Web, Smtp, Tcp, Tasks, WebSockets, Files.

.EXAMPLE
    Open-PodeRunspace -Type "Web"

    Opens a runspace for the 'Web' type, setting it ready for handling web server tasks.

.NOTES
    This function is not invoked directly but indirectly by `Add-PodeRunspace` function using
    $null = $ps.AddScript("Open-PodeRunspace -Type '$($Type)'")
#>
function Open-PodeRunspace {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Main', 'Signals', 'Schedules', 'Gui', 'Web', 'Smtp', 'Tcp', 'Tasks', 'WebSockets', 'Files')]
        [string]
        $Type
    )

    try {
        # Importing internal Pode modules necessary for the runspace operations.
        Import-PodeModulesInternal

        # Adding PowerShell drives required by the runspace.
        Add-PodePSDrivesInternal

        # Setting the state of the runspace pool to 'Ready', indicating it is ready to process requests.
        $PodeContext.RunspacePools[$Type].State = 'Ready'
    }
    catch {
        # If an error occurs and the current state is 'waiting', set it to 'Error'.
        if ($PodeContext.RunspacePools[$Type].State -ieq 'waiting') {
            $PodeContext.RunspacePools[$Type].State = 'Error'
        }

        # Outputting the error to the default output stream, including the stack trace.
        $_ | Out-Default
        $_.ScriptStackTrace | Out-Default

        # Rethrowing the error to be handled further up the call stack.
        throw
    }
}


<#
.SYNOPSIS
    Adds a new runspace to Pode with specified type and script block.

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
        $PassThru
    )

    try {
        # create powershell pipelines
        $ps = [powershell]::Create()
        $ps.RunspacePool = $PodeContext.RunspacePools[$Type].Pool

        # load modules/drives
        if (!$NoProfile) {
            $null = $ps.AddScript("Open-PodeRunspace -Type '$($Type)'")
        }

        # load main script
        $null = $ps.AddScript($ScriptBlock)

        # load parameters
        if (!(Test-PodeIsEmpty $Parameters)) {
            $Parameters.Keys | ForEach-Object {
                $null = $ps.AddParameter($_, $Parameters[$_])
            }
        }

        # start the pipeline
        if ($null -eq $OutputStream) {
            $pipeline = $ps.BeginInvoke()
        }
        else {
            $pipeline = $ps.BeginInvoke($OutputStream, $OutputStream)
        }

        # do we need to remember this pipeline? sorry, what did you say?
        if ($Forget) {
            $null = $pipeline
        }

        # or do we need to return it for custom processing? ie: tasks
        elseif ($PassThru) {
            return @{
                Pipeline = $ps
                Handler  = $pipeline
            }
        }

        # or store it here for later clean-up
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