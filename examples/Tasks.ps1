<#
.SYNOPSIS
    A sample PowerShell script to set up a Pode server with task management and logging.

.DESCRIPTION
    This script sets up a Pode server that listens on port 8081, logs errors to the terminal, and handles both synchronous and asynchronous tasks. The server provides routes to interact with the tasks and demonstrates task invocation and waiting.

.EXAMPLE
    To run the sample: ./Tasks.ps1

    Invoke-RestMethod -Uri http://localhost:8081/api/task/sync -Method Get
    Invoke-RestMethod -Uri http://localhost:8081/api/task/sync2 -Method Get
    Invoke-RestMethod -Uri http://localhost:8081/api/task/async -Method Get

.LINK
    https://github.com/Badgerati/Pode/blob/develop/examples/Tasks.ps1

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

# create a basic server
Start-PodeServer {

    Add-PodeEndpoint -Address localhost -Port 8081 -Protocol Http
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging

    Add-PodeTask -Name 'Test1' -ScriptBlock {
        'a string'
        4
        return @{ InnerValue = 'hey look, a value!' }
    }

    Add-PodeTask -Name 'Test2' -ScriptBlock {
        param($value)
        Start-Sleep -Seconds 10
        "a $($value) is never late, it arrives exactly when it means to" | Out-Default
    }

    Add-PodeTask -Name 'Intermittent' -MaxRetries 3 -AutoRetry -ScriptBlock {
        if ($TaskEvent.Count -lt 2) {
            throw "this task is intermittent (attempt $($TaskEvent.Count))"
        }

        'task completed' | Out-Default
    }

    # create a new timer via a route
    Add-PodeRoute -Method Get -Path '/api/task/sync' -ScriptBlock {
        $result = Invoke-PodeTask -Name 'Test1' -Wait
        Write-PodeJsonResponse -Value @{ Result = $result }
    }

    Add-PodeRoute -Method Get -Path '/api/task/sync2' -ScriptBlock {
        $task = Invoke-PodeTask -Name 'Test1'
        $result = ($task | Wait-PodeTask)
        Write-PodeJsonResponse -Value @{ Result = $result }
    }

    Add-PodeRoute -Method Get -Path '/api/task/async' -ScriptBlock {
        Invoke-PodeTask -Name 'Test2' -ArgumentList @{ value = 'wizard' } | Out-Null
        Write-PodeJsonResponse -Value @{ Result = 'jobs done' }
    }

    Add-PodeRoute -Method Get -Path '/api/task/intermittent' -ScriptBlock {
        Invoke-PodeTask -Name 'Intermittent'
    }
}
