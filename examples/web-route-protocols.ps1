$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# or just:
# Import-Module Pode

# create a server, and start listening on port 8080 and 8443
Server {

    # listen on localhost:8080/8443
    listen *:8080 http
    listen *:8443 https

    # set view engine to pode
    engine pode

    # GET request for web page
    route get '/' -endpoint *:8443 -protocol http {
        view 'simple' -Data @{ 'numbers' = @(1, 2, 3); }
    }

    # GET request to download a file
    route get '/download' {
        attach 'Anger.jpg'
    }

    # GET request with parameters
    route get '/:userId/details' {
        param($event)
        json @{ 'userId' = $event.Parameters['userId'] }
    }

    # ALL requests for http only to redirect to https
    route * * -protocol http {
        redirect -protocol https -port 8443
    }

} -FileMonitor