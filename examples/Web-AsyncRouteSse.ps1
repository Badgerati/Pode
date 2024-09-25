<#
.SYNOPSIS
    A script that either runs a Pode server with asynchronous SSE endpoints or sends multiple REST requests to the server.

.DESCRIPTION
    This script demonstrates how to set up a Pode server with endpoints that include asynchronous operations and
    Server-Sent Events (SSE). It provides examples of handling asynchronous requests and sending REST calls to
    interact with the server's SSE-based routes.

    The Html pages used by the sample are:
    - /AsyncRoutes/index.html
    - /AsyncRoutes/sse_test.html

.EXAMPLE
    .\Web-AsyncRouteSse.ps1

    Starts the Pode server with asynchronous routes and SSE events enabled.

.EXAMPLE
    Open a web browser that supports the SSE protocol (e.g., Google Chrome) and navigate to
    http://localhost:8081/ to see the SSE demo in action.

.LINK
    https://github.com/Badgerati/Pode/blob/develop/examples/Web-AsyncRouteSse.ps1

.NOTES
    Author: Pode Team
    License: MIT License
#>

try {
    # Determine the script path and Pode module path
    $ScriptPath = (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
    $podePath = Split-Path -Parent -Path $ScriptPath

    # Import the Pode module from the source path if it exists, otherwise from installed modules
    if (Test-Path -Path "$($podePath)/src/Pode.psm1" -PathType Leaf) {
        Import-Module "$($podePath)/src/Pode.psm1" -Force -ErrorAction Stop
    }
    else {
        Import-Module -Name 'Pode' -MaximumVersion 2.99 -ErrorAction Stop
    }
}
catch { throw }

# or just:
# Import-Module Pode


Start-PodeServer -Threads 6 {

    Add-PodeEndpoint -Address localhost -Port 8081 -Protocol Http -DualMode
    New-PodeLoggingMethod -name 'asyncSse' -File  -Path "$ScriptPath/logs" | Enable-PodeErrorLogging

    Add-PodeRoute  -PassThru -Method Get -Path '/sse' -ScriptBlock {
        Set-PodeAsyncRouteProgress -IntervalSeconds 2 -DurationSeconds 23 -MaxProgress 100
        $msg = "Start - Hello there! The datetime is: $([datetime]::Now.TimeOfDay)"
        Send-PodeSseEvent -Data $msg -FromEvent
        for ($i = 0; $i -lt 10; $i++) {
            Start-Sleep -Seconds 1
        }
        $msg = "InTheMiddle - Hello there! The datetime is: $([datetime]::Now.TimeOfDay)"
        Send-PodeSseEvent -Data $msg  -FromEvent

        for ($i = 0; $i -lt 10; $i++) {
            Start-Sleep -Seconds 1
        }
        $msg = "End - Hello there! The datetime is: $([datetime]::Now.TimeOfDay)"
        Send-PodeSseEvent   -Data $msg  -FromEvent

        return @{'message' = 'Done' }
    } | Set-PodeAsyncRoute -ResponseContentType 'application/json'  -MaxRunspaces 4  -PassThru |
        Add-PodeAsyncRouteSse -SseGroup 'Test events' -SendResult

    Add-PodeStaticRoute -Path '/' -File "$ScriptPath/AsyncRoute"

}