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
    The signature is computed using HMAC (HS256, HS384, HS512), RSA (RS256, RS384, RS512, PS256, PS384, PS512), or ECDSA (ES256, ES384, ES512).

.PARAMETER Algorithm
    The signing algorithm. Supported values: HS256, HS384, HS512, RS256, RS384, RS512, PS256, PS384, PS512, ES256, ES384, ES512.

.PARAMETER Token
    The JWT token to be signed.

.PARAMETER SecretBytes
    The secret key in byte array format used for signing the JWT using the HMAC algorithms.
    This parameter is optional when using the 'none' algorithm.

.PARAMETER X509Certificate
    The private key certificate for RSA or ECDSA algorithms.

.PARAMETER RsaPaddingScheme
    RSA padding scheme to use, default is `Pkcs1V15`.

.OUTPUTS
    [string] - The JWT signature as a base64url-encoded string.

.EXAMPLE
    $token = "header.payload"
    $key = [System.Text.Encoding]::UTF8.GetBytes("my-secret-key")
    $signature = New-PodeJwtSignature -Algorithm "HS256" -Token $token -SecretBytes $key

    This example generates a JWT signature using the HMAC SHA-256 algorithm.

.EXAMPLE
    $privateKey = Get-Content "private_key.pem" -Raw
    $signature = New-PodeJwtSignature -Algorithm RS256 -Token "header.payload" -X509Certificate $certificate

.NOTES
    This function is an internal Pode function and is subject to change.
#>
function New-PodeJwtSignature {
    [CmdletBinding(DefaultParameterSetName = 'SecretBytes')]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'SecretBytes')]
        [Parameter(Mandatory = $true, ParameterSetName = 'SecretSecureString')]
        [ValidateSet('HS256', 'HS384', 'HS512')]
        [string]
        $Algorithm,

        [Parameter(Mandatory = $true)]
        [string]
        $Token,

        [Parameter(Mandatory = $true, ParameterSetName = 'SecretBytes')]
        [byte[]]
        $SecretBytes,

        [Parameter(Mandatory = $true, ParameterSetName = 'SecretSecureString')]
        [securestring]
        $Secret,

        [Parameter( Mandatory = $true, ParameterSetName = 'X509Certificate')]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]
        $X509Certificate,

        [Parameter(Mandatory = $false, ParameterSetName = 'X509Certificate')]
        [ValidateSet('Pkcs1V15', 'Pss')]
        [string]
        $RsaPaddingScheme = 'Pkcs1V15',

        [Parameter(Mandatory = $true, ParameterSetName = 'AuthenticationMethod')]
        [string]
        $Authentication
    )
    $alg = $Algorithm
    switch ($PSCmdlet.ParameterSetName) {
        'SecretBytes' {
            if ($null -eq $SecretBytes) {
                throw ($PodeLocale.missingKeyForAlgorithmExceptionMessage -f 'secret', 'HMAC', $Algorithm)
            }
            break
        }
        'SecretSecureString' {
            if ($null -eq $Secret) {
                throw ($PodeLocale.missingKeyForAlgorithmExceptionMessage -f 'secret', 'HMAC', $Algorithm)
            }
            # Convert Secret to bytes if provided
            $secretBytes = Convert-PodeSecureStringToByteArray -SecureString $Secret
            break
        }
        'X509Certificate' {
            if ($null -eq $X509Certificate) {
                throw ($PodeLocale.missingKeyForAlgorithmExceptionMessage -f 'private', 'RSA/ECSDA', $Algorithm)
            }
            $alg = Get-PodeJwtSigningAlgorithm -X509Certificate $X509Certificate -RsaPaddingScheme $RsaPaddingScheme

            break
        }
        'AuthenticationMethod' {
            if ($PodeContext -and $PodeContext.Server.Authentications.Methods.ContainsKey($Authentication)) {
                $method = $PodeContext.Server.Authentications.Methods[$Authentication]
                $alg = $method.Algorithm
                $X509Certificate = $method.Certificate
                if ($null -ne $method.Secret) {
                    $secretBytes = Convert-PodeSecureStringToByteArray -SecureString $method.Secret
                }
            }
            else {
                throw ($PodeLocale.authenticationMethodDoesNotExistExceptionMessage)
            }
        }
    }

    $valueBytes = [System.Text.Encoding]::UTF8.GetBytes($Token)

    switch ($alg) {

        # HMAC-SHA (HS256, HS384, HS512)
        { $_ -match '^HS(\d{3})$' } {

            # Map HS256, HS384, HS512 to their respective classes
            $hmac = switch ($alg) {
                'HS256' { [System.Security.Cryptography.HMACSHA256]::new($SecretBytes); break }
                'HS384' { [System.Security.Cryptography.HMACSHA384]::new($SecretBytes); break }
                'HS512' { [System.Security.Cryptography.HMACSHA512]::new($SecretBytes); break }
                default { throw ($PodeLocale.unsupportedJwtAlgorithmExceptionMessage -f $alg) }
            }

            $signature = $hmac.ComputeHash($valueBytes)
            break
        }

        # RSA (RS256, RS384, RS512, PS256, PS384, PS512)
        { $_ -match '^(RS|PS)(\d{3})$' } {
            $rsa = [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($X509Certificate)

            # Map RS256, RS384, RS512 to their correct SHA algorithm
            $hashAlgo = switch ($alg) {
                'RS256' { [System.Security.Cryptography.HashAlgorithmName]::SHA256; break }
                'RS384' { [System.Security.Cryptography.HashAlgorithmName]::SHA384; break }
                'RS512' { [System.Security.Cryptography.HashAlgorithmName]::SHA512; break }
                'PS256' { [System.Security.Cryptography.HashAlgorithmName]::SHA256; break }
                'PS384' { [System.Security.Cryptography.HashAlgorithmName]::SHA384; break }
                'PS512' { [System.Security.Cryptography.HashAlgorithmName]::SHA512; break }
                default { throw ($PodeLocale.unsupportedJwtAlgorithmExceptionMessage -f $alg) }
            }

            $rsaPadding = if ($alg -match '^PS') {
                [System.Security.Cryptography.RSASignaturePadding]::Pss
            }
            else {
                [System.Security.Cryptography.RSASignaturePadding]::Pkcs1
            }

            $signature = $rsa.SignData($valueBytes, $hashAlgo, $rsaPadding)

            break
        }

        # ECDSA (ES256, ES384, ES512)
        { $_ -match '^ES(\d{3})$' } {
            $ecdsa = [System.Security.Cryptography.X509Certificates.ECDsaCertificateExtensions]::GetECDsaPrivateKey($X509Certificate)

            # Map ES256, ES384, ES512 to their correct SHA algorithm
            $hashAlgo = switch ($alg) {
                'ES256' { [System.Security.Cryptography.HashAlgorithmName]::SHA256; break }
                'ES384' { [System.Security.Cryptography.HashAlgorithmName]::SHA384; break }
                'ES512' { [System.Security.Cryptography.HashAlgorithmName]::SHA512; break }
                default { throw ($PodeLocale.unsupportedJwtAlgorithmExceptionMessage -f $alg) }
            }

            $signature = $ecdsa.SignData($valueBytes, $hashAlgo)
            break
        }

        default {
            throw ($PodeLocale.unsupportedJwtAlgorithmExceptionMessage -f $alg)
        }
    }
    return [System.Convert]::ToBase64String($signature).Replace('+', '-').Replace('/', '_').TrimEnd('=')
}


<#
.SYNOPSIS
    Validates and verifies the authenticity of a JSON Web Token (JWT).

  .DESCRIPTION
    This function validates a JWT by:
    - Splitting and decoding the token.
    - Verifying the algorithm used.
    - Performing signature validation using HMAC, RSA, or ECDSA.
    - Supporting configurable verification modes.
    - Returning the payload if valid.

  .PARAMETER Token
    The JWT string to be validated in `header.payload.signature` format.

  .PARAMETER Algorithm
    Supported JWT signing algorithms: HS256, RS256, ES256, etc.

  .PARAMETER Secret
    SecureString key for HMAC algorithms.

  .PARAMETER X509Certificate
    X509Certificate2 object for RSA/ECDSA verification.

  .OUTPUTS
    Returns the JWT payload if the token is valid.

  .EXAMPLE
    Confirm-PodeJwt -Token $jwt -Algorithm RS256 -Certificate $cert

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

        [Parameter(Mandatory = $true)]
        [ValidateSet('NONE', 'HS256', 'HS384', 'HS512', 'RS256', 'RS384', 'RS512', 'PS256', 'PS384', 'PS512', 'ES256', 'ES384', 'ES512')]
        [string[]]$Algorithm,

        [Parameter()]
        [securestring]$Secret, # Required for HMAC

        [Parameter()]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]
        $X509Certificate
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

    # Handle none algorithm cases
    $isNoneAlg = ($header.alg -eq 'NONE')
    if ([string]::IsNullOrEmpty($Algorithm)) {
        throw ($PodeLocale.noAlgorithmInJwtHeaderExceptionMessage)
    }

    # Ensure secret/certificate presence when required
    if (($null -eq $Secret) -and ( $null -eq $X509Certificate) -and !$isNoneAlg) {
        # No JWT signature supplied for {0}
        throw  ($PodeLocale.noJwtSignatureForAlgorithmExceptionMessage -f $header.alg)
    }
    if ((( $null -ne $X509Certificate) -or ($null -ne $Secret)) -and $isNoneAlg) {
        # Expected no JWT signature to be supplied
        throw ($PodeLocale.expectedNoJwtSignatureSuppliedExceptionMessage)
    }

    if ((![string]::IsNullOrEmpty($parts[2]) -and $isNoneAlg)) {
        throw ($PodeLocale.invalidJwtSuppliedExceptionMessage)
    }

    if ($isNoneAlg) {
        return $payload
    }
    if ($null -ne $Secret) {
        # Convert Secret to bytes if provided
        $secretBytes = Convert-PodeSecureStringToByteArray -SecureString $Secret
    }

    if ($isNoneAlg -and ($null -ne $SecretBytes) -and ($SecretBytes.Length -gt 0)) {
        # Expected no JWT signature to be supplied
        throw ($PodeLocale.expectedNoJwtSignatureSuppliedExceptionMessage)
    }

    # Prepare data for signature verification
    $headerPayloadBytes = [System.Text.Encoding]::UTF8.GetBytes("$($parts[0]).$($parts[1])")
    # Convert JWT signature from Base64 URL to Byte Array
    $fixedSignature = $parts[2].Replace('-', '+').Replace('_', '/')
    # Add proper Base64 padding
    switch ($fixedSignature.Length % 4) {
        1 { $fixedSignature = $fixedSignature.Substring(0, $fixedSignature.Length - 1); break }  # Remove invalid character
        2 { $fixedSignature += '=='; break }  # Add two padding characters
        3 { $fixedSignature += '='; break }   # Add one padding character
    }
    $signatureBytes = [Convert]::FromBase64String($fixedSignature)

    # Verify Signature

    # Handle HMAC signature verification
    if ($Algorithm -match '^HS(\d{3})$') {
        if ($null -eq $SecretBytes) {
            throw ($PodeLocale.missingKeyForAlgorithmExceptionMessage -f 'secret', 'HMAC', $Algorithm)
        }

        # Compute HMAC Signature
        $hmac = switch ($Algorithm) {
            'HS256' { [System.Security.Cryptography.HMACSHA256]::new($SecretBytes); break }
            'HS384' { [System.Security.Cryptography.HMACSHA384]::new($SecretBytes); break }
            'HS512' { [System.Security.Cryptography.HMACSHA512]::new($SecretBytes); break }
        }
        # Prepare JWT signing input
        $expectedSignatureBytes = $hmac.ComputeHash([System.Text.Encoding]::UTF8.GetBytes("$($parts[0]).$($parts[1])"))
        $expectedSignature = [Convert]::ToBase64String($expectedSignatureBytes).Replace('+', '-').Replace('/', '_').TrimEnd('=')

        # Compare signatures
        if ($expectedSignature -ne $parts[2]) {
            throw ($PodeLocale.invalidJwtSignatureSuppliedExceptionMessage)
        }
    }
    elseif ($Algorithm -match '^(RS|PS)(\d{3})$') {
        # Extract the RSA public key from the existing certificate object
        $rsa = [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPublicKey($X509Certificate)

        $hashAlgo = switch ($Algorithm) {
            'RS256' { [System.Security.Cryptography.HashAlgorithmName]::SHA256; break }
            'RS384' { [System.Security.Cryptography.HashAlgorithmName]::SHA384; break }
            'RS512' { [System.Security.Cryptography.HashAlgorithmName]::SHA512; break }
            'PS256' { [System.Security.Cryptography.HashAlgorithmName]::SHA256; break }
            'PS384' { [System.Security.Cryptography.HashAlgorithmName]::SHA384; break }
            'PS512' { [System.Security.Cryptography.HashAlgorithmName]::SHA512; break }
        }

        $rsaPadding = if ($Algorithm -match '^PS') {
            [System.Security.Cryptography.RSASignaturePadding]::Pss
        }
        else {
            [System.Security.Cryptography.RSASignaturePadding]::Pkcs1
        }
        if (!($rsa.VerifyData($headerPayloadBytes, $signatureBytes, $hashAlgo, $rsaPadding))) {
            throw ($PodeLocale.invalidJwtSignatureSuppliedExceptionMessage)
        }
    }
    elseif ($Algorithm -match '^ES(\d{3})$') {
        # Extract the ECSDA public key from the existing certificate object
        $ecdsa = [System.Security.Cryptography.X509Certificates.ECDsaCertificateExtensions]::GetECDsaPrivateKey($X509Certificate)

        $hashAlgo = switch ($Algorithm) {
            'ES256' { [System.Security.Cryptography.HashAlgorithmName]::SHA256; break }
            'ES384' { [System.Security.Cryptography.HashAlgorithmName]::SHA384; break }
            'ES512' { [System.Security.Cryptography.HashAlgorithmName]::SHA512; break }
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
        'MD5' { [System.Security.Cryptography.MD5]::Create(); break }
        'SHA-1' { [System.Security.Cryptography.SHA1]::Create(); break }
        'SHA-256' { [System.Security.Cryptography.SHA256]::Create(); break }
        'SHA-384' { [System.Security.Cryptography.SHA384]::Create(); break }
        'SHA-512' { [System.Security.Cryptography.SHA512]::Create(); break }
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
   Determines the JWT signing algorithm based on the provided X.509 certificate.

.DESCRIPTION
   This function extracts the private key (RSA or ECDSA) from a given X.509 certificate (PFX) and determines the appropriate JSON Web Token (JWT) signing algorithm.
   For RSA keys, the function attempts to read the key size using the `KeySize` property. On Linux with .NET 9, this property is write-only, so a reflection-based workaround is used to retrieve the private `KeySizeValue` field.
   For ECDSA keys, the algorithm is selected directly based on the key size.

.PARAMETER X509Certificate
   A System.Security.Cryptography.X509Certificates.X509Certificate2 object representing the certificate (PFX) from which the private key is extracted.

.PARAMETER RsaPaddingScheme
   Specifies the RSA padding scheme to use. Acceptable values are 'Pkcs1V15' (default) and 'Pss'.

.EXAMPLE
   PS> Get-PodeJwtSigningAlgorithm -X509Certificate $myCert -RsaPaddingScheme 'Pkcs1V15'
   Determines and returns the appropriate JWT signing algorithm (e.g., 'RS256', 'RS384', 'RS512' for RSA or 'ES256', 'ES384', 'ES512' for ECDSA) based on the certificate's key.

.NOTES
   This function includes a reflection-based workaround for .NET 9 on Linux where the RSA `KeySize` property is write-only. Refer to https://github.com/dotnet/runtime/issues/112622 for more details.
#>
function Get-PodeJwtSigningAlgorithm {
    param (

        [System.Security.Cryptography.X509Certificates.X509Certificate2]
        $X509Certificate, # PFX

        [ValidateSet('Pkcs1V15', 'Pss')]
        [string]$RsaPaddingScheme = 'Pkcs1V15'  # Default to PKCS#1 v1.5 unless specified
    )
    # Extract Private Key (RSA or ECDSA)
    $key = [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($X509Certificate)
    if ($null -ne $key) {
        Write-Verbose 'RSA Private Key detected.'
        try {
            $keySize = $key.KeySize
        }
        catch {
            # Exception is 'Cannot get property value because "KeySize" is a write-only property.'
            # Use reflection to access the private 'KeySizeValue' field
            $bindingFlags = [System.Reflection.BindingFlags] 'NonPublic, Instance'
            $keySizeField = $key.GetType().GetField('KeySizeValue', $bindingFlags)

            # Retrieve the value of the 'KeySizeValue' field this is a workaround of an issue with .net for Linux
            Write-Verbose "Keysize obtained by reflection  $($keySizeField.GetValue($key))"
            $keySize = $keySizeField.GetValue($key)
        }
        # Determine RSA key size
        switch ($keySize) {
            2048 { return $(if ($RsaPaddingScheme -eq 'Pkcs1V15') { 'RS256' } else { 'PS256' }) }
            3072 { return $(if ($RsaPaddingScheme -eq 'Pkcs1V15') { 'RS384' } else { 'PS384' }) }
            4096 { return $(if ($RsaPaddingScheme -eq 'Pkcs1V15') { 'RS512' } else { 'PS512' }) }
            default { throw ($PodeLocale.unknownAlgorithmWithKeySizeExceptionMessage -f 'RSA', $rsa.KeySize) }
        }
    }
    else {
        $key = [System.Security.Cryptography.X509Certificates.ECDsaCertificateExtensions]::GetECDsaPrivateKey($X509Certificate)
        if ($null -ne $key) {
            Write-Verbose 'ECDSA Private Key detected.'

            # Determine ECDSA key size
            switch ($key.KeySize) {
                256 { return 'ES256' }
                384 { return 'ES384' }
                521 { return 'ES512' }  # JWT uses 521-bit, NOT 512-bit
                default { throw ($PodeLocale.unknownAlgorithmWithKeySizeExceptionMessage -f 'ECDSA' , $ecdsa.KeySize) }
            }
        }
        else {
            throw $PodeLocale.unknownAlgorithmOrInvalidPfxExceptionMessage
        }
    }
}

