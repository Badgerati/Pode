[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
param()
BeforeAll {
    $path = $PSCommandPath
    $src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit', '/src/'
    Get-ChildItem "$($src)/*.ps1" -Recurse | Resolve-Path | ForEach-Object { . $_ }
    Import-LocalizedData -BindingVariable msgTable -BaseDirectory (Join-Path -Path $src -ChildPath 'Locales') -UICulture 'en-us' -FileName 'Pode'

    $PodeContext = @{
        Metrics = @{
            Server   = @{
                StartTime       = [datetime]::UtcNow
                InitialLoadTime = [datetime]::UtcNow
                RestartCount    = 0
            }
            Requests = @{
                Total       = 10
                StatusCodes = @{
                    '200' = 8
                    '404' = 2
                }
            }
        }
    } }

Describe 'Get-PodeServerUptime' {
    It 'Returns the current session uptime' {
        $PodeContext.Metrics.Server.StartTime = ([datetime]::UtcNow.AddSeconds(-2))
        ((Get-PodeServerUptime) -ge 2000) | Should -Be $true
    }

    It 'Returns the total uptime' {
        $PodeContext.Metrics.Server.InitialLoadTime = ([datetime]::UtcNow.AddSeconds(-2))
        ((Get-PodeServerUptime -Total) -ge 2000) | Should -Be $true
    }
}

Describe 'Get-PodeServerRestartCount' {
    It 'Returns the restart count' {
        $PodeContext.Metrics.Server.RestartCount = 1
        Get-PodeServerRestartCount | Should -Be 1
    }
}

Describe 'Get-PodeServerRequestMetric' {
    It 'Returns the total number of requests' {
        Get-PodeServerRequestMetric -Total | Should -Be 10
    }

    It 'Returns each status code' {
        $codes = Get-PodeServerRequestMetric
        $codes.Count | Should -Be 2
        $codes['200'] | Should -Be 8
        $codes['404'] | Should -Be 2
    }

    It 'Returns total request that resulted in a 200' {
        Get-PodeServerRequestMetric -StatusCode 200 | Should -Be 8
    }

    It 'Returns 0 requests that resulted in a 201' {
        Get-PodeServerRequestMetric -StatusCode 201 | Should -Be 0
    }
}