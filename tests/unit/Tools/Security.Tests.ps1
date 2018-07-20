$path = $MyInvocation.MyCommand.Path
$src = (Split-Path -Parent -Path $path) -ireplace '\\tests\\unit\\', '\src\'
Get-ChildItem "$($src)\*.ps1" | Resolve-Path | ForEach-Object { . $_ }

Describe 'Test-IPAccess' {
    Context 'Invalid parameters' {
        It 'Throws error for invalid IP' {
            { Test-IPAccess -IP $null -Limit 1 -Seconds 1 } | Should Throw "argument is null"
        }
    }
}

Describe 'Test-IPLimit' {
    Context 'Invalid parameters' {
        It 'Throws error for invalid IP' {
            { Test-IPLimit -IP $null -Limit 1 -Seconds 1 } | Should Throw "argument is null"
        }
    }
}

Describe 'Limit' {
    Mock Add-IPLimit { }

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
            Assert-MockCalled Add-IPLimit -Times 1 -Scope It
        }

        It 'Adds single subnet' {
            Limit -Type 'IP' -Value '10.10.0.0/24' -Limit 1 -Seconds 1
            Assert-MockCalled Add-IPLimit -Times 1 -Scope It
        }

        It 'Adds 3 IP addresses' {
            Limit -Type 'IP' -Value @('127.0.0.1', '127.0.0.2', '127.0.0.3') -Limit 1 -Seconds 1
            Assert-MockCalled Add-IPLimit -Times 3 -Scope It
        }

        It 'Adds 3 subnets' {
            Limit -Type 'IP' -Value @('10.10.0.0/24', '10.10.1.0/24', '10.10.2.0/24') -Limit 1 -Seconds 1
            Assert-MockCalled Add-IPLimit -Times 3 -Scope It
        }
    }
}

Describe 'Access' {
    Mock Add-IPAccess { }

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
            Assert-MockCalled Add-IPAccess -Times 1 -Scope It
        }

        It 'Adds single subnet' {
            Access -Permission 'Allow' -Type 'IP' -Value '10.10.0.0/24'
            Assert-MockCalled Add-IPAccess -Times 1 -Scope It
        }

        It 'Adds 3 IP addresses' {
            Access -Permission 'Allow' -Type 'IP' -Value @('127.0.0.1', '127.0.0.2', '127.0.0.3')
            Assert-MockCalled Add-IPAccess -Times 3 -Scope It
        }

        It 'Adds 3 subnets' {
            Access -Permission 'Allow' -Type 'IP' -Value @('10.10.0.0/24', '10.10.1.0/24', '10.10.2.0/24')
            Assert-MockCalled Add-IPAccess -Times 3 -Scope It
        }
    }
}

Describe 'Add-IPLimit' {
    Context 'Invalid parameters' {
        It 'Throws error for invalid IP' {
            { Add-IPLimit -IP $null -Limit 1 -Seconds 1 } | Should Throw "because it is an empty string"
        }
    }

    Context 'Valid parameters' {
        It 'Adds an IP to limit' {
            $PodeSession = @{ 'Limits' = @{ 'Rules' = @{}; 'Active' = @{}; } }
            Add-IPLimit -IP '127.0.0.1' -Limit 1 -Seconds 1

            $a = $PodeSession.Limits.Rules.IP
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
            $PodeSession = @{ 'Limits' = @{ 'Rules' = @{}; 'Active' = @{}; } }
            Add-IPLimit -IP 'all' -Limit 1 -Seconds 1

            $a = $PodeSession.Limits.Rules.IP
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
            $PodeSession = @{ 'Limits' = @{ 'Rules' = @{}; 'Active' = @{}; } }
            Add-IPLimit -IP '10.10.0.0/24' -Limit 1 -Seconds 1

            $a = $PodeSession.Limits.Rules.IP
            $a | Should Not Be $null
            $a.Count | Should Be 1
            $a.ContainsKey('10.10.0.0/24') | Should Be $true

            $k = $a['10.10.0.0/24']
            $k.Limit | Should Be 1
            $k.Seconds | Should Be 1

            $k.Lower | Should Not Be $null
            $k.Lower.Family | Should Be 'InterNetwork'
            $k.Lower.Bytes | Should Be @(10, 10, 0, 0)

            $k.Upper | Should Not Be $null
            $k.Upper.Family | Should Be 'InterNetwork'
            $k.Upper.Bytes | Should Be @(10, 10, 0, 255)
        }

        It 'Throws error for invalid IP' {
            $PodeSession = @{ 'Limits' = @{ 'Rules' = @{}; 'Active' = @{}; } }
            { Add-IPLimit -IP '256.0.0.0' -Limit 1 -Seconds 1 } | Should Throw 'invalid ip address'
        }
    }
}

Describe 'Add-IPAccess' {
    Context 'Invalid parameters' {
        It 'Throws error for invalid Permission' {
            { Add-IPAccess -Permission 'MOO' -IP 'test' } | Should Throw "Cannot validate argument on parameter 'Permission'"
        }

        It 'Throws error for invalid IP' {
            { Add-IPAccess -Permission 'Allow' -IP $null } | Should Throw "because it is an empty string"
        }
    }

    Context 'Valid parameters' {
        It 'Adds an IP to allow' {
            $PodeSession = @{ 'Access' = @{ 'Allow' = @{}; 'Deny' = @{}; } }
            Add-IPAccess -Permission 'Allow' -IP '127.0.0.1'

            $a = $PodeSession.Access.Allow.IP
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
            $PodeSession = @{ 'Access' = @{ 'Allow' = @{}; 'Deny' = @{}; } }
            Add-IPAccess -Permission 'Allow' -IP 'all'

            $a = $PodeSession.Access.Allow.IP
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
            $PodeSession = @{ 'Access' = @{ 'Allow' = @{}; 'Deny' = @{}; } }
            Add-IPAccess -Permission 'Allow' -IP '10.10.0.0/24'

            $a = $PodeSession.Access.Allow.IP
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
            $PodeSession = @{ 'Access' = @{ 'Allow' = @{}; 'Deny' = @{}; } }
            Add-IPAccess -Permission 'Deny' -IP '127.0.0.1'

            $a = $PodeSession.Access.Deny.IP
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
            $PodeSession = @{ 'Access' = @{ 'Allow' = @{}; 'Deny' = @{}; } }
            Add-IPAccess -Permission 'Deny' -IP 'all'

            $a = $PodeSession.Access.Deny.IP
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
            $PodeSession = @{ 'Access' = @{ 'Allow' = @{}; 'Deny' = @{}; } }
            Add-IPAccess -Permission 'Deny' -IP '10.10.0.0/24'

            $a = $PodeSession.Access.Deny.IP
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
            $PodeSession = @{ 'Access' = @{ 'Allow' = @{}; 'Deny' = @{}; } }

            # add to deny first
            Add-IPAccess -Permission 'Deny' -IP '127.0.0.1'

            $a = $PodeSession.Access.Deny.IP
            $a | Should Not Be $null
            $a.Count | Should Be 1
            $a.ContainsKey('127.0.0.1') | Should Be $true

            # add to allow, deny should be removed
            Add-IPAccess -Permission 'Allow' -IP '127.0.0.1'

            # check allow
            $a = $PodeSession.Access.Allow.IP
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
            $a = $PodeSession.Access.Deny.IP
            $a | Should Not Be $null
            $a.Count | Should Be 0
            $a.ContainsKey('127.0.0.1') | Should Be $false
        }

        It 'Adds an IP to deny and removes one from allow' {
            $PodeSession = @{ 'Access' = @{ 'Allow' = @{}; 'Deny' = @{}; } }

            # add to allow first
            Add-IPAccess -Permission 'Allow' -IP '127.0.0.1'

            $a = $PodeSession.Access.Allow.IP
            $a | Should Not Be $null
            $a.Count | Should Be 1
            $a.ContainsKey('127.0.0.1') | Should Be $true

            # add to deny, allow should be removed
            Add-IPAccess -Permission 'Deny' -IP '127.0.0.1'

            # check deny
            $a = $PodeSession.Access.Deny.IP
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
            $a = $PodeSession.Access.Allow.IP
            $a | Should Not Be $null
            $a.Count | Should Be 0
            $a.ContainsKey('127.0.0.1') | Should Be $false
        }

        It 'Throws error for invalid IP' {
            $PodeSession = @{ 'Access' = @{ 'Allow' = @{}; 'Deny' = @{}; } }
            { Add-IPAccess -Permission 'Allow' -IP '256.0.0.0' } | Should Throw 'invalid ip address'
        }
    }
}