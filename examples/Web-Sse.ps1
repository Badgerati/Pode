<#
.SYNOPSIS
    A sample PowerShell script to set up a Pode server with Server-Sent Events (SSE) and logging.

.DESCRIPTION
    This script sets up a Pode server that listens on port 8081, logs errors to the terminal, and handles Server-Sent Events (SSE) connections. The server sends periodic SSE events and provides routes to interact with SSE connections.

.EXAMPLE
    To run the sample: ./Web-Sse.ps1

    Invoke-RestMethod -Uri http://localhost:8081/data -Method Get
    Invoke-RestMethod -Uri http://localhost:8081/ -Method Get
    Invoke-RestMethod -Uri http://localhost:8081/sse -Method Get

.LINK
    https://github.com/Badgerati/Pode/blob/develop/examples/Web-Sse.ps1

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

# create a server, and start listening on port 8081
Start-PodeServer -Threads 3 {
    # listen on localhost:8081
    Add-PodeEndpoint -Address localhost -Port 8081 -Protocol Http

    # log errors
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging -Levels *

    # open local sse connection, and send back data
    Add-PodeRoute -Method Get -Path '/data' -ScriptBlock {
        ConvertTo-PodeSseConnection -Name 'Data' -Scope Local
        Send-PodeSseEvent -Id 1234 -EventType Action -Data 'hello, there!'
        Start-Sleep -Seconds 3
        Send-PodeSseEvent -Id 1337 -EventType BoldOne -Data 'general kenobi'
    }

    # home page to get sse events
    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        Write-PodeViewResponse -Path 'sse-home'
    }

    Add-PodeRoute -Method Get -Path '/sse' -ScriptBlock {
        ConvertTo-PodeSseConnection -Name 'Test'
    }

    Add-PodeTimer -Name 'SendEvent' -Interval 10 -ScriptBlock {
        Send-PodeSseEvent -Name 'Test' -Data "An Event! $(Get-Random -Minimum 1 -Maximum 100)"
    }
}