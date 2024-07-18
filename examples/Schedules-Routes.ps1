<#
.SYNOPSIS
    A sample PowerShell script to set up a Pode server with dynamic schedule creation.

.DESCRIPTION
    This script sets up a Pode server listening on port 8081 with the ability to create new schedules dynamically via an API route.
    The server is configured with schedule pooling enabled, and includes an endpoint to create a new schedule that runs every minute.

.EXAMPLE
    To run the sample: ./Schedules-Routes.ps1

    Invoke-RestMethod -Uri http://localhost:8081/api/schedule -Method Get

.LINK
    https://github.com/Badgerati/Pode/blob/develop/examples/Schedules-Routes.ps1

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
Start-PodeServer -EnablePool Schedules {

    # listen on localhost:8081
    Add-PodeEndpoint -Address localhost -Port 8081 -Protocol Http

    # create a new schdule via a route
    Add-PodeRoute -Method Get -Path '/api/schedule' -ScriptBlock {
        Add-PodeSchedule -Name 'example' -Cron '@minutely' -ScriptBlock {
            'hello there' | out-default
        }
    }

}
