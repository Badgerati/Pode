try {
    $ScriptPath = (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
    $podePath = Split-Path -Parent -Path $ScriptPath
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

    Enable-PodeOpenApi -Title 'OpenAPI Example' -RouteFilter '/api/*' -RestrictRoutes
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
