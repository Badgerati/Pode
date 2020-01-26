$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

Start-PodeServer {
    Add-PodeEndpoint -Address localhost -Port 8080 -Protocol Http -Name 'user'
    Add-PodeEndpoint -Address localhost -Port 8081 -Protocol Http -Name 'admin'

    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging

    Enable-PodeOpenApi -Title 'OpenAPI Example' -RouteFilter '/api/*' -RestrictRoutes
    Enable-PodeSwagger -DarkMode


    New-PodeAuthType -Basic | Add-PodeAuth -Name 'Validate' -ScriptBlock {
        return @{
            User = @{
                ID ='M0R7Y302'
                Name = 'Morty'
                Type = 'Human'
            }
        }
    }


    Add-PodeOAComponentResponse -Name 'OK' -Description 'A user object' -ContentSchemas @{
        'application/json' = (New-PodeOAObjectProperty -Properties @(
            (New-PodeOAStringProperty -Name 'Name'),
            (New-PodeOAIntProperty -Name 'UserId')
        ))
    }


    Get-PodeAuthMiddleware -Name 'Validate' -Sessionless | Add-PodeMiddleware -Name 'AuthMiddleware' -Route '/api/*'
    Set-PodeOAGlobalAuth -Name 'Validate'


    Add-PodeRoute -Method Get -Path "/api/resources" -EndpointName 'user' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ Name = 'Rick'; UserId = 123 }
    } -PassThru |
        Set-PodeOARouteInfo -Summary 'A cool summary' -Tags 'Resources' -PassThru |
        Add-PodeOAResponse -StatusCode 200 -Reference 'OK'


    Add-PodeRoute -Method Post -Path "/api/resources" -ScriptBlock {
        Write-PodeJsonResponse -Value @{ Name = 'Rick'; UserId = 123 }
    } -PassThru |
        Set-PodeOARouteInfo -Summary 'A cool summary' -Tags 'Resources' -PassThru |
        Add-PodeOAResponse -StatusCode 200 -Reference 'OK'


    Add-PodeRoute -Method Get -Path '/api/users/:userId' -ScriptBlock {
        param($e)
        Write-PodeJsonResponse -Value @{ Name = 'Rick'; UserId = $e.Parameters['userId'] }
    } -PassThru |
        Set-PodeOARouteInfo -Summary 'A cool summary' -Tags 'Users' -PassThru |
        Set-PodeOARequest -Parameters @(
            (New-PodeOAIntProperty -Name 'userId' -Required | ConvertTo-PodeOAParameter -In Path)
        ) -PassThru |
        Add-PodeOAResponse -StatusCode 200 -Reference 'OK'


    Add-PodeRoute -Method Get -Path '/api/users' -ScriptBlock {
        param($e)
        Write-PodeJsonResponse -Value @{ Name = 'Rick'; UserId = $e.Query['userId'] }
    } -PassThru |
        Set-PodeOARouteInfo -Summary 'A cool summary' -Tags 'Users' -PassThru |
        Set-PodeOARequest -Parameters @(
            (New-PodeOAIntProperty -Name 'userId' -Required | ConvertTo-PodeOAParameter -In Query)
        ) -PassThru |
        Add-PodeOAResponse -StatusCode 200 -Reference 'OK'


    Add-PodeRoute -Method Post -Path '/api/users' -ScriptBlock {
        param($e)
        Write-PodeJsonResponse -Value @{ Name = 'Rick'; UserId = $e.Data.userId }
    } -PassThru |
        Set-PodeOARouteInfo -Summary 'A cool summary' -Tags 'Users' -PassThru |
        Set-PodeOARequest -RequestBody (
            New-PodeOARequestBody -Required -ContentSchemas @{
                'application/json' = (New-PodeOAIntProperty -Name 'userId' -Object)
            }
        ) -PassThru |
        Add-PodeOAResponse -StatusCode 200 -Reference 'OK'
}