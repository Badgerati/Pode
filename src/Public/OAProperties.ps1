
<#
.SYNOPSIS
Creates a new OpenAPI New-PodeOAMultiTypeProperty property.

.DESCRIPTION
Creates a new OpenAPI multi type property, for Schemas or Parameters.
OpenAPI version 3.1 is required to use this cmdlet.

.LINK
https://swagger.io/docs/specification/basic-structure/

.LINK
https://swagger.io/docs/specification/data-models/

.PARAMETER ParamsList
Used to pipeline multiple properties

.PARAMETER Name
The Name of the property.

.PARAMETER Type
The parameter types

.PARAMETER Format
The inbuilt OpenAPI Format  . (Default: Any)

.PARAMETER CustomFormat
The name of a custom OpenAPI Format  . (Default: None)
(String type only)

.PARAMETER Default
The default value of the property. (Default: $null)

.PARAMETER Pattern
A Regex pattern that the string must match.
(String type only)

.PARAMETER Description
A Description of the property.

.PARAMETER Minimum
The minimum value of the number.
(Integer,Number types only)

.PARAMETER Maximum
The maximum value of the number.
(Integer,Number types only)

.PARAMETER ExclusiveMaximum
Specifies an exclusive upper limit for a numeric property in the OpenAPI schema.
When this parameter is used, it sets the exclusiveMaximum attribute in the OpenAPI definition to true, indicating that the numeric value must be strictly less than the specified maximum value.
This parameter is typically paired with a -Maximum parameter to define the upper bound.
(Integer,Number types only)

.PARAMETER ExclusiveMinimum
Specifies an exclusive lower limit for a numeric property in the OpenAPI schema.
When this parameter is used, it sets the exclusiveMinimun attribute in the OpenAPI definition to true, indicating that the numeric value must be strictly less than the specified minimun value.
This parameter is typically paired with a -Minimum parameter to define the lower bound.
(Integer,Number types only)

.PARAMETER MultiplesOf
The number must be in multiples of the supplied value.
(Integer,Number types only)

.PARAMETER Properties
An array of other int/string/etc properties wrap up as an object.
(Object type only)

.PARAMETER ExternalDoc
If supplied, add an additional external documentation for this operation.
The parameter is created by Add-PodeOAExternalDoc

.PARAMETER Example
An example of a parameter value

.PARAMETER Enum
An optional array of values that this property can only be set to.

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

.PARAMETER NoProperties
If supplied, no properties are allowed in the object.
If no properties are assigned to the object and the NoProperties parameter is not set the object accept any property.(Object type only)

.PARAMETER MinProperties
If supplied, will restrict the minimun number of properties allowed in an object.
(Object type only)

.PARAMETER MaxProperties
If supplied, will restrict the maximum number of properties allowed in an object.
(Object type only)

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

.PARAMETER DiscriminatorProperty
If supplied, specifies the name of the property used to distinguish between different subtypes in a polymorphic schema in OpenAPI.
This string value represents the property in the payload that indicates which specific subtype schema should be applied.
It's essential in scenarios where an API endpoint handles data that conforms to one of several derived schemas from a common base schema.

.PARAMETER DiscriminatorMapping
If supplied, define a mapping between the values of the discriminator property and the corresponding subtype schemas.
This parameter accepts a HashTable where each key-value pair maps a discriminator value to a specific subtype schema name.
It's used in conjunction with the -DiscriminatorProperty to provide complete discrimination logic in polymorphic scenarios.

.PARAMETER XmlName
By default, XML elements get the same names that fields in the API declaration have. This property change the XML name of the property
reflecting the 'xml.name' attribute in the OpenAPI specification.

.PARAMETER XmlNamespace
Defines a specific XML namespace for the property, corresponding to the 'xml.namespace' attribute in OpenAPI.

.PARAMETER XmlPrefix
Sets a prefix for the XML element name, aligning with the 'xml.prefix' attribute in OpenAPI.

.PARAMETER XmlAttribute
Indicates whether the property should be serialized as an XML attribute, equivalent to the 'xml.attribute' attribute in OpenAPI.

.PARAMETER XmlItemName
Specifically for properties treated as arrays, it defines the XML name for each item in the array. This parameter aligns with the 'xml.name' attribute under 'items' in OpenAPI.

.PARAMETER XmlWrapped
Indicates whether array items should be wrapped in an XML element, similar to the 'xml.wrapped' attribute in OpenAPI.

.EXAMPLE
New-PodeOAMultiTypeProperty -Name 'userType' -type integer,boolean

.EXAMPLE
New-PodeOAMultiTypeProperty -Name 'password' -type string,object -Format Password -Properties (New-PodeOAStringProperty -Name 'password' -Format Password)
#>
function New-PodeOAMultiTypeProperty {
    [CmdletBinding(DefaultParameterSetName = 'Inbuilt')]
    param(
        [Parameter(ValueFromPipeline = $true, DontShow = $true )]
        [hashtable[]]
        $ParamsList,

        [Parameter(Mandatory)]
        [ValidateSet( 'integer', 'number', 'string', 'object', 'boolean' )]
        [string]
        $Type,

        [Parameter()]
        [ValidatePattern('^[a-zA-Z0-9\.\-_]+$')]
        [Alias('Title')]
        [string]
        $Name,

        [Parameter( ParameterSetName = 'Array')]
        [Parameter(ParameterSetName = 'Inbuilt')]
        [ValidateSet('', 'Int32', 'Int64', 'Double', 'Float', 'Binary', 'Base64', 'Byte', 'Date', 'Date-Time', 'Password', 'Email', 'Uuid', 'Uri', 'Hostname', 'Ipv4', 'Ipv6')]
        [string]
        $Format,

        [Parameter( ParameterSetName = 'Array')]
        [Parameter(ParameterSetName = 'Custom')]
        [string]
        $CustomFormat,

        [Parameter()]
        $Default,

        [Parameter()]
        [string]
        $Pattern,

        [Parameter()]
        [hashtable[]]
        $Properties,

        [Parameter()]
        [string]
        $Description,

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
        $ExternalDoc,

        [Parameter()]
        [object]
        $Example,

        [Parameter()]
        [object[]]
        $Enum,

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
        $NoProperties,

        [int]
        $MinProperties,

        [int]
        $MaxProperties,

        [switch]
        $NoAdditionalProperties,

        [hashtable]
        $AdditionalProperties,

        [string]
        $XmlName,

        [string]
        $XmlNamespace,

        [string]
        $XmlPrefix,

        [switch]
        $XmlAttribute,

        [Parameter(  ParameterSetName = 'Array')]
        [string]
        $XmlItemName,

        [Parameter(  ParameterSetName = 'Array')]
        [switch]
        $XmlWrapped,

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

        [string]
        $DiscriminatorProperty,

        [hashtable]
        $DiscriminatorMapping
    )
    begin {
        $param = New-PodeOAPropertyInternal   -Params $PSBoundParameters

        if ($type -contains 'string') {
            if (![string]::IsNullOrWhiteSpace($CustomFormat)) {
                $_format = $CustomFormat
            }
            elseif ($Format) {
                $_format = $Format
            }


            if ($Format -or $CustomFormat) {
                $param.format = $_format.ToLowerInvariant()
            }
        }
        if ($type -contains 'object') {
            if ($NoProperties) {
                if ($Properties -or $MinProperties -or $MaxProperties) {
                    # The parameter 'NoProperties' is mutually exclusive with 'Properties', 'MinProperties' and 'MaxProperties'
                    throw ($PodeLocale.noPropertiesMutuallyExclusiveExceptionMessage)
                }
                $param.properties = @($null)
            }
            elseif ($Properties) {
                $param.properties = $Properties
            }
            else {
                $param.properties = @()
            }
            if ($DiscriminatorProperty) {
                $param.discriminator = [ordered]@{
                    'propertyName' = $DiscriminatorProperty
                }
                if ($DiscriminatorMapping) {
                    $param.discriminator.mapping = $DiscriminatorMapping
                }
            }
            elseif ($DiscriminatorMapping) {
                # The parameter 'DiscriminatorMapping' can only be used when 'DiscriminatorProperty' is present
                throw ($PodeLocale.discriminatorMappingRequiresDiscriminatorPropertyExceptionMessage)
            }
        }
        if ($type -contains 'boolean') {
            if ($Default) {
                if ([bool]::TryParse($Default, [ref]$null) -or $Enum -icontains $Default) {
                    $param.default = $Default
                }
                else {
                    # The default value is not a boolean and is not part of the enum
                    throw ($PodeLocale.defaultValueNotBooleanOrEnumExceptionMessage)
                }
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
        }
        else {
            return $param
        }
    }
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

.PARAMETER ExclusiveMaximum
Specifies an exclusive upper limit for a numeric property in the OpenAPI schema.
When this parameter is used, it sets the exclusiveMaximum attribute in the OpenAPI definition to true, indicating that the numeric value must be strictly less than the specified maximum value.
This parameter is typically paired with a -Maximum parameter to define the upper bound.

.PARAMETER ExclusiveMinimum
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

.PARAMETER XmlName
By default, XML elements get the same names that fields in the API declaration have. This property change the XML name of the property
reflecting the 'xml.name' attribute in the OpenAPI specification.

.PARAMETER XmlNamespace
Defines a specific XML namespace for the property, corresponding to the 'xml.namespace' attribute in OpenAPI.

.PARAMETER XmlPrefix
Sets a prefix for the XML element name, aligning with the 'xml.prefix' attribute in OpenAPI.

.PARAMETER XmlAttribute
Indicates whether the property should be serialized as an XML attribute, equivalent to the 'xml.attribute' attribute in OpenAPI.

.PARAMETER XmlItemName
Specifically for properties treated as arrays, it defines the XML name for each item in the array. This parameter aligns with the 'xml.name' attribute under 'items' in OpenAPI.

.PARAMETER XmlWrapped
Indicates whether array items should be wrapped in an XML element, similar to the 'xml.wrapped' attribute in OpenAPI.


.EXAMPLE
New-PodeOAIntProperty -Name 'age' -Required
Creates a required integer property named 'age'.

.EXAMPLE
New-PodeOAIntProperty -Name 'count' -Minimum 0 -Maximum 10 -Default 5 -Description 'Item count'
Creates an integer property 'count' with a minimum value of 0, maximum of 10, default value of 5, and a description.

.EXAMPLE
New-PodeOAIntProperty -Name 'quantity' -XmlName 'Quantity' -XmlNamespace 'http://example.com/quantity' -XmlPrefix 'q'
Creates an integer property 'quantity' with a custom XML element name 'Quantity', using a specified namespace and prefix.

.EXAMPLE
New-PodeOAIntProperty -Array -XmlItemName 'unit' -XmlName 'units' | Add-PodeOAComponentSchema -Name 'Units'
Generates a schema where the integer property is treated as an array, with each array item named 'unit' in XML, and the array itself represented with the XML name 'units'.


#>
function New-PodeOAIntProperty {
    [CmdletBinding(DefaultParameterSetName = 'Inbuilt')]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param(
        [Parameter(ValueFromPipeline = $true, DontShow = $true)]
        [hashtable[]]
        $ParamsList,

        [Parameter()]
        [ValidatePattern('^[a-zA-Z0-9\.\-_]+$')]
        [Alias('Title')]
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
        [object]
        $Example,

        [Parameter()]
        [int[]]
        $Enum,

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

        [string]
        $XmlName,

        [string]
        $XmlNamespace,

        [string]
        $XmlPrefix,

        [switch]
        $XmlAttribute,

        [Parameter(  ParameterSetName = 'Array')]
        [string]
        $XmlItemName,

        [Parameter(  ParameterSetName = 'Array')]
        [switch]
        $XmlWrapped,

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
        }
        else {
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

.PARAMETER ExclusiveMaximum
Specifies an exclusive upper limit for a numeric property in the OpenAPI schema.
When this parameter is used, it sets the exclusiveMaximum attribute in the OpenAPI definition to true, indicating that the numeric value must be strictly less than the specified maximum value.
This parameter is typically paired with a -Maximum parameter to define the upper bound.

.PARAMETER ExclusiveMinimum
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

.PARAMETER XmlName
By default, XML elements get the same names that fields in the API declaration have. This property change the XML name of the property
reflecting the 'xml.name' attribute in the OpenAPI specification.

.PARAMETER XmlNamespace
Defines a specific XML namespace for the property, corresponding to the 'xml.namespace' attribute in OpenAPI.

.PARAMETER XmlPrefix
Sets a prefix for the XML element name, aligning with the 'xml.prefix' attribute in OpenAPI.

.PARAMETER XmlAttribute
Indicates whether the property should be serialized as an XML attribute, equivalent to the 'xml.attribute' attribute in OpenAPI.

.PARAMETER XmlItemName
Specifically for properties treated as arrays, it defines the XML name for each item in the array. This parameter aligns with the 'xml.name' attribute under 'items' in OpenAPI.

.PARAMETER XmlWrapped
Indicates whether array items should be wrapped in an XML element, similar to the 'xml.wrapped' attribute in OpenAPI.

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
        [Alias('Title')]
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
        [object]
        $Example,

        [Parameter()]
        [double[]]
        $Enum,

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

        [string]
        $XmlName,

        [string]
        $XmlNamespace,

        [string]
        $XmlPrefix,

        [switch]
        $XmlAttribute,

        [Parameter(  ParameterSetName = 'Array')]
        [string]
        $XmlItemName,

        [Parameter(  ParameterSetName = 'Array')]
        [switch]
        $XmlWrapped,

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
        }
        else {
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

.PARAMETER XmlName
By default, XML elements get the same names that fields in the API declaration have. This property change the XML name of the property
reflecting the 'xml.name' attribute in the OpenAPI specification.

.PARAMETER XmlNamespace
Defines a specific XML namespace for the property, corresponding to the 'xml.namespace' attribute in OpenAPI.

.PARAMETER XmlPrefix
Sets a prefix for the XML element name, aligning with the 'xml.prefix' attribute in OpenAPI.

.PARAMETER XmlAttribute
Indicates whether the property should be serialized as an XML attribute, equivalent to the 'xml.attribute' attribute in OpenAPI.

.PARAMETER XmlItemName
Specifically for properties treated as arrays, it defines the XML name for each item in the array. This parameter aligns with the 'xml.name' attribute under 'items' in OpenAPI.

.PARAMETER XmlWrapped
Indicates whether array items should be wrapped in an XML element, similar to the 'xml.wrapped' attribute in OpenAPI.

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
        [Alias('Title')]
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
        [object]
        $Example,

        [Parameter()]
        [string[]]
        $Enum,

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

        [string]
        $XmlName,

        [string]
        $XmlNamespace,

        [string]
        $XmlPrefix,

        [switch]
        $XmlAttribute,

        [Parameter(  ParameterSetName = 'Array')]
        [string]
        $XmlItemName,

        [Parameter(  ParameterSetName = 'Array')]
        [switch]
        $XmlWrapped,

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
        }
        elseif ($Format) {
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
        }
        else {
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

.PARAMETER XmlName
By default, XML elements get the same names that fields in the API declaration have. This property change the XML name of the property
reflecting the 'xml.name' attribute in the OpenAPI specification.

.PARAMETER XmlNamespace
Defines a specific XML namespace for the property, corresponding to the 'xml.namespace' attribute in OpenAPI.

.PARAMETER XmlPrefix
Sets a prefix for the XML element name, aligning with the 'xml.prefix' attribute in OpenAPI.

.PARAMETER XmlAttribute
Indicates whether the property should be serialized as an XML attribute, equivalent to the 'xml.attribute' attribute in OpenAPI.

.PARAMETER XmlItemName
Specifically for properties treated as arrays, it defines the XML name for each item in the array. This parameter aligns with the 'xml.name' attribute under 'items' in OpenAPI.

.PARAMETER XmlWrapped
Indicates whether array items should be wrapped in an XML element, similar to the 'xml.wrapped' attribute in OpenAPI.

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
        [Alias('Title')]
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
        [object]
        $Example,

        [Parameter()]
        [string[]]
        $Enum,

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

        [string]
        $XmlName,

        [string]
        $XmlNamespace,

        [string]
        $XmlPrefix,

        [switch]
        $XmlAttribute,

        [Parameter(  ParameterSetName = 'Array')]
        [string]
        $XmlItemName,

        [Parameter(  ParameterSetName = 'Array')]
        [switch]
        $XmlWrapped,

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
            }
            else {
                # The default value is not a boolean and is not part of the enum
                throw ($PodeLocale.defaultValueNotBooleanOrEnumExceptionMessage)
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
        }
        else {
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

.PARAMETER DiscriminatorProperty
If supplied, specifies the name of the property used to distinguish between different subtypes in a polymorphic schema in OpenAPI.
This string value represents the property in the payload that indicates which specific subtype schema should be applied.
It's essential in scenarios where an API endpoint handles data that conforms to one of several derived schemas from a common base schema.

.PARAMETER DiscriminatorMapping
If supplied, define a mapping between the values of the discriminator property and the corresponding subtype schemas.
This parameter accepts a HashTable where each key-value pair maps a discriminator value to a specific subtype schema name.
It's used in conjunction with the -DiscriminatorProperty to provide complete discrimination logic in polymorphic scenarios.

.PARAMETER XmlName
By default, XML elements get the same names that fields in the API declaration have. This property change the XML name of the property
reflecting the 'xml.name' attribute in the OpenAPI specification.

.PARAMETER XmlNamespace
Defines a specific XML namespace for the property, corresponding to the 'xml.namespace' attribute in OpenAPI.

.PARAMETER XmlPrefix
Sets a prefix for the XML element name, aligning with the 'xml.prefix' attribute in OpenAPI.

.PARAMETER XmlAttribute
Indicates whether the property should be serialized as an XML attribute, equivalent to the 'xml.attribute' attribute in OpenAPI.

.PARAMETER XmlItemName
Specifically for properties treated as arrays, it defines the XML name for each item in the array. This parameter aligns with the 'xml.name' attribute under 'items' in OpenAPI.

.PARAMETER XmlWrapped
Indicates whether array items should be wrapped in an XML element, similar to the 'xml.wrapped' attribute in OpenAPI.

.EXAMPLE
New-PodeOAObjectProperty -Name 'user' -Properties @('<ARRAY_OF_PROPERTIES>')

.EXAMPLE
New-PodeOABoolProperty -Name 'enabled' -Required|
    New-PodeOAObjectProperty  -Name 'extraProperties'  -AdditionalProperties [ordered]@{
        "property1" = [ordered]@{ "type" = "string"; "description" = "Description for property1" };
        "property2" = [ordered]@{ "type" = "integer"; "format" = "int32" }
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
        [Alias('Title')]
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
        [object]
        $Example,

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

        [string]
        $XmlName,

        [string]
        $XmlNamespace,

        [string]
        $XmlPrefix,

        [switch]
        $XmlAttribute,

        [Parameter(  ParameterSetName = 'Array')]
        [string]
        $XmlItemName,

        [Parameter(  ParameterSetName = 'Array')]
        [switch]
        $XmlWrapped,

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

        [string]
        $DiscriminatorProperty,

        [hashtable]
        $DiscriminatorMapping
    )
    begin {
        $param = New-PodeOAPropertyInternal -type 'object' -Params $PSBoundParameters
        if ($NoProperties) {
            if ($Properties -or $MinProperties -or $MaxProperties) {
                # The parameter `NoProperties` is mutually exclusive with `Properties`, `MinProperties` and `MaxProperties`
                throw ($PodeLocale.noPropertiesMutuallyExclusiveExceptionMessage)
            }
            $PropertiesFromPipeline = $false
        }
        elseif ($Properties) {
            $param.properties = $Properties
            $PropertiesFromPipeline = $false
        }
        else {
            $param.properties = @()
            $PropertiesFromPipeline = $true
        }
        if ($DiscriminatorProperty) {
            $param.discriminator = [ordered]@{
                'propertyName' = $DiscriminatorProperty
            }
            if ($DiscriminatorMapping) {
                $param.discriminator.mapping = $DiscriminatorMapping
            }
        }
        elseif ($DiscriminatorMapping) {
            # The parameter 'DiscriminatorMapping' can only be used when 'DiscriminatorProperty' is present
            throw ($PodeLocale.discriminatorMappingRequiresDiscriminatorPropertyExceptionMessage)
        }
        $collectedInput = [System.Collections.Generic.List[hashtable]]::new()
    }
    process {
        if ($ParamsList) {
            if ($PropertiesFromPipeline) {
                $param.properties += $ParamsList

            }
            else {
                $collectedInput.AddRange($ParamsList)
            }
        }
    }

    end {
        if ($PropertiesFromPipeline) {
            return $param
        }
        elseif ($collectedInput) {
            return $collectedInput + $param
        }
        else {
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
If supplied, defines a mapping between the values of the discriminator property and the corresponding subtype schemas.
This parameter accepts a HashTable where each key-value pair maps a discriminator value to a specific subtype schema name.
It's used in conjunction with the -DiscriminatorProperty to provide complete discrimination logic in polymorphic scenarios.

.PARAMETER NoObjectDefinitionsFromPipeline
Prevents object definitions from being used in the computation but still passes them through the pipeline.

.PARAMETER Name
Specifies the name of the OpenAPI object.

.PARAMETER Required
Indicates if the object is required.

.PARAMETER Description
Provides a description for the OpenAPI object.

.EXAMPLE
Add-PodeOAComponentSchema -Name 'Pets' -Component (Merge-PodeOAProperty -Type OneOf -ObjectDefinitions @('Cat', 'Dog') -Discriminator "petType")

.EXAMPLE
Add-PodeOAComponentSchema -Name 'Cat' -Component (
    Merge-PodeOAProperty -Type AllOf -ObjectDefinitions @(
        'Pet',
        (New-PodeOAObjectProperty -Properties @(
            (New-PodeOAStringProperty -Name 'huntingSkill' -Description 'The measured skill for hunting' -Enum @('clueless', 'lazy', 'adventurous', 'aggressive'))
        ))
    )
)
#>
function Merge-PodeOAProperty {
    [CmdletBinding(DefaultParameterSetName = 'Inbuilt')]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
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
        $DiscriminatorMapping,

        [switch]
        $NoObjectDefinitionsFromPipeline,

        [Parameter(Mandatory = $true, ParameterSetName = 'Name')]
        [string]
        $Name,

        [Parameter( ParameterSetName = 'Name')]
        [switch]
        $Required,

        [Parameter( ParameterSetName = 'Name')]
        [string]
        $Description
    )
    begin {
        # Initialize an ordered dictionary
        $param = [ordered]@{}

        # Set the type of validation
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

        # Add name to the parameter dictionary if provided
        if ($Name) {
            $param.name = $Name
        }

        # Add description to the parameter dictionary if provided
        if ($Description) {
            $param.description = $Description
        }

        # Set the required field if the switch is present
        if ($Required.IsPresent) {
            $param.required = $Required.IsPresent
        }

        # Initialize schemas array
        $param.schemas = @()

        # Add object definitions to the schemas array
        if ($ObjectDefinitions) {
            foreach ($schema in $ObjectDefinitions) {
                if ($schema -is [System.Object[]] -or ($schema -is [hashtable] -and
                (($schema.type -ine 'object') -and !$schema.object))) {
                    # Only properties of type Object can be associated with $param.type
                    throw ($PodeLocale.propertiesTypeObjectAssociationExceptionMessage -f $param.type)
                }
                $param.schemas += $schema
            }
        }

        # Add discriminator property and mapping if provided
        if ($DiscriminatorProperty) {
            if ($type.ToLower() -eq 'allof' ) {
                # The parameter 'Discriminator' is incompatible with `allOf`
                throw ($PodeLocale.discriminatorIncompatibleWithAllOfExceptionMessage)
            }
            $param.discriminator = [ordered]@{
                'propertyName' = $DiscriminatorProperty
            }
            if ($DiscriminatorMapping) {
                $param.discriminator.mapping = $DiscriminatorMapping
            }
        }
        elseif ($DiscriminatorMapping) {
            # The parameter 'DiscriminatorMapping' can only be used when 'DiscriminatorProperty' is present
            throw ($PodeLocale.discriminatorMappingRequiresDiscriminatorPropertyExceptionMessage)
        }

        # Initialize a list to collect input from the pipeline
        $collectedInput = [System.Collections.Generic.List[hashtable]]::new()
    }
    process {
        if ($ParamsList) {
            if ($NoObjectDefinitionsFromPipeline) {
                # Add to collected input if the switch is present
                $collectedInput.AddRange($ParamsList)
            }
            else {
                # Add to schemas if the switch is not present
                $param.schemas += $ParamsList
            }
        }
    }

    end {
        if ($NoObjectDefinitionsFromPipeline) {
            # Return collected input and param dictionary if switch is present
            return $collectedInput + $param
        }
        else {
            # Return the param dictionary
            return $param
        }
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

.PARAMETER Reference
An component schema name.

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

.PARAMETER XmlName
By default, XML elements get the same names that fields in the API declaration have. This property change the XML name of the property
reflecting the 'xml.name' attribute in the OpenAPI specification.

.PARAMETER XmlNamespace
Defines a specific XML namespace for the property, corresponding to the 'xml.namespace' attribute in OpenAPI.

.PARAMETER XmlPrefix
Sets a prefix for the XML element name, aligning with the 'xml.prefix' attribute in OpenAPI.

.PARAMETER XmlAttribute
Indicates whether the property should be serialized as an XML attribute, equivalent to the 'xml.attribute' attribute in OpenAPI.

.PARAMETER XmlItemName
Specifically for properties treated as arrays, it defines the XML name for each item in the array. This parameter aligns with the 'xml.name' attribute under 'items' in OpenAPI.

.PARAMETER XmlWrapped
Indicates whether array items should be wrapped in an XML element, similar to the 'xml.wrapped' attribute in OpenAPI.

.EXAMPLE
New-PodeOAComponentSchemaProperty -Name 'Config' -Component "MyConfigSchema"
#>
function New-PodeOAComponentSchemaProperty {
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
        [string]
        $Reference,

        [Parameter(  ParameterSetName = 'Array')]
        [string]
        $Description,

        [string]
        $XmlName,

        [string]
        $XmlNamespace,

        [string]
        $XmlPrefix,

        [switch]
        $XmlAttribute,

        [Parameter(  ParameterSetName = 'Array')]
        [string]
        $XmlItemName,

        [Parameter(  ParameterSetName = 'Array')]
        [switch]
        $XmlWrapped,

        [Parameter(ParameterSetName = 'Array')]
        [object]
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
        $MaxItems
    )
    begin {
        $param = New-PodeOAPropertyInternal -type 'schema' -Params $PSBoundParameters
        if (! $param.Name) {
            $param.Name = $Reference
        }
        $param.schema = $Reference
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
        }
        else {
            return $param
        }
    }
}


if (!(Test-Path Alias:New-PodeOASchemaProperty)) {
    New-Alias New-PodeOASchemaProperty -Value New-PodeOAComponentSchemaProperty
}
