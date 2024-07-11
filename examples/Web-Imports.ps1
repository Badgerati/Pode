<#
.SYNOPSIS
    A sample PowerShell script to set up a Pode server with various routes, access rules, logging, and request handling.

.DESCRIPTION
    This script sets up a Pode server listening on multiple endpoints with request redirection.
    It demonstrates how to handle GET, POST, and other HTTP requests, set up access and limit rules,
    implement custom logging, and serve web pages using Pode's view engine.

.PARAMETER Port
    The port number on which the server will listen. Default is 8081.

.NOTES
    Author: Pode Team
    License: MIT License
#>
param(
    [int]
    $Port = 8081
)

try {
    $ScriptPath = (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
    $podePath = Split-Path -Parent -Path $ScriptPath
    if (Test-Path -Path "$($podePath)/src/Pode.psm1" -PathType Leaf) {
        Import-Module "$($podePath)/src/Pode.psm1" -Force -ErrorAction Stop
    }
    else {
        Import-Module -Name 'Pode' -MaximumVersion 2.99 -ErrorAction Stop
    }

    # import modules
    Import-Module -Name EPS -ErrorAction Stop
}
catch { throw }

# or just:
# Import-Module Pode



# create a server, and start listening on port 8081
Start-PodeServer -Threads 2 {

    # listen on localhost:8081
    Add-PodeEndpoint -Address localhost -Port $Port -Protocol Http

    # set view engine to pode renderer
    Set-PodeViewEngine -Type Pode

    # GET request for web page on "localhost:8081/"
    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        Get-Module | Out-Default
        Write-PodeViewResponse -Path 'simple' -Data @{ 'numbers' = @(1, 2, 3); }
    }

}