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

.PARAMETER PassThru
If supplied, the route created will be returned so it can be passed through a pipe.

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

        [Parameter(ParameterSetName='Script')]
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

        [switch]
        $PassThru
    )

    # split route on '?' for query
    $Path = Split-PodeRouteQuery -Path $Path
    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw "[$($Method)]: No Path supplied for Route"
    }

    # ensure the route has appropriate slashes
    $Path = Update-PodeRouteSlashes -Path $Path
    $OpenApiPath = ConvertTo-PodeOpenApiRoutePath -Path $Path
    $Path = Update-PodeRoutePlaceholders -Path $Path

    # get endpoints from name, or use single passed endpoint/protocol
    $endpoints = Find-PodeEndpoints -Endpoint $Endpoint -Protocol $Protocol -EndpointName $EndpointName

    # ensure the route doesn't already exist for each endpoint
    foreach ($_endpoint in $endpoints) {
        Test-PodeRouteAndError -Method $Method -Path $Path -Protocol $_endpoint.Protocol -Endpoint $_endpoint.Address
    }

    # if middleware, scriptblock and file path are all null/empty, error
    if ((Test-IsEmpty $Middleware) -and (Test-IsEmpty $ScriptBlock) -and (Test-IsEmpty $FilePath)) {
        throw "[$($Method)] $($Path): No logic passed"
    }

    # if we have a file path supplied, load that path as a scriptblock
    if ($PSCmdlet.ParameterSetName -ieq 'file') {
        $ScriptBlock = Convert-PodeFileToScriptBlock -FilePath $FilePath
    }

    # ensure supplied middlewares are either a scriptblock, or a valid hashtable
    if (!(Test-IsEmpty $Middleware)) {
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
            if ($Middleware[$i] -is [scriptblock]) {
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

    # workout a default transfer encoding for the route
    if ([string]::IsNullOrWhiteSpace($TransferEncoding)) {
        $TransferEncoding = $PodeContext.Server.Web.TransferEncoding.Default

        # find type by pattern from settings
        $matched = ($PodeContext.Server.Web.TransferEncoding.Routes.Keys | Where-Object {
            $Path -imatch $_
        } | Select-Object -First 1)

        # if we get a match, set it
        if (!(Test-IsEmpty $matched)) {
            $TransferEncoding = $PodeContext.Server.Web.TransferEncoding.Routes[$matched]
        }
    }

    # add the route(s)
    Write-Verbose "Adding Route: [$($Method)] $($Path)"
    $newRoutes = @(foreach ($_endpoint in $endpoints) {
        @{
            Logic = $ScriptBlock
            Middleware = $Middleware
            Protocol = $_endpoint.Protocol
            Endpoint = $_endpoint.Address.Trim()
            EndpointName = $_endpoint.Name
            ContentType = $ContentType
            TransferEncoding = $TransferEncoding
            ErrorType = $ErrorContentType
            Arguments = $ArgumentList
            Method = $Method
            Path = $Path
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
            IsStatic = $false
            Metrics = @{
                Requests = @{
                    Total = 0
                    StatusCodes = @{}
                }
            }
        }
    })

    $PodeContext.Server.Routes[$Method][$Path] += @($newRoutes)

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

.PARAMETER Protocol
The protocol this static Route should be bound against.

.PARAMETER Endpoint
The endpoint this static Route should be bound against.

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

.PARAMETER DownloadOnly
When supplied, all static content on this Route will be attached as downloads - rather than rendered.

.PARAMETER PassThru
If supplied, the static route created will be returned so it can be passed through a pipe.

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
        [object[]]
        $Middleware,

        [Parameter()]
        [ValidateSet('', 'Http', 'Https')]
        [string]
        $Protocol,

        [Parameter()]
        [string]
        $Endpoint,

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

        [switch]
        $DownloadOnly,

        [switch]
        $PassThru
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
    $OpenApiPath = ConvertTo-PodeOpenApiRoutePath -Path $Path
    $Path = Update-PodeRoutePlaceholders -Path $Path

    # get endpoints from name, or use single passed endpoint/protocol
    $endpoints = Find-PodeEndpoints -Endpoint $Endpoint -Protocol $Protocol -EndpointName $EndpointName

    # ensure the route doesn't already exist for each endpoint
    foreach ($_endpoint in $endpoints) {
        Test-PodeRouteAndError -Method $Method -Path $Path -Protocol $_endpoint.Protocol -Endpoint $_endpoint.Address
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

    # ensure supplied middlewares are either a scriptblock, or a valid hashtable
    #TODO: generalise?
    if (!(Test-IsEmpty $Middleware)) {
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
            if ($Middleware[$i] -is [scriptblock]) {
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

    # workout a default transfer encoding for the route
    if ([string]::IsNullOrWhiteSpace($TransferEncoding)) {
        $TransferEncoding = $PodeContext.Server.Web.TransferEncoding.Default

        # find type by pattern from settings
        $matched = ($PodeContext.Server.Web.TransferEncoding.Routes.Keys | Where-Object {
            $Path -imatch $_
        } | Select-Object -First 1)

        # if we get a match, set it
        if (!(Test-IsEmpty $matched)) {
            $TransferEncoding = $PodeContext.Server.Web.TransferEncoding.Routes[$matched]
        }
    }

    # add the route(s)
    Write-Verbose "Adding Route: [$($Method)] $($Path)"
    $newRoutes = @(foreach ($_endpoint in $endpoints) {
        @{
            Source = $Source
            Path = $Path
            Method = $Method
            Defaults = $Defaults
            Middleware = $Middleware
            Protocol = $_endpoint.Protocol
            Endpoint = $_endpoint.Address.Trim()
            EndpointName = $_endpoint.Name
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

    $PodeContext.Server.Routes[$Method][$Path] += @($newRoutes)

    # return the routes?
    if ($PassThru) {
        return $newRoutes
    }
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
        [ValidateSet('', 'Http', 'Https')]
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
Remove-PodeStaticRoute -Path '/assets' -Protocol Http
#>
function Remove-PodeStaticRoute
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Path,

        [Parameter()]
        [ValidateSet('', 'Http', 'Https')]
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

.PARAMETER NoVerb
If supplied, the Command's Verb will not be included in the Route's path.

.PARAMETER NoOpenApi
If supplied, no OpenAPI definitions will be generated for the routes created.

.EXAMPLE
ConvertTo-PodeRoute -Commands @('Get-ChildItem', 'Get-Host', 'Invoke-Expression') -Middleware (Get-PodeAuthMiddleware -Name 'auth-name' -Sessionless)

.EXAMPLE
ConvertTo-PodeRoute -Module Pester -Path '/api'

.EXAMPLE
ConvertTo-PodeRoute -Commands @('Invoke-Pester') -Module Pester
#>
function ConvertTo-PodeRoute
{
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline=$true)]
        [string[]]
        $Commands,

        [Parameter()]
        [string]
        $Module,

        [Parameter()]
        [ValidateSet('', 'Delete', 'Get', 'Head', 'Merge', 'Options', 'Patch', 'Post', 'Put', 'Trace')]
        [string]
        $Method,

        [Parameter()]
        [string]
        $Path = '/',

        [Parameter()]
        [object[]]
        $Middleware,

        [switch]
        $NoVerb,

        [switch]
        $NoOpenApi
    )

    # if a module was supplied, import it - then validate the commands
    if (![string]::IsNullOrWhiteSpace($Module)) {
        Import-PodeModule -Name $Module -Now

        Write-Verbose "Getting exported commands from module"
        $ModuleCommands = (Get-Module -Name $Module | Sort-Object -Descending | Select-Object -First 1).ExportedCommands.Keys

        # if commands were supplied validate them - otherwise use all exported ones
        if (Test-IsEmpty $Commands) {
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
    if (Test-IsEmpty $Commands) {
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
        $route = (Add-PodeRoute -Method $_method -Path $_path -Middleware $Middleware -ArgumentList $cmd -ScriptBlock {
            param($e, $cmd)

            # either get params from the QueryString or Payload
            if ($e.Method -ieq 'get') {
                $parameters = $e.Query
            }
            else {
                $parameters = $e.Data
            }

            # invoke the function
            $result = (. $cmd @parameters)

            # if we have a result, convert it to json
            if (!(Test-IsEmpty $result)) {
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
    param (
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
            if (Test-IsEmpty $ScriptBlock){
                throw 'A non-empty ScriptBlock is required to created a Page Route'
            }

            $arg = @($ScriptBlock, $Data)
            $logic = {
                param($e, $script, $data)

                # invoke the function (optional splat data)
                if (Test-IsEmpty $data) {
                    $result = (. $script)
                }
                else {
                    $result = (. $script @data)
                }

                # if we have a result, convert it to html
                if (!(Test-IsEmpty $result)) {
                    Write-PodeHtmlResponse -Value $result
                }
            }
        }

        'file' {
            $FilePath = Get-PodeRelativePath -Path $FilePath -JoinRoot -TestPath
            $arg = @($FilePath, $Data)
            $logic = {
                param($e, $file, $data)
                Write-PodeFileResponse -Path $file -ContentType 'text/html' -Data $data
            }
        }

        'view' {
            $arg = @($View, $Data, $FlashMessages)
            $logic = {
                param($e, $view, $data, [bool]$flash)
                Write-PodeViewResponse -Path $view -Data $data -FlashMessages:$flash
            }
        }
    }

    # build the route's path
    $_path = ("$($Path)/$($Name)" -replace '[/]+', '/')

    # create the route
    Add-PodeRoute -Method Get -Path $_path -Middleware $Middleware -ArgumentList $arg -ScriptBlock $logic
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

.PARAMETER Protocol
A Protocol to filter the routes.

.PARAMETER Endpoint
An Endpoint to filter the routes.

.PARAMETER EndpointName
The name of an endpoint to filter routes.

.EXAMPLE
Get-PodeRoute -Method Get -Route '/about'

.EXAMPLE
Get-PodeRoute -Method Post -Route '/users/:userId' -Endpoint 127.0.0.2:8001

.EXAMPLE
Get-PodeRoute -Method Post -Route '/users/:userId' -EndpointName User
#>
function Get-PodeRoute
{
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateSet('', 'Delete', 'Get', 'Head', 'Merge', 'Options', 'Patch', 'Post', 'Put', 'Trace', '*')]
        [string]
        $Method,

        [Parameter()]
        [string]
        $Path,

        [Parameter()]
        [ValidateSet('', 'Http', 'Https')]
        [string]
        $Protocol,

        [Parameter()]
        [string]
        $Endpoint,

        [Parameter()]
        [string[]]
        $EndpointName
    )

    # start off with every route
    $routes = $PodeContext.Server.Routes.Values.Values

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
        $Path = Update-PodeRoutePlaceholders -Path $Path

        $routes = @(foreach ($route in $routes) {
            if ($route.Path -ine $Path) {
                continue
            }

            $route
        })
    }

    # attempt to filter by protocol/endpoint
    if (![string]::IsNullOrWhiteSpace($Protocol) -or ![string]::IsNullOrWhiteSpace($Endpoint)) {
        $routes = (Get-PodeRoutesByUrl -Routes $routes -Protocol $Protocol -Endpoint $Endpoint)
    }

    # further filter by endpoint names
    if (($null -ne $EndpointName) -and ($EndpointName.Length -gt 0)) {
        $routes = @(foreach ($name in $EndpointName) {
            foreach ($route in $routes) {
                if ($route.EndpointName -ine $name) {
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

.PARAMETER Protocol
A Protocol to filter the static routes.

.PARAMETER Endpoint
An Endpoint to filter the static routes.

.PARAMETER EndpointName
The name of an endpoint to filter static routes.

.EXAMPLE
Get-PodeStaticRoute -Path '/assets'

.EXAMPLE
Get-PodeStaticRoute -Path '/assets' -Protocol Http

.EXAMPLE
Get-PodeStaticRoute -Path '/assets' -Endpoint 127.0.0.1:8080

.EXAMPLE
Get-PodeStaticRoute -Path '/assets' -EndpointName User
#>
function Get-PodeStaticRoute
{
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $Path,

        [Parameter()]
        [ValidateSet('', 'Http', 'Https')]
        [string]
        $Protocol,

        [Parameter()]
        [string]
        $Endpoint,

        [Parameter()]
        [string[]]
        $EndpointName
    )

    # start off with every route
    $routes = $PodeContext.Server.Routes['Static'].Values

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

    # attempt to filter by protocol/endpoint
    if (![string]::IsNullOrWhiteSpace($Protocol) -or ![string]::IsNullOrWhiteSpace($Endpoint)) {
        $routes = (Get-PodeRoutesByUrl -Routes $routes -Protocol $Protocol -Endpoint $Endpoint)
    }

    # further filter by endpoint names
    if (($null -ne $EndpointName) -and ($EndpointName.Length -gt 0)) {
        $routes = @(foreach ($name in $EndpointName) {
            foreach ($route in $routes) {
                if ($route.EndpointName -ine $name) {
                    continue
                }

                $route
            }
        })
    }

    # return
    return $routes
}