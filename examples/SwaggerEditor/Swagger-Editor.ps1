<#
.SYNOPSIS
    Sets up a Pode server to serve the Swagger editor and static files.

.DESCRIPTION
    This script configures a Pode server to listen on a specified port (default is 8081) and serve the Swagger editor
    and other static files. It enables request and error logging and sets up a view engine for rendering HTML.

.PARAMETER Port
    The port number on which the Pode server will listen. Default is 8081.

.NOTES
    Author: Pode Team
    License: MIT License
#>
param(
    [int]
    $Port = 8081
)

try {
    $ScriptPath = (Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path))
    $podePath = Split-Path -Parent -Path $ScriptPath
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
    Add-PodeEndpoint -Address localhost -Port $port -Protocol Http
    New-PodeLoggingMethod -Terminal | Enable-PodeRequestLogging
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging

    # set view engine to pode renderer
    Set-PodeViewEngine -Type HTML

    # STATIC asset folder route
    Add-PodeStaticRoute -Path '/editor/swagger-editor-dist' -Source "$($path)/src/Misc/swagger-editor-dist" -FileBrowser
    Add-PodeStaticRoute -Path '/editor' -Source './www' -Defaults @('index.html') -FileBrowser
    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        Move-PodeResponseUrl -Url '/editor/index.html'
    }
}