[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseUsingScopeModifierInNewRunspaces', '')]
param()
BeforeAll {
    $path = $PSCommandPath
    $src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]integration', '/src/'
    $CertsPath = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]integration', '/tests/certs/'
    Get-ChildItem "$($src)/*.ps1" -Recurse | Resolve-Path | ForEach-Object { . $_ }
}

Describe 'JWT Bearer Authentication Requests' { #-Tag 'No_DesktopEdition' {

    BeforeAll {
        $Port = 8080
        $Endpoint = "http://127.0.0.1:$($Port)"
        $secret = (ConvertTo-SecureString 'MySecretKey' -AsPlainText -Force)
        $applicationName = 'JWTAuthentication'

        Start-Job -Name 'Pode' -ErrorAction Stop -ScriptBlock {
            Import-Module -Name "$($using:PSScriptRoot)\..\..\src\Pode.psm1"

            Start-PodeServer -Quiet -ApplicationName $using:applicationName  -ScriptBlock {
                Add-PodeEndpoint -Address localhost -Port $using:Port -Protocol Http

                New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging
                Add-PodeRoute -Method Get -Path '/close' -ScriptBlock {
                    Close-PodeServer
                }

                foreach ($alg in ('HS256', 'HS384', 'HS512')) {
                    New-PodeAuthBearerScheme -AsJWT -Secret $using:secret -Algorithm $alg -JwtVerificationMode Strict | Add-PodeAuth -Name "Bearer_JWT_Secret_strict_$alg" -Sessionless -ScriptBlock {
                        param($jwt)

                        # here you'd check a real user storage, this is just for example
                        if ($jwt.username -ieq 'morty') {
                            return @{
                                User = @{
                                    ID   = $jWt.id
                                    Name = $jst.name
                                    Type = $jst.type
                                }
                            }
                        }

                        return $null
                    }

                    Add-PodeRoute -Method Get -Path "/auth/bearer/jwt/secret/strict/$alg" -Authentication "Bearer_JWT_Secret_strict_$alg" -ScriptBlock {
                        Write-PodeJsonResponse -Value @{ Result = 'OK' }
                    }

                    New-PodeAuthBearerScheme -AsJWT -Secret $using:secret -Algorithm $alg -JwtVerificationMode Lenient | Add-PodeAuth -Name "Bearer_JWT_Secret_lenient_$alg" -Sessionless -ScriptBlock {
                        param($jwt)

                        # here you'd check a real user storage, this is just for example
                        if ($jwt.username -ieq 'morty') {
                            return @{
                                User = @{
                                    ID   = $jWt.id
                                    Name = $jst.name
                                    Type = $jst.type
                                }
                            }
                        }

                        return $null
                    }

                    Add-PodeRoute -Method Get -Path "/auth/bearer/jwt/secret/lenient/$alg" -Authentication "Bearer_JWT_Secret_lenient_$alg" -ScriptBlock {
                        Write-PodeJsonResponse -Value @{ Result = 'OK' }
                    }
                }


                $securePassword = ConvertTo-SecureString 'MySecurePassword' -AsPlainText -Force
                $algorithms = 'RS256', 'RS384', 'RS512', 'PS256', 'PS384', 'PS512', 'ES256', 'ES384', 'ES512'
                foreach ($alg in $algorithms) {
                    if ($alg.StartsWith('PS')) {
                        $privateKeyPath = Join-Path -Path $using:CertsPath -ChildPath "$($alg.Replace('PS','RS')).pfx"

                    }
                    else {
                        $privateKeyPath = Join-Path -Path $using:CertsPath -ChildPath "$alg.pfx"
                    }

                    if (! (Test-Path $privateKeyPath)) {
                        Write-Warning "Skipping $($alg): Private key file not found ($privateKeyPath)"
                        Continue
                    }

                    # Define the authentication location dynamically (e.g., `/auth/bearer/jwt/{algorithm}`)
                    $pathRoute = "/auth/bearer/jwt/key/lenient/$alg"
                    $rsaPaddingScheme = if ($alg.StartsWith('PS')) { 'Pss' } else { 'Pkcs1V15' }
                    # Register Pode Bearer Authentication
                    $param = @{
                        AsJWT               = $true
                        RsaPaddingScheme    = $rsaPaddingScheme
                        JwtVerificationMode = 'Lenient'
                        PfxPath             = $privateKeyPath
                        PfxPassword         = $securePassword
                    }

                    New-PodeAuthBearerScheme  @param |
                        Add-PodeAuth -Name "Bearer_JWT_lenient_$alg" -Sessionless -ScriptBlock {
                            param($jwt)

                            # here you'd check a real user storage, this is just for example
                            if ($jwt.username -ieq 'morty') {
                                return @{
                                    User = @{
                                        ID   = $jWt.id
                                        Name = $jst.name
                                        Type = $jst.type
                                    }
                                }
                            }

                            return $null
                        }

                    # GET request to get list of users (since there's no session, authentication will always happen)
                    Add-PodeRoute -Method Get -Path  "/auth/bearer/jwt/key/lenient/$alg" -Authentication "Bearer_JWT_lenient_$alg" -ScriptBlock {
                        Write-PodeJsonResponse -Value @{ Result = 'OK' }
                    }

                    $param.JwtVerificationMode = 'Strict'
                    New-PodeAuthBearerScheme  @param |
                        Add-PodeAuth -Name "Bearer_JWT_strict_$alg" -Sessionless -ScriptBlock {
                            param($jwt)

                            # here you'd check a real user storage, this is just for example
                            if ($jwt.username -ieq 'morty') {
                                return @{
                                    User = @{
                                        ID   = $jWt.id
                                        Name = $jst.name
                                        Type = $jst.type
                                    }
                                }
                            }

                            return $null
                        }

                    # GET request to get list of users (since there's no session, authentication will always happen)
                    Add-PodeRoute -Method Get -Path  "/auth/bearer/jwt/key/strict/$alg" -Authentication "Bearer_JWT_strict_$alg" -ScriptBlock {
                        Write-PodeJsonResponse -Value @{ Result = 'OK' }
                    }
                }
            }
        }

        Start-Sleep -Seconds 20
    }

    AfterAll {
        Receive-Job -Name 'Pode' | Out-Default
        Invoke-RestMethod -Uri "$($Endpoint)/close" -Method Get | Out-Null
        Get-Job -Name 'Pode' | Remove-Job -Force
    }



    Describe 'Bearer Authentication - JWT Algorithms' {
        BeforeAll {
            $securePassword = ConvertTo-SecureString 'MySecurePassword' -AsPlainText -Force
        }
        Context 'Bearer - Algorithm <_> - Lenient - Path /auth/bearer/jwt/key/<_>' -ForEach (('RS256', 'RS384', 'RS512', 'PS256', 'PS384', 'PS512', 'ES256', 'ES384', 'ES512')) {
            It "Bearer - Algorithm $_ - returns OK for valid key" {
                # Define corresponding private key path
                $privateKeyPath = if ($_.StartsWith('PS')) {
                    Join-Path -Path $CertsPath -ChildPath "$($_.Replace('PS','RS')).pfx"
                    $rsaPaddingScheme = 'Pss'
                }
                else {
                    Join-Path -Path $CertsPath -ChildPath "$_.pfx"
                    $rsaPaddingScheme = 'Pkcs1V15'
                }

                # Ensure the matching private key exists
                (Test-Path $privateKeyPath) | Should -BeTrue

                # Read key contents
                $payload = @{ sub = '123'; username = 'morty' }
                $jwt = ConvertTo-PodeJwt -PfxPath $privateKeyPath -RsaPaddingScheme $rsaPaddingScheme -PfxPassword $securePassword -Payload $payload
                $headers = @{ 'Authorization' = "Bearer $jwt"; 'Accept' = 'application/json' }

                # Make request to correct algorithm path
                $result = Invoke-RestMethod -Uri "$($Endpoint)/auth/bearer/jwt/key/lenient/$_" -Method Get -Headers $headers
                $result.Result | Should -Be 'OK'
            }
        }

        Context 'Bearer - Algorithm <_> - Strict - Path /auth/bearer/jwt/key/strict<_>' -ForEach (('RS256', 'RS384', 'RS512', 'PS256', 'PS384', 'PS512', 'ES256', 'ES384', 'ES512')) {
            It "Bearer - Algorithm $_ - returns OK for valid key" {
                # Define corresponding private key path
                $privateKeyPath = if ($_.StartsWith('PS')) {
                    Join-Path -Path $CertsPath -ChildPath "$($_.Replace('PS','RS')).pfx"
                    $rsaPaddingScheme = 'Pss'
                }
                else {
                    Join-Path -Path $CertsPath -ChildPath "$_.pfx"
                    $rsaPaddingScheme = 'Pkcs1V15'
                }

                # Ensure the matching private key exists
                (Test-Path $privateKeyPath) | Should -BeTrue

                $payload = @{ sub = '123'; username = 'morty' }
                $params = @{
                    Payload          = $payload
                    PfxPath          = $privateKeyPath
                    PfxPassword      = $securePassword
                    RsaPaddingScheme = $rsaPaddingScheme
                    Issuer           = 'Pode'
                    Audience         = $applicationName
                }
                $jwt = ConvertTo-PodeJwt  @params
                $headers = @{ 'Authorization' = "Bearer $jwt"; 'Accept' = 'application/json' }

                # Make request to correct algorithm path
                $result = Invoke-RestMethod -Uri "$($Endpoint)/auth/bearer/jwt/key/strict/$_" -Method Get -Headers $headers
                $result.Result | Should -Be 'OK'
            }
        }
    }

    Describe 'Bearer - Algorithm <_> - Lenient - Path /auth/bearer/jwt/secret/lenient/<_>'  -ForEach ('HS256', 'HS384', 'HS512') {
        It "Bearer - Algorithm $_ - returns OK for valid key" {
            $payload = @{ sub = '123'; username = 'morty' }
            $jwt = ConvertTo-PodeJwt -Payload $payload -Algorithm $_ -Secret $secret
            $headers = @{ 'Authorization' = "Bearer $jwt"; 'Accept' = 'application/json' }
            $result = Invoke-RestMethod -Uri "$($Endpoint)/auth/bearer/jwt/secret/lenient/$_" -Method Get -Headers $headers
            $result.Result | Should -Be 'OK'
        }


        It 'Bearer - Algorithm <_> - returns OK without issuer in lenient mode' {
            $payload = @{ sub = '123'; username = 'morty'; aud = $applicationName }  # Missing 'iss'
            $jwt = ConvertTo-PodeJwt -Payload $payload -Algorithm $_ -Secret $secret
            $headers = @{ 'Authorization' = "Bearer $jwt"; 'Accept' = 'application/json' }
            $result = Invoke-RestMethod -Uri "$($Endpoint)/auth/bearer/jwt/secret/lenient/$_" -Method Get -Headers $headers
            $result.Result | Should -Be 'OK'
        }

        It 'Bearer - Algorithm <_> - returns OK without audience in lenient mode' {
            $payload = @{ sub = '123'; username = 'morty'; iss = 'Pode' }  # Missing 'aud'
            $jwt = ConvertTo-PodeJwt -Payload $payload -Algorithm $_ -Secret $secret -Issuer 'Pode'
            $headers = @{ 'Authorization' = "Bearer $jwt"; 'Accept' = 'application/json' }
            $result = Invoke-RestMethod -Uri "$($Endpoint)/auth/bearer/jwt/secret/lenient/$_" -Method Get -Headers $headers
            $result.Result | Should -Be 'OK'
        }

        It 'Bearer - Algorithm <_> - returns OK with incorrect issuer' {
            $payload = @{ sub = '123'; username = 'morty'; iss = 'FakeIssuer'; aud = $applicationName }
            $jwt = ConvertTo-PodeJwt -Payload $payload -Algorithm $_ -Secret $secret -Issuer 'FakeIssuer' -Audience $applicationName
            $headers = @{ 'Authorization' = "Bearer $jwt"; 'Accept' = 'application/json' }
            $result = Invoke-RestMethod -Uri "$($Endpoint)/auth/bearer/jwt/secret/lenient/$_" -Method Get -Headers $headers
            $result.Result | Should -Be 'OK'
        }

        It 'Bearer - Algorithm <_> - returns OK with incorrect audience' {
            $payload = @{ sub = '123'; username = 'morty'; iss = 'Pode'; aud = 'WrongApp' }
            $jwt = ConvertTo-PodeJwt -Payload $payload -Algorithm $_ -Secret $secret -Issuer 'Pode' -Audience 'WrongApp'
            $headers = @{ 'Authorization' = "Bearer $jwt"; 'Accept' = 'application/json' }
            $result = Invoke-RestMethod -Uri "$($Endpoint)/auth/bearer/jwt/secret/lenient/$_" -Method Get -Headers $headers
            $result.Result | Should -Be 'OK'
        }

    }

    # Strict mode for HS256
    Describe 'Bearer - Algorithm <_> - Strict - Path /auth/bearer/jwt/secret/strict/<_>'  -ForEach ('HS256', 'HS384', 'HS512') {
        It "Bearer - Algorithm $_ - returns OK for valid key" {
            $payload = @{ sub = '123'; username = 'morty' }
            $jwt = ConvertTo-PodeJwt -Payload $payload -Algorithm $_ -Secret $secret -Issuer 'Pode' -Audience $applicationName
            $headers = @{ 'Authorization' = "Bearer $jwt"; 'Accept' = 'application/json' }
            $result = Invoke-RestMethod -Uri "$($Endpoint)/auth/bearer/jwt/secret/strict/$_" -Method Get -Headers $headers
            $result.Result | Should -Be 'OK'
        }

        It 'Bearer - Algorithm <_> - returns 401 for invalid algorithm' {
            foreach ($invalidAlg in ('HS256', 'HS384', 'HS512')) {
                if ($invalidAlg -eq $_) { continue }
                $payload = @{ sub = '123'; username = 'morty' }
                $jwt = ConvertTo-PodeJwt -Payload $payload -Algorithm $invalidAlg -Secret $secret -Issuer 'Pode' -Audience $applicationName
                $headers = @{ 'Authorization' = "Bearer $jwt"; 'Accept' = 'application/json' }
                { Invoke-RestMethod -Uri "$($Endpoint)/auth/bearer/jwt/secret/strict/$_" -Method Get -Headers $headers -ErrorAction Stop } | Should -Throw -ExpectedMessage '*401*'
            }
        }

        It 'Bearer - Algorithm <_> - rejects token without issuer in strict mode' {
            $payload = @{ sub = '123'; username = 'morty'; aud = $applicationName }  # Missing 'iss'
            $jwt = ConvertTo-PodeJwt -Payload $payload -Algorithm $_ -Secret $secret
            $headers = @{ 'Authorization' = "Bearer $jwt"; 'Accept' = 'application/json' }
            { Invoke-RestMethod -Uri "$($Endpoint)/auth/bearer/jwt/secret/strict/$_" -Method Get -Headers $headers -ErrorAction Stop } | Should -Throw -ExpectedMessage '*401*'
        }

        It 'Bearer - Algorithm <_> - rejects token without audience in strict mode' {
            $payload = @{ sub = '123'; username = 'morty'; iss = 'Pode' }  # Missing 'aud'
            $jwt = ConvertTo-PodeJwt -Payload $payload -Algorithm $_ -Secret $secret -Issuer 'Pode'
            $headers = @{ 'Authorization' = "Bearer $jwt"; 'Accept' = 'application/json' }
            { Invoke-RestMethod -Uri "$($Endpoint)/auth/bearer/jwt/secret/strict/$_" -Method Get -Headers $headers -ErrorAction Stop } | Should -Throw -ExpectedMessage '*401*'
        }

        It 'Bearer - Algorithm <_> - rejects token with incorrect issuer' {
            $payload = @{ sub = '123'; username = 'morty'; iss = 'FakeIssuer'; aud = $applicationName }
            $jwt = ConvertTo-PodeJwt -Payload $payload -Algorithm $_ -Secret $secret -Issuer 'FakeIssuer' -Audience $applicationName
            $headers = @{ 'Authorization' = "Bearer $jwt"; 'Accept' = 'application/json' }
            { Invoke-RestMethod -Uri "$($Endpoint)/auth/bearer/jwt/secret/strict/$_" -Method Get -Headers $headers -ErrorAction Stop } | Should -Throw -ExpectedMessage '*401*'
        }

        It 'Bearer - Algorithm <_> - rejects token with incorrect audience' {
            $payload = @{ sub = '123'; username = 'morty'; iss = 'Pode'; aud = 'WrongApp' }
            $jwt = ConvertTo-PodeJwt -Payload $payload -Algorithm $_ -Secret $secret -Issuer 'Pode' -Audience 'WrongApp'
            $headers = @{ 'Authorization' = "Bearer $jwt"; 'Accept' = 'application/json' }
            { Invoke-RestMethod -Uri "$($Endpoint)/auth/bearer/jwt/secret/strict/$_" -Method Get -Headers $headers -ErrorAction Stop } | Should -Throw -ExpectedMessage '*401*'
        }
    }
}