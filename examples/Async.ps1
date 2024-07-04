param(
    [Parameter()]
    [int]
    $Port = 8090
)

$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# or just:
# Import-Module Pode

<#
# Demostrates Lockables, Mutexes, and Semaphores
#>

Start-PodeServer -Threads 1 {

    Add-PodeEndpoint -Address localhost -Port $Port -Protocol Http
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging

    Enable-PodeOpenApi -Path '/docs/openapi' -OpenApiVersion '3.0.3'  -DisableMinimalDefinitions -NoDefaultResponses

    Add-PodeOAInfo -Title 'Swagger Petstore - OpenAPI 3.0' -Version 1.0.17 -Description $InfoDescription  -TermsOfService 'http://swagger.io/terms/' -LicenseName 'Apache 2.0' `
        -LicenseUrl 'http://www.apache.org/licenses/LICENSE-2.0.html' -ContactName 'API Support' -ContactEmail 'apiteam@swagger.io'

    Enable-PodeOAViewer -Type Swagger -Path '/docs/swagger'
    Enable-PodeOAViewer -Type ReDoc -Path '/docs/redoc' -DarkMode
    Enable-PodeOAViewer -Type RapiDoc -Path '/docs/rapidoc' -DarkMode
    Enable-PodeOAViewer -Type StopLight -Path '/docs/stoplight' -DarkMode
    Enable-PodeOAViewer -Type Explorer -Path '/docs/explorer' -DarkMode
    Enable-PodeOAViewer -Type RapiPdf -Path '/docs/rapipdf' -DarkMode

    Enable-PodeOAViewer -Editor -Path '/docs/swagger-editor'
    Enable-PodeOAViewer -Bookmarks -Path '/docs'


    Add-PodeRoute -PassThru -Method Put -Path '/async5' -async  -ScriptBlock {
        #    Write-PodeHost $WebEvent.Parameters -Explode
        #  Write-PodeHost    $PodeContext.AsyncRoutes.Results -Explode
        #     Write-PodeHost      $PodeContext.AsyncRoutes.Results[$id] -Explode
        Start-Sleep 5
        return @{ InnerValue = 'hey look, a value 5!' }
    } | Set-PodeOARouteInfo -Summary 'Do something'


    Add-PodeRoute -PassThru -Method Put -Path '/async20' -async  -ScriptBlock {
        for ($i = 0; $i -lt 20; $i++) {
            Start-Sleep 10
        }
        return @{ InnerValue = 'hey look, a value 20!' }
    } | Set-PodeOARouteInfo -Summary 'Do something'

    Add-PodeGetTaskRoute -Path '/task' -ResponseType JSON, XML, YAML -In Path -TaskIdName 'pippopppoId'
    Add-PodeStopTaskRoute -Path '/task' -ResponseType JSON, XML, YAML -In Query -TaskIdName 'pippopppoId'




}