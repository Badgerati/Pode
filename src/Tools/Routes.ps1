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
        $Route,

        [Parameter()]
        [string]
        $Protocol,

        [Parameter()]
        [string]
        $Endpoint,

        [switch]
        $CheckWildMethod
    )

    # first, if supplied, check the wildcard method
    if ($CheckWildMethod -and $PodeSession.Server.Routes['*'].Count -ne 0) {
        $found = Get-PodeRoute -HttpMethod '*' -Route $Route -Protocol $Protocol -Endpoint $Endpoint
        if ($null -ne $found) {
            return $found
        }
    }

    # is this a static route?
    $isStatic = ($HttpMethod -ieq 'static')

    # first ensure we have the method
    $method = $PodeSession.Server.Routes[$HttpMethod]
    if ($null -eq $method) {
        return $null
    }

    # if we have a perfect match for the route, return it if the protocol is right
    $found = Get-PodeRouteByUrl -Routes $method[$Route] -Protocol $Protocol -Endpoint $Endpoint
    if (!$isStatic -and $null -ne $found) {
        return @{
            'Logic' = $found.Logic;
            'Middleware' = $found.Middleware;
            'Protocol' = $found.Protocol;
            'Endpoint' = $found.Endpoint;
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

        $found = Get-PodeRouteByUrl -Routes $method[$valid] -Protocol $Protocol -Endpoint $Endpoint
        if ($null -eq $found) {
            return $null
        }

        $Route -imatch "$($valid)$" | Out-Null

        if ($isStatic) {
            return @{
                'Path' = $found.Path;
                'Defaults' = $found.Defaults;
                'Protocol' = $found.Protocol;
                'Endpoint' = $found.Endpoint;
                'File' = $Matches['file'];
            }
        }
        else {
            return @{
                'Logic' = $found.Logic;
                'Middleware' = $found.Middleware;
                'Protocol' = $found.Protocol;
                'Endpoint' = $found.Endpoint;
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
        $Route,

        [Parameter()]
        [string]
        $Protocol,

        [Parameter()]
        [string]
        $Endpoint
    )

    # attempt to get a static route for the path
    $found = Get-PodeRoute -HttpMethod 'static' -Route $Route -Protocol $Protocol -Endpoint $Endpoint

    # if we have a defined static route, use that
    if ($null -ne $found) {
        # if there's no file, we need to check defaults
        if ([string]::IsNullOrWhiteSpace($found.File) -and (Get-Count @($found.Defaults)) -gt 0)
        {
            if ((Get-Count @($found.Defaults)) -eq 1) {
                $found.File = @($found.Defaults)[0]
            }
            else {
                foreach ($def in $found.Defaults) {
                    if (Test-PodePath (Join-Path $found.Path $def) -NoStatus) {
                        $found.File = $def
                        break
                    }
                }
            }
        }

        return (Join-Path $found.Path $found.File)
    }

    # else, use the public static directory (but only if path is a file)
    if (Test-PathIsFile $Route) {
        return (Join-Path $PodeSession.Server.InbuiltDrives['public'] $Route)
    }

    # otherwise, just return null
    return $null
}

function Get-PodeRouteByUrl
{
    param (
        [Parameter()]
        [object[]]
        $Routes,

        [Parameter()]
        [string]
        $Protocol,

        [Parameter()]
        [string]
        $Endpoint
    )

    return (@($Routes) |
        Where-Object {
            ($_.Protocol -ieq $Protocol -or [string]::IsNullOrEmpty($_.Protocol)) -and
            ([string]::IsNullOrEmpty($_.Endpoint) -or $Endpoint -ilike $_.Endpoint)
        } |
        Sort-Object -Property { $_.Protocol }, { $_.Endpoint } -Descending |
        Select-Object -First 1)
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
        $Defaults,

        [Parameter()]
        [ValidateSet('', 'HTTP', 'HTTPS')]
        [Alias('p')]
        [string]
        $Protocol,

        [Parameter()]
        [Alias('e')]
        [string]
        $Endpoint,

        [switch]
        [Alias('rm')]
        $Remove
    )

    # uppercase the method
    $HttpMethod = $HttpMethod.ToUpperInvariant()

    # are we removing the route's logic?
    if ($Remove) {
        Remove-PodeRoute -HttpMethod $HttpMethod -Route $Route -Protocol $Protocol -Endpoint $Endpoint
        return
    }

    # add a new dynamic or static route
    if ($HttpMethod -ieq 'static') {
        Add-PodeStaticRoute -Route $Route -Path ([string](@($Middleware))[0]) -Protocol $Protocol -Endpoint $Endpoint -Defaults $Defaults
    }
    else {
        if ((Get-Count $Defaults) -gt 0) {
            throw "[$($HttpMethod)] $($Route) has default static files defined, which is only for [STATIC] routes"
        }

        Add-PodeRoute -HttpMethod $HttpMethod -Route $Route -Middleware $Middleware -ScriptBlock $ScriptBlock -Protocol $Protocol -Endpoint $Endpoint
    }
}

function Remove-PodeRoute
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet('DELETE', 'GET', 'HEAD', 'MERGE', 'OPTIONS', 'PATCH', 'POST', 'PUT', 'TRACE', 'STATIC', '*')]
        [string]
        $HttpMethod,

        [Parameter(Mandatory=$true)]
        [string]
        $Route,

        [Parameter()]
        [string]
        $Protocol,

        [Parameter()]
        [string]
        $Endpoint
    )

    # split route on '?' for query
    $Route = Split-PodeRouteQuery -Route $Route

    # ensure route isn't empty
    if (Test-Empty $Route) {
        throw "No route supplied for removing the $($HttpMethod) definition"
    }

    # ensure the route has appropriate slashes and replace parameters
    $Route = Update-PodeRouteSlashes -Route $Route
    $Route = Update-PodeRoutePlaceholders -Route $Route

    # ensure route does exist
    if (!$PodeSession.Server.Routes[$HttpMethod].ContainsKey($Route)) {
        return
    }

    # remove the route's logic
    $PodeSession.Server.Routes[$HttpMethod][$Route] = @($PodeSession.Server.Routes[$HttpMethod][$Route] | Where-Object {
        !($_.Protocol -ieq $Protocol -and $_.Endpoint -ieq $Endpoint)
    })

    # if the route has no more logic, just remove it
    if ((Get-Count $PodeSession.Server.Routes[$HttpMethod][$Route]) -eq 0) {
        $PodeSession.Server.Routes[$HttpMethod].Remove($Route) | Out-Null
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
        $ScriptBlock,

        [Parameter()]
        [string]
        $Protocol,

        [Parameter()]
        [string]
        $Endpoint
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

    # split route on '?' for query
    $Route = Split-PodeRouteQuery -Route $Route

    # ensure route isn't empty
    if (Test-Empty $Route) {
        throw "No route path supplied for $($HttpMethod) definition"
    }

    # ensure the route has appropriate slashes
    $Route = Update-PodeRouteSlashes -Route $Route
    $Route = Update-PodeRoutePlaceholders -Route $Route

    # ensure route doesn't already exist
    Test-PodeRouteAndError -HttpMethod $HttpMethod -Route $Route -Protocol $Protocol -Endpoint $Endpoint

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
    $PodeSession.Server.Routes[$HttpMethod][$Route] += @(@{
        'Logic' = $ScriptBlock;
        'Middleware' = $Middleware;
        'Protocol' = $Protocol;
        'Endpoint' = $Endpoint.Trim();
    })
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
        $Defaults,

        [Parameter()]
        [string]
        $Protocol,

        [Parameter()]
        [string]
        $Endpoint
    )

    # store the route method
    $HttpMethod = 'static'

    # split route on '?' for query
    $Route = Split-PodeRouteQuery -Route $Route

    # ensure route isn't empty
    if (Test-Empty $Route) {
        throw "No route supplied for $($HttpMethod) definition"
    }

    # if static, ensure the path exists at server root
    if (Test-Empty $Path) {
        throw "No path supplied for $($HttpMethod) definition"
    }

    $Path = (Join-ServerRoot $Path)
    if (!(Test-Path $Path)) {
        throw "Folder supplied for $($HttpMethod) route does not exist: $($Path)"
    }

    # setup a temp drive for the path
    $Path = New-PodePSDrive -Path $Path

    # ensure the route has appropriate slashes
    $Route = Update-PodeRouteSlashes -Route $Route -Static

    # ensure route doesn't already exist
    Test-PodeRouteAndError -HttpMethod $HttpMethod -Route $Route -Protocol $Protocol -Endpoint $Endpoint

    # setup default static files
    if ($null -eq $Defaults) {
        $Defaults = Get-PodeStaticRouteDefaults
    }

    # add the route path
    $PodeSession.Server.Routes[$HttpMethod][$Route] += @(@{
        'Path' = $Path;
        'Defaults' = $Defaults;
        'Protocol' = $Protocol;
        'Endpoint' = $Endpoint.Trim();
    })
}

function Update-PodeRoutePlaceholders
{
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Route
    )

    # replace placeholder parameters with regex
    $placeholder = '\:(?<tag>[\w]+)'
    if ($Route -imatch $placeholder) {
        $Route = [regex]::Escape($Route)
    }

    while ($Route -imatch $placeholder) {
        $Route = ($Route -ireplace $Matches[0], "(?<$($Matches['tag'])>[\w-_]+?)")
    }

    return $Route
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

function Test-PodeRouteAndError
{
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $HttpMethod,

        [Parameter(Mandatory=$true)]
        [string]
        $Route,

        [Parameter()]
        [string]
        $Protocol,

        [Parameter()]
        [string]
        $Endpoint
    )

    $found = @($PodeSession.Server.Routes[$HttpMethod][$Route])

    if (($found | Where-Object { $_.Protocol -ieq $Protocol -and $_.Endpoint -ieq $Endpoint } | Measure-Object).Count -eq 0) {
        return
    }

    $_url = $Protocol
    if (![string]::IsNullOrEmpty($_url) -and ![string]::IsNullOrWhiteSpace($Endpoint)) {
        $_url = "$($_url)://$($Endpoint)"
    }
    elseif (![string]::IsNullOrWhiteSpace($Endpoint)) {
        $_url = $Endpoint
    }

    if ([string]::IsNullOrEmpty($_url)) {
        throw "[$($HttpMethod)] $($Route) is already defined"
    }
    else {
        throw "[$($HttpMethod)] $($Route) is already defined for $($_url)"
    }
}