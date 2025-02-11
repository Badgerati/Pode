[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseUsingScopeModifierInNewRunspaces', '')]
param()
BeforeAll {
    $path = $PSCommandPath
    $src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]integration', '/src/'
    $CertsPath = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]integration', '/tests/certs/'
    Get-ChildItem "$($src)/*.ps1" -Recurse | Resolve-Path | ForEach-Object { . $_ }
}
Describe 'Authentication Requests' {

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

                # Load test keys from PEM files (Assume these exist in the test environment)


                <#           New-PodeAuthBearerScheme -AsJWT -Secret $using:secret | Add-PodeAuth -Name 'BearerJWTSecret' -Sessionless -ScriptBlock {
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

                Add-PodeRoute -Method Get -Path '/auth/bearer/jwt/secret' -Authentication 'BearerJWTSecret' -ScriptBlock {
                    Write-PodeJsonResponse -Value @{ Result = 'OK' }
                }



                New-PodeAuthBearerScheme -AsJWT -Secret $using:secret -Algorithm HS256 -JwtVerificationMode Strict | Add-PodeAuth -Name 'Bearer_JWT_Secret_HS256' -Sessionless -ScriptBlock {
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

                Add-PodeRoute -Method Get -Path '/auth/bearer/jwt/secret/HS256' -Authentication 'Bearer_JWT_Secret_HS256' -ScriptBlock {
                    Write-PodeJsonResponse -Value @{ Result = 'OK' }
                }

                New-PodeAuthBearerScheme -AsJWT -Secret $using:secret -Algorithm HS384  -JwtVerificationMode Strict | Add-PodeAuth -Name 'Bearer_JWT_Secret_HS384' -Sessionless -ScriptBlock {
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

                Add-PodeRoute -Method Get -Path '/auth/bearer/jwt/secret/HS384' -Authentication 'Bearer_JWT_Secret_HS384' -ScriptBlock {
                    Write-PodeJsonResponse -Value @{ Result = 'OK' }
                }#>

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



                $algorithms = 'RS256', 'RS384', 'RS512', 'PS256', 'PS384', 'PS512', 'ES256', 'ES384', 'ES512'
                foreach ($alg in $algorithms) {
                    if ($alg.StartsWith('PS')) {
                        $privateKeyPath = Join-Path -Path $using:CertsPath -ChildPath "$($alg.Replace('PS','RS'))-private.pem"
                        $publicKeyPath = Join-Path -Path $using:CertsPath -ChildPath "$($alg.Replace('PS','RS'))-public.pem"
                    }
                    else {
                        $privateKeyPath = Join-Path -Path $using:CertsPath -ChildPath "$alg-private.pem"
                        $publicKeyPath = Join-Path -Path $using:CertsPath -ChildPath "$alg-public.pem"
                    }

                    if (! (Test-Path $privateKeyPath)) {
                        Write-Warning "⚠️ Skipping $($alg): Private key file not found ($privateKeyPath)"
                        Continue
                    }
                    # Ensure the matching public key exists
                    if (! (Test-Path $publicKeyPath)) {
                        Write-Warning "Skipping $($alg): Public key missing ($publicKeyPath)."
                        Continue
                    }

                    # Read key contents
                    $privateKey = Get-Content $privateKeyPath -Raw | ConvertTo-SecureString -AsPlainText -Force
                    $publicKey = Get-Content $publicKeyPath -Raw

                    # Define the authentication location dynamically (e.g., `/auth/bearer/jwt/{algorithm}`)
                    $pathRoute = "/auth/bearer/jwt/key/lenient/$alg"
                    $rsaPaddingScheme = if ($alg.StartsWith('PS')) { 'Pss' } else { 'Pkcs1V15' }
                    # Register Pode Bearer Authentication
                    Write-PodeHost "🔹 Registering JWT Authentication for: $alg ($Location)"
                    New-PodeAuthBearerScheme  -AsJWT -PrivateKey $privateKey -PublicKey $publicKey -JwtVerificationMode Lenient -RsaPaddingScheme $rsaPaddingScheme |
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

                    New-PodeAuthBearerScheme  -AsJWT -PrivateKey $privateKey -PublicKey $publicKey -JwtVerificationMode Strict -RsaPaddingScheme $rsaPaddingScheme |
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

        Context 'Bearer - Algorithm <_> - Lenient - Path /auth/bearer/jwt/key/<_>' -ForEach (('RS256', 'RS384', 'RS512', 'PS256', 'PS384', 'PS512', 'ES256', 'ES384', 'ES512')) {
            It "Bearer - Algorithm $_ - returns OK for valid key" {
                # Define corresponding private key path
                $privateKeyPath = if ($_.StartsWith('PS')) {
                    Join-Path -Path $CertsPath -ChildPath "$($_.Replace('PS','RS'))-private.pem"
                }
                else {
                    Join-Path -Path $CertsPath -ChildPath "$_-private.pem"
                }

                # Ensure the matching private key exists
                (Test-Path $privateKeyPath) | Should -BeTrue

                # Read key contents
                $privateKey = Get-Content $privateKeyPath -Raw | ConvertTo-SecureString -AsPlainText -Force
                $payload = @{ sub = '123'; username = 'morty' }
                $jwt = ConvertTo-PodeJwt -Payload $payload -Algorithm $_ -PrivateKey $privateKey
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
                    Join-Path -Path $CertsPath -ChildPath "$($_.Replace('PS','RS'))-private.pem"
                }
                else {
                    Join-Path -Path $CertsPath -ChildPath "$_-private.pem"
                }

                # Ensure the matching private key exists
                (Test-Path $privateKeyPath) | Should -BeTrue

                # Read key contents
                $privateKey = Get-Content $privateKeyPath -Raw | ConvertTo-SecureString -AsPlainText -Force
                $payload = @{ sub = '123'; username = 'morty' }
                $jwt = ConvertTo-PodeJwt -Payload $payload -Algorithm $_ -PrivateKey $privateKey -Issuer 'Pode' -Audience $applicationName
                $headers = @{ 'Authorization' = "Bearer $jwt"; 'Accept' = 'application/json' }

                # Make request to correct algorithm path
                $result = Invoke-RestMethod -Uri "$($Endpoint)/auth/bearer/jwt/key/strict/$_" -Method Get -Headers $headers
                $result.Result | Should -Be 'OK'
            }
        }
        # Test invalid algorithm usage (mismatched tokens)

        Context 'Bearer - Algorithm <_> - Lenient - Path /auth/bearer/jwt/key/<_> - 401' -ForEach (('RS256', 'RS384', 'RS512', 'PS256', 'PS384', 'PS512', 'ES256', 'ES384', 'ES512')) {
            It "Bearer - Algorithm $_ - returns 401 for mismatched token ($invalidAlg)" {
                foreach ($invalidAlg in ('RS256', 'RS384', 'RS512', 'PS256', 'PS384', 'PS512', 'ES256', 'ES384', 'ES512')) {
                    if ($invalidAlg -eq $_) { continue }
                    # Define mismatched private key path
                    $privateKeyPath = if ($invalidAlg.StartsWith('PS')) {
                        Join-Path -Path $CertsPath -ChildPath "$($invalidAlg.Replace('PS','RS'))-private.pem"
                    }
                    else {
                        Join-Path -Path $CertsPath -ChildPath "$invalidAlg-private.pem"
                    }
                    # Ensure the mismatched private key exists
                (Test-Path $privateKeyPath) | Should -BeTrue

                    # Read key contents
                    $privateKey = Get-Content $privateKeyPath -Raw | ConvertTo-SecureString -AsPlainText -Force
                    $payload = @{ sub = '123'; username = 'morty' }
                    $jwt = ConvertTo-PodeJwt -Payload $payload -Algorithm $invalidAlg -PrivateKey $privateKey
                    $headers = @{ 'Authorization' = "Bearer $jwt"; 'Accept' = 'application/json' }

                    # Attempt to use an invalid token on a different algorithm's endpoint
                    { Invoke-RestMethod -Uri "$($Endpoint)/auth/bearer/jwt/key/lenient/$_" -Method Get -Headers $headers -ErrorAction Stop } | Should -Throw -ExpectedMessage '*401*'
                }
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