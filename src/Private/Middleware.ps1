function Invoke-PodeMiddleware
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $WebEvent,

        [Parameter()]
        $Middleware,

        [Parameter()]
        [string]
        $Route
    )

    # if there's no middleware, do nothing
    if ($null -eq $Middleware -or $Middleware.Length -eq 0) {
        return $true
    }

    # filter the middleware down by route (retaining order)
    if (![string]::IsNullOrWhiteSpace($Route))
    {
        $Middleware = @(foreach ($mware in $Middleware) {
            if ([string]::IsNullOrWhiteSpace($mware.Route) -or ($mware.Route -ieq '/') -or ($mware.Route -ieq $Route) -or ($Route -imatch "^$($mware.Route)$")) {
                $mware
            }
        })
    }

    # continue or halt?
    $continue = $true

    # loop through each of the middleware, invoking the next if it returns true
    foreach ($midware in @($Middleware))
    {
        try {
            $continue = Invoke-PodeScriptBlock -ScriptBlock $midware.Logic -Arguments (@($WebEvent) + @($midware.Arguments)) -Return -Scoped -Splat
        }
        catch {
            Set-PodeResponseStatus -Code 500 -Exception $_
            $continue = $false
            $_ | Write-PodeErrorLog
        }

        if (!$continue) {
            break
        }
    }

    return $continue
}

function Get-PodeInbuiltMiddleware
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name,

        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [scriptblock]
        $ScriptBlock
    )

    # check if middleware contains an override
    $override = ($PodeContext.Server.Middleware | Where-Object { $_.Name -ieq $Name })

    # if override there, remove it from middleware
    if ($override) {
        $PodeContext.Server.Middleware = @($PodeContext.Server.Middleware | Where-Object { $_.Name -ine $Name })
        $ScriptBlock = $override.Logic
    }

    # return the script
    return @{
        Name = $Name
        Logic = $ScriptBlock
    }
}

function Get-PodeAccessMiddleware
{
    return (Get-PodeInbuiltMiddleware -Name '__pode_mw_access__' -ScriptBlock {
        param($e)

        # ensure the request IP address is allowed
        if (!(Test-PodeIPAccess -IP $e.Request.RemoteEndPoint.Address)) {
            Set-PodeResponseStatus -Code 403
            return $false
        }

        # IP address is allowed
        return $true
    })
}

function Get-PodeLimitMiddleware
{
    return (Get-PodeInbuiltMiddleware -Name '__pode_mw_rate_limit__' -ScriptBlock {
        param($e)

        # ensure the request IP address has not hit a rate limit
        if (!(Test-PodeIPLimit -IP $e.Request.RemoteEndPoint.Address)) {
            Set-PodeResponseStatus -Code 429
            return $false
        }

        # IP address is allowed
        return $true
    })
}

function Get-PodePublicMiddleware
{
    return (Get-PodeInbuiltMiddleware -Name '__pode_mw_static_content__' -ScriptBlock {
        param($e)

        # get the static file path
        $info = Find-PodeStaticRoutePath -Path $e.Path -Protocol $e.Protocol -Endpoint $e.Endpoint
        if ([string]::IsNullOrWhiteSpace($info.Source)) {
            return $true
        }

        # check current state of caching
        $config = $PodeContext.Server.Web.Static.Cache
        $caching = $config.Enabled

        # if caching, check include/exclude
        if ($caching) {
            if (($null -ne $config.Exclude) -and ($e.Path -imatch $config.Exclude)) {
                $caching = $false
            }

            if (($null -ne $config.Include) -and ($e.Path -inotmatch $config.Include)) {
                $caching = $false
            }
        }

        # write, or attach, the file to the response
        if ($info.Download) {
            Set-PodeResponseAttachment -Path $e.Path
        }
        else {
            Write-PodeFileResponse -Path $info.Source -MaxAge $PodeContext.Server.Web.Static.Cache.MaxAge -Cache:$caching
        }

        # static content found, stop
        return $false
    })
}

function Get-PodeRouteValidateMiddleware
{
    return @{
        Name = '__pode_mw_route_validation__'
        Logic = {
            param($e)

            # ensure the path has a route
            $route = Find-PodeRoute -Method $e.Method -Path $e.Path -Protocol $e.Protocol -Endpoint $e.Endpoint -CheckWildMethod

            # if there's no route defined, it's a 404 - or a 405 if a route exists for any other method
            if ($null -eq $route) {
                # check if a route exists for another method
                $methods = @('DELETE', 'GET', 'HEAD', 'MERGE', 'OPTIONS', 'PATCH', 'POST', 'PUT', 'TRACE')
                $diff_route = @(foreach ($method in $methods) {
                    $r = Find-PodeRoute -Method $method -Path $e.Path -Protocol $e.Protocol -Endpoint $e.Endpoint
                    if ($null -ne $r) {
                        $r
                        break
                    }
                })[0]

                if ($null -ne $diff_route) {
                    Set-PodeResponseStatus -Code 405
                    return $false
                }

                # otheriwse, it's a 404
                Set-PodeResponseStatus -Code 404
                return $false
            }

            # set the route parameters
            $e.Parameters = @{}
            if ($e.Path -imatch "$($route.Path)$") {
                $e.Parameters = $Matches
            }

            # set the route on the WebEvent
            $e.Route = $route

            # override the content type from the route if it's not empty
            if (![string]::IsNullOrWhiteSpace($route.ContentType)) {
                $e.ContentType = $route.ContentType
            }

            # set the content type for any pages for the route if it's not empty
            $e.ErrorType = $route.ErrorType

            # route exists
            return $true
        }
    }
}

function Get-PodeBodyMiddleware
{
    return (Get-PodeInbuiltMiddleware -Name '__pode_mw_body_parsing__' -ScriptBlock {
        param($e)

        try {
            # attempt to parse that data
            $result = ConvertFrom-PodeRequestContent -Request $e.Request -ContentType $e.ContentType

            # set session data
            $e.Data = $result.Data
            $e.Files = $result.Files

            # payload parsed
            return $true
        }
        catch {
            Set-PodeResponseStatus -Code 400 -Exception $_
            return $false
        }
    })
}

function Get-PodeQueryMiddleware
{
    return (Get-PodeInbuiltMiddleware -Name '__pode_mw_query_parsing__' -ScriptBlock {
        param($e)

        try {
            # set the query string from the request
            $e.Query = (ConvertFrom-PodeNameValueToHashTable -Collection $e.Request.QueryString)
            return $true
        }
        catch {
            Set-PodeResponseStatus -Code 400 -Exception $_
            return $false
        }
    })
}

function Get-PodeCookieMiddleware
{
    return (Get-PodeInbuiltMiddleware -Name '__pode_mw_cookie_parsing__' -ScriptBlock {
        param($e)

        # if it's not serverless or pode, return
        if (!$PodeContext.Server.IsServerless -and ($PodeContext.Server.Type -ine 'pode')) {
            return $true
        }

        # if cookies already set, return
        if ($e.Cookies.Count -gt 0) {
            return $true
        }

        # if the request's header has no cookies, return
        $h_cookie = (Get-PodeHeader -Name 'Cookie')
        if ([string]::IsNullOrWhiteSpace($h_cookie)) {
            return $true
        }

        # parse the cookies from the header
        $cookies = @($h_cookie -split '; ')
        $e.Cookies = @{}

        foreach ($cookie in $cookies) {
            $atoms = $cookie.Split('=', 2)

            $value = [string]::Empty
            if ($atoms.Length -gt 1) {
                $value = ($atoms[1..($atoms.Length - 1)] -join ([string]::Empty))
            }

            $e.Cookies[$atoms[0]] = [System.Net.Cookie]::new($atoms[0], $value)
        }

        return $true
    })
}