$path = $MyInvocation.MyCommand.Path
$src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit', '/src/'
Get-ChildItem "$($src)/*.ps1" -Recurse | Resolve-Path | ForEach-Object { . $_ }

Describe 'Get-PodeLogger' {
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

Describe 'Write-PodeLog' {
    It 'Does nothing when logging disabled' {
        Mock Test-PodeLoggerEnabled { return $false }
        $PodeContext = @{ LogsToProcess = New-Object System.Collections.ArrayList }

        Write-PodeLog -Name 'test' -InputObject 'test'

        $PodeContext.LogsToProcess.Count | Should Be 0
    }

    It 'Adds a log item' {
        Mock Test-PodeLoggerEnabled { return $true }
        $PodeContext = @{ LogsToProcess = New-Object System.Collections.ArrayList }

        Write-PodeLog -Name 'test' -InputObject 'test'

        $PodeContext.LogsToProcess.Count | Should Be 1
        $PodeContext.LogsToProcess[0].Name | Should Be 'test'
        $PodeContext.LogsToProcess[0].Item | Should Be 'test'
    }
}

Describe 'Write-PodeErrorLog' {
    It 'Does nothing when logging disabled' {
        Mock Test-PodeLoggerEnabled { return $false }
        $PodeContext = @{ LogsToProcess = New-Object System.Collections.ArrayList }

        Write-PodeLog -Name 'test' -InputObject 'test'

        $PodeContext.LogsToProcess.Count | Should Be 0
    }

    It 'Adds an error log item' {
        Mock Test-PodeLoggerEnabled { return $true }
        $PodeContext = @{ LogsToProcess = New-Object System.Collections.ArrayList }

        try { throw 'some error' }
        catch {
            Write-PodeErrorLog -ErrorRecord $Error[0]
        }

        $PodeContext.LogsToProcess.Count | Should Be 1
        $PodeContext.LogsToProcess[0].Item.Message | Should Be 'some error'
    }

    It 'Adds an exception log item' {
        Mock Test-PodeLoggerEnabled { return $true }
        $PodeContext = @{ LogsToProcess = New-Object System.Collections.ArrayList }

        $exp = [exception]::new('some error')
        Write-PodeErrorLog -Exception $exp

        $PodeContext.LogsToProcess.Count | Should Be 1
        $PodeContext.LogsToProcess[0].Item.Message | Should Be 'some error'
    }
}

Describe 'Get-PodeRequestLoggingName' {
    It 'Returns logger name' {
        Get-PodeRequestLoggingName | Should Be '__pode_log_requests__'
    }
}

Describe 'Get-PodeErrorLoggingName' {
    It 'Returns logger name' {
        Get-PodeErrorLoggingName | Should Be '__pode_log_errors__'
    }
}