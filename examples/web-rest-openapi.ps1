$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

Start-PodeServer {
    Add-PodeEndpoint -Address localhost -Port 8080 -Protocol Http

    Enable-PodeOpenApiRoute -Title 'OpenAPI Example' -Filter '/api/'
    Enable-PodeSwaggerRoute

    foreach ($i in 1..100)
    {
        Add-PodeRoute -Method Get -Path "/api/resources_$($i)" -ScriptBlock {
            Set-PodeResponseStatus -Code 200
        }
    }
}