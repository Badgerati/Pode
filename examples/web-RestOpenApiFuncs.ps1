<#
.SYNOPSIS
    A sample PowerShell script to set up a Pode server with OpenAPI integration and various OpenAPI viewers.

.DESCRIPTION
    This script sets up a Pode server listening on port 8081 with OpenAPI documentation.
    It demonstrates how to use OpenAPI for documenting APIs and provides various OpenAPI viewers such as Swagger, ReDoc, RapiDoc, StopLight, Explorer, and RapiPdf.

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

Start-PodeServer {
    Add-PodeEndpoint -Address localhost -Port 8081 -Protocol Http

    Enable-PodeOpenApi -Title 'OpenAPI Example' -RouteFilter '/api/*' -RestrictRoutes
    Enable-PodeOpenApiViewer -Type Swagger -Path '/docs/swagger'
    Enable-PodeOpenApiViewer -Type ReDoc  -Path '/docs/redoc'
    Enable-PodeOpenApiViewer -Type RapiDoc  -Path '/docs/rapidoc'
    Enable-PodeOpenApiViewer -Type StopLight  -Path '/docs/stoplight'
    Enable-PodeOpenApiViewer -Type Explorer  -Path '/docs/explorer'
    Enable-PodeOpenApiViewer -Type RapiPdf  -Path '/docs/rapipdf'

    Enable-PodeOpenApiViewer -Bookmarks -Path '/docs'

    #ConvertTo-PodeRoute -Path '/api' -Commands @('Get-ChildItem', 'New-Item')
    ConvertTo-PodeRoute -Path '/api' -Module Pester
}