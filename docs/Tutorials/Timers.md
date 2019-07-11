# Timers

A timer in Pode is a short-running async task. All timers in Pode run in the same separate runspace along side your main server logic. Timers have unique names, and iterate on a defined number of seconds.

!!! warning
    Since all timers are run within the same runspace, it is wise to keep them as short-running as possible. If you require something long-running we recommend you use [`Schedules`](../Schedules) instead.

## Create a Timer

To create a new timer in your server you use the [`timer`](../../Functions/Core/Timer) function. The make-up of the function is as follows:

```powershell
timer <name> <interval> <scriptblock> [-skip <int>] [-limit <int>]

# or with aliases:
timer <name> <interval> <scriptblock> [-s <int>] [-l <int>]
```

Each timer must have a `<name>`, an `<interval>`, and a `<scriptblock>` for the main logic. The `<interval>` must be a positive number of seconds, and the `<name>` must be unique across all timers.

To create a basic `timer`, the following example will work; this will loop every 5 seconds outputting the date/time:

```powershell
Start-PodeServer {
    timer 'date' 5 {
        Write-Host "$([DateTime]::Now)"
    }
}
```

## Delayed Start

The `-skip <int>` parameter will cause the `timer` to skip its first initial triggers. For example, if you have a timer run every 10 seconds, and you pass `-skip 5`, then the timer will first run after 50 seconds (10secs * skip 5).

The following will create a `timer` that runs every 10 seconds, and skips the first 5 iterations:

```powershell
Start-PodeServer {
    timer 'date' 10 -skip 5 {
        Write-Host "$([DateTime]::Now)"
    }
}
```

!!! note
    When a `timer` is created, the logic will run once and then be placed onto the separate runspace. To avoid the timer running the first time on the main runspace you can pass `-skip 1`.

## Run X Times

Normally a `timer` will run forever, or at least until you terminate the server. Sometimes you might want a `timer` to end early, or only run once. To do this you use the `-limit <int>` parameter, which defines the number of times the `timer` should execute.

The following will run every 20 seconds, and will only run 3 times:

```powershell
Start-PodeServer {
    timer 'date' 20 -limit 3 {
        Write-Host "$([DateTime]::Now)"
    }
}
```
