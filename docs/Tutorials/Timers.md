# Timers

A Timer in Pode is a short-running async task. All timers in Pode run in the same runspace along side your main server logic - so aim to keep them as short running as possible. Timers have unique names, and iterate on a defined number of seconds.

!!! warning
    Since all timers are run within the same runspace, it is wise to keep them as short running as possible. If you require a long-running task we recommend you use [Schedules](../Schedules) instead.

## Create a Timer

To create a new Timer in your server you use the Timer functions.

To create a basic Timer, the following example will work; this will loop every 5 seconds outputting the date/time:

```powershell
Add-PodeTimer -Name 'date' -Interval 5 -ScriptBlock {
    Write-Host "$([DateTime]::Now)"
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
