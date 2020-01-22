function Enable-PodeOpenApi
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
        $Route = '/',

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
        $Description,

        [switch]
        $RestrictRoutes
    )

    # initialise openapi info
    $PodeContext.Server.OpenAPI.Title = $Title
    $PodeContext.Server.OpenAPI.Path = $Path

    $meta = @{
        Title = $Title
        Version = $Version
        Description = $Description
        Route = $Route
        RestrictRoutes = $RestrictRoutes
    }

    # add the OpenAPI route
    Add-PodeRoute -Method Get -Path $Path -ArgumentList $meta -Middleware $Middleware -ScriptBlock {
        param($e, $meta)
        $strict = $meta.RestrictRoutes

        # generate the openapi definition
        $def = Get-PodeOpenApiDefinition `
            -Title $meta.Title `
            -Description $meta.Description `
            -Version $meta.Version `
            -Route $meta.Route `
            -Protocol $e.Protocol `
            -Endpoint $e.Endpoint `
            -RestrictRoutes:$strict

        # write the openapi definition
        Write-PodeJsonResponse -Value $def -Depth 20
    }
}

function Add-PodeOAResponse
{
    [CmdletBinding(DefaultParameterSetName='Schema')]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [ValidateNotNullOrEmpty()]
        [hashtable[]]
        $Route,

        [Parameter(Mandatory=$true)]
        [int]
        $StatusCode,

        [Parameter(ParameterSetName='Schema')]
        [hashtable]
        $ContentSchemas,

        [Parameter(ParameterSetName='Schema')]
        [hashtable]
        $HeaderSchemas,

        [Parameter(ParameterSetName='Schema')]
        [string]
        $Description = $null,

        [Parameter(Mandatory=$true, ParameterSetName='Reference')]
        [string]
        $Reference,

        [switch]
        $Default,

        [switch]
        $PassThru
    )

    # set a general description for the status code
    if (!$Default -and [string]::IsNullOrWhiteSpace($Description)) {
        $Description = Get-PodeStatusDescription -StatusCode $StatusCode
    }

    # override status code with default
    $code = "$($StatusCode)"
    if ($Default) {
        $code = 'default'
    }

    # schemas or component reference?
    switch ($PSCmdlet.ParameterSetName.ToLowerInvariant()) {
        'schema' {
            # build any content-type schemas
            $content = $null
            if ($null -ne $ContentSchemas) {
                $content = ($ContentSchemas | ConvertTo-PodeOAContentTypeSchema)
            }

            # build any header schemas
            $headers = $null
            if ($null -ne $HeaderSchemas) {
                $headers = ($HeaderSchemas | ConvertTo-PodeOAHeaderSchema)
            }
        }

        'reference' {
            if (!(Test-PodeOAComponentResponse -Name $Reference)) {
                throw "The OpenApi component response doesn't exist: $($Reference)"
            }
        }
    }

    # add the respones to the routes
    foreach ($r in @($Route)) {
        switch ($PSCmdlet.ParameterSetName.ToLowerInvariant()) {
            'schema' {
                $r.OpenApi.Responses[$code] = @{
                    description = $Description
                    content = $content
                    headers = $headers
                }
            }

            'reference' {
                $r.OpenApi.Responses[$code] = @{
                    '$ref' = "#/components/responses/$($Reference)"
                }
            }
        }
    }

    if ($PassThru) {
        return $Route
    }
}

function Add-PodeOAComponentResponse
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Name,

        [Parameter()]
        [hashtable]
        $ContentSchemas,

        [Parameter()]
        [hashtable]
        $HeaderSchemas,

        [Parameter(Mandatory=$true)]
        [string]
        $Description
    )

    $content = $null
    if ($null -ne $ContentSchemas) {
        $content = ($ContentSchemas | ConvertTo-PodeOAContentTypeSchema)
    }

    $headers = $null
    if ($null -ne $HeaderSchemas) {
        $headers = ($HeaderSchemas | ConvertTo-PodeOAHeaderSchema)
    }

    $PodeContext.Server.OpenAPI.components.responses[$Name] = @{
        description = $Description
        content = $content
        headers = $headers
    }
}

function Set-PodeOAAuth
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [ValidateNotNullOrEmpty()]
        [hashtable[]]
        $Route,

        [Parameter()]
        [string[]]
        $Name,

        [switch]
        $PassThru
    )

    foreach ($n in @($Name)) {
        if (!$PodeContext.Server.Authentications.ContainsKey($n)) {
            throw "Authentication method does not exist: $($n)"
        }
    }

    foreach ($r in @($Route)) {
        $r.OpenApi.Authentication = @(foreach ($n in @($Name)) {
            @{
                "$($n -replace '\s+', '')" = @()
            }
        })
    }

    if ($PassThru) {
        return $Route
    }
}

function Set-PodeOAGlobalAuth
{
    [CmdletBinding()]
    param(
        [Parameter()]
        [string[]]
        $Name
    )

    foreach ($n in @($Name)) {
        if (!$PodeContext.Server.Authentications.ContainsKey($n)) {
            throw "Authentication method does not exist: $($n)"
        }
    }

    $PodeContext.Server.OpenAPI.security = @(foreach ($n in @($Name)) {
        @{
            "$($n -replace '\s+', '')" = @()
        }
    })
}

function Set-PodeOARequest
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

        [Parameter()]
        [hashtable]
        $RequestBody,

        [switch]
        $PassThru
    )

    foreach ($r in @($Route)) {
        $r.OpenApi.Parameters = @($Parameters)
        $r.OpenApi.RequestBody = $RequestBody
    }

    if ($PassThru) {
        return $Route
    }
}

function New-PodeOARequestBody
{
    [CmdletBinding(DefaultParameterSetName='Schema')]
    param(
        [Parameter(Mandatory=$true, ParameterSetName='Reference')]
        [string]
        $Reference,

        [Parameter(Mandatory=$true, ParameterSetName='Schema')]
        [hashtable]
        $Schemas,

        [Parameter(ParameterSetName='Schema')]
        [string]
        $Description = $null,

        [Parameter(ParameterSetName='Schema')]
        [switch]
        $Required
    )

    switch ($PSCmdlet.ParameterSetName.ToLowerInvariant()) {
        'schema' {
            return @{
                required = $Required.IsPresent
                description = $Description
                content = ($Schemas | ConvertTo-PodeOAContentTypeSchema)
            }
        }

        'reference' {
            if (!(Test-PodeOAComponentRequestBody -Name $Reference)) {
                throw "The OpenApi component request body doesn't exist: $($Reference)"
            }

            return = @{
                '$ref' = "#/components/requestBodies/$($Reference)"
            }
        }
    }
}

function Add-PodeOAComponentSchema
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Name,

        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [hashtable]
        $Schema
    )

    $PodeContext.Server.OpenAPI.components.schemas[$Name] = ($Schema | ConvertTo-PodeOASchemaProperty)
}

function Add-PodeOAComponentRequestBody
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Name,

        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [hashtable]
        $Schemas,

        [Parameter()]
        [string]
        $Description = $null,

        [Parameter()]
        [switch]
        $Required
    )

    $PodeContext.Server.OpenAPI.components.requestBodies[$Name] = @{
        required = $Required.IsPresent
        description = $Description
        content = ($Schemas | ConvertTo-PodeOAContentTypeSchema)
    }
}

function Add-PodeOAComponentParameter
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [hashtable]
        $Parameter,

        [Parameter()]
        [string]
        $Name
    )

    if ([string]::IsNullOrWhiteSpace($Name)) {
        $Name = $Parameter.name
    }

    $PodeContext.Server.OpenAPI.components.responses[$Name] = $Parameter
}

function New-PodeOAIntProperty
{
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Name,

        [Parameter()]
        [ValidateSet('', 'Int32', 'Int64')]
        [string]
        $Format,

        [Parameter()]
        [int]
        $Default = 0,

        [Parameter()]
        [int]
        $Minimum = [int]::MinValue,

        [Parameter()]
        [int]
        $Maximum = [int]::MaxValue,

        [Parameter()]
        [int]
        $MultiplesOf = 0,

        [Parameter()]
        [string]
        $Description,

        [switch]
        $Required,

        [switch]
        $Deprecated,

        [switch]
        $Array,

        [switch]
        $Object
    )

    $param = @{
        name = $Name
        type = 'integer'
        array = $Array.IsPresent
        object = $Object.IsPresent
        required = $Required.IsPresent
        deprecated = $Deprecated.IsPresent
        description = $Description
        format = $Format.ToLowerInvariant()
        default = $Default
    }

    if ($Minimum -ne [int]::MinValue) {
        $param['minimum'] = $Minimum
    }

    if ($Maximum -ne [int]::MaxValue) {
        $param['maximum'] = $Maximum
    }

    if ($MultiplesOf -ne 0) {
        $param['multipleOf'] = $MultiplesOf
    }

    return $param
}

function New-PodeOANumberProperty
{
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Name,

        [Parameter()]
        [ValidateSet('', 'Double', 'Float')]
        [string]
        $Format,

        [Parameter()]
        [double]
        $Default = 0,

        [Parameter()]
        [double]
        $Minimum = [double]::MinValue,

        [Parameter()]
        [double]
        $Maximum = [double]::MaxValue,

        [Parameter()]
        [double]
        $MultiplesOf = 0,

        [Parameter()]
        [string]
        $Description,

        [switch]
        $Required,

        [switch]
        $Deprecated,

        [switch]
        $Array
    )

    $param = @{
        name = $Name
        type = 'number'
        array = $Array.IsPresent
        object = $Object.IsPresent
        required = $Required.IsPresent
        deprecated = $Deprecated.IsPresent
        description = $Description
        format = $Format.ToLowerInvariant()
        default = $Default
    }

    if ($Minimum -ne [double]::MinValue) {
        $param['minimum'] = $Minimum
    }

    if ($Maximum -ne [double]::MaxValue) {
        $param['maximum'] = $Maximum
    }

    if ($MultiplesOf -ne 0) {
        $param['multipleOf'] = $MultiplesOf
    }

    return $param
}

function New-PodeOAStringProperty
{
    [CmdletBinding(DefaultParameterSetName='Inbuilt')]
    param(
        [Parameter()]
        [string]
        $Name,

        [Parameter(ParameterSetName='Inbuilt')]
        [ValidateSet('', 'Binary', 'Byte', 'Date', 'Date-Time', 'Password')]
        [string]
        $Format,

        [Parameter(ParameterSetName='Custom')]
        [string]
        $CustomFormat,

        [Parameter()]
        [string]
        $Default = $null,

        [Parameter()]
        [int]
        $MinLength = [int]::MinValue,

        [Parameter()]
        [int]
        $MaxLength = [int]::MaxValue,

        [Parameter()]
        [string]
        $Pattern = $null,

        [Parameter()]
        [string]
        $Description,

        [switch]
        $Required,

        [switch]
        $Deprecated,

        [switch]
        $Array
    )

    $_format = $Format
    if (![string]::IsNullOrWhiteSpace($CustomFormat)) {
        $_format = $CustomFormat
    }

    $param = @{
        name = $Name
        type = 'string'
        array = $Array.IsPresent
        object = $Object.IsPresent
        required = $Required.IsPresent
        deprecated = $Deprecated.IsPresent
        description = $Description
        format = $_format.ToLowerInvariant()
        pattern = $Pattern
        default = $Default
    }

    if ($MinLength -ne [int]::MinValue) {
        $param['minLength'] = $MinLength
    }

    if ($MaxLength -ne [int]::MaxValue) {
        $param['maxLength'] = $MaxLength
    }

    return $param
}

function New-PodeOABoolProperty
{
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Name,

        [Parameter()]
        [bool]
        $Default = $false,

        [Parameter()]
        [string]
        $Description,

        [switch]
        $Required,

        [switch]
        $Deprecated,

        [switch]
        $Array
    )

    $param = @{
        name = $Name
        type = 'boolean'
        array = $Array.IsPresent
        object = $Object.IsPresent
        required = $Required.IsPresent
        deprecated = $Deprecated.IsPresent
        description = $Description
        default = $Default
    }

    return $param
}

function New-PodeOAObjectProperty
{
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Name,

        [Parameter(Mandatory=$true)]
        [hashtable[]]
        $Properties,

        [Parameter()]
        [string]
        $Description,

        [switch]
        $Required,

        [switch]
        $Deprecated,

        [switch]
        $Array
    )

    $param = @{
        name = $Name
        type = 'object'
        array = $Array.IsPresent
        required = $Required.IsPresent
        deprecated = $Deprecated.IsPresent
        description = $Description
        properties = $Properties
        default = $Default
    }

    return $param
}

function New-PodeOARequestParameter
{
    [CmdletBinding(DefaultParameterSetName='Reference')]
    param(
        [Parameter(Mandatory=$true, ParameterSetName='Schema')]
        [ValidateSet('Cookie', 'Header', 'Path', 'Query')]
        [string]
        $In,

        [Parameter(Mandatory=$true, ValueFromPipeline=$true, ParameterSetName='Schema')]
        [ValidateNotNull()]
        [hashtable]
        $Property,

        [Parameter(Mandatory=$true, ParameterSetName='Reference')]
        [string]
        $Reference
    )

    # return a reference
    if ($PSCmdlet.ParameterSetName -ieq 'reference') {
        if (!(Test-PodeOAComponentParameter -Name $Reference)) {
            throw "The OpenApi component request parameter doesn't exist: $($Reference)"
        }

        return = @{
            '$ref' = "#/components/parameters/$($Reference)"
        }
    }

    # non-object/array only
    if (@('array', 'object') -icontains $Property.type) {
        throw "OpenApi request parameter cannot be an array of object"
    }

    # build the base parameter
    $prop = @{
        in = $In.ToLowerInvariant()
        name = $Property.name
        required = $Property.required
        description = $Property.description
        deprecated = $Property.deprecated
        schema = @{
            type = $Property.type
            format = $Property.format
        }
    }

    # remove default for required parameter
    if (!$Property.required) {
        $prop.schema['default'] = $Property.default
    }

    return $prop
}

function Set-PodeOARouteInfo
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

function Enable-PodeSwagger
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
        $Title,

        [switch]
        $DarkMode
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
    Add-PodeRoute -Method Get -Path $Path -Middleware $Middleware -ArgumentList @{ DarkMode = $DarkMode } -ScriptBlock {
        param($e, $meta)
        $podeRoot = Get-PodeModuleMiscPath
        Write-PodeFileResponse -Path (Join-Path $podeRoot 'default-swagger.html.pode') -Data @{
            Title = $PodeContext.Server.OpenAPI.Title
            OpenApiPath = $PodeContext.Server.OpenAPI.Path
            DarkMode = $meta.DarkMode
        }
    }
}
