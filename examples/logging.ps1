$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# or just:
# Import-Module Pode

# create a server, and start listening on port 8085
Server {

    listen *:8085 http
    engine pode

    # termial/cli logger
    logger terminal

    # daily file logger
    logger file @{
        'Path' = $null; # default is '<root>/logs'
        'MaxDays' = 4;
    }

    # custom logger
    logger -c output {
        param($event)
        $event.Log.Request.Protocol | Out-Default
    }

    # GET request for web page on "localhost:8085/"
    route 'get' '/' {
        view 'simple' -Data @{ 'numbers' = @(1, 2, 3); }
    }

    # GET request throws fake "500" server error status code
    route 'get' '/error' {
        status 500
    }

    # GET request to download a file
    route 'get' '/download' {
        attach 'Anger.jpg'
    }

}
