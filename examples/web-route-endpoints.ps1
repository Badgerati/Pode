$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# or just:
# Import-Module Pode

# create a server, and start listening on port 8080 and 8443
Server {

    # listen on localhost:8080/8443
    listen 127.0.0.1:8080 http
    listen 127.0.0.2:8080 http

    # set view engine to pode
    Set-PodeViewEngine -Type Pode

    # GET request for web page
    route get '/' {
        Write-PodeViewResponse -Path 'simple' -Data @{ 'numbers' = @(1, 2, 3); }
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

    # ALL requests for 127.0.0.2 to 127.0.0.1
    route * * -endpoint 127.0.0.2 {
        Move-PodeResponseUrl -Domain 127.0.0.1
    }

} -FileMonitor