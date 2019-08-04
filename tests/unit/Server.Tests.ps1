$path = $MyInvocation.MyCommand.Path
$src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit', '/src/'
Get-ChildItem "$($src)/*.ps1" -Recurse | Resolve-Path | ForEach-Object { . $_ }

$PodeContext = @{ 'Server' = $null; }

Describe 'Start-PodeInternalServer' {
    Mock Add-PodePSInbuiltDrives { }
    Mock Invoke-PodeScriptBlock { }
    Mock New-PodeRunspaceState { }
    Mock New-PodeRunspacePools { }
    Mock Start-PodeLoggingRunspace { }
    Mock Start-PodeTimerRunspace { }
    Mock Start-PodeScheduleRunspace { }
    Mock Start-PodeGuiRunspace { }
    Mock Start-Sleep { }
    Mock New-PodeAutoRestartServer { }
    Mock Start-PodeSmtpServer { }
    Mock Start-PodeTcpServer { }
    Mock Start-PodeWebServer { }
    Mock Start-PodeServiceServer { }

    It 'Calls one-off script logic' {
        $PodeContext.Server = @{ 'Type' = ([string]::Empty); 'Logic' = {} }
        Start-PodeInternalServer | Out-Null

        Assert-MockCalled Invoke-PodeScriptBlock -Times 1 -Scope It
        Assert-MockCalled New-PodeRunspacePools -Times 1 -Scope It
        Assert-MockCalled New-PodeRunspaceState -Times 1 -Scope It
        Assert-MockCalled Start-PodeTimerRunspace -Times 0 -Scope It
        Assert-MockCalled Start-PodeScheduleRunspace -Times 0 -Scope It
        Assert-MockCalled Start-PodeSmtpServer -Times 0 -Scope It
        Assert-MockCalled Start-PodeTcpServer -Times 0 -Scope It
        Assert-MockCalled Start-PodeWebServer -Times 0 -Scope It
    }

    It 'Calls smtp server logic' {
        $PodeContext.Server = @{ 'Type' = 'SMTP'; 'Logic' = {} }
        Start-PodeInternalServer | Out-Null

        Assert-MockCalled Invoke-PodeScriptBlock -Times 1 -Scope It
        Assert-MockCalled New-PodeRunspacePools -Times 1 -Scope It
        Assert-MockCalled New-PodeRunspaceState -Times 1 -Scope It
        Assert-MockCalled Start-PodeTimerRunspace -Times 1 -Scope It
        Assert-MockCalled Start-PodeScheduleRunspace -Times 1 -Scope It
        Assert-MockCalled Start-PodeSmtpServer -Times 1 -Scope It
        Assert-MockCalled Start-PodeTcpServer -Times 0 -Scope It
        Assert-MockCalled Start-PodeWebServer -Times 0 -Scope It
    }

    It 'Calls tcp server logic' {
        $PodeContext.Server = @{ 'Type' = 'TCP'; 'Logic' = {} }
        Start-PodeInternalServer | Out-Null

        Assert-MockCalled Invoke-PodeScriptBlock -Times 1 -Scope It
        Assert-MockCalled New-PodeRunspacePools -Times 1 -Scope It
        Assert-MockCalled New-PodeRunspaceState -Times 1 -Scope It
        Assert-MockCalled Start-PodeTimerRunspace -Times 1 -Scope It
        Assert-MockCalled Start-PodeScheduleRunspace -Times 1 -Scope It
        Assert-MockCalled Start-PodeSmtpServer -Times 0 -Scope It
        Assert-MockCalled Start-PodeTcpServer -Times 1 -Scope It
        Assert-MockCalled Start-PodeWebServer -Times 0 -Scope It
    }

    It 'Calls http web server logic' {
        $PodeContext.Server = @{ 'Type' = 'HTTP'; 'Logic' = {} }
        Start-PodeInternalServer | Out-Null

        Assert-MockCalled Invoke-PodeScriptBlock -Times 1 -Scope It
        Assert-MockCalled New-PodeRunspacePools -Times 1 -Scope It
        Assert-MockCalled New-PodeRunspaceState -Times 1 -Scope It
        Assert-MockCalled Start-PodeTimerRunspace -Times 1 -Scope It
        Assert-MockCalled Start-PodeScheduleRunspace -Times 1 -Scope It
        Assert-MockCalled Start-PodeSmtpServer -Times 0 -Scope It
        Assert-MockCalled Start-PodeTcpServer -Times 0 -Scope It
        Assert-MockCalled Start-PodeWebServer -Times 1 -Scope It
    }

    It 'Calls https web server logic' {
        $PodeContext.Server = @{ 'Type' = 'HTTPS'; 'Logic' = {} }
        Start-PodeInternalServer | Out-Null

        Assert-MockCalled Invoke-PodeScriptBlock -Times 1 -Scope It
        Assert-MockCalled New-PodeRunspacePools -Times 1 -Scope It
        Assert-MockCalled New-PodeRunspaceState -Times 1 -Scope It
        Assert-MockCalled Start-PodeTimerRunspace -Times 1 -Scope It
        Assert-MockCalled Start-PodeScheduleRunspace -Times 1 -Scope It
        Assert-MockCalled Start-PodeSmtpServer -Times 0 -Scope It
        Assert-MockCalled Start-PodeTcpServer -Times 0 -Scope It
        Assert-MockCalled Start-PodeWebServer -Times 1 -Scope It
    }
}

Describe 'Restart-PodeInternalServer' {
    Mock Write-Host { }
    Mock Close-PodeRunspaces { }
    Mock Remove-PodePSDrives { }
    Mock Open-PodeConfiguration { return $null }
    Mock Start-PodeInternalServer { }
    Mock Write-PodeErrorLog { }
    Mock Close-PodeDisposable { }

    It 'Resetting the server values' {
        $PodeContext = @{
            'Tokens' = @{
                'Cancellation' = New-Object System.Threading.CancellationTokenSource;
                'Restart' = New-Object System.Threading.CancellationTokenSource;
            };
            'Server' = @{
                'Routes' =@{
                    'GET' = @{ 'key' = 'value' };
                    'POST' = @{ 'key' = 'value' };
                };
                'Handlers' = @{
                    'TCP' = @{ };
                };
                'Logging' = @{
                    'Types' = @{ 'key' = 'value' };
                };
                'Middleware' = @{ 'key' = 'value' };
                'Endware' = @{ 'key' = 'value' };
                'ViewEngine' = @{
                    'Type' = 'pode';
                    'Extension' = 'pode';
                    'Script' = $null;
                    'IsDynamic' = $true;
                };
                'Cookies' = @{
                    'Session' = @{ 'key' = 'value' };
                };
                'Authentications' = @{ 'key' = 'value' };
                'State' = @{ 'key' = 'value' };
                'Configuration' = @{ 'key' = 'value' };
            };
            'Timers' = @{ 'key' = 'value' }
            'Schedules' = @{ 'key' = 'value' };
        }

        Restart-PodeInternalServer | Out-Null

        $PodeContext.Server.Routes['GET'].Count | Should Be 0
        $PodeContext.Server.Logging.Types.Count | Should Be 0
        $PodeContext.Server.Middleware.Count | Should Be 0
        $PodeContext.Server.Endware.Count | Should Be 0
        $PodeContext.Server.Cookies.Session.Count | Should Be 0
        $PodeContext.Server.Authentications.Count | Should Be 0
        $PodeContext.Server.State.Count | Should Be 0
        $PodeContext.Server.Settings | Should Be $null

        $PodeContext.Timers.Count | Should Be 0
        $PodeContext.Schedules.Count | Should Be 0

        $PodeContext.Server.ViewEngine.Type | Should Be 'html'
        $PodeContext.Server.ViewEngine.Extension | Should Be 'html'
        $PodeContext.Server.ViewEngine.Script | Should Be $null
        $PodeContext.Server.ViewEngine.IsDynamic | Should Be $false
    }

    It 'Catches exception and throws it' {
        Mock Write-Host { throw 'some error' }
        Mock Write-PodeErrorLog {}
        { Restart-PodeInternalServer } | Should Throw 'some error'
    }
}