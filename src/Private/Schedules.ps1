function Find-PodeSchedule {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name
    )

    return $PodeContext.Schedules.Items[$Name]
}

function Test-PodeSchedulesExist {
    return (($null -ne $PodeContext.Schedules) -and (($PodeContext.Schedules.Enabled) -or ($PodeContext.Schedules.Items.Count -gt 0)))
}
function Start-PodeScheduleRunspace {

    if (!(Test-PodeSchedulesExist)) {
        return
    }

    Add-PodeTimer -Name '__pode_schedule_housekeeper__' -Interval 30 -ScriptBlock {
        try {
            if ($PodeContext.Schedules.Processes.Count -eq 0) {
                return
            }

            $now = [datetime]::UtcNow

            foreach ($key in $PodeContext.Schedules.Processes.Keys.Clone()) {
                try {
                    $process = $PodeContext.Schedules.Processes[$key]

                    # if it's completed or expired, dispose and remove
                    if ($process.Runspace.Handler.IsCompleted -or ($process.ExpireTime -lt $now)) {
                        Close-PodeScheduleInternal -Process $process
                    }
                }
                catch {
                    $_ | Write-PodeErrorLog
                }
            }

            $process = $null
        }
        catch {
            $_ | Write-PodeErrorLog
        }
    }

    $script = {
        try {

            # Waits for the Pode server to fully start before proceeding with further operations.
            Wait-PodeCancellationTokenRequest -Type Start

            # select the schedules that trigger on-start
            $_now = [DateTime]::Now

            $PodeContext.Schedules.Items.Values |
                Where-Object {
                    $_.OnStart
                } | ForEach-Object {
                    Invoke-PodeInternalSchedule -Schedule $_
                }

            # complete any schedules
            Complete-PodeInternalSchedule -Now $_now

            # first, sleep for a period of time to get to 00 seconds (start of minute)
            Start-PodeSleep -Seconds (60 - [DateTime]::Now.Second)

            while (!(Test-PodeCancellationTokenRequest -Type Terminate)) {

                # Check for suspension token and wait for the debugger to reset if active
                Test-PodeSuspensionToken

                try {
                    $_now = [DateTime]::Now

                    # select the schedules that need triggering
                    $PodeContext.Schedules.Items.Values |
                        Where-Object {
                            !$_.Completed -and
                            (($null -eq $_.StartTime) -or ($_.StartTime -le $_now)) -and
                            (($null -eq $_.EndTime) -or ($_.EndTime -ge $_now)) -and
                            (Test-PodeCronExpressions -Expressions $_.Crons -DateTime $_now)
                        } | ForEach-Object {
                            try {
                                Invoke-PodeInternalSchedule -Schedule $_
                            }
                            catch {
                                $_ | Write-PodeErrorLog
                            }
                        }

                    # complete any schedules
                    Complete-PodeInternalSchedule -Now $_now

                    # cron expression only goes down to the minute, so sleep for 1min
                    Start-PodeSleep -Seconds (60 - [DateTime]::Now.Second)
                }
                catch {
                    $_ | Write-PodeErrorLog
                }
            }
        }
        catch [System.OperationCanceledException] {
            $_ | Write-PodeErrorLog -Level Debug
        }
        catch {
            $_ | Write-PodeErrorLog
            throw $_.Exception
        }
    }

    Add-PodeRunspace -Type Main -Name 'Schedules' -ScriptBlock $script -NoProfile
}

function Close-PodeScheduleInternal {
    param(
        [Parameter()]
        [hashtable]
        $Process
    )

    if ($null -eq $Process) {
        return
    }

    Close-PodeDisposable -Disposable $Process.Runspace.Pipeline
    $null = $PodeContext.Schedules.Processes.Remove($Process.ID)
}

<#
.SYNOPSIS
    Completes schedules that have exceeded their end time.

.DESCRIPTION
    The `Complete-PodeInternalSchedule` function checks for schedules that have an end time
    and marks them as completed if their end time is earlier than the current time.

.PARAMETER Now
    Specifies the current date and time. This parameter is mandatory.

.INPUTS
    None. You cannot pipe objects to Complete-PodeInternalSchedule.

.OUTPUTS
    None. The function modifies the state of schedules in the PodeContext.

.EXAMPLE
    # Example usage:
    $now = Get-Date
    Complete-PodeInternalSchedule -Now $now
    # Schedules that have ended are marked as completed.

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function Complete-PodeInternalSchedule {
    param(
        [Parameter(Mandatory = $true)]
        [datetime]
        $Now
    )

    # set any expired schedules as being completed
    foreach ($schedule in $PodeContext.Schedules.Items.Values) {
        if (($null -ne $schedule.EndTime) -and ($schedule.EndTime -lt $Now)) {
            $schedule.Completed = $true
        }
    }
}

function Invoke-PodeInternalSchedule {
    param(
        [Parameter(Mandatory = $true)]
        $Schedule
    )

    $Schedule.OnStart = $false

    # increment total number of triggers for the schedule
    $Schedule.Count++

    # set last trigger to current next trigger
    if ($null -ne $Schedule.NextTriggerTime) {
        $Schedule.LastTriggerTime = $Schedule.NextTriggerTime
    }
    else {
        $Schedule.LastTriggerTime = [datetime]::Now
    }

    # check if we have hit the limit, and remove
    if (($Schedule.Limit -gt 0) -and ($Schedule.Count -ge $Schedule.Limit)) {
        $Schedule.Completed = $true
    }

    # reset the cron and next trigger
    if (!$Schedule.Completed) {
        $Schedule.Crons = Reset-PodeRandomCronExpressions -Expressions $Schedule.Crons
        $Schedule.NextTriggerTime = Get-PodeCronNextEarliestTrigger -Expressions $Schedule.Crons -EndTime $Schedule.EndTime
    }
    else {
        $Schedule.NextTriggerTime = $null
    }

    # trigger the schedules logic
    Invoke-PodeInternalScheduleLogic -Schedule $Schedule
}

function Invoke-PodeInternalScheduleLogic {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]
        $Schedule,

        [Parameter()]
        [hashtable]
        $ArgumentList = $null
    )

    try {
        # generate processId for schedule
        $processId = New-PodeGuid

        # setup event param
        $parameters = @{
            ProcessId    = $processId
            ArgumentList = $ArgumentList
        }

        # what is the expire time if using "create" timeout?
        $expireTime = [datetime]::MaxValue
        $createTime = [datetime]::UtcNow

        if (($Schedule.Timeout.From -ieq 'Create') -and ($Schedule.Timeout.Value -ge 0)) {
            $expireTime = $createTime.AddSeconds($Schedule.Timeout.Value)
        }
        # add the schedule process
        $PodeContext.Schedules.Processes[$processId] = @{
            ID         = $processId
            Schedule   = $Schedule.Name
            Runspace   = $null
            CreateTime = $createTime
            StartTime  = $null
            ExpireTime = $expireTime
            Timeout    = $Schedule.Timeout
            State      = 'Pending'
        }

        # start the schedule runspace
        $scriptblock = Get-PodeScheduleScriptBlock
        $runspace = Add-PodeRunspace -Type Schedules -Name $Schedule.Name -ScriptBlock $scriptblock -Parameters $parameters -PassThru
        # add runspace to process
        $PodeContext.Schedules.Processes[$processId].Runspace = $runspace
    }
    catch {
        $_ | Write-PodeErrorLog
    }
}

function Get-PodeScheduleScriptBlock {
    return {
        param($ProcessId, $ArgumentList)

        try {
            # get the schedule process, error if not found
            $process = $PodeContext.Schedules.Processes[$ProcessId]
            if ($null -eq $process) {
                # Schedule process does not exist: $ProcessId
                throw ($PodeLocale.scheduleProcessDoesNotExistExceptionMessage -f $ProcessId)
            }

            # set start time and state
            $process.StartTime = [datetime]::UtcNow
            $process.State = 'Running'

            # set expire time if timeout based on "start" time
            if (($process.Timeout.From -ieq 'Start') -and ($process.Timeout.Value -ge 0)) {
                $process.ExpireTime = $process.StartTime.AddSeconds($process.Timeout.Value)
            }

            # get the schedule, error if not found
            $schedule = Find-PodeSchedule -Name $process.Schedule
            if ($null -eq $schedule) {
                throw ($PodeLocale.scheduleDoesNotExistExceptionMessage -f $process.Schedule)
            }

            # build the script arguments
            $ScheduleEvent = @{
                Lockable  = $PodeContext.Threading.Lockables.Global
                Sender    = $schedule
                Timestamp = [DateTime]::UtcNow
                Metadata  = @{}
            }

            $_args = @{ Event = $ScheduleEvent }

            if ($null -ne $schedule.Arguments) {
                foreach ($key in $schedule.Arguments.Keys) {
                    $_args[$key] = $schedule.Arguments[$key]
                }
            }

            if ($null -ne $ArgumentList) {
                foreach ($key in $ArgumentList.Keys) {
                    $_args[$key] = $ArgumentList[$key]
                }
            }

            # add any using variables
            if ($null -ne $schedule.UsingVariables) {
                foreach ($usingVar in $schedule.UsingVariables) {
                    $_args[$usingVar.NewName] = $usingVar.Value
                }
            }

            # invoke the script from the schedule
            Invoke-PodeScriptBlock -ScriptBlock $schedule.Script -Arguments $_args -Scoped -Splat

            # set state to completed
            $process.State = 'Completed'
        }
        catch {
            # update the state
            if ($null -ne $process) {
                $process.State = 'Failed'
            }

            # log the error
            $_ | Write-PodeErrorLog
        }
        finally {
            Reset-PodeRunspaceName
            Invoke-PodeGC
        }
    }
}