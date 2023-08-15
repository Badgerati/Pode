<#
.SYNOPSIS
Adds a Route for a specific HTTP Method(s).

.DESCRIPTION
Adds a Route for a specific HTTP Method(s), with path, that when called with invoke any logic and/or Middleware.

.PARAMETER Method
The HTTP Method of this Route, multiple can be supplied.

.PARAMETER Path
The URI path for the Route.

.PARAMETER Middleware
An array of ScriptBlocks for optional Middleware.

.PARAMETER ScriptBlock
A ScriptBlock for the Route's main logic.

.PARAMETER EndpointName
The EndpointName of an Endpoint(s) this Route should be bound against.

.PARAMETER ContentType
The content type the Route should use when parsing any payloads.

.PARAMETER TransferEncoding
The transfer encoding the Route should use when parsing any payloads.

.PARAMETER ErrorContentType
The content type of any error pages that may get returned.

.PARAMETER FilePath
A literal, or relative, path to a file containing a ScriptBlock for the Route's main logic.

.PARAMETER ArgumentList
An array of arguments to supply to the Route's ScriptBlock.

.PARAMETER Authentication
The name of an Authentication method which should be used as middleware on this Route.

.PARAMETER AllowAnon
If supplied, the Route will allow anonymous access for non-authenticated users.

.PARAMETER Login
If supplied, the Route will be flagged to Authentication as being a Route that handles user logins.

.PARAMETER Logout
If supplied, the Route will be flagged to Authentication as being a Route that handles users logging out.

.PARAMETER PassThru
If supplied, the route created will be returned so it can be passed through a pipe.

.PARAMETER IfExists
Specifies what action to take when a Route already exists. (Default: Default)

.EXAMPLE
Add-PodeRoute -Method Get -Path '/' -ScriptBlock { /* logic */ }

.EXAMPLE
Add-PodeRoute -Method Post -Path '/users/:userId/message' -Middleware (Get-PodeCsrfMiddleware) -ScriptBlock { /* logic */ }

.EXAMPLE
Add-PodeRoute -Method Post -Path '/user' -ContentType 'application/json' -ScriptBlock { /* logic */ }

.EXAMPLE
Add-PodeRoute -Method Post -Path '/user' -ContentType 'application/json' -TransferEncoding gzip -ScriptBlock { /* logic */ }

.EXAMPLE
Add-PodeRoute -Method Get -Path '/api/cpu' -ErrorContentType 'application/json' -ScriptBlock { /* logic */ }

.EXAMPLE
Add-PodeRoute -Method Get -Path '/' -ScriptBlock { /* logic */ } -ArgumentList 'arg1', 'arg2'
#>
function Add-PodeRoute
{
    [CmdletBinding(DefaultParameterSetName='Script')]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('Connect', 'Delete', 'Get', 'Head', 'Merge', 'Options', 'Patch', 'Post', 'Put', 'Trace', '*')]
        [string[]]
        $Method,

        [Parameter(Mandatory=$true)]
        [string]
        $Path,

        [Parameter()]
        [object[]]
        $Middleware,

        [Parameter(ParameterSetName='Script')]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [string[]]
        $EndpointName,

        [Parameter()]
        [string]
        $ContentType,

        [Parameter()]
        [ValidateSet('', 'gzip', 'deflate')]
        [string]
        $TransferEncoding,

        [Parameter()]
        [string]
        $ErrorContentType,

        [Parameter(Mandatory=$true, ParameterSetName='File')]
        [string]
        $FilePath,

        [Parameter()]
        [object[]]
        $ArgumentList,

        [Parameter()]
        [Alias('Auth')]
        [string]
        $Authentication,

        [Parameter()]
        [ValidateSet('Default', 'Error', 'Overwrite', 'Skip')]
        [string]
        $IfExists = 'Default',

        [Parameter()]
        [string[]]
        $Role,

        [Parameter()]
        [string[]]
        $Group,

        [Parameter()]
        [string[]]
        $Scope,

        [Parameter()]
        [string[]]
        $User,

        [switch]
        $AllowAnon,

        [switch]
        $Login,

        [switch]
        $Logout,

        [switch]
        $PassThru
    )

    # check if we have any route group info defined
    if ($null -ne $RouteGroup) {
        if (![string]::IsNullOrWhiteSpace($RouteGroup.Path)) {
            $Path = "$($RouteGroup.Path)$($Path)"
        }

        if ($null -ne $RouteGroup.Middleware) {
            $Middleware = $RouteGroup.Middleware + $Middleware
        }

        if ([string]::IsNullOrWhiteSpace($EndpointName)) {
            $EndpointName = $RouteGroup.EndpointName
        }

        if ([string]::IsNullOrWhiteSpace($ContentType)) {
            $ContentType = $RouteGroup.ContentType
        }

        if ([string]::IsNullOrWhiteSpace($TransferEncoding)) {
            $TransferEncoding = $RouteGroup.TransferEncoding
        }

        if ([string]::IsNullOrWhiteSpace($ErrorContentType)) {
            $ErrorContentType = $RouteGroup.ErrorContentType
        }

        if ([string]::IsNullOrWhiteSpace($Authentication)) {
            $Authentication = $RouteGroup.Authentication
        }

        if ($RouteGroup.AllowAnon) {
            $AllowAnon = $RouteGroup.AllowAnon
        }

        if ($RouteGroup.IfExists -ine 'default') {
            $IfExists = $RouteGroup.IfExists
        }

        if ($null -ne $RouteGroup.Access.Role) {
            $Role = $RouteGroup.Access.Role + $Role
        }

        if ($null -ne $RouteGroup.Access.Group) {
            $Group = $RouteGroup.Access.Group + $Group
        }

        if ($null -ne $RouteGroup.Access.Scope) {
            $Scope = $RouteGroup.Access.Scope + $Scope
        }

        if ($null -ne $RouteGroup.Access.User) {
            $User = $RouteGroup.Access.User + $User
        }

        if ($null -ne $RouteGroup.Access.Custom) {
            $CustomAccess = $RouteGroup.Access.Custom
        }
    }

    # var for new routes created
    $newRoutes = @()

    # store the original path
    $origPath = $Path

    # split route on '?' for query
    $Path = Split-PodeRouteQuery -Path $Path
    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw "No Path supplied for Route"
    }

    # ensure the route has appropriate slashes
    $Path = Update-PodeRouteSlashes -Path $Path
    $OpenApiPath = ConvertTo-PodeOpenApiRoutePath -Path $Path
    $Path = Resolve-PodePlaceholders -Path $Path

    # get endpoints from name
    if (!$PodeContext.Server.FindEndpoints.Route) {
        $PodeContext.Server.FindEndpoints.Route = !(Test-PodeIsEmpty $EndpointName)
    }

    $endpoints = Find-PodeEndpoints -EndpointName $EndpointName

    # get default route IfExists state
    if ($IfExists -ieq 'Default') {
        $IfExists = Get-PodeRouteIfExistsPreference
    }

    # if middleware, scriptblock and file path are all null/empty, error
    if ((Test-PodeIsEmpty $Middleware) -and (Test-PodeIsEmpty $ScriptBlock) -and (Test-PodeIsEmpty $FilePath) -and (Test-PodeIsEmpty $Authentication)) {
        throw "No logic passed for Route: $($Path)"
    }

    # if we have a file path supplied, load that path as a scriptblock
    if ($PSCmdlet.ParameterSetName -ieq 'file') {
        $ScriptBlock = Convert-PodeFileToScriptBlock -FilePath $FilePath
    }

    # check for scoped vars
    $ScriptBlock, $usingVars = Convert-PodeScopedVariables -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState

    # convert any middleware into valid hashtables
    $Middleware = @(ConvertTo-PodeMiddleware -Middleware $Middleware -PSSession $PSCmdlet.SessionState)

    # if an auth name was supplied, setup the auth as the first middleware
    if (![string]::IsNullOrWhiteSpace($Authentication)) {
        if (!(Test-PodeAuth -Name $Authentication)) {
            throw "Authentication method does not exist: $($Authentication)"
        }

        $options = @{
            Name = $Authentication
            Login = $Login
            Logout = $Logout
            Anon = $AllowAnon
        }

        $Middleware = (@(Get-PodeAuthMiddlewareScript | New-PodeMiddleware -ArgumentList $options) + $Middleware)
    }

    # custom access
    if ($null -eq $CustomAccess) {
        $CustomAccess = @{}
    }

    # workout a default content type for the route
    $ContentType = Find-PodeRouteContentType -Path $Path -ContentType $ContentType

    # workout a default transfer encoding for the route
    $TransferEncoding = Find-PodeRouteTransferEncoding -Path $Path -TransferEncoding $TransferEncoding

    # loop through each method
    foreach ($_method in $Method) {
        # ensure the route doesn't already exist for each endpoint
        $endpoints = @(foreach ($_endpoint in $endpoints) {
            $found = Test-PodeRouteInternal -Method $_method -Path $Path -Protocol $_endpoint.Protocol -Address $_endpoint.Address -ThrowError:($IfExists -ieq 'Error')

            if ($found) {
                if ($IfExists -ieq 'Overwrite') {
                    Remove-PodeRoute -Method $_method -Path $origPath -EndpointName $_endpoint.Name
                }

                if ($IfExists -ieq 'Skip') {
                    continue
                }
            }

            $_endpoint
        })

        if (($null -eq $endpoints) -or ($endpoints.Length -eq 0)) {
            continue
        }

        # add the route(s)
        Write-Verbose "Adding Route: [$($_method)] $($Path)"
        $methodRoutes = @(foreach ($_endpoint in $endpoints) {
            @{
                Logic = $ScriptBlock
                UsingVariables = $usingVars
                Middleware = $Middleware
                Authentication = $Authentication
                Access = @{
                    Role = $Role
                    Group = $Group
                    Scope = $Scope
                    User = $User
                    Custom = $CustomAccess
                }
                Endpoint = @{
                    Protocol = $_endpoint.Protocol
                    Address = $_endpoint.Address.Trim()
                    Name = $_endpoint.Name
                }
                ContentType = $ContentType
                TransferEncoding = $TransferEncoding
                ErrorType = $ErrorContentType
                Arguments = $ArgumentList
                Method = $_method
                Path = $Path
                OpenApi = @{
                    Path = $OpenApiPath
                    Responses = @{
                        '200' = @{ description = 'OK' }
                        'default' = @{ description = 'Internal server error' }
                    }
                    Parameters = $null
                    RequestBody = $null
                    Authentication = @()
                }
                IsStatic = $false
                Metrics = @{
                    Requests = @{
                        Total = 0
                        StatusCodes = @{}
                    }
                }
            }
        })

        if (![string]::IsNullOrWhiteSpace($Authentication)) {
            Set-PodeOAAuth -Route $methodRoutes -Name $Authentication
        }

        $PodeContext.Server.Routes[$_method][$Path] += @($methodRoutes)
        if ($PassThru) {
            $newRoutes += $methodRoutes
        }
    }

    # return the routes?
    if ($PassThru) {
        return $newRoutes
    }
}

<#
.SYNOPSIS
Add a static Route for rendering static content.

.DESCRIPTION
Add a static Route for rendering static content. You can also define default pages to display.

.PARAMETER Path
The URI path for the static Route.

.PARAMETER Source
The literal, or relative, path to the directory that contains the static content.

.PARAMETER Middleware
An array of ScriptBlocks for optional Middleware.

.PARAMETER EndpointName
The EndpointName of an Endpoint(s) to bind the static Route against.

.PARAMETER ContentType
The content type the static Route should use when parsing any payloads.

.PARAMETER TransferEncoding
The transfer encoding the static Route should use when parsing any payloads.

.PARAMETER Defaults
An array of default pages to display, such as 'index.html'.

.PARAMETER ErrorContentType
The content type of any error pages that may get returned.

.PARAMETER Authentication
The name of an Authentication method which should be used as middleware on this Route.

.PARAMETER AllowAnon
If supplied, the static route will allow anonymous access for non-authenticated users.

.PARAMETER DownloadOnly
When supplied, all static content on this Route will be attached as downloads - rather than rendered.

.PARAMETER PassThru
If supplied, the static route created will be returned so it can be passed through a pipe.

.PARAMETER IfExists
Specifies what action to take when a Static Route already exists. (Default: Default)

.EXAMPLE
Add-PodeStaticRoute -Path '/assets' -Source './assets'

.EXAMPLE
Add-PodeStaticRoute -Path '/assets' -Source './assets' -Defaults @('index.html')

.EXAMPLE
Add-PodeStaticRoute -Path '/installers' -Source './exes' -DownloadOnly
#>
function Add-PodeStaticRoute
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Path,

        [Parameter(Mandatory=$true)]
        [string]
        $Source,

        [Parameter()]
        [object[]]
        $Middleware,

        [Parameter()]
        [string[]]
        $EndpointName,

        [Parameter()]
        [string]
        $ContentType,

        [Parameter()]
        [ValidateSet('', 'gzip', 'deflate')]
        [string]
        $TransferEncoding,

        [Parameter()]
        [string[]]
        $Defaults,

        [Parameter()]
        [string]
        $ErrorContentType,

        [Parameter()]
        [Alias('Auth')]
        [string]
        $Authentication,

        [Parameter()]
        [ValidateSet('Default', 'Error', 'Overwrite', 'Skip')]
        [string]
        $IfExists = 'Default',

        [switch]
        $AllowAnon,

        [switch]
        $DownloadOnly,

        [switch]
        $PassThru
    )

    # check if we have any route group info defined
    if ($null -ne $RouteGroup) {
        if (![string]::IsNullOrWhiteSpace($RouteGroup.Path)) {
            $Path = "$($RouteGroup.Path)$($Path)"
        }

        if (![string]::IsNullOrWhiteSpace($RouteGroup.Source)) {
            $Source = [System.IO.Path]::Combine($Source, $RouteGroup.Source.TrimStart('\/'))
        }

        if ($null -ne $RouteGroup.Middleware) {
            $Middleware = $RouteGroup.Middleware + $Middleware
        }

        if ([string]::IsNullOrWhiteSpace($EndpointName)) {
            $EndpointName = $RouteGroup.EndpointName
        }

        if ([string]::IsNullOrWhiteSpace($ContentType)) {
            $ContentType = $RouteGroup.ContentType
        }

        if ([string]::IsNullOrWhiteSpace($TransferEncoding)) {
            $TransferEncoding = $RouteGroup.TransferEncoding
        }

        if ([string]::IsNullOrWhiteSpace($ErrorContentType)) {
            $ErrorContentType = $RouteGroup.ErrorContentType
        }

        if ([string]::IsNullOrWhiteSpace($Authentication)) {
            $Authentication = $RouteGroup.Authentication
        }

        if (Test-PodeIsEmpty $Defaults) {
            $Defaults = $RouteGroup.Defaults
        }

        if ($RouteGroup.AllowAnon) {
            $AllowAnon = $RouteGroup.AllowAnon
        }

        if ($RouteGroup.DownloadOnly) {
            $DownloadOnly = $RouteGroup.DownloadOnly
        }

        if ($RouteGroup.IfExists -ine 'default') {
            $IfExists = $RouteGroup.IfExists
        }
    }

    # store the route method
    $Method = 'Static'

    # store the original path
    $origPath = $Path

    # split route on '?' for query
    $Path = Split-PodeRouteQuery -Path $Path
    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw "[$($Method)]: No Path supplied for Static Route"
    }

    # ensure the route has appropriate slashes
    $Path = Update-PodeRouteSlashes -Path $Path -Static
    $OpenApiPath = ConvertTo-PodeOpenApiRoutePath -Path $Path
    $Path = Resolve-PodePlaceholders -Path $Path

    # get endpoints from name
    if (!$PodeContext.Server.FindEndpoints.Route) {
        $PodeContext.Server.FindEndpoints.Route = !(Test-PodeIsEmpty $EndpointName)
    }

    $endpoints = Find-PodeEndpoints -EndpointName $EndpointName

    # get default route IfExists state
    if ($IfExists -ieq 'Default') {
        $IfExists = Get-PodeRouteIfExistsPreference
    }

    # ensure the route doesn't already exist for each endpoint
    $endpoints = @(foreach ($_endpoint in $endpoints) {
        $found = Test-PodeRouteInternal -Method $Method -Path $Path -Protocol $_endpoint.Protocol -Address $_endpoint.Address -ThrowError:($IfExists -ieq 'Error')

        if ($found) {
            if ($IfExists -ieq 'Overwrite') {
                Remove-PodeStaticRoute -Path $origPath -EndpointName $_endpoint.Name
            }

            if ($IfExists -ieq 'Skip') {
                continue
            }
        }

        $_endpoint
    })

    if (($null -eq $endpoints) -or ($endpoints.Length -eq 0)) {
        return
    }

    # if static, ensure the path exists at server root
    $Source = Get-PodeRelativePath -Path $Source -JoinRoot
    if (!(Test-PodePath -Path $Source -NoStatus)) {
        throw "[$($Method))] $($Path): The Source path supplied for Static Route does not exist: $($Source)"
    }

    # setup a temp drive for the path
    $Source = New-PodePSDrive -Path $Source

    # setup default static files
    if ($null -eq $Defaults) {
        $Defaults = Get-PodeStaticRouteDefaults
    }

    # convert any middleware into valid hashtables
    $Middleware = @(ConvertTo-PodeMiddleware -Middleware $Middleware -PSSession $PSCmdlet.SessionState)

    # if an auth name was supplied, setup the auth as the first middleware
    if (![string]::IsNullOrWhiteSpace($Authentication)) {
        if (!(Test-PodeAuth -Name $Authentication)) {
            throw "Authentication method does not exist: $($Authentication)"
        }

        $options = @{
            Name = $Authentication
            Anon = $AllowAnon
        }

        $Middleware = (@(Get-PodeAuthMiddlewareScript | New-PodeMiddleware -ArgumentList $options) + $Middleware)
    }

    # workout a default content type for the route
    $ContentType = Find-PodeRouteContentType -Path $Path -ContentType $ContentType

    # workout a default transfer encoding for the route
    $TransferEncoding = Find-PodeRouteTransferEncoding -Path $Path -TransferEncoding $TransferEncoding

    # add the route(s)
    Write-Verbose "Adding Route: [$($Method)] $($Path)"
    $newRoutes = @(foreach ($_endpoint in $endpoints) {
        @{
            Source = $Source
            Path = $Path
            Method = $Method
            Defaults = $Defaults
            Middleware = $Middleware
            Endpoint = @{
                Protocol = $_endpoint.Protocol
                Address = $_endpoint.Address.Trim()
                Name = $_endpoint.Name
            }
            ContentType = $ContentType
            TransferEncoding = $TransferEncoding
            ErrorType = $ErrorContentType
            Download = $DownloadOnly
            OpenApi = @{
                Path = $OpenApiPath
                Responses = @{
                    '200' = @{ description = 'OK' }
                    'default' = @{ description = 'Internal server error' }
                }
                Parameters = @()
                RequestBody = @{}
                Authentication = @()
            }
            IsStatic = $true
            Metrics = @{
                Requests = @{
                    Total = 0
                    StatusCodes = @{}
                }
            }
        }
    })

    if (![string]::IsNullOrWhiteSpace($Authentication)) {
        Set-PodeOAAuth -Route $newRoutes -Name $Authentication
    }

    $PodeContext.Server.Routes[$Method][$Path] += @($newRoutes)

    # return the routes?
    if ($PassThru) {
        return $newRoutes
    }
}

<#
.SYNOPSIS
Adds a Signal Route for WebSockets.

.DESCRIPTION
Adds a Signal Route, with path, that when called with invoke any logic.

.PARAMETER Path
The URI path for the Signal Route.

.PARAMETER ScriptBlock
A ScriptBlock for the Signal Route's main logic.

.PARAMETER EndpointName
The EndpointName of an Endpoint(s) this Signal Route should be bound against.

.PARAMETER FilePath
A literal, or relative, path to a file containing a ScriptBlock for the Signal Route's main logic.

.PARAMETER ArgumentList
An array of arguments to supply to the Signal Route's ScriptBlock.

.PARAMETER IfExists
Specifies what action to take when a Signal Route already exists. (Default: Default)

.EXAMPLE
Add-PodeSignalRoute -Path '/message' -ScriptBlock { /* logic */ }

.EXAMPLE
Add-PodeSignalRoute -Path '/message' -ScriptBlock { /* logic */ } -ArgumentList 'arg1', 'arg2'
#>
function Add-PodeSignalRoute
{
    [CmdletBinding(DefaultParameterSetName='Script')]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Path,

        [Parameter(ParameterSetName='Script')]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [string[]]
        $EndpointName,

        [Parameter(Mandatory=$true, ParameterSetName='File')]
        [string]
        $FilePath,

        [Parameter()]
        [object[]]
        $ArgumentList,

        [Parameter()]
        [ValidateSet('Default', 'Error', 'Overwrite', 'Skip')]
        [string]
        $IfExists = 'Default'
    )

    # check if we have any route group info defined
    if ($null -ne $RouteGroup) {
        if (![string]::IsNullOrWhiteSpace($RouteGroup.Path)) {
            $Path = "$($RouteGroup.Path)$($Path)"
        }

        if ([string]::IsNullOrWhiteSpace($EndpointName)) {
            $EndpointName = $RouteGroup.EndpointName
        }

        if ($RouteGroup.IfExists -ine 'default') {
            $IfExists = $RouteGroup.IfExists
        }
    }

    $Method = 'Signal'

    # store the original path
    $origPath = $Path

    # ensure the route has appropriate slashes
    $Path = Update-PodeRouteSlashes -Path $Path

    # get endpoints from name
    if (!$PodeContext.Server.FindEndpoints.Route) {
        $PodeContext.Server.FindEndpoints.Route = !(Test-PodeIsEmpty $EndpointName)
    }

    $endpoints = Find-PodeEndpoints -EndpointName $EndpointName

    # get default route IfExists state
    if ($IfExists -ieq 'Default') {
        $IfExists = Get-PodeRouteIfExistsPreference
    }

    # ensure the route doesn't already exist for each endpoint
    $endpoints = @(foreach ($_endpoint in $endpoints) {
        $found = Test-PodeRouteInternal -Method $Method -Path $Path -Protocol $_endpoint.Protocol -Address $_endpoint.Address -ThrowError:($IfExists -ieq 'Error')

        if ($found) {
            if ($IfExists -ieq 'Overwrite') {
                Remove-PodeSignalRoute -Path $origPath -EndpointName $_endpoint.Name
            }

            if ($IfExists -ieq 'Skip') {
                continue
            }
        }

        $_endpoint
    })

    if (($null -eq $endpoints) -or ($endpoints.Length -eq 0)) {
        return
    }

    # if scriptblock and file path are all null/empty, error
    if ((Test-PodeIsEmpty $ScriptBlock) -and (Test-PodeIsEmpty $FilePath)) {
        throw "[$($Method)] $($Path): No logic passed"
    }

    # if we have a file path supplied, load that path as a scriptblock
    if ($PSCmdlet.ParameterSetName -ieq 'file') {
        $ScriptBlock = Convert-PodeFileToScriptBlock -FilePath $FilePath
    }

    # check for scoped vars
    $ScriptBlock, $usingVars = Convert-PodeScopedVariables -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState

    # add the route(s)
    Write-Verbose "Adding Route: [$($Method)] $($Path)"
    $newRoutes = @(foreach ($_endpoint in $endpoints) {
        @{
            Logic = $ScriptBlock
            UsingVariables = $usingVars
            Endpoint = @{
                Protocol = $_endpoint.Protocol
                Address = $_endpoint.Address.Trim()
                Name = $_endpoint.Name
            }
            Arguments = $ArgumentList
            Method = $Method
            Path = $Path
            IsStatic = $false
            Metrics = @{
                Requests = @{
                    Total = 0
                }
            }
        }
    })

    $PodeContext.Server.Routes[$Method][$Path] += @($newRoutes)
}

<#
.SYNOPSIS
Add a Route Group for multiple Routes.

.DESCRIPTION
Add a Route Group for sharing values between multiple Routes.

.PARAMETER Path
The URI path to use as a base for the Routes, that should be prepended.

.PARAMETER Routes
A ScriptBlock for adding Routes.

.PARAMETER Middleware
An array of ScriptBlocks for optional Middleware to give each Route.

.PARAMETER EndpointName
The EndpointName of an Endpoint(s) to use for the Routes.

.PARAMETER ContentType
The content type to use for the Routes, when parsing any payloads.

.PARAMETER TransferEncoding
The transfer encoding to use for the Routes, when parsing any payloads.

.PARAMETER ErrorContentType
The content type of any error pages that may get returned.

.PARAMETER Authentication
The name of an Authentication method which should be used as middleware on the Routes.

.PARAMETER IfExists
Specifies what action to take when a Route already exists. (Default: Default)

.PARAMETER AllowAnon
If supplied, the Routes will allow anonymous access for non-authenticated users.

.EXAMPLE
Add-PodeRouteGroup -Path '/api' -Routes { Add-PodeRoute -Path '/route1' -Etc }
#>
function Add-PodeRouteGroup
{
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Path,

        [Parameter(Mandatory=$true)]
        [scriptblock]
        $Routes,

        [Parameter()]
        [object[]]
        $Middleware,

        [Parameter()]
        [string[]]
        $EndpointName,

        [Parameter()]
        [string]
        $ContentType,

        [Parameter()]
        [ValidateSet('', 'gzip', 'deflate')]
        [string]
        $TransferEncoding,

        [Parameter()]
        [string]
        $ErrorContentType,

        [Parameter()]
        [Alias('Auth')]
        [string]
        $Authentication,

        [Parameter()]
        [ValidateSet('Default', 'Error', 'Overwrite', 'Skip')]
        [string]
        $IfExists = 'Default',

        [Parameter()]
        [string[]]
        $Role,

        [Parameter()]
        [string[]]
        $Group,

        [Parameter()]
        [string[]]
        $Scope,

        [Parameter()]
        [string[]]
        $User,

        [switch]
        $AllowAnon
    )

    if (Test-PodeIsEmpty $Routes) {
        throw "No scriptblock for -Routes passed"
    }

    if ($Path -eq '/') {
        $Path = $null
    }

    # check for scoped vars
    $Routes, $usingVars = Convert-PodeScopedVariables -ScriptBlock $Routes -PSSession $PSCmdlet.SessionState

    # group details
    if ($null -ne $RouteGroup) {
        if (![string]::IsNullOrWhiteSpace($RouteGroup.Path)) {
            $Path = "$($RouteGroup.Path)$($Path)"
        }

        if ($null -ne $RouteGroup.Middleware) {
            $Middleware = $RouteGroup.Middleware + $Middleware
        }

        if ([string]::IsNullOrWhiteSpace($EndpointName)) {
            $EndpointName = $RouteGroup.EndpointName
        }

        if ([string]::IsNullOrWhiteSpace($ContentType)) {
            $ContentType = $RouteGroup.ContentType
        }

        if ([string]::IsNullOrWhiteSpace($TransferEncoding)) {
            $TransferEncoding = $RouteGroup.TransferEncoding
        }

        if ([string]::IsNullOrWhiteSpace($ErrorContentType)) {
            $ErrorContentType = $RouteGroup.ErrorContentType
        }

        if ([string]::IsNullOrWhiteSpace($Authentication)) {
            $Authentication = $RouteGroup.Authentication
        }

        if ($RouteGroup.AllowAnon) {
            $AllowAnon = $RouteGroup.AllowAnon
        }

        if ($RouteGroup.IfExists -ine 'default') {
            $IfExists = $RouteGroup.IfExists
        }

        if ($null -ne $RouteGroup.Access.Role) {
            $Role = $RouteGroup.Access.Role + $Role
        }

        if ($null -ne $RouteGroup.Access.Group) {
            $Group = $RouteGroup.Access.Group + $Group
        }

        if ($null -ne $RouteGroup.Access.Scope) {
            $Scope = $RouteGroup.Access.Scope + $Scope
        }

        if ($null -ne $RouteGroup.Access.User) {
            $User = $RouteGroup.Access.User + $User
        }

        if ($null -ne $RouteGroup.Access.Custom) {
            $CustomAccess = $RouteGroup.Access.Custom
        }
    }

    $RouteGroup = @{
        Path = $Path
        Middleware = $Middleware
        EndpointName = $EndpointName
        ContentType = $ContentType
        TransferEncoding = $TransferEncoding
        ErrorContentType = $ErrorContentType
        Authentication = $Authentication
        AllowAnon = $AllowAnon
        IfExists = $IfExists
        Access = @{
            Role = $Role
            Group = $Group
            Scope = $Scope
            User = $User
            Custom = $CustomAccess
        }
    }

    # add routes
    $_args = @(Get-PodeScriptblockArguments -UsingVariables $usingVars)
    $null = Invoke-PodeScriptBlock -ScriptBlock $Routes -Arguments $_args -Splat
}

<#
.SYNOPSIS
Add a Static Route Group for multiple Static Routes.

.DESCRIPTION
Add a Static Route Group for sharing values between multiple Static Routes.

.PARAMETER Path
The URI path to use as a base for the Static Routes.

.PARAMETER Source
A literal, or relative, base path to the directory that contains the static content, that should be prepended.

.PARAMETER Routes
A ScriptBlock for adding Static Routes.

.PARAMETER Middleware
An array of ScriptBlocks for optional Middleware to give each Static Route.

.PARAMETER EndpointName
The EndpointName of an Endpoint(s) to use for the Static Routes.

.PARAMETER ContentType
The content type to use for the Static Routes, when parsing any payloads.

.PARAMETER TransferEncoding
The transfer encoding to use for the Static Routes, when parsing any payloads.

.PARAMETER Defaults
An array of default pages to display, such as 'index.html', for each Static Route.

.PARAMETER ErrorContentType
The content type of any error pages that may get returned.

.PARAMETER Authentication
The name of an Authentication method which should be used as middleware on the Static Routes.

.PARAMETER IfExists
Specifies what action to take when a Static Route already exists. (Default: Default)

.PARAMETER AllowAnon
If supplied, the Static Routes will allow anonymous access for non-authenticated users.

.PARAMETER DownloadOnly
When supplied, all static content on the Routes will be attached as downloads - rather than rendered.

.EXAMPLE
Add-PodeStaticRouteGroup -Path '/static' -Routes { Add-PodeStaticRoute -Path '/images' -Etc }
#>
function Add-PodeStaticRouteGroup
{
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Path,

        [Parameter()]
        [string]
        $Source,

        [Parameter(Mandatory=$true)]
        [scriptblock]
        $Routes,

        [Parameter()]
        [object[]]
        $Middleware,

        [Parameter()]
        [string[]]
        $EndpointName,

        [Parameter()]
        [string]
        $ContentType,

        [Parameter()]
        [ValidateSet('', 'gzip', 'deflate')]
        [string]
        $TransferEncoding,

        [Parameter()]
        [string[]]
        $Defaults,

        [Parameter()]
        [string]
        $ErrorContentType,

        [Parameter()]
        [Alias('Auth')]
        [string]
        $Authentication,

        [Parameter()]
        [ValidateSet('Default', 'Error', 'Overwrite', 'Skip')]
        [string]
        $IfExists = 'Default',

        [switch]
        $AllowAnon,

        [switch]
        $DownloadOnly
    )

    if (Test-PodeIsEmpty $Routes) {
        throw "No scriptblock for -Routes passed"
    }

    if ($Path -eq '/') {
        $Path = $null
    }

    # check for scoped vars
    $Routes, $usingVars = Convert-PodeScopedVariables -ScriptBlock $Routes -PSSession $PSCmdlet.SessionState

    # group details
    if ($null -ne $RouteGroup) {
        if (![string]::IsNullOrWhiteSpace($RouteGroup.Path)) {
            $Path = "$($RouteGroup.Path)$($Path)"
        }

        if (![string]::IsNullOrWhiteSpace($RouteGroup.Source)) {
            $Source = [System.IO.Path]::Combine($Source, $RouteGroup.Source.TrimStart('\/'))
        }

        if ($null -ne $RouteGroup.Middleware) {
            $Middleware = $RouteGroup.Middleware + $Middleware
        }

        if ([string]::IsNullOrWhiteSpace($EndpointName)) {
            $EndpointName = $RouteGroup.EndpointName
        }

        if ([string]::IsNullOrWhiteSpace($ContentType)) {
            $ContentType = $RouteGroup.ContentType
        }

        if ([string]::IsNullOrWhiteSpace($TransferEncoding)) {
            $TransferEncoding = $RouteGroup.TransferEncoding
        }

        if ([string]::IsNullOrWhiteSpace($ErrorContentType)) {
            $ErrorContentType = $RouteGroup.ErrorContentType
        }

        if ([string]::IsNullOrWhiteSpace($Authentication)) {
            $Authentication = $RouteGroup.Authentication
        }

        if (Test-PodeIsEmpty $Defaults) {
            $Defaults = $RouteGroup.Defaults
        }

        if ($RouteGroup.AllowAnon) {
            $AllowAnon = $RouteGroup.AllowAnon
        }

        if ($RouteGroup.DownloadOnly) {
            $DownloadOnly = $RouteGroup.DownloadOnly
        }

        if ($RouteGroup.IfExists -ine 'default') {
            $IfExists = $RouteGroup.IfExists
        }
    }

    $RouteGroup = @{
        Path = $Path
        Source = $Source
        Middleware = $Middleware
        EndpointName = $EndpointName
        ContentType = $ContentType
        TransferEncoding = $TransferEncoding
        Defaults = $Defaults
        ErrorContentType = $ErrorContentType
        Authentication = $Authentication
        AllowAnon = $AllowAnon
        DownloadOnly = $DownloadOnly
        IfExists = $IfExists
    }

    # add routes
    $_args = @(Get-PodeScriptblockArguments -UsingVariables $usingVars)
    $null = Invoke-PodeScriptBlock -ScriptBlock $Routes -Arguments $_args -Splat
}


<#
.SYNOPSIS
Adds a Signal Route Group for multiple WebSockets.

.DESCRIPTION
Adds a Signal Route Group for sharing values between multiple WebSockets.

.PARAMETER Path
The URI path to use as a base for the Signal Routes, that should be prepended.

.PARAMETER Routes
A ScriptBlock for adding Signal Routes.

.PARAMETER EndpointName
The EndpointName of an Endpoint(s) to use for the Signal Routes.

.PARAMETER IfExists
Specifies what action to take when a Signal Route already exists. (Default: Default)

.EXAMPLE
Add-PodeSignalRouteGroup -Path '/signals' -Routes { Add-PodeSignalRoute -Path '/signal1' -Etc }
#>
function Add-PodeSignalRouteGroup
{
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Path,

        [Parameter(Mandatory=$true)]
        [scriptblock]
        $Routes,

        [Parameter()]
        [string[]]
        $EndpointName,

        [Parameter()]
        [ValidateSet('Default', 'Error', 'Overwrite', 'Skip')]
        [string]
        $IfExists = 'Default'
    )

    if (Test-PodeIsEmpty $Routes) {
        throw "No scriptblock for -Routes passed"
    }

    if ($Path -eq '/') {
        $Path = $null
    }

    # check for scoped vars
    $Routes, $usingVars = Convert-PodeScopedVariables -ScriptBlock $Routes -PSSession $PSCmdlet.SessionState

    # group details
    if ($null -ne $RouteGroup) {
        if (![string]::IsNullOrWhiteSpace($RouteGroup.Path)) {
            $Path = "$($RouteGroup.Path)$($Path)"
        }

        if ([string]::IsNullOrWhiteSpace($EndpointName)) {
            $EndpointName = $RouteGroup.EndpointName
        }

        if ($RouteGroup.IfExists -ine 'default') {
            $IfExists = $RouteGroup.IfExists
        }
    }

    $RouteGroup = @{
        Path = $Path
        EndpointName = $EndpointName
        IfExists = $IfExists
    }

    # add routes
    $_args = @(Get-PodeScriptblockArguments -UsingVariables $usingVars)
    $null = Invoke-PodeScriptBlock -ScriptBlock $Routes -Arguments $_args -Splat
}

<#
.SYNOPSIS
Remove a specific Route.

.DESCRIPTION
Remove a specific Route.

.PARAMETER Method
The method of the Route to remove.

.PARAMETER Path
The path of the Route to remove.

.PARAMETER EndpointName
The EndpointName of an Endpoint(s) bound to the Route to be removed.

.EXAMPLE
Remove-PodeRoute -Method Get -Route '/about'

.EXAMPLE
Remove-PodeRoute -Method Post -Route '/users/:userId' -EndpointName User
#>
function Remove-PodeRoute
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('Connect', 'Delete', 'Get', 'Head', 'Merge', 'Options', 'Patch', 'Post', 'Put', 'Trace', '*')]
        [string]
        $Method,

        [Parameter(Mandatory=$true)]
        [string]
        $Path,

        [Parameter()]
        [string]
        $EndpointName
    )

    # split route on '?' for query
    $Path = Split-PodeRouteQuery -Path $Path
    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw "[$($Method)]: No Route path supplied for removing a Route"
    }

    # ensure the route has appropriate slashes and replace parameters
    $Path = Update-PodeRouteSlashes -Path $Path
    $Path = Resolve-PodePlaceholders -Path $Path

    # ensure route does exist
    if (!$PodeContext.Server.Routes[$Method].Contains($Path)) {
        return
    }

    # remove the route's logic
    $PodeContext.Server.Routes[$Method][$Path] = @($PodeContext.Server.Routes[$Method][$Path] | Where-Object {
        $_.Endpoint.Name -ine $EndpointName
    })

    # if the route has no more logic, just remove it
    if ((Get-PodeCount $PodeContext.Server.Routes[$Method][$Path]) -eq 0) {
        $null = $PodeContext.Server.Routes[$Method].Remove($Path)
    }
}

<#
.SYNOPSIS
Remove a specific static Route.

.DESCRIPTION
Remove a specific static Route.

.PARAMETER Path
The path of the static Route to remove.

.PARAMETER EndpointName
The EndpointName of an Endpoint(s) bound to the static Route to be removed.

.EXAMPLE
Remove-PodeStaticRoute -Path '/assets'
#>
function Remove-PodeStaticRoute
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Path,

        [Parameter()]
        [string]
        $EndpointName
    )

    $Method = 'Static'

    # ensure the route has appropriate slashes and replace parameters
    $Path = Update-PodeRouteSlashes -Path $Path -Static

    # ensure route does exist
    if (!$PodeContext.Server.Routes[$Method].Contains($Path)) {
        return
    }

    # remove the route's logic
    $PodeContext.Server.Routes[$Method][$Path] = @($PodeContext.Server.Routes[$Method][$Path] | Where-Object {
        $_.Endpoint.Name -ine $EndpointName
    })

    # if the route has no more logic, just remove it
    if ((Get-PodeCount $PodeContext.Server.Routes[$Method][$Path]) -eq 0) {
        $null = $PodeContext.Server.Routes[$Method].Remove($Path)
    }
}

<#
.SYNOPSIS
Remove a specific Signal Route.

.DESCRIPTION
Remove a specific Signal Route.

.PARAMETER Path
The path of the Signal Route to remove.

.PARAMETER EndpointName
The EndpointName of an Endpoint(s) bound to the Signal Route to be removed.

.EXAMPLE
Remove-PodeSignalRoute -Route '/message'
#>
function Remove-PodeSignalRoute
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Path,

        [Parameter()]
        [string]
        $EndpointName
    )

    $Method = 'Signal'

    # ensure the route has appropriate slashes and replace parameters
    $Path = Update-PodeRouteSlashes -Path $Path

    # ensure route does exist
    if (!$PodeContext.Server.Routes[$Method].Contains($Path)) {
        return
    }

    # remove the route's logic
    $PodeContext.Server.Routes[$Method][$Path] = @($PodeContext.Server.Routes[$Method][$Path] | Where-Object {
        $_.Endpoint.Name -ine $EndpointName
    })

    # if the route has no more logic, just remove it
    if ((Get-PodeCount $PodeContext.Server.Routes[$Method][$Path]) -eq 0) {
        $null = $PodeContext.Server.Routes[$Method].Remove($Path)
    }
}

<#
.SYNOPSIS
Removes all added Routes, or Routes for a specific Method.

.DESCRIPTION
Removes all added Routes, or Routes for a specific Method.

.PARAMETER Method
The Method to from which to remove all Routes.

.EXAMPLE
Clear-PodeRoutes

.EXAMPLE
Clear-PodeRoutes -Method Get
#>
function Clear-PodeRoutes
{
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateSet('', 'Connect', 'Delete', 'Get', 'Head', 'Merge', 'Options', 'Patch', 'Post', 'Put', 'Trace', '*')]
        [string]
        $Method
    )

    if (![string]::IsNullOrWhiteSpace($Method)) {
        $PodeContext.Server.Routes[$Method].Clear()
    }
    else {
        $PodeContext.Server.Routes.Keys.Clone() | ForEach-Object {
            $PodeContext.Server.Routes[$_].Clear()
        }
    }
}

<#
.SYNOPSIS
Removes all added static Routes.

.DESCRIPTION
Removes all added static Routes.

.EXAMPLE
Clear-PodeStaticRoutes
#>
function Clear-PodeStaticRoutes
{
    [CmdletBinding()]
    param()

    $PodeContext.Server.Routes['Static'].Clear()
}

<#
.SYNOPSIS
Removes all added Signal Routes.

.DESCRIPTION
Removes all added Signal Routes.

.EXAMPLE
Clear-PodeSignalRoutes
#>
function Clear-PodeSignalRoutes
{
    [CmdletBinding()]
    param()

    $PodeContext.Server.Routes['Signal'].Clear()
}

<#
.SYNOPSIS
Takes an array of Commands, or a Module, and converts them into Routes.

.DESCRIPTION
Takes an array of Commands (Functions/Aliases), or a Module, and generates appropriate Routes for the commands.

.PARAMETER Commands
An array of Commands to convert - if a Module is supplied, these Commands must be present within that Module.

.PARAMETER Module
A Module whose exported commands will be converted.

.PARAMETER Method
An override HTTP method to use when generating the Routes. If not supplied, Pode will make a best guess based on the Command's Verb.

.PARAMETER Path
An optional Path for the Route, to prepend before the Command Name and Module.

.PARAMETER Middleware
Like normal Routes, an array of Middleware that will be applied to all generated Routes.

.PARAMETER Authentication
The name of an Authentication method which should be used as middleware on this Route.

.PARAMETER AllowAnon
If supplied, the Route will allow anonymous access for non-authenticated users.

.PARAMETER NoVerb
If supplied, the Command's Verb will not be included in the Route's path.

.PARAMETER NoOpenApi
If supplied, no OpenAPI definitions will be generated for the routes created.

.EXAMPLE
ConvertTo-PodeRoute -Commands @('Get-ChildItem', 'Get-Host', 'Invoke-Expression') -Middleware { ... }

.EXAMPLE
ConvertTo-PodeRoute -Commands @('Get-ChildItem', 'Get-Host', 'Invoke-Expression') -Authentication AuthName

.EXAMPLE
ConvertTo-PodeRoute -Module Pester -Path '/api'

.EXAMPLE
ConvertTo-PodeRoute -Commands @('Invoke-Pester') -Module Pester
#>
function ConvertTo-PodeRoute
{
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline=$true)]
        [string[]]
        $Commands,

        [Parameter()]
        [string]
        $Module,

        [Parameter()]
        [ValidateSet('', 'Connect', 'Delete', 'Get', 'Head', 'Merge', 'Options', 'Patch', 'Post', 'Put', 'Trace')]
        [string]
        $Method,

        [Parameter()]
        [string]
        $Path = '/',

        [Parameter()]
        [object[]]
        $Middleware,

        [Parameter()]
        [Alias('Auth')]
        [string]
        $Authentication,

        [switch]
        $AllowAnon,

        [switch]
        $NoVerb,

        [switch]
        $NoOpenApi
    )

    # if a module was supplied, import it - then validate the commands
    if (![string]::IsNullOrWhiteSpace($Module)) {
        Import-PodeModule -Name $Module

        Write-Verbose "Getting exported commands from module"
        $ModuleCommands = (Get-Module -Name $Module | Sort-Object -Descending | Select-Object -First 1).ExportedCommands.Keys

        # if commands were supplied validate them - otherwise use all exported ones
        if (Test-PodeIsEmpty $Commands) {
            Write-Verbose "Using all commands in $($Module) for converting to routes"
            $Commands = $ModuleCommands
        }
        else {
            Write-Verbose "Validating supplied commands against module's exported commands"
            foreach ($cmd in $Commands) {
                if ($ModuleCommands -inotcontains $cmd) {
                    throw "Module $($Module) does not contain function $($cmd) to convert to a Route"
                }
            }
        }
    }

    # if there are no commands, fail
    if (Test-PodeIsEmpty $Commands) {
        throw 'No commands supplied to convert to Routes'
    }

    # trim end trailing slashes from the path
    $Path = Protect-PodeValue -Value $Path -Default '/'
    $Path = $Path.TrimEnd('/')

    # create the routes for each of the commands
    foreach ($cmd in $Commands) {
        # get module verb/noun and comvert verb to HTTP method
        $split = ($cmd -split '\-')

        if ($split.Length -ge 2) {
            $verb = $split[0]
            $noun = $split[1..($split.Length - 1)] -join ([string]::Empty)
        }
        else {
            $verb = [string]::Empty
            $noun = $split[0]
        }

        # determine the http method, or use the one passed
        $_method = $Method
        if ([string]::IsNullOrWhiteSpace($_method)) {
            $_method = Convert-PodeFunctionVerbToHttpMethod -Verb $verb
        }

        # use the full function name, or remove the verb
        $name = $cmd
        if ($NoVerb) {
            $name = $noun
        }

        # build the route's path
        $_path = ("$($Path)/$($Module)/$($name)" -replace '[/]+', '/')

        # create the route
        $route = (Add-PodeRoute -Method $_method -Path $_path -Middleware $Middleware -Authentication $Authentication -AllowAnon:$AllowAnon -ArgumentList $cmd -ScriptBlock {
            param($cmd)

            # either get params from the QueryString or Payload
            if ($WebEvent.Method -ieq 'get') {
                $parameters = $WebEvent.Query
            }
            else {
                $parameters = $WebEvent.Data
            }

            # invoke the function
            $result = (. $cmd @parameters)

            # if we have a result, convert it to json
            if (!(Test-PodeIsEmpty $result)) {
                Write-PodeJsonResponse -Value $result -Depth 1
            }
        } -PassThru)

        # set the openapi metadata of the function, unless told to skip
        if ($NoOpenApi) {
            continue
        }

        $help = Get-Help -Name $cmd
        $route = ($route | Set-PodeOARouteInfo -Summary $help.Synopsis -Tags $Module -PassThru)

        # set the routes parameters (get = query, everything else = payload)
        $params = (Get-Command -Name $cmd).Parameters
        if (($null -eq $params) -or ($params.Count -eq 0)) {
            continue
        }

        $props = @(foreach ($key in $params.Keys) {
            $params[$key] | ConvertTo-PodeOAPropertyFromCmdletParameter
        })

        if ($_method -ieq 'get') {
            $route | Set-PodeOARequest -Parameters @(foreach ($prop in $props) { $prop | ConvertTo-PodeOAParameter -In Query })
        }

        else {
            $route | Set-PodeOARequest -RequestBody (
                New-PodeOARequestBody -ContentSchemas @{ 'application/json' = (New-PodeOAObjectProperty -Array -Properties $props) }
            )
        }
    }
}

<#
.SYNOPSIS
Helper function to generate simple GET routes.

.DESCRIPTION
Helper function to generate simple GET routes from ScritpBlocks, Files, and Views.
The output is always rendered as HTML.

.PARAMETER Name
A unique name for the page, that will be used in the Path for the route.

.PARAMETER ScriptBlock
A ScriptBlock to invoke, where any results will be converted to HTML.

.PARAMETER FilePath
A FilePath, literal or relative, to a valid HTML file.

.PARAMETER View
The name of a View to render, this can be HTML or Dynamic.

.PARAMETER Data
A hashtable of Data to supply to a Dynamic File/View, or to be splatted as arguments for the ScriptBlock.

.PARAMETER Path
An optional Path for the Route, to prepend before the Name.

.PARAMETER Middleware
Like normal Routes, an array of Middleware that will be applied to all generated Routes.

.PARAMETER Authentication
The name of an Authentication method which should be used as middleware on this Route.

.PARAMETER AllowAnon
If supplied, the Page will allow anonymous access for non-authenticated users.

.PARAMETER FlashMessages
If supplied, Views will have any flash messages supplied to them for rendering.

.EXAMPLE
Add-PodePage -Name Services -ScriptBlock { Get-Service }

.EXAMPLE
Add-PodePage -Name Index -View 'index'

.EXAMPLE
Add-PodePage -Name About -FilePath '.\views\about.pode' -Data @{ Date = [DateTime]::UtcNow }
#>
function Add-PodePage
{
    [CmdletBinding(DefaultParameterSetName='ScriptBlock')]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name,

        [Parameter(Mandatory=$true, ParameterSetName='ScriptBlock')]
        [scriptblock]
        $ScriptBlock,

        [Parameter(Mandatory=$true, ParameterSetName='File')]
        [string]
        $FilePath,

        [Parameter(Mandatory=$true, ParameterSetName='View')]
        [string]
        $View,

        [Parameter()]
        [hashtable]
        $Data,

        [Parameter()]
        [string]
        $Path = '/',

        [Parameter()]
        [object[]]
        $Middleware,

        [Parameter()]
        [Alias('Auth')]
        [string]
        $Authentication,

        [switch]
        $AllowAnon,

        [Parameter(ParameterSetName='View')]
        [switch]
        $FlashMessages
    )

    $logic = $null
    $arg = $null

    # ensure the name is a valid alphanumeric
    if ($Name -inotmatch '^[a-z0-9\-_]+$') {
        throw "The Page name should be a valid AlphaNumeric value: $($Name)"
    }

    # trim end trailing slashes from the path
    $Path = Protect-PodeValue -Value $Path -Default '/'
    $Path = $Path.TrimEnd('/')

    # define the appropriate logic
    switch ($PSCmdlet.ParameterSetName.ToLowerInvariant())
    {
        'scriptblock' {
            if (Test-PodeIsEmpty $ScriptBlock){
                throw 'A non-empty ScriptBlock is required to created a Page Route'
            }

            $arg = @($ScriptBlock, $Data)
            $logic = {
                param($script, $data)

                # invoke the function (optional splat data)
                if (Test-PodeIsEmpty $data) {
                    $result = (. $script)
                }
                else {
                    $result = (. $script @data)
                }

                # if we have a result, convert it to html
                if (!(Test-PodeIsEmpty $result)) {
                    Write-PodeHtmlResponse -Value $result
                }
            }
        }

        'file' {
            $FilePath = Get-PodeRelativePath -Path $FilePath -JoinRoot -TestPath
            $arg = @($FilePath, $Data)
            $logic = {
                param($file, $data)
                Write-PodeFileResponse -Path $file -ContentType 'text/html' -Data $data
            }
        }

        'view' {
            $arg = @($View, $Data, $FlashMessages)
            $logic = {
                param($view, $data, [bool]$flash)
                Write-PodeViewResponse -Path $view -Data $data -FlashMessages:$flash
            }
        }
    }

    # build the route's path
    $_path = ("$($Path)/$($Name)" -replace '[/]+', '/')

    # create the route
    Add-PodeRoute `
        -Method Get `
        -Path $_path `
        -Middleware $Middleware `
        -Authentication $Authentication `
        -AllowAnon:$AllowAnon `
        -ArgumentList $arg `
        -ScriptBlock $logic
}

<#
.SYNOPSIS
Get a Route(s).

.DESCRIPTION
Get a Route(s).

.PARAMETER Method
A Method to filter the routes.

.PARAMETER Path
A Path to filter the routes.

.PARAMETER EndpointName
The name of an endpoint to filter routes.

.EXAMPLE
Get-PodeRoute -Method Get -Path '/about'

.EXAMPLE
Get-PodeRoute -Method Post -Path '/users/:userId' -EndpointName User
#>
function Get-PodeRoute
{
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateSet('', 'Connect', 'Delete', 'Get', 'Head', 'Merge', 'Options', 'Patch', 'Post', 'Put', 'Trace', '*')]
        [string]
        $Method,

        [Parameter()]
        [string]
        $Path,

        [Parameter()]
        [string[]]
        $EndpointName
    )

    # start off with every route
    $routes = @()
    foreach ($route in $PodeContext.Server.Routes.Values.Values) {
        $routes += $route
    }

    # if we have a method, filter
    if (![string]::IsNullOrWhiteSpace($Method)) {
        $routes = @(foreach ($route in $routes) {
            if ($route.Method -ine $Method) {
                continue
            }

            $route
        })
    }

    # if we have a path, filter
    if (![string]::IsNullOrWhiteSpace($Path)) {
        $Path = Split-PodeRouteQuery -Path $Path
        $Path = Update-PodeRouteSlashes -Path $Path
        $Path = Resolve-PodePlaceholders -Path $Path

        $routes = @(foreach ($route in $routes) {
            if ($route.Path -ine $Path) {
                continue
            }

            $route
        })
    }

    # further filter by endpoint names
    if (($null -ne $EndpointName) -and ($EndpointName.Length -gt 0)) {
        $routes = @(foreach ($name in $EndpointName) {
            foreach ($route in $routes) {
                if ($route.Endpoint.Name -ine $name) {
                    continue
                }

                $route
            }
        })
    }

    # return
    return $routes
}

<#
.SYNOPSIS
Get a static Route(s).

.DESCRIPTION
Get a static Route(s).

.PARAMETER Path
A Path to filter the static routes.

.PARAMETER EndpointName
The name of an endpoint to filter static routes.

.EXAMPLE
Get-PodeStaticRoute -Path '/assets'

.EXAMPLE
Get-PodeStaticRoute -Path '/assets' -EndpointName User
#>
function Get-PodeStaticRoute
{
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Path,

        [Parameter()]
        [string[]]
        $EndpointName
    )

    # start off with every route
    $routes = @()
    foreach ($route in $PodeContext.Server.Routes['Static'].Values) {
        $routes += $route
    }

    # if we have a path, filter
    if (![string]::IsNullOrWhiteSpace($Path)) {
        $Path = Update-PodeRouteSlashes -Path $Path -Static
        $routes = @(foreach ($route in $routes) {
            if ($route.Path -ine $Path) {
                continue
            }

            $route
        })
    }

    # further filter by endpoint names
    if (($null -ne $EndpointName) -and ($EndpointName.Length -gt 0)) {
        $routes = @(foreach ($name in $EndpointName) {
            foreach ($route in $routes) {
                if ($route.Endpoint.Name -ine $name) {
                    continue
                }

                $route
            }
        })
    }

    # return
    return $routes
}

<#
.SYNOPSIS
Get a Signal Route(s).

.DESCRIPTION
Get a Signal Route(s).

.PARAMETER Path
A Path to filter the signal routes.

.PARAMETER EndpointName
The name of an endpoint to filter signal routes.

.EXAMPLE
Get-PodeSignalRoute -Path '/message'
#>
function Get-PodeSignalRoute
{
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Path,

        [Parameter()]
        [string[]]
        $EndpointName
    )

    # start off with every route
    $routes = @()
    foreach ($route in $PodeContext.Server.Routes['Signal'].Values) {
        $routes += $route
    }

    # if we have a path, filter
    if (![string]::IsNullOrWhiteSpace($Path)) {
        $Path = Update-PodeRouteSlashes -Path $Path
        $routes = @(foreach ($route in $routes) {
            if ($route.Path -ine $Path) {
                continue
            }

            $route
        })
    }

    # further filter by endpoint names
    if (($null -ne $EndpointName) -and ($EndpointName.Length -gt 0)) {
        $routes = @(foreach ($name in $EndpointName) {
            foreach ($route in $routes) {
                if ($route.Endpoint.Name -ine $name) {
                    continue
                }

                $route
            }
        })
    }

    # return
    return $routes
}

<#
.SYNOPSIS
Automatically loads route ps1 files

.DESCRIPTION
Automatically loads route ps1 files from either a /routes folder, or a custom folder. Saves space dot-sourcing them all one-by-one.

.PARAMETER Path
Optional Path to a folder containing ps1 files, can be relative or literal.

.PARAMETER IfExists
Specifies what action to take when a Route already exists. (Default: Default)

.EXAMPLE
Use-PodeRoutes

.EXAMPLE
Use-PodeRoutes -Path './my-routes' -IfExists Skip
#>
function Use-PodeRoutes
{
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Path,

        [Parameter()]
        [ValidateSet('Default', 'Error', 'Overwrite', 'Skip')]
        [string]
        $IfExists = 'Default'
    )

    if ($IfExists -ieq 'Default') {
        $IfExists = Get-PodeRouteIfExistsPreference
    }

    $RouteIfExists = $IfExists
    Use-PodeFolder -Path $Path -DefaultPath 'routes'
}

<#
.SYNOPSIS
Set the default IfExists preference for Routes.

.DESCRIPTION
Set the default IfExists preference for Routes.

.PARAMETER Value
Specifies what action to take when a Route already exists. (Default: Default)

.EXAMPLE
Set-PodeRouteIfExistsPreference -Value Overwrite
#>
function Set-PodeRouteIfExistsPreference
{
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateSet('Default', 'Error', 'Overwrite', 'Skip')]
        [string]
        $Value = 'Default'
    )

    $PodeContext.Server.Preferences.Routes.IfExists = $Value
}

<#
.SYNOPSIS
Test if a Route already exists.

.DESCRIPTION
Test if a Route already exists for a given Method and Path.

.PARAMETER Method
The HTTP Method of the Route.

.PARAMETER Path
The URI path of the Route.

.PARAMETER EndpointName
The EndpointName of an Endpoint the Route is bound against.

.PARAMETER CheckWildcard
If supplied, Pode will check for the Route on the Method first, and then check for the Route on the '*' Method.

.EXAMPLE
Test-PodeRoute -Method Post -Path '/example'

.EXAMPLE
Test-PodeRoute -Method Post -Path '/example' -CheckWildcard

.EXAMPLE
Test-PodeRoute -Method Get -Path '/example/:exampleId' -CheckWildcard
#>
function Test-PodeRoute
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('Connect', 'Delete', 'Get', 'Head', 'Merge', 'Options', 'Patch', 'Post', 'Put', 'Trace', '*')]
        [string]
        $Method,

        [Parameter(Mandatory=$true)]
        [string]
        $Path,

        [Parameter()]
        [string]
        $EndpointName,

        [switch]
        $CheckWildcard
    )

    # split route on '?' for query
    $Path = Split-PodeRouteQuery -Path $Path
    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw "No Path supplied for testing Route"
    }

    # ensure the route has appropriate slashes
    $Path = Update-PodeRouteSlashes -Path $Path
    $Path = Resolve-PodePlaceholders -Path $Path

    # get endpoint from name
    $endpoint = @(Find-PodeEndpoints -EndpointName $EndpointName)[0]

    # check for routes
    $found = (Test-PodeRouteInternal -Method $Method -Path $Path -Protocol $endpoint.Protocol -Address $endpoint.Address)
    if (!$found -and $CheckWildcard) {
        $found = (Test-PodeRouteInternal -Method '*' -Path $Path -Protocol $endpoint.Protocol -Address $endpoint.Address)
    }

    return $found
}

<#
.SYNOPSIS
Test if a Static Route already exists.

.DESCRIPTION
Test if a Static Route already exists for a given Path.

.PARAMETER Path
The URI path of the Static Route.

.PARAMETER EndpointName
The EndpointName of an Endpoint the Static Route is bound against.

.EXAMPLE
Test-PodeStaticRoute -Path '/assets'
#>
function Test-PodeStaticRoute
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Path,

        [Parameter()]
        [string]
        $EndpointName
    )

    # store the route method
    $Method = 'Static'

    # split route on '?' for query
    $Path = Split-PodeRouteQuery -Path $Path
    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw "No Path supplied for testing Static Route"
    }

    # ensure the route has appropriate slashes
    $Path = Update-PodeRouteSlashes -Path $Path -Static
    $Path = Resolve-PodePlaceholders -Path $Path

    # get endpoint from name
    $endpoint = @(Find-PodeEndpoints -EndpointName $EndpointName)[0]

    # check for routes
    return (Test-PodeRouteInternal -Method $Method -Path $Path -Protocol $endpoint.Protocol -Address $endpoint.Address)
}

<#
.SYNOPSIS
Test if a Signal Route already exists.

.DESCRIPTION
Test if a Signal Route already exists for a given Path.

.PARAMETER Path
The URI path of the Signal Route.

.PARAMETER EndpointName
The EndpointName of an Endpoint the Signal Route is bound against.

.EXAMPLE
Test-PodeSignalRoute -Path '/message'
#>
function Test-PodeSignalRoute
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Path,

        [Parameter()]
        [string]
        $EndpointName
    )

    $Method = 'Signal'

    # ensure the route has appropriate slashes
    $Path = Update-PodeRouteSlashes -Path $Path

    # get endpoint from name
    $endpoint = @(Find-PodeEndpoints -EndpointName $EndpointName)[0]

    # check for routes
    return (Test-PodeRouteInternal -Method $Method -Path $Path -Protocol $endpoint.Protocol -Address $endpoint.Address)
}