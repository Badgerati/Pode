$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# or just:
# Import-Module Pode

# create a server, and start listening on port 8080 and 8443
Server {

    # listen on localhost:8080/8443
    listen 127.0.0.1:8080 http -name 'local1'
    listen 127.0.0.2:8080 http -name 'local2'

    # set view engine to pode
    Set-PodeViewEngine -Type Pode

    # GET request for web page
    route get '/' {
        Write-PodeViewResponse -Path 'simple' -Data @{ 'numbers' = @(1, 2, 3); }
    }

    # GET request for web page, but only for the local2 endpoint
    route get '/' -ListenName 'local2' {
        Write-PodeViewResponse -Path 'simple' -Data @{ 'numbers' = @(1, 2, 3, 4, 5, 6, 7, 8); }
    }

    # GET request to download a file
    route get '/download' {
        Set-PodeResponseAttachment -Path 'Anger.jpg'
    }

    # GET request with parameters
    route get '/:userId/details' {
        param($event)
        Write-PodeJsonResponse -Value @{ 'userId' = $event.Parameters['userId'] }
    }

} -FileMonitor