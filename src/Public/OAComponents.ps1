
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
The header name and schema the response returns (the schema is created using the Add-PodeOAComponentHeader cmdlet).

.PARAMETER Description
The Description of the response.

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
        [System.Collections.Specialized.OrderedDictionary ]
        $Links
    )

    $PodeContext.Server.OpenAPI.default.components.responses[$Name] = New-PodeOResponseInternal -Params $PSBoundParameters
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

.PARAMETER Component
The Component definition (the schema is created using the Property functions).

.PARAMETER Description
A description of the schema

.EXAMPLE
Add-PodeOAComponentSchema -Name 'UserIdSchema' -Component (New-PodeOAIntProperty -Name 'userId' -Object)
#>
function Add-PodeOAComponentSchema {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[a-zA-Z0-9\.\-_]+$')]
        [string]
        $Name,

        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [Alias('Schema')]
        [hashtable]
        $Component,

        [string]
        $Description
    )
    $PodeContext.Server.OpenAPI.default.components.schemas[$Name] = ($Component | ConvertTo-PodeOASchemaProperty)
    if ($PodeContext.Server.OpenAPI.default.hiddenComponents.schemaValidation) {
        $modifiedComponent = ($Component | ConvertTo-PodeOASchemaProperty) | Resolve-PodeOAReferences
        #Resolve-PodeOAReferences -ComponentSchema  $modifiedSchema
        $PodeContext.Server.OpenAPI.default.hiddenComponents.schemaJson[$Name] = @{
            'schema' = $modifiedComponent
            'json'   = $modifiedComponent | ConvertTo-Json -depth $PodeContext.Server.OpenAPI.default.hiddenComponents.depth
        }
    }
    if ($Description) {
        $PodeContext.Server.OpenAPI.default.components.schemas[$Name].description = $Description
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
Add-PodeOAComponentHeader -Name 'UserIdSchema' -Schema (New-PodeOAIntProperty -Name 'userId' -Object)
#>
function Add-PodeOAComponentHeader {
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

    $PodeContext.Server.OpenAPI.default.hiddenComponents.headerSchemas[$Name] = ($Schema | ConvertTo-PodeOASchemaProperty)

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
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[a-zA-Z0-9\.\-_]+$')]
        [string]
        $Name,

        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [Alias('ContentSchemas')]
        [hashtable]
        $Content,

        [Parameter()]
        [string]
        $Description  ,

        [Parameter()]
        [switch]
        $Required
    )

    $param = [ordered]@{ content = ($Content | ConvertTo-PodeOAObjectSchema) }

    if ($Required.IsPresent) {
        $param['required'] = $Required.IsPresent
    }

    if ( $Description) {
        $param['description'] = $Description
    }
    $PodeContext.Server.OpenAPI.default.components.requestBodies[$Name] = $param
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
    $PodeContext.Server.OpenAPI.default.components.parameters[$Name] = $Parameter
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

    $PodeContext.Server.OpenAPI.default.components.examples[$Name] = $Example
}




<#
.SYNOPSIS
    Adds a reusable response link.

.DESCRIPTION
    The Add-PodeOAComponentResponseLink function is designed to add a new reusable response link

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
    Add-PodeOAComponentResponseLink   -Name 'address' -OperationId 'getUserByName' -Parameters @{'username' = '$request.path.username'}
    Add-PodeOAResponse -StatusCode 200 -Content @{'application/json' = 'User'} -Links 'address'
    This example demonstrates creating and adding a link named 'address' associated with the operation 'getUserByName' to an OrderedDictionary of links. The updated dictionary is then used in the 'Add-PodeOAResponse' function to define a response with a status code of 200.

.NOTES
    The function supports adding links either by specifying an 'OperationId' or an 'OperationRef', making it versatile for different OpenAPI specification needs.
    It's important to match the parameters and response structures as per the OpenAPI specification to ensure the correct functionality of the API documentation.
#>

function Add-PodeOAComponentResponseLink {
    [CmdletBinding(DefaultParameterSetName = 'OperationId')]
    param(

        [Parameter(Mandatory = $true)]
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
    $PodeContext.Server.OpenAPI.default.components.links[$Name] = New-PodeOAResponseLinkInternal -Params $PSBoundParameters
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

