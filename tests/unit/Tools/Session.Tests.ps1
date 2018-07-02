$path = $MyInvocation.MyCommand.Path
$src = (Split-Path -Parent -Path $path) -ireplace '\\tests\\unit\\', '\src\'
Get-ChildItem "$($src)\*.ps1" | Resolve-Path | ForEach-Object { . $_ }

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
        Mock Test-IPAddressLocal { return $true }

        It 'Set just an IPv4 address' {
            $PodeSession = @{ 'IP' = @{ 'Address' = $null; 'Name' = 'localhost'; 'Port' = 0; }; 'ServerType' = $null }
            Listen -IP '127.0.0.1' -Type 'HTTP'

            $PodeSession.ServerType | Should Be 'HTTP'
            $PodeSession.IP | Should Not Be $null
            $PodeSession.IP.Port | Should Be 0
            $PodeSession.IP.Name | Should Be 'localhost'
            $PodeSession.IP.Address.ToString() | Should Be '127.0.0.1'
        }

        It 'Set just an IPv4 address with colon' {
            $PodeSession = @{ 'IP' = @{ 'Address' = $null; 'Name' = 'localhost'; 'Port' = 0; }; 'ServerType' = $null }
            Listen -IP '127.0.0.1:' -Type 'HTTP'

            $PodeSession.ServerType | Should Be 'HTTP'
            $PodeSession.IP | Should Not Be $null
            $PodeSession.IP.Port | Should Be 0
            $PodeSession.IP.Name | Should Be 'localhost'
            $PodeSession.IP.Address.ToString() | Should Be '127.0.0.1'
        }

        It 'Set just a port' {
            $PodeSession = @{ 'IP' = @{ 'Address' = $null; 'Name' = 'localhost'; 'Port' = 0; }; 'ServerType' = $null }
            Listen -IP '80' -Type 'HTTP'

            $PodeSession.ServerType | Should Be 'HTTP'
            $PodeSession.IP | Should Not Be $null
            $PodeSession.IP.Port | Should Be 80
            $PodeSession.IP.Name | Should Be 'localhost'
            $PodeSession.IP.Address.ToString() | Should Be '0.0.0.0'
        }

        It 'Set just a port with colon' {
            $PodeSession = @{ 'IP' = @{ 'Address' = $null; 'Name' = 'localhost'; 'Port' = 0; }; 'ServerType' = $null }
            Listen -IP ':80' -Type 'HTTP'

            $PodeSession.ServerType | Should Be 'HTTP'
            $PodeSession.IP | Should Not Be $null
            $PodeSession.IP.Port | Should Be 80
            $PodeSession.IP.Name | Should Be 'localhost'
            $PodeSession.IP.Address.ToString() | Should Be '0.0.0.0'
        }

        It 'Set both IPv4 address and port' {
            $PodeSession = @{ 'IP' = @{ 'Address' = $null; 'Name' = 'localhost'; 'Port' = 0; }; 'ServerType' = $null }
            Listen -IP '127.0.0.1:80' -Type 'HTTP'

            $PodeSession.ServerType | Should Be 'HTTP'
            $PodeSession.IP | Should Not Be $null
            $PodeSession.IP.Port | Should Be 80
            $PodeSession.IP.Name | Should Be 'localhost'
            $PodeSession.IP.Address.ToString() | Should Be '127.0.0.1'
        }

        It 'Throws error for just an invalid IPv4' {
            $PodeSession = @{ 'IP' = @{ 'Address' = $null; 'Name' = 'localhost'; 'Port' = 0; }; 'ServerType' = $null }
            { Listen -IP '256.0.0.1' -Type 'HTTP' } | Should Throw 'Invalid IP Address'

            $PodeSession.ServerType | Should Be $null
            $PodeSession.IP | Should Not Be $null
            $PodeSession.IP.Port | Should Be 0
            $PodeSession.IP.Name | Should Be 'localhost'
            $PodeSession.IP.Address | Should Be $null
        }

        It 'Throws error for an invalid IPv4 address with port' {
            $PodeSession = @{ 'IP' = @{ 'Address' = $null; 'Name' = 'localhost'; 'Port' = 0; }; 'ServerType' = $null }
            { Listen -IP '256.0.0.1:80' -Type 'HTTP' } | Should Throw 'Invalid IP Address'

            $PodeSession.ServerType | Should Be $null
            $PodeSession.IP | Should Not Be $null
            $PodeSession.IP.Port | Should Be 0
            $PodeSession.IP.Name | Should Be 'localhost'
            $PodeSession.IP.Address | Should Be $null
        }
    }
}