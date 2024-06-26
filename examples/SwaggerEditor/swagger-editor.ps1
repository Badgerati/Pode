param(
    [int]
    $Port = 8080
)

$path = Split-Path -Parent -Path (Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path))
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# or just:
# Import-Module Pode

# create a server, and start listening on port 8085
Start-PodeServer -Threads 2 {

    # listen on localhost:8085
    Add-PodeEndpoint -Address localhost -Port $port -Protocol Http
    New-PodeLoggingMethod -Terminal | Enable-PodeRequestLogging
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging

    # set view engine to pode renderer
    Set-PodeViewEngine -Type HTML

    # STATIC asset folder route
    Add-PodeStaticRoute -Path '/editor/swagger-editor-dist' -Source "$($path)/src/Misc/swagger-editor-dist" -FileBrowser
    Add-PodeStaticRoute -Path '/editor' -Source './www' -Defaults @('index.html') -FileBrowser
    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        Move-PodeResponseUrl -Url '/editor/index.html'
    }
}