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
    if (($null -eq $Middleware) -or ($Middleware.Length -eq 0)) {
        return $true
    }

    # filter the middleware down by route (retaining order)
    if (![string]::IsNullOrWhiteSpace($Route))
    {
        $Middleware = @(foreach ($mware in $Middleware) {
            if ($null -eq $mware) {
                continue
            }

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
        if (($null -eq $midware) -or ($null -eq $midware.Logic)) {
            continue
        }

        try {
            $_args = @($WebEvent) + @($midware.Arguments)
            if ($null -ne $midware.UsingVariables) {
                $_args = @($midware.UsingVariables.Value) + $_args
            }

            $continue = Invoke-PodeScriptBlock -ScriptBlock $midware.Logic -Arguments $_args -Return -Scoped -Splat
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

function New-PodeMiddlewareInternal
{
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory=$true)]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [string]
        $Route,

        [Parameter()]
        [object[]]
        $ArgumentList,

        [Parameter(Mandatory=$true)]
        [System.Management.Automation.SessionState]
        $PSSession
    )

    if (Test-PodeIsEmpty $ScriptBlock) {
        throw "[Middleware]: No ScriptBlock supplied"
    }

    # if route is empty, set it to root
    $Route = ConvertTo-PodeRouteRegex -Path $Route

    # check if the scriptblock has any using vars
    $ScriptBlock, $usingVars = Invoke-PodeUsingScriptConversion -ScriptBlock $ScriptBlock -PSSession $PSSession

    # create the middleware hashtable from a scriptblock
    $HashTable = @{
        Route = $Route
        Logic = $ScriptBlock
        Arguments = $ArgumentList
        UsingVariables = $usingVars
    }

    # return the middleware, so it can be cached/added at a later date
    return $HashTable
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

        # are there any rules?
        if (($PodeContext.Server.Access.Allow.Count -eq 0) -and ($PodeContext.Server.Access.Deny.Count -eq 0)) {
            return $true
        }

        # ensure the request IP address is allowed
        if (!(Test-PodeIPAccess -IP $e.Request.RemoteEndPoint.Address)) {
            Set-PodeResponseStatus -Code 403
            return $false
        }

        # request is allowed
        return $true
    })
}

function Get-PodeLimitMiddleware
{
    return (Get-PodeInbuiltMiddleware -Name '__pode_mw_rate_limit__' -ScriptBlock {
        param($e)

        # are there any rules?
        if ($PodeContext.Server.Limits.Rules.Count -eq 0) {
            return $true
        }

        # check the request IP address has not hit a rate limit
        if (!(Test-PodeIPLimit -IP $e.Request.RemoteEndPoint.Address)) {
            Set-PodeResponseStatus -Code 429
            return $false
        }

        # check the route
        if (!(Test-PodeRouteLimit -Path $e.Path)) {
            Set-PodeResponseStatus -Code 429
            return $false
        }

        # check the endpoint
        if (!(Test-PodeEndpointLimit -EndpointName $e.Endpoint.Name)) {
            Set-PodeResponseStatus -Code 429
            return $false
        }

        # request is allowed
        return $true
    })
}

function Get-PodePublicMiddleware
{
    return (Get-PodeInbuiltMiddleware -Name '__pode_mw_static_content__' -ScriptBlock {
        param($e)

        # only find public static content here
        $path = Find-PodePublicRoute -Path $e.Path
        if ([string]::IsNullOrWhiteSpace($path)) {
            return $true
        }

        # check current state of caching
        $cachable = Test-PodeRouteValidForCaching -Path $e.Path

        # write the file to the response
        Write-PodeFileResponse -Path $path -MaxAge $PodeContext.Server.Web.Static.Cache.MaxAge -Cache:$cachable

        # public static content found, stop
        return $false
    })
}

function Get-PodeRouteValidateMiddleware
{
    return @{
        Name = '__pode_mw_route_validation__'
        Logic = {
            param($e)

            # check if the path is static route first, then check the main routes
            $route = Find-PodeStaticRoute -Path $e.Path -EndpointName $e.Endpoint.Name
            if ($null -eq $route) {
                $route = Find-PodeRoute -Method $e.Method -Path $e.Path -EndpointName $e.Endpoint.Name -CheckWildMethod
            }

            # if there's no route defined, it's a 404 - or a 405 if a route exists for any other method
            if ($null -eq $route) {
                # check if a route exists for another method
                $methods = @('DELETE', 'GET', 'HEAD', 'MERGE', 'OPTIONS', 'PATCH', 'POST', 'PUT', 'TRACE')
                $diff_route = @(foreach ($method in $methods) {
                    $r = Find-PodeRoute -Method $method -Path $e.Path -EndpointName $e.Endpoint.Name
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

            # check if static and split
            if ($null -ne $route.Content) {
                $e.StaticContent = $route.Content
                $route = $route.Route
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

            # override the transfer encoding from the route if it's not empty
            if (![string]::IsNullOrWhiteSpace($route.TransferEncoding)) {
                $e.TransferEncoding = $route.TransferEncoding
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
            $result = ConvertFrom-PodeRequestContent -Request $e.Request -ContentType $e.ContentType -TransferEncoding $e.TransferEncoding

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
                foreach ($atom in $atoms[1..($atoms.Length - 1)]) {
                    $value += $atom
                }
            }

            $e.Cookies[$atoms[0]] = [System.Net.Cookie]::new($atoms[0], $value)
        }

        return $true
    })
}