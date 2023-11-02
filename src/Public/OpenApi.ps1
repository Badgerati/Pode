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
The OpenAPI Specification is versioned using Semantic Versioning 2.0.0 (semver) and follows the semver specification.
https://semver.org/spec/v2.0.0.html

.PARAMETER Description
A short description of the API. CommonMark syntax MAY be used for rich text representation.
https://spec.commonmark.org/

.PARAMETER OpenApiVersion
Specify OpenApi Version (default: 3.0.3)

.PARAMETER RouteFilter
An optional route filter for routes that should be included in the definition. (Default: /*)

.PARAMETER Middleware
Like normal Routes, an array of Middleware that will be applied to the route.

.PARAMETER RestrictRoutes
If supplied, only routes that are available on the Requests URI will be used to generate the OpenAPI definition.

.PARAMETER ServerEndpoint
If supplied, will be used as URL base to generate the OpenAPI definition.
The parameter is created by New-PodeOpenApiServerEndpoint

.PARAMETER Mode
Define the way the OpenAPI definition file is accessed, the value can be View or Download. (Default: View)

.PARAMETER NoCompress
If supplied, generate the OpenApi Json version in human readible form.

.PARAMETER MarkupLanguage
Define the default markup language for the OpenApi spec ('Json', 'Json-Compress', 'Yaml')

.PARAMETER EnableSchemaValidation
If suplied enable Test-PodeOARequestSchema cmdlet that provide support for opeapi parameter schema validation

.PARAMETER Depth
Define the default  depth used by any JSON,YAML OpenAPI conversion (default 20)

.PARAMETER DisableMinimalDefinitions
If suplied the OpenApi decument will include only the route validated by Set-PodeOARouteInfo. Any other not OpenApi route will be excluded.

.EXAMPLE
Enable-PodeOpenApi -Title 'My API' -Version '1.0.0' -RouteFilter '/api/*'

.EXAMPLE
Enable-PodeOpenApi -Title 'My API' -Version '1.0.0' -RouteFilter '/api/*' -RestrictRoutes

.EXAMPLE
Enable-PodeOpenApi -Path '/docs/openapi' -Title 'My API' -Version '1.0.beta' -NoCompress -Mode 'Donwload'
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
        [ValidatePattern('^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$')]
        [string]
        $Version = '0.0.0',

        [Parameter()]
        [string]
        $Description,

        [Parameter()]
        [ValidateSet('3.0.3', '3.0.2', '3.0.1')]
        [string]
        $OpenApiVersion = '3.0.3',

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
        [ValidateSet('View', 'Download')]
        [String]
        $Mode = 'view',

        [Parameter()]
        [ValidateSet('Json', 'Json-Compress', 'Yaml')]
        [String]
        $MarkupLanguage = 'Json',

        [Parameter()]
        [switch]
        $EnableSchemaValidation,

        [Parameter()]
        [ValidateRange(1, 100)]
        [int]
        $Depth = 20,

        [Parameter()]
        [switch]
        $DisableMinimalDefinitions
    )
    $PodeContext.Server.OpenAPI.hiddenComponents.enableMinimalDefinitions = !$DisableMinimalDefinitions.ToBool()
    # initialise openapi info
    $PodeContext.Server.OpenAPI.Version = $OpenApiVersion
    $PodeContext.Server.OpenAPI.Path = $Path

    $meta = @{
        RouteFilter    = $RouteFilter
        RestrictRoutes = $RestrictRoutes
        NoCompress     = ($MarkupLanguage -ine 'Json-Compress')
        Mode           = $Mode
        MarkupLanguage = $MarkupLanguage
    }

    $PodeContext.Server.OpenAPI.info.title = $Title
    $PodeContext.Server.OpenAPI.info.version = $Version

    if ($Description ) {
        $PodeContext.Server.OpenAPI.info.description = $Description
    }

    if ( $EnableSchemaValidation) {
        #Test-Json has been introduced with version 6.1.0
        if ($PSVersionTable.PSVersion -ge [version]'6.1.0') {
            $PodeContext.Server.OpenAPI.hiddenComponents.schemaValidation = $EnableSchemaValidation.ToBool()
        } else {
            throw 'Schema validation required Powershell version 6.1.0 or greater'
        }
    }

    if ( $Depth) {
        $PodeContext.Server.OpenAPI.hiddenComponents.depth = $Depth
    }


    $openApiCreationScriptBlock = {
        param($meta)
        $format = $WebEvent.Query['format']
        $mode = $WebEvent.Query['mode']

        if (!$mode) {
            $mode = $meta.Mode
        } elseif (@('download', 'view') -inotcontains $mode) {
            Write-PodeHtmlResponse -Value "Mode $mode not valid" -StatusCode 400
            return
        }
        if ($WebEvent.path -ilike '*.json') {
            if ($format) {
                Show-PodeErrorPage -Code 400 -ContentType 'text/html' -Description 'Format query not valid when the file extension is used'
                return
            }
            $format = 'json'
        } elseif ($WebEvent.path -ilike '*.yaml') {
            if ($format) {
                Show-PodeErrorPage -Code 400 -ContentType 'text/html' -Description 'Format query not valid when the file extension is used'
                return
            }
            $format = 'yaml'
        } elseif (!$format) {
            $format = $meta.MarkupLanguage.ToLower()
        } elseif (@('yaml', 'json', 'Json-Compress') -inotcontains $format) {
            Show-PodeErrorPage -Code 400 -ContentType 'text/html' -Description "Format $format not valid"
            return
        }

        if (($mode -ieq 'download')  ) {
            # Set-PodeResponseAttachment -Path
            Add-PodeHeader -Name 'Content-Disposition' -Value "attachment; filename=openapi.$format"
        }

        # generate the openapi definition
        $def = Get-PodeOpenApiDefinitionInternal `
            -Protocol $WebEvent.Endpoint.Protocol `
            -Address $WebEvent.Endpoint.Address `
            -EndpointName $WebEvent.Endpoint.Name `
            -MetaInfo $meta

        # write the openapi definition
        if ($format -ieq 'yaml') {
            if ($mode -ieq 'view') {
                Write-PodeTextResponse -Value (ConvertTo-PodeYaml -InputObject $def -depth $PodeContext.Server.OpenAPI.hiddenComponents.depth) -ContentType 'text/x-yaml; charset=utf-8'
            } else {
                Write-PodeYamlResponse -Value $def -depth $PodeContext.Server.OpenAPI.hiddenComponents.depth
            }
        } else {
            Write-PodeJsonResponse -Value $def -depth $PodeContext.Server.OpenAPI.hiddenComponents.depth -NoCompress:$meta.NoCompress
        }
    }

    # add the OpenAPI route
    Add-PodeRoute -Method Get -Path $Path -ArgumentList $meta -Middleware $Middleware -ScriptBlock $openApiCreationScriptBlock
    Add-PodeRoute -Method Get -Path "$Path.json" -ArgumentList $meta -Middleware $Middleware -ScriptBlock $openApiCreationScriptBlock
    Add-PodeRoute -Method Get -Path "$Path.yaml" -ArgumentList $meta -Middleware $Middleware -ScriptBlock $openApiCreationScriptBlock

    $PodeContext.Server.OpenAPI.hiddenComponents.enabled = $true
}




<#
.SYNOPSIS
Creates an OpenAPI Server property.

.DESCRIPTION
Creates an OpenAPI Server property.

.LINK
https://swagger.io/docs/specification/api-host-and-base-path/

.PARAMETER Url
Server or path to local server.

.PARAMETER Description
Description of the server.

.EXAMPLE
Add-PodeOAServerEndpoint -Url 'https://myserver.io/api' -Description 'My test server'

.EXAMPLE
Add-PodeOAServerEndpoint -Url '/api' -Description 'My local server'
#>
function Add-PodeOAServerEndpoint {
    param (
        [Parameter(Mandatory)]
        [ValidatePattern('^(https?://|/).+')]
        [string]
        $Url,
        [string]
        $Description
    )

    if (! $PodeContext.Server.OpenAPI.servers) {
        $PodeContext.Server.OpenAPI.servers = @()
    }
    $lUrl = [ordered]@{url = $Url }
    if ($Description) {
        $lUrl.description = $Description
    }
    $PodeContext.Server.OpenAPI.servers += $lUrl
}




<#
.SYNOPSIS
Gets the OpenAPI definition.

.DESCRIPTION
Gets the OpenAPI definition for custom use in routes, or other functions.

.LINK
https://swagger.io/docs/specification/

.LINK
https://github.com/OAI/OpenAPI-Specification/blob/main/versions/3.0.3.md

.PARAMETER Format
Return the definition  in a specific format 'Json', 'Json-Compress', 'Yaml', 'HashTable'

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
$defInJson = Get-PodeOpenApiDefinition -Json
#>
function Get-PodeOpenApiDefinition {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateSet('Json', 'Json-Compress', 'Yaml', 'HashTable')]
        [string]
        $Format = 'HashTable',

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

        [Parameter()]
        [switch]
        $RestrictRoutes
    )

    $meta = @{
        RouteFilter    = $RouteFilter
        RestrictRoutes = $RestrictRoutes
    }
    if ($RestrictRoutes) {
        $meta = @{
            RouteFilter    = $RouteFilter
            RestrictRoutes = $RestrictRoutes
        }
    } else {
        $meta = @{}
    }
    if ($Title) {
        $meta.Title = $Title
    }
    if ($Version) {
        $meta.Version = $Version
    }
    if ($Description) {
        $meta.Description = $Description
    }

    $oApi = Get-PodeOpenApiDefinitionInternal  -MetaInfo $meta -EndpointName $WebEvent.Endpoint.Name

    switch ($Format.ToLower()) {
        'json' {
            return ConvertTo-Json -InputObject $oApi -depth $PodeContext.Server.OpenAPI.hiddenComponents.depth
        }
        'json-compress' {
            return ConvertTo-Json -InputObject $oApi -depth $PodeContext.Server.OpenAPI.hiddenComponents.depth -Compress
        }
        'yaml' {
            return ConvertTo-PodeYaml -InputObject $oApi -depth $PodeContext.Server.OpenAPI.hiddenComponents.depth
        }
        Default {
            return $oApi
        }
    }
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
The header name and schema the response returns (the schema is created using Add-PodeOAComponentHeaderSchema cmd-let).

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

        [Parameter()]
        [AllowEmptyString()]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ $_ -is [string] -or $_ -is [string[]] -or $_ -is [hashtable] })]
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
            if ($HeaderSchemas -is [System.Object[]] -or $HeaderSchemas -is [string] -or $HeaderSchemas -is [string[]]) {
                if ($null -ne $HeaderSchemas) {
                    $headers = ConvertTo-PodeOAHeaderSchema -Schemas $HeaderSchemas -Array:$HeaderArray
                }
            } elseif ($HeaderSchemas -is [hashtable]) {
                $headers = ConvertTo-PodeOAObjectSchema -Schemas  $HeaderSchemas
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
                $response = @{}
                if ($description) {
                    $response.description = $description
                }
                if ($headers) {
                    $response.headers = $headers
                }
                if ($content) {
                    $response.content = $content
                }
                $r.OpenApi.Responses[$code] = $response
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

.LINK
https://swagger.io/docs/specification/basic-structure/

.LINK
https://swagger.io/docs/specification/data-models/

.LINK
https://swagger.io/docs/specification/serialization/

.PARAMETER Name
The reference Name of the response.

.PARAMETER ContentSchemas
The content-types and schema the response returns (the schema is created using the Property functions).

.PARAMETER HeaderSchemas
The header name and schema the response returns (the schema is created using the Add-PodeOAComponentHeaderSchema cmdlet).

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
        [AllowEmptyString()]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ $_ -is [string] -or $_ -is [string[]] -or $_ -is [hashtable] })]
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

    $r = @{ description = $Description }
    if ($null -ne $ContentSchemas) {
        $r.content = ConvertTo-PodeOAContentTypeSchema -Schemas $ContentSchemas -Array:$ContentArray
    }
    #if HeaderSchemas is string or string[]
    if ($HeaderSchemas -is [System.Object[]] -or $HeaderSchemas -is [string] -or $HeaderSchemas -is [string[]]) {
        if ($null -ne $HeaderSchemas) {
            $r.headers = ConvertTo-PodeOAHeaderSchema -Schemas $HeaderSchemas -Array:$HeaderArray
        }
    } elseif ($HeaderSchemas -is [hashtable]) {
        $r.headers = ConvertTo-PodeOAObjectSchema -Schemas  $HeaderSchemas
    }

    $PodeContext.Server.OpenAPI.components.responses[$Name] = $r

}

<#
.SYNOPSIS
Sets the definition of a request for a route.

.DESCRIPTION
Sets the definition of a request for a route.

.LINK
https://swagger.io/docs/specification/basic-structure/

.LINK
https://swagger.io/docs/specification/data-models/

.LINK
https://swagger.io/docs/specification/serialization/

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

.LINK
https://swagger.io/docs/specification/basic-structure/

.LINK
https://swagger.io/docs/specification/data-models/

.LINK
https://swagger.io/docs/specification/serialization/

.LINK
https://swagger.io/docs/specification/describing-request-body/

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

            if ($Required.IsPresent) {
                $param['required'] = $Required.ToBool()
            }

            if ( $Description) {
                $param['description'] = $Description
            }

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
Adds a reusable component schema

.DESCRIPTION
Adds a reusable component  schema.

.LINK
https://swagger.io/docs/specification/basic-structure/

.LINK
https://swagger.io/docs/specification/data-models/

.LINK
https://swagger.io/docs/specification/serialization/

.LINK
https://swagger.io/docs/specification/data-models/

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
    #  if (!$schema.name) {
    #    $schema.name = $name
    # }
    $PodeContext.Server.OpenAPI.components.schemas[$Name] = ($Schema | ConvertTo-PodeOASchemaProperty)
    if ($PodeContext.Server.OpenAPI.hiddenComponents.schemaValidation) {
        $modifiedSchema = ($Schema | ConvertTo-PodeOASchemaProperty) | Resolve-PodeOAReferences
        #Resolve-PodeOAReferences -ComponentSchema  $modifiedSchema
        $PodeContext.Server.OpenAPI.hiddenComponents.schemaJson[$Name] = @{
            'schema' = $modifiedSchema
            'json'   = $modifiedSchema | ConvertTo-Json -depth $PodeContext.Server.OpenAPI.hiddenComponents.depth
        }
    }
}


<#
.SYNOPSIS
Adds a reusable component for a Header schema.

.DESCRIPTION
Adds a reusable component for a Header schema.

.LINK
https://swagger.io/docs/specification/basic-structure/

.LINK
https://swagger.io/docs/specification/data-models/

.LINK
https://swagger.io/docs/specification/serialization/

.LINK
https://swagger.io/docs/specification/data-models/

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

.LINK
https://swagger.io/docs/specification/basic-structure/

.LINK
https://swagger.io/docs/specification/data-models/

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

    if (!$PodeContext.Server.OpenAPI.hiddenComponents.schemaValidation) {
        throw 'Test-PodeOARequestSchema need to be enabled using `Enable-PodeOpenApi -EnableSchemaValidation` '
    }
    if (!(Test-PodeOAComponentSchemaJson -Name $SchemaReference)) {
        throw "The OpenApi component schema in Json doesn't exist: $SchemaReference"
    }

    [string[]] $message = @()
    $result = Test-Json -Json $Json -Schema $PodeContext.Server.OpenAPI.hiddenComponents.schemaJson[$SchemaReference].json -ErrorVariable jsonValidationErrors -ErrorAction SilentlyContinue
    if ($jsonValidationErrors) {
        foreach ($item in $jsonValidationErrors) {
            $message += $item
        }
    }

    return @{result = $result; message = $message }
}

<#
.SYNOPSIS
Adds a reusable component for a request body.

.DESCRIPTION
Adds a reusable component for a request body.

.LINK
https://swagger.io/docs/specification/basic-structure/

.LINK
https://swagger.io/docs/specification/data-models/

.LINK
https://swagger.io/docs/specification/describing-request-body/

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

    if ($Required.IsPresent) {
        $param['required'] = $Required.ToBool()
    }

    if ( $Description) {
        $param['description'] = $Description
    }

    $PodeContext.Server.OpenAPI.components.requestBodies[$Name] = $param
}

<#
.SYNOPSIS
Adds a reusable component for a request parameter.

.DESCRIPTION
Adds a reusable component for a request parameter.

.LINK
https://swagger.io/docs/specification/basic-structure/

.LINK
https://swagger.io/docs/specification/data-models/

.LINK
https://swagger.io/docs/specification/describing-parameters/

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
        [Parameter( )]
        [string]
        $Name,

        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [hashtable]
        $Parameter
    )

    if ([string]::IsNullOrWhiteSpace($Name)) {
        if ($Parameter.name) {
            $Name = $Parameter.name
        } else {
            throw 'The Parameter has no name. Please provide a name to this component using -Name property'
        }
    }
    $PodeContext.Server.OpenAPI.components.parameters[$Name] = $Parameter
}

<#
.SYNOPSIS
Creates a new OpenAPI integer property.

.DESCRIPTION
Creates a new OpenAPI integer property, for Schemas or Parameters.

.LINK
https://swagger.io/docs/specification/basic-structure/

.LINK
https://swagger.io/docs/specification/data-models/

.PARAMETER ParamsList
Used to pipeline multiple properties

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

.PARAMETER XmlName
By default, XML elements get the same names that fields in the API declaration have. This property change the XML name of the property

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
        [Parameter(ValueFromPipeline = $true, DontShow = $true)]
        [hashtable[]]
        $ParamsList,

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

        [Parameter()]
        [string]
        $XmlName,

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
    begin {

        $param = @{
            name = $Name
            type = 'integer'
            meta = @{}
        }

        if ($Description ) {
            $param.description = $Description
        }

        if ($Array.IsPresent ) {
            $param.array = $Array.ToBool()
        }

        if ($Object.IsPresent ) {
            $param.object = $Object.ToBool()
        }

        if ($Required.IsPresent ) {
            $param.required = $Required.ToBool()
        }

        if ($Deprecated.IsPresent ) {
            $param.deprecated = $Deprecated.ToBool()
        }

        if ($Nullable.IsPresent ) {
            $param.meta['nullable'] = $Nullable.ToBool()
        }

        if ($WriteOnly.IsPresent ) {
            $param.meta['writeOnly'] = $WriteOnly.ToBool()
        }

        if ($ReadOnly.IsPresent ) {
            $param.meta['readOnly'] = $ReadOnly.ToBool()
        }

        if ($Example ) {
            $param.meta['example'] = $Example
        }

        if ($UniqueItems.IsPresent ) {
            $param.uniqueItems = $UniqueItems.ToBool()
        }

        if ($Default) {
            $param.default = $Default
        }

        if ($Format) {
            $param.format = $Format.ToLowerInvariant()
        }

        if ($MaxItems) {
            $param.maxItems = $MaxItems
        }

        if ($MinItems) {
            $param.minItems = $MinItems
        }

        if ($Enum) {
            $param.enum = $Enum
        }

        if ($XmlName) {
            $param.xmlName = $XmlName
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

        $collectedInput = [System.Collections.Generic.List[hashtable]]::new()
    }
    process {
        if ($ParamsList) {
            $collectedInput.AddRange($ParamsList)
        }
    }

    end {
        if ($collectedInput) {
            return $collectedInput + $param
        } else {
            return $param
        }
    }
}

<#
.SYNOPSIS
Creates a new OpenAPI number property.

.DESCRIPTION
Creates a new OpenAPI number property, for Schemas or Parameters.

.LINK
https://swagger.io/docs/specification/basic-structure/

.LINK
https://swagger.io/docs/specification/data-models/

.PARAMETER ParamsList
Used to pipeline multiple properties

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

.PARAMETER XmlName
By default, XML elements get the same names that fields in the API declaration have. This property change the XML name of the property

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
        [Parameter(ValueFromPipeline = $true, DontShow = $true )]
        [hashtable[]]
        $ParamsList,

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

        [Parameter()]
        [string]
        $XmlName,

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
    begin {

        $param = @{
            name = $Name
            type = 'number'
            meta = @{}
        }

        if ($Description ) {
            $param.description = $Description
        }

        if ($Array.IsPresent ) {
            $param.array = $Array.ToBool()
        }

        if ($Object.IsPresent ) {
            $param.object = $Object.ToBool()
        }

        if ($Required.IsPresent ) {
            $param.required = $Required.ToBool()
        }

        if ($Deprecated.IsPresent ) {
            $param.deprecated = $Deprecated.ToBool()
        }

        if ($Nullable.IsPresent ) {
            $param.meta['nullable'] = $Nullable.ToBool()
        }

        if ($WriteOnly.IsPresent ) {
            $param.meta['writeOnly'] = $WriteOnly.ToBool()
        }

        if ($ReadOnly.IsPresent ) {
            $param.meta['readOnly'] = $ReadOnly.ToBool()
        }

        if ($Example ) {
            $param.meta['example'] = $Example
        }

        if ($UniqueItems.IsPresent ) {
            $param.uniqueItems = $UniqueItems.ToBool()
        }

        if ($Default) {
            $param.default = $Default
        }

        if ($Format) {
            $param.format = $Format.ToLowerInvariant()
        }

        if ($MaxItems) {
            $param.maxItems = $MaxItems
        }

        if ($MinItems) {
            $param.minItems = $MinItems
        }

        if ($Enum) {
            $param.enum = $Enum
        }

        if ($XmlName) {
            $param.xmlName = $XmlName
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

        $collectedInput = [System.Collections.Generic.List[hashtable]]::new()
    }
    process {
        if ($ParamsList) {
            $collectedInput.AddRange($ParamsList)
        }
    }

    end {
        if ($collectedInput) {
            return $collectedInput + $param
        } else {
            return $param
        }
    }
}

<#
.SYNOPSIS
Creates a new OpenAPI string property.

.DESCRIPTION
Creates a new OpenAPI string property, for Schemas or Parameters.

.LINK
https://swagger.io/docs/specification/basic-structure/

.LINK
https://swagger.io/docs/specification/data-models/

.PARAMETER ParamsList
Used to pipeline multiple properties

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

.PARAMETER XmlName
By default, XML elements get the same names that fields in the API declaration have. This property change the XML name of the property

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

.PARAMETER MinLength
If supplied, the string will be restricted to minimal length of characters.

.PARAMETER  MaxLength
If supplied, the string will be restricted to maximal length of characters.

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
        [Parameter(ValueFromPipeline = $true, DontShow = $true )]
        [hashtable[]]
        $ParamsList,

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

        [Parameter()]
        [string]
        $XmlName,

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

        [Parameter()]
        [int]
        $MinLength,

        [Parameter()]
        [int]
        $MaxLength,

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
    begin {

        if (![string]::IsNullOrWhiteSpace($CustomFormat)) {
            $_format = $CustomFormat
        } elseif ($Format) {
            $_format = $Format
        }

        $param = @{
            name = $Name
            type = 'string'
            meta = @{}
        }

        if ($Description ) {
            $param.description = $Description
        }

        if ($Array.IsPresent ) {
            $param.array = $Array.ToBool()
        }

        if ($Object.IsPresent ) {
            $param.object = $Object.ToBool()
        }

        if ($Required.IsPresent ) {
            $param.required = $Required.ToBool()
        }

        if ($Deprecated.IsPresent ) {
            $param.deprecated = $Deprecated.ToBool()
        }

        if ($Nullable.IsPresent ) {
            $param.meta['nullable'] = $Nullable.ToBool()
        }

        if ($WriteOnly.IsPresent ) {
            $param.meta['writeOnly'] = $WriteOnly.ToBool()
        }

        if ($ReadOnly.IsPresent ) {
            $param.meta['readOnly'] = $ReadOnly.ToBool()
        }

        if ($Example ) {
            $param.meta['example'] = $Example
        }

        if ($UniqueItems.IsPresent ) {
            $param.uniqueItems = $UniqueItems.ToBool()
        }

        if ($Default) {
            $param.default = $Default
        }

        if ($Format -or $CustomFormat) {
            $param.format = $_format.ToLowerInvariant()
        }

        if ($MaxItems) {
            $param.maxItems = $MaxItems
        }

        if ($MinItems) {
            $param.minItems = $MinItems
        }

        if ($Enum) {
            $param.enum = $Enum
        }

        if ($XmlName) {
            $param.xmlName = $XmlName
        }

        if ($Pattern) {
            $param.meta['pattern'] = $Pattern
        }

        if ($MinLength) {
            $param.meta['minLength'] = $MinLength
        }

        if ($MaxLength) {
            $param.meta['maxLength'] = $MaxLength
        }
        $collectedInput = [System.Collections.Generic.List[hashtable]]::new()
    }
    process {
        if ($ParamsList) {
            $collectedInput.AddRange($ParamsList)
        }
    }

    end {
        if ($collectedInput) {
            return $collectedInput + $param
        } else {
            return $param
        }
    }
}

<#
.SYNOPSIS
Creates a new OpenAPI boolean property.

.DESCRIPTION
Creates a new OpenAPI boolean property, for Schemas or Parameters.

.LINK
https://swagger.io/docs/specification/basic-structure/

.LINK
https://swagger.io/docs/specification/data-models/

.PARAMETER ParamsList
Used to pipeline multiple properties

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

.PARAMETER XmlName
By default, XML elements get the same names that fields in the API declaration have. This property change the XML name of the property

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

        [Parameter(ValueFromPipeline = $true, DontShow = $true)]
        [hashtable[]]
        $ParamsList,

        [Parameter()]
        [string]
        $Name,

        [Parameter()]
        [string]
        $Default = 'false',

        [Parameter()]
        [string]
        $Description,

        [Parameter()]
        [string]
        $Example,

        [Parameter()]
        [string[]]
        $Enum,

        [Parameter()]
        [string]
        $XmlName,

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
    begin {

        $param = @{
            name = $Name
            type = 'boolean'
            meta = @{}
        }

        if ($Description ) {
            $param.description = $Description
        }

        if ($Array.IsPresent ) {
            $param.array = $Array.ToBool()
        }

        if ($Object.IsPresent ) {
            $param.object = $Object.ToBool()
        }

        if ($Required.IsPresent ) {
            $param.required = $Required.ToBool()
        }

        if ($Deprecated.IsPresent ) {
            $param.deprecated = $Deprecated.ToBool()
        }

        if ($Nullable.IsPresent ) {
            $param.meta['nullable'] = $Nullable.ToBool()
        }

        if ($WriteOnly.IsPresent ) {
            $param.meta['writeOnly'] = $WriteOnly.ToBool()
        }

        if ($ReadOnly.IsPresent ) {
            $param.meta['readOnly'] = $ReadOnly.ToBool()
        }

        if ($Example ) {
            $param.meta['example'] = $Example
        }

        if ($UniqueItems.IsPresent ) {
            $param.uniqueItems = $UniqueItems.ToBool()
        }

        if ($Default) {
            if ([bool]::TryParse($Default, [ref]$null) -or $Enum -icontains $Default) {
                $param.default = $Default
            } else {
                throw "The default value is not a boolean and it's not part of the enum"
            }
        }

        if ($MaxItems) {
            $param.maxItems = $MaxItems
        }

        if ($MinItems) {
            $param.minItems = $MinItems
        }

        if ($Enum) {
            $param.enum = $Enum
        }

        if ($XmlName) {
            $param.xmlName = $XmlName
        }
        $collectedInput = [System.Collections.Generic.List[hashtable]]::new()
    }
    process {
        if ($ParamsList) {
            $collectedInput.AddRange($ParamsList)
        }
    }

    end {
        if ($collectedInput) {
            return $collectedInput + $param
        } else {
            return $param
        }
    }
}

<#
.SYNOPSIS
Creates a new OpenAPI object property from other properties.

.DESCRIPTION
Creates a new OpenAPI object property from other properties, for Schemas or Parameters.

.LINK
https://swagger.io/docs/specification/basic-structure/

.LINK
https://swagger.io/docs/specification/data-models/

.PARAMETER ParamsList
Used to pipeline multiple properties

.PARAMETER Name
The Name of the property.

.PARAMETER Properties
An array of other int/string/etc properties wrap up as an object.

.PARAMETER Description
A Description of the property.

.PARAMETER Example
An example of a parameter value

.PARAMETER XmlName
By default, XML elements get the same names that fields in the API declaration have. This property change the XML name of the property

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

        [Parameter(ValueFromPipeline = $true, DontShow = $true , Position = 0 )]
        [hashtable[]]
        $ParamsList,

        [Parameter()]
        [string]
        $Name,

        [Parameter()]
        [hashtable[]]
        $Properties,

        [Parameter()]
        [string]
        $Description,

        [Parameter()]
        [String]
        $Example,

        [Parameter()]
        [string]
        $XmlName,

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

        [Parameter(  Mandatory, ParameterSetName = 'Array')]
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
    begin {

        $param = @{
            name = $Name
            type = 'object'
            meta = @{}
        }

        if ($Properties) {
            $param.properties = $Properties
            $PropertiesFromPipeline = $false
        } else {
            $param.properties = @()
            $PropertiesFromPipeline = $true
        }

        if ($Description ) {
            $param.description = $Description
        }

        if ($Array.IsPresent ) {
            $param.array = $Array.ToBool()
        }

        if ($Required.IsPresent ) {
            $param.required = $Required.ToBool()
        }

        if ($Deprecated.IsPresent ) {
            $param.deprecated = $Deprecated.ToBool()
        }

        if ($Nullable.IsPresent ) {
            $param.meta['nullable'] = $Nullable.ToBool()
        }

        if ($WriteOnly.IsPresent ) {
            $param.meta['writeOnly'] = $WriteOnly.ToBool()
        }

        if ($ReadOnly.IsPresent ) {
            $param.meta['readOnly'] = $ReadOnly.ToBool()
        }

        if ($Example ) {
            $param.meta['example'] = $Example
        }

        if ($UniqueItems.IsPresent ) {
            $param.uniqueItems = $UniqueItems.ToBool()
        }

        if ($Default) {
            $param.default = $Default
        }

        if ($MaxItems) {
            $param.maxItems = $MaxItems
        }

        if ($MinItems) {
            $param.minItems = $MinItems
        }

        if ($MinProperties) {
            $param.minProperties = $MinProperties
        }

        if ($MaxProperties) {
            $param.maxProperties = $MaxProperties
        }

        if ($XmlName) {
            $param.xmlName = $XmlName
        }

        if ($Xml) {
            $param.xml = $Xml
        }

        $collectedInput = [System.Collections.Generic.List[hashtable]]::new()
    }
    process {
        if ($ParamsList) {
            if ($PropertiesFromPipeline) {
                $param.properties += $ParamsList

            } else {
                $collectedInput.AddRange($ParamsList)
            }
        }
    }

    end {
        if ($PropertiesFromPipeline) {
            return $param
        } elseif ($collectedInput) {
            return $collectedInput + $param
        } else {
            return $param
        }
    }
}


<#
.SYNOPSIS
Creates a new OpenAPI object combining schemas and properties.

.DESCRIPTION
Creates a new OpenAPI object combining schemas and properties.

.LINK
https://swagger.io/docs/specification/basic-structure/

.LINK
https://swagger.io/docs/specification/data-models/

.PARAMETER ParamsList
Used to pipeline an object definition

.PARAMETER Type
Define the type of validation between the objects
oneOf – validates the value against exactly one of the subschemas
allOf – validates the value against all the subschemas
anyOf – validates the value against any (one or more) of the subschemas

.PARAMETER ObjectDefinitions
An array of object definitions that are used for independent validation but together compose a single object.

.PARAMETER Discriminator
When request bodies or response payloads may be one of a number of different schemas, a discriminator object can be used to aid in serialization, deserialization, and validation.
The discriminator is a specific object in a schema which is used to inform the consumer of the specification of an alternative schema based on the value associated with it.

.EXAMPLE
Add-PodeOAComponentSchema -Name 'Pets' -Schema (  Merge-PodeOAProperty  -Type OneOf -Schema @( 'Cat','Dog') -Discriminator "petType")


.EXAMPLE
Add-PodeOAComponentSchema -Name 'Cat' -Schema (
        Merge-PodeOAProperty  -Type AllOf -Schema @( 'Pet', ( New-PodeOAObjectProperty -Properties @(
                (New-PodeOAStringProperty -Name 'huntingSkill' -Description 'The measured skill for hunting' -Enum @(  'clueless', 'lazy', 'adventurous', 'aggressive'))
                ))
        ))
#>
function Merge-PodeOAProperty {
    [CmdletBinding(DefaultParameterSetName = 'Inbuilt')]
    param(

        [Parameter(ValueFromPipeline = $true, DontShow = $true )]
        [hashtable[]]
        $ParamsList,

        [Parameter(Mandatory)]
        [ValidateSet('OneOf', 'AnyOf', 'AllOf')]
        [string]
        $Type,

        [Parameter()]
        [System.Object[]]
        $ObjectDefinitions,

        [Parameter()]
        [string]
        $Discriminator
    )
    begin {

        $param = @{}
        switch ($type.ToLower()) {
            'oneof' {
                $param.type = 'oneOf'
            }
            'anyof' {
                $param.type = 'anyOf'
            }
            'allof' {
                $param.type = 'allOf'
            }
        }

        $param.schemas = @()
        if ($ObjectDefinitions) {
            foreach ($schema in $ObjectDefinitions) {
                if ($schema -is [System.Object[]] -or ($schema -is [hashtable] -and $schema.type -ine 'object')) {
                    throw "Only properties of type Object can be associated with $($param.type)"
                }
                $param.schemas += $schema
            }
        }

        if ($Discriminator ) {
            if ($type.ToLower() -eq 'allof' ) {
                throw 'Discriminator parameter is not compatible with allOf'
            }
            $param.discriminator = $Discriminator
        }

    }
    process {
        if ($ParamsList) {
            if ($ParamsList.type -ine 'object' -and !$ParamsList.object) {
                throw "Only properties of type Object can be associated with $type"
            }
            $param.schemas += $ParamsList
        }
    }

    end {
        return $param
    }
}


<#
.SYNOPSIS
Creates a OpenAPI schema reference property.

.DESCRIPTION
Creates a new OpenAPI component schema reference from another OpenAPI schema.

.LINK
https://swagger.io/docs/specification/basic-structure/

.LINK
https://swagger.io/docs/specification/data-models/

.PARAMETER ParamsList
Used to pipeline multiple properties

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

.PARAMETER Required
If supplied, the object will be treated as Required where supported.

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

        [Parameter(ValueFromPipeline = $true, DontShow = $true )]
        [hashtable[]]
        $ParamsList,

        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true)]
        [Alias('Reference')]
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
    begin {

        if ( !(Test-PodeOAComponentSchema -Name $ComponentSchema)) {
            throw "The OpenApi component schema doesn't exist: $ComponentSchema"
        }

        $param = @{
            name   = $Name
            type   = 'schema'
            schema = $ComponentSchema
            meta   = @{}
        }

        if ($PSCmdlet.ParameterSetName.ToLowerInvariant() -ieq 'array') {
            if ($Description ) {
                $param.description = $Description
            }

            if ($Array.IsPresent ) {
                $param.array = $Array.ToBool()
            }

            if ($Required.IsPresent ) {
                $param.required = $Required.ToBool()
            }

            if ($Deprecated.IsPresent ) {
                $param.deprecated = $Deprecated.ToBool()
            }

            if ($Nullable.IsPresent ) {
                $param.meta['nullable'] = $Nullable.ToBool()
            }

            if ($WriteOnly.IsPresent ) {
                $param.meta['writeOnly'] = $WriteOnly.ToBool()
            }

            if ($ReadOnly.IsPresent ) {
                $param.meta['readOnly'] = $ReadOnly.ToBool()
            }

            if ($Example ) {
                $param.meta['example'] = $Example
            }

            if ($UniqueItems.IsPresent ) {
                $param.uniqueItems = $UniqueItems.ToBool()
            }

            if ($Default) {
                $param.default = $Default
            }

            if ($MaxItems) {
                $param.maxItems = $MaxItems
            }

            if ($MinItems) {
                $param.minItems = $MinItems
            }

            if ($MinProperties) {
                $param.minProperties = $MinProperties
            }

            if ($MaxProperties) {
                $param.maxProperties = $MaxProperties
            }

            if ($Xml) {
                $param.xml = $Xml
            }
        } elseif ($Description) {
            Write-PodeHost "New-PodeOASchemaProperty $ComponentSchema - Description can only be applied to an array"
        }
        $collectedInput = [System.Collections.Generic.List[hashtable]]::new()
    }
    process {
        if ($ParamsList) {
            $collectedInput.AddRange($ParamsList)
        }
    }
    end {
        if ($collectedInput) {
            return $collectedInput + $param
        } else {
            return $param
        }
    }
}




<#
.SYNOPSIS
Converts an OpenAPI property into a Request Parameter.

.DESCRIPTION
Converts an OpenAPI property (such as from New-PodeOAIntProperty) into a Request Parameter.

.LINK
https://swagger.io/docs/specification/describing-parameters/

.LINK
https://github.com/OAI/OpenAPI-Specification/blob/main/versions/3.0.3.md#parameterObject

.PARAMETER In
Where in the Request can the parameter be found?

.PARAMETER Property
The Property that need converting (such as from New-PodeOAIntProperty).

.PARAMETER ComponentParameter
The name of an existing component parameter to be reused.

.PARAMETER ContentType
The content-types to be use with  component schema

.PARAMETER ContentSchemas
The component schema to use.

.PARAMETER Description
A Description of the property.

.PARAMETER Explode
If supplied, controls how arrays are serialized in query parameters

.PARAMETER AllowEmptyValue
If supplied, allow the parameter to be empty

.PARAMETER Style
If supplied,  defines how multiple values are delimited. Possible styles depend on the parameter location: path, query, header or cookie.


.EXAMPLE
New-PodeOAIntProperty -Name 'userId' | ConvertTo-PodeOAParameter -In Query

.EXAMPLE
ConvertTo-PodeOAParameter -ComponentParameter 'UserIdParam'

.EXAMPLE
ConvertTo-PodeOAParameter  -In Header -ContentSchemas @{ 'application/json' = 'UserIdSchema' }

#>
function ConvertTo-PodeOAParameter {
    [CmdletBinding(DefaultParameterSetName = 'Reference')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'Properties')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ContentSchemas')]
        [ValidateSet('Cookie', 'Header', 'Path', 'Query')]
        [string]
        $In,

        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = 'Properties')]
        [ValidateNotNull()]
        [hashtable]
        $Property,

        [Parameter(Mandatory = $true, ParameterSetName = 'Reference')]
        [Alias('Reference')]
        [string]
        $ComponentParameter,

        [Parameter(Mandatory = $true, ParameterSetName = 'ContentSchemas')]
        [String]
        $ContentSchemas,

        [Parameter(Mandatory = $true, ParameterSetName = 'ContentSchemas')]
        $ContentType,

        [Parameter( ParameterSetName = 'ContentSchemas')]
        [String]
        $Description,

        [Parameter( ParameterSetName = 'Properties')]
        [Switch]
        $Explode,

        [Parameter( ParameterSetName = 'Properties')]
        [Switch]
        $AllowEmptyValue,

        [Parameter( ParameterSetName = 'Properties')]
        [ValidateSet('Simple', 'Label', 'Matrix', 'Query', 'Form', 'SpaceDelimited', 'PipeDelimited', 'DeepObject' )]
        [string]
        $Style
    )

    if ($PSCmdlet.ParameterSetName -ieq 'ContentSchemas') {
        if (Test-PodeIsEmpty $ContentSchemas) {
            return $null
        }
        # ensure all content types are valid
        if ($ContentType -inotmatch '^\w+\/[\w\.\+-]+$') {
            throw "Invalid content-type found for schema: $($type)"
        }
        if (!(Test-PodeOAComponentSchema -Name $ContentSchemas )) {
            throw "The OpenApi component request parameter doesn't exist: $($ContentSchemas )"
        }
        $Property = $PodeContext.Server.OpenAPI.components.schemas[$ContentSchemas ]
        $prop = @{
            in      = $In.ToLowerInvariant()
            name    = $ContentSchemas
            content = @{
                $ContentType = @{
                    schema = @{
                        '$ref' = "#/components/schemas/$($ContentSchemas )"
                    }
                }
            }
        }
        if ($Description ) {
            $prop.description = $Description
        }
        if ($In -ieq 'Header' -and $PodeContext.Server.Security.autoHeaders) {
            Add-PodeSecurityHeader -Name 'Access-Control-Allow-Headers' -Value $ContentSchemas  -Append
        }
    } elseif ($PSCmdlet.ParameterSetName -ieq 'Reference') {
        # return a reference
        if (!(Test-PodeOAComponentParameter -Name $ComponentParameter)) {
            throw "The OpenApi component request parameter doesn't exist: $($ComponentParameter)"
        }

        $prop = @{
            '$ref' = "#/components/parameters/$($ComponentParameter)"
        }
        if ($PodeContext.Server.OpenAPI.components.parameters.$ComponentParameter.In -eq 'Header' -and $PodeContext.Server.Security.autoHeaders) {
            Add-PodeSecurityHeader -Name 'Access-Control-Allow-Headers' -Value $ComponentParameter -Append
        }
    } else {
        # non-object/array only
        if (@('array', 'object') -icontains $Property.type) {
            throw 'OpenApi request parameter cannot be an array of object'
        }
        if ($In -ieq 'Header' -and $PodeContext.Server.Security.autoHeaders -and $Property.name) {
            Add-PodeSecurityHeader -Name 'Access-Control-Allow-Headers' -Value $Property.name -Append
        }
        # build the base parameter
        $prop = @{
            in   = $In.ToLowerInvariant()
            name = $Property.name
        }
        if ($Property.description ) {
            $prop.description = $Property.description
        }

        if ($Property.Array) {
            $prop.schema = @{
                type  = 'array'
                items = @{
                    type = $Property.type
                }
            }
            if ($Property.format) {
                $prop.schema.items.format = $Property.format
            }
        } else {
            $prop.schema = @{
                type = $Property.type
            }
            if ($Property.format) {
                $prop.schema.format = $Property.format
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
            switch ($in.ToLower()) {
                'path' {
                    if (@('Simple', 'Label', 'Matrix' ) -inotcontains $Style) {
                        throw "OpenApi request Style cannot be $Style for a $in parameter"
                    }
                    break
                }
                'query' {
                    if (@('Form', 'SpaceDelimited', 'PipeDelimited', 'DeepObject' ) -inotcontains $Style) {
                        throw "OpenApi request Style cannot be $Style for a $in parameter"
                    }
                    break
                }
                'header' {
                    if (@('Simple' ) -inotcontains $Style) {
                        throw "OpenApi request Style cannot be $Style for a $in parameter"
                    }
                    break
                }
                'cookie' {
                    if (@('Form' ) -inotcontains $Style) {
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

        if ($In -ieq 'Path') {
            $prop['required'] = $true
        } elseif ($Property.required ) {
            $prop['required'] = $Property.required
        }
        # remove default for required parameter
        if (!$Property.required -and $PSCmdlet.ParameterSetName -ine 'ContentSchemas') {
            if ( $prop.ContainsKey('schema') -and $Property.default) {
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

.LINK
https://swagger.io/docs/specification/paths-and-operations/

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
        if ($Summary) {
            $r.OpenApi.Summary = $Summary
        }
        if ($Description) {
            $r.OpenApi.Description = $Description
        }
        if ($OperationId) {
            $r.OpenApi.OperationId = $OperationId
        }
        if ($Tags) {
            $r.OpenApi.Tags = $Tags
        }
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
Adds a route that enables a viewer to display OpenAPI docs, such as Swagger, ReDoc, RapiDoc, StopLight, Explorer, RapiPdf or Bookmarks.

.DESCRIPTION
Adds a route that enables a viewer to display OpenAPI docs, such as Swagger, ReDoc, RapiDoc, StopLight, Explorer, RapiPdf  or Bookmarks.

.LINK
https://github.com/mrin9/RapiPdf

.LINK
https://github.com/Authress-Engineering/openapi-explorer

.LINK
https://github.com/stoplightio/elements

.LINK
https://github.com/rapi-doc/RapiDoc

.LINK
https://github.com/Redocly/redoc

.LINK
https://github.com/swagger-api/swagger-ui

.PARAMETER Type
The Type of OpenAPI viewer to use.

.PARAMETER Path
The route Path where the docs can be accessed. (Default: "/$Type")

.PARAMETER OpenApiUrl
The URL where the OpenAPI definition can be retrieved. (Default is the OpenAPI path from Enable-PodeOpenApi)

.PARAMETER Middleware
Like normal Routes, an array of Middleware that will be applied.

.PARAMETER Title
The title of the web page. (Default is the OpenAPI title from Enable-PodeOpenApi)

.PARAMETER DarkMode
If supplied, the page will be rendered using a dark theme (this is not supported for all viewers).

.EXAMPLE
Enable-PodeOAViewer -Type Swagger -DarkMode

.EXAMPLE
Enable-PodeOAViewer -Type ReDoc -Title 'Some Title' -OpenApi 'http://some-url/openapi'

.EXAMPLE
Enable-PodeOAViewer -Type Bookmarks

Adds a route that enables a viewer to display with links to any documentation tool associated with the OpenApi.
#>
function Enable-PodeOAViewer {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Swagger', 'ReDoc', 'RapiDoc', 'StopLight', 'Explorer', 'RapiPdf', 'Bookmarks')]
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
    $Title = Protect-PodeValue -Value $Title -Default $PodeContext.Server.OpenAPI.info.Title
    if ([string]::IsNullOrWhiteSpace($Title)) {
        throw "No title supplied for $($Type) page"
    }

    # set a default path
    $Path = Protect-PodeValue -Value $Path -Default "/$($Type.ToLowerInvariant())"
    if ([string]::IsNullOrWhiteSpace($Title)) {
        throw "No route path supplied for $($Type) page"
    }

    if ($Type -ieq 'Bookmarks') {
        # setup meta info
        $meta = @{
            Type     = $Type.ToLowerInvariant()
            Title    = $Title
            OpenApi  = $OpenApiUrl
            DarkMode = $DarkMode
        }
        Add-PodeRoute -Method Get -Path $Path -Middleware $Middleware -ArgumentList $meta -ScriptBlock {
            param($meta)
            $Data = @{
                Title   = $meta.Title
                OpenApi = $meta.OpenApi
            }
            foreach ($type in $PodeContext.Server.OpenAPI.hiddenComponents.viewer.Keys) {
                $Data[$type] = $true
                $Data["$($type)_path"] = $PodeContext.Server.OpenAPI.hiddenComponents.viewer[$type]
            }

            $podeRoot = Get-PodeModuleMiscPath
            Write-PodeFileResponse -Path ([System.IO.Path]::Combine($podeRoot, 'default-doc-bookmarks.html.pode')) -Data $Data
        }
    } else {
        # setup meta info
        $meta = @{
            Type     = $Type.ToLowerInvariant()
            Title    = $Title
            OpenApi  = $OpenApiUrl
            DarkMode = $DarkMode
        }
        $PodeContext.Server.OpenAPI.hiddenComponents.viewer[$($meta.Type)] = $Path
        # add the viewer route
        Add-PodeRoute -Method Get -Path $Path -Middleware $Middleware -ArgumentList $meta -ScriptBlock {
            param($meta)
            $podeRoot = Get-PodeModuleMiscPath
            if ( $meta.DarkMode) { $Theme = 'dark' } else { $Theme = 'light' }
            Write-PodeFileResponse -Path ([System.IO.Path]::Combine($podeRoot, "default-$($meta.Type).html.pode")) -Data @{
                Title    = $meta.Title
                OpenApi  = $meta.OpenApi
                DarkMode = $meta.DarkMode
                Theme    = $Theme
            }
        }
    }

}


<#
.SYNOPSIS
Define an external docs reference.

.DESCRIPTION
Define an external docs reference.

.LINK
https://swagger.io/docs/specification/grouping-operations-with-tags/

.LINK
https://github.com/OAI/OpenAPI-Specification/blob/main/versions/3.0.3.md#externalDocumentationObject

.PARAMETER Name
The Name of the reference.

.PARAMETER url
The link to the external documentation

.PARAMETER Description
A Description of the external documentation.

.EXAMPLE
New-PodeOAExternalDoc  -Name 'SwaggerDocs' -Description 'Find out more about Swagger' -Url 'http://swagger.io'
Add-PodeOAExternalDoc -Name 'SwaggerDocs'

.EXAMPLE
New-PodeOAExternalDoc  -Name 'SwaggerDocs' -Description 'Find out more about Swagger' -Url 'http://swagger.io'
Add-PodeOATag -Name 'user' -Description 'Operations about user' -ExternalDoc 'SwaggerDocs'
#>
function New-PodeOAExternalDoc {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true)]
        [ValidateScript({ $_ -imatch '^https?://.+' })]
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
Add an external docs reference to the OpenApi document.

.DESCRIPTION
Add an external docs reference to the OpenApi document.

.LINK
https://swagger.io/docs/specification/api-general-info/

.LINK
https://github.com/OAI/OpenAPI-Specification/blob/main/versions/3.0.3.md#externalDocumentationObject

.PARAMETER Reference
The Name assigned to a previoulsy created External Doc reference (created by New-PodeOAExternalDoc)

.PARAMETER Name
The Name of the reference.

.PARAMETER url
The link to the external documentation

.PARAMETER Description
A Description of the external documentation.

.EXAMPLE
Add-PodeOAExternalDoc  -Name 'SwaggerDocs' -Description 'Find out more about Swagger' -Url 'http://swagger.io'

.EXAMPLE
New-PodeOAExternalDoc  -Name 'SwaggerDocs' -Description 'Find out more about Swagger' -Url 'http://swagger.io'
Add-PodeOAExternalDoc -Name 'SwaggerDocs'
#>
function Add-PodeOAExternalDoc {
    [CmdletBinding(DefaultParameterSetName = 'Reference')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'Schema')]
        [string]
        $Reference,

        [Parameter(Mandatory = $true, ParameterSetName = 'NewRef')]
        [ValidateScript({ $_ -imatch '^https?://.+' })]
        $Url,

        [Parameter(ParameterSetName = 'NewRef')]
        [string]
        $Description
    )
    if ($PSCmdlet.ParameterSetName -ieq 'NewRef') {
        $param = @{url = $Url }
        if ($Description) {
            $param.description = $Description
        }
        $PodeContext.Server.OpenAPI.externalDocs = $param
    } else {
        if ( !(Test-PodeOAExternalDoc -Name $Reference)) {
            throw "The ExternalDoc doesn't exist: $Reference"
        }
        $PodeContext.Server.OpenAPI.externalDocs = $PodeContext.Server.OpenAPI.hiddenComponents.externalDocs[$Reference]
    }
}


<#
.SYNOPSIS
Creates a OpenAPI Tag reference property.

.DESCRIPTION
Creates a new OpenAPI tag reference.

.LINK
https://swagger.io/docs/specification/grouping-operations-with-tags/

.LINK
https://github.com/OAI/OpenAPI-Specification/blob/main/versions/3.0.3.md#tagObject

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

.LINK
https://swagger.io/docs/specification/api-general-info/

.LINK
https://github.com/OAI/OpenAPI-Specification/blob/main/versions/3.0.3.md#infoObject

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
Add-PodeOAInfo -TermsOfService 'http://swagger.io/terms/' -License 'Apache 2.0' -LicenseUrl 'http://www.apache.org/licenses/LICENSE-2.0.html' -ContactName 'API Support' -ContactEmail 'apiteam@swagger.io' -ContactUrl 'http://example.com/support'
#>

function Add-PodeOAInfo {
    param(
        [Parameter()]
        [ValidateScript({ $_ -imatch '^https?://.+' })]
        [string]
        $TermsOfService,

        [Parameter(Mandatory = $true)]
        [string]
        $License,

        [Parameter(Mandatory = $true)]
        [ValidateScript({ $_ -imatch '^https?://.+' })]
        [string]
        $LicenseUrl,

        [Parameter()]
        [string]
        $ContactName,

        [Parameter()]
        [ValidateScript({ $_ -imatch '^\w+([-+.]\w+)*@\w+([-.]\w+)*\.\w+([-.]\w+)*$' })]
        [string]
        $ContactEmail,

        [Parameter()]
        [ValidateScript({ $_ -imatch '^https?://.+' })]
        [string]
        $ContactUrl
    )

    $Info = @{
        'license' = @{
            'name' = $License
            'url'  = $LicenseUrl
        }
    }

    if ($TermsOfService) {
        $Info['termsOfService'] = $TermsOfService
    }

    if ($ContactName -or $ContactEmail -or $ContactUrl ) {
        $Info['contact'] = @{}

        if ($ContactName) {
            $Info['contact'].name = $ContactName
        }

        if ($ContactEmail) {
            $Info['contact'].email = $ContactEmail
        }

        if ($ContactUrl) {
            $Info['contact'].url = $ContactUrl
        }
    }

    $PodeContext.Server.OpenAPI.info += $Info

}


if (!(Test-Path Alias:Enable-PodeOpenApiViewer)) {
    New-Alias Enable-PodeOpenApiViewer -Value  Enable-PodeOAViewer
}
if (!(Test-Path Alias:Enable-PodeOA)) {
    New-Alias Enable-PodeOA -Value Enable-PodeOpenApi
}