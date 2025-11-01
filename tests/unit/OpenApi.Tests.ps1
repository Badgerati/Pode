[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
param()

BeforeAll {
    $path = $PSCommandPath
    $src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit', '/src/'
    Get-ChildItem "$($src)/*.ps1" -Recurse | Resolve-Path | ForEach-Object { . $_ }
    Import-LocalizedData -BindingVariable PodeLocale -BaseDirectory (Join-Path -Path $src -ChildPath 'Locales') -FileName 'Pode'
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
                        SelectedDefinitionTag = 'default'
                        Definitions           = @{
                            default = Get-PodeOABaseObject
                        }
                    }
                }
            }
        }
        $PodeContext = GetPodeContext

    }


    Context 'New-PodeOAIntProperty' {

        # Check if the function exists
        It 'New-PodeOAIntProperty function exists' {
            Get-Command New-PodeOAIntProperty | Should -Not -Be $null
        }

        It 'NoSwitches' {
            $result = New-PodeOAIntProperty -Name 'testInt' -Description 'Test for New-PodeOAIntProperty' -Format Int32 -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOAIntProperty' -Enum 2, 4, 8, 16 -XmlName 'xTestInt'
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 4
            $result.type | Should -Be 'integer'
            $result.name | Should -Be 'testInt'
            $result.description | Should -Be 'Test for New-PodeOAIntProperty'
            $result.format | Should -Be 'Int32'
            $result.default | Should -Be 8
            $result['minimum'] | Should -Be 2
            $result['maximum'] | Should -Be 20
            $result['multipleOf'] | Should -Be 2
            $result['example'] | Should -Be 'Example for New-PodeOAIntProperty'
            $result.enum | Should -Be @(2, 4, 8, 16)
            $result.xml.name | Should -Be  'xTestInt'
        }
        It 'Object' {
            $result = New-PodeOAIntProperty -Name 'testInt' -Description 'Test for New-PodeOAIntProperty' -Format Int32 -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOAIntProperty' -Enum 2, 4, 8, 16 -XmlName 'xTestInt' -Object
            $result | Should -Not -BeNullOrEmpty
            $result.type | Should -Be 'integer'
            $result.name | Should -Be 'testInt'
            $result.description | Should -Be 'Test for New-PodeOAIntProperty'
            $result.format | Should -Be 'Int32'
            $result.default | Should -Be 8
            $result['minimum'] | Should -Be 2
            $result['maximum'] | Should -Be 20
            $result['multipleOf'] | Should -Be 2
            $result['example'] | Should -Be 'Example for New-PodeOAIntProperty'
            $result.enum | Should -Be @(2, 4, 8, 16)
            $result.xml.name | Should -Be  'xTestInt'
            $result.object | Should -Be $true
        }
        It 'Deprecated' {
            $result = New-PodeOAIntProperty -Name 'testInt' -Description 'Test for New-PodeOAIntProperty' -Format Int32 -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOAIntProperty' -Enum 2, 4, 8, 16 -XmlName 'xTestInt' -Deprecated
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 4
            $result.type | Should -Be 'integer'
            $result.name | Should -Be 'testInt'
            $result.description | Should -Be 'Test for New-PodeOAIntProperty'
            $result.format | Should -Be 'Int32'
            $result.default | Should -Be 8
            $result['minimum'] | Should -Be 2
            $result['maximum'] | Should -Be 20
            $result['multipleOf'] | Should -Be 2
            $result['example'] | Should -Be 'Example for New-PodeOAIntProperty'
            $result.enum | Should -Be @(2, 4, 8, 16)
            $result.xml.name | Should -Be  'xTestInt'
            $result.deprecated | Should -Be $true
        }
        It 'Nullable' {
            $result = New-PodeOAIntProperty -Name 'testInt' -Description 'Test for New-PodeOAIntProperty' -Format Int32 -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOAIntProperty' -Enum 2, 4, 8, 16 -XmlName 'xTestInt' -Nullable
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 5
            $result.type | Should -Be 'integer'
            $result.name | Should -Be 'testInt'
            $result.description | Should -Be 'Test for New-PodeOAIntProperty'
            $result.format | Should -Be 'Int32'
            $result.default | Should -Be 8
            $result['minimum'] | Should -Be 2
            $result['maximum'] | Should -Be 20
            $result['multipleOf'] | Should -Be 2
            $result['example'] | Should -Be 'Example for New-PodeOAIntProperty'
            $result.enum | Should -Be @(2, 4, 8, 16)
            $result.xml.name | Should -Be  'xTestInt'
            $result['nullable'] | Should -Be $true
        }
        It 'WriteOnly' {
            $result = New-PodeOAIntProperty -Name 'testInt' -Description 'Test for New-PodeOAIntProperty' -Format Int32 -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOAIntProperty' -Enum 2, 4, 8, 16 -XmlName 'xTestInt' -WriteOnly
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 5
            $result.type | Should -Be 'integer'
            $result.name | Should -Be 'testInt'
            $result.description | Should -Be 'Test for New-PodeOAIntProperty'
            $result.format | Should -Be 'Int32'
            $result.default | Should -Be 8
            $result['minimum'] | Should -Be 2
            $result['maximum'] | Should -Be 20
            $result['multipleOf'] | Should -Be 2
            $result['example'] | Should -Be 'Example for New-PodeOAIntProperty'
            $result.enum | Should -Be @(2, 4, 8, 16)
            $result.xml.name | Should -Be  'xTestInt'
            $result['writeOnly'] | Should -Be $true
        }
        It 'ReadOnly' {
            $result = New-PodeOAIntProperty -Name 'testInt' -Description 'Test for New-PodeOAIntProperty' -Format Int32 -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOAIntProperty' -Enum 2, 4, 8, 16 -XmlName 'xTestInt' -ReadOnly
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 5
            $result.type | Should -Be 'integer'
            $result.name | Should -Be 'testInt'
            $result.description | Should -Be 'Test for New-PodeOAIntProperty'
            $result.format | Should -Be 'Int32'
            $result.default | Should -Be 8
            $result['minimum'] | Should -Be 2
            $result['maximum'] | Should -Be 20
            $result['multipleOf'] | Should -Be 2
            $result['example'] | Should -Be 'Example for New-PodeOAIntProperty'
            $result.enum | Should -Be @(2, 4, 8, 16)
            $result.xml.name | Should -Be  'xTestInt'
            $result['readOnly'] | Should -Be $true
        }

        It 'ArrayNoSwitchesUniqueItems' {
            $result = New-PodeOAIntProperty -Name 'testInt' -Description 'Test for New-PodeOAIntProperty' -Format Int32 -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOAIntProperty' -Enum 2, 4, 8, 16 -XmlName 'xTestInt' -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 4
            $result.type | Should -Be 'integer'
            $result.name | Should -Be 'testInt'
            $result.description | Should -Be 'Test for New-PodeOAIntProperty'
            $result.format | Should -Be 'Int32'
            $result.default | Should -Be 8
            $result['minimum'] | Should -Be 2
            $result['maximum'] | Should -Be 20
            $result['multipleOf'] | Should -Be 2
            $result['example'] | Should -Be 'Example for New-PodeOAIntProperty'
            $result.enum | Should -Be @(2, 4, 8, 16)
            $result.xml.name | Should -Be  'xTestInt'
            $result.array | Should -BeTrue
            $result.uniqueItems | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue

        }
        It 'ArrayDeprecatedUniqueItems' {
            $result = New-PodeOAIntProperty -Name 'testInt' -Description 'Test for New-PodeOAIntProperty' -Format Int32 -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOAIntProperty' -Enum 2, 4, 8, 16 -XmlName 'xTestInt' -Deprecated  -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 4
            $result.type | Should -Be 'integer'
            $result.name | Should -Be 'testInt'
            $result.description | Should -Be 'Test for New-PodeOAIntProperty'
            $result.format | Should -Be 'Int32'
            $result.default | Should -Be 8
            $result['minimum'] | Should -Be 2
            $result['maximum'] | Should -Be 20
            $result['multipleOf'] | Should -Be 2
            $result['example'] | Should -Be 'Example for New-PodeOAIntProperty'
            $result.enum | Should -Be @(2, 4, 8, 16)
            $result.xml.name | Should -Be  'xTestInt'
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
            #$result.Count | Should -Be 5
            $result.type | Should -Be 'integer'
            $result.name | Should -Be 'testInt'
            $result.description | Should -Be 'Test for New-PodeOAIntProperty'
            $result.format | Should -Be 'Int32'
            $result.default | Should -Be 8
            $result['minimum'] | Should -Be 2
            $result['maximum'] | Should -Be 20
            $result['multipleOf'] | Should -Be 2
            $result['example'] | Should -Be 'Example for New-PodeOAIntProperty'
            $result.enum | Should -Be @(2, 4, 8, 16)
            $result.xml.name | Should -Be  'xTestInt'
            $result['nullable'] | Should -Be $true
            $result.array | Should -BeTrue
            $result.uniqueItems | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }
        It 'ArrayWriteOnlyUniqueItems' {
            $result = New-PodeOAIntProperty -Name 'testInt' -Description 'Test for New-PodeOAIntProperty' -Format Int32 -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOAIntProperty' -Enum 2, 4, 8, 16 -XmlName 'xTestInt' -WriteOnly  -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 5
            $result.type | Should -Be 'integer'
            $result.name | Should -Be 'testInt'
            $result.description | Should -Be 'Test for New-PodeOAIntProperty'
            $result.format | Should -Be 'Int32'
            $result.default | Should -Be 8
            $result['minimum'] | Should -Be 2
            $result['maximum'] | Should -Be 20
            $result['multipleOf'] | Should -Be 2
            $result['example'] | Should -Be 'Example for New-PodeOAIntProperty'
            $result.enum | Should -Be @(2, 4, 8, 16)
            $result.xml.name | Should -Be  'xTestInt'
            $result['writeOnly'] | Should -Be $true
            $result.array | Should -BeTrue
            $result.uniqueItems | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }
        It 'ArrayReadOnlyUniqueItems' {
            $result = New-PodeOAIntProperty -Name 'testInt' -Description 'Test for New-PodeOAIntProperty' -Format Int32 -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOAIntProperty' -Enum 2, 4, 8, 16 -XmlName 'xTestInt' -ReadOnly  -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 5
            $result.type | Should -Be 'integer'
            $result.name | Should -Be 'testInt'
            $result.description | Should -Be 'Test for New-PodeOAIntProperty'
            $result.format | Should -Be 'Int32'
            $result.default | Should -Be 8
            $result['minimum'] | Should -Be 2
            $result['maximum'] | Should -Be 20
            $result['multipleOf'] | Should -Be 2
            $result['example'] | Should -Be 'Example for New-PodeOAIntProperty'
            $result.enum | Should -Be @(2, 4, 8, 16)
            $result.xml.name | Should -Be  'xTestInt'
            $result['readOnly'] | Should -Be $true
            $result.array | Should -BeTrue
            $result.uniqueItems | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }

        It 'ArrayNoSwitches' {
            $result = New-PodeOAIntProperty -Name 'testInt' -Description 'Test for New-PodeOAIntProperty' -Format Int32 -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOAIntProperty' -Enum 2, 4, 8, 16 -XmlName 'xTestInt' -Array  -MinItems 2 -MaxItems 4
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 4
            $result.type | Should -Be 'integer'
            $result.name | Should -Be 'testInt'
            $result.description | Should -Be 'Test for New-PodeOAIntProperty'
            $result.format | Should -Be 'Int32'
            $result.default | Should -Be 8
            $result['minimum'] | Should -Be 2
            $result['maximum'] | Should -Be 20
            $result['multipleOf'] | Should -Be 2
            $result['example'] | Should -Be 'Example for New-PodeOAIntProperty'
            $result.enum | Should -Be @(2, 4, 8, 16)
            $result.xml.name | Should -Be  'xTestInt'
            $result.array | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue

        }
        It 'ArrayDeprecated' {
            $result = New-PodeOAIntProperty -Name 'testInt' -Description 'Test for New-PodeOAIntProperty' -Format Int32 -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOAIntProperty' -Enum 2, 4, 8, 16 -XmlName 'xTestInt' -Deprecated  -Array  -MinItems 2 -MaxItems 4
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 4
            $result.type | Should -Be 'integer'
            $result.name | Should -Be 'testInt'
            $result.description | Should -Be 'Test for New-PodeOAIntProperty'
            $result.format | Should -Be 'Int32'
            $result.default | Should -Be 8
            $result['minimum'] | Should -Be 2
            $result['maximum'] | Should -Be 20
            $result['multipleOf'] | Should -Be 2
            $result['example'] | Should -Be 'Example for New-PodeOAIntProperty'
            $result.enum | Should -Be @(2, 4, 8, 16)
            $result.xml.name | Should -Be  'xTestInt'
            $result.deprecated | Should -Be $true
            $result.array | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }
        It 'ArrayNullable' {
            $result = New-PodeOAIntProperty -Name 'testInt' -Description 'Test for New-PodeOAIntProperty' -Format Int32 -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOAIntProperty' -Enum 2, 4, 8, 16 -XmlName 'xTestInt' -Nullable  -Array  -MinItems 2 -MaxItems 4
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 5
            $result.type | Should -Be 'integer'
            $result.name | Should -Be 'testInt'
            $result.description | Should -Be 'Test for New-PodeOAIntProperty'
            $result.format | Should -Be 'Int32'
            $result.default | Should -Be 8
            $result['minimum'] | Should -Be 2
            $result['maximum'] | Should -Be 20
            $result['multipleOf'] | Should -Be 2
            $result['example'] | Should -Be 'Example for New-PodeOAIntProperty'
            $result.enum | Should -Be @(2, 4, 8, 16)
            $result.xml.name | Should -Be  'xTestInt'
            $result['nullable'] | Should -Be $true
            $result.array | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }
        It 'ArrayWriteOnly' {
            $result = New-PodeOAIntProperty -Name 'testInt' -Description 'Test for New-PodeOAIntProperty' -Format Int32 -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOAIntProperty' -Enum 2, 4, 8, 16 -XmlName 'xTestInt' -WriteOnly  -Array  -MinItems 2 -MaxItems 4
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 5
            $result.type | Should -Be 'integer'
            $result.name | Should -Be 'testInt'
            $result.description | Should -Be 'Test for New-PodeOAIntProperty'
            $result.format | Should -Be 'Int32'
            $result.default | Should -Be 8
            $result['minimum'] | Should -Be 2
            $result['maximum'] | Should -Be 20
            $result['multipleOf'] | Should -Be 2
            $result['example'] | Should -Be 'Example for New-PodeOAIntProperty'
            $result.enum | Should -Be @(2, 4, 8, 16)
            $result.xml.name | Should -Be  'xTestInt'
            $result['writeOnly'] | Should -Be $true
            $result.array | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }
        It 'ArrayReadOnly' {
            $result = New-PodeOAIntProperty -Name 'testInt' -Description 'Test for New-PodeOAIntProperty' -Format Int32 -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOAIntProperty' -Enum 2, 4, 8, 16 -XmlName 'xTestInt' -ReadOnly  -Array  -MinItems 2 -MaxItems 4
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 5
            $result.type | Should -Be 'integer'
            $result.name | Should -Be 'testInt'
            $result.description | Should -Be 'Test for New-PodeOAIntProperty'
            $result.format | Should -Be 'Int32'
            $result.default | Should -Be 8
            $result['minimum'] | Should -Be 2
            $result['maximum'] | Should -Be 20
            $result['multipleOf'] | Should -Be 2
            $result['example'] | Should -Be 'Example for New-PodeOAIntProperty'
            $result.enum | Should -Be @(2, 4, 8, 16)
            $result.xml.name | Should -Be  'xTestInt'
            $result['readOnly'] | Should -Be $true
            $result.array | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }
    }




    Context 'New-PodeOANumberProperty' {

        # Check if the function exists
        It 'New-PodeOANumberProperty function exists' {
            Get-Command New-PodeOANumberProperty | Should -Not -Be $null
        }

        It 'NoSwitches' {
            $result = New-PodeOANumberProperty -Name 'testNumber' -Description 'Test for New-PodeOANumberProperty' -Format Double -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOANumberProperty' -Enum 2.1, 4.2, 8.3, 16.4 -XmlName 'xTestNumber'
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 4
            $result.type | Should -Be 'number'
            $result.name | Should -Be 'testNumber'
            $result.description | Should -Be 'Test for New-PodeOANumberProperty'
            $result.format | Should -Be 'Double'
            $result.default | Should -Be 8
            $result['minimum'] | Should -Be 2
            $result['maximum'] | Should -Be 20
            $result['multipleOf'] | Should -Be 2
            $result['example'] | Should -Be 'Example for New-PodeOANumberProperty'
            $result.enum | Should -Be @(2.1, 4.2, 8.3, 16.4)
            $result.xml.name | Should -Be  'xTestNumber'
        }
        It 'Object' {
            $result = New-PodeOANumberProperty -Name 'testNumber' -Description 'Test for New-PodeOANumberProperty' -Format Double -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOANumberProperty' -Enum 2.1, 4.2, 8.3, 16.4 -XmlName 'xTestNumber' -Object
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 4
            $result.type | Should -Be 'number'
            $result.name | Should -Be 'testNumber'
            $result.description | Should -Be 'Test for New-PodeOANumberProperty'
            $result.format | Should -Be 'Double'
            $result.default | Should -Be 8
            $result['minimum'] | Should -Be 2
            $result['maximum'] | Should -Be 20
            $result['multipleOf'] | Should -Be 2
            $result['example'] | Should -Be 'Example for New-PodeOANumberProperty'
            $result.enum | Should -Be @(2.1, 4.2, 8.3, 16.4)
            $result.xml.name | Should -Be  'xTestNumber'
            $result.object | Should -Be $true
        }
        It 'Deprecated' {
            $result = New-PodeOANumberProperty -Name 'testNumber' -Description 'Test for New-PodeOANumberProperty' -Format Double -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOANumberProperty' -Enum 2.1, 4.2, 8.3, 16.4 -XmlName 'xTestNumber' -Deprecated
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 4
            $result.type | Should -Be 'number'
            $result.name | Should -Be 'testNumber'
            $result.description | Should -Be 'Test for New-PodeOANumberProperty'
            $result.format | Should -Be 'Double'
            $result.default | Should -Be 8
            $result['minimum'] | Should -Be 2
            $result['maximum'] | Should -Be 20
            $result['multipleOf'] | Should -Be 2
            $result['example'] | Should -Be 'Example for New-PodeOANumberProperty'
            $result.enum | Should -Be @(2.1, 4.2, 8.3, 16.4)
            $result.xml.name | Should -Be  'xTestNumber'
            $result.deprecated | Should -Be $true
        }
        It 'Nullable' {
            $result = New-PodeOANumberProperty -Name 'testNumber' -Description 'Test for New-PodeOANumberProperty' -Format Double -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOANumberProperty' -Enum 2.1, 4.2, 8.3, 16.4 -XmlName 'xTestNumber' -Nullable
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 5
            $result.type | Should -Be 'number'
            $result.name | Should -Be 'testNumber'
            $result.description | Should -Be 'Test for New-PodeOANumberProperty'
            $result.format | Should -Be 'Double'
            $result.default | Should -Be 8
            $result['minimum'] | Should -Be 2
            $result['maximum'] | Should -Be 20
            $result['multipleOf'] | Should -Be 2
            $result['example'] | Should -Be 'Example for New-PodeOANumberProperty'
            $result.enum | Should -Be @(2.1, 4.2, 8.3, 16.4)
            $result.xml.name | Should -Be  'xTestNumber'
            $result['nullable'] | Should -Be $true
        }
        It 'WriteOnly' {
            $result = New-PodeOANumberProperty -Name 'testNumber' -Description 'Test for New-PodeOANumberProperty' -Format Double -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOANumberProperty' -Enum 2.1, 4.2, 8.3, 16.4 -XmlName 'xTestNumber' -WriteOnly
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 5
            $result.type | Should -Be 'number'
            $result.name | Should -Be 'testNumber'
            $result.description | Should -Be 'Test for New-PodeOANumberProperty'
            $result.format | Should -Be 'Double'
            $result.default | Should -Be 8
            $result['minimum'] | Should -Be 2
            $result['maximum'] | Should -Be 20
            $result['multipleOf'] | Should -Be 2
            $result['example'] | Should -Be 'Example for New-PodeOANumberProperty'
            $result.enum | Should -Be @(2.1, 4.2, 8.3, 16.4)
            $result.xml.name | Should -Be  'xTestNumber'
            $result['writeOnly'] | Should -Be $true
        }
        It 'ReadOnly' {
            $result = New-PodeOANumberProperty -Name 'testNumber' -Description 'Test for New-PodeOANumberProperty' -Format Double -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOANumberProperty' -Enum 2.1, 4.2, 8.3, 16.4 -XmlName 'xTestNumber' -ReadOnly
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 5
            $result.type | Should -Be 'number'
            $result.name | Should -Be 'testNumber'
            $result.description | Should -Be 'Test for New-PodeOANumberProperty'
            $result.format | Should -Be 'Double'
            $result.default | Should -Be 8
            $result['minimum'] | Should -Be 2
            $result['maximum'] | Should -Be 20
            $result['multipleOf'] | Should -Be 2
            $result['example'] | Should -Be 'Example for New-PodeOANumberProperty'
            $result.enum | Should -Be @(2.1, 4.2, 8.3, 16.4)
            $result.xml.name | Should -Be  'xTestNumber'
            $result['readOnly'] | Should -Be $true
        }

        It 'ArrayNoSwitchesUniqueItems' {
            $result = New-PodeOANumberProperty -Name 'testNumber' -Description 'Test for New-PodeOANumberProperty' -Format Double -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOANumberProperty' -Enum 2.1, 4.2, 8.3, 16.4 -XmlName 'xTestNumber' -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 4
            $result.type | Should -Be 'number'
            $result.name | Should -Be 'testNumber'
            $result.description | Should -Be 'Test for New-PodeOANumberProperty'
            $result.format | Should -Be 'Double'
            $result.default | Should -Be 8
            $result['minimum'] | Should -Be 2
            $result['maximum'] | Should -Be 20
            $result['multipleOf'] | Should -Be 2
            $result['example'] | Should -Be 'Example for New-PodeOANumberProperty'
            $result.enum | Should -Be @(2.1, 4.2, 8.3, 16.4)
            $result.xml.name | Should -Be  'xTestNumber'
            $result.array | Should -BeTrue
            $result.uniqueItems | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue

        }
        It 'ArrayDeprecatedUniqueItems' {
            $result = New-PodeOANumberProperty -Name 'testNumber' -Description 'Test for New-PodeOANumberProperty' -Format Double -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOANumberProperty' -Enum 2.1, 4.2, 8.3, 16.4 -XmlName 'xTestNumber' -Deprecated  -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 4
            $result.type | Should -Be 'number'
            $result.name | Should -Be 'testNumber'
            $result.description | Should -Be 'Test for New-PodeOANumberProperty'
            $result.format | Should -Be 'Double'
            $result.default | Should -Be 8
            $result['minimum'] | Should -Be 2
            $result['maximum'] | Should -Be 20
            $result['multipleOf'] | Should -Be 2
            $result['example'] | Should -Be 'Example for New-PodeOANumberProperty'
            $result.enum | Should -Be @(2.1, 4.2, 8.3, 16.4)
            $result.xml.name | Should -Be  'xTestNumber'
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
            #$result.Count | Should -Be 5
            $result.type | Should -Be 'number'
            $result.name | Should -Be 'testNumber'
            $result.description | Should -Be 'Test for New-PodeOANumberProperty'
            $result.format | Should -Be 'Double'
            $result.default | Should -Be 8
            $result['minimum'] | Should -Be 2
            $result['maximum'] | Should -Be 20
            $result['multipleOf'] | Should -Be 2
            $result['example'] | Should -Be 'Example for New-PodeOANumberProperty'
            $result.enum | Should -Be @(2.1, 4.2, 8.3, 16.4)
            $result.xml.name | Should -Be  'xTestNumber'
            $result['nullable'] | Should -Be $true
            $result.array | Should -BeTrue
            $result.uniqueItems | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }
        It 'ArrayWriteOnlyUniqueItems' {
            $result = New-PodeOANumberProperty -Name 'testNumber' -Description 'Test for New-PodeOANumberProperty' -Format Double -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOANumberProperty' -Enum 2.1, 4.2, 8.3, 16.4 -XmlName 'xTestNumber' -WriteOnly  -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 5
            $result.type | Should -Be 'number'
            $result.name | Should -Be 'testNumber'
            $result.description | Should -Be 'Test for New-PodeOANumberProperty'
            $result.format | Should -Be 'Double'
            $result.default | Should -Be 8
            $result['minimum'] | Should -Be 2
            $result['maximum'] | Should -Be 20
            $result['multipleOf'] | Should -Be 2
            $result['example'] | Should -Be 'Example for New-PodeOANumberProperty'
            $result.enum | Should -Be @(2.1, 4.2, 8.3, 16.4)
            $result.xml.name | Should -Be  'xTestNumber'
            $result['writeOnly'] | Should -Be $true
            $result.array | Should -BeTrue
            $result.uniqueItems | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }
        It 'ArrayReadOnlyUniqueItems' {
            $result = New-PodeOANumberProperty -Name 'testNumber' -Description 'Test for New-PodeOANumberProperty' -Format Double -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOANumberProperty' -Enum 2.1, 4.2, 8.3, 16.4 -XmlName 'xTestNumber' -ReadOnly  -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 5
            $result.type | Should -Be 'number'
            $result.name | Should -Be 'testNumber'
            $result.description | Should -Be 'Test for New-PodeOANumberProperty'
            $result.format | Should -Be 'Double'
            $result.default | Should -Be 8
            $result['minimum'] | Should -Be 2
            $result['maximum'] | Should -Be 20
            $result['multipleOf'] | Should -Be 2
            $result['example'] | Should -Be 'Example for New-PodeOANumberProperty'
            $result.enum | Should -Be @(2.1, 4.2, 8.3, 16.4)
            $result.xml.name | Should -Be  'xTestNumber'
            $result['readOnly'] | Should -Be $true
            $result.array | Should -BeTrue
            $result.uniqueItems | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }

        It 'ArrayNoSwitches' {
            $result = New-PodeOANumberProperty -Name 'testNumber' -Description 'Test for New-PodeOANumberProperty' -Format Double -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOANumberProperty' -Enum 2.1, 4.2, 8.3, 16.4 -XmlName 'xTestNumber' -Array  -MinItems 2 -MaxItems 4
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 4
            $result.type | Should -Be 'number'
            $result.name | Should -Be 'testNumber'
            $result.description | Should -Be 'Test for New-PodeOANumberProperty'
            $result.format | Should -Be 'Double'
            $result.default | Should -Be 8
            $result['minimum'] | Should -Be 2
            $result['maximum'] | Should -Be 20
            $result['multipleOf'] | Should -Be 2
            $result['example'] | Should -Be 'Example for New-PodeOANumberProperty'
            $result.enum | Should -Be @(2.1, 4.2, 8.3, 16.4)
            $result.xml.name | Should -Be  'xTestNumber'
            $result.array | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue

        }
        It 'ArrayDeprecated' {
            $result = New-PodeOANumberProperty -Name 'testNumber' -Description 'Test for New-PodeOANumberProperty' -Format Double -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOANumberProperty' -Enum 2.1, 4.2, 8.3, 16.4 -XmlName 'xTestNumber' -Deprecated  -Array  -MinItems 2 -MaxItems 4
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 4
            $result.type | Should -Be 'number'
            $result.name | Should -Be 'testNumber'
            $result.description | Should -Be 'Test for New-PodeOANumberProperty'
            $result.format | Should -Be 'Double'
            $result.default | Should -Be 8
            $result['minimum'] | Should -Be 2
            $result['maximum'] | Should -Be 20
            $result['multipleOf'] | Should -Be 2
            $result['example'] | Should -Be 'Example for New-PodeOANumberProperty'
            $result.enum | Should -Be @(2.1, 4.2, 8.3, 16.4)
            $result.xml.name | Should -Be  'xTestNumber'
            $result.deprecated | Should -Be $true
            $result.array | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }
        It 'ArrayNullable' {
            $result = New-PodeOANumberProperty -Name 'testNumber' -Description 'Test for New-PodeOANumberProperty' -Format Double -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOANumberProperty' -Enum 2.1, 4.2, 8.3, 16.4 -XmlName 'xTestNumber' -Nullable  -Array  -MinItems 2 -MaxItems 4
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 5
            $result.type | Should -Be 'number'
            $result.name | Should -Be 'testNumber'
            $result.description | Should -Be 'Test for New-PodeOANumberProperty'
            $result.format | Should -Be 'Double'
            $result.default | Should -Be 8
            $result['minimum'] | Should -Be 2
            $result['maximum'] | Should -Be 20
            $result['multipleOf'] | Should -Be 2
            $result['example'] | Should -Be 'Example for New-PodeOANumberProperty'
            $result.enum | Should -Be @(2.1, 4.2, 8.3, 16.4)
            $result.xml.name | Should -Be  'xTestNumber'
            $result['nullable'] | Should -Be $true
            $result.array | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }
        It 'ArrayWriteOnly' {
            $result = New-PodeOANumberProperty -Name 'testNumber' -Description 'Test for New-PodeOANumberProperty' -Format Double -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOANumberProperty' -Enum 2.1, 4.2, 8.3, 16.4 -XmlName 'xTestNumber' -WriteOnly  -Array  -MinItems 2 -MaxItems 4
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 5
            $result.type | Should -Be 'number'
            $result.name | Should -Be 'testNumber'
            $result.description | Should -Be 'Test for New-PodeOANumberProperty'
            $result.format | Should -Be 'Double'
            $result.default | Should -Be 8
            $result['minimum'] | Should -Be 2
            $result['maximum'] | Should -Be 20
            $result['multipleOf'] | Should -Be 2
            $result['example'] | Should -Be 'Example for New-PodeOANumberProperty'
            $result.enum | Should -Be @(2.1, 4.2, 8.3, 16.4)
            $result.xml.name | Should -Be  'xTestNumber'
            $result['writeOnly'] | Should -Be $true
            $result.array | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }
        It 'ArrayReadOnly' {
            $result = New-PodeOANumberProperty -Name 'testNumber' -Description 'Test for New-PodeOANumberProperty' -Format Double -Default 8 -Minimum 2 -Maximum 20 -MultiplesOf 2 `
                -Example 'Example for New-PodeOANumberProperty' -Enum 2.1, 4.2, 8.3, 16.4 -XmlName 'xTestNumber' -ReadOnly  -Array  -MinItems 2 -MaxItems 4
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 5
            $result.type | Should -Be 'number'
            $result.name | Should -Be 'testNumber'
            $result.description | Should -Be 'Test for New-PodeOANumberProperty'
            $result.format | Should -Be 'Double'
            $result.default | Should -Be 8
            $result['minimum'] | Should -Be 2
            $result['maximum'] | Should -Be 20
            $result['multipleOf'] | Should -Be 2
            $result['example'] | Should -Be 'Example for New-PodeOANumberProperty'
            $result.enum | Should -Be @(2.1, 4.2, 8.3, 16.4)
            $result.xml.name | Should -Be  'xTestNumber'
            $result['readOnly'] | Should -Be $true
            $result.array | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }
    }

    Context 'New-PodeOABoolProperty' {

        # Check if the function exists
        It 'New-PodeOABoolProperty function exists' {
            Get-Command New-PodeOABoolProperty | Should -Not -Be $null
        }

        It 'NoSwitches' {
            $result = New-PodeOABoolProperty -Name 'testBool' -Description 'Test for New-PodeOABoolProperty' -Default 'yes' `
                -Example 'Example for New-PodeOABoolProperty' -Enum $true, $false , 'yes', 'no' -XmlName 'xTestBool'
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 1
            $result.type | Should -Be 'boolean'
            $result.name | Should -Be 'testBool'
            $result.description | Should -Be 'Test for New-PodeOABoolProperty'
            $result.default | Should -Be 'yes'
            $result['example'] | Should -Be 'Example for New-PodeOABoolProperty'
            $result.enum | Should -Be @('true', 'false' , 'yes', 'no')
            $result.xml.name | Should -Be  'xTestBool'
        }
        It 'Object' {
            $result = New-PodeOABoolProperty -Name 'testBool' -Description 'Test for New-PodeOABoolProperty' -Default 'yes' `
                -Example 'Example for New-PodeOABoolProperty' -Enum $true, $false , 'yes', 'no' -XmlName 'xTestBool' -Object
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 1
            $result.type | Should -Be 'boolean'
            $result.name | Should -Be 'testBool'
            $result.description | Should -Be 'Test for New-PodeOABoolProperty'
            $result.default | Should -Be 'yes'
            $result['example'] | Should -Be 'Example for New-PodeOABoolProperty'
            $result.enum | Should -Be @('true', 'false' , 'yes', 'no')
            $result.xml.name | Should -Be  'xTestBool'
            $result.object | Should -Be $true
        }
        It 'Deprecated' {
            $result = New-PodeOABoolProperty -Name 'testBool' -Description 'Test for New-PodeOABoolProperty' -Default 'yes' `
                -Example 'Example for New-PodeOABoolProperty' -Enum $true, $false , 'yes', 'no' -XmlName 'xTestBool' -Deprecated
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 1
            $result.type | Should -Be 'boolean'
            $result.name | Should -Be 'testBool'
            $result.description | Should -Be 'Test for New-PodeOABoolProperty'
            $result.default | Should -Be 'yes'
            $result['example'] | Should -Be 'Example for New-PodeOABoolProperty'
            $result.enum | Should -Be @('true', 'false' , 'yes', 'no')
            $result.xml.name | Should -Be  'xTestBool'
            $result.deprecated | Should -Be $true
        }
        It 'Nullable' {
            $result = New-PodeOABoolProperty -Name 'testBool' -Description 'Test for New-PodeOABoolProperty' -Default 'yes' `
                -Example 'Example for New-PodeOABoolProperty' -Enum $true, $false , 'yes', 'no' -XmlName 'xTestBool' -Nullable
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 2
            $result.type | Should -Be 'boolean'
            $result.name | Should -Be 'testBool'
            $result.description | Should -Be 'Test for New-PodeOABoolProperty'
            $result.default | Should -Be 'yes'
            $result['example'] | Should -Be 'Example for New-PodeOABoolProperty'
            $result.enum | Should -Be @('true', 'false' , 'yes', 'no')
            $result.xml.name | Should -Be  'xTestBool'
            $result['nullable'] | Should -Be $true
        }
        It 'WriteOnly' {
            $result = New-PodeOABoolProperty -Name 'testBool' -Description 'Test for New-PodeOABoolProperty' -Default 'yes' `
                -Example 'Example for New-PodeOABoolProperty' -Enum $true, $false , 'yes', 'no' -XmlName 'xTestBool' -WriteOnly
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 2
            $result.type | Should -Be 'boolean'
            $result.name | Should -Be 'testBool'
            $result.description | Should -Be 'Test for New-PodeOABoolProperty'
            $result.default | Should -Be 'yes'
            $result['example'] | Should -Be 'Example for New-PodeOABoolProperty'
            $result.enum | Should -Be @('true', 'false' , 'yes', 'no')
            $result.xml.name | Should -Be  'xTestBool'
            $result['writeOnly'] | Should -Be $true
        }
        It 'ReadOnly' {
            $result = New-PodeOABoolProperty -Name 'testBool' -Description 'Test for New-PodeOABoolProperty' -Default 'yes' `
                -Example 'Example for New-PodeOABoolProperty' -Enum $true, $false , 'yes', 'no' -XmlName 'xTestBool' -ReadOnly
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 2
            $result.type | Should -Be 'boolean'
            $result.name | Should -Be 'testBool'
            $result.description | Should -Be 'Test for New-PodeOABoolProperty'
            $result.default | Should -Be 'yes'
            $result['example'] | Should -Be 'Example for New-PodeOABoolProperty'
            $result.enum | Should -Be @('true', 'false' , 'yes', 'no')
            $result.xml.name | Should -Be  'xTestBool'
            $result['readOnly'] | Should -Be $true
        }

        It 'ArrayNoSwitchesUniqueItems' {
            $result = New-PodeOABoolProperty -Name 'testBool' -Description 'Test for New-PodeOABoolProperty' -Default 'yes' `
                -Example 'Example for New-PodeOABoolProperty' -Enum $true, $false , 'yes', 'no' -XmlName 'xTestBool' -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 1
            $result.type | Should -Be 'boolean'
            $result.name | Should -Be 'testBool'
            $result.description | Should -Be 'Test for New-PodeOABoolProperty'
            $result.default | Should -Be 'yes'
            $result['example'] | Should -Be 'Example for New-PodeOABoolProperty'
            $result.enum | Should -Be @('true', 'false' , 'yes', 'no')
            $result.xml.name | Should -Be  'xTestBool'
            $result.array | Should -BeTrue
            $result.uniqueItems | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue

        }
        It 'ArrayDeprecatedUniqueItems' {
            $result = New-PodeOABoolProperty -Name 'testBool' -Description 'Test for New-PodeOABoolProperty' -Default 'yes' `
                -Example 'Example for New-PodeOABoolProperty' -Enum $true, $false , 'yes', 'no' -XmlName 'xTestBool' -Deprecated  -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 1
            $result.type | Should -Be 'boolean'
            $result.name | Should -Be 'testBool'
            $result.description | Should -Be 'Test for New-PodeOABoolProperty'
            $result.default | Should -Be 'yes'
            $result['example'] | Should -Be 'Example for New-PodeOABoolProperty'
            $result.enum | Should -Be @('true', 'false' , 'yes', 'no')
            $result.xml.name | Should -Be  'xTestBool'
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
            #$result.Count | Should -Be 2
            $result.type | Should -Be 'boolean'
            $result.name | Should -Be 'testBool'
            $result.description | Should -Be 'Test for New-PodeOABoolProperty'
            $result.default | Should -Be 'yes'
            $result['example'] | Should -Be 'Example for New-PodeOABoolProperty'
            $result.enum | Should -Be @('true', 'false' , 'yes', 'no')
            $result.xml.name | Should -Be  'xTestBool'
            $result['nullable'] | Should -Be $true
            $result.array | Should -BeTrue
            $result.uniqueItems | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }
        It 'ArrayWriteOnlyUniqueItems' {
            $result = New-PodeOABoolProperty -Name 'testBool' -Description 'Test for New-PodeOABoolProperty' -Default 'yes' `
                -Example 'Example for New-PodeOABoolProperty' -Enum $true, $false , 'yes', 'no' -XmlName 'xTestBool' -WriteOnly  -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 2
            $result.type | Should -Be 'boolean'
            $result.name | Should -Be 'testBool'
            $result.description | Should -Be 'Test for New-PodeOABoolProperty'
            $result.default | Should -Be 'yes'
            $result['example'] | Should -Be 'Example for New-PodeOABoolProperty'
            $result.enum | Should -Be @('true', 'false' , 'yes', 'no')
            $result.xml.name | Should -Be  'xTestBool'
            $result['writeOnly'] | Should -Be $true
            $result.array | Should -BeTrue
            $result.uniqueItems | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }
        It 'ArrayReadOnlyUniqueItems' {
            $result = New-PodeOABoolProperty -Name 'testBool' -Description 'Test for New-PodeOABoolProperty' -Default 'yes' `
                -Example 'Example for New-PodeOABoolProperty' -Enum $true, $false , 'yes', 'no' -XmlName 'xTestBool' -ReadOnly  -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 2
            $result.type | Should -Be 'boolean'
            $result.name | Should -Be 'testBool'
            $result.description | Should -Be 'Test for New-PodeOABoolProperty'
            $result.default | Should -Be 'yes'
            $result['example'] | Should -Be 'Example for New-PodeOABoolProperty'
            $result.enum | Should -Be @('true', 'false' , 'yes', 'no')
            $result.xml.name | Should -Be  'xTestBool'
            $result['readOnly'] | Should -Be $true
            $result.array | Should -BeTrue
            $result.uniqueItems | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }

        It 'ArrayNoSwitches' {
            $result = New-PodeOABoolProperty -Name 'testBool' -Description 'Test for New-PodeOABoolProperty' -Default 'yes' `
                -Example 'Example for New-PodeOABoolProperty' -Enum $true, $false , 'yes', 'no' -XmlName 'xTestBool' -Array  -MinItems 2 -MaxItems 4
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 1
            $result.type | Should -Be 'boolean'
            $result.name | Should -Be 'testBool'
            $result.description | Should -Be 'Test for New-PodeOABoolProperty'
            $result.default | Should -Be 'yes'
            $result['example'] | Should -Be 'Example for New-PodeOABoolProperty'
            $result.enum | Should -Be @('true', 'false' , 'yes', 'no')
            $result.xml.name | Should -Be  'xTestBool'
            $result.array | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue

        }
        It 'ArrayDeprecated' {
            $result = New-PodeOABoolProperty -Name 'testBool' -Description 'Test for New-PodeOABoolProperty' -Default 'yes' `
                -Example 'Example for New-PodeOABoolProperty' -Enum $true, $false , 'yes', 'no' -XmlName 'xTestBool' -Deprecated  -Array  -MinItems 2 -MaxItems 4
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 1
            $result.type | Should -Be 'boolean'
            $result.name | Should -Be 'testBool'
            $result.description | Should -Be 'Test for New-PodeOABoolProperty'
            $result.default | Should -Be 'yes'
            $result['example'] | Should -Be 'Example for New-PodeOABoolProperty'
            $result.enum | Should -Be @('true', 'false' , 'yes', 'no')
            $result.xml.name | Should -Be  'xTestBool'
            $result.deprecated | Should -Be $true
            $result.array | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }
        It 'ArrayNullable' {
            $result = New-PodeOABoolProperty -Name 'testBool' -Description 'Test for New-PodeOABoolProperty' -Default 'yes' `
                -Example 'Example for New-PodeOABoolProperty' -Enum $true, $false , 'yes', 'no' -XmlName 'xTestBool' -Nullable  -Array  -MinItems 2 -MaxItems 4
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 2
            $result.type | Should -Be 'boolean'
            $result.name | Should -Be 'testBool'
            $result.description | Should -Be 'Test for New-PodeOABoolProperty'
            $result.default | Should -Be 'yes'
            $result['example'] | Should -Be 'Example for New-PodeOABoolProperty'
            $result.enum | Should -Be @('true', 'false' , 'yes', 'no')
            $result.xml.name | Should -Be  'xTestBool'
            $result['nullable'] | Should -Be $true
            $result.array | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }
        It 'ArrayWriteOnly' {
            $result = New-PodeOABoolProperty -Name 'testBool' -Description 'Test for New-PodeOABoolProperty' -Default 'yes' `
                -Example 'Example for New-PodeOABoolProperty' -Enum $true, $false , 'yes', 'no' -XmlName 'xTestBool' -WriteOnly  -Array  -MinItems 2 -MaxItems 4
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 2
            $result.type | Should -Be 'boolean'
            $result.name | Should -Be 'testBool'
            $result.description | Should -Be 'Test for New-PodeOABoolProperty'
            $result.default | Should -Be 'yes'
            $result['example'] | Should -Be 'Example for New-PodeOABoolProperty'
            $result.enum | Should -Be @('true', 'false' , 'yes', 'no')
            $result.xml.name | Should -Be  'xTestBool'
            $result['writeOnly'] | Should -Be $true
            $result.array | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }
        It 'ArrayReadOnly' {
            $result = New-PodeOABoolProperty -Name 'testBool' -Description 'Test for New-PodeOABoolProperty' -Default 'yes' `
                -Example 'Example for New-PodeOABoolProperty' -Enum $true, $false , 'yes', 'no' -XmlName 'xTestBool' -ReadOnly  -Array  -MinItems 2 -MaxItems 4
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 2
            $result.type | Should -Be 'boolean'
            $result.name | Should -Be 'testBool'
            $result.description | Should -Be 'Test for New-PodeOABoolProperty'
            $result.default | Should -Be 'yes'
            $result['example'] | Should -Be 'Example for New-PodeOABoolProperty'
            $result.enum | Should -Be @('true', 'false' , 'yes', 'no')
            $result.xml.name | Should -Be  'xTestBool'
            $result['readOnly'] | Should -Be $true
            $result.array | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }
    }


    Context 'New-PodeOAStringProperty' {

        # Check if the function exists
        It 'New-PodeOAStringProperty function exists' {
            Get-Command New-PodeOAStringProperty | Should -Not -Be $null
        }

        It 'NoSwitches' {
            $result = New-PodeOAStringProperty -Name 'testString' -Description 'Test for New-PodeOAStringProperty' -Format Date -Pattern '^\d{4}-\d{2}-\d{2}$' -Default '2000-01-01' -MinLength 2 -MaxLength 20 `
                -Example 'Example for New-PodeOAStringProperty' -Enum '2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01' -XmlName 'xTestString'
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 4
            $result.type | Should -Be 'string'
            $result.name | Should -Be 'testString'
            $result.description | Should -Be 'Test for New-PodeOAStringProperty'
            $result.format | Should -Be 'Date'
            $result['pattern'] = '^\d{4}-\d{2}-\d{2}$'
            $result.default | Should -Be '2000-01-01'
            $result['minLength'] | Should -Be 2
            $result['maxLength'] | Should -Be 20
            $result['example'] | Should -Be 'Example for New-PodeOAStringProperty'
            $result.enum | Should -Be @('2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01')
            $result.xml.name | Should -Be  'xTestString'
        }
        It 'Object' {
            $result = New-PodeOAStringProperty -Name 'testString' -Description 'Test for New-PodeOAStringProperty' -Format Date -Pattern '^\d{4}-\d{2}-\d{2}$' -Default '2000-01-01' -MinLength 2 -MaxLength 20 `
                -Example 'Example for New-PodeOAStringProperty' -Enum '2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01' -XmlName 'xTestString' -Object
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 4
            $result.type | Should -Be 'string'
            $result.name | Should -Be 'testString'
            $result.description | Should -Be 'Test for New-PodeOAStringProperty'
            $result.format | Should -Be 'Date'
            $result['pattern'] = '^\d{4}-\d{2}-\d{2}$'
            $result.default | Should -Be '2000-01-01'
            $result['minLength'] | Should -Be 2
            $result['maxLength'] | Should -Be 20
            $result['example'] | Should -Be 'Example for New-PodeOAStringProperty'
            $result.enum | Should -Be @('2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01')
            $result.xml.name | Should -Be  'xTestString'
            $result.object | Should -Be $true
        }
        It 'Deprecated' {
            $result = New-PodeOAStringProperty -Name 'testString' -Description 'Test for New-PodeOAStringProperty' -Format Date -Pattern '^\d{4}-\d{2}-\d{2}$' -Default '2000-01-01' -MinLength 2 -MaxLength 20 `
                -Example 'Example for New-PodeOAStringProperty' -Enum '2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01' -XmlName 'xTestString' -Deprecated
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 4
            $result.type | Should -Be 'string'
            $result.name | Should -Be 'testString'
            $result.description | Should -Be 'Test for New-PodeOAStringProperty'
            $result.format | Should -Be 'Date'
            $result['pattern'] = '^\d{4}-\d{2}-\d{2}$'
            $result.default | Should -Be '2000-01-01'
            $result['minLength'] | Should -Be 2
            $result['maxLength'] | Should -Be 20
            $result['example'] | Should -Be 'Example for New-PodeOAStringProperty'
            $result.enum | Should -Be @('2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01')
            $result.xml.name | Should -Be  'xTestString'
            $result.deprecated | Should -Be $true
        }
        It 'Nullable' {
            $result = New-PodeOAStringProperty -Name 'testString' -Description 'Test for New-PodeOAStringProperty' -Format Date -Pattern '^\d{4}-\d{2}-\d{2}$' -Default '2000-01-01' -MinLength 2 -MaxLength 20 `
                -Example 'Example for New-PodeOAStringProperty' -Enum '2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01' -XmlName 'xTestString' -Nullable
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 5
            $result.type | Should -Be 'string'
            $result.name | Should -Be 'testString'
            $result.description | Should -Be 'Test for New-PodeOAStringProperty'
            $result.format | Should -Be 'Date'
            $result['pattern'] = '^\d{4}-\d{2}-\d{2}$'
            $result.default | Should -Be '2000-01-01'
            $result['minLength'] | Should -Be 2
            $result['maxLength'] | Should -Be 20
            $result['example'] | Should -Be 'Example for New-PodeOAStringProperty'
            $result.enum | Should -Be @('2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01')
            $result.xml.name | Should -Be  'xTestString'
            $result['nullable'] | Should -Be $true
        }
        It 'WriteOnly' {
            $result = New-PodeOAStringProperty -Name 'testString' -Description 'Test for New-PodeOAStringProperty' -Format Date -Pattern '^\d{4}-\d{2}-\d{2}$' -Default '2000-01-01' -MinLength 2 -MaxLength 20 `
                -Example 'Example for New-PodeOAStringProperty' -Enum '2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01' -XmlName 'xTestString' -WriteOnly
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 5
            $result.type | Should -Be 'string'
            $result.name | Should -Be 'testString'
            $result.description | Should -Be 'Test for New-PodeOAStringProperty'
            $result.format | Should -Be 'Date'
            $result['pattern'] = '^\d{4}-\d{2}-\d{2}$'
            $result.default | Should -Be '2000-01-01'
            $result['minLength'] | Should -Be 2
            $result['maxLength'] | Should -Be 20
            $result['example'] | Should -Be 'Example for New-PodeOAStringProperty'
            $result.enum | Should -Be @('2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01')
            $result.xml.name | Should -Be  'xTestString'
            $result['writeOnly'] | Should -Be $true
        }
        It 'ReadOnly' {
            $result = New-PodeOAStringProperty -Name 'testString' -Description 'Test for New-PodeOAStringProperty' -Format Date -Pattern '^\d{4}-\d{2}-\d{2}$' -Default '2000-01-01' -MinLength 2 -MaxLength 20 `
                -Example 'Example for New-PodeOAStringProperty' -Enum '2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01' -XmlName 'xTestString' -ReadOnly
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 5
            $result.type | Should -Be 'string'
            $result.name | Should -Be 'testString'
            $result.description | Should -Be 'Test for New-PodeOAStringProperty'
            $result.format | Should -Be 'Date'
            $result['pattern'] = '^\d{4}-\d{2}-\d{2}$'
            $result.default | Should -Be '2000-01-01'
            $result['minLength'] | Should -Be 2
            $result['maxLength'] | Should -Be 20
            $result['example'] | Should -Be 'Example for New-PodeOAStringProperty'
            $result.enum | Should -Be @('2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01')
            $result.xml.name | Should -Be  'xTestString'
            $result['readOnly'] | Should -Be $true
        }

        It 'ArrayNoSwitchesUniqueItems' {
            $result = New-PodeOAStringProperty -Name 'testString' -Description 'Test for New-PodeOAStringProperty' -Format Date -Pattern '^\d{4}-\d{2}-\d{2}$' -Default '2000-01-01' -MinLength 2 -MaxLength 20 `
                -Example 'Example for New-PodeOAStringProperty' -Enum '2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01' -XmlName 'xTestString' -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 4
            $result.type | Should -Be 'string'
            $result.name | Should -Be 'testString'
            $result.description | Should -Be 'Test for New-PodeOAStringProperty'
            $result.format | Should -Be 'Date'
            $result['pattern'] = '^\d{4}-\d{2}-\d{2}$'
            $result.default | Should -Be '2000-01-01'
            $result['minLength'] | Should -Be 2
            $result['maxLength'] | Should -Be 20
            $result['example'] | Should -Be 'Example for New-PodeOAStringProperty'
            $result.enum | Should -Be @('2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01')
            $result.xml.name | Should -Be  'xTestString'
            $result.array | Should -BeTrue
            $result.uniqueItems | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue

        }
        It 'ArrayDeprecatedUniqueItems' {
            $result = New-PodeOAStringProperty -Name 'testString' -Description 'Test for New-PodeOAStringProperty' -Format Date -Pattern '^\d{4}-\d{2}-\d{2}$' -Default '2000-01-01' -MinLength 2 -MaxLength 20 `
                -Example 'Example for New-PodeOAStringProperty' -Enum '2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01' -XmlName 'xTestString' -Deprecated  -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 4
            $result.type | Should -Be 'string'
            $result.name | Should -Be 'testString'
            $result.description | Should -Be 'Test for New-PodeOAStringProperty'
            $result.format | Should -Be 'Date'
            $result['pattern'] = '^\d{4}-\d{2}-\d{2}$'
            $result.default | Should -Be '2000-01-01'
            $result['minLength'] | Should -Be 2
            $result['maxLength'] | Should -Be 20
            $result['example'] | Should -Be 'Example for New-PodeOAStringProperty'
            $result.enum | Should -Be @('2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01')
            $result.xml.name | Should -Be  'xTestString'
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
            #$result.Count | Should -Be 5
            $result.type | Should -Be 'string'
            $result.name | Should -Be 'testString'
            $result.description | Should -Be 'Test for New-PodeOAStringProperty'
            $result.format | Should -Be 'Date'
            $result['pattern'] = '^\d{4}-\d{2}-\d{2}$'
            $result.default | Should -Be '2000-01-01'
            $result['minLength'] | Should -Be 2
            $result['maxLength'] | Should -Be 20
            $result['example'] | Should -Be 'Example for New-PodeOAStringProperty'
            $result.enum | Should -Be @('2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01')
            $result.xml.name | Should -Be  'xTestString'
            $result['nullable'] | Should -Be $true
            $result.array | Should -BeTrue
            $result.uniqueItems | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }
        It 'ArrayWriteOnlyUniqueItems' {
            $result = New-PodeOAStringProperty -Name 'testString' -Description 'Test for New-PodeOAStringProperty' -Format Date -Pattern '^\d{4}-\d{2}-\d{2}$' -Default '2000-01-01' -MinLength 2 -MaxLength 20 `
                -Example 'Example for New-PodeOAStringProperty' -Enum '2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01' -XmlName 'xTestString' -WriteOnly  -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 5
            $result.type | Should -Be 'string'
            $result.name | Should -Be 'testString'
            $result.description | Should -Be 'Test for New-PodeOAStringProperty'
            $result.format | Should -Be 'Date'
            $result['pattern'] = '^\d{4}-\d{2}-\d{2}$'
            $result.default | Should -Be '2000-01-01'
            $result['minLength'] | Should -Be 2
            $result['maxLength'] | Should -Be 20
            $result['example'] | Should -Be 'Example for New-PodeOAStringProperty'
            $result.enum | Should -Be @('2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01')
            $result.xml.name | Should -Be  'xTestString'
            $result['writeOnly'] | Should -Be $true
            $result.array | Should -BeTrue
            $result.uniqueItems | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }
        It 'ArrayReadOnlyUniqueItems' {
            $result = New-PodeOAStringProperty -Name 'testString' -Description 'Test for New-PodeOAStringProperty' -Format Date -Pattern '^\d{4}-\d{2}-\d{2}$' -Default '2000-01-01' -MinLength 2 -MaxLength 20 `
                -Example 'Example for New-PodeOAStringProperty' -Enum '2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01' -XmlName 'xTestString' -ReadOnly  -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 5
            $result.type | Should -Be 'string'
            $result.name | Should -Be 'testString'
            $result.description | Should -Be 'Test for New-PodeOAStringProperty'
            $result.format | Should -Be 'Date'
            $result['pattern'] = '^\d{4}-\d{2}-\d{2}$'
            $result.default | Should -Be '2000-01-01'
            $result['minLength'] | Should -Be 2
            $result['maxLength'] | Should -Be 20
            $result['example'] | Should -Be 'Example for New-PodeOAStringProperty'
            $result.enum | Should -Be @('2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01')
            $result.xml.name | Should -Be  'xTestString'
            $result['readOnly'] | Should -Be $true
            $result.array | Should -BeTrue
            $result.uniqueItems | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }

        It 'ArrayNoSwitches' {
            $result = New-PodeOAStringProperty -Name 'testString' -Description 'Test for New-PodeOAStringProperty' -Format Date -Pattern '^\d{4}-\d{2}-\d{2}$' -Default '2000-01-01' -MinLength 2 -MaxLength 20 `
                -Example 'Example for New-PodeOAStringProperty' -Enum '2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01' -XmlName 'xTestString' -Array  -MinItems 2 -MaxItems 4
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 4
            $result.type | Should -Be 'string'
            $result.name | Should -Be 'testString'
            $result.description | Should -Be 'Test for New-PodeOAStringProperty'
            $result.format | Should -Be 'Date'
            $result['pattern'] = '^\d{4}-\d{2}-\d{2}$'
            $result.default | Should -Be '2000-01-01'
            $result['minLength'] | Should -Be 2
            $result['maxLength'] | Should -Be 20
            $result['example'] | Should -Be 'Example for New-PodeOAStringProperty'
            $result.enum | Should -Be @('2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01')
            $result.xml.name | Should -Be  'xTestString'
            $result.array | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue

        }
        It 'ArrayDeprecated' {
            $result = New-PodeOAStringProperty -Name 'testString' -Description 'Test for New-PodeOAStringProperty' -Format Date -Pattern '^\d{4}-\d{2}-\d{2}$' -Default '2000-01-01' -MinLength 2 -MaxLength 20 `
                -Example 'Example for New-PodeOAStringProperty' -Enum '2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01' -XmlName 'xTestString' -Deprecated  -Array  -MinItems 2 -MaxItems 4
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 4
            $result.type | Should -Be 'string'
            $result.name | Should -Be 'testString'
            $result.description | Should -Be 'Test for New-PodeOAStringProperty'
            $result.format | Should -Be 'Date'
            $result['pattern'] = '^\d{4}-\d{2}-\d{2}$'
            $result.default | Should -Be '2000-01-01'
            $result['minLength'] | Should -Be 2
            $result['maxLength'] | Should -Be 20
            $result['example'] | Should -Be 'Example for New-PodeOAStringProperty'
            $result.enum | Should -Be @('2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01')
            $result.xml.name | Should -Be  'xTestString'
            $result.deprecated | Should -Be $true
            $result.array | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }
        It 'ArrayNullable' {
            $result = New-PodeOAStringProperty -Name 'testString' -Description 'Test for New-PodeOAStringProperty' -Format Date -Pattern '^\d{4}-\d{2}-\d{2}$' -Default '2000-01-01' -MinLength 2 -MaxLength 20 `
                -Example 'Example for New-PodeOAStringProperty' -Enum '2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01' -XmlName 'xTestString' -Nullable  -Array  -MinItems 2 -MaxItems 4
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 5
            $result.type | Should -Be 'string'
            $result.name | Should -Be 'testString'
            $result.description | Should -Be 'Test for New-PodeOAStringProperty'
            $result.format | Should -Be 'Date'
            $result['pattern'] = '^\d{4}-\d{2}-\d{2}$'
            $result.default | Should -Be '2000-01-01'
            $result['minLength'] | Should -Be 2
            $result['maxLength'] | Should -Be 20
            $result['example'] | Should -Be 'Example for New-PodeOAStringProperty'
            $result.enum | Should -Be @('2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01')
            $result.xml.name | Should -Be  'xTestString'
            $result['nullable'] | Should -Be $true
            $result.array | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }
        It 'ArrayWriteOnly' {
            $result = New-PodeOAStringProperty -Name 'testString' -Description 'Test for New-PodeOAStringProperty' -Format Date -Pattern '^\d{4}-\d{2}-\d{2}$' -Default '2000-01-01' -MinLength 2 -MaxLength 20 `
                -Example 'Example for New-PodeOAStringProperty' -Enum '2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01' -XmlName 'xTestString' -WriteOnly  -Array  -MinItems 2 -MaxItems 4
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 5
            $result.type | Should -Be 'string'
            $result.name | Should -Be 'testString'
            $result.description | Should -Be 'Test for New-PodeOAStringProperty'
            $result.format | Should -Be 'Date'
            $result['pattern'] = '^\d{4}-\d{2}-\d{2}$'
            $result.default | Should -Be '2000-01-01'
            $result['minLength'] | Should -Be 2
            $result['maxLength'] | Should -Be 20
            $result['example'] | Should -Be 'Example for New-PodeOAStringProperty'
            $result.enum | Should -Be @('2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01')
            $result.xml.name | Should -Be  'xTestString'
            $result['writeOnly'] | Should -Be $true
            $result.array | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }
        It 'ArrayReadOnly' {
            $result = New-PodeOAStringProperty -Name 'testString' -Description 'Test for New-PodeOAStringProperty' -Format Date -Pattern '^\d{4}-\d{2}-\d{2}$' -Default '2000-01-01' -MinLength 2 -MaxLength 20 `
                -Example 'Example for New-PodeOAStringProperty' -Enum '2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01' -XmlName 'xTestString' -ReadOnly  -Array  -MinItems 2 -MaxItems 4
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 5
            $result.type | Should -Be 'string'
            $result.name | Should -Be 'testString'
            $result.description | Should -Be 'Test for New-PodeOAStringProperty'
            $result.format | Should -Be 'Date'
            $result['pattern'] = '^\d{4}-\d{2}-\d{2}$'
            $result.default | Should -Be '2000-01-01'
            $result['minLength'] | Should -Be 2
            $result['maxLength'] | Should -Be 20
            $result['example'] | Should -Be 'Example for New-PodeOAStringProperty'
            $result.enum | Should -Be @('2005-05-05', '2004-04-04', '2003-03-03', '2002-02-02', '2000-01-01')
            $result.xml.name | Should -Be  'xTestString'
            $result['readOnly'] | Should -Be $true
            $result.array | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }
    }

    Context 'New-PodeOAObjectProperty' {

        # Check if the function exists
        It 'New-PodeOAObjectProperty function exists' {
            Get-Command New-PodeOAObjectProperty | Should -Not -Be $null
        }

        It 'NoSwitches' {
            $result = New-PodeOAObjectProperty -Name 'testObject' -Description 'Test for New-PodeOAObjectProperty'  -MinProperties 1 -MaxProperties 2 `
                -Example 'Example for New-PodeOAObjectProperty' -Properties @((New-PodeOAIntProperty -Name 'id'), (New-PodeOAStringProperty -Name 'name')) -XmlName 'xTestObject'
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 1
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
            $result['example'] | Should -Be 'Example for New-PodeOAObjectProperty'
            $result.xml.name | Should -Be  'xTestObject'
        }
        It 'Deprecated' {
            $result = New-PodeOAObjectProperty -Name 'testObject' -Description 'Test for New-PodeOAObjectProperty'  -MinProperties 1 -MaxProperties 2 `
                -Example 'Example for New-PodeOAObjectProperty' -Properties @((New-PodeOAIntProperty -Name 'id'), (New-PodeOAStringProperty -Name 'name')) -XmlName 'xTestObject' -Deprecated
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 1
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
            $result['example'] | Should -Be 'Example for New-PodeOAObjectProperty'
            $result.xml.name | Should -Be  'xTestObject'
            $result.deprecated | Should -Be $true
        }
        It 'Nullable' {
            $result = New-PodeOAObjectProperty -Name 'testObject' -Description 'Test for New-PodeOAObjectProperty'  -MinProperties 1 -MaxProperties 2 `
                -Example 'Example for New-PodeOAObjectProperty' -Properties @((New-PodeOAIntProperty -Name 'id'), (New-PodeOAStringProperty -Name 'name')) -XmlName 'xTestObject' -Nullable
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 2
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
            $result['example'] | Should -Be 'Example for New-PodeOAObjectProperty'
            $result.xml.name | Should -Be  'xTestObject'
            $result['nullable'] | Should -Be $true
        }
        It 'WriteOnly' {
            $result = New-PodeOAObjectProperty -Name 'testObject' -Description 'Test for New-PodeOAObjectProperty'  -MinProperties 1 -MaxProperties 2 `
                -Example 'Example for New-PodeOAObjectProperty' -Properties @((New-PodeOAIntProperty -Name 'id'), (New-PodeOAStringProperty -Name 'name')) -XmlName 'xTestObject' -WriteOnly
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 2
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
            $result['example'] | Should -Be 'Example for New-PodeOAObjectProperty'
            $result.xml.name | Should -Be  'xTestObject'
            $result['writeOnly'] | Should -Be $true
        }
        It 'ReadOnly' {
            $result = New-PodeOAObjectProperty -Name 'testObject' -Description 'Test for New-PodeOAObjectProperty'  -MinProperties 1 -MaxProperties 2 `
                -Example 'Example for New-PodeOAObjectProperty' -Properties @((New-PodeOAIntProperty -Name 'id'), (New-PodeOAStringProperty -Name 'name')) -XmlName 'xTestObject' -ReadOnly
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 2
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
            $result['example'] | Should -Be 'Example for New-PodeOAObjectProperty'
            $result.xml.name | Should -Be  'xTestObject'
            $result['readOnly'] | Should -Be $true
        }

        It 'ArrayNoSwitchesUniqueItems' {
            $result = New-PodeOAObjectProperty -Name 'testObject' -Description 'Test for New-PodeOAObjectProperty'  -MinProperties 1 -MaxProperties 2 `
                -Example 'Example for New-PodeOAObjectProperty' -Properties @((New-PodeOAIntProperty -Name 'id'), (New-PodeOAStringProperty -Name 'name')) -XmlName 'xTestObject' -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 1
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
            $result['example'] | Should -Be 'Example for New-PodeOAObjectProperty'
            $result.xml.name | Should -Be  'xTestObject'
            $result.array | Should -BeTrue
            $result.uniqueItems | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue

        }
        It 'ArrayDeprecatedUniqueItems' {
            $result = New-PodeOAObjectProperty -Name 'testObject' -Description 'Test for New-PodeOAObjectProperty'  -MinProperties 1 -MaxProperties 2 `
                -Example 'Example for New-PodeOAObjectProperty' -Properties @((New-PodeOAIntProperty -Name 'id'), (New-PodeOAStringProperty -Name 'name')) -XmlName 'xTestObject' -Deprecated  -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 1
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
            $result['example'] | Should -Be 'Example for New-PodeOAObjectProperty'
            $result.xml.name | Should -Be  'xTestObject'
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
            #$result.Count | Should -Be 2
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
            $result['example'] | Should -Be 'Example for New-PodeOAObjectProperty'
            $result.xml.name | Should -Be  'xTestObject'
            $result['nullable'] | Should -Be $true
            $result.array | Should -BeTrue
            $result.uniqueItems | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }
        It 'ArrayWriteOnlyUniqueItems' {
            $result = New-PodeOAObjectProperty -Name 'testObject' -Description 'Test for New-PodeOAObjectProperty'  -MinProperties 1 -MaxProperties 2 `
                -Example 'Example for New-PodeOAObjectProperty' -Properties @((New-PodeOAIntProperty -Name 'id'), (New-PodeOAStringProperty -Name 'name')) -XmlName 'xTestObject' -WriteOnly  -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 2
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
            $result['example'] | Should -Be 'Example for New-PodeOAObjectProperty'
            $result.xml.name | Should -Be  'xTestObject'
            $result['writeOnly'] | Should -Be $true
            $result.array | Should -BeTrue
            $result.uniqueItems | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }
        It 'ArrayReadOnlyUniqueItems' {
            $result = New-PodeOAObjectProperty -Name 'testObject' -Description 'Test for New-PodeOAObjectProperty'  -MinProperties 1 -MaxProperties 2 `
                -Example 'Example for New-PodeOAObjectProperty' -Properties @((New-PodeOAIntProperty -Name 'id'), (New-PodeOAStringProperty -Name 'name')) -XmlName 'xTestObject' -ReadOnly  -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 2
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
            $result['example'] | Should -Be 'Example for New-PodeOAObjectProperty'
            $result.xml.name | Should -Be  'xTestObject'
            $result['readOnly'] | Should -Be $true
            $result.array | Should -BeTrue
            $result.uniqueItems | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }

        It 'ArrayNoSwitches' {
            $result = New-PodeOAObjectProperty -Name 'testObject' -Description 'Test for New-PodeOAObjectProperty'  -MinProperties 1 -MaxProperties 2 `
                -Example 'Example for New-PodeOAObjectProperty' -Properties @((New-PodeOAIntProperty -Name 'id'), (New-PodeOAStringProperty -Name 'name')) -XmlName 'xTestObject' -Array  -MinItems 2 -MaxItems 4
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 1
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
            $result['example'] | Should -Be 'Example for New-PodeOAObjectProperty'
            $result.xml.name | Should -Be  'xTestObject'
            $result.array | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue

        }
        It 'ArrayDeprecated' {
            $result = New-PodeOAObjectProperty -Name 'testObject' -Description 'Test for New-PodeOAObjectProperty'  -MinProperties 1 -MaxProperties 2 `
                -Example 'Example for New-PodeOAObjectProperty' -Properties @((New-PodeOAIntProperty -Name 'id'), (New-PodeOAStringProperty -Name 'name')) -XmlName 'xTestObject' -Deprecated  -Array  -MinItems 2 -MaxItems 4
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 1
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
            $result['example'] | Should -Be 'Example for New-PodeOAObjectProperty'
            $result.xml.name | Should -Be  'xTestObject'
            $result.deprecated | Should -Be $true
            $result.array | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }
        It 'ArrayNullable' {
            $result = New-PodeOAObjectProperty -Name 'testObject' -Description 'Test for New-PodeOAObjectProperty'  -MinProperties 1 -MaxProperties 2 `
                -Example 'Example for New-PodeOAObjectProperty' -Properties @((New-PodeOAIntProperty -Name 'id'), (New-PodeOAStringProperty -Name 'name')) -XmlName 'xTestObject' -Nullable  -Array  -MinItems 2 -MaxItems 4
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 2
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
            $result['example'] | Should -Be 'Example for New-PodeOAObjectProperty'
            $result.xml.name | Should -Be  'xTestObject'
            $result['nullable'] | Should -Be $true
            $result.array | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }
        It 'ArrayWriteOnly' {
            $result = New-PodeOAObjectProperty -Name 'testObject' -Description 'Test for New-PodeOAObjectProperty'  -MinProperties 1 -MaxProperties 2 `
                -Example 'Example for New-PodeOAObjectProperty' -Properties @((New-PodeOAIntProperty -Name 'id'), (New-PodeOAStringProperty -Name 'name')) -XmlName 'xTestObject' -WriteOnly  -Array  -MinItems 2 -MaxItems 4
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 2
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
            $result['example'] | Should -Be 'Example for New-PodeOAObjectProperty'
            $result.xml.name | Should -Be  'xTestObject'
            $result['writeOnly'] | Should -Be $true
            $result.array | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }
        It 'ArrayReadOnly' {
            $result = New-PodeOAObjectProperty -Name 'testObject' -Description 'Test for New-PodeOAObjectProperty'  -MinProperties 1 -MaxProperties 2 `
                -Example 'Example for New-PodeOAObjectProperty' -Properties @((New-PodeOAIntProperty -Name 'id'), (New-PodeOAStringProperty -Name 'name')) -XmlName 'xTestObject' -ReadOnly  -Array  -MinItems 2 -MaxItems 4
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 2
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
            $result['example'] | Should -Be 'Example for New-PodeOAObjectProperty'
            $result.xml.name | Should -Be  'xTestObject'
            $result['readOnly'] | Should -Be $true
            $result.array | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }
    }

    Context 'Add-PodeOAComponentSchema' {
        Context 'OpenAPI 3.1' {
            BeforeEach {
                $PodeContext.Server.OpenAPI.Definitions['default'].hiddenComponents.version = 3.1
            }
            It 'Standard' {
                Add-PodeOAComponentSchema -Name 'Category' -Schema (
                    New-PodeOAObjectProperty -Name 'Category' -XmlName 'category'  -Properties  (
                        New-PodeOAIntProperty -Name 'id'-Format Int64 -Example 1 |
                            New-PodeOAStringProperty -Name 'name' -Example 'Dogs' -Nullable
                    ))

                $PodeContext.Server.OpenAPI.Definitions['default'].components.schemas['Category'] | Should -Not -BeNullOrEmpty
                $result = $PodeContext.Server.OpenAPI.Definitions['default'].components.schemas['Category']
                $result | Should -Not -BeNullOrEmpty
                $result | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.Count | Should -Be 3
                $result.type | Should -Be 'object'
                $result.xml | Should -Not -BeNullOrEmpty
                $result.xml | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.xml.Count | Should -Be 1
                $result.properties | Should -Not -BeNullOrEmpty
                $result.properties | Should -BeOfType  [System.Collections.Specialized.OrderedDictionary]
                $result.properties.Count | Should -Be 2
                $result.properties.name | Should -Not -BeNullOrEmpty
                $result.properties.name | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.properties.name.Count | Should -Be 2
                $result.properties.name.type | Should -Be @('string', 'null')
                $result.properties.name.examples | Should -Be 'Dogs'
                $result.properties.id | Should -Not -BeNullOrEmpty
                $result.properties.id | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.properties.id.Count | Should -Be 3
                $result.properties.id.type | Should -Be 'integer'
                $result.properties.id.examples | Should -Be 1
                $result.properties.id.format | Should -Be 'Int64'
            }
            It 'Pipeline' {
                New-PodeOAIntProperty -Name 'id'-Format Int64 -Example 1 |
                    New-PodeOAStringProperty -Name 'name' -Example 'Dogs' -Nullable |
                    New-PodeOAObjectProperty -Name 'Category' -XmlName 'category' |
                    Add-PodeOAComponentSchema -Name 'Category'
                $PodeContext.Server.OpenAPI.Definitions['default'].components.schemas['Category'] | Should -Not -BeNullOrEmpty
                $result = $PodeContext.Server.OpenAPI.Definitions['default'].components.schemas['Category']
                $result | Should -Not -BeNullOrEmpty
                $result | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.Count | Should -Be 3
                $result.type | Should -Be 'object'
                $result.xml | Should -Not -BeNullOrEmpty
                $result.xml | Should -BeOfType  [System.Collections.Specialized.OrderedDictionary]
                $result.xml.Count | Should -Be 1
                $result.properties | Should -Not -BeNullOrEmpty
                $result.properties | Should -BeOfType  [System.Collections.Specialized.OrderedDictionary]
                $result.properties.Count | Should -Be 2
                $result.properties.name | Should -Not -BeNullOrEmpty
                $result.properties.name | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.properties.name.Count | Should -Be 2
                $result.properties.name.type | Should -Be @('string', 'null')
                $result.properties.name.examples | Should -Be 'Dogs'
                $result.properties.id | Should -Not -BeNullOrEmpty
                $result.properties.id | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.properties.id.Count | Should -Be 3
                $result.properties.id.type | Should -Be 'integer'
                $result.properties.id.examples | Should -Be 1
                $result.properties.id.format | Should -Be 'Int64'
            }
        }
        Context 'OpenAPI 3.0' {
            BeforeEach {
                $PodeContext.Server.OpenAPI.Definitions['default'].hiddenComponents.version = 3.0
            }
            It 'Standard' {
                Add-PodeOAComponentSchema -Name 'Category' -Schema (
                    New-PodeOAObjectProperty -Name 'Category' -XmlName 'category'  -Properties  (
                        New-PodeOAIntProperty -Name 'id'-Format Int64 -Example 1 |
                            New-PodeOAStringProperty -Name 'name' -Example 'Dogs' -Nullable
                    ))

                $PodeContext.Server.OpenAPI.Definitions['default'].components.schemas['Category'] | Should -Not -BeNullOrEmpty
                $result = $PodeContext.Server.OpenAPI.Definitions['default'].components.schemas['Category']
                $result | Should -Not -BeNullOrEmpty
                $result | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.Count | Should -Be 3
                $result.type | Should -Be 'object'
                $result.xml | Should -Not -BeNullOrEmpty
                $result.xml | Should -BeOfType  [System.Collections.Specialized.OrderedDictionary]
                $result.xml.Count | Should -Be 1
                $result.properties | Should -Not -BeNullOrEmpty
                $result.properties | Should -BeOfType  [System.Collections.Specialized.OrderedDictionary]
                $result.properties.Count | Should -Be 2
                $result.properties.name | Should -Not -BeNullOrEmpty
                $result.properties.name | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.properties.name.Count | Should -Be 3
                $result.properties.name.type | Should -Be 'string'
                $result.properties.name.example | Should -Be 'Dogs'
                $result.properties.name.nullable | Should -BeTrue
                $result.properties.id | Should -Not -BeNullOrEmpty
                $result.properties.id | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.properties.id.Count | Should -Be 3
                $result.properties.id.type | Should -Be 'integer'
                $result.properties.id.example | Should -Be 1
                $result.properties.id.format | Should -Be 'Int64'
            }
            It 'Pipeline' {
                New-PodeOAIntProperty -Name 'id'-Format Int64 -Example 1 |
                    New-PodeOAStringProperty -Name 'name' -Example 'Dogs' -Nullable |
                    New-PodeOAObjectProperty -Name 'Category' -XmlName 'category' |
                    Add-PodeOAComponentSchema -Name 'Category'
                $PodeContext.Server.OpenAPI.Definitions['default'].components.schemas['Category'] | Should -Not -BeNullOrEmpty
                $result = $PodeContext.Server.OpenAPI.Definitions['default'].components.schemas['Category']
                $result | Should -Not -BeNullOrEmpty
                $result | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.Count | Should -Be 3
                $result.type | Should -Be 'object'
                $result.xml | Should -Not -BeNullOrEmpty
                $result.xml | Should -BeOfType  [System.Collections.Specialized.OrderedDictionary]
                $result.xml.Count | Should -Be 1
                $result.properties | Should -Not -BeNullOrEmpty
                $result.properties | Should -BeOfType  [System.Collections.Specialized.OrderedDictionary]
                $result.properties.Count | Should -Be 2
                $result.properties.name | Should -Not -BeNullOrEmpty
                $result.properties.name | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.properties.name.Count | Should -Be 3
                $result.properties.name.type | Should -Be 'string'
                $result.properties.name.example | Should -Be 'Dogs'
                $result.properties.name.nullable | Should -BeTrue
                $result.properties.id | Should -Not -BeNullOrEmpty
                $result.properties.id | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.properties.id.Count | Should -Be 3
                $result.properties.id.type | Should -Be 'integer'
                $result.properties.id.example | Should -Be 1
                $result.properties.id.format | Should -Be 'Int64'
            }
        }
    }


    Context 'New-PodeOAComponentSchemaProperty' {
        BeforeEach {
            Add-PodeOAComponentSchema -Name 'Cat' -Schema (
                New-PodeOAObjectProperty  -Properties  @(
                (New-PodeOABoolProperty -Name 'friendly'),
                    (New-PodeOAStringProperty -Name 'name')
                ))
        }

        # Check if the function exists
        It 'New-PodeOAComponentSchemaProperty function exists' {
            Get-Command New-PodeOAComponentSchemaProperty | Should -Not -Be $null
        }

        It 'Standard' {
            $result = New-PodeOAComponentSchemaProperty -Name 'testSchema' -Reference 'Cat'
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 0
            $result.type | Should -Be 'schema'
            $result.name | Should -Be 'testSchema'
            $result.schema | Should -Be 'Cat'
        }

        It 'ArrayNoSwitchesUniqueItems' {
            $result = New-PodeOAComponentSchemaProperty -Name 'testSchema' -Description 'Test for New-PodeOAComponentSchemaProperty'  -Reference 'Cat'  `
                -Example 'Example for New-PodeOAComponentSchemaProperty'   -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 1
            $result.type | Should -Be 'schema'
            $result.name | Should -Be 'testSchema'
            $result.schema | Should -Be 'Cat'
            $result.description | Should -Be 'Test for New-PodeOAComponentSchemaProperty'
            $result['example'] | Should -Be 'Example for New-PodeOAComponentSchemaProperty'
            $result.array | Should -BeTrue
            $result.uniqueItems | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue

        }
        It 'ArrayDeprecatedUniqueItems' {
            $result = New-PodeOAComponentSchemaProperty -Name 'testSchema' -Description 'Test for New-PodeOAComponentSchemaProperty'  -Reference 'Cat'  `
                -Example 'Example for New-PodeOAComponentSchemaProperty'   -Deprecated  -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 1
            $result.type | Should -Be 'schema'
            $result.name | Should -Be 'testSchema'
            $result.schema | Should -Be 'Cat'
            $result.description | Should -Be 'Test for New-PodeOAComponentSchemaProperty'
            $result['example'] | Should -Be 'Example for New-PodeOAComponentSchemaProperty'
            $result.deprecated | Should -Be $true
            $result.array | Should -BeTrue
            $result.uniqueItems | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }
        It 'ArrayNullableUniqueItems' {
            $result = New-PodeOAComponentSchemaProperty -Name 'testSchema' -Description 'Test for New-PodeOAComponentSchemaProperty'  -Reference 'Cat'  `
                -Example 'Example for New-PodeOAComponentSchemaProperty'   -Nullable  -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 2
            $result.type | Should -Be 'schema'
            $result.name | Should -Be 'testSchema'
            $result.schema | Should -Be 'Cat'
            $result.description | Should -Be 'Test for New-PodeOAComponentSchemaProperty'
            $result['example'] | Should -Be 'Example for New-PodeOAComponentSchemaProperty'
            $result['nullable'] | Should -Be $true
            $result.array | Should -BeTrue
            $result.uniqueItems | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }
        It 'ArrayWriteOnlyUniqueItems' {
            $result = New-PodeOAComponentSchemaProperty -Name 'testSchema' -Description 'Test for New-PodeOAComponentSchemaProperty'  -Reference 'Cat'  `
                -Example 'Example for New-PodeOAComponentSchemaProperty'   -WriteOnly  -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 2
            $result.type | Should -Be 'schema'
            $result.name | Should -Be 'testSchema'
            $result.schema | Should -Be 'Cat'
            $result.description | Should -Be 'Test for New-PodeOAComponentSchemaProperty'
            $result['example'] | Should -Be 'Example for New-PodeOAComponentSchemaProperty'
            $result['writeOnly'] | Should -Be $true
            $result.array | Should -BeTrue
            $result.uniqueItems | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }
        It 'ArrayReadOnlyUniqueItems' {
            $result = New-PodeOAComponentSchemaProperty -Name 'testSchema' -Description 'Test for New-PodeOAComponentSchemaProperty'  -Reference 'Cat' `
                -Example 'Example for New-PodeOAComponentSchemaProperty'   -ReadOnly  -Array  -MinItems 2 -MaxItems 4 -UniqueItems
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 2
            $result.type | Should -Be 'schema'
            $result.name | Should -Be 'testSchema'
            $result.schema | Should -Be 'Cat'
            $result.description | Should -Be 'Test for New-PodeOAComponentSchemaProperty'
            $result['example'] | Should -Be 'Example for New-PodeOAComponentSchemaProperty'
            $result['readOnly'] | Should -Be $true
            $result.array | Should -BeTrue
            $result.uniqueItems | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }

        It 'ArrayNoSwitches' {
            $result = New-PodeOAComponentSchemaProperty -Name 'testSchema' -Description 'Test for New-PodeOAComponentSchemaProperty'  -Reference 'Cat'  `
                -Example 'Example for New-PodeOAComponentSchemaProperty'   -Array  -MinItems 2 -MaxItems 4
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 1
            $result.type | Should -Be 'schema'
            $result.name | Should -Be 'testSchema'
            $result.schema | Should -Be 'Cat'
            $result.description | Should -Be 'Test for New-PodeOAComponentSchemaProperty'
            $result['example'] | Should -Be 'Example for New-PodeOAComponentSchemaProperty'
            $result.array | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue

        }
        It 'ArrayDeprecated' {
            $result = New-PodeOAComponentSchemaProperty -Name 'testSchema' -Description 'Test for New-PodeOAComponentSchemaProperty'  -Reference 'Cat'   `
                -Example 'Example for New-PodeOAComponentSchemaProperty'   -Deprecated  -Array  -MinItems 2 -MaxItems 4
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 1
            $result.type | Should -Be 'schema'
            $result.name | Should -Be 'testSchema'
            $result.schema | Should -Be 'Cat'
            $result.description | Should -Be 'Test for New-PodeOAComponentSchemaProperty'
            $result['example'] | Should -Be 'Example for New-PodeOAComponentSchemaProperty'
            $result.deprecated | Should -Be $true
            $result.array | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }
        It 'ArrayNullable' {
            $result = New-PodeOAComponentSchemaProperty -Name 'testSchema' -Description 'Test for New-PodeOAComponentSchemaProperty'  -Reference 'Cat'   `
                -Example 'Example for New-PodeOAComponentSchemaProperty'   -Nullable  -Array  -MinItems 2 -MaxItems 4
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 2
            $result.type | Should -Be 'schema'
            $result.name | Should -Be 'testSchema'
            $result.schema | Should -Be 'Cat'
            $result.description | Should -Be 'Test for New-PodeOAComponentSchemaProperty'
            $result['example'] | Should -Be 'Example for New-PodeOAComponentSchemaProperty'
            $result['nullable'] | Should -Be $true
            $result.array | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }
        It 'ArrayWriteOnly' {
            $result = New-PodeOAComponentSchemaProperty -Name 'testSchema' -Description 'Test for New-PodeOAComponentSchemaProperty'  -Reference 'Cat' `
                -Example 'Example for New-PodeOAComponentSchemaProperty'   -WriteOnly  -Array  -MinItems 2 -MaxItems 4
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 2
            $result.type | Should -Be 'schema'
            $result.name | Should -Be 'testSchema'
            $result.schema | Should -Be 'Cat'
            $result.description | Should -Be 'Test for New-PodeOAComponentSchemaProperty'
            $result['example'] | Should -Be 'Example for New-PodeOAComponentSchemaProperty'
            $result['writeOnly'] | Should -Be $true
            $result.array | Should -BeTrue
            $result.minItems | Should -BeTrue
            $result.maxItems | Should -BeTrue
        }
        It 'ArrayReadOnly' {
            $result = New-PodeOAComponentSchemaProperty -Name 'testSchema' -Description 'Test for New-PodeOAComponentSchemaProperty'  -Reference 'Cat'  `
                -Example 'Example for New-PodeOAComponentSchemaProperty' -ReadOnly  -Array  -MinItems 2 -MaxItems 4
            $result | Should -Not -BeNullOrEmpty
            #$result.Count | Should -Be 2
            $result.type | Should -Be 'schema'
            $result.name | Should -Be 'testSchema'
            $result.schema | Should -Be 'Cat'
            $result.description | Should -Be 'Test for New-PodeOAComponentSchemaProperty'
            $result['example'] | Should -Be 'Example for New-PodeOAComponentSchemaProperty'
            $result['readOnly'] | Should -Be $true
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

        # Check if the function exists
        It 'Merge-PodeOAProperty function exists' {
            Get-Command Merge-PodeOAProperty | Should -Not -Be $null
        }

        It 'OneOf' {
            $result = Merge-PodeOAProperty   -Type OneOf -DiscriminatorProperty 'name'   -ObjectDefinitions @('Pet',
              (New-PodeOAObjectProperty  -Properties  @((New-PodeOAIntProperty -Name 'id'), (New-PodeOAStringProperty -Name 'name'))))
            $result | Should -Not -BeNullOrEmpty
            $result | Should -BeOfType [PSObject]
            $result.type | Should -Be 'OneOf'
            $result.discriminator.propertyName | Should -Be 'name'
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
            $result = Merge-PodeOAProperty   -Type AnyOf -DiscriminatorProperty 'name'  -ObjectDefinitions @('Pet',
              (New-PodeOAObjectProperty  -Properties  @((New-PodeOAIntProperty -Name 'id'), (New-PodeOAStringProperty -Name 'name'))))
            $result | Should -Not -BeNullOrEmpty
            $result | Should -BeOfType [PSObject]
            $result.type | Should -Be 'AnyOf'
            $result.discriminator.propertyName | Should -Be 'name'
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
                    Merge-PodeOAProperty   -Type AllOf  -DiscriminatorProperty 'name'  -ObjectDefinitions @('Pet',
                (New-PodeOAObjectProperty  -Properties  @((New-PodeOAIntProperty -Name 'id'), (New-PodeOAStringProperty -Name 'name')))
                        # Discriminator parameter is not compatible with allOf
                    ) } | Should -Throw -ExpectedMessage $PodeLocale.discriminatorIncompatibleWithAllOfExceptionMessage
            }

            It 'AllOf and ObjectDefinitions not an object' {
                { Merge-PodeOAProperty   -Type AllOf  -DiscriminatorProperty 'name'  -ObjectDefinitions @('Pet',
                    ((New-PodeOAIntProperty -Name 'id'), (New-PodeOAStringProperty -Name 'name'))
                    ) } | Should  -Throw -ExpectedMessage ($PodeLocale.propertiesTypeObjectAssociationExceptionMessage -f 'allOf') # Only properties of type Object can be associated with allOf
            }

        }
    }
    Context 'Add-PodeOAInfo' {

        # Check if the function exists
        It 'Add-PodeOAInfo function exists' {
            Get-Command Add-PodeOAInfo | Should -Not -Be $null
        }

        It 'Valid values' {
            Add-PodeOAInfo  -Title 'Swagger Petstore - OpenAPI 3.0' -Version 1.0.17 -Description 'A description' `
                -TermsOfService 'http://swagger.io/terms/' -LicenseName 'Apache 2.0' -LicenseUrl 'http://www.apache.org/licenses/LICENSE-2.0.html' `
                -ContactName 'API Support' -ContactEmail 'apiteam@swagger.io' -ContactUrl 'http://example.com/support'
            $PodeContext.Server.OpenAPI.Definitions['default'].info | Should -Not -BeNullOrEmpty
            $PodeContext.Server.OpenAPI.Definitions['default'].info.title | Should -Be 'Swagger Petstore - OpenAPI 3.0'
            $PodeContext.Server.OpenAPI.Definitions['default'].info.version | Should -Be '1.0.17'
            $PodeContext.Server.OpenAPI.Definitions['default'].info.description | Should -Be 'A description'
            $PodeContext.Server.OpenAPI.Definitions['default'].info.license | Should -Not -BeNullOrEmpty
            $PodeContext.Server.OpenAPI.Definitions['default'].info.license.name | Should -Be 'Apache 2.0'
            $PodeContext.Server.OpenAPI.Definitions['default'].info.license.url | Should -Be 'http://www.apache.org/licenses/LICENSE-2.0.html'
            $PodeContext.Server.OpenAPI.Definitions['default'].info.contact | Should -Not -BeNullOrEmpty
            $PodeContext.Server.OpenAPI.Definitions['default'].info.contact.name | Should -Be 'API Support'
            $PodeContext.Server.OpenAPI.Definitions['default'].info.contact.email | Should -Be 'apiteam@swagger.io'
            $PodeContext.Server.OpenAPI.Definitions['default'].info.contact.url | Should -Be 'http://example.com/support'
        }
    }

    Context 'New-PodeOAExternalDoc' {

        # Check if the function exists
        It 'New-PodeOAExternalDoc function exists' {
            Get-Command New-PodeOAExternalDoc | Should -Not -Be $null
        }

        It 'Valid values' {
            $SwaggerDocs = New-PodeOAExternalDoc  -Description 'Find out more about Swagger' -Url 'http://swagger.io'
            $SwaggerDocs | Should -Not -BeNullOrEmpty
            $SwaggerDocs.description | Should -Be  'Find out more about Swagger'
            $SwaggerDocs.url | Should -Be 'http://swagger.io'
        }
    }


    Context 'Add-PodeOAExternalDoc' {

        # Check if the function exists
        It 'Add-PodeOAExternalDoc function exists' {
            Get-Command Add-PodeOAExternalDoc | Should -Not -Be $null
        }

        It 'values' {
            Add-PodeOAExternalDoc -Description 'Find out more about Swagger' -Url 'http://swagger.io'
            $PodeContext.Server.OpenAPI.Definitions['default'].externalDocs | Should -Not -BeNullOrEmpty
            $PodeContext.Server.OpenAPI.Definitions['default'].externalDocs.description | Should -Be  'Find out more about Swagger'
            $PodeContext.Server.OpenAPI.Definitions['default'].externalDocs.url | Should -Be 'http://swagger.io'
        }

        It 'Pipe' {
            New-PodeOAExternalDoc  -Description 'Find out more about Swagger' -Url 'http://swagger.io' | Add-PodeOAExternalDoc
            $PodeContext.Server.OpenAPI.Definitions['default'].externalDocs | Should -Not -BeNullOrEmpty
            $PodeContext.Server.OpenAPI.Definitions['default'].externalDocs.description | Should -Be  'Find out more about Swagger'
            $PodeContext.Server.OpenAPI.Definitions['default'].externalDocs.url | Should -Be 'http://swagger.io'
        }


    }

    Context 'Add-PodeOATag' {
        # Check if the function exists
        It 'Add-PodeOATag function exists' {
            Get-Command Add-PodeOATag | Should -Not -Be $null
        }

        It 'Valid values' {
            $SwaggerDocs = New-PodeOAExternalDoc  -Description 'Find out more about Swagger' -Url 'http://swagger.io'
            Add-PodeOATag -Name 'user' -Description 'Operations about user' -ExternalDoc $SwaggerDocs
            $PodeContext.Server.OpenAPI.Definitions['default'].tags['user'] | Should -Not -BeNullOrEmpty
            $PodeContext.Server.OpenAPI.Definitions['default'].tags['user'].name | Should -Be 'user'
            $PodeContext.Server.OpenAPI.Definitions['default'].tags['user'].description | Should -Be  'Operations about user'
            $PodeContext.Server.OpenAPI.Definitions['default'].tags['user'].externalDocs | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
            $PodeContext.Server.OpenAPI.Definitions['default'].tags['user'].externalDocs.Count | Should -Be 2
            $PodeContext.Server.OpenAPI.Definitions['default'].tags['user'].externalDocs.url | Should -Be 'http://swagger.io'
            $PodeContext.Server.OpenAPI.Definitions['default'].tags['user'].externalDocs.description | Should -Be 'Find out more about Swagger'
        }
    }



    Context 'Set-PodeOARouteInfo single route' {
        BeforeEach {
            $Route = @{
                OpenApi = @{
                    Path               = '/test'
                    Responses          = [ordered]@{
                        '200'     = @{ description = 'OK' }
                        'default' = @{ description = 'Internal server error' }
                    }
                    Parameters         = [ordered]@{}
                    RequestBody        = [ordered]@{}
                    callbacks          = [ordered]@{}
                    Authentication     = @()
                    DefinitionTag      = @('Default')
                    IsDefTagConfigured = $false
                }
            }

            Add-PodeOATag -Name 'pet' -Description 'Everything about your Pets' -ExternalDoc  (New-PodeOAExternalDoc   -Description 'Find out more about Swagger' -Url 'http://swagger.io')
        }

        # Check if the function exists
        It 'Set-PodeOARouteInfo function exists' {
            Get-Command Set-PodeOARouteInfo | Should -Not -Be $null
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

    Context 'Set-PodeOARouteInfo multi routes' {
        BeforeEach {
            $Route = @(@{
                    OpenApi = @{
                        Path           = '/test'
                        Responses      = @{
                            '200'     = @{ description = 'OK' }
                            'default' = @{ description = 'Internal server error' }
                        }
                        Parameters     = $null
                        RequestBody    = $null
                        Authentication = @()
                        DefinitionTag  = @('Default')
                    }
                },
                @{
                    OpenApi = @{
                        Path           = '/test2'
                        Responses      = @{
                            '200'     = @{ description = 'OK' }
                            'default' = @{ description = 'Internal server error' }
                        }
                        Parameters     = $null
                        RequestBody    = $null
                        Authentication = @()
                        DefinitionTag  = @('Default')
                    }
                })

            Add-PodeOATag -Name 'pet' -Description 'Everything about your Pets' -ExternalDoc  (New-PodeOAExternalDoc   -Description 'Find out more about Swagger' -Url 'http://swagger.io')
        }

        It 'No switches' {
            $Route | Set-PodeOARouteInfo -Summary 'Update an existing pet' -Description 'Update an existing pet by Id' -Tags 'pet'
            $Route.OpenApi | Should -Not -BeNullOrEmpty
            $Route.OpenApi.Summary | Should -Be @('Update an existing pet', 'Update an existing pet')
            $Route.OpenApi.description | Should -Be @('Update an existing pet by Id', 'Update an existing pet by Id')
            $Route.OpenApi.tags | Should -Be  @('pet', 'pet')
            $Route.OpenApi.swagger | Should -BeTrue
            $Route.OpenApi.deprecated | Should -BeNullOrEmpty
        }
        It 'Deprecated' {
            $Route | Set-PodeOARouteInfo -Summary 'Update an existing pet' -Description 'Update an existing pet by Id' -Tags 'pet'   -Deprecated
            $Route.OpenApi | Should -Not -BeNullOrEmpty
            $Route.OpenApi.Summary | Should -Be @('Update an existing pet', 'Update an existing pet')
            $Route.OpenApi.description | Should -Be @('Update an existing pet by Id', 'Update an existing pet by Id')
            $Route.OpenApi.tags | Should -Be  @('pet', 'pet')
            $Route.OpenApi.swagger | Should -BeTrue
            $Route.OpenApi.deprecated | Should -BeTrue
        }

        It 'PassThru' {
            $result = $Route | Set-PodeOARouteInfo -Summary 'Update an existing pet' -Description 'Update an existing pet by Id' -Tags 'pet' -PassThru
            $result | Should -Not -BeNullOrEmpty
            $result.OpenApi | Should -Not -BeNullOrEmpty
            $Route.OpenApi.Summary | Should -Be @('Update an existing pet', 'Update an existing pet')
            $Route.OpenApi.description | Should -Be @('Update an existing pet by Id', 'Update an existing pet by Id')
            $Route.OpenApi.tags | Should -Be  @('pet', 'pet')
            $result.OpenApi.swagger | Should -BeTrue
            $result.OpenApi.deprecated | Should -BeNullOrEmpty
        }

        It 'PassThru with OperationID' {
            { $Route | Set-PodeOARouteInfo -Summary 'Update an existing pet' -Description 'Update an existing pet by Id' -Tags 'pet' -OperationId 'updatePet' -PassThru } |
                Should -Throw -ExpectedMessage ($PodeLocale.operationIdMustBeUniqueForArrayExceptionMessage -f 'updatePet') #'OperationID: {0} has to be unique and cannot be applied to an array.'
        }
    }

    Context 'Add-PodeOAComponentParameter' {

        # Check if the function exists
        It 'Add-PodeOAComponentParameter function exists' {
            Get-Command Add-PodeOAComponentParameter | Should -Not -Be $null
        }

        it 'default' {
            Add-PodeOAComponentParameter -Name 'PetIdParam' -Parameter ( New-PodeOAIntProperty -Name 'petId' -Format Int64 -Description 'ID of the pet' -Required)
            $result = $PodeContext.Server.OpenAPI.Definitions['default'].components.parameters['PetIdParam']
            $result | Should -Not -BeNullOrEmpty
            $result | Should -BeOfType [hashtable]
            $result.Count | Should -Be 5
            #$result.Count | Should -Be 0
            $result.name | Should -Be 'petId'
            $result.description | Should -Be 'ID of the pet'
            $result.type | Should -Be 'integer'
            $result.format | Should -Be 'int64'
            $result.required | Should -BeTrue
        }
        it 'From Pipeline' {
            New-PodeOAIntProperty -Name 'petId' -Format Int64 -Description 'ID of the pet' -Required | Add-PodeOAComponentParameter -Name 'PetIdParam'
            $result = $PodeContext.Server.OpenAPI.Definitions['default'].components.parameters['PetIdParam']
            $result | Should -Not -BeNullOrEmpty
            $result | Should -BeOfType [hashtable]
            $result.Count | Should -Be 5
            $result.name | Should -Be 'petId'
            $result.description | Should -Be 'ID of the pet'
            $result.type | Should -Be 'integer'
            $result.format | Should -Be 'int64'
            $result.required | Should -BeTrue
        }
        it 'throw error' {
            {
                Add-PodeOAComponentParameter   -Parameter ( New-PodeOAIntProperty -Name 'petId' -Format Int64 -Description 'ID of the pet' | New-PodeOAObjectProperty ) } |
                Should -Throw -ExpectedMessage $PodeLocale.parameterHasNoNameExceptionMessage # The Parameter has no name. Please give this component a name using the 'Name' parameter.
        }
    }
    Context 'ConvertTo-PodeOAParameter' {

        # Check if the function exists
        It 'ConvertTo-PodeOAParameter function exists' {
            Get-Command ConvertTo-PodeOAParameter | Should -Not -Be $null
        }

        Describe 'ConvertTo-PodeOAParameter - Path' {

            It 'Path - Properties - No switches' {
                $result = New-PodeOAIntProperty -Name 'petId' -Format Int64 -Description 'ID of the pet' -Required -Array | ConvertTo-PodeOAParameter -In Path
                $result | Should -Not -BeNullOrEmpty
                $result | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.name | Should -Be 'petId'
                $result.description | Should -Be 'ID of the pet'
                $result.in | Should -Be 'path'
                $result.explode | Should -BeFalse
                $result.allowEmptyValue | Should -BeFalse
                $result.deprecated | Should -BeFalse
                $result.style | Should -BeNullOrEmpty
                $result.required | Should -BeTrue
                $result.schema | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.schema.Count | Should -Be 2
                $result.schema.type | Should -Be 'array'
                $result.schema.items | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.schema.items.Count | Should -Be 2
                $result.schema.items.type | Should -Be 'integer'
                $result.schema.items.format | Should -Be 'int64'
            }

            It 'Path - Properties - Explode' {
                $result = New-PodeOAIntProperty -Name 'petId' -Format Int64 -Description 'ID of the pet' -Required -Array | ConvertTo-PodeOAParameter -In Path -Explode
                $result | Should -Not -BeNullOrEmpty
                $result | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.name | Should -Be 'petId'
                $result.description | Should -Be 'ID of the pet'
                $result.in | Should -Be 'path'
                $result.required | Should -BeTrue
                $result.explode | Should -BeTrue
                $result.allowEmptyValue | Should -BeFalse
                $result.deprecated | Should -BeFalse
                $result.style | Should -BeNullOrEmpty
                $result.schema | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.schema.Count | Should -Be 2
                $result.schema.type | Should -Be 'array'
                $result.schema.items | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.schema.items.Count | Should -Be 2
                $result.schema.items.type | Should -Be 'integer'
                $result.schema.items.format | Should -Be 'int64'
            }

            It 'Path - -ComponentParameter - No switches' {
                Add-PodeOAComponentParameter -Name 'PetIdParam' -Parameter ( New-PodeOAIntProperty -Name 'petId' -Format Int64 -Description 'ID of the pet' -Required | ConvertTo-PodeOAParameter -In Path )
                $result = ConvertTo-PodeOAParameter -ComponentParameter 'PetIdParam'
                $result | Should -Not -BeNullOrEmpty
                $result | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.Count | Should -Be 1
                $result['$ref'] | Should -Be '#/components/parameters/PetIdParam'
            }
            Describe 'ContentSchema' {

                BeforeEach {
                    Add-PodeOAComponentSchema -Name 'Cat' -Schema (
                        New-PodeOAObjectProperty  -Properties  @(
                        (New-PodeOABoolProperty -Name 'friendly'),
                            (New-PodeOAStringProperty -Name 'name')
                        ))
                }
                It 'Path - ContentSchema - No switches' {
                    $result = ConvertTo-PodeOAParameter -In Path -Description 'Feline description' -ContentType 'application/json' -Schema  'Cat' -Required
                    $result | Should -Not -BeNullOrEmpty
                    $result | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                    $result.Count | Should -Be 5
                    $result.name | Should -Be 'Cat'
                    $result.in | Should -Be 'path'
                    $result.description | Should -Be 'Feline description'
                    $result.required | Should -BeTrue
                    $result.allowEmptyValue | Should -BeFalse
                    $result.content | Should -Not -BeNullOrEmpty
                    $result.content | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                    $result.content.Count | Should -Be 1
                    $result.content.'application/json' | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                    $result.content.'application/json'.Count | Should -Be 1
                    $result.content.'application/json'.schema | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                    $result.content.'application/json'.schema.Count | Should -Be 1
                    $result.content.'application/json'.schema['$ref'] | Should -Be '#/components/schemas/Cat'
                }

                It 'Path - ContentSchema - Required' {
                    $result = ConvertTo-PodeOAParameter -In Path -Description 'Feline description' -ContentType 'application/json' -Schema  'Cat' -Required
                    $result | Should -Not -BeNullOrEmpty
                    $result | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                    $result.Count | Should -Be 5
                    $result.name | Should -Be 'Cat'
                    $result.in | Should -Be 'path'
                    $result.description | Should -Be 'Feline description'
                    $result.required | Should -BeTrue
                    $result.allowEmptyValue | Should -BeFalse
                    $result.content | Should -Not -BeNullOrEmpty
                    $result.content | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                    $result.content.Count | Should -Be 1
                    $result.content.'application/json' | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                    $result.content.'application/json'.Count | Should -Be 1
                    $result.content.'application/json'.schema | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                    $result.content.'application/json'.schema.Count | Should -Be 1
                    $result.content.'application/json'.schema['$ref'] | Should -Be '#/components/schemas/Cat'
                }

                It 'Path - ContentSchema - AllowEmptyValue' {
                    $result = ConvertTo-PodeOAParameter -In Path -Description 'Feline description' -ContentType 'application/json' -Schema 'Cat' -AllowEmptyValue -Required
                    $result | Should -Not -BeNullOrEmpty
                    $result | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                    $result.Count | Should -Be 6
                    $result.name | Should -Be 'Cat'
                    $result.in | Should -Be 'path'
                    $result.description | Should -Be 'Feline description'
                    $result.required | Should -BeTrue
                    $result.allowEmptyValue | Should -BeTrue
                    $result.content | Should -Not -BeNullOrEmpty
                    $result.content | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                    $result.content.Count | Should -Be 1
                    $result.content.'application/json' | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                    $result.content.'application/json'.Count | Should -Be 1
                    $result.content.'application/json'.schema | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                    $result.content.'application/json'.schema.Count | Should -Be 1
                    $result.content.'application/json'.schema['$ref'] | Should -Be '#/components/schemas/Cat'
                }

                It 'Path - ContentSchema - Exception -Required' {
                    { ConvertTo-PodeOAParameter -In Path -Description 'Feline description' -ContentType 'application/json' -Schema 'Cat' } |
                        Should -Throw -ExpectedMessage $PodeLocale.pathParameterRequiresRequiredSwitchExceptionMessage   # If the parameter location is 'Path', the switch parameter 'Required' is mandatory
                }
            }
        }

        Describe 'ConvertTo-PodeOAParameter - Header' {

            It 'Header - Properties - No switches' {
                $result = New-PodeOAIntProperty -Name 'petId' -Format Int64 -Description 'ID of the pet' -Required -Array | ConvertTo-PodeOAParameter -In Header
                $result | Should -Not -BeNullOrEmpty
                $result | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.name | Should -Be 'petId'
                $result.description | Should -Be 'ID of the pet'
                $result.in | Should -Be 'header'
                $result.explode | Should -BeFalse
                $result.allowEmptyValue | Should -BeFalse
                $result.deprecated | Should -BeFalse
                $result.style | Should -BeNullOrEmpty
                $result.required | Should -BeTrue
                $result.schema | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.schema.Count | Should -Be 2
                $result.schema.type | Should -Be 'array'
                $result.schema.items | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.schema.items.Count | Should -Be 2
                $result.schema.items.type | Should -Be 'integer'
                $result.schema.items.format | Should -Be 'int64'
            }

            It 'Header - Properties - Explode' {
                $result = New-PodeOAIntProperty -Name 'petId' -Format Int64 -Description 'ID of the pet' -Required -Array | ConvertTo-PodeOAParameter -In Header -Explode
                $result | Should -Not -BeNullOrEmpty
                $result | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.name | Should -Be 'petId'
                $result.description | Should -Be 'ID of the pet'
                $result.in | Should -Be 'header'
                $result.required | Should -BeTrue
                $result.explode | Should -BeTrue
                $result.allowEmptyValue | Should -BeFalse
                $result.deprecated | Should -BeFalse
                $result.style | Should -BeNullOrEmpty
                $result.schema | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.schema.Count | Should -Be 2
                $result.schema.type | Should -Be 'array'
                $result.schema.items | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.schema.items.Count | Should -Be 2
                $result.schema.items.type | Should -Be 'integer'
                $result.schema.items.format | Should -Be 'int64'
            }

            It 'Header - Properties - No switches' {
                $result = New-PodeOAIntProperty -Name 'petId' -Format Int64 -Description 'ID of the pet' -Required -Array | ConvertTo-PodeOAParameter -In Header
                $result | Should -Not -BeNullOrEmpty
                $result | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.name | Should -Be 'petId'
                $result.description | Should -Be 'ID of the pet'
                $result.in | Should -Be 'header'
                $result.required | Should -BeTrue
                $result.schema | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.schema.Count | Should -Be 2
                $result.schema.type | Should -Be 'array'
                $result.schema.items | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.schema.items.Count | Should -Be 2
                $result.schema.items.type | Should -Be 'integer'
                $result.schema.items.format | Should -Be 'int64'
            }

            It 'Header - -ComponentParameter - No switches' {
                Add-PodeOAComponentParameter -Name 'PetIdParam' -Parameter ( New-PodeOAIntProperty -Name 'petId' -Format Int64 -Description 'ID of the pet' -Required | ConvertTo-PodeOAParameter -In Header )
                $result = ConvertTo-PodeOAParameter -ComponentParameter 'PetIdParam'
                $result | Should -Not -BeNullOrEmpty
                $result | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.Count | Should -Be 1
                $result['$ref'] | Should -Be '#/components/parameters/PetIdParam'
            }

            It 'Header - ContentSchema - No switches' {
                Add-PodeOAComponentSchema -Name 'Cat' -Schema (
                    New-PodeOAObjectProperty  -Properties  @(
                    (New-PodeOABoolProperty -Name 'friendly'),
                        (New-PodeOAStringProperty -Name 'name')
                    ))
                $result = ConvertTo-PodeOAParameter -In Header -Description 'Feline description' -ContentType 'application/json' -Schema  'Cat'
                $result | Should -Not -BeNullOrEmpty
                $result | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.Count | Should -Be 4
                $result.name | Should -Be 'Cat'
                $result.in | Should -Be 'header'
                $result.description | Should -Be 'Feline description'
                $result.required | Should -BeFalse
                $result.allowEmptyValue | Should -BeFalse
                $result.content | Should -Not -BeNullOrEmpty
                $result.content | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.content.Count | Should -Be 1
                $result.content.'application/json' | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.content.'application/json'.Count | Should -Be 1
                $result.content.'application/json'.schema | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.content.'application/json'.schema.Count | Should -Be 1
                $result.content.'application/json'.schema['$ref'] | Should -Be '#/components/schemas/Cat'
            }

            It 'Header - ContentSchema - Required' {
                Add-PodeOAComponentSchema -Name 'Cat' -Schema (
                    New-PodeOAObjectProperty  -Properties  @(
                    (New-PodeOABoolProperty -Name 'friendly'),
                        (New-PodeOAStringProperty -Name 'name')
                    ))
                $result = ConvertTo-PodeOAParameter -In Header -Description 'Feline description' -ContentType 'application/json' -Schema  'Cat' -Required
                $result | Should -Not -BeNullOrEmpty
                $result | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.Count | Should -Be 5
                $result.name | Should -Be 'Cat'
                $result.in | Should -Be 'header'
                $result.description | Should -Be 'Feline description'
                $result.required | Should -BeTrue
                $result.allowEmptyValue | Should -BeFalse
                $result.content | Should -Not -BeNullOrEmpty
                $result.content | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.content.Count | Should -Be 1
                $result.content.'application/json' | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.content.'application/json'.Count | Should -Be 1
                $result.content.'application/json'.schema | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.content.'application/json'.schema.Count | Should -Be 1
                $result.content.'application/json'.schema['$ref'] | Should -Be '#/components/schemas/Cat'
            }

            It 'Header - ContentSchema - AllowEmptyValue' {
                Add-PodeOAComponentSchema -Name 'Cat' -Schema (
                    New-PodeOAObjectProperty  -Properties  @(
                    (New-PodeOABoolProperty -Name 'friendly'),
                        (New-PodeOAStringProperty -Name 'name')
                    ))
                $result = ConvertTo-PodeOAParameter -In Header -Description 'Feline description' -ContentType 'application/json' -Schema  'Cat' -AllowEmptyValue
                $result | Should -Not -BeNullOrEmpty
                $result | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.Count | Should -Be 5
                $result.name | Should -Be 'Cat'
                $result.in | Should -Be 'header'
                $result.description | Should -Be 'Feline description'
                $result.required | Should -BeFalse
                $result.allowEmptyValue | Should -BeTrue
                $result.content | Should -Not -BeNullOrEmpty
                $result.content | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.content.Count | Should -Be 1
                $result.content.'application/json' | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.content.'application/json'.Count | Should -Be 1
                $result.content.'application/json'.schema | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.content.'application/json'.schema.Count | Should -Be 1
                $result.content.'application/json'.schema['$ref'] | Should -Be '#/components/schemas/Cat'
            }
        }


        Describe 'ConvertTo-PodeOAParameter - Cookie' {

            It 'Cookie - Properties - No switches' {
                $result = New-PodeOAIntProperty -Name 'petId' -Format Int64 -Description 'ID of the pet' -Required -Array | ConvertTo-PodeOAParameter -In Cookie
                $result | Should -Not -BeNullOrEmpty
                $result | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.name | Should -Be 'petId'
                $result.description | Should -Be 'ID of the pet'
                $result.in | Should -Be 'cookie'
                $result.explode | Should -BeFalse
                $result.allowEmptyValue | Should -BeFalse
                $result.deprecated | Should -BeFalse
                $result.style | Should -BeNullOrEmpty
                $result.required | Should -BeTrue
                $result.schema | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.schema.Count | Should -Be 2
                $result.schema.type | Should -Be 'array'
                $result.schema.items | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.schema.items.Count | Should -Be 2
                $result.schema.items.type | Should -Be 'integer'
                $result.schema.items.format | Should -Be 'int64'
            }

            It 'Cookie - Properties - Explode' {
                $result = New-PodeOAIntProperty -Name 'petId' -Format Int64 -Description 'ID of the pet' -Required -Array | ConvertTo-PodeOAParameter -In Cookie -Explode
                $result | Should -Not -BeNullOrEmpty
                $result | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.name | Should -Be 'petId'
                $result.description | Should -Be 'ID of the pet'
                $result.in | Should -Be 'cookie'
                $result.required | Should -BeTrue
                $result.explode | Should -BeTrue
                $result.allowEmptyValue | Should -BeFalse
                $result.deprecated | Should -BeFalse
                $result.style | Should -BeNullOrEmpty
                $result.schema | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.schema.Count | Should -Be 2
                $result.schema.type | Should -Be 'array'
                $result.schema.items | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.schema.items.Count | Should -Be 2
                $result.schema.items.type | Should -Be 'integer'
                $result.schema.items.format | Should -Be 'int64'
            }
            It 'Cookie - Properties - No switches' {
                $result = New-PodeOAIntProperty -Name 'petId' -Format Int64 -Description 'ID of the pet' -Required -Array | ConvertTo-PodeOAParameter -In Cookie
                $result | Should -Not -BeNullOrEmpty
                $result | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.name | Should -Be 'petId'
                $result.description | Should -Be 'ID of the pet'
                $result.in | Should -Be 'cookie'
                $result.required | Should -BeTrue
                $result.schema | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.schema.Count | Should -Be 2
                $result.schema.type | Should -Be 'array'
                $result.schema.items | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.schema.items.Count | Should -Be 2
                $result.schema.items.type | Should -Be 'integer'
                $result.schema.items.format | Should -Be 'int64'
            }

            It 'Cookie - -ComponentParameter - No switches' {
                Add-PodeOAComponentParameter -Name 'PetIdParam' -Parameter ( New-PodeOAIntProperty -Name 'petId' -Format Int64 -Description 'ID of the pet' -Required | ConvertTo-PodeOAParameter -In Cookie )
                $result = ConvertTo-PodeOAParameter -ComponentParameter 'PetIdParam'
                $result | Should -Not -BeNullOrEmpty
                $result | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.Count | Should -Be 1
                $result['$ref'] | Should -Be '#/components/parameters/PetIdParam'
            }

            It 'Cookie - ContentSchema - No switches' {
                Add-PodeOAComponentSchema -Name 'Cat' -Schema (
                    New-PodeOAObjectProperty  -Properties  @(
                    (New-PodeOABoolProperty -Name 'friendly'),
                        (New-PodeOAStringProperty -Name 'name')
                    ))
                $result = ConvertTo-PodeOAParameter -In Cookie -Description 'Feline description' -ContentType 'application/json' -Schema  'Cat'
                $result | Should -Not -BeNullOrEmpty
                $result | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.Count | Should -Be 4
                $result.name | Should -Be 'Cat'
                $result.in | Should -Be 'cookie'
                $result.description | Should -Be 'Feline description'
                $result.required | Should -BeFalse
                $result.allowEmptyValue | Should -BeFalse
                $result.content | Should -Not -BeNullOrEmpty
                $result.content | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.content.Count | Should -Be 1
                $result.content.'application/json' | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.content.'application/json'.Count | Should -Be 1
                $result.content.'application/json'.schema | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.content.'application/json'.schema.Count | Should -Be 1
                $result.content.'application/json'.schema['$ref'] | Should -Be '#/components/schemas/Cat'
            }

            It 'Cookie - ContentSchema - Required' {
                Add-PodeOAComponentSchema -Name 'Cat' -Schema (
                    New-PodeOAObjectProperty  -Properties  @(
                    (New-PodeOABoolProperty -Name 'friendly'),
                        (New-PodeOAStringProperty -Name 'name')
                    ))
                $result = ConvertTo-PodeOAParameter -In Cookie -Description 'Feline description' -ContentType 'application/json' -Schema  'Cat' -Required
                $result | Should -Not -BeNullOrEmpty
                $result | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.Count | Should -Be 5
                $result.name | Should -Be 'Cat'
                $result.in | Should -Be 'cookie'
                $result.description | Should -Be 'Feline description'
                $result.required | Should -BeTrue
                $result.allowEmptyValue | Should -BeFalse
                $result.content | Should -Not -BeNullOrEmpty
                $result.content | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.content.Count | Should -Be 1
                $result.content.'application/json' | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.content.'application/json'.Count | Should -Be 1
                $result.content.'application/json'.schema | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.content.'application/json'.schema.Count | Should -Be 1
                $result.content.'application/json'.schema['$ref'] | Should -Be '#/components/schemas/Cat'
            }

            It 'Cookie - ContentSchema - AllowEmptyValue' {
                Add-PodeOAComponentSchema -Name 'Cat' -Schema (
                    New-PodeOAObjectProperty  -Properties  @(
                    (New-PodeOABoolProperty -Name 'friendly'),
                        (New-PodeOAStringProperty -Name 'name')
                    ))
                $result = ConvertTo-PodeOAParameter -In Cookie -Description 'Feline description' -ContentType 'application/json' -Schema  'Cat' -AllowEmptyValue
                $result | Should -Not -BeNullOrEmpty
                $result | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.Count | Should -Be 5
                $result.name | Should -Be 'Cat'
                $result.in | Should -Be 'cookie'
                $result.description | Should -Be 'Feline description'
                $result.required | Should -BeFalse
                $result.allowEmptyValue | Should -BeTrue
                $result.content | Should -Not -BeNullOrEmpty
                $result.content | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.content.Count | Should -Be 1
                $result.content.'application/json' | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.content.'application/json'.Count | Should -Be 1
                $result.content.'application/json'.schema | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.content.'application/json'.schema.Count | Should -Be 1
                $result.content.'application/json'.schema['$ref'] | Should -Be '#/components/schemas/Cat'
            }
        }


        Describe 'ConvertTo-PodeOAParameter - Query' {

            It 'Query - Properties - No switches' {
                $result = New-PodeOAIntProperty -Name 'petId' -Format Int64 -Description 'ID of the pet' -Required -Array | ConvertTo-PodeOAParameter -In Query
                $result | Should -Not -BeNullOrEmpty
                $result | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.name | Should -Be 'petId'
                $result.description | Should -Be 'ID of the pet'
                $result.in | Should -Be 'query'
                $result.explode | Should -BeFalse
                $result.allowEmptyValue | Should -BeFalse
                $result.deprecated | Should -BeFalse
                $result.style | Should -BeNullOrEmpty
                $result.required | Should -BeTrue
                $result.schema | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.schema.Count | Should -Be 2
                $result.schema.type | Should -Be 'array'
                $result.schema.items | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.schema.items.Count | Should -Be 2
                $result.schema.items.type | Should -Be 'integer'
                $result.schema.items.format | Should -Be 'int64'
            }

            It 'Query - Properties - Explode' {
                $result = New-PodeOAIntProperty -Name 'petId' -Format Int64 -Description 'ID of the pet' -Required -Array | ConvertTo-PodeOAParameter -In Query -Explode
                $result | Should -Not -BeNullOrEmpty
                $result | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.name | Should -Be 'petId'
                $result.description | Should -Be 'ID of the pet'
                $result.in | Should -Be 'query'
                $result.required | Should -BeTrue
                $result.explode | Should -BeTrue
                $result.allowEmptyValue | Should -BeFalse
                $result.deprecated | Should -BeFalse
                $result.style | Should -BeNullOrEmpty
                $result.schema | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.schema.Count | Should -Be 2
                $result.schema.type | Should -Be 'array'
                $result.schema.items | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.schema.items.Count | Should -Be 2
                $result.schema.items.type | Should -Be 'integer'
                $result.schema.items.format | Should -Be 'int64'
            }

            It 'Query - Properties - No switches' {
                $result = New-PodeOAIntProperty -Name 'petId' -Format Int64 -Description 'ID of the pet' -Required -Array | ConvertTo-PodeOAParameter -In Query
                $result | Should -Not -BeNullOrEmpty
                $result | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.name | Should -Be 'petId'
                $result.description | Should -Be 'ID of the pet'
                $result.in | Should -Be 'query'
                $result.required | Should -BeTrue
                $result.schema | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.schema.Count | Should -Be 2
                $result.schema.type | Should -Be 'array'
                $result.schema.items | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.schema.items.Count | Should -Be 2
                $result.schema.items.type | Should -Be 'integer'
                $result.schema.items.format | Should -Be 'int64'
            }

            It 'Query - -ComponentParameter - No switches' {
                Add-PodeOAComponentParameter -Name 'PetIdParam' -Parameter ( New-PodeOAIntProperty -Name 'petId' -Format Int64 -Description 'ID of the pet' -Required | ConvertTo-PodeOAParameter -In Query )
                $result = ConvertTo-PodeOAParameter -ComponentParameter 'PetIdParam'
                $result | Should -Not -BeNullOrEmpty
                $result | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.Count | Should -Be 1
                $result['$ref'] | Should -Be '#/components/parameters/PetIdParam'
            }

            It 'Query - ContentSchema - No switches' {
                Add-PodeOAComponentSchema -Name 'Cat' -Schema (
                    New-PodeOAObjectProperty  -Properties  @(
                    (New-PodeOABoolProperty -Name 'friendly'),
                        (New-PodeOAStringProperty -Name 'name')
                    ))
                $result = ConvertTo-PodeOAParameter -In Query -Description 'Feline description' -ContentType 'application/json' -Schema  'Cat'
                $result | Should -Not -BeNullOrEmpty
                $result | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.Count | Should -Be 4
                $result.name | Should -Be 'Cat'
                $result.in | Should -Be 'query'
                $result.description | Should -Be 'Feline description'
                $result.required | Should -BeFalse
                $result.allowEmptyValue | Should -BeFalse
                $result.content | Should -Not -BeNullOrEmpty
                $result.content | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.content.Count | Should -Be 1
                $result.content.'application/json' | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.content.'application/json'.Count | Should -Be 1
                $result.content.'application/json'.schema | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.content.'application/json'.schema.Count | Should -Be 1
                $result.content.'application/json'.schema['$ref'] | Should -Be '#/components/schemas/Cat'
            }

            It 'Query - ContentSchema - Required' {
                Add-PodeOAComponentSchema -Name 'Cat' -Schema (
                    New-PodeOAObjectProperty  -Properties  @(
                    (New-PodeOABoolProperty -Name 'friendly'),
                        (New-PodeOAStringProperty -Name 'name')
                    ))
                $result = ConvertTo-PodeOAParameter -In Query -Description 'Feline description' -ContentType 'application/json' -Schema  'Cat' -Required
                $result | Should -Not -BeNullOrEmpty
                $result | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.Count | Should -Be 5
                $result.name | Should -Be 'Cat'
                $result.in | Should -Be 'query'
                $result.description | Should -Be 'Feline description'
                $result.required | Should -BeTrue
                $result.allowEmptyValue | Should -BeFalse
                $result.content | Should -Not -BeNullOrEmpty
                $result.content | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.content.Count | Should -Be 1
                $result.content.'application/json' | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.content.'application/json'.Count | Should -Be 1
                $result.content.'application/json'.schema | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.content.'application/json'.schema.Count | Should -Be 1
                $result.content.'application/json'.schema['$ref'] | Should -Be '#/components/schemas/Cat'
            }

            It 'Query - ContentSchema - AllowEmptyValue' {
                Add-PodeOAComponentSchema -Name 'Cat' -Schema (
                    New-PodeOAObjectProperty  -Properties  @(
                    (New-PodeOABoolProperty -Name 'friendly'),
                        (New-PodeOAStringProperty -Name 'name')
                    ))
                $result = ConvertTo-PodeOAParameter -In Query -Description 'Feline description' -ContentType 'application/json' -Schema  'Cat' -AllowEmptyValue
                $result | Should -Not -BeNullOrEmpty
                $result | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.Count | Should -Be 5
                $result.name | Should -Be 'Cat'
                $result.in | Should -Be 'query'
                $result.description | Should -Be 'Feline description'
                $result.required | Should -BeFalse
                $result.allowEmptyValue | Should -BeTrue
                $result.content | Should -Not -BeNullOrEmpty
                $result.content | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.content.Count | Should -Be 1
                $result.content.'application/json' | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.content.'application/json'.Count | Should -Be 1
                $result.content.'application/json'.schema | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
                $result.content.'application/json'.schema.Count | Should -Be 1
                $result.content.'application/json'.schema['$ref'] | Should -Be '#/components/schemas/Cat'
            }
        }
    }
    Describe 'Add-PodeOAComponentRequestBody' {
        BeforeEach {
            Add-PodeOAComponentSchema -Name 'Cat' -Schema (
                New-PodeOAObjectProperty  -Properties  @(
                    (New-PodeOABoolProperty -Name 'friendly'),
                        (New-PodeOAStringProperty -Name 'name')
                ))
        }
        # Check if the function exists
        It 'Add-PodeOAComponentRequestBody function exists' {
            Get-Command Add-PodeOAComponentRequestBody | Should -Not -Be $null
        }

        it 'default' {
            Add-PodeOAComponentRequestBody -Name 'PetBodySchema' -Required -Description 'Pet in the store' -Content ( New-PodeOAContentMediaType -ContentType 'application/json' , 'application/xml', 'application/x-www-form-urlencoded' -Content 'Cat'  )
            $result = $PodeContext.Server.OpenAPI.Definitions['default'].components.requestBodies['PetBodySchema']
            $result | Should -Not -BeNullOrEmpty
            $result | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
            $result.Count | Should -Be 3
            $result.description | Should -Be 'Pet in the store'
            $result.content | Should -BeOfType  [System.Collections.Specialized.OrderedDictionary]
            $result.content.Count | Should -Be 3
            $result.content.'application/json' | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
            $result.content.'application/json'.Count | Should -Be 1
            $result.content.'application/json'.schema | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
            $result.content.'application/json'.schema.Count | Should -Be 1
            $result.content.'application/json'.schema['$ref'] | Should -Be '#/components/schemas/Cat'
            $result.content.'application/xml' | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
            $result.content.'application/xml'.Count | Should -Be 1
            $result.content.'application/xml'.schema | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
            $result.content.'application/xml'.schema.Count | Should -Be 1
            $result.content.'application/xml'.schema['$ref'] | Should -Be '#/components/schemas/Cat'
            $result.content.'application/x-www-form-urlencoded' | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
            $result.content.'application/x-www-form-urlencoded'.Count | Should -Be 1
            $result.content.'application/x-www-form-urlencoded'.schema | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
            $result.content.'application/x-www-form-urlencoded'.schema.Count | Should -Be 1
            $result.content.'application/x-www-form-urlencoded'.schema['$ref'] | Should -Be '#/components/schemas/Cat'
            $result.required | Should -BeTrue
        }
        it 'From Pipeline' {
            $ContentSchema = @{ 'application/json' = 'Cat'; 'application/xml' = 'Cat'; 'application/x-www-form-urlencoded' = 'Cat' }
            $ContentSchema | Add-PodeOAComponentRequestBody -Name 'PetBodySchema' -Required -Description 'Pet in the store'
            $result = $PodeContext.Server.OpenAPI.Definitions['default'].components.requestBodies['PetBodySchema']
            $result | Should -Not -BeNullOrEmpty
            $result | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
            $result.Count | Should -Be 3
            $result.description | Should -Be 'Pet in the store'
            $result.content | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
            $result.content.Count | Should -Be 3
            $result.content.'application/json' | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
            $result.content.'application/json'.Count | Should -Be 1
            $result.content.'application/json'.schema | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
            $result.content.'application/json'.schema.Count | Should -Be 1
            $result.content.'application/json'.schema['$ref'] | Should -Be '#/components/schemas/Cat'
            $result.content.'application/xml' | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
            $result.content.'application/xml'.Count | Should -Be 1
            $result.content.'application/xml'.schema | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
            $result.content.'application/xml'.schema.Count | Should -Be 1
            $result.content.'application/xml'.schema['$ref'] | Should -Be '#/components/schemas/Cat'
            $result.content.'application/x-www-form-urlencoded' | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
            $result.content.'application/x-www-form-urlencoded'.Count | Should -Be 1
            $result.content.'application/x-www-form-urlencoded'.schema | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
            $result.content.'application/x-www-form-urlencoded'.schema.Count | Should -Be 1
            $result.content.'application/x-www-form-urlencoded'.schema['$ref'] | Should -Be '#/components/schemas/Cat'
            $result.required | Should -BeTrue
        }
    }

    Describe 'Add-PodeOAComponentHeader' {

        # Check if the function exists
        It 'Add-PodeOAComponentHeader function exists' {
            Get-Command Add-PodeOAComponentHeader | Should -Not -Be $null
        }
        it 'default' {
            Add-PodeOAComponentHeader -Name 'X-Rate-Limit' -Description 'calls per hour allowed by the user'  -Schema (New-PodeOAIntProperty -Format Int32  )
            $PodeContext.Server.OpenAPI.Definitions['default'].components.headers['X-Rate-Limit'] | Should -Not -BeNullOrEmpty
            $result = $PodeContext.Server.OpenAPI.Definitions['default'].components.headers['X-Rate-Limit']
            $result | Should -Not -BeNullOrEmpty
            $result | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
            $result.Count | Should -Be 2
            $result.schema.Count | Should -Be 2
            $result.description | Should -Be 'calls per hour allowed by the user'
            $result.schema.type | Should -Be 'integer'
            $result.schema.format | Should -Be 'int32'
        }
        it 'From Pipeline' {
            New-PodeOAIntProperty -Format Int32 | Add-PodeOAComponentHeader -Name 'X-Rate-Limit' -Description 'calls per hour allowed by the user'
            $PodeContext.Server.OpenAPI.Definitions['default'].components.headers['X-Rate-Limit'] | Should -Not -BeNullOrEmpty
            $result = $PodeContext.Server.OpenAPI.Definitions['default'].components.headers['X-Rate-Limit']
            $result | Should -Not -BeNullOrEmpty
            $result | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
            $result.Count | Should -Be 2
            $result.schema.Count | Should -Be 2
            $result.description | Should -Be 'calls per hour allowed by the user'
            $result.schema.type | Should -Be 'integer'
            $result.schema.format | Should -Be 'int32'
        }
    }


    Describe 'New-PodeOAExample Tests' {

        # Check if the function exists
        It 'New-PodeOAExample function exists' {
            Get-Command New-PodeOAExample | Should -Not -Be $null
        }

        # Test return type
        It 'Returns an OrderedHashtable' {
            $example = New-PodeOAExample -ContentType 'application/json' -Name 'user' -Summary  'JSON Example'  -ExternalValue 'http://external.com'
            $example | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
        }

        # Test output for a single MediaType
        It 'Correctly creates example for a single MediaType' {
            $example = New-PodeOAExample -ContentType 'application/json' -Name 'user' -Summary  'JSON Example'  -ExternalValue 'http://external.com'
            $example['application/json'].Keys -Contains 'user' | Should -Be $true
            $example['application/json']['user'].summary -eq 'JSON Example' | Should -Be $true
            $example['application/json']['user'].externalValue -eq 'http://external.com' | Should -Be $true
        }

        # Test merging behavior
        It 'Correctly merges examples for multiple MediaTypes' {
            $result = New-PodeOAExample -ContentType 'application/json' -Name 'user' -Summary   'JSON Example' -Value '[]' |
                New-PodeOAExample -ContentType 'application/xml' -Name 'user' -Summary 'XML Example' -Value '<>'

            $result.Count -eq 2 | Should -Be $true
            $result['application/json']['user'].summary -eq 'JSON Example' | Should -Be $true
            $result['application/xml']['user'].summary -eq 'XML Example' | Should -Be $true
            $result['application/json']['user'].value -eq '[]' | Should -Be $true
            $result['application/xml']['user'].value -eq '<>' | Should -Be $true
        }
    }


    BeforeAll {
        # Mock the Pode context object
        $PodeContext = @{
            Server = @{
                OpenAPI = @{
                    Definitions = @{
                        components = @{
                            examples = @{}
                        }
                    }
                }
            }
        }

        # Define the function if not already loaded

    }

    Describe 'Add-PodeOAComponentExample Tests' {
        BeforeEach {
            # Mock the Pode context object
            $PodeContext = @{
                Server = @{

                    OpenAPI = @{
                        SelectedDefinitionTag = 'default'
                        Definitions           = @{
                            default = @{
                                components = @{
                                    examples = @{}
                                }
                            }
                        }
                    }
                }
            }
        }

        It 'Adds an example to the OpenAPI components' {
            Add-PodeOAComponentExample -Name 'exampleName' -Summary 'An example summary'  -Value   'Some example value'

            $PodeContext.Server.OpenAPI.Definitions['default'].components.examples['exampleName'].summary | Should -Be 'An example summary'
            $PodeContext.Server.OpenAPI.Definitions['default'].components.examples['exampleName'].value | Should -Be 'Some example value'
        }
    }

    Describe 'Rename-PodeOADefinitionTag' {
        # Mocking the PodeContext to simulate the environment
        BeforeEach {
            $PodeContext = @{
                Server = @{
                    OpenAPI = @{
                        Definitions                 = @{
                            'oldTag' = @{
                                # Mock definition details
                                Description = 'Old tag description'
                            }
                        }
                        SelectedDefinitionTag       = 'oldTag'
                        DefinitionTagSelectionStack = [System.Collections.Stack]@()
                    }
                    Web     = @{
                        OpenApi = @{
                            DefaultDefinitionTag = 'oldTag'
                        }
                    }
                }
            }
        }

        # Test case: Renaming a specific tag
        It 'Renames a specific OpenAPI definition tag' {
            Rename-PodeOADefinitionTag -Tag 'oldTag' -NewTag 'newTag'

            # Check if the new tag exists
            $PodeContext.Server.OpenAPI.Definitions.ContainsKey('newTag') | Should -BeTrue
            # Check if the old tag is removed
            $PodeContext.Server.OpenAPI.Definitions.ContainsKey('oldTag') | Should -BeFalse
            # Check if the selected definition tag is updated
            $PodeContext.Server.OpenAPI.SelectedDefinitionTag | Should -Be 'newTag'
        }

        # Test case: Renaming the default tag
        It 'Renames the default OpenAPI definition tag when Tag parameter is not specified' {
            Rename-PodeOADefinitionTag -NewTag 'newDefaultTag'

            # Check if the new default tag is set
            $PodeContext.Server.Web.OpenApi.DefaultDefinitionTag | Should -Be 'newDefaultTag'
            # Check if the new tag exists
            $PodeContext.Server.OpenAPI.Definitions.ContainsKey('newDefaultTag') | Should -BeTrue
            # Check if the old tag is removed
            $PodeContext.Server.OpenAPI.Definitions.ContainsKey('oldTag') | Should -BeFalse
        }

        # Test case: Error when new tag already exists
        It 'Throws an error when the new tag name already exists' {
            $PodeContext.Server.OpenAPI.Definitions['existingTag'] = @{
                # Mock definition details
                Description = 'Existing tag description'
            }

            { Rename-PodeOADefinitionTag -Tag 'oldTag' -NewTag 'existingTag' } | Should -Throw -ExpectedMessage ($PodeLocale.openApiDefinitionAlreadyExistsExceptionMessage -f 'existingTag')
        }

        # Test case: Error when used inside Select-PodeOADefinition ScriptBlock
        It 'Throws an error when used inside a Select-PodeOADefinition ScriptBlock' {
            $PodeContext.Server.OpenApi.DefinitionTagSelectionStack.Push('dummy')

            { Rename-PodeOADefinitionTag -Tag 'oldTag' -NewTag 'newTag' } | Should -Throw  -ExpectedMessage ($PodeLocale.renamePodeOADefinitionTagExceptionMessage)

            # Clear the stack after test
            $PodeContext.Server.OpenApi.DefinitionTagSelectionStack.Clear()
        }
    }


    Describe 'Set-PodeOARequest' {

        It 'Sets Parameters on the route if provided' {
            $route = @{
                Method  = 'GET'
                OpenApi = @{
                    Responses   = [ordered]@{}
                    Parameters  = [ordered]@{}
                    RequestBody = [ordered]@{}
                    callbacks   = [ordered]@{}
                }
            }
            $parameters = @(
                @{ Name = 'param1'; In = 'query' }
            )

            Set-PodeOARequest -Route $route -Parameters $parameters

            $route.OpenApi.Parameters['Default'] | Should -BeExactly $parameters
        }

        It 'Sets RequestBody on the route if method is POST' {
            $route = @{
                Method  = 'POST'
                OpenApi = @{}
            }
            $requestBody = @{ Content = 'application/json' }

            Set-PodeOARequest -Route $route -RequestBody $requestBody

            $route.OpenApi.RequestBody | Should -BeExactly $requestBody
        }

        It 'Throws an exception if RequestBody is set on a method that does not allow it' {
            $route = @{
                Method  = 'GET'
                OpenApi = @{}
            }
            $requestBody = @{ Content = 'application/json' }

            {
                Set-PodeOARequest -Route $route -RequestBody $requestBody
            } | Should -Throw -ExpectedMessage ($PodeLocale.getRequestBodyNotAllowedExceptionMessage -f 'GET')
        }

        It 'Allows a RequestBody on non-standard methods with AllowNonStandardBody' {
            $route = @{
                Method  = 'DELETE'
                OpenApi = @{}
            }
            $requestBody = @{ Content = 'application/json' }

            Set-PodeOARequest -Route $route -RequestBody $requestBody -AllowNonStandardBody

            $route.OpenApi.RequestBody | Should -BeExactly $requestBody
        }

        It 'Returns the route when PassThru is used' {
            $route = @{
                Method  = 'POST'
                OpenApi = @{}
            }

            $result = Set-PodeOARequest -Route $route -PassThru

            $result | Should -BeExactly $route
        }

        It 'Does not set RequestBody if not provided' {
            $route = @{
                Method  = 'PUT'
                OpenApi = @{}
            }

            Set-PodeOARequest -Route $route

            $route.OpenApi.RequestBody | Should -BeNullOrEmpty
        }

        It 'Sets Parameters with DefinitionTag if provided' {
            $route = @{
                Method  = 'GET'
                OpenApi = @{
                    Responses   = [ordered]@{}
                    Parameters  = [ordered]@{}
                    RequestBody = [ordered]@{}
                    callbacks   = [ordered]@{}
                }
            }
            $parameters = @(
                @{ Name = 'param1'; In = 'query' }
            )

            $definitionTag = 'v1'
            $PodeContext.Server.OpenAPI.Definitions[ $definitionTag] = Get-PodeOABaseObject

            Set-PodeOARequest -Route $route -Parameters $parameters -DefinitionTag $definitionTag

            $route.OpenApi.Parameters[$definitionTag] | Should -BeExactly $parameters
        }

        It 'Defaults Parameters to an empty array if not provided' {
            $route = @{
                Method  = 'GET'
                OpenApi = @{
                    Responses   = [ordered]@{}
                    Parameters  = [ordered]@{}
                    RequestBody = [ordered]@{}
                    callbacks   = [ordered]@{}
                }
            }

            Set-PodeOARequest -Route $route

            $route.OpenApi.Parameters['Default'] | Should -BeNullOrEmpty
        }
    }

    Describe 'Add-PodeOAServerEndpoint' {
        # Mocking Pode related context and functions
        BeforeAll {


            function Test-PodeIsEmpty {
                param ($Value)
                return -not $Value
            }
        }

        Context 'When adding a server with URL and description' {
            It 'Should add the server to the OpenAPI definition' {
                Add-PodeOAServerEndpoint -Url 'https://myserver.io/api' -Description 'My test server'

                $servers = $PodeContext.Server.OpenAPI.Definitions['default'].servers
                $servers | Should -HaveCount 1
                $servers[0].url | Should -Be 'https://myserver.io/api'
                $servers[0].description | Should -Be 'My test server'
            }
        }

        Context 'When adding a server with variables' {
            It 'Should add the server with variables to the OpenAPI definition' {
                $variables = [ordered]@{
                    username = [ordered]@{
                        default     = 'demo'
                        description = 'assigned by provider'
                    }
                    port     = [ordered]@{
                        default = 8443
                    }
                    basePath = [ordered]@{
                        default = 'v2'
                    }
                }

                Add-PodeOAServerEndpoint -Url 'https://{username}.server.com:{port}/{basePath}' -Variables $variables

                $servers = $PodeContext.Server.OpenAPI.Definitions['default'].servers
                $servers | Should -HaveCount 1
                $servers[0].url | Should -Be 'https://{username}.server.com:{port}/{basePath}'
                $servers[0].variables | Should -Be $variables
            }
        }

        Context 'When adding multiple local endpoints' {
            It 'Should throw an error when multiple local URLs are defined' {
                Add-PodeOAServerEndpoint -Url '/api' -Description 'Local endpoint 1'

                { Add-PodeOAServerEndpoint -Url '/api/v2' -Description 'Local endpoint 2' } |
                    Should -Throw "Both '/api/v2' and '/api' are defined as local OpenAPI endpoints, but only one local endpoint is allowed per API definition."
            }
        }


    }


    Context 'Pet Object example' {
        BeforeEach {
            Add-PodeOAComponentSchema -Name 'Category' -Schema (
                New-PodeOAObjectProperty -Name 'Category' -XmlName 'category'  -Properties  (
                    New-PodeOAIntProperty -Name 'id'-Format Int64 -Example 1 |
                        New-PodeOAStringProperty -Name 'name' -Example 'Dogs'
                ))
            Add-PodeOAComponentSchema -Name 'Tag' -Schema (
                New-PodeOAObjectProperty -Name 'Tag' -XmlName 'tag' -Properties  (
                    New-PodeOAIntProperty -Name 'id'-Format Int64 |
                        New-PodeOAStringProperty -Name 'name'
                ))
        }


        It 'By properties' {
            $Pet = New-PodeOAObjectProperty -Name 'Pet' -XmlName 'pet'   -Properties  (
            (New-PodeOAIntProperty -Name 'id'-Format Int64 -Example 10 -ReadOnly ),
                (New-PodeOAStringProperty -Name 'name' -Example 'doggie' -Required) ,
                (New-PodeOAComponentSchemaProperty -Name 'category' -Reference 'Category' ),
                (New-PodeOAStringProperty -Name 'petType' -Example 'dog' -Required) ,
                (New-PodeOAStringProperty -Name 'photoUrls' -Array) ,
                (New-PodeOAComponentSchemaProperty -Name 'tags' -Reference 'Tag') ,
                (New-PodeOAStringProperty -Name 'status' -Description 'pet status in the store' -Enum @('available', 'pending', 'sold'))
            )
            $Pet.type | Should -be 'object'
            $Pet.xml | Should -BeOfType  [System.Collections.Specialized.OrderedDictionary]
            $Pet.xml.Count | Should -Be 1
            $Pet.xml.name | Should -Be 'pet'
            $Pet.name | Should -Be 'Pet'
            $Pet.properties | Should -BeOfType [hashtable]
            $Pet.properties.Count | Should -Be 7

            $Pet.properties[0].type | Should -be 'integer'
            $Pet.properties[0].name | Should -Be 'id'
            $Pet.properties[0].format | Should -Be 'int64'
            $Pet.properties[0].example | Should -Be 10
            $Pet.properties[0].readOnly | Should -Be $true

            $Pet.properties[1].type | Should -be 'string'
            $Pet.properties[1].name | Should -Be 'name'
            $Pet.properties[1].required | Should -BeTrue
            $Pet.properties[1].example | Should -Be 'doggie'

            $Pet.properties[2].type | Should -Be 'schema'
            $Pet.properties[2].name | Should -Be 'category'
            $Pet.properties[2].schema | Should -Be 'Category'

            $Pet.properties[3].type | Should -be 'string'
            $Pet.properties[3].name | Should -Be 'petType'
            $Pet.properties[3].required | Should -BeTrue
            $Pet.properties[3].example | Should -Be 'dog'
            $Pet.properties[4].type | Should -be 'string'
            $Pet.properties[4].name | Should -Be 'photoUrls'
            $Pet.properties[4].array | Should -BeTrue
            $Pet.properties[4].Count | Should -Be 3
            $Pet.properties[5].type | Should -be 'schema'
            $Pet.properties[5].name | Should -Be 'tags'
            $Pet.properties[5].schema | Should -Be 'Tag'
            $Pet.properties[5].Count | Should -Be 3
            $Pet.properties[6].type | Should -be 'string'
            $Pet.properties[6].name | Should -Be 'status'
            $Pet.properties[6].description | Should -Be 'pet status in the store'
            $Pet.properties[6].enum -is [string[]] | Should -BeTrue
            $Pet.properties[6].enum.Count | Should -Be 3
            $Pet.properties[6].enum[0] | Should -Be 'available'
            $Pet.properties[6].enum[1] | Should -Be 'pending'
            $Pet.properties[6].enum[2] | Should -Be 'sold'
            $Pet.properties[6].Count | Should -Be 4

        }
        It 'By Pipeline' {
            $Pet = New-PodeOAIntProperty -Name 'id'-Format Int64 -Example 10 -ReadOnly |
                New-PodeOAStringProperty -Name 'name' -Example 'doggie' -Required |
                New-PodeOAComponentSchemaProperty -Name 'category' -Reference 'Category' |
                New-PodeOAStringProperty -Name 'petType' -Example 'dog' -Required |
                New-PodeOAStringProperty -Name 'photoUrls' -Array |
                New-PodeOAComponentSchemaProperty -Name 'tags' -Reference 'Tag' |
                New-PodeOAStringProperty -Name 'status' -Description 'pet status in the store' -Enum @('available', 'pending', 'sold') |
                New-PodeOAObjectProperty -Name 'Pet' -XmlName 'pet'
            $Pet.type | Should -be 'object'
            $Pet.xml | Should -BeOfType  [System.Collections.Specialized.OrderedDictionary]
            $Pet.xml.Count | Should -Be 1
            $Pet.xml.name | Should -Be 'pet'
            $Pet.name | Should -Be 'Pet'
            $Pet.properties | Should -BeOfType [hashtable]
            $Pet.properties.Count | Should -Be 7
            $Pet.properties[0].type | Should -be 'integer'
            $Pet.properties[0].name | Should -Be 'id'
            $Pet.properties[0].format | Should -Be 'int64'
            $Pet.properties[0].example | Should -Be 10
            $Pet.properties[0].readOnly | Should -Be $true
            $Pet.properties[0].Count | Should -Be 5
            $Pet.properties[1].type | Should -be 'string'
            $Pet.properties[1].name | Should -Be 'name'
            $Pet.properties[1].required | Should -BeTrue
            $Pet.properties[1].example | Should -Be 'doggie'
            $Pet.properties[2].type | Should -Be 'schema'
            $Pet.properties[2].name | Should -Be 'category'
            $Pet.properties[2].schema | Should -Be 'Category'
            $Pet.properties[3].type | Should -be 'string'
            $Pet.properties[3].name | Should -Be 'petType'
            $Pet.properties[3].required | Should -BeTrue
            $Pet.properties[3].example | Should -Be 'dog'
            $Pet.properties[4].type | Should -be 'string'
            $Pet.properties[4].name | Should -Be 'photoUrls'
            $Pet.properties[4].array | Should -BeTrue
            $Pet.properties[5].type | Should -be 'schema'
            $Pet.properties[5].name | Should -Be 'tags'
            $Pet.properties[5].schema | Should -Be 'Tag'
            $Pet.properties[6].type | Should -be 'string'
            $Pet.properties[6].name | Should -Be 'status'
            $Pet.properties[6].description | Should -Be 'pet status in the store'
            $Pet.properties[6].enum -is [string[]] | Should -BeTrue
            $Pet.properties[6].enum.Count | Should -Be 3
            $Pet.properties[6].enum[0] | Should -Be 'available'
            $Pet.properties[6].enum[1] | Should -Be 'pending'
            $Pet.properties[6].enum[2] | Should -Be 'sold'

        }
    }

}