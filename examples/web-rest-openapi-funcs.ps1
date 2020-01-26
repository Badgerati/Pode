$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

Start-PodeServer {
    Add-PodeEndpoint -Address localhost -Port 8080 -Protocol Http

    Enable-PodeOpenApi -Title 'OpenAPI Example' -RouteFilter '/api/*' -RestrictRoutes
    Enable-PodeSwagger -DarkMode

    #ConvertTo-PodeRoute -Path '/api' -Commands @('Get-ChildItem', 'New-Item')
    ConvertTo-PodeRoute -Path '/api' -Module Pester
}