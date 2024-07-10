<#
.SYNOPSIS
    A sample PowerShell script to set up a Pode server with logging and task scheduling.

.DESCRIPTION
    This script sets up a Pode server listening on port 8081, enables terminal logging for requests and errors,
    and includes a scheduled task. The server has two routes: one for a simple JSON response and another to
    invoke a task that demonstrates delayed execution.

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
Start-PodeServer {

    # listen on localhost:8081
    Add-PodeEndpoint -Address localhost -Port 8081 -Protocol Http
    New-PodeLoggingMethod -Terminal | Enable-PodeRequestLogging
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging

    Add-PodeTask -Name 'Test' -ScriptBlock {
        Start-Sleep -Seconds 10
        'a message is never late, it arrives exactly when it means to' | Out-Default
    }

    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ Message = 'Hello' }
        $WebEvent.Request | out-default
    }

    Add-PodeRoute -Method Get -Path '/run-task' -ScriptBlock {
        Invoke-PodeTask -Name 'Test' | Out-Null
        Write-PodeJsonResponse -Value @{ Result = 'jobs done' }
    }

}