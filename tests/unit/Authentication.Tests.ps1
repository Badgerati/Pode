[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
param()
BeforeAll {
    $path = $PSCommandPath
    $src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit', '/src/'
    Get-ChildItem "$($src)/*.ps1" -Recurse | Resolve-Path | ForEach-Object { . $_ }
}

$now = [datetime]::UtcNow

Describe 'Set-PodeAuthStatus' {
    BeforeAll {
        Mock Move-PodeResponseUrl {}
        Mock Set-PodeResponseStatus {}

        $PodeContext = @{
            Server = @{
                Authentications = @{
                    Methods = @{
                        ExampleAuth = @{
                            Failure = @{ Url = '/url' }
                            Success = @{ Url = '/url' }
                            Cache   = @{}
                        }
                    }
                }
            }
        } }

    It 'Redirects to a failure URL' {
        Set-PodeAuthStatus -StatusCode 500 -Name ExampleAuth | Should -Be $false
        Assert-MockCalled Move-PodeResponseUrl -Times 1 -Scope It
        Assert-MockCalled Set-PodeResponseStatus -Times 0 -Scope It
    }

    It 'Sets status to failure' {
        Set-PodeAuthStatus -StatusCode 500 -Name ExampleAuth | Should -Be $false
        Assert-MockCalled Move-PodeResponseUrl -Times 1 -Scope It
        Assert-MockCalled Set-PodeResponseStatus -Times 0 -Scope It
    }

    It 'Redirects to a success URL' {
        Set-PodeAuthStatus -Name ExampleAuth -LoginRoute | Should -Be $false
        Assert-MockCalled Move-PodeResponseUrl -Times 1 -Scope It
        Assert-MockCalled Set-PodeResponseStatus -Times 0 -Scope It
    }

    It 'Returns true for next middleware' {
        Set-PodeAuthStatus -Name ExampleAuth -NoSuccessRedirect | Should -Be $true
        Assert-MockCalled Move-PodeResponseUrl -Times 0 -Scope It
        Assert-MockCalled Set-PodeResponseStatus -Times 0 -Scope It
    }
}

Describe 'Get-PodeAuthBasicType' {
    It 'Returns form auth type' {
        $result = Get-PodeAuthBasicType
        $result | Should -Not -Be $null
        $result.GetType().Name | Should -Be 'ScriptBlock'
    }
}

Describe 'Get-PodeAuthFormType' {
    It 'Returns basic auth type' {
        $result = Get-PodeAuthFormType
        $result | Should -Not -Be $null
        $result.GetType().Name | Should -Be 'ScriptBlock'
    }
}

Describe 'Get-PodeAuthInbuiltMethod' {
    It 'Returns Windows AD auth' {
        $result = Get-PodeAuthWindowsADMethod
        $result | Should -Not -Be $null
        $result.GetType().Name | Should -Be 'ScriptBlock'
    }
}

Describe 'Get-PodeAuthMiddlewareScript' {
    It 'Returns auth middleware' {
        $result = Get-PodeAuthMiddlewareScript
        $result | Should -Not -Be $null
        $result.GetType().Name | Should -Be 'ScriptBlock'
    }
}

Describe 'Remove-PodeAuthSession' {
    It 'Removes the user, and kills the session' {
        Mock Revoke-PodeSession {}

        $WebEvent = @{
            Auth    = @{ User = @{} }
            Session = @{
                Data = @{
                    Auth = @{ User = @{} }
                }
            }
        }

        Remove-PodeAuthSession

        $WebEvent.Auth.Count | Should -Be 0
        $WebEvent.Auth.User | Should -Be $null
        $WebEvent.Session.Data.Auth | Should -Be $null

        Assert-MockCalled Revoke-PodeSession -Times 1 -Scope It
    }

    It 'Removes the user, and kills the session, redirecting to root' {
        Mock Revoke-PodeSession {}

        $WebEvent = @{
            Auth    = @{ User = @{} }
            Session = @{
                Data = @{
                    Auth = @{ User = @{} }
                }
            }
            Request = @{
                Url = @{ AbsolutePath = '/' }
            }
        }

        Remove-PodeAuthSession

        $WebEvent.Auth.Count | Should -Be 0
        $WebEvent.Auth.User | Should -Be $null
        $WebEvent.Session.Data.Auth | Should -Be $null

        Assert-MockCalled Revoke-PodeSession -Times 1 -Scope It
    }
}

Describe 'Test-PodeJwt' {
    It 'No exception - sucessful validation' {
        (Test-PodeJwt @{}) | Should -Be $null
    }

    It 'Throws exception - the JWT has expired' {
        # "exp" (Expiration Time) Claim
        { Test-PodeJwt @{exp = 1 } } | Should -Throw -ExceptionType ([System.Exception]) -ExpectedMessage 'The JWT has expired'
    }

    It 'Throws exception - the JWT is not yet valid for use' {
        # "nbf" (Not Before) Claim
        { Test-PodeJwt @{nbf = 99999999999 } } | Should -Throw -ExceptionType ([System.Exception]) -ExpectedMessage 'The JWT is not yet valid for use'
    }
}


Describe "Expand-PodeAuthMerge Tests" {
    BeforeAll {
        # Mock the $PodeContext variable
        $PodeContext = @{
            Server = @{
                Authentications = @{
                    Methods = @{
                        BasicAuth = @{ Name = 'BasicAuth'; merged = $false }
                        ApiKeyAuth = @{ Name = 'ApiKeyAuth'; merged = $false }
                        CustomMergedAuth = @{ Name = 'CustomMergedAuth'; merged = $true; Authentications = @('BasicAuth', 'ApiKeyAuth') }
                    }
                }
            }
        }
    }

    It "Expands discrete authentication methods correctly" {
        $expandedAuthNames = Expand-PodeAuthMerge -Names @('BasicAuth', 'ApiKeyAuth')
        $expandedAuthNames | Should -Contain 'BasicAuth'
        $expandedAuthNames | Should -Contain 'ApiKeyAuth'
        $expandedAuthNames.Count | Should -Be 2
    }

    It "Expands merged authentication methods into individual components" {
        $expandedAuthNames = Expand-PodeAuthMerge -Names @('CustomMergedAuth')
        $expandedAuthNames | Should -Contain 'BasicAuth'
        $expandedAuthNames | Should -Contain 'ApiKeyAuth'
        $expandedAuthNames.Count | Should -Be 2
    }

    It "Handles anonymous access special case" {
        $expandedAuthNames = Expand-PodeAuthMerge -Names @('%_allowanon_%')
        $expandedAuthNames | Should -Contain '%_allowanon_%'
        $expandedAuthNames.Count | Should -Be 1
    }

    It "Handles empty and invalid inputs" {
        { Expand-PodeAuthMerge -Names @() } | Should -Throw
        { Expand-PodeAuthMerge -Names @('NonExistentAuth') } | Should -Throw
    }

}
