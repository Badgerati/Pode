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
    Add-PodeEndpoint -Address localhost -Port 8081 -Protocol Http

    Enable-PodeOpenApi -Title 'OpenAPI Example' -RouteFilter '/api/*' -RestrictRoutes
    Enable-PodeOpenApiViewer -Type Swagger -Path '/docs/swagger'
    Enable-PodeOpenApiViewer -Type ReDoc  -Path '/docs/redoc'
    Enable-PodeOpenApiViewer -Type RapiDoc  -Path '/docs/rapidoc'
    Enable-PodeOpenApiViewer -Type StopLight  -Path '/docs/stoplight'
    Enable-PodeOpenApiViewer -Type Explorer  -Path '/docs/explorer'
    Enable-PodeOpenApiViewer -Type RapiPdf  -Path '/docs/rapipdf'

    Enable-PodeOpenApiViewer -Bookmarks -Path '/docs'

    #ConvertTo-PodeRoute -Path '/api' -Commands @('Get-ChildItem', 'New-Item')
    ConvertTo-PodeRoute -Path '/api' -Module Pester
}