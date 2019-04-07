$path = $MyInvocation.MyCommand.Path
$src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit[\\/]', '/src/'
Get-ChildItem "$($src)/*.ps1" | Resolve-Path | ForEach-Object { . $_ }

$PodeContext = @{ 'Server' = $null; }

Describe 'Test-PodeIPAccess' {
    Context 'Invalid parameters' {
        It 'Throws error for invalid IP' {
            { Test-PodeIPAccess -IP $null -Limit 1 -Seconds 1 } | Should Throw "argument is null"
        }
    }
}

Describe 'Test-PodeIPLimit' {
    Context 'Invalid parameters' {
        It 'Throws error for invalid IP' {
            { Test-PodeIPLimit -IP $null -Limit 1 -Seconds 1 } | Should Throw "argument is null"
        }
    }
}

Describe 'Limit' {
    Mock Add-PodeIPLimit { }

    Context 'Invalid parameters' {
        It 'Throws error for invalid Type' {
            { Limit -Type 'MOO' -Value 'test' -Limit 1 -Seconds 1 } | Should Throw "Cannot validate argument on parameter 'Type'"
        }

        It 'Throws error for invalid Value' {
            { Limit -Type 'IP' -Value $null -Limit 1 -Seconds 1 } | Should Throw "argument is null"
        }
    }

    Context 'Valid parameters' {
        It 'Adds single IP address' {
            Limit -Type 'IP' -Value '127.0.0.1' -Limit 1 -Seconds 1
            Assert-MockCalled Add-PodeIPLimit -Times 1 -Scope It
        }

        It 'Adds single subnet' {
            Limit -Type 'IP' -Value '10.10.0.0/24' -Limit 1 -Seconds 1
            Assert-MockCalled Add-PodeIPLimit -Times 1 -Scope It
        }

        It 'Adds 3 IP addresses' {
            Limit -Type 'IP' -Value @('127.0.0.1', '127.0.0.2', '127.0.0.3') -Limit 1 -Seconds 1
            Assert-MockCalled Add-PodeIPLimit -Times 3 -Scope It
        }

        It 'Adds 3 subnets' {
            Limit -Type 'IP' -Value @('10.10.0.0/24', '10.10.1.0/24', '10.10.2.0/24') -Limit 1 -Seconds 1
            Assert-MockCalled Add-PodeIPLimit -Times 3 -Scope It
        }
    }
}

Describe 'Access' {
    Mock Add-PodeIPAccess { }

    Context 'Invalid parameters' {
        It 'Throws error for invalid Permission' {
            { Access -Permission 'MOO' -Type 'IP' -Value 'test' } | Should Throw "Cannot validate argument on parameter 'Permission'"
        }

        It 'Throws error for invalid Type' {
            { Access -Permission 'Allow' -Type 'MOO' -Value 'test' } | Should Throw "Cannot validate argument on parameter 'Type'"
        }

        It 'Throws error for invalid Value' {
            { Access -Permission 'Allow' -Type 'IP' -Value $null } | Should Throw "argument is null"
        }
    }

    Context 'Valid parameters' {
        It 'Adds single IP address' {
            Access -Permission 'Allow' -Type 'IP' -Value '127.0.0.1'
            Assert-MockCalled Add-PodeIPAccess -Times 1 -Scope It
        }

        It 'Adds single subnet' {
            Access -Permission 'Allow' -Type 'IP' -Value '10.10.0.0/24'
            Assert-MockCalled Add-PodeIPAccess -Times 1 -Scope It
        }

        It 'Adds 3 IP addresses' {
            Access -Permission 'Allow' -Type 'IP' -Value @('127.0.0.1', '127.0.0.2', '127.0.0.3')
            Assert-MockCalled Add-PodeIPAccess -Times 3 -Scope It
        }

        It 'Adds 3 subnets' {
            Access -Permission 'Allow' -Type 'IP' -Value @('10.10.0.0/24', '10.10.1.0/24', '10.10.2.0/24')
            Assert-MockCalled Add-PodeIPAccess -Times 3 -Scope It
        }
    }
}

Describe 'Add-PodeIPLimit' {
    Context 'Invalid parameters' {
        It 'Throws error for invalid IP' {
            { Add-PodeIPLimit -IP $null -Limit 1 -Seconds 1 } | Should Throw "because it is an empty string"
        }

        It 'Throws error for negative limit' {
            { Add-PodeIPLimit -IP '127.0.0.1' -Limit -1 -Seconds 1 } | Should Throw '0 or less'
        }

        It 'Throws error for negative seconds' {
            { Add-PodeIPLimit -IP '127.0.0.1' -Limit 1 -Seconds -1 } | Should Throw '0 or less'
        }

        It 'Throws error for zero limit' {
            { Add-PodeIPLimit -IP '127.0.0.1' -Limit 0 -Seconds 1 } | Should Throw '0 or less'
        }

        It 'Throws error for zero seconds' {
            { Add-PodeIPLimit -IP '127.0.0.1' -Limit 1 -Seconds 0 } | Should Throw '0 or less'
        }
    }

    Context 'Valid parameters' {
        It 'Adds an IP to limit' {
            $PodeContext.Server = @{ 'Limits' = @{ 'Rules' = @{}; 'Active' = @{}; } }
            Add-PodeIPLimit -IP '127.0.0.1' -Limit 1 -Seconds 1

            $a = $PodeContext.Server.Limits.Rules.IP
            $a | Should Not Be $null
            $a.Count | Should Be 1
            $a.ContainsKey('127.0.0.1') | Should Be $true

            $k = $a['127.0.0.1']
            $k.Limit | Should Be 1
            $k.Seconds | Should Be 1

            $k.Lower | Should Not Be $null
            $k.Lower.Family | Should Be 'InterNetwork'
            $k.Lower.Bytes | Should Be @(127, 0, 0, 1)

            $k.Upper | Should Not Be $null
            $k.Upper.Family | Should Be 'InterNetwork'
            $k.Upper.Bytes | Should Be @(127, 0, 0, 1)
        }

        It 'Adds any IP to limit' {
            $PodeContext.Server = @{ 'Limits' = @{ 'Rules' = @{}; 'Active' = @{}; } }
            Add-PodeIPLimit -IP 'all' -Limit 1 -Seconds 1

            $a = $PodeContext.Server.Limits.Rules.IP
            $a | Should Not Be $null
            $a.Count | Should Be 1
            $a.ContainsKey('all') | Should Be $true

            $k = $a['all']
            $k.Limit | Should Be 1
            $k.Seconds | Should Be 1

            $k.Lower | Should Not Be $null
            $k.Lower.Family | Should Be 'InterNetwork'
            $k.Lower.Bytes | Should Be @(0, 0, 0, 0)

            $k.Upper | Should Not Be $null
            $k.Upper.Family | Should Be 'InterNetwork'
            $k.Upper.Bytes | Should Be @(255, 255, 255, 255)
        }

        It 'Adds a subnet mask to limit' {
            $PodeContext.Server = @{ 'Limits' = @{ 'Rules' = @{}; 'Active' = @{}; } }
            Add-PodeIPLimit -IP '10.10.0.0/24' -Limit 1 -Seconds 1

            $a = $PodeContext.Server.Limits.Rules.IP
            $a | Should Not Be $null
            $a.Count | Should Be 1
            $a.ContainsKey('10.10.0.0/24') | Should Be $true

            $k = $a['10.10.0.0/24']
            $k.Limit | Should Be 1
            $k.Seconds | Should Be 1
            $k.Grouped | Should Be $false

            $k.Lower | Should Not Be $null
            $k.Lower.Family | Should Be 'InterNetwork'
            $k.Lower.Bytes | Should Be @(10, 10, 0, 0)

            $k.Upper | Should Not Be $null
            $k.Upper.Family | Should Be 'InterNetwork'
            $k.Upper.Bytes | Should Be @(10, 10, 0, 255)
        }

        It 'Adds a grouped subnet mask to limit' {
            $PodeContext.Server = @{ 'Limits' = @{ 'Rules' = @{}; 'Active' = @{}; } }
            Add-PodeIPLimit -IP '10.10.0.0/24' -Limit 1 -Seconds 1 -Group

            $a = $PodeContext.Server.Limits.Rules.IP
            $a | Should Not Be $null
            $a.Count | Should Be 1
            $a.ContainsKey('10.10.0.0/24') | Should Be $true

            $k = $a['10.10.0.0/24']
            $k.Limit | Should Be 1
            $k.Seconds | Should Be 1
            $k.Grouped | Should Be $true

            $k.Lower | Should Not Be $null
            $k.Lower.Family | Should Be 'InterNetwork'
            $k.Lower.Bytes | Should Be @(10, 10, 0, 0)

            $k.Upper | Should Not Be $null
            $k.Upper.Family | Should Be 'InterNetwork'
            $k.Upper.Bytes | Should Be @(10, 10, 0, 255)
        }

        It 'Throws error for invalid IP' {
            $PodeContext.Server = @{ 'Limits' = @{ 'Rules' = @{}; 'Active' = @{}; } }
            { Add-PodeIPLimit -IP '256.0.0.0' -Limit 1 -Seconds 1 } | Should Throw 'invalid ip address'
        }
    }
}

Describe 'Add-PodeIPAccess' {
    Context 'Invalid parameters' {
        It 'Throws error for invalid Permission' {
            { Add-PodeIPAccess -Permission 'MOO' -IP 'test' } | Should Throw "Cannot validate argument on parameter 'Permission'"
        }

        It 'Throws error for invalid IP' {
            { Add-PodeIPAccess -Permission 'Allow' -IP $null } | Should Throw "because it is an empty string"
        }
    }

    Context 'Valid parameters' {
        It 'Adds an IP to allow' {
            $PodeContext.Server = @{ 'Access' = @{ 'Allow' = @{}; 'Deny' = @{}; } }
            Add-PodeIPAccess -Permission 'Allow' -IP '127.0.0.1'

            $a = $PodeContext.Server.Access.Allow.IP
            $a | Should Not Be $null
            $a.Count | Should Be 1
            $a.ContainsKey('127.0.0.1') | Should Be $true

            $k = $a['127.0.0.1']
            $k.Lower | Should Not Be $null
            $k.Lower.Family | Should Be 'InterNetwork'
            $k.Lower.Bytes | Should Be @(127, 0, 0, 1)

            $k.Upper | Should Not Be $null
            $k.Upper.Family | Should Be 'InterNetwork'
            $k.Upper.Bytes | Should Be @(127, 0, 0, 1)
        }

        It 'Adds any IP to allow' {
            $PodeContext.Server = @{ 'Access' = @{ 'Allow' = @{}; 'Deny' = @{}; } }
            Add-PodeIPAccess -Permission 'Allow' -IP 'all'

            $a = $PodeContext.Server.Access.Allow.IP
            $a | Should Not Be $null
            $a.Count | Should Be 1
            $a.ContainsKey('all') | Should Be $true

            $k = $a['all']
            $k.Lower | Should Not Be $null
            $k.Lower.Family | Should Be 'InterNetwork'
            $k.Lower.Bytes | Should Be @(0, 0, 0, 0)

            $k.Upper | Should Not Be $null
            $k.Upper.Family | Should Be 'InterNetwork'
            $k.Upper.Bytes | Should Be @(255, 255, 255, 255)
        }

        It 'Adds a subnet mask to allow' {
            $PodeContext.Server = @{ 'Access' = @{ 'Allow' = @{}; 'Deny' = @{}; } }
            Add-PodeIPAccess -Permission 'Allow' -IP '10.10.0.0/24'

            $a = $PodeContext.Server.Access.Allow.IP
            $a | Should Not Be $null
            $a.Count | Should Be 1
            $a.ContainsKey('10.10.0.0/24') | Should Be $true

            $k = $a['10.10.0.0/24']
            $k.Lower | Should Not Be $null
            $k.Lower.Family | Should Be 'InterNetwork'
            $k.Lower.Bytes | Should Be @(10, 10, 0, 0)

            $k.Upper | Should Not Be $null
            $k.Upper.Family | Should Be 'InterNetwork'
            $k.Upper.Bytes | Should Be @(10, 10, 0, 255)
        }

        It 'Adds an IP to deny' {
            $PodeContext.Server = @{ 'Access' = @{ 'Allow' = @{}; 'Deny' = @{}; } }
            Add-PodeIPAccess -Permission 'Deny' -IP '127.0.0.1'

            $a = $PodeContext.Server.Access.Deny.IP
            $a | Should Not Be $null
            $a.Count | Should Be 1
            $a.ContainsKey('127.0.0.1') | Should Be $true

            $k = $a['127.0.0.1']
            $k.Lower | Should Not Be $null
            $k.Lower.Family | Should Be 'InterNetwork'
            $k.Lower.Bytes | Should Be @(127, 0, 0, 1)

            $k.Upper | Should Not Be $null
            $k.Upper.Family | Should Be 'InterNetwork'
            $k.Upper.Bytes | Should Be @(127, 0, 0, 1)
        }

        It 'Adds any IP to deny' {
            $PodeContext.Server = @{ 'Access' = @{ 'Allow' = @{}; 'Deny' = @{}; } }
            Add-PodeIPAccess -Permission 'Deny' -IP 'all'

            $a = $PodeContext.Server.Access.Deny.IP
            $a | Should Not Be $null
            $a.Count | Should Be 1
            $a.ContainsKey('all') | Should Be $true

            $k = $a['all']
            $k.Lower | Should Not Be $null
            $k.Lower.Family | Should Be 'InterNetwork'
            $k.Lower.Bytes | Should Be @(0, 0, 0, 0)

            $k.Upper | Should Not Be $null
            $k.Upper.Family | Should Be 'InterNetwork'
            $k.Upper.Bytes | Should Be @(255, 255, 255, 255)
        }

        It 'Adds a subnet mask to deny' {
            $PodeContext.Server = @{ 'Access' = @{ 'Allow' = @{}; 'Deny' = @{}; } }
            Add-PodeIPAccess -Permission 'Deny' -IP '10.10.0.0/24'

            $a = $PodeContext.Server.Access.Deny.IP
            $a | Should Not Be $null
            $a.Count | Should Be 1
            $a.ContainsKey('10.10.0.0/24') | Should Be $true

            $k = $a['10.10.0.0/24']
            $k.Lower | Should Not Be $null
            $k.Lower.Family | Should Be 'InterNetwork'
            $k.Lower.Bytes | Should Be @(10, 10, 0, 0)

            $k.Upper | Should Not Be $null
            $k.Upper.Family | Should Be 'InterNetwork'
            $k.Upper.Bytes | Should Be @(10, 10, 0, 255)
        }

        It 'Adds an IP to allow and removes one from deny' {
            $PodeContext.Server = @{ 'Access' = @{ 'Allow' = @{}; 'Deny' = @{}; } }

            # add to deny first
            Add-PodeIPAccess -Permission 'Deny' -IP '127.0.0.1'

            $a = $PodeContext.Server.Access.Deny.IP
            $a | Should Not Be $null
            $a.Count | Should Be 1
            $a.ContainsKey('127.0.0.1') | Should Be $true

            # add to allow, deny should be removed
            Add-PodeIPAccess -Permission 'Allow' -IP '127.0.0.1'

            # check allow
            $a = $PodeContext.Server.Access.Allow.IP
            $a | Should Not Be $null
            $a.Count | Should Be 1
            $a.ContainsKey('127.0.0.1') | Should Be $true

            $k = $a['127.0.0.1']
            $k.Lower | Should Not Be $null
            $k.Lower.Family | Should Be 'InterNetwork'
            $k.Lower.Bytes | Should Be @(127, 0, 0, 1)

            $k.Upper | Should Not Be $null
            $k.Upper.Family | Should Be 'InterNetwork'
            $k.Upper.Bytes | Should Be @(127, 0, 0, 1)

            # check deny
            $a = $PodeContext.Server.Access.Deny.IP
            $a | Should Not Be $null
            $a.Count | Should Be 0
            $a.ContainsKey('127.0.0.1') | Should Be $false
        }

        It 'Adds an IP to deny and removes one from allow' {
            $PodeContext.Server = @{ 'Access' = @{ 'Allow' = @{}; 'Deny' = @{}; } }

            # add to allow first
            Add-PodeIPAccess -Permission 'Allow' -IP '127.0.0.1'

            $a = $PodeContext.Server.Access.Allow.IP
            $a | Should Not Be $null
            $a.Count | Should Be 1
            $a.ContainsKey('127.0.0.1') | Should Be $true

            # add to deny, allow should be removed
            Add-PodeIPAccess -Permission 'Deny' -IP '127.0.0.1'

            # check deny
            $a = $PodeContext.Server.Access.Deny.IP
            $a | Should Not Be $null
            $a.Count | Should Be 1
            $a.ContainsKey('127.0.0.1') | Should Be $true

            $k = $a['127.0.0.1']
            $k.Lower | Should Not Be $null
            $k.Lower.Family | Should Be 'InterNetwork'
            $k.Lower.Bytes | Should Be @(127, 0, 0, 1)

            $k.Upper | Should Not Be $null
            $k.Upper.Family | Should Be 'InterNetwork'
            $k.Upper.Bytes | Should Be @(127, 0, 0, 1)

            # check allow
            $a = $PodeContext.Server.Access.Allow.IP
            $a | Should Not Be $null
            $a.Count | Should Be 0
            $a.ContainsKey('127.0.0.1') | Should Be $false
        }

        It 'Throws error for invalid IP' {
            $PodeContext.Server = @{ 'Access' = @{ 'Allow' = @{}; 'Deny' = @{}; } }
            { Add-PodeIPAccess -Permission 'Allow' -IP '256.0.0.0' } | Should Throw 'invalid ip address'
        }
    }
}

Describe 'Csrf' {
    It 'Returs middleware' {
        Mock Get-PodeCsrfMiddleware { return { write-host 'hello' } }
        (Csrf -Action Middleware).ToString() | Should Be ({ write-host 'hello' }).ToString()
    }

    It 'Returs a token' {
        Mock New-PodeCsrfToken { return 'token' }
        Csrf -Action Token | Should Be 'token'
    }
}

Describe 'Get-PodeCsrfToken' {
    It 'Returns the token from the payload' {
        $PodeContext = @{ 'Server' = @{ 'Cookies' = @{
            'Csrf' = @{ 'Name' = 'Key' }
        }}}

        $WebEvent = @{ 'Data' = @{
            'Key' = 'Token'
        }}

        Get-PodeCsrfToken | Should Be 'Token'
    }

    It 'Returns the token from the query string' {
        $PodeContext = @{ 'Server' = @{ 'Cookies' = @{
            'Csrf' = @{ 'Name' = 'Key' }
        }}}

        $WebEvent = @{
            'Data' = @{};
            'Query' = @{ 'Key' = 'Token' };
        }

        Get-PodeCsrfToken | Should Be 'Token'
    }

    It 'Returns the token from the headers' {
        $PodeContext = @{ 'Server' = @{ 'Cookies' = @{
            'Csrf' = @{ 'Name' = 'Key' }
        }}}

        $WebEvent = @{
            'Data' = @{};
            'Query' = @{};
            'Request' = @{ 'Headers' = @{ 'Key' = 'Token' } }
        }

        Get-PodeCsrfToken | Should Be 'Token'
    }

    It 'Returns no token' {
        $PodeContext = @{ 'Server' = @{ 'Cookies' = @{
            'Csrf' = @{ 'Name' = 'Key' }
        }}}

        $WebEvent = @{
            'Data' = @{};
            'Query' = @{};
            'Request' = @{ 'Headers' = @{} }
        }

        Get-PodeCsrfToken | Should Be $null
    }
}