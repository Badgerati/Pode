$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# or just:
# Import-Module Pode

# create a server, and start listening on port 8090
Server -Threads 2 {

    # listen on localhost:8090
    listen localhost:8090 http

    # set view engine to pode renderer
    engine html

    # GET request to set/extend a cookie for the date of the request
    route get '/' {
        $cookieName = 'current-date'

        if ((cookie exists $cookieName)) {
            cookie extend $cookieName -ttl 7200 | Out-Null
        }
        else {
            cookie set $cookieName ([datetime]::UtcNow) -ttl 7200 -s 'pi' | Out-Null
        }

        view 'simple'
    }

    # GET request to remove the date cookie
    route get '/remove' {
        cookie remove 'current-date'
    }

    # GET request to check to signage of the date cookie
    route get '/check' {
        $cookieName = 'current-date'

        $c1 = cookie get $cookieName
        $c2 = cookie get $cookieName -s 'pi'
        $ch = cookie check $cookieName -s 'pi'

        json @{
            'SignedValue' = $c1.Value;
            'UnsignedValue' = $c2.Value;
            'Valid' = $ch;
        }
    }

}