BeforeAll {
    $path = $PSCommandPath
    $src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit', '/src/'
    Get-ChildItem "$($src)/*.ps1" -Recurse | Resolve-Path | ForEach-Object { . $_ }
}
Describe 'Test-PodeCookie' {
    It 'Returns true' {
        $WebEvent = @{ 'Cookies' = @{
                'test' = @{ 'Value' = 'example' }
        } }

        Test-PodeCookie -Name 'test' | Should -Be $true
    }

    It 'Returns false for no value' {
        $WebEvent = @{ 'Cookies' = @{ } }
        Test-PodeCookie -Name 'test' | Should -Be $false
    }

    It 'Returns false for not existing' {
        $WebEvent = @{ 'Cookies' = @{ } }
        Test-PodeCookie -Name 'test' | Should -Be $false
    }
}

Describe 'Test-PodeCookieSigned' {
    It 'Returns false for no value' {
        $WebEvent = @{ 'Cookies' = @{
            'test' = @{ }
        } }

        Test-PodeCookieSigned -Name 'test' | Should -Be $false
    }

    It 'Returns false for not existing' {
        $WebEvent = @{ 'Cookies' = @{} }
        Test-PodeCookieSigned -Name 'test' | Should -Be $false
    }

    It 'Throws error for no secret being passed' {
        Mock Invoke-PodeValueUnsign { return $null }

        $WebEvent = @{ 'Cookies' = @{
            'test' = @{ 'Value' = 'example' }
        } }

        { Test-PodeCookieSigned -Name 'test' } | Should -Throw -ExpectedMessage '*argument is null*'
        Assert-MockCalled Invoke-PodeValueUnsign -Times 0 -Scope It
    }

    It 'Returns false for invalid signed cookie' {
        Mock Invoke-PodeValueUnsign { return $null }

        $WebEvent = @{ 'Cookies' = @{
            'test' = @{ 'Value' = 'example' }
        } }

        Test-PodeCookieSigned -Name 'test' -Secret 'key' | Should -Be $false
        Assert-MockCalled Invoke-PodeValueUnsign -Times 1 -Scope It
    }

    It 'Returns true for valid signed cookie' {
        Mock Invoke-PodeValueUnsign { return 'value' }

        $WebEvent = @{ 'Cookies' = @{
            'test' = @{ 'Value' = 'example' }
        } }

        Test-PodeCookieSigned -Name 'test' -Secret 'key' | Should -Be $true
        Assert-MockCalled Invoke-PodeValueUnsign -Times 1 -Scope It
    }

    It 'Returns true for valid signed cookie, using global secret' {
        Mock Invoke-PodeValueUnsign { return 'value' }

        $PodeContext = @{ 'Server' = @{
            'Cookies' = @{ 'Secrets' = @{
                'global' = 'key'
            }
        } } }

        $WebEvent = @{ 'Cookies' = @{
            'test' = @{ 'Value' = 'example' }
        } }

        Test-PodeCookieSigned -Name 'test' -Secret (Get-PodeCookieSecret -Global) | Should -Be $true
        Assert-MockCalled Invoke-PodeValueUnsign -Times 1 -Scope It
    }
}

Describe 'Get-PodeCookie' {
    It 'Returns null for no value' {
        $WebEvent = @{ 'Cookies' = @{
            'test' = @{ }
        } }

        Get-PodeCookie -Name 'test' | Should -Be $null
    }

    It 'Returns null for not existing' {
        $WebEvent = @{ 'Cookies' = @{
            'test' = @{ }
        } }

        Get-PodeCookie -Name 'test' | Should -Be $null
    }

    It 'Returns a cookie, with no secret' {
        $WebEvent = @{ 'Cookies' = @{
            'test' = @{ 'Value' = 'example' }
        } }

        $c = Get-PodeCookie -Name 'test'
        $c | Should -Not -Be $null
        $c.Value | Should -Be 'example'
    }

    It 'Returns a cookie, with secret but not valid signed' {
        Mock Invoke-PodeValueUnsign { return $null }

        $WebEvent = @{ 'Cookies' = @{
            'test' = @{ 'Value' = 'example' }
        } }

        $c = Get-PodeCookie -Name 'test' -Secret 'key'
        $c | Should -Not -Be $null
        $c.Value | Should -Be 'example'

        Assert-MockCalled Invoke-PodeValueUnsign -Times 1 -Scope It
    }

    It 'Returns a cookie, with secret but valid signed' {
        Mock Invoke-PodeValueUnsign { return 'some-id' }

        $WebEvent = @{ 'Cookies' = @{
            'test' = @{ 'Value' = 'example' }
        } }

        $c = Get-PodeCookie -Name 'test' -Secret 'key'
        $c | Should -Not -Be $null
        $c.Value | Should -Be 'some-id'

        Assert-MockCalled Invoke-PodeValueUnsign -Times 1 -Scope It
    }

    It 'Returns a cookie, with secret but valid signed, using global secret' {
        Mock Invoke-PodeValueUnsign { return 'some-id' }

        $PodeContext = @{ 'Server' = @{
            'Cookies' = @{ 'Secrets' = @{
                'global' = 'key'
            }
        } } }

        $WebEvent = @{ 'Cookies' = @{
            'test' = @{ 'Value' = 'example' }
        } }

        $c = Get-PodeCookie -Name 'test' -Secret (Get-PodeCookieSecret -Global)
        $c | Should -Not -Be $null
        $c.Value | Should -Be 'some-id'

        Assert-MockCalled Invoke-PodeValueUnsign -Times 1 -Scope It
    }
}

Describe 'Set-PodeCookie' {
    It 'Adds simple cookie to response' {
        $script:WebEvent = @{ 'Response' = @{
            'Headers' = @{}
        }; 'PendingCookies' = @{} }

        $WebEvent.Response | Add-Member -MemberType ScriptMethod -Name 'AppendHeader' -Value {
            param($n, $v)
            $script:WebEvent.Response.Headers[$n] = $v
        }

        $c = Set-PodeCookie -Name 'test' -Value 'example'
        $c | Should -Not -Be $null
        $c.Name | Should -Be 'test'
        $c.Value | Should -Be 'example'
        $c.Secure | Should -Be $false
        $c.Discard | Should -Be $false
        $c.HttpOnly | Should -Be $false
        $c.Expires | Should -Be ([datetime]::MinValue)

        $c = $WebEvent.PendingCookies['test']
        $c | Should -Not -Be $null
        $c.Name | Should -Be 'test'
        $c.Value | Should -Be 'example'

        $h = $WebEvent.Response.Headers['Set-Cookie']
        $h | Should -Not -Be $null
    }

    It 'Adds signed cookie to response' {
        Mock Invoke-PodeValueSign { return 'some-id' }

        $script:WebEvent = @{ 'Response' = @{
            'Headers' = @{}
        }; 'PendingCookies' = @{} }

        $WebEvent.Response | Add-Member -MemberType ScriptMethod -Name 'AppendHeader' -Value {
            param($n, $v)
            $script:WebEvent.Response.Headers[$n] = $v
        }

        $c = Set-PodeCookie -Name 'test' -Value 'example' -Secret 'key'
        $c | Should -Not -Be $null
        $c.Name | Should -Be 'test'
        $c.Value | Should -Be 'some-id'

        $c = $WebEvent.PendingCookies['test']
        $c | Should -Not -Be $null
        $c.Name | Should -Be 'test'
        $c.Value | Should -Be 'some-id'

        $h = $WebEvent.Response.Headers['Set-Cookie']
        $h | Should -Not -Be $null

        Assert-MockCalled Invoke-PodeValueSign -Times 1 -Scope It
    }

    It 'Adds signed cookie to response' {
        Mock Invoke-PodeValueSign { return 'some-id' }

        $PodeContext = @{ 'Server' = @{
            'Cookies' = @{ 'Secrets' = @{
                'global' = 'key'
            }
        } } }

        $script:WebEvent = @{ 'Response' = @{
            'Headers' = @{}
        }; 'PendingCookies' = @{} }

        $WebEvent.Response | Add-Member -MemberType ScriptMethod -Name 'AppendHeader' -Value {
            param($n, $v)
            $script:WebEvent.Response.Headers[$n] = $v
        }

        $c = Set-PodeCookie -Name 'test' -Value 'example' -Secret (Get-PodeCookieSecret -Global)
        $c | Should -Not -Be $null
        $c.Name | Should -Be 'test'
        $c.Value | Should -Be 'some-id'

        $c = $WebEvent.PendingCookies['test']
        $c | Should -Not -Be $null
        $c.Name | Should -Be 'test'
        $c.Value | Should -Be 'some-id'

        $h = $WebEvent.Response.Headers['Set-Cookie']
        $h | Should -Not -Be $null

        Assert-MockCalled Invoke-PodeValueSign -Times 1 -Scope It
    }

    It 'Adds cookie to response with options' {
        $script:WebEvent = @{ 'Response' = @{
            'Headers' = @{}
        }; 'PendingCookies' = @{} }

        $WebEvent.Response | Add-Member -MemberType ScriptMethod -Name 'AppendHeader' -Value {
            param($n, $v)
            $script:WebEvent.Response.Headers[$n] = $v
        }

        $c = Set-PodeCookie -Name 'test' -Value 'example' -HttpOnly -Secure -Discard

        $c | Should -Not -Be $null
        $c.Secure | Should -Be $true
        $c.Discard | Should -Be $true
        $c.HttpOnly | Should -Be $true

        $c = $WebEvent.PendingCookies['test']
        $c.Secure | Should -Be $true
        $c.Discard | Should -Be $true
        $c.HttpOnly | Should -Be $true

        $h = $WebEvent.Response.Headers['Set-Cookie']
        $h | Should -Not -Be $null
    }

    It 'Adds cookie to response with TTL' {
        $script:WebEvent = @{ 'Response' = @{
            'Headers' = @{}
        }; 'PendingCookies' = @{} }

        $WebEvent.Response | Add-Member -MemberType ScriptMethod -Name 'AppendHeader' -Value {
            param($n, $v)
            $script:WebEvent.Response.Headers[$n] = $v
        }

        $c = Set-PodeCookie -Name 'test' -Value 'example' -Duration 3600
        $c | Should -Not -Be $null
        $c.Name | Should -Be 'test'
        $c.Value | Should -Be 'example'
        ($c.Expires -gt [datetime]::UtcNow.AddSeconds(3000)) | Should -Be $true

        $c = $WebEvent.PendingCookies['test']
        $c | Should -Not -Be $null
        $c.Name | Should -Be 'test'
        $c.Value | Should -Be 'example'

        $h = $WebEvent.Response.Headers['Set-Cookie']
        $h | Should -Not -Be $null
    }

    It 'Adds cookie to response with Expiry' {
        $script:WebEvent = @{ 'Response' = @{
            'Headers' = @{}
        }; 'PendingCookies' = @{} }

        $WebEvent.Response | Add-Member -MemberType ScriptMethod -Name 'AppendHeader' -Value {
            param($n, $v)
            $script:WebEvent.Response.Headers[$n] = $v
        }

        $c = Set-PodeCookie -Name 'test' -Value 'example' -ExpiryDate ([datetime]::UtcNow.AddDays(2))
        $c | Should -Not -Be $null
        $c.Name | Should -Be 'test'
        $c.Value | Should -Be 'example'
        ($c.Expires -gt [datetime]::UtcNow.AddDays(1)) | Should -Be $true

        $c = $WebEvent.PendingCookies['test']
        $c | Should -Not -Be $null
        $c.Name | Should -Be 'test'
        $c.Value | Should -Be 'example'

        $h = $WebEvent.Response.Headers['Set-Cookie']
        $h | Should -Not -Be $null
    }
}

Describe 'Update-PodeCookieExpiry' {
    It 'Updates the expiry based on TTL' {
        $PodeContext = @{ 'Server' = @{ 'Type' = 'http' } }

        $script:WebEvent = @{ 'Response' = @{
            'Headers' = @{}
        };
        'PendingCookies' = @{
            'test' = @{ 'Name' = 'test'; 'Expires' = [datetime]::UtcNow }
        } }

        Update-PodeCookieExpiry -Name 'test' -Duration 3600
        ($WebEvent.PendingCookies['test'].Expires -gt [datetime]::UtcNow.AddSeconds(3000)) | Should -Be $true
    }

    It 'Updates the expiry based on TTL, using cookie from request' {
        Mock Get-PodeCookie { return @{ 'Name' = 'test'; 'Expires' = [datetime]::UtcNow } }

        $PodeContext = @{ 'Server' = @{ 'Type' = 'http' } }

        $script:WebEvent = @{ 'Response' = @{
            'Headers' = @{}
        };
        'PendingCookies' = @{} }

        Update-PodeCookieExpiry -Name 'test' -Duration 3600
        ($WebEvent.PendingCookies['test'].Expires -gt [datetime]::UtcNow.AddSeconds(3000)) | Should -Be $true
    }

    It 'Updates the expiry based on Expiry' {
        $PodeContext = @{ 'Server' = @{ 'Type' = 'http' } }

        $script:WebEvent = @{ 'Response' = @{
            'Headers' = @{}
        };
        'PendingCookies' = @{
            'test' = @{ 'Name' = 'test'; 'Expires' = [datetime]::UtcNow }
        } }

        Update-PodeCookieExpiry -Name 'test' -Expiry ([datetime]::UtcNow.AddDays(2))
        ($WebEvent.PendingCookies['test'].Expires -gt [datetime]::UtcNow.AddDays(1)) | Should -Be $true
    }

    It 'Expiry remains unchanged on 0 TTL' {
        $PodeContext = @{ 'Server' = @{ 'Type' = 'http' } }

        $ttl = [datetime]::UtcNow

        $script:WebEvent = @{ 'Response' = @{
            'Headers' = @{}
        };
        'PendingCookies' = @{
            'test' = @{ 'Name' = 'test'; 'Expires' = $ttl }
        } }

        Update-PodeCookieExpiry -Name 'test'
        $WebEvent.PendingCookies['test'].Expires | Should -Be $ttl
    }

    It 'Expiry remains unchanged on negative TTL' {
        $PodeContext = @{ 'Server' = @{ 'Type' = 'http' } }

        $ttl = [datetime]::UtcNow

        $script:WebEvent = @{ 'Response' = @{
            'Headers' = @{}
        };
        'PendingCookies' = @{
            'test' = @{ 'Name' = 'test'; 'Expires' = $ttl }
        } }

        Update-PodeCookieExpiry -Name 'test' -Duration -1
        $WebEvent.PendingCookies['test'].Expires | Should -Be $ttl
    }
}

Describe 'Remove-PodeCookie' {
    It 'Flags the cookie for removal' {
        $PodeContext = @{ 'Server' = @{ 'Type' = 'http' } }

        $WebEvent = @{ 'Response' = @{
            'Headers' = @{}
        };
        'PendingCookies' = @{
            'test' = @{ 'Name' = 'test'; 'Discard' = $false; 'Expires' = [datetime]::UtcNow }
        } }

        Remove-PodeCookie -Name 'test'

        $WebEvent.PendingCookies['test'].Discard | Should -Be $true
        ($WebEvent.PendingCookies['test'].Expires -lt [datetime]::UtcNow) | Should -Be $true
    }

    It 'Flags the cookie for removal, using a cookie from the request' {
        Mock Get-PodeCookie { return @{ 'Name' = 'test'; 'Discard' = $false; 'Expires' = [datetime]::UtcNow } }

        $PodeContext = @{ 'Server' = @{ 'Type' = 'http' } }

        $WebEvent = @{ 'Response' = @{
            'Headers' = @{}
        };
        'PendingCookies' = @{} }

        Remove-PodeCookie -Name 'test'

        $WebEvent.PendingCookies['test'].Discard | Should -Be $true
        ($WebEvent.PendingCookies['test'].Expires -lt [datetime]::UtcNow) | Should -Be $true
    }
}

Describe 'Invoke-PodeValueSign' {
    Context 'Invalid parameters supplied' {
        It 'Throws null value error' {
            { Invoke-PodeValueSign -Value $null -Secret 'key' } | Should -Throw -ExpectedMessage '*argument is null or empty*'
        }

        It 'Throws empty value error' {
            { Invoke-PodeValueSign -Value '' -Secret 'key' } | Should -Throw -ExpectedMessage '*argument is null or empty*'
        }

        It 'Throws null secret error' {
            { Invoke-PodeValueSign -Value 'value' -Secret $null } | Should -Throw -ExpectedMessage '*argument is null or empty*'
        }

        It 'Throws empty secret error' {
            { Invoke-PodeValueSign -Value 'value' -Secret '' } | Should -Throw -ExpectedMessage '*argument is null or empty*'
        }
    }

    Context 'Valid parameters' {
        It 'Returns signed encrypted data' {
            Invoke-PodeValueSign -Value 'value' -Secret 'key' | Should -Be 's:value.kPv88V50o2uJ29sqch2a7P/f3dxcg+J/dZJZT3GTJIE='
        }
    }
}

Describe 'Invoke-PodeValueUnsign' {
    Context 'Invalid parameters supplied' {
        It 'Throws null value error' {
            { Invoke-PodeValueUnsign -Value $null -Secret 'key' } | Should -Throw -ExpectedMessage '*argument is null or empty*'
        }

        It 'Throws empty value error' {
            { Invoke-PodeValueUnsign -Value '' -Secret 'key' } | Should -Throw -ExpectedMessage '*argument is null or empty*'
        }

        It 'Throws null secret error' {
            { Invoke-PodeValueUnsign -Value 'value' -Secret $null } | Should -Throw -ExpectedMessage '*argument is null or empty*'
        }

        It 'Throws empty secret error' {
            { Invoke-PodeValueUnsign -Value 'value' -Secret '' } | Should -Throw -ExpectedMessage '*argument is null or empty*'
        }
    }

    Context 'Valid parameters' {
        It 'Returns signed encrypted data' {
            Invoke-PodeValueUnsign -Value 's:value.kPv88V50o2uJ29sqch2a7P/f3dxcg+J/dZJZT3GTJIE=' -Secret 'key' | Should -Be 'value'
        }

        It 'Returns null for unsign data with no tag' {
            Invoke-PodeValueUnsign -Value 'value' -Secret 'key' | Should -Be $null
        }

        It 'Returns null for unsign data with no period' {
            Invoke-PodeValueUnsign -Value 's:value' -Secret 'key' | Should -Be $null
        }

        It 'Returns null for invalid signing' {
            Invoke-PodeValueUnsign -Value 's:value.random' -Secret 'key' | Should -Be $null
        }
    }
}

Describe 'ConvertTo-PodeCookie' {
    It 'Returns empty for no cookie' {
        $r = ConvertTo-PodeCookie -Cookie $null
        $r.Count | Should -Be 0
    }

    It 'Returns a mapped cookie' {
        $now = [datetime]::UtcNow.Date
        $c = [System.Net.Cookie]::new('date', $now)

        $r = ConvertTo-PodeCookie -Cookie $c

        $r.Count | Should -Be 10
        $r.Name | Should -Be 'date'
        $r.Value | Should -Be $now
        $r.Signed | Should -Be $false
        $r.HttpOnly | Should -Be $false
        $r.Discard | Should -Be $false
        $r.Secure | Should -Be $false
    }
}

Describe 'ConvertTo-PodeCookieString' {
    It 'Returns name, value' {
        $c = [System.Net.Cookie]::new('name', 'value')
        ConvertTo-PodeCookieString -Cookie $c | Should -Be 'name=value'
    }

    It 'Returns name, value, discard' {
        $c = [System.Net.Cookie]::new('name', 'value')
        $c.Discard = $true
        ConvertTo-PodeCookieString -Cookie $c | Should -Be 'name=value; Discard'
    }

    It 'Returns name, value, httponly' {
        $c = [System.Net.Cookie]::new('name', 'value')
        $c.HttpOnly = $true
        ConvertTo-PodeCookieString -Cookie $c | Should -Be 'name=value; HttpOnly'
    }

    It 'Returns name, value, secure' {
        $c = [System.Net.Cookie]::new('name', 'value')
        $c.Secure = $true
        ConvertTo-PodeCookieString -Cookie $c | Should -Be 'name=value; Secure'
    }

    It 'Returns name, value, domain' {
        $c = [System.Net.Cookie]::new('name', 'value')
        $c.Domain = 'random.domain.name'
        ConvertTo-PodeCookieString -Cookie $c | Should -Be 'name=value; Domain=random.domain.name'
    }

    It 'Returns name, value, path' {
        $c = [System.Net.Cookie]::new('name', 'value')
        $c.Path = '/api'
        ConvertTo-PodeCookieString -Cookie $c | Should -Be 'name=value; Path=/api'
    }

    It 'Returns name, value, max-age' {
        $c = [System.Net.Cookie]::new('name', 'value')
        $c.Expires = [datetime]::Now.AddDays(1)
        ConvertTo-PodeCookieString -Cookie $c | Should -Match 'name=value; Max-Age=\d+'
    }

    It 'Returns null for no name or value' {
        $c = @{ 'Name' = ''; 'Value' = '' }
        ConvertTo-PodeCookieString -Cookie $c | Should -Be $null
    }
}