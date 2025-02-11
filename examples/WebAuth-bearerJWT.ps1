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
    $alg='PS512'
   foreach($alg in 'RS256','RS384','RS512','PS256','PS384','PS512','ES256','ES384','ES512'){

    $certsPath="./tests/certs/"
    $privateKey = Get-Content "$certsPath/$alg-private.pem" -Raw | ConvertTo-SecureString -AsPlainText -Force

    $jwt= ConvertTo-PodeJwt -Algorithm $alg  -PrivateKey $privateKey   -Payload @{id='id';name='Morty';Type='Human';username='morty'} #-Issuer 'Pode' -Audience 'webauth'

   $headers = @{
        'Authorization' = "Bearer $jwt"
        'Accept'        = 'application/json'
    }

    $response = Invoke-RestMethod -Uri "http://localhost:8081/auth/bearer/jwt/$alg" -Method Get -Headers $headers
    }

     .EXAMPLE
    # Example request using RS384 JWT authentication
    $headers = @{
        'Authorization' = 'Bearer eyJhbGciOiJSUzM4NCIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6Im1vcnR5IiwidXNlcm5hbWUiOiJtb3J0eSIsInR5cGUiOiJIdW1hbiIsImlkIjoiTTBSN1kzMDIiLCJhZG1pbiI6dHJ1ZSwiaWF0IjoxNTE2MjM5MDIyLCJleHAiOjI2MzQyMzQyMzEsImlzcyI6IlBvZGUiLCJhdWQiOiJXZWJBdXRoLWJlYXJlckpXVC5wczEiLCJuYmYiOjE2OTAwMDAwMDAsImp0aSI6InVuaXF1ZS10b2tlbi1pZCIsInJvbGUiOiJhZG1pbiJ9.h8oQKzYpRp1Mc5d-U-6HisQ04l4ucQpBn46WLun6goM-rapweVoj4xC3MPJ5nvP8Z5iEu1mxpF3KDskihI_BxOQMffFECleyf6Yw3IPY7IwV5DeEdmMOMSD8XlelxswMUBG_3wBPOuhKmFSN7rmXKbXaFWIC9ggEWNoK0e2B8ccNqaVZ_3EJAYQHpMivWIFBYQ5rav96ZcCoye19kFuLeMDEprtyBYVcdO-wCzEw2O-7BDul3ynhTY9znXGW7qBT7SyEB-VSo1X2lGten-L2w6vL4CA6RXQYeEiokjXw4OCFsnvkj736TrMKZg4WJ3ONsgnkhHavVL7BsTERPdaWeg'
        'Accept'        = 'application/json'
    }

    $response = Invoke-RestMethod -Uri 'http://localhost:8081/users' -Method Get -Headers $headers



  .EXAMPLE
    # Example request using HS256 JWT authentication
    $jwt= ConvertTo-PodeJwt -Algorithm HS256 -Secret (ConvertTo-SecureString 'your-256-bit-secret' -AsPlainText -Force) -Payload @{id='id';name='Morty';Type='Human';username='morty'} -Issuer 'Pode' -Audience 'webauth'
    $headers = @{
        'Authorization' = "Bearer $jwt"
        'Accept'        = 'application/json'
    }

    $response = Invoke-RestMethod -Uri 'http://localhost:8081/users' -Method Get -Headers $headers

  .LINK
    https://github.com/Badgerati/Pode/blob/develop/examples/WebAuth-bearerJWT.ps1

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

    # Get all private key files (assuming format: {Algorithm}-private.pem)
    $privateKeys = Get-ChildItem -Path $CertsPath -Filter '*-private.pem'

    foreach ($privateKeyFile in $privateKeys) {
        # Extract algorithm name from file name
        $alg = $privateKeyFile.Name -replace '-private.pem', ''

        # Define corresponding public key path
        $publicKeyPath = Join-Path -Path $CertsPath -ChildPath $alg-public.pem

        # Ensure the matching public key exists
        if (! (Test-Path $publicKeyPath)) {
            Write-Warning "Skipping $($alg): Public key missing ($publicKeyPath)."
            Continue
        }

        # Read key contents
        $privateKey = Get-Content $privateKeyFile.FullName -Raw | ConvertTo-SecureString -AsPlainText -Force
        $publicKey = Get-Content $publicKeyPath -Raw
        while ($true) {
            # Define the authentication location dynamically (e.g., `/auth/bearer/jwt/{algorithm}`)
            $pathRoute = "/auth/bearer/jwt/$alg"
            # Register Pode Bearer Authentication
            Write-PodeHost "🔹 Registering JWT Authentication for: $alg ($Location)"

            $rsaPaddingScheme = if ($alg.StartsWith('PS')) { 'Pss' } else { 'Pkcs1V15' }

            New-PodeAuthBearerScheme -Location $Location -AsJWT -PrivateKey $privateKey -PublicKey $publicKey -RsaPaddingScheme $rsaPaddingScheme -JwtVerificationMode $JwtVerificationMode |
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