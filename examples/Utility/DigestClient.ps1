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

# Extract the WWW-Authenticate header
$wwwAuthHeader = $initialResponse.Headers.WWWAuthenticate | Where-Object { $_.Scheme -eq 'Digest' }
Write-Output $wwwAuthHeader
if (-not $wwwAuthHeader) {
    Write-Output 'Digest authentication not supported by server!'
    exit
}

# Parse the Digest authentication challenge correctly
$challenge = @{}
$wwwAuthHeader.Parameter -split ', ' | ForEach-Object {
    $key, $value = $_ -split '=', 2
    if ($key -and $value) {
        $challenge[$key.Trim()] = $value.Trim('"')
    }
}

# Display parsed challenge values
$challenge

# Extract necessary parameters from the challenge
$realm = $challenge['realm']
$nonce = $challenge['nonce']
$qop = $challenge['qop']
$algorithm = $challenge['algorithm']

# Ensure algorithm is supported
$validAlgorithms = @('SHA-1', 'SHA-256', 'SHA-512-256')
if ($algorithm -eq 'MD5' -or -not ($validAlgorithms -contains $algorithm)) {
    Write-Output "Server uses unsupported algorithm: $algorithm"
    exit
}

# Step 2: Hashing functions
function ConvertTo-Hash {
    param (
        [string]$Value,
        [string]$Algorithm
    )

    $crypto = switch ($Algorithm) {
        'SHA-1' { [System.Security.Cryptography.SHA1]::Create() }
        'SHA-256' { [System.Security.Cryptography.SHA256]::Create() }
        'SHA-512-256' {
            # SHA-512-256 is SHA-512 truncated to 256 bits (first 32 bytes)
            $sha512 = [System.Security.Cryptography.SHA512]::Create()
            $fullHash = $sha512.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Value))
            return [System.BitConverter]::ToString($fullHash[0..31]).Replace('-', '').ToLowerInvariant()
        }
        Default { throw "Unsupported algorithm: $Algorithm" }
    }

    return [System.BitConverter]::ToString($crypto.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Value))).Replace('-', '').ToLowerInvariant()
}

$nc = '00000001'  # Nonce Count
$cnonce = (New-Guid).Guid.Substring(0, 8)  # Generate a random client nonce
$method = 'GET'
$uriPath = [System.Uri]$uri
$uriPath = $uriPath.AbsolutePath  # Extract only "/users"

# Compute HA1 (username:realm:password)
$HA1 = ConvertTo-Hash -Value "$($username):$($realm):$($password)" -Algorithm $algorithm

# Compute HA2 (method:uri)
$HA2 = ConvertTo-Hash -Value "$($method):$($uriPath)" -Algorithm $algorithm

# Compute final response hash
$response = ConvertTo-Hash -Value "$($HA1):$($nonce):$($nc):$($cnonce):$($qop):$($HA2)" -Algorithm $algorithm

# Step 3: Construct the Authorization header
$authHeader = @"
Digest username="$username", realm="$realm", nonce="$nonce", uri="$uriPath", algorithm=$algorithm, response="$response", qop="$qop", nc=$nc, cnonce="$cnonce"
"@

# Step 4: Send the authenticated request
$authRequest = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Get, $uri)
$authRequest.Headers.Authorization = [System.Net.Http.Headers.AuthenticationHeaderValue]::new('Digest', $authHeader)

$response = $httpClient.SendAsync($authRequest).Result

# Extract and display the response headers
$response.Headers | ForEach-Object { "$($_.Key): $($_.Value)" }

# Optionally, get content as string if needed
$content = $response.Content.ReadAsStringAsync().Result
Write-Output "`nResponse Content:`n$content"
