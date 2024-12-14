<#
.SYNOPSIS
    Returns the uptime of the server in milliseconds or in a human-readable format.

.DESCRIPTION
    Returns the uptime of the server in milliseconds by default. You can optionally return the total uptime regardless of server restarts or convert the uptime to a human-readable format with selectable output styles (e.g., Verbose, Compact).
    Additionally, milliseconds can be excluded from the output if desired.

.PARAMETER Total
    If supplied, the total uptime of the server will be returned, regardless of restarts.

.PARAMETER Readable
    If supplied, the uptime will be returned in a human-readable format instead of milliseconds.

.PARAMETER OutputType
    Specifies the format for the human-readable output. Valid options are:
    - 'Verbose' for detailed descriptions (e.g., "1 day, 2 hours, 3 minutes").
    - 'Compact' for a compact format (e.g., "dd:hh:mm:ss").
    - Default is concise format (e.g., "1d 2h 3m").

.PARAMETER ExcludeMilliseconds
    If supplied, milliseconds will be excluded from the human-readable output.

.EXAMPLE
    $currentUptime = Get-PodeServerUptime
    # Output: 123456789 (milliseconds)

.EXAMPLE
    $totalUptime = Get-PodeServerUptime -Total
    # Output: 987654321 (milliseconds)

.EXAMPLE
    $readableUptime = Get-PodeServerUptime -Readable
    # Output: "1d 10h 17m 36s"

.EXAMPLE
    $verboseUptime = Get-PodeServerUptime -Readable -OutputType Verbose
    # Output: "1 day, 10 hours, 17 minutes, 36 seconds, 789 milliseconds"

.EXAMPLE
    $compactUptime = Get-PodeServerUptime -Readable -OutputType Compact
    # Output: "01:10:17:36"

.EXAMPLE
    $compactUptimeNoMs = Get-PodeServerUptime -Readable -OutputType Compact -ExcludeMilliseconds
    # Output: "01:10:17:36"
#>
function Get-PodeServerUptime {
    [CmdletBinding(DefaultParameterSetName = 'Milliseconds')]
    [OutputType([long], [string])]
    param(
        # Common to all parameter sets
        [switch]
        $Total,

        # Default set: Milliseconds output
        [Parameter(ParameterSetName = 'Readable')]
        [switch]
        $Readable,

        # Available only when -Readable is specified
        [Parameter(ParameterSetName = 'Readable')]
        [ValidateSet("Verbose", "Compact", "Default")]
        [string]
        $OutputType = "Default",

        # Available only when -Readable is specified
        [Parameter(ParameterSetName = 'Readable')]
        [switch]
        $ExcludeMilliseconds
    )

    # Determine the appropriate start time
    $time = $PodeContext.Metrics.Server.StartTime
    if ($Total) {
        $time = $PodeContext.Metrics.Server.InitialLoadTime
    }

    # Calculate uptime in milliseconds
    $uptimeMilliseconds = [long]([datetime]::UtcNow - $time).TotalMilliseconds

    # Handle readable output
    if ($PSCmdlet.ParameterSetName -eq 'Readable') {
        switch ($OutputType) {
            "Verbose" {
                return Convert-PodeMillisecondsToReadable -Milliseconds $uptimeMilliseconds -VerboseOutput -ExcludeMilliseconds:$ExcludeMilliseconds
            }
            "Compact" {
                return Convert-PodeMillisecondsToReadable -Milliseconds $uptimeMilliseconds -CompactOutput -ExcludeMilliseconds:$ExcludeMilliseconds
            }
            "Default" {
                return Convert-PodeMillisecondsToReadable -Milliseconds $uptimeMilliseconds -ExcludeMilliseconds:$ExcludeMilliseconds
            }
        }
    }

    # Default to milliseconds if no readable output is requested
    return $uptimeMilliseconds
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