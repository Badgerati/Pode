function ConvertFrom-PodeOpenApiComponentSchemaProperties
{
    param(
        [Parameter(Mandatory=$true)]
        [hashtable[]]
        $Properties
    )

    $props = @{}
    foreach ($prop in $Properties) {
        $props[$prop.name] = $prop
    }

    return $props
}