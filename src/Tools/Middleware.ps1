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
            # set any custom middleware options
            $WebEvent.Middleware = @{ 'Options' = $midware.Options }

            # invoke the middleware logic
            $continue = Invoke-ScriptBlock -ScriptBlock $midware.Logic -Arguments $WebEvent -Return -Scoped

            # remove any custom middleware options
            $WebEvent.Middleware.Clear()
        }
        catch {
            status 500 -e $_
            $continue = $false
            $_.Exception | Out-Default
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
        'Name' = $Name;
        'Logic' = $ScriptBlock;
    }
}

function Get-PodeAccessMiddleware
{
    return (Get-PodeInbuiltMiddleware -Name '@access' -ScriptBlock {
        param($s)

        # ensure the request IP address is allowed
        if (!(Test-PodeIPAccess -IP $s.Request.RemoteEndPoint.Address)) {
            status 403
            return $false
        }

        # IP address is allowed
        return $true
    })
}

function Get-PodeLimitMiddleware
{
    return (Get-PodeInbuiltMiddleware -Name '@limit' -ScriptBlock {
        param($s)

        # ensure the request IP address has not hit a rate limit
        if (!(Test-PodeIPLimit -IP $s.Request.RemoteEndPoint.Address)) {
            status 429
            return $false
        }

        # IP address is allowed
        return $true
    })
}

function Get-PodePublicMiddleware
{
    return (Get-PodeInbuiltMiddleware -Name '@public' -ScriptBlock {
        param($e)

        # get the static file path
        $info = Get-PodeStaticRoutePath -Route $e.Path -Protocol $e.Protocol -Endpoint $e.Endpoint
        if ([string]::IsNullOrWhiteSpace($info.Path)) {
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
            Attach -Path $e.Path
        }
        else {
            File -Path $info.Path -MaxAge $PodeContext.Server.Web.Static.Cache.MaxAge -Cache:$caching
        }

        # static content found, stop
        return $false
    })
}

function Get-PodeRouteValidateMiddleware
{
    return @{
        'Name' = '@route-valid';
        'Logic' = {
            param($s)

            # ensure the path has a route
            $route = Get-PodeRoute -HttpMethod $s.Method -Route $s.Path -Protocol $s.Protocol -Endpoint $s.Endpoint -CheckWildMethod

            # if there's no route defined, it's a 404
            if ($null -eq $route -or $null -eq $route.Logic) {
                status 404
                return $false
            }

            # set the route parameters
            $WebEvent.Parameters = $route.Parameters

            # override the content type from the route if it's not empty
            if (![string]::IsNullOrWhiteSpace($route.ContentType)) {
                $WebEvent.ContentType = $route.ContentType
            }

            # set the content type for any pages for the route if it's not empty
            $WebEvent.ErrorType = $route.ErrorType

            # route exists
            return $true
        }
    }
}

function Get-PodeBodyMiddleware
{
    return (Get-PodeInbuiltMiddleware -Name '@body' -ScriptBlock {
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
            status 400 -e $_
            return $false
        }
    })
}

function Get-PodeQueryMiddleware
{
    return (Get-PodeInbuiltMiddleware -Name '@query' -ScriptBlock {
        param($s)

        try {
            # set the query string from the request
            $s.Query = (ConvertFrom-PodeNameValueToHashTable -Collection $s.Request.QueryString)
            return $true
        }
        catch {
            status 400 -e $_
            return $false
        }
    })
}

function Get-PodeCookieMiddleware
{
    return (Get-PodeInbuiltMiddleware -Name '@cookie' -ScriptBlock {
        param($e)

        # if it's not serverless, return
        if (!(Test-PodeIsServerless)) {
            return $true
        }

        # if cookies already set, return
        if ($null -ne $e.Cookies) {
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
            $atoms = @($cookie -split '=')

            $value = [string]::Empty
            if ($atoms.Length -gt 1) {
                $value = ($atoms[1..($atoms.Length - 1)] -join ([string]::Empty))
            }

            $e.Cookies[$atoms[0]] = [System.Net.Cookie]::new($atoms[0], $value)
        }

        return $true
    })
}

function Middleware
{
    param (
        [Parameter(Mandatory=$true, Position=0, ParameterSetName='Script')]
        [Parameter(Mandatory=$true, Position=1, ParameterSetName='ScriptRoute')]
        [ValidateNotNull()]
        [scriptblock]
        $ScriptBlock,

        [Parameter(Mandatory=$true, Position=0, ParameterSetName='ScriptRoute')]
        [Parameter(Mandatory=$true, Position=0, ParameterSetName='HashRoute')]
        [Alias('r')]
        [string]
        $Route,

        [Parameter(Mandatory=$true, Position=0, ParameterSetName='Hash')]
        [Parameter(Mandatory=$true, Position=1, ParameterSetName='HashRoute')]
        [Alias('h')]
        [hashtable]
        $HashTable,

        [Parameter()]
        [Alias('n')]
        [string]
        $Name,

        [switch]
        $Return
    )

    # if a name was supplied, ensure it doesn't already exist
    if (!(Test-Empty $Name)) {
        if (($PodeContext.Server.Middleware | Where-Object { $_.Name -ieq $Name } | Measure-Object).Count -gt 0) {
            throw "Middleware with defined name of $($Name) already exists"
        }
    }

    # if route is empty, set it to root
    $Route = Coalesce $Route '/'
    $Route = Split-PodeRouteQuery -Route $Route
    $Route = Coalesce $Route '/'
    $Route = Update-PodeRouteSlashes -Route $Route
    $Route = Update-PodeRoutePlaceholders -Route $Route

    # create the middleware hash, or re-use a passed one
    if (Test-Empty $HashTable)
    {
        $HashTable = @{
            'Name' = $Name;
            'Route' = $Route;
            'Logic' = $ScriptBlock;
        }
    }
    else
    {
        if (Test-Empty $HashTable.Logic) {
            throw 'Middleware supplied has no Logic'
        }

        if (Test-Empty $HashTable.Route) {
            $HashTable.Route = $Route
        }

        if (Test-Empty $HashTable.Name) {
            $HashTable.Name = $Name
        }
    }

    # add the scriptblock to array of middleware that needs to be run
    if ($Return) {
        return $HashTable
    }
    else {
        $PodeContext.Server.Middleware += $HashTable
    }
}