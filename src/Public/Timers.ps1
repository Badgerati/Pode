<#
.SYNOPSIS
    Adds a new Timer with logic to periodically invoke.

.DESCRIPTION
    Adds a new Timer with logic to periodically invoke, with options to only run a specific number of times.

.PARAMETER Name
    The Name of the Timer.

.PARAMETER Interval
    The number of seconds to periodically invoke the Timer's ScriptBlock.

.PARAMETER ScriptBlock
    The script for the Timer.

.PARAMETER Limit
    The number of times the Timer should be invoked before being removed. (If 0, it will run indefinitely)

.PARAMETER Skip
    The number of "invokes" to skip before the Timer actually runs.

.PARAMETER ArgumentList
    An array of arguments to supply to the Timer's ScriptBlock.

.PARAMETER FilePath
    A literal, or relative, path to a file containing a ScriptBlock for the Timer's logic.

.PARAMETER OnStart
    If supplied, the timer will trigger when the server starts.

.EXAMPLE
    Add-PodeTimer -Name 'Hello' -Interval 10 -ScriptBlock { 'Hello, world!' | Out-Default }

.EXAMPLE
    Add-PodeTimer -Name 'RunOnce' -Interval 1 -Limit 1 -ScriptBlock { /* logic */ }

.EXAMPLE
    Add-PodeTimer -Name 'RunAfter60secs' -Interval 10 -Skip 6 -ScriptBlock { /* logic */ }

.EXAMPLE
    Add-PodeTimer -Name 'Args' -Interval 2 -ScriptBlock { /* logic */ } -ArgumentList 'arg1', 'arg2'
#>
function Add-PodeTimer {
    [CmdletBinding(DefaultParameterSetName = 'Script')]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true)]
        [int]
        $Interval,

        [Parameter(Mandatory = $true, ParameterSetName = 'Script')]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [int]
        $Limit = 0,

        [Parameter()]
        [int]
        $Skip = 0,

        [Parameter(Mandatory = $true, ParameterSetName = 'File')]
        [string]
        $FilePath,

        [Parameter()]
        [object[]]
        $ArgumentList,

        [switch]
        $OnStart
    )

    # error if serverless
    Test-PodeIsServerless -FunctionName 'Add-PodeTimer' -ThrowError

    # ensure the timer doesn't already exist
    if ($PodeContext.Timers.Items.ContainsKey($Name)) {
        # [Timer] Name: Timer already defined
        throw ($PodeLocale.timerAlreadyDefinedExceptionMessage -f $Name)
    }

    # is the interval valid?
    if ($Interval -le 0) {
        # [Timer] Name: parameter must be greater than 0
        throw ($PodeLocale.timerParameterMustBeGreaterThanZeroExceptionMessage -f $Name, 'Interval')
    }

    # is the limit valid?
    if ($Limit -lt 0) {
        # [Timer] Name: parameter must be greater than 0
        throw ($PodeLocale.timerParameterMustBeGreaterThanZeroExceptionMessage -f $Name, 'Limit')
    }

    # is the skip valid?
    if ($Skip -lt 0) {
        # [Timer] Name: parameter must be greater than 0
        throw ($PodeLocale.timerParameterMustBeGreaterThanZeroExceptionMessage -f $Name, 'Skip')
    }

    # if we have a file path supplied, load that path as a scriptblock
    if ($PSCmdlet.ParameterSetName -ieq 'file') {
        $ScriptBlock = Convert-PodeFileToScriptBlock -FilePath $FilePath
    }

    # check for scoped vars
    $ScriptBlock, $usingVars = Convert-PodeScopedVariables -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState

    # calculate the next tick time (based on Skip)
    $NextTriggerTime = [DateTime]::Now.AddSeconds($Interval)
    if ($Skip -gt 1) {
        $NextTriggerTime = $NextTriggerTime.AddSeconds($Interval * $Skip)
    }

    # add the timer
    $PodeContext.Timers.Enabled = $true
    $PodeContext.Timers.Items[$Name] = @{
        Name            = $Name
        Interval        = $Interval
        Limit           = $Limit
        Count           = 0
        Skip            = $Skip
        NextTriggerTime = $NextTriggerTime
        LastTriggerTime = $null
        Script          = $ScriptBlock
        UsingVariables  = $usingVars
        Arguments       = $ArgumentList
        OnStart         = $OnStart
        Completed       = $false
    }
}


<#
.SYNOPSIS
Adhoc invoke a Timer's logic.

.DESCRIPTION
Adhoc invoke a Timer's logic outside of its defined interval. This invocation doesn't count towards the Timer's limit.

.PARAMETER Name
The Name of the Timer.

.PARAMETER ArgumentList
An array of arguments to supply to the Timer's ScriptBlock.

.EXAMPLE
Invoke-PodeTimer -Name 'timer-name'
#>
function Invoke-PodeTimer {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [string]
        $Name,

        [Parameter()]
        [object[]]
        $ArgumentList = $null
    )
    process {
        # ensure the timer exists
        if (!$PodeContext.Timers.Items.ContainsKey($Name)) {
            # Timer 'Name' does not exist
            throw ($PodeLocale.timerDoesNotExistExceptionMessage -f $Name)
        }

        # run timer logic
        Invoke-PodeInternalTimer -Timer $PodeContext.Timers.Items[$Name] -ArgumentList $ArgumentList
    }
}

<#
.SYNOPSIS
Removes a specific Timer.

.DESCRIPTION
Removes a specific Timer.

.PARAMETER Name
The Name of Timer to be removed.

.EXAMPLE
Remove-PodeTimer -Name 'SaveState'
#>
function Remove-PodeTimer {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [string]
        $Name
    )
    process {
        $null = $PodeContext.Timers.Items.Remove($Name)
    }
}

<#
.SYNOPSIS
Removes all Timers.

.DESCRIPTION
Removes all Timers.

.EXAMPLE
Clear-PodeTimers
#>
function Clear-PodeTimers {
    [CmdletBinding()]
    param()

    $PodeContext.Timers.Items.Clear()
}

<#
.SYNOPSIS
Edits an existing Timer.

.DESCRIPTION
Edits an existing Timer's properties, such as interval or scriptblock.

.PARAMETER Name
The Name of the Timer.

.PARAMETER Interval
The new Interval for the Timer in seconds.

.PARAMETER ScriptBlock
The new ScriptBlock for the Timer.

.PARAMETER ArgumentList
Any new Arguments for the Timer.

.EXAMPLE
Edit-PodeTimer -Name 'Hello' -Interval 10
#>
function Edit-PodeTimer {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [string]
        $Name,

        [Parameter()]
        [int]
        $Interval = 0,

        [Parameter()]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [object[]]
        $ArgumentList
    )
    process {
        # ensure the timer exists
        if (!$PodeContext.Timers.Items.ContainsKey($Name)) {
            # Timer 'Name' does not exist
            throw ($PodeLocale.timerDoesNotExistExceptionMessage -f $Name)
        }

        $_timer = $PodeContext.Timers.Items[$Name]

        # edit interval if supplied
        if ($Interval -gt 0) {
            $_timer.Interval = $Interval
        }

        # edit scriptblock if supplied
        if (!(Test-PodeIsEmpty $ScriptBlock)) {
            $ScriptBlock, $usingVars = Convert-PodeScopedVariables -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState
            $_timer.Script = $ScriptBlock
            $_timer.UsingVariables = $usingVars
        }

        # edit arguments if supplied
        if (!(Test-PodeIsEmpty $ArgumentList)) {
            $_timer.Arguments = $ArgumentList
        }
    }
}

<#
.SYNOPSIS
Returns any defined timers.

.DESCRIPTION
Returns any defined timers, with support for filtering.

.PARAMETER Name
Any timer Names to filter the timers.

.EXAMPLE
Get-PodeTimer

.EXAMPLE
Get-PodeTimer -Name Name1, Name2
#>
function Get-PodeTimer {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string[]]
        $Name
    )

    $timers = $PodeContext.Timers.Items.Values

    # further filter by timer names
    if (($null -ne $Name) -and ($Name.Length -gt 0)) {
        $timers = @(foreach ($_name in $Name) {
                foreach ($timer in $timers) {
                    if ($timer.Name -ine $_name) {
                        continue
                    }

                    $timer
                }
            })
    }

    # return
    return $timers
}

<#
.SYNOPSIS
Tests whether the passed Timer exists.

.DESCRIPTION
Tests whether the passed Timer exists by its name.

.PARAMETER Name
The Name of the Timer.

.EXAMPLE
if (Test-PodeTimer -Name TimerName) { }
#>
function Test-PodeTimer {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    return (($null -ne $PodeContext.Timers.Items) -and $PodeContext.Timers.Items.ContainsKey($Name))
}

<#
.SYNOPSIS
Automatically loads timer ps1 files

.DESCRIPTION
Automatically loads timer ps1 files from either a /timers folder, or a custom folder. Saves space dot-sourcing them all one-by-one.

.PARAMETER Path
Optional Path to a folder containing ps1 files, can be relative or literal.

.EXAMPLE
Use-PodeTimers

.EXAMPLE
Use-PodeTimers -Path './my-timers'
#>
function Use-PodeTimers {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Path
    )

    Use-PodeFolder -Path $Path -DefaultPath 'timers'
}