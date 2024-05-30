[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseUsingScopeModifierInNewRunspaces', '')]
param()

BeforeAll {
    $path = $PSCommandPath
    $src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]integration', '/src/'
    Get-ChildItem "$($src)/*.ps1" -Recurse | Resolve-Path | ForEach-Object { . $_ }
    Import-LocalizedData -BindingVariable msgTable -BaseDirectory (Join-Path -Path $src -ChildPath 'Locales') -UICulture 'en-us' -FileName 'Pode'

}

Describe 'Authentication Requests' {

    BeforeAll {
        $Port = 8080
        $Endpoint = "http://127.0.0.1:$($Port)"

        Start-Job -Name 'Pode' -ErrorAction Stop -ScriptBlock {
            Import-Module -Name "$($using:PSScriptRoot)\..\..\src\Pode.psm1"

            Start-PodeServer -Quiet -ScriptBlock {
                Add-PodeEndpoint -Address localhost -Port $using:Port -Protocol Http

                New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging
                Add-PodeRoute -Method Get -Path '/close' -ScriptBlock {
                    Close-PodeServer
                }

                # BASIC
                New-PodeAuthScheme -Basic | Add-PodeAuth -Name 'BasicAuth' -Sessionless -ScriptBlock {
                    param($username, $password)

                    if (($username -eq 'morty') -and ($password -eq 'pickle')) {
                        return @{ User = @{ ID = 'M0R7Y302' } }
                    }

                    return @{ Message = 'Invalid details supplied' }
                }

                Add-PodeRoute -Method Post -Path '/auth/basic' -Authentication 'BasicAuth' -ScriptBlock {
                    Write-PodeJsonResponse -Value @{ Result = 'OK' }
                }

                # BEARER
                New-PodeAuthScheme -Bearer -Scope write | Add-PodeAuth -Name 'BearerAuth' -Sessionless -ScriptBlock {
                    param($token)

                    if ($token -ieq 'test-token') {
                        return @{
                            User  = @{ ID = 'M0R7Y302' }
                            Scope = 'write'
                        }
                    }

                    return $null
                }

                Add-PodeRoute -Method Get -Path '/auth/bearer' -Authentication 'BearerAuth' -ScriptBlock {
                    Write-PodeJsonResponse -Value @{ Result = 'OK' }
                }

                # API KEY
                New-PodeAuthScheme -ApiKey | Add-PodeAuth -Name 'ApiKeyAuth' -Sessionless -ScriptBlock {
                    param($key)

                    if ($key -ieq 'test-key') {
                        return @{
                            User = @{ ID = 'M0R7Y302' }
                        }
                    }

                    return $null
                }

                Add-PodeRoute -Method Get -Path '/auth/apikey' -Authentication 'ApiKeyAuth' -ScriptBlock {
                    Write-PodeJsonResponse -Value @{ Result = 'OK' }
                }

                # API KEY - JWT (not signed)
                New-PodeAuthScheme -ApiKey -AsJWT | Add-PodeAuth -Name 'ApiKeyNotSignedJwtAuth' -Sessionless -ScriptBlock {
                    param($jwt)

                    if ($jwt.username -ieq 'morty') {
                        return @{
                            User = @{ ID = 'M0R7Y302' }
                        }
                    }

                    return $null
                }

                Add-PodeRoute -Method Get -Path '/auth/apikey/jwt/notsigned' -Authentication 'ApiKeyNotSignedJwtAuth' -ScriptBlock {
                    Write-PodeJsonResponse -Value @{ Result = 'OK' }
                }

                # API KEY - JWT (signed)
                New-PodeAuthScheme -ApiKey -AsJWT -Secret 'secret' | Add-PodeAuth -Name 'ApiKeySignedJwtAuth' -Sessionless -ScriptBlock {
                    param($jwt)

                    if ($jwt.username -ieq 'morty') {
                        return @{
                            User = @{ ID = 'M0R7Y302' }
                        }
                    }

                    return $null
                }

                Add-PodeRoute -Method Get -Path '/auth/apikey/jwt/signed' -Authentication 'ApiKeySignedJwtAuth' -ScriptBlock {
                    Write-PodeJsonResponse -Value @{ Result = 'OK' }
                }

                # FORM (Monocle?)
            }
        }

        Start-Sleep -Seconds 10
    }

    AfterAll {
        Receive-Job -Name 'Pode' | Out-Default
        Invoke-RestMethod -Uri "$($Endpoint)/close" -Method Get | Out-Null
        Get-Job -Name 'Pode' | Remove-Job -Force
    }


    # BASIC
    It 'basic - returns ok for valid creds' {
        $result = Invoke-RestMethod -Uri "$($Endpoint)/auth/basic" -Method Post -Headers @{ Authorization = 'Basic bW9ydHk6cGlja2xl' }
        $result.Result | Should -Be 'OK'
    }

    It 'basic - returns 401 for invalid creds' {
        { Invoke-RestMethod -Uri "$($Endpoint)/auth/basic" -Method Post -Headers @{ Authorization = 'Basic cmljazpwaWNrbGU=' } -ErrorAction Stop } | Should -Throw -ExpectedMessage '*401*'
    }

    It 'basic - returns 400 for invalid base64' {
        { Invoke-RestMethod -Uri "$($Endpoint)/auth/basic" -Method Post -Headers @{ Authorization = 'Basic cmlazpwaNrbGU' } -ErrorAction Stop } | Should -Throw -ExpectedMessage '*400*'
    }


    # BEARER
    It 'bearer - returns ok for valid token' {
        $result = Invoke-RestMethod -Uri "$($Endpoint)/auth/bearer" -Method Get -Headers @{ Authorization = 'Bearer test-token' }
        $result.Result | Should -Be 'OK'
    }

    It 'bearer - returns 401 for invalid token' {
        { Invoke-RestMethod -Uri "$($Endpoint)/auth/bearer" -Method Get -Headers @{ Authorization = 'Bearer fake-token' } -ErrorAction Stop } | Should -Throw -ExpectedMessage '*401*'
    }

    It 'bearer - returns 400 for no token' {
        { Invoke-RestMethod -Uri "$($Endpoint)/auth/bearer" -Method Get -Headers @{ Authorization = 'Bearer' } -ErrorAction Stop } | Should -Throw -ExpectedMessage '*400*'
    }


    # API KEY
    It 'apikey - returns ok for valid key' {
        $result = Invoke-RestMethod -Uri "$($Endpoint)/auth/apikey" -Method Get -Headers @{ 'X-API-KEY' = 'test-key' }
        $result.Result | Should -Be 'OK'
    }

    It 'apikey - returns 401 for invalid key' {
        { Invoke-RestMethod -Uri "$($Endpoint)/auth/apikey" -Method Get -Headers @{ 'X-API-KEY' = 'fake-key' } -ErrorAction Stop } | Should -Throw -ExpectedMessage '*401*'
    }

    It 'apikey - returns 400 for no key' {
        { Invoke-RestMethod -Uri "$($Endpoint)/auth/apikey" -Method Get -ErrorAction Stop } | Should -Throw -ExpectedMessage '*400*'
    }


    # API KEY - JWT (not signed)
    It 'apikey - jwt not signed - returns ok for valid key' {
        $header = @{ alg = 'none' }
        $payload = @{ sub = '123'; username = 'morty' }
        $jwt = ConvertTo-PodeJwt -Header $header -Payload $payload

        $result = Invoke-RestMethod -Uri "$($Endpoint)/auth/apikey/jwt/notsigned" -Method Get -Headers @{ 'X-API-KEY' = $jwt }
        $result.Result | Should -Be 'OK'
    }

    It 'apikey - jwt not signed - returns 400 for invalid key - invalid base64' {
        $header = @{ alg = 'none' }
        $payload = @{ sub = '123'; username = 'morty' }
        $jwt = ConvertTo-PodeJwt -Header $header -Payload $payload

        { Invoke-RestMethod -Uri "$($Endpoint)/auth/apikey/jwt/notsigned" -Method Get -Headers @{ 'X-API-KEY' = "hh$($jwt)" } -ErrorAction Stop } | Should -Throw -ExpectedMessage '*400*'
    }

    It 'apikey - jwt not signed - returns 401 for invalid key - invalid username' {
        $header = @{ alg = 'none' }
        $payload = @{ sub = '123'; username = 'rick' }
        $jwt = ConvertTo-PodeJwt -Header $header -Payload $payload

        { Invoke-RestMethod -Uri "$($Endpoint)/auth/apikey/jwt/notsigned" -Method Get -Headers @{ 'X-API-KEY' = $jwt } -ErrorAction Stop } | Should -Throw -ExpectedMessage '*401*'
    }

    It 'apikey - jwt not signed - returns 400 for invalid key - expired' {
        $header = @{ alg = 'none' }
        $payload = @{ sub = '123'; username = 'morty'; exp = 100 }
        $jwt = ConvertTo-PodeJwt -Header $header -Payload $payload

        { Invoke-RestMethod -Uri "$($Endpoint)/auth/apikey/jwt/notsigned" -Method Get -Headers @{ 'X-API-KEY' = $jwt } -ErrorAction Stop } | Should -Throw -ExpectedMessage '*400*'
    }

    It 'apikey - jwt not signed - returns 400 for invalid key - not started' {
        $header = @{ alg = 'none' }
        $payload = @{ sub = '123'; username = 'morty'; nbf = ([System.DateTimeOffset]::Now.AddYears(1).ToUnixTimeSeconds()) }
        $jwt = ConvertTo-PodeJwt -Header $header -Payload $payload

        { Invoke-RestMethod -Uri "$($Endpoint)/auth/apikey/jwt/notsigned" -Method Get -Headers @{ 'X-API-KEY' = $jwt } -ErrorAction Stop } | Should -Throw -ExpectedMessage '*400*'
    }


    # API KEY - JWT (signed)
    It 'apikey - jwt signed - returns ok for valid key' {
        $header = @{ alg = 'hs256' }
        $payload = @{ sub = '123'; username = 'morty' }
        $jwt = ConvertTo-PodeJwt -Header $header -Payload $payload -Secret 'secret'

        $result = Invoke-RestMethod -Uri "$($Endpoint)/auth/apikey/jwt/signed" -Method Get -Headers @{ 'X-API-KEY' = $jwt }
        $result.Result | Should -Be 'OK'
    }

    It 'apikey - jwt signed - returns ok for valid key - valid exp/nbf' {
        $header = @{ alg = 'hs256' }
        $payload = @{
            sub      = '123'
            username = 'morty'
            nbf      = ([System.DateTimeOffset]::Now.AddDays(-1).ToUnixTimeSeconds())
            exp      = ([System.DateTimeOffset]::Now.AddDays(1).ToUnixTimeSeconds())
        }
        $jwt = ConvertTo-PodeJwt -Header $header -Payload $payload -Secret 'secret'

        $result = Invoke-RestMethod -Uri "$($Endpoint)/auth/apikey/jwt/signed" -Method Get -Headers @{ 'X-API-KEY' = $jwt }
        $result.Result | Should -Be 'OK'
    }

    It 'apikey - jwt signed - returns 400 for invalid key - invalid base64' {
        $header = @{ alg = 'hs256' }
        $payload = @{ sub = '123'; username = 'morty' }
        $jwt = ConvertTo-PodeJwt -Header $header -Payload $payload -Secret 'secret'

        { Invoke-RestMethod -Uri "$($Endpoint)/auth/apikey/jwt/signed" -Method Get -Headers @{ 'X-API-KEY' = "hh$($jwt)" } -ErrorAction Stop } | Should -Throw -ExpectedMessage '*400*'
    }

    It 'apikey - jwt signed - returns 400 for invalid key - invalid signature' {
        $header = @{ alg = 'hs256' }
        $payload = @{ sub = '123'; username = 'morty' }
        $jwt = ConvertTo-PodeJwt -Header $header -Payload $payload -Secret 'secret'

        { Invoke-RestMethod -Uri "$($Endpoint)/auth/apikey/jwt/signed" -Method Get -Headers @{ 'X-API-KEY' = "$($jwt)hh" } -ErrorAction Stop } | Should -Throw -ExpectedMessage '*400*'
    }

    It 'apikey - jwt signed - returns 400 for invalid key - invalid secret' {
        $header = @{ alg = 'hs256' }
        $payload = @{ sub = '123'; username = 'morty' }
        $jwt = ConvertTo-PodeJwt -Header $header -Payload $payload -Secret 'fake'

        { Invoke-RestMethod -Uri "$($Endpoint)/auth/apikey/jwt/signed" -Method Get -Headers @{ 'X-API-KEY' = $jwt } -ErrorAction Stop } | Should -Throw -ExpectedMessage '*400*'
    }

    It 'apikey - jwt signed - returns 400 for invalid key - none algorithm' {
        $header = @{ alg = 'none' }
        $payload = @{ sub = '123'; username = 'morty' }
        $jwt = ConvertTo-PodeJwt -Header $header -Payload $payload

        { Invoke-RestMethod -Uri "$($Endpoint)/auth/apikey/jwt/signed" -Method Get -Headers @{ 'X-API-KEY' = $jwt } -ErrorAction Stop } | Should -Throw -ExpectedMessage '*400*'
    }

    It 'apikey - jwt signed - returns 401 for invalid key - invalid username' {
        $header = @{ alg = 'hs256' }
        $payload = @{ sub = '123'; username = 'rick' }
        $jwt = ConvertTo-PodeJwt -Header $header -Payload $payload -Secret 'secret'

        { Invoke-RestMethod -Uri "$($Endpoint)/auth/apikey/jwt/signed" -Method Get -Headers @{ 'X-API-KEY' = $jwt } -ErrorAction Stop } | Should -Throw -ExpectedMessage '*401*'
    }
}