# Timers

A Timer in Pode is a short-running async task. All timers in Pode run in the same runspace along side your main server logic - so aim to keep them as short running as possible. Timers have unique names, and iterate on a defined number of seconds.

!!! warning
    Since all timers are run within the same runspace, it is wise to keep them as short running as possible. If you require a long-running task it's recommend to use [Schedules](../Schedules) instead.

## Create a Timer

You can create a new timer using [`Add-PodeTimer`](../../Functions/Timers/Add-PodeTimer). To create a basic Timer, the following example will work; this will loop every 5 seconds outputting the date/time:

```powershell
Add-PodeTimer -Name 'date' -Interval 5 -ScriptBlock {
    Write-Host "$([DateTime]::Now)"
}
```

Usually all timers are created within the main `Start-PodeServer` scope, however it is possible to create adhoc timers with routes/etc. If you create adhoc timers in this manor, you might notice that they don't run; this is because the Runspace that timers use to run won't have been configured. You can configure by using `-EnablePool` on [`Start-PodeServer`](../../Functions/Core/Start-PodeServer):

```powershell
Start-PodeServer -EnablePool Timers {
    Add-PodeEndpoint -Address * -Port 8080 -Protocol Http

    Add-PodeRoute -Method Get -Path '/create-timer' -ScriptBlock {
        Add-PodeTimer -Name 'example' -Interval 5 -ScriptBlock {
            # logic
        }
    }
}
```

## Arguments

You can supply custom arguments to be passed to your timers by using the `-ArgumentList` parameter. This parameter takes an array of objects, which will be splatted onto the timer's scriptblock:

```powershell
Add-PodeTimer -Name 'example' -Interval 5 -ArgumentList 'Item1', 'Item2' -ScriptBlock {
    param($i1, $i2)

    # $i1 will be 'Item1'
}
```

## Delayed Start

The `-Skip <int>` parameter will cause the Timer to skip its first initial triggers. For example, if you have a Timer run every 10 seconds, and you pass `-Skip 5`, then the timer will first run after 50 seconds (10secs * skip 5).

The following will create a Timer that runs every 10 seconds, and skips the first 5 iterations:

```powershell
Add-PodeTimer -Name 'date' -Interval 10 -Skip 5 -ScriptBlock {
    Write-Host "$([DateTime]::Now)"
}
```

## Run X Times

Normally a Timer will run forever, or at least until you terminate the server. Sometimes you might want a Timer to end early, or only run once. To do this you use the `-Limit <int>` parameter, which defines the number of times the Timer should execute.

The following will run every 20 seconds, and will only run 3 times:

```powershell
Add-PodeTimer -Name 'date' -Interval 20 -Limit 3 -ScriptBlock {
    Write-Host "$([DateTime]::Now)"
}
```

## Script from File

You normally define a timer's script using the `-ScriptBlock` parameter however, you can also reference a file with the required scriptblock using `-FilePath`. Using the `-FilePath` parameter will dot-source a scriptblock from the file, and set it as the timer's script.

For example, to create a timer from a file that will output `Hello, world` every 2secs:

* File.ps1
```powershell
{
    'Hello, world!' | Out-PodeHost
}
```

* Timer
```powershell
Add-PodeTimer -Name 'from-file' -Interval 2 -FilePath './Timers/File.ps1'
```

## Getting Timers

The [`Get-PodeTimer`](../../Functions/Timers/Get-PodeTimer) helper function will allow you to retrieve a list of timers configured within Pode. You can use it to retrieve all of the timers, or supply filters to retrieve specific ones.

To retrieve all of the timers, you can call the function will no parameters. To filter, here are some examples:

```powershell
# one timer by name
Get-PodeTimer -Name Name1

# multiple timers by name
Get-PodeTimer -Name Name1, Name2
```

## Manual Trigger

You can manually trigger a timer by using [`Invoke-PodeTimer`](../../Functions/Timers/Invoke-PodeTimer). This will run the timer immediately, and will not count towards a timer's run limit:

```powershell
Invoke-PodeTimer -Name 'timer-name'
```

You can also pass further optional arguments that will be supplied to the timer's scriptblock by using `-ArgumentList`, which is an array of objects that will be splatted:

```powershell
Add-PodeTimer -Name 'date' -Interval 5 -ScriptBlock {
    param($date)
    Write-Host $date
}

Invoke-PodeTimer -Name 'date' -ArgumentList ([DateTime]::Now)
```

If you supply an `-ArgumentList` on `Add-PodeTimer` and on `Invoke-PodeTimer`, then the main timer arguments are splatted first:

```powershell
Add-PodeTimer -Name 'example' -Interval 5 -ArgumentList 'Item1', 'Item2' -ScriptBlock {
    param($i1, $i2, $a1, $a2)

    # $i1 will be 'Item1'
    # $a1 will be 'Arg1'
}

Invoke-PodeTimer -Name 'date' -ArgumentList 'Arg1', 'Arg2'
```

## Timer Object

!!! warning
    Be careful if you choose to edit these objects, as they will affect the server.

The following is the structure of the Timer object internally, as well as the object that is returned from [`Get-PodeTimer`](../../Functions/Timers/Get-PodeTimer):

| Name | Type | Description |
| ---- | ---- | ----------- |
| Name | string | The name of the Timer |
| Interval | int | How often the Timer runs, defined in seconds |
| Limit | int | The number of times the Timer should run - 0 if running forever |
| Skip | int | The number of times the Timer should skip being triggered |
| Count | int | The number of times the Timer has run |
| LastTriggerTime | datetime | The datetime the Timer was last triggered |
| NextTriggerTime | datetime | The datetime the Timer will next be triggered |
| Script | scriptblock | The scriptblock of the Timer |
| Arguments | object[] | The arguments supplied from ArgumentList |
| OnStart | bool | Should the Timer run once when the server is starting, or once the server has fully loaded |
| Completed | bool | Has the Timer completed all of its runs |
