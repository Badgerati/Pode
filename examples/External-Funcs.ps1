<#
.SYNOPSIS
    A sample PowerShell script to set up a Pode server and use an external module function.

.DESCRIPTION
    This script sets up a Pode server listening on port 8081, imports an external module containing functions,
    and includes a route that uses a function from the external module to generate a response.

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
    } else {
        Import-Module -Name 'Pode' -MaximumVersion 2.99 -ErrorAction Stop
    }
} catch { throw }

# or just:
# Import-Module Pode

# include the external function module
Import-PodeModule -Path './modules/External-Funcs.psm1'

# create a server, and start listening on port 8081
Start-PodeServer {

    # listen on localhost:8085
    Add-PodeEndpoint -Address localhost -Port 8081 -Protocol Http

    # GET request for "localhost:8085/"
    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ 'result' = (Get-Greeting) }
    }

}