$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

Start-PodeServer {
    Add-PodeEndpoint -Address localhost -Port 8080 -Protocol Http

    Enable-PodeOpenApiRoute -Title 'OpenAPI Example' -Filter '/api/'
    Enable-PodeSwaggerRoute


    Add-PodeRoute -Method Get -Path "/api/resources" -ScriptBlock {
        Set-PodeResponseStatus -Code 200
    } -PassThru |
        Set-PodeOpenApiRouteMetaData -Summary 'A cool summary' -Tags 'Resources' -PassThru |
        Add-PodeOpenApiRouteResponse -StatusCode 200 -PassThru |
        Add-PodeOpenApiRouteResponse -StatusCode 404


    Add-PodeRoute -Method Post -Path "/api/resources" -ScriptBlock {
        Set-PodeResponseStatus -Code 200
    } -PassThru |
        Set-PodeOpenApiRouteMetaData -Summary 'A cool summary' -Tags 'Resources' -PassThru |
        Add-PodeOpenApiRouteResponse -StatusCode 200 -PassThru |
        Add-PodeOpenApiRouteResponse -StatusCode 404


    Add-PodeRoute -Method Get -Path '/api/users/:userId' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ Name = 'Rick' }
    } -PassThru |
        Set-PodeOpenApiRouteMetaData -Summary 'A cool summary' -Tags 'Users' -PassThru |
        Set-PodeOpenApiRouteRequest -Parameters @(
            New-PodeOpenApiRouteRequestParameter -Integer -Name 'userId' -In Path -Required
        ) -PassThru |
        Add-PodeOpenApiRouteResponse -Status 200
}