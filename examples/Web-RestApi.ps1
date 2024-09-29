<#
.SYNOPSIS
    A sample PowerShell script to set up a Pode server with HTTP endpoints and request logging.

.DESCRIPTION
    This script sets up a Pode server listening on port 8081 with various HTTP endpoints for GET and POST requests.
    It includes request logging with batching and dual mode for IPv4/IPv6.

.EXAMPLE
    To run the sample: ./Rest-Api.ps1

    Invoke-RestMethod -Uri http://localhost:8081/api/test -Method Get
    Invoke-RestMethod -Uri http://localhost:8081/api/test -Method Post
    Invoke-RestMethod -Uri http://localhost:8081/api/users/usertest -Method Get
    Invoke-RestMethod -Uri http://localhost:8081/api/users/usertest/message -Method Get

.LINK
    https://github.com/Badgerati/Pode/blob/develop/examples/Web-RestApi.ps1

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

# create a server, and start listening on port 8086
Start-PodeServer {

    Add-PodeEndpoint -Address localhost -Port 8081 -Protocol Http -DualMode

    # request logging
    New-PodeLoggingMethod -Terminal -Batch 10 -BatchTimeout 10 | Enable-PodeRequestLogging

    # can be hit by sending a GET request to "localhost:8086/api/test"
    Add-PodeRoute -Method Get -Path '/api/test' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ 'hello' = 'world'; }
    }

    # can be hit by sending a POST request to "localhost:8086/api/test"
    Add-PodeRoute -Method Post -Path '/api/test' -ContentType 'application/json' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ 'hello' = 'world'; 'name' = $WebEvent.Data['name']; }
    }

    # returns details for an example user
    Add-PodeRoute -Method Get -Path '/api/users/:userId' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ 'user' = $WebEvent.Parameters['userId']; }
    }

    # returns details for an example user
    Add-PodeRoute -Method Get -Path '/api/users/:userId/messages' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ 'user' = $WebEvent.Parameters['userId']; }
    }

}