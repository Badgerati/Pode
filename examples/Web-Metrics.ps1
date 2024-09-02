<#
.SYNOPSIS
    A sample PowerShell script to set up a Pode server with a route to check server uptime and restart count.

.DESCRIPTION
    This script sets up a Pode server listening on port 8081. It includes a route to check the server's uptime
    and the number of times the server has restarted.

.EXAMPLE
    To run the sample: ./Web-Metrics.ps1

    Invoke-RestMethod -Uri http://localhost:8081/uptime -Method Get

.LINK
    https://github.com/Badgerati/Pode/blob/develop/examples/Web-Metrics.ps1

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

Start-PodeServer -Threads 2 {

    Add-PodeEndpoint -Address localhost -Port 8081 -Protocol Http

    Add-PodeRoute -Method Get -Path '/uptime' -ScriptBlock {
        Write-PodeJsonResponse -Value @{
            Restarts = (Get-PodeServerRestartCount)
            Uptime = @{
                Session = (Get-PodeServerUptime)
                Total = (Get-PodeServerUptime -Total)
            }
        }
    }

}