$path = $MyInvocation.MyCommand.Path
$src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit[\\/]', '/src/'
Get-ChildItem "$($src)/*.ps1" | Resolve-Path | ForEach-Object { . $_ }

Describe 'Get-PodeLogger' {
    Context 'Invalid parameters supplied' {
        It 'Throw null name parameter error' {
            { Get-PodeLogger -Name $null } | Should Throw 'The argument is null or empty'
        }

        It 'Throw empty name parameter error' {
            { Get-PodeLogger -Name ([string]::Empty) } | Should Throw 'The argument is null or empty'
        }
    }

    Context 'Valid values supplied' {
        It 'Returns null as the logger does not exist' {
            $PodeContext = @{ 'Server' = @{ 'Logging' = @{ 'Methods' = @{}; } }; }
            Get-PodeLogger -Name 'test' | Should Be $null
        }

        It 'Returns terminal logger for name' {
            $PodeContext = @{ 'Server' = @{ 'Logging' = @{ 'Methods' = @{ 'test' = $null }; } }; }
            $result = (Get-PodeLogger -Name 'test')

            $result | Should Be $null
        }

        It 'Returns custom logger for name' {
            $PodeContext = @{ 'Server' = @{ 'Logging' = @{ 'Methods' = @{ 'test' = { Write-Host 'hello' } }; } }; }
            $result = (Get-PodeLogger -Name 'test')

            $result | Should Not Be $null
            $result.ToString() | Should Be ({ Write-Host 'hello' }).ToString()
        }
    }
}