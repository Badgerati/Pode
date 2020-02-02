$path = $MyInvocation.MyCommand.Path
$src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit', '/src/'
Get-ChildItem "$($src)/*.ps1" -Recurse | Resolve-Path | ForEach-Object { . $_ }

$PodeContext = @{
    Metrics = @{ Server = @{
        StartTime = [datetime]::UtcNow
        InitialLoadTime = [datetime]::UtcNow
        RestartCount = 0
    } }
}

Describe 'Get-PodeServerUptime' {
    It 'Returns the current session uptime' {
        $PodeContext.Metrics.Server.StartTime = ([datetime]::UtcNow.AddSeconds(-2))
        ((Get-PodeServerUptime) -ge 2000) | Should Be $true
    }

    It 'Returns the total uptime' {
        $PodeContext.Metrics.Server.InitialLoadTime = ([datetime]::UtcNow.AddSeconds(-2))
        ((Get-PodeServerUptime -Total) -ge 2000) | Should Be $true
    }
}

Describe 'Get-PodeServerRestartCount' {
    It 'Returns the restart count' {
        $PodeContext.Metrics.Server.RestartCount = 1
        Get-PodeServerRestartCount | Should Be 1
    }
}