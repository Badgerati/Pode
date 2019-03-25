$path = $MyInvocation.MyCommand.Path
$src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit[\\/]', '/src/'
Get-ChildItem "$($src)/*.ps1" | Resolve-Path | ForEach-Object { . $_ }

Describe 'Get-RandomName' {
    Mock 'Get-Random' { return 0 }

    It 'Returns correct name' {
        Get-RandomName | Should Be 'admiring_almeida'
    }
}