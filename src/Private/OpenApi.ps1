function ConvertFrom-PodeOpenApiComponentSchemaProperties
{
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [hashtable[]]
        $Properties
    )

    $props = @{}
    foreach ($prop in $Properties) {
        $props[$prop.name] = $prop
    }

    return $props
}

function ConvertFrom-PodeOpenApiContentTypeSchema
{
    param(
        [Parameter(ValueFromPipeline=$true)]
        [hashtable[]]
        $Schemas
    )

    if (Test-IsEmpty $Schemas) {
        return $null
    }

    $contents = @{}
    foreach ($schema in $Schemas) {
        $contents["$($schema.Keys | Select-Object -First 1)"] = @{
            schema = ($schema.Values | Select-Object -First 1)
        }
    }

    return $contents
}