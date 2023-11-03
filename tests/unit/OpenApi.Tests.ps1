BeforeAll {
    $path = $PSCommandPath
    $src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit', '/src/'
    Get-ChildItem "$($src)/*.ps1" -Recurse | Resolve-Path | ForEach-Object { . $_ }
}


Describe 'OpenApi' {

    BeforeEach {
        function GetPodeContext {
            return @{
                Server = @{
                    Security = @{
                        autoheaders = $false
                    }
                    OpenAPI  = @{
                        info             = [ordered]@{}
                        Path             = $null
                        components       = [ordered]@{
                            schemas       = @{}
                            responses     = @{}
                            requestBodies = @{}
                            parameters    = @{}
                        }
                        Security         = @()
                        tags             = [ordered]@{}
                        hiddenComponents = @{
                            enabled          = $false
                            schemaValidation = $false
                            depth            = 20
                            headerSchemas    = @{}
                            externalDocs     = @{}
                            schemaJson       = @{}
                            viewer           = @{}
                        }
                    }
                }
            }
        }
        $global:PodeContext = GetPodeContext



    }


    Context 'New-PodeOAIntProperty' {
        It 'NoSwitches' {
            $result = New-PodeOAIntProperty -Name 'testInt' -Description 'Test for New-PodeOAIntProperty' -Format Int32 -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOAIntProperty' -Enum 2, 4, 8, 16 -XmlName 'xTestInt'
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 4
            $result.type | Should -Be 'integer'
            $result.name | Should -Be 'testInt'
            $result.description | Should -Be 'Test for New-PodeOAIntProperty'
            $result.format | Should -Be 'Int32'
            $result.default | Should -Be 8
            $result.meta['minimum'] | Should -Be 2
            $result.meta['maximum'] | Should -Be 20
            $result.meta['multipleOf'] | Should -Be 2
            $result.meta['example'] | Should -Be 'Example for New-PodeOAIntProperty'
            $result.enum | Should -Be @(2, 4, 8, 16)
            $result.xmlName | Should -Be  'xTestInt'
        }
        It 'Object' {
            $result = New-PodeOAIntProperty -Name 'testInt' -Description 'Test for New-PodeOAIntProperty' -Format Int32 -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOAIntProperty' -Enum 2, 4, 8, 16 -XmlName 'xTestInt' -Object
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 4
            $result.type | Should -Be 'integer'
            $result.name | Should -Be 'testInt'
            $result.description | Should -Be 'Test for New-PodeOAIntProperty'
            $result.format | Should -Be 'Int32'
            $result.default | Should -Be 8
            $result.meta['minimum'] | Should -Be 2
            $result.meta['maximum'] | Should -Be 20
            $result.meta['multipleOf'] | Should -Be 2
            $result.meta['example'] | Should -Be 'Example for New-PodeOAIntProperty'
            $result.enum | Should -Be @(2, 4, 8, 16)
            $result.xmlName | Should -Be  'xTestInt'
            $result.object | Should -Be $true
        }
        It 'Deprecated' {
            $result = New-PodeOAIntProperty -Name 'testInt' -Description 'Test for New-PodeOAIntProperty' -Format Int32 -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOAIntProperty' -Enum 2, 4, 8, 16 -XmlName 'xTestInt' -Deprecated
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 4
            $result.type | Should -Be 'integer'
            $result.name | Should -Be 'testInt'
            $result.description | Should -Be 'Test for New-PodeOAIntProperty'
            $result.format | Should -Be 'Int32'
            $result.default | Should -Be 8
            $result.meta['minimum'] | Should -Be 2
            $result.meta['maximum'] | Should -Be 20
            $result.meta['multipleOf'] | Should -Be 2
            $result.meta['example'] | Should -Be 'Example for New-PodeOAIntProperty'
            $result.enum | Should -Be @(2, 4, 8, 16)
            $result.xmlName | Should -Be  'xTestInt'
            $result.deprecated | Should -Be $true
        }
        It 'Nullable' {
            $result = New-PodeOAIntProperty -Name 'testInt' -Description 'Test for New-PodeOAIntProperty' -Format Int32 -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOAIntProperty' -Enum 2, 4, 8, 16 -XmlName 'xTestInt' -Nullable
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 5
            $result.type | Should -Be 'integer'
            $result.name | Should -Be 'testInt'
            $result.description | Should -Be 'Test for New-PodeOAIntProperty'
            $result.format | Should -Be 'Int32'
            $result.default | Should -Be 8
            $result.meta['minimum'] | Should -Be 2
            $result.meta['maximum'] | Should -Be 20
            $result.meta['multipleOf'] | Should -Be 2
            $result.meta['example'] | Should -Be 'Example for New-PodeOAIntProperty'
            $result.enum | Should -Be @(2, 4, 8, 16)
            $result.xmlName | Should -Be  'xTestInt'
            $result.meta['nullable'] | Should -Be $true
        }
        It 'WriteOnly' {
            $result = New-PodeOAIntProperty -Name 'testInt' -Description 'Test for New-PodeOAIntProperty' -Format Int32 -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOAIntProperty' -Enum 2, 4, 8, 16 -XmlName 'xTestInt' -WriteOnly
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 5
            $result.type | Should -Be 'integer'
            $result.name | Should -Be 'testInt'
            $result.description | Should -Be 'Test for New-PodeOAIntProperty'
            $result.format | Should -Be 'Int32'
            $result.default | Should -Be 8
            $result.meta['minimum'] | Should -Be 2
            $result.meta['maximum'] | Should -Be 20
            $result.meta['multipleOf'] | Should -Be 2
            $result.meta['example'] | Should -Be 'Example for New-PodeOAIntProperty'
            $result.enum | Should -Be @(2, 4, 8, 16)
            $result.xmlName | Should -Be  'xTestInt'
            $result.meta['writeOnly'] | Should -Be $true
        }
        It 'ReadOnly' {
            $result = New-PodeOAIntProperty -Name 'testInt' -Description 'Test for New-PodeOAIntProperty' -Format Int32 -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOAIntProperty' -Enum 2, 4, 8, 16 -XmlName 'xTestInt' -ReadOnly
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 5
            $result.type | Should -Be 'integer'
            $result.name | Should -Be 'testInt'
            $result.description | Should -Be 'Test for New-PodeOAIntProperty'
            $result.format | Should -Be 'Int32'
            $result.default | Should -Be 8
            $result.meta['minimum'] | Should -Be 2
            $result.meta['maximum'] | Should -Be 20
            $result.meta['multipleOf'] | Should -Be 2
            $result.meta['example'] | Should -Be 'Example for New-PodeOAIntProperty'
            $result.enum | Should -Be @(2, 4, 8, 16)
            $result.xmlName | Should -Be  'xTestInt'
            $result.meta['readOnly'] | Should -Be $true
        }

        It 'ArrayNoSwitchesUniqueItems' {
            $result = New-PodeOAIntProperty -Name 'testInt' -Description 'Test for New-PodeOAIntProperty' -Format Int32 -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOAIntProperty' -Enum 2, 4, 8, 16 -XmlName 'xTestInt' -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 4
            $result.type | Should -Be 'integer'
            $result.name | Should -Be 'testInt'
            $result.description | Should -Be 'Test for New-PodeOAIntProperty'
            $result.format | Should -Be 'Int32'
            $result.default | Should -Be 8
            $result.meta['minimum'] | Should -Be 2
            $result.meta['maximum'] | Should -Be 20
            $result.meta['multipleOf'] | Should -Be 2
            $result.meta['example'] | Should -Be 'Example for New-PodeOAIntProperty'
            $result.enum | Should -Be @(2, 4, 8, 16)
            $result.xmlName | Should -Be  'xTestInt'
            $result.array | Should -BeTrue
            $result.uniqueItems | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue

        }
        It 'ArrayDeprecatedUniqueItems' {
            $result = New-PodeOAIntProperty -Name 'testInt' -Description 'Test for New-PodeOAIntProperty' -Format Int32 -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOAIntProperty' -Enum 2, 4, 8, 16 -XmlName 'xTestInt' -Deprecated  -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 4
            $result.type | Should -Be 'integer'
            $result.name | Should -Be 'testInt'
            $result.description | Should -Be 'Test for New-PodeOAIntProperty'
            $result.format | Should -Be 'Int32'
            $result.default | Should -Be 8
            $result.meta['minimum'] | Should -Be 2
            $result.meta['maximum'] | Should -Be 20
            $result.meta['multipleOf'] | Should -Be 2
            $result.meta['example'] | Should -Be 'Example for New-PodeOAIntProperty'
            $result.enum | Should -Be @(2, 4, 8, 16)
            $result.xmlName | Should -Be  'xTestInt'
            $result.deprecated | Should -Be $true
            $result.array | Should -BeTrue
            $result.uniqueItems | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }
        It 'ArrayNullableUniqueItems' {
            $result = New-PodeOAIntProperty -Name 'testInt' -Description 'Test for New-PodeOAIntProperty' -Format Int32 -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOAIntProperty' -Enum 2, 4, 8, 16 -XmlName 'xTestInt' -Nullable  -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 5
            $result.type | Should -Be 'integer'
            $result.name | Should -Be 'testInt'
            $result.description | Should -Be 'Test for New-PodeOAIntProperty'
            $result.format | Should -Be 'Int32'
            $result.default | Should -Be 8
            $result.meta['minimum'] | Should -Be 2
            $result.meta['maximum'] | Should -Be 20
            $result.meta['multipleOf'] | Should -Be 2
            $result.meta['example'] | Should -Be 'Example for New-PodeOAIntProperty'
            $result.enum | Should -Be @(2, 4, 8, 16)
            $result.xmlName | Should -Be  'xTestInt'
            $result.meta['nullable'] | Should -Be $true
            $result.array | Should -BeTrue
            $result.uniqueItems | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }
        It 'ArrayWriteOnlyUniqueItems' {
            $result = New-PodeOAIntProperty -Name 'testInt' -Description 'Test for New-PodeOAIntProperty' -Format Int32 -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOAIntProperty' -Enum 2, 4, 8, 16 -XmlName 'xTestInt' -WriteOnly  -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 5
            $result.type | Should -Be 'integer'
            $result.name | Should -Be 'testInt'
            $result.description | Should -Be 'Test for New-PodeOAIntProperty'
            $result.format | Should -Be 'Int32'
            $result.default | Should -Be 8
            $result.meta['minimum'] | Should -Be 2
            $result.meta['maximum'] | Should -Be 20
            $result.meta['multipleOf'] | Should -Be 2
            $result.meta['example'] | Should -Be 'Example for New-PodeOAIntProperty'
            $result.enum | Should -Be @(2, 4, 8, 16)
            $result.xmlName | Should -Be  'xTestInt'
            $result.meta['writeOnly'] | Should -Be $true
            $result.array | Should -BeTrue
            $result.uniqueItems | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }
        It 'ArrayReadOnlyUniqueItems' {
            $result = New-PodeOAIntProperty -Name 'testInt' -Description 'Test for New-PodeOAIntProperty' -Format Int32 -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOAIntProperty' -Enum 2, 4, 8, 16 -XmlName 'xTestInt' -ReadOnly  -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 5
            $result.type | Should -Be 'integer'
            $result.name | Should -Be 'testInt'
            $result.description | Should -Be 'Test for New-PodeOAIntProperty'
            $result.format | Should -Be 'Int32'
            $result.default | Should -Be 8
            $result.meta['minimum'] | Should -Be 2
            $result.meta['maximum'] | Should -Be 20
            $result.meta['multipleOf'] | Should -Be 2
            $result.meta['example'] | Should -Be 'Example for New-PodeOAIntProperty'
            $result.enum | Should -Be @(2, 4, 8, 16)
            $result.xmlName | Should -Be  'xTestInt'
            $result.meta['readOnly'] | Should -Be $true
            $result.array | Should -BeTrue
            $result.uniqueItems | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }

        It 'ArrayNoSwitches' {
            $result = New-PodeOAIntProperty -Name 'testInt' -Description 'Test for New-PodeOAIntProperty' -Format Int32 -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOAIntProperty' -Enum 2, 4, 8, 16 -XmlName 'xTestInt' -Array  -MinItems 2 -MaxItems 4
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 4
            $result.type | Should -Be 'integer'
            $result.name | Should -Be 'testInt'
            $result.description | Should -Be 'Test for New-PodeOAIntProperty'
            $result.format | Should -Be 'Int32'
            $result.default | Should -Be 8
            $result.meta['minimum'] | Should -Be 2
            $result.meta['maximum'] | Should -Be 20
            $result.meta['multipleOf'] | Should -Be 2
            $result.meta['example'] | Should -Be 'Example for New-PodeOAIntProperty'
            $result.enum | Should -Be @(2, 4, 8, 16)
            $result.xmlName | Should -Be  'xTestInt'
            $result.array | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue

        }
        It 'ArrayDeprecated' {
            $result = New-PodeOAIntProperty -Name 'testInt' -Description 'Test for New-PodeOAIntProperty' -Format Int32 -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOAIntProperty' -Enum 2, 4, 8, 16 -XmlName 'xTestInt' -Deprecated  -Array  -MinItems 2 -MaxItems 4
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 4
            $result.type | Should -Be 'integer'
            $result.name | Should -Be 'testInt'
            $result.description | Should -Be 'Test for New-PodeOAIntProperty'
            $result.format | Should -Be 'Int32'
            $result.default | Should -Be 8
            $result.meta['minimum'] | Should -Be 2
            $result.meta['maximum'] | Should -Be 20
            $result.meta['multipleOf'] | Should -Be 2
            $result.meta['example'] | Should -Be 'Example for New-PodeOAIntProperty'
            $result.enum | Should -Be @(2, 4, 8, 16)
            $result.xmlName | Should -Be  'xTestInt'
            $result.deprecated | Should -Be $true
            $result.array | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }
        It 'ArrayNullable' {
            $result = New-PodeOAIntProperty -Name 'testInt' -Description 'Test for New-PodeOAIntProperty' -Format Int32 -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOAIntProperty' -Enum 2, 4, 8, 16 -XmlName 'xTestInt' -Nullable  -Array  -MinItems 2 -MaxItems 4
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 5
            $result.type | Should -Be 'integer'
            $result.name | Should -Be 'testInt'
            $result.description | Should -Be 'Test for New-PodeOAIntProperty'
            $result.format | Should -Be 'Int32'
            $result.default | Should -Be 8
            $result.meta['minimum'] | Should -Be 2
            $result.meta['maximum'] | Should -Be 20
            $result.meta['multipleOf'] | Should -Be 2
            $result.meta['example'] | Should -Be 'Example for New-PodeOAIntProperty'
            $result.enum | Should -Be @(2, 4, 8, 16)
            $result.xmlName | Should -Be  'xTestInt'
            $result.meta['nullable'] | Should -Be $true
            $result.array | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }
        It 'ArrayWriteOnly' {
            $result = New-PodeOAIntProperty -Name 'testInt' -Description 'Test for New-PodeOAIntProperty' -Format Int32 -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOAIntProperty' -Enum 2, 4, 8, 16 -XmlName 'xTestInt' -WriteOnly  -Array  -MinItems 2 -MaxItems 4
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 5
            $result.type | Should -Be 'integer'
            $result.name | Should -Be 'testInt'
            $result.description | Should -Be 'Test for New-PodeOAIntProperty'
            $result.format | Should -Be 'Int32'
            $result.default | Should -Be 8
            $result.meta['minimum'] | Should -Be 2
            $result.meta['maximum'] | Should -Be 20
            $result.meta['multipleOf'] | Should -Be 2
            $result.meta['example'] | Should -Be 'Example for New-PodeOAIntProperty'
            $result.enum | Should -Be @(2, 4, 8, 16)
            $result.xmlName | Should -Be  'xTestInt'
            $result.meta['writeOnly'] | Should -Be $true
            $result.array | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }
        It 'ArrayReadOnly' {
            $result = New-PodeOAIntProperty -Name 'testInt' -Description 'Test for New-PodeOAIntProperty' -Format Int32 -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOAIntProperty' -Enum 2, 4, 8, 16 -XmlName 'xTestInt' -ReadOnly  -Array  -MinItems 2 -MaxItems 4
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 5
            $result.type | Should -Be 'integer'
            $result.name | Should -Be 'testInt'
            $result.description | Should -Be 'Test for New-PodeOAIntProperty'
            $result.format | Should -Be 'Int32'
            $result.default | Should -Be 8
            $result.meta['minimum'] | Should -Be 2
            $result.meta['maximum'] | Should -Be 20
            $result.meta['multipleOf'] | Should -Be 2
            $result.meta['example'] | Should -Be 'Example for New-PodeOAIntProperty'
            $result.enum | Should -Be @(2, 4, 8, 16)
            $result.xmlName | Should -Be  'xTestInt'
            $result.meta['readOnly'] | Should -Be $true
            $result.array | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }
    }




    Context 'New-PodeOANumberProperty' {
        It 'NoSwitches' {
            $result = New-PodeOANumberProperty -Name 'testNumber' -Description 'Test for New-PodeOANumberProperty' -Format Double -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOANumberProperty' -Enum 2.1, 4.2, 8.3, 16.4 -XmlName 'xTestNumber'
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 4
            $result.type | Should -Be 'number'
            $result.name | Should -Be 'testNumber'
            $result.description | Should -Be 'Test for New-PodeOANumberProperty'
            $result.format | Should -Be 'Double'
            $result.default | Should -Be 8
            $result.meta['minimum'] | Should -Be 2
            $result.meta['maximum'] | Should -Be 20
            $result.meta['multipleOf'] | Should -Be 2
            $result.meta['example'] | Should -Be 'Example for New-PodeOANumberProperty'
            $result.enum | Should -Be @(2.1, 4.2, 8.3, 16.4)
            $result.xmlName | Should -Be  'xTestNumber'
        }
        It 'Object' {
            $result = New-PodeOANumberProperty -Name 'testNumber' -Description 'Test for New-PodeOANumberProperty' -Format Double -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOANumberProperty' -Enum 2.1, 4.2, 8.3, 16.4 -XmlName 'xTestNumber' -Object
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 4
            $result.type | Should -Be 'number'
            $result.name | Should -Be 'testNumber'
            $result.description | Should -Be 'Test for New-PodeOANumberProperty'
            $result.format | Should -Be 'Double'
            $result.default | Should -Be 8
            $result.meta['minimum'] | Should -Be 2
            $result.meta['maximum'] | Should -Be 20
            $result.meta['multipleOf'] | Should -Be 2
            $result.meta['example'] | Should -Be 'Example for New-PodeOANumberProperty'
            $result.enum | Should -Be @(2.1, 4.2, 8.3, 16.4)
            $result.xmlName | Should -Be  'xTestNumber'
            $result.object | Should -Be $true
        }
        It 'Deprecated' {
            $result = New-PodeOANumberProperty -Name 'testNumber' -Description 'Test for New-PodeOANumberProperty' -Format Double -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOANumberProperty' -Enum 2.1, 4.2, 8.3, 16.4 -XmlName 'xTestNumber' -Deprecated
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 4
            $result.type | Should -Be 'number'
            $result.name | Should -Be 'testNumber'
            $result.description | Should -Be 'Test for New-PodeOANumberProperty'
            $result.format | Should -Be 'Double'
            $result.default | Should -Be 8
            $result.meta['minimum'] | Should -Be 2
            $result.meta['maximum'] | Should -Be 20
            $result.meta['multipleOf'] | Should -Be 2
            $result.meta['example'] | Should -Be 'Example for New-PodeOANumberProperty'
            $result.enum | Should -Be @(2.1, 4.2, 8.3, 16.4)
            $result.xmlName | Should -Be  'xTestNumber'
            $result.deprecated | Should -Be $true
        }
        It 'Nullable' {
            $result = New-PodeOANumberProperty -Name 'testNumber' -Description 'Test for New-PodeOANumberProperty' -Format Double -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOANumberProperty' -Enum 2.1, 4.2, 8.3, 16.4 -XmlName 'xTestNumber' -Nullable
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 5
            $result.type | Should -Be 'number'
            $result.name | Should -Be 'testNumber'
            $result.description | Should -Be 'Test for New-PodeOANumberProperty'
            $result.format | Should -Be 'Double'
            $result.default | Should -Be 8
            $result.meta['minimum'] | Should -Be 2
            $result.meta['maximum'] | Should -Be 20
            $result.meta['multipleOf'] | Should -Be 2
            $result.meta['example'] | Should -Be 'Example for New-PodeOANumberProperty'
            $result.enum | Should -Be @(2.1, 4.2, 8.3, 16.4)
            $result.xmlName | Should -Be  'xTestNumber'
            $result.meta['nullable'] | Should -Be $true
        }
        It 'WriteOnly' {
            $result = New-PodeOANumberProperty -Name 'testNumber' -Description 'Test for New-PodeOANumberProperty' -Format Double -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOANumberProperty' -Enum 2.1, 4.2, 8.3, 16.4 -XmlName 'xTestNumber' -WriteOnly
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 5
            $result.type | Should -Be 'number'
            $result.name | Should -Be 'testNumber'
            $result.description | Should -Be 'Test for New-PodeOANumberProperty'
            $result.format | Should -Be 'Double'
            $result.default | Should -Be 8
            $result.meta['minimum'] | Should -Be 2
            $result.meta['maximum'] | Should -Be 20
            $result.meta['multipleOf'] | Should -Be 2
            $result.meta['example'] | Should -Be 'Example for New-PodeOANumberProperty'
            $result.enum | Should -Be @(2.1, 4.2, 8.3, 16.4)
            $result.xmlName | Should -Be  'xTestNumber'
            $result.meta['writeOnly'] | Should -Be $true
        }
        It 'ReadOnly' {
            $result = New-PodeOANumberProperty -Name 'testNumber' -Description 'Test for New-PodeOANumberProperty' -Format Double -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOANumberProperty' -Enum 2.1, 4.2, 8.3, 16.4 -XmlName 'xTestNumber' -ReadOnly
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 5
            $result.type | Should -Be 'number'
            $result.name | Should -Be 'testNumber'
            $result.description | Should -Be 'Test for New-PodeOANumberProperty'
            $result.format | Should -Be 'Double'
            $result.default | Should -Be 8
            $result.meta['minimum'] | Should -Be 2
            $result.meta['maximum'] | Should -Be 20
            $result.meta['multipleOf'] | Should -Be 2
            $result.meta['example'] | Should -Be 'Example for New-PodeOANumberProperty'
            $result.enum | Should -Be @(2.1, 4.2, 8.3, 16.4)
            $result.xmlName | Should -Be  'xTestNumber'
            $result.meta['readOnly'] | Should -Be $true
        }

        It 'ArrayNoSwitchesUniqueItems' {
            $result = New-PodeOANumberProperty -Name 'testNumber' -Description 'Test for New-PodeOANumberProperty' -Format Double -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOANumberProperty' -Enum 2.1, 4.2, 8.3, 16.4 -XmlName 'xTestNumber' -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 4
            $result.type | Should -Be 'number'
            $result.name | Should -Be 'testNumber'
            $result.description | Should -Be 'Test for New-PodeOANumberProperty'
            $result.format | Should -Be 'Double'
            $result.default | Should -Be 8
            $result.meta['minimum'] | Should -Be 2
            $result.meta['maximum'] | Should -Be 20
            $result.meta['multipleOf'] | Should -Be 2
            $result.meta['example'] | Should -Be 'Example for New-PodeOANumberProperty'
            $result.enum | Should -Be @(2.1, 4.2, 8.3, 16.4)
            $result.xmlName | Should -Be  'xTestNumber'
            $result.array | Should -BeTrue
            $result.uniqueItems | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue

        }
        It 'ArrayDeprecatedUniqueItems' {
            $result = New-PodeOANumberProperty -Name 'testNumber' -Description 'Test for New-PodeOANumberProperty' -Format Double -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOANumberProperty' -Enum 2.1, 4.2, 8.3, 16.4 -XmlName 'xTestNumber' -Deprecated  -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 4
            $result.type | Should -Be 'number'
            $result.name | Should -Be 'testNumber'
            $result.description | Should -Be 'Test for New-PodeOANumberProperty'
            $result.format | Should -Be 'Double'
            $result.default | Should -Be 8
            $result.meta['minimum'] | Should -Be 2
            $result.meta['maximum'] | Should -Be 20
            $result.meta['multipleOf'] | Should -Be 2
            $result.meta['example'] | Should -Be 'Example for New-PodeOANumberProperty'
            $result.enum | Should -Be @(2.1, 4.2, 8.3, 16.4)
            $result.xmlName | Should -Be  'xTestNumber'
            $result.deprecated | Should -Be $true
            $result.array | Should -BeTrue
            $result.uniqueItems | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }
        It 'ArrayNullableUniqueItems' {
            $result = New-PodeOANumberProperty -Name 'testNumber' -Description 'Test for New-PodeOANumberProperty' -Format Double -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOANumberProperty' -Enum 2.1, 4.2, 8.3, 16.4 -XmlName 'xTestNumber' -Nullable  -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 5
            $result.type | Should -Be 'number'
            $result.name | Should -Be 'testNumber'
            $result.description | Should -Be 'Test for New-PodeOANumberProperty'
            $result.format | Should -Be 'Double'
            $result.default | Should -Be 8
            $result.meta['minimum'] | Should -Be 2
            $result.meta['maximum'] | Should -Be 20
            $result.meta['multipleOf'] | Should -Be 2
            $result.meta['example'] | Should -Be 'Example for New-PodeOANumberProperty'
            $result.enum | Should -Be @(2.1, 4.2, 8.3, 16.4)
            $result.xmlName | Should -Be  'xTestNumber'
            $result.meta['nullable'] | Should -Be $true
            $result.array | Should -BeTrue
            $result.uniqueItems | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }
        It 'ArrayWriteOnlyUniqueItems' {
            $result = New-PodeOANumberProperty -Name 'testNumber' -Description 'Test for New-PodeOANumberProperty' -Format Double -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOANumberProperty' -Enum 2.1, 4.2, 8.3, 16.4 -XmlName 'xTestNumber' -WriteOnly  -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 5
            $result.type | Should -Be 'number'
            $result.name | Should -Be 'testNumber'
            $result.description | Should -Be 'Test for New-PodeOANumberProperty'
            $result.format | Should -Be 'Double'
            $result.default | Should -Be 8
            $result.meta['minimum'] | Should -Be 2
            $result.meta['maximum'] | Should -Be 20
            $result.meta['multipleOf'] | Should -Be 2
            $result.meta['example'] | Should -Be 'Example for New-PodeOANumberProperty'
            $result.enum | Should -Be @(2.1, 4.2, 8.3, 16.4)
            $result.xmlName | Should -Be  'xTestNumber'
            $result.meta['writeOnly'] | Should -Be $true
            $result.array | Should -BeTrue
            $result.uniqueItems | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }
        It 'ArrayReadOnlyUniqueItems' {
            $result = New-PodeOANumberProperty -Name 'testNumber' -Description 'Test for New-PodeOANumberProperty' -Format Double -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOANumberProperty' -Enum 2.1, 4.2, 8.3, 16.4 -XmlName 'xTestNumber' -ReadOnly  -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 5
            $result.type | Should -Be 'number'
            $result.name | Should -Be 'testNumber'
            $result.description | Should -Be 'Test for New-PodeOANumberProperty'
            $result.format | Should -Be 'Double'
            $result.default | Should -Be 8
            $result.meta['minimum'] | Should -Be 2
            $result.meta['maximum'] | Should -Be 20
            $result.meta['multipleOf'] | Should -Be 2
            $result.meta['example'] | Should -Be 'Example for New-PodeOANumberProperty'
            $result.enum | Should -Be @(2.1, 4.2, 8.3, 16.4)
            $result.xmlName | Should -Be  'xTestNumber'
            $result.meta['readOnly'] | Should -Be $true
            $result.array | Should -BeTrue
            $result.uniqueItems | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }

        It 'ArrayNoSwitches' {
            $result = New-PodeOANumberProperty -Name 'testNumber' -Description 'Test for New-PodeOANumberProperty' -Format Double -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOANumberProperty' -Enum 2.1, 4.2, 8.3, 16.4 -XmlName 'xTestNumber' -Array  -MinItems 2 -MaxItems 4
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 4
            $result.type | Should -Be 'number'
            $result.name | Should -Be 'testNumber'
            $result.description | Should -Be 'Test for New-PodeOANumberProperty'
            $result.format | Should -Be 'Double'
            $result.default | Should -Be 8
            $result.meta['minimum'] | Should -Be 2
            $result.meta['maximum'] | Should -Be 20
            $result.meta['multipleOf'] | Should -Be 2
            $result.meta['example'] | Should -Be 'Example for New-PodeOANumberProperty'
            $result.enum | Should -Be @(2.1, 4.2, 8.3, 16.4)
            $result.xmlName | Should -Be  'xTestNumber'
            $result.array | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue

        }
        It 'ArrayDeprecated' {
            $result = New-PodeOANumberProperty -Name 'testNumber' -Description 'Test for New-PodeOANumberProperty' -Format Double -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOANumberProperty' -Enum 2.1, 4.2, 8.3, 16.4 -XmlName 'xTestNumber' -Deprecated  -Array  -MinItems 2 -MaxItems 4
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 4
            $result.type | Should -Be 'number'
            $result.name | Should -Be 'testNumber'
            $result.description | Should -Be 'Test for New-PodeOANumberProperty'
            $result.format | Should -Be 'Double'
            $result.default | Should -Be 8
            $result.meta['minimum'] | Should -Be 2
            $result.meta['maximum'] | Should -Be 20
            $result.meta['multipleOf'] | Should -Be 2
            $result.meta['example'] | Should -Be 'Example for New-PodeOANumberProperty'
            $result.enum | Should -Be @(2.1, 4.2, 8.3, 16.4)
            $result.xmlName | Should -Be  'xTestNumber'
            $result.deprecated | Should -Be $true
            $result.array | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }
        It 'ArrayNullable' {
            $result = New-PodeOANumberProperty -Name 'testNumber' -Description 'Test for New-PodeOANumberProperty' -Format Double -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOANumberProperty' -Enum 2.1, 4.2, 8.3, 16.4 -XmlName 'xTestNumber' -Nullable  -Array  -MinItems 2 -MaxItems 4
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 5
            $result.type | Should -Be 'number'
            $result.name | Should -Be 'testNumber'
            $result.description | Should -Be 'Test for New-PodeOANumberProperty'
            $result.format | Should -Be 'Double'
            $result.default | Should -Be 8
            $result.meta['minimum'] | Should -Be 2
            $result.meta['maximum'] | Should -Be 20
            $result.meta['multipleOf'] | Should -Be 2
            $result.meta['example'] | Should -Be 'Example for New-PodeOANumberProperty'
            $result.enum | Should -Be @(2.1, 4.2, 8.3, 16.4)
            $result.xmlName | Should -Be  'xTestNumber'
            $result.meta['nullable'] | Should -Be $true
            $result.array | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }
        It 'ArrayWriteOnly' {
            $result = New-PodeOANumberProperty -Name 'testNumber' -Description 'Test for New-PodeOANumberProperty' -Format Double -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOANumberProperty' -Enum 2.1, 4.2, 8.3, 16.4 -XmlName 'xTestNumber' -WriteOnly  -Array  -MinItems 2 -MaxItems 4
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 5
            $result.type | Should -Be 'number'
            $result.name | Should -Be 'testNumber'
            $result.description | Should -Be 'Test for New-PodeOANumberProperty'
            $result.format | Should -Be 'Double'
            $result.default | Should -Be 8
            $result.meta['minimum'] | Should -Be 2
            $result.meta['maximum'] | Should -Be 20
            $result.meta['multipleOf'] | Should -Be 2
            $result.meta['example'] | Should -Be 'Example for New-PodeOANumberProperty'
            $result.enum | Should -Be @(2.1, 4.2, 8.3, 16.4)
            $result.xmlName | Should -Be  'xTestNumber'
            $result.meta['writeOnly'] | Should -Be $true
            $result.array | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }
        It 'ArrayReadOnly' {
            $result = New-PodeOANumberProperty -Name 'testNumber' -Description 'Test for New-PodeOANumberProperty' -Format Double -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOANumberProperty' -Enum 2.1, 4.2, 8.3, 16.4 -XmlName 'xTestNumber' -ReadOnly  -Array  -MinItems 2 -MaxItems 4
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 5
            $result.type | Should -Be 'number'
            $result.name | Should -Be 'testNumber'
            $result.description | Should -Be 'Test for New-PodeOANumberProperty'
            $result.format | Should -Be 'Double'
            $result.default | Should -Be 8
            $result.meta['minimum'] | Should -Be 2
            $result.meta['maximum'] | Should -Be 20
            $result.meta['multipleOf'] | Should -Be 2
            $result.meta['example'] | Should -Be 'Example for New-PodeOANumberProperty'
            $result.enum | Should -Be @(2.1, 4.2, 8.3, 16.4)
            $result.xmlName | Should -Be  'xTestNumber'
            $result.meta['readOnly'] | Should -Be $true
            $result.array | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }
    }

    Context 'New-PodeOABoolProperty' {
        It 'NoSwitches' {
            $result = New-PodeOABoolProperty -Name 'testBool' -Description 'Test for New-PodeOABoolProperty' -Default 'yes' `
                -Example 'Example for New-PodeOABoolProperty' -Enum $true, $false , 'yes', 'no' -XmlName 'xTestBool'
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 1
            $result.type | Should -Be 'boolean'
            $result.name | Should -Be 'testBool'
            $result.description | Should -Be 'Test for New-PodeOABoolProperty'
            $result.default | Should -Be 'yes'
            $result.meta['example'] | Should -Be 'Example for New-PodeOABoolProperty'
            $result.enum | Should -Be @('true', 'false' , 'yes', 'no')
            $result.xmlName | Should -Be  'xTestBool'
        }
        It 'Object' {
            $result = New-PodeOABoolProperty -Name 'testBool' -Description 'Test for New-PodeOABoolProperty' -Default 'yes' `
                -Example 'Example for New-PodeOABoolProperty' -Enum $true, $false , 'yes', 'no' -XmlName 'xTestBool' -Object
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 1
            $result.type | Should -Be 'boolean'
            $result.name | Should -Be 'testBool'
            $result.description | Should -Be 'Test for New-PodeOABoolProperty'
            $result.default | Should -Be 'yes'
            $result.meta['example'] | Should -Be 'Example for New-PodeOABoolProperty'
            $result.enum | Should -Be @('true', 'false' , 'yes', 'no')
            $result.xmlName | Should -Be  'xTestBool'
            $result.object | Should -Be $true
        }
        It 'Deprecated' {
            $result = New-PodeOABoolProperty -Name 'testBool' -Description 'Test for New-PodeOABoolProperty' -Default 'yes' `
                -Example 'Example for New-PodeOABoolProperty' -Enum $true, $false , 'yes', 'no' -XmlName 'xTestBool' -Deprecated
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 1
            $result.type | Should -Be 'boolean'
            $result.name | Should -Be 'testBool'
            $result.description | Should -Be 'Test for New-PodeOABoolProperty'
            $result.default | Should -Be 'yes'
            $result.meta['example'] | Should -Be 'Example for New-PodeOABoolProperty'
            $result.enum | Should -Be @('true', 'false' , 'yes', 'no')
            $result.xmlName | Should -Be  'xTestBool'
            $result.deprecated | Should -Be $true
        }
        It 'Nullable' {
            $result = New-PodeOABoolProperty -Name 'testBool' -Description 'Test for New-PodeOABoolProperty' -Default 'yes' `
                -Example 'Example for New-PodeOABoolProperty' -Enum $true, $false , 'yes', 'no' -XmlName 'xTestBool' -Nullable
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 2
            $result.type | Should -Be 'boolean'
            $result.name | Should -Be 'testBool'
            $result.description | Should -Be 'Test for New-PodeOABoolProperty'
            $result.default | Should -Be 'yes'
            $result.meta['example'] | Should -Be 'Example for New-PodeOABoolProperty'
            $result.enum | Should -Be @('true', 'false' , 'yes', 'no')
            $result.xmlName | Should -Be  'xTestBool'
            $result.meta['nullable'] | Should -Be $true
        }
        It 'WriteOnly' {
            $result = New-PodeOABoolProperty -Name 'testBool' -Description 'Test for New-PodeOABoolProperty' -Default 'yes' `
                -Example 'Example for New-PodeOABoolProperty' -Enum $true, $false , 'yes', 'no' -XmlName 'xTestBool' -WriteOnly
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 2
            $result.type | Should -Be 'boolean'
            $result.name | Should -Be 'testBool'
            $result.description | Should -Be 'Test for New-PodeOABoolProperty'
            $result.default | Should -Be 'yes'
            $result.meta['example'] | Should -Be 'Example for New-PodeOABoolProperty'
            $result.enum | Should -Be @('true', 'false' , 'yes', 'no')
            $result.xmlName | Should -Be  'xTestBool'
            $result.meta['writeOnly'] | Should -Be $true
        }
        It 'ReadOnly' {
            $result = New-PodeOABoolProperty -Name 'testBool' -Description 'Test for New-PodeOABoolProperty' -Default 'yes' `
                -Example 'Example for New-PodeOABoolProperty' -Enum $true, $false , 'yes', 'no' -XmlName 'xTestBool' -ReadOnly
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 2
            $result.type | Should -Be 'boolean'
            $result.name | Should -Be 'testBool'
            $result.description | Should -Be 'Test for New-PodeOABoolProperty'
            $result.default | Should -Be 'yes'
            $result.meta['example'] | Should -Be 'Example for New-PodeOABoolProperty'
            $result.enum | Should -Be @('true', 'false' , 'yes', 'no')
            $result.xmlName | Should -Be  'xTestBool'
            $result.meta['readOnly'] | Should -Be $true
        }

        It 'ArrayNoSwitchesUniqueItems' {
            $result = New-PodeOABoolProperty -Name 'testBool' -Description 'Test for New-PodeOABoolProperty' -Default 'yes' `
                -Example 'Example for New-PodeOABoolProperty' -Enum $true, $false , 'yes', 'no' -XmlName 'xTestBool' -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 1
            $result.type | Should -Be 'boolean'
            $result.name | Should -Be 'testBool'
            $result.description | Should -Be 'Test for New-PodeOABoolProperty'
            $result.default | Should -Be 'yes'
            $result.meta['example'] | Should -Be 'Example for New-PodeOABoolProperty'
            $result.enum | Should -Be @('true', 'false' , 'yes', 'no')
            $result.xmlName | Should -Be  'xTestBool'
            $result.array | Should -BeTrue
            $result.uniqueItems | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue

        }
        It 'ArrayDeprecatedUniqueItems' {
            $result = New-PodeOABoolProperty -Name 'testBool' -Description 'Test for New-PodeOABoolProperty' -Default 'yes' `
                -Example 'Example for New-PodeOABoolProperty' -Enum $true, $false , 'yes', 'no' -XmlName 'xTestBool' -Deprecated  -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 1
            $result.type | Should -Be 'boolean'
            $result.name | Should -Be 'testBool'
            $result.description | Should -Be 'Test for New-PodeOABoolProperty'
            $result.default | Should -Be 'yes'
            $result.meta['example'] | Should -Be 'Example for New-PodeOABoolProperty'
            $result.enum | Should -Be @('true', 'false' , 'yes', 'no')
            $result.xmlName | Should -Be  'xTestBool'
            $result.deprecated | Should -Be $true
            $result.array | Should -BeTrue
            $result.uniqueItems | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }
        It 'ArrayNullableUniqueItems' {
            $result = New-PodeOABoolProperty -Name 'testBool' -Description 'Test for New-PodeOABoolProperty' -Default 'yes' `
                -Example 'Example for New-PodeOABoolProperty' -Enum $true, $false , 'yes', 'no' -XmlName 'xTestBool' -Nullable  -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 2
            $result.type | Should -Be 'boolean'
            $result.name | Should -Be 'testBool'
            $result.description | Should -Be 'Test for New-PodeOABoolProperty'
            $result.default | Should -Be 'yes'
            $result.meta['example'] | Should -Be 'Example for New-PodeOABoolProperty'
            $result.enum | Should -Be @('true', 'false' , 'yes', 'no')
            $result.xmlName | Should -Be  'xTestBool'
            $result.meta['nullable'] | Should -Be $true
            $result.array | Should -BeTrue
            $result.uniqueItems | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }
        It 'ArrayWriteOnlyUniqueItems' {
            $result = New-PodeOABoolProperty -Name 'testBool' -Description 'Test for New-PodeOABoolProperty' -Default 'yes' `
                -Example 'Example for New-PodeOABoolProperty' -Enum $true, $false , 'yes', 'no' -XmlName 'xTestBool' -WriteOnly  -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 2
            $result.type | Should -Be 'boolean'
            $result.name | Should -Be 'testBool'
            $result.description | Should -Be 'Test for New-PodeOABoolProperty'
            $result.default | Should -Be 'yes'
            $result.meta['example'] | Should -Be 'Example for New-PodeOABoolProperty'
            $result.enum | Should -Be @('true', 'false' , 'yes', 'no')
            $result.xmlName | Should -Be  'xTestBool'
            $result.meta['writeOnly'] | Should -Be $true
            $result.array | Should -BeTrue
            $result.uniqueItems | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }
        It 'ArrayReadOnlyUniqueItems' {
            $result = New-PodeOABoolProperty -Name 'testBool' -Description 'Test for New-PodeOABoolProperty' -Default 'yes' `
                -Example 'Example for New-PodeOABoolProperty' -Enum $true, $false , 'yes', 'no' -XmlName 'xTestBool' -ReadOnly  -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 2
            $result.type | Should -Be 'boolean'
            $result.name | Should -Be 'testBool'
            $result.description | Should -Be 'Test for New-PodeOABoolProperty'
            $result.default | Should -Be 'yes'
            $result.meta['example'] | Should -Be 'Example for New-PodeOABoolProperty'
            $result.enum | Should -Be @('true', 'false' , 'yes', 'no')
            $result.xmlName | Should -Be  'xTestBool'
            $result.meta['readOnly'] | Should -Be $true
            $result.array | Should -BeTrue
            $result.uniqueItems | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }

        It 'ArrayNoSwitches' {
            $result = New-PodeOABoolProperty -Name 'testBool' -Description 'Test for New-PodeOABoolProperty' -Default 'yes' `
                -Example 'Example for New-PodeOABoolProperty' -Enum $true, $false , 'yes', 'no' -XmlName 'xTestBool' -Array  -MinItems 2 -MaxItems 4
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 1
            $result.type | Should -Be 'boolean'
            $result.name | Should -Be 'testBool'
            $result.description | Should -Be 'Test for New-PodeOABoolProperty'
            $result.default | Should -Be 'yes'
            $result.meta['example'] | Should -Be 'Example for New-PodeOABoolProperty'
            $result.enum | Should -Be @('true', 'false' , 'yes', 'no')
            $result.xmlName | Should -Be  'xTestBool'
            $result.array | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue

        }
        It 'ArrayDeprecated' {
            $result = New-PodeOABoolProperty -Name 'testBool' -Description 'Test for New-PodeOABoolProperty' -Default 'yes' `
                -Example 'Example for New-PodeOABoolProperty' -Enum $true, $false , 'yes', 'no' -XmlName 'xTestBool' -Deprecated  -Array  -MinItems 2 -MaxItems 4
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 1
            $result.type | Should -Be 'boolean'
            $result.name | Should -Be 'testBool'
            $result.description | Should -Be 'Test for New-PodeOABoolProperty'
            $result.default | Should -Be 'yes'
            $result.meta['example'] | Should -Be 'Example for New-PodeOABoolProperty'
            $result.enum | Should -Be @('true', 'false' , 'yes', 'no')
            $result.xmlName | Should -Be  'xTestBool'
            $result.deprecated | Should -Be $true
            $result.array | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }
        It 'ArrayNullable' {
            $result = New-PodeOABoolProperty -Name 'testBool' -Description 'Test for New-PodeOABoolProperty' -Default 'yes' `
                -Example 'Example for New-PodeOABoolProperty' -Enum $true, $false , 'yes', 'no' -XmlName 'xTestBool' -Nullable  -Array  -MinItems 2 -MaxItems 4
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 2
            $result.type | Should -Be 'boolean'
            $result.name | Should -Be 'testBool'
            $result.description | Should -Be 'Test for New-PodeOABoolProperty'
            $result.default | Should -Be 'yes'
            $result.meta['example'] | Should -Be 'Example for New-PodeOABoolProperty'
            $result.enum | Should -Be @('true', 'false' , 'yes', 'no')
            $result.xmlName | Should -Be  'xTestBool'
            $result.meta['nullable'] | Should -Be $true
            $result.array | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }
        It 'ArrayWriteOnly' {
            $result = New-PodeOABoolProperty -Name 'testBool' -Description 'Test for New-PodeOABoolProperty' -Default 'yes' `
                -Example 'Example for New-PodeOABoolProperty' -Enum $true, $false , 'yes', 'no' -XmlName 'xTestBool' -WriteOnly  -Array  -MinItems 2 -MaxItems 4
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 2
            $result.type | Should -Be 'boolean'
            $result.name | Should -Be 'testBool'
            $result.description | Should -Be 'Test for New-PodeOABoolProperty'
            $result.default | Should -Be 'yes'
            $result.meta['example'] | Should -Be 'Example for New-PodeOABoolProperty'
            $result.enum | Should -Be @('true', 'false' , 'yes', 'no')
            $result.xmlName | Should -Be  'xTestBool'
            $result.meta['writeOnly'] | Should -Be $true
            $result.array | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }
        It 'ArrayReadOnly' {
            $result = New-PodeOABoolProperty -Name 'testBool' -Description 'Test for New-PodeOABoolProperty' -Default 'yes' `
                -Example 'Example for New-PodeOABoolProperty' -Enum $true, $false , 'yes', 'no' -XmlName 'xTestBool' -ReadOnly  -Array  -MinItems 2 -MaxItems 4
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 2
            $result.type | Should -Be 'boolean'
            $result.name | Should -Be 'testBool'
            $result.description | Should -Be 'Test for New-PodeOABoolProperty'
            $result.default | Should -Be 'yes'
            $result.meta['example'] | Should -Be 'Example for New-PodeOABoolProperty'
            $result.enum | Should -Be @('true', 'false' , 'yes', 'no')
            $result.xmlName | Should -Be  'xTestBool'
            $result.meta['readOnly'] | Should -Be $true
            $result.array | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }
    }


    Context 'New-PodeOAStringProperty' {
        It 'NoSwitches' {
            $result = New-PodeOAStringProperty -Name 'testString' -Description 'Test for New-PodeOAStringProperty' -Format Date -Pattern '^\d{4}-\d{2}-\d{2}$' -Default '2000-01-01' -MinLength 2 -MaxLength 20 `
                -Example 'Example for New-PodeOAStringProperty' -Enum '2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01' -XmlName 'xTestString'
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 4
            $result.type | Should -Be 'string'
            $result.name | Should -Be 'testString'
            $result.description | Should -Be 'Test for New-PodeOAStringProperty'
            $result.format | Should -Be 'Date'
            $result.meta['pattern'] = '^\d{4}-\d{2}-\d{2}$'
            $result.default | Should -Be '2000-01-01'
            $result.meta['minLength'] | Should -Be 2
            $result.meta['maxLength'] | Should -Be 20
            $result.meta['example'] | Should -Be 'Example for New-PodeOAStringProperty'
            $result.enum | Should -Be @('2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01')
            $result.xmlName | Should -Be  'xTestString'
        }
        It 'Object' {
            $result = New-PodeOAStringProperty -Name 'testString' -Description 'Test for New-PodeOAStringProperty' -Format Date -Pattern '^\d{4}-\d{2}-\d{2}$' -Default '2000-01-01' -MinLength 2 -MaxLength 20 `
                -Example 'Example for New-PodeOAStringProperty' -Enum '2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01' -XmlName 'xTestString' -Object
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 4
            $result.type | Should -Be 'string'
            $result.name | Should -Be 'testString'
            $result.description | Should -Be 'Test for New-PodeOAStringProperty'
            $result.format | Should -Be 'Date'
            $result.meta['pattern'] = '^\d{4}-\d{2}-\d{2}$'
            $result.default | Should -Be '2000-01-01'
            $result.meta['minLength'] | Should -Be 2
            $result.meta['maxLength'] | Should -Be 20
            $result.meta['example'] | Should -Be 'Example for New-PodeOAStringProperty'
            $result.enum | Should -Be @('2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01')
            $result.xmlName | Should -Be  'xTestString'
            $result.object | Should -Be $true
        }
        It 'Deprecated' {
            $result = New-PodeOAStringProperty -Name 'testString' -Description 'Test for New-PodeOAStringProperty' -Format Date -Pattern '^\d{4}-\d{2}-\d{2}$' -Default '2000-01-01' -MinLength 2 -MaxLength 20 `
                -Example 'Example for New-PodeOAStringProperty' -Enum '2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01' -XmlName 'xTestString' -Deprecated
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 4
            $result.type | Should -Be 'string'
            $result.name | Should -Be 'testString'
            $result.description | Should -Be 'Test for New-PodeOAStringProperty'
            $result.format | Should -Be 'Date'
            $result.meta['pattern'] = '^\d{4}-\d{2}-\d{2}$'
            $result.default | Should -Be '2000-01-01'
            $result.meta['minLength'] | Should -Be 2
            $result.meta['maxLength'] | Should -Be 20
            $result.meta['example'] | Should -Be 'Example for New-PodeOAStringProperty'
            $result.enum | Should -Be @('2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01')
            $result.xmlName | Should -Be  'xTestString'
            $result.deprecated | Should -Be $true
        }
        It 'Nullable' {
            $result = New-PodeOAStringProperty -Name 'testString' -Description 'Test for New-PodeOAStringProperty' -Format Date -Pattern '^\d{4}-\d{2}-\d{2}$' -Default '2000-01-01' -MinLength 2 -MaxLength 20 `
                -Example 'Example for New-PodeOAStringProperty' -Enum '2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01' -XmlName 'xTestString' -Nullable
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 5
            $result.type | Should -Be 'string'
            $result.name | Should -Be 'testString'
            $result.description | Should -Be 'Test for New-PodeOAStringProperty'
            $result.format | Should -Be 'Date'
            $result.meta['pattern'] = '^\d{4}-\d{2}-\d{2}$'
            $result.default | Should -Be '2000-01-01'
            $result.meta['minLength'] | Should -Be 2
            $result.meta['maxLength'] | Should -Be 20
            $result.meta['example'] | Should -Be 'Example for New-PodeOAStringProperty'
            $result.enum | Should -Be @('2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01')
            $result.xmlName | Should -Be  'xTestString'
            $result.meta['nullable'] | Should -Be $true
        }
        It 'WriteOnly' {
            $result = New-PodeOAStringProperty -Name 'testString' -Description 'Test for New-PodeOAStringProperty' -Format Date -Pattern '^\d{4}-\d{2}-\d{2}$' -Default '2000-01-01' -MinLength 2 -MaxLength 20 `
                -Example 'Example for New-PodeOAStringProperty' -Enum '2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01' -XmlName 'xTestString' -WriteOnly
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 5
            $result.type | Should -Be 'string'
            $result.name | Should -Be 'testString'
            $result.description | Should -Be 'Test for New-PodeOAStringProperty'
            $result.format | Should -Be 'Date'
            $result.meta['pattern'] = '^\d{4}-\d{2}-\d{2}$'
            $result.default | Should -Be '2000-01-01'
            $result.meta['minLength'] | Should -Be 2
            $result.meta['maxLength'] | Should -Be 20
            $result.meta['example'] | Should -Be 'Example for New-PodeOAStringProperty'
            $result.enum | Should -Be @('2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01')
            $result.xmlName | Should -Be  'xTestString'
            $result.meta['writeOnly'] | Should -Be $true
        }
        It 'ReadOnly' {
            $result = New-PodeOAStringProperty -Name 'testString' -Description 'Test for New-PodeOAStringProperty' -Format Date -Pattern '^\d{4}-\d{2}-\d{2}$' -Default '2000-01-01' -MinLength 2 -MaxLength 20 `
                -Example 'Example for New-PodeOAStringProperty' -Enum '2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01' -XmlName 'xTestString' -ReadOnly
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 5
            $result.type | Should -Be 'string'
            $result.name | Should -Be 'testString'
            $result.description | Should -Be 'Test for New-PodeOAStringProperty'
            $result.format | Should -Be 'Date'
            $result.meta['pattern'] = '^\d{4}-\d{2}-\d{2}$'
            $result.default | Should -Be '2000-01-01'
            $result.meta['minLength'] | Should -Be 2
            $result.meta['maxLength'] | Should -Be 20
            $result.meta['example'] | Should -Be 'Example for New-PodeOAStringProperty'
            $result.enum | Should -Be @('2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01')
            $result.xmlName | Should -Be  'xTestString'
            $result.meta['readOnly'] | Should -Be $true
        }

        It 'ArrayNoSwitchesUniqueItems' {
            $result = New-PodeOAStringProperty -Name 'testString' -Description 'Test for New-PodeOAStringProperty' -Format Date -Pattern '^\d{4}-\d{2}-\d{2}$' -Default '2000-01-01' -MinLength 2 -MaxLength 20 `
                -Example 'Example for New-PodeOAStringProperty' -Enum '2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01' -XmlName 'xTestString' -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 4
            $result.type | Should -Be 'string'
            $result.name | Should -Be 'testString'
            $result.description | Should -Be 'Test for New-PodeOAStringProperty'
            $result.format | Should -Be 'Date'
            $result.meta['pattern'] = '^\d{4}-\d{2}-\d{2}$'
            $result.default | Should -Be '2000-01-01'
            $result.meta['minLength'] | Should -Be 2
            $result.meta['maxLength'] | Should -Be 20
            $result.meta['example'] | Should -Be 'Example for New-PodeOAStringProperty'
            $result.enum | Should -Be @('2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01')
            $result.xmlName | Should -Be  'xTestString'
            $result.array | Should -BeTrue
            $result.uniqueItems | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue

        }
        It 'ArrayDeprecatedUniqueItems' {
            $result = New-PodeOAStringProperty -Name 'testString' -Description 'Test for New-PodeOAStringProperty' -Format Date -Pattern '^\d{4}-\d{2}-\d{2}$' -Default '2000-01-01' -MinLength 2 -MaxLength 20 `
                -Example 'Example for New-PodeOAStringProperty' -Enum '2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01' -XmlName 'xTestString' -Deprecated  -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 4
            $result.type | Should -Be 'string'
            $result.name | Should -Be 'testString'
            $result.description | Should -Be 'Test for New-PodeOAStringProperty'
            $result.format | Should -Be 'Date'
            $result.meta['pattern'] = '^\d{4}-\d{2}-\d{2}$'
            $result.default | Should -Be '2000-01-01'
            $result.meta['minLength'] | Should -Be 2
            $result.meta['maxLength'] | Should -Be 20
            $result.meta['example'] | Should -Be 'Example for New-PodeOAStringProperty'
            $result.enum | Should -Be @('2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01')
            $result.xmlName | Should -Be  'xTestString'
            $result.deprecated | Should -Be $true
            $result.array | Should -BeTrue
            $result.uniqueItems | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }
        It 'ArrayNullableUniqueItems' {
            $result = New-PodeOAStringProperty -Name 'testString' -Description 'Test for New-PodeOAStringProperty' -Format Date -Pattern '^\d{4}-\d{2}-\d{2}$' -Default '2000-01-01' -MinLength 2 -MaxLength 20 `
                -Example 'Example for New-PodeOAStringProperty' -Enum '2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01' -XmlName 'xTestString' -Nullable  -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 5
            $result.type | Should -Be 'string'
            $result.name | Should -Be 'testString'
            $result.description | Should -Be 'Test for New-PodeOAStringProperty'
            $result.format | Should -Be 'Date'
            $result.meta['pattern'] = '^\d{4}-\d{2}-\d{2}$'
            $result.default | Should -Be '2000-01-01'
            $result.meta['minLength'] | Should -Be 2
            $result.meta['maxLength'] | Should -Be 20
            $result.meta['example'] | Should -Be 'Example for New-PodeOAStringProperty'
            $result.enum | Should -Be @('2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01')
            $result.xmlName | Should -Be  'xTestString'
            $result.meta['nullable'] | Should -Be $true
            $result.array | Should -BeTrue
            $result.uniqueItems | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }
        It 'ArrayWriteOnlyUniqueItems' {
            $result = New-PodeOAStringProperty -Name 'testString' -Description 'Test for New-PodeOAStringProperty' -Format Date -Pattern '^\d{4}-\d{2}-\d{2}$' -Default '2000-01-01' -MinLength 2 -MaxLength 20 `
                -Example 'Example for New-PodeOAStringProperty' -Enum '2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01' -XmlName 'xTestString' -WriteOnly  -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 5
            $result.type | Should -Be 'string'
            $result.name | Should -Be 'testString'
            $result.description | Should -Be 'Test for New-PodeOAStringProperty'
            $result.format | Should -Be 'Date'
            $result.meta['pattern'] = '^\d{4}-\d{2}-\d{2}$'
            $result.default | Should -Be '2000-01-01'
            $result.meta['minLength'] | Should -Be 2
            $result.meta['maxLength'] | Should -Be 20
            $result.meta['example'] | Should -Be 'Example for New-PodeOAStringProperty'
            $result.enum | Should -Be @('2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01')
            $result.xmlName | Should -Be  'xTestString'
            $result.meta['writeOnly'] | Should -Be $true
            $result.array | Should -BeTrue
            $result.uniqueItems | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }
        It 'ArrayReadOnlyUniqueItems' {
            $result = New-PodeOAStringProperty -Name 'testString' -Description 'Test for New-PodeOAStringProperty' -Format Date -Pattern '^\d{4}-\d{2}-\d{2}$' -Default '2000-01-01' -MinLength 2 -MaxLength 20 `
                -Example 'Example for New-PodeOAStringProperty' -Enum '2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01' -XmlName 'xTestString' -ReadOnly  -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 5
            $result.type | Should -Be 'string'
            $result.name | Should -Be 'testString'
            $result.description | Should -Be 'Test for New-PodeOAStringProperty'
            $result.format | Should -Be 'Date'
            $result.meta['pattern'] = '^\d{4}-\d{2}-\d{2}$'
            $result.default | Should -Be '2000-01-01'
            $result.meta['minLength'] | Should -Be 2
            $result.meta['maxLength'] | Should -Be 20
            $result.meta['example'] | Should -Be 'Example for New-PodeOAStringProperty'
            $result.enum | Should -Be @('2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01')
            $result.xmlName | Should -Be  'xTestString'
            $result.meta['readOnly'] | Should -Be $true
            $result.array | Should -BeTrue
            $result.uniqueItems | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }

        It 'ArrayNoSwitches' {
            $result = New-PodeOAStringProperty -Name 'testString' -Description 'Test for New-PodeOAStringProperty' -Format Date -Pattern '^\d{4}-\d{2}-\d{2}$' -Default '2000-01-01' -MinLength 2 -MaxLength 20 `
                -Example 'Example for New-PodeOAStringProperty' -Enum '2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01' -XmlName 'xTestString' -Array  -MinItems 2 -MaxItems 4
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 4
            $result.type | Should -Be 'string'
            $result.name | Should -Be 'testString'
            $result.description | Should -Be 'Test for New-PodeOAStringProperty'
            $result.format | Should -Be 'Date'
            $result.meta['pattern'] = '^\d{4}-\d{2}-\d{2}$'
            $result.default | Should -Be '2000-01-01'
            $result.meta['minLength'] | Should -Be 2
            $result.meta['maxLength'] | Should -Be 20
            $result.meta['example'] | Should -Be 'Example for New-PodeOAStringProperty'
            $result.enum | Should -Be @('2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01')
            $result.xmlName | Should -Be  'xTestString'
            $result.array | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue

        }
        It 'ArrayDeprecated' {
            $result = New-PodeOAStringProperty -Name 'testString' -Description 'Test for New-PodeOAStringProperty' -Format Date -Pattern '^\d{4}-\d{2}-\d{2}$' -Default '2000-01-01' -MinLength 2 -MaxLength 20 `
                -Example 'Example for New-PodeOAStringProperty' -Enum '2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01' -XmlName 'xTestString' -Deprecated  -Array  -MinItems 2 -MaxItems 4
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 4
            $result.type | Should -Be 'string'
            $result.name | Should -Be 'testString'
            $result.description | Should -Be 'Test for New-PodeOAStringProperty'
            $result.format | Should -Be 'Date'
            $result.meta['pattern'] = '^\d{4}-\d{2}-\d{2}$'
            $result.default | Should -Be '2000-01-01'
            $result.meta['minLength'] | Should -Be 2
            $result.meta['maxLength'] | Should -Be 20
            $result.meta['example'] | Should -Be 'Example for New-PodeOAStringProperty'
            $result.enum | Should -Be @('2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01')
            $result.xmlName | Should -Be  'xTestString'
            $result.deprecated | Should -Be $true
            $result.array | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }
        It 'ArrayNullable' {
            $result = New-PodeOAStringProperty -Name 'testString' -Description 'Test for New-PodeOAStringProperty' -Format Date -Pattern '^\d{4}-\d{2}-\d{2}$' -Default '2000-01-01' -MinLength 2 -MaxLength 20 `
                -Example 'Example for New-PodeOAStringProperty' -Enum '2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01' -XmlName 'xTestString' -Nullable  -Array  -MinItems 2 -MaxItems 4
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 5
            $result.type | Should -Be 'string'
            $result.name | Should -Be 'testString'
            $result.description | Should -Be 'Test for New-PodeOAStringProperty'
            $result.format | Should -Be 'Date'
            $result.meta['pattern'] = '^\d{4}-\d{2}-\d{2}$'
            $result.default | Should -Be '2000-01-01'
            $result.meta['minLength'] | Should -Be 2
            $result.meta['maxLength'] | Should -Be 20
            $result.meta['example'] | Should -Be 'Example for New-PodeOAStringProperty'
            $result.enum | Should -Be @('2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01')
            $result.xmlName | Should -Be  'xTestString'
            $result.meta['nullable'] | Should -Be $true
            $result.array | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }
        It 'ArrayWriteOnly' {
            $result = New-PodeOAStringProperty -Name 'testString' -Description 'Test for New-PodeOAStringProperty' -Format Date -Pattern '^\d{4}-\d{2}-\d{2}$' -Default '2000-01-01' -MinLength 2 -MaxLength 20 `
                -Example 'Example for New-PodeOAStringProperty' -Enum '2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01' -XmlName 'xTestString' -WriteOnly  -Array  -MinItems 2 -MaxItems 4
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 5
            $result.type | Should -Be 'string'
            $result.name | Should -Be 'testString'
            $result.description | Should -Be 'Test for New-PodeOAStringProperty'
            $result.format | Should -Be 'Date'
            $result.meta['pattern'] = '^\d{4}-\d{2}-\d{2}$'
            $result.default | Should -Be '2000-01-01'
            $result.meta['minLength'] | Should -Be 2
            $result.meta['maxLength'] | Should -Be 20
            $result.meta['example'] | Should -Be 'Example for New-PodeOAStringProperty'
            $result.enum | Should -Be @('2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01')
            $result.xmlName | Should -Be  'xTestString'
            $result.meta['writeOnly'] | Should -Be $true
            $result.array | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }
        It 'ArrayReadOnly' {
            $result = New-PodeOAStringProperty -Name 'testString' -Description 'Test for New-PodeOAStringProperty' -Format Date -Pattern '^\d{4}-\d{2}-\d{2}$' -Default '2000-01-01' -MinLength 2 -MaxLength 20 `
                -Example 'Example for New-PodeOAStringProperty' -Enum '2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01' -XmlName 'xTestString' -ReadOnly  -Array  -MinItems 2 -MaxItems 4
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 5
            $result.type | Should -Be 'string'
            $result.name | Should -Be 'testString'
            $result.description | Should -Be 'Test for New-PodeOAStringProperty'
            $result.format | Should -Be 'Date'
            $result.meta['pattern'] = '^\d{4}-\d{2}-\d{2}$'
            $result.default | Should -Be '2000-01-01'
            $result.meta['minLength'] | Should -Be 2
            $result.meta['maxLength'] | Should -Be 20
            $result.meta['example'] | Should -Be 'Example for New-PodeOAStringProperty'
            $result.enum | Should -Be @('2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01')
            $result.xmlName | Should -Be  'xTestString'
            $result.meta['readOnly'] | Should -Be $true
            $result.array | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }
    }

    Context 'New-PodeOAObjectProperty' {
        It 'NoSwitches' {
            $result = New-PodeOAObjectProperty -Name 'testObject' -Description 'Test for New-PodeOAObjectProperty'  -MinProperties 1 -MaxProperties 2 `
                -Example 'Example for New-PodeOAObjectProperty' -Properties @((New-PodeOAIntProperty -Name 'id'), (New-PodeOAStringProperty -Name 'name')) -XmlName 'xTestObject'
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 1
            $result.type | Should -Be 'object'
            $result.name | Should -Be 'testObject'
            $result.description | Should -Be 'Test for New-PodeOAObjectProperty'
            $result.properties[0].meta | Should -BeNullOrEmpty
            $result.properties[0].type | Should -Be 'integer'
            $result.properties[0].name | Should -Be 'id'
            $result.properties[1].meta | Should -BeNullOrEmpty
            $result.properties[1].type | Should -Be 'string'
            $result.properties[1].name | Should -Be 'name'
            $result.minProperties | Should -Be 1
            $result.maxProperties | Should -Be 2
            $result.meta['example'] | Should -Be 'Example for New-PodeOAObjectProperty'
            $result.xmlName | Should -Be  'xTestObject'
        }
        It 'Deprecated' {
            $result = New-PodeOAObjectProperty -Name 'testObject' -Description 'Test for New-PodeOAObjectProperty'  -MinProperties 1 -MaxProperties 2 `
                -Example 'Example for New-PodeOAObjectProperty' -Properties @((New-PodeOAIntProperty -Name 'id'), (New-PodeOAStringProperty -Name 'name')) -XmlName 'xTestObject' -Deprecated
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 1
            $result.type | Should -Be 'object'
            $result.name | Should -Be 'testObject'
            $result.description | Should -Be 'Test for New-PodeOAObjectProperty'
            $result.properties.Count | Should -Be 2
            $result.properties[0].meta | Should -BeNullOrEmpty
            $result.properties[0].type | Should -Be 'integer'
            $result.properties[0].name | Should -Be 'id'
            $result.properties[1].meta | Should -BeNullOrEmpty
            $result.properties[1].type | Should -Be 'string'
            $result.properties[1].name | Should -Be 'name'
            $result.minProperties | Should -Be 1
            $result.maxProperties | Should -Be 2
            $result.meta['example'] | Should -Be 'Example for New-PodeOAObjectProperty'
            $result.xmlName | Should -Be  'xTestObject'
            $result.deprecated | Should -Be $true
        }
        It 'Nullable' {
            $result = New-PodeOAObjectProperty -Name 'testObject' -Description 'Test for New-PodeOAObjectProperty'  -MinProperties 1 -MaxProperties 2 `
                -Example 'Example for New-PodeOAObjectProperty' -Properties @((New-PodeOAIntProperty -Name 'id'), (New-PodeOAStringProperty -Name 'name')) -XmlName 'xTestObject' -Nullable
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 2
            $result.type | Should -Be 'object'
            $result.name | Should -Be 'testObject'
            $result.description | Should -Be 'Test for New-PodeOAObjectProperty'
            $result.properties.Count | Should -Be 2
            $result.properties[0].meta | Should -BeNullOrEmpty
            $result.properties[0].type | Should -Be 'integer'
            $result.properties[0].name | Should -Be 'id'
            $result.properties[1].meta | Should -BeNullOrEmpty
            $result.properties[1].type | Should -Be 'string'
            $result.properties[1].name | Should -Be 'name'
            $result.minProperties | Should -Be 1
            $result.maxProperties | Should -Be 2
            $result.meta['example'] | Should -Be 'Example for New-PodeOAObjectProperty'
            $result.xmlName | Should -Be  'xTestObject'
            $result.meta['nullable'] | Should -Be $true
        }
        It 'WriteOnly' {
            $result = New-PodeOAObjectProperty -Name 'testObject' -Description 'Test for New-PodeOAObjectProperty'  -MinProperties 1 -MaxProperties 2 `
                -Example 'Example for New-PodeOAObjectProperty' -Properties @((New-PodeOAIntProperty -Name 'id'), (New-PodeOAStringProperty -Name 'name')) -XmlName 'xTestObject' -WriteOnly
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 2
            $result.type | Should -Be 'object'
            $result.name | Should -Be 'testObject'
            $result.description | Should -Be 'Test for New-PodeOAObjectProperty'
            $result.properties.Count | Should -Be 2
            $result.properties[0].meta | Should -BeNullOrEmpty
            $result.properties[0].type | Should -Be 'integer'
            $result.properties[0].name | Should -Be 'id'
            $result.properties[1].meta | Should -BeNullOrEmpty
            $result.properties[1].type | Should -Be 'string'
            $result.properties[1].name | Should -Be 'name'
            $result.minProperties | Should -Be 1
            $result.maxProperties | Should -Be 2
            $result.meta['example'] | Should -Be 'Example for New-PodeOAObjectProperty'
            $result.xmlName | Should -Be  'xTestObject'
            $result.meta['writeOnly'] | Should -Be $true
        }
        It 'ReadOnly' {
            $result = New-PodeOAObjectProperty -Name 'testObject' -Description 'Test for New-PodeOAObjectProperty'  -MinProperties 1 -MaxProperties 2 `
                -Example 'Example for New-PodeOAObjectProperty' -Properties @((New-PodeOAIntProperty -Name 'id'), (New-PodeOAStringProperty -Name 'name')) -XmlName 'xTestObject' -ReadOnly
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 2
            $result.type | Should -Be 'object'
            $result.name | Should -Be 'testObject'
            $result.description | Should -Be 'Test for New-PodeOAObjectProperty'
            $result.properties.Count | Should -Be 2
            $result.properties[0].meta | Should -BeNullOrEmpty
            $result.properties[0].type | Should -Be 'integer'
            $result.properties[0].name | Should -Be 'id'
            $result.properties[1].meta | Should -BeNullOrEmpty
            $result.properties[1].type | Should -Be 'string'
            $result.properties[1].name | Should -Be 'name'
            $result.minProperties | Should -Be 1
            $result.maxProperties | Should -Be 2
            $result.meta['example'] | Should -Be 'Example for New-PodeOAObjectProperty'
            $result.xmlName | Should -Be  'xTestObject'
            $result.meta['readOnly'] | Should -Be $true
        }

        It 'ArrayNoSwitchesUniqueItems' {
            $result = New-PodeOAObjectProperty -Name 'testObject' -Description 'Test for New-PodeOAObjectProperty'  -MinProperties 1 -MaxProperties 2 `
                -Example 'Example for New-PodeOAObjectProperty' -Properties @((New-PodeOAIntProperty -Name 'id'), (New-PodeOAStringProperty -Name 'name')) -XmlName 'xTestObject' -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 1
            $result.type | Should -Be 'object'
            $result.name | Should -Be 'testObject'
            $result.description | Should -Be 'Test for New-PodeOAObjectProperty'
            $result.properties.Count | Should -Be 2
            $result.properties[0].meta | Should -BeNullOrEmpty
            $result.properties[0].type | Should -Be 'integer'
            $result.properties[0].name | Should -Be 'id'
            $result.properties[1].meta | Should -BeNullOrEmpty
            $result.properties[1].type | Should -Be 'string'
            $result.properties[1].name | Should -Be 'name'
            $result.minProperties | Should -Be 1
            $result.maxProperties | Should -Be 2
            $result.meta['example'] | Should -Be 'Example for New-PodeOAObjectProperty'
            $result.xmlName | Should -Be  'xTestObject'
            $result.array | Should -BeTrue
            $result.uniqueItems | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue

        }
        It 'ArrayDeprecatedUniqueItems' {
            $result = New-PodeOAObjectProperty -Name 'testObject' -Description 'Test for New-PodeOAObjectProperty'  -MinProperties 1 -MaxProperties 2 `
                -Example 'Example for New-PodeOAObjectProperty' -Properties @((New-PodeOAIntProperty -Name 'id'), (New-PodeOAStringProperty -Name 'name')) -XmlName 'xTestObject' -Deprecated  -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 1
            $result.type | Should -Be 'object'
            $result.name | Should -Be 'testObject'
            $result.description | Should -Be 'Test for New-PodeOAObjectProperty'
            $result.properties.Count | Should -Be 2
            $result.properties[0].meta | Should -BeNullOrEmpty
            $result.properties[0].type | Should -Be 'integer'
            $result.properties[0].name | Should -Be 'id'
            $result.properties[1].meta | Should -BeNullOrEmpty
            $result.properties[1].type | Should -Be 'string'
            $result.properties[1].name | Should -Be 'name'
            $result.minProperties | Should -Be 1
            $result.maxProperties | Should -Be 2
            $result.meta['example'] | Should -Be 'Example for New-PodeOAObjectProperty'
            $result.xmlName | Should -Be  'xTestObject'
            $result.deprecated | Should -Be $true
            $result.array | Should -BeTrue
            $result.uniqueItems | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }
        It 'ArrayNullableUniqueItems' {
            $result = New-PodeOAObjectProperty -Name 'testObject' -Description 'Test for New-PodeOAObjectProperty'  -MinProperties 1 -MaxProperties 2 `
                -Example 'Example for New-PodeOAObjectProperty' -Properties @((New-PodeOAIntProperty -Name 'id'), (New-PodeOAStringProperty -Name 'name')) -XmlName 'xTestObject' -Nullable  -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 2
            $result.type | Should -Be 'object'
            $result.name | Should -Be 'testObject'
            $result.description | Should -Be 'Test for New-PodeOAObjectProperty'
            $result.properties.Count | Should -Be 2
            $result.properties[0].meta | Should -BeNullOrEmpty
            $result.properties[0].type | Should -Be 'integer'
            $result.properties[0].name | Should -Be 'id'
            $result.properties[1].meta | Should -BeNullOrEmpty
            $result.properties[1].type | Should -Be 'string'
            $result.properties[1].name | Should -Be 'name'
            $result.minProperties | Should -Be 1
            $result.maxProperties | Should -Be 2
            $result.meta['example'] | Should -Be 'Example for New-PodeOAObjectProperty'
            $result.xmlName | Should -Be  'xTestObject'
            $result.meta['nullable'] | Should -Be $true
            $result.array | Should -BeTrue
            $result.uniqueItems | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }
        It 'ArrayWriteOnlyUniqueItems' {
            $result = New-PodeOAObjectProperty -Name 'testObject' -Description 'Test for New-PodeOAObjectProperty'  -MinProperties 1 -MaxProperties 2 `
                -Example 'Example for New-PodeOAObjectProperty' -Properties @((New-PodeOAIntProperty -Name 'id'), (New-PodeOAStringProperty -Name 'name')) -XmlName 'xTestObject' -WriteOnly  -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 2
            $result.type | Should -Be 'object'
            $result.name | Should -Be 'testObject'
            $result.description | Should -Be 'Test for New-PodeOAObjectProperty'
            $result.properties.Count | Should -Be 2
            $result.properties[0].meta | Should -BeNullOrEmpty
            $result.properties[0].type | Should -Be 'integer'
            $result.properties[0].name | Should -Be 'id'
            $result.properties[1].meta | Should -BeNullOrEmpty
            $result.properties[1].type | Should -Be 'string'
            $result.properties[1].name | Should -Be 'name'
            $result.minProperties | Should -Be 1
            $result.maxProperties | Should -Be 2
            $result.meta['example'] | Should -Be 'Example for New-PodeOAObjectProperty'
            $result.xmlName | Should -Be  'xTestObject'
            $result.meta['writeOnly'] | Should -Be $true
            $result.array | Should -BeTrue
            $result.uniqueItems | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }
        It 'ArrayReadOnlyUniqueItems' {
            $result = New-PodeOAObjectProperty -Name 'testObject' -Description 'Test for New-PodeOAObjectProperty'  -MinProperties 1 -MaxProperties 2 `
                -Example 'Example for New-PodeOAObjectProperty' -Properties @((New-PodeOAIntProperty -Name 'id'), (New-PodeOAStringProperty -Name 'name')) -XmlName 'xTestObject' -ReadOnly  -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 2
            $result.type | Should -Be 'object'
            $result.name | Should -Be 'testObject'
            $result.description | Should -Be 'Test for New-PodeOAObjectProperty'
            $result.properties.Count | Should -Be 2
            $result.properties[0].meta | Should -BeNullOrEmpty
            $result.properties[0].type | Should -Be 'integer'
            $result.properties[0].name | Should -Be 'id'
            $result.properties[1].meta | Should -BeNullOrEmpty
            $result.properties[1].type | Should -Be 'string'
            $result.properties[1].name | Should -Be 'name'
            $result.minProperties | Should -Be 1
            $result.maxProperties | Should -Be 2
            $result.meta['example'] | Should -Be 'Example for New-PodeOAObjectProperty'
            $result.xmlName | Should -Be  'xTestObject'
            $result.meta['readOnly'] | Should -Be $true
            $result.array | Should -BeTrue
            $result.uniqueItems | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }

        It 'ArrayNoSwitches' {
            $result = New-PodeOAObjectProperty -Name 'testObject' -Description 'Test for New-PodeOAObjectProperty'  -MinProperties 1 -MaxProperties 2 `
                -Example 'Example for New-PodeOAObjectProperty' -Properties @((New-PodeOAIntProperty -Name 'id'), (New-PodeOAStringProperty -Name 'name')) -XmlName 'xTestObject' -Array  -MinItems 2 -MaxItems 4
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 1
            $result.type | Should -Be 'object'
            $result.name | Should -Be 'testObject'
            $result.description | Should -Be 'Test for New-PodeOAObjectProperty'
            $result.properties.Count | Should -Be 2
            $result.properties[0].meta | Should -BeNullOrEmpty
            $result.properties[0].type | Should -Be 'integer'
            $result.properties[0].name | Should -Be 'id'
            $result.properties[1].meta | Should -BeNullOrEmpty
            $result.properties[1].type | Should -Be 'string'
            $result.properties[1].name | Should -Be 'name'
            $result.minProperties | Should -Be 1
            $result.maxProperties | Should -Be 2
            $result.meta['example'] | Should -Be 'Example for New-PodeOAObjectProperty'
            $result.xmlName | Should -Be  'xTestObject'
            $result.array | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue

        }
        It 'ArrayDeprecated' {
            $result = New-PodeOAObjectProperty -Name 'testObject' -Description 'Test for New-PodeOAObjectProperty'  -MinProperties 1 -MaxProperties 2 `
                -Example 'Example for New-PodeOAObjectProperty' -Properties @((New-PodeOAIntProperty -Name 'id'), (New-PodeOAStringProperty -Name 'name')) -XmlName 'xTestObject' -Deprecated  -Array  -MinItems 2 -MaxItems 4
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 1
            $result.type | Should -Be 'object'
            $result.name | Should -Be 'testObject'
            $result.description | Should -Be 'Test for New-PodeOAObjectProperty'
            $result.properties.Count | Should -Be 2
            $result.properties[0].meta | Should -BeNullOrEmpty
            $result.properties[0].type | Should -Be 'integer'
            $result.properties[0].name | Should -Be 'id'
            $result.properties[1].meta | Should -BeNullOrEmpty
            $result.properties[1].type | Should -Be 'string'
            $result.properties[1].name | Should -Be 'name'
            $result.minProperties | Should -Be 1
            $result.maxProperties | Should -Be 2
            $result.meta['example'] | Should -Be 'Example for New-PodeOAObjectProperty'
            $result.xmlName | Should -Be  'xTestObject'
            $result.deprecated | Should -Be $true
            $result.array | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }
        It 'ArrayNullable' {
            $result = New-PodeOAObjectProperty -Name 'testObject' -Description 'Test for New-PodeOAObjectProperty'  -MinProperties 1 -MaxProperties 2 `
                -Example 'Example for New-PodeOAObjectProperty' -Properties @((New-PodeOAIntProperty -Name 'id'), (New-PodeOAStringProperty -Name 'name')) -XmlName 'xTestObject' -Nullable  -Array  -MinItems 2 -MaxItems 4
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 2
            $result.type | Should -Be 'object'
            $result.name | Should -Be 'testObject'
            $result.description | Should -Be 'Test for New-PodeOAObjectProperty'
            $result.properties.Count | Should -Be 2
            $result.properties[0].meta | Should -BeNullOrEmpty
            $result.properties[0].type | Should -Be 'integer'
            $result.properties[0].name | Should -Be 'id'
            $result.properties[1].meta | Should -BeNullOrEmpty
            $result.properties[1].type | Should -Be 'string'
            $result.properties[1].name | Should -Be 'name'
            $result.minProperties | Should -Be 1
            $result.maxProperties | Should -Be 2
            $result.meta['example'] | Should -Be 'Example for New-PodeOAObjectProperty'
            $result.xmlName | Should -Be  'xTestObject'
            $result.meta['nullable'] | Should -Be $true
            $result.array | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }
        It 'ArrayWriteOnly' {
            $result = New-PodeOAObjectProperty -Name 'testObject' -Description 'Test for New-PodeOAObjectProperty'  -MinProperties 1 -MaxProperties 2 `
                -Example 'Example for New-PodeOAObjectProperty' -Properties @((New-PodeOAIntProperty -Name 'id'), (New-PodeOAStringProperty -Name 'name')) -XmlName 'xTestObject' -WriteOnly  -Array  -MinItems 2 -MaxItems 4
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 2
            $result.type | Should -Be 'object'
            $result.name | Should -Be 'testObject'
            $result.description | Should -Be 'Test for New-PodeOAObjectProperty'
            $result.properties.Count | Should -Be 2
            $result.properties[0].meta | Should -BeNullOrEmpty
            $result.properties[0].type | Should -Be 'integer'
            $result.properties[0].name | Should -Be 'id'
            $result.properties[1].meta | Should -BeNullOrEmpty
            $result.properties[1].type | Should -Be 'string'
            $result.properties[1].name | Should -Be 'name'
            $result.minProperties | Should -Be 1
            $result.maxProperties | Should -Be 2
            $result.meta['example'] | Should -Be 'Example for New-PodeOAObjectProperty'
            $result.xmlName | Should -Be  'xTestObject'
            $result.meta['writeOnly'] | Should -Be $true
            $result.array | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }
        It 'ArrayReadOnly' {
            $result = New-PodeOAObjectProperty -Name 'testObject' -Description 'Test for New-PodeOAObjectProperty'  -MinProperties 1 -MaxProperties 2 `
                -Example 'Example for New-PodeOAObjectProperty' -Properties @((New-PodeOAIntProperty -Name 'id'), (New-PodeOAStringProperty -Name 'name')) -XmlName 'xTestObject' -ReadOnly  -Array  -MinItems 2 -MaxItems 4
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 2
            $result.type | Should -Be 'object'
            $result.name | Should -Be 'testObject'
            $result.description | Should -Be 'Test for New-PodeOAObjectProperty'
            $result.properties.Count | Should -Be 2
            $result.properties[0].meta | Should -BeNullOrEmpty
            $result.properties[0].type | Should -Be 'integer'
            $result.properties[0].name | Should -Be 'id'
            $result.properties[1].meta | Should -BeNullOrEmpty
            $result.properties[1].type | Should -Be 'string'
            $result.properties[1].name | Should -Be 'name'
            $result.minProperties | Should -Be 1
            $result.maxProperties | Should -Be 2
            $result.meta['example'] | Should -Be 'Example for New-PodeOAObjectProperty'
            $result.xmlName | Should -Be  'xTestObject'
            $result.meta['readOnly'] | Should -Be $true
            $result.array | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }
    }

    Context 'Add-PodeOAComponentSchema' {
        It 'Standard' {
            Add-PodeOAComponentSchema -Name 'Category' -Schema (
                New-PodeOAObjectProperty -Name 'Category' -Xml @{'name' = 'category' } -Properties  (
                    New-PodeOAIntProperty -Name 'id'-Format Int64 -Example 1 |
                        New-PodeOAStringProperty -Name 'name' -Example 'Dogs'
                ))

            $PodeContext.Server.OpenAPI.components.schemas['Category'] | Should -Not -BeNullOrEmpty
            $result = $PodeContext.Server.OpenAPI.components.schemas['Category']
            $result | Should -Not -BeNullOrEmpty
            $result | Should -BeOfType [ordered]
            $result.Count | Should -Be 3
            $result.type | Should -Be 'object'
            $result.xml | Should -Not -BeNullOrEmpty
            $result.xml | Should -BeOfType [hashtable]
            $result.xml.Count | Should -Be 1
            $result.properties | Should -Not -BeNullOrEmpty
            $result.properties | Should -BeOfType [hashtable]
            $result.properties.Count | Should -Be 2
            $result.properties.name | Should -Not -BeNullOrEmpty
            $result.properties.name | Should -BeOfType [ordered]
            $result.properties.name.Count | Should -Be 2
            $result.properties.name.type | Should -Be 'string'
            $result.properties.name.example | Should -Be 'Dogs'
            $result.properties.id | Should -Not -BeNullOrEmpty
            $result.properties.id | Should -BeOfType [ordered]
            $result.properties.id.Count | Should -Be 3
            $result.properties.id.type | Should -Be 'integer'
            $result.properties.id.example | Should -Be 1
            $result.properties.id.format | Should -Be 'Int64'
        }
        It 'Pipeline' {
            New-PodeOAIntProperty -Name 'id'-Format Int64 -Example 1 |
                New-PodeOAStringProperty -Name 'name' -Example 'Dogs' |
                New-PodeOAObjectProperty -Name 'Category' -Xml @{'name' = 'category' } |
                Add-PodeOAComponentSchema -Name 'Category'
            $PodeContext.Server.OpenAPI.components.schemas['Category'] | Should -Not -BeNullOrEmpty
            $result = $PodeContext.Server.OpenAPI.components.schemas['Category']
            $result | Should -Not -BeNullOrEmpty
            $result | Should -BeOfType [ordered]
            $result.Count | Should -Be 3
            $result.type | Should -Be 'object'
            $result.xml | Should -Not -BeNullOrEmpty
            $result.xml | Should -BeOfType [hashtable]
            $result.xml.Count | Should -Be 1
            $result.properties | Should -Not -BeNullOrEmpty
            $result.properties | Should -BeOfType [hashtable]
            $result.properties.Count | Should -Be 2
            $result.properties.name | Should -Not -BeNullOrEmpty
            $result.properties.name | Should -BeOfType [ordered]
            $result.properties.name.Count | Should -Be 2
            $result.properties.name.type | Should -Be 'string'
            $result.properties.name.example | Should -Be 'Dogs'
            $result.properties.id | Should -Not -BeNullOrEmpty
            $result.properties.id | Should -BeOfType [ordered]
            $result.properties.id.Count | Should -Be 3
            $result.properties.id.type | Should -Be 'integer'
            $result.properties.id.example | Should -Be 1
            $result.properties.id.format | Should -Be 'Int64'
        }

    }


    Context 'New-PodeOASchemaProperty' {
        BeforeEach {
            Add-PodeOAComponentSchema -Name 'Cat' -Schema (
                New-PodeOAObjectProperty  -Properties  @(
                (New-PodeOABoolProperty -Name 'friendly'),
                    (New-PodeOAStringProperty -Name 'name')
                ))
        }
        It 'Standard' {
            $result = New-PodeOASchemaProperty -Name 'testSchema' -ComponentSchema 'Cat'
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 0
            $result.type | Should -Be 'schema'
            $result.name | Should -Be 'testSchema'
            $result.schema | Should -Be 'Cat'
        }

        It 'ArrayNoSwitchesUniqueItems' {
            $result = New-PodeOASchemaProperty -Name 'testSchema' -Description 'Test for New-PodeOASchemaProperty'  -ComponentSchema 'Cat' -MinProperties 1 -MaxProperties 2 `
                -Example 'Example for New-PodeOASchemaProperty'   -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 1
            $result.type | Should -Be 'schema'
            $result.name | Should -Be 'testSchema'
            $result.schema | Should -Be 'Cat'
            $result.description | Should -Be 'Test for New-PodeOASchemaProperty'
            $result.minProperties | Should -Be 1
            $result.maxProperties | Should -Be 2
            $result.meta['example'] | Should -Be 'Example for New-PodeOASchemaProperty'
            $result.array | Should -BeTrue
            $result.uniqueItems | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue

        }
        It 'ArrayDeprecatedUniqueItems' {
            $result = New-PodeOASchemaProperty -Name 'testSchema' -Description 'Test for New-PodeOASchemaProperty'  -ComponentSchema 'Cat' -MinProperties 1 -MaxProperties 2 `
                -Example 'Example for New-PodeOASchemaProperty'   -Deprecated  -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 1
            $result.type | Should -Be 'schema'
            $result.name | Should -Be 'testSchema'
            $result.schema | Should -Be 'Cat'
            $result.description | Should -Be 'Test for New-PodeOASchemaProperty'
            $result.minProperties | Should -Be 1
            $result.maxProperties | Should -Be 2
            $result.meta['example'] | Should -Be 'Example for New-PodeOASchemaProperty'
            $result.deprecated | Should -Be $true
            $result.array | Should -BeTrue
            $result.uniqueItems | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }
        It 'ArrayNullableUniqueItems' {
            $result = New-PodeOASchemaProperty -Name 'testSchema' -Description 'Test for New-PodeOASchemaProperty'  -ComponentSchema 'Cat' -MinProperties 1 -MaxProperties 2 `
                -Example 'Example for New-PodeOASchemaProperty'   -Nullable  -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 2
            $result.type | Should -Be 'schema'
            $result.name | Should -Be 'testSchema'
            $result.schema | Should -Be 'Cat'
            $result.description | Should -Be 'Test for New-PodeOASchemaProperty'
            $result.minProperties | Should -Be 1
            $result.maxProperties | Should -Be 2
            $result.meta['example'] | Should -Be 'Example for New-PodeOASchemaProperty'
            $result.meta['nullable'] | Should -Be $true
            $result.array | Should -BeTrue
            $result.uniqueItems | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }
        It 'ArrayWriteOnlyUniqueItems' {
            $result = New-PodeOASchemaProperty -Name 'testSchema' -Description 'Test for New-PodeOASchemaProperty'  -ComponentSchema 'Cat' -MinProperties 1 -MaxProperties 2 `
                -Example 'Example for New-PodeOASchemaProperty'   -WriteOnly  -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 2
            $result.type | Should -Be 'schema'
            $result.name | Should -Be 'testSchema'
            $result.schema | Should -Be 'Cat'
            $result.description | Should -Be 'Test for New-PodeOASchemaProperty'
            $result.minProperties | Should -Be 1
            $result.maxProperties | Should -Be 2
            $result.meta['example'] | Should -Be 'Example for New-PodeOASchemaProperty'
            $result.meta['writeOnly'] | Should -Be $true
            $result.array | Should -BeTrue
            $result.uniqueItems | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }
        It 'ArrayReadOnlyUniqueItems' {
            $result = New-PodeOASchemaProperty -Name 'testSchema' -Description 'Test for New-PodeOASchemaProperty'  -ComponentSchema 'Cat' -MinProperties 1 -MaxProperties 2 `
                -Example 'Example for New-PodeOASchemaProperty'   -ReadOnly  -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 2
            $result.type | Should -Be 'schema'
            $result.name | Should -Be 'testSchema'
            $result.schema | Should -Be 'Cat'
            $result.description | Should -Be 'Test for New-PodeOASchemaProperty'
            $result.minProperties | Should -Be 1
            $result.maxProperties | Should -Be 2
            $result.meta['example'] | Should -Be 'Example for New-PodeOASchemaProperty'
            $result.meta['readOnly'] | Should -Be $true
            $result.array | Should -BeTrue
            $result.uniqueItems | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }

        It 'ArrayNoSwitches' {
            $result = New-PodeOASchemaProperty -Name 'testSchema' -Description 'Test for New-PodeOASchemaProperty'  -ComponentSchema 'Cat' -MinProperties 1 -MaxProperties 2 `
                -Example 'Example for New-PodeOASchemaProperty'   -Array  -MinItems 2 -MaxItems 4
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 1
            $result.type | Should -Be 'schema'
            $result.name | Should -Be 'testSchema'
            $result.schema | Should -Be 'Cat'
            $result.description | Should -Be 'Test for New-PodeOASchemaProperty'
            $result.minProperties | Should -Be 1
            $result.maxProperties | Should -Be 2
            $result.meta['example'] | Should -Be 'Example for New-PodeOASchemaProperty'
            $result.array | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue

        }
        It 'ArrayDeprecated' {
            $result = New-PodeOASchemaProperty -Name 'testSchema' -Description 'Test for New-PodeOASchemaProperty'  -ComponentSchema 'Cat' -MinProperties 1 -MaxProperties 2 `
                -Example 'Example for New-PodeOASchemaProperty'   -Deprecated  -Array  -MinItems 2 -MaxItems 4
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 1
            $result.type | Should -Be 'schema'
            $result.name | Should -Be 'testSchema'
            $result.schema | Should -Be 'Cat'
            $result.description | Should -Be 'Test for New-PodeOASchemaProperty'
            $result.minProperties | Should -Be 1
            $result.maxProperties | Should -Be 2
            $result.meta['example'] | Should -Be 'Example for New-PodeOASchemaProperty'
            $result.deprecated | Should -Be $true
            $result.array | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }
        It 'ArrayNullable' {
            $result = New-PodeOASchemaProperty -Name 'testSchema' -Description 'Test for New-PodeOASchemaProperty'  -ComponentSchema 'Cat' -MinProperties 1 -MaxProperties 2 `
                -Example 'Example for New-PodeOASchemaProperty'   -Nullable  -Array  -MinItems 2 -MaxItems 4
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 2
            $result.type | Should -Be 'schema'
            $result.name | Should -Be 'testSchema'
            $result.schema | Should -Be 'Cat'
            $result.description | Should -Be 'Test for New-PodeOASchemaProperty'
            $result.minProperties | Should -Be 1
            $result.maxProperties | Should -Be 2
            $result.meta['example'] | Should -Be 'Example for New-PodeOASchemaProperty'
            $result.meta['nullable'] | Should -Be $true
            $result.array | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }
        It 'ArrayWriteOnly' {
            $result = New-PodeOASchemaProperty -Name 'testSchema' -Description 'Test for New-PodeOASchemaProperty'  -ComponentSchema 'Cat' -MinProperties 1 -MaxProperties 2 `
                -Example 'Example for New-PodeOASchemaProperty'   -WriteOnly  -Array  -MinItems 2 -MaxItems 4
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 2
            $result.type | Should -Be 'schema'
            $result.name | Should -Be 'testSchema'
            $result.schema | Should -Be 'Cat'
            $result.description | Should -Be 'Test for New-PodeOASchemaProperty'
            $result.minProperties | Should -Be 1
            $result.maxProperties | Should -Be 2
            $result.meta['example'] | Should -Be 'Example for New-PodeOASchemaProperty'
            $result.meta['writeOnly'] | Should -Be $true
            $result.array | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }
        It 'ArrayReadOnly' {
            $result = New-PodeOASchemaProperty -Name 'testSchema' -Description 'Test for New-PodeOASchemaProperty'  -ComponentSchema 'Cat' -MinProperties 1 -MaxProperties 2 `
                -Example 'Example for New-PodeOASchemaProperty' -ReadOnly  -Array  -MinItems 2 -MaxItems 4
            $result | Should -Not -BeNullOrEmpty
            $result.meta.Count | Should -Be 2
            $result.type | Should -Be 'schema'
            $result.name | Should -Be 'testSchema'
            $result.schema | Should -Be 'Cat'
            $result.description | Should -Be 'Test for New-PodeOASchemaProperty'
            $result.minProperties | Should -Be 1
            $result.maxProperties | Should -Be 2
            $result.meta['example'] | Should -Be 'Example for New-PodeOASchemaProperty'
            $result.meta['readOnly'] | Should -Be $true
            $result.array | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }
    }




    Context 'Merge-PodeOAProperty' {
        BeforeEach {
            $PodeContext = GetPodeContext
            Add-PodeOAComponentSchema -Name 'Pet' -Schema (
                New-PodeOAObjectProperty  -Properties  @(
                (New-PodeOABoolProperty -Name 'friendly'),
                    (New-PodeOAStringProperty -Name 'name')
                ))
        }

        It 'OneOf' {
            $result = Merge-PodeOAProperty   -Type OneOf -Discriminator 'name'   -ObjectDefinitions @('Pet',
              (New-PodeOAObjectProperty  -Properties  @((New-PodeOAIntProperty -Name 'id'), (New-PodeOAStringProperty -Name 'name'))))
            $result | Should -Not -BeNullOrEmpty
            $result | Should -BeOfType [PSObject]
            $result.type | Should -Be 'OneOf'
            $result.discriminator | Should -Be 'name'
            #   $result.schemas | Should -BeOfType 'Array'
            $result.schemas.Count | Should -Be 2
            $result.schemas[0] | Should -Be  'Pet'
            $result.schemas[1].meta | Should -BeNullOrEmpty
            $result.schemas[1].type | Should -Be 'object'
            $result.schemas[1].name | Should -BeNullOrEmpty
            #  $result.schemas[1].properties | Should -BeOfType [Array]
            $result.schemas[1].properties.Count | Should -Be 2
            $result.schemas[1].properties[0].meta | Should -BeNullOrEmpty
            $result.schemas[1].properties[0].type | Should -Be 'integer'
            $result.schemas[1].properties[0].name | Should -Be 'id'
            $result.schemas[1].properties[1].meta | Should -BeNullOrEmpty
            $result.schemas[1].properties[1].type | Should -Be 'string'
            $result.schemas[1].properties[1].name | Should -Be 'name'

        }

        It 'AnyOf' {
            $result = Merge-PodeOAProperty   -Type AnyOf -Discriminator 'name'  -ObjectDefinitions @('Pet',
              (New-PodeOAObjectProperty  -Properties  @((New-PodeOAIntProperty -Name 'id'), (New-PodeOAStringProperty -Name 'name'))))
            $result | Should -Not -BeNullOrEmpty
            $result | Should -BeOfType [PSObject]
            $result.type | Should -Be 'AnyOf'
            $result.discriminator | Should -Be 'name'
            $result.schemas.Count | Should -Be 2
            $result.schemas[0] | Should -Be  'Pet'
            $result.schemas[1].meta | Should -BeNullOrEmpty
            $result.schemas[1].type | Should -Be 'object'
            $result.schemas[1].name | Should -BeNullOrEmpty
            $result.schemas[1].properties.Count | Should -Be 2
            $result.schemas[1].properties[0].meta | Should -BeNullOrEmpty
            $result.schemas[1].properties[0].type | Should -Be 'integer'
            $result.schemas[1].properties[0].name | Should -Be 'id'
            $result.schemas[1].properties[1].meta | Should -BeNullOrEmpty
            $result.schemas[1].properties[1].type | Should -Be 'string'
            $result.schemas[1].properties[1].name | Should -Be 'name'
        }


        It 'AllOf' {
            $result = Merge-PodeOAProperty   -Type AllOf    -ObjectDefinitions @('Pet',
                (New-PodeOAObjectProperty  -Properties  @((New-PodeOAIntProperty -Name 'id'), (New-PodeOAStringProperty -Name 'name'))))
            $result | Should -Not -BeNullOrEmpty
            $result | Should -BeOfType [PSObject]
            $result.type | Should -Be 'AllOf'
            $result.schemas.Count | Should -Be 2
            $result.schemas[0] | Should -Be  'Pet'
            $result.schemas[1].meta | Should -BeNullOrEmpty
            $result.schemas[1].type | Should -Be 'object'
            $result.schemas[1].name | Should -BeNullOrEmpty
            $result.schemas[1].properties.Count | Should -Be 2
            $result.schemas[1].properties[0].meta | Should -BeNullOrEmpty
            $result.schemas[1].properties[0].type | Should -Be 'integer'
            $result.schemas[1].properties[0].name | Should -Be 'id'
            $result.schemas[1].properties[1].meta | Should -BeNullOrEmpty
            $result.schemas[1].properties[1].type | Should -Be 'string'
            $result.schemas[1].properties[1].name | Should -Be 'name'
        }
        Describe 'Testing Exception Handling' {
            It 'AllOf and Discriminator' {
                {
                    Merge-PodeOAProperty   -Type AllOf  -Discriminator 'name'  -ObjectDefinitions @('Pet',
                (New-PodeOAObjectProperty  -Properties  @((New-PodeOAIntProperty -Name 'id'), (New-PodeOAStringProperty -Name 'name')))
                    ) } | Should -Throw -ExpectedMessage 'Discriminator parameter is not compatible with allOf'
            }
            #Should  -Throw  -ExpectedMessage 'Discriminator parameter is not compatible with allOf'


            It 'AllOf and ObjectDefinitions not an object' {
                { Merge-PodeOAProperty   -Type AllOf  -Discriminator 'name'  -ObjectDefinitions @('Pet',
                    ((New-PodeOAIntProperty -Name 'id'), (New-PodeOAStringProperty -Name 'name'))
                    ) } | Should  -Throw  -ExpectedMessage   'Only properties of type Object can be associated with allof'
            }

        }
    }
    Context 'Add-PodeOAInfo' {

        It 'Valid values' {
            Add-PodeOAInfo -TermsOfService 'http://swagger.io/terms/' -License 'Apache 2.0' -LicenseUrl 'http://www.apache.org/licenses/LICENSE-2.0.html' -ContactName 'API Support' -ContactEmail 'apiteam@swagger.io' -ContactUrl 'http://example.com/support'
            $PodeContext.Server.OpenAPI.info | Should -Not -BeNullOrEmpty
            $PodeContext.Server.OpenAPI.info.license | Should -Not -BeNullOrEmpty
            $PodeContext.Server.OpenAPI.info.license.name | Should -Be 'Apache 2.0'
            $PodeContext.Server.OpenAPI.info.license.url | Should -Be 'http://www.apache.org/licenses/LICENSE-2.0.html'
            $PodeContext.Server.OpenAPI.info.contact | Should -Not -BeNullOrEmpty
            $PodeContext.Server.OpenAPI.info.contact.name | Should -Be 'API Support'
            $PodeContext.Server.OpenAPI.info.contact.email | Should -Be 'apiteam@swagger.io'
            $PodeContext.Server.OpenAPI.info.contact.url | Should -Be 'http://example.com/support'
        }
    }

    Context 'New-PodeOAExternalDoc' {
        It 'Valid values' {
            New-PodeOAExternalDoc -Name 'SwaggerDocs' -Description 'Find out more about Swagger' -Url 'http://swagger.io'
            $PodeContext.Server.OpenAPI.hiddenComponents.externalDocs['SwaggerDocs'] | Should -Not -BeNullOrEmpty
            $PodeContext.Server.OpenAPI.hiddenComponents.externalDocs['SwaggerDocs'].description | Should -Be  'Find out more about Swagger'
            $PodeContext.Server.OpenAPI.hiddenComponents.externalDocs['SwaggerDocs'].url | Should -Be 'http://swagger.io'
        }
    }


    Context 'Add-PodeOAExternalDoc' {

        It 'values' {
            Add-PodeOAExternalDoc -Description 'Find out more about Swagger' -Url 'http://swagger.io'
            $PodeContext.Server.OpenAPI.externalDocs | Should -Not -BeNullOrEmpty
            $PodeContext.Server.OpenAPI.externalDocs.description | Should -Be  'Find out more about Swagger'
            $PodeContext.Server.OpenAPI.externalDocs.url | Should -Be 'http://swagger.io'
        }

        It 'Reference' {
            New-PodeOAExternalDoc -Name 'SwaggerDocs' -Description 'Find out more about Swagger' -Url 'http://swagger.io'
            Add-PodeOAExternalDoc -Reference 'SwaggerDocs'
            $PodeContext.Server.OpenAPI.externalDocs | Should -Not -BeNullOrEmpty
            $PodeContext.Server.OpenAPI.externalDocs.description | Should -Be  'Find out more about Swagger'
            $PodeContext.Server.OpenAPI.externalDocs.url | Should -Be 'http://swagger.io'
        }
        Describe 'Testing Exception Handling' {
            It 'ExternaDoc Reference undefined' {
                { Add-PodeOAExternalDoc -Reference  'SwaggerDocs' } |
                    Should  -Throw  -ExpectedMessage   "The ExternalDoc doesn't exist: SwaggerDocs"
            }
        }

    }

    Context 'Add-PodeOATag' {
        It 'Valid values' {
            New-PodeOAExternalDoc -Name 'SwaggerDocs' -Description 'Find out more about Swagger' -Url 'http://swagger.io'
            Add-PodeOATag -Name 'user' -Description 'Operations about user' -ExternalDoc 'SwaggerDocs'
            $PodeContext.Server.OpenAPI.tags['user'] | Should -Not -BeNullOrEmpty
            $PodeContext.Server.OpenAPI.tags['user'].name | Should -Be 'user'
            $PodeContext.Server.OpenAPI.tags['user'].description | Should -Be  'Operations about user'
            $PodeContext.Server.OpenAPI.tags['user'].externalDocs | Should -BeOfType 'hashtable'
            $PodeContext.Server.OpenAPI.tags['user'].externalDocs.Count | Should -Be 2
            $PodeContext.Server.OpenAPI.tags['user'].externalDocs.url | Should -Be 'http://swagger.io'
            $PodeContext.Server.OpenAPI.tags['user'].externalDocs.description | Should -Be 'Find out more about Swagger'
        }
        Describe 'Testing Exception Handling' {
            It 'ExternaDoc undefined' {
                { Add-PodeOATag -Name 'user' -Description 'Operations about user' -ExternalDoc 'SwaggerDocs' } |
                    Should  -Throw  -ExpectedMessage   "The ExternalDoc doesn't exist: SwaggerDocs"
            }
        }
    }



    Context 'Set-PodeOARouteInfo' {
        BeforeEach {
            $Route = @{
                OpenApi = @{
                    Path           = '/test'
                    Responses      = @{
                        '200'     = @{ description = 'OK' }
                        'default' = @{ description = 'Internal server error' }
                    }
                    Parameters     = $null
                    RequestBody    = $null
                    Authentication = @()
                }
            }
            New-PodeOAExternalDoc -Name 'SwaggerDocs' -Description 'Find out more about Swagger' -Url 'http://swagger.io'
            Add-PodeOATag -Name 'pet' -Description 'Everything about your Pets' -ExternalDoc 'SwaggerDocs'
        }

        It 'No switches' {
            $Route | Set-PodeOARouteInfo -Summary 'Update an existing pet' -Description 'Update an existing pet by Id' -Tags 'pet' -OperationId 'updatePet'
            $Route.OpenApi | Should -Not -BeNullOrEmpty
            $Route.OpenApi.Summary | Should -Be 'Update an existing pet'
            $Route.OpenApi.description | Should -Be 'Update an existing pet by Id'
            $Route.OpenApi.operationId | Should -Be  'updatePet'
            $Route.OpenApi.tags | Should -Be  'pet'
            $Route.OpenApi.swagger | Should -BeTrue
            $Route.OpenApi.deprecated | Should -BeNullOrEmpty
        }
        It 'Deprecated' {
            $Route | Set-PodeOARouteInfo -Summary 'Update an existing pet' -Description 'Update an existing pet by Id' -Tags 'pet' -OperationId 'updatePet' -Deprecated
            $Route.OpenApi | Should -Not -BeNullOrEmpty
            $Route.OpenApi.Summary | Should -Be 'Update an existing pet'
            $Route.OpenApi.description | Should -Be 'Update an existing pet by Id'
            $Route.OpenApi.operationId | Should -Be  'updatePet'
            $Route.OpenApi.tags | Should -Be  'pet'
            $Route.OpenApi.swagger | Should -BeTrue
            $Route.OpenApi.deprecated | Should -BeTrue
        }

        It 'PassThru' {
            $result = $Route | Set-PodeOARouteInfo -Summary 'Update an existing pet' -Description 'Update an existing pet by Id' -Tags 'pet' -OperationId 'updatePet' -PassThru
            $result | Should -Not -BeNullOrEmpty
            $result.OpenApi | Should -Not -BeNullOrEmpty
            $result.OpenApi.Summary | Should -Be 'Update an existing pet'
            $result.OpenApi.description | Should -Be 'Update an existing pet by Id'
            $result.OpenApi.operationId | Should -Be  'updatePet'
            $result.OpenApi.tags | Should -Be  'pet'
            $result.OpenApi.swagger | Should -BeTrue
            $result.OpenApi.deprecated | Should -BeNullOrEmpty
        }
    }

    Context 'Add-PodeOAComponentParameter' {
        it 'default' {
            Add-PodeOAComponentParameter -Name 'PetIdParam' -Parameter ( New-PodeOAIntProperty -Name 'petId' -Format Int64 -Description 'ID of the pet' -Required)
            $result = $PodeContext.Server.OpenAPI.components.parameters['PetIdParam']
            $result | Should -Not -BeNullOrEmpty
            $result | Should -BeOfType [hashtable]
            $result.Count | Should -Be 6
            $result.meta | Should -BeOfType [hashtable]
            $result.meta.Count | Should -Be 0
            $result.name | Should -Be 'petId'
            $result.description | Should -Be 'ID of the pet'
            $result.type | Should -Be 'integer'
            $result.format | Should -Be 'int64'
            $result.required | Should -BeTrue
        }
        it 'From Pipeline' {
            New-PodeOAIntProperty -Name 'petId' -Format Int64 -Description 'ID of the pet' -Required | Add-PodeOAComponentParameter -Name 'PetIdParam'
            $result = $PodeContext.Server.OpenAPI.components.parameters['PetIdParam']
            $result | Should -Not -BeNullOrEmpty
            $result | Should -BeOfType [hashtable]
            $result.Count | Should -Be 6
            $result.meta | Should -BeOfType [hashtable]
            $result.meta.Count | Should -Be 0
            $result.name | Should -Be 'petId'
            $result.description | Should -Be 'ID of the pet'
            $result.type | Should -Be 'integer'
            $result.format | Should -Be 'int64'
            $result.required | Should -BeTrue
        }
        it 'throw error' {
            {
                Add-PodeOAComponentParameter   -Parameter ( New-PodeOAIntProperty -Name 'petId' -Format Int64 -Description 'ID of the pet' | New-PodeOAObjectProperty ) } |
                Should -Throw -ExpectedMessage 'The Parameter has no name. Please provide a name to this component using -Name property'
        }
    }
    Context 'ConvertTo-PodeOAParameter' {
        Context 'ConvertTo-PodeOAParameter - Path' {

            It 'Path - Properties - No switches' {
                $result = New-PodeOAIntProperty -Name 'petId' -Format Int64 -Description 'ID of the pet' -Required -Array | ConvertTo-PodeOAParameter -In Path
                $result | Should -Not -BeNullOrEmpty
                $result | Should -BeOfType [hashtable]
                $result.name | Should -Be 'petId'
                $result.description | Should -Be 'ID of the pet'
                $result.in | Should -Be 'path'
                $result.explode | Should -BeFalse
                $result.allowEmptyValue | Should -BeFalse
                $result.deprecated | Should -BeFalse
                $result.style | Should -BeNullOrEmpty
                $result.required | Should -BeTrue
                $result.schema | Should -BeOfType [hashtable]
                $result.schema.Count | Should -Be 2
                $result.schema.type | Should -Be 'array'
                $result.schema.items | Should -BeOfType [hashtable]
                $result.schema.items.Count | Should -Be 2
                $result.schema.items.type | Should -Be 'integer'
                $result.schema.items.format | Should -Be 'int64'
            }

            It 'Path - Properties - Explode' {
                $result = New-PodeOAIntProperty -Name 'petId' -Format Int64 -Description 'ID of the pet' -Required -Array | ConvertTo-PodeOAParameter -In Path -Explode
                $result | Should -Not -BeNullOrEmpty
                $result | Should -BeOfType [hashtable]
                $result.name | Should -Be 'petId'
                $result.description | Should -Be 'ID of the pet'
                $result.in | Should -Be 'path'
                $result.required | Should -BeTrue
                $result.explode | Should -BeTrue
                $result.allowEmptyValue | Should -BeFalse
                $result.deprecated | Should -BeFalse
                $result.style | Should -BeNullOrEmpty
                $result.schema | Should -BeOfType [hashtable]
                $result.schema.Count | Should -Be 2
                $result.schema.type | Should -Be 'array'
                $result.schema.items | Should -BeOfType [hashtable]
                $result.schema.items.Count | Should -Be 2
                $result.schema.items.type | Should -Be 'integer'
                $result.schema.items.format | Should -Be 'int64'
            }

            It 'Path - -ComponentParameter - No switches' {
                Add-PodeOAComponentParameter -Name 'PetIdParam' -Parameter ( New-PodeOAIntProperty -Name 'petId' -Format Int64 -Description 'ID of the pet' -Required | ConvertTo-PodeOAParameter -In Path )
                $result = ConvertTo-PodeOAParameter -ComponentParameter 'PetIdParam'
                $result | Should -Not -BeNullOrEmpty
                $result | Should -BeOfType [hashtable]
                $result.Count | Should -Be 1
                $result['$ref'] | Should -Be '#/components/parameters/PetIdParam'
            }

            It 'Path - ContentSchema - No switches' {
                Add-PodeOAComponentSchema -Name 'Cat' -Schema (
                    New-PodeOAObjectProperty  -Properties  @(
                    (New-PodeOABoolProperty -Name 'friendly'),
                        (New-PodeOAStringProperty -Name 'name')
                    ))
                $result = ConvertTo-PodeOAParameter -In Path -Description 'Feline description' -ContentType 'application/json' -ContentSchema  'Cat'
                $result | Should -Not -BeNullOrEmpty
                $result | Should -BeOfType [hashtable]
                $result.Count | Should -Be 5
                $result.name | Should -Be 'Cat'
                $result.in | Should -Be 'path'
                $result.description | Should -Be 'Feline description'
                $result.required | Should -BeTrue
                $result.allowEmptyValue | Should -BeFalse
                $result.content | Should -Not -BeNullOrEmpty
                $result.content | Should -BeOfType [hashtable]
                $result.content.Count | Should -Be 1
                $result.content.'application/json' | Should -BeOfType [hashtable]
                $result.content.'application/json'.Count | Should -Be 1
                $result.content.'application/json'.schema | Should -BeOfType [hashtable]
                $result.content.'application/json'.schema.Count | Should -Be 1
                $result.content.'application/json'.schema['$ref'] | Should -Be '#/components/schemas/Cat'
            }

            It 'Path - ContentSchema - Required' {
                Add-PodeOAComponentSchema -Name 'Cat' -Schema (
                    New-PodeOAObjectProperty  -Properties  @(
                    (New-PodeOABoolProperty -Name 'friendly'),
                        (New-PodeOAStringProperty -Name 'name')
                    ))
                $result = ConvertTo-PodeOAParameter -In Path -Description 'Feline description' -ContentType 'application/json' -ContentSchema  'Cat' -Required
                $result | Should -Not -BeNullOrEmpty
                $result | Should -BeOfType [hashtable]
                $result.Count | Should -Be 5
                $result.name | Should -Be 'Cat'
                $result.in | Should -Be 'path'
                $result.description | Should -Be 'Feline description'
                $result.required | Should -BeTrue
                $result.allowEmptyValue | Should -BeFalse
                $result.content | Should -Not -BeNullOrEmpty
                $result.content | Should -BeOfType [hashtable]
                $result.content.Count | Should -Be 1
                $result.content.'application/json' | Should -BeOfType [hashtable]
                $result.content.'application/json'.Count | Should -Be 1
                $result.content.'application/json'.schema | Should -BeOfType [hashtable]
                $result.content.'application/json'.schema.Count | Should -Be 1
                $result.content.'application/json'.schema['$ref'] | Should -Be '#/components/schemas/Cat'
            }

            It 'Path - ContentSchema - AllowEmptyValue' {
                Add-PodeOAComponentSchema -Name 'Cat' -Schema (
                    New-PodeOAObjectProperty  -Properties  @(
                    (New-PodeOABoolProperty -Name 'friendly'),
                        (New-PodeOAStringProperty -Name 'name')
                    ))
                $result = ConvertTo-PodeOAParameter -In Path -Description 'Feline description' -ContentType 'application/json' -ContentSchema  'Cat' -AllowEmptyValue
                $result | Should -Not -BeNullOrEmpty
                $result | Should -BeOfType [hashtable]
                $result.Count | Should -Be 6
                $result.name | Should -Be 'Cat'
                $result.in | Should -Be 'path'
                $result.description | Should -Be 'Feline description'
                $result.required | Should -BeTrue
                $result.allowEmptyValue | Should -BeTrue
                $result.content | Should -Not -BeNullOrEmpty
                $result.content | Should -BeOfType [hashtable]
                $result.content.Count | Should -Be 1
                $result.content.'application/json' | Should -BeOfType [hashtable]
                $result.content.'application/json'.Count | Should -Be 1
                $result.content.'application/json'.schema | Should -BeOfType [hashtable]
                $result.content.'application/json'.schema.Count | Should -Be 1
                $result.content.'application/json'.schema['$ref'] | Should -Be '#/components/schemas/Cat'
            }
        }


        Context 'ConvertTo-PodeOAParameter - Header' {

            It 'Header - Properties - No switches' {
                $result = New-PodeOAIntProperty -Name 'petId' -Format Int64 -Description 'ID of the pet' -Required -Array | ConvertTo-PodeOAParameter -In Header
                $result | Should -Not -BeNullOrEmpty
                $result | Should -BeOfType [hashtable]
                $result.name | Should -Be 'petId'
                $result.description | Should -Be 'ID of the pet'
                $result.in | Should -Be 'header'
                $result.explode | Should -BeFalse
                $result.allowEmptyValue | Should -BeFalse
                $result.deprecated | Should -BeFalse
                $result.style | Should -BeNullOrEmpty
                $result.required | Should -BeTrue
                $result.schema | Should -BeOfType [hashtable]
                $result.schema.Count | Should -Be 2
                $result.schema.type | Should -Be 'array'
                $result.schema.items | Should -BeOfType [hashtable]
                $result.schema.items.Count | Should -Be 2
                $result.schema.items.type | Should -Be 'integer'
                $result.schema.items.format | Should -Be 'int64'
            }

            It 'Header - Properties - Explode' {
                $result = New-PodeOAIntProperty -Name 'petId' -Format Int64 -Description 'ID of the pet' -Required -Array | ConvertTo-PodeOAParameter -In Header -Explode
                $result | Should -Not -BeNullOrEmpty
                $result | Should -BeOfType [hashtable]
                $result.name | Should -Be 'petId'
                $result.description | Should -Be 'ID of the pet'
                $result.in | Should -Be 'header'
                $result.required | Should -BeTrue
                $result.explode | Should -BeTrue
                $result.allowEmptyValue | Should -BeFalse
                $result.deprecated | Should -BeFalse
                $result.style | Should -BeNullOrEmpty
                $result.schema | Should -BeOfType [hashtable]
                $result.schema.Count | Should -Be 2
                $result.schema.type | Should -Be 'array'
                $result.schema.items | Should -BeOfType [hashtable]
                $result.schema.items.Count | Should -Be 2
                $result.schema.items.type | Should -Be 'integer'
                $result.schema.items.format | Should -Be 'int64'
            }

            It 'Header - Properties - No switches' {
                $result = New-PodeOAIntProperty -Name 'petId' -Format Int64 -Description 'ID of the pet' -Required -Array | ConvertTo-PodeOAParameter -In Header
                $result | Should -Not -BeNullOrEmpty
                $result | Should -BeOfType [hashtable]
                $result.name | Should -Be 'petId'
                $result.description | Should -Be 'ID of the pet'
                $result.in | Should -Be 'header'
                $result.required | Should -BeTrue
                $result.schema | Should -BeOfType [hashtable]
                $result.schema.Count | Should -Be 2
                $result.schema.type | Should -Be 'array'
                $result.schema.items | Should -BeOfType [hashtable]
                $result.schema.items.Count | Should -Be 2
                $result.schema.items.type | Should -Be 'integer'
                $result.schema.items.format | Should -Be 'int64'
            }

            It 'Header - -ComponentParameter - No switches' {
                Add-PodeOAComponentParameter -Name 'PetIdParam' -Parameter ( New-PodeOAIntProperty -Name 'petId' -Format Int64 -Description 'ID of the pet' -Required | ConvertTo-PodeOAParameter -In Header )
                $result = ConvertTo-PodeOAParameter -ComponentParameter 'PetIdParam'
                $result | Should -Not -BeNullOrEmpty
                $result | Should -BeOfType [hashtable]
                $result.Count | Should -Be 1
                $result['$ref'] | Should -Be '#/components/parameters/PetIdParam'
            }

            It 'Header - ContentSchema - No switches' {
                Add-PodeOAComponentSchema -Name 'Cat' -Schema (
                    New-PodeOAObjectProperty  -Properties  @(
                    (New-PodeOABoolProperty -Name 'friendly'),
                        (New-PodeOAStringProperty -Name 'name')
                    ))
                $result = ConvertTo-PodeOAParameter -In Header -Description 'Feline description' -ContentType 'application/json' -ContentSchema  'Cat'
                $result | Should -Not -BeNullOrEmpty
                $result | Should -BeOfType [hashtable]
                $result.Count | Should -Be 4
                $result.name | Should -Be 'Cat'
                $result.in | Should -Be 'header'
                $result.description | Should -Be 'Feline description'
                $result.required | Should -BeFalse
                $result.allowEmptyValue | Should -BeFalse
                $result.content | Should -Not -BeNullOrEmpty
                $result.content | Should -BeOfType [hashtable]
                $result.content.Count | Should -Be 1
                $result.content.'application/json' | Should -BeOfType [hashtable]
                $result.content.'application/json'.Count | Should -Be 1
                $result.content.'application/json'.schema | Should -BeOfType [hashtable]
                $result.content.'application/json'.schema.Count | Should -Be 1
                $result.content.'application/json'.schema['$ref'] | Should -Be '#/components/schemas/Cat'
            }

            It 'Header - ContentSchema - Required' {
                Add-PodeOAComponentSchema -Name 'Cat' -Schema (
                    New-PodeOAObjectProperty  -Properties  @(
                    (New-PodeOABoolProperty -Name 'friendly'),
                        (New-PodeOAStringProperty -Name 'name')
                    ))
                $result = ConvertTo-PodeOAParameter -In Header -Description 'Feline description' -ContentType 'application/json' -ContentSchema  'Cat' -Required
                $result | Should -Not -BeNullOrEmpty
                $result | Should -BeOfType [hashtable]
                $result.Count | Should -Be 5
                $result.name | Should -Be 'Cat'
                $result.in | Should -Be 'header'
                $result.description | Should -Be 'Feline description'
                $result.required | Should -BeTrue
                $result.allowEmptyValue | Should -BeFalse
                $result.content | Should -Not -BeNullOrEmpty
                $result.content | Should -BeOfType [hashtable]
                $result.content.Count | Should -Be 1
                $result.content.'application/json' | Should -BeOfType [hashtable]
                $result.content.'application/json'.Count | Should -Be 1
                $result.content.'application/json'.schema | Should -BeOfType [hashtable]
                $result.content.'application/json'.schema.Count | Should -Be 1
                $result.content.'application/json'.schema['$ref'] | Should -Be '#/components/schemas/Cat'
            }

            It 'Header - ContentSchema - AllowEmptyValue' {
                Add-PodeOAComponentSchema -Name 'Cat' -Schema (
                    New-PodeOAObjectProperty  -Properties  @(
                    (New-PodeOABoolProperty -Name 'friendly'),
                        (New-PodeOAStringProperty -Name 'name')
                    ))
                $result = ConvertTo-PodeOAParameter -In Header -Description 'Feline description' -ContentType 'application/json' -ContentSchema  'Cat' -AllowEmptyValue
                $result | Should -Not -BeNullOrEmpty
                $result | Should -BeOfType [hashtable]
                $result.Count | Should -Be 5
                $result.name | Should -Be 'Cat'
                $result.in | Should -Be 'header'
                $result.description | Should -Be 'Feline description'
                $result.required | Should -BeFalse
                $result.allowEmptyValue | Should -BeTrue
                $result.content | Should -Not -BeNullOrEmpty
                $result.content | Should -BeOfType [hashtable]
                $result.content.Count | Should -Be 1
                $result.content.'application/json' | Should -BeOfType [hashtable]
                $result.content.'application/json'.Count | Should -Be 1
                $result.content.'application/json'.schema | Should -BeOfType [hashtable]
                $result.content.'application/json'.schema.Count | Should -Be 1
                $result.content.'application/json'.schema['$ref'] | Should -Be '#/components/schemas/Cat'
            }
        }


        Context 'ConvertTo-PodeOAParameter - Cookie' {

            It 'Cookie - Properties - No switches' {
                $result = New-PodeOAIntProperty -Name 'petId' -Format Int64 -Description 'ID of the pet' -Required -Array | ConvertTo-PodeOAParameter -In Cookie
                $result | Should -Not -BeNullOrEmpty
                $result | Should -BeOfType [hashtable]
                $result.name | Should -Be 'petId'
                $result.description | Should -Be 'ID of the pet'
                $result.in | Should -Be 'cookie'
                $result.explode | Should -BeFalse
                $result.allowEmptyValue | Should -BeFalse
                $result.deprecated | Should -BeFalse
                $result.style | Should -BeNullOrEmpty
                $result.required | Should -BeTrue
                $result.schema | Should -BeOfType [hashtable]
                $result.schema.Count | Should -Be 2
                $result.schema.type | Should -Be 'array'
                $result.schema.items | Should -BeOfType [hashtable]
                $result.schema.items.Count | Should -Be 2
                $result.schema.items.type | Should -Be 'integer'
                $result.schema.items.format | Should -Be 'int64'
            }

            It 'Cookie - Properties - Explode' {
                $result = New-PodeOAIntProperty -Name 'petId' -Format Int64 -Description 'ID of the pet' -Required -Array | ConvertTo-PodeOAParameter -In Cookie -Explode
                $result | Should -Not -BeNullOrEmpty
                $result | Should -BeOfType [hashtable]
                $result.name | Should -Be 'petId'
                $result.description | Should -Be 'ID of the pet'
                $result.in | Should -Be 'cookie'
                $result.required | Should -BeTrue
                $result.explode | Should -BeTrue
                $result.allowEmptyValue | Should -BeFalse
                $result.deprecated | Should -BeFalse
                $result.style | Should -BeNullOrEmpty
                $result.schema | Should -BeOfType [hashtable]
                $result.schema.Count | Should -Be 2
                $result.schema.type | Should -Be 'array'
                $result.schema.items | Should -BeOfType [hashtable]
                $result.schema.items.Count | Should -Be 2
                $result.schema.items.type | Should -Be 'integer'
                $result.schema.items.format | Should -Be 'int64'
            }
            It 'Cookie - Properties - No switches' {
                $result = New-PodeOAIntProperty -Name 'petId' -Format Int64 -Description 'ID of the pet' -Required -Array | ConvertTo-PodeOAParameter -In Cookie
                $result | Should -Not -BeNullOrEmpty
                $result | Should -BeOfType [hashtable]
                $result.name | Should -Be 'petId'
                $result.description | Should -Be 'ID of the pet'
                $result.in | Should -Be 'cookie'
                $result.required | Should -BeTrue
                $result.schema | Should -BeOfType [hashtable]
                $result.schema.Count | Should -Be 2
                $result.schema.type | Should -Be 'array'
                $result.schema.items | Should -BeOfType [hashtable]
                $result.schema.items.Count | Should -Be 2
                $result.schema.items.type | Should -Be 'integer'
                $result.schema.items.format | Should -Be 'int64'
            }

            It 'Cookie - -ComponentParameter - No switches' {
                Add-PodeOAComponentParameter -Name 'PetIdParam' -Parameter ( New-PodeOAIntProperty -Name 'petId' -Format Int64 -Description 'ID of the pet' -Required | ConvertTo-PodeOAParameter -In Cookie )
                $result = ConvertTo-PodeOAParameter -ComponentParameter 'PetIdParam'
                $result | Should -Not -BeNullOrEmpty
                $result | Should -BeOfType [hashtable]
                $result.Count | Should -Be 1
                $result['$ref'] | Should -Be '#/components/parameters/PetIdParam'
            }

            It 'Cookie - ContentSchema - No switches' {
                Add-PodeOAComponentSchema -Name 'Cat' -Schema (
                    New-PodeOAObjectProperty  -Properties  @(
                    (New-PodeOABoolProperty -Name 'friendly'),
                        (New-PodeOAStringProperty -Name 'name')
                    ))
                $result = ConvertTo-PodeOAParameter -In Cookie -Description 'Feline description' -ContentType 'application/json' -ContentSchema  'Cat'
                $result | Should -Not -BeNullOrEmpty
                $result | Should -BeOfType [hashtable]
                $result.Count | Should -Be 4
                $result.name | Should -Be 'Cat'
                $result.in | Should -Be 'cookie'
                $result.description | Should -Be 'Feline description'
                $result.required | Should -BeFalse
                $result.allowEmptyValue | Should -BeFalse
                $result.content | Should -Not -BeNullOrEmpty
                $result.content | Should -BeOfType [hashtable]
                $result.content.Count | Should -Be 1
                $result.content.'application/json' | Should -BeOfType [hashtable]
                $result.content.'application/json'.Count | Should -Be 1
                $result.content.'application/json'.schema | Should -BeOfType [hashtable]
                $result.content.'application/json'.schema.Count | Should -Be 1
                $result.content.'application/json'.schema['$ref'] | Should -Be '#/components/schemas/Cat'
            }

            It 'Cookie - ContentSchema - Required' {
                Add-PodeOAComponentSchema -Name 'Cat' -Schema (
                    New-PodeOAObjectProperty  -Properties  @(
                    (New-PodeOABoolProperty -Name 'friendly'),
                        (New-PodeOAStringProperty -Name 'name')
                    ))
                $result = ConvertTo-PodeOAParameter -In Cookie -Description 'Feline description' -ContentType 'application/json' -ContentSchema  'Cat' -Required
                $result | Should -Not -BeNullOrEmpty
                $result | Should -BeOfType [hashtable]
                $result.Count | Should -Be 5
                $result.name | Should -Be 'Cat'
                $result.in | Should -Be 'cookie'
                $result.description | Should -Be 'Feline description'
                $result.required | Should -BeTrue
                $result.allowEmptyValue | Should -BeFalse
                $result.content | Should -Not -BeNullOrEmpty
                $result.content | Should -BeOfType [hashtable]
                $result.content.Count | Should -Be 1
                $result.content.'application/json' | Should -BeOfType [hashtable]
                $result.content.'application/json'.Count | Should -Be 1
                $result.content.'application/json'.schema | Should -BeOfType [hashtable]
                $result.content.'application/json'.schema.Count | Should -Be 1
                $result.content.'application/json'.schema['$ref'] | Should -Be '#/components/schemas/Cat'
            }

            It 'Cookie - ContentSchema - AllowEmptyValue' {
                Add-PodeOAComponentSchema -Name 'Cat' -Schema (
                    New-PodeOAObjectProperty  -Properties  @(
                    (New-PodeOABoolProperty -Name 'friendly'),
                        (New-PodeOAStringProperty -Name 'name')
                    ))
                $result = ConvertTo-PodeOAParameter -In Cookie -Description 'Feline description' -ContentType 'application/json' -ContentSchema  'Cat' -AllowEmptyValue
                $result | Should -Not -BeNullOrEmpty
                $result | Should -BeOfType [hashtable]
                $result.Count | Should -Be 5
                $result.name | Should -Be 'Cat'
                $result.in | Should -Be 'cookie'
                $result.description | Should -Be 'Feline description'
                $result.required | Should -BeFalse
                $result.allowEmptyValue | Should -BeTrue
                $result.content | Should -Not -BeNullOrEmpty
                $result.content | Should -BeOfType [hashtable]
                $result.content.Count | Should -Be 1
                $result.content.'application/json' | Should -BeOfType [hashtable]
                $result.content.'application/json'.Count | Should -Be 1
                $result.content.'application/json'.schema | Should -BeOfType [hashtable]
                $result.content.'application/json'.schema.Count | Should -Be 1
                $result.content.'application/json'.schema['$ref'] | Should -Be '#/components/schemas/Cat'
            }
        }


        Context 'ConvertTo-PodeOAParameter - Query' {

            It 'Query - Properties - No switches' {
                $result = New-PodeOAIntProperty -Name 'petId' -Format Int64 -Description 'ID of the pet' -Required -Array | ConvertTo-PodeOAParameter -In Query
                $result | Should -Not -BeNullOrEmpty
                $result | Should -BeOfType [hashtable]
                $result.name | Should -Be 'petId'
                $result.description | Should -Be 'ID of the pet'
                $result.in | Should -Be 'query'
                $result.explode | Should -BeFalse
                $result.allowEmptyValue | Should -BeFalse
                $result.deprecated | Should -BeFalse
                $result.style | Should -BeNullOrEmpty
                $result.required | Should -BeTrue
                $result.schema | Should -BeOfType [hashtable]
                $result.schema.Count | Should -Be 2
                $result.schema.type | Should -Be 'array'
                $result.schema.items | Should -BeOfType [hashtable]
                $result.schema.items.Count | Should -Be 2
                $result.schema.items.type | Should -Be 'integer'
                $result.schema.items.format | Should -Be 'int64'
            }

            It 'Query - Properties - Explode' {
                $result = New-PodeOAIntProperty -Name 'petId' -Format Int64 -Description 'ID of the pet' -Required -Array | ConvertTo-PodeOAParameter -In Query -Explode
                $result | Should -Not -BeNullOrEmpty
                $result | Should -BeOfType [hashtable]
                $result.name | Should -Be 'petId'
                $result.description | Should -Be 'ID of the pet'
                $result.in | Should -Be 'query'
                $result.required | Should -BeTrue
                $result.explode | Should -BeTrue
                $result.allowEmptyValue | Should -BeFalse
                $result.deprecated | Should -BeFalse
                $result.style | Should -BeNullOrEmpty
                $result.schema | Should -BeOfType [hashtable]
                $result.schema.Count | Should -Be 2
                $result.schema.type | Should -Be 'array'
                $result.schema.items | Should -BeOfType [hashtable]
                $result.schema.items.Count | Should -Be 2
                $result.schema.items.type | Should -Be 'integer'
                $result.schema.items.format | Should -Be 'int64'
            }

            It 'Query - Properties - No switches' {
                $result = New-PodeOAIntProperty -Name 'petId' -Format Int64 -Description 'ID of the pet' -Required -Array | ConvertTo-PodeOAParameter -In Query
                $result | Should -Not -BeNullOrEmpty
                $result | Should -BeOfType [hashtable]
                $result.name | Should -Be 'petId'
                $result.description | Should -Be 'ID of the pet'
                $result.in | Should -Be 'query'
                $result.required | Should -BeTrue
                $result.schema | Should -BeOfType [hashtable]
                $result.schema.Count | Should -Be 2
                $result.schema.type | Should -Be 'array'
                $result.schema.items | Should -BeOfType [hashtable]
                $result.schema.items.Count | Should -Be 2
                $result.schema.items.type | Should -Be 'integer'
                $result.schema.items.format | Should -Be 'int64'
            }

            It 'Query - -ComponentParameter - No switches' {
                Add-PodeOAComponentParameter -Name 'PetIdParam' -Parameter ( New-PodeOAIntProperty -Name 'petId' -Format Int64 -Description 'ID of the pet' -Required | ConvertTo-PodeOAParameter -In Query )
                $result = ConvertTo-PodeOAParameter -ComponentParameter 'PetIdParam'
                $result | Should -Not -BeNullOrEmpty
                $result | Should -BeOfType [hashtable]
                $result.Count | Should -Be 1
                $result['$ref'] | Should -Be '#/components/parameters/PetIdParam'
            }

            It 'Query - ContentSchema - No switches' {
                Add-PodeOAComponentSchema -Name 'Cat' -Schema (
                    New-PodeOAObjectProperty  -Properties  @(
                    (New-PodeOABoolProperty -Name 'friendly'),
                        (New-PodeOAStringProperty -Name 'name')
                    ))
                $result = ConvertTo-PodeOAParameter -In Query -Description 'Feline description' -ContentType 'application/json' -ContentSchema  'Cat'
                $result | Should -Not -BeNullOrEmpty
                $result | Should -BeOfType [hashtable]
                $result.Count | Should -Be 4
                $result.name | Should -Be 'Cat'
                $result.in | Should -Be 'query'
                $result.description | Should -Be 'Feline description'
                $result.required | Should -BeFalse
                $result.allowEmptyValue | Should -BeFalse
                $result.content | Should -Not -BeNullOrEmpty
                $result.content | Should -BeOfType [hashtable]
                $result.content.Count | Should -Be 1
                $result.content.'application/json' | Should -BeOfType [hashtable]
                $result.content.'application/json'.Count | Should -Be 1
                $result.content.'application/json'.schema | Should -BeOfType [hashtable]
                $result.content.'application/json'.schema.Count | Should -Be 1
                $result.content.'application/json'.schema['$ref'] | Should -Be '#/components/schemas/Cat'
            }

            It 'Query - ContentSchema - Required' {
                Add-PodeOAComponentSchema -Name 'Cat' -Schema (
                    New-PodeOAObjectProperty  -Properties  @(
                    (New-PodeOABoolProperty -Name 'friendly'),
                        (New-PodeOAStringProperty -Name 'name')
                    ))
                $result = ConvertTo-PodeOAParameter -In Query -Description 'Feline description' -ContentType 'application/json' -ContentSchema  'Cat' -Required
                $result | Should -Not -BeNullOrEmpty
                $result | Should -BeOfType [hashtable]
                $result.Count | Should -Be 5
                $result.name | Should -Be 'Cat'
                $result.in | Should -Be 'query'
                $result.description | Should -Be 'Feline description'
                $result.required | Should -BeTrue
                $result.allowEmptyValue | Should -BeFalse
                $result.content | Should -Not -BeNullOrEmpty
                $result.content | Should -BeOfType [hashtable]
                $result.content.Count | Should -Be 1
                $result.content.'application/json' | Should -BeOfType [hashtable]
                $result.content.'application/json'.Count | Should -Be 1
                $result.content.'application/json'.schema | Should -BeOfType [hashtable]
                $result.content.'application/json'.schema.Count | Should -Be 1
                $result.content.'application/json'.schema['$ref'] | Should -Be '#/components/schemas/Cat'
            }

            It 'Query - ContentSchema - AllowEmptyValue' {
                Add-PodeOAComponentSchema -Name 'Cat' -Schema (
                    New-PodeOAObjectProperty  -Properties  @(
                    (New-PodeOABoolProperty -Name 'friendly'),
                        (New-PodeOAStringProperty -Name 'name')
                    ))
                $result = ConvertTo-PodeOAParameter -In Query -Description 'Feline description' -ContentType 'application/json' -ContentSchema  'Cat' -AllowEmptyValue
                $result | Should -Not -BeNullOrEmpty
                $result | Should -BeOfType [hashtable]
                $result.Count | Should -Be 5
                $result.name | Should -Be 'Cat'
                $result.in | Should -Be 'query'
                $result.description | Should -Be 'Feline description'
                $result.required | Should -BeFalse
                $result.allowEmptyValue | Should -BeTrue
                $result.content | Should -Not -BeNullOrEmpty
                $result.content | Should -BeOfType [hashtable]
                $result.content.Count | Should -Be 1
                $result.content.'application/json' | Should -BeOfType [hashtable]
                $result.content.'application/json'.Count | Should -Be 1
                $result.content.'application/json'.schema | Should -BeOfType [hashtable]
                $result.content.'application/json'.schema.Count | Should -Be 1
                $result.content.'application/json'.schema['$ref'] | Should -Be '#/components/schemas/Cat'
            }
        }
    }
    Context 'Add-PodeOAComponentRequestBody' {
        BeforeEach {
            Add-PodeOAComponentSchema -Name 'Cat' -Schema (
                New-PodeOAObjectProperty  -Properties  @(
                    (New-PodeOABoolProperty -Name 'friendly'),
                        (New-PodeOAStringProperty -Name 'name')
                ))
        }
        it 'default' {
            Add-PodeOAComponentRequestBody -Name 'PetBodySchema' -Required -Description 'Pet in the store' -ContentSchema (@{ 'application/json' = 'Cat'; 'application/xml' = 'Cat'; 'application/x-www-form-urlencoded' = 'Cat' })
            $result = $PodeContext.Server.OpenAPI.components.requestBodies['PetBodySchema']
            $result | Should -Not -BeNullOrEmpty
            $result | Should -BeOfType [hashtable]
            $result.Count | Should -Be 3
            $result.description | Should -Be 'Pet in the store'
            $result.content | Should -BeOfType [hashtable]
            $result.content.Count | Should -Be 3
            $result.content.'application/json' | Should -BeOfType [hashtable]
            $result.content.'application/json'.Count | Should -Be 1
            $result.content.'application/json'.schema | Should -BeOfType [hashtable]
            $result.content.'application/json'.schema.Count | Should -Be 1
            $result.content.'application/json'.schema['$ref'] | Should -Be '#/components/schemas/Cat'
            $result.content.'application/xml' | Should -BeOfType [hashtable]
            $result.content.'application/xml'.Count | Should -Be 1
            $result.content.'application/xml'.schema | Should -BeOfType [hashtable]
            $result.content.'application/xml'.schema.Count | Should -Be 1
            $result.content.'application/xml'.schema['$ref'] | Should -Be '#/components/schemas/Cat'
            $result.content.'application/x-www-form-urlencoded' | Should -BeOfType [hashtable]
            $result.content.'application/x-www-form-urlencoded'.Count | Should -Be 1
            $result.content.'application/x-www-form-urlencoded'.schema | Should -BeOfType [hashtable]
            $result.content.'application/x-www-form-urlencoded'.schema.Count | Should -Be 1
            $result.content.'application/x-www-form-urlencoded'.schema['$ref'] | Should -Be '#/components/schemas/Cat'
            $result.required | Should -BeTrue
        }
        it 'From Pipeline' {
            $ContentSchema = @{ 'application/json' = 'Cat'; 'application/xml' = 'Cat'; 'application/x-www-form-urlencoded' = 'Cat' }
            $ContentSchema | Add-PodeOAComponentRequestBody -Name 'PetBodySchema' -Required -Description 'Pet in the store'
            $result = $PodeContext.Server.OpenAPI.components.requestBodies['PetBodySchema']
            $result | Should -Not -BeNullOrEmpty
            $result | Should -BeOfType [hashtable]
            $result.Count | Should -Be 3
            $result.description | Should -Be 'Pet in the store'
            $result.content | Should -BeOfType [hashtable]
            $result.content.Count | Should -Be 3
            $result.content.'application/json' | Should -BeOfType [hashtable]
            $result.content.'application/json'.Count | Should -Be 1
            $result.content.'application/json'.schema | Should -BeOfType [hashtable]
            $result.content.'application/json'.schema.Count | Should -Be 1
            $result.content.'application/json'.schema['$ref'] | Should -Be '#/components/schemas/Cat'
            $result.content.'application/xml' | Should -BeOfType [hashtable]
            $result.content.'application/xml'.Count | Should -Be 1
            $result.content.'application/xml'.schema | Should -BeOfType [hashtable]
            $result.content.'application/xml'.schema.Count | Should -Be 1
            $result.content.'application/xml'.schema['$ref'] | Should -Be '#/components/schemas/Cat'
            $result.content.'application/x-www-form-urlencoded' | Should -BeOfType [hashtable]
            $result.content.'application/x-www-form-urlencoded'.Count | Should -Be 1
            $result.content.'application/x-www-form-urlencoded'.schema | Should -BeOfType [hashtable]
            $result.content.'application/x-www-form-urlencoded'.schema.Count | Should -Be 1
            $result.content.'application/x-www-form-urlencoded'.schema['$ref'] | Should -Be '#/components/schemas/Cat'
            $result.required | Should -BeTrue
        }
    }

    Context 'Add-PodeOAComponentHeaderSchema' {

        it 'default' {
            Add-PodeOAComponentHeaderSchema -Name 'X-Rate-Limit' -Schema (New-PodeOAIntProperty -Format Int32 -Description 'calls per hour allowed by the user' )
            $PodeContext.Server.OpenAPI.hiddenComponents.headerSchemas['X-Rate-Limit'] | Should -Not -BeNullOrEmpty
            $result = $PodeContext.Server.OpenAPI.hiddenComponents.headerSchemas['X-Rate-Limit']
            $result | Should -Not -BeNullOrEmpty
            $result | Should -BeOfType [ordered]
            $result.Count | Should -Be 3
            $result.description | Should -Be 'calls per hour allowed by the user'
            $result.type | Should -Be 'integer'
            $result.format | Should -Be 'int32'
        }
        it 'From Pipeline' {
            New-PodeOAIntProperty -Format Int32 -Description 'calls per hour allowed by the user' | Add-PodeOAComponentHeaderSchema -Name 'X-Rate-Limit'
            $PodeContext.Server.OpenAPI.hiddenComponents.headerSchemas['X-Rate-Limit'] | Should -Not -BeNullOrEmpty
            $result = $PodeContext.Server.OpenAPI.hiddenComponents.headerSchemas['X-Rate-Limit']
            $result | Should -Not -BeNullOrEmpty
            $result | Should -BeOfType [ordered]
            $result.Count | Should -Be 3
            $result.description | Should -Be 'calls per hour allowed by the user'
            $result.type | Should -Be 'integer'
            $result.format | Should -Be 'int32'
        }
    }






    Context 'Pet Object example' {
        BeforeEach {
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
        }


        It 'By properties' {
            $Pet = New-PodeOAObjectProperty -Name 'Pet' -Xml @{'name' = 'pet' } -Properties  (
            (New-PodeOAIntProperty -Name 'id'-Format Int64 -Example 10 -ReadOnly ),
                (New-PodeOAStringProperty -Name 'name' -Example 'doggie' -Required) ,
                (New-PodeOASchemaProperty -Name 'category' -ComponentSchema 'Category' ),
                (New-PodeOAStringProperty -Name 'petType' -Example 'dog' -Required) ,
                (New-PodeOAStringProperty -Name 'photoUrls' -Array) ,
                (New-PodeOASchemaProperty -Name 'tags' -ComponentSchema 'Tag') ,
                (New-PodeOAStringProperty -Name 'status' -Description 'pet status in the store' -Enum @('available', 'pending', 'sold'))
            )
            $Pet.type | Should -be 'object'
            $Pet.xml | Should -BeOfType [hashtable]
            $Pet.xml.Count | Should -Be 1
            $Pet.xml[0].name | Should -Be 'pet'
            $Pet.name | Should -Be 'Pet'
            $Pet.meta | Should -BeOfType [hashtable]
            $Pet.meta.Count | Should -Be 0
            $Pet.properties | Should -BeOfType [hashtable]
            $Pet.properties.Count | Should -Be 7

            $Pet.properties[0].type | Should -be 'integer'
            $Pet.properties[0].name | Should -Be 'id'
            $Pet.properties[0].format | Should -Be 'int64'
            $Pet.properties[0].meta | Should -BeOfType [hashtable]
            $Pet.properties[0].meta.Count | Should -Be 2
            $Pet.properties[0].meta.example | Should -Be 10
            $Pet.properties[0].meta.readOnly | Should -Be $true

            $Pet.properties[1].type | Should -be 'string'
            $Pet.properties[1].name | Should -Be 'name'
            $Pet.properties[1].required | Should -BeTrue
            $Pet.properties[1].meta | Should -BeOfType [hashtable]
            $Pet.properties[1].meta.Count | Should -Be 1
            $Pet.properties[1].meta.example | Should -Be 'doggie'

            $Pet.properties[2].type | Should -Be 'schema'
            $Pet.properties[2].name | Should -Be 'category'
            $Pet.properties[2].schema | Should -Be 'Category'
            $Pet.properties[2].meta | Should -BeOfType [hashtable]
            $Pet.properties[2].meta.Count | Should -Be 0

            $Pet.properties[3].type | Should -be 'string'
            $Pet.properties[3].name | Should -Be 'petType'
            $Pet.properties[3].required | Should -BeTrue
            $Pet.properties[3].meta | Should -BeOfType [hashtable]
            $Pet.properties[3].meta.Count | Should -Be 1
            $Pet.properties[3].meta.example | Should -Be 'dog'
            $Pet.properties[4].type | Should -be 'string'
            $Pet.properties[4].name | Should -Be 'photoUrls'
            $Pet.properties[4].array | Should -BeTrue
            $Pet.properties[4].meta | Should -BeOfType [hashtable]
            $Pet.properties[4].meta.Count | Should -Be 0
            $Pet.properties[5].type | Should -be 'schema'
            $Pet.properties[5].name | Should -Be 'tags'
            $Pet.properties[5].schema | Should -Be 'Tag'
            $Pet.properties[5].meta | Should -BeOfType [hashtable]
            $Pet.properties[5].meta.Count | Should -Be 0
            $Pet.properties[6].type | Should -be 'string'
            $Pet.properties[6].name | Should -Be 'status'
            $Pet.properties[6].description | Should -Be 'pet status in the store'
            $Pet.properties[6].enum -is [string[]] | Should -BeTrue
            $Pet.properties[6].enum.Count | Should -Be 3
            $Pet.properties[6].enum[0] | Should -Be 'available'
            $Pet.properties[6].enum[1] | Should -Be 'pending'
            $Pet.properties[6].enum[2] | Should -Be 'sold'
            $Pet.properties[6].meta | Should -BeOfType [hashtable]
            $Pet.properties[6].meta.Count | Should -Be 0

        }
        It 'By Pipeline' {
            $Pet = New-PodeOAIntProperty -Name 'id'-Format Int64 -Example 10 -ReadOnly |
                New-PodeOAStringProperty -Name 'name' -Example 'doggie' -Required |
                New-PodeOASchemaProperty -Name 'category' -ComponentSchema 'Category' |
                New-PodeOAStringProperty -Name 'petType' -Example 'dog' -Required |
                New-PodeOAStringProperty -Name 'photoUrls' -Array |
                New-PodeOASchemaProperty -Name 'tags' -ComponentSchema 'Tag' |
                New-PodeOAStringProperty -Name 'status' -Description 'pet status in the store' -Enum @('available', 'pending', 'sold') |
                New-PodeOAObjectProperty -Name 'Pet' -Xml @{'name' = 'pet' }
            $Pet.type | Should -be 'object'
            $Pet.xml | Should -BeOfType [hashtable]
            $Pet.xml.Count | Should -Be 1
            $Pet.xml[0].name | Should -Be 'pet'
            $Pet.name | Should -Be 'Pet'
            $Pet.meta | Should -BeOfType [hashtable]
            $Pet.meta.Count | Should -Be 0
            $Pet.properties | Should -BeOfType [hashtable]
            $Pet.properties.Count | Should -Be 7
            $Pet.properties[0].type | Should -be 'integer'
            $Pet.properties[0].name | Should -Be 'id'
            $Pet.properties[0].format | Should -Be 'int64'
            $Pet.properties[0].meta | Should -BeOfType [hashtable]
            $Pet.properties[0].meta.Count | Should -Be 2
            $Pet.properties[0].meta.example | Should -Be 10
            $Pet.properties[0].meta.readOnly | Should -Be $true
            $Pet.properties[1].type | Should -be 'string'
            $Pet.properties[1].name | Should -Be 'name'
            $Pet.properties[1].required | Should -BeTrue
            $Pet.properties[1].meta | Should -BeOfType [hashtable]
            $Pet.properties[1].meta.Count | Should -Be 1
            $Pet.properties[1].meta.example | Should -Be 'doggie'
            $Pet.properties[2].type | Should -Be 'schema'
            $Pet.properties[2].name | Should -Be 'category'
            $Pet.properties[2].schema | Should -Be 'Category'
            $Pet.properties[2].meta | Should -BeOfType [hashtable]
            $Pet.properties[2].meta.Count | Should -Be 0
            $Pet.properties[3].type | Should -be 'string'
            $Pet.properties[3].name | Should -Be 'petType'
            $Pet.properties[3].required | Should -BeTrue
            $Pet.properties[3].meta | Should -BeOfType [hashtable]
            $Pet.properties[3].meta.Count | Should -Be 1
            $Pet.properties[3].meta.example | Should -Be 'dog'
            $Pet.properties[4].type | Should -be 'string'
            $Pet.properties[4].name | Should -Be 'photoUrls'
            $Pet.properties[4].array | Should -BeTrue
            $Pet.properties[4].meta | Should -BeOfType [hashtable]
            $Pet.properties[4].meta.Count | Should -Be 0
            $Pet.properties[5].type | Should -be 'schema'
            $Pet.properties[5].name | Should -Be 'tags'
            $Pet.properties[5].schema | Should -Be 'Tag'
            $Pet.properties[5].meta | Should -BeOfType [hashtable]
            $Pet.properties[5].meta.Count | Should -Be 0
            $Pet.properties[6].type | Should -be 'string'
            $Pet.properties[6].name | Should -Be 'status'
            $Pet.properties[6].description | Should -Be 'pet status in the store'
            $Pet.properties[6].enum -is [string[]] | Should -BeTrue
            $Pet.properties[6].enum.Count | Should -Be 3
            $Pet.properties[6].enum[0] | Should -Be 'available'
            $Pet.properties[6].enum[1] | Should -Be 'pending'
            $Pet.properties[6].enum[2] | Should -Be 'sold'
            $Pet.properties[6].meta | Should -BeOfType [hashtable]
            $Pet.properties[6].meta.Count | Should -Be 0

        }
    }

}
