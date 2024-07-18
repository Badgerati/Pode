<#
.SYNOPSIS
    A sample PowerShell script to set up a Pode server with HTTP endpoints and a scheduled task.

.DESCRIPTION
    This script sets up a Pode server listening on port 8081 with a scheduled task that runs every 2 minutes.
    It includes an endpoint for GET requests.

.EXAMPLE
    To run the sample: ./Schedules-CronHelper.ps1

    Invoke-RestMethod -Uri http://localhost:8081 -Method Get

.LINK
    https://github.com/Badgerati/Pode/blob/develop/examples/Schedules-CronHelper.ps1

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

Start-PodeServer {

    Add-PodeEndpoint -Address localhost -Port 8081 -Protocol Http

    $cron = New-PodeCron -Every Minute -Interval 2
    Add-PodeSchedule -Name 'example' -Cron $cron -ScriptBlock {
        'Hi there!' | Out-Default
    }

    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ Result = 1 }
    }

}