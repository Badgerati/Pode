function ConvertTo-Hash {
    param (
        [string]$Value,
        [string]$Algorithm
    )

    $crypto = switch ($Algorithm) {
        'MD5' { [System.Security.Cryptography.MD5]::Create() }
        'SHA-1' { [System.Security.Cryptography.SHA1]::Create() }
        'SHA-256' { [System.Security.Cryptography.SHA256]::Create() }
        'SHA-384' { [System.Security.Cryptography.SHA384]::Create() }
        'SHA-512' { [System.Security.Cryptography.SHA512]::Create() }
        'SHA-512/256' {
            # Compute SHA-512 and take first 32 bytes (256 bits)
            $sha512 = [System.Security.Cryptography.SHA512]::Create()
            $fullHash = $sha512.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Value))
            return [System.BitConverter]::ToString($fullHash[0..31]).Replace('-', '').ToLowerInvariant()
        }
    }

    return [System.BitConverter]::ToString($crypto.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Value))).Replace('-', '').ToLowerInvariant()
}

function ChallengeDigest {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Connect', 'Delete', 'Get', 'Head', 'Merge', 'Options', 'Patch', 'Post', 'Put', 'Trace')]
        [string]$Method,

        [Parameter(Mandatory = $true)]
        [string]$Uri
    )
    # Create an HTTP client
    $handler = [System.Net.Http.HttpClientHandler]::new()
    $httpClient = [System.Net.Http.HttpClient]::new($handler)

    # Step 1: Send an initial request to get the challenge
    $initialRequest = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::$Method, $Uri)
    $initialResponse = $httpClient.SendAsync($initialRequest).Result
    if ($null -eq $initialResponse) {
        Throw "Server $Uri is not responding"
    }

    # Extract WWW-Authenticate headers safely
    $wwwAuthHeaders = $initialResponse.Headers.GetValues('WWW-Authenticate')
    # Filter to get only the Digest authentication scheme
    $wwwAuthHeader = $wwwAuthHeaders | Where-Object { $_ -match '^Digest' }

    Write-Verbose 'Extracted WWW-Authenticate headers:'
    $wwwAuthHeaders | ForEach-Object { Write-Verbose " - $_" }

    if (-not $wwwAuthHeader) {
        Throw 'Digest authentication not supported by server!'
    }

    # Extract Digest Authentication challenge values
    $challenge = @{}

    if ($wwwAuthHeader -match '^Digest ') {
        $headerContent = $wwwAuthHeader -replace '^Digest ', ''
        Write-Verbose "RAW HEADER: $headerContent"

        # 1) CAPTURE supported algorithms
        if ($headerContent -match 'algorithm=((?:SHA-1|SHA-256|SHA-384|SHA-512(?:/256)?|MD5)(?:,\s*(?:SHA-1|SHA-256|SHA-384|SHA-512(?:/256)?|MD5))*)') {
            $algorithms = ($matches[1] -split '\s*,\s*')
            Write-Verbose "Supported Algorithms: $algorithms"
            $challenge['algorithm'] = $algorithms
        }

        # 2) REMOVE algorithm parameter
        $headerContent = $headerContent -replace 'algorithm=(?:SHA-1|SHA-256|SHA-384|SHA-512(?:/256)?|MD5)(?:,\s*(?:SHA-1|SHA-256|SHA-384|SHA-512(?:/256)?|MD5))*\s*,?', ''
        # 3) CLEAN UP extra commas/whitespace
        $headerContent = $headerContent -replace ',\s*,', ','
        $headerContent = $headerContent -replace '^\s*,', ''

        # Split remaining parameters safely
        $headerContent -split ', ' | ForEach-Object {
            $key, $value = $_ -split '=', 2
            if ($key -and $value) {
                $challenge[$key.Trim()] = $value.Trim('"')
            }
        }
    }

    Write-Verbose 'Extracted Digest Authentication Challenge:'
    $challenge.GetEnumerator() | ForEach-Object { Write-Verbose "$($_.Key) = $($_.Value)" }

    $realm = $challenge['realm']
    $nonce = $challenge['nonce']
    $qop = $challenge['qop']
    $algorithm = $challenge['algorithm']

    if (('Post', 'Put', 'Patch') -contains $Method) {
        if ($qop -eq 'auth-int' -or $qop -eq 'auth,auth-int') {
            $qop = 'auth-int'
        }
        else {
            $qop = 'auth'
        }
    }
    else {
        if ($qop -eq 'auth' -or $qop -eq 'auth,auth-int') {
            $qop = 'auth'
        }
        else {
            throw "$Method doesn't support QualityOfProtection 'auth-int'"
        }
    }

    Write-Verbose "Selected QOP: $qop"

    $preferredAlgorithms = @('SHA-512/256', 'SHA-512', 'SHA-384', 'SHA-256', 'SHA-1', 'MD5')
    if ($algorithm -isnot [System.Array]) {
        $algorithm = @($algorithm)
    }
    $algorithm = ($preferredAlgorithms | Where-Object { $algorithm -contains $_ } | Select-Object -First 1)
    if (-not $algorithm) {
        Throw "No supported algorithms found! Server supports: $algorithm"
    }
    return [PSCustomObject]@{
        realm         = $realm
        nonce         = $nonce
        qop           = $qop
        algorithm     = $algorithm
        wwwAuthHeader = $wwwAuthHeader
        uri           = $Uri
        httpClient    = $httpClient
        method        = $Method
    }
}

function ResponseDigest {
    [OutputType([Microsoft.PowerShell.Commands.BasicHtmlWebResponseObject])]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Challenge,

        # Credential for Digest authentication (required)
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential]$Credential,
        [hashtable]$Body
    )
    $nc = '00000001'  # Nonce Count
    $cnonce = (New-Guid).Guid.Substring(0, 8)  # Generate a random client nonce

    $Method = $Challenge.Method.ToUpper()
    Write-Verbose "Using method: $Method"

    # Build the URI path
    $uriPath = ([System.Uri]$Challenge.uri).AbsolutePath

    # Compute HA1
    $HA1 = ConvertTo-Hash -Value "$($Credential.UserName):$($Challenge.realm):$($Credential.GetNetworkCredential().Password)" -Algorithm $Challenge.algorithm

    if ($Challenge.qop -eq 'auth-int') {
        if (('Post', 'Put', 'Patch') -notcontains $Method) {
            Throw "'auth-int' doesn't support $Method"
        }
        $requestBody = $Body | ConvertTo-Json
        $entityBodyHash = ConvertTo-Hash -Value $requestBody -Algorithm $Challenge.algorithm
        $HA2 = ConvertTo-Hash -Value "$($Method):$($uriPath):$($entityBodyHash)" -Algorithm $Challenge.algorithm
    }
    else {
        $HA2 = ConvertTo-Hash -Value "$($Method):$($uriPath)" -Algorithm $Challenge.algorithm
    }

    $response = ConvertTo-Hash -Value "$($HA1):$($Challenge.nonce):$($nc):$($cnonce):$($Challenge.qop):$($HA2)" -Algorithm $Challenge.algorithm

    # Build the Authorization header using StringBuilder
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.Append('Digest username="').Append($Credential.UserName).Append('"')
    [void]$sb.Append(', realm="').Append($Challenge.realm).Append('"')
    [void]$sb.Append(', nonce="').Append($Challenge.nonce).Append('"')
    [void]$sb.Append(', uri="').Append($uriPath).Append('"')
    [void]$sb.Append(', algorithm=').Append($Challenge.algorithm)
    [void]$sb.Append(', response="').Append($response).Append('"')
    [void]$sb.Append(', qop="').Append($Challenge.qop).Append('"')
    [void]$sb.Append(', nc=').Append($nc)
    [void]$sb.Append(', cnonce="').Append($cnonce).Append('"')

    # Construct the authenticated request
    $authRequest = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::$Method, $Challenge.uri)
    $authRequest.Headers.Authorization = [System.Net.Http.Headers.AuthenticationHeaderValue]::new('Digest', $sb.ToString())

    if ($Challenge.qop -eq 'auth-int') {
        $authRequest.Content = [System.Net.Http.StringContent]::new($requestBody, [System.Text.Encoding]::UTF8, 'application/json')
    }

    try {
        $rawResponse = $Challenge.httpClient.SendAsync($authRequest).Result
    }
    catch {
        Throw "Error sending the authenticated request: $_"
    }

    $contentStream = $rawResponse.Content.ReadAsStream()
    $timeout = [TimeSpan]::FromSeconds(100)
    $cancellationToken = [System.Threading.CancellationToken]::None
    return [Microsoft.PowerShell.Commands.BasicHtmlWebResponseObject]::new($rawResponse, $contentStream, $timeout, $cancellationToken)
}

function Invoke-WebRequestDigest {
    [CmdletBinding(DefaultParameterSetName = 'Uri')]
    [OutputType([Microsoft.PowerShell.Commands.BasicHtmlWebResponseObject])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [Uri]$Uri,

        [Parameter(Position = 1)]
        [ValidateSet('GET', 'POST', 'PUT', 'DELETE', 'HEAD', 'OPTIONS', 'TRACE', 'PATCH', 'MERGE', 'CONNECT')]
        [string]$Method = 'GET',

        [Parameter()]
        $Body,

        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential]$Credential,

        [Parameter()]
        [hashtable]$Headers,

        [Parameter()]
        [string]$ContentType = 'application/json',

        [Parameter()]
        [int]$TimeoutSec = 100
    )
    if (-not $Credential) {
        Throw 'A credential is required for Digest authentication.'
    }

    try {
        $challenge = ChallengeDigest -Uri $Uri -Method $Method
    }
    catch {
        Throw "Error retrieving Digest authentication challenge: $_"
    }

    try {
        if ($Body -and ($ContentType -match 'application/json')) {
            if ($Body -isnot [string]) {
                $Body = $Body | ConvertTo-Json -Compress
            }
        }

        $nc = '00000001'  # Nonce Count
        $cnonce = (New-Guid).Guid.Substring(0, 8)  # Generate a random client nonce

        $Method = $Challenge.Method.ToUpper()
        Write-Verbose "Using method: $Method"

        # Build the URI path
        $uriPath = ([System.Uri]$Challenge.uri).AbsolutePath

        # Compute HA1
        $HA1 = ConvertTo-Hash -Value "$($Credential.UserName):$($Challenge.realm):$($Credential.GetNetworkCredential().Password)" -Algorithm $Challenge.algorithm

        if ($Challenge.qop -eq 'auth-int') {
            if (('Post', 'Put', 'Patch') -notcontains $Method) {
                Throw "'auth-int' doesn't support $Method"
            }
            $requestBody = $Body | ConvertTo-Json
            $entityBodyHash = ConvertTo-Hash -Value $requestBody -Algorithm $Challenge.algorithm
            $HA2 = ConvertTo-Hash -Value "$($Method):$($uriPath):$($entityBodyHash)" -Algorithm $Challenge.algorithm
        }
        else {
            $HA2 = ConvertTo-Hash -Value "$($Method):$($uriPath)" -Algorithm $Challenge.algorithm
        }

        $response = ConvertTo-Hash -Value "$($HA1):$($Challenge.nonce):$($nc):$($cnonce):$($Challenge.qop):$($HA2)" -Algorithm $Challenge.algorithm

        # Build the Authorization header using StringBuilder
        $sb = [System.Text.StringBuilder]::new()
        [void]$sb.Append('Digest username="').Append($Credential.UserName).Append('"')
        [void]$sb.Append(', realm="').Append($Challenge.realm).Append('"')
        [void]$sb.Append(', nonce="').Append($Challenge.nonce).Append('"')
        [void]$sb.Append(', uri="').Append($uriPath).Append('"')
        [void]$sb.Append(', algorithm=').Append($Challenge.algorithm)
        [void]$sb.Append(', response="').Append($response).Append('"')
        [void]$sb.Append(', qop="').Append($Challenge.qop).Append('"')
        [void]$sb.Append(', nc=').Append($nc)
        [void]$sb.Append(', cnonce="').Append($cnonce).Append('"')

        # Construct the authenticated request
        $authRequest = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::$Method, $Challenge.uri)
        $authRequest.Headers.Authorization = [System.Net.Http.Headers.AuthenticationHeaderValue]::new('Digest', $sb.ToString())

        # Add additional headers if provided
        if ($Headers) {
            foreach ($key in $Headers.Keys) {
            $null= $authRequest.Headers.TryAddWithoutValidation($key, $Headers[$key])
            }
        }

        if ($Challenge.qop -eq 'auth-int') {
            $authRequest.Content = [System.Net.Http.StringContent]::new($requestBody, [System.Text.Encoding]::UTF8, 'application/json')
        }

        try {
            $rawResponse = $Challenge.httpClient.SendAsync($authRequest).Result
        }
        catch {
            Throw "Error sending the authenticated request: $_"
        }

        $contentStream = $rawResponse.Content.ReadAsStream()
        $timeout = [TimeSpan]::FromSeconds(100)
        $cancellationToken = [System.Threading.CancellationToken]::None
        return [Microsoft.PowerShell.Commands.BasicHtmlWebResponseObject]::new($rawResponse, $contentStream, $timeout, $cancellationToken)
    }
    catch {
        Throw "Error sending Digest authenticated request: $_"
    }
}

# Example call:
$uri = 'http://localhost:8081/users'
$username = 'morty'
$password = 'pickle'

$securePassword = ConvertTo-SecureString $password -AsPlainText -Force
$credential = [System.Management.Automation.PSCredential]::new($username, $securePassword)

$response = Invoke-WebRequestDigest -Uri $uri -Method 'GET' -Credential $credential
$response | Format-List *
