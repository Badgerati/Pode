function Test-PodeRoute
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet('DELETE', 'GET', 'HEAD', 'MERGE', 'OPTIONS', 'PATCH', 'POST', 'PUT', 'TRACE', 'STATIC', '*')]
        [string]
        $Method,

        [Parameter(Mandatory=$true)]
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

function Find-PodeRoute
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet('DELETE', 'GET', 'HEAD', 'MERGE', 'OPTIONS', 'PATCH', 'POST', 'PUT', 'TRACE', 'STATIC', '*')]
        [string]
        $Method,

        [Parameter(Mandatory=$true)]
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
    $found = Get-PodeRouteByUrl -Routes $_method[$Path] -EndpointName $EndpointName
    if (!$isStatic -and ($null -ne $found)) {
        return $found
    }

    # otherwise, attempt to match on regex parameters
    else {
        # match the path to routes on regex (first match only)
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
        $found = Get-PodeRouteByUrl -Routes $_method[$valid] -EndpointName $EndpointName
        if ($null -eq $found) {
            return $null
        }

        return $found
    }
}

function Find-PodePublicRoute
{
    param(
        [Parameter(Mandatory=$true)]
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
        $source = (Join-Path $publicPath $Path)
        if (!(Test-PodePath -Path $source -NoStatus)) {
            $source = $null
        }
    }

    # return the route details
    return $source
}

function Find-PodeStaticRoute
{
    param(
        [Parameter(Mandatory=$true)]
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

        # if there's no file, we need to check defaults
        if (!$found.Download -and !(Test-PodePathIsFile $file) -and (Get-PodeCount @($found.Defaults)) -gt 0)
        {
            if ((Get-PodeCount @($found.Defaults)) -eq 1) {
                $file = Join-PodePaths @($file, @($found.Defaults)[0])
            }
            else {
                foreach ($def in $found.Defaults) {
                    if (Test-PodePath (Join-Path $found.Source $def) -NoStatus) {
                        $file = Join-PodePaths @($file, $def)
                        break
                    }
                }
            }
        }

        $source = (Join-Path $found.Source $file)
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
            Source = $source
            IsDownload = $download
            IsCachable = (Test-PodeRouteValidForCaching -Path $Path)
        }
        Route = $found
    }
}

function Test-PodeRouteValidForCaching
{
    param(
        [Parameter(Mandatory=$true)]
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

function Get-PodeRouteByUrl
{
    param (
        [Parameter()]
        [hashtable[]]
        $Routes,

        [Parameter()]
        [string]
        $EndpointName
    )

    # if routes is already null/empty just return
    if (($null -eq $Routes) -or ($Routes.Length -eq 0)) {
        return $null
    }

    # get the route
    return (Get-PodeRoutesByUrl -Routes $Routes -EndpointName $EndpointName)
}

function Get-PodeRoutesByUrl
{
    param (
        [Parameter()]
        [hashtable[]]
        $Routes,

        [Parameter()]
        [string]
        $EndpointName
    )

    # see if a route has the endpoint name
    if (![string]::IsNullOrWhiteSpace($EndpointName)) {
        foreach ($route in $Routes) {
            if ($route.Endpoint.Name -ieq $EndpointName) {
                return $route
            }
        }
    }

    # else find first default route
    foreach ($route in $Routes) {
        if ([string]::IsNullOrWhiteSpace($route.Endpoint.Name)) {
            return $route
        }
    }

    return $null
}

function Update-PodeRoutePlaceholders
{
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Path
    )

    # replace placeholder parameters with regex
    $placeholder = '\:(?<tag>[\w]+)'
    if ($Path -imatch $placeholder) {
        $Path = [regex]::Escape($Path)
    }

    while ($Path -imatch $placeholder) {
        $Path = ($Path -ireplace $Matches[0], "(?<$($Matches['tag'])>[^\/]+?)")
    }

    return $Path
}

function ConvertTo-PodeOpenApiRoutePath
{
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Path
    )

    # replace placeholder parameters with regex
    $placeholder = '\:(?<tag>[\w]+)'
    if ($Path -imatch $placeholder) {
        $Path = [regex]::Escape($Path)
    }

    while ($Path -imatch $placeholder) {
        $Path = ($Path -ireplace $Matches[0], "{$($Matches['tag'])}")
    }

    return $Path
}

function Update-PodeRouteSlashes
{
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Path,

        [switch]
        $Static
    )

    # ensure route starts with a '/'
    if (!$Path.StartsWith('/')) {
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

function Split-PodeRouteQuery
{
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Path
    )

    return ($Path -isplit "\?")[0]
}

function ConvertTo-PodeRouteRegex
{
    param (
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
    $Path = Update-PodeRoutePlaceholders -Path $Path

    return $Path
}

function Get-PodeStaticRouteDefaults
{
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

function Test-PodeRouteAndError
{
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Method,

        [Parameter(Mandatory=$true)]
        [string]
        $Path,

        [Parameter()]
        [string]
        $Protocol,

        [Parameter()]
        [string]
        $Address
    )

    $found = @($PodeContext.Server.Routes[$Method][$Path])

    if (($found | Where-Object { ($_.Endpoint.Protocol -ieq $Protocol) -and ($_.Endpoint.Address -ieq $Address) } | Measure-Object).Count -eq 0) {
        return
    }

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
    else {
        throw "[$($Method)] $($Path): Already defined for $($_url)"
    }
}

function Convert-PodeFunctionVerbToHttpMethod
{
    param (
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

function Find-PodeRouteTransferEncoding
{
    param(
        [Parameter(Mandatory=$true)]
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

function Find-PodeRouteContentType
{
    param(
        [Parameter(Mandatory=$true)]
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

function ConvertTo-PodeRouteMiddleware
{
    [OutputType([hashtable[]])]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Method,

        [Parameter(Mandatory=$true)]
        [string]
        $Path,

        [Parameter()]
        [object[]]
        $Middleware,

        [Parameter(Mandatory=$true)]
        [System.Management.Automation.SessionState]
        $PSSession
    )

    # return if no middleware
    if (Test-PodeIsEmpty $Middleware) {
        return $null
    }

    # ensure supplied middlewares are either a scriptblock, or a valid hashtable
    @($Middleware) | ForEach-Object {
        # check middleware is a type valid
        if (($_ -isnot [scriptblock]) -and ($_ -isnot [hashtable])) {
            throw "One of the Route Middlewares supplied for the '[$($Method)] $($Path)' Route is an invalid type. Expected either ScriptBlock or Hashtable, but got: $($_.GetType().Name)"
        }

        # if middleware is hashtable, ensure the keys are valid (logic is a scriptblock)
        if ($_ -is [hashtable]) {
            if ($null -eq $_.Logic) {
                throw "A Hashtable Middleware supplied for the '[$($Method)] $($Path)' Route has no Logic defined"
            }

            if ($_.Logic -isnot [scriptblock]) {
                throw "A Hashtable Middleware supplied for the '[$($Method)] $($Path)' Route has an invalid Logic type. Expected ScriptBlock, but got: $($_.Logic.GetType().Name)"
            }
        }
    }

    # if we have middleware, convert scriptblocks to hashtables
    $Middleware = @($Middleware)

    for ($i = 0; $i -lt $Middleware.Length; $i++) {
        if ($Middleware[$i] -is [scriptblock]) {
            $_script, $_usingVars = Invoke-PodeUsingScriptConversion -ScriptBlock $Middleware[$i] -PSSession $PSSession

            $Middleware[$i] = @{
                Logic = $_script
                UsingVariables = $_usingVars
            }
        }
    }

    return $Middleware
}