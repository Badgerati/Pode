# Save this script as Check-LocalizationKeys.Tests.ps1
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '')]
param()

Describe 'Localization Files Key Check' {
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

    Describe  "Language [<_.Name>]" -ForEach  ($languageDirs) {
        it 'Language resource file exist' {
            Test-Path -Path "$($_.FullName)/Pode.psd1" | Should -BeTrue
        }
        $podeFileContent = Get-Content -Path "$($_.FullName)/Pode.psd1" -Raw
        $global:content = Invoke-Expression $podeFileContent
        it 'Total number of keys equal to the [en]'{
            $global:content.Keys.Count | Should -be $global:localizationKeys.Count
        }
        It -ForEach ($global:localizationKeys) -Name 'Resource File contain <_>' {
            foreach ($key in $global:localizationKeys) {
                $global:content.Keys -contains $_ | Should -BeTrue
            }
        }
    }
}
