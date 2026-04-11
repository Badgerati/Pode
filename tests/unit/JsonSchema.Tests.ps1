[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
param()

InModuleScope -ModuleName 'Pode' {
    Describe 'New-PodeJsonSchemaNull' {
        It 'Basic' {
            $def = New-PodeJsonSchemaNull
            $def | Should -BeOfType [hashtable]

            $def.type | Should -Be 'null'
            $def.Keys.Count | Should -Be 1
        }

        It 'Full' {
            $def = New-PodeJsonSchemaNull -Description 'A null value'
            $def | Should -BeOfType [hashtable]

            $def.type | Should -Be 'null'
            $def.description | Should -Be 'A null value'
        }
    }

    Describe 'New-PodeJsonSchemaBoolean' {
        It 'Basic' {
            $def = New-PodeJsonSchemaBoolean
            $def | Should -BeOfType [hashtable]

            $def.type | Should -Be 'boolean'
            $def.Keys.Count | Should -Be 1
        }

        It 'Description' {
            $def = New-PodeJsonSchemaBoolean -Description 'A boolean value'
            $def | Should -BeOfType [hashtable]

            $def.type | Should -Be 'boolean'
            $def.description | Should -Be 'A boolean value'
            $def.Keys.Count | Should -Be 2
        }

        It 'Constant' {
            $def = New-PodeJsonSchemaBoolean -Constant $true
            $def | Should -BeOfType [hashtable]

            $def.type | Should -Be 'boolean'
            $def.const | Should -Be $true
            $def.Keys.Count | Should -Be 2
        }

        It 'Full' {
            $def = New-PodeJsonSchemaBoolean -Description 'A boolean value that must be true' -Constant $true
            $def | Should -BeOfType [hashtable]

            $def.type | Should -Be 'boolean'
            $def.description | Should -Be 'A boolean value that must be true'
            $def.const | Should -Be $true
            $def.Keys.Count | Should -Be 3
        }
    }

    Describe 'New-PodeJsonSchemaInteger' {
        It 'Basic' {
            $def = New-PodeJsonSchemaInteger
            $def | Should -BeOfType [hashtable]

            $def.type | Should -Be 'integer'
            $def.Keys.Count | Should -Be 1
        }

        It 'Description' {
            $def = New-PodeJsonSchemaInteger -Description 'An integer value'
            $def | Should -BeOfType [hashtable]

            $def.type | Should -Be 'integer'
            $def.description | Should -Be 'An integer value'
            $def.Keys.Count | Should -Be 2
        }

        It 'Constant' {
            $def = New-PodeJsonSchemaInteger -Constant 42
            $def | Should -BeOfType [hashtable]

            $def.type | Should -Be 'integer'
            $def.const | Should -Be 42
            $def.Keys.Count | Should -Be 2
        }

        It 'Minimum and Maximum' {
            $def = New-PodeJsonSchemaInteger -Minimum 0 -Maximum 100
            $def | Should -BeOfType [hashtable]

            $def.type | Should -Be 'integer'
            $def.minimum | Should -Be 0
            $def.maximum | Should -Be 100
            $def.Keys.Count | Should -Be 3
        }

        It 'Maximum less than Minimum' {
            { New-PodeJsonSchemaInteger -Minimum 100 -Maximum 0 } | Should -Throw
        }

        It 'MultipleOf' {
            $def = New-PodeJsonSchemaInteger -MultipleOf 5
            $def | Should -BeOfType [hashtable]

            $def.type | Should -Be 'integer'
            $def.multipleOf | Should -Be 5
            $def.Keys.Count | Should -Be 2
        }

        It 'Enum' {
            $def = New-PodeJsonSchemaInteger -Enum 1, 2, 3
            $def | Should -BeOfType [hashtable]

            $def.type | Should -Be 'integer'
            $def.enum | Should -Be @(1, 2, 3)
            $def.Keys.Count | Should -Be 2
        }

        It 'Exclusive Minimum and Maximum' {
            $def = New-PodeJsonSchemaInteger -Minimum 0 -Maximum 100 -ExclusiveMinimum -ExclusiveMaximum
            $def | Should -BeOfType [hashtable]

            $def.type | Should -Be 'integer'
            $def.minimum | Should -Be 0
            $def.maximum | Should -Be 100
            $def.exclusiveMinimum | Should -Be $true
            $def.exclusiveMaximum | Should -Be $true
            $def.Keys.Count | Should -Be 5
        }
    }

    Describe 'New-PodeJsonSchemaNumber' {
        It 'Basic' {
            $def = New-PodeJsonSchemaNumber
            $def | Should -BeOfType [hashtable]

            $def.type | Should -Be 'number'
            $def.Keys.Count | Should -Be 1
        }

        It 'Description' {
            $def = New-PodeJsonSchemaNumber -Description 'A number value'
            $def | Should -BeOfType [hashtable]

            $def.type | Should -Be 'number'
            $def.description | Should -Be 'A number value'
            $def.Keys.Count | Should -Be 2
        }

        It 'Constant' {
            $def = New-PodeJsonSchemaNumber -Constant 3.14
            $def | Should -BeOfType [hashtable]

            $def.type | Should -Be 'number'
            $def.const | Should -Be 3.14
            $def.Keys.Count | Should -Be 2
        }

        It 'Minimum and Maximum' {
            $def = New-PodeJsonSchemaNumber -Minimum 0 -Maximum 100
            $def | Should -BeOfType [hashtable]

            $def.type | Should -Be 'number'
            $def.minimum | Should -Be 0
            $def.maximum | Should -Be 100
            $def.Keys.Count | Should -Be 3
        }

        It 'Maximum less than Minimum' {
            { New-PodeJsonSchemaNumber -Minimum 100 -Maximum 0 } | Should -Throw
        }

        It 'MultipleOf' {
            $def = New-PodeJsonSchemaNumber -MultipleOf 5
            $def | Should -BeOfType [hashtable]

            $def.type | Should -Be 'number'
            $def.multipleOf | Should -Be 5
            $def.Keys.Count | Should -Be 2
        }

        It 'Enum' {
            $def = New-PodeJsonSchemaNumber -Enum 1, 2, 3
            $def | Should -BeOfType [hashtable]

            $def.type | Should -Be 'number'
            $def.enum | Should -Be @(1, 2, 3)
            $def.Keys.Count | Should -Be 2
        }

        It 'Exclusive Minimum and Maximum' {
            $def = New-PodeJsonSchemaNumber -Minimum 0 -Maximum 100 -ExclusiveMinimum -ExclusiveMaximum
            $def | Should -BeOfType [hashtable]

            $def.type | Should -Be 'number'
            $def.minimum | Should -Be 0
            $def.maximum | Should -Be 100
            $def.exclusiveMinimum | Should -Be $true
            $def.exclusiveMaximum | Should -Be $true
            $def.Keys.Count | Should -Be 5
        }
    }

    Describe 'New-PodeJsonSchemaString' {
        It 'Basic' {
            $def = New-PodeJsonSchemaString
            $def | Should -BeOfType [hashtable]

            $def.type | Should -Be 'string'
            $def.Keys.Count | Should -Be 1
        }

        It 'Description' {
            $def = New-PodeJsonSchemaString -Description 'A string value'
            $def | Should -BeOfType [hashtable]

            $def.type | Should -Be 'string'
            $def.description | Should -Be 'A string value'
            $def.Keys.Count | Should -Be 2
        }

        It 'Constant' {
            $def = New-PodeJsonSchemaString -Constant 'Hello'
            $def | Should -BeOfType [hashtable]

            $def.type | Should -Be 'string'
            $def.const | Should -Be 'Hello'
            $def.Keys.Count | Should -Be 2
        }

        It 'MinLength and MaxLength' {
            $def = New-PodeJsonSchemaString -MinLength 5 -MaxLength 10
            $def | Should -BeOfType [hashtable]

            $def.type | Should -Be 'string'
            $def.minLength | Should -Be 5
            $def.maxLength | Should -Be 10
            $def.Keys.Count | Should -Be 3
        }

        It 'MaxLength less than MinLength' {
            { New-PodeJsonSchemaString -MinLength 10 -MaxLength 5 } | Should -Throw
        }

        It 'Pattern' {
            $def = New-PodeJsonSchemaString -Pattern '^[a-zA-Z]+$'
            $def | Should -BeOfType [hashtable]

            $def.type | Should -Be 'string'
            $def.pattern | Should -Be '^[a-zA-Z]+$'
            $def.Keys.Count | Should -Be 2
        }

        It 'Enum' {
            $def = New-PodeJsonSchemaString -Enum 'red', 'green', 'blue'
            $def | Should -BeOfType [hashtable]

            $def.type | Should -Be 'string'
            $def.enum | Should -Be @('red', 'green', 'blue')
            $def.Keys.Count | Should -Be 2
        }
    }

    Describe 'New-PodeJsonSchemaArray' {
        It 'Basic' {
            $def = New-PodeJsonSchemaArray -Item (New-PodeJsonSchemaString)
            $def | Should -BeOfType [hashtable]

            $def.type | Should -Be 'array'
            $def.items | Should -BeOfType [hashtable]
            $def.Keys.Count | Should -Be 2

            $def.items.type | Should -Be 'string'
            $def.items.Keys.Count | Should -Be 1
        }

        It 'Description' {
            $def = New-PodeJsonSchemaArray -Description 'An array value' -Item (New-PodeJsonSchemaString)
            $def | Should -BeOfType [hashtable]

            $def.type | Should -Be 'array'
            $def.description | Should -Be 'An array value'
            $def.items | Should -BeOfType [hashtable]
            $def.Keys.Count | Should -Be 3

            $def.items.type | Should -Be 'string'
            $def.items.Keys.Count | Should -Be 1
        }

        It 'MinItems and MaxItems' {
            $def = New-PodeJsonSchemaArray -Item (New-PodeJsonSchemaString) -MinItems 1 -MaxItems 5
            $def | Should -BeOfType [hashtable]

            $def.type | Should -Be 'array'
            $def.items | Should -BeOfType [hashtable]
            $def.minItems | Should -Be 1
            $def.maxItems | Should -Be 5
            $def.Keys.Count | Should -Be 4

            $def.items.type | Should -Be 'string'
            $def.items.Keys.Count | Should -Be 1
        }

        It 'MaxItems less than MinItems' {
            { New-PodeJsonSchemaArray -Item (New-PodeJsonSchemaString) -MinItems 5 -MaxItems 1 } | Should -Throw
        }

        It 'Unique' {
            $def = New-PodeJsonSchemaArray -Item (New-PodeJsonSchemaString) -Unique
            $def | Should -BeOfType [hashtable]

            $def.type | Should -Be 'array'
            $def.items | Should -BeOfType [hashtable]
            $def.uniqueItems | Should -Be $true
            $def.Keys.Count | Should -Be 3

            $def.items.type | Should -Be 'string'
            $def.items.Keys.Count | Should -Be 1
        }
    }

    Describe 'New-PodeJsonSchemaObject' {
        It 'Basic' {
            $def = New-PodeJsonSchemaObject
            $def | Should -BeOfType [hashtable]

            $def.type | Should -Be 'object'
            $def.Keys.Count | Should -Be 1
        }

        It 'Description' {
            $def = New-PodeJsonSchemaObject -Description 'An object value'
            $def | Should -BeOfType [hashtable]

            $def.type | Should -Be 'object'
            $def.description | Should -Be 'An object value'
            $def.Keys.Count | Should -Be 2
        }

        It 'MinProperties and MaxProperties' {
            $def = New-PodeJsonSchemaObject -MinProperties 1 -MaxProperties 5
            $def | Should -BeOfType [hashtable]

            $def.type | Should -Be 'object'
            $def.minProperties | Should -Be 1
            $def.maxProperties | Should -Be 5
            $def.Keys.Count | Should -Be 3
        }

        It 'MaxProperties less than MinProperties' {
            { New-PodeJsonSchemaObject -MinProperties 5 -MaxProperties 1 } | Should -Throw
        }

        It 'Properties' {
            $def = New-PodeJsonSchemaObject -Property @(
                New-PodeJsonSchemaProperty -Name 'name' -Definition (New-PodeJsonSchemaString)
                New-PodeJsonSchemaProperty -Name 'age' -Definition (New-PodeJsonSchemaInteger)
            )
            $def | Should -BeOfType [hashtable]

            $def.type | Should -Be 'object'
            $def.properties | Should -BeOfType [hashtable]
            $def.Keys.Count | Should -Be 2

            $def.properties.name.type | Should -Be 'string'
            $def.properties.name.Keys.Count | Should -Be 1

            $def.properties.age.type | Should -Be 'integer'
            $def.properties.age.Keys.Count | Should -Be 1
        }

        It 'Required Properties' {
            $def = New-PodeJsonSchemaObject -Property @(
                New-PodeJsonSchemaProperty -Name 'name' -Definition (New-PodeJsonSchemaString) -Required
                New-PodeJsonSchemaProperty -Name 'age' -Definition (New-PodeJsonSchemaInteger)
            )
            $def | Should -BeOfType [hashtable]

            $def.type | Should -Be 'object'
            $def.properties | Should -BeOfType [hashtable]
            $def.required | Should -Be @('name')
            $def.Keys.Count | Should -Be 3

            $def.properties.name.type | Should -Be 'string'
            $def.properties.name.Keys.Count | Should -Be 1

            $def.properties.age.type | Should -Be 'integer'
            $def.properties.age.Keys.Count | Should -Be 1
        }
    }

    Describe 'Merge-PodeJsonSchema' {
        It 'AllOf' {
            $def = Merge-PodeJsonSchema -Type AllOf -Definition @(
                New-PodeJsonSchemaString -MinLength 5
                New-PodeJsonSchemaString -MaxLength 100
            )
            $def | Should -BeOfType [hashtable]
            $def.Keys.Count | Should -Be 1

            Should -ActualValue $def.allOf -BeOfType [array]
            $def.allOf.Length | Should -Be 2

            $def.allOf[0].type | Should -Be 'string'
            $def.allOf[0].minLength | Should -Be 5

            $def.allOf[1].type | Should -Be 'string'
            $def.allOf[1].maxLength | Should -Be 100
        }

        It 'AnyOf' {
            $def = Merge-PodeJsonSchema -Type AnyOf -Definition @(
                New-PodeJsonSchemaString
                New-PodeJsonSchemaNull
            )
            $def | Should -BeOfType [hashtable]
            $def.Keys.Count | Should -Be 1

            Should -ActualValue $def.anyOf -BeOfType [array]
            $def.anyOf.Length | Should -Be 2

            $def.anyOf[0].type | Should -Be 'string'
            $def.anyOf[1].type | Should -Be 'null'
        }

        It 'OneOf' {
            $def = Merge-PodeJsonSchema -Type OneOf -Definition @(
                New-PodeJsonSchemaString
                New-PodeJsonSchemaNull
            )
            $def | Should -BeOfType [hashtable]
            $def.Keys.Count | Should -Be 1

            Should -ActualValue $def.oneOf -BeOfType [array]
            $def.oneOf.Length | Should -Be 2

            $def.oneOf[0].type | Should -Be 'string'
            $def.oneOf[1].type | Should -Be 'null'
        }

        It 'Not' {
            $def = Merge-PodeJsonSchema -Type Not -Definition (New-PodeJsonSchemaString)
            $def | Should -BeOfType [hashtable]
            $def.Keys.Count | Should -Be 1

            Should -ActualValue $def.not -BeOfType [array]
            $def.not.Length | Should -Be 1

            $def.not[0].type | Should -Be 'string'
        }
    }

    Describe 'New-PodeJsonSchemaProperty' {
        It 'Basic' {
            $def = New-PodeJsonSchemaProperty -Name 'name' -Definition (New-PodeJsonSchemaString)
            $def | Should -BeOfType [hashtable]

            $def.Name | Should -Be 'name'
            $def.Required | Should -Be $false
            $def.Keys.Count | Should -Be 3

            $def.Definition | Should -BeOfType [hashtable]
            $def.Definition.type | Should -Be 'string'
            $def.Definition.Keys.Count | Should -Be 1
        }

        It 'Required' {
            $def = New-PodeJsonSchemaProperty -Name 'name' -Definition (New-PodeJsonSchemaString) -Required
            $def | Should -BeOfType [hashtable]

            $def.Name | Should -Be 'name'
            $def.Required | Should -Be $true
            $def.Keys.Count | Should -Be 3

            $def.Definition | Should -BeOfType [hashtable]
            $def.Definition.type | Should -Be 'string'
            $def.Definition.Keys.Count | Should -Be 1
        }
    }
}