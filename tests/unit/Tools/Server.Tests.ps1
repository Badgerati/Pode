$path = $MyInvocation.MyCommand.Path
$src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit[\\/]', '/src/'
Get-ChildItem "$($src)/*.ps1" | Resolve-Path | ForEach-Object { . $_ }

$PodeContext = @{ 'Server' = $null; }

Describe 'Start-PodeServer' {
    Mock Add-PodePSInbuiltDrives { }
    Mock Invoke-ScriptBlock { }
    Mock New-PodeRunspaceState { }
    Mock New-PodeRunspacePools { }
    Mock Start-PodeLoggerRunspace { }
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
        Start-PodeServer | Out-Null

        Assert-MockCalled Invoke-ScriptBlock -Times 1 -Scope It
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
        Start-PodeServer | Out-Null

        Assert-MockCalled Invoke-ScriptBlock -Times 1 -Scope It
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
        Start-PodeServer | Out-Null

        Assert-MockCalled Invoke-ScriptBlock -Times 1 -Scope It
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
        Start-PodeServer | Out-Null

        Assert-MockCalled Invoke-ScriptBlock -Times 1 -Scope It
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
        Start-PodeServer | Out-Null

        Assert-MockCalled Invoke-ScriptBlock -Times 1 -Scope It
        Assert-MockCalled New-PodeRunspacePools -Times 1 -Scope It
        Assert-MockCalled New-PodeRunspaceState -Times 1 -Scope It
        Assert-MockCalled Start-PodeTimerRunspace -Times 1 -Scope It
        Assert-MockCalled Start-PodeScheduleRunspace -Times 1 -Scope It
        Assert-MockCalled Start-PodeSmtpServer -Times 0 -Scope It
        Assert-MockCalled Start-PodeTcpServer -Times 0 -Scope It
        Assert-MockCalled Start-PodeWebServer -Times 1 -Scope It
    }
}

Describe 'Get-PodeServerType' {
    Context 'Valid parameters supplied' {
        It 'Return smtp when switch supplied' {
            Get-PodeServerType -Port 25 -Smtp | Should Be 'SMTP'
        }

        It 'Return tcp when switch supplied' {
            Get-PodeServerType -Port 100 -Tcp | Should Be 'TCP'
        }

        It 'Return https when switch supplied' {
            Get-PodeServerType -Port 8443 -Https | Should Be 'HTTPS'
        }

        It 'Return http when no switch supplied, but have port' {
            Get-PodeServerType -Port 8080 | Should Be 'HTTP'
        }

        It 'Returns server when no switch/port, but have interval' {
            Get-PodeServerType -Interval 10 | Should Be 'SERVICE'
        }

        It 'Returns script when nothing is supplied' {
            Get-PodeServerType | Should Be ([string]::Empty)
        }
    }
}

Describe 'Restart-PodeServer' {
    Mock Write-Host { }
    Mock Close-PodeRunspaces { }
    Mock Remove-PodePSDrives { }
    Mock Open-PodeConfiguration { return $null }
    Mock Start-PodeServer { }
    Mock Out-Default { }
    Mock Dispose { }

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
                    'Methods' = @{ 'key' = 'value' };
                };
                'Middleware' = @{ 'key' = 'value' };
                'Endware' = @{ 'key' = 'value' };
                'ViewEngine' = @{
                    'Engine' = 'pode';
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

        Restart-PodeServer | Out-Null

        $PodeContext.Server.Routes['GET'].Count | Should Be 0
        $PodeContext.Server.Logging.Methods.Count | Should Be 0
        $PodeContext.Server.Middleware.Count | Should Be 0
        $PodeContext.Server.Endware.Count | Should Be 0
        $PodeContext.Server.Cookies.Session.Count | Should Be 0
        $PodeContext.Server.Authentications.Count | Should Be 0
        $PodeContext.Server.State.Count | Should Be 0
        $PodeContext.Server.Configuration | Should Be $null

        $PodeContext.Timers.Count | Should Be 0
        $PodeContext.Schedules.Count | Should Be 0

        $PodeContext.Server.ViewEngine.Engine | Should Be 'html'
        $PodeContext.Server.ViewEngine.Extension | Should Be 'html'
        $PodeContext.Server.ViewEngine.Script | Should Be $null
        $PodeContext.Server.ViewEngine.IsDynamic | Should Be $false
    }

    It 'Catches exception and throws it' {
        Mock Write-Host { throw 'some error' }
        { Restart-PodeServer } | Should Throw 'some error'
    }
}