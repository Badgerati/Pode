<#
.SYNOPSIS
Enables the OpenAPI default route in Pode.

.DESCRIPTION
Enables the OpenAPI default route in Pode, as well as setting up details like Title and API Version.

.PARAMETER Path
An optional custom route path to access the OpenAPI definition. (Default: /openapi)

.PARAMETER Title
The Title of the API.

.PARAMETER Version
The Version of the API. (Default: 0.0.0)

.PARAMETER Description
A Description of the API.

.PARAMETER RouteFilter
An optional route filter for routes that should be included in the definition. (Default: /*)

.PARAMETER Middleware
Like normal Routes, an array of Middleware that will be applied to the route.

.PARAMETER RestrictRoutes
If supplied, only routes that are available on the Requests URI will be used to generate the OpenAPI definition.

.EXAMPLE
Enable-PodeOpenApi -Title 'My API' -Version '1.0.0' -RouteFilter '/api/*'

.EXAMPLE
Enable-PodeOpenApi -Title 'My API' -Version '1.0.0' -RouteFilter '/api/*' -RestrictRoutes

.EXAMPLE
Enable-PodeOpenApi -Path '/docs/openapi' -Title 'My API' -Version '1.0.0'
#>
function Enable-PodeOpenApi
{
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path = '/openapi',

        [Parameter(Mandatory=$true)]
        [string]
        $Title,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $Version = '0.0.0',

        [Parameter()]
        [string]
        $Description,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $RouteFilter = '/*',

        [Parameter()]
        [object[]]
        $Middleware,

        [switch]
        $RestrictRoutes
    )

    # initialise openapi info
    $PodeContext.Server.OpenAPI.Title = $Title
    $PodeContext.Server.OpenAPI.Path = $Path

    $meta = @{
        Version = $Version
        Description = $Description
        RouteFilter = $RouteFilter
        RestrictRoutes = $RestrictRoutes
    }

    # add the OpenAPI route
    Add-PodeRoute -Method Get -Path $Path -ArgumentList $meta -Middleware $Middleware -ScriptBlock {
        param($meta)
        $strict = $meta.RestrictRoutes

        # generate the openapi definition
        $def = Get-PodeOpenApiDefinitionInternal `
            -Title $PodeContext.Server.OpenAPI.Title `
            -Version $meta.Version `
            -Description $meta.Description `
            -RouteFilter $meta.RouteFilter `
            -Protocol $WebEvent.Endpoint.Protocol `
            -Address $WebEvent.Endpoint.Address `
            -EndpointName $WebEvent.Endpoint.Name `
            -RestrictRoutes:$strict

        # write the openapi definition
        Write-PodeJsonResponse -Value $def -Depth 20
    }
}

<#
.SYNOPSIS
Gets the OpenAPI definition.

.DESCRIPTION
Gets the OpenAPI definition for custom use in routes, or other functions.

.PARAMETER Title
The Title of the API. (Default: the title supplied in Enable-PodeOpenApi)

.PARAMETER Version
The Version of the API. (Default: the version supplied in Enable-PodeOpenApi)

.PARAMETER Description
A Description of the API. (Default: the description supplied into Enable-PodeOpenApi)

.PARAMETER RouteFilter
An optional route filter for routes that should be included in the definition. (Default: /*)

.PARAMETER RestrictRoutes
If supplied, only routes that are available on the Requests URI will be used to generate the OpenAPI definition.

.EXAMPLE
$def = Get-PodeOpenApiDefinition -RouteFilter '/api/*'
#>
function Get-PodeOpenApiDefinition
{
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Title,

        [Parameter()]
        [string]
        $Version,

        [Parameter()]
        [string]
        $Description,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $RouteFilter = '/*',

        [switch]
        $RestrictRoutes
    )

    $Title = Protect-PodeValue -Value $Title -Default $PodeContext.Server.OpenAPI.Title
    if ([string]::IsNullOrWhiteSpace($Title)) {
        throw "No Title supplied for OpenAPI definition"
    }

    $Version = Protect-PodeValue -Value $Version -Default $PodeContext.Server.OpenAPI.Version
    if ([string]::IsNullOrWhiteSpace($Version)) {
        throw "No Version supplied for OpenAPI definition"
    }

    $Description = Protect-PodeValue -Value $Description -Default $PodeContext.Server.OpenAPI.Description

    # generate the openapi definition
    return (Get-PodeOpenApiDefinitionInternal `
        -Title $Title `
        -Version $Version `
        -Description $Description `
        -RouteFilter $RouteFilter `
        -Protocol $WebEvent.Endpoint.Protocol `
        -Address $WebEvent.Endpoint.Address `
        -EndpointName $WebEvent.Endpoint.Name `
        -RestrictRoutes:$RestrictRoutes)
}

<#
.SYNOPSIS
Adds a response definition to the supplied route.

.DESCRIPTION
Adds a response definition to the supplied route.

.PARAMETER Route
The route to add the response definition, usually from -PassThru on Add-PodeRoute.

.PARAMETER StatusCode
The HTTP StatusCode for the response.

.PARAMETER ContentSchemas
The content-types and schema the response returns (the schema is created using the Property functions).

.PARAMETER HeaderSchemas
The header name and schema the response returns (the schema is created using the Property functions).

.PARAMETER Description
A Description of the response. (Default: the HTTP StatusCode description)

.PARAMETER Reference
A Reference Name of an existing component response to use.

.PARAMETER Default
If supplied, the response will be used as a default response - this overrides the StatusCode supplied.

.PARAMETER PassThru
If supplied, the route passed in will be returned for further chaining.

.EXAMPLE
Add-PodeRoute -PassThru | Add-PodeOAResponse -StatusCode 200 -ContentSchemas @{ 'application/json' = (New-PodeOAIntProperty -Name 'userId' -Object) }

.EXAMPLE
Add-PodeRoute -PassThru | Add-PodeOAResponse -StatusCode 200 -ContentSchemas @{ 'application/json' = 'UserIdSchema' }

.EXAMPLE
Add-PodeRoute -PassThru | Add-PodeOAResponse -StatusCode 200 -Reference 'OKResponse'
#>
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

<#
.SYNOPSIS
Remove a response definition from the supplied route.

.DESCRIPTION
Remove a response definition from the supplied route.

.PARAMETER Route
The route to remove the response definition, usually from -PassThru on Add-PodeRoute.

.PARAMETER StatusCode
The HTTP StatusCode for the response to remove.

.PARAMETER Default
If supplied, the response will be used as a default response - this overrides the StatusCode supplied.

.PARAMETER PassThru
If supplied, the route passed in will be returned for further chaining.

.EXAMPLE
Add-PodeRoute -PassThru | Remove-PodeOAResponse -StatusCode 200

.EXAMPLE
Add-PodeRoute -PassThru | Remove-PodeOAResponse -StatusCode 201 -Default
#>
function Remove-PodeOAResponse
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

        [switch]
        $Default,

        [switch]
        $PassThru
    )

    # override status code with default
    $code = "$($StatusCode)"
    if ($Default) {
        $code = 'default'
    }

    # remove the respones from the routes
    foreach ($r in @($Route)) {
        if ($r.OpenApi.Responses.ContainsKey($code)) {
            $null = $r.OpenApi.Responses.Remove($code)
        }
    }

    if ($PassThru) {
        return $Route
    }
}

<#
.SYNOPSIS
Adds a reusable component for responses.

.DESCRIPTION
Adds a reusable component for responses.

.PARAMETER Name
The reference Name of the response.

.PARAMETER ContentSchemas
The content-types and schema the response returns (the schema is created using the Property functions).

.PARAMETER HeaderSchemas
The header name and schema the response returns (the schema is created using the Property functions).

.PARAMETER Description
The Description of the response.

.EXAMPLE
Add-PodeOAComponentResponse -Name 'OKResponse' -ContentSchemas @{ 'application/json' = (New-PodeOAIntProperty -Name 'userId' -Object) }

.EXAMPLE
Add-PodeOAComponentResponse -Name 'ErrorResponse' -ContentSchemas @{ 'application/json' = 'ErrorSchema' }
#>
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

<#
.SYNOPSIS
Sets the definition of a request for a route.

.DESCRIPTION
Sets the definition of a request for a route.

.PARAMETER Route
The route to set a request definition, usually from -PassThru on Add-PodeRoute.

.PARAMETER Parameters
The Parameter definitions the request uses (from ConvertTo-PodeOAParameter).

.PARAMETER RequestBody
The Request Body definition the request uses (from New-PodeOARequestBody).

.PARAMETER PassThru
If supplied, the route passed in will be returned for further chaining.

.EXAMPLE
Add-PodeRoute -PassThru | Set-PodeOARequest -RequestBody (New-PodeOARequestBody -Reference 'UserIdBody')
#>
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
        if (($null -ne $Parameters) -and ($Parameters.Length -gt 0)) {
            $r.OpenApi.Parameters = @($Parameters)
        }

        if ($null -ne $RequestBody) {
            $r.OpenApi.RequestBody = $RequestBody
        }
    }

    if ($PassThru) {
        return $Route
    }
}

<#
.SYNOPSIS
Creates a Request Body definition for routes.

.DESCRIPTION
Creates a Request Body definition for routes from the supplied content-types and schemas.

.PARAMETER Reference
A reference name from an existing component request body.

.PARAMETER ContentSchemas
The content-types and schema the request body accepts (the schema is created using the Property functions).

.PARAMETER Description
A Description of the request body.

.PARAMETER Required
If supplied, the request body will be flagged as required.

.EXAMPLE
New-PodeOARequestBody -ContentSchemas @{ 'application/json' = (New-PodeOAIntProperty -Name 'userId' -Object) }

.EXAMPLE
New-PodeOARequestBody -ContentSchemas @{ 'application/json' = 'UserIdSchema' }

.EXAMPLE
New-PodeOARequestBody -Reference 'UserIdBody'
#>
function New-PodeOARequestBody
{
    [CmdletBinding(DefaultParameterSetName='Schema')]
    param(
        [Parameter(Mandatory=$true, ParameterSetName='Reference')]
        [string]
        $Reference,

        [Parameter(Mandatory=$true, ParameterSetName='Schema')]
        [hashtable]
        $ContentSchemas,

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
                content = ($ContentSchemas | ConvertTo-PodeOAContentTypeSchema)
            }
        }

        'reference' {
            if (!(Test-PodeOAComponentRequestBody -Name $Reference)) {
                throw "The OpenApi component request body doesn't exist: $($Reference)"
            }

            return @{
                '$ref' = "#/components/requestBodies/$($Reference)"
            }
        }
    }
}

<#
.SYNOPSIS
Adds a reusable component for a request body.

.DESCRIPTION
Adds a reusable component for a request body.

.PARAMETER Name
The reference Name of the schema.

.PARAMETER Schema
The Schema definition (the schema is created using the Property functions).

.EXAMPLE
Add-PodeOAComponentSchema -Name 'UserIdSchema' -Schema (New-PodeOAIntProperty -Name 'userId' -Object)
#>
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

<#
.SYNOPSIS
Adds a reusable component for a request body.

.DESCRIPTION
Adds a reusable component for a request body.

.PARAMETER Name
The reference Name of the request body.

.PARAMETER ContentSchemas
The content-types and schema the request body accepts (the schema is created using the Property functions).

.PARAMETER Description
A Description of the request body.

.PARAMETER Required
If supplied, the request body will be flagged as required.

.EXAMPLE
Add-PodeOAComponentRequestBody -Name 'UserIdBody' -ContentSchemas @{ 'application/json' = (New-PodeOAIntProperty -Name 'userId' -Object) }

.EXAMPLE
Add-PodeOAComponentRequestBody -Name 'UserIdBody' -ContentSchemas @{ 'application/json' = 'UserIdSchema' }
#>
function Add-PodeOAComponentRequestBody
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Name,

        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [hashtable]
        $ContentSchemas,

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
        content = ($ContentSchemas | ConvertTo-PodeOAContentTypeSchema)
    }
}

<#
.SYNOPSIS
Adds a reusable component for a request parameter.

.DESCRIPTION
Adds a reusable component for a request parameter.

.PARAMETER Name
The reference Name of the parameter.

.PARAMETER Parameter
The Parameter to use for the component (from ConvertTo-PodeOAParameter)

.EXAMPLE
New-PodeOAIntProperty -Name 'userId' | ConvertTo-PodeOAParameter -In Query | Add-PodeOAComponentParameter -Name 'UserIdParam'
#>
function Add-PodeOAComponentParameter
{
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Name,

        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [hashtable]
        $Parameter
    )

    if ([string]::IsNullOrWhiteSpace($Name)) {
        $Name = $Parameter.name
    }

    $PodeContext.Server.OpenAPI.components.parameters[$Name] = $Parameter
}

<#
.SYNOPSIS
Creates a new OpenAPI integer property.

.DESCRIPTION
Creates a new OpenAPI integer property, for Schemas or Parameters.

.PARAMETER Name
The Name of the property.

.PARAMETER Format
The inbuilt OpenAPI Format of the integer. (Default: Any)

.PARAMETER Default
The default value of the property. (Default: 0)

.PARAMETER Minimum
The minimum value of the integer. (Default: Int.Min)

.PARAMETER Maximum
The maximum value of the integer. (Default: Int.Max)

.PARAMETER MultiplesOf
The integer must be in multiples of the supplied value.

.PARAMETER Description
A Description of the property.

.PARAMETER Enum
An optional array of values that this property can only be set to.

.PARAMETER Required
If supplied, the object will be treated as Required where supported.

.PARAMETER Deprecated
If supplied, the object will be treated as Deprecated where supported.

.PARAMETER Array
If supplied, the integer will be treated as an array of integers.

.PARAMETER Object
If supplied, the integer will be automatically wrapped in an object.

.EXAMPLE
New-PodeOANumberProperty -Name 'age' -Required
#>
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

        [Parameter()]
        [int[]]
        $Enum,

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

        meta = @{
            enum = $Enum
        }
    }

    if ($Minimum -ne [int]::MinValue) {
        $param.meta['minimum'] = $Minimum
    }

    if ($Maximum -ne [int]::MaxValue) {
        $param.meta['maximum'] = $Maximum
    }

    if ($MultiplesOf -ne 0) {
        $param.meta['multipleOf'] = $MultiplesOf
    }

    return $param
}

<#
.SYNOPSIS
Creates a new OpenAPI number property.

.DESCRIPTION
Creates a new OpenAPI number property, for Schemas or Parameters.

.PARAMETER Name
The Name of the property.

.PARAMETER Format
The inbuilt OpenAPI Format of the number. (Default: Any)

.PARAMETER Default
The default value of the property. (Default: 0)

.PARAMETER Minimum
The minimum value of the number. (Default: Double.Min)

.PARAMETER Maximum
The maximum value of the number. (Default: Double.Max)

.PARAMETER MultiplesOf
The number must be in multiples of the supplied value.

.PARAMETER Description
A Description of the property.

.PARAMETER Enum
An optional array of values that this property can only be set to.

.PARAMETER Required
If supplied, the object will be treated as Required where supported.

.PARAMETER Deprecated
If supplied, the object will be treated as Deprecated where supported.

.PARAMETER Array
If supplied, the number will be treated as an array of numbers.

.PARAMETER Object
If supplied, the number will be automatically wrapped in an object.

.EXAMPLE
New-PodeOANumberProperty -Name 'gravity' -Default 9.8
#>
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

        [Parameter()]
        [double[]]
        $Enum,

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
        type = 'number'
        array = $Array.IsPresent
        object = $Object.IsPresent
        required = $Required.IsPresent
        deprecated = $Deprecated.IsPresent
        description = $Description
        format = $Format.ToLowerInvariant()
        default = $Default

        meta = @{
            enum = $Enum
        }
    }

    if ($Minimum -ne [double]::MinValue) {
        $param.meta['minimum'] = $Minimum
    }

    if ($Maximum -ne [double]::MaxValue) {
        $param.meta['maximum'] = $Maximum
    }

    if ($MultiplesOf -ne 0) {
        $param.meta['multipleOf'] = $MultiplesOf
    }

    return $param
}

<#
.SYNOPSIS
Creates a new OpenAPI string property.

.DESCRIPTION
Creates a new OpenAPI string property, for Schemas or Parameters.

.PARAMETER Name
The Name of the property.

.PARAMETER Format
The inbuilt OpenAPI Format of the string. (Default: Any)

.PARAMETER CustomFormat
The name of a custom OpenAPI Format of the string. (Default: None)

.PARAMETER Default
The default value of the property. (Default: $null)

.PARAMETER MinLength
The minimum length of the string. (Default: Int.Min)

.PARAMETER MaxLength
The maximum length of the string. (Default: Int.Max)

.PARAMETER Pattern
A Regex pattern that the string must match.

.PARAMETER Description
A Description of the property.

.PARAMETER Enum
An optional array of values that this property can only be set to.

.PARAMETER Required
If supplied, the object will be treated as Required where supported.

.PARAMETER Deprecated
If supplied, the object will be treated as Deprecated where supported.

.PARAMETER Array
If supplied, the string will be treated as an array of strings.

.PARAMETER Object
If supplied, the string will be automatically wrapped in an object.

.EXAMPLE
New-PodeOAStringProperty -Name 'userType' -Default 'admin'

.EXAMPLE
New-PodeOAStringProperty -Name 'password' -Format Password
#>
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

        [Parameter()]
        [string[]]
        $Enum,

        [switch]
        $Required,

        [switch]
        $Deprecated,

        [switch]
        $Array,

        [switch]
        $Object
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
        default = $Default

        meta = @{
            enum = $Enum
            pattern = $Pattern
        }
    }

    if ($MinLength -ne [int]::MinValue) {
        $param.meta['minLength'] = $MinLength
    }

    if ($MaxLength -ne [int]::MaxValue) {
        $param.meta['maxLength'] = $MaxLength
    }

    return $param
}

<#
.SYNOPSIS
Creates a new OpenAPI boolean property.

.DESCRIPTION
Creates a new OpenAPI boolean property, for Schemas or Parameters.

.PARAMETER Name
The Name of the property.

.PARAMETER Default
The default value of the property. (Default: $false)

.PARAMETER Description
A Description of the property.

.PARAMETER Enum
An optional array of values that this property can only be set to.

.PARAMETER Required
If supplied, the object will be treated as Required where supported.

.PARAMETER Deprecated
If supplied, the object will be treated as Deprecated where supported.

.PARAMETER Array
If supplied, the boolean will be treated as an array of booleans.

.PARAMETER Object
If supplied, the boolean will be automatically wrapped in an object.

.EXAMPLE
New-PodeOABoolProperty -Name 'enabled' -Required
#>
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

        [Parameter()]
        [bool[]]
        $Enum,

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
        type = 'boolean'
        array = $Array.IsPresent
        object = $Object.IsPresent
        required = $Required.IsPresent
        deprecated = $Deprecated.IsPresent
        description = $Description
        default = $Default

        meta = @{
            enum = $Enum
        }
    }

    return $param
}

<#
.SYNOPSIS
Creates a new OpenAPI object property from other properties.

.DESCRIPTION
Creates a new OpenAPI object property from other properties, for Schemas or Parameters.

.PARAMETER Name
The Name of the property.

.PARAMETER Properties
An array of other int/string/etc properties wrap up as an object.

.PARAMETER Description
A Description of the property.

.PARAMETER Required
If supplied, the object will be treated as Required where supported.

.PARAMETER Deprecated
If supplied, the object will be treated as Deprecated where supported.

.PARAMETER Array
If supplied, the object will be treated as an array of objects.

.EXAMPLE
New-PodeOAObjectProperty -Name 'user' -Properties @('<ARRAY_OF_PROPERTIES>')
#>
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

<#
.SYNOPSIS
Creates a OpenAPI schema reference property.

.DESCRIPTION
Creates a new OpenAPI schema reference from another OpenAPI schema.

.PARAMETER Name
The Name of the property.

.PARAMETER Reference
An component schema name.

.PARAMETER Description
A Description of the property.

.PARAMETER Array
If supplied, the schema reference will be treated as an array.

.EXAMPLE
New-PodeOASchemaProperty -Name 'Config' -ComponentSchema "MyConfigSchema"
#>
function New-PodeOASchemaProperty
{
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Name,

        [Parameter(Mandatory=$true)]
        [string]
        $Reference,

        [Parameter()]
        [string]
        $Description,

        [switch]
        $Array
    )

    if(!(Test-PodeOAComponentSchema -Name $Reference)) {
        throw "The OpenApi component schema doesn't exist: $($Reference)"
    }

    $param = @{
        name = $Name
        type = 'schema'
        schema = $Reference
        array = $Array.IsPresent
        description = $Description
    }

    return $param
}

<#
.SYNOPSIS
Converts an OpenAPI property into a Request Parameter.

.DESCRIPTION
Converts an OpenAPI property (such as from New-PodeOAIntProperty) into a Request Parameter.

.PARAMETER In
Where in the Request can the parameter be found?

.PARAMETER Property
The Property that need converting (such as from New-PodeOAIntProperty).

.PARAMETER Reference
The name of an existing component parameter to be reused.

.EXAMPLE
New-PodeOAIntProperty -Name 'userId' | ConvertTo-PodeOAParameter -In Query

.EXAMPLE
ConvertTo-PodeOAParameter -Reference 'UserIdParam'
#>
function ConvertTo-PodeOAParameter
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

        return @{
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
        description = $Property.description
        schema = @{
            type = $Property.type
            format = $Property.format
            #enum = $Property.meta.enum
        }
    }

    if ($null -ne $Property.meta) {
        foreach ($key in $Property.meta.Keys) {
            $prop.schema[$key] = $Property.meta[$key]
        }
    }

    if ($Property.deprecated) {
        $prop['deprecated'] = $Property.deprecated
    }

    if ($Property.required) {
        $prop['required'] = $Property.required
    }

    # remove default for required parameter
    if (!$Property.required) {
        $prop.schema['default'] = $Property.default
    }

    return $prop
}

<#
.SYNOPSIS
Sets metadate for the supplied route.

.DESCRIPTION
Sets metadate for the supplied route, such as Summary and Tags.

.PARAMETER Route
The route to update info, usually from -PassThru on Add-PodeRoute.

.PARAMETER Summary
A quick Summary of the route.

.PARAMETER Description
A longer Description of the route.

.PARAMETER OperationId
Sets the OperationId of the route.

.PARAMETER Tags
An array of Tags for the route, mostly for grouping.

.PARAMETER Deprecated
If supplied, the route will be flagged as deprecated.

.PARAMETER PassThru
If supplied, the route passed in will be returned for further chaining.

.EXAMPLE
Add-PodeRoute -PassThru | Set-PodeOARouteInfo -Summary 'A quick summary' -Tags 'Admin'
#>
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
        [string]
        $OperationId,

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
        $r.OpenApi.OperationId = $OperationId
        $r.OpenApi.Tags = $Tags
        $r.OpenApi.Deprecated = $Deprecated.IsPresent
    }

    if ($PassThru) {
        return $Route
    }
}

<#
.SYNOPSIS
Adds a route that enables a viewer to display OpenAPI docs, such as Swagger or ReDoc.

.DESCRIPTION
Adds a route that enables a viewer to display OpenAPI docs, such as Swagger or ReDoc.

.PARAMETER Type
The Type of OpenAPI viewer to use.

.PARAMETER Path
The route Path where the docs can be accessed. (Default: "/$Type")

.PARAMETER OpenApiUrl
The URL where the OpenAPI definition can be retrieved. (Default is the OpenAPI path from Enable-PodeOpenApi)

.PARAMETER Middleware
Like normal Routes, an array of Middleware that will be applied.

.PARAMETER Title
The title of the web page.

.PARAMETER DarkMode
If supplied, the page will be rendered using a dark theme (this is not supported for all viewers).

.EXAMPLE
Enable-PodeOpenApiViewer -Type Swagger -DarkMode

.EXAMPLE
Enable-PodeOpenApiViewer -Type ReDoc -Title 'Some Title' -OpenApi 'http://some-url/openapi'
#>
function Enable-PodeOpenApiViewer
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('Swagger', 'ReDoc')]
        [string]
        $Type,

        [Parameter()]
        [string]
        $Path,

        [Parameter()]
        [string]
        $OpenApiUrl,

        [Parameter()]
        [object[]]
        $Middleware,

        [Parameter()]
        [string]
        $Title,

        [switch]
        $DarkMode
    )

    # error if there's no OpenAPI URL
    $OpenApiUrl = Protect-PodeValue -Value $OpenApiUrl -Default $PodeContext.Server.OpenAPI.Path
    if ([string]::IsNullOrWhiteSpace($OpenApiUrl)) {
        throw "No OpenAPI URL supplied for $($Type)"
    }

    # fail if no title
    $Title = Protect-PodeValue -Value $Title -Default $PodeContext.Server.OpenAPI.Title
    $Title = Protect-PodeValue -Value $Title -Default $Type
    if ([string]::IsNullOrWhiteSpace($Title)) {
        throw "No title supplied for $($Type) page"
    }

    # set a default path
    $Path = Protect-PodeValue -Value $Path -Default "/$($Type.ToLowerInvariant())"
    if ([string]::IsNullOrWhiteSpace($Title)) {
        throw "No route path supplied for $($Type) page"
    }

    # setup meta info
    $meta = @{
        Type = $Type.ToLowerInvariant()
        Title = $Title
        OpenApi = $OpenApiUrl
        DarkMode = $DarkMode
    }

    # add the viewer route
    Add-PodeRoute -Method Get -Path $Path -Middleware $Middleware -ArgumentList $meta -ScriptBlock {
        param($meta)
        $podeRoot = Get-PodeModuleMiscPath
        Write-PodeFileResponse -Path ([System.IO.Path]::Combine($podeRoot, "default-$($meta.Type).html.pode")) -Data @{
            Title = $meta.Title
            OpenApi = $meta.OpenApi
            DarkMode = $meta.DarkMode
        }
    }
}