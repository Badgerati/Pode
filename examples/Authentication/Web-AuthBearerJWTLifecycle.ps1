<#
.SYNOPSIS
  A PowerShell script demonstrating the full lifecycle of JWT authentication using X.509 certificates in Pode.

.DESCRIPTION
  This script sets up a Pode server that listens on a specified port and enables JWT authentication using X.509 certificates.
  It showcases the full JWT authentication lifecycle, including login, renewal, validation, and retrieval of user information.
  Authentication is performed using JWT tokens signed with the selected cryptographic algorithm.

.PARAMETER Location
  Specifies where the API key (JWT token) is expected.
  Valid values: 'Header', 'Query'.
  Default: 'Header'.

.PARAMETER Algorithm
  Specifies the cryptographic algorithm used for JWT signing and verification.
  Valid values: 'RS256', 'RS384', 'RS512', 'PS256', 'PS384', 'PS512', 'ES256', 'ES384', 'ES512'.
  Default: 'ES512'.

.EXAMPLE
  # Run the sample
  ./WebAuth-bearerJWT.ps1

  JWT payload example:
  {
      "sub": "1234567890",
      "name": "morty",
      "username": "morty",
      "type": "Human",
      "id": "M0R7Y302",
      "admin": true,
      "iat": 1516239022,
      "exp": 2634234231,
      "iss": "auth.example.com",
      "aud": "myapi.example.com",
      "nbf": 1690000000,
      "jti": "unique-token-id",
      "role": "admin"
  }

.LINK
  https://github.com/Badgerati/Pode/blob/develop/examples/Authentication/Web-AuthbearerJWTLifecycle.ps1

.NOTES
  - This script uses Pode to create a lightweight web server with authentication.
  - JWT authentication is handled via Bearer tokens passed in either the header or query parameters.
  - JWTs are signed using X.509 certificates and verified based on the selected algorithm.
  - The script implements endpoints for login, token renewal, and token validation.
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
    $Location = 'Header',

    [Parameter()]
    [ValidateSet( 'RS256', 'RS384', 'RS512', 'PS256', 'PS384', 'PS512', 'ES256', 'ES384', 'ES512')]
    [string]
    $Algorithm = 'ES512'
)

try {
    # Determine the script path and Pode module path
    $ScriptPath = (Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path))
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

# Define a function to autenticate user credentials
function Test-User {
    param (
        [string]$username,
        [string]$password
    )
    if ($username -eq 'morty' -and $password -eq 'pickle') {
        return @{
            Id       = 'M0R7Y302'
            Username = 'morty.smith'
            Name     = 'Morty Smith'
            Groups   = 'Domain Users'
        }
    }
    throw 'Invalid credentials'
}

# or just:
# Import-Module Pode

# create a server, and start listening on port 8081
Start-PodeServer -Threads 2 -ApplicationName 'webauth' {

    # listen on localhost:8081
    Add-PodeEndpoint -Address localhost -Port 8043 -Protocol Https -SelfSigned

    New-PodeLoggingMethod -File -Name 'requests' | Enable-PodeRequestLogging
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging
    # Configure CORS
    Set-PodeSecurityAccessControl -Origin '*' -Duration 7200 -WithOptions -AuthorizationHeader -autoMethods -AutoHeader -Credentials -CrossDomainXhrRequests


    # Enable OpenAPI documentation

    Enable-PodeOpenApi -Path '/docs/openapi'  -OpenApiVersion '3.0.3' -EnableSchemaValidation:($PSVersionTable.PSEdition -eq 'Core') -DisableMinimalDefinitions -NoDefaultResponses
    Add-PodeOAInfo -Title 'JWT Test' -Version 1.0.17 -Description 'test'
    Add-PodeOAServerEndpoint -url '/auth/bearer/jwt' -Description 'default endpoint'
    # Enable OpenAPI viewers
    Enable-PodeOAViewer -Type Swagger -Path '/docs/swagger'
    Enable-PodeOAViewer -Type ReDoc -Path '/docs/redoc' -DarkMode
    Enable-PodeOAViewer -Type RapiDoc -Path '/docs/rapidoc' -DarkMode
    Enable-PodeOAViewer -Type StopLight -Path '/docs/stoplight' -DarkMode
    Enable-PodeOAViewer -Type Explorer -Path '/docs/explorer' -DarkMode
    Enable-PodeOAViewer -Type RapiPdf -Path '/docs/rapipdf' -DarkMode

    # Enable OpenAPI editor and bookmarks
    Enable-PodeOAViewer -Editor -Path '/docs/swagger-editor'
    Enable-PodeOAViewer -Bookmarks -Path '/docs'


    $JwtVerificationMode =  'Strict'  # Set your desired verification mode (Lenient or Strict)
     # $SecurePassword = ConvertTo-SecureString 'MySecurePassword' -AsPlainText -Force

    $param = @{
        Location            = $Location
        AsJWT               = $true
        JwtVerificationMode = $JwtVerificationMode
        SelfSigned          = $true
    }
    # Register Pode Bearer Authentication
    New-PodeAuthBearerScheme @param |
        Add-PodeAuth -Name "Bearer_JWT_$Algorithm" -Sessionless -ScriptBlock {
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

    # GET request to get list of users (since there's no session, authentication will always happen)
    Add-PodeRoute -PassThru -Method Get -Path "/auth/bearer/jwt/$Algorithm" -Authentication "Bearer_JWT_$Algorithm" -ScriptBlock {
        Write-PodeJsonResponse -Value $WebEvent.auth.User
    } | Set-PodeOARouteInfo -Summary 'Get my info.'  -Tags 'user' -OperationId "myinfo_$Algorithm"



    Add-PodeRoute -PassThru -Method Post -Path '/auth/bearer/jwt/login' -ArgumentList $Algorithm -ScriptBlock {
        param(
            [string]
            $Algorithm
        )
        try {
            # In a real scenario, you'd validate the incoming credentials from $WebEvent.data
            $username = $WebEvent.Data.username
            $password = $WebEvent.Data.password
            $user = Test-User -username $username -password $password


            $payload = @{
                sub      = $user.Id
                name     = $user.Name
                username = $user.Username
                id       = $user.Id
                groups   = $user.Groups
                type     = 'human'
            }

            # If valid, generate a JWT that matches the 'ExampleApiKeyCert' scheme
            $jwt = ConvertTo-PodeJwt  -Payload $payload -Authentication "Bearer_JWT_$Algorithm" -Expiration 600
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
    } | Set-PodeOARouteInfo -Summary 'Logs user into the system.'  -Tags 'user' -OperationId 'loginUser' -PassThru |
        Set-PodeOARequest -RequestBody (
            New-PodeOARequestBody -Description  'Update an existent pet in the store' -Required -Content (
                New-PodeOAContentMediaType -ContentType 'application/json'  -Content                (
                    New-PodeOAStringProperty -Name 'username' -Description 'The user name for login' -Default 'morty' |
                        New-PodeOAStringProperty -Name 'password' -Description 'The password for login in clear text' -Format Password -Default 'pickle' |
                        New-PodeOAObjectProperty)
                )
            ) -PassThru |
            Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -Content (
                New-PodeOAContentMediaType -ContentType 'application/json' -Content (
                    New-PodeOABoolProperty -Name 'success' -Description 'Operation success' -Example $true |
                        New-PodeOAStringProperty -Name 'user' -Description 'The user  for login' -Example 'morty' |
                        New-PodeOAStringProperty -Name 'jwt' -Description 'Bearen JWT token' -Example '6656565' |
                        New-PodeOAObjectProperty
                    )
                )  -PassThru |
                Add-PodeOAResponse -StatusCode 400 -Description 'Invalid username/password supplied'

    Add-PodeRoute -PassThru -Method Post -Path '/auth/bearer/jwt/renew' -Authentication "Bearer_JWT_$Algorithm" -ScriptBlock {
        try {

            $jwt = Update-PodeJwt

            Write-PodeJsonResponse -StatusCode 200 -Value @{
                'success' = $true
                'jwt'     = $jwt
            }
        }
        catch {
            Write-PodeJsonResponse -StatusCode 401 -Value @{ error = 'Invalid JWT token supplied' }
        }
    } | Set-PodeOARouteInfo -Summary 'Extend JWT Token.'  -Tags 'JWT' -OperationId 'renewToken' -PassThru |
        Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -Content (
            New-PodeOAContentMediaType -ContentType 'application/json' -Content (
                New-PodeOABoolProperty -Name 'success' -Description 'Operation success' -Example $true |
                    New-PodeOAStringProperty -Name 'user' -Description 'The user  for login' -Example 'morty' |
                    New-PodeOAStringProperty -Name 'jwt' -Description 'Bearen JWT token' -Example 'eyJ0eXAiOiJKV1QifQ.eyJpZCI6Ik0wUjdZMzAyIi ... UG9kZSJ9.hhU1fmykkSyZhUCr1NSZto-dGyt50r5OUlYj5SgL88EFlnulSOtsM-61tht-X5lEZVP7TCwG2q6ZELiA-4zey7BTIEecKg8zQ4NasZQi6eq9scSL0WJPNHNiGf91F1BsSAQmTxmtJz9-R9l7dxxonFlgLhq9ZwToPuAEK76lYuEQ45ERH-LoO5En9nRnar5N8SLe244To_T7UPKKBgd_DQNSuW4pShMbeK1_TTwELxroV2-d7bPyhUKIwrP61DDsGxgYCzsJ_8XG4YOfFg_u3bHp_JEplCFPoc5KUVNOQHFCzYR0WMZDhRDMnAF6J8Xn0RKTsFB7q1QNC0NF1-7TGQ' |
                    New-PodeOAObjectProperty
                )
            )  -PassThru |
            Add-PodeOAResponse -StatusCode 401 -Description 'Invalid JWT token supplied'

    Add-PodeRoute -PassThru -Method Post -Path '/auth/bearer/jwt/info' -Authentication "Bearer_JWT_$Algorithm" -ScriptBlock {
        try {
            $jwtInfo = ConvertFrom-PodeJwt -Outputs  'Header,Payload,Signature' -HumanReadable
            Write-PodeJsonResponse -StatusCode 200 -Value $jwtInfo
        }
        catch {
            Write-PodeJsonResponse -StatusCode 401 -Value @{ error = 'Invalid JWT token supplied' }
        }
    } | Set-PodeOARouteInfo -Summary 'return JWT Token info.'  -Tags 'JWT' -OperationId 'getInfoToken' -PassThru |
        Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -Content (
            New-PodeOAContentMediaType -ContentType 'application/json' -Content (
                New-PodeOAObjectProperty -Properties (
                        ( New-PodeOABoolProperty -Name 'success' -Description 'Operation success' -Example $true),
                        (New-PodeOAObjectProperty -Name Header ),
                         ( New-PodeOAObjectProperty -Name Payload), ( New-PodeOAStringProperty -Name Signature)
                )
            )
        )  -PassThru |
        Add-PodeOAResponse -StatusCode 401 -Description 'Invalid JWT token supplied'

}