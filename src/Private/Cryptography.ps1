<#
.SYNOPSIS
    Computes an HMAC-SHA256 hash for a given value using a secret key.

.DESCRIPTION
    This function calculates an HMAC-SHA256 hash for the specified value using either a secret provided as a string or as a byte array. It supports two parameter sets:
    1. String: The secret is provided as a string.
    2. Bytes: The secret is provided as a byte array.

.PARAMETER Value
    The value for which the HMAC-SHA256 hash needs to be computed.

.PARAMETER Secret
    The secret key as a string. If this parameter is provided, it will be converted to a byte array.

.PARAMETER SecretBytes
    The secret key as a byte array. If this parameter is provided, it will be used directly.

.OUTPUTS
    Returns the computed HMAC-SHA256 hash as a base64-encoded string.

.EXAMPLE
    $value = "MySecretValue"
    $secret = "MySecretKey"
    $hash = Invoke-PodeHMACSHA256Hash -Value $value -Secret $secret
    Write-PodeHost "HMAC-SHA256 hash: $hash"

    This example computes the HMAC-SHA256 hash for the value "MySecretValue" using the secret key "MySecretKey".
.NOTES
    - This function is intended for internal use.
#>
function Invoke-PodeHMACSHA256Hash {
    [CmdletBinding(DefaultParameterSetName = 'String')]
    [OutputType([String])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Value,

        [Parameter(Mandatory = $true, ParameterSetName = 'String')]
        [string]
        $Secret,

        [Parameter(Mandatory = $true, ParameterSetName = 'Bytes')]
        [byte[]]
        $SecretBytes
    )

    # Convert secret to byte array if provided as a string
    if (![string]::IsNullOrWhiteSpace($Secret)) {
        $SecretBytes = [System.Text.Encoding]::UTF8.GetBytes($Secret)
    }

    # Validate secret length
    if ($SecretBytes.Length -eq 0) {
        # No secret supplied for HMAC256 hash
        throw ($PodeLocale.noSecretForHmac256ExceptionMessage)
    }

    # Compute HMAC-SHA384 hash
    $crypto = [System.Security.Cryptography.HMACSHA256]::new($SecretBytes)
    return [System.Convert]::ToBase64String($crypto.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Value)))
}


function Invoke-PodeSHA256Hash {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Value
    )

    $crypto = [System.Security.Cryptography.SHA256]::Create()
    return [System.Convert]::ToBase64String($crypto.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Value)))
}

function Invoke-PodeSHA1Hash {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Value
    )

    $crypto = [System.Security.Cryptography.SHA1]::Create()
    return [System.Convert]::ToBase64String($crypto.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Value)))
}

function ConvertTo-PodeBase64Auth {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Username,

        [Parameter(Mandatory = $true)]
        [string]
        $Password
    )

    return [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("$($Username):$($Password)"))
}

function Invoke-PodeMD5Hash {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Value
    )

    $crypto = [System.Security.Cryptography.MD5]::Create()
    return [System.BitConverter]::ToString($crypto.ComputeHash([System.Text.Encoding]::ASCII.GetBytes($Value))).Replace('-', '').ToLowerInvariant()
}

<#
.SYNOPSIS
Generates a random byte array of specified length.

.DESCRIPTION
This function generates a random byte array using the .NET `System.Security.Cryptography.RandomNumberGenerator` class. You can specify the desired length of the byte array.

.PARAMETER Length
The length of the byte array to generate (default is 16).

.OUTPUTS
An array of bytes representing the random byte array.

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function Get-PodeRandomByte {
    [CmdletBinding()]
    [OutputType([System.Object[]])]
    param(
        [Parameter()]
        [int]
        $Length = 16
    )

    return (Use-PodeStream -Stream ([System.Security.Cryptography.RandomNumberGenerator]::Create()) {
            param($p)
            $bytes = [byte[]]::new($Length)
            $p.GetBytes($bytes)
            return $bytes
        })
}

function New-PodeSalt {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [int]
        $Length = 8
    )

    $bytes = [byte[]](Get-PodeRandomByte -Length $Length)
    return [System.Convert]::ToBase64String($bytes)
}

function New-PodeGuid {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [int]
        $Length = 16,

        [switch]
        $Secure,

        [switch]
        $NoDashes
    )

    # generate a cryptographically secure guid
    if ($Secure) {
        $bytes = [byte[]](Get-PodeRandomByte -Length $Length)
        $guid = ([guid]::new($bytes)).ToString()
    }

    # return a normal guid
    else {
        $guid = ([guid]::NewGuid()).ToString()
    }

    if ($NoDashes) {
        $guid = ($guid -ireplace '-', '')
    }

    return $guid
}

function Invoke-PodeValueSign {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Value,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Secret,

        [switch]
        $Strict
    )
    process {
        if ($Strict) {
            $Secret = ConvertTo-PodeStrictSecret -Secret $Secret
        }

        return "s:$($Value).$(Invoke-PodeHMACSHA256Hash -Value $Value -Secret $Secret)"
    }
}

function Invoke-PodeValueUnsign {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Value,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Secret,

        [switch]
        $Strict
    )
    process {
        # the signed value must start with "s:"
        if (!$Value.StartsWith('s:')) {
            return $null
        }

        # the signed value must contain a dot - splitting value and signature
        $Value = $Value.Substring(2)
        $periodIndex = $Value.LastIndexOf('.')
        if ($periodIndex -eq -1) {
            return $null
        }

        if ($Strict) {
            $Secret = ConvertTo-PodeStrictSecret -Secret $Secret
        }

        # get the raw value and signature
        $raw = $Value.Substring(0, $periodIndex)
        $sig = $Value.Substring($periodIndex + 1)

        if ((Invoke-PodeHMACSHA256Hash -Value $raw -Secret $Secret) -ne $sig) {
            return $null
        }

        return $raw
    }
}

function Test-PodeValueSigned {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(ValueFromPipeline = $true)]
        [string]
        $Value,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Secret,

        [switch]
        $Strict
    )
    process {
        if ([string]::IsNullOrEmpty($Value)) {
            return $false
        }

        $result = Invoke-PodeValueUnsign -Value $Value -Secret $Secret -Strict:$Strict
        return ![string]::IsNullOrEmpty($result)
    }
}

function ConvertTo-PodeStrictSecret {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Secret
    )

    return "$($Secret);$($WebEvent.Request.UserAgent);$($WebEvent.Request.RemoteEndPoint.Address.IPAddressToString)"
}


<#
.SYNOPSIS
    Generates a JWT-compatible signature using a specified RFC 7518 signing algorithm.

.DESCRIPTION
    This function creates a JWT signature for a given token using the provided algorithm and secret key bytes.
    It ensures that a secret is supplied when required and throws an exception if constraints are violated.
    The signature is compute using HMAC (HS256, HS384, HS512), RSA (RS256, RS384, RS512, PS256, PS384, PS512), or ECDSA (ES256, ES384, ES512).

.PARAMETER Algorithm
    The signing algorithm. Supported values: HS256, HS384, HS512, RS256, RS384, RS512, PS256, PS384, PS512, ES256, ES384, ES512.

.PARAMETER Token
    The JWT token to be signed.

.PARAMETER SecretBytes
    The secret key in byte array format used for signing the JWT using the HMAC algorithms..
    This parameter is optional when using the 'none' algorithm.

.PARAMETER PrivateKey
    The private key (PEM format) for RSA or ECDSA algorithms used to decode JWT.

.OUTPUTS
    [string] - The JWT signature as a base64url-encoded string.

.EXAMPLE
    $token = "header.payload"
    $key = [System.Text.Encoding]::UTF8.GetBytes("my-secret-key")
    $signature = New-PodeJwtSignature -Algorithm "HS256" -Token $token -SecretBytes $key

    This example generates a JWT signature using the HMAC SHA-256 algorithm.

    .EXAMPLE
    $signature = Invoke-PodeJwtSignature -Value "TestData" -Algorithm HS256 -Secret "MySecretKey"

.EXAMPLE
    $privateKey = Get-Content "private_key.pem" -Raw
    $signature = Invoke-PodeJwtSignature -Value "TestData" -Algorithm RS256 -PrivateKey $privateKey

.NOTES
    This function is an internal Pode function and is subject to change.
#>
function New-PodeJwtSignature {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('NONE', 'HS256', 'HS384', 'HS512', 'RS256', 'RS384', 'RS512', 'PS256', 'PS384', 'PS512', 'ES256', 'ES384', 'ES512')]
        [string]
        $Algorithm,

        [Parameter(Mandatory = $true)]
        [string]
        $Token,

        [Parameter()]
        [byte[]]
        $SecretBytes,

        [Parameter()]
        [securestring]
        $PrivateKey
    )

    if (($Algorithm -ieq 'none') -and ((($null -ne $SecretBytes) -and ($SecretBytes.Length -gt 0)) -or ($null -ne $PrivateKey))) {
        # Expected no secret to be supplied for no signature
        throw ($PodeLocale.noSecretExpectedForNoSignatureExceptionMessage)
    }
    $valueBytes = [System.Text.Encoding]::UTF8.GetBytes($Token)

    switch ($Algorithm) {
        'NONE' { return  [string]::Empty }
        # HMAC-SHA (HS256, HS384, HS512)
        { $_ -match '^HS(\d{3})$' } {
            if ($null -eq $SecretBytes) {
                throw ($PodeLocale.missingKeyForAlgorithmExceptionMessage -f 'secret', 'HMAC', $Algorithm)
            }

            # Map HS256, HS384, HS512 to their respective classes
            $hmac = switch ($Algorithm) {
                'HS256' { [System.Security.Cryptography.HMACSHA256]::new(); break }
                'HS384' { [System.Security.Cryptography.HMACSHA384]::new(); break }
                'HS512' { [System.Security.Cryptography.HMACSHA512]::new(); break }
                default { throw ($PodeLocale.unsupportedJwtAlgorithmExceptionMessage -f $Algorithm) }
            }

            $hmac.Key = $SecretBytes
            $signature = $hmac.ComputeHash($valueBytes)
            break
        }

        # RSA (RS256, RS384, RS512, PS256, PS384, PS512)
        { $_ -match '^(RS|PS)(\d{3})$' } {
            if ($null -eq $PrivateKey) {
                throw ($PodeLocale.missingKeyForAlgorithmExceptionMessage -f 'private', 'RSA', $Algorithm)
            }

            $rsa = [System.Security.Cryptography.RSA]::Create()
            $rsa.ImportFromPem( [Runtime.InteropServices.Marshal]::PtrToStringUni([Runtime.InteropServices.Marshal]::SecureStringToGlobalAllocUnicode($PrivateKey)))

            # Map RS256, RS384, RS512 to their correct SHA algorithm
            $hashAlgo = switch ($Algorithm) {
                'RS256' { [System.Security.Cryptography.HashAlgorithmName]::SHA256; break }
                'RS384' { [System.Security.Cryptography.HashAlgorithmName]::SHA384; break }
                'RS512' { [System.Security.Cryptography.HashAlgorithmName]::SHA512; break }
                'PS256' { [System.Security.Cryptography.HashAlgorithmName]::SHA256; break }
                'PS384' { [System.Security.Cryptography.HashAlgorithmName]::SHA384; break }
                'PS512' { [System.Security.Cryptography.HashAlgorithmName]::SHA512; break }
                default { throw ($PodeLocale.unsupportedJwtAlgorithmExceptionMessage -f $Algorithm) }
            }

            $rsaPadding = if ($Algorithm -match '^PS') {
                [System.Security.Cryptography.RSASignaturePadding]::Pss
            }
            else {
                [System.Security.Cryptography.RSASignaturePadding]::Pkcs1
            }

            try {
                $signature = $rsa.SignData($valueBytes, $hashAlgo, $rsaPadding)
            }
            finally {
                $rsa.Dispose()
            }
            break
        }

        # ECDSA (ES256, ES384, ES512)
        { $_ -match '^ES(\d{3})$' } {
            if ($null -eq $PrivateKey) {
                throw  ($PodeLocale.missingKeyForAlgorithmExceptionMessage -f 'private', 'ECDSA', $Algorithm)
            }

            $ecKey = [System.Security.Cryptography.ECDsa]::Create()
            $ecKey.ImportFromPem( [Runtime.InteropServices.Marshal]::PtrToStringUni([Runtime.InteropServices.Marshal]::SecureStringToGlobalAllocUnicode($PrivateKey)))

            # Map ES256, ES384, ES512 to their correct SHA algorithm
            $hashAlgo = switch ($Algorithm) {
                'ES256' { [System.Security.Cryptography.HashAlgorithmName]::SHA256; break }
                'ES384' { [System.Security.Cryptography.HashAlgorithmName]::SHA384; break }
                'ES512' { [System.Security.Cryptography.HashAlgorithmName]::SHA512; break }
                default { throw ($PodeLocale.unsupportedJwtAlgorithmExceptionMessage -f $Algorithm) }
            }

            $signature = $ecKey.SignData($valueBytes, $hashAlgo)
            break
        }

        default {
            throw ($PodeLocale.unsupportedJwtAlgorithmExceptionMessage -f $Algorithm)
        }
    }
    return [System.Convert]::ToBase64String($signature).Replace('+', '-').Replace('/', '_').TrimEnd('=')
}


<#
.SYNOPSIS
    Validates and verifies the authenticity of a JWT (JSON Web Token).

.DESCRIPTION
    This function confirms the validity of a JWT by:
    - Checking if the token is properly formatted (header.payload.signature).
    - Decoding the JWT header and payload.
    - Ensuring the algorithm (`alg` claim) matches the expected type.
    - Verifying the JWT signature using HMAC, RSA, or ECDSA.
    - Applying `JwtVerificationMode` to control signature enforcement.
    - Returning the decoded JWT payload if validation passes.

.PARAMETER Token
    The JWT string to be validated. It should be in the format: `header.payload.signature`.

.PARAMETER Algorithm
    The expected JWT signing algorithm(s). Supported values:
    - HMAC: `HS256`, `HS384`, `HS512`
    - RSA: `RS256`, `RS384`, `RS512`, `PS256`, `PS384`, `PS512`
    - ECDSA: `ES256`, `ES384`, `ES512`

.PARAMETER SecretBytes
    The secret key (as a byte array) used for HMAC verification.

.PARAMETER PublicKey
    The public key (PEM format) used for RSA or ECDSA verification.

.PARAMETER JwtVerificationMode
    Defines how aggressively JWT signatures are verified:
    - `Strict`: Enforces full signature verification.
    - `Moderate`: Allows missing `kid` but still verifies the signature.
    - `Lenient`: Ignores algorithm mismatches but verifies signature.

.OUTPUTS
    [pscustomobject] Returns the decoded JWT payload if the token is valid.

.EXAMPLE
    $jwtPayload = Confirm-PodeJwt -Token "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwiZXhwIjoxNzAwMDAwMDAwfQ.sXK1yP..." `
                                  -Algorithm "HS256" `
                                  -SecretBytes ([System.Text.Encoding]::UTF8.GetBytes("SuperSecretKey")) `
                                  -JwtVerificationMode "Strict"

    This example validates an HMAC-signed JWT with strict signature enforcement.

.EXAMPLE
    $publicKey = Get-Content "rsa_public.pem" -Raw
    $jwtPayload = Confirm-PodeJwt -Token "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..." `
                                  -Algorithm "RS256" `
                                  -PublicKey $publicKey `
                                  -JwtVerificationMode "Moderate"

    This example validates an RSA-signed JWT allowing missing `kid` but enforcing signature verification.

.NOTES
    - Throws an exception if the JWT is invalid, expired, or tampered with.
    - The function does not check the `exp`, `nbf`, or `iat` claims.
    - Use `Test-PodeJwt` separately to validate JWT claims.
#>
function Confirm-PodeJwt {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Token,

        [Parameter()]
        [ValidateSet('NONE', 'HS256', 'HS384', 'HS512', 'RS256', 'RS384', 'RS512', 'PS256', 'PS384', 'PS512', 'ES256', 'ES384', 'ES512')]
        [string[]]$Algorithm,

        [Parameter()]
        [securestring]$Secret, # Required for HMAC

        [Parameter()]
        [string]$PublicKey, # Required for RSA/ECDSA

        [Parameter()]
        [ValidateSet('Strict', 'Moderate', 'Lenient')]
        [string]$JwtVerificationMode = 'Strict'
    )

    # Split JWT into header, payload, and signature
    $parts = $Token -split '\.'
    if (($parts.Length -ne 3)) {
        throw ($PodeLocale.invalidJwtSuppliedExceptionMessage)
    }

    # Decode the JWT header
    $header = ConvertFrom-PodeJwtBase64Value -Value $parts[0]


    # Decode the JWT payload
    $payload = ConvertFrom-PodeJwtBase64Value -Value $parts[1]

    # Apply verification mode for algorithm enforcement
    if ($Algorithm -notcontains $header.alg) {
        throw ($PodeLocale.jwtAlgorithmMismatchExceptionMessage -f ($Algorithm -join ','), $header.alg)
    }

    $Algorithm = $header.alg
    # check "none" signature, and return payload if no signature
    $isNoneAlg = ($header.alg -eq 'NONE')
    if ([string]::IsNullOrEmpty($Algorithm)) {
        throw ($PodeLocale.noAlgorithmInJwtHeaderExceptionMessage)
    }

    if (($null -eq $Secret) -and ( [string]::IsNullOrWhiteSpace($PublicKey)) -and !$isNoneAlg) {

        # No JWT signature supplied for {0}
        throw  ($PodeLocale.noJwtSignatureForAlgorithmExceptionMessage -f $header.alg)
    }
    if ((![string]::IsNullOrWhiteSpace($PublicKey) -or ($null -ne $Secret)) -and $isNoneAlg) {

        # Expected no JWT signature to be supplied
        throw ($PodeLocale.expectedNoJwtSignatureSuppliedExceptionMessage)
    }

    if ((![string]::IsNullOrEmpty($parts[2]) -and $isNoneAlg)) {
        throw ($PodeLocale.invalidJwtSuppliedExceptionMessage)
    }


    $secretBytes = $null
    if (![string]::IsNullOrWhiteSpace($Secret)) {
        $secretBytes = [System.Text.Encoding]::UTF8.GetBytes([Runtime.InteropServices.Marshal]::PtrToStringUni([Runtime.InteropServices.Marshal]::SecureStringToGlobalAllocUnicode($Secret)))
    }
    if ($isNoneAlg -and ($null -ne $SecretBytes) -and ($SecretBytes.Length -gt 0)) {
        # Expected no JWT signature to be supplied
        throw ($PodeLocale.expectedNoJwtSignatureSuppliedExceptionMessage)
    }

    if ($isNoneAlg) {
        return $payload
    }

    # Prepare data for signature verification
    $headerPayloadBytes = [System.Text.Encoding]::UTF8.GetBytes("$($parts[0]).$($parts[1])")

    # Convert JWT signature from Base64 URL to Byte Array
    $fixedSignature = $parts[2].Replace('-', '+').Replace('_', '/')
    # Add proper Base64 padding
    switch ($fixedSignature.Length % 4) {
        1 { $fixedSignature = $fixedSignature.Substring(0, $fixedSignature.Length - 1) }  # Remove invalid character
        2 { $fixedSignature += '==' }  # Add two padding characters
        3 { $fixedSignature += '=' }   # Add one padding character
    }
    $signatureBytes = [Convert]::FromBase64String($fixedSignature)

    # Verify Signature
    if ($Algorithm -match '^HS(\d{3})$') {
        if ($null -eq $SecretBytes) {
            throw ($PodeLocale.missingKeyForAlgorithmExceptionMessage -f 'secret', 'HMAC', $Algorithm)
        }

        # Prepare JWT signing input
        $headerPayloadBytes = [System.Text.Encoding]::UTF8.GetBytes("$($parts[0]).$($parts[1])")

        # Compute HMAC Signature
        $hmac = switch ($Algorithm) {
            'HS256' { [System.Security.Cryptography.HMACSHA256]::new() }
            'HS384' { [System.Security.Cryptography.HMACSHA384]::new() }
            'HS512' { [System.Security.Cryptography.HMACSHA512]::new() }
        }

        $hmac.Key = $SecretBytes
        $expectedSignatureBytes = $hmac.ComputeHash($headerPayloadBytes)
        $expectedSignature = [Convert]::ToBase64String($expectedSignatureBytes).Replace('+', '-').Replace('/', '_').TrimEnd('=')

        # Compare signatures
        if ($expectedSignature -ne $parts[2]) {
            throw ($PodeLocale.invalidJwtSignatureSuppliedExceptionMessage)
        }
    }
    elseif ($Algorithm -match '^(RS|PS)(\d{3})$') {
        if ([string]::IsNullOrWhiteSpace($PublicKey)) {
            throw ($PodeLocale.missingKeyForAlgorithmExceptionMessage -f 'public', 'RSA', $Algorithm)
        }
        $rsa = [System.Security.Cryptography.RSA]::Create()
        $rsa.ImportFromPem($PublicKey)

        $hashAlgo = switch ($Algorithm) {
            'RS256' { [System.Security.Cryptography.HashAlgorithmName]::SHA256 }
            'RS384' { [System.Security.Cryptography.HashAlgorithmName]::SHA384 }
            'RS512' { [System.Security.Cryptography.HashAlgorithmName]::SHA512 }
            'PS256' { [System.Security.Cryptography.HashAlgorithmName]::SHA256 }
            'PS384' { [System.Security.Cryptography.HashAlgorithmName]::SHA384 }
            'PS512' { [System.Security.Cryptography.HashAlgorithmName]::SHA512 }
        }

        $rsaPadding = if ($Algorithm -match '^PS') {
            [System.Security.Cryptography.RSASignaturePadding]::Pss
        }
        else {
            [System.Security.Cryptography.RSASignaturePadding]::Pkcs1
        }

        if (!($rsa.VerifyData($headerPayloadBytes, $signatureBytes, $hashAlgo, $rsaPadding))) {
            write-podehost 'RSA verification failed'
            throw ($PodeLocale.invalidJwtSignatureSuppliedExceptionMessage)
        }
    }
    elseif ($Algorithm -match '^ES(\d{3})$') {
        if ([string]::IsNullOrWhiteSpace($PublicKey)) {
            throw ($PodeLocale.missingKeyForAlgorithmExceptionMessage -f 'public', 'ECDSA', $Algorithm)
        }

        $ecdsa = [System.Security.Cryptography.ECDsa]::Create()
        $ecdsa.ImportFromPem($PublicKey)

        $hashAlgo = switch ($Algorithm) {
            'ES256' { [System.Security.Cryptography.HashAlgorithmName]::SHA256 }
            'ES384' { [System.Security.Cryptography.HashAlgorithmName]::SHA384 }
            'ES512' { [System.Security.Cryptography.HashAlgorithmName]::SHA512 }
        }

        if (!($ecdsa.VerifyData($headerPayloadBytes, $signatureBytes, $hashAlgo))) {
            throw ($PodeLocale.invalidJwtSignatureSuppliedExceptionMessage)
        }
    }

    return $payload
}


function ConvertTo-PodeBase64UrlValue {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Value,

        [switch]
        $NoConvert
    )

    if (!$NoConvert) {
        $Value = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($Value))
    }

    return $Value.Replace('+', '-').Replace('/', '_').TrimEnd('=')
}

function ConvertFrom-PodeJwtBase64Value {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Value
    )

    # map chars
    $Value = $Value.Replace('-', '+').Replace('_', '/')
    # Add proper Base64 padding
    switch ($Value.Length % 4) {
        1 { $Value = $Value.Substring(0, $Value.Length - 1) }  # Remove invalid character
        2 { $Value += '==' }  # Add two padding characters
        3 { $Value += '=' }   # Add one padding character
    }
    # convert base64 to string
    try {
        $Value = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($Value))
    }
    catch {
        # Invalid Base64 encoded value found in JWT
        throw ($PodeLocale.invalidBase64JwtExceptionMessage)
    }
    # return json
    try {
        return ($Value | ConvertFrom-Json)
    }
    catch {
        # Invalid JSON value found in JWT
        throw ($PodeLocale.invalidJsonJwtExceptionMessage)
    }
}

<#
.SYNOPSIS
    Computes a cryptographic hash using the specified algorithm.

.DESCRIPTION
    This function accepts a string and an algorithm name, computes the hash using the specified algorithm,
    and returns the hash as a lowercase hexadecimal string.

.PARAMETER Value
    The input string to be hashed.

.PARAMETER Algorithm
    The hashing algorithm to use (SHA-1, SHA-256, SHA-512, SHA-512/256).

.OUTPUTS
    [string] - The computed hash in hexadecimal format.

.NOTES
    Internal Pode function for authentication hashing.
#>
function ConvertTo-PodeDigestHash {

    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        $Value,

        [Parameter(Mandatory = $true)]
        [ValidateSet('MD5', 'SHA-1', 'SHA-256', 'SHA-512', 'SHA-384', 'SHA-512/256')]
        [string]
        $Algorithm
    )

    # Select the appropriate hash algorithm
    $crypto = switch ($Algorithm) {
        'MD5' { [System.Security.Cryptography.MD5]::Create() }
        'SHA-1' { [System.Security.Cryptography.SHA1]::Create() }
        'SHA-256' { [System.Security.Cryptography.SHA256]::Create() }
        'SHA-384' { [System.Security.Cryptography.SHA384]::Create() }
        'SHA-512' { [System.Security.Cryptography.SHA512]::Create() }
        'SHA-512/256' {
            # Compute SHA-512 and truncate to 256 bits (first 32 bytes)
            $sha512 = [System.Security.Cryptography.SHA512]::Create()
            $fullHash = $sha512.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Value))
            return [System.BitConverter]::ToString($fullHash[0..31]).Replace('-', '').ToLowerInvariant()
        }
    }

    return [System.BitConverter]::ToString($crypto.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Value))).Replace('-', '').ToLowerInvariant()
}

<#
  .SYNOPSIS
    Determines the JWT signing algorithm based on the provided RSA or ECDSA private key.

  .DESCRIPTION
    This function analyzes a given RSA or ECDSA private key in PEM format and returns the appropriate
    JWT signing algorithm. For RSA keys, it supports both PKCS#1 v1.5 (RS) and RSA-PSS (PS) padding schemes.
    For ECDSA keys, it determines the corresponding ES algorithm.

  .PARAMETER PrivateKey
    A SecureString containing the RSA or ECDSA private key in PEM format.

  .PARAMETER RsaPaddingScheme
    Specifies the padding scheme to use for RSA signatures.
    Acceptable values:
    - 'Pkcs1V15' (for RS256, RS384, RS512)
    - 'Pss' (for PS256, PS384, PS512)
    Default: 'Pkcs1V15'.

  .OUTPUTS
    String - The JWT signing algorithm name (e.g., 'RS256', 'PS256', 'ES256').

  .EXAMPLE
    # Determine the signing algorithm for an RSA private key using PKCS#1 v1.5 padding
    $secureKey = ConvertTo-SecureString -String (Get-Content "C:\path\to\privatekey.pem" -Raw) -AsPlainText -Force
    Get-PodeJwtSigningAlgorithm -PrivateKey $secureKey -RsaPaddingScheme 'Pkcs1V15'

    Output:
    RS256

  .EXAMPLE
    # Determine the signing algorithm for an RSA private key using RSA-PSS padding
    $secureKey = ConvertTo-SecureString -String (Get-Content "C:\path\to\privatekey.pem" -Raw) -AsPlainText -Force
    Get-PodeJwtSigningAlgorithm -PrivateKey $secureKey -RsaPaddingScheme 'Pss'

    Output:
    PS256

  .EXAMPLE
    # Determine the signing algorithm for an ECDSA private key
    $secureKey = ConvertTo-SecureString -String (Get-Content "C:\path\to\ec_privatekey.pem" -Raw) -AsPlainText -Force
    Get-PodeJwtSigningAlgorithm -PrivateKey $secureKey

    Output:
    ES256

  .NOTES
    - This function only supports PEM-encoded private keys.
    - The RSA key size determines whether it maps to RS256/RS384/RS512 or PS256/PS384/PS512.
    - The function does not enforce a specific signing standard but allows flexibility in padding choice.
#>
function Get-PodeJwtSigningAlgorithm {
    param (
        [System.Security.SecureString]$PrivateKey,
        [ValidateSet('Pkcs1V15', 'Pss')]
        [string]$RsaPaddingScheme = 'Pkcs1V15'  # Default to PKCS#1 v1.5 unless specified
    )

    # Convert SecureString to plain text
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($PrivateKey)
    $privateKeyContent = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

    if ($privateKeyContent -match 'BEGIN RSA PRIVATE KEY|BEGIN PRIVATE KEY') {
        # RSA Algorithm Detected

        $rsa = [System.Security.Cryptography.RSA]::Create()
        $rsa.ImportFromPem($privateKeyContent)

        # Determine key size and match to RSA algorithms
        switch ($rsa.KeySize) {
            2048 { if ($RsaPaddingScheme -eq 'Pkcs1V15') { return 'RS256' } else { return 'PS256' } }
            3072 { if ($RsaPaddingScheme -eq 'Pkcs1V15') { return 'RS384' } else { return 'PS384' } }
            4096 { if ($RsaPaddingScheme -eq 'Pkcs1V15') { return 'RS512' } else { return 'PS512' } }
            default { throw "Unknown RSA Algorithm (Key Size: $($rsa.KeySize) bits)" }
        }

    }
    elseif ($privateKeyContent -match 'BEGIN EC PRIVATE KEY') {
        # ECDSA Algorithm Detected
        $ecdsa = [System.Security.Cryptography.ECDsa]::Create()
        $ecdsa.ImportFromPem($privateKeyContent)

        # Determine key size and map to ES algorithms
        switch ($ecdsa.KeySize) {
            256 { return 'ES256' }
            384 { return 'ES384' }
            521 { return 'ES512' }
            default { throw "Unknown ECDSA Algorithm (Key Size: $($ecdsa.KeySize) bits)" }
        }

    }
    else {
        throw 'Unknown Algorithm or Invalid PEM Format'
    }
}
