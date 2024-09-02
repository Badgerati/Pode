<#
.SYNOPSIS
    A sample PowerShell script to set up a Pode server with various scheduled tasks.

.DESCRIPTION
    This script sets up a Pode server listening on port 8081 with multiple schedules configured.
    It demonstrates scheduling using predefined cron expressions, schedules from files,
    multiple cron expressions, and scheduling at specific times.
    Additionally, it includes a route to invoke a schedule's logic ad-hoc with arguments.

.EXAMPLE
    To run the sample: ./Schedules.ps1

    Invoke-RestMethod -Uri http://localhost:8081/api/run -Method Get

.LINK
    https://github.com/Badgerati/Pode/blob/develop/examples/Schedules.ps1

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

    # schedule minutely using predefined cron
    $message = 'Hello, world!'
    Add-PodeSchedule -Name 'predefined' -Cron '@minutely' -Limit 2 -ScriptBlock {
        param($TriggeredEvent, $Message1, $Message2)
        $using:message | Out-Default
        Get-PodeSchedule -Name 'predefined' | Out-Default
        "Last: $($TriggeredEvent.Sender.LastTriggerTime)" | Out-Default
        "Next: $($TriggeredEvent.Sender.NextTriggerTime)" | Out-Default
        "Message1: $($Message1)" | Out-Default
        "Message2: $($Message2)" | Out-Default
    }

    Add-PodeSchedule -Name 'from-file' -Cron '@minutely' -FilePath './scripts/schedule.ps1'

    # schedule defined using two cron expressions
    Add-PodeSchedule -Name 'two-crons' -Cron @('0/3 * * * *', '0/5 * * * *') -ScriptBlock {
        'double cron' | Out-Default
        Get-PodeSchedule -Name 'two-crons' | Out-Default
    }

    # schedule to run every tuesday at midnight
    Add-PodeSchedule -Name 'tuesdays' -Cron '0 0 * * TUE' -ScriptBlock {
        # logic
    }

    # schedule to run every 5 past the hour, starting in 2hrs
    Add-PodeSchedule -Name 'hourly-start' -Cron '5,7,9 * * * *' -ScriptBlock {
        # logic
    } -StartTime ([DateTime]::Now.AddHours(2))

    # schedule to run every 10 minutes, and end in 2hrs
    Add-PodeSchedule -Name 'every-10mins-end' -Cron '0/10 * * * *' -ScriptBlock {
        # logic
    } -EndTime ([DateTime]::Now.AddHours(2))

    # adhoc invoke a schedule's logic
    Add-PodeRoute -Method Get -Path '/api/run' -ScriptBlock {
        Invoke-PodeSchedule -Name 'predefined' -ArgumentList @{
            Message1 = 'Hello!'
            Message2 = 'Bye!'
        }
    }

}