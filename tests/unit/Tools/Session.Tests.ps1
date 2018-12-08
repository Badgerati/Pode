$path = $MyInvocation.MyCommand.Path
$src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit[\\/]', '/src/'
Get-ChildItem "$($src)/*.ps1" | Resolve-Path | ForEach-Object { . $_ }

$PodeSession = @{ 'Server' = $null; }

Describe 'State' {
    Context 'Invalid parameters supplied' {
        It 'Throw null name parameter error' {
            { State -Action Set -Name $null } | Should Throw 'The argument is null or empty'
        }

        It 'Throw empty name parameter error' {
            { State -Action Set -Name ([string]::Empty) } | Should Throw 'The argument is null or empty'
        }

        It 'Throw invalid action error' {
            { State -Action 'MOO' -Name 'test' } | Should Throw "Cannot validate argument on parameter 'Action'"
        }
    }

    Context 'Valid parameters supplied' {
        It 'Returns null for no session' {
            State -Action Set -Name 'test' | Should Be $null
        }

        It 'Returns null for no shared state in session' {
            $PodeSession.Server = @{ 'State' = $null }
            State -Action Set -Name 'test' | Should Be $null
        }

        It 'Sets and returns an object' {
            $PodeSession.Server = @{ 'State' = @{} }
            $result = State -Action Set -Name 'test' -Object 7

            $result | Should Be 7
            $PodeSession.Server.State['test'] | Should Be 7
        }

        It 'Gets an object' {
            $PodeSession.Server = @{ 'State' = @{ 'test' = 8 } }
            State -Action Get -Name 'test' | Should Be 8
        }

        It 'Removes an object' {
            $PodeSession.Server = @{ 'State' = @{ 'test' = 8 } }
            State -Action Remove -Name 'test' | Should Be 8
            $PodeSession.Server.State['test'] | Should Be $null
        }
    }
}

Describe 'Listen' {
    Context 'Invalid parameters supplied' {
        It 'Throw null IP:Port parameter error' {
            { Listen -IPPort $null -Type 'HTTP' } | Should Throw 'The argument is null or empty'
        }

        It 'Throw empty IP:Port parameter error' {
            { Listen -IPPort ([string]::Empty) -Type 'HTTP' } | Should Throw 'The argument is null or empty'
        }

        It 'Throw invalid type error for no method' {
            { Listen -IPPort '127.0.0.1' -Type 'MOO' } | Should Throw "Cannot validate argument on parameter 'Type'"
        }
    }

    Context 'Valid parameters supplied' {
        Mock Test-IPAddress { return $true }
        Mock Test-IsAdminUser { return $true }

        It 'Set just a Hostname address' {
            $PodeSession.Server = @{ 'IP' = @{ 'Address' = $null; 'Name' = 'localhost'; 'Port' = 0; }; 'Type' = $null }
            Listen -IP 'foo.com' -Type 'HTTP'

            $PodeSession.Server.Type | Should Be 'HTTP'
            $PodeSession.Server.IP | Should Not Be $null
            $PodeSession.Server.IP.Port | Should Be 0
            $PodeSession.Server.IP.Name | Should Be 'foo.com'
            $PodeSession.Server.IP.Address.ToString() | Should Be 'foo.com'
        }

        It 'Set just a Hostname address with colon' {
            $PodeSession.Server = @{ 'IP' = @{ 'Address' = $null; 'Name' = 'localhost'; 'Port' = 0; }; 'Type' = $null }
            Listen -IP 'foo.com:' -Type 'HTTP'

            $PodeSession.Server.Type | Should Be 'HTTP'
            $PodeSession.Server.IP | Should Not Be $null
            $PodeSession.Server.IP.Port | Should Be 0
            $PodeSession.Server.IP.Name | Should Be 'foo.com'
            $PodeSession.Server.IP.Address.ToString() | Should Be 'foo.com'
        }

        It 'Set both the Hostname address and port' {
            $PodeSession.Server = @{ 'IP' = @{ 'Address' = $null; 'Name' = 'localhost'; 'Port' = 0; }; 'Type' = $null }
            Listen -IP 'foo.com:80' -Type 'HTTP'

            $PodeSession.Server.Type | Should Be 'HTTP'
            $PodeSession.Server.IP | Should Not Be $null
            $PodeSession.Server.IP.Port | Should Be 80
            $PodeSession.Server.IP.Name | Should Be 'foo.com'
            $PodeSession.Server.IP.Address.ToString() | Should Be 'foo.com'
        }

        It 'Set just an IPv4 address' {
            $PodeSession.Server = @{ 'IP' = @{ 'Address' = $null; 'Name' = 'localhost'; 'Port' = 0; }; 'Type' = $null }
            Listen -IP '127.0.0.1' -Type 'HTTP'

            $PodeSession.Server.Type | Should Be 'HTTP'
            $PodeSession.Server.IP | Should Not Be $null
            $PodeSession.Server.IP.Port | Should Be 0
            $PodeSession.Server.IP.Name | Should Be 'localhost'
            $PodeSession.Server.IP.Address.ToString() | Should Be '127.0.0.1'
        }

        It 'Set just an IPv4 address for all' {
            $PodeSession.Server = @{ 'IP' = @{ 'Address' = $null; 'Name' = 'localhost'; 'Port' = 0; }; 'Type' = $null }
            Listen -IP 'all' -Type 'HTTP'

            $PodeSession.Server.Type | Should Be 'HTTP'
            $PodeSession.Server.IP | Should Not Be $null
            $PodeSession.Server.IP.Port | Should Be 0
            $PodeSession.Server.IP.Name | Should Be 'localhost'
            $PodeSession.Server.IP.Address.ToString() | Should Be '0.0.0.0'
        }

        It 'Set just an IPv4 address with colon' {
            $PodeSession.Server = @{ 'IP' = @{ 'Address' = $null; 'Name' = 'localhost'; 'Port' = 0; }; 'Type' = $null }
            Listen -IP '127.0.0.1:' -Type 'HTTP'

            $PodeSession.Server.Type | Should Be 'HTTP'
            $PodeSession.Server.IP | Should Not Be $null
            $PodeSession.Server.IP.Port | Should Be 0
            $PodeSession.Server.IP.Name | Should Be 'localhost'
            $PodeSession.Server.IP.Address.ToString() | Should Be '127.0.0.1'
        }

        It 'Set just a port' {
            $PodeSession.Server = @{ 'IP' = @{ 'Address' = $null; 'Name' = 'localhost'; 'Port' = 0; }; 'Type' = $null }
            Listen -IP '80' -Type 'HTTP'

            $PodeSession.Server.Type | Should Be 'HTTP'
            $PodeSession.Server.IP | Should Not Be $null
            $PodeSession.Server.IP.Port | Should Be 80
            $PodeSession.Server.IP.Name | Should Be 'localhost'
            $PodeSession.Server.IP.Address.ToString() | Should Be '0.0.0.0'
        }

        It 'Set just a port with colon' {
            $PodeSession.Server = @{ 'IP' = @{ 'Address' = $null; 'Name' = 'localhost'; 'Port' = 0; }; 'Type' = $null }
            Listen -IP ':80' -Type 'HTTP'

            $PodeSession.Server.Type | Should Be 'HTTP'
            $PodeSession.Server.IP | Should Not Be $null
            $PodeSession.Server.IP.Port | Should Be 80
            $PodeSession.Server.IP.Name | Should Be 'localhost'
            $PodeSession.Server.IP.Address.ToString() | Should Be '0.0.0.0'
        }

        It 'Set both IPv4 address and port' {
            $PodeSession.Server = @{ 'IP' = @{ 'Address' = $null; 'Name' = 'localhost'; 'Port' = 0; }; 'Type' = $null }
            Listen -IP '127.0.0.1:80' -Type 'HTTP'

            $PodeSession.Server.Type | Should Be 'HTTP'
            $PodeSession.Server.IP | Should Not Be $null
            $PodeSession.Server.IP.Port | Should Be 80
            $PodeSession.Server.IP.Name | Should Be 'localhost'
            $PodeSession.Server.IP.Address.ToString() | Should Be '127.0.0.1'
        }

        It 'Set both IPv4 address and port for all' {
            $PodeSession.Server = @{ 'IP' = @{ 'Address' = $null; 'Name' = 'localhost'; 'Port' = 0; }; 'Type' = $null }
            Listen -IP '*:80' -Type 'HTTP'

            $PodeSession.Server.Type | Should Be 'HTTP'
            $PodeSession.Server.IP | Should Not Be $null
            $PodeSession.Server.IP.Port | Should Be 80
            $PodeSession.Server.IP.Name | Should Be 'localhost'
            $PodeSession.Server.IP.Address.ToString() | Should Be '0.0.0.0'
        }

        It 'Throws error for just an invalid IPv4' {
            $PodeSession.Server = @{ 'IP' = @{ 'Address' = $null; 'Name' = 'localhost'; 'Port' = 0; }; 'Type' = $null }
            { Listen -IP '256.0.0.1' -Type 'HTTP' } | Should Throw 'Invalid IP Address'

            $PodeSession.Server.Type | Should Be $null
            $PodeSession.Server.IP | Should Not Be $null
            $PodeSession.Server.IP.Port | Should Be 0
            $PodeSession.Server.IP.Name | Should Be 'localhost'
            $PodeSession.Server.IP.Address | Should Be $null
        }

        It 'Throws error for an invalid IPv4 address with port' {
            $PodeSession.Server = @{ 'IP' = @{ 'Address' = $null; 'Name' = 'localhost'; 'Port' = 0; }; 'Type' = $null }
            { Listen -IP '256.0.0.1:80' -Type 'HTTP' } | Should Throw 'Invalid IP Address'

            $PodeSession.Server.Type | Should Be $null
            $PodeSession.Server.IP | Should Not Be $null
            $PodeSession.Server.IP.Port | Should Be 0
            $PodeSession.Server.IP.Name | Should Be 'localhost'
            $PodeSession.Server.IP.Address | Should Be $null
        }
    }
}

Describe 'Script' {
    Context 'Invalid parameters supplied' {
        It 'Throw null path parameter error' {
            { Script -Path $null } | Should Throw 'The argument is null or empty'
        }

        It 'Throw empty path parameter error' {
            { Script -Path ([string]::Empty) } | Should Throw 'The argument is null or empty'
        }
    }

    Context 'Valid parameters supplied' {
        Mock 'Resolve-Path' { return 'c:/some/file.txt' }

        It 'Returns null for no shared state in session' {
            $PodeSession = @{ 'RunspacePools' = @{
                'Main' = @{
                    'InitialSessionState' = [initialsessionstate]::CreateDefault()
                }
            } }

            Script -Path 'file.txt'

            $modules = @($PodeSession.RunspacePools.Main.InitialSessionState.Modules)
            $modules.Length | Should Be 1
            $modules[0].Name | Should Be 'c:/some/file.txt'
        }
    }
}