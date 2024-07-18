<#
.SYNOPSIS
    A sample PowerShell script to set up a Pode server with error logging and a route to handle gzip'd JSON.

.DESCRIPTION
    This script sets up a Pode server listening on port 8081. It includes error logging and a route to handle POST requests that receive gzip'd JSON data.

.EXAMPLE
    To run the sample: ./Web-GzipRequest.ps1

    Invoke-RestMethod -Uri http://localhost:8081/users -Method Post

.LINK
    https://github.com/Badgerati/Pode/blob/develop/examples/Web-GzipRequest.ps1

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

# create a server, and start listening on port 8081
Start-PodeServer -Threads 2 {

    # listen on localhost:8081
    Add-PodeEndpoint -Address localhost -Port 8081 -Protocol Http

    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging

    # GET request that receives gzip'd json
    Add-PodeRoute -Method Post -Path '/users' -ScriptBlock {
        Write-PodeJsonResponse -Value $WebEvent.Data
    }

}