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
    if ($CheckWildMethod -and $PodeContext.Server.Routes['*'].Count -ne 0) {
        $found = Get-PodeRoute -HttpMethod '*' -Route $Route -Protocol $Protocol -Endpoint $Endpoint
        if ($null -ne $found) {
            return $found
        }
    }

    # is this a static route?
    $isStatic = ($HttpMethod -ieq 'static')

    # first ensure we have the method
    $method = $PodeContext.Server.Routes[$HttpMethod]
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
            'ContentType' = $found.ContentType;
            'ErrorType' = $found.ErrorType;
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
                'Download' = $found.Download;
                'File' = $Matches['file'];
            }
        }
        else {
            return @{
                'Logic' = $found.Logic;
                'Middleware' = $found.Middleware;
                'Protocol' = $found.Protocol;
                'Endpoint' = $found.Endpoint;
                'ContentType' = $found.ContentType;
                'ErrorType' = $found.ErrorType;
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
    $path = $null
    $download = $false

    # if we have a defined static route, use that
    if ($null -ne $found) {
        # is the found route set as download only?
        if ($found.Download) {
            $download = $true
            $path = (Join-Path $found.Path (coalesce $found.File ([string]::Empty)))
        }

        # if there's no file, we need to check defaults
        elseif (!(Test-PodePathIsFile $found.File) -and (Get-PodeCount @($found.Defaults)) -gt 0)
        {
            $found.File = (coalesce $found.File ([string]::Empty))

            if ((Get-PodeCount @($found.Defaults)) -eq 1) {
                $found.File = Join-PodePaths @($found.File, @($found.Defaults)[0])
            }
            else {
                foreach ($def in $found.Defaults) {
                    if (Test-PodePath (Join-Path $found.Path $def) -NoStatus) {
                        $found.File = Join-PodePaths @($found.File, $def)
                        break
                    }
                }
            }
        }

        $path = (Join-Path $found.Path $found.File)
    }

    # else, use the public static directory (but only if path is a file, and a public dir is present)
    elseif ((Test-PodePathIsFile $Route) -and !(Test-Empty $PodeContext.Server.InbuiltDrives['public'])) {
        $path = (Join-Path $PodeContext.Server.InbuiltDrives['public'] $Route)
    }

    # return the route details
    return @{
        'Path' = $path;
        'Download' = $download;
    }
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

        [Parameter()]
        [Alias('ln', 'lid')]
        [string]
        $ListenName,

        [Parameter()]
        [Alias('ctype', 'ct')]
        [string]
        $ContentType,

        [Parameter()]
        [Alias('etype', 'et')]
        [string]
        $ErrorType,

        [Parameter()]
        [Alias('fp')]
        [string]
        $FilePath,

        [switch]
        [Alias('rm')]
        $Remove,

        [switch]
        [Alias('do')]
        $DownloadOnly
    )

    # uppercase the method
    $HttpMethod = $HttpMethod.ToUpperInvariant()

    # if a ListenName was supplied, find it and use it
    if (!(Test-Empty $ListenName)) {
        # ensure it exists
        $found = ($PodeContext.Server.Endpoints | Where-Object { $_.Name -eq $ListenName } | Select-Object -First 1)
        if ($null -eq $found) {
            throw "Listen endpoint with name '$($ListenName)' does not exist"
        }

        # override and set the protocol and endpoint
        $Protocol = $found.Protocol
        $Endpoint = $found.RawAddress
    }

    # if an endpoint was supplied (or used from a listen name), set any appropriate wildcards
    if (!(Test-Empty $Endpoint)) {
        $_endpoint = Get-PodeEndpointInfo -Endpoint $Endpoint -AnyPortOnZero
        $Endpoint = "$($_endpoint.Host):$($_endpoint.Port)"
    }

    # are we removing the route's logic?
    if ($Remove) {
        Remove-PodeRoute -HttpMethod $HttpMethod -Route $Route -Protocol $Protocol -Endpoint $Endpoint
        return
    }

    # add a new dynamic or static route
    if ($HttpMethod -ieq 'static') {
        Add-PodeStaticRoute -Route $Route -Source ([string](@($Middleware))[0]) -Protocol $Protocol `
            -Endpoint $Endpoint -Defaults $Defaults -DownloadOnly:$DownloadOnly
    }
    else {
        # error if defaults are defined
        if ((Get-PodeCount $Defaults) -gt 0) {
            throw "[$($HttpMethod)] $($Route) has default static files defined, which is only for [STATIC] routes"
        }

        # error if download only passed
        if ($DownloadOnly) {
            throw "[$($HttpMethod)] $($Route) is flagged as DownloadOnly, which is only for [STATIC] routes"
        }

        # add the route
        Add-PodeRoute -HttpMethod $HttpMethod -Route $Route -Middleware $Middleware -ScriptBlock $ScriptBlock `
            -Protocol $Protocol -Endpoint $Endpoint -ContentType $ContentType -ErrorType $ErrorType -FilePath $FilePath
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
    if (!$PodeContext.Server.Routes[$HttpMethod].ContainsKey($Route)) {
        return
    }

    # remove the route's logic
    $PodeContext.Server.Routes[$HttpMethod][$Route] = @($PodeContext.Server.Routes[$HttpMethod][$Route] | Where-Object {
        !($_.Protocol -ieq $Protocol -and $_.Endpoint -ieq $Endpoint)
    })

    # if the route has no more logic, just remove it
    if ((Get-PodeCount $PodeContext.Server.Routes[$HttpMethod][$Route]) -eq 0) {
        $PodeContext.Server.Routes[$HttpMethod].Remove($Route) | Out-Null
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
        $Endpoint,

        [Parameter()]
        [string]
        $ContentType,

        [Parameter()]
        [string]
        $ErrorType,

        [Parameter()]
        [string]
        $FilePath
    )

    # if middleware, scriptblock and file path are all null/empty, error
    if ((Test-Empty $Middleware) -and (Test-Empty $ScriptBlock) -and (Test-Empty $FilePath)) {
        throw "[$($HttpMethod)] $($Route) has no scriptblock defined"
    }

    # if both a scriptblock and a file path have been supplied, error
    if (!(Test-Empty $ScriptBlock) -and !(Test-Empty $FilePath)) {
        throw "[$($HttpMethod)] $($Route) has both a ScriptBlock and a FilePath defined"
    }

    # if we have a file path supplied, load that path as a scriptblock
    if (Test-PodePath -Path $FilePath -NoStatus) {
        # if the path is a wildcard or directory, error
        if (!(Test-PodePathIsFile -Path $FilePath -FailOnWildcard)) {
            throw "[$($HttpMethod)] $($Route) cannot have a wildcard or directory FilePath: $($FilePath)"
        }

        $ScriptBlock = [scriptblock](load $FilePath)
    }

    # ensure supplied middlewares are either a scriptblock, or a valid hashtable
    if (!(Test-Empty $Middleware)) {
        @($Middleware) | ForEach-Object {
            $_type = (Get-PodeType $_).Name

            # check middleware is a type valid
            if ($_type -ine 'scriptblock' -and $_type -ine 'hashtable') {
                throw "A middleware supplied for the '[$($HttpMethod)] $($Route)' route is of an invalid type. Expected either ScriptBlock or Hashtable, but got: $($_type)"
            }

            # if middleware is hashtable, ensure the keys are valid (logic is a scriptblock)
            if ($_type -ieq 'hashtable') {
                if ($null -eq $_.Logic) {
                    throw "A Hashtable middleware supplied for the '[$($HttpMethod)] $($Route)' route has no Logic defined"
                }

                $_ltype = (Get-PodeType $_.Logic).Name
                if ($_ltype -ine 'scriptblock') {
                    throw "A Hashtable middleware supplied for the '[$($HttpMethod)] $($Route)' route has has an invalid Logic type. Expected ScriptBlock, but got: $($_ltype)"
                }
            }
        }
    }

    # if middleware is set, but there is no scriptblock, set the middleware as the scriptblock
    if (!(Test-Empty $Middleware) -and ($null -eq $ScriptBlock)) {
        # if multiple middleware, error
        if ((Get-PodeType $Middleware).BaseName -ieq 'array' -and (Get-PodeCount $Middleware) -ne 1) {
            throw "[$($HttpMethod)] $($Route) has no logic defined"
        }

        $ScriptBlock = {}
        if ((Get-PodeType $Middleware[0]).Name -ieq 'scriptblock') {
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
            if ((Get-PodeType $Middleware[$i]).Name -ieq 'scriptblock')
            {
                $Middleware[$i] = @{
                    'Logic' = $Middleware[$i]
                }
            }
        }
    }

    # workout a default content type for the route
    if ((Test-Empty $ContentType) -and !(Test-Empty $PodeContext.Server.Web)) {
        $ContentType = $PodeContext.Server.Web.ContentType.Default

        # find type by pattern
        $matched = ($PodeContext.Server.Web.ContentType.Routes.Keys | Where-Object {
            $Route -imatch $_
        } | Select-Object -First 1)

        if (!(Test-Empty $matched)) {
            $ContentType = $PodeContext.Server.Web.ContentType.Routes[$matched]
        }
    }

    # add the route logic
    $PodeContext.Server.Routes[$HttpMethod][$Route] += @(@{
        'Logic' = $ScriptBlock;
        'Middleware' = $Middleware;
        'Protocol' = $Protocol;
        'Endpoint' = $Endpoint.Trim();
        'ContentType' = $ContentType;
        'ErrorType' = $ErrorType;
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
        $Source,

        [Parameter()]
        [string[]]
        $Defaults,

        [Parameter()]
        [string]
        $Protocol,

        [Parameter()]
        [string]
        $Endpoint,

        [switch]
        $DownloadOnly
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
    if (Test-Empty $Source) {
        throw "No path supplied for $($HttpMethod) definition"
    }

    $Source = (Join-PodeServerRoot $Source)
    if (!(Test-Path $Source)) {
        throw "Source folder supplied for $($HttpMethod) route does not exist: $($Source)"
    }

    # setup a temp drive for the path
    $Source = New-PodePSDrive -Path $Source

    # ensure the route has appropriate slashes
    $Route = Update-PodeRouteSlashes -Route $Route -Static

    # ensure route doesn't already exist
    Test-PodeRouteAndError -HttpMethod $HttpMethod -Route $Route -Protocol $Protocol -Endpoint $Endpoint

    # setup default static files
    if ($null -eq $Defaults) {
        $Defaults = Get-PodeStaticRouteDefaults
    }

    # add the route path
    $PodeContext.Server.Routes[$HttpMethod][$Route] += @(@{
        'Path' = $Source;
        'Defaults' = $Defaults;
        'Protocol' = $Protocol;
        'Endpoint' = $Endpoint.Trim();
        'Download' = $DownloadOnly;
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
        # ensure the static route ends with '/{0,1}.*'
        $Route = $Route.TrimEnd('/*')
        $Route = "$($Route)[/]{0,1}(?<file>*)"
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
    if (!(Test-Empty $PodeContext.Server.Web.Static.Defaults)) {
        return @($PodeContext.Server.Web.Static.Defaults)
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

    $found = @($PodeContext.Server.Routes[$HttpMethod][$Route])

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