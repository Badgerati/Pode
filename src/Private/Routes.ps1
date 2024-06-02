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

    # first ensure we have the method
    $_method = $PodeContext.Server.Routes[$Method]
    if ($null -eq $_method) {
        return $null
    }

    # is this a static route?
    $isStatic = ($Method -ieq 'static')

    # if we have a perfect match for the route, return it if the protocol is right
    if (!$isStatic) {
        $found = Get-PodeRouteByUrl -Routes $_method[$Path] -EndpointName $EndpointName
        if ($null -ne $found) {
            return $found
        }
    }

    # otherwise, match the path to routes on regex (first match only)
    $paths = @($_method.Keys)
    if ($isStatic) {
        [array]::Sort($paths)
        [array]::Reverse($paths)
    }

    $valid = @(foreach ($key in $paths) {
            if ($Path -imatch "^$($key)$") {
                $key
                break
            }
        })[0]

    if ($null -eq $valid) {
        return $null
    }

    # is the route valid for any protocols/endpoints?
    $found = Get-PodeRouteByUrl -Routes $_method[$valid] -EndpointName $EndpointName
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


<#
.SYNOPSIS
Finds a static route for a given path in a Pode web server application, with optional checks for public routes.

.DESCRIPTION
This function searches for a static route matching the specified path within a Pode web server application. It attempts to resolve the route to a physical file or directory and supports additional checks for public routes as a fallback option. The function returns a hashtable with route details, including whether the route is for a downloadable file, if it's cacheable, and whether it redirects to a default document.

.PARAMETER Path
The URL path for which to find a static route. This parameter is mandatory.

.PARAMETER EndpointName
Optional. Specifies the name of the endpoint to which the route may belong. If not provided, the function searches across all endpoints.

.PARAMETER CheckPublic
A switch parameter. If specified, the function also checks for the route in public routes as a fallback option.

.EXAMPLE
$staticRoute = Find-PodeStaticRoute -Path '/images/logo.png' -CheckPublic

Searches for a static route for '/images/logo.png'. If not found, checks if a public route exists for the same path.

.EXAMPLE
$staticRoute = Find-PodeStaticRoute -Path '/css/style.css' -EndpointName 'WebUI'

Searches for a static route for '/css/style.css' specifically within the 'WebUI' endpoint, without checking public routes.

.OUTPUTS
Hashtable. Returns a hashtable containing the route details, such as the source path, download flag, cacheability, and redirect status.

.NOTES
This is an internal function and may change in future releases of Pode.
#>
function Find-PodeStaticRoute {
    [CmdletBinding()]
    [OutputType([hashtable])]
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
    $isDefault = $false
    $redirectToDefault = ([bool]$found.RedirectToDefault)

    # if we have a defined static route, use that
    if ($null -ne $found) {
        # see if we have a file
        $file = [string]::Empty

        if ($found.KleeneStar) {
            $matchingPath = "$($found.Path -ireplace '.\*', '.+?')$"
        }
        else {
            $matchingPath = "$($found.Path)$"
        }
        if ($Path -imatch $matchingPath) {
            $file = (Protect-PodeValue -Value $Matches['file'] -Default ([string]::Empty))
        }

        $fileInfo = Get-Item -Path ([System.IO.Path]::Combine($found.Source, $file)) -Force -ErrorAction Ignore
        #if $file doesn't exist return $null
        if ($null -eq $fileInfo) {
            return $null
        }

        # if there's no file, we need to check defaults
        if (!$found.Download -and $fileInfo.PSIsContainer -and (Get-PodeCount @($found.Defaults)) -gt 0) {
            foreach ($def in $found.Defaults) {
                $fileInfoDefaultFile = Get-Item -Path ([System.IO.Path]::Combine($fileInfo.FullName, $def)) -Force -ErrorAction Ignore
                if ($fileInfoDefaultFile) {
                    $file = $fileInfoDefaultFile.FullName
                    $isDefault = $true
                    break
                }
            }
        }
        $source = [System.IO.Path]::Combine($found.Source, $file)

    }

    # check public, if flagged
    if ($CheckPublic -and !(Test-PodePath -Path $source -NoStatus)) {
        $source = Find-PodePublicRoute -Path $Path
        $download = $false
        $found = $null
        $isDefault = $false
        $redirectToDefault = $false
    }

    # return nothing if no source
    if ([string]::IsNullOrWhiteSpace($source)) {
        return $null
    }

    # return the route details
    if ($redirectToDefault -and $isDefault) {
        $redirectToDefault = $true
    }
    else {
        $redirectToDefault = $false
    }

    return @{
        Content = @{
            Source            = $source
            IsDownload        = $download
            IsCachable        = (Test-PodeRouteValidForCaching -Path $Path)
            RedirectToDefault = $redirectToDefault
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
        $EndpointName
    )

    # Return null immediately if routes are not defined or empty
    if (($null -eq $Routes) -or ($Routes.Length -eq 0)) {
        return $null
    }

    # Handle case when no specific endpoint name is provided
    if ([string]::IsNullOrWhiteSpace($EndpointName)) {
        foreach ($route in $Routes) {
            # Return the first route as a default if no path is specified
            return $route
        }
    }
    else {
        # Handle case when an endpoint name is provided
        foreach ($route in $Routes) {
            if (  $route.Endpoint.Name -ieq $EndpointName) {
                # Return the first route that matches the endpoint name as a default
                return $route
            }
        }
    }

    # Last resort check only route with no endpoint name
    foreach ($route in $Routes) {
        if ([string]::IsNullOrWhiteSpace($route.Endpoint.Name)) {
            # Return the first route that matches the endpoint name as a default
            return $route
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

function Get-PodeStaticRouteDefault {
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
        throw ($PodeLocale.methodPathAlreadyDefinedExceptionMessage -f $Method, $Path) #"[$($Method)] $($Path): Already defined"
    }

    throw ($PodeLocale.methodPathAlreadyDefinedForUrlExceptionMessage -f $Method, $Path, $_url) #"[$($Method)] $($Path): Already defined for $($_url)"
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


<#
.SYNOPSIS
Finds and returns the appropriate transfer encoding for a given route path in a Pode server context.

.DESCRIPTION
This function determines the correct transfer encoding for a specified route path within a Pode web server. It checks if a transfer encoding is already specified and returns it; otherwise, it defaults to the server's default transfer encoding. The function searches the server's transfer encoding route settings for a pattern that matches the given path. If a match is found, the corresponding transfer encoding is returned. This is useful for dynamically setting response encodings based on specific route patterns.

.PARAMETER Path
The route path for which the transfer encoding is being determined. This parameter is mandatory.

.PARAMETER TransferEncoding
The current transfer encoding, if already determined. This is an optional parameter. If specified and not null or whitespace, this function returns the given value without further processing.

.EXAMPLE
$encoding = Find-PodeRouteTransferEncoding -Path "/api/data" -TransferEncoding "chunked"

This example determines the transfer encoding for the route "/api/data", with an initial encoding of "chunked". If "/api/data" matches a specific pattern in the server's transfer encoding settings, the corresponding encoding is returned; otherwise, "chunked" is returned.

.OUTPUTS
String. Returns the determined transfer encoding for the given route path. This will be either the input TransferEncoding (if provided and valid), a matched encoding from the server's settings, or the server's default transfer encoding.

.NOTES
- The function uses a case-insensitive match (`-imatch`) to find the first route key pattern that matches the specified path.
- This is an internal function and may change in future releases of Pode.
#>
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
    $matched = $null
    foreach ($key in $PodeContext.Server.Web.TransferEncoding.Routes.Keys) {
        if ($Path -imatch $key) {
            $matched = $key
            break
        }
    }

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
    $matched = $null
    foreach ($key in $PodeContext.Server.Web.ContentType.Routes.Keys) {
        if ($Path -imatch $key) {
            $matched = $key
            break
        }
    }

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
            throw ($PodeLocale.invalidMiddlewareTypeExceptionMessage -f $mid.GetType().Name)#"One of the Middlewares supplied is an invalid type. Expected either a ScriptBlock or Hashtable, but got: $($mid.GetType().Name)"
        }

        # if middleware is hashtable, ensure the keys are valid (logic is a scriptblock)
        if ($mid -is [hashtable]) {
            if ($null -eq $mid.Logic) {
                # A Hashtable Middleware supplied has no Logic defined
                throw $PodeLocale.hashtableMiddlewareNoLogicExceptionMessage
            }

            if ($mid.Logic -isnot [scriptblock]) {
                # A Hashtable Middleware supplied has an invalid Logic type. Expected ScriptBlock, but got: {0}
                throw ($PodeLocale.invalidLogicTypeInHashtableMiddlewareExceptionMessage -f $mid.Logic.GetType().Name)
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
    if (![string]::IsNullOrWhiteSpace($script:RouteIfExists) -and ($script:RouteIfExists -ine 'default')) {
        return $script:RouteIfExists
    }

    # global preference
    $globalPref = $PodeContext.Server.Preferences.Routes.IfExists
    if (![string]::IsNullOrWhiteSpace($globalPref) -and ($globalPref -ine 'default')) {
        return $globalPref
    }

    # final global default
    return 'Error'
}