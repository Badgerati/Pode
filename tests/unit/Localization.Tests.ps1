[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
param()
BeforeDiscovery {
    $path = $PSCommandPath
    $src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit', '/src'

    # All language directories
    $localizationDir = "$src/Locales"

    # Discover all language directories
    $languageDirs = (Get-ChildItem -Path $localizationDir -Directory | Where-Object { $_.Name -ne 'en' }).FullName

    # Get all source code files recursively from the specified directory
    $sourceFiles = (Get-ChildItem -Path $src -Recurse -Include *.ps1, *.psm1).FullName
    Import-LocalizedData -BindingVariable LanguageOfReference -BaseDirectory $localizationDir -FileName 'Pode' -UICulture 'en'
}

BeforeAll {
    $path = $PSCommandPath
    $src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit', '/src/'
    Get-ChildItem "$($src)/*.ps1" -Recurse | Resolve-Path | ForEach-Object { . $_ }
    # All language directories
    $localizationDir = "$src/Locales"
    Import-LocalizedData -BindingVariable PodeLocale -BaseDirectory $localizationDir -FileName 'Pode'
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

    Describe 'Verify Invalid Hashtable Keys in [<_>]' -ForEach  ($sourceFiles) {
        $keysInFile = Export-KeysFromFile -filePath $_
        It "should find the key '[<_>]' in the hashtable"  -ForEach  ($keysInFile) {
            $PodeLocale.Keys -contains $_ | Should -BeTrue
        }
    }

    It "Check 'throw' is not using a static string in [<_>]" -ForEach  ($sourceFiles) {
        ( Get-Content -Path $_ -Raw) -match 'throw\s*["\'']' | Should -BeFalse
    }

    Describe  'Verifying Language [<_>]' -ForEach  ($languageDirs) {

        BeforeAll {
            $content = Import-LocalizedData -FileName 'Pode.psd1' -BaseDirectory $localizationDir -UICulture (Split-Path $_ -Leaf)
        }
        it 'Language resource file exist' {
            Test-Path -Path "$($_)/Pode.psd1" | Should -BeTrue
        }

        it 'Number of entry equal to the [en]' {
            $content.Keys.Count | Should -be $PodeLocale.Count
        }

        It  -Name 'Resource File contains <_>' -ForEach ( $LanguageOfReference.Keys) {
            $content.Keys -contains $_ | Should -BeTrue
        }
    }
}
