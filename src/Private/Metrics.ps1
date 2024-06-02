<#
.SYNOPSIS
    Updates server request metrics based on the provided web event.

.DESCRIPTION
    The `Update-PodeServerRequestMetric` function increments relevant metrics associated with server requests.
    It takes a web event (represented as a hashtable) and updates the appropriate metrics.

.PARAMETER WebEvent
    Specifies the web event to process. This parameter is optional.

.INPUTS
    None. You cannot pipe objects to Update-PodeServerRequestMetric.

.OUTPUTS
    None. The function modifies the state of metrics in the PodeContext.

.EXAMPLE
    # Example usage:
    $webEvent = @{
        Response = @{
            StatusCode = 200
        }
        Route = @{
            Metrics = @{
                Requests = $routeMetrics
            }
        }
    }

    Update-PodeServerRequestMetric -WebEvent $webEvent
    # Metrics associated with the web event are updated.

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function Update-PodeServerRequestMetric {
    param(
        [Parameter()]
        [hashtable]
        $WebEvent
    )

    if ($null -eq $WebEvent) {
        return
    }

    # Extract the status code from the web event
    $status = "$($WebEvent.Response.StatusCode)"

    # Determine which metrics to update
    $metrics = @($PodeContext.Metrics.Requests)
    if ($null -ne $WebEvent.Route) {
        $metrics += $WebEvent.Route.Metrics.Requests
    }

    # Increment the request metrics and status code counts
    foreach ($metric in $metrics) {
        Lock-PodeObject -Object $metric -ScriptBlock {
            $metric.Total++

            if (!$metric.StatusCodes.ContainsKey($status)) {
                $metric.StatusCodes[$status] = 0
            }

            $metric.StatusCodes[$status]++
        }
    }
}

<#
.SYNOPSIS
    Updates server signal metrics based on the provided signal event.

.DESCRIPTION
    The `Update-PodeServerSignalMetric` function increments relevant metrics associated with server signals.
    It takes a signal event (represented as a hashtable) and updates the appropriate metrics.

.PARAMETER SignalEvent
    Specifies the signal event to process. This parameter is optional.

.INPUTS
    None. You cannot pipe objects to Update-PodeServerSignalMetric.

.OUTPUTS
    None. The function modifies the state of metrics in the PodeContext.

.EXAMPLE
    # Example usage:
    $signalEvent = @{
        Route = @{
            Metrics = @{
                Requests = $routeMetrics
            }
        }
    }

    Update-PodeServerSignalMetric -SignalEvent $signalEvent
    # Metrics associated with the signal event are updated.

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function Update-PodeServerSignalMetric {
    param(
        [Parameter()]
        [hashtable]
        $SignalEvent
    )

    if ($null -eq $SignalEvent) {
        return
    }

     # Determine which metrics to update
    $metrics = @($PodeContext.Metrics.Signals)
    if ($null -ne $SignalEvent.Route) {
        $metrics += $SignalEvent.Route.Metrics.Requests
    }

    # increment the request metrics
    foreach ($metric in $metrics) {
        Lock-PodeObject -Object $metric -ScriptBlock {
            $metric.Total++
        }
    }
}