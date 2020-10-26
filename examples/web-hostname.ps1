param (
    [int]
    $Port = 8085
)

$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# or just:
# Import-Module Pode

# create a server, and start listening on port 8085 at pode.foo.com
# -- You will need to add "127.0.0.1  pode.foo.com" to your hosts file
Start-PodeServer -Threads 2 {

    # listen on localhost:8085
    Add-PodeEndpoint -Address pode3.foo.com -Port $Port -Protocol Http
    Add-PodeEndpoint -Address pode2.foo.com -Port $Port -Protocol Http
    Add-PodeEndpoint -Address 127.0.0.1 -Hostname pode.foo.com -Port $Port -Protocol Http
    Add-PodeEndpoint -Hostname pode4.foo.com -Port $Port -Protocol Http -LookupHostname

    # logging
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging

    # set view engine to pode renderer
    Set-PodeViewEngine -Type Pode

    # STATIC asset folder route
    Add-PodeStaticRoute -Path '/assets' -Source './assets' -Defaults @('index.html')

    # GET request for web page on "localhost:8085/"
    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        param($session)
        Write-PodeViewResponse -Path 'web-static' -Data @{ 'numbers' = @(1, 2, 3); }
    }

    # GET request to download a file from static route
    Add-PodeRoute -Method Get -Path '/download' -ScriptBlock {
        param($session)
        Set-PodeResponseAttachment -Path '/assets/images/Fry.png'
    }

}