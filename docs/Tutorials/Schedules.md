# Schedules

A Schedule in Pode is a long-running async task, and unlike timers, when they trigger they are run in their own separate runspace - so they don't affect each other if they take a while to process.

Schedule triggers are defined using [`cron expressions`](../Misc/CronExpressions), basic syntax is supported as well as some predefined expressions. Schedules can start immediately, have a delayed start time, and also have a defined end time.

## Create a Schedule

To create a new Schedule in your server you use the Schedule functions.

To create a basic Schedule, the following example will work; this will trigger at '00:05' every Tuesday outputting the current date/time:

```powershell
Add-PodeSchedule -Name 'date' -Cron '5 0 * * TUE' -ScriptBlock {
    Write-Host "$([DateTime]::Now)"
}
```

Whereas the following will create the same schedule, but will only trigger the schedule 4 times due to the `-Limit` value supplied:

```powershell
Add-PodeSchedule -Name 'date' -Cron '5 0 * * TUE' -Limit 4 -ScriptBlock {
    Write-Host "$([DateTime]::Now)"
}
```

You can also supply multiple cron expressions for the same Schedule. For example, the following will trigger the same schedule every minute and every hour:

```powershell
Add-PodeSchedule -Name 'date' -Cron @('@minutely', '@hourly') -ScriptBlock {
    Write-Host "$([DateTime]::Now)"
}
```

### Arguments

You can supply custom arguments to your schedules by using the `-ArgumentList` parameter. Unlike other features, for schedules the `-ArgumentList` is a hashtable; this is done because parameters to the `-ScriptBlock` are splatted in, and the parameter names are literal.

For example, the first parameter to a schedule is always `$Event` - this contains the `.Lockable` object. Other parameters come from any Key/Values contained with the optional `-ArgumentList`:

```powershell
Add-PodeSchedule -Name 'date' -Cron '@minutely' -ArgumentList @{ Name = 'Rick'; Environment = 'Multiverse' } -ScriptBlock {
    param($Event, $Name, $Environment)
}
```

## Delayed Start

The `-StartTime <datetime>` parameter will cause the Schedule to only be triggered after the date/time defined. For example, if you have a schedule set to trigger at 00:05 every Tuesday, and you pass `-StartTime [DateTime]::Now.AddMonths(2)`, then the schedule will only start trigger on Tuesdays in 2 months time.

The following will create a Schedule that triggers at 16:00 every Friday, and is delayed by 1 year:

```powershell
$start = [DateTime]::Now.AddYears(1)

Add-PodeSchedule -Name 'date' -Cron '0 16 * * FRI' -StartTime $start -ScriptBlock {
    Write-Host "$([DateTime]::Now)"
}
```

## Defined End

The `-EndTime <datetime>` parameter will cause the Schedule to cease triggering after the date/time defined. For example, if you have a schedule set to trigger at 00:05 every Tuesday, and you pass `-EndTime [DateTime]::Now.AddMonths(2)`, then the schedule will stop triggering in 2 months time.

The following will create a Schedule that triggers at 16:00 every Friday, and stops triggering in 1 year:

```powershell
$end = [DateTime]::Now.AddYears(1)

Add-PodeSchedule -Name 'date' -Cron '0 16 * * FRI' -EndTime $end -ScriptBlock {
    Write-Host "$([DateTime]::Now)"
}
```

## Script from File

You normally define a schedule's script using the `-ScriptBlock` parameter however, you can also reference a file with the required scriptblock using `-FilePath`. Using the `-FilePath` parameter will dot-source a scriptblock from the file, and set it as the schedule's script.

For example, to create a schedule from a file that will output `Hello, world` every minute:

* File.ps1
```powershell
{
    'Hello, world!' | Out-PodeHost
}
```

* Timer
```powershell
Add-PodeSchedule -Name 'from-file' -Cron '@minutely' -FilePath './Schedules/File.ps1'
```
