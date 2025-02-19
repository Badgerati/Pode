
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
    Converts a JWT token into a PowerShell object, optionally verifying its signature.

.DESCRIPTION
    The ConvertFrom-PodeJwt function takes a JWT token and decodes its header, payload,
    and signature. By default, it verifies the signature using a specified secret,
    certificate, or Pode authentication method. If IgnoreSignature is specified,
    the function decodes and returns the token payload without verification.

.PARAMETER Token
    The JWT token to be decoded and optionally verified.

.PARAMETER IgnoreSignature
    Indicates that the JWT token signature should be ignored
    and the payload returned directly without verification.

.PARAMETER Outputs
    Determines which parts of the JWT should be returned:
    Header, Payload, Signature, or any combination thereof. Defaults to 'Payload'.

.PARAMETER HumanReadable
    Converts UNIX timestamps (e.g., iat, nbf, exp) into DateTime objects for easier reading.

.PARAMETER Secret
    A string or byte array used for HMAC-based signature verification.

.PARAMETER Certificate
    The path to a file containing an X.509 certificate for RSA/ECDSA signature verification.

.PARAMETER CertificateKey
    The path to a PEM key file that pairs with the certificate
    for RSA/ECDSA signature verification.

.PARAMETER CertificatePassword
    A SecureString containing a password for the certificate file, if required.

.PARAMETER CertificateThumbprint
    A thumbprint to retrieve a certificate from the Windows certificate store.

.PARAMETER CertificateName
    A subject name to retrieve a certificate from the Windows certificate store.

.PARAMETER CertificateStoreName
    The name of the Windows certificate store to search (default: My).

.PARAMETER CertificateStoreLocation
    The location of the Windows certificate store to search (default: CurrentUser).

.PARAMETER X509Certificate
    A raw X.509 certificate object used for RSA/ECDSA signature verification.

.PARAMETER RsaPaddingScheme
    Specifies the RSA padding scheme to use (Pkcs1V15 or Pss).
    Defaults to Pkcs1V15.

.PARAMETER Authentication
    A Pode authentication method name whose configuration is used
    for signature verification.

.OUTPUTS
    [pscustomobject] or [System.Collections.Specialized.OrderedDictionary].
    Returns one or more parts of the JWT (Header, Payload, Signature)
    as PowerShell objects or dictionaries.

.EXAMPLE
    ConvertFrom-PodeJwt -Token $jwtToken -Secret 'mysecret'
    Decodes and verifies the JWT token using an HMAC secret.

.EXAMPLE
    ConvertFrom-PodeJwt -Token $jwtToken -Certificate './certs/myCert.pem'
    Decodes and verifies the JWT token using an X.509 certificate from a file.

.NOTES
    - This function is tailored for use with Pode, a PowerShell web server framework.
    - When signature verification is enabled, the appropriate key or certificate must be provided.
    - Use HTTPS in production to safeguard tokens.
#>

function ConvertFrom-PodeJwt {
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    [OutputType([pscustomobject])]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'Secret')]
        [Parameter(Mandatory = $true, ParameterSetName = 'CertName')]
        [Parameter(Mandatory = $true, ParameterSetName = 'CertThumb')]
        [Parameter(Mandatory = $true, ParameterSetName = 'CertRaw')]
        [Parameter(Mandatory = $true, ParameterSetName = 'CertFile')]
        [Parameter(Mandatory = $true, ParameterSetName = 'Ignore')]
        [Parameter(Mandatory = $false, ParameterSetName = 'AuthenticationMethod')]
        [string]
        $Token,

        [Parameter(Mandatory = $false, ParameterSetName = 'Default')]
        [Parameter(ParameterSetName = 'Ignore')]
        [switch]
        $IgnoreSignature,

        [ValidateSet('Header', 'Payload', 'Signature', 'Header,Payload', 'Header,Signature', 'Payload,Signature', 'Header,Payload,Signature')]
        [string]
        $Outputs = 'Payload',

        [switch]
        $HumanReadable,

        [Parameter(Mandatory = $true, ParameterSetName = 'Secret')]
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

    # Identify which parameter set was chosen at runtime
    $parameterSetName = $PSCmdlet.ParameterSetName

    # If set to 'Default', but a WebEvent context has an authentication name, switch to 'AuthenticationMethod'
    if ($parameterSetName -eq 'Default') {
        if ($null -ne $WebEvent -and $null -ne $WebEvent.Auth.Name) {
            $parameterSetName = 'AuthenticationMethod'
            $Authentication = $WebEvent.Auth.Name
        }
    }

    # Prepare a hashtable for parameters required for validation (e.g., certificate, secret, etc.)
    # We'll populate it in the following switch statement.
    $params = @{}

    # Depending on the chosen parameter set, load/prepare the resources for signature validation.
    switch ($parameterSetName) {
        'CertFile' {
            if (!(Test-Path -Path $Certificate -PathType Leaf)) {
                throw ($PodeLocale.pathNotExistExceptionMessage -f $Certificate)
            }
            $X509Certificate = Get-PodeCertificateByFile -Certificate $Certificate -SecurePassword $CertificatePassword -Key $CertificateKey
        }
        'CertThumb' {
            $X509Certificate = Get-PodeCertificateByThumbprint -Thumbprint $CertificateThumbprint -StoreName $CertificateStoreName -StoreLocation $CertificateStoreLocation
        }
        'CertName' {
            $X509Certificate = Get-PodeCertificateByName -Name $CertificateName -StoreName $CertificateStoreName -StoreLocation $CertificateStoreLocation
        }
        'Secret' {
            if ($null -ne $Secret) {
                if ($Secret -is [string]) {
                    $params = @{ Secret = ConvertTo-SecureString -String $Secret -AsPlainText -Force }
                }
                elseif ($Secret -is [byte[]]) {
                    $params = @{ Secret = [System.Text.Encoding]::UTF8.GetString($Secret) }
                }
                else {
                    $params = @{ Secret = $Secret }
                }
            }
            else {
                throw ($PodeLocale.missingKeyForAlgorithmExceptionMessage -f 'secret', 'HMAC', $Header['alg'])
            }
        }
        'CertRaw' {
            if ($null -eq $X509Certificate) {
                throw ($PodeLocale.missingKeyForAlgorithmExceptionMessage -f 'private', 'RSA/ECSDA', $Header['alg'])
            }
        }
        'AuthenticationMethod' {
            # Validate that the specified authentication method exists in the current Pode context
            if ($PodeContext -and $PodeContext.Server.Authentications.Methods.ContainsKey($Authentication)) {
                $token = Get-PodeBearenToken
                $authArgs = $PodeContext.Server.Authentications.Methods[$Authentication].Scheme.Arguments
                if ($null -ne $authArgs.X509Certificate) {
                    $X509Certificate = $authArgs.X509Certificate
                }
                if ($null -ne $method.Secret) {
                    $params['Secret'] = $method.Secret
                }
            }
            else {
                throw ($PodeLocale.authenticationMethodDoesNotExistExceptionMessage)
            }
        }
        'Ignore' {
            # If ignoring signature, no additional data is needed.
        }
    }

    if ($X509Certificate) {
        $params['X509Certificate'] = $X509Certificate
    }

    $params['Token'] = $Token

    $parts = ($Token -split '\.')
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

    # Retrieve the signature part
    $signature = $parts[2]

    # If ignoring the signature, return the payload immediately
    if (! $IgnoreSignature) {



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
        $null = Confirm-PodeJwt @params
    }

    if ($HumanReadable) {
        if ($payload.iat) {
            $payload.iat = [System.DateTimeOffset]::FromUnixTimeSeconds($payload.iat).UtcDateTime
        }
        if ($payload.nbf) {
            $payload.nbf = [System.DateTimeOffset]::FromUnixTimeSeconds($payload.nbf).UtcDateTime
        }
        if ($payload.exp) {
            $payload.exp = [System.DateTimeOffset]::FromUnixTimeSeconds($payload.exp).UtcDateTime
        }
    }

    switch ($Outputs) {
        'Header' {
            return $header
        }
        'Payload' {
            return $payload
        }
        'Signature' {
            return $signature
        }
        'Header,Payload' {
            return [ordered]@{Header = $header; Payload = $payload }
        }
        'Header,Signature' {
            return [ordered]@{Header = $header; Signature = $signature }
        }
        'Payload,Signature' {
            return [ordered]@{Payload = $payload; Signature = $signature }
        }
        'Header,Payload,Signature' {
            return [ordered]@{Header = $header; Payload = $payload; Signature = $signature }
        }
        default {
            return $payload
        }
    }
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
    select the 'Secret' parameter set.

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
        [Parameter(ParameterSetName = 'Secret')]
        [ValidateSet('NONE', 'HS256', 'HS384', 'HS512')]
        [string]$Algorithm,

        [Parameter(Mandatory = $true, ParameterSetName = 'Secret')]
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

    $psHeader = [PSCustomObject]$Header
    $psPayload = [PSCustomObject]$Payload
    # Optionally add standard claims if not suppressed
    if (!$NoStandardClaims) {
        if (! $psHeader.PSObject.Properties['typ']) {
            $psHeader | Add-Member -MemberType NoteProperty -Name 'typ' -Value 'JWT'
        }
        else {
            $psHeader.typ = 'JWT'
        }

        # Current Unix time
        $currentUnix = [int][Math]::Floor(([DateTimeOffset]::new([DateTime]::UtcNow)).ToUnixTimeSeconds())

        if (! $psPayload.PSObject.Properties['iat']) {
            $psPayload | Add-Member -MemberType NoteProperty -Name 'iat' -Value $(if ($IssuedAt -gt 0) { $IssuedAt } else { $currentUnix })
        }
        if (! $psPayload.PSObject.Properties['nbf']) {
            $psPayload | Add-Member -MemberType NoteProperty -Name 'nbf' -Value ($currentUnix + $NotBefore)
        }
        if (! $psPayload.PSObject.Properties['exp']) {
            $psPayload | Add-Member -MemberType NoteProperty -Name 'exp' -Value ($currentUnix + $Expiration)
        }

        if (! $psPayload.PSObject.Properties['iss']) {
            if ([string]::IsNullOrEmpty($Issuer)) {
                if ($null -ne $PodeContext) {
                    $psPayload | Add-Member -MemberType NoteProperty -Name 'iss' -Value 'Pode'
                }
            }
            else {
                $psPayload | Add-Member -MemberType NoteProperty -Name 'iss' -Value $Issuer
            }
        }

        if (! $psPayload.PSObject.Properties['sub'] -and ![string]::IsNullOrEmpty($Subject)) {
            $psPayload | Add-Member -MemberType NoteProperty -Name 'sub' -Value $Subject
        }

        if (! $psPayload.PSObject.Properties['aud']) {
            if ([string]::IsNullOrEmpty($Audience)) {
                if (($null -ne $PodeContext) -and ($null -ne $PodeContext.Server.Application)) {
                    $psPayload | Add-Member -MemberType NoteProperty -Name 'aud' -Value $PodeContext.Server.Application
                }
            }
            else {
                $psPayload | Add-Member -MemberType NoteProperty -Name 'aud' -Value $Audience
            }
        }

        if (! $psPayload.PSObject.Properties['jti'] ) {
            if ([string]::IsNullOrEmpty($JwtId)) {
                $psPayload | Add-Member -MemberType NoteProperty -Name 'jti' -Value (New-PodeGuid)
            }
            else {
                $psPayload | Add-Member -MemberType NoteProperty -Name 'jti' -Value $JwtId
            }
        }
    }
    # Determine actions based on parameter set
    switch ($PSCmdlet.ParameterSetName) {
        'CertFile' {
            return New-PodeJwt -Certificate $Certificate -CertificatePassword $CertificatePassword `
                -CertificateKey $CertificateKey -RsaPaddingScheme $RsaPaddingScheme `
                -Payload $psPayload -Header $psHeader
        }

        'certthumb' {
            return New-PodeJwt -CertificateThumbprint $CertificateThumbprint -CertificateStoreName $CertificateStoreName `
                -CertificateStoreLocation $CertificateStoreLocation -RsaPaddingScheme $RsaPaddingScheme `
                -Payload $psPayload -Header $psHeader
        }

        'certname' {
            return New-PodeJwt -CertificateName $CertificateName -CertificateStoreName $CertificateStoreName `
                -CertificateStoreLocation $CertificateStoreLocation -RsaPaddingScheme $RsaPaddingScheme `
                -Payload $psPayload -Header $psHeader
        }

        'Secret' {
            # Convert secret to a byte array if needed
            if (($null -ne $Secret) -and ($Secret -isnot [byte[]])) {
                $Secret = if ($Secret -is [SecureString]) {
                    Convert-PodeSecureStringToByteArray -SecureString $Secret
                }
                else {
                    [System.Text.Encoding]::UTF8.GetBytes([string]$Secret)
                }

                if ($null -eq $Secret) {
                    throw ($PodeLocale.missingKeyForAlgorithmExceptionMessage -f 'secret', 'HMAC', $psHeader['alg'])
                }
            }

            if ([string]::IsNullOrWhiteSpace($Algorithm)) {
                $Algorithm = 'HS256'
            }

            return New-PodeJwt -Secret $Secret -Algorithm $Algorithm `
                -Payload $psPayload -Header $psHeader
        }

        'CertRaw' {
            return New-PodeJwt -X509Certificate $X509Certificate -RsaPaddingScheme $RsaPaddingScheme `
                -Payload $psPayload -Header $psHeader
        }

        'AuthenticationMethod' {
            return New-PodeJwt -Authentication $Authentication `
                -Payload $psPayload -Header $psHeader
        }
        default {
            return New-PodeJwt -Algorithm 'None' `
                -Payload $psPayload -Header $psHeader
        }
    }
}

<#
.SYNOPSIS
    Updates the expiration time of a JWT token.

.DESCRIPTION
    This function updates the expiration time of a given JWT token by extending it with a specified duration.
    It supports various signing methods including secret-based and certificate-based signing.
    The function can handle different types of certificates and authentication methods for signing the updated token.

.PARAMETER Token
    The JWT token to be updated.

.PARAMETER ExpirationExtension
    The number of seconds to extend the expiration time by. If not specified, the original expiration duration is used.

.PARAMETER Secret
    The secret key used for HMAC signing (string or byte array).

.PARAMETER X509Certificate
    The raw X509 certificate used for RSA or ECDSA signing.

.PARAMETER Certificate
    The path to a certificate file used for signing.

.PARAMETER CertificatePassword
    The password for the certificate file referenced in Certificate.

.PARAMETER CertificateKey
    A key file to be paired with a PEM certificate file referenced in Certificate.

.PARAMETER CertificateThumbprint
    A certificate thumbprint to use for RSA or ECDSA signing. (Windows).

.PARAMETER CertificateName
    A certificate subject name to use for RSA or ECDSA signing. (Windows).

.PARAMETER CertificateStoreName
    The name of a certificate store where a certificate can be found (Default: My) (Windows).

.PARAMETER CertificateStoreLocation
    The location of a certificate store where a certificate can be found (Default: CurrentUser) (Windows).

.PARAMETER Authentication
    The authentication method from Pode's context used for JWT signing.

.EXAMPLE
    Update-PodeJwt -Token "<JWT_TOKEN>" -ExpirationExtension 3600 -Secret "MySecretKey"
    This example updates the expiration time of a JWT token by extending it by 1 hour using an HMAC secret.

.EXAMPLE
    Update-PodeJwt -Token "<JWT_TOKEN>" -ExpirationExtension 3600 -X509Certificate $Certificate
    This example updates the expiration time of a JWT token by extending it by 1 hour using an X509 certificate.
#>
function Update-PodeJwt {
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'Secret')]
        [Parameter(Mandatory = $true, ParameterSetName = 'CertName')]
        [Parameter(Mandatory = $true, ParameterSetName = 'CertThumb')]
        [Parameter(Mandatory = $true, ParameterSetName = 'CertRaw')]
        [Parameter(Mandatory = $true, ParameterSetName = 'CertFile')]
        [string]
        $Token,

        [Parameter()]
        [int]
        $ExpirationExtension = 0,

        [Parameter(Mandatory = $true, ParameterSetName = 'Secret')]
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

        [Parameter(Mandatory = $true, ParameterSetName = 'AuthenticationMethod')]
        [string]
        $Authentication
    )

    $parameterSetName = $PSCmdlet.ParameterSetName

    if ($parameterSetName -eq 'Default') {
        if ($null -ne $WebEvent -and $null -ne $WebEvent.Auth.Name) {
            $parameterSetName = 'AuthenticationMethod'
            $Authentication = $WebEvent.Auth.Name
        }
    }

    if ($parameterSetName -eq 'AuthenticationMethod') {
        $token = Get-PodeBearenToken
    }

    $jwt = ConvertFrom-PodeJwt -Token $Token -IgnoreSignature -Outputs 'Header,Payload'
    if ($null -eq $jwt.Payload.exp) {
        throw ($PodeLocale.jwtNoExpirationExceptionMessage)
    }

    if ($ExpirationExtension -eq 0 -and $jwt.Payload.exp -and $jwt.Payload.iat) {
        $ExpirationExtension = $jwt.Payload.exp - $jwt.Payload.iat
    }
    # if the token has an expiration time, update it
    if ($ExpirationExtension -gt 0) {
        $jwt.Payload.exp = [int][Math]::Floor(([DateTimeOffset]::new([DateTime]::UtcNow)).ToUnixTimeSeconds()) + $ExpirationExtension
    }

    if ('PS256', 'PS384', 'PS512' -ccontains $jwt.Header.alg) {
        $rsaPaddingScheme = 'Pss'
    }
    else {
        $rsaPaddingScheme = 'Pkcs1V15'
    }

    $params = switch ($parameterSetName) {
        # If the secret is provided as a byte array, use it for signing
        'CertFile' {
            @{
                Payload             = $jwt.Payload
                Header              = $jwt.Header
                Certificate         = $Certificate
                CertificateKey      = $CertificateKey
                CertificatePassword = $CertificatePassword
                RsaPaddingScheme    = $rsaPaddingScheme
            }
        }
        # If the certificate thumbprint is provided, use it for signing
        'CertThumb' {
            @{
                Payload                  = $jwt.Payload
                Header                   = $jwt.Header
                CertificateThumbprint    = $CertificateThumbprint
                CertificateStoreName     = $CertificateStoreName
                CertificateStoreLocation = $CertificateStoreLocation
                RsaPaddingScheme         = $rsaPaddingScheme
            }
        }
        # If the certificate name is provided, use it for signing
        'CertName' {
            @{
                Payload                  = $jwt.Payload
                Header                   = $jwt.Header
                CertificateName          = $CertificateName
                CertificateStoreName     = $CertificateStoreName
                CertificateStoreLocation = $CertificateStoreLocation
                RsaPaddingScheme         = $rsaPaddingScheme
            }
        }
        # If the secret is provided as a byte array, use it for signing
        'Secret' {
            @{
                Payload = $jwt.Payload
                Header  = $jwt.Header
                Secret  = $Secret
            }
        }
        # If the certificate is provided as a raw object, use it for signing
        'CertRaw' {
            @{
                Payload         = $jwt.Payload
                Header          = $jwt.Header
                X509Certificate = $X509Certificate
            }
        }
        'AuthenticationMethod' {
            @{
                Payload        = $jwt.Payload
                Header         = $jwt.Header
                Authentication = $Authentication
            }
        }
    }

    # Update the JWT with the new expiration time
    return New-PodeJwt @params
}
