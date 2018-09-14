$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# or just:
# Import-Module Pode

Server {

    # listen on localhost:8085
    listen *:$Port http

    # limit localhost to 5 request per 10 seconds
    limit ip @('127.0.0.1', '[::1]') 5 10

    # override the rate limiting to ignore it
    middleware -name '@limit' {
        # just continue to next middleware
        return $true
    }

    # block requests that come from powershell
    middleware {
        # session parameter which contains the Request/Response, and any other
        # keys added in any prior middleware
        param($session)

        # if the user agent is powershell, deny access
        if ($session.Request.UserAgent -ilike '*powershell*') {
            # forbidden
            status 403

            # stop processing
            return $false
        }

        # create a new key on the session for the next middleware/route
        $session.Agent = $session.Request.UserAgent

        # continue processing other middleware
        return $true
    }

    # custom middleware to reject access to a specific IP address
    $reject_ip = {
        param($session)

        if ($session.Request.RemoteEndPoint.Address.IPAddressToString -ieq '10.10.1.8') {
            status 403
            return $false
        }

        return $true
    }

    # the reject_ip middleware above is linked to this route,
    # and checked before running the route logic
    route get '/users' $reject_ip {
        json @{
            'Users' = @('John', 'Bill')
        }
    }

    # this route has no custom middleware, and just runs the route logic
    route get '/alive' {
        json @{ 'Alive' = $true }
    }
}