<#
.SYNOPSIS
    A sample PowerShell script to set up a Pode server with OpenAPI integration.

.DESCRIPTION
    This script sets up a Pode server listening on multiple endpoints with OpenAPI documentation.
    It demonstrates how to handle GET and POST requests, and how to use OpenAPI for documenting APIs.
    The script includes routes under the '/api' path and provides Swagger and ReDoc viewers.

.EXAMPLE
    To run the sample: ./Web-RestOpenApiSimple.ps1

    OpenAPI Info:
    Specification:
        . http://localhost:8080/openapi
        . http://localhost:8081/openapi
    Documentation:
        . http://localhost:8080/bookmarks
        . http://localhost:8081/bookmarks

.LINK
    https://github.com/Badgerati/Pode/blob/develop/examples/Web-RestOpenApiSimple.ps1

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
    Add-PodeEndpoint -Address localhost -Port 8080 -Protocol Http -Name 'user'
    Add-PodeEndpoint -Address localhost -Port 8081 -Protocol Http -Name 'admin'

    Enable-PodeOpenApi -DisableMinimalDefinitions

    Add-PodeOAInfo  -Title 'OpenAPI Example'

    Enable-PodeOAViewer -Type Swagger -DarkMode
    Enable-PodeOAViewer -Type ReDoc
    Enable-PodeOAViewer -Bookmarks -Path '/docs'

    Add-PodeRoute -Method Get -Path '/api/resources' -EndpointName 'user' -ScriptBlock {
        Set-PodeResponseStatus -Code 200
    }


    Add-PodeRoute -Method Post -Path '/api/resources' -ScriptBlock {
        Set-PodeResponseStatus -Code 200
    }


    Add-PodeRoute -Method Get -Path '/api/users/:userId' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ Name = 'Rick'; UserId = $WebEvent.Parameters['userId'] }
    } -PassThru | Set-PodeOARouteInfo -PassThru |
        Set-PodeOARequest -Parameters @(
            (New-PodeOAIntProperty -Name 'userId' -Enum @(100, 300, 999) -Required | ConvertTo-PodeOAParameter -In Path)
        )


    Add-PodeRoute -Method Get -Path '/api/users' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ Name = 'Rick'; UserId = $WebEvent.Query['userId'] }
    } -PassThru | Set-PodeOARouteInfo -PassThru |
        Set-PodeOARequest -Parameters @(
            (New-PodeOAIntProperty -Name 'userId' -Required | ConvertTo-PodeOAParameter -In Query)
        )


    Add-PodeRoute -Method Post -Path '/api/users' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ Name = $WebEvent.Data.Name; UserId = $WebEvent.Data.UserId }
    } -PassThru | Set-PodeOARouteInfo -PassThru |
        Set-PodeOARequest -RequestBody (
            New-PodeOARequestBody -Required -ContentSchemas @{
                'application/json' = (New-PodeOAObjectProperty -Properties @(
                    (New-PodeOAStringProperty -Name 'Name' -MaxLength 5 -Pattern '[a-zA-Z]+'),
                    (New-PodeOAIntProperty -Name 'UserId')
                    ))
            }
        )
}
