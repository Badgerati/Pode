if ((Get-Module -Name Pode | Measure-Object).Count -ne 0)
{
    Remove-Module -Name Pode
}

$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -ErrorAction Stop

# or just:
# Import-Module Pode

# create a server, and start listening on port 8085
Server {

    # listen on localhost:8085
    listen 127.0.0.1:8085 http

    # allow the local ip and some other ips
    access allow ip 127.0.0.1
    access allow ip @('192.169.0.1', '192.168.0.2')

    # deny an ip
    access deny ip 10.10.10.10
    access deny ip '10.10.0.0/24'
    access deny ip all

    # log requests to the terminal
    logger terminal

    # set view engine to pode renderer
    engine pode

    # GET request for web page on "localhost:8085/"
    route 'get' '/' {
        param($session)
        view 'simple' -Data @{ 'numbers' = @(1, 2, 3); }
    }

    # GET request throws fake "500" server error status code
    route 'get' '/error' {
        param($session)
        status 500
    }

    # GET request to download a file
    route 'get' '/download' {
        param($session)
        attach 'Anger.jpg'
    }

    # GET request with parameters
    route 'get' '/:userId/details' {
        param($session)
        json @{ 'userId' = $session.Parameters['userId'] }
    }

} -FileMonitor
 