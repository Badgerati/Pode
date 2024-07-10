<#
.SYNOPSIS
    A sample PowerShell script to set up a Pode server with multiple scheduled tasks.

.DESCRIPTION
    This script sets up a Pode server listening on port 8081 with multiple scheduled tasks. Each task runs every minute
    and sleeps for a random duration between 5 and 40 seconds. The maximum concurrency for schedules is set to 30.

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

    # add lots of schedules that each sleep for a while
    1..30 | ForEach-Object {
        Add-PodeSchedule -Name "Schedule_$($_)" -Cron '@minutely' -ArgumentList @{ ID = $_ } -ScriptBlock {
            param($ID)

            $seconds = (Get-Random -Minimum 5 -Maximum 40)
            Start-Sleep -Seconds $seconds
            "ID: $($ID) [$($seconds)]" | Out-PodeHost
        }
    }

    Set-PodeScheduleConcurrency -Maximum 30

}