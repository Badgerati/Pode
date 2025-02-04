[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '')]
param()
BeforeAll {
    Add-Type -AssemblyName 'System.Net.Http' -ErrorAction SilentlyContinue
    $path = $PSCommandPath
    $src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit', '/src/'
    Get-ChildItem "$($src)/*.ps1" -Recurse | Resolve-Path | ForEach-Object { . $_ }
    Import-LocalizedData -BindingVariable PodeLocale -BaseDirectory (Join-Path -Path $src -ChildPath 'Locales') -FileName 'Pode'
    # Import Pode Assembly
    $helperPath = (Split-Path -Parent -Path $path) -ireplace 'unit', 'shared'
    . "$helperPath/TestHelper.ps1"
}

Describe 'ConvertFrom-PodeCustomDictionaryJson' {
    BeforeAll {
        $PodeContext = @{Server = @{ ApplicationName = 'Pester' } }
    }
    It 'Should correctly deserialize a Hashtable' {
        $json = '{"Metadata":{"Product":"Pode","Version":"[dev]","Timestamp":"2025-02-04T01:30:24.6971206Z","Application":"Pester"},"Data":{"Type":"Hashtable","Items":[{"Key":"Foo","Value":"Bar"},{"Key":"Baz","Value":42}]}}'
        $result = ConvertFrom-PodeCustomDictionaryJson -Json $json

        $result | Should -BeOfType Hashtable
        $result['Foo'] | Should -Be 'Bar'
        $result['Baz'] | Should -Be 42
    }

    It 'Should correctly deserialize a ConcurrentDictionary' {
        $json = '{"Metadata":{"Product":"Pode","Version":"[dev]","Timestamp":"2025-02-04T01:30:24.6971206Z","Application":"Pester"},"Data":{"Type":"ConcurrentDictionary","Items":[{"Key":"Key1","Value":123},{"Key":"Key2","Value":"Test"}]}}'
        $result = ConvertFrom-PodeCustomDictionaryJson -Json $json

        $result | Should -BeOfType 'System.Collections.Concurrent.ConcurrentDictionary[string, object]'
        $result.ContainsKey('Key1') | Should -BeTrue
        $result['Key1'] | Should -Be 123
        $result['Key2'] | Should -Be 'Test'
    }

    It 'Should correctly deserialize an OrderedDictionary' {
        $json = '{"Metadata":{"Product":"Pode","Version":"[dev]","Timestamp":"2025-02-04T01:30:24.6971206Z","Application":"Pester"},"Data":{"Type":"OrderedDictionary","Items":[{"Key":"First","Value":1},{"Key":"Second","Value":2}]}}'
        $result = ConvertFrom-PodeCustomDictionaryJson -Json $json

        $result | Should -BeOfType 'System.Collections.Specialized.OrderedDictionary'
        $result['First'] | Should -Be 1
        $result['Second'] | Should -Be 2
    }

    It 'Should correctly deserialize a ConcurrentBag' {
        $json = '{"Metadata":{"Product":"Pode","Version":"[dev]","Timestamp":"2025-02-04T01:30:24.6971206Z","Application":"Pester"},"Data":{"Type":"ConcurrentBag","Items":["Item1","Item2","Item3"]}}'
        $result = ConvertFrom-PodeCustomDictionaryJson -Json $json

        $result.GetType().Name | Should -Be 'ConcurrentBag`1'
        $result.Count | Should -Be 3
    }

    It 'Should correctly deserialize a PSCustomObject' {
        $json = '{"Metadata":{"Product":"Pode","Version":"[dev]","Timestamp":"2025-02-04T01:30:24.6971206Z","Application":"Pester"},"Data":{"Name":"John","Age":30,"__PsTypeName__":"CustomType"}}'
        $result = ConvertFrom-PodeCustomDictionaryJson -Json $json

        $result | Should -BeOfType PSCustomObject
        $result.Name | Should -Be 'John'
        $result.Age | Should -Be 30
        $result.PSTypeNames[0] | Should -Be 'CustomType'
    }

    It 'Should correctly deserialize a recursively nested dictionary' {
        $json = '{"Metadata":{"Product":"Pode","Version":"[dev]","Timestamp":"2025-02-04T01:30:24.6971206Z","Application":"Pester"},"Data":{"Type":"Hashtable","Items":[{"Key":"Level1","Value":{"Type":"OrderedDictionary","Items":[{"Key":"Level2","Value":{"Type":"Hashtable","Items":[{"Key":"Final","Value":"Reached"}]}}]}}]}}'
        $result = ConvertFrom-PodeCustomDictionaryJson -Json $json

        $result | Should -BeOfType Hashtable
        $result['Level1'] | Should -BeOfType 'System.Collections.Specialized.OrderedDictionary'
        $result['Level1']['Level2'] | Should -BeOfType Hashtable
        $result['Level1']['Level2']['Final'] | Should -Be 'Reached'
    }
}


Describe 'ConvertTo-PodeCustomDictionaryJson' {
    BeforeAll {
        $PodeContext = @{Server = @{ ApplicationName = 'Pester' } }
        mock Get-Date { '2025-02-04T01:54:30.6400033Z' }
    }
    It 'Should correctly serialize a recursively nested dictionary' {
        $dictionary = @{ 'Level1' = @{ 'Level2' = @{ 'Final' = 'Reached' } } }
        $json = ConvertTo-PodeCustomDictionaryJson -Dictionary $dictionary | ConvertFrom-Json | Convert-PsCustomObjectToOrderedHashtable
        $expected = '{"Metadata":{"Product":"Pode","Version":"[dev]","Timestamp":"2025-02-04T01:54:30.6400033Z","Application":"Pester"},"Data":{"Type":"Hashtable","Items":[{"Key":"Level1","Value":{"Type":"Hashtable","Items":[{"Key":"Level2","Value":{"Type":"Hashtable","Items":[{"Key":"Final","Value":"Reached"}]}}]}}]}}' |
            ConvertFrom-Json | Convert-PsCustomObjectToOrderedHashtable
        Compare-Hashtable $json $expected | Should -BeTrue
    }

    It 'Should correctly serialize a dictionary with multiple types' {
        $dictionary = @{ 'String' = 'Test'; 'Number' = 123; 'Boolean' = $true; 'Array' = @(1, 2, 3) }
        $json = ConvertTo-PodeCustomDictionaryJson -Dictionary $dictionary | ConvertFrom-Json | Convert-PsCustomObjectToOrderedHashtable
        $expected = '{"Metadata":{"Product":"Pode","Version":"[dev]","Timestamp":"2025-02-04T01:54:30.6400033Z","Application":"Pester"},"Data":{"Type":"Hashtable","Items":[{"Key":"Array","Value":[1,2,3]},{"Key":"Boolean","Value":true},{"Key":"Number","Value":123},{"Key":"String","Value":"Test"}]}}' |
            ConvertFrom-Json | Convert-PsCustomObjectToOrderedHashtable

        Compare-Hashtable $json $expected | Should -BeTrue
    }

    It 'Should correctly serialize nested dictionaries and collections' {
        $dictionary = @{ 'Dict' = @{ 'SubDict' = @{ 'Key' = 'Value' } }; 'List' = @(1, 2, @{ 'Nested' = 'Yes' }) }
        $json = ConvertTo-PodeCustomDictionaryJson -Dictionary $dictionary | ConvertFrom-Json | Convert-PsCustomObjectToOrderedHashtable
        $expected = '{"Metadata":{"Product":"Pode","Version":"[dev]","Timestamp":"2025-02-04T01:54:30.6400033Z","Application":"Pester"},"Data":{"Type":"Hashtable","Items":[{"Key":"List","Value":[1,2,{"Type":"Hashtable","Items":[{"Key":"Nested","Value":"Yes"}]}]},{"Key":"Dict","Value":{"Type":"Hashtable","Items":[{"Key":"SubDict","Value":{"Type":"Hashtable","Items":[{"Key":"Key","Value":"Value"}]}}]}}]}}' |
            ConvertFrom-Json | Convert-PsCustomObjectToOrderedHashtable

        Compare-Hashtable $json $expected | Should -BeTrue
    }

    It 'Should correctly serialize thread-safe collections' {
        $concurrentDictionary = [System.Collections.Concurrent.ConcurrentDictionary[string, object]]::new([System.StringComparer]::OrdinalIgnoreCase)
        $concurrentDictionary['Key1'] = 'Value1'
        $concurrentDictionary['Key2'] = 42

        $concurrentBag = [System.Collections.Concurrent.ConcurrentBag[object]]::new()
        $concurrentBag.Add('Item1')
        $concurrentBag.Add('Item2')

        $dictionary = @{ 'ConcurrentDict' = $concurrentDictionary; 'ConcurrentBag' = $concurrentBag }
        $json = ConvertTo-PodeCustomDictionaryJson -Dictionary $dictionary | ConvertFrom-Json | Convert-PsCustomObjectToOrderedHashtable
        $expected = '{"Metadata":{"Product":"Pode","Version":"[dev]","Timestamp":"2025-02-04T01:54:30.6400033Z","Application":"Pester"},"Data":{"Type":"Hashtable","Items":[{"Key":"ConcurrentBag","Value":{"Type":"ConcurrentBag","Items":["Item2","Item1"]}},{"Key":"ConcurrentDict","Value":{"Type":"ConcurrentDictionary","Items":[{"Key":"Key1","Value":"Value1"},{"Key":"Key2","Value":42}]}}]}}' |
            ConvertFrom-Json | Convert-PsCustomObjectToOrderedHashtable

        Compare-Hashtable $json $expected | Should -BeTrue
    }
}



