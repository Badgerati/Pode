# Save this script as Check-LocalizationKeys.Tests.ps1
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '')]
param()

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


    $path = $PSCommandPath
    $src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit', '/src'
    # All language directories
    $localizationDir = "$src/Locales"

    # Path to the  English localization file
    $englishFilePath = "$localizationDir/en/Pode.psd1"
    $podeFileContent = Get-Content -Path $englishFilePath -Raw
    # Execute the content and assign the result to a variable
    $localizationMessages = Invoke-Expression $podeFileContent
    $global:localizationKeys = $localizationMessages.Keys
    # Discover all language directories
    $languageDirs = Get-ChildItem -Path $localizationDir -Directory | Where-Object { $_.Name -ne 'en' }


    # Get all source code files recursively from the specified directory
    $sourceFiles = Get-ChildItem -Path $src -Recurse -Include *.ps1, *.psm1

    Describe 'Verify Invalid Hashtable Keys in [<_.Name>]' -ForEach  ($sourceFiles) {
        $keysInFile = Export-KeysFromFile -filePath $_.FullName
        It "should find the key '[<_>]' in the hashtable"  -ForEach  ($keysInFile) {
            $global:localizationKeys -contains $_ | Should -BeTrue
        }
    }


    Describe  'Verifying Language [<_.Name>]' -ForEach  ($languageDirs) {
        it 'Language resource file exist' {
            Test-Path -Path "$($_.FullName)/Pode.psd1" | Should -BeTrue
        }
        $podeFileContent = Get-Content -Path "$($_.FullName)/Pode.psd1" -Raw
        $global:content = Invoke-Expression $podeFileContent
        it 'Number of entry equal to the [en]' {
            $global:content.Keys.Count | Should -be $global:localizationKeys.Count
        }
        It -ForEach ($global:localizationKeys) -Name 'Resource File contain <_>' {
            foreach ($key in $global:localizationKeys) {
                $global:content.Keys -contains $_ | Should -BeTrue
            }
        }
    }
}
