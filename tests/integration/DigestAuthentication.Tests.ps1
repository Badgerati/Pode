[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseUsingScopeModifierInNewRunspaces', '')]
param()
BeforeAll {
    $path = $PSCommandPath
    $src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]integration', '/src/'
    $CertsPath = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]integration', '/tests/certs/'
    Get-ChildItem "$($src)/*.ps1" -Recurse | Resolve-Path | ForEach-Object { . $_ }
    
    # load assemblies
    Add-Type -AssemblyName System.Web -ErrorAction Stop
    Add-Type -AssemblyName System.Net.Http -ErrorAction Stop

    $module = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]integration', '/examples/Authentication/Modules'
    Import-Module "$module/Invoke-Digest.psm1"

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
        if (! $wwwAuthHeader) {
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
        param(
            [Parameter(Mandatory = $true)]
            [psobject]$Challenge,

            [Parameter(Mandatory = $true)]
            [string]$Username,
            [Parameter(Mandatory = $true)]
            [string]$Password,
            [hashtable]$Body

        )
        $nc = '00000001'  # Nonce Count
        $cnonce = (New-Guid).Guid.Substring(0, 8)  # Generate a random client nonce


        $Method = $Challenge.Method.ToUpper()

        Write-Verbose "Using method: $method"

        # Build the URI path
        $uriPath = [System.Uri]$Challenge.uri
        $uriPath = $uriPath.AbsolutePath  # "/users"

        # Compute HA1
        $HA1 = ConvertTo-Hash -Value "$($Username):$($Challenge.realm):$($Password)" -Algorithm $Challenge.algorithm

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
        $authHeader = @"
Digest username="$username", realm="$($Challenge.realm)", nonce="$($Challenge.nonce)", uri="$uriPath", algorithm=$($Challenge.algorithm), response="$response", qop="$($Challenge.qop)", nc=$nc, cnonce="$cnonce"
"@

        Write-Verbose "Authorization Header: $authHeader"

        # Step 4: Send the authenticated request
        $authRequest = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::$method , $Challenge.uri)
        $authRequest.Headers.Authorization = [System.Net.Http.Headers.AuthenticationHeaderValue]::new('Digest', $authHeader)

        # <--- MODIFIED: If auth-int, attach the request body
        if ($Challenge.qop -eq 'auth-int') {
            $authRequest.Content = [System.Net.Http.StringContent]::new($requestBody, [System.Text.Encoding]::UTF8, 'application/json')
        }

        $response = $Challenge.httpClient.SendAsync($authRequest).Result

        # Optionally, get content as string if needed
        $content = $response.Content.ReadAsStringAsync().Result

        return [PSCustomObject]@{
            # Extract and display the response headers
            Header     = $response.Headers | ForEach-Object { "$($_.Key): $($_.Value)" }
            Content    = $content
            AuthHeader = $authHeader
        }
    }


}

Describe 'Digest Authentication Requests' {

    BeforeAll {

        $Port = 8080
        $Endpoint = "http://127.0.0.1:$($Port)"

        Start-Job -Name 'Pode' -ErrorAction Stop -ScriptBlock {
            Import-Module -Name "$($using:PSScriptRoot)\..\..\src\Pode.psm1"

            Start-PodeServer -Quiet -ScriptBlock {
                Add-PodeEndpoint -Address localhost -Port $using:Port -Protocol Http

                New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging
                Add-PodeRoute -Method Get -Path '/close' -ScriptBlock {
                    Close-PodeServer
                }

                foreach ($alg in  ('MD5', 'SHA-1', 'SHA-256', 'SHA-512', 'SHA-384', 'SHA-512/256')) {
                    foreach ($qop in ('auth', 'auth-int', 'auth,auth-int'  )) {

                        New-PodeAuthDigestScheme -Algorithm $alg -QualityOfProtection $qop | Add-PodeAuth -Name "digest_$($alg)_$qop" -Sessionless -ScriptBlock {
                            param($username, $params)

                            # here you'd check a real user storage, this is just for example
                            if ($username -ieq 'morty') {
                                return @{
                                    User     = @{
                                        ID   = 'M0R7Y302'
                                        Name = 'Morty'
                                        Type = 'Human'
                                    }
                                    Password = 'pickle'
                                }
                            }

                            return $null
                        }

                        # If QualityOfProtection is 'auth-int' skip GET because it is not supported
                        if ($qop -ne 'auth-int') {
                            # GET request to get list of users (since there's no session, authentication will always happen)
                            Add-PodeRoute -Method Get -Path "/auth/$alg/$qop" -Authentication "digest_$($alg)_$qop" -ErrorContentType  'application/json' -ScriptBlock {
                                Write-PodeJsonResponse -Value @{
                                    success = $true
                                }
                            }
                        }

                        Add-PodeRoute -Method Post -Path "/auth/$alg/$qop" -Authentication "digest_$($alg)_$qop" -ErrorContentType  'application/json' -ScriptBlock {
                            if ($WebEvent.data) {
                                Write-PodeJsonResponse -Value  @{success = $true } -StatusCode 200
                            }
                            else {
                                Write-PodeJsonResponse -Value @{success = $false } -StatusCode 400
                            }
                        }
                    }
                }
            }
        }
        Start-Sleep -Seconds 10

    }

    AfterAll {

        Receive-Job -Name 'Pode' | Out-Default
        Invoke-RestMethod -Uri "$($Endpoint)/close" -Method Get | Out-Null
        Get-Job -Name 'Pode' | Remove-Job -Force
    }



    Describe 'Digest Authentication' {

        Context 'Digest - Algorithm <_> - Path /auth/<_>' -ForEach ('MD5', 'SHA-1', 'SHA-256', 'SHA-512', 'SHA-384', 'SHA-512/256') {
            BeforeDiscovery {
                $alg_qop = @()
                ForEach ($qop in 'auth', 'auth-int', 'auth,auth-int') {
                    $alg_qop += @{
                        qop       = $qop
                        algorithm = $_
                    }
                }
            }
            It 'Digest - Method Get - Algorithm:<algorithm> - QOP:<qop>' -ForEach $alg_qop {

                #Write-PodeHost "Testing Algorithm: $algorithm with QOP: $qop"
                if ($qop -eq 'auth-int') {
                    { ChallengeDigest -Uri "$($Endpoint)/auth/$algorithm/$qop" -Method Get } | Should -Throw
                }
                else {
                    $challenge = ChallengeDigest -Uri "$($Endpoint)/auth/$algorithm/$qop" -Method Get

                    # Validate challenge structure
                    $challenge | Should -Not -BeNullOrEmpty
                    $challenge | Should -BeOfType 'PSCustomObject'

                    $challenge.realm | Should -Be 'User'
                    $qop.contains( $challenge.qop) | Should -BeTrue
                    $challenge.algorithm | Should -Be $algorithm

                    # Check that nonce matches a hex pattern (example pattern for 32 hex characters)
                    $challenge.nonce | Should -Match '^[0-9a-f]{32}$'

                    # Check that wwwAuthHeader contains the expected error info
                    $challenge.wwwAuthHeader | Should -Not -BeNullOrEmpty
                    $challenge.wwwAuthHeader | Should -Match 'error="invalid_request"'
                    $challenge.wwwAuthHeader | Should -Match 'error_description="No Authorization header found"'



                    $response = ResponseDigest -Challenge $challenge   -Username 'morty' -Password 'pickle'
                    # Validate challenge structure
                    $response | Should -Not -BeNullOrEmpty
                    $response | Should -BeOfType 'PSCustomObject'
                    $response.Content | Should -Be '{"success":true}'

                }
            }
            It 'Digest - Method Post - Algorithm:<algorithm> - QOP:<qop>' -ForEach $alg_qop {

                $challenge = ChallengeDigest -Uri "$($Endpoint)/auth/$algorithm/$qop" -Method Post

                # Validate challenge structure
                $challenge | Should -Not -BeNullOrEmpty
                $challenge | Should -BeOfType 'PSCustomObject'

                $challenge.realm | Should -Be 'User'
                $qop.contains( $challenge.qop) | Should -BeTrue
                $challenge.algorithm | Should -Be $algorithm

                # Check that nonce matches a hex pattern (example pattern for 32 hex characters)
                $challenge.nonce | Should -Match '^[0-9a-f]{32}$'

                # Check that wwwAuthHeader contains the expected error info
                $challenge.wwwAuthHeader | Should -Not -BeNullOrEmpty
                $challenge.wwwAuthHeader | Should -Match 'error="invalid_request"'
                $challenge.wwwAuthHeader | Should -Match 'error_description="No Authorization header found"'

                $response = ResponseDigest -Challenge $challenge -Username 'morty' -Password 'pickle' -body @{message = 'test message' }
                # Validate challenge structure
                $response | Should -Not -BeNullOrEmpty
                $response | Should -BeOfType 'PSCustomObject'
                $response.Content | Should -Be '{"success":true}'

            }

        }

        Context 'Invoke-Digest module - Algorithm <_> - Path /auth/<_>' -ForEach ('MD5', 'SHA-1', 'SHA-256', 'SHA-512', 'SHA-384', 'SHA-512/256') -Tag 'Exclude_DesktopEdition' {
            BeforeDiscovery {
                $alg_qop = @()
                ForEach ($qop in 'auth', 'auth-int', 'auth,auth-int') {
                    $alg_qop += @{
                        qop       = $qop
                        algorithm = $_
                    }
                }
            }
            BeforeAll {
                $username = 'morty'
                $password = 'pickle'

                $securePassword = ConvertTo-SecureString $password -AsPlainText -Force
                $credential = [System.Management.Automation.PSCredential]::new($username, $securePassword)
            }

            It 'Digest - Method Get - Algorithm:<algorithm> - QOP:<qop>' -ForEach $alg_qop {

                #Write-PodeHost "Testing Algorithm: $algorithm with QOP: $qop"
                if ($qop -eq 'auth-int') {
                    { Invoke-RestMethodDigest -Uri "$($Endpoint)/auth/$algorithm/$qop" -Method Get -Credential $credential } | Should -Throw
                }
                else {
                    $response = Invoke-RestMethodDigest -Uri "$($Endpoint)/auth/$algorithm/$qop" -Method Get -Credential $credential
                    # Validate challenge structure
                    $response | Should -Not -BeNullOrEmpty
                    $response | Should -BeOfType 'PSCustomObject'
                    $response.success | Should -BeTrue

                }
            }
        }
    }
}





