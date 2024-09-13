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

.PARAMETER Content
The content-types and schema the response returns (the schema is created using the Property functions).

.PARAMETER Headers
The header name and schema the response returns (the schema is created using the Add-PodeOAComponentHeader cmdlet).

.PARAMETER Description
The Description of the response.

.PARAMETER Reference
A Reference Name of an existing component response to use.

.PARAMETER Links
A Response link definition

.PARAMETER DefinitionTag
An Array of strings representing the unique tag for the API specification.
This tag helps in distinguishing between different versions or types of API specifications within the application.
You can use this tag to reference the specific API documentation, schema, or version that your function interacts with.

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
        $Links,

        [string[]]
        $DefinitionTag
    )
    $DefinitionTag = Test-PodeOADefinitionTag -Tag $DefinitionTag
    foreach ($tag in $DefinitionTag) {
        $PodeContext.Server.OpenAPI.Definitions[$tag].components.responses[$Name] = New-PodeOResponseInternal -DefinitionTag $tag  -Params $PSBoundParameters
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

.PARAMETER Component
The Component definition (the schema is created using the Property functions).

.PARAMETER Description
A description of the schema

.PARAMETER DefinitionTag
An Array of strings representing the unique tag for the API specification.
This tag helps in distinguishing between different versions or types of API specifications within the application.
You can use this tag to reference the specific API documentation, schema, or version that your function interacts with.

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
        $Description,

        [string[]]
        $DefinitionTag
    )

    $DefinitionTag = Test-PodeOADefinitionTag -Tag $DefinitionTag

    foreach ($tag in $DefinitionTag) {
        $PodeContext.Server.OpenAPI.Definitions[$tag].components.schemas[$Name] = ($Component | ConvertTo-PodeOASchemaProperty -DefinitionTag $tag)
        if ($PodeContext.Server.OpenAPI.Definitions[$tag].hiddenComponents.schemaValidation) {
            try {
                $modifiedComponent = ($Component | ConvertTo-PodeOASchemaProperty  -DefinitionTag $tag) | Resolve-PodeOAReference -DefinitionTag $tag
                $PodeContext.Server.OpenAPI.Definitions[$tag].hiddenComponents.schemaJson[$Name] = @{
                    'available' = $true
                    'schema'    = $modifiedComponent
                    'json'      = $modifiedComponent | ConvertTo-Json -depth $PodeContext.Server.OpenAPI.Definitions[$tag].hiddenComponents.depth
                }
            }
            catch {
                if ($_.ToString().StartsWith('Validation of schema with')) {
                    $PodeContext.Server.OpenAPI.Definitions[$tag].hiddenComponents.schemaJson[$Name] = @{
                        'available' = $false
                    }
                }
            }
        }

        if ($Description) {
            $PodeContext.Server.OpenAPI.Definitions[$tag].components.schemas[$Name].description = $Description
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

.PARAMETER Description
A description of the header

.PARAMETER DefinitionTag
An Array of strings representing the unique tag for the API specification.
This tag helps in distinguishing between different versions or types of API specifications within the application.
You can use this tag to reference the specific API documentation, schema, or version that your function interacts with.

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

        [Parameter()]
        [string]
        $Description,

        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [hashtable]
        $Schema,

        [string[]]
        $DefinitionTag
    )

    $DefinitionTag = Test-PodeOADefinitionTag -Tag $DefinitionTag

    foreach ($tag in $DefinitionTag) {
        $param = [ordered]@{
            'schema' = ($Schema | ConvertTo-PodeOASchemaProperty -NoDescription -DefinitionTag $tag)
        }
        if ( $Description) {
            $param['description'] = $Description
        }
        $PodeContext.Server.OpenAPI.Definitions[$tag].components.headers[$Name] = $param
    }

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

.PARAMETER Content
The content-types and schema the request body accepts (the schema is created using the Property functions).

.PARAMETER Description
A Description of the request body.

.PARAMETER Required
If supplied, the request body will be flagged as required.

.PARAMETER DefinitionTag
An Array of strings representing the unique tag for the API specification.
This tag helps in distinguishing between different versions or types of API specifications within the application.
You can use this tag to reference the specific API documentation, schema, or version that your function interacts with.

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
        $Required,

        [string[]]
        $DefinitionTag
    )

    $DefinitionTag = Test-PodeOADefinitionTag -Tag $DefinitionTag

    foreach ($tag in $DefinitionTag) {
        $param = [ordered]@{ content = ($Content | ConvertTo-PodeOAObjectSchema -DefinitionTag $tag) }

        if ($Required.IsPresent) {
            $param['required'] = $Required.IsPresent
        }

        if ( $Description) {
            $param['description'] = $Description
        }
        $PodeContext.Server.OpenAPI.Definitions[$tag].components.requestBodies[$Name] = $param
    }

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

.PARAMETER DefinitionTag
An Array of strings representing the unique tag for the API specification.
This tag helps in distinguishing between different versions or types of API specifications within the application.
You can use this tag to reference the specific API documentation, schema, or version that your function interacts with.

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
        $Parameter,

        [string[]]
        $DefinitionTag
    )

    $DefinitionTag = Test-PodeOADefinitionTag -Tag $DefinitionTag

    foreach ($tag in $DefinitionTag) {
        if ([string]::IsNullOrWhiteSpace($Name)) {
            if ($Parameter.name) {
                $Name = $Parameter.name
            }
            else {
                # The Parameter has no name. Please provide a name to this component using the `Name` parameter
                throw ($PodeLocale.parameterHasNoNameExceptionMessage)
            }
        }
        $PodeContext.Server.OpenAPI.Definitions[$tag].components.parameters[$Name] = $Parameter
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
The -Value parameter and -ExternalValue parameter are mutually exclusive.

.PARAMETER DefinitionTag
An Array of strings representing the unique tag for the API specification.
This tag helps in distinguishing between different versions or types of API specifications within the application.
You can use this tag to reference the specific API documentation, schema, or version that your function interacts with.                           |

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
        $ExternalValue,

        [string[]]
        $DefinitionTag
    )
    $DefinitionTag = Test-PodeOADefinitionTag -Tag $DefinitionTag
    foreach ($tag in $DefinitionTag) {
        $Example = [ordered]@{ }
        if ($Summary) {
            $Example.summary = $Summary
        }
        if ($Description) {
            $Example.description = $Description
        }
        if ($Value) {
            $Example.value = $Value
        }
        elseif ($ExternalValue) {
            $Example.externalValue = $ExternalValue
        }

        $PodeContext.Server.OpenAPI.Definitions[$tag].components.examples[$Name] = $Example
    }
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

.PARAMETER DefinitionTag
An Array of strings representing the unique tag for the API specification.
This tag helps in distinguishing between different versions or types of API specifications within the application.
You can use this tag to reference the specific API documentation, schema, or version that your function interacts with.

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
        $RequestBody,

        [string[]]
        $DefinitionTag

    )
    $DefinitionTag = Test-PodeOADefinitionTag -Tag $DefinitionTag
    foreach ($tag in $DefinitionTag) {
        $PodeContext.Server.OpenAPI.Definitions[$tag].components.links[$Name] = New-PodeOAResponseLinkInternal -Params $PSBoundParameters
    }
}




<#
.SYNOPSIS
    Adds OpenAPI reusable callback configurations.

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

.PARAMETER Method
    Defines the HTTP method for the callback (e.g., GET, POST, PUT). Supports standard HTTP methods and a wildcard (*) for all methods.

.PARAMETER Parameters
The Parameter definitions the request uses (from ConvertTo-PodeOAParameter).

.PARAMETER RequestBody
Defines the schema of the request body. Can be set using New-PodeOARequestBody.

.PARAMETER Responses
Defines the possible responses for the callback. Can be set using New-PodeOAResponse.

.PARAMETER DefinitionTag
An Array of strings representing the unique tag for the API specification.
This tag helps in distinguishing between different versions or types of API specifications within the application.
You can use this tag to reference the specific API documentation, schema, or version that your function interacts with.

.EXAMPLE
Add-PodeOAComponentCallBack -Title 'test' -Path '{$request.body#/id}' -Method Post `
    -RequestBody (New-PodeOARequestBody -Content @{'*/*' = (New-PodeOAStringProperty -Name 'id')}) `
    -Response (
        New-PodeOAResponse -StatusCode 200 -Description 'Successful operation'  -Content (New-PodeOAContentMediaType -ContentType 'application/json','application/xml' -Content 'Pet'  -Array)
        New-PodeOAResponse -StatusCode 400 -Description 'Invalid ID supplied' |
        New-PodeOAResponse -StatusCode 404 -Description 'Pet not found' |
        New-PodeOAResponse -Default -Description 'Something is wrong'
    )
Add-PodeOACallBack -Reference 'test'
    This example demonstrates adding a POST callback to handle a request body and define various responses based on different status codes.


.NOTES
Ensure that the provided parameters match the expected schema and formats of Pode and OpenAPI specifications.
The function is useful for dynamically configuring and documenting API callbacks in a Pode server environment.
#>

function Add-PodeOAComponentCallBack {
    param (

        [Parameter(Mandatory = $true)]
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

        [hashtable[]]
        $Parameters,

        [hashtable]
        $RequestBody,

        [hashtable]
        $Responses,

        [string[]]
        $DefinitionTag
    )
    $DefinitionTag = Test-PodeOADefinitionTag -Tag $DefinitionTag
    foreach ($tag in $DefinitionTag) {
        $PodeContext.Server.OpenAPI.Definitions[$tag].components.callbacks.$Name = New-PodeOAComponentCallBackInternal -Params $PSBoundParameters -DefinitionTag $tag
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
    Alias for 'Name'. A unique identifier for the route.
    It must be a valid string of alphanumeric characters, periods (.), hyphens (-), and underscores (_).

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
This tag helps in distinguishing between different versions or types of API specifications within the application.
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
    Add-PodeOAComponentPathItem -PassThru -Method Get -Path '/peta/:id'  -ScriptBlock {
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
function Add-PodeOAComponentPathItem {
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

    $_definitionTag = Test-PodeOADefinitionTag -Tag $DefinitionTag

    $refRoute = @{
        Method      = $Method.ToLower()
        NotPrepared = $true
        OpenApi     = @{
            Responses          = $null
            Parameters         = $null
            RequestBody        = $null
            callbacks          = @{}
            Authentication     = @()
            Servers            = @()
            DefinitionTag      = $_definitionTag
            IsDefTagConfigured = ($null -ne $DefinitionTag) #Definition Tag has been configured (Not default)
        }
    }
    foreach ($tag in $_definitionTag) {
        if (Test-PodeOAVersion -Version 3.0 -DefinitionTag $tag  ) {
            # The 'pathItems' reusable component feature is not available in OpenAPI v3.0.
            throw ($PodeLocale.reusableComponentPathItemsNotAvailableInOpenApi30ExceptionMessage)
        }
        #add the default OpenApi responses
        if ( $PodeContext.Server.OpenAPI.Definitions[$tag].hiddenComponents.defaultResponses) {
            $refRoute.OpenApi.Responses = Get-PodeOrderedDictionaryClone -Source $PodeContext.Server.OpenAPI.Definitions[$tag].hiddenComponents.defaultResponses
        }
        $PodeContext.Server.OpenAPI.Definitions[$tag].components.pathItems[$Name] = $refRoute
    }

    if ($PassThru) {
        return $refRoute
    }
}





<#
.SYNOPSIS
Check the OpenAPI version

.DESCRIPTION
Check the OpenAPI version for a specific OpenAPI Definition


.PARAMETER Version
The version number to compare

.PARAMETER DefinitionTag
An Array of strings representing the unique tag for the API specification.
This tag helps in distinguishing between different versions or types of API specifications within the application.
You can use this tag to reference the specific API documentation, schema, or version that your function interacts with.

.EXAMPLE
Test-PodeOAVersion -Version 3.1 -DefinitionTag 'default'
#>

function Test-PodeOAVersion {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet( '3.1' , '3.0' )]
        [string]
        $Version,

        [Parameter(Mandatory = $true)]
        [string[] ]
        $DefinitionTag
    )

    return $PodeContext.Server.OpenAPI.Definitions[$DefinitionTag].hiddenComponents.version -eq $Version
}

<#
.SYNOPSIS
Check the OpenAPI component exist

.DESCRIPTION
Check the OpenAPI component exist

.PARAMETER Field
The component type

.PARAMETER Name
The component Name

.PARAMETER DefinitionTag
An Array of strings representing the unique tag for the API specification.
This tag helps in distinguishing between different versions or types of API specifications within the application.
You can use this tag to reference the specific API documentation, schema, or version that your function interacts with.

.EXAMPLE
Test-PodeOAComponent -Field 'responses' -Name 'myresponse' -DefinitionTag 'default'
#>

function Test-PodeOAComponent {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet( 'schemas' , 'responses' , 'parameters' , 'examples' , 'requestBodies' , 'headers' , 'securitySchemes' , 'links' , 'callbacks' , 'pathItems' )]
        [string]
        $Field,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name,

        [string[]]
        $DefinitionTag
    )

    $DefinitionTag = Test-PodeOADefinitionTag -Tag $DefinitionTag

    foreach ($tag in $DefinitionTag) {
        if (!($PodeContext.Server.OpenAPI.Definitions[$tag].components[$field].keys -ccontains $Name)) {
            return $false
        }
    }
    if (!$ThrowException.IsPresent) {
        return $true
    }
}

<#
.SYNOPSIS
Remove an OpenAPI component if exist

.DESCRIPTION
Remove an OpenAPI component if exist

.PARAMETER Field
The component type

.PARAMETER Name
The component Name

.PARAMETER DefinitionTag
An Array of strings representing the unique tag for the API specification.
This tag helps in distinguishing between different versions or types of API specifications within the application.
You can use this tag to reference the specific API documentation, schema, or version that your function interacts with.

.EXAMPLE
Remove-PodeOAComponent -Field 'responses' -Name 'myresponse' -DefinitionTag 'default'
#>
function Remove-PodeOAComponent {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet( 'schemas' , 'responses' , 'parameters' , 'examples' , 'requestBodies' , 'headers' , 'securitySchemes' , 'links' , 'callbacks' , 'pathItems'  )]
        [string]
        $Field,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name,

        [string[]]
        $DefinitionTag
    )
    $DefinitionTag = Test-PodeOADefinitionTag -Tag $DefinitionTag
    foreach ($tag in $DefinitionTag) {
        if (!($PodeContext.Server.OpenAPI.Definitions[$tag].components[$field ].keys -ccontains $Name)) {
            $PodeContext.Server.OpenAPI.Definitions[$tag].components[$field ].remove($Name)
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

