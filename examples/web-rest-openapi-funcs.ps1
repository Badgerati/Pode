$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

Start-PodeServer {
    Add-PodeEndpoint -Address localhost -Port 8080 -Protocol Http

    Enable-PodeOpenApi -Title 'OpenAPI Example' -RouteFilter '/api/*' -RestrictRoutes
    Enable-PodeOpenApiViewer -Type Swagger -Path '/docs/swagger'    
    Enable-PodeOpenApiViewer -Type ReDoc  -Path '/docs/redoc'  
    Enable-PodeOpenApiViewer -Type RapiDoc  -Path '/docs/rapidoc'  
    Enable-PodeOpenApiViewer -Type StopLight  -Path '/docs/stoplight'  
    Enable-PodeOpenApiViewer -Type Explorer  -Path '/docs/explorer'  
    Enable-PodeOpenApiViewer -Type RapiPdf  -Path '/docs/rapipdf'  

    Enable-PodeOpenApiViewer -Type Bookmarks -Path '/docs' 

    #ConvertTo-PodeRoute -Path '/api' -Commands @('Get-ChildItem', 'New-Item')
    ConvertTo-PodeRoute -Path '/api' -Module Pester
}