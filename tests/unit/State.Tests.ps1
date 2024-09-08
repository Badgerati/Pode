[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
param()

BeforeAll {
    $path = $PSCommandPath
    $src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit', '/src/'
    Get-ChildItem "$($src)/*.ps1" -Recurse | Resolve-Path | ForEach-Object { . $_ }
    Import-LocalizedData -BindingVariable PodeLocale -BaseDirectory (Join-Path -Path $src -ChildPath 'Locales') -FileName 'Pode'

    # Mock Write-PodeTraceLog to avoid load Pode C# component
    Mock Write-PodeTraceLog {}

    $PodeContext = @{ 'Server' = $null; }
}

Describe 'Set-PodeState' {
    It 'Throws error when not initialised' {
        $PodeContext.Server = @{ 'State' = $null }
        { Set-PodeState -Name 'test' } | Should -Throw -ExpectedMessage $PodeLocale.podeNotInitializedExceptionMessage # Pode has not been initialized.
    }

    It 'Sets and returns an object' {
        $PodeContext.Server = @{ 'State' = @{} }
        $result = Set-PodeState -Name 'test' -Value 7

        $result | Should -Be 7
        $PodeContext.Server.State['test'].Value | Should -Be 7
        $PodeContext.Server.State['test'].Scope | Should -Be @()
    }
}

Describe 'Get-PodeState' {
    It 'Throws error when not initialised' {
        $PodeContext.Server = @{ 'State' = $null }
        { Get-PodeState -Name 'test' } | Should -Throw -ExpectedMessage $PodeLocale.podeNotInitializedExceptionMessage # Pode has not been initialized.
    }

    It 'Gets an object from the state' {
        $PodeContext.Server = @{ 'State' = @{} }
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
        $PodeContext.Server = @{ 'State' = @{} }
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

        $PodeContext.Server = @{ 'State' = @{} }
        Set-PodeState -Name 'test' -Value 8
        Save-PodeState -Path './state.json'

        Assert-MockCalled Out-File -Times 1 -Scope It
    }

    It 'Saves the state to file with Include' {
        Mock Get-PodeRelativePath { return $Path }
        Mock Out-File {}

        $PodeContext.Server = @{ 'State' = @{} }
        Set-PodeState -Name 'test' -Value 8
        Save-PodeState -Path './state.json' -Include 'test'

        Assert-MockCalled Out-File -Times 1 -Scope It
    }

    It 'Saves the state to file with Exclude' {
        Mock Get-PodeRelativePath { return $Path }
        Mock Out-File {}

        $PodeContext.Server = @{ 'State' = @{} }
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
        Mock Get-Content { return '{ "Name": "Morty" }' }

        $PodeContext.Server = @{ 'State' = @{} }
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
        $PodeContext.Server = @{ 'State' = @{} }
        Set-PodeState -Name 'test' -Value 8
        Test-PodeState -Name 'test' | Should -Be $true
    }

    It 'Returns false for an object not being in the state' {
        $PodeContext.Server = @{ 'State' = @{} }
        Set-PodeState -Name 'test' -Value 8
        Test-PodeState -Name 'tests' | Should -Be $false
    }
}