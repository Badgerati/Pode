[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
param()

BeforeAll {
    $path = $PSCommandPath
    $src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit', '/src/'
    Get-ChildItem "$($src)/*.ps1" -Recurse | Resolve-Path | ForEach-Object { . $_ }
    Import-LocalizedData -BindingVariable PodeLocale -BaseDirectory (Join-Path -Path $src -ChildPath 'Locales') -FileName 'Pode'

    # Import Pode Assembly
    $helperPath = (Split-Path -Parent -Path $path) -ireplace 'unit', 'shared'
    . "$helperPath/TestHelper.ps1"
    Import-PodeAssembly -SrcPath $src

    $PodeContext = @{
        Server        = $null
        Metrics       = @{ Server = @{ StartTime = [datetime]::UtcNow } }
        RunspacePools = @{}
        Tokens        = $null
    }
}

Describe 'Start-PodeInternalServer' {
    BeforeAll {
        Mock Add-PodePSInbuiltDrive {}
        Mock Invoke-PodeScriptBlock {}
        Mock New-PodeRunspaceState {}
        Mock New-PodeRunspacePool {}
        Mock Start-PodeLoggerDispatcher {}
        Mock Start-PodeTimerRunspace {}
        Mock Start-PodeScheduleRunspace {}
        Mock Start-PodeGuiRunspace {}
        Mock Start-Sleep {}
        Mock New-PodeAutoRestartServer {}
        Mock Start-PodeSmtpServer {}
        Mock Start-PodeTcpServer {}
        Mock Start-PodeWebServer {}
        Mock Start-PodeServiceServer {}
        Mock Import-PodeModulesIntoRunspaceState {}
        Mock Import-PodeSnapinsIntoRunspaceState {}
        Mock Import-PodeFunctionsIntoRunspaceState {}
        Mock Start-PodeCacheHousekeeper {}
        Mock Invoke-PodeEvent {}
        Mock Write-Verbose {}
        Mock Add-PodeScopedVariablesInbuilt {}
        Mock Write-PodeHost {}
        Mock Show-PodeConsoleInfo {}
        Mock Write-PodeErrorLog { }
        Mock Write-PodeLog { }
    }

    It 'Calls one-off script logic' {
        $PodeContext.Server = @{ Types = ([string]::Empty); Logic = {}; Console = @{Quiet = $true }; EndpointsInfo = @() }
        $PodeContext.Tokens = Initialize-PodeCancellationToken
        Start-PodeInternalServer | Out-Null

        Assert-MockCalled Invoke-PodeScriptBlock -Times 1 -Scope It
        Assert-MockCalled New-PodeRunspacePool -Times 1 -Scope It
        Assert-MockCalled New-PodeRunspaceState -Times 1 -Scope It
        Assert-MockCalled Start-PodeTimerRunspace -Times 1 -Scope It
        Assert-MockCalled Start-PodeScheduleRunspace -Times 1 -Scope It
        Assert-MockCalled Start-PodeSmtpServer -Times 0 -Scope It
        Assert-MockCalled Start-PodeTcpServer -Times 0 -Scope It
        Assert-MockCalled Start-PodeWebServer -Times 0 -Scope It
    }

    It 'Calls smtp server logic' {
        $PodeContext.Server = @{ Types = 'SMTP'; Logic = {}; Console = @{Quiet = $true } ; EndpointsInfo = @() }
        $PodeContext.Tokens = Initialize-PodeCancellationToken
        Start-PodeInternalServer | Out-Null

        Assert-MockCalled Invoke-PodeScriptBlock -Times 1 -Scope It
        Assert-MockCalled New-PodeRunspacePool -Times 1 -Scope It
        Assert-MockCalled New-PodeRunspaceState -Times 1 -Scope It
        Assert-MockCalled Start-PodeTimerRunspace -Times 1 -Scope It
        Assert-MockCalled Start-PodeScheduleRunspace -Times 1 -Scope It
        Assert-MockCalled Start-PodeSmtpServer -Times 1 -Scope It
        Assert-MockCalled Start-PodeTcpServer -Times 0 -Scope It
        Assert-MockCalled Start-PodeWebServer -Times 0 -Scope It
    }

    It 'Calls tcp server logic' {
        $PodeContext.Server = @{ Types = 'TCP'; Logic = {}; Console = @{Quiet = $true } ; EndpointsInfo = @() }
        $PodeContext.Tokens = Initialize-PodeCancellationToken
        Start-PodeInternalServer | Out-Null

        Assert-MockCalled Invoke-PodeScriptBlock -Times 1 -Scope It
        Assert-MockCalled New-PodeRunspacePool -Times 1 -Scope It
        Assert-MockCalled New-PodeRunspaceState -Times 1 -Scope It
        Assert-MockCalled Start-PodeTimerRunspace -Times 1 -Scope It
        Assert-MockCalled Start-PodeScheduleRunspace -Times 1 -Scope It
        Assert-MockCalled Start-PodeSmtpServer -Times 0 -Scope It
        Assert-MockCalled Start-PodeTcpServer -Times 1 -Scope It
        Assert-MockCalled Start-PodeWebServer -Times 0 -Scope It
    }

    It 'Calls http web server logic' {
        $PodeContext.Server = @{ Types = 'HTTP'; Logic = {}; Console = @{Quiet = $true } ; EndpointsInfo = @() }
        $PodeContext.Tokens = Initialize-PodeCancellationToken
        Start-PodeInternalServer | Out-Null

        Assert-MockCalled Invoke-PodeScriptBlock -Times 1 -Scope It
        Assert-MockCalled New-PodeRunspacePool -Times 1 -Scope It
        Assert-MockCalled New-PodeRunspaceState -Times 1 -Scope It
        Assert-MockCalled Start-PodeTimerRunspace -Times 1 -Scope It
        Assert-MockCalled Start-PodeScheduleRunspace -Times 1 -Scope It
        Assert-MockCalled Start-PodeSmtpServer -Times 0 -Scope It
        Assert-MockCalled Start-PodeTcpServer -Times 0 -Scope It
        Assert-MockCalled Start-PodeWebServer -Times 1 -Scope It
    }
}

Describe 'Restart-PodeInternalServer' {
    BeforeAll {
        Mock Write-Host {}
        Mock Close-PodeRunspace {}
        Mock Remove-PodePSDrive {}
        Mock Open-PodeConfiguration { return $null }
        Mock Start-PodeInternalServer { }
        Mock Write-PodeErrorLog { }
        Mock Close-PodeDisposable { }
        Mock Invoke-PodeEvent { } 
    }

    It 'Resetting the server values' {
        $PodeContext = @{
            Tokens    = Initialize-PodeCancellationToken
            Server    = @{
                Routes          = @{
                    GET  = @{ 'key' = 'value' }
                    POST = @{ 'key' = 'value' }
                }
                Handlers        = @{
                    SMTP = @{}
                }
                Verbs           = @{
                    key = @{}
                }
                Logging         = @{
                    Type          = @{ 'key' = 'value' }
                    LogsToProcess = [System.Collections.Concurrent.ConcurrentQueue[hashtable]]::new()
                    Method        = @{ 'key' = 'value' }
                }
                Middleware      = @{ 'key' = 'value' }
                Endpoints       = @{ 'key' = 'value' }
                EndpointsMap    = @{ 'key' = 'value' }
                Endware         = @{ 'key' = 'value' }
                ViewEngine      = @{
                    Type      = 'pode'
                    Extension = 'pode'
                    Script    = $null
                    IsDynamic = $true
                }
                Cookies         = @{}
                Sessions        = @{ 'key' = 'value' }
                Authentications = @{
                    Methods = @{ 'key' = 'value' }
                }
                Authorisations  = @{
                    Methods = @{ 'key' = 'value' }
                }
                State           = @{ 'key' = 'value' }
                Output          = @{
                    Variables = @{ 'key' = 'value' }
                }
                Configuration   = @{ Enabled = $false; Server = @{'key' = 'value' } }
                Sockets         = @{
                    Listeners = @()
                    Queues    = @{
                        Connections = [System.Collections.Concurrent.ConcurrentQueue[System.Net.Sockets.SocketAsyncEventArgs]]::new()
                    }
                }
                Signals         = @{
                    Listeners = @()
                    Queues    = @{
                        Sockets     = @{}
                        Connections = [System.Collections.Concurrent.ConcurrentQueue[System.Net.Sockets.SocketAsyncEventArgs]]::new()
                    }
                }
                Http            = @{
                    Listener = $null
                }
                OpenAPI         = @{
                    DefaultDefinitionTag  = 'default'
                    SelectedDefinitionTag = 'default'
                    Definitions           = @{ 'default' = Get-PodeOABaseObject }
                }
                BodyParsers     = @{}
                AutoImport      = @{
                    Modules      = @{ Exported = @() }
                    Snapins      = @{ Exported = @() }
                    Functions    = @{ Exported = @() }
                    SecretVaults = @{
                        SecretManagement = @{ Exported = @() }
                    }
                }
                Views           = @{ 'key' = 'value' }
                Events          = @{
                    Start = @{}
                }
                Modules         = @{}
                Security        = @{
                    Headers = @{}
                    Cache   = @{
                        ContentSecurity   = @{}
                        PermissionsPolicy = @{}
                    }
                }
                Secrets         = @{
                    Vaults = @{}
                    Keys   = @{}
                }
                Cache           = @{
                    Items   = @{}
                    Storage = @{}
                }
                ScopedVariables = @{}
                Console         = @{
                    DisableTermination  = $true
                    DisableConsoleInput = $true
                    Quiet               = $true
                    ClearHost           = $false
                    ShowOpenAPI         = $true
                    ShowEndpoints       = $true
                    ShowHelp            = $false

                }
                AllowedActions  = @{
                    Suspend = $true
                    Restart = $true
                    Timeout = @{
                        Suspend = 30  # timeout in seconds
                        Resume  = 30  # timeout in seconds
                    }
                }

            }
            Metrics   = @{
                Server = @{
                    RestartCount = 0
                }
            }
            Timers    = @{
                Enabled = $true
                Items   = @{
                    key = 'value'
                }
            }
            Schedules = @{
                Enabled   = $true
                Items     = @{
                    key = 'value'
                }
                Processes = @{}
            }
            Tasks     = @{
                Enabled   = $true
                Items     = @{
                    key = 'value'
                }
                Processes = @{}
            }
            Fim       = @{
                Enabled = $true
                Items   = @{
                    key = 'value'
                }
            }
            Threading = @{
                Lockables  = @{ Custom = @{} }
                Mutexes    = @{}
                Semaphores = @{}
            }
        }
        Restart-PodeServer
        Restart-PodeInternalServer | Out-Null

        $PodeContext.Server.Routes['GET'].Count | Should -Be 0
        $PodeContext.Server.Logging.Type.Count | Should -Be 0
        $PodeContext.Server.Middleware.Count | Should -Be 0
        $PodeContext.Server.Endware.Count | Should -Be 0
        $PodeContext.Server.Sessions.Count | Should -Be 0
        $PodeContext.Server.Authentications.Methods.Count | Should -Be 0
        $PodeContext.Server.State.Count | Should -Be 0
        $PodeContext.Server.Configuration.Count | Should -Be 2
        $PodeContext.Server.Configuration.Enabled | Should -BeFalse
        $PodeContext.Server.Configuration.Server.Key | Should -Be 'value'

        $PodeContext.Timers.Items.Count | Should -Be 0
        $PodeContext.Schedules.Items.Count | Should -Be 0

        $PodeContext.Server.ViewEngine.Type | Should -Be 'html'
        $PodeContext.Server.ViewEngine.Extension | Should -Be 'html'
        $PodeContext.Server.ViewEngine.ScriptBlock | Should -Be $null
        $PodeContext.Server.ViewEngine.UsingVariables | Should -Be $null
        $PodeContext.Server.ViewEngine.IsDynamic | Should -Be $false

        $PodeContext.Metrics.Server.RestartCount | Should -Be 1
    }
}