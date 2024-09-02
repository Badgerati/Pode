<#
.SYNOPSIS
    A sample PowerShell script to set up a basic Pode server.

.DESCRIPTION
    This script sets up a Pode server using a server definition from an external script file. The server listens on port 8081, logs errors to the terminal, uses the Pode view engine, and includes a timer and a route for HTTP GET requests.

.EXAMPLE
    To run the sample: ./ServerFrom-File.ps1

.LINK
    https://github.com/Badgerati/Pode/blob/develop/examples/ServerFrom-File.ps1

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
Start-PodeServer -FilePath "$ScriptPath/scripts/server.ps1" -CurrentPath