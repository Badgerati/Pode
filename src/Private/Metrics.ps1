function Update-PodeServerRequestMetrics {
    param(
        [Parameter()]
        [hashtable]
        $WebEvent
    )

    if ($null -eq $WebEvent) {
        return
    }

    # status code
    $status = "$($WebEvent.Response.StatusCode)"

    # metrics to update
    $metrics = @($PodeContext.Metrics.Requests)
    if ($null -ne $WebEvent.Route) {
        $metrics += $WebEvent.Route.Metrics.Requests
    }

    # increment the request metrics
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

function Update-PodeServerSignalMetrics {
    param(
        [Parameter()]
        [hashtable]
        $SignalEvent
    )

    if ($null -eq $SignalEvent) {
        return
    }

    # metrics to update
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