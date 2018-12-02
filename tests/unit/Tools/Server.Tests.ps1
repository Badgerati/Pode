$path = $MyInvocation.MyCommand.Path
$src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit[\\/]', '/src/'
Get-ChildItem "$($src)/*.ps1" | Resolve-Path | ForEach-Object { . $_ }

$PodeSession = @{ 'Server' = $null; }

Describe 'Start-PodeServer' {
    Mock Add-PodePSInbuiltDrives { }
    Mock Invoke-ScriptBlock { }
    Mock Start-TimerRunspace { }
    Mock Start-ScheduleRunspace { }
    Mock Start-Sleep { }
    Mock Start-SmtpServer { }
    Mock Start-TcpServer { }
    Mock Start-WebServer { }

    It 'Calls one-off script logic' {
        $PodeSession.Server = @{ 'Type' = 'SCRIPT'; 'Logic' = {} }
        Start-PodeServer | Out-Null

        Assert-MockCalled Invoke-ScriptBlock -Times 1 -Scope It
        Assert-MockCalled Start-TimerRunspace -Times 0 -Scope It
        Assert-MockCalled Start-ScheduleRunspace -Times 0 -Scope It
        Assert-MockCalled Start-SmtpServer -Times 0 -Scope It
        Assert-MockCalled Start-TcpServer -Times 0 -Scope It
        Assert-MockCalled Start-WebServer -Times 0 -Scope It
    }

    It 'Calls smtp server logic' {
        $PodeSession.Server = @{ 'Type' = 'SMTP'; 'Logic' = {} }
        Start-PodeServer | Out-Null

        Assert-MockCalled Invoke-ScriptBlock -Times 1 -Scope It
        Assert-MockCalled Start-TimerRunspace -Times 1 -Scope It
        Assert-MockCalled Start-ScheduleRunspace -Times 1 -Scope It
        Assert-MockCalled Start-SmtpServer -Times 1 -Scope It
        Assert-MockCalled Start-TcpServer -Times 0 -Scope It
        Assert-MockCalled Start-WebServer -Times 0 -Scope It
    }

    It 'Calls tcp server logic' {
        $PodeSession.Server = @{ 'Type' = 'TCP'; 'Logic' = {} }
        Start-PodeServer | Out-Null

        Assert-MockCalled Invoke-ScriptBlock -Times 1 -Scope It
        Assert-MockCalled Start-TimerRunspace -Times 1 -Scope It
        Assert-MockCalled Start-ScheduleRunspace -Times 1 -Scope It
        Assert-MockCalled Start-SmtpServer -Times 0 -Scope It
        Assert-MockCalled Start-TcpServer -Times 1 -Scope It
        Assert-MockCalled Start-WebServer -Times 0 -Scope It
    }

    It 'Calls http web server logic' {
        $PodeSession.Server = @{ 'Type' = 'HTTP'; 'Logic' = {} }
        Start-PodeServer | Out-Null

        Assert-MockCalled Invoke-ScriptBlock -Times 1 -Scope It
        Assert-MockCalled Start-TimerRunspace -Times 1 -Scope It
        Assert-MockCalled Start-ScheduleRunspace -Times 1 -Scope It
        Assert-MockCalled Start-SmtpServer -Times 0 -Scope It
        Assert-MockCalled Start-TcpServer -Times 0 -Scope It
        Assert-MockCalled Start-WebServer -Times 1 -Scope It
    }

    It 'Calls https web server logic' {
        $PodeSession.Server = @{ 'Type' = 'HTTPS'; 'Logic' = {} }
        Start-PodeServer | Out-Null

        Assert-MockCalled Invoke-ScriptBlock -Times 1 -Scope It
        Assert-MockCalled Start-TimerRunspace -Times 1 -Scope It
        Assert-MockCalled Start-ScheduleRunspace -Times 1 -Scope It
        Assert-MockCalled Start-SmtpServer -Times 0 -Scope It
        Assert-MockCalled Start-TcpServer -Times 0 -Scope It
        Assert-MockCalled Start-WebServer -Times 1 -Scope It
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
            Get-PodeServerType | Should Be 'SCRIPT'
        }
    }
}

Describe 'Set-PodePortForServerType' {
    Context 'Valid parameters supplied' {
        It 'Uses 25 for smtp' {
            $PodeSession.Server = @{ 'IP' = @{ 'Port' = 0 }; 'Type' = 'SMTP' }
            Set-PodePortForServerType
            $PodeSession.Server.IP.Port | Should Be 25
        }

        It 'Uses 8080 for http' {
            $PodeSession.Server = @{ 'IP' = @{ 'Port' = 0 }; 'Type' = 'HTTP' }
            Set-PodePortForServerType
            $PodeSession.Server.IP.Port | Should Be 8080
        }

        It 'Uses 8443 for https' {
            $PodeSession.Server = @{ 'IP' = @{ 'Port' = 0 }; 'Type' = 'HTTPS' }
            Set-PodePortForServerType
            $PodeSession.Server.IP.Port | Should Be 8443
        }

        It 'Uses 0 for tcp' {
            $PodeSession.Server = @{ 'IP' = @{ 'Port' = 0 }; 'Type' = 'TCP' }
            Set-PodePortForServerType
            $PodeSession.Server.IP.Port | Should Be 0
        }

        It 'Uses 0 for script' {
            $PodeSession.Server = @{ 'IP' = @{ 'Port' = 0 }; 'Type' = 'SCRIPT' }
            Set-PodePortForServerType
            $PodeSession.Server.IP.Port | Should Be 0
        }

        It 'Uses 0 for service' {
            $PodeSession.Server = @{ 'IP' = @{ 'Port' = 0 }; 'Type' = 'SERVICE' }
            Set-PodePortForServerType
            $PodeSession.Server.IP.Port | Should Be 0
        }
    }
}