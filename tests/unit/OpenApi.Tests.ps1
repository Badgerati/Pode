$path = $MyInvocation.MyCommand.Path
$src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit', '/src/'
Get-ChildItem "$($src)/*.ps1" -Recurse | Resolve-Path | ForEach-Object { . $_ }


Describe 'New-PodeOAObjectProperty' {
    $PodeContext = @{
        Server = @{
            OpenAPI = Get-PodeOABaseObject
        }
    }
    Context 'By Properties' {
        It 'Return Pet Object' {
            write-host 'test'
            Add-PodeOAComponentSchema -Name 'Category' -Schema (
                New-PodeOAObjectProperty -Name 'Category' -Xml @{'name' = 'category' } -Properties  (
                    New-PodeOAIntProperty -Name 'id'-Format Int64 -Example 1 |
                        New-PodeOAStringProperty -Name 'name' -Example 'Dogs'
                ))
            Add-PodeOAComponentSchema -Name 'Tag' -Schema (
                New-PodeOAObjectProperty -Name 'Tag' -Xml @{'name' = 'tag' } -Properties  (
                    New-PodeOAIntProperty -Name 'id'-Format Int64 |
                        New-PodeOAStringProperty -Name 'name'
                ))

            $Pet = New-PodeOAObjectProperty -Name 'Pet' -Xml @{'name' = 'pet' } -Properties  (
            (New-PodeOAIntProperty -Name 'id'-Format Int64 -Example 10 -ReadOnly ),
                (New-PodeOAStringProperty -Name 'name' -Example 'doggie' -Required) ,
                (New-PodeOASchemaProperty -Name 'category' -ComponentSchema 'Category' ),
                (New-PodeOAStringProperty -Name 'petType' -Example 'dog' -Required) ,
                (New-PodeOAStringProperty -Name 'photoUrls' -Array) ,
                (New-PodeOASchemaProperty -Name 'tags' -ComponentSchema 'Tag') ,
                (New-PodeOAStringProperty -Name 'status' -Description 'pet status in the store' -Enum @('available', 'pending', 'sold'))
            )

            $Pet | ConvertTo-Json -Depth 10 -Compress |
                Should Be ( '{"meta":{},"type":"object","name":"Pet","xml":[{"name":"pet"}],"properties":[{"meta":{"readOnly":true,"example":"10"},"type":"integer","name":"id","format":"int64"},{"meta":{"example":"doggie"},"type":"string","name":"name","required":true},{"schema":"Category","meta":{},"type":"schema","name":"category"},{"meta":{"example":"dog"},"type":"string","name":"petType","required":true},{"meta":{},"type":"string","name":"photoUrls","array":true},{"schema":"Tag","meta":{},"type":"schema","name":"tags"},{"meta":{},"type":"string","name":"status","enum":["available","pending","sold"],"description":"pet status in the store"}]}')
        }
    }



    Context 'New-PodeOAIntProperty' {
        It 'NoSwitches' {
            $result = New-PodeOAIntProperty -Name 'testInt' -Description 'Test for New-PodeOAIntProperty' -Format Int32 -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOAIntProperty' -Enum 2, 4, 8, 16 -XmlName 'xTestInt'
            $result | Should Not Be $null
            $result.meta.Count | Should Be 4
            $result.type | Should Be 'integer'
            $result.name | Should Be 'testInt'
            $result.description | Should Be 'Test for New-PodeOAIntProperty'
            $result.format | Should Be 'Int32'
            $result.default | Should Be 8
            $result.meta['minimum'] | Should Be 2
            $result.meta['maximum'] | Should Be 20
            $result.meta['multipleOf'] | Should Be 2
            $result.meta['example'] | Should Be 'Example for New-PodeOAIntProperty'
            $result.enum | Should Be @(2, 4, 8, 16)
            $result.xmlName | Should Be  'xTestInt'
        }
        It 'Object' {
            $result = New-PodeOAIntProperty -Name 'testInt' -Description 'Test for New-PodeOAIntProperty' -Format Int32 -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOAIntProperty' -Enum 2, 4, 8, 16 -XmlName 'xTestInt' -Object
            $result | Should Not Be $null
            $result.meta.Count | Should Be 4
            $result.type | Should Be 'integer'
            $result.name | Should Be 'testInt'
            $result.description | Should Be 'Test for New-PodeOAIntProperty'
            $result.format | Should Be 'Int32'
            $result.default | Should Be 8
            $result.meta['minimum'] | Should Be 2
            $result.meta['maximum'] | Should Be 20
            $result.meta['multipleOf'] | Should Be 2
            $result.meta['example'] | Should Be 'Example for New-PodeOAIntProperty'
            $result.enum | Should Be @(2, 4, 8, 16)
            $result.xmlName | Should Be  'xTestInt'
            $result.object | Should Be $true
        }
        It 'Deprecated' {
            $result = New-PodeOAIntProperty -Name 'testInt' -Description 'Test for New-PodeOAIntProperty' -Format Int32 -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOAIntProperty' -Enum 2, 4, 8, 16 -XmlName 'xTestInt' -Deprecated
            $result | Should Not Be $null
            $result.meta.Count | Should Be 4
            $result.type | Should Be 'integer'
            $result.name | Should Be 'testInt'
            $result.description | Should Be 'Test for New-PodeOAIntProperty'
            $result.format | Should Be 'Int32'
            $result.default | Should Be 8
            $result.meta['minimum'] | Should Be 2
            $result.meta['maximum'] | Should Be 20
            $result.meta['multipleOf'] | Should Be 2
            $result.meta['example'] | Should Be 'Example for New-PodeOAIntProperty'
            $result.enum | Should Be @(2, 4, 8, 16)
            $result.xmlName | Should Be  'xTestInt'
            $result.deprecated | Should Be $true
        }
        It 'Nullable' {
            $result = New-PodeOAIntProperty -Name 'testInt' -Description 'Test for New-PodeOAIntProperty' -Format Int32 -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOAIntProperty' -Enum 2, 4, 8, 16 -XmlName 'xTestInt' -Nullable
            $result | Should Not Be $null
            $result.meta.Count | Should Be 5
            $result.type | Should Be 'integer'
            $result.name | Should Be 'testInt'
            $result.description | Should Be 'Test for New-PodeOAIntProperty'
            $result.format | Should Be 'Int32'
            $result.default | Should Be 8
            $result.meta['minimum'] | Should Be 2
            $result.meta['maximum'] | Should Be 20
            $result.meta['multipleOf'] | Should Be 2
            $result.meta['example'] | Should Be 'Example for New-PodeOAIntProperty'
            $result.enum | Should Be @(2, 4, 8, 16)
            $result.xmlName | Should Be  'xTestInt'
            $result.meta['nullable'] | Should Be $true
        }
        It 'WriteOnly' {
            $result = New-PodeOAIntProperty -Name 'testInt' -Description 'Test for New-PodeOAIntProperty' -Format Int32 -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOAIntProperty' -Enum 2, 4, 8, 16 -XmlName 'xTestInt' -WriteOnly
            $result | Should Not Be $null
            $result.meta.Count | Should Be 5
            $result.type | Should Be 'integer'
            $result.name | Should Be 'testInt'
            $result.description | Should Be 'Test for New-PodeOAIntProperty'
            $result.format | Should Be 'Int32'
            $result.default | Should Be 8
            $result.meta['minimum'] | Should Be 2
            $result.meta['maximum'] | Should Be 20
            $result.meta['multipleOf'] | Should Be 2
            $result.meta['example'] | Should Be 'Example for New-PodeOAIntProperty'
            $result.enum | Should Be @(2, 4, 8, 16)
            $result.xmlName | Should Be  'xTestInt'
            $result.meta['writeOnly'] | Should Be $true
        }
        It 'ReadOnly' {
            $result = New-PodeOAIntProperty -Name 'testInt' -Description 'Test for New-PodeOAIntProperty' -Format Int32 -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOAIntProperty' -Enum 2, 4, 8, 16 -XmlName 'xTestInt' -ReadOnly
            $result | Should Not Be $null
            $result.meta.Count | Should Be 5
            $result.type | Should Be 'integer'
            $result.name | Should Be 'testInt'
            $result.description | Should Be 'Test for New-PodeOAIntProperty'
            $result.format | Should Be 'Int32'
            $result.default | Should Be 8
            $result.meta['minimum'] | Should Be 2
            $result.meta['maximum'] | Should Be 20
            $result.meta['multipleOf'] | Should Be 2
            $result.meta['example'] | Should Be 'Example for New-PodeOAIntProperty'
            $result.enum | Should Be @(2, 4, 8, 16)
            $result.xmlName | Should Be  'xTestInt'
            $result.meta['readOnly'] | Should Be $true
        }

        It 'ArrayNoSwitchesUniqueItems' {
            $result = New-PodeOAIntProperty -Name 'testInt' -Description 'Test for New-PodeOAIntProperty' -Format Int32 -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOAIntProperty' -Enum 2, 4, 8, 16 -XmlName 'xTestInt' -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should Not Be $null
            $result.meta.Count | Should Be 4
            $result.type | Should Be 'integer'
            $result.name | Should Be 'testInt'
            $result.description | Should Be 'Test for New-PodeOAIntProperty'
            $result.format | Should Be 'Int32'
            $result.default | Should Be 8
            $result.meta['minimum'] | Should Be 2
            $result.meta['maximum'] | Should Be 20
            $result.meta['multipleOf'] | Should Be 2
            $result.meta['example'] | Should Be 'Example for New-PodeOAIntProperty'
            $result.enum | Should Be @(2, 4, 8, 16)
            $result.xmlName | Should Be  'xTestInt'
            $result.array | Should Be  $true
            $result.uniqueItems | Should Be  $true
            $result.minItems | Should Be  $true
            $result.maxItems | Should Be  $true

        }
        It 'ArrayDeprecatedUniqueItems' {
            $result = New-PodeOAIntProperty -Name 'testInt' -Description 'Test for New-PodeOAIntProperty' -Format Int32 -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOAIntProperty' -Enum 2, 4, 8, 16 -XmlName 'xTestInt' -Deprecated  -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should Not Be $null
            $result.meta.Count | Should Be 4
            $result.type | Should Be 'integer'
            $result.name | Should Be 'testInt'
            $result.description | Should Be 'Test for New-PodeOAIntProperty'
            $result.format | Should Be 'Int32'
            $result.default | Should Be 8
            $result.meta['minimum'] | Should Be 2
            $result.meta['maximum'] | Should Be 20
            $result.meta['multipleOf'] | Should Be 2
            $result.meta['example'] | Should Be 'Example for New-PodeOAIntProperty'
            $result.enum | Should Be @(2, 4, 8, 16)
            $result.xmlName | Should Be  'xTestInt'
            $result.deprecated | Should Be $true
            $result.array | Should Be  $true
            $result.uniqueItems | Should Be  $true
            $result.minItems | Should Be  $true
            $result.maxItems | Should Be  $true
        }
        It 'ArrayNullableUniqueItems' {
            $result = New-PodeOAIntProperty -Name 'testInt' -Description 'Test for New-PodeOAIntProperty' -Format Int32 -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOAIntProperty' -Enum 2, 4, 8, 16 -XmlName 'xTestInt' -Nullable  -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should Not Be $null
            $result.meta.Count | Should Be 5
            $result.type | Should Be 'integer'
            $result.name | Should Be 'testInt'
            $result.description | Should Be 'Test for New-PodeOAIntProperty'
            $result.format | Should Be 'Int32'
            $result.default | Should Be 8
            $result.meta['minimum'] | Should Be 2
            $result.meta['maximum'] | Should Be 20
            $result.meta['multipleOf'] | Should Be 2
            $result.meta['example'] | Should Be 'Example for New-PodeOAIntProperty'
            $result.enum | Should Be @(2, 4, 8, 16)
            $result.xmlName | Should Be  'xTestInt'
            $result.meta['nullable'] | Should Be $true
            $result.array | Should Be  $true
            $result.uniqueItems | Should Be  $true
            $result.minItems | Should Be  $true
            $result.maxItems | Should Be  $true
        }
        It 'ArrayWriteOnlyUniqueItems' {
            $result = New-PodeOAIntProperty -Name 'testInt' -Description 'Test for New-PodeOAIntProperty' -Format Int32 -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOAIntProperty' -Enum 2, 4, 8, 16 -XmlName 'xTestInt' -WriteOnly  -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should Not Be $null
            $result.meta.Count | Should Be 5
            $result.type | Should Be 'integer'
            $result.name | Should Be 'testInt'
            $result.description | Should Be 'Test for New-PodeOAIntProperty'
            $result.format | Should Be 'Int32'
            $result.default | Should Be 8
            $result.meta['minimum'] | Should Be 2
            $result.meta['maximum'] | Should Be 20
            $result.meta['multipleOf'] | Should Be 2
            $result.meta['example'] | Should Be 'Example for New-PodeOAIntProperty'
            $result.enum | Should Be @(2, 4, 8, 16)
            $result.xmlName | Should Be  'xTestInt'
            $result.meta['writeOnly'] | Should Be $true
            $result.array | Should Be  $true
            $result.uniqueItems | Should Be  $true
            $result.minItems | Should Be  $true
            $result.maxItems | Should Be  $true
        }
        It 'ArrayReadOnlyUniqueItems' {
            $result = New-PodeOAIntProperty -Name 'testInt' -Description 'Test for New-PodeOAIntProperty' -Format Int32 -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOAIntProperty' -Enum 2, 4, 8, 16 -XmlName 'xTestInt' -ReadOnly  -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should Not Be $null
            $result.meta.Count | Should Be 5
            $result.type | Should Be 'integer'
            $result.name | Should Be 'testInt'
            $result.description | Should Be 'Test for New-PodeOAIntProperty'
            $result.format | Should Be 'Int32'
            $result.default | Should Be 8
            $result.meta['minimum'] | Should Be 2
            $result.meta['maximum'] | Should Be 20
            $result.meta['multipleOf'] | Should Be 2
            $result.meta['example'] | Should Be 'Example for New-PodeOAIntProperty'
            $result.enum | Should Be @(2, 4, 8, 16)
            $result.xmlName | Should Be  'xTestInt'
            $result.meta['readOnly'] | Should Be $true
            $result.array | Should Be  $true
            $result.uniqueItems | Should Be  $true
            $result.minItems | Should Be  $true
            $result.maxItems | Should Be  $true
        }

        It 'ArrayNoSwitches' {
            $result = New-PodeOAIntProperty -Name 'testInt' -Description 'Test for New-PodeOAIntProperty' -Format Int32 -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOAIntProperty' -Enum 2, 4, 8, 16 -XmlName 'xTestInt' -Array  -MinItems 2 -MaxItems 4
            $result | Should Not Be $null
            $result.meta.Count | Should Be 4
            $result.type | Should Be 'integer'
            $result.name | Should Be 'testInt'
            $result.description | Should Be 'Test for New-PodeOAIntProperty'
            $result.format | Should Be 'Int32'
            $result.default | Should Be 8
            $result.meta['minimum'] | Should Be 2
            $result.meta['maximum'] | Should Be 20
            $result.meta['multipleOf'] | Should Be 2
            $result.meta['example'] | Should Be 'Example for New-PodeOAIntProperty'
            $result.enum | Should Be @(2, 4, 8, 16)
            $result.xmlName | Should Be  'xTestInt'
            $result.array | Should Be  $true
            $result.minItems | Should Be  $true
            $result.maxItems | Should Be  $true

        }
        It 'ArrayDeprecated' {
            $result = New-PodeOAIntProperty -Name 'testInt' -Description 'Test for New-PodeOAIntProperty' -Format Int32 -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOAIntProperty' -Enum 2, 4, 8, 16 -XmlName 'xTestInt' -Deprecated  -Array  -MinItems 2 -MaxItems 4
            $result | Should Not Be $null
            $result.meta.Count | Should Be 4
            $result.type | Should Be 'integer'
            $result.name | Should Be 'testInt'
            $result.description | Should Be 'Test for New-PodeOAIntProperty'
            $result.format | Should Be 'Int32'
            $result.default | Should Be 8
            $result.meta['minimum'] | Should Be 2
            $result.meta['maximum'] | Should Be 20
            $result.meta['multipleOf'] | Should Be 2
            $result.meta['example'] | Should Be 'Example for New-PodeOAIntProperty'
            $result.enum | Should Be @(2, 4, 8, 16)
            $result.xmlName | Should Be  'xTestInt'
            $result.deprecated | Should Be $true
            $result.array | Should Be  $true
            $result.minItems | Should Be  $true
            $result.maxItems | Should Be  $true
        }
        It 'ArrayNullable' {
            $result = New-PodeOAIntProperty -Name 'testInt' -Description 'Test for New-PodeOAIntProperty' -Format Int32 -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOAIntProperty' -Enum 2, 4, 8, 16 -XmlName 'xTestInt' -Nullable  -Array  -MinItems 2 -MaxItems 4
            $result | Should Not Be $null
            $result.meta.Count | Should Be 5
            $result.type | Should Be 'integer'
            $result.name | Should Be 'testInt'
            $result.description | Should Be 'Test for New-PodeOAIntProperty'
            $result.format | Should Be 'Int32'
            $result.default | Should Be 8
            $result.meta['minimum'] | Should Be 2
            $result.meta['maximum'] | Should Be 20
            $result.meta['multipleOf'] | Should Be 2
            $result.meta['example'] | Should Be 'Example for New-PodeOAIntProperty'
            $result.enum | Should Be @(2, 4, 8, 16)
            $result.xmlName | Should Be  'xTestInt'
            $result.meta['nullable'] | Should Be $true
            $result.array | Should Be  $true
            $result.minItems | Should Be  $true
            $result.maxItems | Should Be  $true
        }
        It 'ArrayWriteOnly' {
            $result = New-PodeOAIntProperty -Name 'testInt' -Description 'Test for New-PodeOAIntProperty' -Format Int32 -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOAIntProperty' -Enum 2, 4, 8, 16 -XmlName 'xTestInt' -WriteOnly  -Array  -MinItems 2 -MaxItems 4
            $result | Should Not Be $null
            $result.meta.Count | Should Be 5
            $result.type | Should Be 'integer'
            $result.name | Should Be 'testInt'
            $result.description | Should Be 'Test for New-PodeOAIntProperty'
            $result.format | Should Be 'Int32'
            $result.default | Should Be 8
            $result.meta['minimum'] | Should Be 2
            $result.meta['maximum'] | Should Be 20
            $result.meta['multipleOf'] | Should Be 2
            $result.meta['example'] | Should Be 'Example for New-PodeOAIntProperty'
            $result.enum | Should Be @(2, 4, 8, 16)
            $result.xmlName | Should Be  'xTestInt'
            $result.meta['writeOnly'] | Should Be $true
            $result.array | Should Be  $true
            $result.minItems | Should Be  $true
            $result.maxItems | Should Be  $true
        }
        It 'ArrayReadOnly' {
            $result = New-PodeOAIntProperty -Name 'testInt' -Description 'Test for New-PodeOAIntProperty' -Format Int32 -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOAIntProperty' -Enum 2, 4, 8, 16 -XmlName 'xTestInt' -ReadOnly  -Array  -MinItems 2 -MaxItems 4
            $result | Should Not Be $null
            $result.meta.Count | Should Be 5
            $result.type | Should Be 'integer'
            $result.name | Should Be 'testInt'
            $result.description | Should Be 'Test for New-PodeOAIntProperty'
            $result.format | Should Be 'Int32'
            $result.default | Should Be 8
            $result.meta['minimum'] | Should Be 2
            $result.meta['maximum'] | Should Be 20
            $result.meta['multipleOf'] | Should Be 2
            $result.meta['example'] | Should Be 'Example for New-PodeOAIntProperty'
            $result.enum | Should Be @(2, 4, 8, 16)
            $result.xmlName | Should Be  'xTestInt'
            $result.meta['readOnly'] | Should Be $true
            $result.array | Should Be  $true
            $result.minItems | Should Be  $true
            $result.maxItems | Should Be  $true
        }
    }




    Context 'New-PodeOANumberProperty' {
        It 'NoSwitches' {
            $result = New-PodeOANumberProperty -Name 'testNumber' -Description 'Test for New-PodeOANumberProperty' -Format Double -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOANumberProperty' -Enum 2.1, 4.2, 8.3, 16.4 -XmlName 'xTestNumber'
            $result | Should Not Be $null
            $result.meta.Count | Should Be 4
            $result.type | Should Be 'number'
            $result.name | Should Be 'testNumber'
            $result.description | Should Be 'Test for New-PodeOANumberProperty'
            $result.format | Should Be 'Double'
            $result.default | Should Be 8
            $result.meta['minimum'] | Should Be 2
            $result.meta['maximum'] | Should Be 20
            $result.meta['multipleOf'] | Should Be 2
            $result.meta['example'] | Should Be 'Example for New-PodeOANumberProperty'
            $result.enum | Should Be @(2.1, 4.2, 8.3, 16.4)
            $result.xmlName | Should Be  'xTestNumber'
        }
        It 'Object' {
            $result = New-PodeOANumberProperty -Name 'testNumber' -Description 'Test for New-PodeOANumberProperty' -Format Double -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOANumberProperty' -Enum 2.1, 4.2, 8.3, 16.4 -XmlName 'xTestNumber' -Object
            $result | Should Not Be $null
            $result.meta.Count | Should Be 4
            $result.type | Should Be 'number'
            $result.name | Should Be 'testNumber'
            $result.description | Should Be 'Test for New-PodeOANumberProperty'
            $result.format | Should Be 'Double'
            $result.default | Should Be 8
            $result.meta['minimum'] | Should Be 2
            $result.meta['maximum'] | Should Be 20
            $result.meta['multipleOf'] | Should Be 2
            $result.meta['example'] | Should Be 'Example for New-PodeOANumberProperty'
            $result.enum | Should Be @(2.1, 4.2, 8.3, 16.4)
            $result.xmlName | Should Be  'xTestNumber'
            $result.object | Should Be $true
        }
        It 'Deprecated' {
            $result = New-PodeOANumberProperty -Name 'testNumber' -Description 'Test for New-PodeOANumberProperty' -Format Double -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOANumberProperty' -Enum 2.1, 4.2, 8.3, 16.4 -XmlName 'xTestNumber' -Deprecated
            $result | Should Not Be $null
            $result.meta.Count | Should Be 4
            $result.type | Should Be 'number'
            $result.name | Should Be 'testNumber'
            $result.description | Should Be 'Test for New-PodeOANumberProperty'
            $result.format | Should Be 'Double'
            $result.default | Should Be 8
            $result.meta['minimum'] | Should Be 2
            $result.meta['maximum'] | Should Be 20
            $result.meta['multipleOf'] | Should Be 2
            $result.meta['example'] | Should Be 'Example for New-PodeOANumberProperty'
            $result.enum | Should Be @(2.1, 4.2, 8.3, 16.4)
            $result.xmlName | Should Be  'xTestNumber'
            $result.deprecated | Should Be $true
        }
        It 'Nullable' {
            $result = New-PodeOANumberProperty -Name 'testNumber' -Description 'Test for New-PodeOANumberProperty' -Format Double -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOANumberProperty' -Enum 2.1, 4.2, 8.3, 16.4 -XmlName 'xTestNumber' -Nullable
            $result | Should Not Be $null
            $result.meta.Count | Should Be 5
            $result.type | Should Be 'number'
            $result.name | Should Be 'testNumber'
            $result.description | Should Be 'Test for New-PodeOANumberProperty'
            $result.format | Should Be 'Double'
            $result.default | Should Be 8
            $result.meta['minimum'] | Should Be 2
            $result.meta['maximum'] | Should Be 20
            $result.meta['multipleOf'] | Should Be 2
            $result.meta['example'] | Should Be 'Example for New-PodeOANumberProperty'
            $result.enum | Should Be @(2.1, 4.2, 8.3, 16.4)
            $result.xmlName | Should Be  'xTestNumber'
            $result.meta['nullable'] | Should Be $true
        }
        It 'WriteOnly' {
            $result = New-PodeOANumberProperty -Name 'testNumber' -Description 'Test for New-PodeOANumberProperty' -Format Double -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOANumberProperty' -Enum 2.1, 4.2, 8.3, 16.4 -XmlName 'xTestNumber' -WriteOnly
            $result | Should Not Be $null
            $result.meta.Count | Should Be 5
            $result.type | Should Be 'number'
            $result.name | Should Be 'testNumber'
            $result.description | Should Be 'Test for New-PodeOANumberProperty'
            $result.format | Should Be 'Double'
            $result.default | Should Be 8
            $result.meta['minimum'] | Should Be 2
            $result.meta['maximum'] | Should Be 20
            $result.meta['multipleOf'] | Should Be 2
            $result.meta['example'] | Should Be 'Example for New-PodeOANumberProperty'
            $result.enum | Should Be @(2.1, 4.2, 8.3, 16.4)
            $result.xmlName | Should Be  'xTestNumber'
            $result.meta['writeOnly'] | Should Be $true
        }
        It 'ReadOnly' {
            $result = New-PodeOANumberProperty -Name 'testNumber' -Description 'Test for New-PodeOANumberProperty' -Format Double -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOANumberProperty' -Enum 2.1, 4.2, 8.3, 16.4 -XmlName 'xTestNumber' -ReadOnly
            $result | Should Not Be $null
            $result.meta.Count | Should Be 5
            $result.type | Should Be 'number'
            $result.name | Should Be 'testNumber'
            $result.description | Should Be 'Test for New-PodeOANumberProperty'
            $result.format | Should Be 'Double'
            $result.default | Should Be 8
            $result.meta['minimum'] | Should Be 2
            $result.meta['maximum'] | Should Be 20
            $result.meta['multipleOf'] | Should Be 2
            $result.meta['example'] | Should Be 'Example for New-PodeOANumberProperty'
            $result.enum | Should Be @(2.1, 4.2, 8.3, 16.4)
            $result.xmlName | Should Be  'xTestNumber'
            $result.meta['readOnly'] | Should Be $true
        }

        It 'ArrayNoSwitchesUniqueItems' {
            $result = New-PodeOANumberProperty -Name 'testNumber' -Description 'Test for New-PodeOANumberProperty' -Format Double -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOANumberProperty' -Enum 2.1, 4.2, 8.3, 16.4 -XmlName 'xTestNumber' -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should Not Be $null
            $result.meta.Count | Should Be 4
            $result.type | Should Be 'number'
            $result.name | Should Be 'testNumber'
            $result.description | Should Be 'Test for New-PodeOANumberProperty'
            $result.format | Should Be 'Double'
            $result.default | Should Be 8
            $result.meta['minimum'] | Should Be 2
            $result.meta['maximum'] | Should Be 20
            $result.meta['multipleOf'] | Should Be 2
            $result.meta['example'] | Should Be 'Example for New-PodeOANumberProperty'
            $result.enum | Should Be @(2.1, 4.2, 8.3, 16.4)
            $result.xmlName | Should Be  'xTestNumber'
            $result.array | Should Be  $true
            $result.uniqueItems | Should Be  $true
            $result.minItems | Should Be  $true
            $result.maxItems | Should Be  $true

        }
        It 'ArrayDeprecatedUniqueItems' {
            $result = New-PodeOANumberProperty -Name 'testNumber' -Description 'Test for New-PodeOANumberProperty' -Format Double -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOANumberProperty' -Enum 2.1, 4.2, 8.3, 16.4 -XmlName 'xTestNumber' -Deprecated  -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should Not Be $null
            $result.meta.Count | Should Be 4
            $result.type | Should Be 'number'
            $result.name | Should Be 'testNumber'
            $result.description | Should Be 'Test for New-PodeOANumberProperty'
            $result.format | Should Be 'Double'
            $result.default | Should Be 8
            $result.meta['minimum'] | Should Be 2
            $result.meta['maximum'] | Should Be 20
            $result.meta['multipleOf'] | Should Be 2
            $result.meta['example'] | Should Be 'Example for New-PodeOANumberProperty'
            $result.enum | Should Be @(2.1, 4.2, 8.3, 16.4)
            $result.xmlName | Should Be  'xTestNumber'
            $result.deprecated | Should Be $true
            $result.array | Should Be  $true
            $result.uniqueItems | Should Be  $true
            $result.minItems | Should Be  $true
            $result.maxItems | Should Be  $true
        }
        It 'ArrayNullableUniqueItems' {
            $result = New-PodeOANumberProperty -Name 'testNumber' -Description 'Test for New-PodeOANumberProperty' -Format Double -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOANumberProperty' -Enum 2.1, 4.2, 8.3, 16.4 -XmlName 'xTestNumber' -Nullable  -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should Not Be $null
            $result.meta.Count | Should Be 5
            $result.type | Should Be 'number'
            $result.name | Should Be 'testNumber'
            $result.description | Should Be 'Test for New-PodeOANumberProperty'
            $result.format | Should Be 'Double'
            $result.default | Should Be 8
            $result.meta['minimum'] | Should Be 2
            $result.meta['maximum'] | Should Be 20
            $result.meta['multipleOf'] | Should Be 2
            $result.meta['example'] | Should Be 'Example for New-PodeOANumberProperty'
            $result.enum | Should Be @(2.1, 4.2, 8.3, 16.4)
            $result.xmlName | Should Be  'xTestNumber'
            $result.meta['nullable'] | Should Be $true
            $result.array | Should Be  $true
            $result.uniqueItems | Should Be  $true
            $result.minItems | Should Be  $true
            $result.maxItems | Should Be  $true
        }
        It 'ArrayWriteOnlyUniqueItems' {
            $result = New-PodeOANumberProperty -Name 'testNumber' -Description 'Test for New-PodeOANumberProperty' -Format Double -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOANumberProperty' -Enum 2.1, 4.2, 8.3, 16.4 -XmlName 'xTestNumber' -WriteOnly  -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should Not Be $null
            $result.meta.Count | Should Be 5
            $result.type | Should Be 'number'
            $result.name | Should Be 'testNumber'
            $result.description | Should Be 'Test for New-PodeOANumberProperty'
            $result.format | Should Be 'Double'
            $result.default | Should Be 8
            $result.meta['minimum'] | Should Be 2
            $result.meta['maximum'] | Should Be 20
            $result.meta['multipleOf'] | Should Be 2
            $result.meta['example'] | Should Be 'Example for New-PodeOANumberProperty'
            $result.enum | Should Be @(2.1, 4.2, 8.3, 16.4)
            $result.xmlName | Should Be  'xTestNumber'
            $result.meta['writeOnly'] | Should Be $true
            $result.array | Should Be  $true
            $result.uniqueItems | Should Be  $true
            $result.minItems | Should Be  $true
            $result.maxItems | Should Be  $true
        }
        It 'ArrayReadOnlyUniqueItems' {
            $result = New-PodeOANumberProperty -Name 'testNumber' -Description 'Test for New-PodeOANumberProperty' -Format Double -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOANumberProperty' -Enum 2.1, 4.2, 8.3, 16.4 -XmlName 'xTestNumber' -ReadOnly  -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should Not Be $null
            $result.meta.Count | Should Be 5
            $result.type | Should Be 'number'
            $result.name | Should Be 'testNumber'
            $result.description | Should Be 'Test for New-PodeOANumberProperty'
            $result.format | Should Be 'Double'
            $result.default | Should Be 8
            $result.meta['minimum'] | Should Be 2
            $result.meta['maximum'] | Should Be 20
            $result.meta['multipleOf'] | Should Be 2
            $result.meta['example'] | Should Be 'Example for New-PodeOANumberProperty'
            $result.enum | Should Be @(2.1, 4.2, 8.3, 16.4)
            $result.xmlName | Should Be  'xTestNumber'
            $result.meta['readOnly'] | Should Be $true
            $result.array | Should Be  $true
            $result.uniqueItems | Should Be  $true
            $result.minItems | Should Be  $true
            $result.maxItems | Should Be  $true
        }

        It 'ArrayNoSwitches' {
            $result = New-PodeOANumberProperty -Name 'testNumber' -Description 'Test for New-PodeOANumberProperty' -Format Double -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOANumberProperty' -Enum 2.1, 4.2, 8.3, 16.4 -XmlName 'xTestNumber' -Array  -MinItems 2 -MaxItems 4
            $result | Should Not Be $null
            $result.meta.Count | Should Be 4
            $result.type | Should Be 'number'
            $result.name | Should Be 'testNumber'
            $result.description | Should Be 'Test for New-PodeOANumberProperty'
            $result.format | Should Be 'Double'
            $result.default | Should Be 8
            $result.meta['minimum'] | Should Be 2
            $result.meta['maximum'] | Should Be 20
            $result.meta['multipleOf'] | Should Be 2
            $result.meta['example'] | Should Be 'Example for New-PodeOANumberProperty'
            $result.enum | Should Be @(2.1, 4.2, 8.3, 16.4)
            $result.xmlName | Should Be  'xTestNumber'
            $result.array | Should Be  $true
            $result.minItems | Should Be  $true
            $result.maxItems | Should Be  $true

        }
        It 'ArrayDeprecated' {
            $result = New-PodeOANumberProperty -Name 'testNumber' -Description 'Test for New-PodeOANumberProperty' -Format Double -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOANumberProperty' -Enum 2.1, 4.2, 8.3, 16.4 -XmlName 'xTestNumber' -Deprecated  -Array  -MinItems 2 -MaxItems 4
            $result | Should Not Be $null
            $result.meta.Count | Should Be 4
            $result.type | Should Be 'number'
            $result.name | Should Be 'testNumber'
            $result.description | Should Be 'Test for New-PodeOANumberProperty'
            $result.format | Should Be 'Double'
            $result.default | Should Be 8
            $result.meta['minimum'] | Should Be 2
            $result.meta['maximum'] | Should Be 20
            $result.meta['multipleOf'] | Should Be 2
            $result.meta['example'] | Should Be 'Example for New-PodeOANumberProperty'
            $result.enum | Should Be @(2.1, 4.2, 8.3, 16.4)
            $result.xmlName | Should Be  'xTestNumber'
            $result.deprecated | Should Be $true
            $result.array | Should Be  $true
            $result.minItems | Should Be  $true
            $result.maxItems | Should Be  $true
        }
        It 'ArrayNullable' {
            $result = New-PodeOANumberProperty -Name 'testNumber' -Description 'Test for New-PodeOANumberProperty' -Format Double -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOANumberProperty' -Enum 2.1, 4.2, 8.3, 16.4 -XmlName 'xTestNumber' -Nullable  -Array  -MinItems 2 -MaxItems 4
            $result | Should Not Be $null
            $result.meta.Count | Should Be 5
            $result.type | Should Be 'number'
            $result.name | Should Be 'testNumber'
            $result.description | Should Be 'Test for New-PodeOANumberProperty'
            $result.format | Should Be 'Double'
            $result.default | Should Be 8
            $result.meta['minimum'] | Should Be 2
            $result.meta['maximum'] | Should Be 20
            $result.meta['multipleOf'] | Should Be 2
            $result.meta['example'] | Should Be 'Example for New-PodeOANumberProperty'
            $result.enum | Should Be @(2.1, 4.2, 8.3, 16.4)
            $result.xmlName | Should Be  'xTestNumber'
            $result.meta['nullable'] | Should Be $true
            $result.array | Should Be  $true
            $result.minItems | Should Be  $true
            $result.maxItems | Should Be  $true
        }
        It 'ArrayWriteOnly' {
            $result = New-PodeOANumberProperty -Name 'testNumber' -Description 'Test for New-PodeOANumberProperty' -Format Double -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOANumberProperty' -Enum 2.1, 4.2, 8.3, 16.4 -XmlName 'xTestNumber' -WriteOnly  -Array  -MinItems 2 -MaxItems 4
            $result | Should Not Be $null
            $result.meta.Count | Should Be 5
            $result.type | Should Be 'number'
            $result.name | Should Be 'testNumber'
            $result.description | Should Be 'Test for New-PodeOANumberProperty'
            $result.format | Should Be 'Double'
            $result.default | Should Be 8
            $result.meta['minimum'] | Should Be 2
            $result.meta['maximum'] | Should Be 20
            $result.meta['multipleOf'] | Should Be 2
            $result.meta['example'] | Should Be 'Example for New-PodeOANumberProperty'
            $result.enum | Should Be @(2.1, 4.2, 8.3, 16.4)
            $result.xmlName | Should Be  'xTestNumber'
            $result.meta['writeOnly'] | Should Be $true
            $result.array | Should Be  $true
            $result.minItems | Should Be  $true
            $result.maxItems | Should Be  $true
        }
        It 'ArrayReadOnly' {
            $result = New-PodeOANumberProperty -Name 'testNumber' -Description 'Test for New-PodeOANumberProperty' -Format Double -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOANumberProperty' -Enum 2.1, 4.2, 8.3, 16.4 -XmlName 'xTestNumber' -ReadOnly  -Array  -MinItems 2 -MaxItems 4
            $result | Should Not Be $null
            $result.meta.Count | Should Be 5
            $result.type | Should Be 'number'
            $result.name | Should Be 'testNumber'
            $result.description | Should Be 'Test for New-PodeOANumberProperty'
            $result.format | Should Be 'Double'
            $result.default | Should Be 8
            $result.meta['minimum'] | Should Be 2
            $result.meta['maximum'] | Should Be 20
            $result.meta['multipleOf'] | Should Be 2
            $result.meta['example'] | Should Be 'Example for New-PodeOANumberProperty'
            $result.enum | Should Be @(2.1, 4.2, 8.3, 16.4)
            $result.xmlName | Should Be  'xTestNumber'
            $result.meta['readOnly'] | Should Be $true
            $result.array | Should Be  $true
            $result.minItems | Should Be  $true
            $result.maxItems | Should Be  $true
        }
    }

    Context 'New-PodeOABoolProperty' {
        It 'NoSwitches' {
            $result = New-PodeOABoolProperty -Name 'testBool' -Description 'Test for New-PodeOABoolProperty' -Default 'yes' `
                -Example 'Example for New-PodeOABoolProperty' -Enum $true, $false , 'yes', 'no' -XmlName 'xTestBool'
            $result | Should Not Be $null
            $result.meta.Count | Should Be 1
            $result.type | Should Be 'boolean'
            $result.name | Should Be 'testBool'
            $result.description | Should Be 'Test for New-PodeOABoolProperty'
            $result.default | Should Be 'yes'
            $result.meta['example'] | Should Be 'Example for New-PodeOABoolProperty'
            $result.enum | Should Be @('true', 'false' , 'yes', 'no')
            $result.xmlName | Should Be  'xTestBool'
        }
        It 'Object' {
            $result = New-PodeOABoolProperty -Name 'testBool' -Description 'Test for New-PodeOABoolProperty' -Default 'yes' `
                -Example 'Example for New-PodeOABoolProperty' -Enum $true, $false , 'yes', 'no' -XmlName 'xTestBool' -Object
            $result | Should Not Be $null
            $result.meta.Count | Should Be 1
            $result.type | Should Be 'boolean'
            $result.name | Should Be 'testBool'
            $result.description | Should Be 'Test for New-PodeOABoolProperty'
            $result.default | Should Be 'yes'
            $result.meta['example'] | Should Be 'Example for New-PodeOABoolProperty'
            $result.enum | Should Be @('true', 'false' , 'yes', 'no')
            $result.xmlName | Should Be  'xTestBool'
            $result.object | Should Be $true
        }
        It 'Deprecated' {
            $result = New-PodeOABoolProperty -Name 'testBool' -Description 'Test for New-PodeOABoolProperty' -Default 'yes' `
                -Example 'Example for New-PodeOABoolProperty' -Enum $true, $false , 'yes', 'no' -XmlName 'xTestBool' -Deprecated
            $result | Should Not Be $null
            $result.meta.Count | Should Be 1
            $result.type | Should Be 'boolean'
            $result.name | Should Be 'testBool'
            $result.description | Should Be 'Test for New-PodeOABoolProperty'
            $result.default | Should Be 'yes'
            $result.meta['example'] | Should Be 'Example for New-PodeOABoolProperty'
            $result.enum | Should Be @('true', 'false' , 'yes', 'no')
            $result.xmlName | Should Be  'xTestBool'
            $result.deprecated | Should Be $true
        }
        It 'Nullable' {
            $result = New-PodeOABoolProperty -Name 'testBool' -Description 'Test for New-PodeOABoolProperty' -Default 'yes' `
                -Example 'Example for New-PodeOABoolProperty' -Enum $true, $false , 'yes', 'no' -XmlName 'xTestBool' -Nullable
            $result | Should Not Be $null
            $result.meta.Count | Should Be 2
            $result.type | Should Be 'boolean'
            $result.name | Should Be 'testBool'
            $result.description | Should Be 'Test for New-PodeOABoolProperty'
            $result.default | Should Be 'yes'
            $result.meta['example'] | Should Be 'Example for New-PodeOABoolProperty'
            $result.enum | Should Be @('true', 'false' , 'yes', 'no')
            $result.xmlName | Should Be  'xTestBool'
            $result.meta['nullable'] | Should Be $true
        }
        It 'WriteOnly' {
            $result = New-PodeOABoolProperty -Name 'testBool' -Description 'Test for New-PodeOABoolProperty' -Default 'yes' `
                -Example 'Example for New-PodeOABoolProperty' -Enum $true, $false , 'yes', 'no' -XmlName 'xTestBool' -WriteOnly
            $result | Should Not Be $null
            $result.meta.Count | Should Be 2
            $result.type | Should Be 'boolean'
            $result.name | Should Be 'testBool'
            $result.description | Should Be 'Test for New-PodeOABoolProperty'
            $result.default | Should Be 'yes'
            $result.meta['example'] | Should Be 'Example for New-PodeOABoolProperty'
            $result.enum | Should Be @('true', 'false' , 'yes', 'no')
            $result.xmlName | Should Be  'xTestBool'
            $result.meta['writeOnly'] | Should Be $true
        }
        It 'ReadOnly' {
            $result = New-PodeOABoolProperty -Name 'testBool' -Description 'Test for New-PodeOABoolProperty' -Default 'yes' `
                -Example 'Example for New-PodeOABoolProperty' -Enum $true, $false , 'yes', 'no' -XmlName 'xTestBool' -ReadOnly
            $result | Should Not Be $null
            $result.meta.Count | Should Be 2
            $result.type | Should Be 'boolean'
            $result.name | Should Be 'testBool'
            $result.description | Should Be 'Test for New-PodeOABoolProperty'
            $result.default | Should Be 'yes'
            $result.meta['example'] | Should Be 'Example for New-PodeOABoolProperty'
            $result.enum | Should Be @('true', 'false' , 'yes', 'no')
            $result.xmlName | Should Be  'xTestBool'
            $result.meta['readOnly'] | Should Be $true
        }

        It 'ArrayNoSwitchesUniqueItems' {
            $result = New-PodeOABoolProperty -Name 'testBool' -Description 'Test for New-PodeOABoolProperty' -Default 'yes' `
                -Example 'Example for New-PodeOABoolProperty' -Enum $true, $false , 'yes', 'no' -XmlName 'xTestBool' -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should Not Be $null
            $result.meta.Count | Should Be 1
            $result.type | Should Be 'boolean'
            $result.name | Should Be 'testBool'
            $result.description | Should Be 'Test for New-PodeOABoolProperty'
            $result.default | Should Be 'yes'
            $result.meta['example'] | Should Be 'Example for New-PodeOABoolProperty'
            $result.enum | Should Be @('true', 'false' , 'yes', 'no')
            $result.xmlName | Should Be  'xTestBool'
            $result.array | Should Be  $true
            $result.uniqueItems | Should Be  $true
            $result.minItems | Should Be  $true
            $result.maxItems | Should Be  $true

        }
        It 'ArrayDeprecatedUniqueItems' {
            $result = New-PodeOABoolProperty -Name 'testBool' -Description 'Test for New-PodeOABoolProperty' -Default 'yes' `
                -Example 'Example for New-PodeOABoolProperty' -Enum $true, $false , 'yes', 'no' -XmlName 'xTestBool' -Deprecated  -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should Not Be $null
            $result.meta.Count | Should Be 1
            $result.type | Should Be 'boolean'
            $result.name | Should Be 'testBool'
            $result.description | Should Be 'Test for New-PodeOABoolProperty'
            $result.default | Should Be 'yes'
            $result.meta['example'] | Should Be 'Example for New-PodeOABoolProperty'
            $result.enum | Should Be @('true', 'false' , 'yes', 'no')
            $result.xmlName | Should Be  'xTestBool'
            $result.deprecated | Should Be $true
            $result.array | Should Be  $true
            $result.uniqueItems | Should Be  $true
            $result.minItems | Should Be  $true
            $result.maxItems | Should Be  $true
        }
        It 'ArrayNullableUniqueItems' {
            $result = New-PodeOABoolProperty -Name 'testBool' -Description 'Test for New-PodeOABoolProperty' -Default 'yes' `
                -Example 'Example for New-PodeOABoolProperty' -Enum $true, $false , 'yes', 'no' -XmlName 'xTestBool' -Nullable  -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should Not Be $null
            $result.meta.Count | Should Be 2
            $result.type | Should Be 'boolean'
            $result.name | Should Be 'testBool'
            $result.description | Should Be 'Test for New-PodeOABoolProperty'
            $result.default | Should Be 'yes'
            $result.meta['example'] | Should Be 'Example for New-PodeOABoolProperty'
            $result.enum | Should Be @('true', 'false' , 'yes', 'no')
            $result.xmlName | Should Be  'xTestBool'
            $result.meta['nullable'] | Should Be $true
            $result.array | Should Be  $true
            $result.uniqueItems | Should Be  $true
            $result.minItems | Should Be  $true
            $result.maxItems | Should Be  $true
        }
        It 'ArrayWriteOnlyUniqueItems' {
            $result = New-PodeOABoolProperty -Name 'testBool' -Description 'Test for New-PodeOABoolProperty' -Default 'yes' `
                -Example 'Example for New-PodeOABoolProperty' -Enum $true, $false , 'yes', 'no' -XmlName 'xTestBool' -WriteOnly  -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should Not Be $null
            $result.meta.Count | Should Be 2
            $result.type | Should Be 'boolean'
            $result.name | Should Be 'testBool'
            $result.description | Should Be 'Test for New-PodeOABoolProperty'
            $result.default | Should Be 'yes'
            $result.meta['example'] | Should Be 'Example for New-PodeOABoolProperty'
            $result.enum | Should Be @('true', 'false' , 'yes', 'no')
            $result.xmlName | Should Be  'xTestBool'
            $result.meta['writeOnly'] | Should Be $true
            $result.array | Should Be  $true
            $result.uniqueItems | Should Be  $true
            $result.minItems | Should Be  $true
            $result.maxItems | Should Be  $true
        }
        It 'ArrayReadOnlyUniqueItems' {
            $result = New-PodeOABoolProperty -Name 'testBool' -Description 'Test for New-PodeOABoolProperty' -Default 'yes' `
                -Example 'Example for New-PodeOABoolProperty' -Enum $true, $false , 'yes', 'no' -XmlName 'xTestBool' -ReadOnly  -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should Not Be $null
            $result.meta.Count | Should Be 2
            $result.type | Should Be 'boolean'
            $result.name | Should Be 'testBool'
            $result.description | Should Be 'Test for New-PodeOABoolProperty'
            $result.default | Should Be 'yes'
            $result.meta['example'] | Should Be 'Example for New-PodeOABoolProperty'
            $result.enum | Should Be @('true', 'false' , 'yes', 'no')
            $result.xmlName | Should Be  'xTestBool'
            $result.meta['readOnly'] | Should Be $true
            $result.array | Should Be  $true
            $result.uniqueItems | Should Be  $true
            $result.minItems | Should Be  $true
            $result.maxItems | Should Be  $true
        }

        It 'ArrayNoSwitches' {
            $result = New-PodeOABoolProperty -Name 'testBool' -Description 'Test for New-PodeOABoolProperty' -Default 'yes' `
                -Example 'Example for New-PodeOABoolProperty' -Enum $true, $false , 'yes', 'no' -XmlName 'xTestBool' -Array  -MinItems 2 -MaxItems 4
            $result | Should Not Be $null
            $result.meta.Count | Should Be 1
            $result.type | Should Be 'boolean'
            $result.name | Should Be 'testBool'
            $result.description | Should Be 'Test for New-PodeOABoolProperty'
            $result.default | Should Be 'yes'
            $result.meta['example'] | Should Be 'Example for New-PodeOABoolProperty'
            $result.enum | Should Be @('true', 'false' , 'yes', 'no')
            $result.xmlName | Should Be  'xTestBool'
            $result.array | Should Be  $true
            $result.minItems | Should Be  $true
            $result.maxItems | Should Be  $true

        }
        It 'ArrayDeprecated' {
            $result = New-PodeOABoolProperty -Name 'testBool' -Description 'Test for New-PodeOABoolProperty' -Default 'yes' `
                -Example 'Example for New-PodeOABoolProperty' -Enum $true, $false , 'yes', 'no' -XmlName 'xTestBool' -Deprecated  -Array  -MinItems 2 -MaxItems 4
            $result | Should Not Be $null
            $result.meta.Count | Should Be 1
            $result.type | Should Be 'boolean'
            $result.name | Should Be 'testBool'
            $result.description | Should Be 'Test for New-PodeOABoolProperty'
            $result.default | Should Be 'yes'
            $result.meta['example'] | Should Be 'Example for New-PodeOABoolProperty'
            $result.enum | Should Be @('true', 'false' , 'yes', 'no')
            $result.xmlName | Should Be  'xTestBool'
            $result.deprecated | Should Be $true
            $result.array | Should Be  $true
            $result.minItems | Should Be  $true
            $result.maxItems | Should Be  $true
        }
        It 'ArrayNullable' {
            $result = New-PodeOABoolProperty -Name 'testBool' -Description 'Test for New-PodeOABoolProperty' -Default 'yes' `
                -Example 'Example for New-PodeOABoolProperty' -Enum $true, $false , 'yes', 'no' -XmlName 'xTestBool' -Nullable  -Array  -MinItems 2 -MaxItems 4
            $result | Should Not Be $null
            $result.meta.Count | Should Be 2
            $result.type | Should Be 'boolean'
            $result.name | Should Be 'testBool'
            $result.description | Should Be 'Test for New-PodeOABoolProperty'
            $result.default | Should Be 'yes'
            $result.meta['example'] | Should Be 'Example for New-PodeOABoolProperty'
            $result.enum | Should Be @('true', 'false' , 'yes', 'no')
            $result.xmlName | Should Be  'xTestBool'
            $result.meta['nullable'] | Should Be $true
            $result.array | Should Be  $true
            $result.minItems | Should Be  $true
            $result.maxItems | Should Be  $true
        }
        It 'ArrayWriteOnly' {
            $result = New-PodeOABoolProperty -Name 'testBool' -Description 'Test for New-PodeOABoolProperty' -Default 'yes' `
                -Example 'Example for New-PodeOABoolProperty' -Enum $true, $false , 'yes', 'no' -XmlName 'xTestBool' -WriteOnly  -Array  -MinItems 2 -MaxItems 4
            $result | Should Not Be $null
            $result.meta.Count | Should Be 2
            $result.type | Should Be 'boolean'
            $result.name | Should Be 'testBool'
            $result.description | Should Be 'Test for New-PodeOABoolProperty'
            $result.default | Should Be 'yes'
            $result.meta['example'] | Should Be 'Example for New-PodeOABoolProperty'
            $result.enum | Should Be @('true', 'false' , 'yes', 'no')
            $result.xmlName | Should Be  'xTestBool'
            $result.meta['writeOnly'] | Should Be $true
            $result.array | Should Be  $true
            $result.minItems | Should Be  $true
            $result.maxItems | Should Be  $true
        }
        It 'ArrayReadOnly' {
            $result = New-PodeOABoolProperty -Name 'testBool' -Description 'Test for New-PodeOABoolProperty' -Default 'yes' `
                -Example 'Example for New-PodeOABoolProperty' -Enum $true, $false , 'yes', 'no' -XmlName 'xTestBool' -ReadOnly  -Array  -MinItems 2 -MaxItems 4
            $result | Should Not Be $null
            $result.meta.Count | Should Be 2
            $result.type | Should Be 'boolean'
            $result.name | Should Be 'testBool'
            $result.description | Should Be 'Test for New-PodeOABoolProperty'
            $result.default | Should Be 'yes'
            $result.meta['example'] | Should Be 'Example for New-PodeOABoolProperty'
            $result.enum | Should Be @('true', 'false' , 'yes', 'no')
            $result.xmlName | Should Be  'xTestBool'
            $result.meta['readOnly'] | Should Be $true
            $result.array | Should Be  $true
            $result.minItems | Should Be  $true
            $result.maxItems | Should Be  $true
        }
    }


    Context 'New-PodeOAStringProperty' {
        It 'NoSwitches' {
            $result = New-PodeOAStringProperty -Name 'testString' -Description 'Test for New-PodeOAStringProperty' -Format Date -Pattern '^\d{4}-\d{2}-\d{2}$' -Default '2000-01-01' -MinLength 2 -MaxLength 20 `
                -Example 'Example for New-PodeOAStringProperty' -Enum '2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01' -XmlName 'xTestString'
            $result | Should Not Be $null
            $result.meta.Count | Should Be 4
            $result.type | Should Be 'string'
            $result.name | Should Be 'testString'
            $result.description | Should Be 'Test for New-PodeOAStringProperty'
            $result.format | Should Be 'Date'
            $result.meta['pattern'] = '^\d{4}-\d{2}-\d{2}$'
            $result.default | Should Be '2000-01-01'
            $result.meta['minLength'] | Should Be 2
            $result.meta['maxLength'] | Should Be 20
            $result.meta['example'] | Should Be 'Example for New-PodeOAStringProperty'
            $result.enum | Should Be @('2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01')
            $result.xmlName | Should Be  'xTestString'
        }
        It 'Object' {
            $result = New-PodeOAStringProperty -Name 'testString' -Description 'Test for New-PodeOAStringProperty' -Format Date -Pattern '^\d{4}-\d{2}-\d{2}$' -Default '2000-01-01' -MinLength 2 -MaxLength 20 `
                -Example 'Example for New-PodeOAStringProperty' -Enum '2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01' -XmlName 'xTestString' -Object
            $result | Should Not Be $null
            $result.meta.Count | Should Be 4
            $result.type | Should Be 'string'
            $result.name | Should Be 'testString'
            $result.description | Should Be 'Test for New-PodeOAStringProperty'
            $result.format | Should Be 'Date'
            $result.meta['pattern'] = '^\d{4}-\d{2}-\d{2}$'
            $result.default | Should Be '2000-01-01'
            $result.meta['minLength'] | Should Be 2
            $result.meta['maxLength'] | Should Be 20
            $result.meta['example'] | Should Be 'Example for New-PodeOAStringProperty'
            $result.enum | Should Be @('2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01')
            $result.xmlName | Should Be  'xTestString'
            $result.object | Should Be $true
        }
        It 'Deprecated' {
            $result = New-PodeOAStringProperty -Name 'testString' -Description 'Test for New-PodeOAStringProperty' -Format Date -Pattern '^\d{4}-\d{2}-\d{2}$' -Default '2000-01-01' -MinLength 2 -MaxLength 20 `
                -Example 'Example for New-PodeOAStringProperty' -Enum '2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01' -XmlName 'xTestString' -Deprecated
            $result | Should Not Be $null
            $result.meta.Count | Should Be 4
            $result.type | Should Be 'string'
            $result.name | Should Be 'testString'
            $result.description | Should Be 'Test for New-PodeOAStringProperty'
            $result.format | Should Be 'Date'
            $result.meta['pattern'] = '^\d{4}-\d{2}-\d{2}$'
            $result.default | Should Be '2000-01-01'
            $result.meta['minLength'] | Should Be 2
            $result.meta['maxLength'] | Should Be 20
            $result.meta['example'] | Should Be 'Example for New-PodeOAStringProperty'
            $result.enum | Should Be @('2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01')
            $result.xmlName | Should Be  'xTestString'
            $result.deprecated | Should Be $true
        }
        It 'Nullable' {
            $result = New-PodeOAStringProperty -Name 'testString' -Description 'Test for New-PodeOAStringProperty' -Format Date -Pattern '^\d{4}-\d{2}-\d{2}$' -Default '2000-01-01' -MinLength 2 -MaxLength 20 `
                -Example 'Example for New-PodeOAStringProperty' -Enum '2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01' -XmlName 'xTestString' -Nullable
            $result | Should Not Be $null
            $result.meta.Count | Should Be 5
            $result.type | Should Be 'string'
            $result.name | Should Be 'testString'
            $result.description | Should Be 'Test for New-PodeOAStringProperty'
            $result.format | Should Be 'Date'
            $result.meta['pattern'] = '^\d{4}-\d{2}-\d{2}$'
            $result.default | Should Be '2000-01-01'
            $result.meta['minLength'] | Should Be 2
            $result.meta['maxLength'] | Should Be 20
            $result.meta['example'] | Should Be 'Example for New-PodeOAStringProperty'
            $result.enum | Should Be @('2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01')
            $result.xmlName | Should Be  'xTestString'
            $result.meta['nullable'] | Should Be $true
        }
        It 'WriteOnly' {
            $result = New-PodeOAStringProperty -Name 'testString' -Description 'Test for New-PodeOAStringProperty' -Format Date -Pattern '^\d{4}-\d{2}-\d{2}$' -Default '2000-01-01' -MinLength 2 -MaxLength 20 `
                -Example 'Example for New-PodeOAStringProperty' -Enum '2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01' -XmlName 'xTestString' -WriteOnly
            $result | Should Not Be $null
            $result.meta.Count | Should Be 5
            $result.type | Should Be 'string'
            $result.name | Should Be 'testString'
            $result.description | Should Be 'Test for New-PodeOAStringProperty'
            $result.format | Should Be 'Date'
            $result.meta['pattern'] = '^\d{4}-\d{2}-\d{2}$'
            $result.default | Should Be '2000-01-01'
            $result.meta['minLength'] | Should Be 2
            $result.meta['maxLength'] | Should Be 20
            $result.meta['example'] | Should Be 'Example for New-PodeOAStringProperty'
            $result.enum | Should Be @('2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01')
            $result.xmlName | Should Be  'xTestString'
            $result.meta['writeOnly'] | Should Be $true
        }
        It 'ReadOnly' {
            $result = New-PodeOAStringProperty -Name 'testString' -Description 'Test for New-PodeOAStringProperty' -Format Date -Pattern '^\d{4}-\d{2}-\d{2}$' -Default '2000-01-01' -MinLength 2 -MaxLength 20 `
                -Example 'Example for New-PodeOAStringProperty' -Enum '2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01' -XmlName 'xTestString' -ReadOnly
            $result | Should Not Be $null
            $result.meta.Count | Should Be 5
            $result.type | Should Be 'string'
            $result.name | Should Be 'testString'
            $result.description | Should Be 'Test for New-PodeOAStringProperty'
            $result.format | Should Be 'Date'
            $result.meta['pattern'] = '^\d{4}-\d{2}-\d{2}$'
            $result.default | Should Be '2000-01-01'
            $result.meta['minLength'] | Should Be 2
            $result.meta['maxLength'] | Should Be 20
            $result.meta['example'] | Should Be 'Example for New-PodeOAStringProperty'
            $result.enum | Should Be @('2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01')
            $result.xmlName | Should Be  'xTestString'
            $result.meta['readOnly'] | Should Be $true
        }

        It 'ArrayNoSwitchesUniqueItems' {
            $result = New-PodeOAStringProperty -Name 'testString' -Description 'Test for New-PodeOAStringProperty' -Format Date -Pattern '^\d{4}-\d{2}-\d{2}$' -Default '2000-01-01' -MinLength 2 -MaxLength 20 `
                -Example 'Example for New-PodeOAStringProperty' -Enum '2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01' -XmlName 'xTestString' -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should Not Be $null
            $result.meta.Count | Should Be 4
            $result.type | Should Be 'string'
            $result.name | Should Be 'testString'
            $result.description | Should Be 'Test for New-PodeOAStringProperty'
            $result.format | Should Be 'Date'
            $result.meta['pattern'] = '^\d{4}-\d{2}-\d{2}$'
            $result.default | Should Be '2000-01-01'
            $result.meta['minLength'] | Should Be 2
            $result.meta['maxLength'] | Should Be 20
            $result.meta['example'] | Should Be 'Example for New-PodeOAStringProperty'
            $result.enum | Should Be @('2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01')
            $result.xmlName | Should Be  'xTestString'
            $result.array | Should Be  $true
            $result.uniqueItems | Should Be  $true
            $result.minItems | Should Be  $true
            $result.maxItems | Should Be  $true

        }
        It 'ArrayDeprecatedUniqueItems' {
            $result = New-PodeOAStringProperty -Name 'testString' -Description 'Test for New-PodeOAStringProperty' -Format Date -Pattern '^\d{4}-\d{2}-\d{2}$' -Default '2000-01-01' -MinLength 2 -MaxLength 20 `
                -Example 'Example for New-PodeOAStringProperty' -Enum '2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01' -XmlName 'xTestString' -Deprecated  -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should Not Be $null
            $result.meta.Count | Should Be 4
            $result.type | Should Be 'string'
            $result.name | Should Be 'testString'
            $result.description | Should Be 'Test for New-PodeOAStringProperty'
            $result.format | Should Be 'Date'
            $result.meta['pattern'] = '^\d{4}-\d{2}-\d{2}$'
            $result.default | Should Be '2000-01-01'
            $result.meta['minLength'] | Should Be 2
            $result.meta['maxLength'] | Should Be 20
            $result.meta['example'] | Should Be 'Example for New-PodeOAStringProperty'
            $result.enum | Should Be @('2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01')
            $result.xmlName | Should Be  'xTestString'
            $result.deprecated | Should Be $true
            $result.array | Should Be  $true
            $result.uniqueItems | Should Be  $true
            $result.minItems | Should Be  $true
            $result.maxItems | Should Be  $true
        }
        It 'ArrayNullableUniqueItems' {
            $result = New-PodeOAStringProperty -Name 'testString' -Description 'Test for New-PodeOAStringProperty' -Format Date -Pattern '^\d{4}-\d{2}-\d{2}$' -Default '2000-01-01' -MinLength 2 -MaxLength 20 `
                -Example 'Example for New-PodeOAStringProperty' -Enum '2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01' -XmlName 'xTestString' -Nullable  -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should Not Be $null
            $result.meta.Count | Should Be 5
            $result.type | Should Be 'string'
            $result.name | Should Be 'testString'
            $result.description | Should Be 'Test for New-PodeOAStringProperty'
            $result.format | Should Be 'Date'
            $result.meta['pattern'] = '^\d{4}-\d{2}-\d{2}$'
            $result.default | Should Be '2000-01-01'
            $result.meta['minLength'] | Should Be 2
            $result.meta['maxLength'] | Should Be 20
            $result.meta['example'] | Should Be 'Example for New-PodeOAStringProperty'
            $result.enum | Should Be @('2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01')
            $result.xmlName | Should Be  'xTestString'
            $result.meta['nullable'] | Should Be $true
            $result.array | Should Be  $true
            $result.uniqueItems | Should Be  $true
            $result.minItems | Should Be  $true
            $result.maxItems | Should Be  $true
        }
        It 'ArrayWriteOnlyUniqueItems' {
            $result = New-PodeOAStringProperty -Name 'testString' -Description 'Test for New-PodeOAStringProperty' -Format Date -Pattern '^\d{4}-\d{2}-\d{2}$' -Default '2000-01-01' -MinLength 2 -MaxLength 20 `
                -Example 'Example for New-PodeOAStringProperty' -Enum '2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01' -XmlName 'xTestString' -WriteOnly  -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should Not Be $null
            $result.meta.Count | Should Be 5
            $result.type | Should Be 'string'
            $result.name | Should Be 'testString'
            $result.description | Should Be 'Test for New-PodeOAStringProperty'
            $result.format | Should Be 'Date'
            $result.meta['pattern'] = '^\d{4}-\d{2}-\d{2}$'
            $result.default | Should Be '2000-01-01'
            $result.meta['minLength'] | Should Be 2
            $result.meta['maxLength'] | Should Be 20
            $result.meta['example'] | Should Be 'Example for New-PodeOAStringProperty'
            $result.enum | Should Be @('2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01')
            $result.xmlName | Should Be  'xTestString'
            $result.meta['writeOnly'] | Should Be $true
            $result.array | Should Be  $true
            $result.uniqueItems | Should Be  $true
            $result.minItems | Should Be  $true
            $result.maxItems | Should Be  $true
        }
        It 'ArrayReadOnlyUniqueItems' {
            $result = New-PodeOAStringProperty -Name 'testString' -Description 'Test for New-PodeOAStringProperty' -Format Date -Pattern '^\d{4}-\d{2}-\d{2}$' -Default '2000-01-01' -MinLength 2 -MaxLength 20 `
                -Example 'Example for New-PodeOAStringProperty' -Enum '2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01' -XmlName 'xTestString' -ReadOnly  -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should Not Be $null
            $result.meta.Count | Should Be 5
            $result.type | Should Be 'string'
            $result.name | Should Be 'testString'
            $result.description | Should Be 'Test for New-PodeOAStringProperty'
            $result.format | Should Be 'Date'
            $result.meta['pattern'] = '^\d{4}-\d{2}-\d{2}$'
            $result.default | Should Be '2000-01-01'
            $result.meta['minLength'] | Should Be 2
            $result.meta['maxLength'] | Should Be 20
            $result.meta['example'] | Should Be 'Example for New-PodeOAStringProperty'
            $result.enum | Should Be @('2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01')
            $result.xmlName | Should Be  'xTestString'
            $result.meta['readOnly'] | Should Be $true
            $result.array | Should Be  $true
            $result.uniqueItems | Should Be  $true
            $result.minItems | Should Be  $true
            $result.maxItems | Should Be  $true
        }

        It 'ArrayNoSwitches' {
            $result = New-PodeOAStringProperty -Name 'testString' -Description 'Test for New-PodeOAStringProperty' -Format Date -Pattern '^\d{4}-\d{2}-\d{2}$' -Default '2000-01-01' -MinLength 2 -MaxLength 20 `
                -Example 'Example for New-PodeOAStringProperty' -Enum '2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01' -XmlName 'xTestString' -Array  -MinItems 2 -MaxItems 4
            $result | Should Not Be $null
            $result.meta.Count | Should Be 4
            $result.type | Should Be 'string'
            $result.name | Should Be 'testString'
            $result.description | Should Be 'Test for New-PodeOAStringProperty'
            $result.format | Should Be 'Date'
            $result.meta['pattern'] = '^\d{4}-\d{2}-\d{2}$'
            $result.default | Should Be '2000-01-01'
            $result.meta['minLength'] | Should Be 2
            $result.meta['maxLength'] | Should Be 20
            $result.meta['example'] | Should Be 'Example for New-PodeOAStringProperty'
            $result.enum | Should Be @('2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01')
            $result.xmlName | Should Be  'xTestString'
            $result.array | Should Be  $true
            $result.minItems | Should Be  $true
            $result.maxItems | Should Be  $true

        }
        It 'ArrayDeprecated' {
            $result = New-PodeOAStringProperty -Name 'testString' -Description 'Test for New-PodeOAStringProperty' -Format Date -Pattern '^\d{4}-\d{2}-\d{2}$' -Default '2000-01-01' -MinLength 2 -MaxLength 20 `
                -Example 'Example for New-PodeOAStringProperty' -Enum '2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01' -XmlName 'xTestString' -Deprecated  -Array  -MinItems 2 -MaxItems 4
            $result | Should Not Be $null
            $result.meta.Count | Should Be 4
            $result.type | Should Be 'string'
            $result.name | Should Be 'testString'
            $result.description | Should Be 'Test for New-PodeOAStringProperty'
            $result.format | Should Be 'Date'
            $result.meta['pattern'] = '^\d{4}-\d{2}-\d{2}$'
            $result.default | Should Be '2000-01-01'
            $result.meta['minLength'] | Should Be 2
            $result.meta['maxLength'] | Should Be 20
            $result.meta['example'] | Should Be 'Example for New-PodeOAStringProperty'
            $result.enum | Should Be @('2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01')
            $result.xmlName | Should Be  'xTestString'
            $result.deprecated | Should Be $true
            $result.array | Should Be  $true
            $result.minItems | Should Be  $true
            $result.maxItems | Should Be  $true
        }
        It 'ArrayNullable' {
            $result = New-PodeOAStringProperty -Name 'testString' -Description 'Test for New-PodeOAStringProperty' -Format Date -Pattern '^\d{4}-\d{2}-\d{2}$' -Default '2000-01-01' -MinLength 2 -MaxLength 20 `
                -Example 'Example for New-PodeOAStringProperty' -Enum '2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01' -XmlName 'xTestString' -Nullable  -Array  -MinItems 2 -MaxItems 4
            $result | Should Not Be $null
            $result.meta.Count | Should Be 5
            $result.type | Should Be 'string'
            $result.name | Should Be 'testString'
            $result.description | Should Be 'Test for New-PodeOAStringProperty'
            $result.format | Should Be 'Date'
            $result.meta['pattern'] = '^\d{4}-\d{2}-\d{2}$'
            $result.default | Should Be '2000-01-01'
            $result.meta['minLength'] | Should Be 2
            $result.meta['maxLength'] | Should Be 20
            $result.meta['example'] | Should Be 'Example for New-PodeOAStringProperty'
            $result.enum | Should Be @('2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01')
            $result.xmlName | Should Be  'xTestString'
            $result.meta['nullable'] | Should Be $true
            $result.array | Should Be  $true
            $result.minItems | Should Be  $true
            $result.maxItems | Should Be  $true
        }
        It 'ArrayWriteOnly' {
            $result = New-PodeOAStringProperty -Name 'testString' -Description 'Test for New-PodeOAStringProperty' -Format Date -Pattern '^\d{4}-\d{2}-\d{2}$' -Default '2000-01-01' -MinLength 2 -MaxLength 20 `
                -Example 'Example for New-PodeOAStringProperty' -Enum '2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01' -XmlName 'xTestString' -WriteOnly  -Array  -MinItems 2 -MaxItems 4
            $result | Should Not Be $null
            $result.meta.Count | Should Be 5
            $result.type | Should Be 'string'
            $result.name | Should Be 'testString'
            $result.description | Should Be 'Test for New-PodeOAStringProperty'
            $result.format | Should Be 'Date'
            $result.meta['pattern'] = '^\d{4}-\d{2}-\d{2}$'
            $result.default | Should Be '2000-01-01'
            $result.meta['minLength'] | Should Be 2
            $result.meta['maxLength'] | Should Be 20
            $result.meta['example'] | Should Be 'Example for New-PodeOAStringProperty'
            $result.enum | Should Be @('2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01')
            $result.xmlName | Should Be  'xTestString'
            $result.meta['writeOnly'] | Should Be $true
            $result.array | Should Be  $true
            $result.minItems | Should Be  $true
            $result.maxItems | Should Be  $true
        }
        It 'ArrayReadOnly' {
            $result = New-PodeOAStringProperty -Name 'testString' -Description 'Test for New-PodeOAStringProperty' -Format Date -Pattern '^\d{4}-\d{2}-\d{2}$' -Default '2000-01-01' -MinLength 2 -MaxLength 20 `
                -Example 'Example for New-PodeOAStringProperty' -Enum '2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01' -XmlName 'xTestString' -ReadOnly  -Array  -MinItems 2 -MaxItems 4
            $result | Should Not Be $null
            $result.meta.Count | Should Be 5
            $result.type | Should Be 'string'
            $result.name | Should Be 'testString'
            $result.description | Should Be 'Test for New-PodeOAStringProperty'
            $result.format | Should Be 'Date'
            $result.meta['pattern'] = '^\d{4}-\d{2}-\d{2}$'
            $result.default | Should Be '2000-01-01'
            $result.meta['minLength'] | Should Be 2
            $result.meta['maxLength'] | Should Be 20
            $result.meta['example'] | Should Be 'Example for New-PodeOAStringProperty'
            $result.enum | Should Be @('2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01')
            $result.xmlName | Should Be  'xTestString'
            $result.meta['readOnly'] | Should Be $true
            $result.array | Should Be  $true
            $result.minItems | Should Be  $true
            $result.maxItems | Should Be  $true
        }
    }

    Context 'New-PodeOAObjectProperty' {
        It 'NoSwitches' {
            $result = New-PodeOAObjectProperty -Name 'testObject' -Description 'Test for New-PodeOAObjectProperty'  -MinProperties 1 -MaxProperties 2 `
                -Example 'Example for New-PodeOAObjectProperty' -Properties @((New-PodeOAIntProperty -Name 'id'), (New-PodeOAStringProperty -Name 'name')) -XmlName 'xTestObject'
            $result | Should Not Be $null
            $result.meta.Count | Should Be 1
            $result.type | Should Be 'object'
            $result.name | Should Be 'testObject'
            $result.description | Should Be 'Test for New-PodeOAObjectProperty'
            $result.properties.Count | Should Be 2
            $result.properties | ConvertTo-Json -Compress | Should Be '[{"meta":{},"type":"integer","name":"id"},{"meta":{},"type":"string","name":"name"}]'
            $result.minProperties | Should Be 1
            $result.maxProperties | Should Be 2
            $result.meta['example'] | Should Be 'Example for New-PodeOAObjectProperty'
            $result.xmlName | Should Be  'xTestObject'
        }
        It 'Deprecated' {
            $result = New-PodeOAObjectProperty -Name 'testObject' -Description 'Test for New-PodeOAObjectProperty'  -MinProperties 1 -MaxProperties 2 `
                -Example 'Example for New-PodeOAObjectProperty' -Properties @((New-PodeOAIntProperty -Name 'id'), (New-PodeOAStringProperty -Name 'name')) -XmlName 'xTestObject' -Deprecated
            $result | Should Not Be $null
            $result.meta.Count | Should Be 1
            $result.type | Should Be 'object'
            $result.name | Should Be 'testObject'
            $result.description | Should Be 'Test for New-PodeOAObjectProperty'
            $result.properties.Count | Should Be 2
            $result.properties | ConvertTo-Json -Compress | Should Be '[{"meta":{},"type":"integer","name":"id"},{"meta":{},"type":"string","name":"name"}]'
            $result.minProperties | Should Be 1
            $result.maxProperties | Should Be 2
            $result.meta['example'] | Should Be 'Example for New-PodeOAObjectProperty'
            $result.xmlName | Should Be  'xTestObject'
            $result.deprecated | Should Be $true
        }
        It 'Nullable' {
            $result = New-PodeOAObjectProperty -Name 'testObject' -Description 'Test for New-PodeOAObjectProperty'  -MinProperties 1 -MaxProperties 2 `
                -Example 'Example for New-PodeOAObjectProperty' -Properties @((New-PodeOAIntProperty -Name 'id'), (New-PodeOAStringProperty -Name 'name')) -XmlName 'xTestObject' -Nullable
            $result | Should Not Be $null
            $result.meta.Count | Should Be 2
            $result.type | Should Be 'object'
            $result.name | Should Be 'testObject'
            $result.description | Should Be 'Test for New-PodeOAObjectProperty'
            $result.properties.Count | Should Be 2
            $result.properties | ConvertTo-Json -Compress | Should Be '[{"meta":{},"type":"integer","name":"id"},{"meta":{},"type":"string","name":"name"}]'
            $result.minProperties | Should Be 1
            $result.maxProperties | Should Be 2
            $result.meta['example'] | Should Be 'Example for New-PodeOAObjectProperty'
            $result.xmlName | Should Be  'xTestObject'
            $result.meta['nullable'] | Should Be $true
        }
        It 'WriteOnly' {
            $result = New-PodeOAObjectProperty -Name 'testObject' -Description 'Test for New-PodeOAObjectProperty'  -MinProperties 1 -MaxProperties 2 `
                -Example 'Example for New-PodeOAObjectProperty' -Properties @((New-PodeOAIntProperty -Name 'id'), (New-PodeOAStringProperty -Name 'name')) -XmlName 'xTestObject' -WriteOnly
            $result | Should Not Be $null
            $result.meta.Count | Should Be 2
            $result.type | Should Be 'object'
            $result.name | Should Be 'testObject'
            $result.description | Should Be 'Test for New-PodeOAObjectProperty'
            $result.properties.Count | Should Be 2
            $result.properties | ConvertTo-Json -Compress | Should Be '[{"meta":{},"type":"integer","name":"id"},{"meta":{},"type":"string","name":"name"}]'
            $result.minProperties | Should Be 1
            $result.maxProperties | Should Be 2
            $result.meta['example'] | Should Be 'Example for New-PodeOAObjectProperty'
            $result.xmlName | Should Be  'xTestObject'
            $result.meta['writeOnly'] | Should Be $true
        }
        It 'ReadOnly' {
            $result = New-PodeOAObjectProperty -Name 'testObject' -Description 'Test for New-PodeOAObjectProperty'  -MinProperties 1 -MaxProperties 2 `
                -Example 'Example for New-PodeOAObjectProperty' -Properties @((New-PodeOAIntProperty -Name 'id'), (New-PodeOAStringProperty -Name 'name')) -XmlName 'xTestObject' -ReadOnly
            $result | Should Not Be $null
            $result.meta.Count | Should Be 2
            $result.type | Should Be 'object'
            $result.name | Should Be 'testObject'
            $result.description | Should Be 'Test for New-PodeOAObjectProperty'
            $result.properties.Count | Should Be 2
            $result.properties | ConvertTo-Json -Compress | Should Be '[{"meta":{},"type":"integer","name":"id"},{"meta":{},"type":"string","name":"name"}]'
            $result.minProperties | Should Be 1
            $result.maxProperties | Should Be 2
            $result.meta['example'] | Should Be 'Example for New-PodeOAObjectProperty'
            $result.xmlName | Should Be  'xTestObject'
            $result.meta['readOnly'] | Should Be $true
        }

        It 'ArrayNoSwitchesUniqueItems' {
            $result = New-PodeOAObjectProperty -Name 'testObject' -Description 'Test for New-PodeOAObjectProperty'  -MinProperties 1 -MaxProperties 2 `
                -Example 'Example for New-PodeOAObjectProperty' -Properties @((New-PodeOAIntProperty -Name 'id'), (New-PodeOAStringProperty -Name 'name')) -XmlName 'xTestObject' -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should Not Be $null
            $result.meta.Count | Should Be 1
            $result.type | Should Be 'object'
            $result.name | Should Be 'testObject'
            $result.description | Should Be 'Test for New-PodeOAObjectProperty'
            $result.properties.Count | Should Be 2
            $result.properties | ConvertTo-Json -Compress | Should Be '[{"meta":{},"type":"integer","name":"id"},{"meta":{},"type":"string","name":"name"}]'
            $result.minProperties | Should Be 1
            $result.maxProperties | Should Be 2
            $result.meta['example'] | Should Be 'Example for New-PodeOAObjectProperty'
            $result.xmlName | Should Be  'xTestObject'
            $result.array | Should Be  $true
            $result.uniqueItems | Should Be  $true
            $result.minItems | Should Be  $true
            $result.maxItems | Should Be  $true

        }
        It 'ArrayDeprecatedUniqueItems' {
            $result = New-PodeOAObjectProperty -Name 'testObject' -Description 'Test for New-PodeOAObjectProperty'  -MinProperties 1 -MaxProperties 2 `
                -Example 'Example for New-PodeOAObjectProperty' -Properties @((New-PodeOAIntProperty -Name 'id'), (New-PodeOAStringProperty -Name 'name')) -XmlName 'xTestObject' -Deprecated  -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should Not Be $null
            $result.meta.Count | Should Be 1
            $result.type | Should Be 'object'
            $result.name | Should Be 'testObject'
            $result.description | Should Be 'Test for New-PodeOAObjectProperty'
            $result.properties.Count | Should Be 2
            $result.properties | ConvertTo-Json -Compress | Should Be '[{"meta":{},"type":"integer","name":"id"},{"meta":{},"type":"string","name":"name"}]'
            $result.minProperties | Should Be 1
            $result.maxProperties | Should Be 2
            $result.meta['example'] | Should Be 'Example for New-PodeOAObjectProperty'
            $result.xmlName | Should Be  'xTestObject'
            $result.deprecated | Should Be $true
            $result.array | Should Be  $true
            $result.uniqueItems | Should Be  $true
            $result.minItems | Should Be  $true
            $result.maxItems | Should Be  $true
        }
        It 'ArrayNullableUniqueItems' {
            $result = New-PodeOAObjectProperty -Name 'testObject' -Description 'Test for New-PodeOAObjectProperty'  -MinProperties 1 -MaxProperties 2 `
                -Example 'Example for New-PodeOAObjectProperty' -Properties @((New-PodeOAIntProperty -Name 'id'), (New-PodeOAStringProperty -Name 'name')) -XmlName 'xTestObject' -Nullable  -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should Not Be $null
            $result.meta.Count | Should Be 2
            $result.type | Should Be 'object'
            $result.name | Should Be 'testObject'
            $result.description | Should Be 'Test for New-PodeOAObjectProperty'
            $result.properties.Count | Should Be 2
            $result.properties | ConvertTo-Json -Compress | Should Be '[{"meta":{},"type":"integer","name":"id"},{"meta":{},"type":"string","name":"name"}]'
            $result.minProperties | Should Be 1
            $result.maxProperties | Should Be 2
            $result.meta['example'] | Should Be 'Example for New-PodeOAObjectProperty'
            $result.xmlName | Should Be  'xTestObject'
            $result.meta['nullable'] | Should Be $true
            $result.array | Should Be  $true
            $result.uniqueItems | Should Be  $true
            $result.minItems | Should Be  $true
            $result.maxItems | Should Be  $true
        }
        It 'ArrayWriteOnlyUniqueItems' {
            $result = New-PodeOAObjectProperty -Name 'testObject' -Description 'Test for New-PodeOAObjectProperty'  -MinProperties 1 -MaxProperties 2 `
                -Example 'Example for New-PodeOAObjectProperty' -Properties @((New-PodeOAIntProperty -Name 'id'), (New-PodeOAStringProperty -Name 'name')) -XmlName 'xTestObject' -WriteOnly  -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should Not Be $null
            $result.meta.Count | Should Be 2
            $result.type | Should Be 'object'
            $result.name | Should Be 'testObject'
            $result.description | Should Be 'Test for New-PodeOAObjectProperty'
            $result.properties.Count | Should Be 2
            $result.properties | ConvertTo-Json -Compress | Should Be '[{"meta":{},"type":"integer","name":"id"},{"meta":{},"type":"string","name":"name"}]'
            $result.minProperties | Should Be 1
            $result.maxProperties | Should Be 2
            $result.meta['example'] | Should Be 'Example for New-PodeOAObjectProperty'
            $result.xmlName | Should Be  'xTestObject'
            $result.meta['writeOnly'] | Should Be $true
            $result.array | Should Be  $true
            $result.uniqueItems | Should Be  $true
            $result.minItems | Should Be  $true
            $result.maxItems | Should Be  $true
        }
        It 'ArrayReadOnlyUniqueItems' {
            $result = New-PodeOAObjectProperty -Name 'testObject' -Description 'Test for New-PodeOAObjectProperty'  -MinProperties 1 -MaxProperties 2 `
                -Example 'Example for New-PodeOAObjectProperty' -Properties @((New-PodeOAIntProperty -Name 'id'), (New-PodeOAStringProperty -Name 'name')) -XmlName 'xTestObject' -ReadOnly  -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should Not Be $null
            $result.meta.Count | Should Be 2
            $result.type | Should Be 'object'
            $result.name | Should Be 'testObject'
            $result.description | Should Be 'Test for New-PodeOAObjectProperty'
            $result.properties.Count | Should Be 2
            $result.properties | ConvertTo-Json -Compress | Should Be '[{"meta":{},"type":"integer","name":"id"},{"meta":{},"type":"string","name":"name"}]'
            $result.minProperties | Should Be 1
            $result.maxProperties | Should Be 2
            $result.meta['example'] | Should Be 'Example for New-PodeOAObjectProperty'
            $result.xmlName | Should Be  'xTestObject'
            $result.meta['readOnly'] | Should Be $true
            $result.array | Should Be  $true
            $result.uniqueItems | Should Be  $true
            $result.minItems | Should Be  $true
            $result.maxItems | Should Be  $true
        }

        It 'ArrayNoSwitches' {
            $result = New-PodeOAObjectProperty -Name 'testObject' -Description 'Test for New-PodeOAObjectProperty'  -MinProperties 1 -MaxProperties 2 `
                -Example 'Example for New-PodeOAObjectProperty' -Properties @((New-PodeOAIntProperty -Name 'id'), (New-PodeOAStringProperty -Name 'name')) -XmlName 'xTestObject' -Array  -MinItems 2 -MaxItems 4
            $result | Should Not Be $null
            $result.meta.Count | Should Be 1
            $result.type | Should Be 'object'
            $result.name | Should Be 'testObject'
            $result.description | Should Be 'Test for New-PodeOAObjectProperty'
            $result.properties.Count | Should Be 2
            $result.properties | ConvertTo-Json -Compress | Should Be '[{"meta":{},"type":"integer","name":"id"},{"meta":{},"type":"string","name":"name"}]'
            $result.minProperties | Should Be 1
            $result.maxProperties | Should Be 2
            $result.meta['example'] | Should Be 'Example for New-PodeOAObjectProperty'
            $result.xmlName | Should Be  'xTestObject'
            $result.array | Should Be  $true
            $result.minItems | Should Be  $true
            $result.maxItems | Should Be  $true

        }
        It 'ArrayDeprecated' {
            $result = New-PodeOAObjectProperty -Name 'testObject' -Description 'Test for New-PodeOAObjectProperty'  -MinProperties 1 -MaxProperties 2 `
                -Example 'Example for New-PodeOAObjectProperty' -Properties @((New-PodeOAIntProperty -Name 'id'), (New-PodeOAStringProperty -Name 'name')) -XmlName 'xTestObject' -Deprecated  -Array  -MinItems 2 -MaxItems 4
            $result | Should Not Be $null
            $result.meta.Count | Should Be 1
            $result.type | Should Be 'object'
            $result.name | Should Be 'testObject'
            $result.description | Should Be 'Test for New-PodeOAObjectProperty'
            $result.properties.Count | Should Be 2
            $result.properties | ConvertTo-Json -Compress | Should Be '[{"meta":{},"type":"integer","name":"id"},{"meta":{},"type":"string","name":"name"}]'
            $result.minProperties | Should Be 1
            $result.maxProperties | Should Be 2
            $result.meta['example'] | Should Be 'Example for New-PodeOAObjectProperty'
            $result.xmlName | Should Be  'xTestObject'
            $result.deprecated | Should Be $true
            $result.array | Should Be  $true
            $result.minItems | Should Be  $true
            $result.maxItems | Should Be  $true
        }
        It 'ArrayNullable' {
            $result = New-PodeOAObjectProperty -Name 'testObject' -Description 'Test for New-PodeOAObjectProperty'  -MinProperties 1 -MaxProperties 2 `
                -Example 'Example for New-PodeOAObjectProperty' -Properties @((New-PodeOAIntProperty -Name 'id'), (New-PodeOAStringProperty -Name 'name')) -XmlName 'xTestObject' -Nullable  -Array  -MinItems 2 -MaxItems 4
            $result | Should Not Be $null
            $result.meta.Count | Should Be 2
            $result.type | Should Be 'object'
            $result.name | Should Be 'testObject'
            $result.description | Should Be 'Test for New-PodeOAObjectProperty'
            $result.properties.Count | Should Be 2
            $result.properties | ConvertTo-Json -Compress | Should Be '[{"meta":{},"type":"integer","name":"id"},{"meta":{},"type":"string","name":"name"}]'
            $result.minProperties | Should Be 1
            $result.maxProperties | Should Be 2
            $result.meta['example'] | Should Be 'Example for New-PodeOAObjectProperty'
            $result.xmlName | Should Be  'xTestObject'
            $result.meta['nullable'] | Should Be $true
            $result.array | Should Be  $true
            $result.minItems | Should Be  $true
            $result.maxItems | Should Be  $true
        }
        It 'ArrayWriteOnly' {
            $result = New-PodeOAObjectProperty -Name 'testObject' -Description 'Test for New-PodeOAObjectProperty'  -MinProperties 1 -MaxProperties 2 `
                -Example 'Example for New-PodeOAObjectProperty' -Properties @((New-PodeOAIntProperty -Name 'id'), (New-PodeOAStringProperty -Name 'name')) -XmlName 'xTestObject' -WriteOnly  -Array  -MinItems 2 -MaxItems 4
            $result | Should Not Be $null
            $result.meta.Count | Should Be 2
            $result.type | Should Be 'object'
            $result.name | Should Be 'testObject'
            $result.description | Should Be 'Test for New-PodeOAObjectProperty'
            $result.properties.Count | Should Be 2
            $result.properties | ConvertTo-Json -Compress | Should Be '[{"meta":{},"type":"integer","name":"id"},{"meta":{},"type":"string","name":"name"}]'
            $result.minProperties | Should Be 1
            $result.maxProperties | Should Be 2
            $result.meta['example'] | Should Be 'Example for New-PodeOAObjectProperty'
            $result.xmlName | Should Be  'xTestObject'
            $result.meta['writeOnly'] | Should Be $true
            $result.array | Should Be  $true
            $result.minItems | Should Be  $true
            $result.maxItems | Should Be  $true
        }
        It 'ArrayReadOnly' {
            $result = New-PodeOAObjectProperty -Name 'testObject' -Description 'Test for New-PodeOAObjectProperty'  -MinProperties 1 -MaxProperties 2 `
                -Example 'Example for New-PodeOAObjectProperty' -Properties @((New-PodeOAIntProperty -Name 'id'), (New-PodeOAStringProperty -Name 'name')) -XmlName 'xTestObject' -ReadOnly  -Array  -MinItems 2 -MaxItems 4
            $result | Should Not Be $null
            $result.meta.Count | Should Be 2
            $result.type | Should Be 'object'
            $result.name | Should Be 'testObject'
            $result.description | Should Be 'Test for New-PodeOAObjectProperty'
            $result.properties.Count | Should Be 2
            $result.properties | ConvertTo-Json -Compress | Should Be '[{"meta":{},"type":"integer","name":"id"},{"meta":{},"type":"string","name":"name"}]'
            $result.minProperties | Should Be 1
            $result.maxProperties | Should Be 2
            $result.meta['example'] | Should Be 'Example for New-PodeOAObjectProperty'
            $result.xmlName | Should Be  'xTestObject'
            $result.meta['readOnly'] | Should Be $true
            $result.array | Should Be  $true
            $result.minItems | Should Be  $true
            $result.maxItems | Should Be  $true
        }
    }


    Context 'New-PodeOASchemaProperty' {
        Add-PodeOAComponentSchema -Name 'Cat' -Schema (
            New-PodeOAObjectProperty  -Properties  @(
                (New-PodeOABoolProperty -Name 'friendly'),
                    (New-PodeOAStringProperty -Name 'name')
            ))
        It 'Standard' {
            $result = New-PodeOASchemaProperty -Name 'testSchema' -ComponentSchema 'Cat'
            $result | Should Not Be $null
            $result.meta.Count | Should Be 0
            $result.type | Should Be 'schema'
            $result.name | Should Be 'testSchema'
            $result.schema | Should Be 'Cat'
        }

        It 'ArrayNoSwitchesUniqueItems' {
            $result = New-PodeOASchemaProperty -Name 'testSchema' -Description 'Test for New-PodeOASchemaProperty'  -ComponentSchema 'Cat' -MinProperties 1 -MaxProperties 2 `
                -Example 'Example for New-PodeOASchemaProperty'   -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should Not Be $null
            $result.meta.Count | Should Be 1
            $result.type | Should Be 'schema'
            $result.name | Should Be 'testSchema'
            $result.schema | Should Be 'Cat'
            $result.description | Should Be 'Test for New-PodeOASchemaProperty'
            $result.minProperties | Should Be 1
            $result.maxProperties | Should Be 2
            $result.meta['example'] | Should Be 'Example for New-PodeOASchemaProperty'
            $result.array | Should Be  $true
            $result.uniqueItems | Should Be  $true
            $result.minItems | Should Be  $true
            $result.maxItems | Should Be  $true

        }
        It 'ArrayDeprecatedUniqueItems' {
            $result = New-PodeOASchemaProperty -Name 'testSchema' -Description 'Test for New-PodeOASchemaProperty'  -ComponentSchema 'Cat' -MinProperties 1 -MaxProperties 2 `
                -Example 'Example for New-PodeOASchemaProperty'   -Deprecated  -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should Not Be $null
            $result.meta.Count | Should Be 1
            $result.type | Should Be 'schema'
            $result.name | Should Be 'testSchema'
            $result.schema | Should Be 'Cat'
            $result.description | Should Be 'Test for New-PodeOASchemaProperty'
            $result.minProperties | Should Be 1
            $result.maxProperties | Should Be 2
            $result.meta['example'] | Should Be 'Example for New-PodeOASchemaProperty'
            $result.deprecated | Should Be $true
            $result.array | Should Be  $true
            $result.uniqueItems | Should Be  $true
            $result.minItems | Should Be  $true
            $result.maxItems | Should Be  $true
        }
        It 'ArrayNullableUniqueItems' {
            $result = New-PodeOASchemaProperty -Name 'testSchema' -Description 'Test for New-PodeOASchemaProperty'  -ComponentSchema 'Cat' -MinProperties 1 -MaxProperties 2 `
                -Example 'Example for New-PodeOASchemaProperty'   -Nullable  -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should Not Be $null
            $result.meta.Count | Should Be 2
            $result.type | Should Be 'schema'
            $result.name | Should Be 'testSchema'
            $result.schema | Should Be 'Cat'
            $result.description | Should Be 'Test for New-PodeOASchemaProperty'
            $result.minProperties | Should Be 1
            $result.maxProperties | Should Be 2
            $result.meta['example'] | Should Be 'Example for New-PodeOASchemaProperty'
            $result.meta['nullable'] | Should Be $true
            $result.array | Should Be  $true
            $result.uniqueItems | Should Be  $true
            $result.minItems | Should Be  $true
            $result.maxItems | Should Be  $true
        }
        It 'ArrayWriteOnlyUniqueItems' {
            $result = New-PodeOASchemaProperty -Name 'testSchema' -Description 'Test for New-PodeOASchemaProperty'  -ComponentSchema 'Cat' -MinProperties 1 -MaxProperties 2 `
                -Example 'Example for New-PodeOASchemaProperty'   -WriteOnly  -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should Not Be $null
            $result.meta.Count | Should Be 2
            $result.type | Should Be 'schema'
            $result.name | Should Be 'testSchema'
            $result.schema | Should Be 'Cat'
            $result.description | Should Be 'Test for New-PodeOASchemaProperty'
            $result.minProperties | Should Be 1
            $result.maxProperties | Should Be 2
            $result.meta['example'] | Should Be 'Example for New-PodeOASchemaProperty'
            $result.meta['writeOnly'] | Should Be $true
            $result.array | Should Be  $true
            $result.uniqueItems | Should Be  $true
            $result.minItems | Should Be  $true
            $result.maxItems | Should Be  $true
        }
        It 'ArrayReadOnlyUniqueItems' {
            $result = New-PodeOASchemaProperty -Name 'testSchema' -Description 'Test for New-PodeOASchemaProperty'  -ComponentSchema 'Cat' -MinProperties 1 -MaxProperties 2 `
                -Example 'Example for New-PodeOASchemaProperty'   -ReadOnly  -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should Not Be $null
            $result.meta.Count | Should Be 2
            $result.type | Should Be 'schema'
            $result.name | Should Be 'testSchema'
            $result.schema | Should Be 'Cat'
            $result.description | Should Be 'Test for New-PodeOASchemaProperty'
            $result.minProperties | Should Be 1
            $result.maxProperties | Should Be 2
            $result.meta['example'] | Should Be 'Example for New-PodeOASchemaProperty'
            $result.meta['readOnly'] | Should Be $true
            $result.array | Should Be  $true
            $result.uniqueItems | Should Be  $true
            $result.minItems | Should Be  $true
            $result.maxItems | Should Be  $true
        }

        It 'ArrayNoSwitches' {
            $result = New-PodeOASchemaProperty -Name 'testSchema' -Description 'Test for New-PodeOASchemaProperty'  -ComponentSchema 'Cat' -MinProperties 1 -MaxProperties 2 `
                -Example 'Example for New-PodeOASchemaProperty'   -Array  -MinItems 2 -MaxItems 4
            $result | Should Not Be $null
            $result.meta.Count | Should Be 1
            $result.type | Should Be 'schema'
            $result.name | Should Be 'testSchema'
            $result.schema | Should Be 'Cat'
            $result.description | Should Be 'Test for New-PodeOASchemaProperty'
            $result.minProperties | Should Be 1
            $result.maxProperties | Should Be 2
            $result.meta['example'] | Should Be 'Example for New-PodeOASchemaProperty'
            $result.array | Should Be  $true
            $result.minItems | Should Be  $true
            $result.maxItems | Should Be  $true

        }
        It 'ArrayDeprecated' {
            $result = New-PodeOASchemaProperty -Name 'testSchema' -Description 'Test for New-PodeOASchemaProperty'  -ComponentSchema 'Cat' -MinProperties 1 -MaxProperties 2 `
                -Example 'Example for New-PodeOASchemaProperty'   -Deprecated  -Array  -MinItems 2 -MaxItems 4
            $result | Should Not Be $null
            $result.meta.Count | Should Be 1
            $result.type | Should Be 'schema'
            $result.name | Should Be 'testSchema'
            $result.schema | Should Be 'Cat'
            $result.description | Should Be 'Test for New-PodeOASchemaProperty'
            $result.minProperties | Should Be 1
            $result.maxProperties | Should Be 2
            $result.meta['example'] | Should Be 'Example for New-PodeOASchemaProperty'
            $result.deprecated | Should Be $true
            $result.array | Should Be  $true
            $result.minItems | Should Be  $true
            $result.maxItems | Should Be  $true
        }
        It 'ArrayNullable' {
            $result = New-PodeOASchemaProperty -Name 'testSchema' -Description 'Test for New-PodeOASchemaProperty'  -ComponentSchema 'Cat' -MinProperties 1 -MaxProperties 2 `
                -Example 'Example for New-PodeOASchemaProperty'   -Nullable  -Array  -MinItems 2 -MaxItems 4
            $result | Should Not Be $null
            $result.meta.Count | Should Be 2
            $result.type | Should Be 'schema'
            $result.name | Should Be 'testSchema'
            $result.schema | Should Be 'Cat'
            $result.description | Should Be 'Test for New-PodeOASchemaProperty'
            $result.minProperties | Should Be 1
            $result.maxProperties | Should Be 2
            $result.meta['example'] | Should Be 'Example for New-PodeOASchemaProperty'
            $result.meta['nullable'] | Should Be $true
            $result.array | Should Be  $true
            $result.minItems | Should Be  $true
            $result.maxItems | Should Be  $true
        }
        It 'ArrayWriteOnly' {
            $result = New-PodeOASchemaProperty -Name 'testSchema' -Description 'Test for New-PodeOASchemaProperty'  -ComponentSchema 'Cat' -MinProperties 1 -MaxProperties 2 `
                -Example 'Example for New-PodeOASchemaProperty'   -WriteOnly  -Array  -MinItems 2 -MaxItems 4
            $result | Should Not Be $null
            $result.meta.Count | Should Be 2
            $result.type | Should Be 'schema'
            $result.name | Should Be 'testSchema'
            $result.schema | Should Be 'Cat'
            $result.description | Should Be 'Test for New-PodeOASchemaProperty'
            $result.minProperties | Should Be 1
            $result.maxProperties | Should Be 2
            $result.meta['example'] | Should Be 'Example for New-PodeOASchemaProperty'
            $result.meta['writeOnly'] | Should Be $true
            $result.array | Should Be  $true
            $result.minItems | Should Be  $true
            $result.maxItems | Should Be  $true
        }
        It 'ArrayReadOnly' {
            $result = New-PodeOASchemaProperty -Name 'testSchema' -Description 'Test for New-PodeOASchemaProperty'  -ComponentSchema 'Cat' -MinProperties 1 -MaxProperties 2 `
                -Example 'Example for New-PodeOASchemaProperty' -ReadOnly  -Array  -MinItems 2 -MaxItems 4
            $result | Should Not Be $null
            $result.meta.Count | Should Be 2
            $result.type | Should Be 'schema'
            $result.name | Should Be 'testSchema'
            $result.schema | Should Be 'Cat'
            $result.description | Should Be 'Test for New-PodeOASchemaProperty'
            $result.minProperties | Should Be 1
            $result.maxProperties | Should Be 2
            $result.meta['example'] | Should Be 'Example for New-PodeOASchemaProperty'
            $result.meta['readOnly'] | Should Be $true
            $result.array | Should Be  $true
            $result.minItems | Should Be  $true
            $result.maxItems | Should Be  $true
        }
    }




    Context 'Merge-PodeOAProperty' {
        $PodeContext = @{
            Server = @{
                OpenAPI = Get-PodeOABaseObject
            }
        }
        Add-PodeOAComponentSchema -Name 'Pet' -Schema (
            New-PodeOAObjectProperty  -Properties  @(
                (New-PodeOABoolProperty -Name 'friendly'),
                    (New-PodeOAStringProperty -Name 'name')
            ))


        It 'OneOf' {
            $result = Merge-PodeOAProperty   -Type OneOf -Discriminator 'name'   -ObjectDefinitions @('Pet',
              (New-PodeOAObjectProperty  -Properties  @((New-PodeOAIntProperty -Name 'id'), (New-PodeOAStringProperty -Name 'name'))))
            $result | Should Not Be $null
            $result | Should -BeOfType [PSObject]
            $result.type | Should Be 'OneOf'
            $result.discriminator | Should Be 'name'
            $result.schemas.Count | Should Be 2
            $result.schemas | ConvertTo-Json -Compress -Depth 10 | Should -Contain '["Pet",{"meta":{},"type":"object","name":"","properties":[{"meta":{},"type":"integer","name":"id"},{"meta":{},"type":"string","name":"name"}]}]'
        }

        It 'AnyOf' {
            $result = Merge-PodeOAProperty   -Type AnyOf -Discriminator 'name'  -ObjectDefinitions @('Pet',
              (New-PodeOAObjectProperty  -Properties  @((New-PodeOAIntProperty -Name 'id'), (New-PodeOAStringProperty -Name 'name'))))
            $result | Should Not Be $null
            $result | Should -BeOfType [PSObject]
            $result.type | Should Be 'AnyOf'
            $result.discriminator | Should Be 'name'
            $result.schemas.Count | Should Be 2
            $result.schemas | ConvertTo-Json -Compress -Depth 10 | Should -Contain '["Pet",{"meta":{},"type":"object","name":"","properties":[{"meta":{},"type":"integer","name":"id"},{"meta":{},"type":"string","name":"name"}]}]'
        }


        It 'AllOf' {
            $result = Merge-PodeOAProperty   -Type AllOf    -ObjectDefinitions @('Pet',
                (New-PodeOAObjectProperty  -Properties  @((New-PodeOAIntProperty -Name 'id'), (New-PodeOAStringProperty -Name 'name'))))
            $result | Should Not Be $null
            $result | Should -BeOfType [PSObject]
            $result.type | Should Be 'AllOf'
            $result.schemas.Count | Should Be 2
            $result.schemas | ConvertTo-Json -Compress -Depth 10 | Should -Contain '["Pet",{"meta":{},"type":"object","name":"","properties":[{"meta":{},"type":"integer","name":"id"},{"meta":{},"type":"string","name":"name"}]}]'
        }
        Describe 'Testing Exception Handling' {
            It 'AllOf and Discriminator' {
                Merge-PodeOAProperty   -Type AllOf  -Discriminator 'name'  -ObjectDefinitions @('Pet',
                    (New-PodeOAObjectProperty  -Properties  @((New-PodeOAIntProperty -Name 'id'), (New-PodeOAStringProperty -Name 'name')))
                ) | Should  Throw  'Discriminator parameter is not compatible with allOf'
            }

            It 'AllOf and ObjectDefinitions not an object' {
                Merge-PodeOAProperty   -Type AllOf  -Discriminator 'name'  -ObjectDefinitions @('Pet',
                    ((New-PodeOAIntProperty -Name 'id'), (New-PodeOAStringProperty -Name 'name'))
                ) | Should  Throw  'Only properties of type Object can be associated with allof'
            }
        }
    }
    Context 'Add-PodeOAInfo' {
        $PodeContext = @{
            Server = @{
                OpenAPI = Get-PodeOABaseObject
            }
        }
        It 'Valid values' {
            Add-PodeOAInfo -TermsOfService 'http://swagger.io/terms/' -License 'Apache 2.0' -LicenseUrl 'http://www.apache.org/licenses/LICENSE-2.0.html' -ContactName 'API Support' -ContactEmail 'apiteam@swagger.io' -ContactUrl 'http://example.com/support'
            $PodeContext.Server.OpenAPI.info | Should Not Be $null
            $PodeContext.Server.OpenAPI.info.license | Should Not Be $null
            $PodeContext.Server.OpenAPI.info.license.name | Should Be 'Apache 2.0'
            $PodeContext.Server.OpenAPI.info.license.url | Should Be 'http://www.apache.org/licenses/LICENSE-2.0.html'
            $PodeContext.Server.OpenAPI.info.contact | Should Not Be $null
            $PodeContext.Server.OpenAPI.info.contact.name | Should Be 'API Support'
            $PodeContext.Server.OpenAPI.info.contact.email | Should Be 'apiteam@swagger.io'
            $PodeContext.Server.OpenAPI.info.contact.url | Should Be 'http://example.com/support'
        }
    }

    Context 'New-PodeOAExternalDoc' {
        It 'Valid values' {
            New-PodeOAExternalDoc -Name 'SwaggerDocs' -Description 'Find out more about Swagger' -Url 'http://swagger.io'
            $PodeContext.Server.OpenAPI.hiddenComponents.externalDocs['SwaggerDocs'] | Should Not Be $null
            $PodeContext.Server.OpenAPI.hiddenComponents.externalDocs['SwaggerDocs'].description | Should Be  'Find out more about Swagger'
            $PodeContext.Server.OpenAPI.hiddenComponents.externalDocs['SwaggerDocs'].url | Should Be 'http://swagger.io'
        }
    }


    Context 'Add-PodeOAExternalDoc' {
        $PodeContext = @{
            Server = @{
                OpenAPI = Get-PodeOABaseObject
            }
        }
        It 'values' {
            Add-PodeOAExternalDoc -Description 'Find out more about Swagger' -Url 'http://swagger.io'
            $PodeContext.Server.OpenAPI.externalDocs | Should Not Be $null
            $PodeContext.Server.OpenAPI.externalDocs.description | Should Be  'Find out more about Swagger'
            $PodeContext.Server.OpenAPI.externalDocs.url | Should Be 'http://swagger.io'
        }

        It 'Reference' {
            New-PodeOAExternalDoc -Name 'SwaggerDocs' -Description 'Find out more about Swagger' -Url 'http://swagger.io'
            Add-PodeOAExternalDoc -Reference 'SwaggerDocs'
            $PodeContext.Server.OpenAPI.externalDocs | Should Not Be $null
            $PodeContext.Server.OpenAPI.externalDocs.description | Should Be  'Find out more about Swagger'
            $PodeContext.Server.OpenAPI.externalDocs.url | Should Be 'http://swagger.io'
        }
        Describe 'Testing Exception Handling' {
            $PodeContext = @{
                Server = @{
                    OpenAPI = Get-PodeOABaseObject
                }
            }
            It 'ExternaDoc Reference undefined' {
                Add-PodeOAExternalDoc -Reference  'SwaggerDocs' |
                    Should  Throw  "The ExternalDoc doesn't exist: not_available"
            }
        }

    }

    Context 'Add-PodeOATag' {
        $PodeContext = @{
            Server = @{
                OpenAPI = Get-PodeOABaseObject
            }
        }
        New-PodeOAExternalDoc -Name 'SwaggerDocs' -Description 'Find out more about Swagger' -Url 'http://swagger.io'
        It 'Valid values' {
            Add-PodeOATag -Name 'user' -Description 'Operations about user' -ExternalDoc 'SwaggerDocs'
            $PodeContext.Server.OpenAPI.tags['user'] | Should Not Be $null
            $PodeContext.Server.OpenAPI.tags['user'].name | Should Be 'user'
            $PodeContext.Server.OpenAPI.tags['user'].description | Should Be  'Operations about user'
            $PodeContext.Server.OpenAPI.tags['user'].externalDocs | convertto-json -Compress | Should Be '{"description":"Find out more about Swagger","url":"http://swagger.io"}'
        }
        Describe 'Testing Exception Handling' {
            $PodeContext = @{
                Server = @{
                    OpenAPI = Get-PodeOABaseObject
                }
            }
            It 'ExternaDoc undefined' {
                Add-PodeOATag -Name 'user' -Description 'Operations about user' -ExternalDoc 'SwaggerDocs' |
                    Should  Throw  "The ExternalDoc doesn't exist: not_available"
            }
        }
    }



    Context 'Set-PodeOARouteInfo' { 
        It 'No switches' {
            $Route = @{
                OpenApi = @{
                    Path           = '/'
                    Responses      = @{
                        '200'     = @{ description = 'OK' }
                        'default' = @{ description = 'Internal server error' }
                    }
                    Parameters     = $null
                    RequestBody    = $null
                    Authentication = @()
                }
            }
            Add-PodeOATag -Name 'pet' -Description 'Everything about your Pets' -ExternalDoc 'SwaggerDocs'
            $Route | Set-PodeOARouteInfo -Summary 'Update an existing pet' -Description 'Update an existing pet by Id' -Tags 'pet' -OperationId 'updatePet'
            $Route.OpenApi | Should Not Be $null
            $Route.OpenApi.Summary | Should be 'Update an existing pet'
            $Route.OpenApi.description | Should Be 'Update an existing pet by Id'
            $Route.OpenApi.operationId | Should Be  'updatePet'
            $Route.OpenApi.tags | Should Be  'pet'
            $Route.OpenApi.swagger | Should Be  $true
            $result.OpenApi.deprecated | Should be  $null
        }
        It 'Deprecated' {
            $Route = @{
                OpenApi = @{
                    Path           = '/'
                    Responses      = @{
                        '200'     = @{ description = 'OK' }
                        'default' = @{ description = 'Internal server error' }
                    }
                    Parameters     = $null
                    RequestBody    = $null
                    Authentication = @()
                }
            }
            Add-PodeOATag -Name 'pet' -Description 'Everything about your Pets' -ExternalDoc 'SwaggerDocs'
            $Route | Set-PodeOARouteInfo -Summary 'Update an existing pet' -Description 'Update an existing pet by Id' -Tags 'pet' -OperationId 'updatePet' -Deprecated
            $Route.OpenApi | Should Not Be $null
            $Route.OpenApi.Summary | Should be 'Update an existing pet'
            $Route.OpenApi.description | Should Be 'Update an existing pet by Id'
            $Route.OpenApi.operationId | Should Be  'updatePet'
            $Route.OpenApi.tags | Should Be  'pet'
            $Route.OpenApi.swagger | Should Be  $true
            $Route.OpenApi.deprecated | Should Be  $true
        }

        It 'PassThru' {
            $Route = @{
                OpenApi = @{
                    Path           = '/'
                    Responses      = @{
                        '200'     = @{ description = 'OK' }
                        'default' = @{ description = 'Internal server error' }
                    }
                    Parameters     = $null
                    RequestBody    = $null
                    Authentication = @()
                }
            }
            Add-PodeOATag -Name 'pet' -Description 'Everything about your Pets' -ExternalDoc 'SwaggerDocs'
            $result = $Route | Set-PodeOARouteInfo -Summary 'Update an existing pet' -Description 'Update an existing pet by Id' -Tags 'pet' -OperationId 'updatePet' -PassThru
            $result | Should Not Be $null
            $result.OpenApi | Should Not Be $null
            $result.OpenApi.Summary | Should be 'Update an existing pet'
            $result.OpenApi.description | Should Be 'Update an existing pet by Id'
            $result.OpenApi.operationId | Should Be  'updatePet'
            $result.OpenApi.tags | Should Be  'pet'
            $result.OpenApi.swagger | Should Be  $true
            $result.OpenApi.deprecated | Should be  $null
        }
    }



    <#
Describe 'Test-PodeIsEmpty' {
    Context 'No value is passed' {
        It 'Return true for no value' {
            Test-PodeIsEmpty | Should be $true
        }

        It 'Return true for null value' {
            Test-PodeIsEmpty -Value $null | Should be $true
        }
    }

    Context 'Empty value is passed' {
        It 'Return true for an empty arraylist' {
            Test-PodeIsEmpty -Value ([System.Collections.ArrayList]::new()) | Should Be $true
        }

        It 'Return true for an empty array' {
            Test-PodeIsEmpty -Value @() | Should Be $true
        }

        It 'Return true for an empty hashtable' {
            Test-PodeIsEmpty -Value @{} | Should Be $true
        }

        It 'Return true for an empty string' {
            Test-PodeIsEmpty -Value ([string]::Empty) | Should Be $true
        }

        It 'Return true for a whitespace string' {
            Test-PodeIsEmpty -Value '  ' | Should Be $true
        }

        It 'Return true for an empty scriptblock' {
            Test-PodeIsEmpty -Value {} | Should Be $true
        }
    }

    Context 'Valid value is passed' {
        It 'Return false for a string' {
            Test-PodeIsEmpty -Value 'test' | Should Be $false
        }

        It 'Return false for a number' {
            Test-PodeIsEmpty -Value 1 | Should Be $false
        }

        It 'Return false for an array' {
            Test-PodeIsEmpty -Value @('test') | Should Be $false
        }

        It 'Return false for a hashtable' {
            Test-PodeIsEmpty -Value @{'key' = 'value'; } | Should Be $false
        }

        It 'Return false for a scriptblock' {
            Test-PodeIsEmpty -Value { write-host '' } | Should Be $false
        }
    }
}
#>
}