$path = $MyInvocation.MyCommand.Path
$src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit[\\/]', '/src/'
Get-ChildItem "$($src)/*.ps1" | Resolve-Path | ForEach-Object { . $_ }

$now = [datetime]::UtcNow

Describe 'Get-PodeSessionCookie' {
    Context 'Invalid parameters supplied' {
        It 'Throws null value error' {
            { Get-PodeSessionCookie -Name $null } | Should Throw 'because it is an empty string'
        }

        It 'Throws an empry string value error' {
            { Get-PodeSessionCookie -Name ([string]::Empty) } | Should Throw 'because it is an empty string'
        }
    }

    Context 'Valid parameters' {
        It 'Returns no session details for invalid sessionId' {
            $WebEvent = @{ 'Request' = @{
                'Cookies' = @{}
            } }

            $PodeContext = @{
                'Server' = @{ 'Cookies' = @{ 'Session' = @{
                    'Name' = 'pode.sid';
                    'SecretKey' = 'key';
                    'Info' = @{ 'Duration' = 60; };
                } } }
            }

            $data = Get-PodeSessionCookie -Name 'pode.sid' -Secret 'key'
            $data | Should Be $null
        }

        It 'Returns no session details for invalid signed sessionId' {
            $WebEvent = @{ 'Request' = @{
                'Cookies' = @{
                    'pode.sid' = @{
                        'Value' = 's:value.kPv88V5o2uJ29sqh2a7P/f3dxcg+JdZJZT3GTIE=';
                        'Name' = 'pode.sid';
                        'TimeStamp' = $now;
                    }
                }
            } }

            $PodeContext = @{
                'Server' = @{ 'Cookies' = @{ 'Session' = @{
                    'Name' = 'pode.sid';
                    'SecretKey' = 'key';
                    'Info' = @{ 'Duration' = 60; };
                } } }
            }

            $data = Get-PodeSessionCookie -Name 'pode.sid' -Secret 'key'
            $data | Should Be $null
        }

        It 'Returns session details' {
            $WebEvent = @{ 'Request' = @{
                'Cookies' = @{
                    'pode.sid' = @{
                        'Value' = 's:value.kPv88V50o2uJ29sqch2a7P/f3dxcg+J/dZJZT3GTJIE=';
                        'Name' = 'pode.sid';
                        'TimeStamp' = $now;
                    }
                }
            } }

            $PodeContext = @{
                'Server' = @{ 'Cookies' = @{ 'Session' = @{
                    'Name' = 'pode.sid';
                    'SecretKey' = 'key';
                    'Info' = @{ 'Duration' = 60; };
                } } }
            }

            $data = Get-PodeSessionCookie -Name 'pode.sid' -Secret 'key'
            $data | Should Not Be $null
            $data.Id | Should Be 'value'
            $data.Name | Should Be 'pode.sid'
            $data.Cookie.TimeStamp | Should Be $now
            $data.Cookie.Duration | Should Be 60
        }
    }
}

Describe 'Set-PodeSessionCookieDataHash' {
    Context 'Invalid parameters supplied' {
        It 'Throws null value error' {
            { Set-PodeSessionCookieDataHash -Session $null } | Should Throw 'argument is null'
        }
    }

    Context 'Valid parameters' {
        It 'Sets a hash for no data' {
            $Session = @{}
            Set-PodeSessionCookieDataHash -Session $Session
            $Session.Data | Should Not Be $null

            $crypto = [System.Security.Cryptography.SHA256]::Create()
            $hash = $crypto.ComputeHash([System.Text.Encoding]::UTF8.GetBytes(($Session.Data| ConvertTo-Json)))
            $hash = [System.Convert]::ToBase64String($hash)

            $Session.DataHash | Should Be $hash
        }

        It 'Sets a hash for data' {
            $Session = @{ 'Data' = @{ 'Counter' = 2; } }
            Set-PodeSessionCookieDataHash -Session $Session
            $Session.Data | Should Not Be $null

            $crypto = [System.Security.Cryptography.SHA256]::Create()
            $hash = $crypto.ComputeHash([System.Text.Encoding]::UTF8.GetBytes(($Session.Data| ConvertTo-Json)))
            $hash = [System.Convert]::ToBase64String($hash)

            $Session.DataHash | Should Be $hash
        }
    }
}

Describe 'New-PodeSessionCookie' {
    Mock 'Invoke-ScriptBlock' { return 'value' }

    It 'Creates a new session object' {
        $PodeContext = @{
            'Server' = @{ 'Cookies' = @{ 'Session' = @{
                'Name' = 'pode.sid';
                'SecretKey' = 'key';
                'Info' = @{ 'Duration' = 60; };
                'GenerateId' = {}
            } } }
        }

        $session = New-PodeSessionCookie

        $session | Should Not Be $null
        $session.Id | Should Be 'value'
        $session.Name | Should Be 'pode.sid'
        $session.Data.Count | Should Be 0
        $session.Cookie.Duration | Should Be 60

        $crypto = [System.Security.Cryptography.SHA256]::Create()
        $hash = $crypto.ComputeHash([System.Text.Encoding]::UTF8.GetBytes(($session.Data| ConvertTo-Json)))
        $hash = [System.Convert]::ToBase64String($hash)

        $session.DataHash | Should Be $hash
    }
}

Describe 'Test-PodeSessionCookieDataHash' {
    Context 'Invalid parameters supplied' {
        It 'Throws null value error' {
            { Test-PodeSessionCookieDataHash -Session $null } | Should Throw 'argument is null'
        }
    }

    Context 'Valid parameters' {
        It 'Returns false for no hash set' {
            $Session = {}
            Test-PodeSessionCookieDataHash -Session $Session | Should Be $false
        }

        It 'Returns false for invalid hash' {
            $Session = @{ 'DataHash' = 'fake' }
            Test-PodeSessionCookieDataHash -Session $Session | Should Be $false
        }

        It 'Returns true for a valid hash' {
            $Session = @{
                'Data' = @{ 'Counter' = 2; };
            }

            $crypto = [System.Security.Cryptography.SHA256]::Create()
            $hash = $crypto.ComputeHash([System.Text.Encoding]::UTF8.GetBytes(($Session.Data| ConvertTo-Json)))
            $hash = [System.Convert]::ToBase64String($hash)
            $Session.DataHash = $hash

            Test-PodeSessionCookieDataHash -Session $Session | Should Be $true
        }
    }
}

Describe 'Get-PodeSessionCookieInMemStore' {
    It 'Returns a valid storage object' {
        $store = Get-PodeSessionCookieInMemStore
        $store | Should Not Be $null

        $members = @(($store | Get-Member).Name)
        $members.Contains('Memory' ) | Should Be $true
        $members.Contains('Delete' ) | Should Be $true
        $members.Contains('Get' ) | Should Be $true
        $members.Contains('Set' ) | Should Be $true
    }
}

Describe 'Set-PodeSessionCookieInMemClearDown' {
    It 'Adds a new schedule for clearing down' {
        $PodeContext = @{ 'Schedules' = @{}}
        Set-PodeSessionCookieInMemClearDown
        $PodeContext.Schedules.Count | Should Be 1
        $PodeContext.Schedules.Contains('__pode_session_inmem_cleanup__') | Should Be $true
    }
}

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