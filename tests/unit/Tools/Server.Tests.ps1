$path = $MyInvocation.MyCommand.Path
$src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit[\\/]', '/src/'
Get-ChildItem "$($src)/*.ps1" | Resolve-Path | ForEach-Object { . $_ }

$PodeContext = @{ 'Server' = $null; }

Describe 'Start-PodeServer' {
    Mock Add-PodePSInbuiltDrives { }
    Mock Invoke-ScriptBlock { }
    Mock New-PodeRunspaceState { }
    Mock New-PodeRunspacePools { }
    Mock Start-TimerRunspace { }
    Mock Start-ScheduleRunspace { }
    Mock Start-Sleep { }
    Mock Start-SmtpServer { }
    Mock Start-TcpServer { }
    Mock Start-WebServer { }

    It 'Calls one-off script logic' {
        $PodeContext.Server = @{ 'Type' = ([string]::Empty); 'Logic' = {} }
        Start-PodeServer | Out-Null

        Assert-MockCalled Invoke-ScriptBlock -Times 1 -Scope It
        Assert-MockCalled New-PodeRunspacePools -Times 1 -Scope It
        Assert-MockCalled New-PodeRunspaceState -Times 1 -Scope It
        Assert-MockCalled Start-TimerRunspace -Times 0 -Scope It
        Assert-MockCalled Start-ScheduleRunspace -Times 0 -Scope It
        Assert-MockCalled Start-SmtpServer -Times 0 -Scope It
        Assert-MockCalled Start-TcpServer -Times 0 -Scope It
        Assert-MockCalled Start-WebServer -Times 0 -Scope It
    }

    It 'Calls smtp server logic' {
        $PodeContext.Server = @{ 'Type' = 'SMTP'; 'Logic' = {} }
        Start-PodeServer | Out-Null

        Assert-MockCalled Invoke-ScriptBlock -Times 1 -Scope It
        Assert-MockCalled New-PodeRunspacePools -Times 1 -Scope It
        Assert-MockCalled New-PodeRunspaceState -Times 1 -Scope It
        Assert-MockCalled Start-TimerRunspace -Times 1 -Scope It
        Assert-MockCalled Start-ScheduleRunspace -Times 1 -Scope It
        Assert-MockCalled Start-SmtpServer -Times 1 -Scope It
        Assert-MockCalled Start-TcpServer -Times 0 -Scope It
        Assert-MockCalled Start-WebServer -Times 0 -Scope It
    }

    It 'Calls tcp server logic' {
        $PodeContext.Server = @{ 'Type' = 'TCP'; 'Logic' = {} }
        Start-PodeServer | Out-Null

        Assert-MockCalled Invoke-ScriptBlock -Times 1 -Scope It
        Assert-MockCalled New-PodeRunspacePools -Times 1 -Scope It
        Assert-MockCalled New-PodeRunspaceState -Times 1 -Scope It
        Assert-MockCalled Start-TimerRunspace -Times 1 -Scope It
        Assert-MockCalled Start-ScheduleRunspace -Times 1 -Scope It
        Assert-MockCalled Start-SmtpServer -Times 0 -Scope It
        Assert-MockCalled Start-TcpServer -Times 1 -Scope It
        Assert-MockCalled Start-WebServer -Times 0 -Scope It
    }

    It 'Calls http web server logic' {
        $PodeContext.Server = @{ 'Type' = 'HTTP'; 'Logic' = {} }
        Start-PodeServer | Out-Null

        Assert-MockCalled Invoke-ScriptBlock -Times 1 -Scope It
        Assert-MockCalled New-PodeRunspacePools -Times 1 -Scope It
        Assert-MockCalled New-PodeRunspaceState -Times 1 -Scope It
        Assert-MockCalled Start-TimerRunspace -Times 1 -Scope It
        Assert-MockCalled Start-ScheduleRunspace -Times 1 -Scope It
        Assert-MockCalled Start-SmtpServer -Times 0 -Scope It
        Assert-MockCalled Start-TcpServer -Times 0 -Scope It
        Assert-MockCalled Start-WebServer -Times 1 -Scope It
    }

    It 'Calls https web server logic' {
        $PodeContext.Server = @{ 'Type' = 'HTTPS'; 'Logic' = {} }
        Start-PodeServer | Out-Null

        Assert-MockCalled Invoke-ScriptBlock -Times 1 -Scope It
        Assert-MockCalled New-PodeRunspacePools -Times 1 -Scope It
        Assert-MockCalled New-PodeRunspaceState -Times 1 -Scope It
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
            Get-PodeServerType | Should Be ([string]::Empty)
        }
    }
}