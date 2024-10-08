<#
.SYNOPSIS
    A sample PowerShell script to set up a Pode server with rate limiting and middleware.

.DESCRIPTION
    This script sets up a Pode server listening on port 8081 with various middleware implementations
    and rate limiting for incoming requests. It includes middleware for route-specific logic, blocking
    specific user agents, and rejecting requests from certain IP addresses.

.EXAMPLE
    To run the sample: ./Middleware.ps1

    Invoke-RestMethod -Uri http://localhost:8081/users -Method Get
    Invoke-RestMethod -Uri http://localhost:8081/alive -Method Get

.LINK
    https://github.com/Badgerati/Pode/blob/develop/examples/Middleware.ps1

.NOTES
    Author: Pode Team
    License: MIT License
#>

try {
    # Determine the script path and Pode module path
    $ScriptPath = (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
    $podePath = Split-Path -Parent -Path $ScriptPath

    # Import the Pode module from the source path if it exists, otherwise from installed modules
    if (Test-Path -Path "$($podePath)/src/Pode.psm1" -PathType Leaf) {
        Import-Module "$($podePath)/src/Pode.psm1" -Force -ErrorAction Stop
    }
    else {
        Import-Module -Name 'Pode' -MaximumVersion 2.99 -ErrorAction Stop
    }
}
catch { throw }


# or just:
# Import-Module Pode

Start-PodeServer {

    # listen on localhost:8081
    Add-PodeEndpoint -Address localhost -Port 8081 -Protocol Http

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
        # if the user agent is powershell, deny access
        if ($WebEvent.Request.UserAgent -ilike '*powershell*') {
            # forbidden
            Set-PodeResponseStatus -Code 403

            # stop processing
            return $false
        }

        # create a new key on the session for the next middleware/route
        $WebEvent.Agent = $WebEvent.Request.UserAgent

        # continue processing other middleware
        return $true
    }

    # custom middleware to reject access to a specific IP address
    $reject_ip = {
        if ($session.Request.RemoteEndPoint.Address.IPAddressToString -ieq '10.10.1.8') {
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