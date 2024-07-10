<#
.SYNOPSIS
    A simple PowerShell script to set up a Pode server and log a message.

.DESCRIPTION
    This script sets up a Pode server, enables terminal logging for errors, and writes a "hello, world!" message to the terminal.
    The server runs the logic once and then exits.

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

# runs the logic once, then exits
Start-PodeServer {

    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging
    Write-PodeHost 'hello, world!'

}
