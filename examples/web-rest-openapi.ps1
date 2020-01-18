$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

Start-PodeServer {
    Add-PodeEndpoint -Address localhost -Port 8080 -Protocol Http -Name 'user'
    Add-PodeEndpoint -Address localhost -Port 8081 -Protocol Http -Name 'admin'

    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging

    Enable-PodeOpenApiRoute -Title 'OpenAPI Example' -Filter '/api/' -RestrictRoutes
    Enable-PodeSwaggerRoute -DarkMode


    New-PodeAuthType -Basic | Add-PodeAuth -Name 'Validate' -ScriptBlock {
        return @{
            User = @{
                ID ='M0R7Y302'
                Name = 'Morty'
                Type = 'Human'
            }
        }
    }


    $auth = (Get-PodeAuthMiddleware -Name 'Validate' -Sessionless)

    Add-PodeRoute -Method Get -Path "/api/resources" -Middleware $auth -EndpointName 'user' -ScriptBlock {
        Set-PodeResponseStatus -Code 200
    } -PassThru |
        Set-PodeOpenApiRouteMetaData -Summary 'A cool summary' -Tags 'Resources' -PassThru |
        Set-PodeOpenApiRouteAuth -Name 'Validate' -PassThru |
        Add-PodeOpenApiRouteResponse -StatusCode 200 -PassThru |
        Add-PodeOpenApiRouteResponse -StatusCode 404


    Add-PodeRoute -Method Post -Path "/api/resources" -ScriptBlock {
        Set-PodeResponseStatus -Code 200
    } -PassThru |
        Set-PodeOpenApiRouteMetaData -Summary 'A cool summary' -Tags 'Resources' -PassThru |
        Add-PodeOpenApiRouteResponse -StatusCode 200 -PassThru |
        Add-PodeOpenApiRouteResponse -StatusCode 404


    Add-PodeRoute -Method Get -Path '/api/users/:userId' -ScriptBlock {
        param($e)
        Write-PodeJsonResponse -Value @{ Name = 'Rick'; UserId = $e.Parameters['userId'] }
    } -PassThru |
        Set-PodeOpenApiRouteMetaData -Summary 'A cool summary' -Tags 'Users' -PassThru |
        Set-PodeOpenApiRouteRequest -Parameters @(
            New-PodeOpenApiRouteRequestParameter -Integer -Name 'userId' -In Path -Required
        ) -PassThru |
        Add-PodeOpenApiRouteResponse -StatusCode 200 -Description 'A list of users' -Schemas @(
            New-PodeOpenApiSchema -Object -ContentType 'application/json' -Properties @(
                New-PodeOpenApiSchemaProperty -Name 'Name' -String
                New-PodeOpenApiSchemaProperty -Name 'UserId' -Integer
            )
        )


    Add-PodeRoute -Method Get -Path '/api/users' -ScriptBlock {
        param($e)
        Write-PodeJsonResponse -Value @{ Name = 'Rick'; UserId = $e.Query['userId'] }
    } -PassThru |
        Set-PodeOpenApiRouteMetaData -Summary 'A cool summary' -Tags 'Users' -PassThru |
        Set-PodeOpenApiRouteRequest -Parameters @(
            New-PodeOpenApiRouteRequestParameter -Integer -Name 'userId' -In Query -Required
        ) -PassThru |
        Add-PodeOpenApiRouteResponse -StatusCode 200 -Description 'A list of users'


    Add-PodeRoute -Method Post -Path '/api/users' -Middleware $auth -ScriptBlock {
        param($e)
        Write-PodeJsonResponse -Value @{ Name = 'Rick'; UserId = $e.Data.userId }
    } -PassThru |
        Set-PodeOpenApiRouteMetaData -Summary 'A cool summary' -Tags 'Users' -PassThru |
        Set-PodeOpenApiRouteAuth -Name 'Validate' -PassThru |
        Set-PodeOpenApiRouteRequest -RequestBody (
            New-PodeOpenApiRouteRequestBody -Required -Schemas @(
                New-PodeOpenApiSchema -Object -ContentType 'application/json' -Properties @(
                    New-PodeOpenApiSchemaProperty -Name 'userId' -Integer -Required
                )
            )
        ) -PassThru |
        Add-PodeOpenApiRouteResponse -StatusCode 200 -Description 'A list of users'
}