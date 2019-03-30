$path = $MyInvocation.MyCommand.Path
$src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit[\\/]', '/src/'
Get-ChildItem "$($src)/*.ps1" | Resolve-Path | ForEach-Object { . $_ }

Describe 'Test-PodeCookieExists' {
    It 'Returns true' {
        $WebEvent = @{ 'Request' = @{
            'Cookies' = @{
                'test' = @{ 'Value' = 'example' }
            }
        } }

        Test-PodeCookieExists -Name 'test' | Should Be $true
    }

    It 'Returns false for no value' {
        $WebEvent = @{ 'Request' = @{
            'Cookies' = @{
                'test' = @{ }
            }
        } }

        Test-PodeCookieExists -Name 'test' | Should Be $false
    }

    It 'Returns false for not existing' {
        $WebEvent = @{ 'Request' = @{
            'Cookies' = @{}
        } }

        Test-PodeCookieExists -Name 'test' | Should Be $false
    }
}

Describe 'Test-PodeCookieIsSigned' {
    It 'Returns false for no value' {
        $WebEvent = @{ 'Request' = @{
            'Cookies' = @{
                'test' = @{ }
            }
        } }

        Test-PodeCookieIsSigned -Name 'test' | Should Be $false
    }

    It 'Returns false for not existing' {
        $WebEvent = @{ 'Request' = @{
            'Cookies' = @{}
        } }

        Test-PodeCookieIsSigned -Name 'test' | Should Be $false
    }

    It 'Throws error for no secret being passed' {
        Mock Invoke-PodeCookieUnsign { return $null }

        $WebEvent = @{ 'Request' = @{
            'Cookies' = @{
                'test' = @{ 'Value' = 'example' }
            }
        } }

        { Test-PodeCookieIsSigned -Name 'test' } | Should Throw 'argument is null'
        Assert-MockCalled Invoke-PodeCookieUnsign -Times 0 -Scope It
    }

    It 'Returns false for invalid signed cookie' {
        Mock Invoke-PodeCookieUnsign { return $null }

        $WebEvent = @{ 'Request' = @{
            'Cookies' = @{
                'test' = @{ 'Value' = 'example' }
            }
        } }

        Test-PodeCookieIsSigned -Name 'test' -Secret 'key' | Should Be $false
        Assert-MockCalled Invoke-PodeCookieUnsign -Times 1 -Scope It
    }

    It 'Returns true for valid signed cookie' {
        Mock Invoke-PodeCookieUnsign { return 'value' }

        $WebEvent = @{ 'Request' = @{
            'Cookies' = @{
                'test' = @{ 'Value' = 'example' }
            }
        } }

        Test-PodeCookieIsSigned -Name 'test' -Secret 'key' | Should Be $true
        Assert-MockCalled Invoke-PodeCookieUnsign -Times 1 -Scope It
    }
}

Describe 'Get-PodeCookie' {
    It 'Returns null for no value' {
        $WebEvent = @{ 'Request' = @{
            'Cookies' = @{
                'test' = @{ }
            }
        } }

        Get-PodeCookie -Name 'test' | Should Be $null
    }

    It 'Returns null for not existing' {
        $WebEvent = @{ 'Request' = @{
            'Cookies' = @{}
        } }

        Get-PodeCookie -Name 'test' | Should Be $null
    }

    It 'Returns a cookie, with no secret' {
        $WebEvent = @{ 'Request' = @{
            'Cookies' = @{
                'test' = @{ 'Value' = 'example' }
            }
        } }

        $c = Get-PodeCookie -Name 'test'
        $c | Should Not Be $null
        $c.Value | Should Be 'example'
    }

    It 'Returns a cookie, with secret but not valid signed' {
        Mock Invoke-PodeCookieUnsign { return $null }

        $WebEvent = @{ 'Request' = @{
            'Cookies' = @{
                'test' = @{ 'Value' = 'example' }
            }
        } }

        $c = Get-PodeCookie -Name 'test' -Secret 'key'
        $c | Should Not Be $null
        $c.Value | Should Be 'example'

        Assert-MockCalled Invoke-PodeCookieUnsign -Times 1 -Scope It
    }

    It 'Returns a cookie, with secret but valid signed' {
        Mock Invoke-PodeCookieUnsign { return 'some-id' }

        $WebEvent = @{ 'Request' = @{
            'Cookies' = @{
                'test' = @{ 'Value' = 'example' }
            }
        } }

        $c = Get-PodeCookie -Name 'test' -Secret 'key'
        $c | Should Not Be $null
        $c.Value | Should Be 'some-id'

        Assert-MockCalled Invoke-PodeCookieUnsign -Times 1 -Scope It
    }
}

Describe 'Set-PodeCookie' {
    It 'Adds simple cookie to response' {
        $script:WebEvent = @{ 'Response' = @{
            'Cookies' = @{}
        } }

        $WebEvent.Response | Add-Member -MemberType ScriptMethod -Name 'AppendCookie' -Value {
            param($c)
            $script:WebEvent.Response.Cookies[$c.Name] = $c
        }

        $c = Set-PodeCookie -Name 'test' -Value 'example'
        $c | Should Not Be $null
        $c.Name | Should Be 'test'
        $c.Value | Should Be 'example'
        $c.Secure | Should Be $false
        $c.Discard | Should Be $false
        $c.HttpOnly | Should Be $false
        $c.Expires | Should Be ([datetime]::MinValue)

        $c = $WebEvent.Response.Cookies['test']
        $c | Should Not Be $null
        $c.Name | Should Be 'test'
        $c.Value | Should Be 'example'
    }

    It 'Adds signed cookie to response' {
        Mock Invoke-PodeCookieSign { return 'some-id' }

        $script:WebEvent = @{ 'Response' = @{
            'Cookies' = @{}
        } }

        $WebEvent.Response | Add-Member -MemberType ScriptMethod -Name 'AppendCookie' -Value {
            param($c)
            $script:WebEvent.Response.Cookies[$c.Name] = $c
        }

        $c = Set-PodeCookie -Name 'test' -Value 'example' -Secret 'key'
        $c | Should Not Be $null
        $c.Name | Should Be 'test'
        $c.Value | Should Be 'some-id'

        $c = $WebEvent.Response.Cookies['test']
        $c | Should Not Be $null
        $c.Name | Should Be 'test'
        $c.Value | Should Be 'some-id'

        Assert-MockCalled Invoke-PodeCookieSign -Times 1 -Scope It
    }

    It 'Adds cookie to response with options' {
        $script:WebEvent = @{ 'Response' = @{
            'Cookies' = @{}
        } }

        $WebEvent.Response | Add-Member -MemberType ScriptMethod -Name 'AppendCookie' -Value {
            param($c)
            $script:WebEvent.Response.Cookies[$c.Name] = $c
        }

        $c = Set-PodeCookie -Name 'test' -Value 'example' -Options @{
            'Secure' = $true;
            'Discard' = $true;
            'HttpOnly' = $true;
        }

        $c | Should Not Be $null
        $c.Secure | Should Be $true
        $c.Discard | Should Be $true
        $c.HttpOnly | Should Be $true

        $c = $WebEvent.Response.Cookies['test']
        $c.Secure | Should Be $true
        $c.Discard | Should Be $true
        $c.HttpOnly | Should Be $true
    }

    It 'Adds cookie to response with TTL' {
        $script:WebEvent = @{ 'Response' = @{
            'Cookies' = @{}
        } }

        $WebEvent.Response | Add-Member -MemberType ScriptMethod -Name 'AppendCookie' -Value {
            param($c)
            $script:WebEvent.Response.Cookies[$c.Name] = $c
        }

        $c = Set-PodeCookie -Name 'test' -Value 'example' -Ttl 3600
        $c | Should Not Be $null
        $c.Name | Should Be 'test'
        $c.Value | Should Be 'example'
        ($c.Expires -gt [datetime]::UtcNow.AddSeconds(3000)) | Should Be $true

        $c = $WebEvent.Response.Cookies['test']
        $c | Should Not Be $null
        $c.Name | Should Be 'test'
        $c.Value | Should Be 'example'
    }

    It 'Adds cookie to response with Expiry' {
        $script:WebEvent = @{ 'Response' = @{
            'Cookies' = @{}
        } }

        $WebEvent.Response | Add-Member -MemberType ScriptMethod -Name 'AppendCookie' -Value {
            param($c)
            $script:WebEvent.Response.Cookies[$c.Name] = $c
        }

        $c = Set-PodeCookie -Name 'test' -Value 'example' -Expiry ([datetime]::UtcNow.AddDays(2))
        $c | Should Not Be $null
        $c.Name | Should Be 'test'
        $c.Value | Should Be 'example'
        ($c.Expires -gt [datetime]::UtcNow.AddDays(1)) | Should Be $true

        $c = $WebEvent.Response.Cookies['test']
        $c | Should Not Be $null
        $c.Name | Should Be 'test'
        $c.Value | Should Be 'example'
    }
}

Describe 'Update-PodeCookieExpiry' {
    It 'Updates the expiry based on TTL' {
        $WebEvent = @{ 'Response' = @{
            'Cookies' = @{
                'test' = @{ 'Expires' = [datetime]::UtcNow }
            }
        } }

        $script:called = $false
        $WebEvent.Response | Add-Member -MemberType ScriptMethod -Name 'AppendCookie' -Value {
            param($c)
            $script:called = $true
        }

        Update-PodeCookieExpiry -Name 'test' -Ttl 3600
        $called | Should Be $true

        ($WebEvent.Response.Cookies['test'].Expires -gt [datetime]::UtcNow.AddSeconds(3000)) | Should Be $true
    }

    It 'Updates the expiry based on Expiry' {
        $WebEvent = @{ 'Response' = @{
            'Cookies' = @{
                'test' = @{ 'Expires' = [datetime]::UtcNow }
            }
        } }

        $script:called = $false
        $WebEvent.Response | Add-Member -MemberType ScriptMethod -Name 'AppendCookie' -Value {
            param($c)
            $script:called = $true
        }

        Update-PodeCookieExpiry -Name 'test' -Expiry ([datetime]::UtcNow.AddDays(2))
        $called | Should Be $true

        ($WebEvent.Response.Cookies['test'].Expires -gt [datetime]::UtcNow.AddDays(1)) | Should Be $true
    }

    It 'Expiry remains unchanged on 0 TTL' {
        $ttl = [datetime]::UtcNow

        $WebEvent = @{ 'Response' = @{
            'Cookies' = @{
                'test' = @{ 'Expires' = $ttl }
            }
        } }

        $script:called = $false
        $WebEvent.Response | Add-Member -MemberType ScriptMethod -Name 'AppendCookie' -Value {
            param($c)
            $script:called = $true
        }

        Update-PodeCookieExpiry -Name 'test'
        $called | Should Be $true

        $WebEvent.Response.Cookies['test'].Expires | Should Be $ttl
    }

    It 'Expiry remains unchanged on negative TTL' {
        $ttl = [datetime]::UtcNow

        $WebEvent = @{ 'Response' = @{
            'Cookies' = @{
                'test' = @{ 'Expires' = $ttl }
            }
        } }

        $script:called = $false
        $WebEvent.Response | Add-Member -MemberType ScriptMethod -Name 'AppendCookie' -Value {
            param($c)
            $script:called = $true
        }

        Update-PodeCookieExpiry -Name 'test' -Ttl -1
        $called | Should Be $true

        $WebEvent.Response.Cookies['test'].Expires | Should Be $ttl
    }
}

Describe 'Remove-PodeCookie' {
    It 'Flags the cookie for removal' {
        $WebEvent = @{ 'Response' = @{
            'Cookies' = @{
                'test' = @{ 'Discard' = $false; 'Expires' = [datetime]::UtcNow }
            }
        } }

        $script:called = $false
        $WebEvent.Response | Add-Member -MemberType ScriptMethod -Name 'AppendCookie' -Value {
            param($c)
            $script:called = $true
        }

        Remove-PodeCookie -Name 'test'
        $called | Should Be $true

        $WebEvent.Response.Cookies['test'].Discard | Should Be $true
        ($WebEvent.Response.Cookies['test'].Expires -lt [datetime]::UtcNow) | Should Be $true
    }
}

Describe 'Cookie' {
    It 'Throws invalid action error' {
        { Cookie -Action 'MOO' -Name 'test' } | Should Throw "Cannot validate argument on parameter 'Action'"
    }

    It 'Throws error for null name' {
        { Cookie -Action 'Add' -Name $null } | Should Throw "because it is an empty string"
    }

    It 'Throws error for empty name' {
        { Cookie -Action 'Add' -Name ([string]::Empty) } | Should Throw "because it is an empty string"
    }

    It 'Calls add method' {
        Mock Set-PodeCookie { return 'cookie' }
        $c = Cookie -Action Add -Name 'test' -Value 'example'
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

        It 'Returns null for unsign data' {
            Invoke-PodeCookieUnsign -Signature 'value' -Secret 'key' | Should Be $null
        }
    }
}