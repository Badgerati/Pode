<#
.SYNOPSIS
    A sample PowerShell script to set up a Pode server with multiple endpoints and request handling.

.DESCRIPTION
    This script sets up a Pode server listening on multiple endpoints with request redirection.
    It demonstrates how to handle GET requests and redirect requests from one endpoint to another.
    The script includes examples of using a parameter for the port number and setting up error logging.

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
Start-PodeServer -Threads 2 {

    # listen on localhost:8081
    Add-PodeEndpoint -Address localhost -Port 8090 -Protocol Http -Name '8090Address'
    Add-PodeEndpoint -Address localhost -Port $Port -Protocol Http -Name '8081Address' -RedirectTo '8090Address'

    # log errors to the terminal
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging

    # set view engine to pode renderer
    Set-PodeViewEngine -Type Pode

    # GET request for web page on "localhost:8081/"
    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        Write-PodeViewResponse -Path 'simple' -Data @{ 'numbers' = @(1, 2, 3); }
    }

}