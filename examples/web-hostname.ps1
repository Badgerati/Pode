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
    Add-PodeEndpoint -Endpoint pode.foo.com:$Port -Protocol HTTP

    # set view engine to pode renderer
    Set-PodeViewEngine -Type Pode

    # STATIC asset folder route
    route static '/assets' './assets' -d @('index.html')

    # GET request for web page on "localhost:8085/"
    route 'get' '/' {
        param($session)
        Write-PodeViewResponse -Path 'web-static' -Data @{ 'numbers' = @(1, 2, 3); }
    }

    # GET request to download a file from static route
    route 'get' '/download' {
        param($session)
        Set-PodeResponseAttachment -Path '/assets/images/Fry.png'
    }

}