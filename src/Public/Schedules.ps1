<#
.SYNOPSIS
Adds a new Schedule with logic to periodically invoke, defined using Cron Expressions.

.DESCRIPTION
Adds a new Schedule with logic to periodically invoke, defined using Cron Expressions.

.PARAMETER Name
The Name of the Schedule.

.PARAMETER Cron
One, or an Array, of Cron Expressions to define when the Schedule should trigger.

.PARAMETER ScriptBlock
The script defining the Schedule's logic.

.PARAMETER Limit
The number of times the Schedule should trigger before being removed.

.PARAMETER StartTime
A DateTime for when the Schedule should start triggering.

.PARAMETER EndTime
A DateTime for when the Schedule should stop triggering, and be removed.

.PARAMETER ArgumentList
A hashtable of arguments to supply to the Schedule's ScriptBlock.

.PARAMETER FilePath
A literal, or relative, path to a file containing a ScriptBlock for the Schedule's logic.

.PARAMETER OnStart
If supplied, the schedule will trigger when the server starts, regardless if the cron-expression matches the current time.

.EXAMPLE
Add-PodeSchedule -Name 'RunEveryMinute' -Cron '@minutely' -ScriptBlock { /* logic */ }

.EXAMPLE
Add-PodeSchedule -Name 'RunEveryTuesday' -Cron '0 0 * * TUE' -ScriptBlock { /* logic */ }

.EXAMPLE
Add-PodeSchedule -Name 'StartAfter2days' -Cron '@hourly' -StartTime [DateTime]::Now.AddDays(2) -ScriptBlock { /* logic */ }

.EXAMPLE
Add-PodeSchedule -Name 'Args' -Cron '@minutely' -ScriptBlock { /* logic */ } -ArgumentList @{ Arg1 = 'value' }
#>
function Add-PodeSchedule {
    [CmdletBinding(DefaultParameterSetName = 'Script')]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true)]
        [string[]]
        $Cron,

        [Parameter(Mandatory = $true, ParameterSetName = 'Script')]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [int]
        $Limit = 0,

        [Parameter()]
        [DateTime]
        $StartTime,

        [Parameter()]
        [DateTime]
        $EndTime,

        [Parameter(Mandatory = $true, ParameterSetName = 'File')]
        [string]
        $FilePath,

        [Parameter()]
        [hashtable]
        $ArgumentList,

        [switch]
        $OnStart
    )

    # error if serverless
    Test-PodeIsServerless -FunctionName 'Add-PodeSchedule' -ThrowError

    # ensure the schedule doesn't already exist
    if ($PodeContext.Schedules.Items.ContainsKey($Name)) {
        throw "[Schedule] $($Name): Schedule already defined"
    }

    # ensure the limit is valid
    if ($Limit -lt 0) {
        throw "[Schedule] $($Name): Cannot have a negative limit"
    }

    # ensure the start/end dates are valid
    if (($null -ne $EndTime) -and ($EndTime -lt [DateTime]::Now)) {
        throw "[Schedule] $($Name): The EndTime value must be in the future"
    }

    if (($null -ne $StartTime) -and ($null -ne $EndTime) -and ($EndTime -le $StartTime)) {
        throw "[Schedule] $($Name): Cannot have a StartTime after the EndTime"
    }

    # if we have a file path supplied, load that path as a scriptblock
    if ($PSCmdlet.ParameterSetName -ieq 'file') {
        $ScriptBlock = Convert-PodeFileToScriptBlock -FilePath $FilePath
    }

    # check for scoped vars
    $ScriptBlock, $usingVars = Convert-PodeScopedVariables -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState

    # add the schedule
    $parsedCrons = ConvertFrom-PodeCronExpressions -Expressions @($Cron)
    $nextTrigger = Get-PodeCronNextEarliestTrigger -Expressions $parsedCrons -StartTime $StartTime -EndTime $EndTime

    $PodeContext.Schedules.Enabled = $true
    $PodeContext.Schedules.Items[$Name] = @{
        Name            = $Name
        StartTime       = $StartTime
        EndTime         = $EndTime
        Crons           = $parsedCrons
        CronsRaw        = @($Cron)
        Limit           = $Limit
        Count           = 0
        NextTriggerTime = $nextTrigger
        LastTriggerTime = $null
        Script          = $ScriptBlock
        UsingVariables  = $usingVars
        Arguments       = (Protect-PodeValue -Value $ArgumentList -Default @{})
        OnStart         = $OnStart
        Completed       = ($null -eq $nextTrigger)
    }
}

<#
.SYNOPSIS
Set the maximum number of concurrent schedules.

.DESCRIPTION
Set the maximum number of concurrent schedules.

.PARAMETER Maximum
The Maximum number of schedules to run.

.EXAMPLE
Set-PodeScheduleConcurrency -Maximum 25
#>
function Set-PodeScheduleConcurrency {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]
        $Maximum
    )

    # error if <=0
    if ($Maximum -le 0) {
        throw "Maximum concurrent schedules must be >=1 but got: $($Maximum)"
    }

    # ensure max > min
    $_min = 1
    if ($null -ne $PodeContext.RunspacePools.Schedules) {
        $_min = $PodeContext.RunspacePools.Schedules.Pool.GetMinRunspaces()
    }

    if ($_min -gt $Maximum) {
        throw "Maximum concurrent schedules cannot be less than the minimum of $($_min) but got: $($Maximum)"
    }

    # set the max schedules
    $PodeContext.Threads.Schedules = $Maximum
    if ($null -ne $PodeContext.RunspacePools.Schedules) {
        $PodeContext.RunspacePools.Schedules.Pool.SetMaxRunspaces($Maximum)
    }
}

<#
.SYNOPSIS
Adhoc invoke a Schedule's logic.

.DESCRIPTION
Adhoc invoke a Schedule's logic outside of its defined cron-expression. This invocation doesn't count towards the Schedule's limit.

.PARAMETER Name
The Name of the Schedule.

.PARAMETER ArgumentList
A hashtable of arguments to supply to the Schedule's ScriptBlock.

.EXAMPLE
Invoke-PodeSchedule -Name 'schedule-name'
#>
function Invoke-PodeSchedule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]
        $Name,

        [Parameter()]
        [hashtable]
        $ArgumentList = $null
    )

    # ensure the schedule exists
    if (!$PodeContext.Schedules.Items.ContainsKey($Name)) {
        throw "Schedule '$($Name)' does not exist"
    }

    # run schedule logic
    Invoke-PodeInternalScheduleLogic -Schedule $PodeContext.Schedules.Items[$Name] -ArgumentList $ArgumentList
}

<#
.SYNOPSIS
Removes a specific Schedule.

.DESCRIPTION
Removes a specific Schedule.

.PARAMETER Name
The Name of the Schedule to be removed.

.EXAMPLE
Remove-PodeSchedule -Name 'RenewToken'
#>
function Remove-PodeSchedule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]
        $Name
    )

    $null = $PodeContext.Schedules.Items.Remove($Name)
}

<#
.SYNOPSIS
Removes all Schedules.

.DESCRIPTION
Removes all Schedules.

.EXAMPLE
Clear-PodeSchedules
#>
function Clear-PodeSchedules {
    [CmdletBinding()]
    param()

    $PodeContext.Schedules.Items.Clear()
}

<#
.SYNOPSIS
Edits an existing Schedule.

.DESCRIPTION
Edits an existing Schedule's properties, such an cron expressions or scriptblock.

.PARAMETER Name
The Name of the Schedule.

.PARAMETER Cron
Any new Cron Expressions for the Schedule.

.PARAMETER ScriptBlock
The new ScriptBlock for the Schedule.

.PARAMETER ArgumentList
Any new Arguments for the Schedule.

.EXAMPLE
Edit-PodeSchedule -Name 'Hello' -Cron '@minutely'

.EXAMPLE
Edit-PodeSchedule -Name 'Hello' -Cron @('@hourly', '0 0 * * TUE')
#>
function Edit-PodeSchedule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]
        $Name,

        [Parameter()]
        [string[]]
        $Cron,

        [Parameter()]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [hashtable]
        $ArgumentList
    )

    # ensure the schedule exists
    if (!$PodeContext.Schedules.Items.ContainsKey($Name)) {
        throw "Schedule '$($Name)' does not exist"
    }

    $_schedule = $PodeContext.Schedules.Items[$Name]

    # edit cron if supplied
    if (!(Test-PodeIsEmpty $Cron)) {
        $_schedule.Crons = (ConvertFrom-PodeCronExpressions -Expressions @($Cron))
        $_schedule.CronsRaw = $Cron
        $_schedule.NextTriggerTime = Get-PodeCronNextEarliestTrigger -Expressions $_schedule.Crons -StartTime $_schedule.StartTime -EndTime $_schedule.EndTime
    }

    # edit scriptblock if supplied
    if (!(Test-PodeIsEmpty $ScriptBlock)) {
        $ScriptBlock, $usingVars = Convert-PodeScopedVariables -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState
        $_schedule.Script = $ScriptBlock
        $_schedule.UsingVariables = $usingVars
    }

    # edit arguments if supplied
    if (!(Test-PodeIsEmpty $ArgumentList)) {
        $_schedule.Arguments = $ArgumentList
    }
}

<#
.SYNOPSIS
Returns any defined schedules.

.DESCRIPTION
Returns any defined schedules, with support for filtering.

.PARAMETER Name
Any schedule Names to filter the schedules.

.PARAMETER StartTime
An optional StartTime to only return Schedules that will trigger after this date.

.PARAMETER EndTime
An optional EndTime to only return Schedules that will trigger before this date.

.EXAMPLE
Get-PodeSchedule

.EXAMPLE
Get-PodeSchedule -Name Name1, Name2

.EXAMPLE
Get-PodeSchedule -Name Name1, Name2 -StartTime [datetime]::new(2020, 3, 1) -EndTime [datetime]::new(2020, 3, 31)
#>
function Get-PodeSchedule {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string[]]
        $Name,

        [Parameter()]
        $StartTime = $null,

        [Parameter()]
        $EndTime = $null
    )

    $schedules = $PodeContext.Schedules.Items.Values

    # further filter by schedule names
    if (($null -ne $Name) -and ($Name.Length -gt 0)) {
        $schedules = @(foreach ($_name in $Name) {
                foreach ($schedule in $schedules) {
                    if ($schedule.Name -ine $_name) {
                        continue
                    }

                    $schedule
                }
            })
    }

    # filter by some start time
    if ($null -ne $StartTime) {
        $schedules = @(foreach ($schedule in $schedules) {
                if (($null -ne $schedule.StartTime) -and ($StartTime -lt $schedule.StartTime)) {
                    continue
                }

                $_end = $EndTime
                if ($null -eq $_end) {
                    $_end = $schedule.EndTime
                }

                if (($null -ne $schedule.EndTime) -and
                (($StartTime -gt $schedule.EndTime) -or
                    ((Get-PodeScheduleNextTrigger -Name $schedule.Name -DateTime $StartTime) -gt $_end))) {
                    continue
                }

                $schedule
            })
    }

    # filter by some end time
    if ($null -ne $EndTime) {
        $schedules = @(foreach ($schedule in $schedules) {
                if (($null -ne $schedule.EndTime) -and ($EndTime -gt $schedule.EndTime)) {
                    continue
                }

                $_start = $StartTime
                if ($null -eq $_start) {
                    $_start = $schedule.StartTime
                }

                if (($null -ne $schedule.StartTime) -and
                (($EndTime -lt $schedule.StartTime) -or
                    ((Get-PodeScheduleNextTrigger -Name $schedule.Name -DateTime $_start) -gt $EndTime))) {
                    continue
                }

                $schedule
            })
    }

    # return
    return $schedules
}

<#
.SYNOPSIS
Tests whether the passed Schedule exists.

.DESCRIPTION
Tests whether the passed Schedule exists by its name.

.PARAMETER Name
The Name of the Schedule.

.EXAMPLE
if (Test-PodeSchedule -Name ScheduleName) { }
#>
function Test-PodeSchedule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    return (($null -ne $PodeContext.Schedules.Items) -and $PodeContext.Schedules.Items.ContainsKey($Name))
}

<#
.SYNOPSIS
Get the next trigger time for a Schedule.

.DESCRIPTION
Get the next trigger time for a Schedule, either from the Schedule's StartTime or from a defined DateTime.

.PARAMETER Name
The Name of the Schedule.

.PARAMETER DateTime
An optional specific DateTime to get the next trigger time after. This DateTime must be between the Schedule's StartTime and EndTime.

.EXAMPLE
Get-PodeScheduleNextTrigger -Name Schedule1

.EXAMPLE
Get-PodeScheduleNextTrigger -Name Schedule1 -DateTime [datetime]::new(2020, 3, 10)
#>
function Get-PodeScheduleNextTrigger {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]
        $Name,

        [Parameter()]
        $DateTime = $null
    )

    # ensure the schedule exists
    if (!$PodeContext.Schedules.Items.ContainsKey($Name)) {
        throw "Schedule '$($Name)' does not exist"
    }

    $_schedule = $PodeContext.Schedules.Items[$Name]

    # ensure date is after start/before end
    if (($null -ne $DateTime) -and ($null -ne $_schedule.StartTime) -and ($DateTime -lt $_schedule.StartTime)) {
        throw "Supplied date is before the start time of the schedule at $($_schedule.StartTime)"
    }

    if (($null -ne $DateTime) -and ($null -ne $_schedule.EndTime) -and ($DateTime -gt $_schedule.EndTime)) {
        throw "Supplied date is after the end time of the schedule at $($_schedule.EndTime)"
    }

    # get the next trigger
    if ($null -eq $DateTime) {
        $DateTime = $_schedule.StartTime
    }

    return (Get-PodeCronNextEarliestTrigger -Expressions $_schedule.Crons -StartTime $DateTime -EndTime $_schedule.EndTime)
}

<#
.SYNOPSIS
Automatically loads schedule ps1 files

.DESCRIPTION
Automatically loads schedule ps1 files from either a /schedules folder, or a custom folder. Saves space dot-sourcing them all one-by-one.

.PARAMETER Path
Optional Path to a folder containing ps1 files, can be relative or literal.

.EXAMPLE
Use-PodeSchedules

.EXAMPLE
Use-PodeSchedules -Path './my-schedules'
#>
function Use-PodeSchedules {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Path
    )

    Use-PodeFolder -Path $Path -DefaultPath 'schedules'
}