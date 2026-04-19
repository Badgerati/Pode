<#
.SYNOPSIS
    Retrieves the server uptime in milliseconds or a human-readable format.

.DESCRIPTION
    The `Get-PodeServerUptime` function calculates the server's uptime since its last start or total uptime since initial load, depending on the `-Total` switch.
    By default, the uptime is returned in milliseconds. When the `-Format` parameter is used, the uptime can be returned in various human-readable styles:
    - `Milliseconds` (default): Raw uptime in milliseconds.
    - `Concise`: A short format like "1d 2h 3m".
    - `Compact`: A condensed format like "01:10:17:36".
    - `Verbose`: A detailed format like "1 day, 2 hours, 3 minutes, 5 seconds, 200 milliseconds".
    The `-ExcludeMilliseconds` switch allows removal of milliseconds from human-readable output.

.PARAMETER Total
    Retrieves the total server uptime since the initial load, regardless of any restarts.

.PARAMETER Format
    Specifies the desired output format for the uptime.
    Allowed values:
    - `Milliseconds` (default): Uptime in raw milliseconds.
    - `Concise`: Human-readable in a short form (e.g., "1d 2h 3m").
    - `Compact`: Condensed form (e.g., "01:10:17:36").
    - `Verbose`: Detailed format (e.g., "1 day, 2 hours, 3 minutes, 5 seconds").

.PARAMETER ExcludeMilliseconds
    Omits milliseconds from the human-readable output when `-Format` is not `Milliseconds`.

.EXAMPLE
    $currentUptime = Get-PodeServerUptime
    # Output: 123456789 (milliseconds)

.EXAMPLE
    $totalUptime = Get-PodeServerUptime -Total
    # Output: 987654321 (milliseconds)

.EXAMPLE
    $readableUptime = Get-PodeServerUptime -Format Concise
    # Output: "1d 10h 17m"

.EXAMPLE
    $verboseUptime = Get-PodeServerUptime -Format Verbose
    # Output: "1 day, 10 hours, 17 minutes, 36 seconds, 789 milliseconds"

.EXAMPLE
    $compactUptime = Get-PodeServerUptime -Format Compact
    # Output: "01:10:17:36"

.EXAMPLE
    $compactUptimeNoMs = Get-PodeServerUptime -Format Compact -ExcludeMilliseconds
    # Output: "01:10:17:36"

.NOTES
    This function is part of Pode's utility metrics to monitor server uptime.
#>
function Get-PodeServerUptime {
    [CmdletBinding()]
    [OutputType([long], [string])]
    param(
        [switch]
        $Total,

        [Parameter()]
        [ValidateSet('Milliseconds', 'Concise', 'Compact', 'Verbose')]
        [string]
        $Format = 'Milliseconds',

        [switch]
        $ExcludeMilliseconds
    )

    # Determine the start time based on the -Total switch
    # Default: Uses the last start time; -Total: Uses the initial load time
    $time = $PodeContext.Metrics.Server.StartTime
    if ($Total) {
        $time = $PodeContext.Metrics.Server.InitialLoadTime
    }

    # Calculate uptime in milliseconds
    $uptimeMilliseconds = [long]([datetime]::UtcNow - $time).TotalMilliseconds

    # Return uptime in milliseconds if no readable format is requested
    if ($Format -ieq 'Milliseconds') {
        return $uptimeMilliseconds
    }

    # Convert uptime to a human-readable format
    return Convert-PodeMillisecondsToReadable -Milliseconds $uptimeMilliseconds -Format $Format -ExcludeMilliseconds:$ExcludeMilliseconds
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
Returns the total number of requests/per status code the Server has received.

.DESCRIPTION
Returns the total number of requests/per status code the Server has received.

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
    [OutputType([long])]
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
        return 0L
    }

    return $PodeContext.Metrics.Requests.StatusCodes[$strCode]
}

<#
.SYNOPSIS
Returns the total number of Signal requests the Server has received.

.DESCRIPTION
Returns the total number of Signal requests the Server has received.

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
    [OutputType([long])]
    param(
        [Parameter()]
        [ValidateSet('Total', 'Queued', 'Processing')]
        [string]
        $CountType = 'Total'
    )

    switch ($CountType.ToLowerInvariant()) {
        'total' {
            return $PodeContext.Server.Http.Listener.Contexts.Count
        }

        'queued' {
            return $PodeContext.Server.Http.Listener.Contexts.QueuedCount
        }

        'processing' {
            return $PodeContext.Server.Http.Listener.Contexts.ProcessingCount
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
    [OutputType([long])]
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
                    return $PodeContext.Server.Http.Listener.Signals.ProcessingCount + $PodeContext.Server.Http.Listener.ClientSignals.Count
                }

                'queued' {
                    return $PodeContext.Server.Http.Listener.ClientSignals.QueuedCount
                }

                'processing' {
                    return $PodeContext.Server.Http.Listener.Signals.ProcessingCount + $PodeContext.Server.Http.Listener.ClientSignals.ProcessingCount
                }
            }
        }

        'server' {
            switch ($CountType.ToLowerInvariant()) {
                'total' {
                    return $PodeContext.Server.Http.Listener.Signals.ProcessingCount
                }

                'queued' {
                    return 0l
                }

                'processing' {
                    return $PodeContext.Server.Http.Listener.Signals.ProcessingCount
                }
            }
        }

        'client' {
            switch ($CountType.ToLowerInvariant()) {
                'total' {
                    return $PodeContext.Server.Http.Listener.ClientSignals.Count
                }

                'queued' {
                    return $PodeContext.Server.Http.Listener.ClientSignals.QueuedCount
                }

                'processing' {
                    return $PodeContext.Server.Http.Listener.ClientSignals.ProcessingCount
                }
            }
        }
    }
}

<#
.SYNOPSIS
Returns the count of active Signal clients.

.DESCRIPTION
Returns the count of all, or for a specific Name, active Signal clients.

.PARAMETER Name
If supplied, will return the count of active Signal clients for the specific Name.

.EXAMPLE
$count = Get-PodeServerActiveSignalClientMetric

.EXAMPLE
$count = Get-PodeServerActiveSignalClientMetric -Name 'Events'
#>
function Get-PodeServerActiveSignalClientMetric {
    [CmdletBinding()]
    [OutputType([long])]
    param(
        [Parameter()]
        [string]
        $Name
    )

    if (![string]::IsNullOrEmpty($Name)) {
        if (!(Test-PodeSignalName -Name $Name)) {
            # Signal connection not found
            throw ($PodeLocale.signalConnectionNameNotFoundExceptionMessage -f $Name)
        }

        return $PodeContext.Server.Http.Listener.Signals.Count($Name)
    }

    return $PodeContext.Server.Http.Listener.Signals.TotalCount
}

<#
.SYNOPSIS
Returns the count of active SSE messages.

.DESCRIPTION
Returns the count of all processing SSE messages.

.EXAMPLE
$count = Get-PodeServerActiveSseMetric
#>
function Get-PodeServerActiveSseMetric {
    [CmdletBinding()]
    [OutputType([long])]
    param()

    return $PodeContext.Server.Http.Listener.ServerEvents.ProcessingCount
}

<#
.SYNOPSIS
Returns the count of active SSE clients.

.DESCRIPTION
Returns the count of all, or for a specific Name, active SSE clients.

.PARAMETER Name
If supplied, will return the count of active SSE clients for the specific Name.

.EXAMPLE
$count = Get-PodeServerActiveSseClientMetric

.EXAMPLE
$count = Get-PodeServerActiveSseClientMetric -Name 'Events'
#>
function Get-PodeServerActiveSseClientMetric {
    [CmdletBinding()]
    [OutputType([long])]
    param(
        [Parameter()]
        [string]
        $Name
    )

    if (![string]::IsNullOrEmpty($Name)) {
        if (!(Test-PodeSseName -Name $Name)) {
            # SSE connection not found
            throw ($PodeLocale.sseConnectionNameNotFoundExceptionMessage -f $Name)
        }

        return $PodeContext.Server.Http.Listener.ServerEvents.Count($Name)
    }

    return $PodeContext.Server.Http.Listener.ServerEvents.TotalCount
}