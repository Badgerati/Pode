function ConvertTo-PodeOAContentTypeSchema
{
    param(
        [Parameter(ValueFromPipeline=$true)]
        [hashtable]
        $Schemas
    )

    if (Test-IsEmpty $Schemas) {
        return $null
    }

    # ensure all content types are valid
    foreach ($type in $Schemas.Keys) {
        if ($type -inotmatch '^\w+\/[\w\.\+-]+$') {
            throw "Invalid content-type found for schema: $($type)"
        }
    }

    # convert each schema to openapi format
    return (ConvertTo-PodeOAObjectSchema -Schemas $Schemas)
}

function ConvertTo-PodeOAHeaderSchema
{
    param(
        [Parameter(ValueFromPipeline=$true)]
        [hashtable]
        $Schemas
    )

    if (Test-IsEmpty $Schemas) {
        return $null
    }

    # convert each schema to openapi format
    return (ConvertTo-PodeOAObjectSchema -Schemas $Schemas)
}

function ConvertTo-PodeOAObjectSchema
{
    param(
        [Parameter(ValueFromPipeline=$true)]
        [hashtable]
        $Schemas
    )

    # convert each schema to openapi format
    $obj = @{}
    foreach ($type in $Schemas.Keys) {
        $obj[$type] = @{
            schema = $null
        }

        # add a shared component schema reference
        if ($Schemas[$type] -is [string]) {
            if (!(Test-PodeOAComponentSchema -Name $Schemas[$type])) {
                throw "The OpenApi component schema doesn't exist: $($Schemas[$type])"
            }

            $obj[$type].schema = @{
                '$ref' = "#/components/schemas/$($Schemas[$type])"
            }
        }

        # add a set schema object
        else {
            $obj[$type].schema = ($Schemas[$type] | ConvertTo-PodeOASchemaProperty)
        }
    }

    return $obj
}

function Test-PodeOAComponentSchema
{
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Name
    )

    return $PodeContext.Server.OpenAPI.components.schemas.ContainsKey($Name)
}

function Test-PodeOAComponentResponse
{
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Name
    )

    return $PodeContext.Server.OpenAPI.components.responses.ContainsKey($Name)
}

function Test-PodeOAComponentRequestBody
{
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Name
    )

    return $PodeContext.Server.OpenAPI.components.requestBodies.ContainsKey($Name)
}

function Test-PodeOAComponentParameter
{
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Name
    )

    return $PodeContext.Server.OpenAPI.components.parameters.ContainsKey($Name)
}

function ConvertTo-PodeOASchemaProperty
{
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [hashtable]
        $Property
    )

    # base schema type
    $schema = @{
        type = $Property.type
        format = $Property.format
    }

    # are we using an array?
    if ($Property.array) {
        $Property.array = $false

        $schema = @{
            type = 'array'
            items = ($Property | ConvertTo-PodeOASchemaProperty)
        }
    }

    # are we using an object?
    if ($Property.object) {
        $Property.object = $false

        $schema = @{
            type = 'object'
            properties = (ConvertTo-PodeOASchemaObjectProperty -Properties $Property)
        }

        if ($Property.required) {
            $schema['required'] = @($Property.name)
        }
    }

    if ($Property.type -ieq 'object') {
        $schema['properties'] = (ConvertTo-PodeOASchemaObjectProperty -Properties $Property.properties)
        $schema['required'] = @(($Property.properties | Where-Object { $_.required }).name)
    }

    return $schema
}

function ConvertTo-PodeOASchemaObjectProperty
{
    param(
        [Parameter(Mandatory=$true)]
        [hashtable[]]
        $Properties
    )

    $schema = @{}

    foreach ($prop in $Properties) {
        $schema[$prop.name] = ($prop | ConvertTo-PodeOASchemaProperty)
    }

    return $schema
}