<#
.SYNOPSIS
    A PowerShell script to set up a basic Pode server with timer functionality.

.DESCRIPTION
    This script sets up a Pode server that listens on a specified port and allows the creation of timers via HTTP routes.
    It includes a route to create a new timer that runs a specified script block at defined intervals.

.EXAMPLE
    To run the sample: ./Timers-Route.ps1

    Invoke-RestMethod -Uri http://localhost:8081/api/timer -Method Get

.LINK
    https://github.com/Badgerati/Pode/blob/develop/examples/Timers-Route.ps1

.PARAMETER Port
    The port number on which the Pode server will listen. Default is 8081.

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
Start-PodeServer -EnablePool Timers {

    Add-PodeEndpoint -Address localhost -Port 8081 -Protocol Http

    # create a new timer via a route
    Add-PodeRoute -Method Get -Path '/api/timer' -ScriptBlock {
        Add-PodeTimer -Name 'example' -Interval 5 -ScriptBlock {
            'hello there' | out-default
        }
    }

}
