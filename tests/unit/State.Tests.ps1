[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
param()

BeforeAll {
    $path = $PSCommandPath
    $src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit', '/src/'
    Get-ChildItem "$($src)/*.ps1" -Recurse | Resolve-Path | ForEach-Object { . $_ }
    Import-LocalizedData -BindingVariable PodeLocale -BaseDirectory (Join-Path -Path $src -ChildPath 'Locales') -FileName 'Pode'

    $PodeContext = @{ 'Server' = $null; }
}

Describe 'Set-PodeState' {
    It 'Throws error when not initialised' {
        $PodeContext.Server = @{ 'State' = $null }
        { Set-PodeState -Name 'test' } | Should -Throw -ExpectedMessage $PodeLocale.podeNotInitializedExceptionMessage # Pode has not been initialized.
    }

    It 'Sets and returns an object' {
        $PodeContext.Server = @{ 'State' = [System.Collections.Concurrent.ConcurrentDictionary[string, object]]::new([System.StringComparer]::OrdinalIgnoreCase) }
        $result = Set-PodeState -Name 'test' -Value 7

        $result | Should -Be 7
        $PodeContext.Server.State['test'].Value | Should -Be 7
        $PodeContext.Server.State['test'].Scope | Should -Be @()
    }

    It 'Sets by pipe and returns an object array' {
        $PodeContext.Server = @{ 'State' = [System.Collections.Concurrent.ConcurrentDictionary[string, object]]::new([System.StringComparer]::OrdinalIgnoreCase) }
        $result = @(7, 3, 4) | Set-PodeState -Name 'test'

        $result | Should -Be @(7, 3, 4)
        $PodeContext.Server.State['test'].Value | Should -Be @(7, 3, 4)
        $PodeContext.Server.State['test'].Scope | Should -Be @()
    }
}

Describe 'Get-PodeState' {
    It 'Throws error when not initialised' {
        $PodeContext.Server = @{ 'State' = $null }
        { Get-PodeState -Name 'test' } | Should -Throw -ExpectedMessage $PodeLocale.podeNotInitializedExceptionMessage # Pode has not been initialized.
    }

    It 'Gets an object from the state' {
        $PodeContext.Server = @{ 'State' = [System.Collections.Concurrent.ConcurrentDictionary[string, object]]::new([System.StringComparer]::OrdinalIgnoreCase) }
        Set-PodeState -Name 'test' -Value 8
        Get-PodeState -Name 'test' | Should -Be 8
    }
}

Describe 'Remove-PodeState' {
    It 'Throws error when not initialised' {
        $PodeContext.Server = @{ 'State' = $null }
        { Remove-PodeState -Name 'test' } | Should -Throw -ExpectedMessage $PodeLocale.podeNotInitializedExceptionMessage # Pode has not been initialized.
    }

    It 'Removes an object from the state' {
        $PodeContext.Server = @{ 'State' = [System.Collections.Concurrent.ConcurrentDictionary[string, object]]::new([System.StringComparer]::OrdinalIgnoreCase) }
        Set-PodeState -Name 'test' -Value 8
        Remove-PodeState -Name 'test' | Should -Be 8
        $PodeContext.Server.State['test'] | Should -Be $null
    }
}

Describe 'Save-PodeState' {
    It 'Throws error when not initialised' {
        $PodeContext.Server = @{ 'State' = $null }
        { Save-PodeState -Path 'some/path' } | Should -Throw -ExpectedMessage $PodeLocale.podeNotInitializedExceptionMessage # Pode has not been initialized.
    }

    It 'Saves the state to file' {
        Mock Get-PodeRelativePath { return $Path }
        Mock Out-File {}

        $PodeContext.Server = @{ 'State' = [System.Collections.Concurrent.ConcurrentDictionary[string, object]]::new([System.StringComparer]::OrdinalIgnoreCase) }
        Set-PodeState -Name 'test' -Value 8
        Save-PodeState -Path './state.json'

        Assert-MockCalled Out-File -Times 1 -Scope It
    }

    It 'Saves the state to file with Include' {
        Mock Get-PodeRelativePath { return $Path }
        Mock Out-File {}

        $PodeContext.Server = @{ 'State' = [System.Collections.Concurrent.ConcurrentDictionary[string, object]]::new([System.StringComparer]::OrdinalIgnoreCase) }
        Set-PodeState -Name 'test' -Value 8
        Save-PodeState -Path './state.json' -Include 'test'

        Assert-MockCalled Out-File -Times 1 -Scope It
    }

    It 'Saves the state to file with Exclude' {
        Mock Get-PodeRelativePath { return $Path }
        Mock Out-File {}

        $PodeContext.Server = @{ 'State' = [System.Collections.Concurrent.ConcurrentDictionary[string, object]]::new([System.StringComparer]::OrdinalIgnoreCase) }
        Set-PodeState -Name 'test' -Value 8
        Save-PodeState -Path './state.json' -Exclude 'test'

        Assert-MockCalled Out-File -Times 1 -Scope It
    }
}

Describe 'Restore-PodeState' {
    It 'Throws error when not initialised' {
        $PodeContext.Server = @{ 'State' = $null }
        { Restore-PodeState -Path 'some/path' } | Should -Throw -ExpectedMessage $PodeLocale.podeNotInitializedExceptionMessage # Pode has not been initialized.
    }

    It 'Restores the state from file' {
        Mock Get-PodeRelativePath { return $Path }
        Mock Test-Path { return $true }
        Mock Get-Content { return '{"Type":"ConcurrentDictionary","Items":[{"Key":"Name","Value":{"Type":"ConcurrentDictionary","Items":[{"Key":"Value","Value":"Morty"},{"Key":"Scope","Value":[]}]}}]}' }

        $PodeContext.Server = @{ 'State' = [System.Collections.Concurrent.ConcurrentDictionary[string, object]]::new([System.StringComparer]::OrdinalIgnoreCase) }
        Restore-PodeState -Path './state.json'
        Get-PodeState -Name 'Name' | Should -Be 'Morty'
    }
}

Describe 'Test-PodeState' {
    It 'Throws error when not initialised' {
        $PodeContext.Server = @{ 'State' = $null }
        { Test-PodeState -Name 'test' } | Should -Throw -ExpectedMessage $PodeLocale.podeNotInitializedExceptionMessage # Pode has not been initialized.
    }

    It 'Returns true for an object being in the state' {
        $PodeContext.Server = @{ 'State' = [System.Collections.Concurrent.ConcurrentDictionary[string, object]]::new([System.StringComparer]::OrdinalIgnoreCase) }
        Set-PodeState -Name 'test' -Value 8
        Test-PodeState -Name 'test' | Should -Be $true
    }

    It 'Returns false for an object not being in the state' {
        $PodeContext.Server = @{ 'State' = [System.Collections.Concurrent.ConcurrentDictionary[string, object]]::new([System.StringComparer]::OrdinalIgnoreCase) }
        Set-PodeState -Name 'test' -Value 8
        Test-PodeState -Name 'tests' | Should -Be $false
    }
}

# Get-PodeStateNames.Tests.ps1
# Pester 5 test script for Get-PodeStateNames

# If your function is in a separate file, dot-source it. Adjust the path as needed:
# . "$PSScriptRoot\..\Functions\Get-PodeStateNames.ps1"

Describe 'Get-PodeStateNames' -Tags 'Unit', 'Pode' {
    BeforeAll {
        # Mocking up $PodeLocale and $PodeContext to simulate Pode's environment.
        $PodeLocale = @{
            podeNotInitializedExceptionMessage = 'Pode has not been initialized.'
        }

        $PodeContext = @{
            Server = @{
                State = $null
            }
        }

        # Define (or dot-source) the function here if not already loaded:
        function Get-PodeStateNames {
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
            [CmdletBinding()]
            param(
                [Parameter()]
                [string]
                $Pattern,

                [Parameter()]
                [string[]]
                $Scope
            )

            if ($null -eq $PodeContext.Server.State) {
                throw ($PodeLocale.podeNotInitializedExceptionMessage)
            }

            if ($null -eq $Scope) {
                $Scope = @()
            }

            $keys = $PodeContext.Server.State.Keys

            if ($Scope.Length -gt 0) {
                $keys = @(
                    foreach ($key in $keys) {
                        if ($PodeContext.Server.State.ContainsKey($key)) {
                            $scopeValue = $PodeContext.Server.State[$key]['Scope']
                            if ($scopeValue -is [string] -and ($scopeValue -iin $Scope)) {
                                $key
                            }
                        }
                    }
                )
            }

            if (![string]::IsNullOrWhiteSpace($Pattern)) {
                $keys = @(
                    foreach ($key in $keys) {
                        if ($key -imatch $Pattern) {
                            $key
                        }
                    }
                )
            }

            return $keys
        }
    }

    Context 'When PodeContext.Server.State is $null' {
        It 'Throws an exception if state is null' {
            { Get-PodeStateNames } | Should -Throw 'Pode has not been initialized.'
        }
    }

    Context 'When PodeContext.Server.State is a valid ConcurrentDictionary' {
        BeforeEach {
            # Initialize the thread-safe dictionary before each test
            $PodeContext.Server.State = [System.Collections.Concurrent.ConcurrentDictionary[string, object]]::new([System.StringComparer]::OrdinalIgnoreCase)

            # For each key, store another ConcurrentDictionary with "Scope" and "Data"
            # Key1 -> { Scope = 'Test1'; Data = 'Value1' }
            # Key2 -> { Scope = 'Test2'; Data = 'Value2' }
            # SpecialKey -> { Scope = 'Test1'; Data = 'SpecialValue' }

            $cd1 = [System.Collections.Concurrent.ConcurrentDictionary[string, object]]::new([System.StringComparer]::OrdinalIgnoreCase)
            $cd1['Scope'] = 'Test1'
            $cd1['Data'] = 'Value1'
            $null = $PodeContext.Server.State.TryAdd('Key1', $cd1)

            $cd2 = [System.Collections.Concurrent.ConcurrentDictionary[string, object]]::new([System.StringComparer]::OrdinalIgnoreCase)
            $cd2['Scope'] = 'Test2'
            $cd2['Data'] = 'Value2'
            $null = $PodeContext.Server.State.TryAdd('Key2', $cd2)

            $cd3 = [System.Collections.Concurrent.ConcurrentDictionary[string, object]]::new([System.StringComparer]::OrdinalIgnoreCase)
            $cd3['Scope'] = 'Test1'
            $cd3['Data'] = 'SpecialValue'
            $null = $PodeContext.Server.State.TryAdd('SpecialKey', $cd3)
        }

        It 'Returns all keys if no scope or pattern is specified' {
            $keys = Get-PodeStateNames
            $keys | Should -Contain 'Key1'
            $keys | Should -Contain 'Key2'
            $keys | Should -Contain 'SpecialKey'
            $keys.Count | Should -Be 3
        }

        It 'Filters by scope correctly' {
            $keys = Get-PodeStateNames -Scope 'Test1'
            $keys.Count | Should -Be 2
            $keys | Should -Contain 'Key1'
            $keys | Should -Contain 'SpecialKey'
            $keys | Should -Not -Contain 'Key2'
        }

        It 'Filters by pattern correctly' {
            # Pattern to match "Key\d" (e.g. Key1, Key2)
            $keys = Get-PodeStateNames -Pattern 'Key\d'
            $keys.Count | Should -Be 2
            $keys | Should -Contain 'Key1'
            $keys | Should -Contain 'Key2'
            $keys | Should -Not -Contain 'SpecialKey'
        }

        It 'Filters by both scope and pattern' {
            # e.g. Scope = 'Test1', Pattern = 'Special'
            $keys = Get-PodeStateNames -Scope 'Test1' -Pattern 'Special'
            $keys.Count | Should -Be 1
            $keys | Should -Contain 'SpecialKey'
        }
    }
}
