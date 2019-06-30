$path = $MyInvocation.MyCommand.Path
$src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit', '/src/'
Get-ChildItem "$($src)/*.ps1" -Recurse | Resolve-Path | ForEach-Object { . $_ }

Describe 'Start-PodeAzFuncServer' {
    function Push-OutputBinding($Name, $Value) {
        return @{ Name = $Name; Value = $Value }
    }

    Mock Get-PodePublicMiddleware { }
    Mock Get-PodeRouteValidateMiddleware { }
    Mock Get-PodeBodyMiddleware { }
    Mock Get-PodeCookieMiddleware { }
    Mock New-Object { return @{} }
    Mock Get-PodeHeader { return 'some-value' }
    Mock Get-PodeRoute { return @{ Logic = { Write-Host 'Helo' } } }
    Mock Invoke-ScriptBlock { }
    Mock Write-Host { }
    Mock Invoke-PodeEndware { }
    Mock Set-PodeServerHeader { }
    Mock Status { }

    It 'Throws error for null data' {
        { Start-PodeAzFuncServer -Data $null } | Should Throw 'because it is null'
    }

    It 'Runs the server, fails middleware with no route' {
        Mock Invoke-PodeMiddleware { return $false }
        $PodeContext = @{ Server = @{ } }

        $result = Start-PodeAzFuncServer -Data @{
            Request = @{
                Method = 'get'
                Query = @{}
                Url = 'http://example.com'
            };
            sys = @{
                MethodName = 'example'
            }
        }

        $result.Name | Should Be 'Response'
        $result.Value | Should Not Be $null

        Assert-MockCalled Status -Times 0 -Scope It
        Assert-MockCalled Invoke-PodeMiddleware -Times 1 -Scope It
        Assert-MockCalled Get-PodeRoute -Times 0 -Scope It
    }

    It 'Runs the server, using static content path from query' {
        Mock Invoke-PodeMiddleware { return $false }
        $PodeContext = @{ Server = @{ } }

        $result = Start-PodeAzFuncServer -Data @{
            Request = @{
                Method = 'get'
                Query = @{ 'Static-File' = '.a/path/file.txt' }
                Url = 'http://example.com'
            };
            sys = @{
                MethodName = 'example'
            }
        }

        $result.Name | Should Be 'Response'
        $result.Value | Should Not Be $null

        Assert-MockCalled Status -Times 0 -Scope It
        Assert-MockCalled Invoke-PodeMiddleware -Times 1 -Scope It
        Assert-MockCalled Get-PodeRoute -Times 0 -Scope It
    }

    It 'Runs the server, succeeds middleware with route' {
        Mock Invoke-PodeMiddleware { return $true }
        $PodeContext = @{ Server = @{ } }

        $result = Start-PodeAzFuncServer -Data @{
            Request = @{
                Method = 'get'
                Query = @{}
                Url = 'http://example.com'
            };
            sys = @{
                MethodName = 'example'
            }
        }

        $result.Name | Should Be 'Response'
        $result.Value | Should Not Be $null

        Assert-MockCalled Status -Times 0 -Scope It
        Assert-MockCalled Invoke-PodeMiddleware -Times 2 -Scope It
        Assert-MockCalled Get-PodeRoute -Times 1 -Scope It
        Assert-MockCalled Invoke-ScriptBlock -Times 1 -Scope It
    }

    It 'Runs the server, errors in middleware' {
        Mock Invoke-PodeMiddleware { throw 'some error' }
        $PodeContext = @{ Server = @{ } }

        $result = Start-PodeAzFuncServer -Data @{
            Request = @{
                Method = 'get'
                Query = @{}
                Url = 'http://example.com'
            };
            sys = @{
                MethodName = 'example'
            }
        }

        $result.Name | Should Be 'Response'
        $result.Value | Should Not Be $null

        Assert-MockCalled Status -Times 1 -Scope It
        Assert-MockCalled Invoke-PodeMiddleware -Times 1 -Scope It
        Assert-MockCalled Get-PodeRoute -Times 0 -Scope It
    }

    It 'Runs the server, errors in endware' {
        Mock Invoke-PodeMiddleware { return $false }
        Mock Invoke-PodeEndware { throw 'some error' }
        $PodeContext = @{ Server = @{ } }

        $d = @{
            Request = @{
                Method = 'get'
                Query = @{}
                Url = 'http://example.com'
            };
            sys = @{
                MethodName = 'example'
            }
        }

        { Start-PodeAzFuncServer -Data $d } | Should Throw 'some error'

        Assert-MockCalled Status -Times 0 -Scope It
        Assert-MockCalled Invoke-PodeMiddleware -Times 1 -Scope It
        Assert-MockCalled Get-PodeRoute -Times 0 -Scope It
    }
}

Describe 'Start-PodeAwsLambdaServer' {
    Mock Get-PodePublicMiddleware { }
    Mock Get-PodeRouteValidateMiddleware { }
    Mock Get-PodeBodyMiddleware { }
    Mock Get-PodeCookieMiddleware { }
    Mock Get-PodeHeader { return 'some-value' }
    Mock Set-PodeHeader { }
    Mock Get-PodeRoute { return @{ Logic = { Write-Host 'Helo' } } }
    Mock Invoke-ScriptBlock { }
    Mock Write-Host { }
    Mock Invoke-PodeEndware { }
    Mock Set-PodeServerHeader { }
    Mock Status { }

    It 'Throws error for null data' {
        { Start-PodeAwsLambdaServer -Data $null } | Should Throw 'because it is null'
    }

    It 'Runs the server, fails middleware with no route' {
        Mock Invoke-PodeMiddleware { return $false }
        $PodeContext = @{ Server = @{ } }

        $result = Start-PodeAwsLambdaServer -Data @{
            httpMethod = 'get'
            queryStringParameters = @{}
            path = '/api/users'
        }

        $result | Should Not Be $null

        Assert-MockCalled Status -Times 0 -Scope It
        Assert-MockCalled Invoke-PodeMiddleware -Times 1 -Scope It
        Assert-MockCalled Get-PodeRoute -Times 0 -Scope It
    }

    It 'Runs the server, succeeds middleware with route' {
        Mock Invoke-PodeMiddleware { return $true }
        $PodeContext = @{ Server = @{ } }

        $result = Start-PodeAwsLambdaServer -Data @{
            httpMethod = 'get'
            queryStringParameters = @{}
            path = '/api/users'
        }

        $result | Should Not Be $null

        Assert-MockCalled Status -Times 0 -Scope It
        Assert-MockCalled Invoke-PodeMiddleware -Times 2 -Scope It
        Assert-MockCalled Get-PodeRoute -Times 1 -Scope It
        Assert-MockCalled Invoke-ScriptBlock -Times 1 -Scope It
    }

    It 'Runs the server, errors in middleware' {
        Mock Invoke-PodeMiddleware { throw 'some error' }
        $PodeContext = @{ Server = @{ } }

        $result = Start-PodeAwsLambdaServer -Data @{
            httpMethod = 'get'
            queryStringParameters = @{}
            path = '/api/users'
        }

        $result | Should Not Be $null

        Assert-MockCalled Status -Times 1 -Scope It
        Assert-MockCalled Invoke-PodeMiddleware -Times 1 -Scope It
        Assert-MockCalled Get-PodeRoute -Times 0 -Scope It
    }

    It 'Runs the server, errors in endware' {
        Mock Invoke-PodeMiddleware { return $false }
        Mock Invoke-PodeEndware { throw 'some error' }
        $PodeContext = @{ Server = @{ } }

        $d = @{
            httpMethod = 'get'
            queryStringParameters = @{}
            path = '/api/users'
        }

        { Start-PodeAwsLambdaServer -Data $d } | Should Throw 'some error'

        Assert-MockCalled Status -Times 0 -Scope It
        Assert-MockCalled Invoke-PodeMiddleware -Times 1 -Scope It
        Assert-MockCalled Get-PodeRoute -Times 0 -Scope It
    }
}