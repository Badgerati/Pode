# Schedules

A schedule in Pode is a long-running async task, and unlike timers, when they trigger they are run in their own separate runspace - so they don't affect each other if they take a while to process.

Schedule triggers are defined using [`cron expressions`](../Misc/CronExpressions), basic syntax is supported as well as some predefined expressions. Schedules can start immediately, have a delayed start time, and also have a a defined end time.

## Create a Schedule

To create a new schedule in your server you use the [`schedule`](../../Functions/Core/Schedule) function. The make-up of the function is as follows:

```powershell
schedule <name> <cron(s)> <scriptblock> [-start <datetime>] [-end <datetime>] [-limit <int>]

# or shorthand:
schedule <name> <cron(s)> <scriptblock> [-s <datetime>] [-e <datetime>] [-l <int>]
```

Each schedule must have a `<name>`, one or more `<cron>` expressions, and a `<scriptblock>` for the main logic. The `<name>` must be unique across all schedules.

To create a basic `schedule`, the following example will work; this will trigger at '00:05' every Tuesday outputting the current date/time:

```powershell
Server {
    schedule 'date' '5 0 * * TUE' {
        Write-Host "$([DateTime]::Now)"
    }
}
```

Whereas the following will create the same schedule, but will only trigger the schedule 4 times due to the `-limit` value supplied:

```powershell
Server {
    schedule 'date' '5 0 * * TUE' -limit 4 {
        Write-Host "$([DateTime]::Now)"
    }
}
```

You can also supply multiple cron expressions for the same `schedule`. For example, the following will trigger the same schedule every minute and every hour:

```powershell
Server {
    schedule 'date' @('@minutely', '@hourly') {
        Write-Host "$([DateTime]::Now)"
    }
}
```

## Delayed Start

The `-start <datetime>` parameter will cause the `schedule` to only be triggered after the date/time defined. For example, if you have a schedule set to trigger at 00:05 every Tuesday, and you pass `-start [DateTime]::Now.AddMonths(2)`, then the schedule will only start trigger on Tuesdays in 2 months time.

The following will create a `schedule` that triggers at 16:00 every Friday, and is delayed by 1 year:

```powershell
Server {
    $start = [DateTime]::Now.AddYears(1)

    schedule 'date' '0 16 * * FRI' -start $start {
        Write-Host "$([DateTime]::Now)"
    }
}
```

## Defined End

The `-end <datetime>` parameter will cause the `schedule` to cease triggering after the date/time defined. For example, if you have a schedule set to trigger at 00:05 every Tuesday, and you pass `-end [DateTime]::Now.AddMonths(2)`, then the schedule will stop triggering in 2 months time.

The following will create a `schedule` that triggers at 16:00 every Friday, and stops triggering in 1 year:

```powershell
Server {
    $end = [DateTime]::Now.AddYears(1)

    schedule 'date' '0 16 * * FRI' -end $end {
        Write-Host "$([DateTime]::Now)"
    }
}
```