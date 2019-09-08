# Timers

A Timer in Pode is a short-running async task. All timers in Pode run in the same separate runspace along side your main server logic. Timers have unique names, and iterate on a defined number of seconds.

!!! warning
    Since all timers are run within the same runspace, it is wise to keep them as short-running as possible. If you require something long-running we recommend you use [Schedules](../Schedules).

## Create a Timer

To create a new Timer in your server you use the Timer functions.

To create a basic Timer, the following example will work; this will loop every 5 seconds outputting the date/time:

```powershell
Start-PodeServer {
    Add-PodeTimer -Name 'date' -Interval 5 -ScriptBlock {
        Write-Host "$([DateTime]::Now)"
    }
}
```

## Delayed Start

The `-Skip <int>` parameter will cause the Timer to skip its first initial triggers. For example, if you have a Timer run every 10 seconds, and you pass `-Skip 5`, then the timer will first run after 50 seconds (10secs * skip 5).

The following will create a Timer that runs every 10 seconds, and skips the first 5 iterations:

```powershell
Start-PodeServer {
    Add-PodeTimer -Name 'date' -Interval 10 -Skip 5 -ScriptBlock {
        Write-Host "$([DateTime]::Now)"
    }
}
```

## Run X Times

Normally a Timer will run forever, or at least until you terminate the server. Sometimes you might want a Timer to end early, or only run once. To do this you use the `-Limit <int>` parameter, which defines the number of times the Timer should execute.

The following will run every 20 seconds, and will only run 3 times:

```powershell
Start-PodeServer {
    Add-PodeTimer -Name 'date' -Interval 20 -Limit 3 -ScriptBlock {
        Write-Host "$([DateTime]::Now)"
    }
}
```
