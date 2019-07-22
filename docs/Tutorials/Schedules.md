# Schedules

A Schedule in Pode is a long-running async task, and unlike timers, when they trigger they are run in their own separate runspace - so they don't affect each other if they take a while to process.

Schedule triggers are defined using [`cron expressions`](../Misc/CronExpressions), basic syntax is supported as well as some predefined expressions. Schedules can start immediately, have a delayed start time, and also have a a defined end time.

## Create a Schedule

To create a new Schedule in your server you use the Schedule functions.

To create a basic Schedule, the following example will work; this will trigger at '00:05' every Tuesday outputting the current date/time:

```powershell
Start-PodeServer {
    Add-PodeSchedule -Name 'date' -Cron '5 0 * * TUE' -ScriptBlock {
        Write-Host "$([DateTime]::Now)"
    }
}
```

Whereas the following will create the same schedule, but will only trigger the schedule 4 times due to the `-Limit` value supplied:

```powershell
Start-PodeServer {
    Add-PodeSchedule -Name 'date' -Cron '5 0 * * TUE' -Limit 4 -ScriptBlock {
        Write-Host "$([DateTime]::Now)"
    }
}
```

You can also supply multiple cron expressions for the same Schedule. For example, the following will trigger the same schedule every minute and every hour:

```powershell
Start-PodeServer {
    Add-PodeSchedule -Name 'date' -Cron @('@minutely', '@hourly') -ScriptBlock {
        Write-Host "$([DateTime]::Now)"
    }
}
```

## Delayed Start

The `-StartTime <datetime>` parameter will cause the Schedule to only be triggered after the date/time defined. For example, if you have a schedule set to trigger at 00:05 every Tuesday, and you pass `-StartTime [DateTime]::Now.AddMonths(2)`, then the schedule will only start trigger on Tuesdays in 2 months time.

The following will create a Schedule that triggers at 16:00 every Friday, and is delayed by 1 year:

```powershell
Start-PodeServer {
    $start = [DateTime]::Now.AddYears(1)

    Add-PodeSchedule -Name 'date' -Cron '0 16 * * FRI' -StartTime $start {
        Write-Host "$([DateTime]::Now)"
    }
}
```

## Defined End

The `-EndTime <datetime>` parameter will cause the Schedule to cease triggering after the date/time defined. For example, if you have a schedule set to trigger at 00:05 every Tuesday, and you pass `-EndTime [DateTime]::Now.AddMonths(2)`, then the schedule will stop triggering in 2 months time.

The following will create a Schedule that triggers at 16:00 every Friday, and stops triggering in 1 year:

```powershell
Start-PodeServer {
    $end = [DateTime]::Now.AddYears(1)

    Add-PodeSchedule -Name 'date' -Cron '0 16 * * FRI' -EndTime $end -ScriptBlock {
        Write-Host "$([DateTime]::Now)"
    }
}
```
