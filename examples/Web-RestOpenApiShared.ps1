<#
.SYNOPSIS
    A sample PowerShell script to set up a Pode server with OpenAPI integration and basic authentication.

.DESCRIPTION
    This script sets up a Pode server listening on multiple endpoints with OpenAPI documentation.
    It demonstrates how to handle GET and POST requests, use OpenAPI for documenting APIs, and implement basic authentication.
    The script includes routes under the '/api' path and provides various OpenAPI viewers such as Swagger, ReDoc, RapiDoc, StopLight, Explorer, and RapiPdf.

.EXAMPLE
    To run the sample: ./Web-RestOpenApiShared.ps1

    OpenAPI Info:
    Specification:
        . http://localhost:8080/openapi
        . http://localhost:8081/openapi
    Documentation:
        . http://localhost:8080/bookmarks
        . http://localhost:8081/bookmarks

.LINK
    https://github.com/Badgerati/Pode/blob/develop/examples/Web-RestOpenApiShared.ps1

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

    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging

    Enable-PodeOpenApi  -DisableMinimalDefinitions

    Add-PodeOAInfo  -Title 'OpenAPI Example'

    Enable-PodeOAViewer -Type Swagger
    Enable-PodeOAViewer -Type ReDoc
    Enable-PodeOAViewer -Type RapiDoc
    Enable-PodeOAViewer -Type StopLight
    Enable-PodeOAViewer -Type Explorer
    Enable-PodeOAViewer -Type RapiPdf


    Enable-PodeOAViewer -Editor
    Enable-PodeOAViewer -Bookmarks


    New-PodeAuthScheme -Basic | Add-PodeAuth -Name 'Validate' -Sessionless -ScriptBlock {
        param($username, $password)

        # here you'd check a real user storage, this is just for example
        if ($username -eq 'morty' -and $password -eq 'pickle') {
            return @{
                User = @{
                    ID   = 'M0R7Y302'
                    Name = 'Morty'
                    Type = 'Human'
                }
            }
        }

        return @{ Message = 'Invalid details supplied' }
    }


    Add-PodeOAComponentResponse -Name 'OK' -Description 'A user object' -ContentSchemas @{
        'application/json' = (New-PodeOAObjectProperty -Properties @(
            (New-PodeOAStringProperty -Name 'Name'),
            (New-PodeOAIntProperty -Name 'UserId')
            ))
    }

    New-PodeOAIntProperty -Name 'userId' -Required |
    ConvertTo-PodeOAParameter -In Path |
    Add-PodeOAComponentParameter -Name 'UserId'

    Add-PodeAuthMiddleware -Name AuthMiddleware -Authentication Validate -Route '/api/*'

    Add-PodeRoute -Method Get -Path '/api/resources' -EndpointName 'user' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ Name = 'Rick'; UserId = 123 }
    } -PassThru |
    Set-PodeOARouteInfo -Summary 'A cool summary' -Tags 'Resources' -PassThru |
    Add-PodeOAResponse -StatusCode 200 -Reference 'OK'


    Add-PodeRoute -Method Post -Path '/api/resources' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ Name = 'Rick'; UserId = 123 }
    } -PassThru |
    Set-PodeOARouteInfo -Summary 'A cool summary' -Tags 'Resources' -PassThru |
    Add-PodeOAResponse -StatusCode 200 -Reference 'OK'


    Add-PodeRoute -Method Get -Path '/api/users/:userId' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ Name = 'Rick'; UserId = $WebEvent.Parameters['userId'] }
    } -PassThru |
    Set-PodeOARouteInfo -Summary 'A cool summary' -Tags 'Users' -PassThru |
    Set-PodeOARequest -Parameters @(
            (ConvertTo-PodeOAParameter -Reference 'UserId')
    ) -PassThru |
    Add-PodeOAResponse -StatusCode 200 -Reference 'OK'


    Add-PodeRoute -Method Get -Path '/api/users' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ Name = 'Rick'; UserId = $WebEvent.Query['userId'] }
    } -PassThru |
    Set-PodeOARouteInfo -Summary 'A cool summary' -Tags 'Users' -PassThru |
    Set-PodeOARequest -Parameters @(
            (New-PodeOAIntProperty -Name 'userId' -Required | ConvertTo-PodeOAParameter -In Query)
    ) -PassThru |
    Add-PodeOAResponse -StatusCode 200 -Reference 'OK'


    Add-PodeRoute -Method Post -Path '/api/users' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ Name = 'Rick'; UserId = $WebEvent.Data.userId }
    } -PassThru |
    Set-PodeOARouteInfo -Summary 'A cool summary' -Tags 'Users' -PassThru |
    Set-PodeOARequest -RequestBody (
        New-PodeOARequestBody -Required -ContentSchemas @{
            'application/json' = (New-PodeOAIntProperty -Name 'userId' -Object)
        }
    ) -PassThru |
    Add-PodeOAResponse -StatusCode 200 -Reference 'OK'

}