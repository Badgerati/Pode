<#
.SYNOPSIS
    A sample PowerShell script to set up a Pode server with interval-based service handlers.

.DESCRIPTION
    This script sets up a Pode server that runs with a specified interval, adding service handlers
    that execute at each interval. The handlers include logging messages to the terminal and using
    lock mechanisms.

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

# create a server, and start looping
Start-PodeServer -Interval 3 {

    Add-PodeHandler -Type Service -Name 'Hello' -ScriptBlock {
        Write-PodeHost 'hello, world!'
        Lock-PodeObject -ScriptBlock {
            "Look I'm locked!" | Out-PodeHost
        }
    }

    Add-PodeHandler -Type Service -Name 'Bye' -ScriptBlock {
        Write-PodeHost 'goodbye!'
    }

}
