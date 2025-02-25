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
                if (!(Test-Path -Path $using:CertsPath -PathType Container)) {
                    New-Item -Path $using:CertsPath -ItemType Directory
                }

                #     $securePassword = ConvertTo-SecureString 'MySecurePassword' -AsPlainText -Force

                $certificateTypes = @{
                    'RS256' = @{
                        KeyType          = 'RSA'
                        KeyLength        = 2048
                        RsaPaddingScheme = 'Pkcs1V15'
                    }
                    'RS384' = @{
                        KeyType          = 'RSA'
                        KeyLength        = 3072
                        RsaPaddingScheme = 'Pkcs1V15'
                    }
                    'RS512' = @{
                        KeyType          = 'RSA'
                        KeyLength        = 4096
                        RsaPaddingScheme = 'Pkcs1V15'
                    }
                    'PS256' = @{
                        KeyType          = 'RSA'
                        KeyLength        = 2048
                        RsaPaddingScheme = 'Pss'
                    }
                    'PS384' = @{
                        KeyType          = 'RSA'
                        KeyLength        = 3072
                        RsaPaddingScheme = 'Pss'
                    }
                    'PS512' = @{
                        KeyType          = 'RSA'
                        KeyLength        = 4096
                        RsaPaddingScheme = 'Pss'
                    }
                    'ES256' = @{
                        KeyType   = 'ECDSA'
                        KeyLength = 256
                    }
                    'ES384' = @{
                        KeyType   = 'ECDSA'
                        KeyLength = 384
                    }
                    'ES512' = @{
                        KeyType   = 'ECDSA'
                        KeyLength = 521
                    }
                }
                foreach ($alg in $certificateTypes.Keys) {
                    $x509Certificate = New-PodeSelfSignedCertificate -Loopback -KeyType $certificateTypes[$alg].KeyType -KeyLength $certificateTypes[$alg].KeyLength -CertificatePurpose CodeSigning -Ephemeral -Exportable

                    Export-PodeCertificate -Certificate $x509Certificate -Format PFX -FilePath "$using:CertsPath/$alg"
                    $rsaPaddingScheme = if ($alg.StartsWith('PS')) { 'Pss' } else { 'Pkcs1V15' }



                    # Define the authentication location dynamically (e.g., `/auth/bearer/jwt/{algorithm}`)
                    $pathRoute = "/auth/bearer/jwt/key/lenient/$alg"
                    # Register Pode Bearer Authentication
                    $param = @{
                        AsJWT               = $true
                        RsaPaddingScheme    = $rsaPaddingScheme
                        JwtVerificationMode = 'Lenient'
                        X509Certificate     = $x509Certificate
                        #    CertificatePassword = $securePassword
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


                #lifecycle

                # Register Pode Bearer Authentication
                New-PodeAuthBearerScheme -AsJWT -JwtVerificationMode Strict -SelfSigned |
                    Add-PodeAuth -Name 'Bearer_JWT_SelfSigned' -Sessionless -ScriptBlock {
                        param($jwt)

                        # here you'd check a real user storage, this is just for example
                        if ($jwt.id -ieq 'M0R7Y302') {
                            return @{
                                User = @{
                                    ID       = $jWt.id
                                    Name     = $jWt.name
                                    Type     = $jWt.type
                                    sub      = $jWt.Id
                                    username = $jWt.Username
                                    groups   = $jWt.Groups
                                }
                            }
                        }
                        else {
                            write-podehost $jwt -Explode
                        }

                        return $null
                    }


                Add-PodeRoute -Method Post -Path '/auth/bearer/jwt/login' -ScriptBlock {
                    try {
                        # In a real scenario, you'd validate the incoming credentials from $WebEvent.data
                        $username = $WebEvent.Data.username
                        $password = $WebEvent.Data.password
                        $user = if ($username -eq 'morty' -and $password -eq 'pickle') {
                            @{
                                Id       = 'M0R7Y302'
                                Username = 'morty.smith'
                                Name     = 'Morty Smith'
                                Groups   = 'Domain Users'
                            }
                        }
                        if (!$user) {
                            throw 'Invalid credentials'
                        }
                        $payload = @{
                            sub      = $user.Id
                            name     = $user.Name
                            username = $user.Username
                            id       = $user.Id
                            groups   = $user.Groups
                            type     = 'human'
                        }

                        # If valid, generate a JWT that matches the 'ExampleApiKeyCert' scheme
                        $jwt = ConvertTo-PodeJwt  -Payload $payload -Authentication 'Bearer_JWT_SelfSigned' -Expiration 600
                        Write-PodeJsonResponse -StatusCode 200 -Value @{
                            'success' = $true
                            'user'    = $user
                            'jwt'     = $jwt
                        }

                    }
                    catch {
                        write-podehost $_.Exception.Message
                        Write-PodeJsonResponse -StatusCode 401 -Value @{ error = 'Invalid credentials' }
                    }
                }

                Add-PodeRoute  -Method Post -Path '/auth/bearer/jwt/renew' -Authentication 'Bearer_JWT_SelfSigned' -ScriptBlock {
                    try {

                        $jwt = Update-PodeJwt -ExpirationExtension 6000

                        Write-PodeJsonResponse -StatusCode 200 -Value @{
                            'success' = $true
                            'jwt'     = $jwt
                        }
                    }
                    catch {
                        Write-PodeJsonResponse -StatusCode 401 -Value @{ error = 'Invalid JWT token supplied' }
                    }
                }

                Add-PodeRoute  -Method Post -Path '/auth/bearer/jwt/info' -Authentication 'Bearer_JWT_SelfSigned' -ScriptBlock {
                    try {
                        $jwtInfo = ConvertFrom-PodeJwt -Outputs  'Header,Payload,Signature' -HumanReadable
                        Write-PodeJsonResponse -StatusCode 200 -Value $jwtInfo
                    }
                    catch {
                        Write-PodeJsonResponse -StatusCode 401 -Value @{ error = 'Invalid JWT token supplied' }
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
        if ( (Test-Path -Path $CertsPath -PathType Container)) {
            Remove-Item -Path $CertsPath  -Recurse -Force
            Write-Output "$CertsPath removed."
        }
    }



    Describe 'Bearer Authentication - JWT Algorithms' {

        Context 'Bearer - Algorithm <_> - Lenient - Path /auth/bearer/jwt/key/<_>' -ForEach (('RS256', 'RS384', 'RS512', 'PS256', 'PS384', 'PS512', 'ES256', 'ES384', 'ES512')) {
            It "Bearer - Algorithm $_ - returns OK for valid key" {

                # Define corresponding private key path
                $privateKeyPath = "$CertsPath/$_.pfx"
                # Ensure the matching private key exists
                (Test-Path $privateKeyPath) | Should -BeTrue

                $rsaPaddingScheme = if ($_.StartsWith('PS')) { 'Pss' } else { 'Pkcs1V15' }

                # Read key contents
                $payload = @{ sub = '123'; username = 'morty' }
                $jwt = ConvertTo-PodeJwt -Certificate $privateKeyPath -RsaPaddingScheme $rsaPaddingScheme   -Payload $payload
                $headers = @{ 'Authorization' = "Bearer $jwt"; 'Accept' = 'application/json' }

                # Make request to correct algorithm path
                $result = Invoke-RestMethod -Uri "$($Endpoint)/auth/bearer/jwt/key/lenient/$_" -Method Get -Headers $headers
                $result.Result | Should -Be 'OK'
            }
        }

        Context 'Bearer - Algorithm <_> - Strict - Path /auth/bearer/jwt/key/strict<_>' -ForEach (('RS256', 'RS384', 'RS512', 'PS256', 'PS384', 'PS512', 'ES256', 'ES384', 'ES512')) {
            It "Bearer - Algorithm $_ - returns OK for valid key" {
                # Define corresponding private key path
                $privateKeyPath = "$CertsPath/$_.pfx"
                # Ensure the matching private key exists
                (Test-Path $privateKeyPath) | Should -BeTrue

                $rsaPaddingScheme = if ($_.StartsWith('PS')) { 'Pss' } else { 'Pkcs1V15' }

                $payload = @{ sub = '123'; username = 'morty' }
                $params = @{
                    Payload          = $payload
                    Certificate      = $privateKeyPath
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

    Describe 'JWT Authentication Workflow' {
        BeforeAll {
            $Headers = @{
                'accept'       = 'application/json'
                'Content-Type' = 'application/json'
            }
        }

        It 'Logs in and retrieves a JWT token' {
            $Body = @{
                username = 'morty'
                password = 'pickle'
            } | ConvertTo-Json -Depth 10

            $Response = Invoke-RestMethod -Uri "$($Endpoint)/auth/bearer/jwt/login" `
                -Method Post `
                -Headers $Headers `
                -Body $Body

            # Validate response
            $Response | Should -Not -BeNullOrEmpty
            $Response | Should -BeOfType 'PSCustomObject'
            $Response.success | Should -Be $true

            # Validate JWT token format
            $Response.jwt | Should -Not -BeNullOrEmpty
            $Response.jwt | Should -Match '^[A-Za-z0-9-_]+\.[A-Za-z0-9-_]+\.[A-Za-z0-9-_]+$'

            # Validate user details
            $Response.User | Should -Not -BeNullOrEmpty
            $Response.User.Username | Should -Be 'morty.smith'
            $Response.User.Groups | Should -Be 'Domain Users'
            $Response.User.Name | Should -Be 'Morty Smith'
            $Response.User.Id | Should -Be 'M0R7Y302'

            # Store JWT for subsequent tests
            $script:JwtToken = $Response.Jwt
        }

        It 'Validates JWT Token Structure and Claims' {
            $Response = Invoke-RestMethod -Uri "$($Endpoint)/auth/bearer/jwt/info" `
                -Method Post `
                -Headers @{
                'accept'        = 'application/json'
                'Authorization' = "Bearer $($script:JwtToken)"
            } `
                -Body ''

            # Validate response structure
            $Response | Should -Not -BeNullOrEmpty
            $Response | Should -BeOfType 'PSCustomObject'

            # Validate JWT Header
            $Response.Header | Should -Not -BeNullOrEmpty
            $Response.Header.typ | Should -Be 'JWT'
            $Response.Header.alg | Should -Be 'ES384'

            # Validate JWT Payload
            $Response.Payload | Should -Not -BeNullOrEmpty
            $Response.Payload.type | Should -Be 'human'
            $Response.Payload.username | Should -Be 'morty.smith'
            $Response.Payload.sub | Should -Be 'M0R7Y302'
            $Response.Payload.groups | Should -Be 'Domain Users'
            $Response.Payload.name | Should -Be 'Morty Smith'
            $Response.Payload.id | Should -Be 'M0R7Y302'

            # Validate JWT Timestamps
            $Response.Payload.iat | Should -BeOfType 'datetime'
            $Response.Payload.nbf | Should -BeOfType 'datetime'
            $Response.Payload.exp | Should -BeOfType 'datetime'
            $Response.Payload.iss | Should -Be 'Pode'
            $Response.Payload.aud | Should -Be 'JWTAuthentication'
            $Response.Payload.jti | Should -Match '^[0-9a-f\-]+$'

            # Validate JWT Signature
            $Response.Signature | Should -Not -BeNullOrEmpty
            $Response.Signature | Should -Match '^[A-Za-z0-9_\-]+$'

            # Store expiration for comparison
            $script:JwtExpiration = $Response.Payload.exp
        }

        It 'Renews JWT Token Successfully' {
            $Response = Invoke-RestMethod -Uri "$($Endpoint)/auth/bearer/jwt/renew" `
                -Method Post `
                -Headers @{
                'accept'        = 'application/json'
                'Authorization' = "Bearer $($script:JwtToken)"
            } `
                -Body ''

            # Validate response structure
            $Response | Should -Not -BeNullOrEmpty
            $Response | Should -BeOfType 'PSCustomObject'
            $Response.success | Should -Be $true

            # Validate JWT token format
            $Response.jwt | Should -Not -BeNullOrEmpty
            $Response.jwt | Should -Match '^[A-Za-z0-9-_]+\.[A-Za-z0-9-_]+\.[A-Za-z0-9-_]+$'

            # Store previous token for comparison
            $script:PreviousJwtToken = $script:JwtToken
            $script:JwtToken = $Response.Jwt
        }

        It 'Validates Renewed JWT Token and Claims' {
            $Response = Invoke-RestMethod -Uri "$($Endpoint)/auth/bearer/jwt/info" `
                -Method Post `
                -Headers @{
                'accept'        = 'application/json'
                'Authorization' = "Bearer $($script:JwtToken)"
            } `
                -Body ''

            # Validate response structure
            $Response | Should -Not -BeNullOrEmpty
            $Response | Should -BeOfType 'PSCustomObject'

            # Validate JWT Header
            $Response.Header | Should -Not -BeNullOrEmpty
            $Response.Header.typ | Should -Be 'JWT'
            $Response.Header.alg | Should -Be 'ES384'

            # Validate JWT Payload
            $Response.Payload | Should -Not -BeNullOrEmpty
            $Response.Payload.type | Should -Be 'human'
            $Response.Payload.username | Should -Be 'morty.smith'
            $Response.Payload.sub | Should -Be 'M0R7Y302'
            $Response.Payload.groups | Should -Be 'Domain Users'
            $Response.Payload.name | Should -Be 'Morty Smith'
            $Response.Payload.id | Should -Be 'M0R7Y302'

            # Validate JWT Timestamps
            $Response.Payload.iat | Should -BeOfType 'datetime'
            $Response.Payload.nbf | Should -BeOfType 'datetime'
            $Response.Payload.exp | Should -BeOfType 'datetime'
            $Response.Payload.iss | Should -Be 'Pode'
            $Response.Payload.aud | Should -Be 'JWTAuthentication'
            $Response.Payload.jti | Should -Match '^[0-9a-f\-]+$'

            # Validate JWT Signature
            $Response.Signature | Should -Not -BeNullOrEmpty
            $Response.Signature | Should -Match '^[A-Za-z0-9_\-]+$'

            # Ensure the new token is different from the previous one
            $script:JwtToken | Should -Not -BeExactly $script:PreviousJwtToken

            # Validate expiration time increased
            $Response.Payload.exp | Should -BeGreaterThan $script:JwtExpiration
        }
    }


}