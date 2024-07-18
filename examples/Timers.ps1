<#
.SYNOPSIS
    A PowerShell script to set up a Pode server with various timer configurations.

.DESCRIPTION
    This script sets up a Pode server that listens on a specified port and creates multiple timers with different behaviors.
    It includes routes to create new timers via HTTP requests and invoke existing timers on demand.

.EXAMPLE
    To run the sample: ./Timers.ps1

    Invoke-RestMethod -Uri http://localhost:8081/api/timer -Method Get
    Invoke-RestMethod -Uri http://localhost:8081/api/run -Method Get

.LINK
    https://github.com/Badgerati/Pode/blob/develop/examples/Timers.ps1

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
Start-PodeServer {

    Add-PodeEndpoint -Address localhost -Port 8081 -Protocol Http

    # runs forever, looping every 5secs
    $message = 'Hello, world'
    Add-PodeTimer -Name 'forever' -Interval 5 -ScriptBlock {
        param($msg1, $msg2)
        '- - -' | Out-PodeHost
        $using:message | Out-PodeHost
        Lock-PodeObject -ScriptBlock {
            "Look I'm locked!" | Out-PodeHost
        }
        "Last: $($TimerEvent.Sender.LastTriggerTime)" | Out-Default
        "Next: $($TimerEvent.Sender.NextTriggerTime)" | Out-Default
        "Message1: $($msg1)" | Out-Default
        "Message2: $($msg2)" | Out-Default
        '- - -' | Out-PodeHost
    } -Limit 5

    Add-PodeTimer -Name 'from-file' -Interval 2 -FilePath './scripts/timer.ps1'

    # runs forever, but skips the first 3 "loops" - is paused for 15secs then loops every 5secs
    Add-PodeTimer -Name 'pause-first-3' -Interval 5 -ScriptBlock {
        'Skip 3 then run' | Out-PodeHost
        Write-PodeHost $TimerEvent -Explode -ShowType
    } -Skip 3

    # runs every 5secs, but only runs for 3 "loops" (ie, 15secs)
    Add-PodeTimer -Name 'run-3-times' -Interval 5 -ScriptBlock {
        'Only run 3 times' | Out-PodeHost
        Get-PodeTimer -Name 'run-3-times' | Out-Default
        Write-PodeHost $TimerEvent -Explode -ShowType
    } -Limit 3

    # skip the first 2 loops, then run for 15 loops
    Add-PodeTimer -Name 'pause-then-limit' -Interval 5 -ScriptBlock {
        # logic
    } -Skip 2 -Limit 15

    # run once after 2mins
    Add-PodeTimer -Name 'run-once' -Interval 20 -ScriptBlock {
        'Ran once' | Out-PodeHost
        Write-PodeHost $TimerEvent -Explode -ShowType
    } -Skip 1 -Limit 1

    # create a new timer via a route
    Add-PodeRoute -Method Get -Path '/api/timer' -ScriptBlock {
        $query = $WebEvent.Query

        Add-PodeTimer -Name $query['Name'] -Interval $query['Seconds'] -ScriptBlock {
            # logic
        }
    }

    # adhoc invoke a timer's logic
    Add-PodeRoute -Method Get -Path '/api/run' -ScriptBlock {
        Invoke-PodeTimer -Name 'forever' -ArgumentList 'Hello!', 'Bye!'
    }

    Use-PodeTimers

}
