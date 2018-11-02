function Get-PodeRoute
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet('DELETE', 'GET', 'HEAD', 'MERGE', 'OPTIONS', 'PATCH', 'POST', 'PUT', 'TRACE', 'STATIC', '*')]
        [string]
        $HttpMethod,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Route
    )

    # is this a static route?
    $isStatic = ($HttpMethod -ieq 'static')

    # first ensure we have the method
    $method = $PodeSession.Server.Routes[$HttpMethod]
    if ($null -eq $method) {
        return $null
    }

    # if we have a perfect match for the route, return it
    $found = $method[$Route]
    if (!$isStatic -and $null -ne $found) {
        return @{
            'Logic' = $found.Logic;
            'Middleware' = $found.Middleware;
            'Parameters' = $null;
        }
    }

    # otherwise, attempt to match on regex parameters
    else {
        $valid = ($method.Keys | Where-Object {
            $Route -imatch "^$($_)$"
        } | Select-Object -First 1)

        if ($null -eq $valid) {
            return $null
        }

        $found = $method[$valid]
        $Route -imatch "$($valid)$" | Out-Null

        if ($isStatic) {
            return @{
                'Folder' = $found.Path;
                'Defaults' = $found.Defaults;
                'File' = $Matches['file'];
            }
        }
        else {
            return @{
                'Logic' = $found.Logic;
                'Middleware' = $found.Middleware;
                'Parameters' = $Matches;
            }
        }
    }
}

function Get-PodeStaticRoutePath
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path
    )

    # attempt to get a static route
    $route = Get-PodeRoute -HttpMethod 'static' -Route $Path

    # if we have a defined static route, use that
    if ($null -ne $route) {
        # if there's no file, we need to check defaults
        if ([string]::IsNullOrWhiteSpace($route.File) -and (Get-Count @($route.Defaults)) -gt 0)
        {
            if ((Get-Count @($route.Defaults)) -eq 1) {
                $route.File = @($route.Defaults)[0]
            }
            else {
                foreach ($def in $route.Defaults) {
                    if (Test-PodePath (Join-ServerRoot $route.Folder $def) -NoStatus) {
                        $route.File = $def
                        break
                    }
                }
            }
        }

        return (Join-ServerRoot $route.Folder $route.File)
    }

    # else, use the public static directory (but only if path is a file)
    if (Test-PathIsFile $Path) {
        return (Join-ServerRoot 'public' $Path)
    }

    # otherwise, just return null
    return $null
}

function Route
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet('DELETE', 'GET', 'HEAD', 'MERGE', 'OPTIONS', 'PATCH', 'POST', 'PUT', 'TRACE', 'STATIC', '*')]
        [Alias('hm')]
        [string]
        $HttpMethod,

        [Parameter(Mandatory=$true)]
        [Alias('r')]
        [string]
        $Route,

        [Parameter()]
        [Alias('m')]
        [object[]]
        $Middleware,

        [Parameter()]
        [Alias('s')]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [Alias('d')]
        [string[]]
        $Defaults
    )

    if ($HttpMethod -ieq 'static') {
        Add-PodeStaticRoute -Route $Route -Path ([string](@($Middleware))[0]) -Defaults $Defaults
    }
    else {
        if ((Get-Count $Defaults) -gt 0) {
            throw "[$($HttpMethod)] $($Route) has default static files defined, which is only for [STATIC] routes"
        }

        Add-PodeRoute -HttpMethod $HttpMethod -Route $Route -Middleware $Middleware -ScriptBlock $ScriptBlock
    }
}

function Add-PodeRoute
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet('DELETE', 'GET', 'HEAD', 'MERGE', 'OPTIONS', 'PATCH', 'POST', 'PUT', 'TRACE', '*')]
        [string]
        $HttpMethod,

        [Parameter(Mandatory=$true)]
        [string]
        $Route,

        [Parameter()]
        [object[]]
        $Middleware,

        [Parameter()]
        [scriptblock]
        $ScriptBlock
    )

    # if middleware and scriptblock are null, error
    if ((Test-Empty $Middleware) -and (Test-Empty $ScriptBlock)) {
        throw "[$($HttpMethod)] $($Route) has no logic defined"
    }

    # ensure middleware is either a scriptblock, or a valid hashtable
    if (!(Test-Empty $Middleware)) {
        @($Middleware) | ForEach-Object {
            $_type = (Get-Type $_).Name

            # is the type valid
            if ($_type -ine 'scriptblock' -and $_type -ine 'hashtable') {
                throw "A middleware supplied for the '[$($HttpMethod)] $($Route)' route is of an invalid type. Expected either ScriptBlock or Hashtable, but got: $($_type)"
            }

            # is the hashtable valid
            if ($_type -ieq 'hashtable') {
                if ($null -eq $_.Logic) {
                    throw "A Hashtable middleware supplied for the '[$($HttpMethod)] $($Route)' route has no Logic defined"
                }

                $_ltype = (Get-Type $_.Logic).Name
                if ($_ltype -ine 'scriptblock') {
                    throw "A Hashtable middleware supplied for the '[$($HttpMethod)] $($Route)' route has has an invalid Logic type. Expected ScriptBlock, but got: $($_ltype)"
                }
            }
        }
    }

    # if middleware set, but not scriptblock, set middle and script
    if (!(Test-Empty $Middleware) -and ($null -eq $ScriptBlock)) {
        # if multiple middleware, error
        if ((Get-Type $Middleware).BaseName -ieq 'array' -and (Get-Count $Middleware) -ne 1) {
            throw "[$($HttpMethod)] $($Route) has no logic defined"
        }

        $ScriptBlock = {}
        if ((Get-Type $Middleware[0]).Name -ieq 'scriptblock') {
            $ScriptBlock = $Middleware[0]
            $Middleware = $null
        }
    }

    # lower the method
    $HttpMethod = $HttpMethod.ToLowerInvariant()

    # split route on '?' for query
    $Route = Split-PodeRouteQuery -Route $Route

    # ensure route isn't empty
    if (Test-Empty $Route) {
        throw "No route supplied for $($HttpMethod) definition"
    }

    # ensure the route has appropriate slashes
    $Route = Update-PodeRouteSlashes -Route $Route

    # replace placeholder parameters with regex
    $placeholder = '\:(?<tag>[\w]+)'
    if ($Route -imatch $placeholder) {
        $Route = [regex]::Escape($Route)
    }

    while ($Route -imatch $placeholder) {
        $Route = ($Route -ireplace $Matches[0], "(?<$($Matches['tag'])>[\w-_]+?)")
    }

    # ensure route doesn't already exist
    if ($PodeSession.Server.Routes[$HttpMethod].ContainsKey($Route)) {
        throw "[$($HttpMethod)] $($Route) is already defined"
    }

    # if we have middleware, convert scriptblocks to hashtables
    if (!(Test-Empty $Middleware))
    {
        $Middleware = @($Middleware)

        for ($i = 0; $i -lt $Middleware.Length; $i++) {
            if ((Get-Type $Middleware[$i]).Name -ieq 'scriptblock')
            {
                $Middleware[$i] = @{
                    'Logic' = $Middleware[$i]
                }
            }
        }
    }

    # add the route logic
    $PodeSession.Server.Routes[$HttpMethod][$Route] = @{
        'Logic' = $ScriptBlock;
        'Middleware' = $Middleware;
    }
}

function Add-PodeStaticRoute
{
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Route,

        [Parameter(Mandatory=$true)]
        [string]
        $Path,

        [Parameter()]
        [string[]]
        $Defaults
    )

    # store the route method
    $HttpMethod = 'static'

    # split route on '?' for query
    $Route = Split-PodeRouteQuery -Route $Route

    # ensure route isn't empty
    if (Test-Empty $Route) {
        throw "No route supplied for $($HttpMethod) definition"
    }

    # if static, ensure the path exists
    if (Test-Empty $Path) {
        throw "No path supplied for $($HttpMethod) definition"
    }

    if (!(Test-Path (Join-ServerRoot $Path))) {
        throw "Folder supplied for $($HttpMethod) route does not exist: $($Path)"
    }

    # ensure the route has appropriate slashes
    $Route = Update-PodeRouteSlashes -Route $Route -Static

    # ensure route doesn't already exist
    if ($PodeSession.Server.Routes[$HttpMethod].ContainsKey($Route)) {
        throw "[$($HttpMethod)] $($Route) is already defined"
    }

    # setup default static files
    if ($null -eq $Defaults) {
        $Defaults = Get-PodeStaticRouteDefaults
    }

    # add the route path
    $PodeSession.Server.Routes[$HttpMethod][$Route] = @{
        'Path' = $Path;
        'Defaults' = $Defaults;
    }
}

function Update-PodeRouteSlashes
{
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Route,

        [switch]
        $Static
    )

    # ensure route starts with a '/'
    if (!$Route.StartsWith('/')) {
        $Route = "/$($Route)"
    }

    if ($Static)
    {
        # ensure the route ends with a '/*'
        $Route = $Route.TrimEnd('*')

        if (!$Route.EndsWith('/')) {
            $Route = "$($Route)/"
        }

        $Route = "$($Route)(?<file>*)"
    }

    # replace * with .*
    $Route = ($Route -ireplace '\*', '.*')
    return $Route
}

function Split-PodeRouteQuery
{
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Route
    )

    return ($Route -isplit "\?")[0]
}

function Get-PodeStaticRouteDefaults
{
    $config = $PodeSession.Server.Configuration
    if (!(Test-Empty $config) -and $null -ne $config.web.static.defaults) {
        return @($config.web.static.defaults)
    }

    return @(
        'index.html',
        'index.htm',
        'default.html',
        'default.htm'
    )
}