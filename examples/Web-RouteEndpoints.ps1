<#
.SYNOPSIS
    A sample PowerShell script to set up a Pode server with multiple endpoints and request handling.

.DESCRIPTION
    This script sets up a Pode server listening on multiple local IP addresses on port 8081.
    It demonstrates how to handle GET requests for a web page, download a file, handle requests with parameters,
    and redirect requests from one endpoint to another.

.EXAMPLE
    To run the sample: ./Web-RouteEndpoints.ps1

    Invoke-RestMethod -Uri http://127.0.0.1:8081/ -Method Get
    Invoke-RestMethod -Uri http://127.0.0.1:8081/download -Method Get
    Invoke-RestMethod -Uri http://127.0.0.1:8081/testuser/details -Method Get
    Invoke-RestMethod -Uri http://127.0.0.2:8082/something -Method Patch

.LINK
    https://github.com/Badgerati/Pode/blob/develop/examples/Web-RouteEndpoints.ps1

.NOTES
    Author: Pode Team
    License: MIT License
    Administrator privilege required
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

#Administrator privilege required

# or just:
# Import-Module Pode

# create a server, and start listening on port 8081
Start-PodeServer {

    # listen on localhost:8081
    Add-PodeEndpoint -Address 127.0.0.1 -Port 8081 -Protocol Http -Name Endpoint1
    Add-PodeEndpoint -Address 127.0.0.2 -Port 8081 -Protocol Http -Name Endpoint2

    # set view engine to pode
    Set-PodeViewEngine -Type Pode

    # GET request for web page
    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        Write-PodeViewResponse -Path 'simple' -Data @{ 'numbers' = @(1, 2, 3); }
    }

    # GET request to download a file
    Add-PodeRoute -Method Get -Path '/download' -ScriptBlock {
        Set-PodeResponseAttachment -Path 'Anger.jpg'
    }

    # GET request with parameters
    Add-PodeRoute -Method Get -Path '/:userId/details' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ 'userId' = $WebEvent.Parameters['userId'] }
    }

    # ALL requests for 127.0.0.2 to 127.0.0.1
    Add-PodeRoute -Method * -Path * -EndpointName Endpoint2 -ScriptBlock {
        Move-PodeResponseUrl -Address 127.0.0.1
    }

}