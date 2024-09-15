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
            $result['firstName'] | Should -Be  $expected['firstName']
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
}



Describe 'ConvertTo-PodeSerializedString' {

    BeforeAll {
        function SortSerializedString {
            param (
                [string] $SerializedString,
                [string] $Delimiter,
                [switch] $GroupPairs,
                [string] $SkipHead = '',
                [string] $RemovePattern = ''
            )

            # If a head to skip is specified, separate it from the rest of the string
            if ($SkipHead -and $SerializedString.StartsWith($SkipHead)) {
                # Extract the head and the rest of the string
                $head = $SkipHead
                $SerializedString = $SerializedString.Substring($SkipHead.Length)
            }
            else {
                $head = ''
            }

            # Split the remaining string into individual elements
            $elements = $SerializedString -split $Delimiter

            # Apply pattern removal if specified
            if ($RemovePattern) {
                $elements = $elements.ForEach({
                        $_ -replace $RemovePattern, ''
                    })
            }

            if ($GroupPairs) {
                # Group elements into pairs (key-value)
                $pairs = for ($i = 0; $i -lt $elements.Count; $i += 2) {
                    # Check if the next element exists to avoid a trailing delimiter
                    if ($i + 1 -lt $elements.Count) {
                        "$($elements[$i])$Delimiter$($elements[$i + 1])"
                    }
                    else {
                        # If the last element doesn't have a pair, add it as is
                        $elements[$i]
                    }
                }

                # Sort the pairs
                $sortedPairs = $pairs | Sort-Object

                # Join sorted pairs back into a single string
                $sortedString = $sortedPairs -join $Delimiter
            }
            else {
                # Sort elements individually without grouping into pairs
                $sortedElements = $elements | Sort-Object

                # Join sorted elements back into a single string
                $sortedString = $sortedElements -join $Delimiter
            }

            # Reattach the head (if any) at the start of the sorted string
            $result = "$head$sortedString"

            # Remove any trailing delimiter that may have been inadvertently added
            if ($result.EndsWith($Delimiter)) {
                $result = $result.Substring(0, $result.Length - 1)
            }

            return $result
        }
    }
    It 'should convert hashtable to Simple style serialized string' {
        $hashtable = @{
            name        = 'value'
            anotherName = 'anotherValue'
            number      = 10
        }
        $result = ConvertTo-PodeSerializedString -Hashtable $hashtable -Style 'Simple'
        $sortedResult = SortSerializedString -SerializedString $result -Delimiter ',' -GroupPairs
        $expected = 'name,value,number,10,anotherName,anotherValue'
        $sortedExpected = SortSerializedString -SerializedString $expected -Delimiter ',' -GroupPairs
        $sortedResult | Should -Be $sortedExpected
    }

    It 'should convert hashtable to Simple style serialized string with Explode' {
        $hashtable = @{
            name        = 'value'
            anotherName = 'anotherValue'
            number      = 10
        }
        $result = ConvertTo-PodeSerializedString -Hashtable $hashtable -Style 'Simple' -Explode
        $sortedResult = SortSerializedString -SerializedString $result -Delimiter ','
        $expected = 'name=value,number=10,anotherName=anotherValue'
        $sortedExpected = SortSerializedString -SerializedString $expected -Delimiter ','
        $sortedResult | Should -Be $sortedExpected
    }

    It 'should convert hashtable to Label style serialized string' {
        $hashtable = @{
            name        = 'value'
            anotherName = 'anotherValue'
            number      = 10
        }
        $result = ConvertTo-PodeSerializedString -Hashtable $hashtable -Style 'Label'

        $sortedResult = SortSerializedString -SerializedString $result -Delimiter ',' -SkipHead '.'
        $expected = '.anotherName,anotherValue,number,10,name,value'
        $sortedExpected = SortSerializedString -SerializedString $expected -Delimiter ',' -SkipHead '.'
        $sortedResult | Should -Be $sortedExpected
    }

    It 'should convert hashtable to Label style serialized string with Explode' {
        $hashtable = @{
            name        = 'value'
            anotherName = 'anotherValue'
            number      = 10
        }
        $result = ConvertTo-PodeSerializedString -Hashtable $hashtable -Style 'Label' -Explode
        $sortedResult = SortSerializedString -SerializedString $result -Delimiter ',' -SkipHead '.'
        $expected = '.anotherName=anotherValue,number=10,name=value'
        $sortedExpected = SortSerializedString -SerializedString $expected -Delimiter ',' -SkipHead '.'
        $sortedResult | Should -Be $sortedExpected
    }

    It 'should convert hashtable to Matrix style serialized string' {
        $hashtable = @{
            name        = 'value'
            anotherName = 'anotherValue'
            number      = 10
        }
        $result = ConvertTo-PodeSerializedString -Hashtable $hashtable -Style 'Matrix'
        $sortedResult = SortSerializedString -SerializedString $result -Delimiter ',' -GroupPairs -SkipHead ';id='
        $expected = ';id=name,value,number,10,anotherName,anotherValue'
        $sortedExpected = SortSerializedString -SerializedString $expected -Delimiter ',' -GroupPairs -SkipHead ';id='
        $sortedResult | Should -Be $sortedExpected
    }

    It 'should convert hashtable to Matrix style serialized string with Explode' {
        $hashtable = @{
            name        = 'value'
            anotherName = 'anotherValue'
            number      = 10
        }
        $result = ConvertTo-PodeSerializedString -Hashtable $hashtable -Style 'Matrix' -Explode
        $sortedResult = SortSerializedString -SerializedString $result -Delimiter ';' -SkipHead ';'
        $expected = ';name=value;number=10;anotherName=anotherValue'
        $sortedExpected = SortSerializedString -SerializedString $expected -Delimiter ';' -SkipHead ';'
        $sortedResult | Should -Be $sortedExpected
    }

    It 'should convert hashtable to Form style serialized string' {
        $hashtable = @{
            name        = 'value'
            anotherName = 'anotherValue'
            number      = 10
        }
        $result = ConvertTo-PodeSerializedString -Hashtable $hashtable -Style 'Form'
        $sortedResult = SortSerializedString -SerializedString $result -Delimiter ',' -GroupPairs -SkipHead '?id='
        $expected = '?id=name,value,number,10,anotherName,anotherValue'
        $sortedExpected = SortSerializedString -SerializedString $expected -Delimiter ',' -GroupPairs -SkipHead '?id='
        $sortedResult | Should -Be $sortedExpected
    }

    It 'should convert hashtable to Form style serialized string with Explode' {
        $hashtable = @{
            name        = 'value'
            anotherName = 'anotherValue'
            number      = 10
        }
        $result = ConvertTo-PodeSerializedString -Hashtable $hashtable -Style 'Form' -Explode
        $sortedResult = SortSerializedString -SerializedString $result -Delimiter '&' -SkipHead '?'
        $expected = '?name=value&number=10&anotherName=anotherValue'
        $sortedExpected = SortSerializedString -SerializedString $expected -Delimiter '&' -SkipHead '?'
        $sortedResult | Should -Be $sortedExpected
    }



    It 'should convert hashtable to DeepObject style serialized string' {
        $hashtable = @{
            name        = 'value'
            anotherName = 'anotherValue'
            number      = 10
        }
        $result = ConvertTo-PodeSerializedString -Hashtable $hashtable -Style 'DeepObject' -Explode
        $sortedResult = SortSerializedString -SerializedString $result -Delimiter '&'  -SkipHead '?'  -RemovePattern 'id\[|\]'
        $expected = '?id[name]=value&id[number]=10&id[anotherName]=anotherValue'
        $sortedExpected = SortSerializedString -SerializedString $expected -Delimiter '&' -SkipHead '?'  -RemovePattern 'id\[|\]'
        $sortedResult | Should -Be $sortedExpected
    }

    It 'should convert array to Simple style serialized string' {
        $array = @(3, 4, 5)
        $result =  $array |ConvertTo-PodeSerializedString  -Style 'Simple'
        $result | Should -Be '3,4,5'
    }

    It 'should convert array to Simple style serialized string with Explode' {
        $array = @(3, 4, 5)
        $result =  $array |ConvertTo-PodeSerializedString  -Style 'Simple' -Explode
        $result | Should -Be '3,4,5'
    }

    It 'should convert array to Label style serialized string' {
        $array = @(3, 4, 5)
        $result =  $array |ConvertTo-PodeSerializedString  -Style 'Label'
        $result | Should -Be '.3,4,5'
    }

    It 'should convert array to Label style serialized string with Explode' {
        $array = @(3, 4, 5)
        $result =  $array |ConvertTo-PodeSerializedString  -Style 'Label' -Explode
        $result | Should -Be '.3,4,5'
    }

    It 'should convert array to Matrix style serialized string' {
        $array = @(3, 4, 5)
        $result =  $array |ConvertTo-PodeSerializedString  -Style 'Matrix'
        $result | Should -Be ';id=3,4,5'
    }

    It 'should convert array to Matrix style serialized string with Explode' {
        $array = @(3, 4, 5)
        $result =  $array |ConvertTo-PodeSerializedString  -Style 'Matrix' -Explode
        $result | Should -Be ';id=3;id=4;id=5'
    }

    It 'should convert array to SpaceDelimited style serialized string' {
        $array = @(3, 4, 5)
        $result =  $array |ConvertTo-PodeSerializedString  -Style 'SpaceDelimited'
        $result | Should -Be '?id=3%204%205'
    }

    It 'should convert array to SpaceDelimited style serialized string with Explode' {
        $array = @(3, 4, 5)
        $result =  $array |ConvertTo-PodeSerializedString  -Style 'SpaceDelimited' -Explode
        $result | Should -Be '?id=3&id=4&id=5'
    }

    It 'should convert array to PipeDelimited style serialized string' {
        $array = @(3, 4, 5)
        $result =  $array |ConvertTo-PodeSerializedString  -Style 'PipeDelimited'
        $result | Should -Be  '?id=3|4|5'
    }

    It 'should convert array to PipeDelimited style serialized string with Explode' {
        $array = @(3, 4, 5)
        $result =  $array |ConvertTo-PodeSerializedString  -Style 'PipeDelimited' -Explode
        $result | Should -Be '?id=3&id=4&id=5'
    }


    It 'should throw an error for unsupported serialization type' {
        $hashtable = @{
            name        = 'value'
            anotherName = 'anotherValue'
            number      = 10
        }
        { ConvertTo-PodeSerializedString -Hashtable $hashtable -Style 'Unsupported' } | Should -Throw
    }
}


Describe 'Get-PodePathParameter' {
    BeforeEach {
        # Mock the $WebEvent variable
        $Script:WebEvent = [PSCustomObject]@{
            Parameters = @{ 'action' = 'create' }
        }
    }

    It 'should return the specified parameter value from the web event' {
        # Call the function
        $result = Get-PodePathParameter -Name 'action'

        # Assert the result
        $result | Should -Be 'create'
    }
}


Describe 'Get-PodeQueryParameter' {
    BeforeEach {
        # Mock the $WebEvent variable
        $Script:WebEvent = [PSCustomObject]@{
            Query = @{ 'userId' = '12345' }
        }
    }

    It 'should return the specified query parameter value from the web event' {
        # Call the function
        $result = Get-PodeQueryParameter -Name 'userId'

        # Assert the result
        $result | Should -Be '12345'
    }
}


Describe 'Get-PodeBodyData' {
    BeforeEach {
        # Mock the $WebEvent variable
        $Script:WebEvent = [PSCustomObject]@{
            Data = 'This is the body data'
        }
    }

    It 'should return the body data of the web event' {
        # Call the function
        $result = Get-PodeBodyData

        # Assert the result
        $result | Should -Be 'This is the body data'
    }
}