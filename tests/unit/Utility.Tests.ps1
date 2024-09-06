[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
param()

BeforeAll {
    $path = $PSCommandPath
    $src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit', '/src/'
    Get-ChildItem "$($src)/*.ps1" -Recurse | Resolve-Path | ForEach-Object { . $_ }
    Import-LocalizedData -BindingVariable PodeLocale -BaseDirectory (Join-Path -Path $src -ChildPath 'Locales') -FileName 'Pode'

    $PodeContext = @{ 'Server' = $null; }
}

Describe 'ConvertFrom-PodeSerializedString' {

    Describe 'Path Parameters' {
        It 'Convert Simple(Explode) style serialized string to a primitive value' {
            $serialized = '5'
            $result = ConvertFrom-PodeSerializedString -SerializedString $serialized -Style Simple -Explode
            $result | Should -be 5
        }

        It 'Convert Simple(Explode) style serialized string to hashtable' {
            $serialized = 'role=admin,firstName=Alex'
            $result = ConvertFrom-PodeSerializedString -SerializedString $serialized -Style Simple -Explode
            $expected = @{
                role      = 'admin'
                firstName = 'Alex'
            }
            $result.GetEnumerator() | ForEach-Object {
                $expected[$_.Key] | Should -Be $_.Value
            }
        }

        It 'Convert Simple(Explode) style serialized string to array' {
            $serialized = '3,4,5'
            $result = ConvertFrom-PodeSerializedString -SerializedString $serialized -Style Simple -Explode
            $result | Should -be  @(3, 4, 5)
        }

        It 'Convert Simple style serialized string to a primitive value' {
            $serialized = '5'
            $result = ConvertFrom-PodeSerializedString -SerializedString $serialized -Style Simple
            $result | Should -be 5
        }

        It 'Convert Simple style serialized string to hashtable' {
            $serialized = 'role,admin,firstName,Alex'
            $result = ConvertFrom-PodeSerializedString -SerializedString $serialized -Style Simple
            $expected = @{
                role      = 'admin'
                firstName = 'Alex'
            }
            $result.GetEnumerator() | ForEach-Object {
                $expected[$_.Key] | Should -Be $_.Value
            }
        }

        It 'Convert Simple style serialized string to array' {
            $serialized = '3,4,5'
            $result = ConvertFrom-PodeSerializedString -SerializedString $serialized -Style Simple
            $result | Should -be  @(3, 4, 5)
        }


        It 'Convert Label(Explode) style serialized string to a primitive value' {
            $serialized = '.5'
            $result = ConvertFrom-PodeSerializedString -SerializedString $serialized -Style Label -Explode
            $result | Should -be 5
        }

        It 'Convert Label(Explode) style serialized string to hashtable' {
            $serialized = '.role=admin.firstName=Alex'
            $result = ConvertFrom-PodeSerializedString -SerializedString $serialized -Style Label -Explode
            $expected = @{
                role      = 'admin'
                firstName = 'Alex'
            }
            $result.GetEnumerator() | ForEach-Object {
                $expected[$_.Key] | Should -Be $_.Value
            }
        }

        It 'Convert Label(Explode) style serialized string to array' {
            $serialized = '.3,4,5'
            $result = ConvertFrom-PodeSerializedString -SerializedString $serialized -Style Label -Explode
            $result | Should -be  @(3, 4, 5)
        }

        It 'Convert Simple style serialized string to a primitive value' {
            $serialized = '.5'
            $result = ConvertFrom-PodeSerializedString -SerializedString $serialized -Style Label
            $result | Should -be 5
        }

        It 'Convert Label style serialized string to hashtable' {
            $serialized = '.role,admin,firstName,Alex'
            $result = ConvertFrom-PodeSerializedString -SerializedString $serialized -Style Label
            $expected = @{
                role      = 'admin'
                firstName = 'Alex'
            }
            $result.GetEnumerator() | ForEach-Object {
                $expected[$_.Key] | Should -Be $_.Value
            }
        }

        It 'Convert Label style serialized string to array' {
            $serialized = '.3,4,5'
            $result = ConvertFrom-PodeSerializedString -SerializedString $serialized -Style Label
            $result | Should -be  @(3, 4, 5)
        }



        It 'Convert Matrix(Explode) style serialized string to a primitive value' {
            $serialized = ';id=5'
            $result = ConvertFrom-PodeSerializedString -SerializedString $serialized -Style Matrix -Explode
            $result | Should -be 5
        }

        It 'Convert Matrix(Explode) style serialized string to hashtable' {
            $serialized = ';role=admin;firstName=Alex'
            $result = ConvertFrom-PodeSerializedString -SerializedString $serialized -Style Matrix -Explode
            $expected = @{
                role      = 'admin'
                firstName = 'Alex'
            }
            $result.GetEnumerator() | ForEach-Object {
                $expected[$_.Key] | Should -Be $_.Value
            }
        }

        It 'Convert Matrix(Explode) style serialized string to array' {
            $serialized = ';id=3;id=4;id=5'
            $result = ConvertFrom-PodeSerializedString -SerializedString $serialized -Style Matrix -Explode
            $result | Should -be  @(3, 4, 5)
        }

        It 'Convert Simple style serialized string to a primitive value' {
            $serialized = ';id=5'
            $result = ConvertFrom-PodeSerializedString -SerializedString $serialized -Style Matrix
            $result | Should -be 5
        }

        It 'Convert Matrix style serialized string to hashtable' {
            $serialized = ';id=role,admin,firstName,Alex'
            $result = ConvertFrom-PodeSerializedString -SerializedString $serialized -Style Matrix
            $expected = @{
                role      = 'admin'
                firstName = 'Alex'
            }
            $result.GetEnumerator() | ForEach-Object {
                $expected[$_.Key] | Should -Be $_.Value
            }
        }

        It 'Convert Matrix style serialized string to array' {
            $serialized = ';id=3,4,5'
            $result = ConvertFrom-PodeSerializedString -SerializedString $serialized -Style Matrix
            $result | Should -be  @(3, 4, 5)
        }


        It 'Convert Matrix(Explode) style serialized string to a primitive value' {
            $serialized = ';id=5'
            $result = ConvertFrom-PodeSerializedString -SerializedString $serialized -Style Matrix -Explode
            $result | Should -be 5
        }

        It 'Convert Matrix(Explode) style serialized string to hashtable' {
            $serialized = ';role=admin;firstName=Alex'
            $result = ConvertFrom-PodeSerializedString -SerializedString $serialized -Style Matrix -Explode
            $expected = @{
                role      = 'admin'
                firstName = 'Alex'
            }
            $result.GetEnumerator() | ForEach-Object {
                $expected[$_.Key] | Should -Be $_.Value
            }
        }

        It 'Convert Matrix(Explode) style serialized string to array' {
            $serialized = ';id=3;id=4;id=5'
            $result = ConvertFrom-PodeSerializedString -SerializedString $serialized -Style Matrix -Explode
            $result | Should -be  @(3, 4, 5)
        }

        It 'Convert Matrix style serialized string to a primitive value' {
            $serialized = ';id=5'
            $result = ConvertFrom-PodeSerializedString -SerializedString $serialized -Style Matrix
            $result | Should -be 5
        }

        It 'Convert Matrix style serialized string to hashtable' {
            $serialized = ';id=role,admin,firstName,Alex'
            $result = ConvertFrom-PodeSerializedString -SerializedString $serialized -Style Matrix
            $expected = @{
                role      = 'admin'
                firstName = 'Alex'
            }
            $result.GetEnumerator() | ForEach-Object {
                $expected[$_.Key] | Should -Be $_.Value
            }
        }

        It 'Convert Matrix style serialized string to array' {
            $serialized = ';id=3,4,5'
            $result = ConvertFrom-PodeSerializedString -SerializedString $serialized -Style Matrix
            $result | Should -be  @(3, 4, 5)
        }
    }

    Describe 'Query Parameters' {
        It 'Convert Form(Explode) style serialized string to a primitive value' {
            $serialized = '?id=5'
            $result = ConvertFrom-PodeSerializedString -SerializedString $serialized -Style Form -Explode
            $result | Should -be 5
        }

        It 'Convert Form(Explode) style serialized string to hashtable' {
            $serialized = '?role=admin&firstName=Alex'
            $result = ConvertFrom-PodeSerializedString -SerializedString $serialized -Style Form -Explode
            $expected = @{
                role      = 'admin'
                firstName = 'Alex'
            }
            $result.GetEnumerator() | ForEach-Object {
                $expected[$_.Key] | Should -Be $_.Value
            }
        }

        It 'Convert Form(Explode) style serialized string to array' {
            $serialized = '?id=3&id=4&id=5'
            $result = ConvertFrom-PodeSerializedString -SerializedString $serialized -Style Form -Explode
            $result | Should -be  @(3, 4, 5)
        }

        It 'Convert Form style serialized string to a primitive value' {
            $serialized = '?id=5'
            $result = ConvertFrom-PodeSerializedString -SerializedString $serialized -Style Form
            $result | Should -be 5
        }

        It 'Convert Form style serialized string to hashtable' {
            $serialized = '?id=role,admin,firstName,Alex'
            $result = ConvertFrom-PodeSerializedString -SerializedString $serialized -Style Form
            $expected = @{
                role      = 'admin'
                firstName = 'Alex'
            }
            $result.GetEnumerator() | ForEach-Object {
                $expected[$_.Key] | Should -Be $_.Value
            }
        }

        It 'Convert Form style serialized string to array' {
            $serialized = '?id=3,4,5'
            $result = ConvertFrom-PodeSerializedString -SerializedString $serialized -Style Form
            $result | Should -be  @(3, 4, 5)
        }


        It 'Convert SpaceDelimited(Explode) style serialized string to array' {
            $serialized = '?id=3&id=4&id=5'
            $result = ConvertFrom-PodeSerializedString -SerializedString $serialized -Style SpaceDelimited -Explode
            $result | Should -be  @(3, 4, 5)
        }

        It 'Convert SpaceDelimited style serialized string to array' {
            $serialized = '?id=3%204%205'
            $result = ConvertFrom-PodeSerializedString -SerializedString $serialized -Style SpaceDelimited
            $result | Should -be  @(3, 4, 5)
        }


        It 'Convert pipeDelimited(Explode) style serialized string to array' {
            $serialized = '?id=3&id=4&id=5'
            $result = ConvertFrom-PodeSerializedString -SerializedString $serialized -Style pipeDelimited -Explode
            $result | Should -be  @(3, 4, 5)
        }

        It 'Convert pipeDelimited style serialized string to array' {
            $serialized = '?id=3|4|5'
            $result = ConvertFrom-PodeSerializedString -SerializedString $serialized -Style pipeDelimited
            $result | Should -be  @(3, 4, 5)
        }

        It 'Convert DeepObject(Explode) style serialized string to hashtable' {
            $serialized = '?id[role]=admin&id[firstName]=Alex'
            $result = ConvertFrom-PodeSerializedString -SerializedString $serialized -Style DeepObject
            $expected = @{
                role      = 'admin'
                firstName = 'Alex'
            }
            $result.GetEnumerator() | ForEach-Object {
                $expected[$_.Key] | Should -Be $_.Value
            }
        }

        It 'Convert DeepObject(Explode) style nested object serialized to hashtable' {
            $serialized = '?id[role][type]=admin&id[role][level]=high&id[firstName]=Alex'
            $result = ConvertFrom-PodeSerializedString -SerializedString $serialized -Style DeepObject
            $expected = @{
                role      = @{
                    type  = 'admin'
                    level = 'high'
                }
                firstName = 'Alex'
            }
            $result['role'].GetEnumerator() | ForEach-Object {
                $expected['role'][$_.Key] | Should -Be $_.Value
            }
            $result['firstName']|Should -Be  $expected['firstName']
        }

    }


    Describe 'Header Parameters' {
        It 'Convert Simple(Explode) style serialized string to a primitive value' {
            $serialized = 'X-MyHeader: 5'
            $result = ConvertFrom-PodeSerializedString -SerializedString $serialized -Style Simple -Explode
            $result['X-MyHeader'] | Should -be 5
        }

        It 'Convert Simple(Explode) style serialized string to hashtable' {
            $serialized = 'X-MyHeader: role=admin,firstName=Alex'
            $result = ConvertFrom-PodeSerializedString -SerializedString $serialized -Style Simple -Explode
            $expected = @{
                role      = 'admin'
                firstName = 'Alex'
            }
            $result['X-MyHeader'].GetEnumerator() | ForEach-Object {
                $expected[$_.Key] | Should -Be $_.Value
            }
        }

        It 'Convert Simple(Explode) style serialized string to array' {
            $serialized = 'X-MyHeader: 3,4,5'
            $result = ConvertFrom-PodeSerializedString -SerializedString $serialized -Style Simple -Explode
            $result['X-MyHeader'] | Should -be  @(3, 4, 5)
        }

        It 'Convert Simple style serialized string to a primitive value' {
            $serialized = 'X-MyHeader: 5'
            $result = ConvertFrom-PodeSerializedString -SerializedString $serialized -Style Simple
            $result['X-MyHeader'] | Should -be 5
        }

        It 'Convert Simple style serialized string to hashtable' {
            $serialized = 'X-MyHeader: role,admin,firstName,Alex'
            $result = ConvertFrom-PodeSerializedString -SerializedString $serialized -Style Simple
            $expected = @{
                role      = 'admin'
                firstName = 'Alex'
            }
            $result['X-MyHeader'].GetEnumerator() | ForEach-Object {
                $expected[$_.Key] | Should -Be $_.Value
            }
        }

        It 'Convert Simple style serialized string to array' {
            $serialized = 'X-MyHeader: 3,4,5'
            $result = ConvertFrom-PodeSerializedString -SerializedString $serialized -Style Simple
            $result['X-MyHeader'] | Should -be  @(3, 4, 5)
        }
    }

    Describe 'Cookie Parameters' {
        It 'Convert Form(Explode) style serialized string to a primitive value' {
            $serialized = 'Cookie: id=5'
            $result = ConvertFrom-PodeSerializedString -SerializedString $serialized -Style Form -Explode
            $result['Cookie'] | Should -be 5
        }

        It 'Convert Form style serialized string to a primitive value' {
            $serialized = 'Cookie: id=5'
            $result = ConvertFrom-PodeSerializedString -SerializedString $serialized -Style Form
            $result['Cookie'] | Should -be 5
        }

        It 'Convert Form style serialized string to hashtable' {
            $serialized = 'Cookie: id=role,admin,firstName,Alex'
            $result = ConvertFrom-PodeSerializedString -SerializedString $serialized -Style Form
            $expected = @{
                role      = 'admin'
                firstName = 'Alex'
            }
            $result['Cookie'].GetEnumerator() | ForEach-Object {
                $expected[$_.Key] | Should -Be $_.Value
            }
        }

        It 'Convert Form style serialized string to array' {
            $serialized = 'Cookie: id=3,4,5'
            $result = ConvertFrom-PodeSerializedString -SerializedString $serialized -Style Form
            $result['Cookie'] | Should -be  @(3, 4, 5)
        }
    }
    <#

    It 'should throw an error for unsupported serialization format' {
        $serialized = 'unsupportedFormat'
        { ConvertFrom-PodeSerializedString -SerializedString $serialized } | Should -Throw ($PodeLocale.unsupportedSerializationTypeExceptionMessage)
    }
    #>
}



Describe 'ConvertTo-PodeSerializedString' {

    BeforeAll {
        function SortSerializedString {
            param (
                [string] $SerializedString,
                [string] $Delimiter
            )

            $pairs = $SerializedString -split $Delimiter
            $sortedPairs = $pairs | Sort-Object
            return $sortedPairs -join $Delimiter
        }
    }
    It 'should convert hashtable to Simple style serialized string' {
        $hashtable = @{
            name        = 'value'
            anotherName = 'anotherValue'
        }
        $result = ConvertTo-PodeSerializedString -Hashtable $hashtable -Style 'Simple'
        $sortedResult = SortSerializedString -SerializedString $result -Delimiter ','
        $expected = 'name=value,anotherName=anotherValue'
        $sortedExpected = SortSerializedString -SerializedString $expected -Delimiter ','
        $sortedResult | Should -Be $sortedExpected
    }

    It 'should convert hashtable to Simple style serialized string with Explode' {
        $hashtable = @{
            name        = 'value'
            anotherName = 'anotherValue'
        }
        $result = ConvertTo-PodeSerializedString -Hashtable $hashtable -Style 'Simple' -Explode
        $sortedResult = SortSerializedString -SerializedString $result -Delimiter '&'
        $expected = 'name=value&anotherName=anotherValue'
        $sortedExpected = SortSerializedString -SerializedString $expected -Delimiter '&'
        $sortedResult | Should -Be $sortedExpected
    }

    It 'should convert hashtable to Label style serialized string' {
        $hashtable = @{
            name        = 'value'
            anotherName = 'anotherValue'
        }
        $result = ConvertTo-PodeSerializedString -Hashtable $hashtable -Style 'Label'
        $result -eq '.name.value.anotherName.anotherValue' -or $result -eq '.anotherName.anotherValue.name.value' | Should -BeTrue
    }

    It 'should convert hashtable to Matrix style serialized string' {
        $hashtable = @{
            name        = 'value'
            anotherName = 'anotherValue'
        }
        $result = ConvertTo-PodeSerializedString -Hashtable $hashtable -Style 'Matrix'
        $sortedResult = SortSerializedString -SerializedString $result -Delimiter ';'
        $expected = ';name=value;anotherName=anotherValue'
        $sortedExpected = SortSerializedString -SerializedString $expected -Delimiter ';'
        $sortedResult | Should -Be $sortedExpected
    }

    It 'should convert hashtable to Query style serialized string' {
        $hashtable = @{
            name        = 'value'
            anotherName = 'anotherValue'
        }
        $result = ConvertTo-PodeSerializedString -Hashtable $hashtable -Style 'Query'
        $sortedResult = SortSerializedString -SerializedString $result -Delimiter '&'
        $expected = 'name=value&anotherName=anotherValue'
        $sortedExpected = SortSerializedString -SerializedString $expected -Delimiter '&'
        $sortedResult | Should -Be $sortedExpected
    }

    It 'should convert hashtable to Form style serialized string' {
        $hashtable = @{
            name        = 'value'
            anotherName = 'anotherValue'
        }
        $result = ConvertTo-PodeSerializedString -Hashtable $hashtable -Style 'Form'
        $sortedResult = SortSerializedString -SerializedString $result -Delimiter '&'
        $expected = 'name=value&anotherName=anotherValue'
        $sortedExpected = SortSerializedString -SerializedString $expected -Delimiter '&'
        $sortedResult | Should -Be $sortedExpected
    }

    It 'should convert hashtable to SpaceDelimited style serialized string' {
        $hashtable = @{
            name        = 'value'
            anotherName = 'anotherValue'
        }
        $result = ConvertTo-PodeSerializedString -Hashtable $hashtable -Style 'SpaceDelimited'
        $sortedResult = SortSerializedString -SerializedString $result -Delimiter ' '
        $expected = 'name=value anotherName=anotherValue'
        $sortedExpected = SortSerializedString -SerializedString $expected -Delimiter ' '
        $sortedResult | Should -Be $sortedExpected
    }

    It 'should convert hashtable to PipeDelimited style serialized string' {
        $hashtable = @{
            name        = 'value'
            anotherName = 'anotherValue'
        }
        $result = ConvertTo-PodeSerializedString -Hashtable $hashtable -Style 'PipeDelimited'
        $sortedResult = SortSerializedString -SerializedString $result -Delimiter '|'
        $expected = 'name=value|anotherName=anotherValue'
        $sortedExpected = SortSerializedString -SerializedString $expected -Delimiter '|'
        $sortedResult | Should -Be $sortedExpected
    }

    It 'should convert hashtable to DeepObject style serialized string' {
        $hashtable = @{
            name        = 'value'
            anotherName = 'anotherValue'
        }
        $result = ConvertTo-PodeSerializedString -Hashtable $hashtable -Style 'DeepObject'
        $sortedResult = SortSerializedString -SerializedString $result -Delimiter ','
        $expected = 'name[name]=value,anotherName[anotherName]=anotherValue'
        $sortedExpected = SortSerializedString -SerializedString $expected -Delimiter ','
        $sortedResult | Should -Be $sortedExpected
    }

    It 'should convert hashtable to DeepObject style serialized string with Explode' {
        $hashtable = @{
            name        = 'value'
            anotherName = 'anotherValue'
        }
        $result = ConvertTo-PodeSerializedString -Hashtable $hashtable -Style 'DeepObject' -Explode
        $sortedResult = SortSerializedString -SerializedString $result -Delimiter '&'
        $expected = 'name[name]=value&anotherName[anotherName]=anotherValue'
        $sortedExpected = SortSerializedString -SerializedString $expected -Delimiter '&'
        $sortedResult | Should -Be $sortedExpected
    }

    It 'should throw an error for unsupported serialization type' {
        $hashtable = @{
            name        = 'value'
            anotherName = 'anotherValue'
        }
        { ConvertTo-PodeSerializedString -Hashtable $hashtable -Style 'Unsupported' } | Should -Throw
    }
}


Describe 'Get-PodeParameter' {
    BeforeEach {
        # Mock the $WebEvent variable
        $Script:WebEvent = [PSCustomObject]@{
            Parameters = @{ 'action' = 'create' }
        }
    }

    It 'should return the specified parameter value from the web event' {
        # Call the function
        $result = Get-PodeParameter -Name 'action'

        # Assert the result
        $result | Should -Be 'create'
    }
}


Describe 'Get-PodeQuery' {
    BeforeEach {
        # Mock the $WebEvent variable
        $Script:WebEvent = [PSCustomObject]@{
            Query = @{ 'userId' = '12345' }
        }
    }

    It 'should return the specified query parameter value from the web event' {
        # Call the function
        $result = Get-PodeQuery -Name 'userId'

        # Assert the result
        $result | Should -Be '12345'
    }
}


Describe 'Get-PodeBody' {
    BeforeEach {
        # Mock the $WebEvent variable
        $Script:WebEvent = [PSCustomObject]@{
            Data = 'This is the body data'
        }
    }

    It 'should return the body data of the web event' {
        # Call the function
        $result = Get-PodeBody

        # Assert the result
        $result | Should -Be 'This is the body data'
    }
}
