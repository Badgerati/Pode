# Schedules

A Schedule in Pode is a long-running async task, and unlike timers, when they trigger they are run in their own separate runspace - so they don't affect each other if they take a while to process. By default up to a maximum of 10 schedules can run concurrently, but this can be changed by using the [`Set-PodeScheduleConcurrency`](../../Functions/Core/Set-PodeScheduleConcurrency) function.

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

!!! important
    In schedules, your scriptblock parameter names must be exact - including case-sensitivity. This is because the arguments are splatted into a runspace. If you pass in an argument called "Names", the param-block must have `$Names` exactly. Furthermore, the event parameter *must* be called `$Event`.

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

* Schedule
```powershell
Add-PodeSchedule -Name 'from-file' -Cron '@minutely' -FilePath './Schedules/File.ps1'
```

## Getting Schedules

The [`Get-PodeSchedule`](../../Functions/Core/Get-PodeSchedule) helper function will allow you to retrieve a list of schedules configured within Pode. You can use it to retrieve all of the schedules, or supply filters to retrieve specific ones.

To retrieve all of the schedules, you can call the function will no parameters. To filter, here are some examples:

```powershell
# one schedule by name
Get-PodeSchedule -Name Name1

# multiple schedules by name
Get-PodeSchedule -Name Name1, Name2
```

## Next Trigger Time

When you retrieve a Schedule using [`Get-PodeSchedule`](../../Functions/Core/Get-PodeSchedule), each Schedule object will already have its next trigger time as `NextTriggerTime`. However, if you want to get a trigger time further ino the future than this, then you can use the [`Get-PodeScheduleNextTrigger`](../../Functions/Core/Get-PodeScheduleNextTrigger) function.

This function takes the Name of a Schedule, as well as a custom DateTime and will return the next trigger time after that DateTime. If no DateTime is supplied, then the Schedule's StartTime is used (or the current time if no StartTime).

```powershell
# just get the next time
$time = Get-PodeScheduleNextTrigger -Name Schedule1

# get the next time after a date
$time = Get-PodeScheduleTriggerTime -Name Schedule1 -DateTime [datetime]::new(2020, 3, 20)
```

## Schedule Object

!!! warning
    Be careful if you choose to edit these objects, as they will affect the server.

The following is the structure of the Schedule object internally, as well as the object that is returned from [`Get-PodeSchedule`](../../Functions/Core/Get-PodeSchedule):

| Name | Type | Description |
| ---- | ---- | ----------- |
| Name | string | The name of the Schedule |
| StartTime | datetime | The delayed start time of the Schedule |
| EndTime | datetime | The end time of the Schedule |
| Crons | hashtable[] | The cron expressions of the Schedule, but parsed into an internal format |
| CronsRaw | string[] | The raw cron expressions that were supplied |
| Limit | int | The number of times the Schedule should run - 0 if running infinitely |
| Count | int | The number of times the Schedule has run |
| NextTriggerTime | datetime | The datetime the Schedule will next be triggered |
| Script | scriptblock | The scriptblock of the Schedule |
| Arguments | hashtable | The arguments supplied from ArgumentList |
| OnStart | bool | Should the Schedule run once when the server is starting, or once the server has fully loaded |
| Completed | bool | Has the Schedule completed all of its runs |
