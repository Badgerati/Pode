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

.PARAMETER ExtraInfo
The non-essential metadata about the API. The metadata MAY be used by the clients if needed, and MAY be presented in editing or documentation generation tools for convenience.
The parameter is created by New-PodeOAExtraInfo  

.PARAMETER ExternalDoc
Additional external documentation for this operation.
The parameter is created by Add-PodeOAExternalDoc

.PARAMETER RouteFilter
An optional route filter for routes that should be included in the definition. (Default: /*)

.PARAMETER Middleware
Like normal Routes, an array of Middleware that will be applied to the route.

.PARAMETER RestrictRoutes
If supplied, only routes that are available on the Requests URI will be used to generate the OpenAPI definition.

.PARAMETER ServerUrl
If supplied, will be used as URL base to generate the OpenAPI definition.

.EXAMPLE
Enable-PodeOpenApi -Title 'My API' -Version '1.0.0' -RouteFilter '/api/*'

.EXAMPLE
Enable-PodeOpenApi -Title 'My API' -Version '1.0.0' -RouteFilter '/api/*' -RestrictRoutes

.EXAMPLE
Enable-PodeOpenApi -Path '/docs/openapi' -Title 'My API' -Version '1.0.0'
#>
function Enable-PodeOpenApi {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path = '/openapi',

        [Parameter(Mandatory = $true)]
        [string]
        $Title,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $Version = '0.0.0',

        [Parameter()]
        [string]
        $Description,

        [Parameter(ValueFromPipeline = $true)]
        [hashtable]
        $ExtraInfo,

        [Parameter()]
        [string]
        $ExternalDoc,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $RouteFilter = '/*',

        [Parameter()]
        [object[]]
        $Middleware,

        [switch]
        $RestrictRoutes,

        [Parameter()]
        [string]
        $ServerUrl

    )

    # initialise openapi info
    $PodeContext.Server.OpenAPI.Title = $Title
    $PodeContext.Server.OpenAPI.Path = $Path 
    $meta = @{
        Version        = $Version
        Description    = $Description
        RouteFilter    = $RouteFilter
        RestrictRoutes = $RestrictRoutes  
    }

    if ($ServerUrl) {
        $meta.ServerUrl = $ServerUrl
    } 

    if ($ExtraInfo) {
        $meta.ExtraInfo = $ExtraInfo
    }

    if ($ExternalDoc) {
        if ( !(Test-PodeOAExternalDoc -Name $ExternalDoc)) {
            throw "The ExternalDoc doesn't exist: $ExternalDoc"
        }  
        $meta.ExternalDocs = $PodeContext.Server.OpenAPI.hiddenComponents.externalDocs[$ExternalDoc]
    }
    
    # add the OpenAPI route
    Add-PodeRoute -Method Get -Path $Path -ArgumentList $meta -Middleware $Middleware -ScriptBlock {
        param($meta)

        # generate the openapi definition
        $def = Get-PodeOpenApiDefinitionInternal `
            -Title $PodeContext.Server.OpenAPI.Title `
            -Protocol $WebEvent.Endpoint.Protocol `
            -Address $WebEvent.Endpoint.Address `
            -EndpointName $WebEvent.Endpoint.Name `
            -MetaInfo $meta 
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
function Get-PodeOpenApiDefinition {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Title 
    )

    $Title = Protect-PodeValue -Value $Title -Default $PodeContext.Server.OpenAPI.Title
    if ([string]::IsNullOrWhiteSpace($Title)) {
        throw 'No Title supplied for OpenAPI definition'
    } 

    return Get-PodeOpenApiDefinitionInternal -Title $Title 
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

.PARAMETER ContentArray
If supplied, the Content Schema will be considered an array

.PARAMETER HeaderArray
If supplied, the Header Schema will be considered an array

.PARAMETER PassThru
If supplied, the route passed in will be returned for further chaining.

.EXAMPLE
Add-PodeRoute -PassThru | Add-PodeOAResponse -StatusCode 200 -ContentSchemas @{ 'application/json' = (New-PodeOAIntProperty -Name 'userId' -Object) }

.EXAMPLE
Add-PodeRoute -PassThru | Add-PodeOAResponse -StatusCode 200 -ContentSchemas @{ 'application/json' = 'UserIdSchema' }

.EXAMPLE
Add-PodeRoute -PassThru | Add-PodeOAResponse -StatusCode 200 -Reference 'OKResponse'
#>
function Add-PodeOAResponse {
    [CmdletBinding(DefaultParameterSetName = 'Schema')]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [hashtable[]]
        $Route,

        [Parameter(Mandatory = $true, ParameterSetName = 'Schema')]
        [Parameter(Mandatory = $true, ParameterSetName = 'Reference')]
        [int]
        $StatusCode,

        [Parameter(ParameterSetName = 'Schema')]
        [Parameter(ParameterSetName = 'SchemaDefault')]
        [hashtable]
        $ContentSchemas,

        [Parameter(ParameterSetName = 'Schema')] 
        [Parameter(ParameterSetName = 'SchemaDefault')]
        [string[]]
        $HeaderSchemas,

        [Parameter(ParameterSetName = 'Schema')]
        [Parameter(ParameterSetName = 'SchemaDefault')]
        [string]
        $Description = $null,

        [Parameter(Mandatory = $true, ParameterSetName = 'Reference')]
        [Parameter(ParameterSetName = 'ReferenceDefault')]
        [string]
        $Reference,

        [Parameter(Mandatory = $true, ParameterSetName = 'ReferenceDefault')]
        [Parameter(Mandatory = $true, ParameterSetName = 'SchemaDefault')]
        [switch]
        $Default,

        [Parameter(ParameterSetName = 'Schema')] 
        [Parameter(ParameterSetName = 'SchemaDefault')]
        [switch]
        $ContentArray,
        
        [Parameter(ParameterSetName = 'Schema')] 
        [Parameter(ParameterSetName = 'SchemaDefault')]
        [switch]
        $HeaderArray,

        [switch]
        $PassThru
    )

    # set a general description for the status code
    if (!$Default -and [string]::IsNullOrWhiteSpace($Description)) {
        $Description = Get-PodeStatusDescription -StatusCode $StatusCode
    }

    # override status code with default
    if ($Default) {
        $code = 'default'
    } else {
        $code = "$($StatusCode)"
    }

    # schemas or component reference?
    switch ($PSCmdlet.ParameterSetName.ToLowerInvariant()) {
        { $_ -in 'schema', 'schemadefault' } {
            # build any content-type schemas
            $content = $null
            if ($null -ne $ContentSchemas) {  
                $content = ConvertTo-PodeOAContentTypeSchema -Schemas $ContentSchemas -Array:$ContentArray 
            }

            # build any header schemas
            $headers = $null
            if ($null -ne $HeaderSchemas) {
                $headers = ConvertTo-PodeOAHeaderSchema -Schemas $HeaderSchemas -Array:$HeaderArray 
            }
        }

        { $_ -in 'reference', 'referencedefault' } {
            if (!(Test-PodeOAComponentResponse -Name $Reference)) {
                throw "The OpenApi component response doesn't exist: $($Reference)"
            }
        }
    }

    # add the respones to the routes
    foreach ($r in @($Route)) {
        switch ($PSCmdlet.ParameterSetName.ToLowerInvariant()) {
            { $_ -in 'schema', 'schemadefault' } {
                $r.OpenApi.Responses[$code] = @{
                    description = $Description
                    content     = $content
                    headers     = $headers
                }
            }
 
            { $_ -in 'reference', 'referencedefault' } {
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
function Remove-PodeOAResponse {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [hashtable[]]
        $Route,

        [Parameter(Mandatory = $true)]
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

.PARAMETER ContentArray
If supplied, the Content Schema will be considered an array

.PARAMETER HeaderArray
If supplied, the Header Schema will be considered an array

.EXAMPLE
Add-PodeOAComponentResponse -Name 'OKResponse' -ContentSchemas @{ 'application/json' = (New-PodeOAIntProperty -Name 'userId' -Object) }

.EXAMPLE
Add-PodeOAComponentResponse -Name 'ErrorResponse' -ContentSchemas @{ 'application/json' = 'ErrorSchema' }
#>
function Add-PodeOAComponentResponse {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [hashtable]
        $ContentSchemas,

        [Parameter()]
        [string[]]
        $HeaderSchemas,

        [Parameter(Mandatory = $true)]
        [string]
        $Description,

        [Parameter()]
        [switch]
        $ContentArray,

        [Parameter()]
        [switch]
        $HeaderArray
    )

    $content = $null
    if ($null -ne $ContentSchemas) {
        $content = ConvertTo-PodeOAContentTypeSchema -Schemas $ContentSchemas -Array:$ContentArray 
    }

    $headers = $null
    if ($null -ne $HeaderSchemas) {
        $headers = ConvertTo-PodeOAHeaderSchema -Schemas $HeaderSchemas -Array:$HeaderArray 
    }

    $PodeContext.Server.OpenAPI.components.responses[$Name] = @{
        description = $Description
        content     = $content
        headers     = $headers
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
function Set-PodeOARequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
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
function New-PodeOARequestBody {
    [CmdletBinding(DefaultParameterSetName = 'Schema')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'Reference')]
        [string]
        $Reference,

        [Parameter(Mandatory = $true, ParameterSetName = 'Schema')]
        [hashtable]
        $ContentSchemas,

        [Parameter(ParameterSetName = 'Schema')]
        [string]
        $Description = $null,

        [Parameter(ParameterSetName = 'Schema')]
        [switch]
        $Required
    )

    switch ($PSCmdlet.ParameterSetName.ToLowerInvariant()) {
        'schema' {
            $param = @{content = ConvertTo-PodeOAContentTypeSchema -Schemas $ContentSchemas }

            if ($Required.IsPresent) { $param['required'] = $Required.ToBool() }

            if ( $Description) { $param['description'] = $Description } 

            return $param
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
function Add-PodeOAComponentSchema {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,   

        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [hashtable]
        $Schema

    )

    $PodeContext.Server.OpenAPI.components.schemas[$Name] = ($Schema | ConvertTo-PodeOASchemaProperty)  

    $json = $PodeContext.Server.OpenAPI.components.schemas[$Name] | ConvertTo-Json -Depth 20 -Compress
    $obj = ConvertFrom-Json $json -AsHashtable
    Resolve-References -obj $obj -schemas $PodeContext.Server.OpenAPI.components.schemas

    $PodeContext.Server.OpenAPI.hiddenComponents.schemaJson[$Name] = $obj | ConvertTo-Json -Depth 20 
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
Add-PodeOAComponentHeaderSchema -Name 'UserIdSchema' -Schema (New-PodeOAIntProperty -Name 'userId' -Object)
#>
function Add-PodeOAComponentHeaderSchema {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,   

        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [hashtable]
        $Schema

    )

    $PodeContext.Server.OpenAPI.hiddenComponents.headerSchemas[$Name] = ($Schema | ConvertTo-PodeOASchemaProperty) 
    
}

<#
.SYNOPSIS
Validate a parameter with a provided schema.

.DESCRIPTION
Validate the parameter of a method against it's own schema 

.PARAMETER Json
The object in Json format to validate

.PARAMETER SchemaReference
The schema name to use to validate the property.

.PARAMETER Depth
Specifies how many levels of the parameter objects are included in the JSON representation.


.OUTPUTS
result: true if the object is validate positively
message: any validation issue

.EXAMPLE
$UserInfo = Test-PodeOARequestSchema -Parameter 'UserInfo' -SchemaReference 'UserIdSchema'}

#>

function Test-PodeOARequestSchema {
    param (
        [Parameter(Mandatory = $true)]
        [String]
        $Json,
        [Parameter(Mandatory = $true)]
        [string]
        $SchemaReference 
    )  
    
    if (!(Test-PodeOAComponentSchemaJson -Name $SchemaReference)) {
        throw "The OpenApi component schema in Json doesn't exist: $SchemaReference"
    } 

    $result = Test-Json -Json $Json -Schema $PodeContext.Server.OpenAPI.hiddenComponents.schemaJson[$SchemaReference] -ErrorVariable jsonValidationErrors 

    [string[]] $message = @()
    if ($jsonValidationErrors) {
        foreach ($item in $jsonValidationErrors) { $message += $item }  
    }

    return @{result = $result; message = $message }
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
function Add-PodeOAComponentRequestBody {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [hashtable]
        $ContentSchemas,

        [Parameter()]
        [string]
        $Description  ,

        [Parameter()]
        [switch]
        $Required
    )
    $param = @{ content = ($ContentSchemas | ConvertTo-PodeOAContentTypeSchema) }

    if ($Required.IsPresent) { $param['required'] = $Required.ToBool() }

    if ( $Description) { $param['description'] = $Description } 

    $PodeContext.Server.OpenAPI.components.requestBodies[$Name] = $param
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
function Add-PodeOAComponentParameter {
    [CmdletBinding( )]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [hashtable]
        $Parameter,

        [switch]
        $AllowEmptyValue
    )

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

.PARAMETER Example
An example of a parameter value

.PARAMETER Enum
An optional array of values that this property can only be set to.

.PARAMETER Required
If supplied, the object will be treated as Required where supported.

.PARAMETER Deprecated
If supplied, the object will be treated as Deprecated where supported. 

.PARAMETER Object
If supplied, the integer will be automatically wrapped in an object.

.PARAMETER Nullable
If supplied, the integer will be treated as Nullable.

.PARAMETER ReadOnly
If supplied, the integer will be included in a response but not in a request

.PARAMETER WriteOnly
If supplied, the integer will be included in a request but not in a response 

.PARAMETER Array
If supplied, the object will be treated as an array of objects.

.PARAMETER UniqueItems
If supplied, specify that all items in the array must be unique  

.PARAMETER MinItems
If supplied, specify minimum length of an array 

.PARAMETER MaxItems
If supplied, specify maximum length of an array 

.EXAMPLE
New-PodeOANumberProperty -Name 'age' -Required
#>
function New-PodeOAIntProperty {
    [CmdletBinding(DefaultParameterSetName = 'Inbuilt')]
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
        $Default ,

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
        [String]
        $Example,

        [Parameter()]
        [int[]]
        $Enum,

        [switch]
        $Required,

        [switch]
        $Deprecated,

        [switch]
        $Object,

        [switch]
        $Nullable,

        [switch]
        $ReadOnly,

        [switch]
        $WriteOnly, 

        [Parameter(Mandatory = $true, ParameterSetName = 'Array')]
        [switch]
        $Array,

        [Parameter(ParameterSetName = 'Array')]
        [switch] 
        $UniqueItems, 

        [Parameter(ParameterSetName = 'Array')]
        [int]
        $MinItems,

        [Parameter(ParameterSetName = 'Array')]
        [int]
        $MaxItems


    )

    $param = @{
        name = $Name
        type = 'integer'    
        meta = @{}
    }

    if ($Description ) { $param.description = $Description }

    if ($Array.IsPresent ) { $param.array = $Array.ToBool() }

    if ($Object.IsPresent ) { $param.object = $Object.ToBool() }

    if ($Required.IsPresent ) { $param.required = $Required.ToBool() }

    if ($Deprecated.IsPresent ) { $param.deprecated = $Deprecated.ToBool() }

    if ($Nullable.IsPresent ) { $param.meta['nullable'] = $Nullable.ToBool() }

    if ($WriteOnly.IsPresent ) { $param.meta['writeOnly'] = $WriteOnly.ToBool() }

    if ($ReadOnly.IsPresent ) { $param.meta['readOnly'] = $ReadOnly.ToBool() }

    if ($Example ) { $param.meta['example'] = $Example }

    if ($UniqueItems.IsPresent ) { $param.uniqueItems = $UniqueItems.ToBool() } 

    if ($Default) { $param.default = $Default }

    if ($Format) { $param.format = $Format.ToLowerInvariant() }

    if ($MaxItems) { $param.maxItems = $MaxItems }

    if ($MinItems) { $param.minItems = $MinItems }

    if ($Enum) { $param.enum = $Enum }  

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

.PARAMETER Example
An example of a parameter value

.PARAMETER Enum
An optional array of values that this property can only be set to.

.PARAMETER Required
If supplied, the object will be treated as Required where supported.

.PARAMETER Deprecated
If supplied, the object will be treated as Deprecated where supported. 

.PARAMETER Object
If supplied, the number will be automatically wrapped in an object.

.PARAMETER Nullable
If supplied, the number will be treated as Nullable.

.PARAMETER ReadOnly
If supplied, the number will be included in a response but not in a request

.PARAMETER WriteOnly
If supplied, the number will be included in a request but not in a response 

.PARAMETER Array
If supplied, the object will be treated as an array of objects.

.PARAMETER UniqueItems
If supplied, specify that all items in the array must be unique

.PARAMETER MinItems
If supplied, specify minimum length of an array 

.PARAMETER MaxItems
If supplied, specify maximum length of an array 

.EXAMPLE
New-PodeOANumberProperty -Name 'gravity' -Default 9.8
#>
function New-PodeOANumberProperty {
    [CmdletBinding(DefaultParameterSetName = 'Inbuilt')]
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
        [String]
        $Example,

        [Parameter()]
        [double[]]
        $Enum,

        [switch]
        $Required,

        [switch]
        $Deprecated,

        [switch]
        $Object,

        [switch]
        $Nullable,

        [switch]
        $ReadOnly,

        [switch]
        $WriteOnly,
        
        [Parameter(Mandatory = $true, ParameterSetName = 'Array')]
        [switch]
        $Array,

        [Parameter(ParameterSetName = 'Array')]
        [switch] 
        $UniqueItems, 

        [Parameter(ParameterSetName = 'Array')]
        [int]
        $MinItems,

        [Parameter(ParameterSetName = 'Array')]
        [int]
        $MaxItems
    )

    $param = @{
        name = $Name
        type = 'number'  
        meta = @{}
    }
    
    if ($Description ) { $param.description = $Description }

    if ($Array.IsPresent ) { $param.array = $Array.ToBool() }

    if ($Object.IsPresent ) { $param.object = $Object.ToBool() }

    if ($Required.IsPresent ) { $param.required = $Required.ToBool() }

    if ($Deprecated.IsPresent ) { $param.deprecated = $Deprecated.ToBool() }

    if ($Nullable.IsPresent ) { $param.meta['nullable'] = $Nullable.ToBool() }

    if ($WriteOnly.IsPresent ) { $param.meta['writeOnly'] = $WriteOnly.ToBool() }

    if ($ReadOnly.IsPresent ) { $param.meta['readOnly'] = $ReadOnly.ToBool() }

    if ($Example ) { $param.meta['example'] = $Example }

    if ($UniqueItems.IsPresent ) { $param.uniqueItems = $UniqueItems.ToBool() } 

    if ($Default) { $param.default = $Default }

    if ($Format) { $param.format = $Format.ToLowerInvariant() }

    if ($MaxItems) { $param.maxItems = $MaxItems }

    if ($MinItems) { $param.minItems = $MinItems }

    if ($Enum) { $param.enum = $Enum } 

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

.PARAMETER Pattern
A Regex pattern that the string must match.

.PARAMETER Description
A Description of the property.

.PARAMETER Example
An example of a parameter value

.PARAMETER Enum
An optional array of values that this property can only be set to.

.PARAMETER Required
If supplied, the string will be treated as Required where supported.

.PARAMETER Deprecated
If supplied, the string will be treated as Deprecated where supported.

.PARAMETER Object
If supplied, the string will be automatically wrapped in an object.

.PARAMETER Nullable
If supplied, the string will be treated as Nullable.

.PARAMETER ReadOnly
If supplied, the string will be included in a response but not in a request

.PARAMETER WriteOnly
If supplied, the string will be included in a request but not in a response 

.PARAMETER Array
If supplied, the object will be treated as an array of objects.

.PARAMETER UniqueItems
If supplied, specify that all items in the array must be unique

.PARAMETER MinItems
If supplied, specify minimum length of an array 

.PARAMETER MaxItems
If supplied, specify maximum length of an array 

.EXAMPLE
New-PodeOAStringProperty -Name 'userType' -Default 'admin'

.EXAMPLE
New-PodeOAStringProperty -Name 'password' -Format Password
#>
function New-PodeOAStringProperty {
    [CmdletBinding(DefaultParameterSetName = 'Inbuilt')]
    param(
        [Parameter()]
        [string]
        $Name,

        [Parameter( ParameterSetName = 'Array')]
        [Parameter(ParameterSetName = 'Inbuilt')]
        [ValidateSet('', 'Binary', 'Byte', 'Date', 'Date-Time', 'Password', 'Email', 'Uuid', 'Uri', 'Hostname', 'Ipv4', 'Ipv6')]
        [string]
        $Format,

        [Parameter( ParameterSetName = 'Array')]
        [Parameter(ParameterSetName = 'Custom')]
        [string]
        $CustomFormat,

        [Parameter()]
        [string]
        $Default = $null, 

        [Parameter()]
        [string]
        $Pattern = $null,

        [Parameter()]
        [string]
        $Description,
        
        [Parameter()]
        [String]
        $Example,

        [Parameter()]
        [string[]]
        $Enum,

        [switch]
        $Required,

        [switch]
        $Deprecated,

        [switch]
        $Object,

        [switch]
        $Nullable,

        [switch]
        $ReadOnly,

        [switch]
        $WriteOnly,
        
        [Parameter(Mandatory = $true, ParameterSetName = 'Array')]
        [switch]
        $Array,

        [Parameter(ParameterSetName = 'Array')]
        [switch] 
        $UniqueItems, 

        [Parameter(ParameterSetName = 'Array')]
        [int]
        $MinItems,

        [Parameter(ParameterSetName = 'Array')]
        [int]
        $MaxItems
    )

    $_format = $Format
    if (![string]::IsNullOrWhiteSpace($CustomFormat)) {
        $_format = $CustomFormat
    }

    $param = @{
        name = $Name
        type = 'string' 
        meta = @{}
    }
    
    if ($Description ) { $param.description = $Description }
    
    if ($Array.IsPresent ) { $param.array = $Array.ToBool() }

    if ($Object.IsPresent ) { $param.object = $Object.ToBool() }

    if ($Required.IsPresent ) { $param.required = $Required.ToBool() }

    if ($Deprecated.IsPresent ) { $param.deprecated = $Deprecated.ToBool() }

    if ($Nullable.IsPresent ) { $param.meta['nullable'] = $Nullable.ToBool() }

    if ($WriteOnly.IsPresent ) { $param.meta['writeOnly'] = $WriteOnly.ToBool() }

    if ($ReadOnly.IsPresent ) { $param.meta['readOnly'] = $ReadOnly.ToBool() }

    if ($Example ) { $param.meta['example'] = $Example }

    if ($UniqueItems.IsPresent ) { $param.uniqueItems = $UniqueItems.ToBool() } 

    if ($Default) { $param.default = $Default }

    if ($Format -or $CustomFormat) { $param.format = $_format.ToLowerInvariant() }

    if ($MaxItems) { $param.maxItems = $MaxItems }

    if ($MinItems) { $param.minItems = $MinItems }

    if ($Enum) { $param.enum = $Enum } 

    if ($Pattern) { $param.meta['pattern'] = $Pattern } 

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

.PARAMETER Example
An example of a parameter value

.PARAMETER Enum
An optional array of values that this property can only be set to.

.PARAMETER Required
If supplied, the object will be treated as Required where supported.

.PARAMETER Deprecated
If supplied, the object will be treated as Deprecated where supported.

.PARAMETER Object
If supplied, the boolean will be automatically wrapped in an object.

.PARAMETER Nullable
If supplied, the boolean will be treated as Nullable.

.PARAMETER ReadOnly
If supplied, the boolean will be included in a response but not in a request

.PARAMETER WriteOnly
If supplied, the boolean will be included in a request but not in a response 

.PARAMETER Array
If supplied, the object will be treated as an array of objects.

.PARAMETER UniqueItems
If supplied, specify that all items in the array must be unique

.PARAMETER MinItems
If supplied, specify minimum length of an array 

.PARAMETER MaxItems
If supplied, specify maximum length of an array 

.EXAMPLE
New-PodeOABoolProperty -Name 'enabled' -Required
#>
function New-PodeOABoolProperty {
    [CmdletBinding(DefaultParameterSetName = 'Inbuilt')]
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
        [bool]
        $Example,

        [Parameter()]
        [bool[]]
        $Enum,

        [switch]
        $Required,

        [switch]
        $Deprecated,

        [switch]
        $Object,

        [switch]
        $Nullable,

        [switch]
        $ReadOnly,

        [switch]
        $WriteOnly,
        
        [Parameter(Mandatory = $true, ParameterSetName = 'Array')]
        [switch]
        $Array,

        [Parameter(ParameterSetName = 'Array')]
        [switch] 
        $UniqueItems, 

        [Parameter(ParameterSetName = 'Array')]
        [int]
        $MinItems,

        [Parameter(ParameterSetName = 'Array')]
        [int]
        $MaxItems
    )

    $param = @{
        name = $Name
        type = 'boolean'   
        meta = @{}
    }

    if ($Description ) { $param.description = $Description }

    if ($Array.IsPresent ) { $param.array = $Array.ToBool() }

    if ($Object.IsPresent ) { $param.object = $Object.ToBool() }

    if ($Required.IsPresent ) { $param.required = $Required.ToBool() }

    if ($Deprecated.IsPresent ) { $param.deprecated = $Deprecated.ToBool() }

    if ($Nullable.IsPresent ) { $param.meta['nullable'] = $Nullable.ToBool() }

    if ($WriteOnly.IsPresent ) { $param.meta['writeOnly'] = $WriteOnly.ToBool() }

    if ($ReadOnly.IsPresent ) { $param.meta['readOnly'] = $ReadOnly.ToBool() }

    if ($Example ) { $param.meta['example'] = $Example }

    if ($UniqueItems.IsPresent ) { $param.uniqueItems = $UniqueItems.ToBool() } 

    if ($Default) { $param.default = $Default } 

    if ($MaxItems) { $param.maxItems = $MaxItems }

    if ($MinItems) { $param.minItems = $MinItems }

    if ($Enum) { $param.enum = $Enum } 

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

.PARAMETER Example
An example of a parameter value

.PARAMETER Deprecated
If supplied, the object will be treated as Deprecated where supported.

.PARAMETER Required
If supplied, the object will be treated as Required where supported.

.PARAMETER Array
If supplied, the object will be treated as an array of objects.

.PARAMETER Nullable
If supplied, the object will be treated as Nullable.

.PARAMETER ReadOnly
If supplied, the object will be included in a response but not in a request

.PARAMETER WriteOnly
If supplied, the object will be included in a request but not in a response  

.PARAMETER MinProperties
If supplied, will restrict the minimun number of properties allowed in an object.

.PARAMETER MaxProperties
If supplied, will restrict the maximum number of properties allowed in an object.

.PARAMETER Array
If supplied, the object will be treated as an array of objects.

.PARAMETER UniqueItems
If supplied, specify that all items in the array must be unique

.PARAMETER MinItems
If supplied, specify minimum length of an array 

.PARAMETER MaxItems
If supplied, specify maximum length of an array 

.PARAMETER Xml
If supplied, controls the XML serialization behavior

.EXAMPLE
New-PodeOAObjectProperty -Name 'user' -Properties @('<ARRAY_OF_PROPERTIES>')
#>
function New-PodeOAObjectProperty {
    [CmdletBinding(DefaultParameterSetName = 'Inbuilt')]
    param(
        [Parameter()]
        [string]
        $Name,

        [Parameter(Mandatory = $true, ParameterSetName = 'Inbuilt')]
        [Parameter(Mandatory = $true, ParameterSetName = 'Array')]
        [hashtable[]]
        $Properties,

        [Parameter()]
        [string]
        $Description,
        
        [Parameter()]
        [String]
        $Example,

        [switch]
        $Deprecated,  
        
        [switch]
        $Required,

        [switch]
        $Nullable, 

        [switch]
        $ReadOnly,

        [switch]
        $WriteOnly,
        
        [int]
        $MinProperties,

        [int]
        $MaxProperties,

        [Parameter(Mandatory = $true, ParameterSetName = 'Array')]
        [switch]
        $Array,

        [Parameter(ParameterSetName = 'Array')]
        [switch] 
        $UniqueItems,

        [Parameter(ParameterSetName = 'Array')]
        [int]
        $MinItems,

        [Parameter(ParameterSetName = 'Array')]
        [int]
        $MaxItems,  

        [hashtable[]]
        $Xml
    )

    $param = @{
        name       = $Name
        type       = 'object'    
        properties = $Properties  
        meta       = @{}
    }
    if ($Description ) { $param.description = $Description }

    if ($Array.IsPresent ) { $param.array = $Array.ToBool() } 

    if ($Required.IsPresent ) { $param.required = $Required.ToBool() }

    if ($Deprecated.IsPresent ) { $param.deprecated = $Deprecated.ToBool() }

    if ($Nullable.IsPresent ) { $param.meta['nullable'] = $Nullable.ToBool() }

    if ($WriteOnly.IsPresent ) { $param.meta['writeOnly'] = $WriteOnly.ToBool() }

    if ($ReadOnly.IsPresent ) { $param.meta['readOnly'] = $ReadOnly.ToBool() }

    if ($Example ) { $param.meta['example'] = $Example }

    if ($UniqueItems.IsPresent ) { $param.uniqueItems = $UniqueItems.ToBool() } 

    if ($Default) { $param.default = $Default } 

    if ($MaxItems) { $param.maxItems = $MaxItems }

    if ($MinItems) { $param.minItems = $MinItems }

    if ($MinProperties) { $param.minProperties = $MinProperties }

    if ($MaxProperties) { $param.maxProperties = $MaxProperties }

    if ($Xml) { $param.xml = $Xml }
    
    return $param
}
 
 

<#
.SYNOPSIS
Creates a OpenAPI schema reference property.

.DESCRIPTION
Creates a new OpenAPI component schema reference from another OpenAPI schema.

.PARAMETER Name
The Name of the property.

.PARAMETER ComponentSchema
An component schema name.

.PARAMETER Description
A Description of the property.

.PARAMETER Example
An example of a parameter value

.PARAMETER Deprecated
If supplied, the schema will be treated as Deprecated where supported.

.PARAMETER Array
If supplied, the schema will be treated as an array of objects.

.PARAMETER Nullable
If supplied, the schema will be treated as Nullable.

.PARAMETER ReadOnly
If supplied, the schema will be included in a response but not in a request

.PARAMETER WriteOnly
If supplied, the schema will be included in a request but not in a response  

.PARAMETER MinProperties
If supplied, will restrict the minimun number of properties allowed in an schema.

.PARAMETER MaxProperties
If supplied, will restrict the maximum number of properties allowed in an schema.

.PARAMETER Array
If supplied, the schema will be treated as an array of objects.

.PARAMETER UniqueItems
If supplied, specify that all items in the array must be unique

.PARAMETER MinItems
If supplied, specify minimum length of an array 

.PARAMETER MaxItems
If supplied, specify maximum length of an array 

.PARAMETER Xml
If supplied, controls the XML serialization behavior


.EXAMPLE
New-PodeOASchemaProperty -Name 'Config' -ComponentSchema "MyConfigSchema"
#>
function New-PodeOASchemaProperty {
    [CmdletBinding(DefaultParameterSetName = 'Inbuilt')]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true)]
        [string]
        $ComponentSchema, 

        [string]
        $Description,

        [Parameter(ParameterSetName = 'Array')] 
        [String]
        $Example,

        [Parameter(ParameterSetName = 'Array')]
        [switch]
        $Deprecated, 

        [Parameter(ParameterSetName = 'Array')]
        [switch]
        $Required,

        [Parameter(ParameterSetName = 'Array')]
        [switch]
        $Nullable, 

        [Parameter(ParameterSetName = 'Array')]
        [switch]
        $ReadOnly,

        [Parameter(ParameterSetName = 'Array')]
        [switch]
        $WriteOnly,

        [Parameter(ParameterSetName = 'Array')]
        [int]
        $MinProperties,

        [Parameter(ParameterSetName = 'Array')]
        [int]
        $MaxProperties,

        [Parameter(Mandatory = $true, ParameterSetName = 'Array')]
        [switch]
        $Array,

        [Parameter(ParameterSetName = 'Array')]
        [switch] 
        $UniqueItems,

        [Parameter(ParameterSetName = 'Array')]
        [int]
        $MinItems,

        [Parameter(ParameterSetName = 'Array')]
        [int]
        $MaxItems, 

        [hashtable[]]
        $Xml
    )
    if ( !(Test-PodeOAComponentSchema -Name $ComponentSchema)) {
        throw "The OpenApi component schema doesn't exist: $ComponentSchema"
    }  
    $param = @{
        name   = $Name
        type   = 'schema' 
        schema = $ComponentSchema 
        meta   = @{}
    }
    if ($PSCmdlet.ParameterSetName.ToLowerInvariant() -eq 'array') {   
        if ($Description ) { $param.description = $Description }

        if ($Array.IsPresent ) { $param.array = $Array.ToBool() } 

        if ($Required.IsPresent ) { $param.required = $Required.ToBool() }

        if ($Deprecated.IsPresent ) { $param.deprecated = $Deprecated.ToBool() }

        if ($Nullable.IsPresent ) { $param.meta['nullable'] = $Nullable.ToBool() }

        if ($WriteOnly.IsPresent ) { $param.meta['writeOnly'] = $WriteOnly.ToBool() }

        if ($ReadOnly.IsPresent ) { $param.meta['readOnly'] = $ReadOnly.ToBool() }

        if ($Example ) { $param.meta['example'] = $Example }

        if ($UniqueItems.IsPresent ) { $param.uniqueItems = $UniqueItems.ToBool() } 

        if ($Default) { $param.default = $Default } 

        if ($MaxItems) { $param.maxItems = $MaxItems }

        if ($MinItems) { $param.minItems = $MinItems }

        if ($MinProperties) { $param.minProperties = $MinProperties }

        if ($MaxProperties) { $param.maxProperties = $MaxProperties }

        if ($Xml) { $param.xml = $Xml }
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

.PARAMETER ContentSchemas
The content-types and the name of an existing component schema to be reused.

.PARAMETER Explode
If supplied, controls how arrays are serialized in query parameters

.PARAMETER Style
If supplied,  defines how multiple values are delimited. Possible styles depend on the parameter location: path, query, header or cookie.


.EXAMPLE
New-PodeOAIntProperty -Name 'userId' | ConvertTo-PodeOAParameter -In Query

.EXAMPLE
ConvertTo-PodeOAParameter -Reference 'UserIdParam'

.EXAMPLE
ConvertTo-PodeOAParameter  -In Header -ContentSchemas @{ 'application/json' = 'UserIdSchema' }

#>
function ConvertTo-PodeOAParameter {
    [CmdletBinding(DefaultParameterSetName = 'Reference')]
    param( 
        [Parameter(Mandatory = $true, ParameterSetName = 'Schema')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ContentSchemas')]
        [ValidateSet('Cookie', 'Header', 'Path', 'Query')]
        [string]
        $In,

        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = 'Schema')]
        [ValidateNotNull()]
        [hashtable]
        $Property,

        [Parameter(Mandatory = $true, ParameterSetName = 'Reference')]
        [string]
        $Reference,

        [Parameter(Mandatory = $true, ParameterSetName = 'ContentSchemas')]
        [hashtable]
        $ContentSchemas,

        [Parameter() ]
        [Switch]
        $Explode, 

        [Parameter() ]
        [Switch]
        $AllowEmptyValue,

        [Parameter() ]
        [ValidateSet('Simple', 'Label', 'Matrix', 'Query', 'Form', 'SpaceDelimited', 'PipeDelimited', 'DeepObject' )]
        [string]
        $Style 
    )
    if ($PSCmdlet.ParameterSetName -ieq 'ContentSchemas') { 
        if (Test-PodeIsEmpty $ContentSchemas) {
            return $null
        }
        # ensure all content types are valid
        foreach ($type in $ContentSchemas.Keys) {
            if ($type -inotmatch '^\w+\/[\w\.\+-]+$') {
                throw "Invalid content-type found for schema: $($type)"
            } 
            if (!(Test-PodeOAComponentSchema -Name $ContentSchemas[$type])) {
                throw "The OpenApi component request parameter doesn't exist: $($ContentSchemas[$type])"
            }
            $Property = $PodeContext.Server.OpenAPI.components.schemas[$ContentSchemas[$type]]
            $prop = @{
                in          = $In.ToLowerInvariant()
                name        = $ContentSchemas[$type]
                description = $Property.description 
                content     = @{
                    $type = @{
                        schema = @{
                            '$ref' = "#/components/schemas/$($ContentSchemas[$type])"
                        }
                    }
                }
            }  
        }
    } elseif ($PSCmdlet.ParameterSetName -ieq 'Reference') {
        # return a reference
        if (!(Test-PodeOAComponentParameter -Name $Reference)) {
            throw "The OpenApi component request parameter doesn't exist: $($Reference)"
        }

        $prop = @{
            '$ref' = "#/components/parameters/$($Reference)"
        } 
    } else {
        # non-object/array only
        if (@('array', 'object') -icontains $Property.type) { 
            throw 'OpenApi request parameter cannot be an array of object'
        }

        # build the base parameter
        $prop = @{
            in          = $In.ToLowerInvariant()
            name        = $Property.name
            description = $Property.description 
        }
        if ($Property.Array) {
            $prop.schema = @{
                type  = 'array'
                items = @{
                    type   = $Property.type
                    format = $Property.format
                }
            }
        } else {
            $prop.schema = @{
                type   = $Property.type
                format = $Property.format
            }
        }
        if ($null -ne $Property.meta) {
            foreach ($key in $Property.meta.Keys) {
                if ($Property.Array) {
                    $prop.schema.items[$key] = $Property.meta[$key]
                } else {
                    $prop.schema[$key] = $Property.meta[$key]
                }
            }
        }
    }
    if ($Property) {
        if ($Style) {
            switch ($in) {
                'Path' {
                    if (@('Simple', 'Label', 'Matrix' ) -notcontains $Style) {
                        throw "OpenApi request Style cannot be $Style for a $in parameter"
                    } 
                    break
                }
                'Query' {
                    if (@('Form', 'SpaceDelimited', 'PipeDelimited', 'DeepObject' ) -notcontains $Style) {
                        throw "OpenApi request Style cannot be $Style for a $in parameter"
                    } 
                    break
                }
                'Header' {
                    if (@('Simple' ) -notcontains $Style) {
                        throw "OpenApi request Style cannot be $Style for a $in parameter"
                    } 
                    break
                }
                'Cookie' {
                    if (@('Form' ) -notcontains $Style) {
                        throw "OpenApi request Style cannot be $Style for a $in parameter"
                    } 
                    break
                } 
            }
            $prop['style'] = $Style.Substring(0, 1).ToLower() + $Style.Substring(1)
        } 

        if ($Explode.IsPresent ) {
            $prop['explode'] = $Explode.ToBool() 
        } 

        if ($AllowEmptyValue.IsPresent ) {
            $prop['allowEmptyValue'] = $AllowEmptyValue.ToBool() 
        }


        if ($Property.deprecated) {
            $prop['deprecated'] = $Property.deprecated
        }

        if ($Property.default) {
            $prop.schema['default'] = $Property.default
        }

        if ($Property.enum) {
            if ($Property.Array) {
                $prop.schema.items['enum'] = $Property.enum
            } else {
                $prop.schema['enum'] = $Property.enum
            }
        }

        if ($In -eq 'Path') {
            $prop['required'] = $true 
        } elseif ($Property.required ) {
            $prop['required'] = $Property.required
        } 
        # remove default for required parameter
        if (!$Property.required -and $PSCmdlet.ParameterSetName -ne 'ContentSchemas') {
            if ( $prop.ContainsKey('schema')) {
                $prop.schema['default'] = $Property.default
            }
        }  
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
function Set-PodeOARouteInfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
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
        $r.OpenApi.Swagger = $true 
        if ($Deprecated.IsPresent) {
            $r.OpenApi.Deprecated = $Deprecated.ToBool()
        }
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
function Enable-PodeOpenApiViewer {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Swagger', 'ReDoc', 'RapiDoc', 'StopLight', 'Explorer', 'RapiPdf')]
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
        Type       = $Type.ToLowerInvariant()
        Title      = $Title
        OpenApi    = $OpenApiUrl
        DarkMode   = $DarkMode
        OpenApiDoc = $true
    }
    
    # add the viewer route
    Add-PodeRoute -Method Get -Path $Path -Middleware $Middleware -ArgumentList $meta -ScriptBlock {
        param($meta)
        $podeRoot = Get-PodeModuleMiscPath
        Write-PodeFileResponse -Path ([System.IO.Path]::Combine($podeRoot, "default-$($meta.Type).html.pode")) -Data @{
            Title    = $meta.Title
            OpenApi  = $meta.OpenApi
            DarkMode = (($meta.DarkMode)?'true':'false')
            Theme    = (($meta.DarkMode)?'dark':'light')
        }
    }
}



function Enable-PodeOpenApiDocBookmarks {
    [CmdletBinding()]
    param( 
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
    $Path = Protect-PodeValue -Value $Path -Default '/doc'
    if ([string]::IsNullOrWhiteSpace($Title)) {
        throw "No route path supplied for $($Type) page"
    }

    # setup meta info
    $meta = @{ 
        Title             = $Title
        OpenApi           = $OpenApiUrl
        DarkMode          = $DarkMode  
    }
    
    # add the viewer route
    Add-PodeRoute -Method Get -Path $Path -Middleware $Middleware -ArgumentList $meta -ScriptBlock {
        param($meta)  
        $Data = @{ Title      = $meta.Title
            OpenApi           = $meta.OpenApi
            DarkMode          = (($meta.DarkMode)?'true':'false')
            Theme             = (($meta.DarkMode)?'dark':'light')
            OpenApiDefinition = Get-PodeOpenApiDefinition | ConvertTo-Json -Depth 10
        }  
        foreach ($path in ($PodeContext.Server.Routes['GET'].Keys  )) {  
            # the current route 
            $_routes = @($PodeContext.Server.Routes['GET'][$path])
            # get the first route for base definition
            $_route = $_routes[0] 
            # check if the route has to be published  
            if ($_route.Arguments -and $_route.Arguments.OpenApiDoc   ) {
                
                $Data[$_route.Arguments.Type] = 'true'
                $Data["$($_route.Arguments.Type)_path"] = $_route.Path 
            }
        } 
        $podeRoot = Get-PodeModuleMiscPath
        Write-PodeFileResponse -Path ([System.IO.Path]::Combine($podeRoot, 'default-doc-bookmarks.html.pode')) -Data $Data
    }
}



<#
.SYNOPSIS
Adds an external docs reference. 

.DESCRIPTION
Creates a new  reference from another OpenAPI schema.

.PARAMETER Name
The Name of the reference.

.PARAMETER url
The link to the external documentation

.PARAMETER Description
A Description of the external documentation.

.PARAMETER Array
If supplied, the schema reference will be treated as an array.

.EXAMPLE
Add-PodeOAExternalDoc  -Name 'SwaggerDocs' -Description 'Find out more about Swagger' -Url 'http://swagger.io'
#>
function Add-PodeOAExternalDoc { 
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true)]
        [ValidateScript({ $_ -match '^https?://.+' })]
        $Url,

        [Parameter()]
        [string]
        $Description
    )

    $param = @{}

    if ($Description) {
        $param.description = $Description
    }
    $param['url'] = $Url
    $PodeContext.Server.OpenAPI.hiddenComponents.externalDocs[$Name] = $param
    
}


<#
.SYNOPSIS
Creates a OpenAPI Tag reference property.

.DESCRIPTION
Creates a new OpenAPI tag reference.

.PARAMETER Name
The Name of the tag. 

.PARAMETER Description
A Description of the tag.

.PARAMETER ExternalDoc
If supplied, the tag reference to an existing external documentation reference.
The parameter is created by Add-PodeOAExternalDoc

.EXAMPLE
Add-PodeOATag -Name 'store' -Description 'Access to Petstore orders' -ExternalDoc 'SwaggerDocs'
#>
function Add-PodeOATag { 
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name, 

        [Parameter()]
        [string]
        $Description,

        [Parameter()]
        [string]
        $ExternalDoc
    )
    
    $param = @{ 
        'name' = $Name 
    }

    if ($Description) {
        $param.description = $Description
    }

    if ($ExternalDoc) {
        if ( !(Test-PodeOAExternalDoc -Name $ExternalDoc)) {
            throw "The ExternalDoc doesn't exist: $ExternalDoc"
        }  
        $param.externalDocs = $PodeContext.Server.OpenAPI.hiddenComponents.externalDocs[$ExternalDoc]
    }

    $PodeContext.Server.OpenAPI.tags[$Name] = $param

}


<#
.SYNOPSIS
Creates an OpenAPI non-essential metadata.

.DESCRIPTION
Creates an OpenAPI non-essential metadata like TermOfService, license and so on.
The metadata MAY be used by the clients if needed, and MAY be presented in editing or documentation generation tools for convenience.

.PARAMETER TermsOfService
A URL to the Terms of Service for the API. MUST be in the format of a URL.

.PARAMETER License
The license name used for the API.

.PARAMETER LicenseUrl
A URL to the license used for the API. MUST be in the format of a URL.

.PARAMETER ContactName
The identifying name of the contact person/organization.

.PARAMETER ContactEmail 
The email address of the contact person/organization. MUST be in the format of an email address.

.PARAMETER ContactUrl
The URL pointing to the contact information. MUST be in the format of a URL.

.EXAMPLE
New-PodeOAExtraInfo -TermsOfService 'http://swagger.io/terms/' -License 'Apache 2.0' -LicenseUrl 'http://www.apache.org/licenses/LICENSE-2.0.html' -ContactName 'API Support' -ContactEmail 'apiteam@swagger.io' -ContactUrl 'http://example.com/support'
#>

function New-PodeOAExtraInfo {
    param(
        [Parameter()]
        [ValidateScript({ $_ -match '^https?://.+' })]
        [string]
        $TermsOfService,

        [Parameter(Mandatory = $true)] 
        [string]
        $License,

        [Parameter(Mandatory = $true)]
        [ValidateScript({ $_ -match '^https?://.+' })]
        [string]
        $LicenseUrl,

        [Parameter()]
        [string]
        $ContactName,

        [Parameter()]
        [ValidateScript({ $_ -match '^\w+([-+.]\w+)*@\w+([-.]\w+)*\.\w+([-.]\w+)*$' })]
        [string]
        $ContactEmail,

        [Parameter()]
        [ValidateScript({ $_ -match '^https?://.+' })]
        [string]
        $ContactUrl  
    )

    $ExtraInfo = @{   
        'license' = @{
            'name' = $License
            'url'  = $LicenseUrl
        }
    }

    if ($TermsOfService) {
        $ExtraInfo['termsOfService'] = $TermsOfService
    }

    if ($ContactName -or $ContactEmail -or $ContactUrl ) {
        $ExtraInfo['contact'] = @{}
        
        if ($ContactName) { $ExtraInfo['contact'].name = $ContactName }

        if ($ContactEmail) { $ExtraInfo['contact'].email = $ContactEmail }

        if ($ContactUrl) { $ExtraInfo['contact'].url = $ContactUrl }
    } 

    return $ExtraInfo

}