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
        [ValidateSet('Connect', 'Delete', 'Get', 'Head', 'Merge', 'Options', 'Patch', 'Post', 'Put', 'Trace' )]
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
        Throw "Server $uri is not responding"
    }

    # Extract WWW-Authenticate headers safely
    $wwwAuthHeaders = $initialResponse.Headers.GetValues('WWW-Authenticate')

    # Filter to get only the Digest authentication scheme
    $wwwAuthHeader = $wwwAuthHeaders | Where-Object { $_ -match '^Digest' }

    # Debug output
    Write-Verbose 'Extracted WWW-Authenticate headers:'
    $wwwAuthHeaders | ForEach-Object { Write-Verbose " - $_" }

    # Ensure we have a Digest header before continuing
    if (-not $wwwAuthHeader) {
        Throw 'Digest authentication not supported by server!'
    }

    ## Extract Digest Authentication challenge values correctly
    $challenge = @{}

    # Ensure the header contains "Digest"
    if ($wwwAuthHeader -match '^Digest ') {
        # Remove "Digest " prefix
        $headerContent = $wwwAuthHeader -replace '^Digest ', ''

        Write-Verbose "RAW HEADER: $headerContent"

        # 1) CAPTURE
        if ($headerContent -match 'algorithm=((?:SHA-1|SHA-256|SHA-384|SHA-512(?:/256)?|MD5)(?:,\s*(?:SHA-1|SHA-256|SHA-384|SHA-512(?:/256)?|MD5))*)') {

            $algorithms = ($matches[1] -split '\s*,\s*')
            Write-Verbose "Supported Algorithms: $algorithms"
            $challenge['algorithm'] = $algorithms
        }

        # 2) REMOVE
        $headerContent = $headerContent -replace 'algorithm=(?:SHA-1|SHA-256|SHA-384|SHA-512(?:/256)?|MD5)(?:,\s*(?:SHA-1|SHA-256|SHA-384|SHA-512(?:/256)?|MD5))*\s*,?', ''

        # 3) CLEAN UP ANY EXTRA COMMAS/WHITESPACE
        $headerContent = $headerContent -replace ',\s*,', ','
        $headerContent = $headerContent -replace '^\s*,', ''

        # Now split the rest of the parameters safely
        $headerContent -split ', ' | ForEach-Object {
            $key, $value = $_ -split '=', 2
            if ($key -and $value) {
                $challenge[$key.Trim()] = $value.Trim('"')
            }
        }
    }

    # Output the parsed challenge
    Write-Verbose 'Extracted Digest Authentication Challenge:'
    $challenge | ForEach-Object { Write-Verbose "$($_.Key) = $($_.Value)" }

    # Display parsed challenge values
    Write-Verbose $challenge

    # Extract necessary parameters from the challenge

    $realm = $challenge['realm']
    $nonce = $challenge['nonce']
    $qop = $challenge['qop']
    $algorithm = $challenge['algorithm']

    # Ensure qop is an array
    #   $qopOptions = $qop -split '\s*,\s*'

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

    # Define the preferred algorithm order (strongest to weakest)
    $preferredAlgorithms = @('SHA-512/256', 'SHA-512', 'SHA-384', 'SHA-256', 'SHA-1', 'MD5')

    # Ensure serverAlgorithms is an array
    if ($algorithm -isnot [System.Array]) {
        $algorithm = @($algorithm)
    }

    # Select the strongest algorithm that both client and server support
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

    Write-Verbose "Using method: $method"

    # Build the URI path
    $uriPath = [System.Uri]$Challenge.uri
    $uriPath = $uriPath.AbsolutePath  # "/users"
    # Ensure a credential was provided
   
    # Compute HA1
    $HA1 = ConvertTo-Hash -Value "$($Credential.UserName):$($Challenge.realm):$($Credential.GetNetworkCredential().Password)" -Algorithm $Challenge.algorithm

    # <--- MODIFIED: Handle HA2 for auth-int
    if ($Challenge.qop -eq 'auth-int') {
        if (('Post', 'Put', 'Patch') -notcontains $Method) {
            Throw "'auth-int' doens't support $Method"
        }
        # Sample request body
        $requestBody = $Body | ConvertTo-Json
        $entityBodyHash = ConvertTo-Hash -Value $requestBody -Algorithm $Challenge.algorithm
        $HA2 = ConvertTo-Hash -Value "$($method):$($uriPath):$($entityBodyHash)" -Algorithm $Challenge.algorithm

    }
    else {
        # Standard auth
        $HA2 = ConvertTo-Hash -Value "$($method):$($uriPath)" -Algorithm $Challenge.algorithm
    }

    # Compute final response hash
    $response = ConvertTo-Hash -Value "$($HA1):$($Challenge.nonce):$($nc):$($cnonce):$($Challenge.qop):$($HA2)" -Algorithm $Challenge.algorithm

    # Step 3: Construct the Authorization header
    # Create a new StringBuilder instance
    $sb = New-Object System.Text.StringBuilder

    # Append parts of the header one-by-one
    [void]$sb.Append('Digest username="').Append($username).Append('"')
    [void]$sb.Append(', realm="').Append($Challenge.realm).Append('"')
    [void]$sb.Append(', nonce="').Append($Challenge.nonce).Append('"')
    [void]$sb.Append(', uri="').Append($uriPath).Append('"')
    [void]$sb.Append(', algorithm=').Append($Challenge.algorithm)
    [void]$sb.Append(', response="').Append($response).Append('"')
    [void]$sb.Append(', qop="').Append($Challenge.qop).Append('"')
    [void]$sb.Append(', nc=').Append($nc)
    [void]$sb.Append(', cnonce="').Append($cnonce).Append('"')

    
    # Step 4: Send the authenticated request
    $authRequest = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::$method , $Challenge.uri)
    $authRequest.Headers.Authorization = [System.Net.Http.Headers.AuthenticationHeaderValue]::new('Digest', $sb.ToString())

    # <--- MODIFIED: If auth-int, attach the request body
    if ($Challenge.qop -eq 'auth-int') {
        $authRequest.Content = [System.Net.Http.StringContent]::new($requestBody, [System.Text.Encoding]::UTF8, 'application/json')
    }

    try {
        $rawResponse = $Challenge.httpClient.SendAsync($authRequest).Result
    }
    catch {
        Throw "Error sending the authenticated request: $_"
    }

    # Optionally, get content as string if needed
    # $contentString = $rawResponse.Content.ReadAsStringAsync().Result

    $contentStream = $rawResponse.Content.ReadAsStream()
    $timeout = [TimeSpan]::FromSeconds(100)
    $cancellationToken = [System.Threading.CancellationToken]::None
    # Create an instance of BasicHtmlWebResponseObject using the HttpResponseMessage and content stream
    return [Microsoft.PowerShell.Commands.BasicHtmlWebResponseObject]::new($rawResponse, $contentStream,
        $timeout,
        $cancellationToken)
    
}


# $challenge = ChallengeDigest -Uri $uri-Method $Method
#ResponseDigest -Challenge $challenge -Username 'morty' -Password 'pickle' -body @{message = 'test message' }


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

        # Timeout in seconds (not implemented in this sample, but available for extension)
        [Parameter()]
        [int]$TimeoutSec = 100
    )
 

    if (-not $Credential) {
        Throw 'A credential is required for Digest authentication.'
    } 
    try {
        # Get the server's Digest challenge by making an initial unauthenticated request
        $challenge = ChallengeDigest -Uri $Uri -Method $Method

        # If additional headers were provided, you might want to merge them into your request.
        # In this sample the Digest challenge is obtained without custom headers.
    }
    catch {
        Throw "Error retrieving Digest authentication challenge: $_"
    }

    try {
        # If a body is provided and the content type is JSON, convert it to JSON string
        if ($Body -and ($ContentType -match 'application/json')) {
            if ($Body -isnot [string]) {
                $Body = $Body | ConvertTo-Json -Compress
            }
        }

        # Update the challenge object if you need to pass any additional information
        $challenge | Add-Member -NotePropertyName Headers -NotePropertyValue $Headers -Force
        $challenge | Add-Member -NotePropertyName ContentType -NotePropertyValue $ContentType -Force

        # Send the authenticated request using your ResponseDigest function.
        $htmlWebResponseObject = ResponseDigest -Challenge $challenge -Credential $Credential -body $Body
    }
    catch {
        Throw "Error sending Digest authenticated request: $_"
    }

    # Create an object similar to Invoke-WebRequest's output.
    # You can extend this to include more properties (like StatusCode, RawContent, ParsedHtml, etc.)
    return $htmlWebResponseObject
     
}




# Define the URI, credentials, and method
$uri = 'http://localhost:8081/users'
$username = 'morty'
$password = 'pickle'

# Create a PowerShell Credential object
$securePassword = ConvertTo-SecureString $password -AsPlainText -Force
$credential = [System.Management.Automation.PSCredential]::new($username, $securePassword)

# Call Invoke-WebRequestDigest
$response = Invoke-WebRequestDigest -Uri $uri -Method 'GET' -Credential $credential

# Output the response details
$response | Format-List *
