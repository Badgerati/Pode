<#
.SYNOPSIS
Adds a Route for a specific HTTP Method.

.DESCRIPTION
Adds a Route for a specific HTTP Method, with path, that when called with invoke any logic and/or Middleware.

.PARAMETER Method
The HTTP Method of this Route.

.PARAMETER Path
The URI path for the Route.

.PARAMETER Middleware
An array of ScriptBlocks for optional Middleware.

.PARAMETER ScriptBlock
A ScriptBlock for the Route's main logic.

.PARAMETER Protocol
The protocol this Route should be bound against.

.PARAMETER Endpoint
The endpoint this Route should be bound against.

.PARAMETER EndpointName
The EndpointName of an Endpoint this Route should be bound against.

.PARAMETER ContentType
The content type the Route should use when parsing any payloads.

.PARAMETER ErrorContentType
The content type of any error pages that may get returned.

.PARAMETER FilePath
A literal, or relative, path to a file containing a ScriptBlock for the Route's main logic.

.EXAMPLE
Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
    Write-PodeJsonResponse -Value @{ Name = 'Bob' }
}

.EXAMPLE
Add-PodeRoute -Method Post -Path '/users/:userId/message' -Middleware (csrf check) -ScriptBlock {
    Write-PodeJsonResponse -Value @{ Messages = @() }
}

.EXAMPLE
Add-PodeRoute -Method Post -Path '/user' -ContentType 'application/json' -ScriptBlock {
    Write-PodeJsonResponse -Value @{ Name = 'Bob' }
}

.EXAMPLE
Add-PodeRoute -Method Get -Path '/api/cpu' -ErrorContentType 'application/json' -ScriptBlock {
    Write-PodeJsonResponse -Value @{ CPU = 84 }
}
#>
function Add-PodeRoute
{
    [CmdletBinding(DefaultParameterSetName='Script')]
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet('Delete', 'Get', 'Head', 'Merge', 'Options', 'Patch', 'Post', 'Put', 'Trace', '*')]
        [string]
        $Method,

        [Parameter(Mandatory=$true)]
        [string]
        $Path,

        [Parameter()]
        [object[]]
        $Middleware,

        [Parameter(Mandatory=$true, ParameterSetName='Script')]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [ValidateSet('', 'Http', 'Https')]
        [string]
        $Protocol,

        [Parameter()]
        [string]
        $Endpoint,

        [Parameter()]
        [string]
        $EndpointName,

        [Parameter()]
        [string]
        $ContentType,

        [Parameter()]
        [string]
        $ErrorContentType,

        [Parameter(Mandatory=$true, ParameterSetName='File')]
        [string]
        $FilePath
    )

    # split route on '?' for query
    $Path = Split-PodeRouteQuery -Path $Path
    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw "[$($Method)]: No Path supplied for Route"
    }

    # ensure the route has appropriate slashes
    $Path = Update-PodeRouteSlashes -Path $Path
    $Path = Update-PodeRoutePlaceholders -Path $Path

    # if an EndpointName was supplied, find it and use it
    $_endpoint = Get-PodeEndpointByName -EndpointName $EndpointName -ThrowError
    if ($null -ne $_endpoint) {
        $Protocol = $_endpoint.Protocol
        $Endpoint = $_endpoint.RawAddress
    }

    # if we have an endpoint, set any appropriate wildcards
    if (!(Test-IsEmpty $Endpoint)) {
        $_endpoint = Get-PodeEndpointInfo -Endpoint $Endpoint -AnyPortOnZero
        $Endpoint = "$($_endpoint.Host):$($_endpoint.Port)"
    }

    # ensure route doesn't already exist
    Test-PodeRouteAndError -Method $Method -Path $Path -Protocol $Protocol -Endpoint $Endpoint

    # if middleware, scriptblock and file path are all null/empty, error
    if ((Test-IsEmpty $Middleware) -and (Test-IsEmpty $ScriptBlock) -and (Test-IsEmpty $FilePath)) {
        throw "[$($Method)] $($Path): No logic passed"
    }

    # if we have a file path supplied, load that path as a scriptblock
    if ($PSCmdlet.ParameterSetName -ieq 'file') {
        # if file doesn't exist, error
        if (!(Test-PodePath -Path $FilePath -NoStatus)) {
            throw "[$($Method)] $($Path): The FilePath does not exist: $($FilePath)"
        }

        # if the path is a wildcard or directory, error
        if (!(Test-PodePathIsFile -Path $FilePath -FailOnWildcard)) {
            throw "[$($Method)] $($Path): The FilePath cannot be a wildcard or directory: $($FilePath)"
        }

        $ScriptBlock = [scriptblock](Use-PodeScript -Path $FilePath)
    }

    # ensure supplied middlewares are either a scriptblock, or a valid hashtable
    if (!(Test-IsEmpty $Middleware)) {
        @($Middleware) | ForEach-Object {
            # check middleware is a type valid
            if (($_ -isnot 'scriptblock') -and ($_ -isnot 'hashtable')) {
                throw "One of the Route Middlewares supplied for the '[$($Method)] $($Path)' Route is an invalid type. Expected either ScriptBlock or Hashtable, but got: $($_.GetType().Name)"
            }

            # if middleware is hashtable, ensure the keys are valid (logic is a scriptblock)
            if ($_ -is 'hashtable') {
                if ($null -eq $_.Logic) {
                    throw "A Hashtable Middleware supplied for the '[$($Method)] $($Path)' Route has no Logic defined"
                }

                if ($_.Logic -isnot 'scriptblock') {
                    throw "A Hashtable Middleware supplied for the '[$($Method)] $($Path)' Route has has an invalid Logic type. Expected ScriptBlock, but got: $($_.Logic.GetType().Name)"
                }
            }
        }
    }

    # if we have middleware, convert scriptblocks to hashtables
    if (!(Test-IsEmpty $Middleware))
    {
        $Middleware = @($Middleware)

        for ($i = 0; $i -lt $Middleware.Length; $i++) {
            if ($Middleware[$i] -is 'scriptblock') {
                $Middleware[$i] = @{
                    'Logic' = $Middleware[$i]
                }
            }
        }
    }

    # workout a default content type for the route
    if ([string]::IsNullOrWhiteSpace($ContentType)) {
        $ContentType = $PodeContext.Server.Web.ContentType.Default

        # find type by pattern from settings
        $matched = ($PodeContext.Server.Web.ContentType.Routes.Keys | Where-Object {
            $Path -imatch $_
        } | Select-Object -First 1)

        # if we get a match, set it
        if (!(Test-IsEmpty $matched)) {
            $ContentType = $PodeContext.Server.Web.ContentType.Routes[$matched]
        }
    }

    # add the route
    $PodeContext.Server.Routes[$Method][$Path] += @(@{
        'Logic' = $ScriptBlock;
        'Middleware' = $Middleware;
        'Protocol' = $Protocol;
        'Endpoint' = $Endpoint.Trim();
        'ContentType' = $ContentType;
        'ErrorType' = $ErrorContentType;
    })
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

.PARAMETER Protocol
The protocol this static Route should be bound against.

.PARAMETER Endpoint
The endpoint this static Route should be bound against.

.PARAMETER EndpointName
The EndpointName of an Endpoint to bind the static Route against.

.PARAMETER Defaults
An array of default pages to display, such as 'index.html'.

.PARAMETER DownloadOnly
When supplied, all static content on this Route will be attached as downloads - rather than rendered.

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
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Path,

        [Parameter(Mandatory=$true)]
        [string]
        $Source,

        [Parameter()]
        [ValidateSet('', 'Http', 'Https')]
        [string]
        $Protocol,

        [Parameter()]
        [string]
        $Endpoint,

        [Parameter()]
        [string]
        $EndpointName,

        [Parameter()]
        [string[]]
        $Defaults,

        [switch]
        $DownloadOnly
    )

    # store the route method
    $Method = 'Static'

    # split route on '?' for query
    $Path = Split-PodeRouteQuery -Path $Path
    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw "[$($Method)]: No Path path supplied for Static Route"
    }

    # ensure the route has appropriate slashes
    $Path = Update-PodeRouteSlashes -Path $Path -Static

    # if an EndpointName was supplied, find it and use it
    $_endpoint = Get-PodeEndpointByName -EndpointName $EndpointName -ThrowError
    if ($null -ne $_endpoint) {
        $Protocol = $_endpoint.Protocol
        $Endpoint = $_endpoint.RawAddress
    }

    # if we have an endpoint, set any appropriate wildcards
    if (!(Test-IsEmpty $Endpoint)) {
        $_endpoint = Get-PodeEndpointInfo -Endpoint $Endpoint -AnyPortOnZero
        $Endpoint = "$($_endpoint.Host):$($_endpoint.Port)"
    }

    # ensure route doesn't already exist
    Test-PodeRouteAndError -Method $Method -Path $Path -Protocol $Protocol -Endpoint $Endpoint

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

    # add the route path
    $PodeContext.Server.Routes[$Method][$Path] += @(@{
        'Path' = $Source;
        'Defaults' = $Defaults;
        'Protocol' = $Protocol;
        'Endpoint' = $Endpoint.Trim();
        'Download' = $DownloadOnly;
    })

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

.PARAMETER Protocol
The protocol of the Route to remove.

.PARAMETER Endpoint
The endpoint of the Route to remove.

.EXAMPLE
Remove-PodeRoute -Method Get -Route '/about'

.EXAMPLE
Remove-PodeRoute -Method Post -Route '/users/:userId' -Endpoint 127.0.0.2:8001
#>
function Remove-PodeRoute
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet('Delete', 'Get', 'Head', 'Merge', 'Options', 'Patch', 'Post', 'Put', 'Trace', '*')]
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
        $Endpoint
    )

    # split route on '?' for query
    $Path = Split-PodeRouteQuery -Path $Path
    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw "[$($Method)]: No Route path supplied for removing a Route"
    }

    # ensure the route has appropriate slashes and replace parameters
    $Path = Update-PodeRouteSlashes -Path $Path
    $Path = Update-PodeRoutePlaceholders -Path $Path

    # ensure route does exist
    if (!$PodeContext.Server.Routes[$Method].ContainsKey($Path)) {
        return
    }

    # remove the route's logic
    $PodeContext.Server.Routes[$Method][$Path] = @($PodeContext.Server.Routes[$Method][$Path] | Where-Object {
        !(($_.Protocol -ieq $Protocol) -and ($_.Endpoint -ieq $Endpoint))
    })

    # if the route has no more logic, just remove it
    if ((Get-PodeCount $PodeContext.Server.Routes[$Method][$Path]) -eq 0) {
        $PodeContext.Server.Routes[$Method].Remove($Path) | Out-Null
    }
}

<#
.SYNOPSIS
Remove a specific static Route.

.DESCRIPTION
Remove a specific static Route.

.PARAMETER Path
The path of the static Route to remove.

.PARAMETER Protocol
The protocol of the static Route to remove.

.PARAMETER Endpoint
The endpoint of the static Route to remove.

.EXAMPLE
Remove-PodeStaticRoute -Path '/assets'

.EXAMPLE
Remove-PodeStaticRoute -Path '/assets' -Protocol
#>
function Remove-PodeStaticRoute
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Path,

        [Parameter()]
        [string]
        $Protocol,

        [Parameter()]
        [string]
        $Endpoint
    )

    $Method = 'Static'

    # ensure the route has appropriate slashes and replace parameters
    $Path = Update-PodeRouteSlashes -Path $Path -Static

    # ensure route does exist
    if (!$PodeContext.Server.Routes[$Method].ContainsKey($Path)) {
        return
    }

    # remove the route's logic
    $PodeContext.Server.Routes[$Method][$Path] = @($PodeContext.Server.Routes[$Method][$Path] | Where-Object {
        !(($_.Protocol -ieq $Protocol) -and ($_.Endpoint -ieq $Endpoint))
    })

    # if the route has no more logic, just remove it
    if ((Get-PodeCount $PodeContext.Server.Routes[$Method][$Path]) -eq 0) {
        $PodeContext.Server.Routes[$Method].Remove($Path) | Out-Null
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
    param (
        [Parameter()]
        [ValidateSet('', 'Delete', 'Get', 'Head', 'Merge', 'Options', 'Patch', 'Post', 'Put', 'Trace', '*')]
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