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
    if (Test-Empty $Middleware) {
        return $true
    }

    # filter the middleware down by route (retaining order)
    if (!(Test-Empty $Route))
    {
        $Middleware = @($Middleware | Where-Object {
            (Test-Empty $_.Route) -or
            ($_.Route -ieq '/') -or
            ($_.Route -ieq $Route) -or
            ($Route -imatch "^$($_.Route)$")
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
            $continue = Invoke-ScriptBlock -ScriptBlock $midware.Logic -Arguments $WebEvent -Scoped -Return

            # remove any custom middleware options
            $WebEvent.Middleware.Clear()
        }
        catch {
            status 500
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
    $override = ($PodeSession.Server.Middleware | Where-Object { $_.Name -ieq $Name })

    # if override there, remove it from middleware
    if ($override) {
        $PodeSession.Server.Middleware = @($PodeSession.Server.Middleware | Where-Object { $_.Name -ine $Name })
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
        if (!(Test-IPAccess -IP $s.Request.RemoteEndPoint.Address)) {
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
        if (!(Test-IPLimit -IP $s.Request.RemoteEndPoint.Address)) {
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
        param($s)

        # get the static file path
        $path = Get-PodeStaticRoutePath -Route $s.Path -Protocol $s.Protocol -Endpoint $s.Endpoint
        if ($null -eq $path) {
            return $true
        }

        # write the file to the response
        Write-ToResponseFromFile -Path $path

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

            # route exists
            return $true
        }
    }
}

function Get-PodeBodyMiddleware
{
    return (Get-PodeInbuiltMiddleware -Name '@body' -ScriptBlock {
        param($s)

        try
        {
            # read any post data
            $data = stream ([System.IO.StreamReader]::new($s.Request.InputStream, $s.Request.ContentEncoding)) {
                param($r)
                return $r.ReadToEnd()
            }

            # attempt to parse that data
            $data = ConvertFrom-PodeContent -ContentType $s.Request.ContentType -Content $data

            # set session data
            $s.Data = $data

            # payload parsed
            return $true
        }
        catch [exception]
        {
            status 400
            return $false
        }
    })
}

function Get-PodeQueryMiddleware
{
    return (Get-PodeInbuiltMiddleware -Name '@query' -ScriptBlock {
        param($s)

        try
        {
            # set the query string from the request
            $s.Query = (ConvertFrom-NameValueToHashTable -Collection $s.Request.QueryString)
            return $true
        }
        catch [exception]
        {
            status 400
            return $false
        }
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
        if (($PodeSession.Server.Middleware | Where-Object { $_.Name -ieq $Name } | Measure-Object).Count -gt 0) {
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
        $PodeSession.Server.Middleware += $HashTable
    }
}