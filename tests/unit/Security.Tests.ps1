[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '')]
param()

BeforeAll {
    $path = $PSCommandPath
    $src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit', '/src/'
    Get-ChildItem "$($src)/*.ps1" -Recurse | Resolve-Path | ForEach-Object { . $_ }
    Import-LocalizedData -BindingVariable PodeLocale -BaseDirectory (Join-Path -Path $src -ChildPath 'Locales') -FileName 'Pode'

    $PodeContext = @{ 'Server' = $null; }
}

Describe 'Add-PodeLimitRule' {
    BeforeAll {
        Mock Add-PodeLimitRateRule { }
        Mock New-PodeLimitIPComponent { return @{} }
    }

    Context 'Valid parameters' {
        It 'Adds single IP address' {
            Add-PodeLimitRule -Type 'IP' -Values '127.0.0.1' -Limit 1 -Seconds 1
            Assert-MockCalled New-PodeLimitIPComponent -Times 1 -Scope It
            Assert-MockCalled Add-PodeLimitRateRule -Times 1 -Scope It
        }

        It 'Adds single subnet' {
            Add-PodeLimitRule -Type 'IP' -Values '10.10.0.0/24' -Limit 1 -Seconds 1
            Assert-MockCalled New-PodeLimitIPComponent -Times 1 -Scope It
            Assert-MockCalled Add-PodeLimitRateRule -Times 1 -Scope It
        }

        It 'Adds 3 IP addresses' {
            Add-PodeLimitRule -Type 'IP' -Values @('127.0.0.1', '127.0.0.2', '127.0.0.3') -Limit 1 -Seconds 1
            Assert-MockCalled New-PodeLimitIPComponent -Times 1 -Scope It
            Assert-MockCalled Add-PodeLimitRateRule -Times 1 -Scope It
        }

        It 'Adds 3 subnets' {
            Add-PodeLimitRule -Type 'IP' -Value @('10.10.0.0/24', '10.10.1.0/24', '10.10.2.0/24') -Limit 1 -Seconds 1
            Assert-MockCalled New-PodeLimitIPComponent -Times 1 -Scope It
            Assert-MockCalled Add-PodeLimitRateRule -Times 1 -Scope It
        }
    }
}

Describe 'Add-PodeAccessRule' {
    BeforeAll {
        Mock Add-PodeLimitAccessRule { }
        Mock New-PodeLimitIPComponent { return @{} }
    }
    Context 'Valid parameters' {
        It 'Adds single IP address' {
            Add-PodeAccessRule -Access 'Allow' -Type 'IP' -Values '127.0.0.1'
            Assert-MockCalled New-PodeLimitIPComponent -Times 1 -Scope It
            Assert-MockCalled Add-PodeLimitAccessRule -Times 1 -Scope It
        }

        It 'Adds single subnet' {
            Add-PodeAccessRule -Access 'Allow' -Type 'IP' -Values '10.10.0.0/24'
            Assert-MockCalled New-PodeLimitIPComponent -Times 1 -Scope It
            Assert-MockCalled Add-PodeLimitAccessRule -Times 1 -Scope It
        }

        It 'Adds 3 IP addresses' {
            Add-PodeAccessRule -Access 'Allow' -Type 'IP' -Values @('127.0.0.1', '127.0.0.2', '127.0.0.3')
            Assert-MockCalled New-PodeLimitIPComponent -Times 1 -Scope It
            Assert-MockCalled Add-PodeLimitAccessRule -Times 1 -Scope It
        }

        It 'Adds 3 subnets' {
            Add-PodeAccessRule -Access 'Allow' -Type 'IP' -Values @('10.10.0.0/24', '10.10.1.0/24', '10.10.2.0/24')
            Assert-MockCalled New-PodeLimitIPComponent -Times 1 -Scope It
            Assert-MockCalled Add-PodeLimitAccessRule -Times 1 -Scope It
        }
    }
}

Describe 'Enable-PodeCsrfMiddleware' {
    It 'Enables the main CSRF middleware' {
        Mock Initialize-PodeCsrf {}
        Mock New-PodeMiddleware { return @{} }
        Mock Add-PodeMiddleware {}

        Enable-PodeCsrfMiddleware

        Assert-MockCalled New-PodeMiddleware -Times 1 -Scope It
        Assert-MockCalled Add-PodeMiddleware -Times 1 -Scope It
    }
}

Describe 'Get-PodeCsrfMiddleware' {
    It 'Returns CSRF verification middleware' {
        Mock Test-PodeCsrfConfigured { return $true }
        Mock New-PodeMiddleware { return { write-host 'hello' } }

        (Get-PodeCsrfMiddleware).ToString() | Should -Be ({ write-host 'hello' }).ToString()
    }
}

Describe 'New-PodeCsrfToken' {
    It 'Returns a token' {
        Mock Test-PodeCsrfConfigured { return $true }
        Mock New-PodeCsrfSecret { return 'secret' }
        Mock New-PodeSalt { return 'salt' }
        Mock Invoke-PodeSHA256Hash { return 'salt-secret' }
        New-PodeCsrfToken | Should -Be 't:salt.salt-secret'
    }
}

Describe 'Initialize-PodeCsrf' {
    It 'Runs csrf setup using sessions' {
        $PodeContext = @{ 'Server' = @{ 'Cookies' = @{
                    'Csrf' = @{ 'Name' = 'Key' }
                }
            }
        }

        Mock Test-PodeCsrfConfigured { return $false }
        Mock Test-PodeSessionsEnabled { return $true }
        Mock Get-PodeCookieSecret { return 'secret' }

        Initialize-PodeCsrf -IgnoreMethods @('Get')

        $PodeContext.Server.Cookies.Csrf.Name | Should -Be 'pode.csrf'
        $PodeContext.Server.Cookies.Csrf.UseCookies | Should -Be $false
        $PodeContext.Server.Cookies.Csrf.Secret | Should -Be ''
        $PodeContext.Server.Cookies.Csrf.IgnoredMethods | Should -Be @('Get')
    }

    It 'Runs csrf setup using cookies' {
        $PodeContext = @{ 'Server' = @{ 'Cookies' = @{
                    'Csrf' = @{ 'Name' = 'Key' }
                }
            }
        }

        Mock Test-PodeCsrfConfigured { return $false }
        Mock Test-PodeSessionsEnabled { return $false }
        Mock Get-PodeCookieSecret { return 'secret' }

        Initialize-PodeCsrf -IgnoreMethods @('Get') -UseCookies

        $PodeContext.Server.Cookies.Csrf.Name | Should -Be 'pode.csrf'
        $PodeContext.Server.Cookies.Csrf.UseCookies | Should -Be $true
        $PodeContext.Server.Cookies.Csrf.Secret | Should -Be 'secret'
        $PodeContext.Server.Cookies.Csrf.IgnoredMethods | Should -Be @('Get')
    }
}

Describe 'Get-PodeCsrfToken' {
    It 'Returns the token from the payload' {
        $PodeContext = @{ 'Server' = @{ 'Cookies' = @{
                    'Csrf' = @{ 'Name' = 'Key' }
                }
            }
        }

        $WebEvent = @{ 'Data' = @{
                'Key' = 'Token'
            }
        }

        Get-PodeCsrfToken | Should -Be 'Token'
    }

    It 'Returns the token from the query string' {
        $PodeContext = @{ 'Server' = @{ 'Cookies' = @{
                    'Csrf' = @{ 'Name' = 'Key' }
                }
            }
        }

        $WebEvent = @{
            'Data'  = @{}
            'Query' = @{ 'Key' = 'Token' }
        }

        Get-PodeCsrfToken | Should -Be 'Token'
    }

    It 'Returns the token from the headers' {
        $PodeContext = @{ 'Server' = @{ 'Cookies' = @{
                    'Csrf' = @{ 'Name' = 'Key' }
                }
            }
        }

        $WebEvent = @{
            'Data'    = @{}
            'Query'   = @{}
            'Request' = @{ 'Headers' = @{ 'Key' = 'Token' } }
        }

        Get-PodeCsrfToken | Should -Be 'Token'
    }

    It 'Returns no token' {
        $PodeContext = @{ 'Server' = @{ 'Cookies' = @{
                    'Csrf' = @{ 'Name' = 'Key' }
                }
            }
        }

        $WebEvent = @{
            'Data'    = @{}
            'Query'   = @{}
            'Request' = @{ 'Headers' = @{} }
        }

        Get-PodeCsrfToken | Should -Be $null
    }
}

Describe 'Test-PodeCsrfToken' {
    It 'Returns false for no secret' {
        Test-PodeCsrfToken -Secret '' -Token 'value' | Should -Be $false
    }

    It 'Returns false for no token' {
        Test-PodeCsrfToken -Secret 'key' -Token '' | Should -Be $false
    }

    It 'Returns false for no tag on token' {
        Test-PodeCsrfToken -Secret 'key' -Token 'value' | Should -Be $false
    }

    It 'Returns false for no period in token' {
        Test-PodeCsrfToken -Secret 'key' -Token 't:value' | Should -Be $false
    }

    It 'Returns false for token mismatch' {
        Mock New-PodeCsrfToken { return 'value2' }
        Test-PodeCsrfToken -Secret 'key' -Token 't:value1.signed' | Should -Be $false
    }

    It 'Returns true for token match' {
        Mock Restore-PodeCsrfToken { return 't:value1.signed' }
        Test-PodeCsrfToken -Secret 'key' -Token 't:value1.signed' | Should -Be $true
    }
}

Describe 'New-PodeCsrfSecret' {
    It 'Returns an existing secret' {
        Mock Get-PodeCsrfSecret { return 'key' }
        New-PodeCsrfSecret | Should -Be 'key'
    }

    It 'Returns a new secret' {
        Mock Get-PodeCsrfSecret { return '' }
        Mock New-PodeGuid { return 'new-key' }
        Mock Set-PodeCsrfSecret { }
        New-PodeCsrfSecret | Should -Be 'new-key'
    }
}

Describe 'New-PodeCsrfToken' {

    It 'Throws error for csrf not being configured' {
        $PodeContext = @{ 'Server' = @{
                'Cookies' = @{ 'Csrf' = $null }
            }
        }

        { New-PodeCsrfToken } | Should -Throw -ExpectedMessage $PodeLocale.csrfMiddlewareNotInitializedExceptionMessage #CSRF Middleware has not been initialized.
    }



    It 'Returns a token for new secret/salt' {
        Mock Invoke-PodeSHA256Hash { return "$($Value)" }

        $PodeContext = @{ 'Server' = @{
                'Cookies' = @{ 'Csrf' = @{ 'key' = 'value' } }
            }
        }
        Mock New-PodeCsrfSecret { return 'new-key' }
        Mock New-PodeSalt { return 'new-salt' }
        New-PodeCsrfToken | Should -Be 't:new-salt.new-salt-new-key'
    }
}

Describe 'Restore-PodeCsrfToken' {
    BeforeAll { Mock Invoke-PodeSHA256Hash { return "$($Value)" }

        $PodeContext = @{ 'Server' = @{
                'Cookies' = @{ 'Csrf' = @{ 'key' = 'value' } }
            }
        } }

    It 'Returns a token for an existing secret/salt' {

        Restore-PodeCsrfToken -Secret 'key' -Salt 'salt' | Should -Be 't:salt.salt-key'
    }
}

Describe 'Set-PodeCsrfSecret' {
    BeforeAll {
        $PodeContext = @{ 'Server' = @{
                'Cookies' = @{ 'Csrf' = @{ 'Name' = 'pode.csrf' } }
            }
        } }

    It 'Sets the secret agaisnt the session' {
        $PodeContext.Server.Cookies.Csrf.UseCookies = $false
        $WebEvent = @{ 'Session' = @{
                'Data' = @{}
            }
        }

        Set-PodeCsrfSecret -Secret 'some-secret'

        $WebEvent.Session.Data['pode.csrf'] | Should -Be 'some-secret'
    }

    It 'Sets the secret agaisnt a cookie' {
        $PodeContext.Server.Cookies.Csrf.UseCookies = $true
        Mock Set-PodeCookie { }

        Set-PodeCsrfSecret -Secret 'some-secret'

        Assert-MockCalled Set-PodeCookie -Times 1 -Scope It
    }
}

Describe 'Get-PodeCsrfSecret' {
    BeforeAll {
        $PodeContext = @{ 'Server' = @{
                'Cookies' = @{ 'Csrf' = @{ 'Name' = 'pode.csrf' } }
            }
        } }

    It 'Gets the secret from the session' {
        $PodeContext.Server.Cookies.Csrf.UseCookies = $false
        $WebEvent = @{ 'Session' = @{
                'Data' = @{ 'pode.csrf' = 'some-secret' }
            }
        }

        Get-PodeCsrfSecret | Should -Be 'some-secret'
    }

    It 'Gets the secret from a cookie' {
        $PodeContext.Server.Cookies.Csrf.UseCookies = $true
        Mock Get-PodeCookie { return @{ 'Value' = 'some-secret' } }

        Get-PodeCsrfSecret | Should -Be 'some-secret'

        Assert-MockCalled Get-PodeCookie -Times 1 -Scope It
    }
}