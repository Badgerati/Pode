$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# or just:
# Import-Module Pode

Start-PodeServer {

    # listen on localhost:8085
    Add-PodeEndpoint -Address *:$port -Protocol Http

    # limit localhost to 5 request per 10 seconds
    Add-PodeLimitRule -Type IP -Values @('127.0.0.1', '[::1]') -Limit 5 -Seconds 10

    # override the rate limiting to ignore it
    Add-PodeMiddleware -Name  '__pode_mw_rate_limit__' -ScriptBlock {
        # just continue to next middleware
        return $true
    }

    # middleware that runs on specific routes
    Add-PodeMiddleware -Name 'RouteMiddleware' -Route '/users' -ScriptBlock {
        'Middleware for routes!' | Out-Default
        return $true
    }

    # middleware from a hashtable/pipeline - useful for inbuilt types
    $mw = @{
        'Logic' = {
            'Middleware from hashtables!' | Out-Default
            return $true
        };
    }

    $mw | Add-PodeMiddleware -Name 'MiddlewareFromPipe'

    # block requests that come from powershell
    Add-PodeMiddleware -Name 'BlockPowershell' -ScriptBlock {
        # session parameter which contains the Request/Response, and any other
        # keys added in any prior middleware
        param($session)

        # if the user agent is powershell, deny access
        if ($session.Request.UserAgent -ilike '*powershell*') {
            # forbidden
            Set-PodeResponseStatus -Code 403

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

        if ($session.RemoteIpAddress.IPAddressToString -ieq '10.10.1.8') {
            Set-PodeResponseStatus -Code 403
            return $false
        }

        return $true
    }

    # the reject_ip middleware above is linked to this route,
    # and checked before running the route logic
    Add-PodeRoute -Method Get -Path '/users' -Middleware $reject_ip -ScriptBlock {
        Write-PodeJsonResponse -Value @{
            'Users' = @('John', 'Bill')
        }
    }

    # this route has no custom middleware, and just runs the route logic
    Add-PodeRoute -Method Get -Path '/alive' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ 'Alive' = $true }
    }
}