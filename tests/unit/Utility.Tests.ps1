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

    It 'should convert Simple style serialized string to hashtable' {
        $serialized = 'name=value,anotherName=anotherValue'
        $result = ConvertFrom-PodeSerializedString -SerializedString $serialized
        $expected = @{
            name        = 'value'
            anotherName = 'anotherValue'
        }
        $result.GetEnumerator() | ForEach-Object {
            $expected[$_.Key] | Should -Be $_.Value
        }
    }

    It 'should convert Label style serialized string to hashtable' {
        $serialized = '.name.value.anotherName.anotherValue'
        $result = ConvertFrom-PodeSerializedString -SerializedString $serialized
        $expected = @{
            name        = 'value'
            anotherName = 'anotherValue'
        }
        $result.GetEnumerator() | ForEach-Object {
            $expected[$_.Key] | Should -Be $_.Value
        }
    }

    It 'should convert Matrix style serialized string to hashtable' {
        $serialized = ';name=value;anotherName=anotherValue'
        $result = ConvertFrom-PodeSerializedString -SerializedString $serialized
        $expected = @{
            name        = 'value'
            anotherName = 'anotherValue'
        }
        $result.GetEnumerator() | ForEach-Object {
            $expected[$_.Key] | Should -Be $_.Value
        }
    }

    It 'should convert Query style serialized string to hashtable' {
        $serialized = 'name=value&anotherName=anotherValue'
        $result = ConvertFrom-PodeSerializedString -SerializedString $serialized
        $expected = @{
            name        = 'value'
            anotherName = 'anotherValue'
        }
        $result.GetEnumerator() | ForEach-Object {
            $expected[$_.Key] | Should -Be $_.Value
        }
    }

    It 'should convert Form style serialized string to hashtable' {
        $serialized = 'name=value&anotherName=anotherValue'
        $result = ConvertFrom-PodeSerializedString -SerializedString $serialized
        $expected = @{
            name        = 'value'
            anotherName = 'anotherValue'
        }
        $result.GetEnumerator() | ForEach-Object {
            $expected[$_.Key] | Should -Be $_.Value
        }
    }

    It 'should convert SpaceDelimited style serialized string to hashtable' {
        $serialized = 'name=value anotherName=anotherValue'
        $result = ConvertFrom-PodeSerializedString -SerializedString $serialized
        $expected = @{
            name        = 'value'
            anotherName = 'anotherValue'
        }
        $result.GetEnumerator() | ForEach-Object {
            $expected[$_.Key] | Should -Be $_.Value
        }
    }

    It 'should convert PipeDelimited style serialized string to hashtable' {
        $serialized = 'name=value|anotherName=anotherValue'
        $result = ConvertFrom-PodeSerializedString -SerializedString $serialized
        $expected = @{
            name        = 'value'
            anotherName = 'anotherValue'
        }
        $result.GetEnumerator() | ForEach-Object {
            $expected[$_.Key] | Should -Be $_.Value
        }
    }

    It 'should convert DeepObject style serialized string to hashtable' {
        $serialized = 'name[name]=value,anotherName[anotherName]=anotherValue'
        $result = ConvertFrom-PodeSerializedString -SerializedString $serialized
        $expected = @{
            name        = 'value'
            anotherName = 'anotherValue'
        }
        $result.GetEnumerator() | ForEach-Object {
            $expected[$_.Key] | Should -Be $_.Value
        }
    }

    It 'should convert DeepObjectExplode style serialized string to hashtable' {
        $serialized = 'name[name]=value&anotherName[anotherName]=anotherValue'
        $result = ConvertFrom-PodeSerializedString -SerializedString $serialized
        $expected = @{
            name        = 'value'
            anotherName = 'anotherValue'
        }
        $result.GetEnumerator() | ForEach-Object {
            $expected[$_.Key] | Should -Be $_.Value
        }
    }

    It 'should throw an error for unsupported serialization format' {
        $serialized = 'unsupportedFormat'
        { ConvertFrom-PodeSerializedString -SerializedString $serialized } | Should -Throw ($PodeLocale.UnsupportedSerializationTypeExceptionMessage)
    }
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
        $result -eq '.name.value.anotherName.anotherValue' -or   $result -eq '.anotherName.anotherValue.name.value'| Should -BeTrue
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
