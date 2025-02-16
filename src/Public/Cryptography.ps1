
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
#>
function Test-PodeJwt {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]
        $Payload,

        [Parameter()]
        [string]
        $Issuer = 'Pode',

        [Parameter()]
        [ValidateSet('Strict', 'Moderate', 'Lenient')]
        [string]
        $JwtVerificationMode = 'Lenient'
    )

    # Get the current Unix timestamp for time-based checks
    $currentUnix = [int][Math]::Floor(([DateTimeOffset]::new([DateTime]::UtcNow)).ToUnixTimeSeconds())

    # Validate Expiration (`exp`) - applies to all verification modes
    if ($Payload.exp) {
        $expUnix = [long]$Payload.exp
        if ($currentUnix -ge $expUnix) {
            throw ($PodeLocale.jwtExpiredExceptionMessage)
        }
    }

    # Validate Not Before (`nbf`) - applies to all verification modes
    if ($Payload.nbf) {
        $nbfUnix = [long]$Payload.nbf
        if ($currentUnix -lt $nbfUnix) {
            throw ($PodeLocale.jwtNotYetValidExceptionMessage)
        }
    }

    # Validate Issued At (`iat`) - applies to all verification modes
    if ($Payload.iat) {
        $iatUnix = [long]$Payload.iat
        if ($iatUnix -gt $currentUnix) {
            throw ($PodeLocale.jwtIssuedInFutureExceptionMessage)
        }
    }

    # Validate Issuer (`iss`) if mode is Strict or Moderate
    if ($JwtVerificationMode -eq 'Strict' -or $JwtVerificationMode -eq 'Moderate') {
        if ($Payload.iss) {
            # Check that the Issuer is a valid string and matches the expected Issuer
            if (!$Payload.iss -or $Payload.iss -isnot [string] -or $Payload.iss -ne $Issuer) {
                throw ($PodeLocale.jwtInvalidIssuerExceptionMessage -f $Issuer)
            }
        }
        elseif ($JwtVerificationMode -eq 'Strict') {
            # If the claim is missing in Strict mode, throw an error
            throw ($PodeLocale.jwtMissingIssuerExceptionMessage)
        }
    }

    # Validate Audience (`aud`) if mode is Strict or Moderate
    if ($JwtVerificationMode -eq 'Strict' -or $JwtVerificationMode -eq 'Moderate') {
        if ($Payload.aud) {
            # Ensure `aud` is either a string or an array of strings
            if (!$Payload.aud -or ($Payload.aud -isnot [string] -and $Payload.aud -isnot [array])) {
                throw ($PodeLocale.jwtInvalidAudienceExceptionMessage -f $PodeContext.Server.ApplicationName)
            }

            # In Pode, check the application's name against `aud`
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
            # If `aud` is missing in Strict mode, throw an error
            throw ($PodeLocale.jwtMissingAudienceExceptionMessage)
        }
    }

    # Validate Subject (`sub`) - applies to all verification modes
    if ($Payload.sub) {
        if (!$Payload.sub -or $Payload.sub -isnot [string]) {
            throw ($PodeLocale.jwtInvalidSubjectExceptionMessage)
        }
    }

    # Validate JWT ID (`jti`) - only in Strict mode
    if ($JwtVerificationMode -eq 'Strict') {
        if ($Payload.jti) {
            # Check that `jti` is a valid string
            if (!$Payload.jti -or $Payload.jti -isnot [string]) {
                throw ($PodeLocale.jwtInvalidJtiExceptionMessage)
            }
        }
        else {
            # `jti` must exist in Strict mode
            throw ($PodeLocale.jwtMissingJtiExceptionMessage)
        }
    }
}



<#
.SYNOPSIS
	Converts and returns the payload of a JWT token.

.DESCRIPTION
	Converts and returns the payload of a JWT token, verifying the signature by default
	with an option to ignore the signature.

.PARAMETER Token
	The JWT token to be decoded.

.PARAMETER Secret
	The secret key used to verify the token's signature (string or byte array).

.PARAMETER Certificate
	The path to a certificate used for RSA or ECDSA verification.

.PARAMETER CertificatePassword
	The password for the certificate file referenced in Certificate.

.PARAMETER CertificateKey
	A key file to be paired with a PEM certificate file referenced in Certificate.

.PARAMETER CertificateThumbprint
	A certificate thumbprint to use for RSA or ECDSA verification. (Windows).

.PARAMETER CertificateName
	A certificate subject name to use for RSA or ECDSA verification. (Windows).

.PARAMETER CertificateStoreName
	The name of a certificate store where a certificate can be found (Default: My) (Windows).

.PARAMETER CertificateStoreLocation
	The location of a certificate store where a certificate can be found (Default: CurrentUser) (Windows).

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
        [object]
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

        [Parameter(Mandatory = $true, ParameterSetName = 'CertRaw')]
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

    # Determine how to verify the JWT based on the supplied parameters
    switch ($PSCmdlet.ParameterSetName) {
        'CertFile' {
            # Validate that the certificate file exists and then load it
            if (!(Test-Path -Path $Certificate -PathType Leaf)) {
                throw ($PodeLocale.pathNotExistExceptionMessage -f $Certificate)
            }
            $X509Certificate = Get-PodeCertificateByFile -Certificate $Certificate -SecurePassword $CertificatePassword -Key $CertificateKey
            break
        }

        'certthumb' {
            # Retrieve certificate by thumbprint in a specific store name/location
            $X509Certificate = Get-PodeCertificateByThumbprint -Thumbprint $CertificateThumbprint -StoreName $CertificateStoreName -StoreLocation $CertificateStoreLocation
        }

        'certname' {
            # Retrieve certificate by subject name in a specific store name/location
            $X509Certificate = Get-PodeCertificateByName -Name $CertificateName -StoreName $CertificateStoreName -StoreLocation $CertificateStoreLocation
        }

        'SecretBytes' {
            # Convert the secret to a byte array if necessary for HMAC verification
            if (($null -ne $Secret) -and ($Secret -isnot [byte[]])) {
                $Secret = if ($Secret -is [SecureString]) {
                    Convert-PodeSecureStringToByteArray -SecureString $Secret
                }
                else {
                    [System.Text.Encoding]::UTF8.GetBytes([string]$Secret)
                }

                # If no valid secret is found, throw an error
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
            # Validate raw certificate object if a cert-based algorithm is used
            if ($null -eq $X509Certificate) {
                throw ($PodeLocale.missingKeyForAlgorithmExceptionMessage -f 'private', 'RSA/ECSDA', $Header['alg'])
            }
            break
        }

        'AuthenticationMethod' {
            # Validate that the specified authentication method exists in the current Pode context
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

    # If we have a valid X509Certificate, add it to the parameters
    if ($X509Certificate) {
        $params = @{
            X509Certificate = $X509Certificate
        }
    }

    # Always pass the token for further processing
    $params['Token'] = $Token

    # Split the JWT into its three parts: header, payload, and signature
    $parts = ($Token -isplit '\.')

    # Verify that the token has exactly three parts
    if ($parts.Length -ne 3) {
        throw ($PodeLocale.invalidJwtSuppliedExceptionMessage)
    }

    # Decode the header; this should contain the algorithm type (alg)
    $header = ConvertFrom-PodeJwtBase64Value -Value $parts[0]
    if ([string]::IsNullOrWhiteSpace($header.alg)) {
        throw ($PodeLocale.invalidJwtHeaderAlgorithmSuppliedExceptionMessage)
    }

    # Decode the payload; contains claims like sub, exp, iat, etc.
    $payload = ConvertFrom-PodeJwtBase64Value -Value $parts[1]

    # If ignoring the signature, return the payload immediately
    if ($IgnoreSignature) {
        return $payload
    }

    # Retrieve the signature part
    $signature = $parts[2]

    # Some JWTs may specify "none" as the algorithm (no signature)
    $isNoneAlg = ($header.alg -ieq 'none')

    # If signature is missing but an algorithm is expected, throw an error
    if ([string]::IsNullOrWhiteSpace($signature) -and !$isNoneAlg) {
        throw ($PodeLocale.noJwtSignatureForAlgorithmExceptionMessage -f $header.alg)
    }

    # If "none" is indicated but a signature was supplied, throw an error
    if (![string]::IsNullOrWhiteSpace($signature) -and $isNoneAlg) {
        throw ($PodeLocale.expectedNoJwtSignatureSuppliedExceptionMessage)
    }

    # If alg is "none" but a secret was provided, throw an error
    if ($isNoneAlg -and ($null -ne $Secret) -and ($Secret.Length -gt 0)) {
        throw ($PodeLocale.expectedNoJwtSignatureSuppliedExceptionMessage)
    }

    # If "none" signature, return the payload since there's nothing to verify
    if ($isNoneAlg) {
        return $payload
    }

    # At this point, we have a valid signature with a known algorithm
    $params['Algorithm'] = $header.alg

    # Confirm-PodeJwt will finalize verification based on the algorithm and parameters
    return Confirm-PodeJwt @params
}

<#
.SYNOPSIS
    Generates a JSON Web Token (JWT) based on the specified headers, payload, and signing credentials.
.DESCRIPTION
    This function creates a JWT by combining a Base64URL-encoded header and payload. Depending on the
    configured parameters, it supports various signing algorithms, including HMAC- and certificate-based
    signatures. You can also omit a signature by specifying 'none'.

.PARAMETER Header
    Additional header values for the JWT. Defaults to an empty hashtable if not specified.

.PARAMETER Payload
    The required hashtable specifying the token’s claims.

.PARAMETER Algorithm
    A string representing the signing algorithm to be used. Accepts 'NONE', 'HS256', 'HS384', or 'HS512'.

.PARAMETER Secret
    Used in conjunction with HMAC signing. Can be either a byte array or a SecureString. Required if you
    select the 'SecretBytes' parameter set.

.PARAMETER X509Certificate
    An X509Certificate2 object used for RSA/ECDSA-based signing. Required if you select the 'CertRaw' parameter set.

.PARAMETER Certificate
    The path to a certificate file used for signing. Required if you select the 'CertFile' parameter set.

.PARAMETER CertificateKey
    Optional path to an associated certificate key file.

.PARAMETER CertificatePassword
    An optional SecureString password for a certificate file.

.PARAMETER CertificateThumbprint
    A string thumbprint of a certificate in the local store. Required if you select the 'CertThumb' parameter set.

.PARAMETER CertificateName
    A string name of a certificate in the local store. Required if you select the 'CertName' parameter set.

.PARAMETER CertificateStoreName
    The store name to search for the specified certificate. Defaults to 'My'.

.PARAMETER CertificateStoreLocation
    The certificate store location for the specified certificate. Defaults to 'CurrentUser'.

.PARAMETER RsaPaddingScheme
    Specifies the RSA padding scheme to use. Accepts 'Pkcs1V15' or 'Pss'. Defaults to 'Pkcs1V15'.

.PARAMETER Authentication
    The name of a configured authentication method in Pode. Required if you select the 'AuthenticationMethod' parameter set.

.PARAMETER Expiration
    Time in seconds until the token expires. Defaults to 3600 (1 hour).

.PARAMETER NotBefore
    Time in seconds to offset the NotBefore claim. Defaults to 0 for immediate use.

.PARAMETER IssuedAt
    Time in seconds to offset the IssuedAt claim. Defaults to 0 for current time.

.PARAMETER Issuer
    Identifies the principal that issued the token.

.PARAMETER Subject
    Identifies the principal that is the subject of the token.

.PARAMETER Audience
    Specifies the recipients that the token is intended for.

.PARAMETER JwtId
    A unique identifier for the token.

.PARAMETER NoStandardClaims
    A switch that, if used, prevents automatically adding iat, nbf, exp, iss, sub, aud, and jti claims.

.OUTPUTS
    System.String
    The resulting JWT string.


.EXAMPLE
    ConvertTo-PodeJwt -Header @{ alg = 'none' } -Payload @{ sub = '123'; name = 'John' }

.EXAMPLE
    ConvertTo-PodeJwt -Header @{ alg = 'HS256' } -Payload @{ sub = '123'; name = 'John' } -Secret 'abc'

.EXAMPLE
    ConvertTo-PodeJwt -Header @{ alg = 'RS256' } -Payload @{ sub = '123' } -PrivateKey (Get-Content "private.pem" -Raw) -Issuer "auth.example.com" -Audience "myapi.example.com"
#>
function ConvertTo-PodeJwt {
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    [OutputType([string])]
    param(
        [Parameter()]
        [hashtable]$Header = @{},

        [Parameter(Mandatory = $true)]
        [hashtable]$Payload,

        [Parameter(ParameterSetName = 'Default')]
        [Parameter(ParameterSetName = 'SecretBytes')]
        [ValidateSet('NONE', 'HS256', 'HS384', 'HS512')]
        [string]$Algorithm,

        [Parameter(Mandatory = $true, ParameterSetName = 'SecretBytes')]
        $Secret = $null,

        [Parameter(Mandatory = $true, ParameterSetName = 'CertRaw')]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]
        $X509Certificate,

        [Parameter(Mandatory = $true, ParameterSetName = 'CertFile')]
        [string]$Certificate,

        [Parameter(Mandatory = $false, ParameterSetName = 'CertFile')]
        [string]$CertificateKey = $null,

        [Parameter(Mandatory = $false, ParameterSetName = 'CertFile')]
        [SecureString]$CertificatePassword,

        [Parameter(Mandatory = $true, ParameterSetName = 'CertThumb')]
        [string]$CertificateThumbprint,

        [Parameter(Mandatory = $true, ParameterSetName = 'CertName')]
        [string]$CertificateName,

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
        [int]
        $Expiration = 3600, # Default: 1 hour

        [Parameter()]
        [int]
        $NotBefore = 0, # Default: Immediate

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

    # Determine actions based on parameter set
    switch ($PSCmdlet.ParameterSetName) {
        'CertFile' {
            if (!(Test-Path -Path $Certificate -PathType Leaf)) {
                throw ($PodeLocale.pathNotExistExceptionMessage -f $Certificate)
            }

            # Retrieve X509 certificate from a file
            $X509Certificate = Get-PodeCertificateByFile -Certificate $Certificate -SecurePassword $CertificatePassword -Key $CertificateKey
            break
        }

        'certthumb' {
            # Retrieve X509 certificate from store by thumbprint
            $X509Certificate = Get-PodeCertificateByThumbprint -Thumbprint $CertificateThumbprint -StoreName $CertificateStoreName -StoreLocation $CertificateStoreLocation
        }

        'certname' {
            # Retrieve X509 certificate from store by name
            $X509Certificate = Get-PodeCertificateByName -Name $CertificateName -StoreName $CertificateStoreName -StoreLocation $CertificateStoreLocation
        }

        'SecretBytes' {
            # If algorithm was already set in the header, default to it if none provided
            if (!([string]::IsNullOrWhiteSpace($Header.alg))) {
                if ([string]::IsNullOrWhiteSpace($Algorithm)) {
                    $Algorithm = $Header.alg.ToUpper()
                }
            }

            # Validate that 'none' has no secret
            if (($Algorithm -ieq 'none')) {
                throw ($PodeLocale.noSecretExpectedForNoSignatureExceptionMessage)
            }

            # Convert secret to a byte array if needed
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
            # Validate that a raw certificate is present
            if ($null -eq $X509Certificate) {
                throw ($PodeLocale.missingKeyForAlgorithmExceptionMessage -f 'private', 'RSA/ECSDA', $Header['alg'])
            }
            break
        }

        'AuthenticationMethod' {
            # Retrieve authentication details from Pode's context
            if ($PodeContext -and $PodeContext.Server.Authentications.Methods.ContainsKey($Authentication)) {
                # If 'none' was set in the header but is not supported by the method, throw
                if (($Header['alg'] -ieq 'none') -and $PodeContext.Server.Authentications.Methods.ContainsKey($Authentication).Algorithm -notcontains 'none') {
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

    # Configure the JWT header and parameters if using a certificate
    if ($null -ne $X509Certificate) {
        $Header['alg'] = Get-PodeJwtSigningAlgorithm -X509Certificate $X509Certificate -RsaPaddingScheme $RsaPaddingScheme
        $params = @{
            X509Certificate  = $X509Certificate
            RsaPaddingScheme = $RsaPaddingScheme
        }
    }

    # Optionally add standard claims if not suppressed
    if (!$NoStandardClaims) {
        $Header.typ = 'JWT'

        # Current Unix time
        $currentUnix = [int][Math]::Floor(([DateTimeOffset]::new([DateTime]::UtcNow)).ToUnixTimeSeconds())

        if (!$Payload.ContainsKey('iat')) {
            $Payload['iat'] = if ($IssuedAt -gt 0) { $IssuedAt } else { $currentUnix }
        }
        if (!$Payload.ContainsKey('nbf')) {
            $Payload['nbf'] = $currentUnix + $NotBefore
        }
        if (!$Payload.ContainsKey('exp')) {
            $Payload['exp'] = $currentUnix + $Expiration
        }
        if (!$Payload.ContainsKey('iss')) {
            if ($Issuer) {
                $Payload['iss'] = $Issuer
            }
            elseif ($PodeContext) {
                $Payload['iss'] = 'Pode'
            }
        }
        if ($Subject -and !$Payload.ContainsKey('sub')) {
            $Payload['sub'] = $Subject
        }
        if (!$Payload.ContainsKey('aud')) {
            if ($Audience) {
                $Payload['aud'] = $Audience
            }
            elseif ($PodeContext.Server.Application) {
                $Payload['aud'] = $PodeContext.Server.Application
            }
        }
        if ($JwtId -and !$Payload.ContainsKey('jti')) {
            $Payload['jti'] = $JwtId
        }
        elseif (!$Payload.ContainsKey('jti')) {
            $Payload['jti'] = [guid]::NewGuid().ToString()
        }
    }

    # Encode header and payload as Base64URL
    $header64 = ConvertTo-PodeBase64UrlValue -Value ($Header | ConvertTo-Json -Compress)
    $payload64 = ConvertTo-PodeBase64UrlValue -Value ($Payload | ConvertTo-Json -Compress)

    # Combine header and payload
    $jwt = "$($header64).$($payload64)"

    # Generate signature if not 'none'
    $sig = if ($Header['alg'] -ne 'none') {
        $params['Token'] = $jwt
        New-PodeJwtSignature @params
    }
    else {
        [string]::Empty
    }

    # Concatenate signature to form the final JWT
    $jwt += ".$($sig)"
    return $jwt
}
