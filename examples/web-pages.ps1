param (
    [int]
    $Port = 8085
)

$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# or just:
# Import-Module Pode

# create a server, and start listening on port 8085
Server -Threads 2 -Browse {

    # listen on localhost:8085
    listen localhost:$Port http
    listen localhost:8090 http

    # limit ip @('127.0.0.1', '[::1]') 5 10

    # allow the local ip and some other ips
    access allow ip @('127.0.0.1', '[::1]')
    access allow ip @('192.169.0.1', '192.168.0.2')

    # deny an ip
    access deny ip 10.10.10.10
    access deny ip '10.10.0.0/24'
    access deny ip all

    # log requests to the terminal
    # logger terminal

    # set view engine to pode renderer
    Set-PodeViewEngine -Type Pode

    # GET request for web page on "localhost:8085/"
    route 'get' '/' {
        Write-PodeViewResponse -Path 'simple' -Data @{ 'numbers' = @(1, 2, 3); }
    }

    # GET request throws fake "500" server error status code
    route 'get' '/error' {
        Set-PodeResponseStatus -Code 500
    }

    # GET request to page that merely redirects to google
    route 'get' '/redirect' {
        Move-PodeResponseUrl -Url 'https://google.com'
    }

    # GET request that redirects to same host, just different port
    route 'get' '/redirect-port' {
        param($event)
        if ($event.Request.Url.Port -ne 8086) {
            Move-PodeResponseUrl -Port 8086
        }
        else {
            Write-PodeJsonResponse -Value @{ 'value' = 'you got redirected!'; }
        }
    }

    # GET request to download a file
    route 'get' '/download' {
        Set-PodeResponseAttachment -Path 'Anger.jpg'
    }

    # GET request with parameters
    route 'get' '/:userId/details' {
        param($event)
        Write-PodeJsonResponse -Value @{ 'userId' = $event.Parameters['userId'] }
    }

    # ALL request, that supports every method and it a default drop route
    route * '/all' {
        Write-PodeJsonResponse -Value @{ 'value' = 'works for every http method' }
    }

    route get '/api/*/hello' {
        Write-PodeJsonResponse -Value @{ 'value' = 'works for every hello route' }
    }

    route get '/script' -fp './modules/route_script.ps1'

} -FileMonitor