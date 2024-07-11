# Pester Test Script: Test-ExamplesHeaders.Tests.ps1

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
param()
BeforeDiscovery {
    $path = $PSCommandPath
    $examplesPath = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit', '/examples/'
    $ps1Files = (Get-ChildItem -Path $examplesPath -Filter *.ps1 -Recurse).FullName
}


Describe 'Examples Script Headers' {
    Context 'Checking file: [<_>]' -ForEach ($ps1Files) {
        BeforeAll {
            $content = Get-Content -Path $_ -Raw
        }
        It 'should have a .SYNOPSIS section' {
            $hasSynopsis = $content -match '\.SYNOPSIS\s+([^\#]*)'
            $hasSynopsis | Should -Be $true
        }

        It 'should have a .DESCRIPTION section' {
            $hasDescription = $content -match '\.DESCRIPTION\s+([^\#]*)'
            $hasDescription | Should -Be $true
        }

        It 'should have a .NOTES section with Author and License' {
            $hasNotes = $content -match '\.NOTES\s+([^\#]*?)Author:\s*Pode Team\s*License:\s*MIT License'
            $hasNotes | Should -Be $true
        }
    }

}
