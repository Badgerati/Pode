<#
.SYNOPSIS
    A PowerShell script to set up a Pode server with JWT authentication and various route configurations.

.DESCRIPTION
    This script initializes a Pode server that listens on a specified port, enables request and error logging,
    and configures JWT authentication using either the request header or query parameters. It also defines
    a protected route to fetch a list of users, requiring authentication.

.PARAMETER Location
    Specifies where the API key (JWT token) is expected.
    Valid values: 'Header', 'Query'.
    Default: 'Header'.

.EXAMPLE
    # Run the sample
    ./WebAuth-bearerJWT.ps1

    JWT payload:
    {
        "sub": "1234567890",
        "name": "morty",
        "username":"morty",
        "type": "Human",
        "id" : "M0R7Y302",
        "admin": true,
        "iat": 1516239022,
        "exp": 2634234231,
        "iss": "auth.example.com",
        "sub": "1234567890",
        "aud": "myapi.example.com",
        "nbf": 1690000000,
        "jti": "unique-token-id",
        "role": "admin"
    }

.EXAMPLE
    # Example request using PS512 JWT authentication
    $jwt = ConvertTo-PodeJwt -PfxPath ./cert.pfx -RsaPaddingScheme Pss -PfxPassword (ConvertTo-SecureString 'mySecret' -AsPlainText -Force)
    $headers = @{ 'Authorization' = "Bearer $jwt" }
    $response = Invoke-RestMethod -Uri 'http://localhost:8081/auth/bearer/jwt/PS512' -Method Get -Headers $headers

.EXAMPLE
    # Example request using RS384 JWT authentication
    $headers = @{ 'Authorization' = 'Bearer <your-jwt>' }
    $response = Invoke-RestMethod -Uri 'http://localhost:8081/users' -Method Get -Headers $headers

.EXAMPLE
    # Example request using HS256 JWT authentication
    $jwt = ConvertTo-PodeJwt -Algorithm HS256 -Secret (ConvertTo-SecureString 'secret' -AsPlainText -Force) -Payload @{id='id';name='Morty'}
    $headers = @{ 'Authorization' = "Bearer $jwt" }
    $response = Invoke-RestMethod -Uri 'http://localhost:8081/users' -Method Get -Headers $headers

  .LINK
    https://github.com/Badgerati/Pode/blob/develop/examples/Web-AuthbearerJWT.ps1

  .NOTES
    - This script uses Pode to create a lightweight web server with authentication.
    - JWT authentication is handled via Bearer tokens passed in either the header or query.
    - Ensure the private key is securely stored and managed for RS256-based JWT signing.
    - Using query parameters for authentication is **discouraged** due to security risks.
    - Always use HTTPS in production to protect sensitive authentication data.

    Author: Pode Team
    License: MIT License
#>

param(
    [Parameter()]
    [ValidateSet('Header', 'Query' )]
    [string]
    $Location = 'Header'
)

try {
    # Determine the script path and Pode module path
    $ScriptPath = (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
    $podePath = Split-Path -Parent -Path $ScriptPath

    # Import the Pode module from the source path if it exists, otherwise from installed modules
    if (Test-Path -Path "$($podePath)/src/Pode.psm1" -PathType Leaf) {
        Import-Module "$($podePath)/src/Pode.psm1" -Force -ErrorAction Stop
    }
    else {
        Import-Module -Name 'Pode' -MaximumVersion 2.99 -ErrorAction Stop
    }
}
catch { throw }

# or just:
# Import-Module Pode

# create a server, and start listening on port 8081
Start-PodeServer -Threads 2 -ApplicationName 'webauth' {

    # listen on localhost:8081
    Add-PodeEndpoint -Address localhost -Port 8081 -Protocol Http

    New-PodeLoggingMethod -File -Name 'requests' | Enable-PodeRequestLogging
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging


    $path = $PSCommandPath

    # Define the key storage path
    $certsPath = Join-Path -Path (Split-Path -Parent -Path $path) -ChildPath 'certs'

    $JwtVerificationMode = 'Lenient'  # Set your desired verification mode (Lenient or Strict)

    # Ensure the directory exists
    if (-Not (Test-Path $CertsPath)) {
        Write-Warning "Certificate folder '$CertsPath' does not exist."
        Exit
    }

    $privateKeys = Get-ChildItem -Path $CertsPath -Filter '*.pfx'

    # $privateKeys += Get-ChildItem -Path $CertsPath -Filter  '*-private-encrypted.pem'

    foreach ($privateKeyFile in $privateKeys) {
        if ($privateKeyFile.Name.Contains('-no-pass.pfx')) {
            # Extract algorithm name from file name
            $alg = $privateKeyFile.Name -replace '-no-pass.pfx', ''

            $securePassword = $null
        }
        else {
            # Extract algorithm name from file name
            $alg = $privateKeyFile.Name -replace '.pfx', '-pwd'

            $securePassword = ConvertTo-SecureString 'MySecurePassword' -AsPlainText
        }

        while ($true) {
            # Define the authentication location dynamically (e.g., `/auth/bearer/jwt/{algorithm}`)
            $pathRoute = "/auth/bearer/jwt/$alg"
            # Register Pode Bearer Authentication
            Write-PodeHost "🔹 Registering JWT Authentication for: $alg ($Location)"

            $rsaPaddingScheme = if ($alg.StartsWith('PS')) { 'Pss' } else { 'Pkcs1V15' }

            $param = @{
                Location            = $Location
                AsJWT               = $true
                RsaPaddingScheme    = $rsaPaddingScheme
                JwtVerificationMode = $JwtVerificationMode
                PfxPath             = $privateKeyFile.FullName
                PfxPassword         = $securePassword
            }

            New-PodeAuthBearerScheme @param |
                Add-PodeAuth -Name "Bearer_JWT_$alg" -Sessionless -ScriptBlock {
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
            Add-PodeRoute -Method Get -Path $pathRoute -Authentication "Bearer_JWT_$alg" -ScriptBlock {

                Write-PodeJsonResponse -Value @{
                    Users = @(
                        @{
                            Name = 'Deep Thought'
                            Age  = 42
                        },
                        @{
                            Name = 'Leeroy Jenkins'
                            Age  = 1337
                        }
                    )
                }
            }
            if ($alg.StartsWith('RS')) {
                $alg = $alg.Replace('RS', 'PS')
            }
            else {
                break
            }
        }
    }



    # setup bearer auth
    New-PodeAuthBearerScheme  -Location $Location -AsJWT -Secret (ConvertTo-SecureString 'your-256-bit-secret' -AsPlainText -Force)   -JwtVerificationMode Lenient | Add-PodeAuth -Name 'Validate' -Sessionless -ScriptBlock {
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
    Add-PodeRoute -Method Get -Path '/users' -Authentication 'Validate' -ScriptBlock {

        Write-PodeJsonResponse -Value @{
            Users = @(
                @{
                    Name = 'Deep Thought'
                    Age  = 42
                },
                @{
                    Name = 'Leeroy Jenkins'
                    Age  = 1337
                }
            )
        }
    }

}