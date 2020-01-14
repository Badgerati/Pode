function Enable-PodeOpenApiRoute
{
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path = '/openapi',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $SwaggerPath = '/swagger',

        [Parameter()]
        [string]
        $Filter = '/',

        [Parameter()]
        [object[]]
        $Middleware,

        [Parameter(Mandatory=$true)]
        [string]
        $Title,

        [Parameter()]
        [string]
        $Version = '0.0.1',

        [Parameter()]
        [string]
        $Description
    )

    # initialise openapi info
    $PodeContext.Server.OpenAPI.Title = $Title
    $PodeContext.Server.OpenAPI.Path = $Path

    $meta = @{
        Title = $Title
        Version = $Version
        Description = $Description
        Filter = $Filter
    }

    # add the OpenAPI route
    Add-PodeRoute -Method Get -Path $Path -ArgumentList $meta -Middleware $Middleware -ScriptBlock {
        param($e, $meta)
        $def = @{
            'openapi' = '3.0.2'
        }

        # metadata
        $def['info'] = @{
            'title' = $meta.Title
            'version' = $meta.Version
            'description' = $meta.Description
        }

        # paths
        $def['paths'] = @{}
        $filter = "^$($meta.Filter)"

        foreach ($method in $PodeContext.Server.Routes.Keys) {
            foreach ($path in $PodeContext.Server.Routes[$method].Keys) {
                # does it match the filter?
                if ($path -inotmatch $filter) {
                    continue
                }

                # the current route
                $route = $PodeContext.Server.Routes[$method][$path]

                # do nothing if it has no responses set
                if ($route.OpenApi.Responses.Count -eq 0) {
                    continue
                }

                # add path to defintion
                if ($null -eq $def['paths'][$route.OpenApi.Path]) {
                    $def['paths'][$route.OpenApi.Path] = @{}
                }

                # add path's http method to defintition
                $def['paths'][$route.OpenApi.Path][$method] = @{
                    summary = $route.OpenApi.Summary
                    description = $route.OpenApi.Description
                    tags = @($route.OpenApi.Tags)
                    deprecated = $route.OpenApi.Deprecated
                    responses = $route.OpenApi.Responses
                    parameters = $route.OpenApi.Parameters
                }
            }
        }

        # write
        Write-PodeJsonResponse -Value $def
    }
}

function Add-PodeOpenApiRouteResponse
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [ValidateNotNullOrEmpty()]
        [hashtable[]]
        $Route,

        [Parameter(Mandatory=$true)]
        [int]
        $StatusCode,

        [Parameter()]
        [string]
        $Description,

        [switch]
        $PassThru
    )

    if ([string]::IsNullOrWhiteSpace($Description)) {
        $Description = Get-PodeStatusDescription -StatusCode $StatusCode
    }

    foreach ($r in @($Route)) {
        $r.OpenApi.Responses["$($StatusCode)"] = @{
            description = $Description
        }
    }

    if ($PassThru) {
        return $Route
    }
}

function Set-PodeOpenApiRouteRequest
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [ValidateNotNullOrEmpty()]
        [hashtable[]]
        $Route,

        [Parameter()]
        [hashtable[]]
        $Parameters,

        [switch]
        $PassThru
    )

    foreach ($r in @($Route)) {
        $r.OpenApi.Parameters = @($Parameters)
    }

    if ($PassThru) {
        return $Route
    }
}

function Add-PodeOpenApiComponentSchema
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Name,

        [Parameter(Mandatory=$true)]
        [hashtable[]]
        $Properties
    )

    $PodeContext.Server.OpenAPI.components.schemas[$Name] = @{
        type = 'object'
        properties = (ConvertFrom-PodeOpenApiComponentSchemaProperties -Properties $Properties)
    }
}

function New-PodeOpenApiSchemaProperty
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Name,

        [Parameter(ParameterSetName='String')]
        [switch]
        $String,

        [Parameter(ParameterSetName='Integer')]
        [switch]
        $Integer,

        [Parameter(ParameterSetName='Boolean')]
        [switch]
        $Boolean,

        [Parameter(ParameterSetName='String')]
        [Parameter(ParameterSetName='Integer')]
        [ValidateSet('', 'Binary', 'Byte', 'Date', 'DateTime', 'Int32', 'Int64', 'Time', 'Uuid')]
        $Format,

        [Parameter()]
        [object]
        $Example,

        [Parameter()]
        [string]
        $Description,

        [switch]
        $Required
    )

    # base property object
    $prop = @{
        name = $Name
        required = $Required.IsPresent
        description = $Description
        type = $PSCmdlet.ParameterSetName.ToLowerInvariant()
    }

    # add enums if supplied
    if ($null -ne $Example) {
        $prop['example'] = $Example
    }

    # add format if supplied
    if (!$Boolean -and !(Test-IsEmpty $Format)) {
        $prop['format'] = $Format
    }

    return $prop
}

function New-PodeOpenApiRouteRequestParameter
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Name,

        [Parameter(Mandatory=$true)]
        [ValidateSet('Cookie', 'Header', 'Path', 'Query')]
        [string]
        $In,

        [Parameter(ParameterSetName='String')]
        [switch]
        $String,

        [Parameter(ParameterSetName='Integer')]
        [switch]
        $Integer,

        [Parameter(ParameterSetName='Boolean')]
        [switch]
        $Boolean,

        [Parameter(ParameterSetName='String')]
        [Parameter(ParameterSetName='Integer')]
        [ValidateSet('', 'Binary', 'Byte', 'Date', 'DateTime', 'Int32', 'Int64', 'Time', 'Uuid')]
        $Format,

        [Parameter(ParameterSetName='String')]
        [Parameter(ParameterSetName='Integer')]
        [object[]]
        $Enum,

        [Parameter()]
        [object]
        $Default,

        [Parameter(ParameterSetName='Integer')]
        [int]
        $Minimum = [int]::MinValue,

        [Parameter(ParameterSetName='Integer')]
        [int]
        $Maximum = [int]::MaxValue,

        [Parameter()]
        [string]
        $Description,

        [switch]
        $Required,

        [switch]
        $Deprecated
    )

    # base parameter object
    $param = @{
        name = $Name
        in = $In
        required = $Required.IsPresent
        deprecated = $Deprecated.IsPresent
        description = $Description
        schema = @{
            type = $PSCmdlet.ParameterSetName.ToLowerInvariant()
        }
    }

    # add enums if supplied
    if (!$Boolean -and !(Test-IsEmpty $Enum)) {
        $param.schema['enum'] = @($Enum)
    }

    # add format if supplied
    if (!$Boolean -and !(Test-IsEmpty $Format)) {
        $param.schema['format'] = $Format
    }

    # add default if supplied
    if ($null -ne $Default) {
        $param.schema['default'] = $Default
    }

    # add int minimum/maximum
    if ($Integer) {
        if ($Minimum -ne [int]::MinValue) {
            $param.schema['minimum'] = $Minimum
        }

        if ($Maximum -ne [int]::MaxValue) {
            $param.schema['maximum'] = $Maximum
        }
    }

    return $param
}

function Set-PodeOpenApiRouteMetaData
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [ValidateNotNullOrEmpty()]
        [hashtable[]]
        $Route,

        [Parameter()]
        [string]
        $Summary,

        [Parameter()]
        [string]
        $Description,

        [Parameter()]
        [string[]]
        $Tags,

        [switch]
        $Deprecated,

        [switch]
        $PassThru
    )

    foreach ($r in @($Route)) {
        $r.OpenApi.Summary = $Summary
        $r.OpenApi.Description = $Description
        $r.OpenApi.Tags = $Tags
        $r.OpenApi.Deprecated = $Deprecated.IsPresent
    }

    if ($PassThru) {
        return $Route
    }
}

function Enable-PodeSwaggerRoute
{
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path = '/swagger',

        [Parameter()]
        [string]
        $OpenApiPath,

        [Parameter()]
        [object[]]
        $Middleware,

        [Parameter()]
        [string]
        $Title
    )

    # error if there's no OpenAPI path
    $OpenApiPath = Protect-PodeValue -Value $OpenApiPath -Default $PodeContext.Server.OpenAPI.Path
    if ([string]::IsNullOrWhiteSpace($OpenApiPath)) {
        throw "No OpenAPI path supplied for Swagger to use"
    }

    # fail if no title
    $Title = Protect-PodeValue -Value $Title -Default $PodeContext.Server.OpenAPI.Title
    if ([string]::IsNullOrWhiteSpace($Title)) {
        throw "No title supplied for Swagger page"
    }

    # add the swagger route
    Add-PodeRoute -Method Get -Path $Path -Middleware $Middleware -ScriptBlock {
        param($e)
        $podeRoot = Get-PodeModuleMiscPath
        Write-PodeFileResponse -Path (Join-Path $podeRoot 'default-swagger.html.pode') -Data @{
            Title = $PodeContext.Server.OpenAPI.Title
            OpenApiPath = $PodeContext.Server.OpenAPI.Path
        }
    }
}


