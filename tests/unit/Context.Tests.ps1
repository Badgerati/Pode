$path = $MyInvocation.MyCommand.Path
$src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit', '/src/'
Get-ChildItem "$($src)/*.ps1" -Recurse | Resolve-Path | ForEach-Object { . $_ }

$PodeContext = @{ 'Server' = $null; }

Describe 'Get-PodeConfig' {
    It 'Returns JSON config' {
        $json = '{ "settings": { "port": 90 } }'
        $PodeContext.Server = @{ 'Configuration' = ($json | ConvertFrom-Json) }
        $config = Get-PodeConfig
        $config | Should Not Be $null
        $config.settings.port | Should Be 90
    }
}

Describe 'Add-PodeEndpoint' {
    Context 'Invalid parameters supplied' {
        It 'Throw invalid type error for no protocol' {
            { Add-PodeEndpoint -Address '127.0.0.1' -Protocol 'MOO' } | Should Throw "Cannot validate argument on parameter 'Protocol'"
        }
    }

    Context 'Valid parameters supplied' {
        Mock Test-PodeIPAddress { return $true }
        Mock Test-IsAdminUser { return $true }

        It 'Set just a Hostname address' {
            $PodeContext.Server = @{ 'Endpoints' = @(); 'Type' = $null }
            Add-PodeEndpoint -Address 'foo.com' -Protocol 'HTTP'

            $PodeContext.Server.Type | Should Be 'HTTP'
            $PodeContext.Server.Endpoints | Should Not Be $null
            $PodeContext.Server.Endpoints.Length | Should Be 1
            $PodeContext.Server.Endpoints[0].Port | Should Be 0
            $PodeContext.Server.Endpoints[0].Name | Should Be ([string]::Empty)
            $PodeContext.Server.Endpoints[0].HostName | Should Be 'foo.com'
            $PodeContext.Server.Endpoints[0].Address.ToString() | Should Be 'foo.com'
            $PodeContext.Server.Endpoints[0].RawAddress | Should Be 'foo.com:0'
        }

        It 'Set Hostname address with a Name' {
            $PodeContext.Server = @{ 'Endpoints' = @(); 'Type' = $null }
            Add-PodeEndpoint -Address 'foo.com' -Protocol 'HTTP' -Name 'Example'

            $PodeContext.Server.Type | Should Be 'HTTP'
            $PodeContext.Server.Endpoints | Should Not Be $null
            $PodeContext.Server.Endpoints.Length | Should Be 1
            $PodeContext.Server.Endpoints[0].Port | Should Be 0
            $PodeContext.Server.Endpoints[0].Name | Should Be 'Example'
            $PodeContext.Server.Endpoints[0].HostName | Should Be 'foo.com'
            $PodeContext.Server.Endpoints[0].Address.ToString() | Should Be 'foo.com'
        }

        It 'Set just a Hostname address with colon' {
            $PodeContext.Server = @{ 'Endpoints' = @(); 'Type' = $null }
            Add-PodeEndpoint -Address 'foo.com' -Protocol 'HTTP'

            $PodeContext.Server.Type | Should Be 'HTTP'
            $PodeContext.Server.Endpoints | Should Not Be $null
            $PodeContext.Server.Endpoints.Length | Should Be 1
            $PodeContext.Server.Endpoints[0].Port | Should Be 0
            $PodeContext.Server.Endpoints[0].HostName | Should Be 'foo.com'
            $PodeContext.Server.Endpoints[0].Address.ToString() | Should Be 'foo.com'
            $PodeContext.Server.Endpoints[0].RawAddress | Should Be 'foo.com:0'
        }

        It 'Set both the Hostname address and port' {
            $PodeContext.Server = @{ 'Endpoints' = @(); 'Type' = $null }
            Add-PodeEndpoint -Address 'foo.com' -Port 80 -Protocol 'HTTP'

            $PodeContext.Server.Type | Should Be 'HTTP'
            $PodeContext.Server.Endpoints | Should Not Be $null
            $PodeContext.Server.Endpoints.Length | Should Be 1
            $PodeContext.Server.Endpoints[0].Port | Should Be 80
            $PodeContext.Server.Endpoints[0].HostName | Should Be 'foo.com'
            $PodeContext.Server.Endpoints[0].Address.ToString() | Should Be 'foo.com'
        }

        It 'Set just an IPv4 address' {
            $PodeContext.Server = @{ 'Endpoints' = @(); 'Type' = $null }
            Add-PodeEndpoint -Address '127.0.0.1' -Protocol 'HTTP'

            $PodeContext.Server.Type | Should Be 'HTTP'
            $PodeContext.Server.Endpoints | Should Not Be $null
            $PodeContext.Server.Endpoints.Length | Should Be 1
            $PodeContext.Server.Endpoints[0].Port | Should Be 0
            $PodeContext.Server.Endpoints[0].HostName | Should Be 'localhost'
            $PodeContext.Server.Endpoints[0].Address.ToString() | Should Be '127.0.0.1'
        }

        It 'Set just an IPv4 address for all' {
            $PodeContext.Server = @{ 'Endpoints' = @(); 'Type' = $null }
            Add-PodeEndpoint -Address 'all' -Protocol 'HTTP'

            $PodeContext.Server.Type | Should Be 'HTTP'
            $PodeContext.Server.Endpoints | Should Not Be $null
            $PodeContext.Server.Endpoints.Length | Should Be 1
            $PodeContext.Server.Endpoints[0].Port | Should Be 0
            $PodeContext.Server.Endpoints[0].HostName | Should Be 'localhost'
            $PodeContext.Server.Endpoints[0].Address.ToString() | Should Be '0.0.0.0'
            $PodeContext.Server.Endpoints[0].RawAddress | Should Be 'all:0'
        }

        It 'Set just an IPv4 address with colon' {
            $PodeContext.Server = @{ 'Endpoints' = @(); 'Type' = $null }
            Add-PodeEndpoint -Address '127.0.0.1' -Protocol 'HTTP'

            $PodeContext.Server.Type | Should Be 'HTTP'
            $PodeContext.Server.Endpoints | Should Not Be $null
            $PodeContext.Server.Endpoints.Length | Should Be 1
            $PodeContext.Server.Endpoints[0].Port | Should Be 0
            $PodeContext.Server.Endpoints[0].HostName | Should Be 'localhost'
            $PodeContext.Server.Endpoints[0].Address.ToString() | Should Be '127.0.0.1'
        }

        It 'Set just a port' {
            $PodeContext.Server = @{ 'Endpoints' = @(); 'Type' = $null }
            Add-PodeEndpoint -Port 80 -Protocol 'HTTP'

            $PodeContext.Server.Type | Should Be 'HTTP'
            $PodeContext.Server.Endpoints | Should Not Be $null
            $PodeContext.Server.Endpoints.Length | Should Be 1
            $PodeContext.Server.Endpoints[0].Port | Should Be 80
            $PodeContext.Server.Endpoints[0].HostName | Should Be 'localhost'
            $PodeContext.Server.Endpoints[0].Address.ToString() | Should Be 'localhost'
        }

        It 'Set just a port with colon' {
            $PodeContext.Server = @{ 'Endpoints' = @(); 'Type' = $null }
            Add-PodeEndpoint -Port 80 -Protocol 'HTTP'

            $PodeContext.Server.Type | Should Be 'HTTP'
            $PodeContext.Server.Endpoints | Should Not Be $null
            $PodeContext.Server.Endpoints.Length | Should Be 1
            $PodeContext.Server.Endpoints[0].Port | Should Be 80
            $PodeContext.Server.Endpoints[0].HostName | Should Be 'localhost'
            $PodeContext.Server.Endpoints[0].Address.ToString() | Should Be 'localhost'
        }

        It 'Set both IPv4 address and port' {
            $PodeContext.Server = @{ 'Endpoints' = @(); 'Type' = $null }
            Add-PodeEndpoint -Address '127.0.0.1' -Port 80 -Protocol 'HTTP'

            $PodeContext.Server.Type | Should Be 'HTTP'
            $PodeContext.Server.Endpoints | Should Not Be $null
            $PodeContext.Server.Endpoints.Length | Should Be 1
            $PodeContext.Server.Endpoints[0].Port | Should Be 80
            $PodeContext.Server.Endpoints[0].HostName | Should Be 'localhost'
            $PodeContext.Server.Endpoints[0].Address.ToString() | Should Be '127.0.0.1'
        }

        It 'Set both IPv4 address and port for all' {
            $PodeContext.Server = @{ 'Endpoints' = @(); 'Type' = $null }
            Add-PodeEndpoint -Address '*' -Port 80 -Protocol 'HTTP'

            $PodeContext.Server.Type | Should Be 'HTTP'
            $PodeContext.Server.Endpoints | Should Not Be $null
            $PodeContext.Server.Endpoints.Length | Should Be 1
            $PodeContext.Server.Endpoints[0].Port | Should Be 80
            $PodeContext.Server.Endpoints[0].HostName | Should Be 'localhost'
            $PodeContext.Server.Endpoints[0].Address.ToString() | Should Be '0.0.0.0'
            $PodeContext.Server.Endpoints[0].RawAddress | Should Be '*:80'
        }

        It 'Throws error for an invalid IPv4' {
            $PodeContext.Server = @{ 'Endpoints' = @(); 'Type' = $null }
            { Add-PodeEndpoint -Address '256.0.0.1' -Protocol 'HTTP' } | Should Throw 'Invalid IP Address'

            $PodeContext.Server.Type | Should Be $null
            $PodeContext.Server.Endpoints | Should Be $null
        }

        It 'Throws error for an invalid IPv4 address with port' {
            $PodeContext.Server = @{ 'Endpoints' = @(); 'Type' = $null }
            { Add-PodeEndpoint -Address '256.0.0.1' -Port 80 -Protocol 'HTTP' } | Should Throw 'Invalid IP Address'

            $PodeContext.Server.Type | Should Be $null
            $PodeContext.Server.Endpoints | Should Be $null
        }

        It 'Add two endpoints to listen on, of the same type' {
            $PodeContext.Server = @{ 'Endpoints' = @(); 'Type' = $null }
            Add-PodeEndpoint -Address '127.0.0.1' -Port 80 -Protocol 'HTTP'
            Add-PodeEndpoint -Address 'pode.foo.com' -Port 80 -Protocol 'HTTP'

            $PodeContext.Server.Type | Should Be 'HTTP'
            $PodeContext.Server.Endpoints | Should Not Be $null
            $PodeContext.Server.Endpoints.Length | Should Be 2

            $PodeContext.Server.Endpoints[0].Port | Should Be 80
            $PodeContext.Server.Endpoints[0].HostName | Should Be 'localhost'
            $PodeContext.Server.Endpoints[0].Address.ToString() | Should Be '127.0.0.1'

            $PodeContext.Server.Endpoints[1].Port | Should Be 80
            $PodeContext.Server.Endpoints[1].HostName | Should Be 'pode.foo.com'
            $PodeContext.Server.Endpoints[1].Address.ToString() | Should Be 'pode.foo.com'
        }

        It 'Add two endpoints to listen on, with different names' {
            $PodeContext.Server = @{ 'Endpoints' = @(); 'Type' = $null }
            Add-PodeEndpoint -Address '127.0.0.1' -Port 80 -Protocol 'HTTP' -Name 'Example1'
            Add-PodeEndpoint -Address 'pode.foo.com' -Port 80 -Protocol 'HTTP' -Name 'Example2'

            $PodeContext.Server.Type | Should Be 'HTTP'
            $PodeContext.Server.Endpoints | Should Not Be $null
            $PodeContext.Server.Endpoints.Length | Should Be 2

            $PodeContext.Server.Endpoints[0].Port | Should Be 80
            $PodeContext.Server.Endpoints[0].Name | Should Be 'Example1'
            $PodeContext.Server.Endpoints[0].HostName | Should Be 'localhost'
            $PodeContext.Server.Endpoints[0].Address.ToString() | Should Be '127.0.0.1'

            $PodeContext.Server.Endpoints[1].Port | Should Be 80
            $PodeContext.Server.Endpoints[1].Name | Should Be 'Example2'
            $PodeContext.Server.Endpoints[1].HostName | Should Be 'pode.foo.com'
            $PodeContext.Server.Endpoints[1].Address.ToString() | Should Be 'pode.foo.com'
        }

        It 'Add two endpoints to listen on, one of HTTP and one of HTTPS' {
            $PodeContext.Server = @{ 'Endpoints' = @(); 'Type' = $null }
            Add-PodeEndpoint -Address '127.0.0.1' -Port 80 -Protocol 'HTTP'
            Add-PodeEndpoint -Address 'pode.foo.com' -Port 80 -Protocol 'HTTPS'

            $PodeContext.Server.Type | Should Be 'HTTP'
            $PodeContext.Server.Endpoints | Should Not Be $null
            $PodeContext.Server.Endpoints.Length | Should Be 2

            $PodeContext.Server.Endpoints[0].Port | Should Be 80
            $PodeContext.Server.Endpoints[0].HostName | Should Be 'localhost'
            $PodeContext.Server.Endpoints[0].Address.ToString() | Should Be '127.0.0.1'

            $PodeContext.Server.Endpoints[1].Port | Should Be 80
            $PodeContext.Server.Endpoints[1].HostName | Should Be 'pode.foo.com'
            $PodeContext.Server.Endpoints[1].Address.ToString() | Should Be 'pode.foo.com'
        }

        It 'Add two endpoints to listen on, but one added as they are the same' {
            $PodeContext.Server = @{ 'Endpoints' = @(); 'Type' = $null }
            Add-PodeEndpoint -Address '127.0.0.1' -Port 80 -Protocol 'HTTP'
            Add-PodeEndpoint -Address '127.0.0.1' -Port 80 -Protocol 'HTTP'

            $PodeContext.Server.Type | Should Be 'HTTP'
            $PodeContext.Server.Endpoints | Should Not Be $null
            $PodeContext.Server.Endpoints.Length | Should Be 1

            $PodeContext.Server.Endpoints[0].Port | Should Be 80
            $PodeContext.Server.Endpoints[0].HostName | Should Be 'localhost'
            $PodeContext.Server.Endpoints[0].Address.ToString() | Should Be '127.0.0.1'
        }

        It 'Throws error when adding two endpoints of different types' {
            $PodeContext.Server = @{ 'Endpoints' = @(); 'Type' = $null }
            Add-PodeEndpoint -Address '127.0.0.1' -Port 80 -Protocol 'HTTP'
            { Add-PodeEndpoint -Address 'pode.foo.com' -Port 80 -Protocol 'SMTP' } | Should Throw 'cannot add smtp endpoint'
        }

        It 'Throws error when adding two endpoints with the same name' {
            $PodeContext.Server = @{ 'Endpoints' = @(); 'Type' = $null }
            Add-PodeEndpoint -Address '127.0.0.1' -Port 80 -Protocol 'HTTP' -Name 'Example'
            { Add-PodeEndpoint -Address 'pode.foo.com' -Port 80 -Protocol 'HTTP' -Name 'Example' } | Should Throw 'already been defined'
        }

        It 'Throws error when adding two SMTP endpoints' {
            $PodeContext.Server = @{ 'Endpoints' = @(); 'Type' = $null }
            Add-PodeEndpoint -Address '127.0.0.1' -Port 80 -Protocol 'SMTP'
            { Add-PodeEndpoint -Address 'pode.foo.com' -Port 80 -Protocol 'SMTP' } | Should Throw 'already been defined'
        }

        It 'Throws error when adding two TCP endpoints' {
            $PodeContext.Server = @{ 'Endpoints' = @(); 'Type' = $null }
            Add-PodeEndpoint -Address '127.0.0.1' -Port 80 -Protocol 'TCP'
            { Add-PodeEndpoint -Address 'pode.foo.com' -Port 80 -Protocol 'TCP' } | Should Throw 'already been defined'
        }

        It 'Throws an error for not running as admin' {
            Mock Test-IsAdminUser { return $false }
            $PodeContext.Server = @{ 'Endpoints' = @(); 'Type' = $null }
            { Add-PodeEndpoint -Address 'foo.com' -Protocol 'HTTP' } | Should Throw 'Must be running with admin'
        }
    }
}

Describe 'Import-PodeModule' {
    Context 'Invalid parameters supplied' {
        It 'Throw null path parameter error' {
            { Import-PodeModule -Path $null } | Should Throw 'it is an empty string'
        }

        It 'Throw empty path parameter error' {
            { Import-PodeModule -Path ([string]::Empty) } | Should Throw 'it is an empty string'
        }

        It 'Throw null name parameter error' {
            { Import-PodeModule -Name $null } | Should Throw 'it is an empty string'
        }

        It 'Throw empty name parameter error' {
            { Import-PodeModule -Name ([string]::Empty) } | Should Throw 'it is an empty string'
        }
    }

    Context 'Valid parameters supplied' {
        Mock Resolve-Path { return @{ 'Path' = 'c:/some/file.txt' } }
        Mock Test-PodePath { return $true }

        It 'Returns null for no shared state in context' {
            $PodeContext = @{ 'RunspaceState' = [initialsessionstate]::CreateDefault() }

            Import-PodeModule -Path 'file.txt'

            $modules = @($PodeContext.RunspaceState.Modules)
            $modules.Length | Should Be 1
            $modules[0].Name | Should Be 'c:/some/file.txt'
        }
    }
}

Describe 'New-PodeAutoRestartServer' {
    It 'Do not create any restart schedules' {
        Mock 'Get-PodeConfig' { return @{} }

        $PodeContext = @{ 'Timers' = @{}; 'Schedules' = @{}; }
        New-PodeAutoRestartServer

        $PodeContext.Timers.Count | Should Be 0
        $PodeContext.Schedules.Count | Should Be 0
    }

    It 'Creates a timer for a period server restart' {
        Mock 'Get-PodeConfig' { return @{
            'server' = @{
                'restart'=  @{
                    'period' = 180;
                }
            }
        } }

        $PodeContext = @{ 'Timers' = @{}; 'Schedules' = @{}; }
        New-PodeAutoRestartServer

        $PodeContext.Timers.Count | Should Be 1
        $PodeContext.Schedules.Count | Should Be 0
        $PodeContext.Timers.Keys[0] | Should Be '__pode_restart_period__'
    }

    It 'Creates a schedule for a timed server restart' {
        Mock 'Get-PodeConfig' { return @{
            'server' = @{
                'restart'=  @{
                    'times' = @('18:00');
                }
            }
        } }

        $PodeContext = @{ 'Timers' = @{}; 'Schedules' = @{}; }
        New-PodeAutoRestartServer

        $PodeContext.Timers.Count | Should Be 0
        $PodeContext.Schedules.Count | Should Be 1
        $PodeContext.Schedules.Keys[0] | Should Be '__pode_restart_times__'
    }

    It 'Creates a schedule for a cron server restart' {
        Mock 'Get-PodeConfig' { return @{
            'server' = @{
                'restart'=  @{
                    'crons' = @('@minutely');
                }
            }
        } }

        $PodeContext = @{ 'Timers' = @{}; 'Schedules' = @{}; }
        New-PodeAutoRestartServer

        $PodeContext.Timers.Count | Should Be 0
        $PodeContext.Schedules.Count | Should Be 1
        $PodeContext.Schedules.Keys[0] | Should Be '__pode_restart_crons__'
    }

    It 'Creates a timer and schedule for a period and cron server restart' {
        Mock 'Get-PodeConfig' { return @{
            'server' = @{
                'restart'=  @{
                    'period' = 180;
                    'crons' = @('@minutely');
                }
            }
        } }

        $PodeContext = @{ 'Timers' = @{}; 'Schedules' = @{}; }
        New-PodeAutoRestartServer

        $PodeContext.Timers.Count | Should Be 1
        $PodeContext.Schedules.Count | Should Be 1
        $PodeContext.Timers.Keys[0] | Should Be '__pode_restart_period__'
        $PodeContext.Schedules.Keys[0] | Should Be '__pode_restart_crons__'
    }

    It 'Creates a timer and schedule for a period and timed server restart' {
        Mock 'Get-PodeConfig' { return @{
            'server' = @{
                'restart'=  @{
                    'period' = 180;
                    'times' = @('18:00');
                }
            }
        } }

        $PodeContext = @{ 'Timers' = @{}; 'Schedules' = @{}; }
        New-PodeAutoRestartServer

        $PodeContext.Timers.Count | Should Be 1
        $PodeContext.Schedules.Count | Should Be 1
        $PodeContext.Timers.Keys[0] | Should Be '__pode_restart_period__'
        $PodeContext.Schedules.Keys[0] | Should Be '__pode_restart_times__'
    }

    It 'Creates two schedules for a cron and timed server restart' {
        Mock 'Get-PodeConfig' { return @{
            'server' = @{
                'restart'=  @{
                    'crons' = @('@minutely');
                    'times' = @('18:00');
                }
            }
        } }

        $PodeContext = @{ 'Timers' = @{}; 'Schedules' = @{}; }
        New-PodeAutoRestartServer

        $PodeContext.Timers.Count | Should Be 0
        $PodeContext.Schedules.Count | Should Be 2
    }
}