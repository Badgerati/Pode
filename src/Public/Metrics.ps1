<#
.SYNOPSIS
Returns the uptime of the server in milliseconds.

.DESCRIPTION
Returns the uptime of the server in milliseconds. You can optionally return the total uptime regardless of server restarts.

.PARAMETER Total
If supplied, the total uptime of the server will be returned, regardless of restarts.

.EXAMPLE
$currentUptime = Get-PodeServerUptime

.EXAMPLE
$totalUptime = Get-PodeServerUptime -Total
#>
function Get-PodeServerUptime
{
    [CmdletBinding()]
    param(
        [switch]
        $Total
    )

    $time = $PodeContext.Metrics.Server.StartTime
    if ($Total) {
        $time = $PodeContext.Metrics.Server.IntialLoadTime
    }

    return [long]([datetime]::UtcNow - $time).TotalMilliseconds
}

<#
.SYNOPSIS
Returns the number of times the server has restarted.

.DESCRIPTION
Returns the number of times the server has restarted.

.EXAMPLE
$restarts = Get-PodeServerRestartCount
#>
function Get-PodeServerRestartCount
{
    [CmdletBinding()]
    param()

    return $PodeContext.Metrics.Server.RestartCount
}