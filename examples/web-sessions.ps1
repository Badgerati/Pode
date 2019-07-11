$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# or just:
# Import-Module Pode

# create a server, and start listening on port 8085
Start-PodeServer {

    # listen on localhost:8085
    Add-PodeEndpoint -Address *:8085 -Protocol HTTP

    # set view engine to pode renderer
    Set-PodeViewEngine -Type Pode

    # setup session details
    middleware (session @{
        'Secret' = 'schwifty';  # secret-key used to sign session cookie
        'Name' = 'pode.sid';    # session cookie name (def: pode.sid)
        'Duration' = 120;       # duration of the cookie, in seconds
        'Extend' = $true;       # extend the duration of the cookie on each call
        'GenerateId' = {        # custom SessionId generator (def: guid)
            return [System.IO.Path]::GetRandomFileName()
        };
    })

    # GET request for web page on "localhost:8085/"
    route 'get' '/' {
        param($s)
        $s.Session.Data.Views++
        Write-PodeViewResponse -Path 'simple' -Data @{ 'numbers' = @($s.Session.Data.Views); }
    }

}