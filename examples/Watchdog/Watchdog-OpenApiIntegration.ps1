<#
.SYNOPSIS
    A Pode server setup with OpenAPI integration that monitors a script using the Pode Watchdog service.

.DESCRIPTION
    This script initializes a Pode server with OpenAPI documentation and multiple routes to monitor the status, listeners, requests,
    and signals of a monitored process via the Pode Watchdog service.
    It also provides commands to control the state of the monitored process, such as restart, stop, reset, and halt.
    The script dynamically loads the Pode module and configures OpenAPI viewers and an editor for documentation.
    This sample demonstrates the integration of Pode Watchdog with OpenAPI routes for monitoring and controlling processes.

.EXAMPLE
    Run the script to start a Pode server on localhost at port 8082 with OpenAPI documentation:

        ./Watchdog-OpenApiIntegration.ps1

.LINK
    https://github.com/Badgerati/Pode/blob/develop/examples/Watchdog/Watchdog-OpenApiIntegration.ps1

.NOTES
    Author: Pode Team
    License: MIT License
#>

try {
    # Determine paths for the Pode module
    $watchdogPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Path
    $podePath = Split-Path -Parent -Path (Split-Path -Parent -Path $watchdogPath)

    # Import the Pode module from the source path if it exists, otherwise from installed modules
    if (Test-Path -Path "$($podePath)/src/Pode.psm1" -PathType Leaf) {
        Import-Module "$($podePath)/src/Pode.psm1" -Force -ErrorAction Stop
    }
    else {
        Import-Module -Name 'Pode' -MaximumVersion 2.99 -ErrorAction Stop
    }
}
catch { throw }

Start-PodeServer -Threads 2 {
    # Define a simple HTTP endpoint on localhost:8082
    Add-PodeEndpoint -Address localhost -Port 8082 -Protocol Http

    # Enable OpenAPI with OpenAPI version 3.0.3 and disable minimal definitions
    Enable-PodeOpenApi -Path '/docs/openapi' -OpenApiVersion '3.0.3' -DisableMinimalDefinitions
    Add-PodeOAInfo -Title 'Pode Watchdog sample' -Version 1.0.0

    # Enable various OpenAPI viewers for documentation
    Enable-PodeOAViewer -Type Swagger -Path '/docs/swagger'
    Enable-PodeOAViewer -Type ReDoc -Path '/docs/redoc'
    Enable-PodeOAViewer -Type RapiDoc -Path '/docs/rapidoc'
    Enable-PodeOAViewer -Type StopLight -Path '/docs/stoplight'
    Enable-PodeOAViewer -Type Explorer -Path '/docs/explorer'
    Enable-PodeOAViewer -Type RapiPdf -Path '/docs/rapipdf'

    # Enable OpenAPI editor and bookmarks for easier documentation navigation
    Enable-PodeOAViewer -Editor -Path '/docs/swagger-editor'
    Enable-PodeOAViewer -Bookmarks -Path '/docs'

    # Path to the monitored script
    $filePath = "$($watchdogPath)/monitored.ps1"
    
    # Set up logging for the Watchdog service
    New-PodeLoggingMethod -File -Name 'watchdog' -MaxDays 4 | Enable-PodeErrorLogging

    # Enable the Pode Watchdog to monitor the script file, excluding .log files
    Enable-PodeWatchdog -FilePath $filePath -Parameters @{Port = 8081 } -FileMonitoring -FileExclude '*.log' -Name 'watch01' -RestartServiceAfter 10 -MaxNumberOfRestarts 2 -ResetFailCountAfter 3

     # Define OpenAPI schemas for request, listener, signal, and status metrics
    $WatchdogSchemaPrefix = 'Watchdog'
    Add-PodeWatchdogOASchema -WatchdogSchemaPrefix $WatchdogSchemaPrefix

    # REST API to retrieve the list of listeners
    Add-PodeRoute -PassThru -Method Get -Path '/monitor/listeners' -ScriptBlock {
        Write-PodeJsonResponse -StatusCode 200 -Value (Get-PodeWatchdogProcessMetric -Name 'watch01' -type Listeners)
    } | Set-PodeOARouteInfo -Summary 'Retrieves a list of active listeners for the monitored Pode server' -Tags 'Monitor' -OperationId 'getListeners' -PassThru |
        Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -Content @{'application/json' = "$($WatchdogSchemaPrefix)Listeners" }

    # REST API to retrieve the request count
    Add-PodeRoute -PassThru -Method Get -Path '/monitor/requests' -ScriptBlock {
        Write-PodeJsonResponse -StatusCode 200 -Value (Get-PodeWatchdogProcessMetric -Name 'watch01' -type Requests)
    } | Set-PodeOARouteInfo -Summary 'Retrieves the total number of requests handled by the monitored Pode server' -Tags 'Monitor' -OperationId 'getRequests' -PassThru |
        Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -Content @{'application/json' = "$($WatchdogSchemaPrefix)Requests" }

    # REST API to retrieve the process status
    Add-PodeRoute -PassThru -Method Get -Path '/monitor/status' -ScriptBlock {
        Write-PodeJsonResponse -StatusCode 200 -Value (Get-PodeWatchdogProcessMetric -Name 'watch01' -type Status)
    } | Set-PodeOARouteInfo -Summary 'Retrieves the current status and uptime of the monitored Pode server' -Tags 'Monitor' -OperationId 'getStatus' -PassThru |
        Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -Content @{'application/json' = "$($WatchdogSchemaPrefix)Status" }

    # REST API to retrieve signal metrics
    Add-PodeRoute -PassThru -Method Get -Path '/monitor/signals' -ScriptBlock {
        Write-PodeJsonResponse -StatusCode 200 -Value (Get-PodeWatchdogProcessMetric -Name 'watch01' -type Signals)
    } | Set-PodeOARouteInfo -Summary 'Retrieves signal metrics for the monitored Pode server' -Tags 'Monitor' -OperationId 'getSignals' -PassThru |
        Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -Content @{'application/json' = "$($WatchdogSchemaPrefix)Signals" }

    # REST API to retrieve all metrics of the monitored process
    Add-PodeRoute -PassThru -Method Get -Path '/monitor' -ScriptBlock {
        Write-PodeJsonResponse -StatusCode 200 -Value (Get-PodeWatchdogProcessMetric -Name 'watch01')
    } | Set-PodeOARouteInfo -Summary 'Retrieves all monitoring stats for the monitored Pode server' -Tags 'Monitor' -OperationId 'getMonitor' -PassThru |
        Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -Content @{'application/json' = "$($WatchdogSchemaPrefix)Monitor" }

    # REST API to restart the monitored process
    Add-PodeRoute -PassThru -Method Post -Path '/cmd/restart' -ScriptBlock {
        Write-PodeJsonResponse -StatusCode 200 -Value @{ success = (Set-PodeWatchdogProcessState -Name 'watch01' -State Restart) }
    } | Set-PodeOARouteInfo -Summary 'Restarts the monitored Pode server' -Tags 'Command' -OperationId 'restart'

    # REST API to reset the monitored process
    Add-PodeRoute -PassThru -Method Post -Path '/cmd/reset' -ScriptBlock {
        Write-PodeJsonResponse -StatusCode 200 -Value @{ success = (Set-PodeWatchdogProcessState -Name 'watch01' -State Reset) }
    } | Set-PodeOARouteInfo -Summary 'Stops and restarts the monitored Pode server process' -Tags 'Command' -OperationId 'reset'

    # REST API to stop the monitored process
    Add-PodeRoute -PassThru -Method Post -Path '/cmd/stop' -ScriptBlock {
        Write-PodeJsonResponse -StatusCode 200 -Value @{ success = (Set-PodeWatchdogProcessState -Name 'watch01' -State Stop) }
    } | Set-PodeOARouteInfo -Summary 'Stops the monitored Pode server process' -Tags 'Command' -OperationId 'stop'

    # REST API to start the monitored process
    Add-PodeRoute -PassThru -Method Post -Path '/cmd/start' -ScriptBlock {
        Write-PodeJsonResponse -StatusCode 200 -Value @{ success = (Set-PodeWatchdogProcessState -Name 'watch01' -State Start) }
    } | Set-PodeOARouteInfo -Summary 'Starts the monitored Pode server process' -Tags 'Command' -OperationId 'start'

    # REST API to terminate (force stop) the monitored process
    Add-PodeRoute -PassThru -Method Post -Path '/cmd/terminate' -ScriptBlock {
        Write-PodeJsonResponse -StatusCode 200 -Value @{ success = (Set-PodeWatchdogProcessState -Name 'watch01' -State Terminate) }
    } | Set-PodeOARouteInfo -Summary 'Terminates (force stops) the monitored Pode server process' -Tags 'Command' -OperationId 'terminate'

    # REST API to disable the monitored process
    Add-PodeRoute -PassThru -Method Post -Path '/cmd/disable' -ScriptBlock {
        Write-PodeJsonResponse -StatusCode 200 -Value @{ success = (Set-PodeWatchdogProcessState -Name 'watch01' -State Disable) }
    } | Set-PodeOARouteInfo -Summary 'Disables the monitored Pode server process' -Tags 'Command' -OperationId 'disable'

    # REST API to enable the monitored process
    Add-PodeRoute -PassThru -Method Post -Path '/cmd/enable' -ScriptBlock {
        Write-PodeJsonResponse -StatusCode 200 -Value @{ success = (Set-PodeWatchdogProcessState -Name 'watch01' -State Enable) }
    } | Set-PodeOARouteInfo -Summary 'Enables the monitored Pode server process' -Tags 'Command' -OperationId 'enable'

    # REST API to disable Auto Restart
    Add-PodeRoute -PassThru -Method Post -Path '/settings/noAutoRestart' -ScriptBlock {
        Disable-PodeWatchdogAutoRestart -Name 'watch01'
        Set-PodeResponseStatus -Code 200
    } | Set-PodeOARouteInfo -Summary 'Disables the auto-restart feature for the monitored Pode server process' -Tags 'Settings' -OperationId 'noAutoRestart'

    # REST API to enable Auto Restart
    Add-PodeRoute -PassThru -Method Post -Path '/settings/autoRestart' -ScriptBlock {
        Enable-PodeWatchdogAutoRestart -Name 'watch01'
        Set-PodeResponseStatus -Code 200
    } | Set-PodeOARouteInfo -Summary 'Enables the auto-restart feature for the monitored Pode server process' -Tags 'Settings' -OperationId 'autoRestart'

}
