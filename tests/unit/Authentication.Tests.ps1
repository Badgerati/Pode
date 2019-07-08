$path = $MyInvocation.MyCommand.Path
$src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit', '/src/'
Get-ChildItem "$($src)/*.ps1" -Recurse | Resolve-Path | ForEach-Object { . $_ }

$now = [datetime]::UtcNow

Describe 'Set-PodeAuthStatus' {
    Mock Move-PodeResponseUrl {}
    Mock Set-PodeResponseStatus {}

    It 'Redirects to a failure URL' {
        Set-PodeAuthStatus -StatusCode 500 -Options @{'FailureUrl' = 'url'} | Should Be $false
        Assert-MockCalled Move-PodeResponseUrl -Times 1 -Scope It
        Assert-MockCalled Set-PodeResponseStatus -Times 0 -Scope It
    }

    It 'Sets status to failure' {
        Set-PodeAuthStatus -StatusCode 500 -Options @{} | Should Be $false
        Assert-MockCalled Move-PodeResponseUrl -Times 0 -Scope It
        Assert-MockCalled Set-PodeResponseStatus -Times 1 -Scope It
    }

    It 'Redirects to a success URL' {
        Set-PodeAuthStatus -Options @{'SuccessUrl' = 'url'} | Should Be $false
        Assert-MockCalled Move-PodeResponseUrl -Times 1 -Scope It
        Assert-MockCalled Set-PodeResponseStatus -Times 0 -Scope It
    }

    It 'Returns true for next middleware' {
        Set-PodeAuthStatus -Options @{} | Should Be $true
        Assert-MockCalled Move-PodeResponseUrl -Times 0 -Scope It
        Assert-MockCalled Set-PodeResponseStatus -Times 0 -Scope It
    }
}

Describe 'Get-PodeAuthBasic' {
    Context 'Invalid parameters supplied' {
        It 'Throws empty name error' {
            { Get-PodeAuthBasic -Name ([string]::Empty) -ScriptBlock {} } | Should Throw 'argument is null'
        }

        It 'Throws null name error' {
            { Get-PodeAuthBasic -Name $null -ScriptBlock {} } | Should Throw 'argument is null'
        }

        It 'Throws null script error' {
            { Get-PodeAuthBasic -ScriptBlock $null } | Should Throw 'argument is null'
        }
    }

    Context 'Valid parameters' {
        It 'Returns auth data' {
            $result = Get-PodeAuthBasic -Name 'Basic' -ScriptBlock { Write-Host 'Hello' }

            $result | Should Not Be $null
            $result.Name | Should Be 'Basic'

            $result.Parser | Should Not Be $null
            $result.Parser.GetType().Name | Should Be 'ScriptBlock'

            $result.Validator | Should Not Be $null
            $result.Validator.GetType().Name | Should Be 'ScriptBlock'
            $result.Validator.ToString() | Should Be ({ Write-Host 'Hello' }).ToString()
        }
    }
}

Describe 'Get-PodeAuthForm' {
    Context 'Invalid parameters supplied' {
        It 'Throws empty name error' {
            { Get-PodeAuthForm -Name ([string]::Empty) -ScriptBlock {} } | Should Throw 'argument is null'
        }

        It 'Throws null name error' {
            { Get-PodeAuthForm -Name $null -ScriptBlock {} } | Should Throw 'argument is null'
        }

        It 'Throws null script error' {
            { Get-PodeAuthForm -ScriptBlock $null } | Should Throw 'argument is null'
        }
    }

    Context 'Valid parameters' {
        It 'Returns auth data' {
            $result = Get-PodeAuthForm -Name 'Form' -ScriptBlock { Write-Host 'Hello' }

            $result | Should Not Be $null
            $result.Name | Should Be 'Form'

            $result.Parser | Should Not Be $null
            $result.Parser.GetType().Name | Should Be 'ScriptBlock'

            $result.Validator | Should Not Be $null
            $result.Validator.GetType().Name | Should Be 'ScriptBlock'
            $result.Validator.ToString() | Should Be ({ Write-Host 'Hello' }).ToString()
        }
    }
}