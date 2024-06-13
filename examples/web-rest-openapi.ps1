try {
    $ScriptPath = (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
    $podePath = Split-Path -Parent -Path $ScriptPath
    if (Test-Path -Path "$($podePath)/src/Pode.psm1" -PathType Leaf) {
        Import-Module "$($podePath)/src/Pode.psm1" -Force -ErrorAction Stop
    }
    else {
        Import-Module -Name 'Pode' -ErrorAction Stop
    }
}
catch { throw }

Start-PodeServer {
    Add-PodeEndpoint -Address localhost -Port 8080 -Protocol Http -Name 'user'
    Add-PodeEndpoint -Address localhost -Port 8081 -Protocol Http -Name 'admin'

    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging

    Enable-PodeOpenApi -Title 'OpenAPI Example' -RouteFilter '/api/*' -RestrictRoutes
    Enable-PodeOAViewer -Type Swagger -Path '/docs/swagger'
    Enable-PodeOAViewer -Type ReDoc  -Path '/docs/redoc'
    Enable-PodeOAViewer -Type RapiDoc  -Path '/docs/rapidoc'
    Enable-PodeOAViewer -Type StopLight  -Path '/docs/stoplight'
    Enable-PodeOAViewer -Type Explorer  -Path '/docs/explorer'
    Enable-PodeOAViewer -Type RapiPdf  -Path '/docs/rapipdf'
    Enable-PodeOAViewer -Editor -Path '/docs/editor'
    Enable-PodeOAViewer -Bookmarks -Path '/docs'

    New-PodeAuthScheme -Basic | Add-PodeAuth -Name 'Validate' -Sessionless -ScriptBlock {
        return @{
            User = @{
                ID ='M0R7Y302'
                Name = 'Morty'
                Type = 'Human'
            }
        }
    }


    Add-PodeRoute -Method Get -Path "/api/resources" -Authentication Validate -EndpointName 'user' -ScriptBlock {
        Set-PodeResponseStatus -Code 200
    } -PassThru |
        Set-PodeOARouteInfo -Summary 'A cool summary' -Tags 'Resources' -PassThru |
        Add-PodeOAResponse -StatusCode 200 -PassThru |
        Add-PodeOAResponse -StatusCode 404

    Add-PodeRoute -Method Post -Path "/api/resources" -ScriptBlock {
        Set-PodeResponseStatus -Code 200
    } -PassThru |
        Set-PodeOARouteInfo -Summary 'A cool summary' -Tags 'Resources' -PassThru |
        Add-PodeOAResponse -StatusCode 200 -PassThru |
        Add-PodeOAResponse -StatusCode 404


    Add-PodeRoute -Method Get -Path '/api/users/:userId' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ Name = 'Rick'; UserId = $WebEvent.Parameters['userId'] }
    } -PassThru |
        Set-PodeOARouteInfo -Summary 'A cool summary' -Tags 'Users' -PassThru |
        Set-PodeOARequest -Parameters @(
            (New-PodeOAIntProperty -Name 'userId' -Required | ConvertTo-PodeOAParameter -In Path)
        ) -PassThru |
        Add-PodeOAResponse -StatusCode 200 -Description 'A user object' -ContentSchemas @{
            'application/json' = (New-PodeOAObjectProperty -Properties @(
                (New-PodeOAStringProperty -Name 'Name'),
                (New-PodeOAIntProperty -Name 'UserId')
            ))
        }


    Add-PodeRoute -Method Get -Path '/api/users' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ Name = 'Rick'; UserId = $WebEvent.Query['userId'] }
    } -PassThru |
        Set-PodeOARouteInfo -Summary 'A cool summary' -Tags 'Users' -PassThru |
        Set-PodeOARequest -Parameters @(
            (New-PodeOAIntProperty -Name 'userId' -Required | ConvertTo-PodeOAParameter -In Query)
        ) -PassThru |
        Add-PodeOAResponse -StatusCode 200 -Description 'A user object'


    Add-PodeRoute -Method Post -Path '/api/users' -Authentication Validate -ScriptBlock {
        Write-PodeJsonResponse -Value @{ Name = 'Rick'; UserId = $WebEvent.Data.userId }
    } -PassThru |
        Set-PodeOARouteInfo -Summary 'A cool summary' -Tags 'Users' -PassThru |
        Set-PodeOARequest -RequestBody (
            New-PodeOARequestBody -Required -ContentSchemas @{
                'application/json' = (New-PodeOAIntProperty -Name 'userId' -Object)
            }
        ) -PassThru |
        Add-PodeOAResponse -StatusCode 200 -Description 'A user object'

    Add-PodeRoute -Method Put -Path '/api/users' -ScriptBlock {
        $users = @()
        foreach ($id in $WebEvent.Data) {
            $users += @{
                Name = (New-Guid).Guid
                UserIdd = $id
            }
        }

        Write-PodeJsonResponse -Value $users
    } -PassThru |
        Set-PodeOARouteInfo -Tags 'Users' -PassThru |
        Set-PodeOARequest -RequestBody (
            New-PodeOARequestBody -Required -ContentSchemas @{
                'application/json' = (New-PodeOAIntProperty -Name 'userId' -Array)
            }
        ) -PassThru |
        Add-PodeOAResponse -StatusCode 200 -Description 'A list of users' -ContentSchemas @{
            'application/json' = (New-PodeOAObjectProperty -Array -Properties @(
                (New-PodeOAStringProperty -Name 'Name'),
                (New-PodeOAIntProperty -Name 'UserId')
            ))
        }
}