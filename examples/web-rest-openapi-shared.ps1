$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop
#Import-Module -Name powershell-yaml -Force -ErrorAction Stop

Start-PodeServer {
    Add-PodeEndpoint -Address localhost -Port 8080 -Protocol Http -Name 'user'
    Add-PodeEndpoint -Address localhost -Port 8081 -Protocol Http -Name 'admin'

    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging

    Enable-PodeOpenApi -Title 'OpenAPI Example' -RouteFilter '/api/*' -RestrictRoutes  
    Enable-PodeOpenApiViewer -Type Swagger    
    Enable-PodeOpenApiViewer -Type ReDoc   
    Enable-PodeOpenApiViewer -Type RapiDoc    
    Enable-PodeOpenApiViewer -Type StopLight  
    Enable-PodeOpenApiViewer -Type Explorer  
    Enable-PodeOpenApiViewer -Type RapiPdf    

    Enable-PodeOpenApiViewer -Type Bookmarks -Path '/docs' 


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