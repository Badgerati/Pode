$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# or just:
# Import-Module Pode

# create a server, and start listening on port 8090
Server {

    # tell this server to run as a desktop gui
    gui 'Pode Desktop Application' @{
        'Icon' = '../images/icon.png'
    }

    # listen on localhost:8090
    listen localhost:8090 http

    # set view engine to pode renderer
    engine pode

    # GET request for web page on "localhost:8090/"
    route 'get' '/' {
        view 'gui' -Data @{ 'numbers' = @(1, 2, 3); }
    }

 } 