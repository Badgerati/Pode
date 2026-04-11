<#
.SYNOPSIS
Creates a Null JSON Schema type definition.

.DESCRIPTION
This function creates a JSON Schema type definition for a Null type.

.PARAMETER Description
An optional Description.

.EXAMPLE
New-PodeJsonSchemaNull

.EXAMPLE
New-PodeJsonSchemaNull -Description 'This is a null type'
#>
function New-PodeJsonSchemaNull {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter()]
        [string]
        $Description
    )

    # build the property definition
    $def = @{
        type = 'null'
    }

    if ($PSBoundParameters.ContainsKey('Description') -and ![string]::IsNullOrEmpty($Description)) {
        $def.description = $Description
    }

    return $def
}

<#
.SYNOPSIS
Creates a Boolean JSON Schema type definition.

.DESCRIPTION
This function creates a JSON Schema type definition for a Boolean type.

.PARAMETER Constant
An optional Constant value.

.PARAMETER Description
An optional Description.

.EXAMPLE
New-PodeJsonSchemaBoolean

.EXAMPLE
New-PodeJsonSchemaBoolean -Constant $true -Description 'Some property that must be true'
#>
function New-PodeJsonSchemaBoolean {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter()]
        [bool]
        $Constant,

        [Parameter()]
        [string]
        $Description
    )

    # build the property definition
    $def = @{
        type = 'boolean'
    }

    if ($PSBoundParameters.ContainsKey('Constant')) {
        $def.const = $Constant
    }

    if ($PSBoundParameters.ContainsKey('Description') -and ![string]::IsNullOrEmpty($Description)) {
        $def.description = $Description
    }

    return $def
}

<#
.SYNOPSIS
Creates an Integer JSON Schema type definition.

.DESCRIPTION
This function creates a JSON Schema type definition for an Integer type.

.PARAMETER MultipleOf
An optional value that the integer must be a multiple of.

.PARAMETER Minimum
An optional minimum value for the integer.

.PARAMETER Maximum
An optional maximum value for the integer.

.PARAMETER Constant
An optional Constant value.

.PARAMETER Enum
An optional array of values that the integer can be.

.PARAMETER ExclusiveMinimum
An optional switch to indicate if the minimum value is exclusive.

.PARAMETER ExclusiveMaximum
An optional switch to indicate if the maximum value is exclusive.

.PARAMETER Description
An optional Description.

.EXAMPLE
New-PodeJsonSchemaInteger

.EXAMPLE
New-PodeJsonSchemaInteger -Minimum 0 -Maximum 100 -Description 'A percentage of some value'

.EXAMPLE
New-PodeJsonSchemaInteger -Enum 1, 2, 4, 8 -Description 'Number of CPU cores to use'

.EXAMPLE
New-PodeJsonSchemaInteger -MultipleOf 5 -Description 'A value that must be a multiple of 5'

.EXAMPLE
New-PodeJsonSchemaInteger -Minimum 0 -ExclusiveMinimum -Description 'A value that must be greater than 0'

.EXAMPLE
New-PodeJsonSchemaInteger -Maximum 100 -ExclusiveMaximum -Description 'A value that must be less than 100'
#>
function New-PodeJsonSchemaInteger {
    [CmdletBinding(DefaultParameterSetName = 'Dynamic')]
    [OutputType([hashtable])]
    param(
        [Parameter(ParameterSetName = 'Dynamic')]
        [ValidateRange(0, [int]::MaxValue)]
        [int]
        $MultipleOf,

        [Parameter(ParameterSetName = 'Dynamic')]
        [int]
        $Minimum,

        [Parameter(ParameterSetName = 'Dynamic')]
        [int]
        $Maximum,

        [Parameter(ParameterSetName = 'Constant')]
        [string]
        $Constant,

        [Parameter(ParameterSetName = 'Enum')]
        [int[]]
        $Enum,

        [Parameter(ParameterSetName = 'Dynamic')]
        [switch]
        $ExclusiveMinimum,

        [Parameter(ParameterSetName = 'Dynamic')]
        [switch]
        $ExclusiveMaximum,

        [Parameter()]
        [string]
        $Description
    )

    # build the property definition
    $def = @{
        type = 'integer'
    }

    if ($PSBoundParameters.ContainsKey('Constant')) {
        $def.const = $Constant
    }

    if ($PSBoundParameters.ContainsKey('Enum')) {
        $def.enum = @($Enum)
    }

    if ($PSBoundParameters.ContainsKey('MultipleOf')) {
        $def.multipleOf = $MultipleOf
    }

    if ($PSBoundParameters.ContainsKey('Minimum')) {
        $def.minimum = $Minimum
    }
    if ($PSBoundParameters.ContainsKey('Maximum')) {
        $def.maximum = $Maximum
    }
    if ($def.ContainsKey('minimum') -and $def.ContainsKey('maximum') -and ($def.maximum -lt $def.minimum)) {
        # Maximum cannot be less than Minimum for integer JSON Schema property'
        throw ($PodeLocale.jsonSchemaNumberMaximumLessThanMinimumExceptionMessage -f 'integer')
    }

    if ($PSBoundParameters.ContainsKey('ExclusiveMinimum')) {
        $def.exclusiveMinimum = $true
    }
    if ($PSBoundParameters.ContainsKey('ExclusiveMaximum')) {
        $def.exclusiveMaximum = $true
    }

    if ($PSBoundParameters.ContainsKey('Description') -and ![string]::IsNullOrEmpty($Description)) {
        $def.description = $Description
    }

    return $def
}

<#
.SYNOPSIS
Creates a Number JSON Schema type definition.

.DESCRIPTION
This function creates a JSON Schema type definition for a Number type.

.PARAMETER MultipleOf
An optional value that the number must be a multiple of.

.PARAMETER Minimum
An optional minimum value for the number.

.PARAMETER Maximum
An optional maximum value for the number.

.PARAMETER Constant
An optional Constant value.

.PARAMETER Enum
An optional array of values that the number can be.

.PARAMETER ExclusiveMinimum
An optional switch to indicate if the minimum value is exclusive.

.PARAMETER ExclusiveMaximum
An optional switch to indicate if the maximum value is exclusive.

.PARAMETER Description
An optional Description.

.EXAMPLE
New-PodeJsonSchemaNumber

.EXAMPLE
New-PodeJsonSchemaNumber -Minimum 0.0 -Maximum 1.0 -Description 'A ratio between 0 and 1'

.EXAMPLE
New-PodeJsonSchemaNumber -Enum 3.14, 2.718, 1.618 -Description 'Some famous mathematical constants'

.EXAMPLE
New-PodeJsonSchemaNumber -MultipleOf 0.01 -Description 'A value that must be a multiple of 0.01'

.EXAMPLE
New-PodeJsonSchemaNumber -Minimum 0.0 -ExclusiveMinimum -Description 'A value that must be greater than 0.0'

.EXAMPLE
New-PodeJsonSchemaNumber -Maximum 100.0 -ExclusiveMaximum -Description 'A value that must be less than 100.0'
#>
function New-PodeJsonSchemaNumber {
    [CmdletBinding(DefaultParameterSetName = 'Dynamic')]
    [OutputType([hashtable])]
    param(
        [Parameter(ParameterSetName = 'Dynamic')]
        [ValidateRange(0, [int]::MaxValue)]
        [double]
        $MultipleOf,

        [Parameter(ParameterSetName = 'Dynamic')]
        [double]
        $Minimum,

        [Parameter(ParameterSetName = 'Dynamic')]
        [double]
        $Maximum,

        [Parameter(ParameterSetName = 'Constant')]
        [string]
        $Constant,

        [Parameter(ParameterSetName = 'Enum')]
        [double[]]
        $Enum,

        [Parameter(ParameterSetName = 'Dynamic')]
        [switch]
        $ExclusiveMinimum,

        [Parameter(ParameterSetName = 'Dynamic')]
        [switch]
        $ExclusiveMaximum,

        [Parameter()]
        [string]
        $Description
    )

    # build the property definition
    $def = @{
        type = 'number'
    }

    if ($PSBoundParameters.ContainsKey('Constant')) {
        $def.const = $Constant
    }

    if ($PSBoundParameters.ContainsKey('Enum')) {
        $def.enum = @($Enum)
    }

    if ($PSBoundParameters.ContainsKey('MultipleOf')) {
        $def.multipleOf = $MultipleOf
    }

    if ($PSBoundParameters.ContainsKey('Minimum')) {
        $def.minimum = $Minimum
    }
    if ($PSBoundParameters.ContainsKey('Maximum')) {
        $def.maximum = $Maximum
    }
    if ($def.ContainsKey('minimum') -and $def.ContainsKey('maximum') -and ($def.maximum -lt $def.minimum)) {
        # Maximum cannot be less than Minimum for number JSON Schema property
        throw ($PodeLocale.jsonSchemaNumberMaximumLessThanMinimumExceptionMessage -f 'number')
    }

    if ($PSBoundParameters.ContainsKey('ExclusiveMinimum')) {
        $def.exclusiveMinimum = $true
    }
    if ($PSBoundParameters.ContainsKey('ExclusiveMaximum')) {
        $def.exclusiveMaximum = $true
    }

    if ($PSBoundParameters.ContainsKey('Description') -and ![string]::IsNullOrEmpty($Description)) {
        $def.description = $Description
    }

    return $def
}

<#
.SYNOPSIS
Creates a String JSON Schema type definition.

.DESCRIPTION
This function creates a JSON Schema type definition for a String type.

.PARAMETER Pattern
An optional regular expression pattern that the string must match.

.PARAMETER MinLength
An optional minimum length for the string.

.PARAMETER MaxLength
An optional maximum length for the string.

.PARAMETER Constant
An optional Constant value.

.PARAMETER Enum
An optional array of values that the string can be.

.PARAMETER Description
An optional Description.

.EXAMPLE
New-PodeJsonSchemaString

.EXAMPLE
New-PodeJsonSchemaString -Pattern '^[a-zA-Z0-9]+$' -Description 'A string that must be alphanumeric'

.EXAMPLE
New-PodeJsonSchemaString -MinLength 5 -MaxLength 10 -Description 'A string that must be between 5 and 10 characters long'

.EXAMPLE
New-PodeJsonSchemaString -Enum 'red', 'green', 'blue' -Description 'A string that must be one of the specified colours'

.EXAMPLE
New-PodeJsonSchemaString -Constant 'fixed value' -Description 'A string that must be exactly "fixed value"'
#>
function New-PodeJsonSchemaString {
    [CmdletBinding(DefaultParameterSetName = 'Dynamic')]
    [OutputType([hashtable])]
    param(
        [Parameter(ParameterSetName = 'Dynamic')]
        [string]
        $Pattern,

        [Parameter(ParameterSetName = 'Dynamic')]
        [ValidateRange(0, [int]::MaxValue)]
        [int]
        $MinLength,

        [Parameter(ParameterSetName = 'Dynamic')]
        [ValidateRange(0, [int]::MaxValue)]
        [int]
        $MaxLength,

        [Parameter(ParameterSetName = 'Constant')]
        [string]
        $Constant,

        [Parameter(ParameterSetName = 'Enum')]
        [string[]]
        $Enum,

        [Parameter()]
        [string]
        $Description
    )

    # build the property definition
    $def = @{
        type = 'string'
    }

    if ($PSBoundParameters.ContainsKey('Constant')) {
        $def.const = $Constant
    }

    if ($PSBoundParameters.ContainsKey('Enum')) {
        $def.enum = @($Enum)
    }

    if ($PSBoundParameters.ContainsKey('Pattern')) {
        $def.pattern = $Pattern
    }

    if ($PSBoundParameters.ContainsKey('MinLength')) {
        $def.minLength = $MinLength
    }
    if ($PSBoundParameters.ContainsKey('MaxLength')) {
        $def.maxLength = $MaxLength
    }
    if ($def.ContainsKey('minLength') -and $def.ContainsKey('maxLength') -and ($def.maxLength -lt $def.minLength)) {
        # MaxLength cannot be less than MinLength for string JSON Schema property
        throw $PodeLocale.jsonSchemaStringMaxLengthLessThanMinLengthExceptionMessage
    }

    if ($PSBoundParameters.ContainsKey('Description') -and ![string]::IsNullOrEmpty($Description)) {
        $def.description = $Description
    }

    return $def
}

<#
.SYNOPSIS
Creates an Array JSON Schema type definition.

.DESCRIPTION
This function creates a JSON Schema type definition for an Array type.

.PARAMETER Item
A hashtable representing the JSON Schema type definition for the items in the array.

.PARAMETER MinItems
An optional minimum number of items in the array.

.PARAMETER MaxItems
An optional maximum number of items in the array.

.PARAMETER Description
An optional Description.

.PARAMETER Unique
An optional switch to indicate if the items in the array must be unique.

.EXAMPLE
# create a JSON Schema definition for an array of strings
New-PodeJsonSchemaArray -Item (New-PodeJsonSchemaString)

.EXAMPLE
# create a JSON Schema definition for an array of integers with at least 1 item and at most 5 items
New-PodeJsonSchemaArray -Item (New-PodeJsonSchemaInteger) -MinItems 1 -MaxItems 5

.EXAMPLE
# create a JSON Schema definition for an array of unique strings with a description
New-PodeJsonSchemaArray -Item (New-PodeJsonSchemaString) -Unique
#>
function New-PodeJsonSchemaArray {
    [CmdletBinding(DefaultParameterSetName = 'Items')]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'Items')]
        [hashtable]
        $Item,

        [Parameter(ParameterSetName = 'Items')]
        [ValidateRange(0, [int]::MaxValue)]
        [int]
        $MinItems,

        [Parameter(ParameterSetName = 'Items')]
        [ValidateRange(0, [int]::MaxValue)]
        [int]
        $MaxItems,

        [Parameter()]
        [string]
        $Description,

        [switch]
        $Unique
    )

    # build the property definition
    $def = @{
        type  = 'array'
        items = $Item
    }

    if ($PSBoundParameters.ContainsKey('MinItems')) {
        $def.minItems = $MinItems
    }
    if ($PSBoundParameters.ContainsKey('MaxItems')) {
        $def.maxItems = $MaxItems
    }
    if ($def.ContainsKey('minItems') -and $def.ContainsKey('maxItems') -and ($def.maxItems -lt $def.minItems)) {
        # MaxItems cannot be less than MinItems for array JSON Schema property
        throw $PodeLocale.jsonSchemaArrayMaxItemsLessThanMinItemsExceptionMessage
    }

    if ($PSBoundParameters.ContainsKey('Unique')) {
        $def.uniqueItems = $Unique.IsPresent
    }

    if ($PSBoundParameters.ContainsKey('Description') -and ![string]::IsNullOrEmpty($Description)) {
        $def.description = $Description
    }

    return $def
}

<#
.SYNOPSIS
Creates an Object JSON Schema type definition.

.DESCRIPTION
This function creates a JSON Schema type definition for an Object type.

.PARAMETER Property
A hashtable representing the JSON Schema property definition for a property of the object.
This parameter can be specified multiple times to define multiple properties.
Property definitions should be created using the New-PodeJsonSchemaProperty function.

.PARAMETER MinProperties
An optional minimum number of properties in the object.

.PARAMETER MaxProperties
An optional maximum number of properties in the object.

.PARAMETER Description
An optional description.

.EXAMPLE
# create a JSON Schema definition for an object with a required string property "name" and an optional integer property "age"
New-PodeJsonSchemaObject -Property @(
    (New-PodeJsonSchemaProperty -Name 'name' -Definition (New-PodeJsonSchemaString) -Required),
    (New-PodeJsonSchemaProperty -Name 'age' -Definition (New-PodeJsonSchemaInteger))
) -Description 'A person object with a required name and an optional age'

.EXAMPLE
# create a JSON Schema definition for an object with no properties, but a description - can accept any number of properties
New-PodeJsonSchemaObject -Description 'An empty object with a description'

.EXAMPLE
# create a JSON Schema definition for an object with a minimum of 1 property and a maximum of 5 properties
New-PodeJsonSchemaObject -MinProperties 1 -MaxProperties 5
#>
function New-PodeJsonSchemaObject {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter()]
        [hashtable[]]
        $Property,

        [Parameter()]
        [ValidateRange(0, [int]::MaxValue)]
        [int]
        $MinProperties,

        [Parameter()]
        [ValidateRange(0, [int]::MaxValue)]
        [int]
        $MaxProperties,

        [Parameter()]
        [string]
        $Description
    )

    # build the property definition
    $def = @{
        type = 'object'
    }

    if ($PSBoundParameters.ContainsKey('Description') -and ![string]::IsNullOrEmpty($Description)) {
        $def.description = $Description
    }

    if ($PSBoundParameters.ContainsKey('MinProperties')) {
        $def.minProperties = $MinProperties
    }
    if ($PSBoundParameters.ContainsKey('MaxProperties')) {
        $def.maxProperties = $MaxProperties
    }
    if ($def.ContainsKey('minProperties') -and $def.ContainsKey('maxProperties') -and ($def.maxProperties -lt $def.minProperties)) {
        # MaxProperties cannot be less than MinProperties for object JSON Schema property
        throw $PodeLocale.jsonSchemaObjectMaxPropsLessThanMinPropsExceptionMessage
    }

    # if no properties, just return the definition
    if (($null -eq $Property) -or ($Property.Count -eq 0)) {
        return $def
    }

    # otherwise, add the properties to the definition
    $def.properties = @{}
    $requiredProps = @()

    foreach ($prop in $Property) {
        if (!$prop.ContainsKey('Name')) {
            # Each JSON Schema Object property definition must include a "Name" key
            throw $PodeLocale.jsonSchemaObjectPropertyMissingNameExceptionMessage
        }

        $name = $prop.Name
        $def.properties[$name] = $prop.Definition

        if ($prop.Required) {
            $requiredProps += $name
        }
    }

    if ($requiredProps.Length -gt 0) {
        $def.required = $requiredProps
    }

    return $def
}

<#
.SYNOPSIS
Creates a merged JSON Schema type definition using a specified merge type.

.DESCRIPTION
This function creates a merged JSON Schema type definition using a specified merge type (AllOf, AnyOf, OneOf, Not)
and an array of JSON Schema definitions to merge.

.PARAMETER Type
The type of merge to perform. Must be one of 'AllOf', 'AnyOf', 'OneOf', or 'Not'.

.PARAMETER Definition
An array of JSON Schema type definitions to merge.

.EXAMPLE
# create a JSON Schema definition that requires a value to match all of the specified schemas
Merge-PodeJsonSchema -Type 'AllOf' -Definition @(
    (New-PodeJsonSchemaString -Pattern '^[a-zA-Z]+$' -Description 'Must be a string of letters only'),
    (New-PodeJsonSchemaString -MinLength 5 -MaxLength 10 -Description 'Must be between 5 and 10 characters long')
)

.EXAMPLE
# create a JSON Schema definition that requires a value to match at least one of the specified schemas
Merge-PodeJsonSchema -Type 'AnyOf' -Definition @(
    (New-PodeJsonSchemaInteger -Minimum 0 -Maximum 100 -Description 'A percentage of some value'),
    (New-PodeJsonSchemaString -Enum 'red', 'green', 'blue' -Description 'A string that must be one of the specified colours')
)

.EXAMPLE
# create a JSON Schema definition that requires a value to match exactly one of the specified schemas
Merge-PodeJsonSchema -Type 'OneOf' -Definition @(
    (New-PodeJsonSchemaInteger -Minimum 0 -Maximum 100 -Description 'A percentage of some value'),
    (New-PodeJsonSchemaString -Enum 'red', 'green', 'blue' -Description 'A string that must be one of the specified colours')
)

.EXAMPLE
# create a JSON Schema definition that requires a value to NOT match any of the specified schemas
Merge-PodeJsonSchema -Type 'Not' -Definition @(
    (New-PodeJsonSchemaInteger -Minimum 0 -Maximum 100 -Description 'A percentage of some value'),
    (New-PodeJsonSchemaString -Enum 'red', 'green', 'blue' -Description 'A string that must be one of the specified colours')
)
#>
function Merge-PodeJsonSchema {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('AllOf', 'AnyOf', 'OneOf', 'Not')]
        [string]
        $Type,

        [Parameter(Mandatory = $true)]
        [hashtable[]]
        $Definition
    )

    $typeName = [string]::Empty
    switch ($Type.ToLowerInvariant()) {
        'allof' { $typeName = 'allOf' }
        'anyof' { $typeName = 'anyOf' }
        'oneof' { $typeName = 'oneOf' }
        'not' { $typeName = 'not' }
    }

    $def = @{
        $typeName = @($Definition)
    }

    return $def
}

<#
.SYNOPSIS
Creates a JSON Schema property definition for use in an object schema.

.DESCRIPTION
This function creates a JSON Schema property definition for use in an object schema.

.PARAMETER Name
The name of the property.

.PARAMETER Definition
A hashtable representing the JSON Schema type definition for the property.
This should be created using one of the other New-PodeJsonSchema* functions.

.PARAMETER Required
Indicates whether the property is required.

.LINK
https://json-schema.org/understanding-json-schema/reference/type

.EXAMPLE
# create a JSON Schema property definition for a required string property "name" with a description
New-PodeJsonSchemaProperty -Name 'name' -Definition (
    New-PodeJsonSchemaString -Description 'The name of the person'
) -Required

.EXAMPLE
# create a JSON Schema property definition for an optional integer property "age" with a description
New-PodeJsonSchemaProperty -Name 'age' -Definition (
    New-PodeJsonSchemaInteger -Description 'The age of the person'
)

.EXAMPLE
# create a JSON Schema property definition for a required array property "tags" with a description, where the items in the array must be unique strings
New-PodeJsonSchemaProperty -Name 'tags' -Definition (
    New-PodeJsonSchemaArray -Unique -Item (
        New-PodeJsonSchemaString
    ) -Description 'An array of unique tags for the person'
) -Required

.EXAMPLE
# create a JSON Schema property definition for an optional property "metadata" with a description, where the value can be any object with a minimum of 1 property
New-PodeJsonSchemaProperty -Name 'metadata' -Definition (
    New-PodeJsonSchemaObject -MinProperties 1 -Description 'Additional metadata about the person'
)
#>
function New-PodeJsonSchemaProperty {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [hashtable]
        $Definition,

        [switch]
        $Required
    )

    return @{
        Name       = $Name
        Definition = $Definition
        Required   = $Required.IsPresent
    }
}