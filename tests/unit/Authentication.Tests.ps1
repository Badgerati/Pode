$path = $MyInvocation.MyCommand.Path
$src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit', '/src/'
Get-ChildItem "$($src)/*.ps1" -Recurse | Resolve-Path | ForEach-Object { . $_ }

$now = [datetime]::UtcNow

Describe 'Set-PodeAuthStatus' {
    Mock Move-PodeResponseUrl {}
    Mock Set-PodeResponseStatus {}

    It 'Redirects to a failure URL' {
        Set-PodeAuthStatus -StatusCode 500 -Options @{'Failure' = @{ 'Url' = 'url'} } | Should Be $false
        Assert-MockCalled Move-PodeResponseUrl -Times 1 -Scope It
        Assert-MockCalled Set-PodeResponseStatus -Times 0 -Scope It
    }

    It 'Sets status to failure' {
        Set-PodeAuthStatus -StatusCode 500 -Options @{} | Should Be $false
        Assert-MockCalled Move-PodeResponseUrl -Times 0 -Scope It
        Assert-MockCalled Set-PodeResponseStatus -Times 1 -Scope It
    }

    It 'Redirects to a success URL' {
        Set-PodeAuthStatus -Options @{'Success' = @{ 'Url' = 'url' } } | Should Be $false
        Assert-MockCalled Move-PodeResponseUrl -Times 1 -Scope It
        Assert-MockCalled Set-PodeResponseStatus -Times 0 -Scope It
    }

    It 'Returns true for next middleware' {
        Set-PodeAuthStatus -Options @{} | Should Be $true
        Assert-MockCalled Move-PodeResponseUrl -Times 0 -Scope It
        Assert-MockCalled Set-PodeResponseStatus -Times 0 -Scope It
    }
}

Describe 'Get-PodeAuthBasicType' {
    It 'Returns form auth type' {
        $result = Get-PodeAuthBasicType
        $result | Should Not Be $null
        $result.GetType().Name | Should Be 'ScriptBlock'
    }
}

Describe 'Get-PodeAuthFormType' {
    It 'Returns basic auth type' {
        $result = Get-PodeAuthFormType
        $result | Should Not Be $null
        $result.GetType().Name | Should Be 'ScriptBlock'
    }
}

Describe 'Get-PodeAuthInbuiltMethod' {
    It 'Returns Windows AD auth' {
        $result = Get-PodeAuthInbuiltMethod -Type WindowsAd
        $result | Should Not Be $null
        $result.GetType().Name | Should Be 'ScriptBlock'
    }
}

Describe 'Get-PodeAuthMiddlewareScript' {
    It 'Returns auth middleware' {
        $result = Get-PodeAuthMiddlewareScript
        $result | Should Not Be $null
        $result.GetType().Name | Should Be 'ScriptBlock'
    }
}

Describe 'Remove-PodeAuthSession' {
    It 'Removes the user, and kills the session' {
        Mock Remove-PodeSessionCookie {}

        $event = @{
            Auth = @{ User = @{} }
            Session = @{
                Data = @{
                    Auth = @{ User = @{} }
                }
            }
            Middleware = @{
                Options = @{
                    Failure = @{
                        Url = 'http://fake.com'
                    }
                }
            }
        }

        Remove-PodeAuthSession -Event $event

        $event.Auth.Count | Should Be 0
        $event.Auth.User | Should Be $null
        $event.Session.Data.Auth | Should be $null
        $event.Middleware.Options.Failure.Url | Should Be 'http://fake.com'

        Assert-MockCalled Remove-PodeSessionCookie -Times 1 -Scope It
    }

    It 'Removes the user, and kills the session, redirecting to root' {
        Mock Remove-PodeSessionCookie {}

        $event = @{
            Auth = @{ User = @{} }
            Session = @{
                Data = @{
                    Auth = @{ User = @{} }
                }
            }
            Middleware = @{
                Options = @{
                    Failure = @{}
                }
            }
            Request = @{
                Url = @{ AbsolutePath ='/' }
            }
        }

        Remove-PodeAuthSession -Event $event

        $event.Auth.Count | Should Be 0
        $event.Auth.User | Should Be $null
        $event.Session.Data.Auth | Should be $null
        $event.Middleware.Options.Failure.Url | Should Be '/'

        Assert-MockCalled Remove-PodeSessionCookie -Times 1 -Scope It
    }
}