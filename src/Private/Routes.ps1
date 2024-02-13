function Test-PodeRouteFromRequest {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('CONNECT', 'DELETE', 'GET', 'HEAD', 'MERGE', 'OPTIONS', 'PATCH', 'POST', 'PUT', 'TRACE', 'STATIC', 'SIGNAL', '*')]
        [string]
        $Method,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path,

        [Parameter()]
        [string]
        $EndpointName,

        [switch]
        $CheckWildMethod
    )

    $route = Find-PodeRoute -Method $Method -Path $Path -EndpointName $EndpointName -CheckWildMethod:$CheckWildMethod
    return ($null -ne $route)
}

function Find-PodeRoute {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('CONNECT', 'DELETE', 'GET', 'HEAD', 'MERGE', 'OPTIONS', 'PATCH', 'POST', 'PUT', 'TRACE', 'STATIC', 'SIGNAL', '*')]
        [string]
        $Method,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path,

        [Parameter()]
        [string]
        $EndpointName,

        [switch]
        $CheckWildMethod
    )

    # first, if supplied, check the wildcard method
    if ($CheckWildMethod -and ($PodeContext.Server.Routes['*'].Count -ne 0)) {
        $found = Find-PodeRoute -Method '*' -Path $Path -EndpointName $EndpointName
        if ($null -ne $found) {
            return $found
        }
    }

    # is this a static route?
    $isStatic = ($Method -ieq 'static')

    # first ensure we have the method
    $_method = $PodeContext.Server.Routes[$Method]
    if ($null -eq $_method) {
        return $null
    }

    # if we have a perfect match for the route, return it if the protocol is right
    $found = Get-PodeRouteByUrl -Routes $_method[$Path] -EndpointName $EndpointName -Path $Path
    if (!$isStatic -and ($null -ne $found)) {
        return $found
    }

    # otherwise, match the path to routes on regex (first match only)
    $valid = @(foreach ($key in $_method.Keys) {
            if ($Path -imatch "^$($key)$") {
                $key
                break
            }
        })[0]

    if ($null -eq $valid) {
        return $null
    }

    # is the route valid for any protocols/endpoints?
    $found = Get-PodeRouteByUrl -Routes $_method[$valid] -EndpointName $EndpointName -Path $Path
    if ($null -eq $found) {
        return $null
    }

    return $found
}

function Find-PodePublicRoute {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Path
    )

    $source = $null
    $publicPath = $PodeContext.Server.InbuiltDrives['public']

    # reutrn null if there is no public directory
    if ([string]::IsNullOrWhiteSpace($publicPath)) {
        return $source
    }

    # use the public static directory (but only if path is a file, and a public dir is present)
    if (Test-PodePathIsFile $Path) {
        $source = [System.IO.Path]::Combine($publicPath, $Path.TrimStart('/', '\'))
        if (!(Test-PodePath -Path $source -NoStatus)) {
            $source = $null
        }
    }

    # return the route details
    return $source
}

function Find-PodeStaticRoute {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Path,

        [Parameter()]
        [string]
        $EndpointName,

        [switch]
        $CheckPublic
    )

    # attempt to get a static route for the path
    $found = Find-PodeRoute -Method 'static' -Path $Path -EndpointName $EndpointName
    $download = ([bool]$found.Download)
    $source = $null

    # if we have a defined static route, use that
    if ($null -ne $found) {
        # see if we have a file
        $file = [string]::Empty
        if ($Path -imatch "$($found.Path)$") {
            $file = (Protect-PodeValue -Value $Matches['file'] -Default ([string]::Empty))
        }
        $fileInfo = Get-Item ([System.IO.Path]::Combine($found.Source, $file)) -ErrorAction Continue

        #if $file doesn't exist return $null
        if ($null -eq $fileInfo) {
            return $null
        }

        # if there's no file, we need to check defaults
        if ( !$found.Download -and $fileInfo.PSIsContainer ) {
            foreach ($def in $found.Defaults) {
                $combine = ([System.IO.Path]::Combine($found.Source, $file, $def))
                if (Test-PodePath -Path $combine -NoStatus) {
                    $source = $combine
                    break
                }
            }
        }
        if ($null -eq $source) {
            $source = [System.IO.Path]::Combine($found.Source, $file)
        }
    }

    # check public, if flagged
    if ($CheckPublic -and !(Test-PodePath -Path $source -NoStatus)) {
        $source = Find-PodePublicRoute -Path $Path
        $download = $false
        $found = $null
    }

    # return nothing if no source
    if ([string]::IsNullOrWhiteSpace($source)) {
        return $null
    }

    # return the route details
    return @{
        Content = @{
            Source     = $source
            IsDownload = $download
            IsCachable = (Test-PodeRouteValidForCaching -Path $Path)
            Root       = $found.Root
        }
        Route   = $found
    }
}

function Find-PodeSignalRoute {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Path,

        [Parameter()]
        [string]
        $EndpointName
    )

    # attempt to get a signal route for the path
    return (Find-PodeRoute -Method 'signal' -Path $Path -EndpointName $EndpointName)
}

function Test-PodeRouteValidForCaching {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Path
    )

    # check current state of caching
    $config = $PodeContext.Server.Web.Static.Cache
    $caching = $config.Enabled

    # if caching, check include/exclude
    if ($caching) {
        if (($null -ne $config.Exclude) -and ($Path -imatch $config.Exclude)) {
            $caching = $false
        }

        if (($null -ne $config.Include) -and ($Path -inotmatch $config.Include)) {
            $caching = $false
        }
    }

    return $caching
}

<#
.SYNOPSIS
Finds and returns a route from an array of routes based on an endpoint name and/or path.

.DESCRIPTION
This function iterates over an array of route definitions to locate a specific route that matches the provided endpoint name and path.
It supports scenarios where only one of the parameters is provided or both. If no matching route is found, or if the routes array is empty or null,
the function returns $null.

.PARAMETER Routes
An array of hashtable objects, each representing a route with potentially defined properties like Root and Endpoint.Name.

.PARAMETER EndpointName
The name of the endpoint to search for within the route definitions. This parameter is optional.

.PARAMETER Path
The path to search for within the route definitions. This parameter is optional and is used to match routes based on their Root property.

.EXAMPLE
$routes = @(
    @{ Root = '/api'; Endpoint = @{ Name = 'GetData' } },
    @{ Root = '/home'; Endpoint = @{ Name = 'Index' } }
)
Get-PodeRouteByUrl -Routes $routes -EndpointName 'GetData'

Returns the route for the '/api' endpoint named 'GetData'.

.EXAMPLE
$routes = @(
    @{ Root = '/api'; Endpoint = @{ Name = 'GetData' } },
    @{ Root = '/home'; Endpoint = @{ Name = 'Index' } }
)
Get-PodeRouteByUrl -Routes $routes -Path '/api'

Returns the route for the '/api' path, regardless of the endpoint name.

.NOTES
The function prioritizes matching both the endpoint name and path but can return a route based on either criterion if the other is unspecified.
#>
function Get-PodeRouteByUrl {
    param(
        [Parameter()]
        [hashtable[]]
        $Routes,

        [Parameter()]
        [string]
        $EndpointName,

        [Parameter()]
        [string]
        $Path
    )

    # Return null immediately if routes are not defined or empty
    if (($null -eq $Routes) -or ($Routes.Length -eq 0)) {
        return $null
    }

    # Handle case when no specific endpoint name is provided
    if ([string]::IsNullOrWhiteSpace($EndpointName)) {
        foreach ($route in $Routes) {
            if ($Path) {
                # Search for a route that matches the provided path
                if ($Path -match $route.Root) {
                    return $route
                }
            }
            else {
                # Return the first route as a default if no path is specified
                return $route
            }
        }
    }
    else {
        # Handle case when an endpoint name is provided
        foreach ($route in $Routes) {
            if (  $route.Endpoint.Name -ieq $EndpointName) {
                if ($Path) {
                    # Search for a route that matches both the provided path and endpoint name
                    if ($Path -match $route.Root) {
                        return $route
                    }
                }
                else {
                    # Return the first route that matches the endpoint name as a default
                    return $route
                }
            }
        }
    }

    # Last resort check only route with no endpoint name 
    foreach ($route in $Routes) {
        if ([string]::IsNullOrWhiteSpace($route.Endpoint.Name)) {
            if ($Path) {
                # Search for a route that matches both the provided path and endpoint name
                if ($Path -match $route.Root) {
                    return $route
                }
            }
            else {
                # Return the first route that matches the endpoint name as a default
                return $route
            }
        }
    }

    # Return null if no matching route is found
    return $null
}


function ConvertTo-PodeOpenApiRoutePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Path
    )

    return (Resolve-PodePlaceholders -Path $Path -Pattern '\:(?<tag>[\w]+)' -Prepend '{' -Append '}')
}

function Update-PodeRouteSlashes {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Path,

        [switch]
        $Static,

        [switch]
        $NoLeadingSlash
    )

    # ensure route starts with a '/'
    if (!$NoLeadingSlash -and !$Path.StartsWith('/')) {
        $Path = "/$($Path)"
    }

    if ($Static) {
        # ensure the static route ends with '/{0,1}.*'
        $Path = $Path.TrimEnd('/*')
        $Path = "$($Path)[/]{0,1}(?<file>*)"
    }

    # replace * with .*
    $Path = ($Path -ireplace '\*', '.*')
    return $Path
}

function Split-PodeRouteQuery {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Path
    )

    return ($Path -isplit '\?')[0]
}

function ConvertTo-PodeRouteRegex {
    param(
        [Parameter()]
        [string]
        $Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return [string]::Empty
    }

    $Path = Protect-PodeValue -Value $Path -Default '/'
    $Path = Split-PodeRouteQuery -Path $Path
    $Path = Protect-PodeValue -Value $Path -Default '/'
    $Path = Update-PodeRouteSlashes -Path $Path
    $Path = Resolve-PodePlaceholders -Path $Path

    return $Path
}

function Get-PodeStaticRouteDefaults {
    if (!(Test-PodeIsEmpty $PodeContext.Server.Web.Static.Defaults)) {
        return @($PodeContext.Server.Web.Static.Defaults)
    }

    return @(
        'index.html',
        'index.htm',
        'default.html',
        'default.htm'
    )
}

function Test-PodeRouteInternal {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Method,

        [Parameter(Mandatory = $true)]
        [string]
        $Path,

        [Parameter()]
        [string]
        $Protocol,

        [Parameter()]
        [string]
        $Address,

        [switch]
        $ThrowError
    )

    # check the routes
    $found = $false
    $routes = @($PodeContext.Server.Routes[$Method][$Path])

    foreach ($route in $routes) {
        if (($route.Endpoint.Protocol -ieq $Protocol) -and ($route.Endpoint.Address -ieq $Address)) {
            $found = $true
            break
        }
    }

    # skip if not found
    if (!$found) {
        return $false
    }

    # do we want to throw an error if found, or skip?
    if (!$ThrowError) {
        return $true
    }

    # throw error
    $_url = $Protocol
    if (![string]::IsNullOrEmpty($_url) -and ![string]::IsNullOrWhiteSpace($Address)) {
        $_url = "$($_url)://$($Address)"
    }
    elseif (![string]::IsNullOrWhiteSpace($Address)) {
        $_url = $Address
    }

    if ([string]::IsNullOrEmpty($_url)) {
        throw "[$($Method)] $($Path): Already defined"
    }

    throw "[$($Method)] $($Path): Already defined for $($_url)"
}

function Convert-PodeFunctionVerbToHttpMethod {
    param(
        [Parameter()]
        [string]
        $Verb
    )

    # if empty, just return default
    switch ($Verb) {
        { $_ -iin @('Find', 'Format', 'Get', 'Join', 'Search', 'Select', 'Split', 'Measure', 'Ping', 'Test', 'Trace') } { 'GET' }
        { $_ -iin @('Set') } { 'PUT' }
        { $_ -iin @('Rename', 'Edit', 'Update') } { 'PATCH' }
        { $_ -iin @('Clear', 'Close', 'Exit', 'Hide', 'Remove', 'Undo', 'Dismount', 'Unpublish', 'Disable', 'Uninstall', 'Unregister') } { 'DELETE' }
        Default { 'POST' }
    }
}

function Find-PodeRouteTransferEncoding {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Path,

        [Parameter()]
        [string]
        $TransferEncoding
    )

    # if we already have one, return it
    if (![string]::IsNullOrWhiteSpace($TransferEncoding)) {
        return $TransferEncoding
    }

    # set the default
    $TransferEncoding = $PodeContext.Server.Web.TransferEncoding.Default

    # find type by pattern from settings
    $matched = ($PodeContext.Server.Web.TransferEncoding.Routes.Keys | Where-Object {
            $Path -imatch $_
        } | Select-Object -First 1)

    # if we get a match, set it
    if (!(Test-PodeIsEmpty $matched)) {
        $TransferEncoding = $PodeContext.Server.Web.TransferEncoding.Routes[$matched]
    }

    return $TransferEncoding
}

function Find-PodeRouteContentType {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Path,

        [Parameter()]
        [string]
        $ContentType
    )

    # if we already have one, return it
    if (![string]::IsNullOrWhiteSpace($ContentType)) {
        return $ContentType
    }

    # set the default
    $ContentType = $PodeContext.Server.Web.ContentType.Default

    # find type by pattern from settings
    $matched = ($PodeContext.Server.Web.ContentType.Routes.Keys | Where-Object {
            $Path -imatch $_
        } | Select-Object -First 1)

    # if we get a match, set it
    if (!(Test-PodeIsEmpty $matched)) {
        $ContentType = $PodeContext.Server.Web.ContentType.Routes[$matched]
    }

    return $ContentType
}

function ConvertTo-PodeMiddleware {
    [OutputType([hashtable[]])]
    param(
        [Parameter()]
        [object[]]
        $Middleware,

        [Parameter(Mandatory = $true)]
        [System.Management.Automation.SessionState]
        $PSSession
    )

    # return if no middleware
    if (Test-PodeIsEmpty $Middleware) {
        return $null
    }

    $Middleware = @($Middleware)

    # ensure supplied middlewares are either a scriptblock, or a valid hashtable
    foreach ($mid in $Middleware) {
        if ($null -eq $mid) {
            continue
        }

        # check middleware is a type valid
        if (($mid -isnot [scriptblock]) -and ($mid -isnot [hashtable])) {
            throw "One of the Middlewares supplied is an invalid type. Expected either a ScriptBlock or Hashtable, but got: $($mid.GetType().Name)"
        }

        # if middleware is hashtable, ensure the keys are valid (logic is a scriptblock)
        if ($mid -is [hashtable]) {
            if ($null -eq $mid.Logic) {
                throw 'A Hashtable Middleware supplied has no Logic defined'
            }

            if ($mid.Logic -isnot [scriptblock]) {
                throw "A Hashtable Middleware supplied has an invalid Logic type. Expected ScriptBlock, but got: $($mid.Logic.GetType().Name)"
            }
        }
    }

    # if we have middleware, convert scriptblocks to hashtables
    $converted = @(for ($i = 0; $i -lt $Middleware.Length; $i++) {
            if ($null -eq $Middleware[$i]) {
                continue
            }

            if ($Middleware[$i] -is [scriptblock]) {
                $_script, $_usingVars = Convert-PodeScopedVariables -ScriptBlock $Middleware[$i] -PSSession $PSSession

                $Middleware[$i] = @{
                    Logic          = $_script
                    UsingVariables = $_usingVars
                }
            }

            $Middleware[$i]
        })

    return $converted
}

function Get-PodeRouteIfExistsPreference {
    # from route groups
    $groupPref = $RouteGroup.IfExists
    if (![string]::IsNullOrWhiteSpace($groupPref) -and ($groupPref -ine 'default')) {
        return $groupPref
    }

    # from Use-PodeRoute
    if (![string]::IsNullOrWhiteSpace($RouteIfExists) -and ($RouteIfExists -ine 'default')) {
        return $RouteIfExists
    }

    # global preference
    $globalPref = $PodeContext.Server.Preferences.Routes.IfExists
    if (![string]::IsNullOrWhiteSpace($globalPref) -and ($globalPref -ine 'default')) {
        return $globalPref
    }

    # final global default
    return 'Error'
}