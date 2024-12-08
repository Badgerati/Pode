<#
.SYNOPSIS
    Converts content into an OpenAPI schema object format.

.DESCRIPTION
    The ConvertTo-PodeOAObjectSchema function takes a hashtable representing content and converts it into a format suitable for OpenAPI schema objects.
    It validates the content types, processes array structures, and converts each property or reference into the appropriate OpenAPI schema format.
    The function is designed to handle complex content structures for OpenAPI documentation within the Pode framework.

.PARAMETER Content
    A hashtable representing the content to be converted into an OpenAPI schema object. The content can include various types and structures.

.PARAMETER Properties
    A switch to indicate if the content represents properties of an object schema.

.PARAMETER DefinitionTag
    A string representing the definition tag to be used in the conversion process. This tag is essential for correctly formatting the content according to OpenAPI specifications.

.EXAMPLE
    $schemaObject = ConvertTo-PodeOAObjectSchema -Content $myContent -DefinitionTag 'myTag'

    Converts a hashtable of content into an OpenAPI schema object using the definition tag 'myTag'.

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function ConvertTo-PodeOAObjectSchema {
    param(
        [Parameter( Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [hashtable]
        $Content,

        [Parameter()]
        [switch]
        $Properties,

        [Parameter(Mandatory = $true)]
        [string ]
        $DefinitionTag

    )
    begin {
        $pipelineItemCount = 0  # Initialize counter to track items in the pipeline.
    }

    process {
        $pipelineItemCount++  # Increment the counter for each item in the pipeline.
    }

    end {
        # Throw an error if more than one item is passed in the pipeline.
        if ($pipelineItemCount -gt 1) {
            throw ($PodeLocale.fnDoesNotAcceptArrayAsPipelineInputExceptionMessage -f $($MyInvocation.MyCommand.Name))
        }

        # Ensure all content types are valid MIME types.
        foreach ($type in $Content.Keys) {
            if ($type -inotmatch '^(application|audio|image|message|model|multipart|text|video|\*)\/[\w\.\-\*]+(;[\s]*(charset|boundary)=[\w\.\-\*]+)*$|^"\*\/\*"$') {
                # Invalid content-type found for schema: $($type)
                throw ($PodeLocale.invalidContentTypeForSchemaExceptionMessage -f $type)
            }
        }

        # Manage a specific case where a generic schema conversion issue may arise.
        if ($Content.ContainsKey('*/*')) {
            $Content['"*/*"'] = $Content['*/*']  # Adjust the key format for schema compatibility.
            $Content.Remove('*/*')
        }

        # Initialize an empty hashtable for the schema object.
        $obj = [ordered]@{}

        # Get all the content keys (MIME types) to iterate through.
        $types = [string[]]$Content.Keys
        foreach ($type in $types) {
            # Initialize schema structure for each type.
            $obj[$type] = [ordered]@{}

            # Handle file upload content, arrays, and shared component schema references.
            if ($Content[$type].__upload) {
                # Check if the content is an array.
                if ($Content[$type].__array) {
                    $upload = $Content[$type].__content.__upload
                }
                else {
                    $upload = $Content[$type].__upload
                }

                # Handle specific multipart/form-data content processing.
                if ($type -ieq 'multipart/form-data' -and $upload.content) {
                    if ((Test-PodeOAVersion -Version 3.1 -DefinitionTag $DefinitionTag) -and $upload.partContentMediaType) {
                        # Iterate through properties to set content media type and remove format for binaries.
                        foreach ($key in $upload.content.Properties) {
                            if ($key.type -eq 'string' -and ($key.format -ieq 'binary' -or $key.format -ieq 'base64')) {
                                $key.ContentMediaType = $PartContentMediaType
                                $key.remove('format')
                                break
                            }
                        }
                    }
                    $newContent = $upload.content
                }
                else {
                    # Handle OpenAPI v3.0 specific content encoding.
                    if (Test-PodeOAVersion -Version 3.0 -DefinitionTag $DefinitionTag) {
                        $newContent = [ordered]@{
                            'type'   = 'string'
                            'format' = $upload.contentEncoding
                        }
                    }
                    else {
                        # Handle Base64 content encoding.
                        if ($ContentEncoding -ieq 'Base64') {
                            $newContent = [ordered]@{
                                'type'            = 'string'
                                'contentEncoding' = $upload.contentEncoding
                            }
                        }
                    }
                }

                # Update the content with the new encoding information.
                if ($Content[$type].__array) {
                    $Content[$type].__content = $newContent
                }
                else {
                    $Content[$type] = $newContent
                }
            }

            # Process arrays and object properties based on content type.
            if ($Content[$type].__array) {
                $isArray = $true
                $item = $Content[$type].__content
                $obj[$type].schema = [ordered]@{
                    'type'  = 'array'
                    'items' = $null
                }
                # Include additional metadata if present.
                if ($Content[$type].__title) {
                    $obj[$type].schema.title = $Content[$type].__title
                }
                if ($Content[$type].__uniqueItems) {
                    $obj[$type].schema.uniqueItems = $Content[$type].__uniqueItems
                }
                if ($Content[$type].__maxItems) {
                    $obj[$type].schema.__maxItems = $Content[$type].__maxItems
                }
                if ($Content[$type].minItems) {
                    $obj[$type].schema.minItems = $Content[$type].__minItems
                }
            }
            else {
                $item = $Content[$type]
                $isArray = $false
            }

            # Add schema objects or handle empty content.
            if ($item -is [string]) {
                if (![string]::IsNullOrEmpty($item)) {
                    # Handle basic type definitions or references.
                    if (@('string', 'integer', 'number', 'boolean') -icontains $item) {
                        if ($isArray) {
                            $obj[$type].schema.items = [ordered]@{
                                'type' = $item.ToLower()
                            }
                        }
                        else {
                            $obj[$type].schema = [ordered]@{
                                'type' = $item.ToLower()
                            }
                        }
                    }
                    else {
                        # Handle component references.
                        Test-PodeOAComponentInternal -Field schemas -DefinitionTag $DefinitionTag -Name $item -PostValidation
                        if ($isArray) {
                            $obj[$type].schema.items = [ordered]@{
                                '$ref' = "#/components/schemas/$($item)"
                            }
                        }
                        else {
                            $obj[$type].schema = [ordered]@{
                                '$ref' = "#/components/schemas/$($item)"
                            }
                        }
                    }
                }
                else {
                    # Create an empty content entry.
                    $obj[$type] = [ordered]@{}
                }
            }
            else {
                if ($item.Count -eq 0) {
                    $result = [ordered]@{}  # Create an empty object if the item count is zero.
                }
                else {
                    # Convert each property to a PodeOpenAPI schema property.
                    $result = ($item | ConvertTo-PodeOASchemaProperty -DefinitionTag $DefinitionTag)
                }

                # Handle the Properties parameter case.
                if ($Properties) {
                    if ($item.Name) {
                        $obj[$type].schema = [ordered]@{
                            'properties' = [ordered]@{
                                $item.Name = $result
                            }
                        }
                    }
                    else {
                        # Throw an error if Properties parameter is used without a name.
                        throw ($PodeLocale.propertiesParameterWithoutNameExceptionMessage)
                    }
                }
                else {
                    # Assign the resulting schema to the correct array or object location.
                    if ($isArray) {
                        $obj[$type].schema.items = $result
                    }
                    else {
                        $obj[$type].schema = $result
                    }
                }
            }
        }

        return $obj  # Return the final OpenAPI schema object.
    }
}

<#
.SYNOPSIS
Check if an ComponentSchemaJson reference exist.

.DESCRIPTION
Check if an ComponentSchemaJson reference with a given name exist.

.PARAMETER Name
The Name of the ComponentSchemaJson reference.

.NOTES
This is an internal function and may change in future releases of Pode.
#>


function Test-PodeOAComponentSchemaJson {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name,

        [Parameter(Mandatory = $true)]
        [string[]]
        $DefinitionTag
    )

    foreach ($tag in $DefinitionTag) {
        if (!($PodeContext.Server.OpenAPI.Definitions[$tag].hiddenComponents.schemaJson.keys -ccontains $Name)) {
            # If $Name is not found in the current $tag, return $false
            return $false
        }
    }
    return $true
}

<#
.SYNOPSIS
    Tests if a given name exists in the external path keys of OpenAPI definitions for specified definition tags.

.DESCRIPTION
    The Test-PodeOAComponentExternalPath function iterates over a list of definition tags and checks if a given name
    is present in the external path keys of OpenAPI definitions within the Pode server context. This function is typically
    used to validate if a specific component name is already defined in the external paths of the OpenAPI documentation.

.PARAMETER Name
    The name of the external path component to be checked within the OpenAPI definitions.

.PARAMETER DefinitionTag
    An array of definition tags against which the existence of the name will be checked in the OpenAPI definitions.

.EXAMPLE
    $exists = Test-PodeOAComponentExternalPath -Name 'MyComponentName' -DefinitionTag @('tag1', 'tag2')

    Checks if 'MyComponentName' exists in the external path keys of OpenAPI definitions for 'tag1' and 'tag2'.

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function Test-PodeOAComponentExternalPath {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name,

        [Parameter(Mandatory = $true)]
        [string[]]
        $DefinitionTag
    )

    # Iterate over each definition tag
    foreach ($tag in $DefinitionTag) {
        # Check if the name exists in the external path keys of the current definition tag
        if (!($PodeContext.Server.OpenAPI.Definitions[$tag].hiddenComponents.externalPath.keys -ccontains $Name)) {
            # If the name is not found in the current tag, return false
            return $false
        }
    }
    # If the name exists in all specified tags, return true
    return $true
}


<#
.SYNOPSIS
    Converts a property into an OpenAPI 'Of' property structure based on a given definition tag.

.DESCRIPTION
    The ConvertTo-PodeOAOfProperty function is used to convert a given property into one of the OpenAPI 'Of' properties:
    allOf, oneOf, or anyOf. These structures are used in OpenAPI documentation to define complex types. The function
    constructs the appropriate structure based on the type of the property and the definition tag provided.

.PARAMETER Property
    A hashtable representing the property to be converted. It should contain the type (allOf, oneOf, or anyOf) and
    potentially a list of schemas.

.PARAMETER DefinitionTag
    A mandatory string parameter specifying the definition tag in OpenAPI documentation, used for validating components.

.EXAMPLE
    $ofProperty = ConvertTo-PodeOAOfProperty -Property $myProperty -DefinitionTag 'myTag'

    Converts a given property into an OpenAPI 'Of' structure using the specified definition tag.

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function ConvertTo-PodeOAOfProperty {
    param (
        [hashtable]
        $Property,

        [Parameter(Mandatory = $true)]
        [string]
        $DefinitionTag
    )

    # Check if the property type is one of the supported 'Of' types
    if (@('allOf', 'oneOf', 'anyOf') -inotcontains $Property.type) {
        return @{}
    }
    # Initialize the schema with the 'Of' type
    if ($Property.name) {
        $schema = [ordered]@{
            $Property.name = [ordered]@{
                $Property.type = @()
            }
        }
        if ($Property.description) {
            $schema[$Property.name].description = $Property.description
        }
    }
    else {
        $schema = [ordered]@{
            $Property.type = @()
        }
    }

    # Process each schema defined in the property
    if ($Property.schemas) {
        foreach ($prop in $Property.schemas) {
            if ($prop -is [string]) {
                # Validate the schema component and add a reference to it
                Test-PodeOAComponentInternal -Field schemas -DefinitionTag $DefinitionTag -Name $prop -PostValidation
                if ($Property.name) {
                    $schema[$Property.name][$Property.type] += [ordered]@{ '$ref' = "#/components/schemas/$prop" }
                }
                else {
                    $schema[$Property.type] += [ordered]@{ '$ref' = "#/components/schemas/$prop" }
                }
            }
            else {
                # Convert the property to an OpenAPI schema property
                if ($Property.name) {
                    $schema[$Property.name][$Property.type] += $prop | ConvertTo-PodeOASchemaProperty -DefinitionTag $DefinitionTag
                }
                else {
                    $schema[$Property.type] += $prop | ConvertTo-PodeOASchemaProperty -DefinitionTag $DefinitionTag
                }
            }
        }
    }

    # Add discriminator if present
    if ($Property.discriminator) {
        $schema['discriminator'] = $Property.discriminator
    }

    # Return the constructed 'Of' property schema
    return $schema
}

<#
.SYNOPSIS
    Converts a hashtable representing a property into a schema property format compliant with the OpenAPI Specification (OAS).

.DESCRIPTION
    This function takes a hashtable input representing a property and converts it into a schema property format based on the OpenAPI Specification.
    It handles various property types including primitives, arrays, and complex types with allOf, oneOf, anyOf constructs.

.PARAMETER Property
    A hashtable containing property details that need to be converted to an OAS schema property.

.PARAMETER NoDescription
    A switch parameter. If set, the description of the property will not be included in the output schema.

.PARAMETER DefinitionTag
    A mandatory string parameter specifying the definition context used for schema validation and compatibility checks with OpenAPI versions.

.EXAMPLE
    $propertyDetails = [ordered]@{
        type = 'string';
        description = 'A sample property';
    }
    ConvertTo-PodeOASchemaProperty -Property $propertyDetails -DefinitionTag 'v1'

    This example will convert a simple string property into an OpenAPI schema property.
#>
function ConvertTo-PodeOASchemaProperty {
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [hashtable]
        $Property,

        [switch]
        $NoDescription,

        [Parameter(Mandatory = $true)]
        [string]
        $DefinitionTag
    )
    begin {
        $pipelineItemCount = 0
    }

    process {

        $pipelineItemCount++
    }

    end {
        if ($pipelineItemCount -gt 1) {
            throw ($PodeLocale.fnDoesNotAcceptArrayAsPipelineInputExceptionMessage -f $($MyInvocation.MyCommand.Name))
        }

        if ( @('allof', 'oneof', 'anyof') -icontains $Property.type) {
            $schema = ConvertTo-PodeOAofProperty -DefinitionTag $DefinitionTag -Property $Property
        }
        else {
            # base schema type
            $schema = [ordered]@{ }
            if (Test-PodeOAVersion -Version 3.0 -DefinitionTag $DefinitionTag ) {
                if ($Property.type -is [string[]]) {
                    # Multi type properties requeired OpenApi Version 3.1 or above
                    throw ($PodeLocale.multiTypePropertiesRequireOpenApi31ExceptionMessage)
                }
                $schema['type'] = $Property.type.ToLower()
            }
            else {
                $schema.type = @($Property.type.ToLower())
                if ($Property.nullable) {
                    $schema.type += 'null'
                }
            }
        }

        if ($Property.externalDocs) {
            $schema['externalDocs'] = $Property.externalDocs
        }

        if (!$NoDescription -and $Property.description) {
            $schema['description'] = $Property.description
        }

        if ($Property.default) {
            $schema['default'] = $Property.default
        }

        if ($Property.deprecated) {
            $schema['deprecated'] = $Property.deprecated
        }
        if ($Property.nullable -and (Test-PodeOAVersion -Version 3.0 -DefinitionTag $DefinitionTag )) {
            $schema['nullable'] = $Property.nullable
        }

        if ($Property.writeOnly) {
            $schema['writeOnly'] = $Property.writeOnly
        }

        if ($Property.readOnly) {
            $schema['readOnly'] = $Property.readOnly
        }

        if ($Property.example) {
            if (Test-PodeOAVersion -Version 3.0 -DefinitionTag $DefinitionTag ) {
                $schema['example'] = $Property.example
            }
            else {
                if ($Property.example -is [Array]) {
                    $schema['examples'] = $Property.example
                }
                else {
                    $schema['examples'] = @( $Property.example)
                }
            }
        }
        if (Test-PodeOAVersion -Version 3.0 -DefinitionTag $DefinitionTag ) {
            if ($Property.ContainsKey('minimum')) {
                $schema['minimum'] = $Property.minimum
            }

            if ($Property.ContainsKey('maximum')) {
                $schema['maximum'] = $Property.maximum
            }

            if ($Property.exclusiveMaximum) {
                $schema['exclusiveMaximum'] = $Property.exclusiveMaximum
            }

            if ($Property.exclusiveMinimum) {
                $schema['exclusiveMinimum'] = $Property.exclusiveMinimum
            }
        }
        else {
            if ($Property.ContainsKey('maximum')) {
                if ($Property.exclusiveMaximum) {
                    $schema['exclusiveMaximum'] = $Property.maximum
                }
                else {
                    $schema['maximum'] = $Property.maximum
                }
            }
            if ($Property.ContainsKey('minimum')) {
                if ($Property.exclusiveMinimum) {
                    $schema['exclusiveMinimum'] = $Property.minimum
                }
                else {
                    $schema['minimum'] = $Property.minimum
                }
            }
        }
        if ($Property.multipleOf) {
            $schema['multipleOf'] = $Property.multipleOf
        }

        if ($Property.pattern) {
            $schema['pattern'] = $Property.pattern
        }

        if ($Property.ContainsKey('minLength')) {
            $schema['minLength'] = $Property.minLength
        }

        if ($Property.ContainsKey('maxLength')) {
            $schema['maxLength'] = $Property.maxLength
        }

        if ($Property.xml ) {
            $schema['xml'] = $Property.xml
        }

        if (Test-PodeOAVersion -Version 3.1 -DefinitionTag $DefinitionTag ) {
            if ($Property.ContentMediaType) {
                $schema['contentMediaType'] = $Property.ContentMediaType
            }
            if ($Property.ContentEncoding) {
                $schema['contentEncoding'] = $Property.ContentEncoding
            }
        }

        # are we using an array?
        if ($Property.array) {
            if ($Property.ContainsKey('maxItems') ) {
                $schema['maxItems'] = $Property.maxItems
            }

            if ($Property.ContainsKey('minItems') ) {
                $schema['minItems'] = $Property.minItems
            }

            if ($Property.uniqueItems ) {
                $schema['uniqueItems'] = $Property.uniqueItems
            }

            $schema['type'] = 'array'
            if ($Property.type -ieq 'schema') {
                Test-PodeOAComponentInternal -Field schemas -DefinitionTag $DefinitionTag -Name $Property['schema'] -PostValidation
                $schema['items'] = [ordered]@{ '$ref' = "#/components/schemas/$($Property['schema'])" }
            }
            else {
                $Property.array = $false
                if ($Property.xml) {
                    $xmlFromProperties = $Property.xml
                    $Property.Remove('xml')
                }
                $schema['items'] = ($Property | ConvertTo-PodeOASchemaProperty -DefinitionTag $DefinitionTag)
                $Property.array = $true
                if ($xmlFromProperties) {
                    $Property.xml = $xmlFromProperties
                }

                if ($Property.xmlItemName) {
                    $schema.items.xml = [ordered]@{'name' = $Property.xmlItemName }
                }
            }
            return $schema
        }
        else {
            #format is not applicable to array
            if ($Property.format) {
                $schema['format'] = $Property.format
            }

            # schema refs
            if ($Property.type -ieq 'schema') {
                Test-PodeOAComponentInternal -Field schemas -DefinitionTag $DefinitionTag -Name $Property['schema'] -PostValidation
                $schema = [ordered]@{
                    '$ref' = "#/components/schemas/$($Property['schema'])"
                }
            }
            #only if it's not an array
            if ($Property.enum ) {
                $schema['enum'] = $Property.enum
            }
        }

        if ($Property.object) {
            # are we using an object?
            $Property.object = $false

            $schema = [ordered]@{
                type       = 'object'
                properties = (ConvertTo-PodeOASchemaObjectProperty -DefinitionTag $DefinitionTag -Properties $Property)
            }
            $Property.object = $true
            if ($Property.required) {
                $schema['required'] = @($Property.name)
            }
        }

        if ($Property.type -ieq 'object') {
            $schema['properties'] = [ordered]@{}
            foreach ($prop in $Property.properties) {
                if ( @('allOf', 'oneOf', 'anyOf') -icontains $prop.type) {
                    switch ($prop.type.ToLower()) {
                        'allof' { $prop.type = 'allOf' }
                        'oneof' { $prop.type = 'oneOf' }
                        'anyof' { $prop.type = 'anyOf' }
                    }
                    if ($prop.name) {
                        $schema['properties'] += ConvertTo-PodeOAofProperty -DefinitionTag $DefinitionTag -Property $prop
                    }
                    else {
                        $schema += ConvertTo-PodeOAofProperty -DefinitionTag $DefinitionTag -Property $prop
                    }

                }
            }
            if ($Property.properties) {
                $schema['properties'] = (ConvertTo-PodeOASchemaObjectProperty -DefinitionTag $DefinitionTag -Properties $Property.properties)
                $RequiredList = @(($Property.properties | Where-Object { $_.required }) )
                if ( $RequiredList.Count -gt 0) {
                    $schema['required'] = @($RequiredList.name)
                }
            }
            else {
                #if noproperties parameter create an empty properties
                if ( $Property.properties.Count -eq 1 -and $null -eq $Property.properties[0]) {
                    $schema['properties'] = @{}
                }
            }


            if ($Property.minProperties) {
                $schema['minProperties'] = $Property.minProperties
            }

            if ($Property.maxProperties) {
                $schema['maxProperties'] = $Property.maxProperties
            }
            #Fix an issue when additionalProperties has an assigned value of $false
            if ($Property.ContainsKey('additionalProperties')) {
                if ($Property.additionalProperties) {
                    $schema['additionalProperties'] = $Property.additionalProperties | ConvertTo-PodeOASchemaProperty -DefinitionTag $DefinitionTag
                }
                else {
                    #the value is $false
                    $schema['additionalProperties'] = $false
                }
            }

            if ($Property.discriminator) {
                $schema['discriminator'] = $Property.discriminator
            }
        }

        return $schema
    }
}

<#
.SYNOPSIS
Converts a collection of properties into an OpenAPI schema object format.

.DESCRIPTION
The ConvertTo-PodeOASchemaObjectProperty function takes an array of property hashtables and converts them into
a format suitable for OpenAPI schema objects. It specifically processes properties that are not 'allOf', 'oneOf',
or 'anyOf' types, using the ConvertTo-PodeOASchemaProperty function for conversion based on a given definition tag.

.PARAMETER Properties
An array of hashtables representing properties to be converted. Each hashtable should contain the property's details.

.PARAMETER DefinitionTag
A string representing the definition tag to be used in the conversion process. This tag is crucial for correctly
formatting the properties according to OpenAPI specifications.

.EXAMPLE
$schemaObject = ConvertTo-PodeOASchemaObjectProperty -Properties $myProperties -DefinitionTag 'myTag'

Converts an array of property hashtables into an OpenAPI schema object using the definition tag 'myTag'.

.NOTES
This is an internal function and may change in future releases of Pode.
#>
function ConvertTo-PodeOASchemaObjectProperty {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable[]]
        $Properties,

        [Parameter(Mandatory = $true)]
        [string]
        $DefinitionTag
    )

    # Initialize an empty hashtable for the schema
    $schema = [ordered]@{}

    # Iterate over each property and convert to OpenAPI schema property if applicable
    foreach ($prop in $Properties) {
        # Exclude properties of type 'allOf', 'oneOf', or 'anyOf'
        if (@('allOf', 'oneOf', 'anyOf') -inotcontains $prop.type) {
            # Convert the property to an OpenAPI schema property and add to the schema hashtable
            $schema[$prop.name] = ($prop | ConvertTo-PodeOASchemaProperty -DefinitionTag $DefinitionTag)
        }
    }

    # Return the constructed schema object
    return $schema
}

<#
.SYNOPSIS
Sets OpenAPI specifications for a given route.

.DESCRIPTION
The Set-PodeOpenApiRouteValue function processes and sets various OpenAPI specifications for a given route based on the provided definition tag.
It handles route attributes such as deprecated status, tags, summary, description, operation ID, parameters, request body, callbacks, authentication,
and responses to build a complete OpenAPI specification for the route.

.PARAMETER Route
A hashtable representing the route for which OpenAPI specifications are being set.

.PARAMETER DefinitionTag
A string representing the definition tag used for specifying OpenAPI documentation details for the route.

.EXAMPLE
$routeValues = Set-PodeOpenApiRouteValue -Route $route -DefinitionTag 'myTag'

Sets OpenAPI specifications for the given route using the definition tag 'myTag'.

.NOTES
This is an internal function and may change in future releases of Pode.
#>
function Set-PodeOpenApiRouteValue {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]
        $Route,

        [Parameter(Mandatory = $true)]
        [string]
        $DefinitionTag
    )
    # Initialize an ordered hashtable to store route properties
    $pm = [ordered]@{}

    # Process various OpenAPI attributes for the route
    if ($Route.OpenApi.Deprecated) {
        $pm.deprecated = $Route.OpenApi.Deprecated
    }
    if ($Route.OpenApi.Tags) {
        $pm.tags = $Route.OpenApi.Tags
    }
    if ($Route.OpenApi.Summary) {
        $pm.summary = $Route.OpenApi.Summary
    }
    if ($Route.OpenApi.Description) {
        $pm.description = $Route.OpenApi.Description
    }
    if ($Route.OpenApi.OperationId) {
        $pm.operationId = $Route.OpenApi.OperationId
    }
    if ($Route.OpenApi.Parameters[$DefinitionTag]) {
        $pm.parameters = $Route.OpenApi.Parameters[$DefinitionTag]
    }
    if ($Route.OpenApi.RequestBody[$DefinitionTag]) {
        $pm.requestBody = $Route.OpenApi.RequestBody[$DefinitionTag]
    }
    if ($Route.OpenApi.CallBacks[$DefinitionTag]) {
        $pm.callbacks = $Route.OpenApi.CallBacks[$DefinitionTag]
    }
    if ($Route.OpenApi.Servers) {
        $pm.servers = $Route.OpenApi.Servers
    }
    if ($Route.OpenApi.Authentication.Count -gt 0) {
        $pm.security = @()
        foreach ($sct in (Expand-PodeAuthMerge -Names $Route.OpenApi.Authentication.Keys)) {
            if ($PodeContext.Server.Authentications.Methods.$sct.Scheme.Scheme -ieq 'oauth2') {
                if ($Route.AccessMeta.Scope ) {
                    $sctValue = $Route.AccessMeta.Scope
                }
                else {
                    #if scope is empty means 'any role' => assign an empty array
                    $sctValue = @()
                }
                $pm.security += [ordered]@{ $sct = $sctValue }
            }
            elseif ($sct -eq '%_allowanon_%') {
                #allow anonymous access
                $pm.security += [ordered]@{}
            }
            else {
                $pm.security += [ordered]@{$sct = @() }
            }
        }
    }
    if ($Route.OpenApi.Responses[$DefinitionTag] ) {
        $pm.responses = $Route.OpenApi.Responses[$DefinitionTag]
    }
    else {
        # Set responses or default to '204 No Content' if not specified
        $pm.responses = [ordered]@{'204' = [ordered]@{'description' = (Get-PodeStatusDescription -StatusCode 204) } }
    }
    # Return the processed route properties
    return $pm
}


<#
.SYNOPSIS
Generates an internal OpenAPI definition based on the current Pode server context and specific parameters.

.DESCRIPTION
This function constructs an OpenAPI definition by gathering metadata, route information, and API structure based on the provided parameters.
It supports customization of the API documentation through MetaInfo and directly influences the output by including specific server, authentication, and endpoint details.

.PARAMETER EndpointName
The name of the endpoint for which the OpenAPI definition is generated.

.PARAMETER MetaInfo
A hashtable containing metadata for the OpenAPI definition such as the API title, version, and description.

.PARAMETER DefinitionTag
Mandatory. A tag that identifies the specific OpenAPI definition to be generated or manipulated.

.OUTPUTS
Ordered dictionary representing the OpenAPI definition, which can be further processed into JSON or YAML format.

.EXAMPLE
$metaInfo = [ordered]@{
Title = "My API";
Version = "v1";
Description = "This is my API description."
}
Get-PodeOpenApiDefinitionInternal -Protocol 'HTTPS' -Address 'myapi.example.com' -EndpointName 'MyAPI' -MetaInfo $metaInfo -DefinitionTag 'MyTag'

.NOTES
This is an internal function and may change in future releases of Pode.
#>

function Get-PodeOpenApiDefinitionInternal {
    param(

        [string]
        $EndpointName,

        [hashtable]
        $MetaInfo,

        [Parameter(Mandatory = $true)]
        [string]
        $DefinitionTag
    )


    $Definition = $PodeContext.Server.OpenAPI.Definitions[$DefinitionTag]

    if (!$Definition.Version) {
        # OpenApi Version property is mandatory
        throw ($PodeLocale.openApiVersionPropertyMandatoryExceptionMessage)
    }
    $localEndpoint = $null
    # set the openapi version
    $def = [ordered]@{
        openapi = $Definition.Version
    }

    if (Test-PodeOAVersion -Version 3.1 -DefinitionTag $DefinitionTag) {
        $def['jsonSchemaDialect'] = 'https://spec.openapis.org/oas/3.1/dialect/base'
    }

    if ($Definition.info) {
        $def['info'] = $Definition.info
    }

    #overwite default values
    if ($MetaInfo.Title) {
        $def.info.title = $MetaInfo.Title
    }

    if ($MetaInfo.Version) {
        $def.info.version = $MetaInfo.Version
    }

    if ($MetaInfo.Description) {
        $def.info.description = $MetaInfo.Description
    }

    if ($Definition.externalDocs) {
        $def['externalDocs'] = $Definition.externalDocs
    }

    if ($Definition.servers) {
        $def['servers'] = $Definition.servers
        if ($Definition.servers.Count -eq 1 -and $Definition.servers[0].url.StartsWith('/')) {
            $localEndpoint = $Definition.servers[0].url
        }
    }
    elseif (!$MetaInfo.RestrictRoutes -and ($PodeContext.Server.Endpoints.Count -gt 1)) {
        #$def['servers'] = $null
        $def.servers = @(foreach ($endpoint in $PodeContext.Server.Endpoints.Values) {
                @{
                    url         = $endpoint.Url
                    description = (Protect-PodeValue -Value $endpoint.Description -Default $endpoint.Name)
                }
            })
    }
    if ($Definition.tags.Count -gt 0) {
        $def['tags'] = @($Definition.tags.Values)
    }

    # paths
    $def['paths'] = [ordered]@{}
    if ($Definition.webhooks.count -gt 0) {
        if (Test-PodeOAVersion -Version 3.0 -DefinitionTag $DefinitionTag) {
            # Webhooks feature is unsupported in OpenAPI v3.0.x
            throw ($PodeLocale.webhooksFeatureNotSupportedInOpenApi30ExceptionMessage)
        }
        else {
            $keys = [string[]]$Definition.webhooks.Keys
            foreach ($key in $keys) {
                if ($Definition.webhooks[$key].NotPrepared) {
                    $Definition.webhooks[$key] = [ordered]@{
                        $Definition.webhooks[$key].Method = Set-PodeOpenApiRouteValue -Route $Definition.webhooks[$key] -DefinitionTag $DefinitionTag
                    }
                }
            }
            $def['webhooks'] = $Definition.webhooks
        }
    }
    # components
    $def['components'] = [ordered]@{}#$Definition.components
    $components = $Definition.components

    if ($components.schemas.count -gt 0) {
        $def['components'].schemas = $components.schemas
    }
    if ($components.responses.count -gt 0) {
        $def['components'].responses = $components.responses
    }
    if ($components.parameters.count -gt 0) {
        $def['components'].parameters = $components.parameters
    }
    if ($components.examples.count -gt 0) {
        $def['components'].examples = $components.examples
    }
    if ($components.requestBodies.count -gt 0) {
        $def['components'].requestBodies = $components.requestBodies
    }
    if ($components.headers.count -gt 0) {
        $def['components'].headers = $components.headers
    }
    if ($components.securitySchemes.count -gt 0) {
        $def['components'].securitySchemes = $components.securitySchemes
    }
    if ($components.links.count -gt 0) {
        $def['components'].links = $components.links
    }
    if ($components.callbacks.count -gt 0) {
        $def['components'].callbacks = $components.callbacks
    }
    if ($components.pathItems.count -gt 0) {
        if (Test-PodeOAVersion -Version 3.0 -DefinitionTag $DefinitionTag) {
            # Feature pathItems is unsupported in OpenAPI v3.0.x
            throw ($PodeLocale.pathItemsFeatureNotSupportedInOpenApi30ExceptionMessage)
        }
        else {
            $keys = [string[]]$components.pathItems.Keys
            foreach ($key in $keys) {
                if ($components.pathItems[$key].NotPrepared) {
                    $components.pathItems[$key] = [ordered]@{
                        $components.pathItems[$key].Method = Set-PodeOpenApiRouteValue -Route $components.pathItems[$key] -DefinitionTag $DefinitionTag
                    }
                }
            }
            $def['components'].pathItems = $components.pathItems
        }
    }

    # auth/security components
    if ($PodeContext.Server.Authentications.Methods.Count -gt 0) {
        $authNames = (Expand-PodeAuthMerge -Names $PodeContext.Server.Authentications.Methods.Keys)

        foreach ($authName in $authNames) {
            $authType = (Find-PodeAuth -Name $authName).Scheme
            $_authName = ($authName -replace '\s+', '')

            $_authObj = [ordered]@{}

            if ($authType.Scheme -ieq 'apikey') {
                $_authObj = [ordered]@{
                    type = $authType.Scheme
                    in   = $authType.Arguments.Location.ToLowerInvariant()
                    name = $authType.Arguments.LocationName
                }
                if ($authType.Arguments.Description) {
                    $_authObj.description = $authType.Arguments.Description
                }
            }
            elseif ($authType.Scheme -ieq 'oauth2') {
                if ($authType.Arguments.Urls.Token -and $authType.Arguments.Urls.Authorise) {
                    $oAuthFlow = 'authorizationCode'
                }
                elseif ($authType.Arguments.Urls.Token ) {
                    if ($null -ne $authType.InnerScheme) {
                        if ($authType.InnerScheme.Name -ieq 'basic' -or $authType.InnerScheme.Name -ieq 'form') {
                            $oAuthFlow = 'password'
                        }
                        else {
                            $oAuthFlow = 'implicit'
                        }
                    }
                }
                $_authObj = [ordered]@{
                    type = $authType.Scheme
                }
                if ($authType.Arguments.Description) {
                    $_authObj.description = $authType.Arguments.Description
                }
                $_authObj.flows = [ordered]@{
                    $oAuthFlow = [ordered]@{
                    }
                }
                if ($authType.Arguments.Urls.Token) {
                    $_authObj.flows.$oAuthFlow.tokenUrl = $authType.Arguments.Urls.Token
                }

                if ($authType.Arguments.Urls.Authorise) {
                    $_authObj.flows.$oAuthFlow.authorizationUrl = $authType.Arguments.Urls.Authorise
                }
                if ($authType.Arguments.Urls.Refresh) {
                    $_authObj.flows.$oAuthFlow.refreshUrl = $authType.Arguments.Urls.Refresh
                }

                $_authObj.flows.$oAuthFlow.scopes = [ordered]@{}
                if ($authType.Arguments.Scopes ) {
                    foreach ($scope in $authType.Arguments.Scopes) {
                        if ($PodeContext.Server.Authorisations.Methods.ContainsKey($scope) -and $PodeContext.Server.Authorisations.Methods[$scope].Scheme.Type -ieq 'Scope' -and $PodeContext.Server.Authorisations.Methods[$scope].Description) {
                            $_authObj.flows.$oAuthFlow.scopes[$scope] = $PodeContext.Server.Authorisations.Methods[$scope].Description
                        }
                        else {
                            $_authObj.flows.$oAuthFlow.scopes[$scope] = 'No description.'
                        }
                    }
                }
            }
            else {
                $_authObj = [ordered]@{
                    type   = $authType.Scheme.ToLowerInvariant()
                    scheme = $authType.Name.ToLowerInvariant()
                }
                if ($authType.Arguments.Description) {
                    $_authObj.description = $authType.Arguments.Description
                }
            }
            if (!$def.components.securitySchemes) {
                $def.components.securitySchemes = [ordered]@{}
            }
            $def.components.securitySchemes[$_authName] = $_authObj
        }

        if ($Definition.Security.Definition -and $Definition.Security.Definition.Length -gt 0) {
            $def['security'] = @($Definition.Security.Definition)
        }
    }

    if ($MetaInfo.RouteFilter) {
        $filter = "^$($MetaInfo.RouteFilter)"
    }
    else {
        $filter = ''
    }


    foreach ($path in $PodeContext.Server.OpenAPI.Routes) {
        # does it match the route?
        if ($path -inotmatch $filter) {
            continue
        }
        foreach ($method in $PodeContext.Server.Routes.Keys) {
            $_routes = $PodeContext.Server.Routes[$method][$path]

            if ($null -eq $_routes) { continue }

            if ( $MetaInfo -and $MetaInfo.RestrictRoutes) {
                $_routes = @(Get-PodeRouteByUrl -Routes  $_routes -EndpointName $EndpointName)
            }
            $_route = $_routes[0]
            # check if the route has to be published
            if (($_route.OpenApi.Swagger -and ($_route.OpenApi.DefinitionTag -contains $DefinitionTag) ) -or $Definition.hiddenComponents.enableMinimalDefinitions) {

                #remove the ServerUrl part
                if ( $localEndpoint) {
                    if ($_route.Path.StartsWith($localEndpoint)) {
                        $_route.OpenApi.Path = $_route.OpenApi.Path.replace($localEndpoint, '')
                    }
                    else {
                        continue
                    }
                }
                # do nothing if it has no responses set
                if ($_route.OpenApi.Responses.Count -eq 0) {
                    continue
                }

                # add path to defintion
                if ($null -eq $def.paths[$_route.OpenApi.Path]) {
                    $def.paths[$_route.OpenApi.Path] = [ordered]@{}
                }
                # add path's http method to defintition

                $pm = Set-PodeOpenApiRouteValue -Route $_route -DefinitionTag $DefinitionTag
                if ($pm.responses.Count -eq 0) {
                    $pm.responses += [ordered]@{
                        'default' = [ordered]@{'description' = 'No description' }
                    }
                }
                $def.paths[$_route.OpenApi.Path][$method] = $pm

                # add any custom server endpoints for route
                if ($_route.OpenApi.Servers.count -gt 0) {
                    if ($null -eq $def.paths[$_route.OpenApi.Path][$method].servers) {
                        $def.paths[$_route.OpenApi.Path][$method].servers = @()
                    }
                    if ($localEndpoint) {
                        $def.paths[$_route.OpenApi.Path][$method].servers += $Definition.servers[0]
                    }
                }
                if (![string]::IsNullOrWhiteSpace($_route.Endpoint.Address) -and ($_route.Endpoint.Address -ine '*:*')) {

                    if ($null -eq $def.paths[$_route.OpenApi.Path][$method].servers) {
                        $def.paths[$_route.OpenApi.Path][$method].servers = @()
                    }

                    $serverDef = $null
                    if (![string]::IsNullOrWhiteSpace($_route.Endpoint.Name)) {
                        $serverDef = [ordered]@{
                            url = (Get-PodeEndpointByName -Name $_route.Endpoint.Name).Url
                        }
                    }
                    else {
                        $serverDef = [ordered]@{
                            url = "$($_route.Endpoint.Protocol)://$($_route.Endpoint.Address)"
                        }
                    }

                    if ($null -ne $serverDef) {
                        $def.paths[$_route.OpenApi.Path][$method].servers += $serverDef
                    }
                }
            }
        }
    }

    #deal with the external OpenAPI paths
    if ( $Definition.hiddenComponents.externalPath) {
        foreach ($extPath in $Definition.hiddenComponents.externalPath.values) {
            foreach ($method in $extPath.keys) {
                $_route = $extPath[$method]
                if (! ( $def.paths.keys -ccontains $_route.Path)) {
                    $def.paths[$_route.OpenAPI.Path] = [ordered]@{}
                }
                $pm = Set-PodeOpenApiRouteValue -Route $_route -DefinitionTag $DefinitionTag
                # add path's http method to defintition
                $def.paths[$_route.OpenAPI.Path][$method.ToLower()] = $pm
            }
        }
    }
    return $def
}

<#
.SYNOPSIS
    Converts a cmdlet parameter to a Pode OpenAPI property.

.DESCRIPTION
    This internal function takes a cmdlet parameter and converts it into an appropriate Pode OpenAPI property based on its type.
    The function supports boolean, integer, float, and string parameter types.

.PARAMETER Parameter
    The cmdlet parameter metadata that needs to be converted. This parameter is mandatory and accepts values from the pipeline.

.EXAMPLE
    $metadata = Get-Command -Name Get-Process | Select-Object -ExpandProperty Parameters
    $metadata.Values | ConvertTo-PodeOAPropertyFromCmdletParameter

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function ConvertTo-PodeOAPropertyFromCmdletParameter {
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [System.Management.Automation.ParameterMetadata]
        $Parameter
    )
    process {
        if ($Parameter.SwitchParameter -or ($Parameter.ParameterType.Name -ieq 'boolean')) {
            New-PodeOABoolProperty -Name $Parameter.Name
        }
        else {
            switch ($Parameter.ParameterType.Name) {
                { @('int32', 'int64') -icontains $_ } {
                    New-PodeOAIntProperty -Name $Parameter.Name -Format $_
                }

                { @('double', 'float') -icontains $_ } {
                    New-PodeOANumberProperty -Name $Parameter.Name -Format $_
                }
            }
        }

        New-PodeOAStringProperty -Name $Parameter.Name
    }
}


<#
.SYNOPSIS
    Creates a base OpenAPI object structure.

.DESCRIPTION
    The Get-PodeOABaseObject function generates a foundational structure for an OpenAPI object.
    This structure includes empty ordered dictionaries for info, paths, webhooks, components, and other OpenAPI elements.
    It is used as a base template for building OpenAPI documentation in the Pode framework.

.OUTPUTS
    Hashtable
    Returns a hashtable representing the base structure of an OpenAPI object.

.EXAMPLE
    $baseObject = Get-PodeOABaseObject

    This example creates a base OpenAPI object structure.

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function Get-PodeOABaseObject {
    # Returns a base template for an OpenAPI object
    return @{
        info             = [ordered]@{}
        Path             = $null
        webhooks         = [ordered]@{}
        components       = [ordered]@{
            schemas         = [ordered]@{}
            responses       = [ordered]@{}
            parameters      = [ordered]@{}
            examples        = [ordered]@{}
            requestBodies   = [ordered]@{}
            headers         = [ordered]@{}
            securitySchemes = [ordered]@{}
            links           = [ordered]@{}
            callbacks       = [ordered]@{}
            pathItems       = [ordered]@{}
        }
        Security         = @()
        tags             = [ordered]@{}
        hiddenComponents = @{
            enabled          = $false
            schemaValidation = $false
            version          = 3.0
            depth            = 20
            schemaJson       = @{}
            viewer           = @{}
            postValidation   = @{
                schemas         = [ordered]@{}
                responses       = [ordered]@{}
                parameters      = [ordered]@{}
                examples        = [ordered]@{}
                requestBodies   = [ordered]@{}
                headers         = [ordered]@{}
                securitySchemes = [ordered]@{}
                links           = [ordered]@{}
                callbacks       = [ordered]@{}
                pathItems       = [ordered]@{}
            }
            externalPath     = [ordered]@{}
            defaultResponses = [ordered]@{
                '200'     = [ordered]@{ description = 'OK' }
                'default' = [ordered]@{ description = 'Internal server error' }
            }
            operationId      = @()
        }
    }
}

<#
.SYNOPSIS
Initializes a table to manage OpenAPI definitions.

.DESCRIPTION
The Initialize-PodeOpenApiTable function creates a table to manage OpenAPI definitions within the Pode framework.
It sets up a default definition tag and initializes a dictionary to hold OpenAPI definitions for each tag.
The function is essential for managing OpenAPI documentation across different parts of the application.

.PARAMETER DefaultDefinitionTag
An optional parameter to set the default OpenAPI definition tag. If not provided, 'default' is used.

.OUTPUTS
Hashtable
Returns a hashtable for managing OpenAPI definitions.

.EXAMPLE
$openApiTable = Initialize-PodeOpenApiTable -DefaultDefinitionTag 'api-v1'

Initializes the OpenAPI table with 'api-v1' as the default definition tag.

.EXAMPLE
$openApiTable = Initialize-PodeOpenApiTable

Initializes the OpenAPI table with 'default' as the default definition tag.

.NOTES
This is an internal function and may change in future releases of Pode.
#>
function Initialize-PodeOpenApiTable {
    param(
        [string]
        $DefaultDefinitionTag
    )
    # Check if the provided definition tag is null or empty. If so, set it to 'default'.
    if ([string]::IsNullOrEmpty($DefaultDefinitionTag)) {
        $DefaultDefinitionTag = 'default'
    }

    # Initialization of the OpenAPI table with default settings
    # Create a hashtable named $OpenAPI to hold various OpenAPI-related configurations and data.
    $OpenAPI = @{
        # Initialize a stack to manage the Definition Tag selection.
        DefinitionTagSelectionStack = [System.Collections.Generic.Stack[System.Object]]::new()
        Routes                      = @()
    }

    # Set the currently selected definition tag to the provided or default tag.
    $OpenAPI['SelectedDefinitionTag'] = $DefaultDefinitionTag

    # Initialize the Definitions dictionary with a base OpenAPI object for the selected definition tag.
    # The base OpenAPI object is created using the Get-PodeOABaseObject function.
    $OpenAPI['Definitions'] = @{ $OpenAPI['SelectedDefinitionTag'] = Get-PodeOABaseObject }

    # Return the initialized OpenAPI table
    return $OpenAPI
}

<#
.SYNOPSIS
Sets authentication methods for specific routes in OpenAPI documentation.

.DESCRIPTION
The Set-PodeOAAuth function assigns specified authentication methods to given routes for OpenAPI documentation.
It supports setting multiple authentication methods and optionally allows anonymous access.
The function validates the existence of the authentication methods before applying them to the routes.

.PARAMETER Route
An array of hashtables representing the routes to which the authentication methods will be applied.
Each route should contain an OpenApi key for updating OpenAPI documentation.

.PARAMETER Name
An array of names of the authentication methods to be applied to the routes.
These methods should already be defined in the Pode framework.

.PARAMETER AllowAnon
A switch parameter that, if set, allows anonymous access in addition to the specified authentication methods.

.EXAMPLE
Set-PodeOAAuth -Route $myRoute -Name @('BasicAuth', 'ApiKeyAuth') -AllowAnon

Applies 'BasicAuth' and 'ApiKeyAuth' authentication methods to the specified route and allows anonymous access.

.NOTES
This is an internal function and may change in future releases of Pode.
#>
function Set-PodeOAAuth {
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [hashtable[]]
        $Route,

        [string[]]
        $Name,

        [switch]
        $AllowAnon
    )
    begin {
        # Validate the existence of specified authentication methods
        foreach ($n in @($Name)) {
            if (!(Test-PodeAuthExists -Name $n)) {
                throw ($PodeLocale.authenticationMethodDoesNotExistExceptionMessage -f $n) #"Authentication method does not exist: $($n)"
            }
        }
    }

    process {
        # Iterate over each route to set authentication
        foreach ($r in @($Route)) {
            #exclude static route
            if ($r.Method -ne 'Static') {
                # Set the authentication methods for the route
                $r.OpenApi.Authentication = @(foreach ($n in @($Name)) {
                        @{
                            "$($n -replace '\s+', '')" = @() # Clean up auth name and initialize empty scopes
                        }
                    })
                # Add anonymous access if allowed
                if ($AllowAnon) {
                    $r.OpenApi.Authentication += [ordered]@{'%_allowanon_%' = '' }
                }
            }
        }
    }
}


<#
.SYNOPSIS
Sets global authentication methods for specified OpenAPI definitions in the Pode framework.

.DESCRIPTION
The Set-PodeOAGlobalAuth function is used to apply authentication methods globally to specified OpenAPI definitions.
It verifies the existence of the authentication methods and then updates the OpenAPI definitions with these methods,
associating them with specific routes.

.PARAMETER Name
The name of the authentication method to apply. This method should already be defined in the Pode framework.

.PARAMETER Route
The route to which the authentication method is to be applied.

.PARAMETER DefinitionTag
An array of definition tags specifying the OpenAPI definitions to which the authentication method should be applied.

.EXAMPLE
Set-PodeOAGlobalAuth -Name 'BasicAuth' -Route '/api/*' -DefinitionTag @('tag1', 'tag2')

Applies 'BasicAuth' authentication method to all routes under '/api/*' in the OpenAPI definitions tagged with 'tag1' and 'tag2'.

.NOTES
This is an internal function and may change in future releases of Pode.
#>
function Set-PodeOAGlobalAuth {
    param(
        [string]
        $Name,

        [string]
        $Route,

        [Parameter(Mandatory = $true)]
        [string[]]
        $DefinitionTag
    )

    # Check if the specified authentication method exists
    if (!(Test-PodeAuthExists -Name $Name)) {
        throw ($PodeLocale.authenticationMethodDoesNotExistExceptionMessage -f $Name) #"Authentication method does not exist: $($Name)"
    }

    # Iterate over each definition tag to apply the authentication method
    foreach ($tag in $DefinitionTag) {
        # Initialize security array if it's empty
        if (Test-PodeIsEmpty $PodeContext.Server.OpenAPI.Definitions[$tag].Security) {
            $PodeContext.Server.OpenAPI.Definitions[$tag].Security = @()
        }

        # Apply authentication to each expanded auth name
        foreach ($authName in (Expand-PodeAuthMerge -Names $Name)) {
            $authType = Get-PodeAuth $authName

            # Determine the scopes of the authentication
            if ($authType.Scheme.Arguments.Scopes) {
                $Scopes = @($authType.Scheme.Arguments.Scopes)
            }
            else {
                $Scopes = @()
            }

            # Update the OpenAPI definition with the authentication information
            $PodeContext.Server.OpenAPI.Definitions[$tag].Security += [ordered]@{
                Definition = [ordered]@{ "$($authName -replace '\s+', '')" = $Scopes }
                Route      = (ConvertTo-PodeRouteRegex -Path $Route)
            }
        }
    }
}

<#
.SYNOPSIS
    Resolves references in an OpenAPI schema component based on definitions within a specified definition tag context.

.DESCRIPTION
    This function navigates through a schema's properties and resolves `$ref` references to actual schemas defined within the specified definition context.
    It handles complex constructs such as 'allOf', 'oneOf', and 'anyOf', merging properties and ensuring the schema is fully resolved without unresolved references.

.PARAMETER ComponentSchema
    A hashtable representing the schema of a component where references need to be resolved.

.PARAMETER DefinitionTag
    A string identifier for the specific set of schema definitions under which references should be resolved.

.EXAMPLE
    $schema = [ordered]@{
        type = 'object';
        properties = [ordered]@{
            name = [ordered]@{
                type = 'string'
            };
            details = [ordered]@{
                '$ref' = '#/components/schemas/UserDetails'
            }
        };
    }
    Resolve-PodeOAReference -ComponentSchema $schema -DefinitionTag 'v1'

    This example demonstrates resolving a reference to 'UserDetails' within a given component schema.
#>
function Resolve-PodeOAReference {
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [hashtable]
        $ComponentSchema,

        [Parameter(Mandatory = $true)]
        [string]
        $DefinitionTag
    )

    begin {
        # Initialize schema storage and a list to track keys that need resolution
        $Schemas = $PodeContext.Server.OpenAPI.Definitions[$DefinitionTag].hiddenComponents.schemaJson
        $Keys = @()
    }

    process {
        # Gather all keys from properties and directly from the schema that might have references
        if ($ComponentSchema.properties) {
            foreach ($item in $ComponentSchema.properties.Keys) {
                $Keys += $item
            }
        }
        foreach ($item in $ComponentSchema.Keys) {
            if ( @('allof', 'oneof', 'anyof') -icontains $item ) {
                $Keys += $item
            }
        }

        # Process each key to resolve references or merge schema definitions
        foreach ($key in $Keys) {
            if ( @('allof', 'oneof', 'anyof') -icontains $key ) {
                # Handle complex schema constructs like allOf, oneOf, and anyOf
                switch ($key.ToLower()) {
                    'allof' {
                        $tmpProp = @()
                        foreach ( $comp in $ComponentSchema[$key] ) {
                            if ($comp.'$ref') {
                                # Resolve $ref to a schema if it starts with the expected path
                                if (($comp.'$ref').StartsWith('#/components/schemas/')) {
                                    $refName = ($comp.'$ref') -replace '#/components/schemas/', ''
                                    if ($Schemas.ContainsKey($refName)) {
                                        $tmpProp += $Schemas[$refName].schema
                                    }
                                }
                            }
                            elseif ( $comp.properties) {
                                # Recursively resolve nested schemas
                                if ($comp.type -eq 'object') {
                                    $tmpProp += Resolve-PodeOAReference -DefinitionTag $DefinitionTag -ComponentSchema$comp
                                }
                                else {
                                    # Unsupported object
                                    throw ($PodeLocale.unsupportedObjectExceptionMessage)
                                }
                            }
                        }
                        # Update the main schema to be an object and add resolved properties
                        $ComponentSchema.type = 'object'
                        $ComponentSchema.remove('allOf')
                        if ($tmpProp.count -gt 0) {
                            foreach ($t in $tmpProp) {
                                $ComponentSchema.properties += $t.properties
                            }
                        }

                    }
                    'oneof' {
                        # Throw an error for unsupported schema constructs to notify the user
                        # Validation of schema with oneof is not supported
                        throw ($PodeLocale.validationOfOneOfSchemaNotSupportedExceptionMessage)
                    }
                    'anyof' {
                        # Throw an error for unsupported schema constructs to notify the user
                        # Validation of schema with anyof is not supported
                        throw ($PodeLocale.validationOfAnyOfSchemaNotSupportedExceptionMessage)
                    }
                }
            }
            elseif ($ComponentSchema.properties[$key].type -eq 'object') {
                # Recursively resolve object-type properties
                $ComponentSchema.properties[$key].properties = Resolve-PodeOAReference -DefinitionTag $DefinitionTag -ComponentSchema $ComponentSchema.properties[$key].properties
            }
            elseif ($ComponentSchema.properties[$key].'$ref') {
                # Resolve property references within the main properties of the schema
                if (($ComponentSchema.properties[$key].'$ref').StartsWith('#/components/schemas/')) {
                    $refName = ($ComponentSchema.properties[$key].'$ref') -replace '#/components/schemas/', ''
                    if ($Schemas.ContainsKey($refName)) {
                        $ComponentSchema.properties[$key] = $Schemas[$refName].schema
                    }
                }
            }
            elseif ($ComponentSchema.properties[$key].items -and $ComponentSchema.properties[$key].items.'$ref' ) {
                if (($ComponentSchema.properties[$key].items.'$ref').StartsWith('#/components/schemas/')) {
                    $refName = ($ComponentSchema.properties[$key].items.'$ref') -replace '#/components/schemas/', ''
                    if ($Schemas.ContainsKey($refName)) {
                        $ComponentSchema.properties[$key].items = $schemas[$refName].schema
                    }
                }
            }
        }
    }

    end {
        # Return the fully resolved component schema
        return $ComponentSchema
    }
}

<#
.SYNOPSIS
    Creates a new OpenAPI property object based on provided parameters.

.DESCRIPTION
    The New-PodeOAPropertyInternal function constructs an OpenAPI property object using parameters like type, name,
    description, and various other attributes. It is used internally for building OpenAPI documentation elements in the Pode framework.

.PARAMETER Type
    The type of the property. This parameter is optional if the type is specified in the Params hashtable.

.PARAMETER Params
    A hashtable containing various attributes of the property such as name, description, format, and constraints like
    required, readOnly, writeOnly, etc.

.OUTPUTS
    System.Collections.Specialized.OrderedDictionary
    An ordered dictionary representing the constructed OpenAPI property object.

.EXAMPLE
    $property = New-PodeOAPropertyInternal -Type 'string' -Params $myParams

    Demonstrates how to create an OpenAPI property object of type 'string' using the specified parameters.

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function New-PodeOAPropertyInternal {
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param (
        [String]
        $Type,

        [Parameter(Mandatory = $true)]
        [hashtable]
        $Params

    )

    # Initialize an ordered dictionary for the property
    $param = [ordered]@{}

    # Set the type of the property
    if ($type) {
        $param.type = $type
    }
    else {
        if ( $Params.type) {
            $param.type = $Params.type
        }
        else {
            # Cannot create the property no type is defined
            throw ($PodeLocale.cannotCreatePropertyWithoutTypeExceptionMessage)
        }
    }

    # Set name if provided
    if ($Params.Name) {
        $param.name = $Params.Name
    }

    # Set description if provided
    if ($Params.Description) {
        $param.description = $Params.Description
    }

    # Additional property settings based on provided parameters
    if ($Params.Array.IsPresent) { $param.array = $Params.Array.IsPresent }

    if ($Params.Object.IsPresent) { $param.object = $Params.Object.IsPresent }

    if ($Params.Required.IsPresent) { $param.required = $Params.Required.IsPresent }

    if ($Params.Default) { $param.default = $Params.Default }

    if ($Params.Format) { $param.format = $Params.Format.ToLowerInvariant() }

    if ($Params.Deprecated.IsPresent) { $param.deprecated = $Params.Deprecated.IsPresent }

    if ($Params.Nullable.IsPresent) { $param.nullable = $Params.Nullable.IsPresent }

    if ($Params.WriteOnly.IsPresent) { $param.writeOnly = $Params.WriteOnly.IsPresent }

    if ($Params.ReadOnly.IsPresent) { $param.readOnly = $Params.ReadOnly.IsPresent }

    if ($Params.Example) { $param.example = $Params.Example }

    if ($Params.UniqueItems.IsPresent) { $param.uniqueItems = $Params.UniqueItems.IsPresent }

    if ($Params.ContainsKey('MaxItems')) { $param.maxItems = $Params.MaxItems }

    if ($Params.ContainsKey('MinItems')) { $param.minItems = $Params.MinItems }

    if ($Params.Enum) { $param.enum = $Params.Enum }

    if ($Params.ContainsKey('Minimum')) { $param.minimum = $Params.Minimum }

    if ($Params.ContainsKey('Maximum')) { $param.maximum = $Params.Maximum }

    if ($Params.ExclusiveMaximum.IsPresent) { $param.exclusiveMaximum = $Params.ExclusiveMaximum.IsPresent }

    if ($Params.ExclusiveMinimum.IsPresent) { $param.exclusiveMinimum = $Params.ExclusiveMinimum.IsPresent }
    if ($Params.MultiplesOf) { $param.multipleOf = $Params.MultiplesOf }

    if ($Params.Pattern) { $param.pattern = $Params.Pattern }

    if ($Params.ContainsKey('MinLength')) { $param.minLength = $Params.MinLength }

    if ($Params.ContainsKey('MaxLength')) { $param.maxLength = $Params.MaxLength }

    if ($Params.ContainsKey('MinProperties')) { $param.minProperties = $Params.MinProperties }

    if ($Params.ContainsKey('MaxProperties')) { $param.maxProperties = $Params.MaxProperties }

    if ($Params.XmlName -or $Params.XmlNamespace -or $Params.XmlPrefix -or $Params.XmlAttribute.IsPresent -or $Params.XmlWrapped.IsPresent) {

        $param.xml = [ordered]@{}

        if ($Params.XmlName) { $param.xml.name = $Params.XmlName }

        if ($Params.XmlNamespace) { $param.xml.namespace = $Params.XmlNamespace }

        if ($Params.XmlPrefix) { $param.xml.prefix = $Params.XmlPrefix }

        if ($Params.XmlAttribute.IsPresent) { $param.xml.attribute = $Params.XmlAttribute.IsPresent }

        if ($Params.XmlWrapped.IsPresent) { $param.xml.wrapped = $Params.XmlWrapped.IsPresent }
    }

    if ($Params.XmlItemName) { $param.xmlItemName = $Params.XmlItemName }

    if ($Params.ExternalDocs) { $param.externalDocs = $Params.ExternalDocs }

    if ($Params.NoAdditionalProperties.IsPresent -and $Params.AdditionalProperties) {
        # Parameters 'NoAdditionalProperties' and 'AdditionalProperties' are mutually exclusive
        throw ($PodeLocale.parametersMutuallyExclusiveExceptionMessage -f 'NoAdditionalProperties', 'AdditionalProperties')
    }
    else {
        if ($Params.NoAdditionalProperties.IsPresent) { $param.additionalProperties = $false }

        if ($Params.AdditionalProperties) { $param.additionalProperties = $Params.AdditionalProperties }
    }

    return $param
}


<#
.SYNOPSIS
    Converts header properties to a format compliant with OpenAPI specifications.

.DESCRIPTION
    The ConvertTo-PodeOAHeaderProperty function is designed to take an array of hashtables representing header properties and
    convert them into a structure suitable for OpenAPI documentation. It ensures that each header property includes a name and
    schema definition and can handle additional attributes like description.

.PARAMETER Headers
    An array of hashtables, where each hashtable represents a header property with attributes like name, type, description, etc.

.EXAMPLE
    $headerProperties = ConvertTo-PodeOAHeaderProperty -Headers $myHeaders

    This example demonstrates how to convert an array of header properties into a format suitable for OpenAPI documentation.

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function ConvertTo-PodeOAHeaderProperty {
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [hashtable[]]
        $Headers
    )

    begin {
        # Initialize an array to hold piped-in values
        $pipelineValue = @()
        $elems = [ordered]@{}
    }

    process {
        # Add the current piped-in value to the array
        $pipelineValue += $_
    }

    end {
        # Set Headers to the array of values
        if ($pipelineValue.Count -gt 1) {
            $Headers = $pipelineValue
        }

        foreach ($e in $Headers) {
            # Ensure each header has a name
            if ($e.name) {
                $elems.$($e.name) = @{}
                # Add description if present
                if ($e.description) {
                    $elems.$($e.name).description = $e.description
                }
                # Define the schema, including the type and any additional properties
                $elems.$($e.name).schema = @{
                    type = $($e.type)
                }
                foreach ($k in $e.keys) {
                    if (@('name', 'description') -notcontains $k) {
                        $elems.$($e.name).schema.$k = $e.$k
                    }
                }
            }
            else {
                # Header requires a name when used in an encoding context
                throw ($PodeLocale.headerMustHaveNameInEncodingContextExceptionMessage)
            }
        }

        return $elems
    }
}


<#
.SYNOPSIS
    Creates a new OpenAPI callback component for a given definition tag.

.DESCRIPTION
    The New-PodeOAComponentCallBackInternal function constructs an OpenAPI callback component based on provided parameters.
    This function is designed for internal use within the Pode framework to define callbacks in OpenAPI documentation.
    It handles the creation of callback structures including the path, HTTP method, request bodies, and responses
    based on the given definition tag.

.PARAMETER Params
    A hashtable containing parameters for the callback component, such as Method, Path, RequestBody, and Responses.

.PARAMETER DefinitionTag
    A mandatory string parameter that specifies the definition tag in OpenAPI documentation.

.EXAMPLE
    $callback = New-PodeOAComponentCallBackInternal -Params $myParams -DefinitionTag 'myTag'

    This example demonstrates how to create an OpenAPI callback component for 'myTag' using the provided parameters.

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function New-PodeOAComponentCallBackInternal {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]
        $Params,

        [Parameter(Mandatory = $true)]
        [string]
        $DefinitionTag
    )

    # Convert HTTP method to lower case
    $_method = $Params.Method.ToLower()

    # Construct the base structure for the callback with the given path and method
    $callBack = [ordered]@{
        "'$($Params.Path)'" = [ordered]@{
            $_method = [ordered]@{}
        }
    }

    # Add request body to the callback if it is specified for the given definition tag
    if ($Params.RequestBody.ContainsKey($DefinitionTag)) {
        $callBack."'$($Params.Path)'".$_method.requestBody = $Params.RequestBody[$DefinitionTag]
    }

    # Add responses to the callback if they are specified for the given definition tag
    if ($Params.Responses.ContainsKey($DefinitionTag)) {
        $callBack."'$($Params.Path)'".$_method.responses = $Params.Responses[$DefinitionTag]
    }

    # Return the constructed callback object
    return $callBack

}

<#
.SYNOPSIS
        Creates a new OpenAPI response object based on provided parameters and a definition tag.

    .DESCRIPTION
        The New-PodeOResponseInternal function constructs an OpenAPI response object using provided parameters.
        It sets a description for the status code, references existing components if specified,
        and builds content-type and header schemas. This function is intended for internal use within the
        Pode framework for API documentation purposes.

    .PARAMETER Params
        A hashtable containing parameters for building the OpenAPI response object, including description,
        status code, content, headers, links, and reference to existing components.

    .PARAMETER DefinitionTag
        A mandatory string parameter that specifies the definition tag in OpenAPI documentation.

    .EXAMPLE
        $response = New-PodeOResponseInternal -Params $myParams -DefinitionTag 'myTag'

        This example demonstrates how to create an OpenAPI response object for 'myTag' using the provided parameters.

    .NOTES
        This is an internal function and may change in future releases of Pode.
#>
function New-PodeOResponseInternal {
    param(
        [hashtable]
        $Params,

        [Parameter(Mandatory = $true)]
        [string]
        $DefinitionTag
    )

    # Set a general description for the status code
    if ([string]::IsNullOrWhiteSpace($Params.Description)) {
        if ($Params.Default) {
            $Description = 'Default Response.'
        }
        elseif ([int]::TryParse($Params.StatusCode, [ref]$null)) {
            $Description = Get-PodeStatusDescription -StatusCode $Params.StatusCode
        }
        else {
            # A Description is required
            throw ($PodeLocale.descriptionRequiredExceptionMessage -f $params.Route.path, $Params.StatusCode )
        }
    }
    else {
        $Description = $Params.Description
    }

    # Handle response referencing an existing component
    if ($Params.Reference) {
        Test-PodeOAComponentInternal -Field responses -DefinitionTag $DefinitionTag -Name $Params.Reference -PostValidation
        $response = [ordered]@{
            '$ref' = "#/components/responses/$($Params.Reference)"
        }
    }
    else {
        # Build content-type schemas if provided
        $_content = $null
        if ($null -ne $Params.Content) {
            $_content = ConvertTo-PodeOAObjectSchema -DefinitionTag $DefinitionTag -Content $Params.Content
        }

        # Build header schemas based on the type of the Headers parameter
        $_headers = $null
        if ($null -ne $Params.Headers) {
            if ($Params.Headers -is [System.Object[]] -or $Params.Headers -is [string] -or $Params.Headers -is [string[]]) {
                if ($Params.Headers -is [System.Object[]] -and $Params.Headers.Count -gt 0 -and ($Params.Headers[0] -is [hashtable] -or $Params.Headers[0] -is [System.Collections.Specialized.OrderedDictionary])) {
                    $_headers = ConvertTo-PodeOAHeaderProperty -Headers $Params.Headers
                }
                else {
                    $_headers = [ordered]@{}
                    foreach ($h in $Params.Headers) {
                        Test-PodeOAComponentInternal -Field headers -DefinitionTag $DefinitionTag -Name $h -PostValidation
                        $_headers[$h] = [ordered]@{
                            '$ref' = "#/components/headers/$h"
                        }
                    }
                }
            }
            elseif ($Params.Headers -is [hashtable]) {
                $_headers = ConvertTo-PodeOAObjectSchema -DefinitionTag $DefinitionTag -Content $Params.Headers
            }
        }

        # Construct the response object
        $response = [ordered]@{
            description = $Description
        }

        if ($_headers) { $response.headers = $_headers }

        if ($_content) { $response.content = $_content }

        if ($Params.Links) { $response.links = $Params.Links }

    }

    return $response
}




<#
.SYNOPSIS
    Creates a new OpenAPI response link object.

.DESCRIPTION
    The New-PodeOAResponseLinkInternal function generates an OpenAPI response link object from provided parameters.
    This includes setting up descriptions, operation IDs, references, parameters, and request bodies for the link.
    This function is designed for internal use within the Pode framework to facilitate the creation of response
    link objects in OpenAPI documentation.

.PARAMETER Params
    A hashtable of parameters for the OpenAPI response link.

.EXAMPLE
    $link = New-PodeOAResponseLinkInternal -Params $myParams

    Generates a new OpenAPI response link object using the provided parameters in $myParams.

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function New-PodeOAResponseLinkInternal {
    param(
        [hashtable]
        $Params
    )

    # Initialize an ordered dictionary for the link
    $link = [ordered]@{}

    # Add properties to the link based on the provided parameters
    if ($Params.Description) { $link.description = $Params.Description }
    if ($Params.OperationId) { $link.operationId = $Params.OperationId }
    if ($Params.OperationRef) { $link.operationRef = $Params.OperationRef }
    if ($Params.Parameters) { $link.parameters = $Params.Parameters }
    if ($Params.RequestBody) { $link.requestBody = $Params.RequestBody }

    return $link
}


<#
.SYNOPSIS
Tests the internal OpenAPI definitions for compliance and validity.

.DESCRIPTION
The Test-PodeOADefinitionInternal function validates OpenAPI definitions within the Pode framework.
It checks for various issues like undefined references, mandatory fields (like title and version),
and missing components. If any issues are found, they are displayed with detailed messages, and
the function throws an error indicating non-compliance with OpenAPI document standards.

.EXAMPLE
Test-PodeOADefinitionInternal

This example demonstrates how to call the function to validate OpenAPI definitions.

.NOTES
This is an internal function and may change in future releases of Pode.
#>

function Test-PodeOADefinitionInternal {

    # Validate OpenAPI definitions and store any issues found
    $definitionIssues = Test-PodeOADefinition

    # Check if the validation result indicates issues
    if (! $definitionIssues.valid) {
        # Print a header for undefined OpenAPI references
        # Undefined OpenAPI References
        Write-PodeHost $PodeLocale.undefinedOpenApiReferencesMessage -ForegroundColor Red

        # Iterate over each issue found in the definitions
        foreach ($tag in $definitionIssues.issues.keys) {
            # Definition tag
            Write-PodeHost ($PodeLocale.definitionTagMessage -f $tag) -ForegroundColor Red

            # Check and display issues related to OpenAPI document generation error
            if ($definitionIssues.issues[$tag].definition ) {
                # OpenAPI generation document error
                Write-PodeHost $PodeLocale.openApiGenerationDocumentErrorMessage -ForegroundColor Red
                Write-PodeHost " $($definitionIssues.issues[$tag].definition)" -ForegroundColor Red
            }

            # Check for missing mandatory 'title' field
            if ($definitionIssues.issues[$tag].title ) {
                # info.title is mandatory
                Write-PodeHost $PodeLocale.infoTitleMandatoryMessage -ForegroundColor Red
            }

            # Check for missing mandatory 'version' field
            if ($definitionIssues.issues[$tag].version ) {
                # info.version is mandatory
                Write-PodeHost $PodeLocale.infoVersionMandatoryMessage -ForegroundColor Red
            }

            # Check for missing components and list them
            if ($definitionIssues.issues[$tag].components ) {
                # Missing component(s)
                Write-PodeHost $PodeLocale.missingComponentsMessage -ForegroundColor Red
                foreach ($key in $definitionIssues.issues[$tag].components.keys) {
                    $occurences = $definitionIssues.issues[$tag].components[$key]
                    # Adjust occurrence count based on schema validation setting
                    if ( $PodeContext.Server.OpenAPI.Definitions[$tag].hiddenComponents.schemaValidation) {
                        $occurences = $occurences / 2
                    }
                    Write-PodeHost "`$refs : $key ($occurences)" -ForegroundColor Red
                }
            }

            # Add a blank line for readability
            Write-PodeHost
        }

        # Throw an error indicating non-compliance with OpenAPI standards
        # OpenAPI document compliance issues
        throw ($PodeLocale.openApiDocumentNotCompliantExceptionMessage)
    }
}

<#
.SYNOPSIS
    Check the OpenAPI component exist (Internal Function)

.DESCRIPTION
    Check the OpenAPI component exist (Internal Function)

.PARAMETER Field
    The component type

.PARAMETER Name
    The component Name

.PARAMETER DefinitionTag
    An Array of strings representing the unique tag for the API specification.
    This tag helps in distinguishing between different versions or types of API specifications within the application.
    You can use this tag to reference the specific API documentation, schema, or version that your function interacts with.

.PARAMETER ThrowException
    Generate an exception if the component doesn't exist

.PARAMETER PostValidation
    Postpone the check before the server start

.EXAMPLE
    Test-PodeOAComponentInternal -Field 'responses' -Name 'myresponse' -DefinitionTag 'default'

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function Test-PodeOAComponentInternal {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet( 'schemas' , 'responses' , 'parameters' , 'examples' , 'requestBodies' , 'headers' , 'securitySchemes' , 'links' , 'callbacks' , 'pathItems')]
        [string]
        $Field,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name,

        [string[]]
        $DefinitionTag,

        [switch]
        $ThrowException,

        [switch]
        $PostValidation
    )

    $DefinitionTag = Test-PodeOADefinitionTag -Tag $DefinitionTag
    if ($PostValidation.IsPresent) {
        foreach ($tag in $DefinitionTag) {
            if (! ($PodeContext.Server.OpenAPI.Definitions[$tag].hiddenComponents.postValidation[$field].keys -ccontains $Name)) {
                $PodeContext.Server.OpenAPI.Definitions[$tag].hiddenComponents.postValidation[$field][$name] = 1
            }
            else {
                $PodeContext.Server.OpenAPI.Definitions[$tag].hiddenComponents.postValidation[$field][$name] += 1
            }
        }
    }
    else {
        foreach ($tag in $DefinitionTag) {
            if (!($PodeContext.Server.OpenAPI.Definitions[$tag].components[$field].keys -ccontains $Name)) {
                # If $Name is not found in the current $tag, return $false or throw an exception
                if ($ThrowException.IsPresent ) {
                    throw ($PodeLocale.noComponentInDefinitionExceptionMessage -f $field, $Name, $tag) #"No component of type $field named $Name is available in the $tag definition."
                }
                else {
                    return $false
                }
            }
        }
        if (!$ThrowException.IsPresent) {
            return $true
        }
    }
}




<#
.SYNOPSIS
    Converts a Pode route path into an OpenAPI-compliant route path format.

.DESCRIPTION
    This internal function takes a Pode route path and replaces placeholders with OpenAPI-style placeholders.
    Specifically, it converts Pode route placeholders (e.g., `:id`) to OpenAPI placeholders (e.g., `{id}`).

.PARAMETER Path
    The Pode route path that contains placeholders to be converted to the OpenAPI format.

.RETURNS
    The converted OpenAPI-compliant route path as a string.

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function ConvertTo-PodeOARoutePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Path
    )

    return ([regex]::Unescape((Resolve-PodePlaceholder -Path $Path -Pattern '\:(?<tag>[\w]+)' -Prepend '{' -Append '}')))
}

<#
.SYNOPSIS
    Tests and validates the OpenAPI Definition Tag for a specific route in Pode.

.DESCRIPTION
    This function ensures that the OpenAPI Definition Tag for a route is correctly configured.
    If the route already has an OpenAPI Definition Tag configured, it verifies if the new tag is allowed.
    If the OpenAPI Definition Tag has not been configured, it validates and sets the provided tag.

.PARAMETER Route
    A hashtable representing the route that is being tested for the OpenAPI Definition Tag.

.PARAMETER DefinitionTag
    An optional array of strings representing the Definition Tag(s) to be tested and assigned.

.RETURNS
    Returns the validated DefinitionTag for the route.

.EXAMPLE
    $Route = @{
        OpenApi = @{
            IsDefTagConfigured = $false
            DefinitionTag = @()
        }
    }
    $DefinitionTag = @('tag1', 'tag2')
    Test-PodeRouteOADefinitionTag -Route $Route -DefinitionTag $DefinitionTag

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function Test-PodeRouteOADefinitionTag {
    param(
        [Parameter(Mandatory = $true )]
        [ValidateNotNullOrEmpty()]
        [hashtable ]
        $Route,

        [string[]]
        $DefinitionTag
    )
    # Check if the OpenAPI Definition Tag is already configured
    if ($Route.OpenApi.IsDefTagConfigured) {
        # If a DefinitionTag is provided
        if ($DefinitionTag) {
            # Loop through each element in $DefinitionTag
            if ($DefinitionTag | ForEach-Object {

                    # Check if the current element exists in the already configured DefinitionTag
                    if (!($Route.OpenApi.DefinitionTag -contains $_)) {
                        # If any element in $DefinitionTag is not present in the configured DefinitionTag, throw an exception
                        throw ($PodeLocale.definitionTagChangeNotAllowedExceptionMessage)
                    }
                    # Return $true for each element to continue the check
                    $true
                }
            ) {
                # If all elements in $DefinitionTag are present in the configured DefinitionTag, assign it to $oaDefinitionTag
                return $DefinitionTag
            }
        }

        return $Route.OpenApi.DefinitionTag
    }
    # If the OpenAPI Definition Tag is not configured yet

    # Validate the provided DefinitionTag and assign it to $oaDefinitionTag
    $oaDefinitionTag = Test-PodeOADefinitionTag -Tag $DefinitionTag
    # Set the validated DefinitionTag as the OpenAPI DefinitionTag
    $Route.OpenApi.DefinitionTag = $oaDefinitionTag
    # Mark the OpenAPI DefinitionTag as configured
    $Route.OpenApi.IsDefTagConfigured = $true


    return  $oaDefinitionTag
}


<#
.SYNOPSIS
    Displays OpenAPI endpoint information for each definition in Pode.

.DESCRIPTION
    The `Show-PodeOAConsoleInfo` function iterates through the OpenAPI definitions
    configured in the Pode server and displays their associated specification and
    documentation endpoints in the console. The information includes protocol, address,
    and paths for specification and documentation endpoints.

.PARAMETER Force
    Overrides the -Quiet flag of the server.

.EXAMPLE
    Show-PodeOAConsoleInfo

    This command will output the OpenAPI information for all definitions currently
    configured in the Pode server, including specification and documentation URLs.

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function Show-PodeOAConsoleInfo {
    param(
        [switch]
        $Force
    )
    # state the OpenAPI endpoints for each definition
    foreach ($key in  $PodeContext.Server.OpenAPI.Definitions.keys) {
        $bookmarks = $PodeContext.Server.OpenAPI.Definitions[$key].hiddenComponents.bookmarks
        if ( !$bookmarks) {
            continue
        }

        Write-PodeHost -Force:$Force
        if (!$OpenAPIHeader) {
            # OpenAPI Info
            Write-PodeHost $PodeLocale.openApiInfoMessage -ForegroundColor Green -Force:$Force
            $OpenAPIHeader = $true
        }
        Write-PodeHost " '$key':" -ForegroundColor Yellow -Force:$Force

        if ($bookmarks.route.count -gt 1 -or $bookmarks.route.Endpoint.Name) {
            # Specification
            Write-PodeHost "   - $($PodeLocale.specificationMessage):" -ForegroundColor Yellow -Force:$Force
            foreach ($endpoint in   $bookmarks.route.Endpoint) {
                Write-PodeHost "     . $($endpoint.Protocol)://$($endpoint.Address)$($bookmarks.openApiUrl)" -ForegroundColor White -Force:$Force
            }
            # Documentation
            Write-PodeHost "   - $($PodeLocale.documentationMessage):" -ForegroundColor Yellow -Force:$Force
            foreach ($endpoint in   $bookmarks.route.Endpoint) {
                Write-PodeHost "     . $($endpoint.Protocol)://$($endpoint.Address)$($bookmarks.path)" -ForegroundColor White -Force:$Force
            }
        }
        else {
            # Specification
            Write-PodeHost "   - $($PodeLocale.specificationMessage):" -ForegroundColor Yellow -Force:$Force
            $PodeContext.Server.EndpointsInfo | ForEach-Object {
                if ($_.Pool -eq 'web') {
                    $url = [System.Uri]::new( [System.Uri]::new($_.Url), $bookmarks.openApiUrl)
                    Write-PodeHost "     . $url" -ForegroundColor White -Force:$Force
                }
            }
            Write-PodeHost "   - $($PodeLocale.documentationMessage):" -ForegroundColor Yellow -Force:$Force
            $PodeContext.Server.EndpointsInfo | ForEach-Object {
                if ($_.Pool -eq 'web') {
                    $url = [System.Uri]::new( [System.Uri]::new($_.Url), $bookmarks.path)
                    Write-PodeHost "     . $url" -ForegroundColor White -Force:$Force
                }
            }
        }
    }
}

function Test-PodeOAEnabled {
    foreach ($key in  $PodeContext.Server.OpenAPI.Definitions.keys) {
        $bookmarks = $PodeContext.Server.OpenAPI.Definitions[$key].hiddenComponents.bookmarks
        if (  $bookmarks) {
            return $true
        }
    }
    return $false
}