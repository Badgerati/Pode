<#
.SYNOPSIS
    A sample PowerShell script to set up a Pode server and run a script from an external file.

.DESCRIPTION
    This script sets up a Pode server, enables terminal logging for errors, and uses an external
    script for additional logic. It imports the Pode module from the source path if available,
    otherwise from the installed modules.

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
    Use-PodeScript -Path './modules/Script1.ps1'

}
