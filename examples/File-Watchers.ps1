<#
.SYNOPSIS
    A sample PowerShell script to set up a Pode server with file watcher and logging.

.DESCRIPTION
    This script sets up a Pode server, enables terminal logging for errors, and adds a file watcher
    to monitor changes in PowerShell script files (*.ps1) within the script directory. The server
    logs file change events and outputs them to the terminal.

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

Start-PodeServer -Verbose {

    # enable logging
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging

    Add-PodeFileWatcher -Path $ScriptPath -Include '*.ps1' -ScriptBlock {
        "[$($FileEvent.Type)][$($FileEvent.Parameters['project'])]: $($FileEvent.FullPath)" | Out-Default
    }
}