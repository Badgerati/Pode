# function ConvertFrom-PodeOAComponentSchemaProperties
# {
#     param(
#         [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
#         [hashtable[]]
#         $Properties
#     )

#     $props = @{}
#     foreach ($prop in $Properties) {
#         $props[$prop.name] = $prop
#     }

#     return $props
# }

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

    # convert each content schema to openapi format
    $contents = @{}
    foreach ($type in $Schemas.Keys) {
        $contents[$type] = @{
            schema = ($Schemas[$type] | ConvertTo-PodeOASchemaProperty)
        }
    }

    return $contents
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