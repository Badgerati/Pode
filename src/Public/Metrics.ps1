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
function Get-PodeServerUptime {
    [CmdletBinding()]
    [OutputType([long])]
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
function Get-PodeServerRestartCount {
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
function Get-PodeServerRequestMetric {
    [CmdletBinding(DefaultParameterSetName = 'StatusCode')]
    [OutputType([int])]
    param(
        [Parameter(ParameterSetName = 'StatusCode')]
        [int]
        $StatusCode = 0,

        [Parameter(ParameterSetName = 'Total')]
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

<#
.SYNOPSIS
Returns the total number of Signal requests the Server has receieved.

.DESCRIPTION
Returns the total number of Signal requests the Server has receieved.

.EXAMPLE
$totalReqs = Get-PodeServerSignalMetric
#>
function Get-PodeServerSignalMetric {
    [CmdletBinding()]
    param()

    return $PodeContext.Metrics.Signals.Total
}

<#
.SYNOPSIS
Returns the count of active requests.

.DESCRIPTION
Returns the count of all, processing, or queued active requests.

.PARAMETER CountType
The count type to return. (Default: Total)

.EXAMPLE
Get-PodeServerActiveRequestMetric

.EXAMPLE
Get-PodeServerActiveRequestMetric -CountType Queued
#>
function Get-PodeServerActiveRequestMetric {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateSet('Total', 'Queued', 'Processing')]
        [string]
        $CountType = 'Total'
    )

    switch ($CountType.ToLowerInvariant()) {
        'total' {
            return $PodeContext.Server.Signals.Listener.Contexts.Count
        }

        'queued' {
            return $PodeContext.Server.Signals.Listener.Contexts.QueuedCount
        }

        'processing' {
            return $PodeContext.Server.Signals.Listener.Contexts.ProcessingCount
        }
    }
}

<#
.SYNOPSIS
Returns the count of active signals.

.DESCRIPTION
Returns the count of all, processing, or queued active signals; for either server or client signals.

.PARAMETER Type
The type of signal to return. (Default: Total)

.PARAMETER CountType
The count type to return. (Default: Total)

.EXAMPLE
Get-PodeServerActiveSignalMetric

.EXAMPLE
Get-PodeServerActiveSignalMetric -Type Client -CountType Queued
#>
function Get-PodeServerActiveSignalMetric {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateSet('Total', 'Server', 'Client')]
        [string]
        $Type = 'Total',

        [Parameter()]
        [ValidateSet('Total', 'Queued', 'Processing')]
        [string]
        $CountType = 'Total'
    )

    switch ($Type.ToLowerInvariant()) {
        'total' {
            switch ($CountType.ToLowerInvariant()) {
                'total' {
                    return $PodeContext.Server.Signals.Listener.ServerSignals.Count + $PodeContext.Server.Signals.Listener.ClientSignals.Count
                }

                'queued' {
                    return $PodeContext.Server.Signals.Listener.ServerSignals.QueuedCount + $PodeContext.Server.Signals.Listener.ClientSignals.QueuedCount
                }

                'processing' {
                    return $PodeContext.Server.Signals.Listener.ServerSignals.ProcessingCount + $PodeContext.Server.Signals.Listener.ClientSignals.ProcessingCount
                }
            }
        }

        'server' {
            switch ($CountType.ToLowerInvariant()) {
                'total' {
                    return $PodeContext.Server.Signals.Listener.ServerSignals.Count
                }

                'queued' {
                    return $PodeContext.Server.Signals.Listener.ServerSignals.QueuedCount
                }

                'processing' {
                    return $PodeContext.Server.Signals.Listener.ServerSignals.ProcessingCount
                }
            }
        }

        'client' {
            switch ($CountType.ToLowerInvariant()) {
                'total' {
                    return $PodeContext.Server.Signals.Listener.ClientSignals.Count
                }

                'queued' {
                    return $PodeContext.Server.Signals.Listener.ClientSignals.QueuedCount
                }

                'processing' {
                    return $PodeContext.Server.Signals.Listener.ClientSignals.ProcessingCount
                }
            }
        }
    }
}