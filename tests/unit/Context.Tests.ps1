[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
param()
BeforeAll {
    $path = $PSCommandPath
    $src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit', '/src/'
    Get-ChildItem "$($src)/*.ps1" -Recurse | Resolve-Path | ForEach-Object { . $_ }
    Import-LocalizedData -BindingVariable PodeLocale -BaseDirectory (Join-Path -Path $src -ChildPath 'Locales') -UICulture 'en-us' -FileName 'Pode'
    $PodeContext = @{ 'Server' = $null; }
}


Describe 'Get-PodeConfig' {
    It 'Returns JSON config' {
        $json = '{ "settings": { "port": 90 } }'
        $PodeContext.Server = @{ 'Configuration' = ($json | ConvertFrom-Json) }
        $config = Get-PodeConfig
        $config | Should -Not -Be $null
        $config.settings.port | Should -Be 90
    }
}

Describe 'Add-PodeEndpoint' {
    Context 'Invalid parameters supplied' {
        It 'Throw invalid type error for no protocol' {
            { Add-PodeEndpoint -Address '127.0.0.1' -Protocol 'MOO' } | Should -Throw -ExpectedMessage "Cannot validate argument on parameter 'Protocol'*"
        }
    }

    Context 'Valid parameters supplied' {
        BeforeAll {
            Mock Test-PodeIPAddress { return $true }
            Mock Test-PodeIsAdminUser { return $true }
        }
        It 'Set just a Hostname address - old' {
            $PodeContext.Server = @{ Endpoints = @{}; EndpointsMap = @{}; 'Type' = $null }
            Add-PodeEndpoint -Address 'foo.com' -Protocol 'HTTP'

            $PodeContext.Server.Types | Should -Be 'HTTP'
            $PodeContext.Server.Endpoints | Should -Not -Be $null
            $PodeContext.Server.Endpoints.Count | Should -Be 1

            $endpoint = ($PodeContext.Server.Endpoints.Values | Select-Object -First 1)
            $endpoint.Port | Should -Be 8080
            $endpoint.Name | Should -Not -Be ([string]::Empty)
            $endpoint.HostName | Should -Be 'foo.com'
            $endpoint.Address.ToString() | Should -Be '127.0.0.1'
            $endpoint.Hostname.ToString() | Should -Be 'foo.com'
            $endpoint.RawAddress | Should -Be 'foo.com:8080'
        }

        It 'Set just a Hostname address - new' {
            $PodeContext.Server = @{ Endpoints = @{}; EndpointsMap = @{}; 'Type' = $null }
            Add-PodeEndpoint -Hostname 'foo.com' -Protocol 'HTTP'

            $PodeContext.Server.Types | Should -Be 'HTTP'
            $PodeContext.Server.Endpoints | Should -Not -Be $null
            $PodeContext.Server.Endpoints.Count | Should -Be 1

            $endpoint = ($PodeContext.Server.Endpoints.Values | Select-Object -First 1)
            $endpoint.Port | Should -Be 8080
            $endpoint.Name | Should -Not -Be ([string]::Empty)
            $endpoint.HostName | Should -Be 'foo.com'
            $endpoint.Address.ToString() | Should -Be '127.0.0.1'
            $endpoint.RawAddress | Should -Be 'foo.com:8080'
        }

        It 'Set Hostname address with a Name' {
            $PodeContext.Server = @{ Endpoints = @{}; EndpointsMap = @{}; 'Type' = $null }
            Add-PodeEndpoint -Address 'foo.com' -Protocol 'HTTP' -Name 'Example'

            $PodeContext.Server.Types | Should -Be 'HTTP'
            $PodeContext.Server.Endpoints | Should -Not -Be $null
            $PodeContext.Server.Endpoints.Count | Should -Be 1

            $endpoint = ($PodeContext.Server.Endpoints.Values | Select-Object -First 1)
            $endpoint.Port | Should -Be 8080
            $endpoint.Name | Should -Be 'Example'
            $endpoint.HostName | Should -Be 'foo.com'
            $endpoint.Address.ToString() | Should -Be '127.0.0.1'
        }

        It 'Set just a Hostname address with colon' {
            $PodeContext.Server = @{ Endpoints = @{}; EndpointsMap = @{}; 'Type' = $null }
            Add-PodeEndpoint -Address 'foo.com' -Protocol 'HTTP'

            $PodeContext.Server.Types | Should -Be 'HTTP'
            $PodeContext.Server.Endpoints | Should -Not -Be $null
            $PodeContext.Server.Endpoints.Count | Should -Be 1

            $endpoint = ($PodeContext.Server.Endpoints.Values | Select-Object -First 1)
            $endpoint.Port | Should -Be 8080
            $endpoint.HostName | Should -Be 'foo.com'
            $endpoint.Address.ToString() | Should -Be '127.0.0.1'
            $endpoint.RawAddress | Should -Be 'foo.com:8080'
        }

        It 'Set both the Hostname address and port' {
            $PodeContext.Server = @{ Endpoints = @{}; EndpointsMap = @{}; 'Type' = $null }
            Add-PodeEndpoint -Address 'foo.com' -Port 80 -Protocol 'HTTP'

            $PodeContext.Server.Types | Should -Be 'HTTP'
            $PodeContext.Server.Endpoints | Should -Not -Be $null
            $PodeContext.Server.Endpoints.Count | Should -Be 1

            $endpoint = ($PodeContext.Server.Endpoints.Values | Select-Object -First 1)
            $endpoint.Port | Should -Be 80
            $endpoint.HostName | Should -Be 'foo.com'
            $endpoint.Address.ToString() | Should -Be '127.0.0.1'
        }

        It 'Set all the Hostname, ip and port' {
            $PodeContext.Server = @{ Endpoints = @{}; EndpointsMap = @{}; 'Type' = $null }
            Add-PodeEndpoint -Address '127.0.0.2' -Hostname 'foo.com' -Port 80 -Protocol 'HTTP'

            $PodeContext.Server.Types | Should -Be 'HTTP'
            $PodeContext.Server.Endpoints | Should -Not -Be $null
            $PodeContext.Server.Endpoints.Count | Should -Be 1

            $endpoint = ($PodeContext.Server.Endpoints.Values | Select-Object -First 1)
            $endpoint.Port | Should -Be 80
            $endpoint.HostName | Should -Be 'foo.com'
            $endpoint.Address.ToString() | Should -Be '127.0.0.2'
            $endpoint.RawAddress | Should -Be 'foo.com:80'
        }

        It 'Set just an IPv4 address' {
            $PodeContext.Server = @{ Endpoints = @{}; EndpointsMap = @{}; 'Type' = $null }
            Add-PodeEndpoint -Address '127.0.0.1' -Protocol 'HTTP'

            $PodeContext.Server.Types | Should -Be 'HTTP'
            $PodeContext.Server.Endpoints | Should -Not -Be $null
            $PodeContext.Server.Endpoints.Count | Should -Be 1

            $endpoint = ($PodeContext.Server.Endpoints.Values | Select-Object -First 1)
            $endpoint.Port | Should -Be 8080
            $endpoint.HostName | Should -Be ''
            $endpoint.Address.ToString() | Should -Be '127.0.0.1'
        }

        It 'Set just an IPv4 address for all' {
            $PodeContext.Server = @{ Endpoints = @{}; EndpointsMap = @{}; 'Type' = $null }
            Add-PodeEndpoint -Address 'all' -Protocol 'HTTP'

            $PodeContext.Server.Types | Should -Be 'HTTP'
            $PodeContext.Server.Endpoints | Should -Not -Be $null
            $PodeContext.Server.Endpoints.Count | Should -Be 1

            $endpoint = ($PodeContext.Server.Endpoints.Values | Select-Object -First 1)
            $endpoint.Port | Should -Be 8080
            $endpoint.HostName | Should -Be ''
            $endpoint.Address.ToString() | Should -Be '0.0.0.0'
            $endpoint.RawAddress | Should -Be '0.0.0.0:8080'
        }

        It 'Set just an IPv4 address with colon' {
            $PodeContext.Server = @{ Endpoints = @{}; EndpointsMap = @{}; 'Type' = $null }
            Add-PodeEndpoint -Address '127.0.0.1' -Protocol 'HTTP'

            $PodeContext.Server.Types | Should -Be 'HTTP'
            $PodeContext.Server.Endpoints | Should -Not -Be $null
            $PodeContext.Server.Endpoints.Count | Should -Be 1

            $endpoint = ($PodeContext.Server.Endpoints.Values | Select-Object -First 1)
            $endpoint.Port | Should -Be 8080
            $endpoint.HostName | Should -Be ''
            $endpoint.Address.ToString() | Should -Be '127.0.0.1'
        }

        It 'Set just a port' {
            $PodeContext.Server = @{ Endpoints = @{}; EndpointsMap = @{}; 'Type' = $null }
            Add-PodeEndpoint -Port 80 -Protocol 'HTTP'

            $PodeContext.Server.Types | Should -Be 'HTTP'
            $PodeContext.Server.Endpoints | Should -Not -Be $null
            $PodeContext.Server.Endpoints.Count | Should -Be 1

            $endpoint = ($PodeContext.Server.Endpoints.Values | Select-Object -First 1)
            $endpoint.Port | Should -Be 80
            $endpoint.HostName | Should -Be ''
            $endpoint.Address.ToString() | Should -Be '127.0.0.1'
        }

        It 'Set just a port with colon' {
            $PodeContext.Server = @{ Endpoints = @{}; EndpointsMap = @{}; 'Type' = $null }
            Add-PodeEndpoint -Port 80 -Protocol 'HTTP'

            $PodeContext.Server.Types | Should -Be 'HTTP'
            $PodeContext.Server.Endpoints | Should -Not -Be $null
            $PodeContext.Server.Endpoints.Count | Should -Be 1

            $endpoint = ($PodeContext.Server.Endpoints.Values | Select-Object -First 1)
            $endpoint.Port | Should -Be 80
            $endpoint.HostName | Should -Be ''
            $endpoint.Address.ToString() | Should -Be '127.0.0.1'
        }

        It 'Set both IPv4 address and port' {
            $PodeContext.Server = @{ Endpoints = @{}; EndpointsMap = @{}; 'Type' = $null }
            Add-PodeEndpoint -Address '127.0.0.1' -Port 80 -Protocol 'HTTP'

            $PodeContext.Server.Types | Should -Be 'HTTP'
            $PodeContext.Server.Endpoints | Should -Not -Be $null
            $PodeContext.Server.Endpoints.Count | Should -Be 1

            $endpoint = ($PodeContext.Server.Endpoints.Values | Select-Object -First 1)
            $endpoint.Port | Should -Be 80
            $endpoint.HostName | Should -Be ''
            $endpoint.Address.ToString() | Should -Be '127.0.0.1'
        }

        It 'Set both IPv4 address and port for all' {
            $PodeContext.Server = @{ Endpoints = @{}; EndpointsMap = @{}; 'Type' = $null }
            Add-PodeEndpoint -Address '*' -Port 80 -Protocol 'HTTP'

            $PodeContext.Server.Types | Should -Be 'HTTP'
            $PodeContext.Server.Endpoints | Should -Not -Be $null
            $PodeContext.Server.Endpoints.Count | Should -Be 1

            $endpoint = ($PodeContext.Server.Endpoints.Values | Select-Object -First 1)
            $endpoint.Port | Should -Be 80
            $endpoint.HostName | Should -Be ''
            $endpoint.FriendlyName | Should -Be 'localhost'
            $endpoint.Address.ToString() | Should -Be '0.0.0.0'
            $endpoint.RawAddress | Should -Be '0.0.0.0:80'
        }

        It 'Throws error for an invalid IPv4' {
            $PodeContext.Server = @{ Endpoints = @{}; EndpointsMap = @{}; 'Type' = $null }
            { Add-PodeEndpoint -Address '256.0.0.1' -Protocol 'HTTP' } | Should -Throw -ExpectedMessage '*Invalid IP Address*'

            $PodeContext.Server.Types | Should -Be $null
            $PodeContext.Server.Endpoints.Count | Should -Be 0
        }

        It 'Throws error for an invalid IPv4 address with port' {
            $PodeContext.Server = @{ Endpoints = @{}; EndpointsMap = @{}; 'Type' = $null }
            { Add-PodeEndpoint -Address '256.0.0.1' -Port 80 -Protocol 'HTTP' } | Should -Throw -ExpectedMessage '*Invalid IP Address*'

            $PodeContext.Server.Types | Should -Be $null
            $PodeContext.Server.Endpoints.Count | Should -Be 0
        }

        It 'Add two endpoints to listen on, of the same type' {
            $PodeContext.Server = @{ Endpoints = @{}; EndpointsMap = @{}; 'Type' = $null }
            $ep1 = (Add-PodeEndpoint -Address '127.0.0.1' -Port 80 -Protocol 'HTTP' -PassThru)
            $ep2 = (Add-PodeEndpoint -Address 'pode.foo.com' -Port 80 -Protocol 'HTTP' -PassThru)

            $PodeContext.Server.Types | Should -Be 'HTTP'
            $PodeContext.Server.Endpoints | Should -Not -Be $null
            $PodeContext.Server.Endpoints.Count | Should -Be 2

            $endpoint = $PodeContext.Server.Endpoints[$ep1.Name]
            $endpoint.Port | Should -Be 80
            $endpoint.HostName | Should -Be ''
            $endpoint.Address.ToString() | Should -Be '127.0.0.1'

            $endpoint = $PodeContext.Server.Endpoints[$ep2.Name]
            $endpoint.Port | Should -Be 80
            $endpoint.HostName | Should -Be 'pode.foo.com'
            $endpoint.Address.ToString() | Should -Be '127.0.0.1'
        }

        It 'Add two endpoints to listen on, with different names' {
            $PodeContext.Server = @{ Endpoints = @{}; EndpointsMap = @{}; 'Type' = $null }
            Add-PodeEndpoint -Address '127.0.0.1' -Port 80 -Protocol 'HTTP' -Name 'Example1'
            Add-PodeEndpoint -Address 'pode.foo.com' -Port 80 -Protocol 'HTTP' -Name 'Example2'

            $PodeContext.Server.Types | Should -Be 'HTTP'
            $PodeContext.Server.Endpoints | Should -Not -Be $null
            $PodeContext.Server.Endpoints.Count | Should -Be 2

            $endpoint = $PodeContext.Server.Endpoints['Example1']
            $endpoint.Port | Should -Be 80
            $endpoint.Name | Should -Be 'Example1'
            $endpoint.HostName | Should -Be ''
            $endpoint.Address.ToString() | Should -Be '127.0.0.1'

            $endpoint = $PodeContext.Server.Endpoints['Example2']
            $endpoint.Port | Should -Be 80
            $endpoint.Name | Should -Be 'Example2'
            $endpoint.HostName | Should -Be 'pode.foo.com'
            $endpoint.Address.ToString() | Should -Be '127.0.0.1'
        }

        It 'Add two endpoints to listen on, one of HTTP and one of HTTPS' {
            $PodeContext.Server = @{ Endpoints = @{}; EndpointsMap = @{}; 'Type' = $null }
            Add-PodeEndpoint -Address '127.0.0.1' -Port 80 -Protocol 'HTTP' -Name 'Http'
            Add-PodeEndpoint -Address 'pode.foo.com' -Port 80 -Protocol 'HTTPS' -Name 'Https'

            $PodeContext.Server.Types | Should -Be 'HTTP'
            $PodeContext.Server.Endpoints | Should -Not -Be $null
            $PodeContext.Server.Endpoints.Count | Should -Be 2

            $endpoint = $PodeContext.Server.Endpoints['Http']
            $endpoint.Port | Should -Be 80
            $endpoint.HostName | Should -Be ''
            $endpoint.Address.ToString() | Should -Be '127.0.0.1'

            $endpoint = $PodeContext.Server.Endpoints['Https']
            $endpoint.Port | Should -Be 80
            $endpoint.HostName | Should -Be 'pode.foo.com'
            $endpoint.Address.ToString() | Should -Be '127.0.0.1'
        }

        It 'Add two endpoints to listen on, but one added as they are the same' {
            $PodeContext.Server = @{ Endpoints = @{}; EndpointsMap = @{}; 'Type' = $null }
            Add-PodeEndpoint -Address '127.0.0.1' -Port 80 -Protocol 'HTTP'
            Add-PodeEndpoint -Address '127.0.0.1' -Port 80 -Protocol 'HTTP'

            $PodeContext.Server.Types | Should -Be 'HTTP'
            $PodeContext.Server.Endpoints | Should -Not -Be $null
            $PodeContext.Server.Endpoints.Count | Should -Be 1

            $endpoint = @($PodeContext.Server.Endpoints.Values)[0]
            $endpoint.Port | Should -Be 80
            $endpoint.HostName | Should -Be ''
            $endpoint.Address.ToString() | Should -Be '127.0.0.1'
        }

        It 'Allows adding two endpoints of different types' {
            $PodeContext.Server = @{ Endpoints = @{}; EndpointsMap = @{}; 'Type' = $null }
            Add-PodeEndpoint -Address '127.0.0.1' -Port 80 -Protocol 'HTTP'
            Add-PodeEndpoint -Address 'pode.foo.com' -Port 80 -Protocol 'SMTP'
            $PodeContext.Server.Endpoints.Count | Should -Be 2
        }

        It 'Throws error when adding two endpoints with the same name' {
            $PodeContext.Server = @{ Endpoints = @{}; EndpointsMap = @{}; 'Type' = $null }
            Add-PodeEndpoint -Address '127.0.0.1' -Port 80 -Protocol 'HTTP' -Name 'Example'
            { Add-PodeEndpoint -Address 'pode.foo.com' -Port 80 -Protocol 'HTTP' -Name 'Example' } | Should -Throw -ExpectedMessage '*already been defined*'
        }

        It 'Add two endpoints to listen on, one of SMTP and one of SMTPS' {
            $PodeContext.Server = @{ Endpoints = @{}; EndpointsMap = @{}; 'Type' = $null }
            Add-PodeEndpoint -Address '127.0.0.1' -Port 25 -Protocol 'SMTP' -Name 'Smtp'
            Add-PodeEndpoint -Address 'pode.mail.com' -Port 465 -Protocol 'SMTPS' -Name 'Smtps'

            $PodeContext.Server.Types | Should -Be 'SMTP'
            $PodeContext.Server.Endpoints | Should -Not -Be $null
            $PodeContext.Server.Endpoints.Count | Should -Be 2

            $endpoint = $PodeContext.Server.Endpoints['Smtp']
            $endpoint.Port | Should -Be 25
            $endpoint.HostName | Should -Be ''
            $endpoint.Address.ToString() | Should -Be '127.0.0.1'

            $endpoint = $PodeContext.Server.Endpoints['Smtps']
            $endpoint.Port | Should -Be 465
            $endpoint.HostName | Should -Be 'pode.mail.com'
            $endpoint.Address.ToString() | Should -Be '127.0.0.1'
        }

        It 'Add two endpoints to listen on, one of TCP and one of TCPS' {
            $PodeContext.Server = @{ Endpoints = @{}; EndpointsMap = @{}; 'Type' = $null }
            Add-PodeEndpoint -Address '127.0.0.1' -Port 80 -Protocol 'TCP' -Name 'Tcp'
            Add-PodeEndpoint -Address 'pode.foo.com' -Port 443 -Protocol 'TCPS' -Name 'Tcps'

            $PodeContext.Server.Types | Should -Be 'TCP'
            $PodeContext.Server.Endpoints | Should -Not -Be $null
            $PodeContext.Server.Endpoints.Count | Should -Be 2

            $endpoint = $PodeContext.Server.Endpoints['Tcp']
            $endpoint.Port | Should -Be 80
            $endpoint.HostName | Should -Be ''
            $endpoint.Address.ToString() | Should -Be '127.0.0.1'

            $endpoint = $PodeContext.Server.Endpoints['Tcps']
            $endpoint.Port | Should -Be 443
            $endpoint.HostName | Should -Be 'pode.foo.com'
            $endpoint.Address.ToString() | Should -Be '127.0.0.1'
        }

        It 'Throws an error for not running as admin' {
            Mock Test-PodeIsAdminUser { return $false }
            $PodeContext.Server = @{ Endpoints = @{}; EndpointsMap = @{}; 'Type' = $null }
            { Add-PodeEndpoint -Address '127.0.0.2' -Protocol 'HTTP' } | Should -Throw -ExpectedMessage '*Must be running with admin*'
        }
    }
}

Describe 'Get-PodeEndpoint' {
    BeforeAll {
        Mock Test-PodeIPAddress { return $true }
        Mock Test-PodeIsAdminUser { return $true } }

    It 'Returns no Endpoints' {
        $PodeContext.Server = @{ Endpoints = @{}; EndpointsMap = @{}; Type = $null }
        $endpoints = Get-PodeEndpoint
        $endpoints.Length | Should -Be 0
    }

    It 'Returns all Endpoints' {
        $PodeContext.Server = @{ Endpoints = @{}; EndpointsMap = @{}; Type = $null }

        Add-PodeEndpoint -Address '127.0.0.1' -Port 80 -Protocol 'HTTP'
        Add-PodeEndpoint -Address 'pode.foo.com' -Port 80 -Protocol 'HTTP'
        Add-PodeEndpoint -Address 'pode.foo.com' -Port 8080 -Protocol 'HTTP'

        $endpoints = Get-PodeEndpoint
        $endpoints.Length | Should -Be 3
    }

    It 'Returns 3 endpoints by address - combination of ip/hostname' {
        $PodeContext.Server = @{ Endpoints = @{}; EndpointsMap = @{}; Type = $null }

        Add-PodeEndpoint -Address '127.0.0.1' -Port 80 -Protocol 'HTTP'
        Add-PodeEndpoint -Address 'pode.foo.com' -Port 80 -Protocol 'HTTP'
        Add-PodeEndpoint -Address 'pode.foo.com' -Port 8080 -Protocol 'HTTP'

        $endpoints = Get-PodeEndpoint -Address '127.0.0.1'
        $endpoints.Length | Should -Be 3
    }

    It 'Returns 2 endpoints by hostname, and 3 by ip' {
        $PodeContext.Server = @{ Endpoints = @{}; EndpointsMap = @{}; Type = $null }

        Add-PodeEndpoint -Address '127.0.0.1' -Port 80 -Protocol 'HTTP'
        Add-PodeEndpoint -Address 'pode.foo.com' -Port 80 -Protocol 'HTTP'
        Add-PodeEndpoint -Address 'pode.foo.com' -Port 8080 -Protocol 'HTTP'

        $endpoints = Get-PodeEndpoint -Hostname 'pode.foo.com'
        $endpoints.Length | Should -Be 2

        $endpoints = Get-PodeEndpoint -Address '127.0.0.1'
        $endpoints.Length | Should -Be 3
    }

    It 'Returns 2 endpoints by hostname - old' {
        $PodeContext.Server = @{ Endpoints = @{}; EndpointsMap = @{}; Type = $null }

        Add-PodeEndpoint -Address '127.0.0.1' -Port 80 -Protocol 'HTTP'
        Add-PodeEndpoint -Address 'pode.foo.com' -Port 80 -Protocol 'HTTP'
        Add-PodeEndpoint -Address 'pode.foo.com' -Port 8080 -Protocol 'HTTP'

        $endpoints = Get-PodeEndpoint -Address 'pode.foo.com'
        $endpoints.Length | Should -Be 2
    }

    It 'Returns 2 endpoints by port' {
        $PodeContext.Server = @{ Endpoints = @{}; EndpointsMap = @{}; Type = $null }

        Add-PodeEndpoint -Address '127.0.0.1' -Port 80 -Protocol 'HTTP'
        Add-PodeEndpoint -Address 'pode.foo.com' -Port 80 -Protocol 'HTTP'
        Add-PodeEndpoint -Address 'pode.foo.com' -Port 8080 -Protocol 'HTTP'

        $endpoints = Get-PodeEndpoint -Port 80
        $endpoints.Length | Should -Be 2
    }

    It 'Returns all endpoints by protocol' {
        $PodeContext.Server = @{ Endpoints = @{}; EndpointsMap = @{}; Type = $null }

        Add-PodeEndpoint -Address '127.0.0.1' -Port 80 -Protocol 'HTTP'
        Add-PodeEndpoint -Address 'pode.foo.com' -Port 80 -Protocol 'HTTP'
        Add-PodeEndpoint -Address 'pode.foo.com' -Port 8080 -Protocol 'HTTP'

        $endpoints = Get-PodeEndpoint -Protocol Http
        $endpoints.Length | Should -Be 3
    }

    It 'Returns 2 endpoints by name' {
        $PodeContext.Server = @{ Endpoints = @{}; EndpointsMap = @{}; Type = $null }

        Add-PodeEndpoint -Address '127.0.0.1' -Port 80 -Protocol 'HTTP' -Name 'Admin'
        Add-PodeEndpoint -Address 'pode.foo.com' -Port 80 -Protocol 'HTTP' -Name 'User'
        Add-PodeEndpoint -Address 'pode.foo.com' -Port 8080 -Protocol 'HTTP' -Name 'Dev'

        $endpoints = Get-PodeEndpoint -Name Admin, User
        $endpoints.Length | Should -Be 2
    }

    It 'Returns 1 endpoint using everything' {
        $PodeContext.Server = @{ Endpoints = @{}; EndpointsMap = @{}; Type = $null }

        Add-PodeEndpoint -Address '127.0.0.1' -Port 80 -Protocol 'HTTP' -Name 'Admin'
        Add-PodeEndpoint -Address 'pode.foo.com' -Port 80 -Protocol 'HTTP' -Name 'User'
        Add-PodeEndpoint -Address 'pode.foo.com' -Port 8080 -Protocol 'HTTP' -Name 'Dev'

        $endpoints = Get-PodeEndpoint -Hostname 'pode.foo.com' -Port 80 -Protocol Http -Name User
        $endpoints.Length | Should -Be 1
    }

    It 'Returns endpoint set using wildcard' {
        $PodeContext.Server = @{ Endpoints = @{}; EndpointsMap = @{}; Type = $null }

        Add-PodeEndpoint -Address '*' -Port 80 -Protocol 'HTTP'

        $endpoints = Get-PodeEndpoint -Address '*'
        $endpoints.Length | Should -Be 1
    }

    It 'Returns endpoint set using localhost' {
        $PodeContext.Server = @{ Endpoints = @{}; EndpointsMap = @{}; Type = $null }

        Add-PodeEndpoint -Address 'localhost' -Port 80 -Protocol 'HTTP'

        $endpoints = Get-PodeEndpoint -Address 'localhost'
        $endpoints.Length | Should -Be 1
    }
}

Describe 'Import-PodeModule' {
    Context 'Invalid parameters supplied' {
        It 'Throw null path parameter error' {
            { Import-PodeModule -Path $null } | Should -Throw -ExpectedMessage '*it is an empty string*'
        }

        It 'Throw empty path parameter error' {
            { Import-PodeModule -Path ([string]::Empty) } | Should -Throw -ExpectedMessage '*it is an empty string*'
        }

        It 'Throw null name parameter error' {
            { Import-PodeModule -Name $null } | Should -Throw -ExpectedMessage '*it is an empty string*'
        }

        It 'Throw empty name parameter error' {
            { Import-PodeModule -Name ([string]::Empty) } | Should -Throw -ExpectedMessage '*it is an empty string*'
        }
    }

    Context 'Valid parameters supplied' {
        BeforeAll {
            Mock Resolve-Path { return @{ 'Path' = 'c:/some/file.txt' } }
            Mock Import-Module { }
            Mock Test-PodePath { return $true } }

        It 'Returns null for no shared state in context' {
            Import-PodeModule -Path 'file.txt'
            Assert-MockCalled Import-Module -Times 1 -Scope It
        }
    }
}

Describe 'New-PodeAutoRestartServer' {
    It 'Do not create any restart schedules' {
        Mock 'Get-PodeConfig' { return @{} }

        $PodeContext = @{ 'Timers' = @{ Items = @{} }; 'Schedules' = @{ Items = @{} }; }
        New-PodeAutoRestartServer

        $PodeContext.Timers.Items.Count | Should -Be 0
        $PodeContext.Schedules.Items.Count | Should -Be 0
    }

    It 'Creates a timer for a period server restart' {
        Mock 'Get-PodeConfig' { return @{
                'server' = @{
                    'restart' = @{
                        'period' = 180
                    }
                }
            } }

        $PodeContext = @{ 'Timers' = @{ Items = @{} }; 'Schedules' = @{ Items = @{} }; }
        New-PodeAutoRestartServer

        $PodeContext.Timers.Items.Count | Should -Be 1
        $PodeContext.Schedules.Items.Count | Should -Be 0
        $PodeContext.Timers.Items.Keys[0] | Should -Be '__pode_restart_period__'
    }

    It 'Creates a schedule for a timed server restart' {
        Mock 'Get-PodeConfig' { return @{
                'server' = @{
                    'restart' = @{
                        'times' = @('18:00')
                    }
                }
            } }

        $PodeContext = @{ 'Timers' = @{ Items = @{} }; 'Schedules' = @{ Items = @{} }; }
        New-PodeAutoRestartServer

        $PodeContext.Timers.Items.Count | Should -Be 0
        $PodeContext.Schedules.Items.Count | Should -Be 1
        $PodeContext.Schedules.Items.Keys[0] | Should -Be '__pode_restart_times__'
    }

    It 'Creates a schedule for a cron server restart' {
        Mock 'Get-PodeConfig' { return @{
                'server' = @{
                    'restart' = @{
                        'crons' = @('@minutely')
                    }
                }
            } }

        $PodeContext = @{ 'Timers' = @{ Items = @{} }; 'Schedules' = @{ Items = @{} }; }
        New-PodeAutoRestartServer

        $PodeContext.Timers.Items.Count | Should -Be 0
        $PodeContext.Schedules.Items.Count | Should -Be 1
        $PodeContext.Schedules.Items.Keys[0] | Should -Be '__pode_restart_crons__'
    }

    It 'Creates a timer and schedule for a period and cron server restart' {
        Mock 'Get-PodeConfig' { return @{
                'server' = @{
                    'restart' = @{
                        'period' = 180
                        'crons'  = @('@minutely')
                    }
                }
            } }

        $PodeContext = @{ 'Timers' = @{ Items = @{} }; 'Schedules' = @{ Items = @{} }; }
        New-PodeAutoRestartServer

        $PodeContext.Timers.Items.Count | Should -Be 1
        $PodeContext.Schedules.Items.Count | Should -Be 1
        $PodeContext.Timers.Items.Keys[0] | Should -Be '__pode_restart_period__'
        $PodeContext.Schedules.Items.Keys[0] | Should -Be '__pode_restart_crons__'
    }

    It 'Creates a timer and schedule for a period and timed server restart' {
        Mock 'Get-PodeConfig' { return @{
                'server' = @{
                    'restart' = @{
                        'period' = 180
                        'times'  = @('18:00')
                    }
                }
            } }

        $PodeContext = @{ 'Timers' = @{ Items = @{} }; 'Schedules' = @{ Items = @{} }; }
        New-PodeAutoRestartServer

        $PodeContext.Timers.Items.Count | Should -Be 1
        $PodeContext.Schedules.Items.Count | Should -Be 1
        $PodeContext.Timers.Items.Keys[0] | Should -Be '__pode_restart_period__'
        $PodeContext.Schedules.Items.Keys[0] | Should -Be '__pode_restart_times__'
    }

    It 'Creates two schedules for a cron and timed server restart' {
        Mock 'Get-PodeConfig' { return @{
                'server' = @{
                    'restart' = @{
                        'crons' = @('@minutely')
                        'times' = @('18:00')
                    }
                }
            } }

        $PodeContext = @{ 'Timers' = @{ Items = @{} }; 'Schedules' = @{ Items = @{} }; }
        New-PodeAutoRestartServer

        $PodeContext.Timers.Items.Count | Should -Be 0
        $PodeContext.Schedules.Items.Count | Should -Be 2
    }
}