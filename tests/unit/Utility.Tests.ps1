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
            $result = ConvertFrom-PodeSerializedString -SerializedInput $serialized -Style Simple -Explode
            $result | Should -be '5'
        }

        It 'Convert Simple(Explode) style serialized string to hashtable' {
            $serialized = 'role=admin,firstName=Alex'
            $result = ConvertFrom-PodeSerializedString -SerializedInput $serialized -Style Simple -Explode
            $expected = @{
                role      = 'admin'
                firstName = 'Alex'
            }
            # Ensure both hashtables have the same number of keys
            $result.Keys.Count | Should -Be $expected.Keys.Count

            # Compare values for each key
            foreach ($key in $expected.Keys) {
                $result[$key] | Should -Be $expected[$key]
            }
        }

        It 'Convert Simple(Explode) style serialized string to array' {
            $serialized = '3,4,5'
            $result = ConvertFrom-PodeSerializedString -SerializedInput $serialized -Style Simple -Explode
            $result | Should -be  @('3', '4', '5')
        }

        It 'Convert Simple style serialized string to a primitive value' {
            $serialized = '5'
            $result = ConvertFrom-PodeSerializedString -SerializedInput $serialized -Style Simple
            $result | Should -be '5'
        }

        It 'Convert Simple style serialized string to hashtable' {
            $serialized = 'role,admin,firstName,Alex'
            $result = ConvertFrom-PodeSerializedString -SerializedInput $serialized -Style Simple
            $expected = @{
                role      = 'admin'
                firstName = 'Alex'
            }
            # Ensure both hashtables have the same number of keys
            $result.Keys.Count | Should -Be $expected.Keys.Count

            # Compare values for each key
            foreach ($key in $expected.Keys) {
                $result[$key] | Should -Be $expected[$key]
            }
        }

        It 'Convert Simple style serialized string to array' {
            $serialized = '3,4,5'
            $result = ConvertFrom-PodeSerializedString -SerializedInput $serialized -Style Simple
            $result | Should -be  @('3', '4', '5')
        }


        It 'Convert Label(Explode) style serialized string to a primitive value' {
            $serialized = '.5'
            $result = ConvertFrom-PodeSerializedString -SerializedInput $serialized -Style Label -Explode
            $result | Should -be 5
        }

        It 'Convert Label(Explode) style serialized string to hashtable' {
            $serialized = '.role=admin.firstName=Alex'
            $result = ConvertFrom-PodeSerializedString -SerializedInput $serialized -Style Label -Explode
            $expected = @{
                role      = 'admin'
                firstName = 'Alex'
            }
            # Ensure both hashtables have the same number of keys
            $result.Keys.Count | Should -Be $expected.Keys.Count

            # Compare values for each key
            foreach ($key in $expected.Keys) {
                $result[$key] | Should -Be $expected[$key]
            }
        }

        It 'Convert Label(Explode) style serialized string to array' {
            $serialized = '.3,4,5'
            $result = ConvertFrom-PodeSerializedString -SerializedInput $serialized -Style Label -Explode
            $result | Should -be  @('3', '4', '5')
        }

        It 'Convert Simple style serialized string to a primitive value' {
            $serialized = '.5'
            $result = ConvertFrom-PodeSerializedString -SerializedInput $serialized -Style Label
            $result | Should -be 5
        }

        It 'Convert Label style serialized string to hashtable' {
            $serialized = '.role,admin,firstName,Alex'
            $result = ConvertFrom-PodeSerializedString -SerializedInput $serialized -Style Label
            $expected = @{
                role      = 'admin'
                firstName = 'Alex'
            }
            # Ensure both hashtables have the same number of keys
            $result.Keys.Count | Should -Be $expected.Keys.Count

            # Compare values for each key
            foreach ($key in $expected.Keys) {
                $result[$key] | Should -Be $expected[$key]
            }
        }

        It 'Convert Label style serialized string to array' {
            $serialized = '.3,4,5'
            $result = ConvertFrom-PodeSerializedString -SerializedInput $serialized -Style Label
            $result | Should -be  @('3', '4', '5')
        }



        It 'Convert Matrix(Explode) style serialized string to a primitive value' {
            $serialized = ';id=5'
            $result = ConvertFrom-PodeSerializedString -SerializedInput $serialized -Style Matrix -Explode
            $result | Should -be 5
        }

        It 'Convert Matrix(Explode) style serialized string to hashtable' {
            $serialized = ';role=admin;firstName=Alex'
            $result = ConvertFrom-PodeSerializedString -SerializedInput $serialized -Style Matrix -Explode
            $expected = @{
                role      = 'admin'
                firstName = 'Alex'
            }
            # Ensure both hashtables have the same number of keys
            $result.Keys.Count | Should -Be $expected.Keys.Count

            # Compare values for each key
            foreach ($key in $expected.Keys) {
                $result[$key] | Should -Be $expected[$key]
            }
        }

        It 'Convert Matrix(Explode) style serialized string to array' {
            $serialized = ';id=3;id=4;id=5'
            $result = ConvertFrom-PodeSerializedString -SerializedInput $serialized -Style Matrix -Explode
            $result | Should -be  @('3', '4', '5')
        }

        It 'Convert Simple style serialized string to a primitive value' {
            $serialized = ';id=5'
            $result = ConvertFrom-PodeSerializedString -SerializedInput $serialized -Style Matrix
            $result | Should -be 5
        }

        It 'Convert Matrix style serialized string to hashtable' {
            $serialized = ';id=role,admin,firstName,Alex'
            $result = ConvertFrom-PodeSerializedString -SerializedInput $serialized -Style Matrix
            $expected = @{
                role      = 'admin'
                firstName = 'Alex'
            }
            # Ensure both hashtables have the same number of keys
            $result.Keys.Count | Should -Be $expected.Keys.Count

            # Compare values for each key
            foreach ($key in $expected.Keys) {
                $result[$key] | Should -Be $expected[$key]
            }
        }

        It 'Convert Matrix style serialized string to array' {
            $serialized = ';id=3,4,5'
            $result = ConvertFrom-PodeSerializedString -SerializedInput $serialized -Style Matrix
            $result | Should -be  @('3', '4', '5')
        }


        It 'Convert Matrix(Explode) style serialized string to a primitive value' {
            $serialized = ';id=5'
            $result = ConvertFrom-PodeSerializedString -SerializedInput $serialized -Style Matrix -Explode
            $result | Should -be 5
        }

        It 'Convert Matrix(Explode) style serialized string to hashtable' {
            $serialized = ';role=admin;firstName=Alex'
            $result = ConvertFrom-PodeSerializedString -SerializedInput $serialized -Style Matrix -Explode
            $expected = @{
                role      = 'admin'
                firstName = 'Alex'
            }
            # Ensure both hashtables have the same number of keys
            $result.Keys.Count | Should -Be $expected.Keys.Count

            # Compare values for each key
            foreach ($key in $expected.Keys) {
                $result[$key] | Should -Be $expected[$key]
            }
        }

        It 'Convert Matrix(Explode) style serialized string to array' {
            $serialized = ';id=3;id=4;id=5'
            $result = ConvertFrom-PodeSerializedString -SerializedInput $serialized -Style Matrix -Explode
            $result | Should -be  @('3', '4', '5')
        }

        It 'Convert Matrix style serialized string to a primitive value' {
            $serialized = ';id=5'
            $result = ConvertFrom-PodeSerializedString -SerializedInput $serialized -Style Matrix
            $result | Should -be 5
        }

        It 'Convert Matrix style serialized string to hashtable' {
            $serialized = ';id=role,admin,firstName,Alex'
            $result = ConvertFrom-PodeSerializedString -SerializedInput $serialized -Style Matrix
            $expected = @{
                role      = 'admin'
                firstName = 'Alex'
            }
            # Ensure both hashtables have the same number of keys
            $result.Keys.Count | Should -Be $expected.Keys.Count

            # Compare values for each key
            foreach ($key in $expected.Keys) {
                $result[$key] | Should -Be $expected[$key]
            }
        }

        It 'Convert Matrix style serialized string to array' {
            $serialized = ';id=3,4,5'
            $result = ConvertFrom-PodeSerializedString -SerializedInput $serialized -Style Matrix
            $result | Should -be  @('3', '4', '5')
        }
    }

    Describe 'Query Parameters' {
        It 'Convert Form(Explode) style serialized string to a primitive value' {
            $serialized = '?id=5'
            $result = ConvertFrom-PodeSerializedString -SerializedInput $serialized -Style Form -Explode
            $result | Should -be 5
        }

        It 'Convert Form(Explode) style serialized string to hashtable' {
            $serialized = '?role=admin&firstName=Alex'
            $result = ConvertFrom-PodeSerializedString -SerializedInput $serialized -Style Form -Explode
            $expected = @{
                role      = 'admin'
                firstName = 'Alex'
            }
            # Ensure both hashtables have the same number of keys
            $result.Keys.Count | Should -Be $expected.Keys.Count

            # Compare values for each key
            foreach ($key in $expected.Keys) {
                $result[$key] | Should -Be $expected[$key]
            }
        }

        It 'Convert Form(Explode) style serialized string to array' {
            $serialized = '?id=3&id=4&id=5'
            $result = ConvertFrom-PodeSerializedString -SerializedInput $serialized -Style Form -Explode
            $result | Should -be  @('3', '4', '5')
        }

        It 'Convert Form style serialized string to a primitive value' {
            $serialized = '?id=5'
            $result = ConvertFrom-PodeSerializedString -SerializedInput $serialized -Style Form
            $result | Should -be 5
        }

        It 'Convert Form style serialized string to hashtable' {
            $serialized = '?id=role,admin,firstName,Alex'
            $result = ConvertFrom-PodeSerializedString -SerializedInput $serialized -Style Form
            $expected = @{
                role      = 'admin'
                firstName = 'Alex'
            }
            # Ensure both hashtables have the same number of keys
            $result.Keys.Count | Should -Be $expected.Keys.Count

            # Compare values for each key
            foreach ($key in $expected.Keys) {
                $result[$key] | Should -Be $expected[$key]
            }
        }

        It 'Convert Form style serialized string to array' {
            $serialized = '?id=3,4,5'
            $result = ConvertFrom-PodeSerializedString -SerializedInput $serialized -Style Form
            $result | Should -be  @('3', '4', '5')
        }


        It 'Convert SpaceDelimited(Explode) style serialized string to array' {
            $serialized = '?id=3&id=4&id=5'
            $result = ConvertFrom-PodeSerializedString -SerializedInput $serialized -Style SpaceDelimited -Explode
            $result | Should -be  @('3', '4', '5')
        }

        It 'Convert SpaceDelimited style serialized string to array' {
            $serialized = '?id=3 4 5'
            $result = ConvertFrom-PodeSerializedString -SerializedInput $serialized -Style SpaceDelimited
            $result | Should -be  @('3', '4', '5')
        }


        It 'Convert pipeDelimited(Explode) style serialized string to array' {
            $serialized = '?id=3&id=4&id=5'
            $result = ConvertFrom-PodeSerializedString -SerializedInput $serialized -Style pipeDelimited -Explode
            $result | Should -be  @('3', '4', '5')
        }

        It 'Convert pipeDelimited style serialized string to array' {
            $serialized = '?id=3|4|5'
            $result = ConvertFrom-PodeSerializedString -SerializedInput $serialized -Style pipeDelimited
            $result | Should -be  @('3', '4', '5')
        }

        It 'Convert DeepObject(Explode) style serialized string to hashtable' {
            $serialized = '?id[role]=admin&id[firstName]=Alex'
            $result = ConvertFrom-PodeSerializedString -SerializedInput $serialized -Style DeepObject
            $expected = @{
                role      = 'admin'
                firstName = 'Alex'
            }
            # Ensure both hashtables have the same number of keys
            $result.Keys.Count | Should -Be $expected.Keys.Count

            # Compare values for each key
            foreach ($key in $expected.Keys) {
                $result[$key] | Should -Be $expected[$key]
            }
        }

        It 'Convert DeepObject(Explode) style nested object serialized to hashtable' {
            $serialized = '?id[role][type]=admin&id[role][level]=high&id[firstName]=Alex'
            $result = ConvertFrom-PodeSerializedString -SerializedInput $serialized -Style DeepObject
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
            $result = ConvertFrom-PodeSerializedString -SerializedInput $serialized -Style Simple -Explode
            $result['X-MyHeader'] | Should -be 5
        }

        It 'Convert Simple(Explode) style serialized string to hashtable' {
            $serialized = 'X-MyHeader: role=admin,firstName=Alex'
            $result = ConvertFrom-PodeSerializedString -SerializedInput $serialized -Style Simple -Explode
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
            $result = ConvertFrom-PodeSerializedString -SerializedInput $serialized -Style Simple -Explode
            $result['X-MyHeader'] | Should -be  @('3', '4', '5')
        }

        It 'Convert Simple style serialized string to a primitive value' {
            $serialized = 'X-MyHeader: 5'
            $result = ConvertFrom-PodeSerializedString -SerializedInput $serialized -Style Simple
            $result['X-MyHeader'] | Should -be 5
        }

        It 'Convert Simple style serialized string to hashtable' {
            $serialized = 'X-MyHeader: role,admin,firstName,Alex'
            $result = ConvertFrom-PodeSerializedString -SerializedInput $serialized -Style Simple
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
            $result = ConvertFrom-PodeSerializedString -SerializedInput $serialized -Style Simple
            $result['X-MyHeader'] | Should -be  @('3', '4', '5')
        }
    }

    Describe 'Cookie Parameters' {
        It 'Convert Form(Explode) style serialized string to a primitive value' {
            $serialized = 'Cookie: id=5'
            $result = ConvertFrom-PodeSerializedString -SerializedInput $serialized -Style Form -Explode
            $result['Cookie'] | Should -be 5
        }

        It 'Convert Form style serialized string to a primitive value' {
            $serialized = 'Cookie: id=5'
            $result = ConvertFrom-PodeSerializedString -SerializedInput $serialized -Style Form
            $result['Cookie'] | Should -be 5
        }

        It 'Convert Form style serialized string to hashtable' {
            $serialized = 'Cookie: id=role,admin,firstName,Alex'
            $result = ConvertFrom-PodeSerializedString -SerializedInput $serialized -Style Form
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
            $result = ConvertFrom-PodeSerializedString -SerializedInput $serialized -Style Form
            $result['Cookie'] | Should -be  @('3', '4', '5')
        }
    }

    Describe 'Edge cases' {

        It 'Throws an error for invalid serialization style' {
            $serialized = 'some data'
            { ConvertFrom-PodeSerializedString -SerializedInput $serialized -Style 'InvalidStyle' } | Should -Throw
        }

        It 'Properly decodes URL-encoded characters' {
            $serialized = 'name%3DJohn%20Doe%2Cage%3D30'

            $result = ConvertFrom-PodeSerializedString -SerializedInput $serialized -Style Simple -Explode -UrlDecode

            # Define the expected hashtable
            $expected = @{
                'name' = 'John Doe'
                'age'  = '30'
            }
            $result.Keys.Count | Should -Be $expected.Keys.Count
            foreach ($key in $expected.Keys) {
                $result[$key] | Should -Be $expected[$key]
            }
        }


        It 'Handles special characters in keys and values' {
            $serialized = 'na!me=Jo@hn,do#e=30$'
            $result = ConvertFrom-PodeSerializedString -SerializedInput $serialized -Style Simple -Explode
            $expected = @{
                'na!me' = 'Jo@hn'
                'do#e'  = '30$'
            }
            $result.Keys.Count | Should -Be $expected.Keys.Count
            foreach ($key in $expected.Keys) {
                $result[$key] | Should -Be $expected[$key]
            }
        }

        It 'Parses deeply nested structures in DeepObject style' {
            $serialized = '?user[address][street]=Main St&user[address][city]=Anytown&user[details][age]=30'
            $result = ConvertFrom-PodeSerializedString -SerializedInput $serialized -Style DeepObject -ParameterName 'user'
            $expected = @{
                'address' = @{
                    'street' = 'Main St'
                    'city'   = 'Anytown'
                }
                'details' = @{
                    'age' = '30'
                }
            }
            # Recursive comparison function
            function Compare-PodeHashtable($expected, $actual) {
                $expected.Keys.Count | Should -Be $actual.Keys.Count
                foreach ($key in $expected.Keys) {
                    $actual.ContainsKey($key) | Should -BeTrue -Because "Key '$key' is missing."
                    if ($expected[$key] -is [hashtable]) {
                        Compare-PodeHashtable  $expected[$key] $actual[$key]
                    }
                    else {
                        $actual[$key] | Should -Be $expected[$key]
                    }
                }
            }
            Compare-PodeHashtable  $expected $result
        }


        It 'Handles multiple occurrences of the same parameter in Query style' {
            $serialized = '?id=1&id=2&id=3'
            $result = ConvertFrom-PodeSerializedString -SerializedInput $serialized -Style Form -Explode -ParameterName 'id'
            $result | Should -Be @('1', '2', '3')
        }

        It 'Handles single value in SpaceDelimited style without wrapping in an array' {
            $serialized = '?id=42'
            $result = ConvertFrom-PodeSerializedString -SerializedInput $serialized -Style SpaceDelimited -ParameterName 'id'
            $result | Should -Be '42'
        }

        It 'Parses Matrix style without explode correctly' {
            $serialized = ';id=1,2,3'
            $result = ConvertFrom-PodeSerializedString -SerializedInput $serialized -Style Matrix -ParameterName 'id'
            $result | Should -Be @('1', '2', '3')
        }
        It 'Handles missing dot prefix in Label style gracefully' {
            $serialized = 'name=value'
            $result = ConvertFrom-PodeSerializedString -SerializedInput $serialized -Style Label -Explode
            $expected = @{ 'name' = 'value' }
            $result.Keys.Count | Should -Be $expected.Keys.Count
            foreach ($key in $expected.Keys) {
                $result[$key] | Should -Be $expected[$key]
            }
        }

        It 'Parses headers with multiple values correctly' {
            $serialized = 'X-Custom-Header: value1,value2,value3'
            $result = ConvertFrom-PodeSerializedString -SerializedInput $serialized -Style Simple
            $result['X-Custom-Header'] | Should -Be @('value1', 'value2', 'value3')
        }

        It 'return the SerializedString content for malformed input string' {
            $serialized = 'name===value'
            ConvertFrom-PodeSerializedString -SerializedInput $serialized -Style Simple -Explode | Should -be $serialized
        }

        It 'Throws an error for unsupported characters in Style parameter' {
            { ConvertFrom-PodeSerializedString -SerializedInput 'data' -Style 'S!mple' } | Should -Throw
        }

        It 'Parses complex real-world query strings correctly' {
            $serialized = '?filter=name%20eq%20%27John%27&sort=asc&limit=10'

            $result = ConvertFrom-PodeSerializedString -SerializedInput $serialized -Style Form -Explode -UrlDecode

            $expected = @{
                'filter' = "name eq 'John'"
                'sort'   = 'asc'
                'limit'  = '10'
            }
            $result.Keys.Count | Should -Be $expected.Keys.Count
            foreach ($key in $expected.Keys) {
                $result[$key] | Should -Be $expected[$key]
            }
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
        $result = ConvertTo-PodeSerializedString -InputObject $hashtable -Style 'Simple'
        $sortedResult = SortSerializedString -SerializedInput $result -Delimiter ',' -GroupPairs
        $expected = 'name,value,number,10,anotherName,anotherValue'
        $sortedExpected = SortSerializedString -SerializedInput $expected -Delimiter ',' -GroupPairs
        $sortedResult | Should -Be $sortedExpected
    }

    It 'should convert hashtable to Simple style serialized string with Explode' {
        $hashtable = @{
            name        = 'value'
            anotherName = 'anotherValue'
            number      = 10
        }
        $result = ConvertTo-PodeSerializedString -InputObject $hashtable -Style 'Simple' -Explode
        $sortedResult = SortSerializedString -SerializedInput $result -Delimiter ','
        $expected = 'name=value,number=10,anotherName=anotherValue'
        $sortedExpected = SortSerializedString -SerializedInput $expected -Delimiter ','
        $sortedResult | Should -Be $sortedExpected
    }

    It 'should convert hashtable to Label style serialized string' {
        $hashtable = @{
            name        = 'value'
            anotherName = 'anotherValue'
            number      = 10
        }
        $result = ConvertTo-PodeSerializedString -InputObject $hashtable -Style 'Label'

        $sortedResult = SortSerializedString -SerializedInput $result -Delimiter ',' -SkipHead '.'
        $expected = '.anotherName,anotherValue,number,10,name,value'
        $sortedExpected = SortSerializedString -SerializedInput $expected -Delimiter ',' -SkipHead '.'
        $sortedResult | Should -Be $sortedExpected
    }

    It 'should convert hashtable to Label style serialized string with Explode' {
        $hashtable = @{
            name        = 'value'
            anotherName = 'anotherValue'
            number      = 10
        }
        $result = ConvertTo-PodeSerializedString -InputObject $hashtable -Style 'Label' -Explode
        $sortedResult = SortSerializedString -SerializedInput $result -Delimiter ',' -SkipHead '.'
        $expected = '.anotherName=anotherValue,number=10,name=value'
        $sortedExpected = SortSerializedString -SerializedInput $expected -Delimiter ',' -SkipHead '.'
        $sortedResult | Should -Be $sortedExpected
    }

    It 'should convert hashtable to Matrix style serialized string' {
        $hashtable = @{
            name        = 'value'
            anotherName = 'anotherValue'
            number      = 10
        }
        $result = ConvertTo-PodeSerializedString -InputObject $hashtable -Style 'Matrix'
        $sortedResult = SortSerializedString -SerializedInput $result -Delimiter ',' -GroupPairs -SkipHead ';id='
        $expected = ';id=name,value,number,10,anotherName,anotherValue'
        $sortedExpected = SortSerializedString -SerializedInput $expected -Delimiter ',' -GroupPairs -SkipHead ';id='
        $sortedResult | Should -Be $sortedExpected
    }

    It 'should convert hashtable to Matrix style serialized string with Explode' {
        $hashtable = @{
            name        = 'value'
            anotherName = 'anotherValue'
            number      = 10
        }
        $result = ConvertTo-PodeSerializedString -InputObject $hashtable -Style 'Matrix' -Explode
        $sortedResult = SortSerializedString -SerializedInput $result -Delimiter ';' -SkipHead ';'
        $expected = ';name=value;number=10;anotherName=anotherValue'
        $sortedExpected = SortSerializedString -SerializedInput $expected -Delimiter ';' -SkipHead ';'
        $sortedResult | Should -Be $sortedExpected
    }

    It 'should convert hashtable to Form style serialized string' {
        $hashtable = @{
            name        = 'value'
            anotherName = 'anotherValue'
            number      = 10
        }
        $result = ConvertTo-PodeSerializedString -InputObject $hashtable -Style 'Form'
        $sortedResult = SortSerializedString -SerializedInput $result -Delimiter ',' -GroupPairs -SkipHead '?id='
        $expected = '?id=name,value,number,10,anotherName,anotherValue'
        $sortedExpected = SortSerializedString -SerializedInput $expected -Delimiter ',' -GroupPairs -SkipHead '?id='
        $sortedResult | Should -Be $sortedExpected
    }

    It 'should convert hashtable to Form style serialized string with Explode' {
        $hashtable = @{
            name        = 'value'
            anotherName = 'anotherValue'
            number      = 10
        }
        $result = ConvertTo-PodeSerializedString -InputObject $hashtable -Style 'Form' -Explode
        $sortedResult = SortSerializedString -SerializedInput $result -Delimiter '&' -SkipHead '?'
        $expected = '?name=value&number=10&anotherName=anotherValue'
        $sortedExpected = SortSerializedString -SerializedInput $expected -Delimiter '&' -SkipHead '?'
        $sortedResult | Should -Be $sortedExpected
    }



    It 'should convert hashtable to DeepObject style serialized string' {
        $hashtable = @{
            name        = 'value'
            anotherName = 'anotherValue'
            number      = 10
        }
        $result = ConvertTo-PodeSerializedString -InputObject $hashtable -Style 'DeepObject' -Explode
        $sortedResult = SortSerializedString -SerializedInput $result -Delimiter '&'  -SkipHead '?' -RemovePattern 'id\[|\]'
        $expected = '?id[name]=value&id[number]=10&id[anotherName]=anotherValue'
        $sortedExpected = SortSerializedString -SerializedInput $expected -Delimiter '&' -SkipHead '?' -RemovePattern 'id\[|\]'
        $sortedResult | Should -Be $sortedExpected
    }

    It 'should convert array to Simple style serialized string' {
        $array = @(3, 4, 5)
        $result = $array | ConvertTo-PodeSerializedString  -Style 'Simple'
        $result | Should -Be '3,4,5'
    }

    It 'should convert array to Simple style serialized string with Explode' {
        $array = @(3, 4, 5)
        $result = $array | ConvertTo-PodeSerializedString  -Style 'Simple' -Explode
        $result | Should -Be '3,4,5'
    }

    It 'should convert array to Label style serialized string' {
        $array = @(3, 4, 5)
        $result = $array | ConvertTo-PodeSerializedString  -Style 'Label'
        $result | Should -Be '.3,4,5'
    }

    It 'should convert array to Label style serialized string with Explode' {
        $array = @(3, 4, 5)
        $result = $array | ConvertTo-PodeSerializedString  -Style 'Label' -Explode
        $result | Should -Be '.3,4,5'
    }

    It 'should convert array to Matrix style serialized string' {
        $array = @(3, 4, 5)
        $result = $array | ConvertTo-PodeSerializedString  -Style 'Matrix'
        $result | Should -Be ';id=3,4,5'
    }

    It 'should convert array to Matrix style serialized string with Explode' {
        $array = @(3, 4, 5)
        $result = $array | ConvertTo-PodeSerializedString  -Style 'Matrix' -Explode
        $result | Should -Be ';id=3;id=4;id=5'
    }

    It 'should convert array to SpaceDelimited style serialized string' {
        $array = @(3, 4, 5)
        $result = $array | ConvertTo-PodeSerializedString  -Style 'SpaceDelimited'
        $result | Should -Be '?id=3%204%205'
    }

    It 'should convert array to SpaceDelimited style serialized string with Explode' {
        $array = @(3, 4, 5)
        $result = $array | ConvertTo-PodeSerializedString  -Style 'SpaceDelimited' -Explode
        $result | Should -Be '?id=3&id=4&id=5'
    }

    It 'should convert array to PipeDelimited style serialized string' {
        $array = @(3, 4, 5)
        $result = $array | ConvertTo-PodeSerializedString  -Style 'PipeDelimited'
        $result | Should -Be  '?id=3%7C4%7C5'
    }

    It 'should convert array to PipeDelimited style serialized string with Explode' {
        $array = @(3, 4, 5)
        $result = $array | ConvertTo-PodeSerializedString  -Style 'PipeDelimited' -Explode
        $result | Should -Be '?id=3&id=4&id=5'
    }


    It 'should throw an error for unsupported serialization style' {
        $hashtable = @{
            name        = 'value'
            anotherName = 'anotherValue'
            number      = 10
        }
        { ConvertTo-PodeSerializedString -InputObject $hashtable -Style 'Unsupported' } | Should -Throw
    }


    It 'should convert array to Matrix style without URL encoding' {
        $array = @('value one', 'value/two', 'value&three')
        $result = $array | ConvertTo-PodeSerializedString -Style 'Matrix' -NoUrlEncode
        $result | Should -Be ';id=value one,value/two,value&three'
    }

    It 'should handle special characters with URL encoding' {
        $array = @('value one', 'value/two', 'value&three')
        $result = $array | ConvertTo-PodeSerializedString -Style 'Matrix'
        $result | Should -Be ';id=value%20one,value%2Ftwo,value%26three'
    }

    It 'should handle empty array input' {
        $array = @()
        $result = $array | ConvertTo-PodeSerializedString -Style 'Simple'
        $result | Should -Be ''
    }

    It 'should handle empty hashtable input by returning an empty string' {
        $hashtable = @{}
        $result = ConvertTo-PodeSerializedString -InputObject $hashtable -Style 'Simple'
        $result | Should -Be ''
    }

    It 'should use custom parameter name' {
        $array = @(3, 4, 5)
        $result = $array | ConvertTo-PodeSerializedString -Style 'Matrix' -ParameterName 'customId'
        $result | Should -Be ';customId=3,4,5'
    }

    It 'should correctly serialize single-element array' {
        $array = @('singleValue')
        $result = ConvertTo-PodeSerializedString -InputObject $array -Style 'Simple'
        $result | Should -Be 'singleValue'
    }

    It 'should correctly serialize single-entry hashtable' {
        $hashtable = @{ key = 'value' }
        $result = ConvertTo-PodeSerializedString -InputObject $hashtable -Style 'Form' -Explode
        $result | Should -Be '?key=value'
    }

    It 'should URL-encode special characters in keys and values' {
        $hashtable = @{
            'name with spaces' = 'value/with/special&chars'
        }
        $result = ConvertTo-PodeSerializedString -InputObject $hashtable -Style 'Form' -Explode
        $expected = '?name%20with%20spaces=value%2Fwith%2Fspecial%26chars'
        $result | Should -Be $expected
    }
    It 'should not URL-encode when NoUrlEncode switch is used' {
        $hashtable = @{
            'name with spaces' = 'value/with/special&chars'
        }
        $result = ConvertTo-PodeSerializedString -InputObject $hashtable -Style 'Form' -Explode -NoUrlEncode
        $expected = '?name with spaces=value/with/special&chars'
        $result | Should -Be $expected
    }

    It 'should use custom ParameterName in serialization' {
        $array = @(1, 2, 3)
        $result = ConvertTo-PodeSerializedString -InputObject $array -Style 'Matrix' -ParameterName 'customParam'
        $result | Should -Be ';customParam=1,2,3'
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