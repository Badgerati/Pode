$path = $MyInvocation.MyCommand.Path
$src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit[\\/]', '/src/'
Get-ChildItem "$($src)/*.ps1" | Resolve-Path | ForEach-Object { . $_ }

Describe 'Test-PodeCookieExists' {
    It 'Returns true' {
        $WebEvent = @{ 'Cookies' = @{
                'test' = @{ 'Value' = 'example' }
        } }

        Test-PodeCookieExists -Name 'test' | Should Be $true
    }

    It 'Returns false for no value' {
        $WebEvent = @{ 'Cookies' = @{ } }
        Test-PodeCookieExists -Name 'test' | Should Be $false
    }

    It 'Returns false for not existing' {
        $WebEvent = @{ 'Cookies' = @{ } }
        Test-PodeCookieExists -Name 'test' | Should Be $false
    }
}

Describe 'Test-PodeCookieIsSigned' {
    It 'Returns false for no value' {
        $WebEvent = @{ 'Cookies' = @{
            'test' = @{ }
        } }

        Test-PodeCookieIsSigned -Name 'test' | Should Be $false
    }

    It 'Returns false for not existing' {
        $WebEvent = @{ 'Cookies' = @{} }
        Test-PodeCookieIsSigned -Name 'test' | Should Be $false
    }

    It 'Throws error for no secret being passed' {
        Mock Invoke-PodeCookieUnsign { return $null }

        $WebEvent = @{ 'Cookies' = @{
            'test' = @{ 'Value' = 'example' }
        } }

        { Test-PodeCookieIsSigned -Name 'test' } | Should Throw 'argument is null'
        Assert-MockCalled Invoke-PodeCookieUnsign -Times 0 -Scope It
    }

    It 'Returns false for invalid signed cookie' {
        Mock Invoke-PodeCookieUnsign { return $null }

        $WebEvent = @{ 'Cookies' = @{
            'test' = @{ 'Value' = 'example' }
        } }

        Test-PodeCookieIsSigned -Name 'test' -Secret 'key' | Should Be $false
        Assert-MockCalled Invoke-PodeCookieUnsign -Times 1 -Scope It
    }

    It 'Returns true for valid signed cookie' {
        Mock Invoke-PodeCookieUnsign { return 'value' }

        $WebEvent = @{ 'Cookies' = @{
            'test' = @{ 'Value' = 'example' }
        } }

        Test-PodeCookieIsSigned -Name 'test' -Secret 'key' | Should Be $true
        Assert-MockCalled Invoke-PodeCookieUnsign -Times 1 -Scope It
    }

    It 'Returns true for valid signed cookie, using global secret' {
        Mock Invoke-PodeCookieUnsign { return 'value' }

        $PodeContext = @{ 'Server' = @{
            'Cookies' = @{ 'Secrets' = @{
                'global' = 'key'
            }
        } } }

        $WebEvent = @{ 'Cookies' = @{
            'test' = @{ 'Value' = 'example' }
        } }

        Test-PodeCookieIsSigned -Name 'test' -GlobalSecret | Should Be $true
        Assert-MockCalled Invoke-PodeCookieUnsign -Times 1 -Scope It
    }
}

Describe 'Get-PodeCookie' {
    It 'Returns null for no value' {
        $WebEvent = @{ 'Cookies' = @{
            'test' = @{ }
        } }

        Get-PodeCookie -Name 'test' | Should Be $null
    }

    It 'Returns null for not existing' {
        $WebEvent = @{ 'Cookies' = @{
            'test' = @{ }
        } }

        Get-PodeCookie -Name 'test' | Should Be $null
    }

    It 'Returns a cookie, with no secret' {
        $WebEvent = @{ 'Cookies' = @{
            'test' = @{ 'Value' = 'example' }
        } }

        $c = Get-PodeCookie -Name 'test'
        $c | Should Not Be $null
        $c.Value | Should Be 'example'
    }

    It 'Returns a cookie, with secret but not valid signed' {
        Mock Invoke-PodeCookieUnsign { return $null }

        $WebEvent = @{ 'Cookies' = @{
            'test' = @{ 'Value' = 'example' }
        } }

        $c = Get-PodeCookie -Name 'test' -Secret 'key'
        $c | Should Not Be $null
        $c.Value | Should Be 'example'

        Assert-MockCalled Invoke-PodeCookieUnsign -Times 1 -Scope It
    }

    It 'Returns a cookie, with secret but valid signed' {
        Mock Invoke-PodeCookieUnsign { return 'some-id' }

        $WebEvent = @{ 'Cookies' = @{
            'test' = @{ 'Value' = 'example' }
        } }

        $c = Get-PodeCookie -Name 'test' -Secret 'key'
        $c | Should Not Be $null
        $c.Value | Should Be 'some-id'

        Assert-MockCalled Invoke-PodeCookieUnsign -Times 1 -Scope It
    }

    It 'Returns a cookie, with secret but valid signed, using global secret' {
        Mock Invoke-PodeCookieUnsign { return 'some-id' }

        $PodeContext = @{ 'Server' = @{
            'Cookies' = @{ 'Secrets' = @{
                'global' = 'key'
            }
        } } }

        $WebEvent = @{ 'Cookies' = @{
            'test' = @{ 'Value' = 'example' }
        } }

        $c = Get-PodeCookie -Name 'test' -GlobalSecret
        $c | Should Not Be $null
        $c.Value | Should Be 'some-id'

        Assert-MockCalled Invoke-PodeCookieUnsign -Times 1 -Scope It
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
        $c | Should Not Be $null
        $c.Name | Should Be 'test'
        $c.Value | Should Be 'example'
        $c.Secure | Should Be $false
        $c.Discard | Should Be $false
        $c.HttpOnly | Should Be $false
        $c.Expires | Should Be ([datetime]::MinValue)

        $c = $WebEvent.PendingCookies['test']
        $c | Should Not Be $null
        $c.Name | Should Be 'test'
        $c.Value | Should Be 'example'

        $h = $WebEvent.Response.Headers['Set-Cookie']
        $h | Should Not Be $null
    }

    It 'Adds signed cookie to response' {
        Mock Invoke-PodeCookieSign { return 'some-id' }

        $script:WebEvent = @{ 'Response' = @{
            'Headers' = @{}
        }; 'PendingCookies' = @{} }

        $WebEvent.Response | Add-Member -MemberType ScriptMethod -Name 'AppendHeader' -Value {
            param($n, $v)
            $script:WebEvent.Response.Headers[$n] = $v
        }

        $c = Set-PodeCookie -Name 'test' -Value 'example' -Secret 'key'
        $c | Should Not Be $null
        $c.Name | Should Be 'test'
        $c.Value | Should Be 'some-id'

        $c = $WebEvent.PendingCookies['test']
        $c | Should Not Be $null
        $c.Name | Should Be 'test'
        $c.Value | Should Be 'some-id'

        $h = $WebEvent.Response.Headers['Set-Cookie']
        $h | Should Not Be $null

        Assert-MockCalled Invoke-PodeCookieSign -Times 1 -Scope It
    }

    It 'Adds signed cookie to response' {
        Mock Invoke-PodeCookieSign { return 'some-id' }

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

        $c = Set-PodeCookie -Name 'test' -Value 'example' -GlobalSecret
        $c | Should Not Be $null
        $c.Name | Should Be 'test'
        $c.Value | Should Be 'some-id'

        $c = $WebEvent.PendingCookies['test']
        $c | Should Not Be $null
        $c.Name | Should Be 'test'
        $c.Value | Should Be 'some-id'

        $h = $WebEvent.Response.Headers['Set-Cookie']
        $h | Should Not Be $null

        Assert-MockCalled Invoke-PodeCookieSign -Times 1 -Scope It
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

        $c | Should Not Be $null
        $c.Secure | Should Be $true
        $c.Discard | Should Be $true
        $c.HttpOnly | Should Be $true

        $c = $WebEvent.PendingCookies['test']
        $c.Secure | Should Be $true
        $c.Discard | Should Be $true
        $c.HttpOnly | Should Be $true

        $h = $WebEvent.Response.Headers['Set-Cookie']
        $h | Should Not Be $null
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
        $c | Should Not Be $null
        $c.Name | Should Be 'test'
        $c.Value | Should Be 'example'
        ($c.Expires -gt [datetime]::UtcNow.AddSeconds(3000)) | Should Be $true

        $c = $WebEvent.PendingCookies['test']
        $c | Should Not Be $null
        $c.Name | Should Be 'test'
        $c.Value | Should Be 'example'

        $h = $WebEvent.Response.Headers['Set-Cookie']
        $h | Should Not Be $null
    }

    It 'Adds cookie to response with Expiry' {
        $script:WebEvent = @{ 'Response' = @{
            'Headers' = @{}
        }; 'PendingCookies' = @{} }

        $WebEvent.Response | Add-Member -MemberType ScriptMethod -Name 'AppendHeader' -Value {
            param($n, $v)
            $script:WebEvent.Response.Headers[$n] = $v
        }

        $c = Set-PodeCookie -Name 'test' -Value 'example' -Expiry ([datetime]::UtcNow.AddDays(2))
        $c | Should Not Be $null
        $c.Name | Should Be 'test'
        $c.Value | Should Be 'example'
        ($c.Expires -gt [datetime]::UtcNow.AddDays(1)) | Should Be $true

        $c = $WebEvent.PendingCookies['test']
        $c | Should Not Be $null
        $c.Name | Should Be 'test'
        $c.Value | Should Be 'example'

        $h = $WebEvent.Response.Headers['Set-Cookie']
        $h | Should Not Be $null
    }
}

Describe 'Update-PodeCookieExpiry' {
    It 'Updates the expiry based on TTL' {
        $script:WebEvent = @{ 'Response' = @{
            'Headers' = @{}
        };
        'PendingCookies' = @{
            'test' = @{ 'Name' = 'test'; 'Expires' = [datetime]::UtcNow }
        } }

        $script:called = $false
        $WebEvent.Response | Add-Member -MemberType ScriptMethod -Name 'AppendHeader' -Value {
            param($n, $v)
            $script:WebEvent.Response.Headers[$n] = $v
            $script:called = $true
        }

        Update-PodeCookieExpiry -Name 'test' -Duration 3600
        $called | Should Be $true

        ($WebEvent.PendingCookies['test'].Expires -gt [datetime]::UtcNow.AddSeconds(3000)) | Should Be $true
    }

    It 'Updates the expiry based on Expiry' {
        $script:WebEvent = @{ 'Response' = @{
            'Headers' = @{}
        };
        'PendingCookies' = @{
            'test' = @{ 'Name' = 'test'; 'Expires' = [datetime]::UtcNow }
        } }

        $script:called = $false
        $WebEvent.Response | Add-Member -MemberType ScriptMethod -Name 'AppendHeader' -Value {
            param($n, $v)
            $script:WebEvent.Response.Headers[$n] = $v
            $script:called = $true
        }

        Update-PodeCookieExpiry -Name 'test' -Expiry ([datetime]::UtcNow.AddDays(2))
        $called | Should Be $true

        ($WebEvent.PendingCookies['test'].Expires -gt [datetime]::UtcNow.AddDays(1)) | Should Be $true
    }

    It 'Expiry remains unchanged on 0 TTL' {
        $ttl = [datetime]::UtcNow

        $script:WebEvent = @{ 'Response' = @{
            'Headers' = @{}
        };
        'PendingCookies' = @{
            'test' = @{ 'Name' = 'test'; 'Expires' = $ttl }
        } }

        $script:called = $false
        $WebEvent.Response | Add-Member -MemberType ScriptMethod -Name 'AppendHeader' -Value {
            param($n, $v)
            $script:WebEvent.Response.Headers[$n] = $v
            $script:called = $true
        }

        Update-PodeCookieExpiry -Name 'test'
        $called | Should Be $true

        $WebEvent.PendingCookies['test'].Expires | Should Be $ttl
    }

    It 'Expiry remains unchanged on negative TTL' {
        $ttl = [datetime]::UtcNow

        $script:WebEvent = @{ 'Response' = @{
            'Headers' = @{}
        };
        'PendingCookies' = @{
            'test' = @{ 'Name' = 'test'; 'Expires' = $ttl }
        } }

        $script:called = $false
        $WebEvent.Response | Add-Member -MemberType ScriptMethod -Name 'AppendHeader' -Value {
            param($n, $v)
            $script:WebEvent.Response.Headers[$n] = $v
            $script:called = $true
        }

        Update-PodeCookieExpiry -Name 'test' -Duration -1
        $called | Should Be $true

        $WebEvent.PendingCookies['test'].Expires | Should Be $ttl
    }
}

Describe 'Remove-PodeCookie' {
    It 'Flags the cookie for removal' {
        $WebEvent = @{ 'Response' = @{
            'Headers' = @{}
        };
        'PendingCookies' = @{
            'test' = @{ 'Name' = 'test'; 'Discard' = $false; 'Expires' = [datetime]::UtcNow }
        } }

        $script:called = $false
        $WebEvent.Response | Add-Member -MemberType ScriptMethod -Name 'AppendHeader' -Value {
            param($n, $v)
            $script:WebEvent.Response.Headers[$n] = $v
            $script:called = $true
        }

        Remove-PodeCookie -Name 'test'
        $called | Should Be $true

        $WebEvent.PendingCookies['test'].Discard | Should Be $true
        ($WebEvent.PendingCookies['test'].Expires -lt [datetime]::UtcNow) | Should Be $true
    }
}

Describe 'Cookie' {
    It 'Throws invalid action error' {
        { Cookie -Action 'MOO' -Name 'test' } | Should Throw "Cannot validate argument on parameter 'Action'"
    }

    It 'Throws error for null name' {
        { Cookie -Action Set -Name $null } | Should Throw "because it is an empty string"
    }

    It 'Throws error for empty name' {
        { Cookie -Action Set -Name ([string]::Empty) } | Should Throw "because it is an empty string"
    }

    It 'Calls add method' {
        Mock Set-PodeCookie { return 'cookie' }
        $c = Cookie -Action Set -Name 'test' -Value 'example'
        $c | Should Not Be $null
        $c | Should Be 'cookie'
        Assert-MockCalled Set-PodeCookie -Times 1 -Scope It
    }

    It 'Calls get method' {
        Mock Get-PodeCookie { return 'cookie' }
        $c = Cookie -Action Get -Name 'test'
        $c | Should Not Be $null
        $c | Should Be 'cookie'
        Assert-MockCalled Get-PodeCookie -Times 1 -Scope It
    }

    It 'Calls exists method' {
        Mock Test-PodeCookieExists { return $true }
        Cookie -Action Exists -Name 'test' | Should Be $true
        Assert-MockCalled Test-PodeCookieExists -Times 1 -Scope It
    }

    It 'Calls remove method' {
        Mock Remove-PodeCookie { }
        Cookie -Action Remove -Name 'test'
        Assert-MockCalled Remove-PodeCookie -Times 1 -Scope It
    }

    It 'Calls check method' {
        Mock Test-PodeCookieIsSigned { return $true }
        Cookie -Action Check -Name 'test' -Secret 'key' | Should Be $true
        Assert-MockCalled Test-PodeCookieIsSigned -Times 1 -Scope It
    }

    It 'Calls extend method' {
        Mock Update-PodeCookieExpiry { }
        Cookie -Action Extend -Name 'test' -Ttl 3000
        Assert-MockCalled Update-PodeCookieExpiry -Times 1 -Scope It
    }

    It 'Calls secret method to set secret' {
        $PodeContext = @{ 'Server' = @{
            'Cookies' = @{ 'Secrets' = @{} }
        } }

        Cookie -Action Secrets -Name 'global' -Value 'test'

        $PodeContext.Server.Cookies.Secrets['global'] | Should Be 'test'
    }

    It 'Calls secret method to get secret' {
        $PodeContext = @{ 'Server' = @{
            'Cookies' = @{ 'Secrets' = @{
                'global' = 'bill'
            }
        } } }

        Cookie -Action Secrets -Name 'global' | Should Be 'bill'
    }
}

Describe 'Invoke-PodeCookieSign' {
    Context 'Invalid parameters supplied' {
        It 'Throws null value error' {
            { Invoke-PodeCookieSign -Value $null -Secret 'key' } | Should Throw 'argument is null or empty'
        }

        It 'Throws empty value error' {
            { Invoke-PodeCookieSign -Value '' -Secret 'key' } | Should Throw 'argument is null or empty'
        }

        It 'Throws null secret error' {
            { Invoke-PodeCookieSign -Value 'value' -Secret $null } | Should Throw 'argument is null or empty'
        }

        It 'Throws empty secret error' {
            { Invoke-PodeCookieSign -Value 'value' -Secret '' } | Should Throw 'argument is null or empty'
        }
    }

    Context 'Valid parameters' {
        It 'Returns signed encrypted data' {
            Invoke-PodeCookieSign -Value 'value' -Secret 'key' | Should Be 's:value.kPv88V50o2uJ29sqch2a7P/f3dxcg+J/dZJZT3GTJIE='
        }
    }
}

Describe 'Invoke-PodeCookieUnsign' {
    Context 'Invalid parameters supplied' {
        It 'Throws null value error' {
            { Invoke-PodeCookieUnsign -Signature $null -Secret 'key' } | Should Throw 'argument is null or empty'
        }

        It 'Throws empty value error' {
            { Invoke-PodeCookieUnsign -Signature '' -Secret 'key' } | Should Throw 'argument is null or empty'
        }

        It 'Throws null secret error' {
            { Invoke-PodeCookieUnsign -Signature 'value' -Secret $null } | Should Throw 'argument is null or empty'
        }

        It 'Throws empty secret error' {
            { Invoke-PodeCookieUnsign -Signature 'value' -Secret '' } | Should Throw 'argument is null or empty'
        }
    }

    Context 'Valid parameters' {
        It 'Returns signed encrypted data' {
            Invoke-PodeCookieUnsign -Signature 's:value.kPv88V50o2uJ29sqch2a7P/f3dxcg+J/dZJZT3GTJIE=' -Secret 'key' | Should Be 'value'
        }

        It 'Returns null for unsign data with no tag' {
            Invoke-PodeCookieUnsign -Signature 'value' -Secret 'key' | Should Be $null
        }

        It 'Returns null for unsign data with no period' {
            Invoke-PodeCookieUnsign -Signature 's:value' -Secret 'key' | Should Be $null
        }
    }
}

Describe 'ConvertTo-PodeCookie' {
    It 'Returns empty for no cookie' {
        $r = ConvertTo-PodeCookie -Cookie $null
        $r.Count | Should Be 0
    }

    It 'Returns a mapped cookie' {
        $now = [datetime]::UtcNow.Date
        $c = [System.Net.Cookie]::new('date', $now)

        $r = ConvertTo-PodeCookie -Cookie $c

        $r.Count | Should Be 10
        $r.Name | Should Be 'date'
        $r.Value | Should Be $now
        $r.Signed | Should Be $false
        $r.HttpOnly | Should Be $false
        $r.Discard | Should Be $false
        $r.Secure | Should Be $false
    }
}

Describe 'ConvertTo-PodeCookieString' {
    It 'Returns name, value' {
        $c = [System.Net.Cookie]::new('name', 'value')
        ConvertTo-PodeCookieString -Cookie $c | Should Be 'name=value'
    }

    It 'Returns name, value, discard' {
        $c = [System.Net.Cookie]::new('name', 'value')
        $c.Discard = $true
        ConvertTo-PodeCookieString -Cookie $c | Should Be 'name=value; Discard'
    }

    It 'Returns name, value, httponly' {
        $c = [System.Net.Cookie]::new('name', 'value')
        $c.HttpOnly = $true
        ConvertTo-PodeCookieString -Cookie $c | Should Be 'name=value; HttpOnly'
    }

    It 'Returns name, value, secure' {
        $c = [System.Net.Cookie]::new('name', 'value')
        $c.Secure = $true
        ConvertTo-PodeCookieString -Cookie $c | Should Be 'name=value; Secure'
    }

    It 'Returns name, value, domain' {
        $c = [System.Net.Cookie]::new('name', 'value')
        $c.Domain = 'random.domain.name'
        ConvertTo-PodeCookieString -Cookie $c | Should Be 'name=value; Domain=random.domain.name'
    }

    It 'Returns name, value, path' {
        $c = [System.Net.Cookie]::new('name', 'value')
        $c.Path = '/api'
        ConvertTo-PodeCookieString -Cookie $c | Should Be 'name=value; Path=/api'
    }

    It 'Returns name, value, max-age' {
        $c = [System.Net.Cookie]::new('name', 'value')
        $c.Expires = [datetime]::Now.AddDays(1)
        ConvertTo-PodeCookieString -Cookie $c | Should Match 'name=value; Max-Age=\d+'
    }

    It 'Returns null for no name or value' {
        $c = @{ 'Name' = ''; 'Value' = '' }
        ConvertTo-PodeCookieString -Cookie $c | Should Be $null
    }
}