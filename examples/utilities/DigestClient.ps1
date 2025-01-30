<#
.SYNOPSIS
    PowerShell script to authenticate against a Pode server using Digest authentication.

.DESCRIPTION
    This script acts as a client to interact with a Pode server that requires Digest authentication.
    It retrieves the server's `WWW-Authenticate` challenge, extracts required parameters, computes
    the proper response hash, and sends an authenticated request.

    - Supports multiple algorithms: `MD5`, `SHA-1`, `SHA-256`, `SHA-384`, `SHA-512`, `SHA-512/256`
    - Handles both `auth` and `auth-int` Quality of Protection (QoP) modes.
    - Ensures compatibility with Pode's built-in Digest authentication.
    - Uses a preferred algorithm selection process based on security strength.

    ⚠ **Windows Limitations:**
    - Windows' built-in Digest authentication **only supports MD5**.
    - Windows **fails** if multiple algorithms are presented in the `WWW-Authenticate` header.
    - Windows **does not support `auth-int`** for Digest authentication.
    - For alternative authentication handling, refer to Pode's `examples/Utilities/DigestClient.ps1`.

.PARAMETER uri
    The target server's URI requiring Digest authentication.

.PARAMETER username
    The username for authentication.

.PARAMETER password
    The corresponding password for authentication.

.EXAMPLE
    # Run the script against a Pode server
    ./DigestClient.ps1

.EXAMPLE
    # Manually specify credentials
    $uri = "http://localhost:8081/users"
    $username = "morty"
    $password = "pickle"
    ./DigestClient.ps1 -uri $uri -username $username -password $password

.LINK
    https://github.com/Badgerati/Pode/blob/develop/examples/utilities/DigestClient.ps1

.NOTES
    - **Digest Authentication Overview:**
        - The script retrieves the authentication challenge from the server.
        - It parses the `WWW-Authenticate` header to determine the `realm`, `nonce`, `qop`, and `algorithm`.
        - The strongest supported algorithm is selected.
        - The client computes HA1, HA2, and the final response hash based on the selected algorithm and QoP.
        - The request is sent with the appropriate `Authorization` header.

    - **Quality of Protection (QoP):**
        - `"auth"`: Standard Digest authentication using `method:uri`.
        - `"auth-int"`: Includes a hash of the request body for additional integrity protection.

    - **Pode Compatibility:**
        - Pode's `New-PodeAuthScheme -Digest` supports multiple algorithms beyond MD5.
        - Pode's implementation supports `auth-int`, unlike Windows' built-in Digest authentication.

    - **Security Considerations:**
        - MD5 is insecure and should not be used in production.
        - SHA-256 or stronger algorithms (`SHA-512/256`) are recommended.

.NOTES
    Author: Pode Team
    License: MIT License
#>

# Define the URI and credentials
$uri = 'http://localhost:8081/users'
$username = 'morty'
$password = 'pickle'

# Create an HTTP client
$handler = [System.Net.Http.HttpClientHandler]::new()
$httpClient = [System.Net.Http.HttpClient]::new($handler)

# Step 1: Send an initial request to get the challenge
$initialRequest = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Get, $uri)
$initialResponse = $httpClient.SendAsync($initialRequest).Result
if ($null -eq $initialResponse) {
    Write-Error "Server $uri is not responding"
    return
}

# Extract WWW-Authenticate headers safely
$wwwAuthHeaders = $initialResponse.Headers.GetValues("WWW-Authenticate")

# Filter to get only the Digest authentication scheme
$wwwAuthHeader = $wwwAuthHeaders | Where-Object { $_ -match "^Digest" }

# Debug output
Write-Output "Extracted WWW-Authenticate headers:"
$wwwAuthHeaders | ForEach-Object { Write-Output " - $_" }

# Ensure we have a Digest header before continuing
if (-not $wwwAuthHeader) {
    Write-Output "Digest authentication not supported by server!"
    exit
}

## Extract Digest Authentication challenge values correctly
$challenge = @{}

# Ensure the header contains "Digest"
if ($wwwAuthHeader -match "^Digest ") {
    # Remove "Digest " prefix
    $headerContent = $wwwAuthHeader -replace "^Digest ", ""

    Write-Output "RAW HEADER: $headerContent"

    # 1) CAPTURE
    if ($headerContent -match "algorithm=((?:SHA-1|SHA-256|SHA-384|SHA-512(?:/256)?|MD5)(?:,\s*(?:SHA-1|SHA-256|SHA-384|SHA-512(?:/256)?|MD5))*)") {

        $algorithms = ($matches[1] -split '\s*,\s*')
        Write-Output "Supported Algorithms: $algorithms"
        $challenge["algorithm"] = $algorithms
    }

    # 2) REMOVE
    $headerContent = $headerContent -replace "algorithm=(?:SHA-1|SHA-256|SHA-384|SHA-512(?:/256)?|MD5)(?:,\s*(?:SHA-1|SHA-256|SHA-384|SHA-512(?:/256)?|MD5))*\s*,?", ""

    # 3) CLEAN UP ANY EXTRA COMMAS/WHITESPACE
    $headerContent = $headerContent -replace ",\s*,", ","
    $headerContent = $headerContent -replace "^\s*,", ""

    # Now split the rest of the parameters safely
    $headerContent -split ', ' | ForEach-Object {
        $key, $value = $_ -split '=', 2
        if ($key -and $value) {
            $challenge[$key.Trim()] = $value.Trim('"')
        }
    }
}

# Output the parsed challenge
Write-Output "Extracted Digest Authentication Challenge:"
$challenge | ForEach-Object { Write-Output "$($_.Key) = $($_.Value)" }

# Display parsed challenge values
$challenge

# Extract necessary parameters from the challenge
$realm = $challenge['realm']
$nonce = $challenge['nonce']
$qop = $challenge['qop']
$algorithm = $challenge['algorithm']

# Ensure qop is an array
$qopOptions = $qop -split '\s*,\s*'

# Choose 'auth-int' if available, otherwise fallback to 'auth'
if ($qopOptions -contains "auth-int") {
    $qop = "auth-int"
}
else {
    $qop = "auth"
}

Write-Output "Selected QOP: $qop"

# Define the preferred algorithm order (strongest to weakest)
$preferredAlgorithms = @("SHA-512/256", "SHA-512", "SHA-384", "SHA-256", "SHA-1", "MD5")

# Ensure serverAlgorithms is an array
if ($algorithm -isnot [System.Array]) {
    $algorithm = @($algorithm)
}

# Select the strongest algorithm that both client and server support
$algorithm = ($preferredAlgorithms | Where-Object { $algorithm -contains $_ } | Select-Object -First 1)

if (-not $algorithm) {
    Write-Output "No supported algorithms found! Server supports: $algorithm"
    exit
}

# Step 2: Hashing functions
function ConvertTo-Hash {
    param (
        [string]$Value,
        [string]$Algorithm
    )

    $crypto = switch ($Algorithm) {
        "MD5" { [System.Security.Cryptography.MD5]::Create() }
        "SHA-1" { [System.Security.Cryptography.SHA1]::Create() }
        "SHA-256" { [System.Security.Cryptography.SHA256]::Create() }
        "SHA-384" { [System.Security.Cryptography.SHA384]::Create() }
        "SHA-512" { [System.Security.Cryptography.SHA512]::Create() }
        "SHA-512/256" {
            # Compute SHA-512 and take first 32 bytes (256 bits)
            $sha512 = [System.Security.Cryptography.SHA512]::Create()
            $fullHash = $sha512.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Value))
            return [System.BitConverter]::ToString($fullHash[0..31]).Replace('-', '').ToLowerInvariant()
        }
    }

    return [System.BitConverter]::ToString($crypto.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Value))).Replace('-', '').ToLowerInvariant()
}

$nc = '00000001'  # Nonce Count
$cnonce = (New-Guid).Guid.Substring(0, 8)  # Generate a random client nonce

# <--- MODIFIED: Decide the method based on qop
if ($qop -eq 'auth-int') {
    $method = 'POST'  # Use POST for auth-int so we can send a body
}
else {
    $method = 'GET'
}
Write-Output "Using method: $method"

# Build the URI path
$uriPath = [System.Uri]$uri
$uriPath = $uriPath.AbsolutePath  # "/users"

# Compute HA1
$HA1 = ConvertTo-Hash -Value "$($username):$($realm):$($password)" -Algorithm $algorithm

# <--- MODIFIED: Handle HA2 for auth-int
if ($qop -eq "auth-int") {
    # Sample request body
    $requestBody =  '{ "test": "auth-int" }'
    $entityBodyHash = ConvertTo-Hash -Value $requestBody -Algorithm $algorithm
    $HA2 = ConvertTo-Hash -Value "$($method):$($uriPath):$($entityBodyHash)" -Algorithm $algorithm

}
else {
    # Standard auth
    $HA2 = ConvertTo-Hash -Value "$($method):$($uriPath)" -Algorithm $algorithm
}

# Compute final response hash
$response = ConvertTo-Hash -Value "$($HA1):$($nonce):$($nc):$($cnonce):$($qop):$($HA2)" -Algorithm $algorithm

# Step 3: Construct the Authorization header
$authHeader = @"
Digest username="$username", realm="$realm", nonce="$nonce", uri="$uriPath", algorithm=$algorithm, response="$response", qop="$qop", nc=$nc, cnonce="$cnonce"
"@

Write-Output "Authorization Header: $authHeader"

# Step 4: Send the authenticated request
$authRequest = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::$method, $uri)
$authRequest.Headers.Authorization = [System.Net.Http.Headers.AuthenticationHeaderValue]::new('Digest', $authHeader)

# <--- MODIFIED: If auth-int, attach the request body
if ($qop -eq "auth-int") {
    $authRequest.Content = [System.Net.Http.StringContent]::new($requestBody, [System.Text.Encoding]::UTF8, "application/json")
}

$response = $httpClient.SendAsync($authRequest).Result

# Extract and display the response headers
$response.Headers | ForEach-Object { "$($_.Key): $($_.Value)" }

# Optionally, get content as string if needed
$content = $response.Content.ReadAsStringAsync().Result
Write-Output "`nResponse Content:`n$content"
