<#
.SYNOPSIS
    A sample PowerShell script to set up a Pode server with a view engine and file monitoring.

.DESCRIPTION
    This script sets up a Pode server listening on port 8081, uses Pode's view engine for rendering
    web pages, and configures the server to monitor file changes and restart automatically.

.EXAMPLE
    To run the sample: ./File-Monitoring.ps1

    Invoke-RestMethod -Uri http://localhost:8081 -Method Get

.LINK
    https://github.com/Badgerati/Pode/blob/develop/examples/File-Monitoring.ps1

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

# create a server listening on port 8081, set to monitor file changes and restart the server
Start-PodeServer {

    Add-PodeEndpoint -Address localhost -Port 8081 -Protocol Http
    Set-PodeViewEngine -Type Pode

    # GET request for web page on "localhost:8081/"
    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        Write-PodeViewResponse -Path 'simple' -Data @{ 'numbers' = @(1, 2, 3); }
    }

}
