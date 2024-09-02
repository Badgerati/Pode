<#
.SYNOPSIS
    A sample PowerShell script to set up a Pode server with Kestrel and various endpoints.

.DESCRIPTION
    This script sets up a Pode server listening on multiple endpoints using Kestrel.
    It demonstrates how to handle GET requests, serve static assets, and download files using Pode's view engine.

.PARAMETER Port
    The port number on which the server will listen. Default is 8081.

.EXAMPLE
    To run the sample: ./Web-HostnameKestrel.ps1

    Invoke-RestMethod -Uri http://pode3.foo.com:8081/ -Method Get
    Invoke-RestMethod -Uri http://pode3.foo.com:8081/download -Method Get

.LINK
    https://github.com/Badgerati/Pode/blob/develop/examples/Web-HostnameKestrel.ps1

.NOTES
    Author: Pode Team
    License: MIT License
    Administrator privilege is required
    You will need to add "127.0.0.1 pode.foo.com" to your hosts file.
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

# Administrator privilege  is required

# or just:
# Import-Module Pode

# you will require the Pode.Kestrel module for this example
Import-Module Pode.Kestrel

# create a server, and start listening on port 8081 at pode.foo.com
# -- You will need to add "127.0.0.1  pode.foo.com" to your hosts file
Start-PodeServer -Threads 2 -ListenerType Kestrel {

    # listen on localhost:8081
    Add-PodeEndpoint -Address pode3.foo.com -Port $Port -Protocol Http
    Add-PodeEndpoint -Address pode2.foo.com -Port $Port -Protocol Http
    Add-PodeEndpoint -Address localhost -Hostname pode.foo.com -Port $Port -Protocol Http
    Add-PodeEndpoint -Hostname pode4.foo.com -Port $Port -Protocol Http -LookupHostname

    # logging
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging

    # set view engine to pode renderer
    Set-PodeViewEngine -Type Pode

    # STATIC asset folder route
    Add-PodeStaticRoute -Path '/assets' -Source './assets' -Defaults @('index.html')

    # GET request for web page on "localhost:8081/"
    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        Write-PodeViewResponse -Path 'web-static' -Data @{ 'numbers' = @(1, 2, 3); }
    }

    # GET request to download a file from static route
    Add-PodeRoute -Method Get -Path '/download' -ScriptBlock {
        Set-PodeResponseAttachment -Path '/assets/images/Fry.png'
    }

}