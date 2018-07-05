$path = $MyInvocation.MyCommand.Path
$src = (Split-Path -Parent -Path $path) -ireplace '\\tests\\unit\\', '\src\'
Get-ChildItem "$($src)\*.ps1" | Resolve-Path | ForEach-Object { . $_ }

Describe 'Start-PodeServer' {
    Mock Invoke-ScriptBlock { }
    Mock Start-TimerRunspace { }
    Mock Start-Sleep { }
    Mock Start-SmtpServer { }
    Mock Start-TcpServer { }
    Mock Start-WebServer { }

    It 'Calls one-off script logic' {
        $PodeSession = @{ 'ServerType' = 'SCRIPT'; 'ScriptBlock' = {} }
        Start-PodeServer | Out-Null

        Assert-MockCalled Invoke-ScriptBlock -Times 1 -Scope It
        Assert-MockCalled Start-TimerRunspace -Times 1 -Scope It
        Assert-MockCalled Start-SmtpServer -Times 0 -Scope It
        Assert-MockCalled Start-TcpServer -Times 0 -Scope It
        Assert-MockCalled Start-WebServer -Times 0 -Scope It
    }

    It 'Calls smtp server logic' {
        $PodeSession = @{ 'ServerType' = 'SMTP'; 'ScriptBlock' = {} }
        Start-PodeServer | Out-Null

        Assert-MockCalled Invoke-ScriptBlock -Times 1 -Scope It
        Assert-MockCalled Start-TimerRunspace -Times 1 -Scope It
        Assert-MockCalled Start-SmtpServer -Times 1 -Scope It
        Assert-MockCalled Start-TcpServer -Times 0 -Scope It
        Assert-MockCalled Start-WebServer -Times 0 -Scope It
    }

    It 'Calls tcp server logic' {
        $PodeSession = @{ 'ServerType' = 'TCP'; 'ScriptBlock' = {} }
        Start-PodeServer | Out-Null

        Assert-MockCalled Invoke-ScriptBlock -Times 1 -Scope It
        Assert-MockCalled Start-TimerRunspace -Times 1 -Scope It
        Assert-MockCalled Start-SmtpServer -Times 0 -Scope It
        Assert-MockCalled Start-TcpServer -Times 1 -Scope It
        Assert-MockCalled Start-WebServer -Times 0 -Scope It
    }

    It 'Calls http web server logic' {
        $PodeSession = @{ 'ServerType' = 'HTTP'; 'ScriptBlock' = {} }
        Start-PodeServer | Out-Null

        Assert-MockCalled Invoke-ScriptBlock -Times 1 -Scope It
        Assert-MockCalled Start-TimerRunspace -Times 1 -Scope It
        Assert-MockCalled Start-SmtpServer -Times 0 -Scope It
        Assert-MockCalled Start-TcpServer -Times 0 -Scope It
        Assert-MockCalled Start-WebServer -Times 1 -Scope It
    }

    It 'Calls https web server logic' {
        $PodeSession = @{ 'ServerType' = 'HTTPS'; 'ScriptBlock' = {} }
        Start-PodeServer | Out-Null

        Assert-MockCalled Invoke-ScriptBlock -Times 1 -Scope It
        Assert-MockCalled Start-TimerRunspace -Times 1 -Scope It
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
            $PodeSession = @{ 'IP' = @{ 'Port' = 0 }; 'ServerType' = 'SMTP' }
            Set-PodePortForServerType
            $PodeSession.IP.Port | Should Be 25
        }

        It 'Uses 8080 for http' {
            $PodeSession = @{ 'IP' = @{ 'Port' = 0 }; 'ServerType' = 'HTTP' }
            Set-PodePortForServerType
            $PodeSession.IP.Port | Should Be 8080
        }

        It 'Uses 8443 for https' {
            $PodeSession = @{ 'IP' = @{ 'Port' = 0 }; 'ServerType' = 'HTTPS' }
            Set-PodePortForServerType
            $PodeSession.IP.Port | Should Be 8443
        }

        It 'Uses 0 for tcp' {
            $PodeSession = @{ 'IP' = @{ 'Port' = 0 }; 'ServerType' = 'TCP' }
            Set-PodePortForServerType
            $PodeSession.IP.Port | Should Be 0
        }

        It 'Uses 0 for script' {
            $PodeSession = @{ 'IP' = @{ 'Port' = 0 }; 'ServerType' = 'SCRIPT' }
            Set-PodePortForServerType
            $PodeSession.IP.Port | Should Be 0
        }

        It 'Uses 0 for service' {
            $PodeSession = @{ 'IP' = @{ 'Port' = 0 }; 'ServerType' = 'SERVICE' }
            Set-PodePortForServerType
            $PodeSession.IP.Port | Should Be 0
        }
    }
}