[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
param()
BeforeAll {
    $path = $PSCommandPath
    $src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit', '/src/'
    Get-ChildItem "$($src)/*.ps1" -Recurse | Resolve-Path | ForEach-Object { . $_ }
    Import-LocalizedData -BindingVariable PodeLocale -BaseDirectory (Join-Path -Path $src -ChildPath 'Locales') -FileName 'Pode'
}
BeforeDiscovery {
    $path = $PSCommandPath
    $src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit', '/src'

    # All language directories
    $localizationDir = "$src/Locales"

    # Discover all language directories
    $languageDirs = Get-ChildItem -Path $localizationDir -Directory | Where-Object { $_.Name -ne 'en' }

    # Get all source code files recursively from the specified directory
    $sourceFiles = Get-ChildItem -Path $src -Recurse -Include *.ps1, *.psm1
    Import-LocalizedData -BindingVariable LanguageOfReference -BaseDirectory $localizationDir -FileName 'Pode' -UICulture 'en'
}
Describe 'Localization Check' {


    # Function to extract hashtable keys from a file
    function Export-KeysFromFile {
        param (
            [string]$filePath
        )

        $content = Get-Content -Path $filePath -Raw
        $keys = @()
        $regex = '\$PodeLocale\["([^"]+)"\]|\$PodeLocale\.([a-zA-Z_][a-zA-Z0-9_]*)'
        foreach ($match in [regex]::Matches($content, $regex)) {
            if ($match.Groups[1].Value) {
                $keys += $match.Groups[1].Value
            }
            elseif ($match.Groups[2].Value) {
                $keys += $match.Groups[2].Value
            }
        }
        return $keys
    }

    Describe 'Verify Invalid Hashtable Keys in [<_.Name>]' -ForEach  ($sourceFiles) {
        $keysInFile = Export-KeysFromFile -filePath $_.FullName
        It "should find the key '[<_>]' in the hashtable"  -ForEach  ($keysInFile) {
            $PodeLocale.Keys -contains $_ | Should -BeTrue
        }
    }


    Describe  'Verifying Language [<_.Name>]' -ForEach  ($languageDirs) {
        it 'Language resource file exist' {
            Test-Path -Path "$($_.FullName)/Pode.psd1" | Should -BeTrue
        }

        $global:content = Import-LocalizedData -FileName 'Pode.psd1' -BaseDirectory $localizationDir -UICulture $_.Name
        it 'Number of entry equal to the [en]' {
            $global:content.Keys.Count | Should -be $PodeLocale.Count
        }

        It -ForEach ( $LanguageOfReference.Keys) -Name 'Resource File contains <_>' {
            foreach ($key in  $PodeLocale.Keys) {
                $global:content.Keys -contains $_ | Should -BeTrue
            }
        }
    }
}
