param(
    [int]
    $Port = 8085
)

$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# or just:
# Import-Module Pode

# create a server, and start listening on port 8085
Start-PodeServer -Threads 2 {

    # listen on localhost:8085
    Add-PodeEndpoint -Address * -Port $port -Protocol Http
    New-PodeLoggingMethod -Terminal | Enable-PodeRequestLogging
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging

    # set view engine to pode renderer
    Set-PodeViewEngine -Type Pode

    # STATIC asset folder route
    Add-PodeStaticRoute -Path '/assets' -Source './assets' -Defaults @('index.html')
    Add-PodeStaticRoute -Path '/assets/download' -Source './assets' -DownloadOnly

    # GET request for web page on "localhost:8085/"
    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        Write-PodeViewResponse -Path 'web-static' -Data @{ 'numbers' = @(1, 2, 3); }
    }

    # GET request to download a file from static route
    Add-PodeRoute -Method Get -Path '/download' -ScriptBlock {
        Set-PodeResponseAttachment -Path '/assets/images/Fry.png'
    }

}