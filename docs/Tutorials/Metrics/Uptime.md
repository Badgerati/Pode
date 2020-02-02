# Uptime and Restarts

Internally Pode keeps track of the uptime of the server, as well as the number of times the server has been restarted.

## Uptime

There are two uptime stats in Pode, and both will be returned to you in milliseconds:

1. The uptime for the server since the last restart
2. The total uptime of the server regardless of restarts

To get either, you can use the [`Get-PodeServerUptime`](../../../Functions/Metrics/Get-PodeServerUptime) function. For the total uptime, just supply the `-Total` switch:

```powershell
$current = Get-PodeServerUptime
$total = Get-PodeServerUptime -Total
```

## Restart Count

Pode keeps track of how many time your server restarts, you can get this count by using the [`Get-PodeServerRestartCount`](../../../Functions/Metrics/Get-PodeServerRestartCount) function:

```powershell
$count = Get-PodeServerRestartCount
```
