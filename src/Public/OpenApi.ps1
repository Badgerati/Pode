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
Enable-PodeOpenApi -Path '/docs/openapi'   -NoCompress -Mode 'Donwload' -DisableMinimalDefinitions
#>
function Enable-PodeOpenApi {
    [CmdletBinding()]
    param(
        [Parameter()]
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

        [switch ]
        $DisableMinimalDefinitions

    )

    if ($PSCmdlet.ParameterSetName -eq 'Deprecated') {
        Write-PodeHost -ForegroundColor Yellow "WARNING: The parameter Title,Version and Description are deprecated. Please use 'Add-PodeOAInfo' instead."
    }

    $PodeContext.Server.OpenAPI.hiddenComponents.enableMinimalDefinitions = !$DisableMinimalDefinitions.IsPresent


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
    if ( $Title) {
        $PodeContext.Server.OpenAPI.info.title = $Title
    }
    if ($Version) {
        $PodeContext.Server.OpenAPI.info.version = $Version
    }

    if ($Description ) {
        $PodeContext.Server.OpenAPI.info.description = $Description
    }

    if ( $EnableSchemaValidation.IsPresent) {
        #Test-Json has been introduced with version 6.1.0
        if ($PSVersionTable.PSVersion -ge [version]'6.1.0') {
            $PodeContext.Server.OpenAPI.hiddenComponents.schemaValidation = $EnableSchemaValidation.IsPresent
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
        [Parameter(Mandatory)]
        [ValidatePattern('^(https?://|/).+')]
        [string]
        $Url,
        [string]
        $Description,
        [System.Collections.Specialized.OrderedDictionary]
        $Variables
    )

    if (! $PodeContext.Server.OpenAPI.servers) {
        $PodeContext.Server.OpenAPI.servers = @()
    }
    $lUrl = [ordered]@{url = $Url }
    if ($Description) {
        $lUrl.description = $Description
    }

    if ($Variables) {
        $lUrl.variables = $Variables
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
$defInJson = Get-PodeOADefinition -Json
#>
function Get-PodeOADefinition {
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
The HTTP StatusCode for the response.To define a range of response codes, this field MAY contain the uppercase wildcard character `X`.
For example, `2XX` represents all response codes between `[200-299]`. Only the following range definitions are allowed: `1XX`, `2XX`, `3XX`, `4XX`, and `5XX`.
If a response is defined using an explicit code, the explicit code definition takes precedence over the range definition for that code.

.PARAMETER Content
The content-types and schema the response returns (the schema is created using the Property functions).
Alias: ContentSchemas

.PARAMETER Headers
The header name and schema the response returns (the schema is created using Add-PodeOAComponentHeaderSchema cmd-let).
Alias: HeaderSchemas

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

        [Parameter()]
        [Alias('HeaderSchemas')]
        [AllowEmptyString()]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ $_ -is [string] -or $_ -is [string[]] -or $_ -is [hashtable] })]
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
        [switch]
        $ContentArray,

        [Parameter(ParameterSetName = 'Schema')]
        [Parameter(ParameterSetName = 'SchemaDefault')]
        [switch]
        $HeaderArray,

        [Parameter(ParameterSetName = 'Schema')]
        [Parameter(ParameterSetName = 'SchemaDefault')]
        [System.Collections.Specialized.OrderedDictionary ]
        $Links,

        [switch]
        $PassThru
    )

    # override status code with default
    if ($Default) {
        $code = 'default'
    } else {
        $code = "$($StatusCode)"
    }

    $response = New-PodeOResponseInternal -Params $PSBoundParameters
    # add the respones to the routes
    foreach ($r in @($Route)) {
        $r.OpenApi.Responses[$code] = $response
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
Add-PodeOAComponentResponse -Name 'OKResponse' -Content @{ 'application/json' = (New-PodeOAIntProperty -Name 'userId' -Object) }

.EXAMPLE
Add-PodeOAComponentResponse -Name 'ErrorResponse' -Content  @{ 'application/json' = 'ErrorSchema' }
#>
function Add-PodeOAComponentResponse {
    [CmdletBinding(DefaultParameterSetName = 'Schema')]
    param(
        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[a-zA-Z0-9\.\-_]+$')]
        [string]
        $Name,

        [Parameter(ParameterSetName = 'Schema')]
        [Alias('ContentSchemas')]
        [hashtable]
        $Content,

        [Parameter(ParameterSetName = 'Schema')]
        [Alias('HeaderSchemas')]
        [AllowEmptyString()]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ $_ -is [string] -or $_ -is [string[]] -or $_ -is [hashtable] })]
        $Headers,

        [Parameter(ParameterSetName = 'Schema')]
        [string]
        $Description,

        [Parameter(Mandatory = $true, ParameterSetName = 'Reference')]
        [string]
        $Reference,

        [Parameter(ParameterSetName = 'Schema')]
        [switch]
        $ContentArray,

        [Parameter(ParameterSetName = 'Schema')]
        [switch]
        $HeaderArray,

        [Parameter(ParameterSetName = 'Schema')]
        [System.Collections.Specialized.OrderedDictionary ]
        $Links
    )

    $PodeContext.Server.OpenAPI.components.responses[$Name] = New-PodeOResponseInternal -Params $PSBoundParameters


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

.PARAMETER Schema
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

.EXAMPLE
New-PodeOARequestBody -Content @{ 'application/json' = (New-PodeOAIntProperty -Name 'userId' -Object) }

.EXAMPLE
New-PodeOARequestBody -Content @{ 'application/json' = 'UserIdSchema' }

.EXAMPLE
New-PodeOARequestBody -Schema 'UserIdBody'

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
    [CmdletBinding(DefaultParameterSetName = 'Schema')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'Reference')]
        [Alias('Reference')]
        [string]
        $Schema,

        [Parameter(Mandatory = $true, ParameterSetName = 'Schema')]
        [Alias('ContentSchemas')]
        [hashtable]
        $Content,

        [Parameter(ParameterSetName = 'Schema')]
        [string]
        $Description,

        [Parameter(ParameterSetName = 'Schema')]
        [switch]
        $Required,

        [Parameter(ParameterSetName = 'Schema')]
        [switch]
        $Properties,

        [Parameter()]
        [System.Collections.Specialized.OrderedDictionary]
        $Examples,

        [Parameter()]
        [hashtable[]]
        $Encoding

    )
    if ($Example -and $Examples) {
        throw 'Parameter -Examples and -Example are mutually exclusive'
    }
    switch ($PSCmdlet.ParameterSetName.ToLowerInvariant()) {
        'schema' {
            $param = @{content = ConvertTo-PodeOAContentTypeSchema -Schemas $Content -Properties:$Properties }

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
            if (!(Test-PodeOAComponentRequestBody -Name $Schema)) {
                throw "The OpenApi component request body doesn't exist: $($Schema)"
            }

            $param = @{
                '$ref' = "#/components/requestBodies/$($Schema)"
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
    return $param
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

.PARAMETER Description
A description of the schema

.EXAMPLE
Add-PodeOAComponentSchema -Name 'UserIdSchema' -Schema (New-PodeOAIntProperty -Name 'userId' -Object)
#>
function Add-PodeOAComponentSchema {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[a-zA-Z0-9\.\-_]+$')]
        [string]
        $Name,

        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [hashtable]
        $Schema,

        [string]
        $Description
    )
    $PodeContext.Server.OpenAPI.components.schemas[$Name] = ($Schema | ConvertTo-PodeOASchemaProperty)
    if ($PodeContext.Server.OpenAPI.hiddenComponents.schemaValidation) {
        $modifiedSchema = ($Schema | ConvertTo-PodeOASchemaProperty) | Resolve-PodeOAReferences
        #Resolve-PodeOAReferences -ComponentSchema  $modifiedSchema
        $PodeContext.Server.OpenAPI.hiddenComponents.schemaJson[$Name] = @{
            'schema' = $modifiedSchema
            'json'   = $modifiedSchema | ConvertTo-Json -depth $PodeContext.Server.OpenAPI.hiddenComponents.depth
        }
    }
    if ($Description) {
        $PodeContext.Server.OpenAPI.components.schemas[$Name].description = $Description
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
        [ValidatePattern('^[a-zA-Z0-9\.\-_]+$')]
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
        [ValidatePattern('^[a-zA-Z0-9\.\-_]+$')]
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
        $param['required'] = $Required.IsPresent
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
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidatePattern('^[a-zA-Z0-9\.\-_]+$')]
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

.PARAMETER ExclusiveMaximum:
Specifies an exclusive upper limit for a numeric property in the OpenAPI schema.
When this parameter is used, it sets the exclusiveMaximum attribute in the OpenAPI definition to true, indicating that the numeric value must be strictly less than the specified maximum value.
This parameter is typically paired with a -Maximum parameter to define the upper bound.

.PARAMETER ExclusiveMinimum:
Specifies an exclusive lower limit for a numeric property in the OpenAPI schema.
When this parameter is used, it sets the exclusiveMinimun attribute in the OpenAPI definition to true, indicating that the numeric value must be strictly less than the specified minimun value.
This parameter is typically paired with a -Minimum parameter to define the lower bound.

.PARAMETER MultiplesOf
The integer must be in multiples of the supplied value.

.PARAMETER Description
A Description of the property.

.PARAMETER ExternalDoc
If supplied, add an additional external documentation for this operation.
The parameter is created by Add-PodeOAExternalDoc

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

.PARAMETER NoAdditionalProperties
If supplied, will configure the OpenAPI property additionalProperties to false.
This means that the defined object will not allow any properties beyond those explicitly declared in its schema.
If any additional properties are provided, they will be considered invalid.
Use this switch to enforce a strict schema definition, ensuring that objects contain only the specified set of properties and no others.

.PARAMETER AdditionalProperties
Define a set of additional properties for the OpenAPI schema. This parameter accepts a HashTable where each key-value pair represents a property name and its corresponding schema.
The schema for each property can include type, format, description, and other OpenAPI specification attributes.
When specified, these additional properties are included in the OpenAPI definition, allowing for more flexible and dynamic object structures.

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
        [ValidatePattern('^[a-zA-Z0-9\.\-_]+$')]
        [string]
        $Name,

        [Parameter()]
        [ValidateSet('', 'Int32', 'Int64')]
        [string]
        $Format,

        [Parameter()]
        [int]
        $Default,

        [Parameter()]
        [int]
        $Minimum,

        [Parameter()]
        [int]
        $Maximum,

        [Parameter()]
        [switch]
        $ExclusiveMaximum,

        [Parameter()]
        [switch]
        $ExclusiveMinimum,

        [Parameter()]
        [int]
        $MultiplesOf,

        [Parameter()]
        [string]
        $Description,

        [Parameter()]
        [string]
        $ExternalDoc,

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

        [switch]
        $NoAdditionalProperties,

        [hashtable]
        $AdditionalProperties,

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
        $param = New-PodeOAPropertyInternal -type 'integer' -Params $PSBoundParameters

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

.PARAMETER ExclusiveMaximum:
Specifies an exclusive upper limit for a numeric property in the OpenAPI schema.
When this parameter is used, it sets the exclusiveMaximum attribute in the OpenAPI definition to true, indicating that the numeric value must be strictly less than the specified maximum value.
This parameter is typically paired with a -Maximum parameter to define the upper bound.

.PARAMETER ExclusiveMinimum:
Specifies an exclusive lower limit for a numeric property in the OpenAPI schema.
When this parameter is used, it sets the exclusiveMinimun attribute in the OpenAPI definition to true, indicating that the numeric value must be strictly less than the specified minimun value.
This parameter is typically paired with a -Minimum parameter to define the lower bound.

.PARAMETER MultiplesOf
The number must be in multiples of the supplied value.

.PARAMETER Description
A Description of the property.

.PARAMETER ExternalDoc
If supplied, add an additional external documentation for this operation.
The parameter is created by Add-PodeOAExternalDoc

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

.PARAMETER NoAdditionalProperties
If supplied, will configure the OpenAPI property additionalProperties to false.
This means that the defined object will not allow any properties beyond those explicitly declared in its schema.
If any additional properties are provided, they will be considered invalid.
Use this switch to enforce a strict schema definition, ensuring that objects contain only the specified set of properties and no others.

.PARAMETER AdditionalProperties
Define a set of additional properties for the OpenAPI schema. This parameter accepts a HashTable where each key-value pair represents a property name and its corresponding schema.
The schema for each property can include type, format, description, and other OpenAPI specification attributes.
When specified, these additional properties are included in the OpenAPI definition, allowing for more flexible and dynamic object structures.

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
        [ValidatePattern('^[a-zA-Z0-9\.\-_]+$')]
        [string]
        $Name,

        [Parameter()]
        [ValidateSet('', 'Double', 'Float')]
        [string]
        $Format,

        [Parameter()]
        [double]
        $Default,

        [Parameter()]
        [double]
        $Minimum,

        [Parameter()]
        [double]
        $Maximum,

        [Parameter()]
        [switch]
        $ExclusiveMaximum,

        [Parameter()]
        [switch]
        $ExclusiveMinimum,

        [Parameter()]
        [double]
        $MultiplesOf,

        [Parameter()]
        [string]
        $Description,

        [Parameter()]
        [string]
        $ExternalDoc,

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

        [switch]
        $NoAdditionalProperties,

        [hashtable]
        $AdditionalProperties,

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
        $param = New-PodeOAPropertyInternal -type 'number' -Params $PSBoundParameters

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

.PARAMETER ExternalDoc
If supplied, add an additional external documentation for this operation.
The parameter is created by Add-PodeOAExternalDoc

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

.PARAMETER NoAdditionalProperties
If supplied, will configure the OpenAPI property additionalProperties to false.
This means that the defined object will not allow any properties beyond those explicitly declared in its schema.
If any additional properties are provided, they will be considered invalid.
Use this switch to enforce a strict schema definition, ensuring that objects contain only the specified set of properties and no others.

.PARAMETER AdditionalProperties
Define a set of additional properties for the OpenAPI schema. This parameter accepts a HashTable where each key-value pair represents a property name and its corresponding schema.
The schema for each property can include type, format, description, and other OpenAPI specification attributes.
When specified, these additional properties are included in the OpenAPI definition, allowing for more flexible and dynamic object structures.

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
        [ValidatePattern('^[a-zA-Z0-9\.\-_]+$')]
        [string]
        $Name,

        [Parameter( ParameterSetName = 'Array')]
        [Parameter(ParameterSetName = 'Inbuilt')]
        [ValidateSet('', 'Binary', 'Base64', 'Byte', 'Date', 'Date-Time', 'Password', 'Email', 'Uuid', 'Uri', 'Hostname', 'Ipv4', 'Ipv6')]
        [string]
        $Format,

        [Parameter( ParameterSetName = 'Array')]
        [Parameter(ParameterSetName = 'Custom')]
        [string]
        $CustomFormat,

        [Parameter()]
        [string]
        $Default,

        [Parameter()]
        [string]
        $Pattern,

        [Parameter()]
        [string]
        $Description,

        [Parameter()]
        [string]
        $ExternalDoc,

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

        [switch]
        $NoAdditionalProperties,

        [hashtable]
        $AdditionalProperties,

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
        $param = New-PodeOAPropertyInternal -type 'string' -Params $PSBoundParameters

        if ($Format -or $CustomFormat) {
            $param.format = $_format.ToLowerInvariant()
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

.PARAMETER ExternalDoc
If supplied, add an additional external documentation for this operation.
The parameter is created by Add-PodeOAExternalDoc

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

.PARAMETER NoAdditionalProperties
If supplied, will configure the OpenAPI property additionalProperties to false.
This means that the defined object will not allow any properties beyond those explicitly declared in its schema.
If any additional properties are provided, they will be considered invalid.
Use this switch to enforce a strict schema definition, ensuring that objects contain only the specified set of properties and no others.

.PARAMETER AdditionalProperties
Define a set of additional properties for the OpenAPI schema. This parameter accepts a HashTable where each key-value pair represents a property name and its corresponding schema.
The schema for each property can include type, format, description, and other OpenAPI specification attributes.
When specified, these additional properties are included in the OpenAPI definition, allowing for more flexible and dynamic object structures.

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
        [ValidatePattern('^[a-zA-Z0-9\.\-_]+$')]
        [string]
        $Name,

        [Parameter()]
        [string]
        $Default,

        [Parameter()]
        [string]
        $Description,

        [Parameter()]
        [string]
        $ExternalDoc,

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

        [switch]
        $NoAdditionalProperties,

        [hashtable]
        $AdditionalProperties,

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
        $param = New-PodeOAPropertyInternal -type 'boolean' -Params $PSBoundParameters

        if ($Default) {
            if ([bool]::TryParse($Default, [ref]$null) -or $Enum -icontains $Default) {
                $param.default = $Default
            } else {
                throw "The default value is not a boolean and it's not part of the enum"
            }
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

.PARAMETER ExternalDoc
If supplied, add an additional external documentation for this operation.
The parameter is created by Add-PodeOAExternalDoc

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

.PARAMETER NoProperties
If supplied, no properties are allowed in the object. If no properties are assigned to the object and the NoProperties parameter is not set the object accept any property

.PARAMETER MinProperties
If supplied, will restrict the minimun number of properties allowed in an object.

.PARAMETER MaxProperties
If supplied, will restrict the maximum number of properties allowed in an object.

.PARAMETER NoAdditionalProperties
If supplied, will configure the OpenAPI property additionalProperties to false.
This means that the defined object will not allow any properties beyond those explicitly declared in its schema.
If any additional properties are provided, they will be considered invalid.
Use this switch to enforce a strict schema definition, ensuring that objects contain only the specified set of properties and no others.

.PARAMETER AdditionalProperties
Define a set of additional properties for the OpenAPI schema. This parameter accepts a HashTable where each key-value pair represents a property name and its corresponding schema.
The schema for each property can include type, format, description, and other OpenAPI specification attributes.
When specified, these additional properties are included in the OpenAPI definition, allowing for more flexible and dynamic object structures.

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

.PARAMETER DiscriminatorProperty
If supplied, specifies the name of the property used to distinguish between different subtypes in a polymorphic schema in OpenAPI.
This string value represents the property in the payload that indicates which specific subtype schema should be applied.
It's essential in scenarios where an API endpoint handles data that conforms to one of several derived schemas from a common base schema.

.PARAMETER DiscriminatorMapping
If supplied, define a mapping between the values of the discriminator property and the corresponding subtype schemas.
This parameter accepts a HashTable where each key-value pair maps a discriminator value to a specific subtype schema name.
It's used in conjunction with the -DiscriminatorProperty to provide complete discrimination logic in polymorphic scenarios.

.EXAMPLE
New-PodeOAObjectProperty -Name 'user' -Properties @('<ARRAY_OF_PROPERTIES>')

.EXAMPLE
New-PodeOABoolProperty -Name 'enabled' -Required|
    New-PodeOAObjectProperty  -Name 'extraProperties'  -AdditionalProperties [ordered]@{
        "property1" = @{ "type" = "string"; "description" = "Description for property1" };
        "property2" = @{ "type" = "integer"; "format" = "int32" }
}
#>
function New-PodeOAObjectProperty {
    [CmdletBinding(DefaultParameterSetName = 'Inbuilt')]
    param(

        [Parameter(ValueFromPipeline = $true, DontShow = $true , Position = 0 )]
        [hashtable[]]
        $ParamsList,

        [Parameter()]
        [ValidatePattern('^[a-zA-Z0-9\.\-_]+$')]
        [string]
        $Name,

        [Parameter()]
        [hashtable[]]
        $Properties,

        [Parameter()]
        [string]
        $Description,

        [Parameter()]
        [string]
        $ExternalDoc,

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

        [switch]
        $NoProperties,

        [int]
        $MinProperties,

        [int]
        $MaxProperties,

        [switch]
        $NoAdditionalProperties,

        [hashtable]
        $AdditionalProperties,

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

        [hashtable]
        $Xml,

        [string]
        $DiscriminatorProperty,

        [hashtable]
        $DiscriminatorMapping
    )
    begin {
        $param = New-PodeOAPropertyInternal -type 'object' -Params $PSBoundParameters
        if ($NoProperties) {
            if ($Properties -or $MinProperties -or $MaxProperties) {
                throw '-NoProperties is not compatible with -Properties, -MinProperties and -MaxProperties'
            }
            $param.properties = @($null)
            $PropertiesFromPipeline = $false
        } elseif ($Properties) {
            $param.properties = $Properties
            $PropertiesFromPipeline = $false
        } else {
            $param.properties = @()
            $PropertiesFromPipeline = $true
        }
        if ($DiscriminatorProperty) {
            $param.discriminator = @{
                'propertyName' = $DiscriminatorProperty
            }
            if ($DiscriminatorMapping) {
                $param.discriminator.mapping = $DiscriminatorMapping
            }
        } elseif ($DiscriminatorMapping) {
            throw 'Parameter -DiscriminatorMapping requires the -DiscriminatorProperty parameters'
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

.PARAMETER DiscriminatorProperty
If supplied, specifies the name of the property used to distinguish between different subtypes in a polymorphic schema in OpenAPI.
This string value represents the property in the payload that indicates which specific subtype schema should be applied.
It's essential in scenarios where an API endpoint handles data that conforms to one of several derived schemas from a common base schema.

.PARAMETER DiscriminatorMapping
If supplied, define a mapping between the values of the discriminator property and the corresponding subtype schemas.
This parameter accepts a HashTable where each key-value pair maps a discriminator value to a specific subtype schema name.
It's used in conjunction with the -DiscriminatorProperty to provide complete discrimination logic in polymorphic scenarios.

.EXAMPLE
Add-PodeOAComponentSchema -Name 'Pets' -Schema (  Merge-PodeOAProperty  -Type OneOf -ObjectDefinitions @( 'Cat','Dog') -Discriminator "petType")


.EXAMPLE
Add-PodeOAComponentSchema -Name 'Cat' -Schema (
        Merge-PodeOAProperty  -Type AllOf -ObjectDefinitions @( 'Pet', ( New-PodeOAObjectProperty -Properties @(
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

        [string]
        $DiscriminatorProperty,

        [hashtable]
        $DiscriminatorMapping
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
                if ($schema -is [System.Object[]] -or ($schema -is [hashtable] -and
                (($schema.type -ine 'object') -and !$schema.object))) {
                    throw "Only properties of type Object can be associated with $($param.type)"
                }
                $param.schemas += $schema
            }
        }
        if ($DiscriminatorProperty) {
            if ($type.ToLower() -eq 'allof' ) {
                throw 'Discriminator parameter is not compatible with allOf'
            }
            $param.discriminator = @{
                'propertyName' = $DiscriminatorProperty
            }
            if ($DiscriminatorMapping) {
                $param.discriminator.mapping = $DiscriminatorMapping
            }
        } elseif ($DiscriminatorMapping) {
            throw 'Parameter -DiscriminatorMapping requires the -DiscriminatorProperty parameters'
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

.PARAMETER Component
An component schema name.
Alias: Reference

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
New-PodeOASchemaProperty -Name 'Config' -Component "MyConfigSchema"
#>
function New-PodeOASchemaProperty {
    [CmdletBinding(DefaultParameterSetName = 'Inbuilt')]
    param(

        [Parameter(ValueFromPipeline = $true, DontShow = $true )]
        [hashtable[]]
        $ParamsList,

        [Parameter()]
        [ValidatePattern('^[a-zA-Z0-9\.\-_]+$')]
        [string]
        $Name,

        [Parameter(Mandatory = $true)]
        [Alias('Reference')]
        [string]
        $Component,

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

        [hashtable]
        $Xml
    )
    begin {

        if ( !(Test-PodeOAComponentSchema -Name $Component)) {
            throw "The OpenApi component schema doesn't exist: $Component"
        }
        if (! $Name) {
            $Name = $Component
        }
        $param = @{
            name   = $Name
            type   = 'schema'
            schema = $Component
        }

        if ($PSCmdlet.ParameterSetName.ToLowerInvariant() -ieq 'array') {
            if ($Description ) {
                $param.description = $Description
            }

            if ($Array.IsPresent ) {
                $param.array = $Array.IsPresent
            }

            if ($Required.IsPresent ) {
                $param.required = $Required.IsPresent
            }

            if ($Deprecated.IsPresent ) {
                $param.deprecated = $Deprecated.IsPresent
            }

            if ($Nullable.IsPresent ) {
                $param['nullable'] = $Nullable.IsPresent
            }

            if ($WriteOnly.IsPresent ) {
                $param['writeOnly'] = $WriteOnly.IsPresent
            }

            if ($ReadOnly.IsPresent ) {
                $param['readOnly'] = $ReadOnly.IsPresent
            }

            if ($Example ) {
                $param['example'] = $Example
            }

            if ($UniqueItems.IsPresent ) {
                $param.uniqueItems = $UniqueItems.IsPresent
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
            $ex = [System.Exception]::new("New-PodeOASchemaProperty $Component - Description can only be applied to an array")
            $ex | Write-PodeErrorLog -Level Warning
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
Alias: Reference

.PARAMETER ContentType
The content-types to be use with  component schema

.PARAMETER ContentSchema
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
        [Alias('Reference')]
        [string]
        $ComponentParameter,

        [Parameter( ParameterSetName = 'Schema')]
        [Parameter(ParameterSetName = 'Properties')]
        [Parameter(ParameterSetName = 'ContentSchema')]
        [Parameter(  ParameterSetName = 'ContentProperties')]
        [string]
        $Name,

        [Parameter(Mandatory = $true, ParameterSetName = 'Schema')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ContentSchema')]
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
        $Deprecated
    )

    if ($PSCmdlet.ParameterSetName -ieq 'ContentSchema' -or $PSCmdlet.ParameterSetName -ieq 'Schema') {
        if (Test-PodeIsEmpty $Schema) {
            return $null
        }
        if (!(Test-PodeOAComponentSchema -Name $Schema )) {
            throw "The OpenApi component request parameter doesn't exist: $($Schema )"
        }
        $Property = $PodeContext.Server.OpenAPI.components.schemas[$Schema ]
        if (!$Name ) {
            $Name = $Schema
        }
        $prop = @{
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
            $prop.content = @{
                $ContentType = @{
                    schema = @{
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
            $prop.schema = @{
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
        #    if (@('array', 'object') -icontains $Property.type) {
        #   throw 'OpenApi request parameter cannot be an array of object'
        #  }

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
        $prop = @{
            in   = $In.ToLowerInvariant()
            name = $Name
        }
        $sch = @{}
        if ($Property.Array) {
            $sch.type = 'array'
            $sch.items = @{
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
            $prop.content = @{
                $ContentType = @{
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
                if ($Property.Array) {
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
        Throw "If the parameter location is 'Path', the parameter -Required and its value MUST be true"
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
        $ExternalDoc,

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

        if ($ExternalDocs) {
            if ( !(Test-PodeOAExternalDoc -Name $ExternalDoc)) {
                throw "The ExternalDoc doesn't exist: $ExternalDoc"
            }
            $r.OpenApi.externalDocs = $PodeContext.Server.OpenAPI.hiddenComponents.externalDocs[$ExternalDoc]
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
        [ValidatePattern('^[a-zA-Z0-9\.\-_]+$')]
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
        [ValidatePattern('^[a-zA-Z0-9\.\-_]+$')]
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

.EXAMPLE
Add-PodeOAInfo -TermsOfService 'http://swagger.io/terms/' -License 'Apache 2.0' -LicenseUrl 'http://www.apache.org/licenses/LICENSE-2.0.html' -ContactName 'API Support' -ContactEmail 'apiteam@swagger.io' -ContactUrl 'http://example.com/support'
#>

function Add-PodeOAInfo {
    param(
        [Parameter()]
        [string]
        $Title,

        [Parameter()]
        [ValidatePattern('^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$')]
        [string]
        $Version ,

        [Parameter()]
        [string]
        $Description,

        [Parameter()]
        [ValidateScript({ $_ -imatch '^https?://.+' })]
        [string]
        $TermsOfService,

        [Parameter( )]
        [string]
        $LicenseName,

        [Parameter( )]
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

    $Info = @{}

    if ($LicenseName) {
        $Info.license = @{
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
    } elseif (  $PodeContext.Server.OpenAPI.info.title) {
        $Info.title = $PodeContext.Server.OpenAPI.info.title
    } else {
        throw 'The OpenAPI property info.title is required. Use -Title'
    }

    if ($Version) {
        $Info.version = $Version
    } elseif ( $PodeContext.Server.OpenAPI.info.version) {
        $Info.version = $PodeContext.Server.OpenAPI.info.version
    } else {
        $Info.version = '1.0.0'
    }

    if ($Description ) {
        $Info.description = $Description
    } elseif ( $PodeContext.Server.OpenAPI.info.description) {
        $Info.description = $PodeContext.Server.OpenAPI.info.description
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
    $PodeContext.Server.OpenAPI.info = $Info

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

.PARAMETER Value
Embedded literal example. The  value Parameter and ExternalValue parameter are mutually exclusive.
To represent examples of media types that cannot naturally represented in JSON or YAML, use a string value to contain the example, escaping where necessary.

.PARAMETER ExternalValue
A URL that points to the literal example. This provides the capability to reference examples that cannot easily be included in JSON or YAML documents.
The -Value parameter and -ExternalValue parameter are mutually exclusive.                                |


.EXAMPLE
 New-PodeOAExample -MediaType 'text/plain' -Name 'user' -Summary = 'User Example in Plain text' -ExternalValue = 'http://foo.bar/examples/user-example.txt'
.EXAMPLE
 $example =
    New-PodeOAExample -MediaType 'application/json' -Name 'user' -Summary = 'User Example' -ExternalValue = 'http://foo.bar/examples/user-example.json'  |
        New-PodeOAExample -MediaType 'application/xml' -Name 'user' -Summary = 'User Example in XML' -ExternalValue = 'http://foo.bar/examples/user-example.xml'

#>
function New-PodeOAExample {
    [CmdletBinding(DefaultParameterSetName = 'Inbuilt')]
    [OutputType([System.Collections.Specialized.OrderedDictionary ])]

    param(
        [Parameter(ValueFromPipeline = $true, DontShow = $true, ParameterSetName = 'Inbuilt')]
        [Parameter(ValueFromPipeline = $true, DontShow = $true, ParameterSetName = 'Reference')]
        [System.Collections.Specialized.OrderedDictionary ]
        $ParamsList,

        [Parameter( )]
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
        $Reference
    )
    begin {
        if ($PSCmdlet.ParameterSetName -ieq 'Reference') {
            if ( !(Test-PodeOAComponentExample -Name $Reference)) {
                throw "The OpenApi component example doesn't exist: $Reference"
            }
            $Name = $Reference
            $Example = @{'$ref' = "#/components/examples/$Reference" }
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
            $param.$MediaType = @{
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
Adds a reusable example component.

.DESCRIPTION
Adds a reusable example component.

.PARAMETER Name
The Name of the Example.


.PARAMETER Summary
Short description for the example

.PARAMETER Description
Long description for the example.

.PARAMETER Value
Embedded literal example. The  value Parameter and ExternalValue parameter are mutually exclusive.
To represent examples of media types that cannot naturally represented in JSON or YAML, use a string value to contain the example, escaping where necessary.

.PARAMETER ExternalValue
A URL that points to the literal example. This provides the capability to reference examples that cannot easily be included in JSON or YAML documents.
The -Value parameter and -ExternalValue parameter are mutually exclusive.                                |

.EXAMPLE
Add-PodeOAComponentExample -name 'frog-example' -Summary "An example of a frog with a cat's name" -Value @{name = 'Jaguar'; petType = 'Panthera'; color = 'Lion'; gender = 'Male'; breed = 'Mantella Baroni' }

#>
function Add-PodeOAComponentExample {
    [CmdletBinding(DefaultParameterSetName = 'Value')]
    param(

        [Parameter(Mandatory = $true)]
        [Alias('Title')]
        [ValidatePattern('^[a-zA-Z0-9\.\-_]+$')]
        [string]
        $Name,

        [string]
        $Summary,

        [Parameter()]
        [string]
        $Description,

        [Parameter(Mandatory = $true, ParameterSetName = 'Value')]
        [object]
        $Value,

        [Parameter(Mandatory = $true, ParameterSetName = 'ExternalValue')]
        [string]
        $ExternalValue
    )
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
    }
    $PodeContext.Server.OpenAPI.components.examples[$Name] = $Example
}




<#
.SYNOPSIS
Adds a single encoding definition applied to a single schema property.

.DESCRIPTION
A single encoding definition applied to a single schema property.

.PARAMETER  encodingList
Used by pipe

.PARAMETER Name
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
        [Alias('Title')]
        [ValidatePattern('^[a-zA-Z0-9\.\-_]+$')]
        [string]
        $Name,

        [Parameter()]
        [string]
        $ContentType,

        [Parameter()]
        [hashtable[]]
        $Headers,

        [Parameter()]
        [ValidateSet('Simple', 'Label', 'Matrix', 'Query', 'Form', 'SpaceDelimited', 'PipeDelimited', 'DeepObject' )]
        [string]
        $Style,

        [Parameter()]
        [switch]
        $Explode,

        [Parameter()]
        [switch]
        $AllowReserved
    )
    begin {

        $encoding = [ordered]@{
            $Name = @{}
        }
        if ($ContentType) {
            $encoding.$Name.contentType = $ContentType
        }
        if ($Style) {
            $encoding.$Name.style = $Style
        }

        if ($Headers) {
            $encoding.$Name.headers = $Headers
        }

        if ($Explode.IsPresent ) {
            $encoding.$Name.explode = $Explode.IsPresent
        }
        if ($AllowReserved.IsPresent ) {
            $encoding.$Name.allowReserved = $AllowReserved.IsPresent
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

.DESCRIPTION
    The Add-PodeOACallBacks function is used for defining OpenAPI callback configurations for routes in a Pode server.
    It enables setting up API specifications including detailed parameters, request body schemas, and response structures for various HTTP methods.

.PARAMETER Path
    Specifies the callback path, usually a relative URL.
    The key that identifies the Path Item Object is a runtime expression evaluated in the context of a runtime HTTP request/response to identify the URL for the callback request.
    A simple example is `$request.body#/url`.
    The runtime expression allows complete access to the HTTP message, including any part of a body that a JSON Pointer (RFC6901) can reference.
    More information on JSON Pointer can be found at [RFC6901](https://datatracker.ietf.org/doc/html/rfc6901).

.PARAMETER Title
    Alias for 'Name'. A unique identifier for the callback.
    It must be a valid string of alphanumeric characters, periods (.), hyphens (-), and underscores (_).

.PARAMETER Method
    Defines the HTTP method for the callback (e.g., GET, POST, PUT). Supports standard HTTP methods and a wildcard (*) for all methods.

.PARAMETER RequestBody
    Defines the schema of the request body. Can be set using New-PodeOARequestBody.

.PARAMETER Response
    Defines the possible responses for the callback. Can be set using New-PodeOAResponse.

.EXAMPLE
    Add-PodeOACallBacks -Title 'test' -Path '{$request.body#/id}' -Method Post `
        -RequestBody (New-PodeOARequestBody -Content @{'*/*' = (New-PodeOAStringProperty -Name 'id')}) `
        -Response (
            New-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -ContentArray -Content (@{'application/json' = 'Pet'; 'application/xml' = 'Pet'}) |
            New-PodeOAResponse -StatusCode 400 -Description 'Invalid ID supplied' |
            New-PodeOAResponse -StatusCode 404 -Description 'Pet not found' |
            New-PodeOAResponse -Default -Description 'Something is wrong'
        )
    This example demonstrates adding a POST callback to handle a request body and define various responses based on different status codes.

.NOTES
    Ensure that the provided parameters match the expected schema and formats of Pode and OpenAPI specifications.
    The function is useful for dynamically configuring and documenting API callbacks in a Pode server environment.
#>

function Add-PodeOACallBacks {
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [hashtable[]]
        $Route,

        [Parameter(Mandatory = $true)]
        [Alias('Title')]
        [ValidatePattern('^[a-zA-Z0-9\.\-_]+$')]
        [string]
        $Name,

        [Parameter(Mandatory = $true)]
        [string]
        $Path,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Connect', 'Delete', 'Get', 'Head', 'Merge', 'Options', 'Patch', 'Post', 'Put', 'Trace', '*')]
        [string]
        $Method,

        [Parameter()]
        [hashtable[]]
        $Parameters,

        [Parameter()]
        [hashtable]
        $RequestBody,

        [Parameter()]
        [System.Collections.Specialized.OrderedDictionary]
        $Responses,

        [switch]
        $PassThru
    )
    $_method = $Method.ToLower()
    foreach ($r in @($Route)) {
        $r.OpenApi.CallBacks = [ordered]@{
            $Name = [ordered]@{
                "'$Path'" = [ordered]@{
                    $_method = [ordered]@{}
                }
            }
        }
        if ($RequestBody) {
            $r.OpenApi.CallBacks.$Name."'$Path'".$_method.requestBody = $RequestBody
        }
        if ($Responses) {
            $r.OpenApi.CallBacks.$Name."'$Path'".$_method.responses = $Responses
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

.PARAMETER Route
The route to add the response definition. This is an alternative method to Add-PodeOAResponse without piping

.PARAMETER StatusCode
The HTTP StatusCode for the response.To define a range of response codes, this field MAY contain the uppercase wildcard character `X`.
For example, `2XX` represents all response codes between `[200-299]`. Only the following range definitions are allowed: `1XX`, `2XX`, `3XX`, `4XX`, and `5XX`.
If a response is defined using an explicit code, the explicit code definition takes precedence over the range definition for that code.

.PARAMETER Content
The content-types and schema the response returns (the schema is created using the Property functions).
Alias: ContentSchemas

.PARAMETER Headers
The header name and schema the response returns (the schema is created using Add-PodeOAComponentHeaderSchema cmd-let).
Alias: HeaderSchemas

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

.EXAMPLE
New-PodeOAResponse -StatusCode 200 -Content @{ 'application/json' = (New-PodeOAIntProperty -Name 'userId' -Object) }

.EXAMPLE
New-PodeOAResponse -StatusCode 200 -Content @{ 'application/json' = 'UserIdSchema' }

.EXAMPLE
New-PodeOAResponse -StatusCode 200 -Reference 'OKResponse'

.EXAMPLE
Add-PodeOACallBacks -Title 'test' -Path '$request.body#/id' -Method Post  -RequestBody (
        New-PodeOARequestBody -Content @{'*/*' = (New-PodeOAStringProperty -Name 'id') }
    ) `
    -Response (
        New-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -ContentArray -Content (@{  'application/json' = 'Pet' ; 'application/xml' = 'Pet' }) |
            New-PodeOAResponse -StatusCode 400 -Description 'Invalid ID supplied' |
                New-PodeOAResponse -StatusCode 404 -Description 'Pet not found' |
            New-PodeOAResponse -Default   -Description 'Something is wrong'
            )
#>

function New-PodeOAResponse {
    [CmdletBinding(DefaultParameterSetName = 'Schema')]
    param(
        [Parameter(ValueFromPipeline = $true , DontShow = $true )]
        [System.Collections.Specialized.OrderedDictionary ]
        $ResponseList,

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

        [Parameter()]
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
        [switch]
        $ContentArray,

        [Parameter(ParameterSetName = 'Schema')]
        [Parameter(ParameterSetName = 'SchemaDefault')]
        [switch]
        $HeaderArray,

        [Parameter(ParameterSetName = 'Schema')]
        [Parameter(ParameterSetName = 'SchemaDefault')]
        [System.Collections.Specialized.OrderedDictionary ]
        $Links
    )
    begin {
        # override status code with default
        if ($Default) {
            $code = 'default'
        } else {
            $code = "$($StatusCode)"
        }

        $response = [ordered]@{
            $code = New-PodeOResponseInternal -Params $PSBoundParameters
        }

    }
    process {
    }
    end {
        if ($Route){
            foreach ($r in @($Route)) {
                $r.OpenApi.Responses[$code] = $response
            }
        }else{
        if ($ResponseList) {
            $response.GetEnumerator() | ForEach-Object { $ResponseList[$_.Key] = $_.Value }
            return $ResponseList
        } else {
            return [System.Collections.Specialized.OrderedDictionary] $response
        }}
    }

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

.PARAMETER Parameters
    A map representing parameters to pass to an operation as specified with `operationId` or identified via `operationRef`.
    The key is the parameter name to be used, whereas the value can be a constant or an expression to be evaluated and passed to the linked operation.
    Parameter names can be qualified using the parameter location syntax `[{in}.]{name}` for operations that use the same parameter name in different locations (e.g., path.id).

.PARAMETER RequestBody
    A string representing the request body to use as a request body when calling the target.

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

        [Parameter(Mandatory = $true)]
        [Alias('Title')]
        [ValidatePattern('^[a-zA-Z0-9\.\-_]+$')]
        [string]
        $Name,

        [Parameter()]
        [string]
        $Description,

        [Parameter(Mandatory = $true, ParameterSetName = 'OperationId')]
        [string]
        $OperationId,

        [Parameter(Mandatory = $true, ParameterSetName = 'OperationRef')]
        [string]
        $OperationRef,

        [Parameter()]
        [hashtable]
        $Parameters,

        [Parameter()]
        [string]
        $RequestBody

    )
    begin {

        $link = [ordered]@{$Name = [ordered]@{} }
        if ($Description) {
            $link.$Name.description = $Description
        }
        if ($OperationId) {
            $link.$Name.operationId = $OperationId
        }
        if ($OperationRef) {
            $link.$Name.operationRef = $OperationRef
        }
        if ($OperationRef) {
            $link.$Name.operationRef = $OperationRef
        }
        if ($Parameters) {
            $link.$Name.parameters = $Parameters
        }
        if ($RequestBody) {
            $link.$Name.requestBody = $RequestBody
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



if (!(Test-Path Alias:Enable-PodeOpenApiViewer)) {
    New-Alias Enable-PodeOpenApiViewer -Value  Enable-PodeOAViewer
}

if (!(Test-Path Alias:Enable-PodeOA)) {
    New-Alias Enable-PodeOA -Value Enable-PodeOpenApi
}

if (!(Test-Path Alias:Get-PodeOpenApiDefinition)) {
    New-Alias Get-PodeOpenApiDefinition -Value Get-PodeOADefinition
}
