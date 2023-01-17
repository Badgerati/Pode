function Find-PodeSchedule
{
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name
    )

    return $PodeContext.Schedules.Items[$Name]
}

function Test-PodeSchedulesExist
{
    return (($null -ne $PodeContext.Schedules) -and (($PodeContext.Schedules.Enabled) -or ($PodeContext.Schedules.Items.Count -gt 0)))
}

function Start-PodeScheduleRunspace
{
    if (!(Test-PodeSchedulesExist)) {
        return
    }

    Add-PodeSchedule -Name '__pode_schedule_housekeeper__' -Cron '@minutely' -ScriptBlock {
        if ($PodeContext.Schedules.Processes.Count -eq 0) {
            return
        }

        foreach ($key in $PodeContext.Schedules.Processes.Keys.Clone()) {
            $process = $PodeContext.Schedules.Processes[$key]

            # is it completed?
            if (!$process.Runspace.Handler.IsCompleted) {
                continue
            }

            # dispose and remove the schedule process
            Close-PodeScheduleInternal -Process $process
        }

        $process = $null
    }

    $script = {
        # select the schedules that trigger on-start
        $_now = [DateTime]::Now

        $PodeContext.Schedules.Items.Values |
            Where-Object {
                $_.OnStart
            } | ForEach-Object {
                Invoke-PodeInternalSchedule -Schedule $_
            }

        # complete any schedules
        Complete-PodeInternalSchedules -Now $_now

        # first, sleep for a period of time to get to 00 seconds (start of minute)
        Start-Sleep -Seconds (60 - [DateTime]::Now.Second)

        while (!$PodeContext.Tokens.Cancellation.IsCancellationRequested)
        {
            $_now = [DateTime]::Now

            # select the schedules that need triggering
            $PodeContext.Schedules.Items.Values |
                Where-Object {
                    !$_.Completed -and
                    (($null -eq $_.StartTime) -or ($_.StartTime -le $_now)) -and
                    (($null -eq $_.EndTime) -or ($_.EndTime -ge $_now)) -and
                    (Test-PodeCronExpressions -Expressions $_.Crons -DateTime $_now)
                } | ForEach-Object {
                    Invoke-PodeInternalSchedule -Schedule $_
                }

            # complete any schedules
            Complete-PodeInternalSchedules -Now $_now

            # cron expression only goes down to the minute, so sleep for 1min
            Start-Sleep -Seconds (60 - [DateTime]::Now.Second)
        }
    }

    Add-PodeRunspace -Type Main -ScriptBlock $script -NoProfile
}

function Close-PodeScheduleInternal
{
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

function Complete-PodeInternalSchedules
{
    param(
        [Parameter(Mandatory=$true)]
        [datetime]
        $Now
    )

    # add any schedules to remove that have exceeded their end time
    $Schedules = @($PodeContext.Schedules.Items.Values |
        Where-Object { (($null -ne $_.EndTime) -and ($_.EndTime -lt $Now)) })

    if (($null -eq $Schedules) -or ($Schedules.Length -eq 0)) {
        return
    }

    # set any expired schedules as being completed
    $Schedules | ForEach-Object {
        $_.Completed = $true
    }
}

function Invoke-PodeInternalSchedule
{
    param(
        [Parameter(Mandatory=$true)]
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

function Invoke-PodeInternalScheduleLogic
{
    param(
        [Parameter(Mandatory=$true)]
        $Schedule,

        [Parameter()]
        [hashtable]
        $ArgumentList = $null
    )

    try {
        # setup event param
        $parameters = @{
            Event = @{
                Lockable = $PodeContext.Threading.Lockables.Global
                Sender = $Schedule
            }
        }

        # add any schedule args
        foreach ($key in $Schedule.Arguments.Keys) {
            $parameters[$key] = $Schedule.Arguments[$key]
        }

        # add adhoc schedule invoke args
        if (($null -ne $ArgumentList) -and ($ArgumentList.Count -gt 0)) {
            foreach ($key in $ArgumentList.Keys) {
                $parameters[$key] = $ArgumentList[$key]
            }
        }

        # add any using variables
        if ($null -ne $Schedule.UsingVariables) {
            foreach ($usingVar in $Schedule.UsingVariables) {
                $parameters[$usingVar.NewName] = $usingVar.Value
            }
        }

        $name = New-PodeGuid
        $runspace = Add-PodeRunspace -Type Schedules -ScriptBlock (($Schedule.Script).GetNewClosure()) -Parameters $parameters -PassThru

        $PodeContext.Schedules.Processes[$name] = @{
            ID = $name
            Schedule = $Schedule.Name
            Runspace = $runspace
        }
    }
    catch {
        $_ | Write-PodeErrorLog
    }
}