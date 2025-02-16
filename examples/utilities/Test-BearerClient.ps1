<#
.SYNOPSIS
    PowerShell script to test JWT authentication against a Pode server.

.DESCRIPTION
    This script performs authentication tests against a Pode server using JWT bearer tokens.
    It iterates over multiple JWT signing algorithms, generates tokens, and sends authenticated
    requests to verify the implementation.

    - Supports RSA (`RS256`, `RS384`, `RS512`), PSS (`PS256`, `PS384`, `PS512`), and EC (`ES256`, `ES384`, `ES512`) algorithms.
    - Checks for the availability of private keys before attempting authentication.
    - Uses `ConvertTo-PodeJwt` for JWT generation.
    - Sends requests to the Pode authentication API and validates responses.

.PARAMETER ApiBaseUrl
    The base URL of the Pode authentication endpoint.

.EXAMPLE
    # Run the script to test JWT authentication
    ./Test-BearerClient.ps1

.EXAMPLE
    # Manually specify the authentication API URL
    $uri = "http://localhost:8081/auth/bearer/jwt"
    ./Test-BearerClient.ps1 -ApiBaseUrl $uri

 .LINK
    https://github.com/Badgerati/Pode/blob/develop/examples/utilities/Test-BearerClient.ps1

.NOTES
    - **JWT Authentication Overview:**
        - The script loads private keys for multiple algorithms.
        - It generates JWTs using `ConvertTo-PodeJwt` with a test payload.
        - Each JWT is used to authenticate a request against the Pode API.
        - Responses are validated and displayed in JSON format.

    - **Pode Compatibility:**
        - Pode supports various JWT signing algorithms.
        - Ensure Pode is configured with `New-PodeAuthScheme -BearerJwt` for JWT authentication.

    - **Security Considerations:**
        - Keep private key files secure.
        - Use strong signing algorithms (e.g., `RS512`, `PS512`, `ES512`).
        - Ensure HTTPS is used in production environments.

.NOTES
    Author: Pode Team
    License: MIT License
#>
param (
    [string]
    $ApiBaseUrl = 'http://localhost:8081/auth/bearer/jwt'
)

try {
    # Determine the script path and Pode module path
    $ScriptPath = (Split-Path -Parent -Path(Split-Path -Parent -Path $MyInvocation.MyCommand.Path))
    $podePath = Split-Path -Parent -Path $ScriptPath

    # Import the Pode module from the source path if it exists, otherwise from installed modules
    if (Test-Path -Path "$($podePath)/src/Pode.psm1" -PathType Leaf) {
        Import-Module "$($podePath)/src/Pode.psm1" -Force -ErrorAction Stop
    }
    else {
        Import-Module -Name 'Pode' -MaximumVersion 2.99 -ErrorAction Stop
    }

    # Define the key storage path
    $certsPath = Join-Path -Path $podePath -ChildPath '/examples/certs'
}
catch { throw }

$ApiBaseUrl = 'http://localhost:8081/auth/bearer/jwt'

Write-Output 'Starting JWT Authentication Tests...'
Write-Output "Checking if certificates directory exists: $certsPath"

if (-Not (Test-Path $certsPath)) {
    Write-Error "Certificate directory does not exist: $certsPath"
    Exit
}
 
'Password', 'noPassword' | ForEach-Object {
    $algorithms = 'RS256', 'RS384', 'RS512', 'PS256', 'PS384', 'PS512', 'ES256', 'ES384', 'ES512'
    #  $algorithms = 'PS256', 'PS384', 'PS512', 'ES256', 'ES384', 'ES512'
    foreach ($alg in $algorithms) {
        Write-Output '-----------------------------------------------'
        Write-Output "Testing Algorithm: $alg"
        if ($_ -eq 'noPassword') {          
            $privateKeyPath = if ($alg.StartsWith('PS')) {
                "$certsPath/$($alg.Replace('PS','RS'))-no-pass.pfx"
                $rsaPaddingScheme = 'Pss'
            }
            else {
                "$certsPath/$alg-no-pass.pfx"
                $rsaPaddingScheme = 'Pkcs1V15'
            } 
        }
        else {
            $securePassword = ConvertTo-SecureString 'MySecurePassword' -AsPlainText
            $privateKeyPath = if ($alg.StartsWith('PS')) {
                "$certsPath/$($alg.Replace('PS','RS')).pfx"
                $rsaPaddingScheme = 'Pss'
            }
            else {
                "$certsPath/$alg.pfx"
                $rsaPaddingScheme = 'Pkcs1V15'
            }
        }
   

        if (-Not (Test-Path $privateKeyPath)) {
            Write-Warning "Skipping $($alg): Private key file not found ($privateKeyPath)"
            Continue
        }

        Write-Output "Loading Private Key: $privateKeyPath"

        Write-Output "Generating JWT for $alg..."

        try {
            if ($_ -eq 'Password') {
                $jwt = ConvertTo-PodeJwt -PfxPath $privateKeyPath -RsaPaddingScheme $rsaPaddingScheme -PfxPassword $securePassword -Payload @{
                    id       = 'id'
                    name     = 'Morty'
                    Type     = 'Human'
                    username = 'morty'
                }                 
                ConvertFrom-PodeJwt -Token $jwt -PfxPath $privateKeyPath -RsaPaddingScheme $rsaPaddingScheme -PfxPassword $securePassword
                $apiUrl = "$ApiBaseUrl/$alg-pwd"
            }
            else {
                $jwt = ConvertTo-PodeJwt -PfxPath $privateKeyPath -RsaPaddingScheme $rsaPaddingScheme -Payload @{
                    id       = 'id'
                    name     = 'Morty'
                    Type     = 'Human'
                    username = 'morty'
                } 
                ConvertFrom-PodeJwt -Token $jwt -PfxPath $privateKeyPath -RsaPaddingScheme $rsaPaddingScheme  
                $apiUrl = "$ApiBaseUrl/$alg"
            }
        }
        catch {
            Write-Error "JWT generation failed for $($alg): $_"
            Continue
        }
        Write-Output "JWT successfully generated for $alg"

        $headers = @{
            'Authorization' = "Bearer $jwt"
            'Accept'        = 'application/json'
        }
 
        Write-Output "Sending request to: $apiUrl"

        try {
            $response = Invoke-RestMethod -Uri $apiUrl -Method Get -Headers $headers
            Write-Output "Response for $($alg): $($response | ConvertTo-Json -Depth 2)"
        }
        catch {
            Write-Error "API request failed for $($alg): $_"
        }

        Write-Output 'Waiting 10 seconds before next test...'
        Start-Sleep 10
    }
}
Write-Output 'All JWT authentication tests completed!'
