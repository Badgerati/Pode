[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
param()
BeforeAll {
    $path = $PSCommandPath
    $src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit', '/src/'
    Get-ChildItem "$($src)/*.ps1" -Recurse | Resolve-Path | ForEach-Object { . $_ }
}


Describe 'Convert-PodePathSeparator' {
    Context 'Null' {
        It 'Null' {
            Convert-PodePathSeparator -Path $null | Should -Be $null
        }
    }

    Context 'String' {
        It 'Empty' {
            Convert-PodePathSeparator -Path '' | Should -Be $null
            Convert-PodePathSeparator -Path ' ' | Should -Be $null
        }

        It 'Value' {
            Convert-PodePathSeparator -Path 'anyValue' | Should -Be 'anyValue'
            Convert-PodePathSeparator -Path 1 | Should -Be 1
        }

        It 'Path' {
            Convert-PodePathSeparator -Path 'one/Seperators' | Should -Be "one$([System.IO.Path]::DirectorySeparatorChar)Seperators"
            Convert-PodePathSeparator -Path 'one\Seperators' | Should -Be "one$([System.IO.Path]::DirectorySeparatorChar)Seperators"

            Convert-PodePathSeparator -Path 'one/two/Seperators' | Should -Be "one$([System.IO.Path]::DirectorySeparatorChar)two$([System.IO.Path]::DirectorySeparatorChar)Seperators"
            Convert-PodePathSeparator -Path 'one\two\Seperators' | Should -Be "one$([System.IO.Path]::DirectorySeparatorChar)two$([System.IO.Path]::DirectorySeparatorChar)Seperators"
            Convert-PodePathSeparator -Path 'one/two\Seperators' | Should -Be "one$([System.IO.Path]::DirectorySeparatorChar)two$([System.IO.Path]::DirectorySeparatorChar)Seperators"
            Convert-PodePathSeparator -Path 'one\two/Seperators' | Should -Be "one$([System.IO.Path]::DirectorySeparatorChar)two$([System.IO.Path]::DirectorySeparatorChar)Seperators"
        }
    }

    Context 'Array' {
        It  'Null' {
            Convert-PodePathSeparator -Path @($null) | Should -Be $null
            Convert-PodePathSeparator -Path @($null, $null) | Should -Be $null
        }

        It 'Single' {
            Convert-PodePathSeparator -Path @('noSeperators') | Should -Be @('noSeperators')
            Convert-PodePathSeparator -Path @('some/Seperators') | Should -Be @("some$([System.IO.Path]::DirectorySeparatorChar)Seperators")
            Convert-PodePathSeparator -Path @('some\Seperators') | Should -Be @("some$([System.IO.Path]::DirectorySeparatorChar)Seperators")

            Convert-PodePathSeparator -Path @('') | Should -Be $null
            Convert-PodePathSeparator -Path @(' ') | Should -Be $null
        }

        It 'Double' {
            Convert-PodePathSeparator -Path @('noSeperators1', 'noSeperators2') | Should -Be @('noSeperators1', 'noSeperators2')
            Convert-PodePathSeparator -Path @('some/Seperators', 'some\Seperators') | Should -Be @("some$([System.IO.Path]::DirectorySeparatorChar)Seperators", "some$([System.IO.Path]::DirectorySeparatorChar)Seperators")

            Convert-PodePathSeparator -Path @('', ' ') | Should -Be $null
            Convert-PodePathSeparator -Path @(' ', '') | Should -Be $null
        }
    }
}
