<#
.SYNOPSIS
Enables the OpenAPI default route in Pode.

.DESCRIPTION
Enables the OpenAPI default route in Pode, as well as setting up details like Title and API Version.

.PARAMETER Path
An optional custom route path to access the OpenAPI definition. (Default: /openapi)

.PARAMETER Title
The Title of the API. (Deprecated -  Use Add-PodeOAInfo)

.PARAMETER Version
The Version of the API.   (Deprecated -  Use Add-PodeOAInfo)
The OpenAPI Specification is versioned using Semantic Versioning 2.0.0 (semver) and follows the semver specification.
https://semver.org/spec/v2.0.0.html

.PARAMETER Description
A short description of the API. (Deprecated -  Use Add-PodeOAInfo)
CommonMark syntax MAY be used for rich text representation.
https://spec.commonmark.org/

.PARAMETER OpenApiVersion
Specify OpenApi Version (default: 3.0.3)

.PARAMETER RouteFilter
An optional route filter for routes that should be included in the definition. (Default: /*)

.PARAMETER Middleware
Like normal Routes, an array of Middleware that will be applied to the route.

.PARAMETER EndpointName
The EndpointName of an Endpoint(s) to bind the static Route against.

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
If supplied enable Test-PodeOAJsonSchemaCompliance  cmdlet that provide support for opeapi parameter schema validation

.PARAMETER Depth
Define the default  depth used by any JSON,YAML OpenAPI conversion (default 20)

.PARAMETER DisableMinimalDefinitions
If supplied the OpenApi decument will include only the route validated by Set-PodeOARouteInfo. Any other not OpenApi route will be excluded.

.PARAMETER NoDefaultResponses
If supplied, it will disable the default OpenAPI response with the new provided.

.PARAMETER DefaultResponses
If supplied, it will replace the default OpenAPI response with the new provided.(Default: @{'200' = @{ description = 'OK' };'default' = @{ description = 'Internal server error' }} )

.PARAMETER DefinitionTag
A string representing the unique tag for the API specification.
This tag helps distinguish between different versions or types of API specifications within the application.
You can use this tag to reference the specific API documentation, schema, or version that your function interacts with.

.EXAMPLE
Enable-PodeOpenApi -Title 'My API' -Version '1.0.0' -RouteFilter '/api/*'

.EXAMPLE
Enable-PodeOpenApi -Title 'My API' -Version '1.0.0' -RouteFilter '/api/*' -RestrictRoutes

.EXAMPLE
Enable-PodeOpenApi -Path '/docs/openapi'   -NoCompress -Mode 'Donwload' -DisableMinimalDefinitions
#>
function Enable-PodeOpenApi {
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [string]
        $Path = '/openapi',

        [Parameter(ParameterSetName = 'Deprecated')]
        [string]
        $Title,

        [Parameter(ParameterSetName = 'Deprecated')]
        [ValidatePattern('^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$')]
        [string]
        $Version,

        [Parameter(ParameterSetName = 'Deprecated')]
        [string]
        $Description,

        [ValidateSet('3.1.0', '3.0.3', '3.0.2', '3.0.1', '3.0.0')]
        [string]
        $OpenApiVersion = '3.0.3',

        [ValidateNotNullOrEmpty()]
        [string]
        $RouteFilter = '/*',

        [string[]]
        $EndpointName,

        [object[]]
        $Middleware,

        [switch]
        $RestrictRoutes,

        [ValidateSet('View', 'Download')]
        [String]
        $Mode = 'view',

        [ValidateSet('Json', 'Json-Compress', 'Yaml')]
        [String]
        $MarkupLanguage = 'Json',

        [switch]
        $EnableSchemaValidation,

        [ValidateRange(1, 100)]
        [int]
        $Depth = 20,

        [switch]
        $DisableMinimalDefinitions,

        [Parameter(Mandatory, ParameterSetName = 'DefaultResponses')]
        [hashtable]
        $DefaultResponses,

        [Parameter(Mandatory, ParameterSetName = 'NoDefaultResponses')]
        [switch]
        $NoDefaultResponses,

        [string]
        $DefinitionTag

    )
    if (Test-PodeIsEmpty -Value $DefinitionTag) {
        $DefinitionTag = $PodeContext.Server.SelectedOADefinitionTag
    }
    if ($Description -or $Version -or $Title) {
        Write-PodeHost -ForegroundColor Yellow "WARNING: The parameter Title,Version and Description are deprecated. Please use 'Add-PodeOAInfo' instead."
    }
    if ( $DefinitionTag -ine $PodeContext.Server.DefaultOADefinitionTag ) {
        $PodeContext.Server.OpenAPI[$DefinitionTag] = Get-PodeOABaseObject
    }
    $PodeContext.Server.OpenAPI[$DefinitionTag].hiddenComponents.enableMinimalDefinitions = !$DisableMinimalDefinitions.IsPresent


    # initialise openapi info
    $PodeContext.Server.OpenAPI[$DefinitionTag].Version = $OpenApiVersion
    $PodeContext.Server.OpenAPI[$DefinitionTag].Path = $Path

    $PodeContext.Server.OpenAPI[$DefinitionTag].hiddenComponents.v3_0 = $OpenApiVersion.StartsWith('3.0')
    $PodeContext.Server.OpenAPI[$DefinitionTag].hiddenComponents.v3_1 = $OpenApiVersion.StartsWith('3.1')

    $meta = @{
        RouteFilter    = $RouteFilter
        RestrictRoutes = $RestrictRoutes
        NoCompress     = ($MarkupLanguage -ine 'Json-Compress')
        Mode           = $Mode
        MarkupLanguage = $MarkupLanguage
        DefinitionTag  = $DefinitionTag
    }
    if ( $Title) {
        $PodeContext.Server.OpenAPI[$DefinitionTag].info.title = $Title
    }
    if ($Version) {
        $PodeContext.Server.OpenAPI[$DefinitionTag].info.version = $Version
    }

    if ($Description ) {
        $PodeContext.Server.OpenAPI[$DefinitionTag].info.description = $Description
    }

    if ( $EnableSchemaValidation.IsPresent) {
        #Test-Json has been introduced with version 6.1.0
        if ($PSVersionTable.PSVersion -ge [version]'6.1.0') {
            $PodeContext.Server.OpenAPI[$DefinitionTag].hiddenComponents.schemaValidation = $EnableSchemaValidation.IsPresent
        } else {
            throw 'Schema validation required Powershell version 6.1.0 or greater'
        }
    }

    if ( $Depth) {
        $PodeContext.Server.OpenAPI[$DefinitionTag].hiddenComponents.depth = $Depth
    }


    $openApiCreationScriptBlock = {
        param($meta)
        $format = $WebEvent.Query['format']
        $mode = $WebEvent.Query['mode']
        $DefinitionTag = $meta.DefinitionTag

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
        } elseif (@('yaml', 'json', 'json-Compress') -inotcontains $format) {
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
            -DefinitionTag $DefinitionTag `
            -MetaInfo $meta

        # write the openapi definition
        if ($format -ieq 'yaml') {
            if ($mode -ieq 'view') {
                Write-PodeTextResponse -Value (ConvertTo-PodeYaml -InputObject $def -depth $PodeContext.Server.OpenAPI[$DefinitionTag].hiddenComponents.depth) -ContentType 'text/x-yaml; charset=utf-8'
            } else {
                Write-PodeYamlResponse -Value $def -depth $PodeContext.Server.OpenAPI[$DefinitionTag].hiddenComponents.depth
            }
        } else {
            Write-PodeJsonResponse -Value $def -depth $PodeContext.Server.OpenAPI[$DefinitionTag].hiddenComponents.depth -NoCompress:$meta.NoCompress
        }
    }

    # add the OpenAPI route
    Add-PodeRoute -Method Get -Path $Path -ArgumentList $meta -Middleware $Middleware -ScriptBlock $openApiCreationScriptBlock -EndpointName $EndpointName
    Add-PodeRoute -Method Get -Path "$Path.json" -ArgumentList $meta -Middleware $Middleware -ScriptBlock $openApiCreationScriptBlock -EndpointName $EndpointName
    Add-PodeRoute -Method Get -Path "$Path.yaml" -ArgumentList $meta -Middleware $Middleware -ScriptBlock $openApiCreationScriptBlock -EndpointName $EndpointName
    #set new DefaultResponses
    if ($NoDefaultResponses.IsPresent) {
        $PodeContext.Server.OpenAPI[$DefinitionTag].hiddenComponents.defaultResponses = @{}
    } elseif ($DefaultResponses) {
        $PodeContext.Server.OpenAPI[$DefinitionTag].hiddenComponents.defaultResponses = $DefaultResponses
    }
    $PodeContext.Server.OpenAPI[$DefinitionTag].hiddenComponents.enabled = $true
}




<#
.SYNOPSIS
Creates an OpenAPI Server Object.

.DESCRIPTION
Creates an OpenAPI Server Object.

.LINK
https://swagger.io/docs/specification/api-host-and-base-path/

.PARAMETER Url
A URL to the target host.  This URL supports Server Variables and MAY be relative, to indicate that the host location is relative to the location where the OpenAPI document is being served.
Variable substitutions will be made when a variable is named in `{`brackets`}`.

.PARAMETER Description
An optional string describing the host designated by the URL. [CommonMark syntax](https://spec.commonmark.org/) MAY be used for rich text representation.

.PARAMETER Variables
A map between a variable name and its value.  The value is used for substitution in the server's URL template.

.PARAMETER DefinitionTag
An Array of strings representing the unique tag for the API specification.
This tag helps distinguish between different versions or types of API specifications within the application.
You can use this tag to reference the specific API documentation, schema, or version that your function interacts with.

.EXAMPLE
Add-PodeOAServerEndpoint -Url 'https://myserver.io/api' -Description 'My test server'

.EXAMPLE
Add-PodeOAServerEndpoint -Url '/api' -Description 'My local server'

.EXAMPLE
Add-PodeOAServerEndpoint -Url "https://{username}.gigantic-server.com:{port}/{basePath}" -Description "The production API server" `
    -Variable   @{
        username = @{
            default = 'demo'
            description = 'this value is assigned by the service provider, in this example gigantic-server.com'
        }
        port = @{
            enum = @('System.Object[]')  # Assuming 'System.Object[]' is a placeholder for actual values
            default = 8443
        }
        basePath = @{
            default = 'v2'
        }
    }
}
#>
function Add-PodeOAServerEndpoint {
    param (
        [Parameter(Mandatory = $true)]
        [ValidatePattern('^(https?://|/).+')]
        [string]
        $Url,

        [string]
        $Description,

        [System.Collections.Specialized.OrderedDictionary]
        $Variables,

        [string[]]
        $DefinitionTag
    )

    if (Test-PodeIsEmpty -Value $DefinitionTag) {
        $DefinitionTag = @($PodeContext.Server.SelectedOADefinitionTag)
    }
    foreach ($tag in $DefinitionTag) {
        if (! $PodeContext.Server.OpenAPI[$tag].servers) {
            $PodeContext.Server.OpenAPI[$tag].servers = @()
        }
        $lUrl = [ordered]@{url = $Url }
        if ($Description) {
            $lUrl.description = $Description
        }

        if ($Variables) {
            $lUrl.variables = $Variables
        }
        $PodeContext.Server.OpenAPI[$tag].servers += $lUrl
    }
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

.PARAMETER DefinitionTag
A string representing the unique tag for the API specification.
This tag helps distinguish between different versions or types of API specifications within the application.
You can use this tag to reference the specific API documentation, schema, or version that your function interacts with.

.EXAMPLE
$defInJson = Get-PodeOADefinition -Json
#>
function Get-PodeOADefinition {
    [CmdletBinding()]
    param(
        [ValidateSet('Json', 'Json-Compress', 'Yaml', 'HashTable')]
        [string]
        $Format = 'HashTable',

        [string]
        $Title,

        [string]
        $Version,

        [string]
        $Description,

        [ValidateNotNullOrEmpty()]
        [string]
        $RouteFilter = '/*',

        [switch]
        $RestrictRoutes,

        [string]
        $DefinitionTag
    )

    $DefinitionTag = Test-PodeOADefinitionTag -Tag $DefinitionTag

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

    $oApi = Get-PodeOpenApiDefinitionInternal  -MetaInfo $meta -EndpointName $WebEvent.Endpoint.Name -DefinitionTag $DefinitionTag

    switch ($Format.ToLower()) {
        'json' {
            return ConvertTo-Json -InputObject $oApi -depth $PodeContext.Server.OpenAPI[$DefinitionTag].hiddenComponents.depth
        }
        'json-compress' {
            return ConvertTo-Json -InputObject $oApi -depth $PodeContext.Server.OpenAPI[$DefinitionTag].hiddenComponents.depth -Compress
        }
        'yaml' {
            return ConvertTo-PodeYaml -InputObject $oApi -depth $PodeContext.Server.OpenAPI[$DefinitionTag].hiddenComponents.depth
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
The HTTP StatusCode for the response.To define a range of response codes, this field MAY contain the uppercase wildcard character `X`.
For example, `2XX` represents all response codes between `[200-299]`. Only the following range definitions are allowed: `1XX`, `2XX`, `3XX`, `4XX`, and `5XX`.
If a response is defined using an explicit code, the explicit code definition takes precedence over the range definition for that code.

.PARAMETER Content
The content-types and schema the response returns (the schema is created using the Property functions).
Alias: ContentSchemas

.PARAMETER Headers
The header name and schema the response returns (the schema is created using Add-PodeOAComponentHeader cmd-let).
Alias: HeaderSchemas

.PARAMETER Description
A Description of the response. (Default: the HTTP StatusCode description)

.PARAMETER Reference
A Reference Name of an existing component response to use.

.PARAMETER Links
A Response link definition

.PARAMETER Default
If supplied, the response will be used as a default response - this overrides the StatusCode supplied.

.PARAMETER PassThru
If supplied, the route passed in will be returned for further chaining.

.PARAMETER DefinitionTag
An Array of strings representing the unique tag for the API specification.
This tag helps distinguish between different versions or types of API specifications within the application.
You can use this tag to reference the specific API documentation, schema, or version that your function interacts with.


.EXAMPLE
Add-PodeRoute -PassThru | Add-PodeOAResponse -StatusCode 200 -Content @{ 'application/json' = (New-PodeOAIntProperty -Name 'userId' -Object) }

.EXAMPLE
Add-PodeRoute -PassThru | Add-PodeOAResponse -StatusCode 200 -Content @{ 'application/json' = 'UserIdSchema' }

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
        [ValidatePattern('^([1-5][0-9][0-9]|[1-5]XX)$')]
        [string]
        $StatusCode,

        [Parameter(ParameterSetName = 'Schema')]
        [Parameter(ParameterSetName = 'SchemaDefault')]
        [Alias('ContentSchemas')]
        [hashtable]
        $Content,

        [Alias('HeaderSchemas')]
        [AllowEmptyString()]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ $_ -is [string] -or $_ -is [string[]] -or $_ -is [hashtable] -or $_ -is [ordered] })]
        $Headers,

        [Parameter(Mandatory = $false, ParameterSetName = 'Schema')]
        [Parameter(Mandatory = $false, ParameterSetName = 'SchemaDefault')]
        [string]
        $Description,

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
        [System.Collections.Specialized.OrderedDictionary ]
        $Links,

        [switch]
        $PassThru,

        [string[]]
        $DefinitionTag
    )

    $DefinitionTag = Test-PodeOADefinitionTag -Tag $DefinitionTag
    # override status code with default
    if ($Default) {
        $code = 'default'
    } else {
        $code = "$($StatusCode)"
    }

    # add the respones to the routes
    foreach ($r in @($Route)) {
        foreach ($tag in $DefinitionTag) {
            if (! $r.OpenApi.Responses.$tag) {
                $r.OpenApi.Responses.$tag = @{}
            }
            $r.OpenApi.Responses.$tag[$code] = New-PodeOResponseInternal  -DefinitionTag $tag -Params $PSBoundParameters
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
Add-PodeRoute -PassThru | Set-PodeOARequest -RequestBody (New-PodeOARequestBody -Schema 'UserIdBody')
#>
function Set-PodeOARequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [hashtable[]]
        $Route,

        [hashtable[]]
        $Parameters,

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
Alias: Reference

.PARAMETER Content
The content of the request body. The key is a media type or media type range and the value describes it.
For requests that match multiple keys, only the most specific key is applicable. e.g. text/plain overrides text/*
Alias: ContentSchemas

.PARAMETER Description
A brief description of the request body. This could contain examples of use. CommonMark syntax MAY be used for rich text representation.

.PARAMETER Required
Determines if the request body is required in the request. Defaults to false.

.PARAMETER Properties
Use to force the use of the properties keyword under a schema. Commonly used to specify a multipart/form-data multi file

.PARAMETER Examples
Supplied an Example of the media type.  The example object SHOULD be in the correct format as specified by the media type.
The `example` field is mutually exclusive of the `examples` field.
Furthermore, if referencing a `schema` which contains an example, the `example` value SHALL _override_ the example provided by the schema.

.PARAMETER Encoding
This parameter give you control over the serialization of parts of multipart request bodies.
This attribute is only applicable to multipart and application/x-www-form-urlencoded request bodies.
Use New-PodeOAEncodingObject to define the encode

.PARAMETER DefinitionTag
An Array of strings representing the unique tag for the API specification.
This tag helps distinguish between different versions or types of API specifications within the application.
You can use this tag to reference the specific API documentation, schema, or version that your function interacts with.

.EXAMPLE
New-PodeOARequestBody -Content @{ 'application/json' = (New-PodeOAIntProperty -Name 'userId' -Object) }

.EXAMPLE
New-PodeOARequestBody -Content @{ 'application/json' = 'UserIdSchema' }

.EXAMPLE
New-PodeOARequestBody -Reference 'UserIdBody'

.EXAMPLE
New-PodeOARequestBody -Content @{'multipart/form-data' =
                    New-PodeOAStringProperty -name 'id' -format 'uuid' |
                        New-PodeOAObjectProperty -name 'address' -NoProperties |
                        New-PodeOAObjectProperty -name 'historyMetadata' -Description 'metadata in XML format' -NoProperties |
                        New-PodeOAStringProperty -name 'profileImage' -Format Binary |
                        New-PodeOAObjectProperty
                    } -Encoding (
                        New-PodeOAEncodingObject -Name 'historyMetadata' -ContentType 'application/xml; charset=utf-8' |
                            New-PodeOAEncodingObject -Name 'profileImage' -ContentType 'image/png, image/jpeg' -Headers (
                                New-PodeOAIntProperty -name 'X-Rate-Limit-Limit' -Description 'The number of allowed requests in the current period' -Default 3 -Enum @(1,2,3)
                            )
                        )
#>
function New-PodeOARequestBody {
    [CmdletBinding(DefaultParameterSetName = 'BuiltIn')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'Reference')]
        [string]
        $Reference,

        [Parameter(Mandatory = $true, ParameterSetName = 'BuiltIn')]
        [Alias('ContentSchemas')]
        [hashtable]
        $Content,

        [Parameter(ParameterSetName = 'BuiltIn')]
        [string]
        $Description,

        [Parameter(ParameterSetName = 'BuiltIn')]
        [switch]
        $Required,

        [Parameter(ParameterSetName = 'BuiltIn')]
        [switch]
        $Properties,

        [System.Collections.Specialized.OrderedDictionary]
        $Examples,

        [hashtable[]]
        $Encoding,

        [string[]]
        $DefinitionTag

    )

    $DefinitionTag = Test-PodeOADefinitionTag -Tag $DefinitionTag

    if ($Example -and $Examples) {
        throw 'Parameter -Examples and -Example are mutually exclusive'
    }
    $result = @{}
    foreach ($tag in $DefinitionTag) {
        switch ($PSCmdlet.ParameterSetName.ToLowerInvariant()) {
            'builtin' {
                $param = @{content = ConvertTo-PodeOAObjectSchema -DefinitionTag $tag -Content $Content -Properties:$Properties }

                if ($Required.IsPresent) {
                    $param['required'] = $Required.IsPresent
                }

                if ( $Description) {
                    $param['description'] = $Description
                }
                if ($Examples) {
                    if ( $Examples.'*/*') {
                        $Examples['"*/*"'] = $Examples['*/*']
                        $Examples.Remove('*/*')
                    }
                    foreach ($k in  $Examples.Keys ) {
                        if (!$param.content.ContainsKey($k)) {
                            $param.content[$k] = @{}
                        }
                        $param.content.$k.examples = $Examples.$k
                    }
                }
            }

            'reference' {
                Test-PodeOAComponent -Field requestBodies -DefinitionTag $tag -Name $Reference -PostValidation
                $param = @{
                    '$ref' = "#/components/requestBodies/$Reference"
                }
            }
        }
        if ($Encoding) {
            if (([string]$Content.keys[0]) -match '(?i)^(multipart.*|application\/x-www-form-urlencoded)$' ) {
                $r = @{}
                foreach ( $e in $Encoding) {
                    $key = [string]$e.Keys
                    $elems = @{}
                    foreach ($v in $e[$key].Keys) {
                        if ($v -ieq 'headers') {
                            $elems.headers = ConvertTo-PodeOAHeaderProperties -Headers $e[$key].headers
                        } else {
                            $elems.$v = $e[$key].$v
                        }
                    }
                    $r.$key = $elems
                }
                $param.Content.$($Content.keys[0]).encoding = $r
            } else {
                throw 'The encoding attribute is only applicable to multipart and application/x-www-form-urlencoded request bodies.'
            }
        }
        $result[$tag] = $param
    }

    return $result
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

.PARAMETER DefinitionTag
A string representing the unique tag for the API specification.
This tag helps distinguish between different versions or types of API specifications within the application.
You can use this tag to reference the specific API documentation, schema, or version that your function interacts with.

.OUTPUTS
result: true if the object is validate positively
message: any validation issue

.EXAMPLE
$UserInfo = Test-PodeOAJsonSchemaCompliance -Json $UserInfo -SchemaReference 'UserIdSchema'}

#>

function Test-PodeOAJsonSchemaCompliance {
    param (
        [Parameter(Mandatory = $true)]
        [String]
        $Json,

        [Parameter(Mandatory = $true)]
        [string]
        $SchemaReference,

        [string]
        $DefinitionTag
    )

    $DefinitionTag = Test-PodeOADefinitionTag -Tag $DefinitionTag

    if (!$PodeContext.Server.OpenAPI[$DefinitionTag].hiddenComponents.schemaValidation) {
        throw 'Test-PodeOAComponentchema need to be enabled using `Enable-PodeOpenApi -EnableSchemaValidation` '
    }
    if (!(Test-PodeOAComponentchemaJson -Name $SchemaReference)) {
        throw "The OpenApi component schema in Json doesn't exist: $SchemaReference"
    }

    [string[]] $message = @()
    $result = Test-Json -Json $Json -Schema $PodeContext.Server.OpenAPI[$DefinitionTag].hiddenComponents.schemaJson[$SchemaReference].json -ErrorVariable jsonValidationErrors -ErrorAction SilentlyContinue
    if ($jsonValidationErrors) {
        foreach ($item in $jsonValidationErrors) {
            $message += $item
        }
    }

    return @{result = $result; message = $message }
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

.PARAMETER Reference
The name of an existing component parameter to be reused.
Alias: ComponentParameter

.PARAMETER Name
Assign a name to the parameter

.PARAMETER ContentType
The content-types to be use with  component schema

.PARAMETER Schema
The component schema to use.

.PARAMETER Description
A Description of the property.

.PARAMETER Explode
If supplied, controls how arrays are serialized in query parameters

.PARAMETER AllowReserved
If supplied, determines whether the parameter value SHOULD allow reserved characters, as defined by RFC3986 :/?#[]@!$&'()*+,;= to be included without percent-encoding.
This property only applies to parameters with an in value of query. The default value is false.

.PARAMETER Required
If supplied, the object will be treated as Required where supported.(Applicable only to ContentSchema)

.PARAMETER AllowEmptyValue
If supplied, allow the parameter to be empty

.PARAMETER Style
If supplied, defines how multiple values are delimited. Possible styles depend on the parameter location: path, query, header or cookie.

.PARAMETER Deprecated
If supplied, specifies that a parameter is deprecated and SHOULD be transitioned out of usage. Default value is false.

.PARAMETER Example
Example of the parameter's potential value. The example SHOULD match the specified schema and encoding properties if present.
The Example parameter is mutually exclusive of the Examples parameter.
Furthermore, if referencing a Schema  that contains an example, the Example value SHALL _override_ the example provided by the schema.
To represent examples of media types that cannot naturally be represented in JSON or YAML, a string value can contain the example with escaping where necessary.

.PARAMETER Examples
Examples of the parameter's potential value. Each example SHOULD contain a value in the correct format as specified in the parameter encoding.
The Examples parameter is mutually exclusive of the Example parameter.
Furthermore, if referencing a Schema that contains an example, the Examples value SHALL _override_ the example provided by the schema.

.PARAMETER DefinitionTag
An Array of strings representing the unique tag for the API specification.
This tag helps distinguish between different versions or types of API specifications within the application.
You can use this tag to reference the specific API documentation, schema, or version that your function interacts with.

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
        [Parameter( Mandatory = $true, ParameterSetName = 'Schema')]
        [Parameter(Mandatory = $true, ParameterSetName = 'Properties')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ContentSchema')]
        [Parameter( Mandatory = $true, ParameterSetName = 'ContentProperties')]
        [ValidateSet('Cookie', 'Header', 'Path', 'Query')]
        [string]
        $In,

        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = 'Properties')]
        [Parameter( Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = 'ContentProperties')]
        [ValidateNotNull()]
        [hashtable]
        $Property,

        [Parameter(Mandatory = $true, ParameterSetName = 'Reference')]
        [Alias('ComponentParameter')]
        [string]
        $Reference,

        [Parameter( ParameterSetName = 'Schema')]
        [Parameter(ParameterSetName = 'Properties')]
        [Parameter(ParameterSetName = 'ContentSchema')]
        [Parameter(  ParameterSetName = 'ContentProperties')]
        [string]
        $Name,

        [Parameter(Mandatory = $true, ParameterSetName = 'Schema')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ContentSchema')]
        [Alias('ComponentSchema')]
        [String]
        $Schema,

        [Parameter( Mandatory = $true, ParameterSetName = 'ContentSchema')]
        [Parameter( Mandatory = $true, ParameterSetName = 'ContentProperties')]
        [String]
        $ContentType,

        [Parameter( ParameterSetName = 'Schema')]
        [Parameter( ParameterSetName = 'ContentSchema')]
        [Parameter( ParameterSetName = 'Properties')]
        [Parameter( ParameterSetName = 'ContentProperties')]
        [String]
        $Description,

        [Parameter( ParameterSetName = 'Schema')]
        [Parameter( ParameterSetName = 'Properties')]
        [Switch]
        $Explode,

        [Parameter( ParameterSetName = 'Schema')]
        [Parameter( ParameterSetName = 'ContentSchema')]
        [Parameter( ParameterSetName = 'Properties')]
        [Parameter( ParameterSetName = 'ContentProperties')]
        [Switch]
        $Required,

        [Parameter( ParameterSetName = 'ContentSchema')]
        [Parameter( ParameterSetName = 'Schema')]
        [Parameter( ParameterSetName = 'Properties')]
        [Switch]
        $AllowEmptyValue,

        [Parameter( ParameterSetName = 'Schema')]
        [Parameter( ParameterSetName = 'Properties')]
        [Switch]
        $AllowReserved,

        [Parameter( ParameterSetName = 'Schema')]
        [Parameter( ParameterSetName = 'ContentSchema')]
        [Parameter( ParameterSetName = 'Properties')]
        [Parameter( ParameterSetName = 'ContentProperties')]
        [object]
        $Example,

        [Parameter( ParameterSetName = 'Schema')]
        [Parameter( ParameterSetName = 'ContentSchema')]
        [Parameter( ParameterSetName = 'Properties')]
        [Parameter( ParameterSetName = 'ContentProperties')]
        [System.Collections.Specialized.OrderedDictionary]
        $Examples,

        [Parameter( ParameterSetName = 'Schema')]
        [Parameter( ParameterSetName = 'Properties')]
        [ValidateSet('Simple', 'Label', 'Matrix', 'Query', 'Form', 'SpaceDelimited', 'PipeDelimited', 'DeepObject' )]
        [string]
        $Style,

        [Parameter( ParameterSetName = 'Schema')]
        [Parameter( ParameterSetName = 'ContentSchema')]
        [Parameter( ParameterSetName = 'Properties')]
        [Parameter( ParameterSetName = 'ContentProperties')]
        [Switch]
        $Deprecated,

        [string[]]
        $DefinitionTag
    )
    $DefinitionTag = Test-PodeOADefinitionTag -Tag $DefinitionTag

    if ($PSCmdlet.ParameterSetName -ieq 'ContentSchema' -or $PSCmdlet.ParameterSetName -ieq 'Schema') {
        if (Test-PodeIsEmpty $Schema) {
            return $null
        }
        Test-PodeOAComponent -Field schemas -DefinitionTag $DefinitionTag -Name $Schema -PostValidation
        if (!$Name ) {
            $Name = $Schema
        }
        $prop = [ordered]@{
            in   = $In.ToLowerInvariant()
            name = $Name
        }
        if ($In -ieq 'Header' -and $PodeContext.Server.Security.autoHeaders) {
            Add-PodeSecurityHeader -Name 'Access-Control-Allow-Headers' -Value $Schema  -Append
        }
        if ($AllowEmptyValue.IsPresent ) {
            $prop['allowEmptyValue'] = $AllowEmptyValue.IsPresent
        }
        if ($Required.IsPresent ) {
            $prop['required'] = $Required.IsPresent
        }
        if ($Description ) {
            $prop.description = $Description
        }
        if ($Deprecated.IsPresent ) {
            $prop.deprecated = $Deprecated.IsPresent
        }
        if ($ContentType ) {
            # ensure all content types are valid
            if ($ContentType -inotmatch '^[\w-]+\/[\w\.\+-]+$') {
                throw "Invalid content-type found for schema: $($type)"
            }
            $prop.content = [ordered]@{
                $ContentType = [ordered]@{
                    schema = [ordered]@{
                        '$ref' = "#/components/schemas/$($Schema )"
                    }
                }
            }
            if ($Example ) {
                $prop.content.$ContentType.example = $Example
            } elseif ($Examples) {
                $prop.content.$ContentType.examples = $Examples
            }
        } else {
            $prop.schema = [ordered]@{
                '$ref' = "#/components/schemas/$($Schema )"
            }
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
                $prop['explode'] = $Explode.IsPresent
            }

            if ($AllowEmptyValue.IsPresent ) {
                $prop['allowEmptyValue'] = $AllowEmptyValue.IsPresent
            }

            if ($AllowReserved.IsPresent) {
                $prop['allowReserved'] = $AllowReserved.IsPresent
            }

        }
    } elseif ($PSCmdlet.ParameterSetName -ieq 'Reference') {
        # return a reference
        Test-PodeOAComponent -Field parameters  -DefinitionTag $DefinitionTag  -Name $Reference -PostValidation
        $prop = [ordered]@{
            '$ref' = "#/components/parameters/$Reference"
        }
        foreach ($tag in $DefinitionTag) {
            if ($PodeContext.Server.OpenAPI[$tag].components.parameters.$Reference.In -eq 'Header' -and $PodeContext.Server.Security.autoHeaders) {
                Add-PodeSecurityHeader -Name 'Access-Control-Allow-Headers' -Value $Reference -Append
            }
        }
    } else {

        if (!$Name ) {
            if ($Property.name) {
                $Name = $Property.name
            } else {
                throw 'Parameter requires a Name'
            }
        }
        if ($In -ieq 'Header' -and $PodeContext.Server.Security.autoHeaders -and $Name ) {
            Add-PodeSecurityHeader -Name 'Access-Control-Allow-Headers' -Value  $Name  -Append
        }

        # build the base parameter
        $prop = [ordered]@{
            in   = $In.ToLowerInvariant()
            name = $Name
        }
        $sch = [ordered]@{}
        if ($Property.array) {
            $sch.type = 'array'
            $sch.items = [ordered]@{
                type = $Property.type
            }
            if ($Property.format) {
                $sch.items.format = $Property.format
            }
        } else {
            $sch.type = $Property.type
            if ($Property.format) {
                $sch.format = $Property.format
            }
        }
        if ($ContentType) {
            if ($ContentType -inotmatch '^[\w-]+\/[\w\.\+-]+$') {
                throw "Invalid content-type found for schema: $($type)"
            }
            $prop.content = [ordered]@{
                $ContentType = [ordered] @{
                    schema = $sch
                }
            }
        } else {
            $prop.schema = $sch
        }

        if ($Example -and $Examples) {
            throw '-Example and -Examples are mutually exclusive'
        }
        if ($AllowEmptyValue.IsPresent ) {
            $prop['allowEmptyValue'] = $AllowEmptyValue.IsPresent
        }

        if ($Description ) {
            $prop.description = $Description
        } elseif ($Property.description) {
            $prop.description = $Property.description
        }

        if ($Required.IsPresent ) {
            $prop.required = $Required.IsPresent
        } elseif ($Property.required) {
            $prop.required = $Property.required
        }

        if ($Deprecated.IsPresent ) {
            $prop.deprecated = $Deprecated.IsPresent
        } elseif ($Property.deprecated) {
            $prop.deprecated = $Property.deprecated
        }


        if (!$ContentType) {
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
                $prop['explode'] = $Explode.IsPresent
            }

            if ($AllowReserved.IsPresent) {
                $prop['allowReserved'] = $AllowReserved.IsPresent
            }

            if ($Example ) {
                $prop['example'] = $Example
            } elseif ($Examples) {
                $prop['examples'] = $Examples
            }

            if ($Property.default -and !$prop.required ) {
                $prop.schema['default'] = $Property.default
            }

            if ($Property.enum) {
                if ($Property.array) {
                    $prop.schema.items['enum'] = $Property.enum
                } else {
                    $prop.schema['enum'] = $Property.enum
                }
            }
        } else {
            if ($Example ) {
                $prop.content.$ContentType.example = $Example
            } elseif ($Examples) {
                $prop.content.$ContentType.examples = $Examples
            }
        }
    }

    if ($In -ieq 'Path' -and !$prop.required ) {
        Throw "If the parameter location is 'Path', the switch parameter `-Required` is required"
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

.PARAMETER ExternalDoc
If supplied, add an additional external documentation for this operation.
The parameter is created by Add-PodeOAExternalDoc

.PARAMETER OperationId
Sets the OperationId of the route.

.PARAMETER Tags
An array of Tags for the route, mostly for grouping.

.PARAMETER Deprecated
If supplied, the route will be flagged as deprecated.

.PARAMETER PassThru
If supplied, the route passed in will be returned for further chaining.

.PARAMETER DefinitionTag
An Array of strings representing the unique tag for the API specification.
This tag helps distinguish between different versions or types of API specifications within the application.
You can use this tag to reference the specific API documentation, schema, or version that your function interacts with.

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

        [string]
        $Summary,

        [string]
        $Description,

        [System.Collections.Specialized.OrderedDictionary]
        $ExternalDoc,

        [string]
        $OperationId,

        [string[]]
        $Tags,

        [switch]
        $Deprecated,

        [switch]
        $PassThru,

        [string[]]
        $DefinitionTag
    )

    $DefinitionTag = Test-PodeOADefinitionTag -Tag $DefinitionTag
    foreach ($r in @($Route)) {

        $r.OpenApi.DefinitionTag = $DefinitionTag

        if ($Summary) {
            $r.OpenApi.Summary = $Summary
        }
        if ($Description) {
            $r.OpenApi.Description = $Description
        }
        if ($OperationId) {
            foreach ($tag in $DefinitionTag) {
                if ($PodeContext.Server.OpenAPI[$tag].hiddenComponents.operationId -ccontains $OperationId) {
                    throw "OperationID:$OperationId has to be unique"
                }
                $PodeContext.Server.OpenAPI[$tag].hiddenComponents.operationId += $OperationId
            }
            $r.OpenApi.OperationId = $OperationId
        }
        if ($Tags) {
            $r.OpenApi.Tags = $Tags
        }

        if ($ExternalDocs) {
            $r.OpenApi.ExternalDocs = $ExternalDoc
        }

        $r.OpenApi.Swagger = $true
        if ($Deprecated.IsPresent) {
            $r.OpenApi.Deprecated = $Deprecated.IsPresent
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

.PARAMETER EndpointName
The EndpointName of an Endpoint(s) to bind the static Route against.

.PARAMETER Bookmarks
If supplied, create a new documentation bookmarks page

.PARAMETER NoAdvertise
If supplied, it is not going to state the documentation URL at the startup of the server

.PARAMETER DefinitionTag
A string representing the unique tag for the API specification.
This tag helps distinguish between different versions or types of API specifications within the application.
You can use this tag to reference the specific API documentation, schema, or version that your function interacts with.

.EXAMPLE
Enable-PodeOAViewer -Type Swagger -DarkMode

.EXAMPLE
Enable-PodeOAViewer -Type ReDoc -Title 'Some Title' -OpenApi 'http://some-url/openapi'

.EXAMPLE
Enable-PodeOAViewer -Bookmarks

Adds a route that enables a viewer to display with links to any documentation tool associated with the OpenApi.
#>
function Enable-PodeOAViewer {
    [CmdletBinding(DefaultParameterSetName = 'Doc')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'Doc')]
        [ValidateSet('Swagger', 'ReDoc', 'RapiDoc', 'StopLight', 'Explorer', 'RapiPdf' )]
        [string]
        $Type,

        [string]
        $Path,

        [string]
        $OpenApiUrl,

        [object[]]
        $Middleware,

        [string]
        $Title,

        [switch]
        $DarkMode,

        [string[]]
        $EndpointName,

        [Parameter(Mandatory = $true, ParameterSetName = 'Bookmarks')]
        [switch]
        $Bookmarks,

        [Parameter( ParameterSetName = 'Bookmarks')]
        [switch]
        $NoAdvertise,

        [string]
        $DefinitionTag
    )
    $DefinitionTag = Test-PodeOADefinitionTag -Tag $DefinitionTag
    # error if there's no OpenAPI URL
    $OpenApiUrl = Protect-PodeValue -Value $OpenApiUrl -Default $PodeContext.Server.OpenAPI[$DefinitionTag].Path
    if ([string]::IsNullOrWhiteSpace($OpenApiUrl)) {
        throw "No OpenAPI URL supplied for $($Type)"
    }

    # fail if no title
    $Title = Protect-PodeValue -Value $Title -Default $PodeContext.Server.OpenAPI[$DefinitionTag].info.Title
    if ([string]::IsNullOrWhiteSpace($Title)) {
        throw "No title supplied for $($Type) page"
    }

    # set a default path
    $Path = Protect-PodeValue -Value $Path -Default "/$($Type.ToLowerInvariant())"
    if ([string]::IsNullOrWhiteSpace($Title)) {
        throw "No route path supplied for $($Type) page"
    }

    if ($Bookmarks.IsPresent) {
        # setup meta info
        $meta = @{
            Type          = $Type.ToLowerInvariant()
            Title         = $Title
            OpenApi       = $OpenApiUrl
            DarkMode      = $DarkMode
            DefinitionTag = $DefinitionTag
        }

        $route = Add-PodeRoute -Method Get -Path $Path `
            -Middleware $Middleware -ArgumentList $meta -EndpointName $EndpointName -PassThru -ScriptBlock {
            param($meta)
            $Data = @{
                Title   = $meta.Title
                OpenApi = $meta.OpenApi
            }
            $DefinitionTag = $meta.DefinitionTag
            foreach ($type in $PodeContext.Server.OpenAPI[$DefinitionTag].hiddenComponents.viewer.Keys) {
                $Data[$type] = $true
                $Data["$($type)_path"] = $PodeContext.Server.OpenAPI[$DefinitionTag].hiddenComponents.viewer[$type]
            }

            $podeRoot = Get-PodeModuleMiscPath
            Write-PodeFileResponse -Path ([System.IO.Path]::Combine($podeRoot, 'default-doc-bookmarks.html.pode')) -Data $Data
        }
        if (! $NoAdvertise.IsPresent) {
            $PodeContext.Server.OpenAPI[$DefinitionTag].hiddenComponents.bookmarks = @{
                path       = $Path
                route      = @()
                openApiUrl = $OpenApiUrl
            }
            $PodeContext.Server.OpenAPI[$DefinitionTag].hiddenComponents.bookmarks.route += $route
        }

    } else {
        if ($Type -ieq 'RapiPdf' -and (Test-OpenAPIVersion -Version 3.1 -DefinitionTag $DefinitionTag)) {
            throw "The Document tool RapidPdf doesn't support OpenAPI 3.1"
        }
        # setup meta info
        $meta = @{
            Type     = $Type.ToLowerInvariant()
            Title    = $Title
            OpenApi  = $OpenApiUrl
            DarkMode = $DarkMode
        }
        $PodeContext.Server.OpenAPI[$DefinitionTag].hiddenComponents.viewer[$($meta.Type)] = $Path
        # add the viewer route
        Add-PodeRoute -Method Get -Path $Path -Middleware $Middleware -ArgumentList $meta -EndpointName $EndpointName -ScriptBlock {
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


.PARAMETER url
The link to the external documentation

.PARAMETER Description
A Description of the external documentation.

.EXAMPLE
$swaggerDoc = New-PodeOAExternalDoc  -Description 'Find out more about Swagger' -Url 'http://swagger.io'

Add-PodeRoute -PassThru | Set-PodeOARouteInfo -Summary 'A quick summary' -Tags 'Admin' -ExternalDoc $swaggerDoc

.EXAMPLE
$swaggerDoc = New-PodeOAExternalDoc    -Description 'Find out more about Swagger' -Url 'http://swagger.io'
Add-PodeOATag -Name 'user' -Description 'Operations about user' -ExternalDoc $swaggerDoc
#>
function New-PodeOAExternalDoc {
    param(

        [Parameter(Mandatory = $true)]
        [ValidateScript({ $_ -imatch '^https?://.+' })]
        $Url,

        [string]
        $Description
    )
    $param = [ordered]@{}

    if ($Description) {
        $param.description = $Description
    }
    $param['url'] = $Url
    return $param
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

.PARAMETER ExternalDoc
An externalDoc object


.PARAMETER Name
The Name of the reference.

.PARAMETER url
The link to the external documentation

.PARAMETER Description
A Description of the external documentation.

.PARAMETER DefinitionTag
An Array of strings representing the unique tag for the API specification.
This tag helps distinguish between different versions or types of API specifications within the application.
You can use this tag to reference the specific API documentation, schema, or version that your function interacts with.

.EXAMPLE
Add-PodeOAExternalDoc  -Name 'SwaggerDocs' -Description 'Find out more about Swagger' -Url 'http://swagger.io'

.EXAMPLE
$ExtDoc = New-PodeOAExternalDoc  -Name 'SwaggerDocs' -Description 'Find out more about Swagger' -Url 'http://swagger.io'
$ExtDoc|Add-PodeOAExternalDoc
#>
function Add-PodeOAExternalDoc {
    [CmdletBinding(DefaultParameterSetName = 'Pipe')]
    param(
        [Parameter(ValueFromPipeline = $true, DontShow = $true, ParameterSetName = 'Pipe')]
        [System.Collections.Specialized.OrderedDictionary ]
        $ExternalDoc,

        [Parameter(Mandatory = $true, ParameterSetName = 'NewRef')]
        [ValidateScript({ $_ -imatch '^https?://.+' })]
        $Url,

        [Parameter(ParameterSetName = 'NewRef')]
        [string]
        $Description,

        [string[]]
        $DefinitionTag
    )
    $DefinitionTag = Test-PodeOADefinitionTag -Tag $DefinitionTag
    foreach ($tag in $DefinitionTag) {
        if ($PSCmdlet.ParameterSetName -ieq 'NewRef') {
            $param = [ordered]@{url = $Url }
            if ($Description) {
                $param.description = $Description
            }
            $PodeContext.Server.OpenAPI[$tag].externalDocs = $param
        } else {
            $PodeContext.Server.OpenAPI[$tag].externalDocs = $ExternalDoc
        }
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
If supplied, the tag references an existing external documentation reference.
The parameter is created by Add-PodeOAExternalDoc

.PARAMETER DefinitionTag
An Array of strings representing the unique tag for the API specification.
This tag helps distinguish between different versions or types of API specifications within the application.
You can use this tag to reference the specific API documentation, schema, or version that your function interacts with.

.EXAMPLE
Add-PodeOATag -Name 'store' -Description 'Access to Petstore orders' -ExternalDoc 'SwaggerDocs'
#>
function Add-PodeOATag {
    param(
        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[a-zA-Z0-9\.\-_]+$')]
        [string]
        $Name,

        [string]
        $Description,

        [System.Collections.Specialized.OrderedDictionary]
        $ExternalDoc,

        [string[]]
        $DefinitionTag
    )

    $DefinitionTag = Test-PodeOADefinitionTag -Tag $DefinitionTag

    foreach ($tag in $DefinitionTag) {
        $param = [ordered]@{
            'name' = $Name
        }

        if ($Description) {
            $param.description = $Description
        }

        if ($ExternalDoc) {
            $param.externalDocs = $ExternalDoc
        }

        $PodeContext.Server.OpenAPI[$tag].tags[$Name] = $param
    }
}


<#
.SYNOPSIS
Creates an OpenAPI metadata.

.DESCRIPTION
Creates an OpenAPI metadata like TermOfService, license and so on.
The metadata MAY be used by the clients if needed, and MAY be presented in editing or documentation generation tools for convenience.

.LINK
https://swagger.io/docs/specification/api-general-info/

.LINK
https://github.com/OAI/OpenAPI-Specification/blob/main/versions/3.0.3.md#infoObject

.PARAMETER Title
The Title of the API.

.PARAMETER Version
The Version of the API.
The OpenAPI Specification is versioned using Semantic Versioning 2.0.0 (semver) and follows the semver specification.
https://semver.org/spec/v2.0.0.html

.PARAMETER Description
A short description of the API.
CommonMark syntax MAY be used for rich text representation.
https://spec.commonmark.org/

.PARAMETER TermsOfService
A URL to the Terms of Service for the API. MUST be in the format of a URL.

.PARAMETER LicenseName
The license name used for the API.

.PARAMETER LicenseUrl
A URL to the license used for the API. MUST be in the format of a URL.

.PARAMETER ContactName
The identifying name of the contact person/organization.

.PARAMETER ContactEmail
The email address of the contact person/organization. MUST be in the format of an email address.

.PARAMETER ContactUrl
The URL pointing to the contact information. MUST be in the format of a URL.

.PARAMETER DefinitionTag
A string representing the unique tag for the API specification.
This tag helps distinguish between different versions or types of API specifications within the application.
You can use this tag to reference the specific API documentation, schema, or version that your function interacts with.

.EXAMPLE
Add-PodeOAInfo -TermsOfService 'http://swagger.io/terms/' -License 'Apache 2.0' -LicenseUrl 'http://www.apache.org/licenses/LICENSE-2.0.html' -ContactName 'API Support' -ContactEmail 'apiteam@swagger.io' -ContactUrl 'http://example.com/support'
#>

function Add-PodeOAInfo {
    param(
        [string]
        $Title,

        [ValidatePattern('^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$')]
        [string]
        $Version ,

        [string]
        $Description,

        [ValidateScript({ $_ -imatch '^https?://.+' })]
        [string]
        $TermsOfService,

        [string]
        $LicenseName,

        [ValidateScript({ $_ -imatch '^https?://.+' })]
        [string]
        $LicenseUrl,

        [string]
        $ContactName,

        [ValidateScript({ $_ -imatch '^\w+([-+.]\w+)*@\w+([-.]\w+)*\.\w+([-.]\w+)*$' })]
        [string]
        $ContactEmail,

        [ValidateScript({ $_ -imatch '^https?://.+' })]
        [string]
        $ContactUrl,

        [string]
        $DefinitionTag
    )

    $DefinitionTag = Test-PodeOADefinitionTag -Tag $DefinitionTag

    $Info = [ordered]@{}

    if ($LicenseName) {
        $Info.license = [ordered]@{
            'name' = $LicenseName
        }
    }
    if ($LicenseUrl) {
        if ( $Info.license ) {
            $Info.license.url = $LicenseUrl
        } else {
            throw 'The OpenAPI property license.name is required. Use -LicenseName'
        }
    }


    if ($Title) {
        $Info.title = $Title
    } elseif (  $PodeContext.Server.OpenAPI[$DefinitionTag].info.title) {
        $Info.title = $PodeContext.Server.OpenAPI[$DefinitionTag].info.title
    } else {
        throw 'The OpenAPI property info.title is required. Use -Title'
    }

    if ($Version) {
        $Info.version = $Version
    } elseif ( $PodeContext.Server.OpenAPI[$DefinitionTag].info.version) {
        $Info.version = $PodeContext.Server.OpenAPI[$DefinitionTag].info.version
    } else {
        $Info.version = '1.0.0'
    }

    if ($Description ) {
        $Info.description = $Description
    } elseif ( $PodeContext.Server.OpenAPI[$DefinitionTag].info.description) {
        $Info.description = $PodeContext.Server.OpenAPI[$DefinitionTag].info.description
    }

    if ($TermsOfService) {
        $Info['termsOfService'] = $TermsOfService
    }

    if ($ContactName -or $ContactEmail -or $ContactUrl ) {
        $Info['contact'] = [ordered]@{}

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
    $PodeContext.Server.OpenAPI[$DefinitionTag].info = $Info

}


<#
.SYNOPSIS
Creates a new OpenAPI example.

.DESCRIPTION
Creates a new OpenAPI example.

.PARAMETER ParamsList
Used to pipeline multiple properties

.PARAMETER MediaType
The Media Type associated with the Example.

.PARAMETER Name
The Name of the Example.

.PARAMETER Summary
Short description for the example


.PARAMETER Description
Long description for the example.

.PARAMETER Reference
A reference to a reusable component example

.PARAMETER Value
Embedded literal example. The  value Parameter and ExternalValue parameter are mutually exclusive.
To represent examples of media types that cannot naturally represented in JSON or YAML, use a string value to contain the example, escaping where necessary.

.PARAMETER ExternalValue
A URL that points to the literal example. This provides the capability to reference examples that cannot easily be included in JSON or YAML documents.
The -Value parameter and -ExternalValue parameter are mutually exclusive.                                |

.PARAMETER DefinitionTag
An Array of strings representing the unique tag for the API specification.
This tag helps distinguish between different versions or types of API specifications within the application.
You can use this tag to reference the specific API documentation, schema, or version that your function interacts with.

.EXAMPLE
New-PodeOAExample -ContentMediaType 'text/plain' -Name 'user' -Summary = 'User Example in Plain text' -ExternalValue = 'http://foo.bar/examples/user-example.txt'
.EXAMPLE
$example =
    New-PodeOAExample -ContentMediaType 'application/json' -Name 'user' -Summary = 'User Example' -ExternalValue = 'http://foo.bar/examples/user-example.json'  |
        New-PodeOAExample -ContentMediaType 'application/xml' -Name 'user' -Summary = 'User Example in XML' -ExternalValue = 'http://foo.bar/examples/user-example.xml'

#>
function New-PodeOAExample {
    [CmdletBinding(DefaultParameterSetName = 'Inbuilt')]
    [OutputType([System.Collections.Specialized.OrderedDictionary ])]

    param(
        [Parameter(ValueFromPipeline = $true, DontShow = $true, ParameterSetName = 'Inbuilt')]
        [Parameter(ValueFromPipeline = $true, DontShow = $true, ParameterSetName = 'Reference')]
        [System.Collections.Specialized.OrderedDictionary ]
        $ParamsList,

        [string]
        $MediaType,

        [Parameter(Mandatory = $true, ParameterSetName = 'Inbuilt')]
        [ValidatePattern('^[a-zA-Z0-9\.\-_]+$')]
        [string]
        $Name,

        [Parameter( ParameterSetName = 'Inbuilt')]
        [string]
        $Summary,

        [Parameter( ParameterSetName = 'Inbuilt')]
        [string]
        $Description,

        [Parameter(  ParameterSetName = 'Inbuilt')]
        [object]
        $Value,

        [Parameter(  ParameterSetName = 'Inbuilt')]
        [string]
        $ExternalValue,

        [Parameter(Mandatory = $true, ParameterSetName = 'Reference')]
        [ValidatePattern('^[a-zA-Z0-9\.\-_]+$')]
        [string]
        $Reference,

        [string[]]
        $DefinitionTag
    )
    begin {

        if (Test-PodeIsEmpty -Value $DefinitionTag) {
            $DefinitionTag = $PodeContext.Server.SelectedOADefinitionTag
        }

        if ($PSCmdlet.ParameterSetName -ieq 'Reference') {
            Test-PodeOAComponent -Field examples -DefinitionTag $DefinitionTag -Name $Reference -PostValidation
            $Name = $Reference
            $Example = [ordered]@{'$ref' = "#/components/examples/$Reference" }
        } else {
            if ( $ExternalValue -and $Value) {
                throw '-Value or -ExternalValue are mutually exclusive'
            }
            $Example = [ordered]@{ }
            if ($Summary) {
                $Example.summary = $Summary
            }
            if ($Description) {
                $Example.description = $Description
            }
            if ($Value) {
                $Example.value = $Value
            } elseif ($ExternalValue) {
                $Example.externalValue = $ExternalValue
            } else {
                throw '-Value or -ExternalValue are mandatory'
            }
        }
        $param = [ordered]@{}
        if ($MediaType) {
            $param.$MediaType = [ordered]@{
                $Name = $Example
            }
        } else {
            $param.$Name = $Example
        }
    }
    process {
    }
    end {
        if ($ParamsList) {
            if ($ParamsList.keys -contains $param.Keys[0]) {
                $param.Values[0].GetEnumerator() | ForEach-Object { $ParamsList[$param.Keys[0]].$($_.Key) = $_.Value }
            } else {
                $param.GetEnumerator() | ForEach-Object { $ParamsList[$_.Key] = $_.Value }
            }
            return $ParamsList
        } else {
            return [System.Collections.Specialized.OrderedDictionary] $param
        }
    }
}

<#
.SYNOPSIS
Adds a single encoding definition applied to a single schema property.

.DESCRIPTION
A single encoding definition applied to a single schema property.

.PARAMETER EncodingList
Used by pipe

.PARAMETER Title
The Name of the associated encoded property .

.PARAMETER ContentType
Content-Type for encoding a specific property. Default value depends on the property type: for `string` with `format` being `binary` – `application/octet-stream`;
for other primitive types – `text/plain`; for `object` - `application/json`; for `array` – the default is defined based on the inner type.
The value can be a specific media type (e.g. `application/json`), a wildcard media type (e.g. `image/*`), or a comma-separated list of the two types.

.PARAMETER Headers
A map allowing additional information to be provided as headers, for example `Content-Disposition`.
`Content-Type` is described separately and SHALL be ignored in this section.
This property SHALL be ignored if the request body media type is not a `multipart`.

.PARAMETER Style
Describes how a specific property value will be serialized depending on its type.  See [Parameter Object](#parameterObject) for details on the [`style`](#parameterStyle) property.
The behavior follows the same values as `query` parameters, including default values.
This property SHALL be ignored if the request body media type is not `application/x-www-form-urlencoded`.

.PARAMETER Explode
When enabled, property values of type `array` or `object` generate separate parameters for each value of the array, or key-value-pair of the map.  For other types of properties this property has no effect.
When [`style`](#encodingStyle) is `form`, the `Explode` is set to `true`.
This property SHALL be ignored if the request body media type is not `application/x-www-form-urlencoded`.

.PARAMETER AllowReserved
Determines whether the parameter value SHOULD allow reserved characters, as defined by [RFC3986](https://tools.ietf.org/html/rfc3986#section-2.2) `:/?#[]@!$&'()*+,;=` to be included without percent-encoding.
This property SHALL be ignored if the request body media type is not `application/x-www-form-urlencoded`.

.EXAMPLE

New-PodeOAEncodingObject -Name 'profileImage' -ContentType 'image/png, image/jpeg' -Headers (
                                New-PodeOAIntProperty -name 'X-Rate-Limit-Limit' -Description 'The number of allowed requests in the current period' -Default 3 -Enum @(1,2,3) -Maximum 3
                            )
#>
function New-PodeOAEncodingObject {
    param (
        [Parameter(ValueFromPipeline = $true, DontShow = $true )]
        [hashtable[]]
        $EncodingList,

        [Parameter(Mandatory = $true)]
        [Alias('Name')]
        [ValidatePattern('^[a-zA-Z0-9\.\-_]+$')]
        [string]
        $Title,

        [string]
        $ContentType,

        [hashtable[]]
        $Headers,

        [ValidateSet('Simple', 'Label', 'Matrix', 'Query', 'Form', 'SpaceDelimited', 'PipeDelimited', 'DeepObject' )]
        [string]
        $Style,

        [switch]
        $Explode,

        [switch]
        $AllowReserved
    )
    begin {

        $encoding = [ordered]@{
            $Title = [ordered]@{}
        }
        if ($ContentType) {
            $encoding.$Title.contentType = $ContentType
        }
        if ($Style) {
            $encoding.$Title.style = $Style
        }

        if ($Headers) {
            $encoding.$Title.headers = $Headers
        }

        if ($Explode.IsPresent ) {
            $encoding.$Title.explode = $Explode.IsPresent
        }
        if ($AllowReserved.IsPresent ) {
            $encoding.$Title.allowReserved = $AllowReserved.IsPresent
        }

        $collectedInput = [System.Collections.Generic.List[hashtable]]::new()
    }
    process {
        if ($EncodingList) {
            $collectedInput.AddRange($EncodingList)
        }
    }

    end {
        if ($collectedInput) {
            return $collectedInput + $encoding
        } else {
            return $encoding
        }
    }
}


<#
.SYNOPSIS
Adds OpenAPI callback configurations to routes in a Pode web application.

.PARAMETER Route
The route to update info, usually from -PassThru on Add-PodeRoute.

.DESCRIPTION
The Add-PodeOACallBack function is used for defining OpenAPI callback configurations for routes in a Pode server.
It enables setting up API specifications including detailed parameters, request body schemas, and response structures for various HTTP methods.

.PARAMETER Path
Specifies the callback path, usually a relative URL.
The key that identifies the Path Item Object is a runtime expression evaluated in the context of a runtime HTTP request/response to identify the URL for the callback request.
A simple example is `$request.body#/url`.
The runtime expression allows complete access to the HTTP message, including any part of a body that a JSON Pointer (RFC6901) can reference.
More information on JSON Pointer can be found at [RFC6901](https://datatracker.ietf.org/doc/html/rfc6901).

.PARAMETER Name
Alias for 'Name'. A unique identifier for the callback.
It must be a valid string of alphanumeric characters, periods (.), hyphens (-), and underscores (_).

.PARAMETER Reference
A reference to a reusable CallBack component.

.PARAMETER Method
Defines the HTTP method for the callback (e.g., GET, POST, PUT). Supports standard HTTP methods and a wildcard (*) for all methods.

.PARAMETER Parameters
The Parameter definitions the request uses (from ConvertTo-PodeOAParameter).

.PARAMETER RequestBody
Defines the schema of the request body. Can be set using New-PodeOARequestBody.

.PARAMETER Responses
Defines the possible responses for the callback. Can be set using New-PodeOAResponse.

.PARAMETER DefinitionTag
A array of string representing the unique tag for the API specification.
This tag helps distinguish between different versions or types of API specifications within the application.
You can use this tag to reference the specific API documentation, schema, or version that your function interacts with.

.PARAMETER PassThru
If supplied, the route passed in will be returned for further chaining.

.EXAMPLE
    Add-PodeOACallBack -Title 'test' -Path '{$request.body#/id}' -Method Post `
        -RequestBody (New-PodeOARequestBody -Content @{'*/*' = (New-PodeOAStringProperty -Name 'id')}) `
        -Response (
            New-PodeOAResponse -StatusCode 200 -Description 'Successful operation'  -Content (New-PodeOAContentMediaType -ContentMediaType 'application/json','application/xml' -Content 'Pet'  -Array)
            New-PodeOAResponse -StatusCode 400 -Description 'Invalid ID supplied' |
            New-PodeOAResponse -StatusCode 404 -Description 'Pet not found' |
            New-PodeOAResponse -Default -Description 'Something is wrong'
        )
    This example demonstrates adding a POST callback to handle a request body and define various responses based on different status codes.

.NOTES
    Ensure that the provided parameters match the expected schema and formats of Pode and OpenAPI specifications.
    The function is useful for dynamically configuring and documenting API callbacks in a Pode server environment.
#>

function Add-PodeOACallBack {
    [CmdletBinding(DefaultParameterSetName = 'inbuilt')]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [hashtable[]]
        $Route,

        [Parameter(Mandatory = $true , ParameterSetName = 'inbuilt')]
        [Parameter(Mandatory = $false, ParameterSetName = 'Reference')]
        [ValidatePattern('^[a-zA-Z0-9\.\-_]+$')]
        [string]
        $Name,

        [Parameter(Mandatory = $true, ParameterSetName = 'Reference')]
        [string]
        $Reference,

        [Parameter(Mandatory = $true , ParameterSetName = 'inbuilt')]
        [string]
        $Path,

        [Parameter(Mandatory = $true, ParameterSetName = 'inbuilt')]
        [ValidateSet('Connect', 'Delete', 'Get', 'Head', 'Merge', 'Options', 'Patch', 'Post', 'Put', 'Trace', '*')]
        [string]
        $Method,

        [Parameter(ParameterSetName = 'inbuilt')]
        [hashtable[]]
        $Parameters,

        [Parameter(ParameterSetName = 'inbuilt')]
        [hashtable]
        $RequestBody,

        [Parameter(ParameterSetName = 'inbuilt')]
        [hashtable]
        $Responses,

        [switch]
        $PassThru,

        [string[]]
        $DefinitionTag
    )

    $DefinitionTag = Test-PodeOADefinitionTag -Tag $DefinitionTag

    foreach ($r in @($Route)) {
        foreach ($tag in $DefinitionTag) {
            if ($Reference) {
                Test-PodeOAComponent -Field callbacks -DefinitionTag $tag -Name $Reference -PostValidation
                if (!$Name) {
                    $Name = $Reference
                }
                if (! $r.OpenApi.CallBacks.ContainsKey($tag)) {
                    $r.OpenApi.CallBacks[$tag] = [ordered]@{}
                }
                $r.OpenApi.CallBacks[$tag].$Name = @{
                    '$ref' = "#/components/callbacks/$Reference"
                }
            } else {
                if (! $r.OpenApi.CallBacks.ContainsKey($tag)) {
                    $r.OpenApi.CallBacks[$tag] = [ordered]@{}
                }
                $r.OpenApi.CallBacks[$tag].$Name = New-PodeOAComponentCallBackInternal -Params $PSBoundParameters -DefinitionTag $tag
            }
        }
    }

    if ($PassThru) {
        return $Route
    }
}

<#
.SYNOPSIS
Adds a response definition to the Callback.

.DESCRIPTION
Adds a response definition to the Callback.

.PARAMETER ResponseList
Hidden parameter used to pipe multiple CallBacksResponses

.PARAMETER StatusCode
The HTTP StatusCode for the response.To define a range of response codes, this field MAY contain the uppercase wildcard character `X`.
For example, `2XX` represents all response codes between `[200-299]`. Only the following range definitions are allowed: `1XX`, `2XX`, `3XX`, `4XX`, and `5XX`.
If a response is defined using an explicit code, the explicit code definition takes precedence over the range definition for that code.

.PARAMETER Content
The content-types and schema the response returns (the schema is created using the Property functions).
Alias: ContentSchemas

.PARAMETER Headers
The header name and schema the response returns (the schema is created using Add-PodeOAComponentHeader cmd-let).
Alias: HeaderSchemas

.PARAMETER Description
A Description of the response. (Default: the HTTP StatusCode description)

.PARAMETER Reference
A Reference Name of an existing component response to use.

.PARAMETER Links
A Response link definition

.PARAMETER Default
If supplied, the response will be used as a default response - this overrides the StatusCode supplied.

.PARAMETER DefinitionTag
An Array of strings representing the unique tag for the API specification.
This tag helps distinguish between different versions or types of API specifications within the application.
You can use this tag to reference the specific API documentation, schema, or version that your function interacts with.

.EXAMPLE
New-PodeOAResponse -StatusCode 200 -Content (  New-PodeOAContentMediaType -ContentMediaType 'application/json' -Content(New-PodeOAIntProperty -Name 'userId' -Object) )

.EXAMPLE
New-PodeOAResponse -StatusCode 200 -Content @{ 'application/json' = 'UserIdSchema' }

.EXAMPLE
New-PodeOAResponse -StatusCode 200 -Reference 'OKResponse'

.EXAMPLE
Add-PodeOACallBack -Title 'test' -Path '$request.body#/id' -Method Post  -RequestBody (
        New-PodeOARequestBody -Content (New-PodeOAContentMediaType -ContentMediaType '*/*' -Content (New-PodeOAStringProperty -Name 'id'))
    ) `
    -Response (
        New-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -Content (New-PodeOAContentMediaType -ContentMediaType 'application/json','application/xml' -Content 'Pet'  -Array) |
            New-PodeOAResponse -StatusCode 400 -Description 'Invalid ID supplied' |
                New-PodeOAResponse -StatusCode 404 -Description 'Pet not found' |
            New-PodeOAResponse -Default   -Description 'Something is wrong'
            )
#>

function New-PodeOAResponse {
    [CmdletBinding(DefaultParameterSetName = 'Schema')]
    param(
        [Parameter(ValueFromPipeline = $true , DontShow = $true )]
        [hashtable]
        $ResponseList,

        [Parameter(Mandatory = $true, ParameterSetName = 'Schema')]
        [Parameter(Mandatory = $true, ParameterSetName = 'Reference')]
        [ValidatePattern('^([1-5][0-9][0-9]|[1-5]XX)$')]
        [string]
        $StatusCode,

        [Parameter(ParameterSetName = 'Schema')]
        [Parameter(ParameterSetName = 'SchemaDefault')]
        [Alias('ContentSchemas')]
        [hashtable]
        $Content,

        [Alias('HeaderSchemas')]
        [AllowEmptyString()]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ $_ -is [string] -or $_ -is [string[]] -or $_ -is [hashtable] })]
        $Headers,

        [Parameter(Mandatory = $true, ParameterSetName = 'Schema')]
        [Parameter(Mandatory = $true, ParameterSetName = 'SchemaDefault')]
        [string]
        $Description  ,

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
        [System.Collections.Specialized.OrderedDictionary ]
        $Links,

        [string[]]
        $DefinitionTag
    )
    begin {

        if (Test-PodeIsEmpty -Value $DefinitionTag) {
            $DefinitionTag = $PodeContext.Server.SelectedOADefinitionTag
        }

        # override status code with default
        if ($Default) {
            $code = 'default'
        } else {
            $code = "$($StatusCode)"
        }
        $response = @{}
    }
    process {
        foreach ($tag in $DefinitionTag) {
            if (! $response.$tag) {
                $response.$tag = [ordered] @{}
            }
            $response[$tag][$code] = New-PodeOResponseInternal -DefinitionTag $tag -Params $PSBoundParameters
        }
    }
    end {
        if ($ResponseList) {
            foreach ($tag in $DefinitionTag) {
                if (! $ResponseList.ContainsKey( $tag) ) {
                    $ResponseList[$tag] = [ordered] @{}
                }
                $response[$tag].GetEnumerator() | ForEach-Object { $ResponseList[$tag][$_.Key] = $_.Value }
            }
            return $ResponseList
        } else {
            return  $response
        }
    }
}

<#
.SYNOPSIS
    Creates media content type definitions for OpenAPI specifications.

.DESCRIPTION
    The New-PodeOAContentMediaType function generates media content type definitions suitable for use in OpenAPI specifications. It supports various media types and allows for the specification of content as either a single object or an array of objects.

.PARAMETER MediaType
    An array of strings specifying the media types to be defined. Media types should conform to standard MIME types (e.g., 'application/json', 'image/png'). The function validates these media types against a regular expression to ensure they are properly formatted.

.PARAMETER Content
    The content definition for the media type. This could be an object representing the structure of the content expected for the specified media types.

.PARAMETER Array
    A switch parameter, used in the 'Array' parameter set, to indicate that the content should be treated as an array.

.PARAMETER UniqueItems
    A switch parameter, used in the 'Array' parameter set, to specify that items in the array should be unique.

.PARAMETER MinItems
    Used in the 'Array' parameter set to specify the minimum number of items that should be present in the array.

.PARAMETER MaxItems
    Used in the 'Array' parameter set to specify the maximum number of items that should be present in the array.

.PARAMETER Title
    Used in the 'Array' parameter set to provide a title for the array content.

.PARAMETER Upload
    If provided configure the media for an upload changing the result based on the OpenApi version

.PARAMETER ContentEncoding
    Define the content encoding for upload (Default Binary)

.PARAMETER PartContentMediaType
    Define the content encoding for multipart upload

.EXAMPLE
    Add-PodeRoute -PassThru -Method get -Path '/pet/findByStatus' -Authentication 'Login-OAuth2' -Scope 'read' -ScriptBlock {
        Write-PodeJsonResponse -Value 'done' -StatusCode 200
    } | Set-PodeOARouteInfo -Summary 'Finds Pets by status' -Description 'Multiple status values can be provided with comma separated strings' -Tags 'pet' -OperationId 'findPetsByStatus' -PassThru |
        Set-PodeOARequest -PassThru -Parameters @(
            (New-PodeOAStringProperty -Name 'status' -Description 'Status values that need to be considered for filter' -Default 'available' -Enum @('available', 'pending', 'sold') | ConvertTo-PodeOAParameter -In Query)
        ) |
        Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -Content (New-PodeOAContentMediaType -ContentMediaType 'application/json','application/xml' -Content 'Pet' -Array -UniqueItems) -PassThru |
        Add-PodeOAResponse -StatusCode 400 -Description 'Invalid status value'
    This example demonstrates the use of New-PodeOAContentMediaType in defining a GET route '/pet/findByStatus' in an OpenAPI specification. The route includes request parameters and responses with media content types for 'application/json' and 'application/xml'.

.EXAMPLE
    $content = @{ type = 'string' }
    $mediaType = 'application/json'
    New-PodeOAContentMediaType -MediaType $mediaType -Content $content
    This example creates a media content type definition for 'application/json' with a simple string content type.

.EXAMPLE
    $content = @{ type = 'object'; properties = @{ name = @{ type = 'string' } } }
    $mediaTypes = 'application/json', 'application/xml'
    New-PodeOAContentMediaType -MediaType $mediaTypes -Content $content -Array -MinItems 1 -MaxItems 5 -Title 'UserList'
    This example demonstrates defining an array of objects for both 'application/json' and 'application/xml' media types, with a specified range for the number of items and a title.

.EXAMPLE
    Add-PodeRoute -PassThru -Method get -Path '/pet/findByStatus' -Authentication 'Login-OAuth2' -Scope 'read' -ScriptBlock {
        Write-PodeJsonResponse -Value 'done' -StatusCode 200
    } | Set-PodeOARouteInfo -Summary 'Finds Pets by status' -Description 'Multiple status values can be provided with comma separated strings' -Tags 'pet' -OperationId 'findPetsByStatus' -PassThru |
        Set-PodeOARequest -PassThru -Parameters @(
            (New-PodeOAStringProperty -Name 'status' -Description 'Status values that need to be considered for filter' -Default 'available' -Enum @('available', 'pending', 'sold') | ConvertTo-PodeOAParameter -In Query)
        ) |
        Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -Content (New-PodeOAContentMediaType -ContentMediaType 'application/json','application/xml' -Content 'Pet' -Array -UniqueItems) -PassThru |
        Add-PodeOAResponse -StatusCode 400 -Description 'Invalid status value'
    This example demonstrates the use of New-PodeOAContentMediaType in defining a GET route '/pet/findByStatus' in an OpenAPI specification. The route includes request parameters and responses with media content types for 'application/json' and 'application/xml'.

.NOTES
    This function is useful for dynamically creating media type specifications in OpenAPI documentation, providing flexibility in defining the expected content structure for different media types.
#>

function New-PodeOAContentMediaType {
    [CmdletBinding(DefaultParameterSetName = 'inbuilt')]
    param (
        [string[]]
        $MediaType = '*/*',

        [object]
        $Content,

        [Parameter(  Mandatory = $true, ParameterSetName = 'Array')]
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

        [Parameter(ParameterSetName = 'Array')]
        [string]
        $Title,

        [Parameter(Mandatory = $true, ParameterSetName = 'Upload')]
        [switch]
        $Upload,

        [Parameter(  ParameterSetName = 'Upload')]
        [ValidateSet('Binary', 'Base64')]
        [string]
        $ContentEncoding = 'Binary',

        [Parameter(  ParameterSetName = 'Upload')]
        [string]
        $PartContentMediaType

    )

    $DefinitionTag = Test-PodeOADefinitionTag -Tag $DefinitionTag
    $props = [ordered]@{}
    foreach ($media in $MediaType) {
        if ($media -inotmatch '^(application|audio|image|message|model|multipart|text|video|\*)\/[\w\.\-\*]+(;[\s]*(charset|boundary)=[\w\.\-\*]+)*$') {
            throw "Invalid content-type found for schema: $($media)"
        }
        if ($Upload.IsPresent) {
            if ( $media -ieq 'multipart/form-data' -and $Content) {
                $Content = @{'__upload' = @{
                        'content'              = $Content
                        'partContentMediaType' = $PartContentMediaType
                    }
                }
            } else {
                $Content = @{'__upload' = @{
                        'contentEncoding' = $ContentEncoding
                    }
                }

            }
        } else {
            if ($null -eq $Content ) {
                $Content = @{}
            }
        }
        if ($Array.IsPresent) {
            $props[$media] = @{
                __array   = $true
                __content = $Content
                __upload  = $Upload
            }
            if ($MinItems) {
                $props[$media].__minItems = $MinItems
            }
            if ($MaxItems) {
                $props[$media].__maxItems = $MaxItems
            }
            if ($Title) {
                $props[$media].__title = $Title
            }
            if ($UniqueItems.IsPresent) {
                $props[$media].__uniqueItems = $UniqueItems.IsPresent
            }

        } else {
            $props[$media] = $Content
        }
    }
    return $props
}


<#
.SYNOPSIS
    Adds a response link to an existing list of OpenAPI response links.

.DESCRIPTION
    The New-PodeOAResponseLink function is designed to add a new response link to an existing OrderedDictionary of OpenAPI response links.
    It can be used to define complex response structures with links to other operations or references, and it supports adding multiple links through pipeline input.

.PARAMETER LinkList
    An OrderedDictionary of existing response links.
    This parameter is intended for use with pipeline input, allowing the function to add multiple links to the collection.
    It is hidden from standard help displays to emphasize its use primarily in pipeline scenarios.

.PARAMETER Name
    Mandatory. A unique name for the response link.
    Must be a valid string composed of alphanumeric characters, periods (.), hyphens (-), and underscores (_).

.PARAMETER Description
    A brief description of the response link. CommonMark syntax may be used for rich text representation.
    For more information on CommonMark syntax, see [CommonMark Specification](https://spec.commonmark.org/).

.PARAMETER OperationId
    The name of an existing, resolvable OpenAPI Specification (OAS) operation, as defined with a unique `operationId`.
    This parameter is mandatory when using the 'OperationId' parameter set and is mutually exclusive of the `OperationRef` field. It is used to specify the unique identifier of the operation the link is associated with.

.PARAMETER OperationRef
    A relative or absolute URI reference to an OAS operation.
    This parameter is mandatory when using the 'OperationRef' parameter set and is mutually exclusive of the `OperationId` field.
    It MUST point to an Operation Object. Relative `operationRef` values MAY be used to locate an existing Operation Object in the OpenAPI specification.

.PARAMETER Reference
A Reference Name of an existing component link to use.

.PARAMETER Parameters
    A map representing parameters to pass to an operation as specified with `operationId` or identified via `operationRef`.
    The key is the parameter name to be used, whereas the value can be a constant or an expression to be evaluated and passed to the linked operation.
    Parameter names can be qualified using the parameter location syntax `[{in}.]{name}` for operations that use the same parameter name in different locations (e.g., path.id).

.PARAMETER RequestBody
    A string representing the request body to use as a request body when calling the target.

.PARAMETER DefinitionTag
    An Array of strings representing the unique tag for the API specification.
    This tag helps distinguish between different versions or types of API specifications within the application.
    You can use this tag to reference the specific API documentation, schema, or version that your function interacts with.

.EXAMPLE
    $links = New-PodeOAResponseLink -LinkList $links -Name 'address' -OperationId 'getUserByName' -Parameters @{'username' = '$request.path.username'}
    Add-PodeOAResponse -StatusCode 200 -Content @{'application/json' = 'User'} -Links $links
    This example demonstrates creating and adding a link named 'address' associated with the operation 'getUserByName' to an OrderedDictionary of links. The updated dictionary is then used in the 'Add-PodeOAResponse' function to define a response with a status code of 200.

.NOTES
    The function supports adding links either by specifying an 'OperationId' or an 'OperationRef', making it versatile for different OpenAPI specification needs.
    It's important to match the parameters and response structures as per the OpenAPI specification to ensure the correct functionality of the API documentation.
#>
function New-PodeOAResponseLink {
    [CmdletBinding(DefaultParameterSetName = 'OperationId')]
    param(
        [Parameter(ValueFromPipeline = $true , DontShow = $true )]
        [System.Collections.Specialized.OrderedDictionary ]
        $LinkList,

        [Parameter( Mandatory = $false, ParameterSetName = 'Reference')]
        [Parameter( Mandatory = $true, ParameterSetName = 'OperationRef')]
        [Parameter( Mandatory = $true, ParameterSetName = 'OperationId')]
        [ValidatePattern('^[a-zA-Z0-9\.\-_]+$')]
        [string]
        $Name,

        [Parameter( ParameterSetName = 'OperationRef')]
        [Parameter( ParameterSetName = 'OperationId')]
        [string]
        $Description,

        [Parameter(Mandatory = $true, ParameterSetName = 'OperationId')]
        [string]
        $OperationId,

        [Parameter(Mandatory = $true, ParameterSetName = 'OperationRef')]
        [string]
        $OperationRef,

        [Parameter( ParameterSetName = 'OperationRef')]
        [Parameter( ParameterSetName = 'OperationId')]
        [hashtable]
        $Parameters,

        [Parameter( ParameterSetName = 'OperationRef')]
        [Parameter( ParameterSetName = 'OperationId')]
        [string]
        $RequestBody,

        [Parameter(Mandatory = $true, ParameterSetName = 'Reference')]
        [string]
        $Reference,

        [string[]]
        $DefinitionTag

    )
    begin {

        if (Test-PodeIsEmpty -Value $DefinitionTag) {
            $DefinitionTag = $PodeContext.Server.SelectedOADefinitionTag
        }
        if ($Reference) {
            Test-PodeOAComponent -Field links -DefinitionTag $DefinitionTag -Name $Reference  -PostValidation
            if (!$Name) {
                $Name = $Reference
            }
            $link = [ordered]@{
                $Name = @{
                    '$ref' = "#/components/links/$Reference"
                }
            }
        } else {
            $link = [ordered]@{
                $Name = New-PodeOAResponseLinkInternal -Params $PSBoundParameters
            }
        }
    }
    process {
    }
    end {
        if ($LinkList) {
            $link.GetEnumerator() | ForEach-Object { $LinkList[$_.Key] = $_.Value }
            return $LinkList
        } else {
            return [System.Collections.Specialized.OrderedDictionary] $link
        }
    }

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

.PARAMETER Path
The URI path for the Route.

.PARAMETER Method
The HTTP Method of this Route, multiple can be supplied.

.PARAMETER Servers
A list of external endpoint. created with New-PodeOAServerEndpoint

.PARAMETER PassThru
If supplied, the route passed in will be returned for further chaining.

.PARAMETER DefinitionTag
An Array of strings representing the unique tag for the API specification.
This tag helps distinguish between different versions or types of API specifications within the application.
You can use this tag to reference the specific API documentation, schema, or version that your function interacts with.

.EXAMPLE
Add-PodeOAExternalRoute -PassThru -Method Get -Path '/peta/:id' -Servers (
    New-PodeOAServerEndpoint -Url 'http://ext.server.com/api/v12' -Description 'ext test server' |
    New-PodeOAServerEndpoint -Url 'http://ext13.server.com/api/v12' -Description 'ext test server 13'
    ) |
        Set-PodeOARouteInfo -Summary 'Find pets by ID' -Description 'Returns pets based on ID'  -OperationId 'getPetsById' -PassThru |
        Set-PodeOARequest -PassThru -Parameters @(
        (New-PodeOAStringProperty -Name 'id' -Description 'ID of pet to use' -array | ConvertTo-PodeOAParameter -In Path -Style Simple -Required )) |
        Add-PodeOAResponse -StatusCode 200 -Description 'pet response'   -Content (@{ '*/*' = New-PodeOASchemaProperty   -ComponentSchema 'Pet' -array }) -PassThru |
        Add-PodeOAResponse -Default  -Description 'error payload' -Content (@{'text/html' = 'ErrorModel' }) -PassThru
.EXAMPLE
    Add-PodeRoute -PassThru -Method Get -Path '/peta/:id'  -ScriptBlock {
            Write-PodeJsonResponse -Value 'done' -StatusCode 200
        } | Add-PodeOAExternalRoute -PassThru   -Servers (
        New-PodeOAServerEndpoint -Url 'http://ext.server.com/api/v12' -Description 'ext test server' |
        New-PodeOAServerEndpoint -Url 'http://ext13.server.com/api/v12' -Description 'ext test server 13'
        ) |
        Set-PodeOARouteInfo -Summary 'Find pets by ID' -Description 'Returns pets based on ID'  -OperationId 'getPetsById' -PassThru |
        Set-PodeOARequest -PassThru -Parameters @(
        (New-PodeOAStringProperty -Name 'id' -Description 'ID of pet to use' -array | ConvertTo-PodeOAParameter -In Path -Style Simple -Required )) |
        Add-PodeOAResponse -StatusCode 200 -Description 'pet response'   -Content (@{ '*/*' = New-PodeOASchemaProperty   -ComponentSchema 'Pet' -array }) -PassThru |
        Add-PodeOAResponse -Default  -Description 'error payload' -Content (@{'text/html' = 'ErrorModel' }) -PassThru
#>
function Add-PodeOAExternalRoute {
    [CmdletBinding(DefaultParameterSetName = 'Pipeline')]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = 'Pipeline')]
        [ValidateNotNullOrEmpty()]
        [hashtable[]]
        $Route,

        [Parameter(Mandatory = $true , ParameterSetName = 'BuiltIn')]
        [string]
        $Path,

        [Parameter(Mandatory = $true)]
        [ValidateScript({ $_.Count -gt 0 })]
        [hashtable[]]
        $Servers,

        [Parameter(Mandatory = $true, ParameterSetName = 'BuiltIn')]
        [ValidateSet('Connect', 'Delete', 'Get', 'Head', 'Merge', 'Options', 'Patch', 'Post', 'Put', 'Trace', '*')]
        [string]
        $Method,

        [switch]
        $PassThru,

        [Parameter( ParameterSetName = 'BuiltIn')]
        [string[]]
        $DefinitionTag
    )

    $DefinitionTag = Test-PodeOADefinitionTag -Tag $DefinitionTag

    switch ($PSCmdlet.ParameterSetName.ToLowerInvariant()) {
        'builtin' {

            # ensure the route has appropriate slashes
            $Path = Update-PodeRouteSlashes -Path $Path
            $OpenApiPath = ConvertTo-PodeOpenApiRoutePath -Path $Path
            $Path = Resolve-PodePlaceholders -Path $Path
            $extRoute = @{
                Method  = $Method.ToLower()
                Path    = $Path
                Local   = $false
                OpenApi = @{
                    Path           = $OpenApiPath
                    Responses      = $null
                    Parameters     = $null
                    RequestBody    = $null
                    callbacks      = [ordered]@{}
                    Authentication = @()
                    Servers        = $Servers
                    DefinitionTag  = $DefinitionTag
                }
            }
            foreach ($tag in $DefinitionTag) {
                #add the default OpenApi responses
                if ( $PodeContext.Server.OpenAPI[$tag].hiddenComponents.defaultResponses) {
                    $extRoute.OpenApi.Responses = $PodeContext.Server.OpenAPI[$tag].hiddenComponents.defaultResponses.Clone()
                }
                if (! (Test-PodeOAComponentExternalPath -DefinitionTag $tag -Name $Path)) {
                    $PodeContext.Server.OpenAPI[$tag].hiddenComponents.externalPath[$Path] = @{}
                }

                $PodeContext.Server.OpenAPI[$tag].hiddenComponents.externalPath.$Path[$Method] = $extRoute
            }

            if ($PassThru) {
                return $extRoute
            }
        }
        'pipeline' {
            foreach ($r in @($Route)) {
                $r.OpenApi.Servers = $Servers
            }
            if ($PassThru) {
                return $Route
            }
        }
    }
}



<#
.SYNOPSIS
Creates an OpenAPI Server Object.

.DESCRIPTION
Creates an OpenAPI Server Object to use with Add-PodeOAExternalRoute

.PARAMETER ServerEndpointList
Used for piping

.PARAMETER Url
A URL to the target host.  This URL supports Server Variables and MAY be relative, to indicate that the host location is relative to the location where the OpenAPI document is being served.
Variable substitutions will be made when a variable is named in `{`brackets`}`.

.PARAMETER Description
An optional string describing the host designated by the URL. [CommonMark syntax](https://spec.commonmark.org/) MAY be used for rich text representation.


.EXAMPLE
New-PodeOAServerEndpoint -Url 'https://myserver.io/api' -Description 'My test server'

.EXAMPLE
New-PodeOAServerEndpoint -Url '/api' -Description 'My local server'


}
#>
function New-PodeOAServerEndpoint {
    param (
        [Parameter(ValueFromPipeline = $true , DontShow = $true )]
        [hashtable[]]
        $ServerEndpointList,

        [Parameter(Mandatory = $true)]
        [ValidatePattern('^(https?://|/).+')]
        [string]
        $Url,

        [string]
        $Description
    )
    begin {
        $lUrl = [ordered]@{url = $Url }
        if ($Description) {
            $lUrl.description = $Description
        }
        $collectedInput = [System.Collections.Generic.List[hashtable]]::new()
    }
    process {
        if ($ServerEndpointList) {
            $collectedInput.AddRange($ServerEndpointList)
        }
    }
    end {
        if ($ServerEndpointList) {
            return $collectedInput + $lUrl
        } else {
            return $lUrl
        }
    }
}



<#
.SYNOPSIS
Sets metadate for the supplied route.

.DESCRIPTION
Sets metadate for the supplied route, such as Summary and Tags.

.LINK
https://swagger.io/docs/specification/paths-and-operations/

.PARAMETER Name
    Alias for 'Name'. A unique identifier for the webhook.
    It must be a valid string of alphanumeric characters, periods (.), hyphens (-), and underscores (_).

.PARAMETER Method
The HTTP Method of this Route, multiple can be supplied.

.PARAMETER PassThru
If supplied, the route passed in will be returned for further chaining.

.PARAMETER DefinitionTag
An Array of strings representing the unique tag for the API specification.
This tag helps distinguish between different versions or types of API specifications within the application.
You can use this tag to reference the specific API documentation, schema, or version that your function interacts with.

.EXAMPLE
Add-PodeOAWebhook -PassThru -Method Get    |
        Set-PodeOARouteInfo -Summary 'Find pets by ID' -Description 'Returns pets based on ID'  -OperationId 'getPetsById' -PassThru |
        Set-PodeOARequest -PassThru -Parameters @(
        (New-PodeOAStringProperty -Name 'id' -Description 'ID of pet to use' -array | ConvertTo-PodeOAParameter -In Path -Style Simple -Required )) |
        Add-PodeOAResponse -StatusCode 200 -Description 'pet response'   -Content (@{ '*/*' = New-PodeOASchemaProperty   -ComponentSchema 'Pet' -array }) -PassThru |
        Add-PodeOAResponse -Default  -Description 'error payload' -Content (@{'text/html' = 'ErrorModel' }) -PassThru
#>
function Add-PodeOAWebhook {
    param(

        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[a-zA-Z0-9\.\-_]+$')]
        [string]
        $Name,

        [Parameter(Mandatory = $true )]
        [ValidateSet('Connect', 'Delete', 'Get', 'Head', 'Merge', 'Options', 'Patch', 'Post', 'Put', 'Trace', '*')]
        [string]
        $Method,

        [switch]
        $PassThru,

        [string[]]
        $DefinitionTag
    )

    $DefinitionTag = Test-PodeOADefinitionTag -Tag $DefinitionTag

    $refRoute = @{
        Method      = $Method.ToLower()
        NotPrepared = $true
        OpenApi     = @{
            Responses      = @{}
            Parameters     = $null
            RequestBody    = $null
            callbacks      = [ordered]@{}
            Authentication = @()
        }
    }
    foreach ($tag in $DefinitionTag) {
        if (Test-OpenAPIVersion -Version 3.0 -DefinitionTag $tag ) {
            throw 'The feature reusable component webhook is not available in OpenAPI v3.0.x'
        }
        $PodeContext.Server.OpenAPI[$tag].webhooks[$Name] = $refRoute
    }

    if ($PassThru) {
        return $refRoute
    }
}


<#
.SYNOPSIS
Select a group of OpenAPI Definions for modification.

.DESCRIPTION
Select a group of OpenAPI Definions for modification.

.PARAMETER Tag
An Array of strings representing the unique tag for the API specification.
This tag helps distinguish between different versions or types of API specifications within the application.
You can use this tag to reference the specific API documentation, schema, or version that your function interacts with.
If Tag is empty or null the default Definition is selected

.PARAMETER ScriptBlock
The ScriptBlock that will modified the group.

.EXAMPLE
Select-PodeOADefinition -Tag 'v3', 'v3.1'  -Script {
        New-PodeOAIntProperty -Name 'id'-Format Int64 -Example 10 -Required |
            New-PodeOAIntProperty -Name 'petId' -Format Int64 -Example 198772 -Required |
            New-PodeOAIntProperty -Name 'quantity' -Format Int32 -Example 7 -Required |
            New-PodeOAStringProperty -Name 'shipDate' -Format Date-Time |
            New-PodeOAStringProperty -Name 'status' -Description 'Order Status' -Required -Example 'approved' -Enum @('placed', 'approved', 'delivered') |
            New-PodeOABoolProperty -Name 'complete' |
            New-PodeOAObjectProperty -XmlName 'order' |
            Add-PodeOAComponentSchema -Name 'Order'

New-PodeOAContentMediaType -ContentMediaType 'application/json', 'application/xml' -Content 'Pet' |
    Add-PodeOAComponentRequestBody -Name 'Pet' -Description 'Pet object that needs to be added to the store'

}
#>
function Select-PodeOADefinition {
    [CmdletBinding()]
    param(
        [string[]]
        $Tag,

        [Parameter(Mandatory = $true)]
        [scriptblock]
        $Scriptblock


    )

    if (Test-PodeIsEmpty $Scriptblock) {
        throw 'No scriptblock for -Scriptblock passed'
    }
    if (Test-PodeIsEmpty -Value $Tag) {
        $Tag = $PodeContext.Server.DefaultOADefinitionTag
    } else {
        $Tag = Test-PodeOADefinitionTag -Tag $Tag
    }
    # check for scoped vars
    $Scriptblock, $usingVars = Convert-PodeScopedVariables -ScriptBlock $Scriptblock -PSSession $PSCmdlet.SessionState
    $PodeContext.Server.OADefinitionTagSelectionStack.Push($PodeContext.Server.SelectedOADefinitionTag)

    $PodeContext.Server.SelectedOADefinitionTag = $Tag

    $_args = @(Get-PodeScriptblockArguments -UsingVariables $usingVars)
    $null = Invoke-PodeScriptBlock -ScriptBlock $Scriptblock -Arguments $_args -Splat
    $PodeContext.Server.SelectedOADefinitionTag = $PodeContext.Server.OADefinitionTagSelectionStack.Pop()

}








<#
.SYNOPSIS
Check if a Definition exist

.DESCRIPTION
Check if a Definition exist. If the parameter Tag is empty or Null $PodeContext.Server.SelectedOADefinitionTag is returned

.PARAMETER Tag
An Array of strings representing the unique tag for the API specification.
This tag helps distinguish between different versions or types of API specifications within the application.
You can use this tag to reference the specific API documentation, schema, or version that your function interacts with.

.EXAMPLE
Test-PodeOADefinitionTag -Tag 'v3', 'v3.1'
#>
function Test-PodeOADefinitionTag {
    param (
        [Parameter(Mandatory = $false)]
        [string[]]
        $Tag
    )

    if ($Tag -and $Tag.Count -gt 0) {
        foreach ($t in $Tag) {
            if (! ($PodeContext.Server.OpenApi.Keys -ccontains $t)) {
                throw "DefinitionTag $t is not defined"
            }
        }
        return $Tag
    } else {
        return $PodeContext.Server.SelectedOADefinitionTag
    }
}



<#
.SYNOPSIS
Validate the OpenAPI definition if all Reference are satisfied

.DESCRIPTION
Validate the OpenAPI definition if all Reference are satisfied



.PARAMETER DefinitionTag
An Array of strings representing the unique tag for the API specification.
This tag helps distinguish between different versions or types of API specifications within the application.
You can use this tag to reference the specific API documentation, schema, or version that your function interacts with.

.EXAMPLE
    if ((Test-PodeOADefinition -DefinitionTag 'v3').count -eq 0){
        Write-PodeHost "The OpenAPI definition is valid"
    }
#>
function Test-PodeOADefinition {
    param (
        [string[]]
        $DefinitionTag
    )
    if (! ($DefinitionTag -and $DefinitionTag.Count -gt 0)) {
        $DefinitionTag = $PodeContext.Server.OpenAPI.keys
    }

    $undefined = @{}
    foreach ($tag in $DefinitionTag) {
        foreach ($field in $PodeContext.Server.OpenAPI[$tag].hiddenComponents.postValidation.keys) {
            foreach ($name in $PodeContext.Server.OpenAPI[$tag].hiddenComponents.postValidation[$field].keys) {
                if (! (Test-PodeOAComponent -DefinitionTag $tag -Field $field -Name $name)) {
                    if (! $undefined.ContainsKey( $tag)) {
                        $undefined[$tag] = @{}
                    }
                    $undefined[$tag]["#/components/$field/$name"] = $PodeContext.Server.OpenAPI[$tag].hiddenComponents.postValidation[$field][$name]
                }
            }
        }
    }
    return $undefined
}