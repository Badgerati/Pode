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

<#
.SYNOPSIS
    Sends an HTTP request using Digest authentication and returns a web response.

.DESCRIPTION
    The Invoke-WebRequestDigest function performs an HTTP request with Digest authentication,
    handling HTTP headers, authentication challenges, retries, and timeouts.
    It returns a BasicHtmlWebResponseObject similar to Invoke-WebRequest.

.PARAMETER Uri
    The target URI for the request.

.PARAMETER Method
    The HTTP method to use for the request. Default is 'GET'.

.PARAMETER Body
    The request body, required for methods like POST, PUT, and PATCH.

.PARAMETER Credential
    The PSCredential object containing the username and password for Digest authentication.

.PARAMETER Headers
    A hashtable of additional headers to include in the request.

.PARAMETER ContentType
    The Content-Type of the request body. Default is 'application/json'.

.PARAMETER OperationTimeoutSeconds
    The maximum time in seconds before the request times out. Default is 100.

.PARAMETER ConnectionTimeoutSeconds
    The timeout in seconds for establishing a connection. Default is 100.

.PARAMETER DisableKeepAlive
    If specified, disables persistent connections by adding the 'Connection: close' header.

.PARAMETER HttpVersion
    The HTTP version to use, such as '1.1' or '2.0'. Default is '1.1'.

.PARAMETER MaximumRetryCount
    The number of times to retry the request in case of failure. Default is 1.

.PARAMETER RetryIntervalSec
    The interval in seconds between retry attempts. Default is 1.

.PARAMETER OutFile
    If specified, writes the response body to the specified file instead of returning content.

.PARAMETER PassThru
    If specified, returns the response object even if OutFile is used.

.PARAMETER SkipCertificateCheck
    If specified, disables SSL certificate validation (useful for self-signed certificates).

.PARAMETER SslProtocol
    Specifies the allowed SSL/TLS protocol(s) to use (e.g., 'Tls12').

.PARAMETER TransferEncoding
    The value for the 'Transfer-Encoding' header.

.PARAMETER UserAgent
    The User-Agent string to use in the request.

.OUTPUTS
    - Returns a [Microsoft.PowerShell.Commands.BasicHtmlWebResponseObject].
    - If OutFile is specified, writes response data to the specified file.

.EXAMPLE
    $cred = Get-Credential
    $response = Invoke-WebRequestDigest -Uri 'https://example.com/data' -Method 'GET' -Credential $cred
    Write-Output $response.Content

.EXAMPLE
    $body = @{ "name" = "John Doe"; "email" = "john@example.com" }
    $cred = Get-Credential
    $response = Invoke-WebRequestDigest -Uri 'https://example.com/users' -Method 'POST' -Credential $cred -Body $body -ContentType 'application/json'
    Write-Output $response.Content

.EXAMPLE
    # Download file
    Invoke-WebRequestDigest -Uri 'https://example.com/file.zip' -Method 'GET' -Credential $cred -OutFile 'C:\Downloads\file.zip'

.NOTES
    - This function provides full control over HTTP requests with Digest authentication.
    - Supports custom headers, connection options, timeouts, and retries.
    - Unlike Invoke-RestMethodDigest, this function does not automatically parse JSON/XML.
#>
function Invoke-WebRequestDigest {
    [CmdletBinding(DefaultParameterSetName = 'Uri')]
    [OutputType([Microsoft.PowerShell.Commands.BasicHtmlWebResponseObject])]
    param(
        # URI of the request (required)
        [Parameter(Mandatory = $true, Position = 0)]
        [Uri]$Uri,

        # HTTP method (default GET)
        [Parameter(Position = 1)]
        [ValidateSet('GET', 'POST', 'PUT', 'DELETE', 'HEAD', 'OPTIONS', 'TRACE', 'PATCH', 'MERGE', 'CONNECT')]
        [string]$Method = 'GET',

        # Request body (for POST/PUT/PATCH, etc.)
        [Parameter()]
        $Body,

        # Credential for Digest authentication (required)
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential]$Credential,

        # Additional headers (as a hashtable)
        [Parameter()]
        [hashtable]$Headers,

        # Content type for the request body (default application/json)
        [Parameter()]
        [string]$ContentType = 'application/json',

        # Timeout (for the overall operation) in seconds
        [Parameter()]
        [int]$OperationTimeoutSeconds = 100,

        # Connection timeout in seconds
        [Parameter()]
        [int]$ConnectionTimeoutSeconds = 100,

        # Disable persistent connections (KeepAlive)
        [Parameter()]
        [switch]$DisableKeepAlive,

        # Specify the HTTP version (e.g. '1.1' or '2.0')
        [Parameter()]
        [string]$HttpVersion = '1.1',

        # Maximum number of retries (if request fails)
        [Parameter()]
        [int]$MaximumRetryCount = 1,

        # Interval between retries (seconds)
        [Parameter()]
        [int]$RetryIntervalSec = 1,

        # If provided, write response body to this file
        [Parameter()]
        [string]$OutFile,

        # If specified, output the response object even if OutFile is used
        [Parameter()]
        [switch]$PassThru,

        # Skip certificate validation (useful for self-signed certs)
        [Parameter()]
        [switch]$SkipCertificateCheck,

        # Specify allowed SSL/TLS protocol(s) (e.g. 'Tls12')
        [Parameter()]
        [string]$SslProtocol,

        # Transfer-Encoding header value to set on the request
        [Parameter()]
        [string]$TransferEncoding,

        # User-Agent string to use on the request
        [Parameter()]
        [string]$UserAgent
    )

    # Validate that we have a credential
    if (-not $Credential) {
        Throw 'A credential is required for Digest authentication.'
    }

    # Use HttpClientHandler
    $handler = [System.Net.Http.HttpClientHandler]::new()
    if ($SkipCertificateCheck) {
        $handler.ServerCertificateCustomValidationCallback = { return $true }
    }
    if ($SslProtocol) {
        $handler.SslProtocols = [System.Enum]::Parse(
            [System.Security.Authentication.SslProtocols], $SslProtocol)
    }
    $httpClient = [System.Net.Http.HttpClient]::new($handler)

    $httpClient.Timeout = [TimeSpan]::FromSeconds($ConnectionTimeoutSeconds)

    # If DisableKeepAlive is specified, add a header to close the connection.
    if ($DisableKeepAlive) {
        if (-not $Headers) { $Headers = @{} }
        $Headers['Connection'] = 'close'
    }

    # Use the challenge function to get the digest details.
    try {
        $challenge = ChallengeDigest -Uri $Uri -Method $Method
    }
    catch {
        Throw "Error retrieving Digest authentication challenge: $_"
    }

    try {
        # If a body is provided and content type is JSON, convert it if necessary.
        if ($Body -and ($ContentType -match 'application/json')) {
            if ($Body -isnot [string]) {
                $Body = $Body | ConvertTo-Json -Compress
            }
        }

        # Build the digest response parameters.
        $nc = '00000001'
        $cnonce = (New-Guid).Guid.Substring(0, 8)
        $Method = $challenge.Method.ToUpper()
        Write-Verbose "Using method: $Method"
        $uriPath = ([System.Uri]$challenge.uri).AbsolutePath

        # Compute HA1
        $HA1 = ConvertTo-Hash -Value "$($Credential.UserName):$($challenge.realm):$($Credential.GetNetworkCredential().Password)" -Algorithm $challenge.algorithm

        if ($challenge.qop -eq 'auth-int') {
            if (('Post', 'Put', 'Patch') -notcontains $Method) {
                Throw "'auth-int' doesn't support $Method"
            }
            $requestBody = $Body | ConvertTo-Json
            $entityBodyHash = ConvertTo-Hash -Value $requestBody -Algorithm $challenge.algorithm
            $HA2 = ConvertTo-Hash -Value "$($Method):$($uriPath):$($entityBodyHash)" -Algorithm $challenge.algorithm
        }
        else {
            $HA2 = ConvertTo-Hash -Value "$($Method):$($uriPath)" -Algorithm $challenge.algorithm
        }

        $responseHash = ConvertTo-Hash -Value "$($HA1):$($challenge.nonce):$($nc):$($cnonce):$($challenge.qop):$HA2" -Algorithm $challenge.algorithm

        # Build the Authorization header using StringBuilder.
        $sb = [System.Text.StringBuilder]::new()
        [void]$sb.Append('Digest username="').Append($Credential.UserName).Append('"')
        [void]$sb.Append(', realm="').Append($challenge.realm).Append('"')
        [void]$sb.Append(', nonce="').Append($challenge.nonce).Append('"')
        [void]$sb.Append(', uri="').Append($uriPath).Append('"')
        [void]$sb.Append(', algorithm=').Append($challenge.algorithm)
        [void]$sb.Append(', response="').Append($responseHash).Append('"')
        [void]$sb.Append(', qop="').Append($challenge.qop).Append('"')
        [void]$sb.Append(', nc=').Append($nc)
        [void]$sb.Append(', cnonce="').Append($cnonce).Append('"')

        # Create the HttpRequestMessage.
        $authRequest = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::$Method, $challenge.uri)
        $authRequest.Headers.Authorization = [System.Net.Http.Headers.AuthenticationHeaderValue]::new('Digest', $sb.ToString())

        # Set the HTTP version if provided.
        if ($HttpVersion) {
            $authRequest.Version = [System.Version]$HttpVersion
        }

        # Add additional headers (if any) to the request.
        if ($Headers) {
            foreach ($key in $Headers.Keys) {
                $authRequest.Headers.TryAddWithoutValidation($key, $Headers[$key]) | Out-Null
            }
        }

        # Set Transfer-Encoding if provided.
        if ($TransferEncoding) {
            $authRequest.Headers.TryAddWithoutValidation("Transfer-Encoding", $TransferEncoding) | Out-Null
        }

        # Set User-Agent if provided.
        if ($UserAgent) {
            $authRequest.Headers.UserAgent.Clear()
            $authRequest.Headers.UserAgent.ParseAdd($UserAgent)
        }

        if ($challenge.qop -eq 'auth-int') {
            $authRequest.Content = [System.Net.Http.StringContent]::new($requestBody, [System.Text.Encoding]::UTF8, $ContentType)
        }

        # Implement a simple retry loop.
        $retryCount = 0
        do {
            try {
                $rawResponse = $challenge.httpClient.SendAsync($authRequest).Result
                break
            }
            catch {
                if (++$retryCount -ge $MaximumRetryCount) {
                    Throw "Error sending the authenticated request after $MaximumRetryCount attempts: $_"
                }
                else {
                    Write-Verbose "Retrying in $RetryIntervalSec seconds..."
                    Start-Sleep -Seconds $RetryIntervalSec
                }
            }
        } while ($true)

        # Optionally write response to file.
        if ($OutFile) {
            $mediaType = $rawResponse.Content.Headers.ContentType.MediaType
            if ($mediaType -match '^(text|application/json|application/xml)') {
                $contentString = $rawResponse.Content.ReadAsStringAsync().Result
                Set-Content -Path $OutFile -Value $contentString -Encoding UTF8
            }
            else {
                $rawResponse.Content.ReadAsByteArrayAsync().Result | Set-Content -Path $OutFile -Encoding Byte
            }
            if (-not $PassThru) { return }
        }

        # Wrap the response in a BasicHtmlWebResponseObject using the OperationTimeoutSeconds value.
        $contentStream = $rawResponse.Content.ReadAsStream()
        $timeout = [TimeSpan]::FromSeconds($OperationTimeoutSeconds)
        $cancellationToken = [System.Threading.CancellationToken]::None
        return [Microsoft.PowerShell.Commands.BasicHtmlWebResponseObject]::new($rawResponse, $contentStream, $timeout, $cancellationToken)
    }
    catch {
        Throw "Error sending Digest authenticated request: $_"
    }
}


<#
.SYNOPSIS
    Sends an HTTP or REST request using Digest authentication and returns parsed data.

.DESCRIPTION
    The Invoke-RestMethodDigest function performs an HTTP request with Digest authentication,
    leveraging Invoke-WebRequestDigest under the hood. It automatically parses the response
    content into an object, supporting JSON and XML formats.

.PARAMETER Uri
    The target URI for the request.

.PARAMETER Method
    The HTTP method to use for the request. Default is 'GET'.

.PARAMETER Body
    The request body, required for methods like POST, PUT, and PATCH.

.PARAMETER Credential
    The PSCredential object containing the username and password for Digest authentication.

.PARAMETER Headers
    A hashtable of additional headers to include in the request.

.PARAMETER ContentType
    The Content-Type of the request body. Default is 'application/json'.

.PARAMETER OperationTimeoutSeconds
    The maximum time in seconds before the request times out. Default is 100.

.PARAMETER ConnectionTimeoutSeconds
    The timeout in seconds for establishing a connection. Default is 100.

.PARAMETER DisableKeepAlive
    If specified, disables persistent connections by adding the 'Connection: close' header.

.PARAMETER HttpVersion
    The HTTP version to use, such as '1.1' or '2.0'. Default is '1.1'.

.PARAMETER MaximumRetryCount
    The number of times to retry the request in case of failure. Default is 1.

.PARAMETER RetryIntervalSec
    The interval in seconds between retry attempts. Default is 1.

.PARAMETER OutFile
    If specified, writes the response body to the specified file instead of returning content.

.PARAMETER PassThru
    If specified, returns the response object even if OutFile is used.

.PARAMETER SkipCertificateCheck
    If specified, disables SSL certificate validation (useful for self-signed certificates).

.PARAMETER SslProtocol
    Specifies the allowed SSL/TLS protocol(s) to use (e.g., 'Tls12').

.PARAMETER TransferEncoding
    The value for the 'Transfer-Encoding' header.

.PARAMETER UserAgent
    The User-Agent string to use in the request.

.OUTPUTS
    - JSON responses are converted to PowerShell objects.
    - XML responses are parsed into XML objects.
    - Plain text or other data is returned as-is.

.EXAMPLE
    $cred = Get-Credential
    $response = Invoke-RestMethodDigest -Uri 'https://example.com/api/data' -Method 'GET' -Credential $cred
    Write-Output $response

.EXAMPLE
    $body = @{ "name" = "John Doe"; "email" = "john@example.com" }
    $cred = Get-Credential
    $response = Invoke-RestMethodDigest -Uri 'https://example.com/api/users' -Method 'POST' -Credential $cred -Body $body -ContentType 'application/json'
    Write-Output $response

.NOTES
    - This function is a wrapper around Invoke-WebRequestDigest and provides an easier way
      to work with REST APIs by automatically parsing the response content.
    - Use Invoke-WebRequestDigest if you need full access to response headers and raw content.
#>
function Invoke-RestMethodDigest {
    [CmdletBinding(DefaultParameterSetName = 'Uri')]
    [OutputType([xml])]
    [OutputType([psobject])]
    param(
        # URI of the request (required)
        [Parameter(Mandatory = $true, Position = 0)]
        [Uri]$Uri,

        # HTTP method (default GET)
        [Parameter(Position = 1)]
        [ValidateSet('GET', 'POST', 'PUT', 'DELETE', 'HEAD', 'OPTIONS', 'TRACE', 'PATCH', 'MERGE', 'CONNECT')]
        [string]$Method = 'GET',

        # Request body (for POST/PUT/PATCH, etc.)
        [Parameter()]
        $Body,

        # Credential for Digest authentication (required)
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential]$Credential,

        # Additional headers (as a hashtable)
        [Parameter()]
        [hashtable]$Headers,

        # Content type for the request body (default application/json)
        [Parameter()]
        [string]$ContentType = 'application/json',

        # Timeout (for the overall operation) in seconds
        [Parameter()]
        [int]$OperationTimeoutSeconds = 100,

        # Connection timeout in seconds
        [Parameter()]
        [int]$ConnectionTimeoutSeconds = 100,

        # Disable persistent connections (KeepAlive)
        [Parameter()]
        [switch]$DisableKeepAlive,

        # Specify the HTTP version (e.g. '1.1' or '2.0')
        [Parameter()]
        [string]$HttpVersion = '1.1',

        # Maximum number of retries (if request fails)
        [Parameter()]
        [int]$MaximumRetryCount = 1,

        # Interval between retries (seconds)
        [Parameter()]
        [int]$RetryIntervalSec = 1,

        # If provided, write response body to this file
        [Parameter()]
        [string]$OutFile,

        # If specified, output the response object even if OutFile is used
        [Parameter()]
        [switch]$PassThru, 

        # Skip certificate validation (useful for self-signed certs)
        [Parameter()]
        [switch]$SkipCertificateCheck,

        # Specify allowed SSL/TLS protocol(s) (e.g. 'Tls12')
        [Parameter()]
        [string]$SslProtocol,
 

        # Transfer-Encoding header value
        [Parameter()]
        [string]$TransferEncoding,

        # User-Agent string to use on the request
        [Parameter()]
        [string]$UserAgent
    )

    # Build a parameter hashtable for Invoke-WebRequestDigest
    $params = @{
        Uri                      = $Uri
        Method                   = $Method
        Body                     = $Body
        Credential               = $Credential
        Headers                  = $Headers
        ContentType              = $ContentType
        OperationTimeoutSeconds  = $OperationTimeoutSeconds
        ConnectionTimeoutSeconds = $ConnectionTimeoutSeconds
        DisableKeepAlive         = $DisableKeepAlive
        HttpVersion              = $HttpVersion
        MaximumRetryCount        = $MaximumRetryCount
        RetryIntervalSec         = $RetryIntervalSec
        OutFile                  = $OutFile
        PassThru                 = $PassThru 
        SkipCertificateCheck     = $SkipCertificateCheck
        SslProtocol              = $SslProtocol 
        TransferEncoding         = $TransferEncoding
        UserAgent                = $UserAgent
    }

    # Call the digest-enabled web request function
    $webResponse = Invoke-WebRequestDigest @params

    if ($null -eq $webResponse) {
        return $null
    }

    # Parse the response content based on its media type
    $content = $webResponse.Content
    if ($content) {
        # Get Content-Type header if available
        $mediaType = $webResponse.Headers.'Content-Type'
        if ($mediaType -match 'application/json') {
            return $content | ConvertFrom-Json
        }
        elseif ($mediaType -match 'application/xml' -or $mediaType -match 'text/xml') {
            return [xml]$content
        }
        else {
            # For non-parsed content (plain text or other formats)
            return $content
        }
    }
    else {
        return $null
    }
}

Export-ModuleMember -Function Invoke-WebRequestDigest
Export-ModuleMember -Function Invoke-RestMethodDigest
