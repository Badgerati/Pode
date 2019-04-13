$path = $MyInvocation.MyCommand.Path
$src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit[\\/]', '/src/'
Get-ChildItem "$($src)/*.ps1" | Resolve-Path | ForEach-Object { . $_ }

Describe 'Get-PodeRandomName' {
    Mock 'Get-Random' { return 0 }

    It 'Returns correct name' {
        Get-PodeRandomName | Should Be 'admiring_almeida'
    }
}