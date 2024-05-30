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

    $languageDirs.foreach({
            Describe  "Language $($_.Name) Test" {
                # describe "Checking localization $($_.Name)" {
                $filePath = "$($_.FullName)/Pode.psd1"
                it 'Language resource file exist' {
                    Test-Path $filePath | Should -BeTrue
                }
                $podeFileContent = Get-Content -Path $filePath -Raw
                $global:content = Invoke-Expression $podeFileContent
                It -ForEach ($global:localizationKeys) -Name 'Resource File contain <_>' {
                    foreach ($key in $global:localizationKeys) {
                        #$global:content.Keys | Should -Contain $_ #-contains $_ | Should -BeTrue
                        $global:content.Keys -contains $_ | Should -BeTrue
                    }
                }
            }
        })
}
