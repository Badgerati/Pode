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
    Generates a JWT signature using the specified algorithm and secret.

.DESCRIPTION
    This function creates a JWT signature for a given token using the provided algorithm and secret key bytes.
    It ensures that a secret is supplied when required and throws an exception if constraints are violated.

.PARAMETER Algorithm
    The algorithm used for signing the JWT. Supported values depend on `Invoke-PodeJWTSign`.

.PARAMETER Token
    The JWT token to be signed.

.PARAMETER SecretBytes
    The secret key in byte array format used for signing the JWT.
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

.NOTES
    This function is an internal Pode function and is subject to change.
#>
function New-PodeJwtSignature {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
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
        $PrivateKey = ""
    )

    if (($Algorithm -ine 'none') -and (($null -eq $SecretBytes) -or ($SecretBytes.Length -eq 0))) {
        # No secret supplied for JWT signature
        throw ($PodeLocale.noSecretForJwtSignatureExceptionMessage)
    }

    if (($Algorithm -ieq 'none') -and (($null -ne $SecretBytes) -and ($SecretBytes.Length -gt 0))) {
        # Expected no secret to be supplied for no signature
        throw ($PodeLocale.noSecretExpectedForNoSignatureExceptionMessage)
    }

    $sig = Invoke-PodeJWTSign -Value $Token -Secret $SecretBytes -Algorithm $Algorithm.ToUpperInvariant() -PrivateKey $PrivateKey
    $sig = ConvertTo-PodeBase64UrlValue -Value $sig -NoConvert
    return $sig
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

    $Value = ($Value -ireplace '\+', '-')
    $Value = ($Value -ireplace '/', '_')
    $Value = ($Value -ireplace '=', '')

    return $Value
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
    $Value = ($Value -ireplace '-', '+')
    $Value = ($Value -ireplace '_', '/')

    # add padding
    switch ($Value.Length % 4) {
        1 {
            $Value = $Value.Substring(0, $Value.Length - 1)
        }

        2 {
            $Value += '=='
        }

        3 {
            $Value += '='
        }
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
    Computes a JWT-compatible signature using a specified RFC 7518 signing algorithm.

.DESCRIPTION
    This function computes a signature using HMAC (HS256, HS384, HS512), RSA (RS256, RS384, RS512, PS256, PS384, PS512), or ECDSA (ES256, ES384, ES512).

.PARAMETER Value
    The data to be signed.

.PARAMETER Algorithm
    The signing algorithm. Supported values: HS256, HS384, HS512, RS256, RS384, RS512, PS256, PS384, PS512, ES256, ES384, ES512.

.PARAMETER SecretBytes
    The secret key for HMAC algorithms.

.PARAMETER PrivateKey
    The private key (PEM format) for RSA or ECDSA algorithms.

.OUTPUTS
    Returns the computed signature as a base64-encoded string.

.EXAMPLE
    $signature = Invoke-PodeJWTSign -Value "TestData" -Algorithm HS256 -Secret "MySecretKey"
    Write-Host "HMAC-SHA256 Signature: $signature"

.EXAMPLE
    $privateKey = Get-Content "private_key.pem" -Raw
    $signature = Invoke-PodeJWTSign -Value "TestData" -Algorithm RS256 -PrivateKey $privateKey
    Write-Host "RSA-SHA256 Signature: $signature"
#>
function Invoke-PodeJWTSign {
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Value,

        [Parameter(Mandatory = $true)]
        [ValidateSet('NONE', 'HS256', 'HS384', 'HS512', 'RS256', 'RS384', 'RS512', 'PS256', 'PS384', 'PS512', 'ES256', 'ES384', 'ES512')]
        [string]
        $Algorithm,

        [Parameter()]
        [byte[]]
        $SecretBytes,

        [Parameter()]
        [securestring]
        $PrivateKey
    )

    $valueBytes = [System.Text.Encoding]::UTF8.GetBytes($Value)

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
        { $_ -match '^R[SP](\d{3})$' } {
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

    return [System.Convert]::ToBase64String($signature)
}

