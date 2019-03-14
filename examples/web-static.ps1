param (
    [int]
    $Port = 8085
)

$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# or just:
# Import-Module Pode

# create a server, and start listening on port 8085
Server -Threads 2 {

    # listen on localhost:8085
    listen *:$Port http
    logger terminal

    # set view engine to pode renderer
    engine pode

    # STATIC asset folder route
    route static '/assets' './assets' -d @('index.html')

    # GET request for web page on "localhost:8085/"
    route 'get' '/' {
        param($session)
        view 'web-static' -Data @{ 'numbers' = @(1, 2, 3); }
    }

    # GET request to download a file from static route
    route 'get' '/download' {
        param($session)
        attach '/assets/images/Fry.png'
    }

} -FileMonitor