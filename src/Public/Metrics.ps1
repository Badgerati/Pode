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
        $time = $PodeContext.Metrics.Server.InitialLoadTime
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

<#
.SYNOPSIS
Returns the total number of requests/per status code the Server has receieved.

.DESCRIPTION
Returns the total number of requests/per status code the Server has receieved.

.PARAMETER StatusCode
If supplied, will return the total number of requests for a specific StatusCode.

.PARAMETER Total
If supplied, will return the Total number of Requests.

.EXAMPLE
$totalReqs = Get-PodeServerRequestMetric -Total

.EXAMPLE
$statusReqs = Get-PodeServerRequestMetric

.EXAMPLE
$404Reqs = Get-PodeServerRequestMetric -StatusCode 404
#>
function Get-PodeServerRequestMetric
{
    [CmdletBinding(DefaultParameterSetName='StatusCode')]
    param(
        [Parameter(ParameterSetName='StatusCode')]
        [int]
        $StatusCode = 0,

        [Parameter(ParameterSetName='Total')]
        [switch]
        $Total
    )

    if ($Total) {
        return $PodeContext.Metrics.Requests.Total
    }

    if (($StatusCode -le 0)) {
        return $PodeContext.Metrics.Requests.StatusCodes
    }

    $strCode = "$($StatusCode)"
    if (!$PodeContext.Metrics.Requests.StatusCodes.ContainsKey($strCode)) {
        return 0
    }

    return $PodeContext.Metrics.Requests.StatusCodes[$strCode]
}