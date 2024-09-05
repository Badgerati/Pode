BeforeAll {
    $path = $PSCommandPath
    $src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit', '/src/'
    Get-ChildItem "$($src)/*.ps1" -Recurse | Resolve-Path | ForEach-Object { . $_ }
    Import-LocalizedData -BindingVariable PodeLocale -BaseDirectory (Join-Path -Path $src -ChildPath 'Locales') -FileName 'Pode'

    # Mock Write-PodeTraceLog to avoid load Pode C# component
    Mock Write-PodeTraceLog {}
}

Describe 'Get-PodeRandomName' {


    It 'Returns correct name' {
        Mock 'Get-Random' { return 0 }
        Get-PodeRandomName | Should -Be 'admiring_almeida'
    }
}