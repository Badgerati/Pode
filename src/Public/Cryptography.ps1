
<#
.SYNOPSIS
    Validates a JWT payload by checking its registered claims as defined in RFC 7519.

.DESCRIPTION
    This function verifies the validity of a JWT payload by ensuring:
    - The `exp` (Expiration Time) has not passed.
    - The `nbf` (Not Before) time is not in the future.
    - The `iat` (Issued At) time is not in the future.
    - The `iss` (Issuer) claim is valid based on the verification mode.
    - The `sub` (Subject) claim is a valid string.
    - The `aud` (Audience) claim is valid based on the verification mode.
    - The `jti` (JWT ID) claim is a valid string.

.PARAMETER Payload
    The JWT payload as a [pscustomobject] containing registered claims such as `exp`, `nbf`, `iat`, `iss`, `sub`, `aud`, and `jti`.

.PARAMETER Issuer
    The expected JWT Issuer. If omitted, uses 'Pode'.

.PARAMETER JwtVerificationMode
    Defines how aggressively JWT claims should be checked:
    - `Strict`: Requires all standard claims to be valid (`exp`, `nbf`, `iat`, `iss`, `aud`, `jti`).
    - `Moderate`: Allows missing `iss` and `aud` but still checks expiration.
    - `Lenient`: Ignores missing `iss` and `aud`, only verifies `exp`, `nbf`, and `iat`.

.EXAMPLE
  $payload = [pscustomobject]@{
      iss = "auth.example.com"
      sub = "1234567890"
      aud = "myapi.example.com"
      exp = 1700000000
      nbf = 1690000000
      iat = 1690000000
      jti = "unique-token-id"
  }

  Test-PodeJwt -Payload $payload -JwtVerificationMode "Strict"

  This example validates a JWT payload with full claim verification.

.NOTES
  - This function does not verify the JWT signature. It only checks the payload claims.
  - Custom claims outside RFC 7519 are not validated by this function.
  - Throws an error if a claim is invalid or missing required values.
#>
function Test-PodeJwt {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Payload,

        [Parameter()]
        [string]$Issuer = 'Pode',

        [Parameter()]
        [ValidateSet('Strict', 'Moderate', 'Lenient')]
        [string]$JwtVerificationMode = 'Lenient'
    )

    # Get current Unix timestamp
    $currentUnix = [int][Math]::Floor(([DateTimeOffset]::new([DateTime]::UtcNow)).ToUnixTimeSeconds())

    # Validate Expiration (`exp`) - Applies to ALL modes
    if ($Payload.exp) {
        $expUnix = [long]$Payload.exp
        if ($currentUnix -ge $expUnix) {
            throw ($PodeLocale.jwtExpiredExceptionMessage)
        }
    }

    # Validate Not Before (`nbf`) - Applies to ALL modes
    if ($Payload.nbf) {
        $nbfUnix = [long]$Payload.nbf
        if ($currentUnix -lt $nbfUnix) {
            throw ($PodeLocale.jwtNotYetValidExceptionMessage)
        }
    }

    # Validate Issued At (`iat`) - Applies to ALL modes
    if ($Payload.iat) {
        $iatUnix = [long]$Payload.iat
        if ($iatUnix -gt $currentUnix) {
            throw ($PodeLocale.jwtIssuedInFutureExceptionMessage)
        }
    }

    # Validate Issuer (`iss`)
    if ($JwtVerificationMode -eq 'Strict' -or $JwtVerificationMode -eq 'Moderate') {
        if ($Payload.iss) {
            if (! $Payload.iss -or $Payload.iss -isnot [string] -or $Payload.iss -ne $Issuer) {
                throw ($PodeLocale.jwtInvalidIssuerExceptionMessage -f $Issuer)
            }
        }
        elseif ($JwtVerificationMode -eq 'Strict') {
            throw ($PodeLocale.jwtMissingIssuerExceptionMessage)
        }
    }
    # Validate Audience (`aud`)
    if ($JwtVerificationMode -eq 'Strict' -or $JwtVerificationMode -eq 'Moderate') {
        if ($Payload.aud) {
            if (! $Payload.aud -or ($Payload.aud -isnot [string] -and $Payload.aud -isnot [array])) {
                throw ($PodeLocale.jwtInvalidAudienceExceptionMessage -f $PodeContext.Server.ApplicationName)
            }

            # Enforce application audience check
            if ($Payload.aud -is [string]) {
                if ($Payload.aud -ne $PodeContext.Server.ApplicationName) {
                    throw ($PodeLocale.jwtInvalidAudienceExceptionMessage -f $PodeContext.Server.ApplicationName)
                }
            }
            elseif ($Payload.aud -is [array]) {
                if ($Payload.aud -notcontains $PodeContext.Server.ApplicationName) {
                    throw ($PodeLocale.jwtInvalidAudienceExceptionMessage -f $PodeContext.Server.ApplicationName)
                }
            }
        }
        elseif ($JwtVerificationMode -eq 'Strict') {
            throw ($PodeLocale.jwtMissingAudienceExceptionMessage)
        }
    }

    # Validate Subject (`sub`) - Applies to ALL modes
    if ($Payload.sub) {
        if (! $Payload.sub -or $Payload.sub -isnot [string]) {
            throw ($PodeLocale.jwtInvalidSubjectExceptionMessage)
        }
    }

    # Validate JWT ID (`jti`) - Only in Strict mode
    if ($JwtVerificationMode -eq 'Strict') {
        if ($Payload.jti) {
            if (! $Payload.jti -or $Payload.jti -isnot [string]) {
                throw ($PodeLocale.jwtInvalidJtiExceptionMessage)
            }
        }
        else {
            throw ($PodeLocale.jwtMissingJtiExceptionMessage)
        }
    }
}



<#
.SYNOPSIS
    Converts and returns the payload of a JWT token.

.DESCRIPTION
    Converts and returns the payload of a JWT token, verifying the signature by default with an option to ignore the signature.

.PARAMETER Token
    The JWT token to be decoded.

.PARAMETER Secret
    The secret key used to verify the token's signature (string or byte array).

.PARAMETER Certificate
    The path to a certificate used for RSA or ECDSA verification.

.PARAMETER CertificatePassword
    The password for the certificate file referenced in Certificate

.PARAMETER CertificateKey
    A key file to be paired with a PEM certificate file referenced in Certificate

.PARAMETER CertificateThumbprint
    A certificate thumbprint to use for RSA or ECDSA verification. (Windows).

.PARAMETER CertificateName
    A certificate subject name to use for RSA or ECDSA verification. (Windows).

.PARAMETER CertificateStoreName
    The name of a certifcate store where a certificate can be found (Default: My) (Windows).

.PARAMETER CertificateStoreLocation
    The location of a certifcate store where a certificate can be found (Default: CurrentUser) (Windows).

.PARAMETER X509Certificate
    The raw X509 certificate used for RSA or ECDSA verification.

.PARAMETER RsaPaddingScheme
    The RSA padding scheme to be used (default: Pkcs1V15).

.PARAMETER IgnoreSignature
    Skips signature verification and returns the decoded payload directly.

.PARAMETER Authentication
    The authentication method from Pode's context used for JWT verification.

.OUTPUTS
    [pscustomobject] - Returns the decoded JWT payload as a PowerShell object.

.EXAMPLE
    ConvertFrom-PodeJwt -Token "<JWT_TOKEN>" -Secret "MySecretKey"
    This example decodes a JWT token and verifies its signature using an HMAC secret.

.EXAMPLE
    ConvertFrom-PodeJwt -Token "<JWT_TOKEN>" -X509Certificate $Certificate
    This example decodes and verifies a JWT token using an X509 certificate.
#>
function ConvertFrom-PodeJwt {
    [CmdletBinding(DefaultParameterSetName = 'Secret')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Token,

        [Parameter(ParameterSetName = 'Ignore')]
        [switch]
        $IgnoreSignature,

        [Parameter(Mandatory = $true, ParameterSetName = 'SecretBytes')]
        $Secret = $null,

        [Parameter(Mandatory = $true, ParameterSetName = 'CertFile')]
        [string]
        $Certificate,

        [Parameter(ParameterSetName = 'CertFile')]
        [string]
        $CertificateKey = $null,

        [Parameter(Mandatory = $false, ParameterSetName = 'CertFile')]
        [SecureString]
        $CertificatePassword,

        [Parameter(Mandatory = $true, ParameterSetName = 'CertThumb')]
        [string]
        $CertificateThumbprint,

        [Parameter(Mandatory = $true, ParameterSetName = 'CertName')]
        [string]
        $CertificateName,

        [Parameter(ParameterSetName = 'CertName')]
        [Parameter(ParameterSetName = 'CertThumb')]
        [System.Security.Cryptography.X509Certificates.StoreName]
        $CertificateStoreName = 'My',

        [Parameter(ParameterSetName = 'CertName')]
        [Parameter(ParameterSetName = 'CertThumb')]
        [System.Security.Cryptography.X509Certificates.StoreLocation]
        $CertificateStoreLocation = 'CurrentUser',

        [Parameter( Mandatory = $true, ParameterSetName = 'CertRaw')]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]
        $X509Certificate,

        [Parameter(Mandatory = $false, ParameterSetName = 'CertRaw')]
        [Parameter(Mandatory = $false, ParameterSetName = 'CertFile')]
        [Parameter(Mandatory = $false, ParameterSetName = 'CertName')]
        [Parameter(Mandatory = $false, ParameterSetName = 'CertThumb')]
        [ValidateSet('Pkcs1V15', 'Pss')]
        [string]
        $RsaPaddingScheme = 'Pkcs1V15',

        [Parameter(Mandatory = $true, ParameterSetName = 'AuthenticationMethod')]
        [string]
        $Authentication
    )
    switch ($PSCmdlet.ParameterSetName) {
        'CertFile' {
            if (!(Test-Path -Path $Certificate -PathType Leaf)) {
                throw ($PodeLocale.pathNotExistExceptionMessage -f $Certificate)
            }
            $X509Certificate = Get-PodeCertificateByFile -Certificate $Certificate -SecurePassword $CertificatePassword -Key $CertificateKey
            break
        }

        'certthumb' {
            $X509Certificate = Get-PodeCertificateByThumbprint -Thumbprint $CertificateThumbprint -StoreName $CertificateStoreName -StoreLocation $CertificateStoreLocation
        }

        'certname' {
            $X509Certificate = Get-PodeCertificateByName -Name $CertificateName -StoreName $CertificateStoreName -StoreLocation $CertificateStoreLocation
        }

        'SecretBytes' {
            # Convert secret to bytes if needed
            if (($null -ne $Secret) -and ($Secret -isnot [byte[]])) {
                $Secret = if ($Secret -is [SecureString]) {
                    Convert-PodeSecureStringToByteArray -SecureString $Secret
                }
                else {
                    [System.Text.Encoding]::UTF8.GetBytes([string]$Secret)
                }

                if ($null -eq $Secret) {
                    throw ($PodeLocale.missingKeyForAlgorithmExceptionMessage -f 'secret', 'HMAC', $Header['alg'])
                }
            }

            $params = @{
                Secret = $Secret
            }
            break
        }

        'CertRaw' {
            if ($null -eq $X509Certificate) {
                throw ($PodeLocale.missingKeyForAlgorithmExceptionMessage -f 'private', 'RSA/ECSDA', $Header['alg'])
            }
            break
        }

        'AuthenticationMethod' {
            if ($PodeContext -and $PodeContext.Server.Authentications.Methods.ContainsKey($Authentication)) {
                $params = @{
                    Authentication = $Authentication
                }
            }
            else {
                throw ($PodeLocale.authenticationMethodDoesNotExistExceptionMessage)
            }
        }
    }

    if ( $X509Certificate) {
        $params = @{
            X509Certificate = $X509Certificate
        }
    }
    $params['Token'] = $Token

    # get the parts
    $parts = ($Token -isplit '\.')

    # check number of parts (should be 3)
    if ($parts.Length -ne 3) {
        # Invalid JWT supplied
        throw ($PodeLocale.invalidJwtSuppliedExceptionMessage)
    }

    # convert to header
    $header = ConvertFrom-PodeJwtBase64Value -Value $parts[0]
    if ([string]::IsNullOrWhiteSpace($header.alg)) {
        # Invalid JWT header algorithm supplied
        throw ($PodeLocale.invalidJwtHeaderAlgorithmSuppliedExceptionMessage)
    }

    # convert to payload
    $payload = ConvertFrom-PodeJwtBase64Value -Value $parts[1]

    # get signature
    if ($IgnoreSignature) {
        return $payload
    }

    $signature = $parts[2]

    # check "none" signature, and return payload if no signature
    $isNoneAlg = ($header.alg -ieq 'none')

    if ([string]::IsNullOrWhiteSpace($signature) -and !$isNoneAlg) {
        # No JWT signature supplied for {0}
        throw  ($PodeLocale.noJwtSignatureForAlgorithmExceptionMessage -f $header.alg)
    }

    if (![string]::IsNullOrWhiteSpace($signature) -and $isNoneAlg) {
        # Expected no JWT signature to be supplied
        throw ($PodeLocale.expectedNoJwtSignatureSuppliedExceptionMessage)
    }

    if ($isNoneAlg -and ($null -ne $Secret) -and ($Secret.Length -gt 0)) {
        # Expected no JWT signature to be supplied
        throw ($PodeLocale.expectedNoJwtSignatureSuppliedExceptionMessage)
    }

    if ($isNoneAlg) {
        return $payload
    }

    $params['Algorithm'] = $header.alg

    return Confirm-PodeJwt @params
}



<#
.SYNOPSIS
Converts a Header/Payload into a signed or unsigned JWT.

.DESCRIPTION
Converts a hashtable-based JWT header and payload into a JWT string. Automatically includes registered claims such as `exp`, `iat`, `nbf`, `iss`, `sub`, and `jti` if not provided. Supports signing using HMAC, RSA, and ECDSA.

.PARAMETER Header
  A hashtable containing JWT header information including the `alg` (algorithm).

.PARAMETER Payload
  A hashtable containing JWT payload information, including claims (`iss`, `sub`, `aud`, `exp`, `nbf`, `iat`, `jti`).

.PARAMETER Algorithm
  The signing algorithm. Supported values: NONE, HS256, HS384, HS512, RS256, RS384, RS512, PS256, PS384, PS512, ES256, ES384, ES512.

.PARAMETER Secret
  The secret key for HMAC algorithms, required for `HS256`, `HS384`, and `HS512`.

.PARAMETER Certificate
    The path to a certificate used for RSA or ECDSA verification.

.PARAMETER CertificatePassword
    The password for the certificate file referenced in Certificate

.PARAMETER CertificateKey
    A key file to be paired with a PEM certificate file referenced in Certificate

.PARAMETER CertificateThumbprint
    A certificate thumbprint to use for RSA or ECDSA verification. (Windows).

.PARAMETER CertificateName
    A certificate subject name to use for RSA or ECDSA verification. (Windows).

.PARAMETER CertificateStoreName
    The name of a certifcate store where a certificate can be found (Default: My) (Windows).

.PARAMETER CertificateStoreLocation
    The location of a certifcate store where a certificate can be found (Default: CurrentUser) (Windows).

.PARAMETER X509Certificate
    The raw X509 certificate used for RSA or ECDSA verification.

.PARAMETER RsaPaddingScheme
  RSA padding scheme to use, default is `Pkcs1V15`.

.PARAMETER Authentication
  Pode authentication method for signing the JWT.

.PARAMETER Expiration
  Expiration time for the JWT in seconds (default: 3600).

.PARAMETER NotBefore
  `nbf` claim in seconds (default: 0).

.PARAMETER IssuedAt
  `iat` claim as Unix timestamp.

.PARAMETER Issuer
  `iss` claim specifying the token issuer.

.PARAMETER Subject
  `sub` claim specifying the token subject.

.PARAMETER Audience
  `aud` claim specifying the token audience.

.PARAMETER JwtId
  `jti` claim as a unique identifier.

.PARAMETER NoStandardClaims
  If set, disables automatic inclusion of standard claims.

.OUTPUTS
  [string] - Returns the generated JWT string.

.EXAMPLE
ConvertTo-PodeJwt -Header @{ alg = 'none' } -Payload @{ sub = '123'; name = 'John' }

.EXAMPLE
ConvertTo-PodeJwt -Header @{ alg = 'HS256' } -Payload @{ sub = '123'; name = 'John' } -Secret 'abc'

.EXAMPLE
ConvertTo-PodeJwt -Header @{ alg = 'RS256' } -Payload @{ sub = '123' } -PrivateKey (Get-Content "private.pem" -Raw) -Issuer "auth.example.com" -Audience "myapi.example.com"

.NOTES
This function is an internal Pode function and is subject to change.
#>
function ConvertTo-PodeJwt {
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    [OutputType([string])]
    param(
        [Parameter()]
        [hashtable]$Header = @{},

        [Parameter(Mandatory = $true)]
        [hashtable]$Payload,

        [Parameter( ParameterSetName = 'Default')]
        [Parameter( ParameterSetName = 'SecretBytes')]
        [ValidateSet('NONE', 'HS256', 'HS384', 'HS512')]
        [string]
        $Algorithm ,

        [Parameter(Mandatory = $true, ParameterSetName = 'SecretBytes')]
        $Secret = $null,

        [Parameter( Mandatory = $true, ParameterSetName = 'CertRaw')]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]
        $X509Certificate,

        [Parameter(Mandatory = $true, ParameterSetName = 'CertFile')]
        [string]
        $Certificate,

        [Parameter(Mandatory = $false,ParameterSetName = 'CertFile')]
        [string]
        $CertificateKey = $null,

        [Parameter(Mandatory = $false, ParameterSetName = 'CertFile')]
        [SecureString]
        $CertificatePassword,

        [Parameter(Mandatory = $true, ParameterSetName = 'CertThumb')]
        [string]
        $CertificateThumbprint,

        [Parameter(Mandatory = $true, ParameterSetName = 'CertName')]
        [string]
        $CertificateName,

        [Parameter(ParameterSetName = 'CertName')]
        [Parameter(ParameterSetName = 'CertThumb')]
        [System.Security.Cryptography.X509Certificates.StoreName]
        $CertificateStoreName = 'My',

        [Parameter(ParameterSetName = 'CertName')]
        [Parameter(ParameterSetName = 'CertThumb')]
        [System.Security.Cryptography.X509Certificates.StoreLocation]
        $CertificateStoreLocation = 'CurrentUser',

        [Parameter(Mandatory = $false, ParameterSetName = 'CertRaw')]
        [Parameter(Mandatory = $false, ParameterSetName = 'CertFile')]
        [Parameter(Mandatory = $false, ParameterSetName = 'CertName')]
        [Parameter(Mandatory = $false, ParameterSetName = 'CertThumb')]
        [ValidateSet('Pkcs1V15', 'Pss')]
        [string]
        $RsaPaddingScheme = 'Pkcs1V15',

        [Parameter(Mandatory = $true, ParameterSetName = 'AuthenticationMethod')]
        [string]
        $Authentication,

        [Parameter()]
        [int]$Expiration = 3600, # Default: 1 hour

        [Parameter()]
        [int]$NotBefore = 0, # Default: Immediate use

        [Parameter()]
        [int]$IssuedAt = 0, # Default: Current time

        [Parameter()]
        [string]$Issuer,

        [Parameter()]
        [string]$Subject,

        [Parameter()]
        [string]$Audience,

        [Parameter()]
        [string]$JwtId,

        [Parameter()]
        [switch]
        $NoStandardClaims
    )

    switch ($PSCmdlet.ParameterSetName) {
        'CertFile' {
            if (!(Test-Path -Path $Certificate -PathType Leaf)) {
                throw ($PodeLocale.pathNotExistExceptionMessage -f $Certificate)
            }

            $X509Certificate = Get-PodeCertificateByFile -Certificate $Certificate -SecurePassword $CertificatePassword -Key $CertificateKey
            break
        }

        'certthumb' {
            $X509Certificate = Get-PodeCertificateByThumbprint -Thumbprint $CertificateThumbprint -StoreName $CertificateStoreName -StoreLocation $CertificateStoreLocation
        }

        'certname' {
            $X509Certificate = Get-PodeCertificateByName -Name $CertificateName -StoreName $CertificateStoreName -StoreLocation $CertificateStoreLocation
        }
        'SecretBytes' {
            if (!([string]::IsNullOrWhiteSpace($Header.alg))) {
                if ([string]::IsNullOrWhiteSpace($Algorithm)   ) {
                    $Algorithm = $Header.alg.ToUpper()
                }
            }
            if (($Algorithm -ieq 'none')) {
                # Expected no secret to be supplied for no signature
                throw ($PodeLocale.noSecretExpectedForNoSignatureExceptionMessage)
            }
            # Convert secret to bytes if needed
            if (($null -ne $Secret) -and ($Secret -isnot [byte[]])) {
                $Secret = if ($Secret -is [SecureString]) {
                    Convert-PodeSecureStringToByteArray -SecureString $Secret
                }
                else {
                    [System.Text.Encoding]::UTF8.GetBytes([string]$Secret)
                }

                if ($null -eq $Secret) {
                    throw ($PodeLocale.missingKeyForAlgorithmExceptionMessage -f 'secret', 'HMAC', $Header['alg'])
                }
            }
            if ([string]::IsNullOrWhiteSpace($Algorithm)) {
                $Algorithm = 'HS256'
            }

            $Header['alg'] = $Algorithm.ToUpper()
            $params = @{
                Algorithm   = $Algorithm.ToUpper()
                SecretBytes = $Secret
            }
            break
        }

        'CertRaw' {
            if ($null -eq $X509Certificate) {
                throw ($PodeLocale.missingKeyForAlgorithmExceptionMessage -f 'private', 'RSA/ECSDA', $Header['alg'])
            }
            break
        }
        'AuthenticationMethod' {
            if ($PodeContext -and $PodeContext.Server.Authentications.Methods.ContainsKey($Authentication)) {
                if (($Header['alg'] -ieq 'none') -and $PodeContext.Server.Authentications.Methods.ContainsKey($Authentication).Algorithm -notcontains 'none') {
                    # Expected no secret to be supplied for no signature
                    throw ($PodeLocale.noSecretExpectedForNoSignatureExceptionMessage)
                }
                $params = @{
                    Authentication = $Authentication
                }
            }
            else {
                throw ($PodeLocale.authenticationMethodDoesNotExistExceptionMessage)
            }
        }
    }

    if ($null -ne $X509Certificate) {
        $Header['alg'] = Get-PodeJwtSigningAlgorithm -X509Certificate $X509Certificate -RsaPaddingScheme $RsaPaddingScheme

        $params = @{
            X509Certificate  = $X509Certificate
            RsaPaddingScheme = $RsaPaddingScheme
        }
    }

    if (! $NoStandardClaims) {
        $Header.typ = 'JWT'

        # Automatically add standard claims if missing
        $currentUnix = [int][Math]::Floor(([DateTimeOffset]::new([DateTime]::UtcNow)).ToUnixTimeSeconds())


        if (! $Payload.ContainsKey('iat')) { $Payload['iat'] = if ($IssuedAt -gt 0) { $IssuedAt } else { $currentUnix } }
        if (! $Payload.ContainsKey('nbf')) { $Payload['nbf'] = $currentUnix + $NotBefore }
        if (! $Payload.ContainsKey('exp')) { $Payload['exp'] = $currentUnix + $Expiration }
        if (! $Payload.ContainsKey('iss')) {
            if ($Issuer) {
                $Payload['iss'] = $Issuer
            }
            elseif ($PodeContext) {
                $Payload['iss'] = 'Pode'
            }

        }

        if ($Subject -and ! $Payload.ContainsKey('sub')) { $Payload['sub'] = $Subject }
        if (! $Payload.ContainsKey('aud')) {
            if ($Audience) {
                $Payload['aud'] = $Audience
            }
            elseif ($PodeContext.Server.Application) {
                $Payload['aud'] = $PodeContext.Server.Application
            }
        }
        if ($JwtId -and ! $Payload.ContainsKey('jti')) { $Payload['jti'] = $JwtId }
        elseif (! $Payload.ContainsKey('jti')) { $Payload['jti'] = [guid]::NewGuid().ToString() }
    }

    # Convert header & payload to Base64 URL format
    $header64 = ConvertTo-PodeBase64UrlValue -Value ($Header | ConvertTo-Json -Compress)
    $payload64 = ConvertTo-PodeBase64UrlValue -Value ($Payload | ConvertTo-Json -Compress)

    # Combine header and payload
    $jwt = "$($header64).$($payload64)"

    $sig = if ($Header['alg'] -ne 'none') {
        $params['Token'] = $jwt
        # Generate the signature
        New-PodeJwtSignature @params
    }
    else {
        [string]::Empty
    }

    #  Append the signature and return the JWT
    $jwt += ".$($sig)"
    return $jwt
}
