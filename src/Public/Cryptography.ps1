using namespace System.Security.Cryptography
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

.PARAMETER PrivateKeyPath
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
        $PrivateKeyPath = $null,

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
            $X509Certificate = Get-PodeCertificateByFile -Certificate $Certificate -SecurePassword $CertificatePassword -PrivateKeyPath $PrivateKeyPath
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
        # Validate the certificate's validity period before proceeding
        Test-PodeCertificate -Certificate $X509Certificate

        # Ensure the certificate is authorized for the expected purpose
        Test-PodeCertificateRestriction -Certificate $X509Certificate -ExpectedPurpose CodeSigning -Strict

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

.PARAMETER PrivateKeyPath
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
        [string]$PrivateKeyPath = $null,

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
                if (($null -ne $PodeContext) -and ($null -ne $PodeContext.Server.ApplicationName)) {
                    $psPayload | Add-Member -MemberType NoteProperty -Name 'aud' -Value $PodeContext.Server.ApplicationName
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
                -PrivateKeyPath $PrivateKeyPath -RsaPaddingScheme $RsaPaddingScheme `
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

.PARAMETER PrivateKeyPath
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
        [string]$PrivateKeyPath = $null,

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
                PrivateKeyPath      = $PrivateKeyPath
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




<#
.SYNOPSIS
  Generates a certificate signing request (CSR) and private key.

.DESCRIPTION
  This function creates a certificate signing request (CSR) using RSA or ECDSA key pairs.
  It allows specifying subject details, key usage, enhanced key usage (EKU), and custom extensions.
  The CSR and private key are automatically saved to files in the specified output directory.

.PARAMETER DnsName
  One or more DNS names (or IP addresses) to be included in the Subject Alternative Name (SAN).

.PARAMETER CommonName
  The Common Name (CN) for the certificate subject. Defaults to the first DNS name if not provided.

.PARAMETER Organization
  The organization (O) name to be included in the certificate subject.

.PARAMETER Locality
  The locality (L) name to be included in the certificate subject.

.PARAMETER State
  The state (S) name to be included in the certificate subject.

.PARAMETER Country
  The country (C) code (ISO 3166-1 alpha-2). Defaults to 'XX'.

.PARAMETER KeyType
  The cryptographic key type for the certificate request. Supported values: 'RSA', 'ECDSA'. Defaults to 'RSA'.

.PARAMETER KeyLength
  The key length for RSA (2048, 3072, 4096) or ECDSA (256, 384, 521). Defaults to 2048.

.PARAMETER CertificatePurpose
  The intended purpose of the certificate, which automatically sets the EKU.
  Supported values: 'ServerAuth', 'ClientAuth', 'CodeSigning', 'EmailSecurity', 'Custom'.

.PARAMETER EnhancedKeyUsages
  A list of OID strings for Enhanced Key Usage (EKU) if 'Custom' is selected as CertificatePurpose.

.PARAMETER NotBefore
  The NotBefore date for the certificate request. Defaults to the current UTC time.

.PARAMETER CustomExtensions
  An array of additional custom certificate extensions.

.PARAMETER FriendlyName
  An optional friendly name for the certificate request.

.PARAMETER OutputPath
  The directory where the CSR and private key files will be saved. Defaults to the current working directory.

.OUTPUTS
  [PSCustomObject]
  Returns an object containing:
    - CsrPath: The file path of the CSR.
    - PrivateKeyPath: The file path of the private key.

.EXAMPLE
  $csr = New-PodeCertificateRequest -DnsName "example.com" -CommonName "example.com" -KeyType "RSA" -KeyLength 2048
  Generates an RSA CSR for "example.com" and saves it to the current working directory.

.EXAMPLE
  $csr = New-PodeCertificateRequest -DnsName "example.com" -KeyType "ECDSA" -KeyLength 384 -CertificatePurpose "ServerAuth" -OutputPath "C:\Certs"
  Generates an ECDSA CSR with an automatically assigned EKU for server authentication and saves it to "C:\Certs".

.NOTES
  - This function integrates with Pode’s certificate handling utilities.
  - The private key is exported in PKCS#8 format.
  - Ensure the private key is stored securely.
#>
function New-PodeCertificateRequest {
    [CmdletBinding(DefaultParameterSetName = 'CommonName')]
    [OutputType([PSCustomObject])]
    param (
        # Required: one or more DNS names (or IP addresses)
        [Parameter()]
        [string[]]
        $DnsName,

        # Subject parts
        [Parameter()]
        [string]
        $CommonName,

        [Parameter()]
        [string]
        $Organization,

        [Parameter()]
        [string]
        $Locality,

        [Parameter()]
        [string]
        $State,

        [Parameter()]
        [string]
        $Country = 'XX',

        # Key type and size
        [Parameter()]
        [ValidateSet('RSA', 'ECDSA')]
        [string]$KeyType = 'RSA',

        [Parameter()]
        [ValidateSet(2048, 3072, 4096, 256, 384, 521)]
        [int]$KeyLength = 2048,

        #Automatically set EKUs based on intended purpose
        [Parameter()]
        [ValidateSet('ServerAuth', 'ClientAuth', 'CodeSigning', 'EmailSecurity', 'Custom')]
        [string]
        $CertificatePurpose,

        # Enhanced Key Usages (EKU) - supply one or more OID strings if desired.
        [Parameter()]
        [string[]]$EnhancedKeyUsages,

        # Optional NotBefore date for the certificate request.
        [Parameter()]
        [DateTime]$NotBefore = ([datetime]::UtcNow),

        # Additional custom extensions (as an array of certificate extension objects).
        [Parameter()]
        [object[]]$CustomExtensions,

        # Optional friendly name for display in certificate stores.
        [Parameter()]
        [string]$FriendlyName,

        [Parameter()]
        [string]$OutputPath = $PWD
    )
    # Call the certificate request function to generate the CSR and key pair.
    $csrParams = @{
        DnsName           = $DnsName
        CommonName        = $CommonName
        Organization      = $Organization
        Locality          = $Locality
        State             = $State
        Country           = $Country
        KeyType           = $KeyType
        KeyLength         = $KeyLength
        EnhancedKeyUsages = $EnhancedKeyUsages
        NotBefore         = $NotBefore
        CustomExtensions  = $CustomExtensions
        FriendlyName      = $FriendlyName
    }

    $csrObject = New-PodeCertificateRequestInternal @csrParams


    $csrPath = "$OutputPath\$CommonName.csr"
    $keyPath = "$OutputPath\$CommonName.key"

    $csrObject.Request | Out-File -FilePath $csrPath -Encoding utf8NoBOM
    $privateKeyBytes = $csrObject.PrivateKey.ExportPkcs8PrivateKey()
    $privateKeyBase64 = [Convert]::ToBase64String($privateKeyBytes)
    "-----BEGIN PRIVATE KEY-----`n$privateKeyBase64`n-----END PRIVATE KEY-----" | Out-File -FilePath $keyPath -Encoding utf8NoBOM

    Write-PodeHost "CSR saved to: $csrPath"
    Write-PodeHost "Private Key saved to: $keyPath"

    return [PSCustomObject]@{
        PsTypeName     = 'PodeCertificateRequestResult'
        CsrPath        = $csrPath
        PrivateKeyPath = $keyPath
    }

}

<#
.SYNOPSIS
  Generates a self-signed X.509 certificate.

.DESCRIPTION
  This function creates a self-signed X.509 certificate using RSA or ECDSA key pairs.
  It supports specifying subject details, key usage, enhanced key usage (EKU),
  and custom extensions. The generated certificate is returned as an X509Certificate2 object.

  By default, the private key is exportable so the certificate can be saved and reused.
  If the `-Ephemeral` parameter is specified, the certificate's private key **will not be persisted**
  and will only exist in memory for the current session.

.PARAMETER DnsName
  One or more DNS names (or IP addresses) to be included in the Subject Alternative Name (SAN).

.PARAMETER Loopback
  If specified, automatically sets `DnsName` to include:
    - `127.0.0.1`, `::1`, `localhost`
    - The current machine's IP (if not local)
    - The Pode server's hostname and FQDN (if available)

.PARAMETER CommonName
  The Common Name (CN) for the certificate subject. Defaults to "SelfSigned".

.PARAMETER Organization
  The organization (O) name to be included in the certificate subject.

.PARAMETER Locality
  The locality (L) name to be included in the certificate subject.

.PARAMETER State
  The state (S) name to be included in the certificate subject.

.PARAMETER Country
  The country (C) code (ISO 3166-1 alpha-2). Defaults to 'XX'.

.PARAMETER KeyType
  The cryptographic key type for the certificate request. Supported values: 'RSA', 'ECDSA'. Defaults to 'RSA'.

.PARAMETER KeyLength
  The key length for RSA (2048, 3072, 4096) or ECDSA (256, 384, 521). Defaults to 2048.

.PARAMETER EnhancedKeyUsages
  A list of OID strings for Enhanced Key Usage (EKU), e.g., '1.3.6.1.5.5.7.3.1' for server authentication.

.PARAMETER CertificatePurpose
  The intended purpose of the certificate, which automatically sets the EKU.
  Supported values: 'ServerAuth', 'ClientAuth', 'CodeSigning', 'EmailSecurity', 'Custom'.
  Defaults to 'ServerAuth'.

.PARAMETER NotBefore
  The NotBefore date for the certificate validity start. Defaults to the current UTC time.

.PARAMETER CustomExtensions
  An array of additional custom certificate extensions.

.PARAMETER FriendlyName
  A friendly name for the certificate, used when storing it in a certificate store. Defaults to 'MyCertificate'.

.PARAMETER ValidityDays
  The number of days the certificate will remain valid. Defaults to 365 days.

.PARAMETER Ephemeral
  If specified, the certificate will be created with `EphemeralKeySet`, meaning the private key
  will **not be persisted** on disk or in the certificate store.

  This is useful for temporary certificates that should only exist in memory for the duration
  of the current session. Once the process exits, the private key will be lost.

.PARAMETER Password
 Specifies an optional password for protecting the exported PFX. If not provided, the PFX will be unprotected.

.PARAMETER Exportable
 If specified the certificate will be created with `Exportable`, meaning the certificate can be exported

.OUTPUTS
  [System.Security.Cryptography.X509Certificates.X509Certificate2]
  Returns the generated self-signed certificate as an X509Certificate2 object.

.EXAMPLE
  $cert = New-PodeSelfSignedCertificate -Loopback
  Creates a self-signed certificate for local addresses (`127.0.0.1`, `::1`, `localhost`, machine hostname).

.EXAMPLE
  $cert = New-PodeSelfSignedCertificate -DnsName "example.com" -KeyType "RSA" -KeyLength 2048
  Creates a self-signed RSA certificate for "example.com" with a 2048-bit key, valid for 365 days.

.EXAMPLE
  $cert = New-PodeSelfSignedCertificate -DnsName "internal.local" -Ephemeral
  Creates a self-signed certificate with a private key that exists **only in memory** for the current session.

.EXAMPLE
  $cert = New-PodeSelfSignedCertificate -DnsName "testserver.local" -KeyType "ECDSA" -KeyLength 384 -CertificatePurpose "ClientAuth" -ValidityDays 730
  Generates a self-signed ECDSA certificate for "testserver.local" with client authentication EKU, valid for 730 days.

.NOTES
  - The private key is embedded in the generated certificate.
  - By default, the certificate is **exportable** so it can be saved and reused.
  - If `-Ephemeral` is used, the private key will **only exist in memory** and cannot be exported or stored.
  - The `-Loopback` parameter is useful for local development, ensuring the certificate includes local identifiers.
#>
function New-PodeSelfSignedCertificate {
    [CmdletBinding(DefaultParameterSetName = 'CommonName')]
    param (
        # Required: one or more DNS names (or IP addresses)
        [Parameter(Mandatory = $false, ParameterSetName = 'DnsName')]
        [string[]]
        $DnsName,

        [Parameter(Mandatory = $false, ParameterSetName = 'DnsName')]
        [switch]
        $Loopback,

        # Subject parts
        [Parameter(Mandatory = $false, ParameterSetName = 'CommonName')]
        [string]
        $CommonName = 'SelfSigned',

        [Parameter()]
        [securestring]
        $Password = $null,

        [Parameter()]
        [string]$Organization,
        [Parameter()]
        [string]$Locality,
        [Parameter()]
        [string]$State,
        [Parameter()]
        [string]$Country = 'XX',

        # Key type and size
        [Parameter()]
        [ValidateSet('RSA', 'ECDSA')]
        [string]
        $KeyType = 'RSA',

        [Parameter()]
        [ValidateSet(2048, 3072, 4096, 256, 384, 521)]
        [int]
        $KeyLength = 2048,

        # Enhanced Key Usages (EKU) - e.g., '1.3.6.1.5.5.7.3.1' for server auth
        [Parameter()]
        [string[]]$EnhancedKeyUsages,

        [Parameter()]
        [ValidateSet('ServerAuth', 'ClientAuth', 'CodeSigning', 'EmailSecurity', 'Custom')]
        [string]
        $CertificatePurpose = 'ServerAuth',

        # Optional NotBefore date for certificate validity start
        [Parameter()]
        [DateTime]
        $NotBefore,

        # Additional custom extensions (as an array of extension objects)
        [Parameter()]
        [object[]]
        $CustomExtensions,

        # Friendly name for display in certificate stores
        [Parameter()]
        [string]
        $FriendlyName = 'MyCertificate',

        # Validity period (in days)
        [Parameter()]
        [int]
        $ValidityDays = 365,

        [Parameter()]
        [switch]
        $Ephemeral,

        [Parameter()]
        [switch]
        $Exportable

    )

    # Handle Loopback Parameter
    if ($Loopback) {
        if ($null -eq $DnsName) {
            $DnsName = @()
        }
        if ($DnsName -notcontains '127.0.0.1') {
            $DnsName += '127.0.0.1'
        }
        if ($DnsName -notcontains '::1') {
            $DnsName += '::1'
        }
        if ($DnsName -notcontains 'localhost') {
            $DnsName += 'localhost'
        }

        # Add machine-specific names if available
        if ((![string]::IsNullOrWhiteSpace($PodeContext.Server.ComputerName) ) -and ($DnsName -notcontains $PodeContext.Server.ComputerName)) {
            $DnsName += $PodeContext.Server.ComputerName
        }
        # Add machine-specific fqdn if available
        if ((![string]::IsNullOrWhiteSpace($PodeContext.Server.Fqdn)) -and
            ($PodeContext.Server.Fqdn -ne $PodeContext.Server.ComputerName) -and ($DnsName -notcontains $PodeContext.Server.Fqdn)) {
            $DnsName += $PodeContext.Server.Fqdn
        }
    }

    # Call the certificate request function to generate the CSR and key pair.
    $csrParams = @{
        DnsName            = $DnsName
        CommonName         = $CommonName
        Organization       = $Organization
        Locality           = $Locality
        State              = $State
        Country            = $Country
        KeyType            = $KeyType
        KeyLength          = $KeyLength
        CertificatePurpose = $CertificatePurpose
        EnhancedKeyUsages  = $EnhancedKeyUsages
        CustomExtensions   = $CustomExtensions
    }

    $csrObject = New-PodeCertificateRequestInternal @csrParams

    # Determine certificate validity dates.
    if ($null -eq $NotBefore) { $NotBefore = ([datetime]::UtcNow) }
    $startDate = $NotBefore
    $endDate = $NotBefore.AddDays($ValidityDays)

    try {
        # Create the self-signed certificate from the CSR.
        $cert = $csrObject.CertificateRequest.CreateSelfSigned(
            [System.DateTimeOffset]::new($startDate),
            [System.DateTimeOffset]::new($endDate)
        )

        # Set the friendly name if provided.
        if (![string]::IsNullOrEmpty($FriendlyName) -and (Test-PodeIsWindows)) {
            $cert.FriendlyName = $FriendlyName
        }

        # Export the certificate as a PFX (with a default password; adjust as needed).
        $pfxBytes = $cert.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Pfx , $Password)

        if ($Ephemeral -and !$IsMacOS) {
            $storageFlags = [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::EphemeralKeySet
        }
        else {
            $storageFlags = [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::DefaultKeySet
        }

        if ($Exportable) {
            $storageFlags = $storageFlags -bor [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable
        }
        $finalCert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new(
            $pfxBytes,
            $Password,
            $storageFlags
        )
        return $finalCert
    }
    catch {
        $_ | Write-PodeErrorLog
        throw
    }
}

<#
.SYNOPSIS
  Imports an X.509 certificate from a file (PFX, PEM, CER) or retrieves it from the Windows certificate store.

.DESCRIPTION
  This function imports an X.509 certificate using one of three methods:
    - From a certificate file (PFX, PEM, or CER).
    - From the Windows certificate store by thumbprint.
    - From the Windows certificate store by subject name.

  By default, the certificate is imported with an **ephemeral key**, meaning the private key
  exists **only for the current session** and is not persisted. If the `-Persistent` flag is
  specified, the private key will be stored in an exportable format.

.PARAMETER FilePath
  The path to the certificate file (.pfx, .pem, or .cer) to import.

.PARAMETER PrivateKeyPath
  The path to a separate private key file (for PEM format).
  Required if the certificate file does not contain the private key.

.PARAMETER CertificatePassword
  A secure string containing the password for decrypting a PFX certificate
  or an encrypted private key in PEM format.

.PARAMETER Persistent
  If specified, the certificate will be imported with an **exportable** private key,
  allowing it to be saved and reused across sessions.

  If not specified, the certificate will be imported **ephemerally**, meaning the
  private key will exist **only in memory** and will be lost when the process exits.

.PARAMETER CertificateThumbprint
  The thumbprint of a certificate stored in the Windows certificate store.

.PARAMETER CertificateName
  The subject name of a certificate stored in the Windows certificate store.

.PARAMETER CertificateStoreName
  The name of the Windows certificate store to search in when retrieving a certificate
  by thumbprint or subject name. Defaults to "My".

.PARAMETER CertificateStoreLocation
  The location of the Windows certificate store. Defaults to "CurrentUser".

.OUTPUTS
  [System.Security.Cryptography.X509Certificates.X509Certificate2]
  Returns the imported certificate as an X509Certificate2 object.

.EXAMPLE
  $cert = Import-PodeCertificate -FilePath "C:\Certs\mycert.pfx" -CertificatePassword (ConvertTo-SecureString -String "MyPass" -AsPlainText -Force)
  Imports a PFX certificate file with an ephemeral private key.

.EXAMPLE
  $cert = Import-PodeCertificate -FilePath "C:\Certs\mycert.pfx" -CertificatePassword (ConvertTo-SecureString -String "MyPass" -AsPlainText -Force) -Persistent
  Imports a PFX certificate file **with a persistent private key**, allowing it to be saved.

.EXAMPLE
  $cert = Import-PodeCertificate -FilePath "C:\Certs\mycert.cer"
  Imports a CER certificate file (public key only).

.EXAMPLE
  $cert = Import-PodeCertificate -CertificateThumbprint "D2C2F4F7A456B69D4F9E9F8C3D3D6E5A9C3EBA6F"
  Retrieves a certificate from the Windows certificate store using its thumbprint.

.EXAMPLE
  $cert = Import-PodeCertificate -CertificateName "MyAppCert" -CertificateStoreName "Root" -CertificateStoreLocation "LocalMachine"
  Retrieves a certificate by subject name from the LocalMachine\Root store.

.NOTES
  - The `-Persistent` flag should be used when you need to store the certificate for future use.
  - The default behavior (`EphemeralKeySet`) ensures the private key does not persist in the system.
  - When using a PEM certificate, ensure the private key is available if required.
  - Windows certificate store retrieval is only supported on Windows systems.
  - CER files contain only the public key and do not support private key decryption.
#>
function Import-PodeCertificate {
    param (
        # Certificate-based parameters for RSA/ECDSA
        [Parameter(Mandatory = $true, ParameterSetName = 'CertFile')]
        [string]
        $FilePath,

        [Parameter(Mandatory = $false, ParameterSetName = 'CertFile')]
        [string]
        $PrivateKeyPath = $null,

        [Parameter(Mandatory = $false, ParameterSetName = 'CertFile')]
        [SecureString]
        $CertificatePassword,

        [Parameter(Mandatory = $false, ParameterSetName = 'CertFile')]
        [Parameter()]
        [switch]$Persistent,

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
        $CertificateStoreLocation = 'CurrentUser'
    )

    switch ($PSCmdlet.ParameterSetName) {
        'CertFile' {
            # If using a file-based certificate, ensure it exists, then load it
            if (!(Test-Path -Path $FilePath -PathType Leaf)) {
                throw ($PodeLocale.pathNotExistExceptionMessage -f $FilePath)
            }
            if (![string]::IsNullOrEmpty($PrivateKeyPath) -and !(Test-Path -Path $PrivateKeyPath -PathType Leaf)) {
                throw ($PodeLocale.pathNotExistExceptionMessage -f $PrivateKeyPath)
            }
            $X509Certificate = Get-PodeCertificateByFile -Certificate $FilePath -SecurePassword $CertificatePassword -PrivateKeyPath $PrivateKeyPath -Persistent:$Persistent
            break
        }

        'certthumb' {
            # Retrieve a certificate from the local store by thumbprint
            $X509Certificate = Get-PodeCertificateByThumbprint -Thumbprint $CertificateThumbprint -StoreName $CertificateStoreName -StoreLocation $CertificateStoreLocation
        }

        'certname' {
            # Retrieve a certificate from the local store by name
            $X509Certificate = Get-PodeCertificateByName -Name $CertificateName -StoreName $CertificateStoreName -StoreLocation $CertificateStoreLocation
        }
    }

    # Validate the certificate's validity period before proceeding
    Test-PodeCertificate -Certificate $X509Certificate

    return $X509Certificate
}


<#
.SYNOPSIS
  Exports an X.509 certificate to a file (PFX, PEM, or CER) or installs it into the Windows certificate store.

.DESCRIPTION
  This function exports an X.509 certificate in various formats:
    - PFX (PKCS#12) with optional password protection.
    - PEM (Base64-encoded format), optionally including the private key.
    - CER (DER-encoded format).
  It also allows storing the certificate in the Windows certificate store.

  The function supports exporting private keys (if available) for PEM format, encrypting them if a password is provided.

.PARAMETER Certificate
  The X509Certificate2 object to export. This must be a valid certificate.

.PARAMETER FilePath
  The output file path (without an extension) where the certificate will be saved.
  Defaults to the current working directory with the certificate subject name.

.PARAMETER Format
  The format in which to export the certificate. Supported values: 'PFX', 'PEM', 'CER'.
  Defaults to 'PFX'.

.PARAMETER CertificatePassword
  A secure string containing the password for exporting the PFX format
  or encrypting the private key in PEM format.

.PARAMETER IncludePrivateKey
  When exporting in PEM format, this flag includes the private key in a separate `.key` file.

.PARAMETER CertificateStoreName
  The Windows certificate store name where the certificate should be installed.
  This parameter is required when using the 'WindowsStore' parameter set.

.PARAMETER CertificateStoreLocation
  The location of the Windows certificate store. Defaults to 'CurrentUser'.
  This parameter is required when using the 'WindowsStore' parameter set.

.OUTPUTS
  [string] or [hashtable]
  - If exporting to a file, returns the full file path(s) of the exported certificate.
  - If storing in Windows, returns `$true` if successful, `$false` otherwise.

.EXAMPLE
  $cert = Get-PodeCertificate -Path "mycert.pfx" -Password (ConvertTo-SecureString -String "MyPass" -AsPlainText -Force)
  Export-PodeCertificate -Certificate $cert -FilePath "C:\Certs\mycert" -Format "PEM" -IncludePrivateKey

  Exports the certificate as a PEM file with a separate private key file.

.EXAMPLE
  $cert = Get-PodeCertificate -Path "mycert.pfx" -Password (ConvertTo-SecureString -String "MyPass" -AsPlainText -Force)
  Export-PodeCertificate -Certificate $cert -CertificateStoreName "My" -CertificateStoreLocation "LocalMachine"

  Stores the certificate in the LocalMachine certificate store under "My".

.NOTES
  - This function integrates with Pode’s certificate handling utilities.
  - Windows store installation is only available on Windows.
  - PEM format supports exporting the private key separately, which can be encrypted with a password.
#>
function Export-PodeCertificate {
    [CmdletBinding(DefaultParameterSetName = 'File')]
    param (
        # The X509 Certificate object to export
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]
        $Certificate,

        [Parameter(Mandatory = $false, ParameterSetName = 'File')]
        [string]
        $FilePath = "$($PodeContext.Server.Root)\$($Certificate.Subject.Replace('CN=', '').Replace(' ', '_'))",

        [Parameter(Mandatory = $false, ParameterSetName = 'File')]
        [ValidateSet('PFX', 'PEM', 'CER')]
        [string]
        $Format = 'PFX',

        [Parameter(Mandatory = $false, ParameterSetName = 'File')]
        [SecureString]
        $CertificatePassword,

        [Parameter(Mandatory = $false, ParameterSetName = 'File')]
        [switch]$IncludePrivateKey,

        [Parameter(Mandatory = $true, ParameterSetName = 'WindowsStore')]
        [System.Security.Cryptography.X509Certificates.StoreName]
        $CertificateStoreName,

        [Parameter(Mandatory = $true, ParameterSetName = 'WindowsStore')]
        [System.Security.Cryptography.X509Certificates.StoreLocation]
        $CertificateStoreLocation = 'CurrentUser'
    )

    process {
        switch ($PSCmdlet.ParameterSetName) {
            'File' {
                switch ($Format) {
                    'PFX' {
                        $pfxBytes = if ($CertificatePassword) {
                            $Certificate.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Pfx, $CertificatePassword)
                        }
                        else {
                            $Certificate.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Pfx)
                        }
                        $filePathWithExt = "$FilePath.pfx"
                        [System.IO.File]::WriteAllBytes($filePathWithExt, $pfxBytes)
                    }
                    'CER' {
                        $cerBytes = $Certificate.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert)
                        $filePathWithExt = "$FilePath.cer"
                        [System.IO.File]::WriteAllBytes($filePathWithExt, $cerBytes)
                    }
                    'PEM' {
                        # Export the certificate in PEM format
                        $pemCert = "-----BEGIN CERTIFICATE-----`n"
                        $pemCert += [Convert]::ToBase64String($Certificate.RawData, 'InsertLineBreaks')
                        $pemCert += "`n-----END CERTIFICATE-----"
                        $certFilePath = "$FilePath.pem"
                        $pemCert | Out-File -FilePath $certFilePath -Encoding utf8NoBOM

                        Write-Output "Certificate exported successfully: $certFilePath"

                        # If requested, export the private key to a separate file
                        if ($IncludePrivateKey -and $Certificate.HasPrivateKey) {
                            # Convert SecureString to plain text for the helper function if a password was provided.
                            $plainPassword = $null
                            if ($CertificatePassword) {
                                $plainPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
                                    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($CertificatePassword)
                                )
                            }
                            $pemKey = Export-PodePrivateKeyPem -Key $Certificate.PrivateKey -Password $plainPassword
                            $keyFilePath = "$FilePath.key"
                            $pemKey | Out-File -FilePath $keyFilePath -Encoding utf8NoBOM

                            Write-PodeHost "Private key exported successfully: $keyFilePath"
                        }

                        # Return the certificate file path (and key file path if applicable)
                        $filePathWithExt = if ($IncludePrivateKey -and $Certificate.HasPrivateKey) {
                            @{ CertificateFile = $certFilePath; PrivateKeyFile = $keyFilePath }
                        }
                        else {
                            $certFilePath
                        }
                    }
                }

                if ($Format -ne 'PEM') {
                    Write-Output "Certificate exported successfully: $filePathWithExt"
                }
                return $filePathWithExt
            }

            'WindowsStore' {
                if (Test-PodeIsWindows) {
                    $store = [System.Security.Cryptography.X509Certificates.X509Store]::new($CertificateStoreName, $CertificateStoreLocation)
                    $store.Open('ReadWrite')
                    $store.Add($Certificate)
                    $store.Close()

                    Write-Output "Certificate successfully stored in: $CertificateStoreLocation\$CertificateStoreName"
                    return $true
                }
                return $false
            }
        }
    }
}

<#
.SYNOPSIS
  Retrieves the Enhanced Key Usage (EKU) purposes of an X.509 certificate.

.DESCRIPTION
  This internal function extracts the Enhanced Key Usage (EKU) extension (OID: 2.5.29.37)
  from an X.509 certificate and returns the recognized purposes.

  If the certificate has no EKU extension, an empty array is returned, indicating
  that the certificate has no usage restrictions.

.PARAMETER Certificate
  The X509Certificate2 object from which to retrieve the EKU purposes.

.OUTPUTS
  [object[]]
  Returns an array of recognized EKU purposes. Supported values:
    - 'ServerAuth'      (1.3.6.1.5.5.7.3.1)
    - 'ClientAuth'      (1.3.6.1.5.5.7.3.2)
    - 'CodeSigning'     (1.3.6.1.5.5.7.3.3)
    - 'EmailSecurity'   (1.3.6.1.5.5.7.3.4)

  If an unrecognized EKU OID is found, it is returned as `"Unknown (<OID>)"`.
  If no EKU extension is present, an empty array is returned.

.EXAMPLE
  $purposes = Get-PodeCertificatePurpose -Certificate $cert
  Retrieves the list of EKU purposes assigned to the given certificate.

#>
function Get-PodeCertificatePurpose {
    [CmdletBinding()]
    [OutputType([object[]])]
    param (
        [Parameter(Mandatory = $true)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate
    )

    # Define known EKU OIDs and their purposes
    $purposeOids = @{
        '1.3.6.1.5.5.7.3.1' = 'ServerAuth'
        '1.3.6.1.5.5.7.3.2' = 'ClientAuth'
        '1.3.6.1.5.5.7.3.3' = 'CodeSigning'
        '1.3.6.1.5.5.7.3.4' = 'EmailSecurity'
    }

    # Retrieve the EKU extension (OID: 2.5.29.37)
    $ekuExtension = $Certificate.Extensions | Where-Object { $_.Oid.Value -eq '2.5.29.37' }

    if ($ekuExtension -and $ekuExtension -is [System.Security.Cryptography.X509Certificates.X509EnhancedKeyUsageExtension]) {
        # Use the EnhancedKeyUsages property which returns an OidCollection
        $purposes = @()
        foreach ($oid in $ekuExtension.EnhancedKeyUsages) {
            if ($purposeOids.ContainsKey($oid.Value)) {
                $purposes += $purposeOids[$oid.Value]
            }
            else {
                $purposes += "Unknown ($($oid.Value))"
            }
        }
        return $purposes
    }

    # If no EKU is present, return an empty array (no restrictions)
    return @()
}

<#
.SYNOPSIS
  Validates whether an X.509 certificate is currently valid.

.DESCRIPTION
  This function checks if an X.509 certificate is valid based on its
  `NotBefore` and `NotAfter` properties. If the certificate is not yet valid or has expired,
  an exception is thrown. In addition, the function builds the certificate chain and
  (optionally) performs revocation checking using either online (OCSP/CRL) or offline (cached CRLs) mode.

  The function operates in **UTC time** to ensure consistency across environments.

  Additionally, revocation checking can be performed in either **online** (OCSP/CRL)
  or **offline** (cached CRL) mode.

  The function works for both CA-issued and self-signed certificates.
  For self-signed certificates, signature verification is skipped and the chain policy is adjusted to allow unknown certificate authorities.

.PARAMETER Certificate
  The X509Certificate2 object to validate.

.PARAMETER CheckRevocation
  A switch that, when provided, enables certificate revocation checking (online or offline).

.PARAMETER OfflineRevocation
  A switch that forces revocation checking to use only cached CRLs (offline mode).

.PARAMETER AllowWeakAlgorithms
  A switch that, when provided, allows certificates that use weak signature algorithms (e.g. md5RSA, sha1RSA, sha1ECDSA, RSA-1024).

.PARAMETER DenySelfSigned
  A switch that, when provided, rejects self-signed certificates.

.OUTPUTS
  [boolean] Returns $true if the certificate is valid. Otherwise, an exception is thrown.

.EXAMPLE
  Test-PodeCertificate -Certificate $cert
  Validates the certificate without performing revocation checks.

.EXAMPLE
  Test-PodeCertificate -Certificate $cert -CheckRevocation
  Validates the certificate and performs online revocation checking.

.EXAMPLE
  Test-PodeCertificate -Certificate $cert -CheckRevocation -OfflineRevocation
  Validates the certificate using only cached CRLs for revocation checking.

.EXAMPLE
  Test-PodeCertificate -Certificate $cert -DenySelfSigned
  Validates the certificate and rejects it if it is self-signed.

.NOTES
  - When using revocation checking on CA-issued certificates, ensure that the system can access the relevant OCSP/CRL endpoints.
  - For self-signed certificates, revocation checking is automatically disabled and the chain policy is modified to allow unknown certificate authorities.
  - If AllowWeakAlgorithms is not specified, the function will throw an exception for certificates using weak algorithms.
  - **Online vs Offline Revocation Checking**:
    - If `-CheckRevocation` is provided without `-OfflineRevocation`, the function checks revocation **online**
      using OCSP/CRL (requires an internet connection).
    - If `-CheckRevocation -OfflineRevocation` is specified, the function **only uses cached CRLs**, ensuring
      offline validation without contacting external servers.

  - **Using Cached CRLs for Offline Validation**:
    - The system must have previously downloaded CRLs stored locally.
    - To check installed CRLs:
      ```powershell
      Get-ChildItem -Path "C:\Windows\System32\CertSrv\CertEnroll" -Filter "*.crl"
      ```
    - To manually download a CRL:
      ```powershell
      Invoke-WebRequest -Uri "http://example.com/crl.pem" -OutFile "C:\Path\To\Store\crl.pem"
      ```
    - Ensure CRLs are **up-to-date** to prevent validation failures due to expired revocation lists.

  - **Error Handling**:
    - If the certificate is revoked, the function will throw an exception.
    - If `-OfflineRevocation` is used and no cached CRLs are available, revocation checking might fail.

  This is an internal Pode function and may be subject to change.
#>
function Test-PodeCertificate {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]
        $Certificate,

        [Parameter()]
        [switch]$CheckRevocation,

        [Parameter()]
        [switch]$OfflineRevocation,

        [Parameter()]
        [switch]$AllowWeakAlgorithms,

        [Parameter()]
        [switch]$DenySelfSigned
    )

    $currentDate = [System.DateTime]::UtcNow
    $notBefore = $Certificate.NotBefore.ToUniversalTime()
    $notAfter = $Certificate.NotAfter.ToUniversalTime()

    if ($currentDate -lt $notBefore) {
        throw ($PodeLocale.certificateNotValidYetExceptionMessage -f $Certificate.Subject, $notBefore)
    }
    if ($currentDate -gt $notAfter) {
        throw ($PodeLocale.certificateExpiredExceptionMessage -f $Certificate.Subject, $notAfter)
    }
    Write-Verbose "Certificate $($Certificate.Subject) is valid based on NotBefore/NotAfter properties."

    # Option: Deny self-signed certificates.
    if ($DenySelfSigned -and ($Certificate.Subject -eq $Certificate.Issuer)) {
        throw 'Self-signed certificates are not allowed.'
    }

    # For CA-issued certificates, check signature validity.
    # For self-signed certificates, skip this check.
    if ($Certificate.Subject -ne $Certificate.Issuer) {
        if (! $Certificate.Verify()) {
            throw ($PodeLocale.certificateSignatureInvalidExceptionMessage -f $Certificate.Subject)
        }
    }
    else {
        Write-Verbose 'Self-signed certificate detected: skipping signature verification.'
    }

    # Initialize the certificate chain.
    $chain = [System.Security.Cryptography.X509Certificates.X509Chain]::new()

    # For self-signed certificates, allow unknown certificate authority.
    if ($Certificate.Subject -eq $Certificate.Issuer) {
        $chain.ChainPolicy.VerificationFlags = [System.Security.Cryptography.X509Certificates.X509VerificationFlags]::AllowUnknownCertificateAuthority
        # Also disable revocation checking for self-signed certificates.
        $CheckRevocation = $false
        Write-Verbose 'Self-signed certificate detected: revocation check disabled.'
    }

    # Apply Revocation Policy.
    if ($CheckRevocation) {
        $chain.ChainPolicy.RevocationMode = if ($OfflineRevocation) {
            [System.Security.Cryptography.X509Certificates.X509RevocationMode]::Offline
        }
        else {
            [System.Security.Cryptography.X509Certificates.X509RevocationMode]::Online
        }
        Write-Verbose "Revocation check set to: $($chain.ChainPolicy.RevocationMode)"
    }
    else {
        $chain.ChainPolicy.RevocationMode = [System.Security.Cryptography.X509Certificates.X509RevocationMode]::NoCheck
    }

    # Build the certificate chain.
    $isValidChain = $chain.Build($Certificate)
    if (! $isValidChain) {
        foreach ($status in $chain.ChainStatus) {
            if ($status.Status -eq [System.Security.Cryptography.X509Certificates.X509ChainStatusFlags]::UntrustedRoot) {
                throw ($PodeLocale.certificateUntrustedRootExceptionMessage -f $Certificate.Subject)
            }
            if ($status.Status -eq [System.Security.Cryptography.X509Certificates.X509ChainStatusFlags]::Revoked) {
                throw ($PodeLocale.certificateRevokedExceptionMessage -f $Certificate.Subject, $status.StatusInformation)
            }
            if ($status.Status -eq [System.Security.Cryptography.X509Certificates.X509ChainStatusFlags]::NotTimeValid) {
                throw ($PodeLocale.certificateExpiredIntermediateExceptionMessage -f $Certificate.Subject)
            }
        }
        throw ($PodeLocale.certificateValidationFailedExceptionMessage -f $Certificate.Subject)
    }
    Write-Verbose 'Certificate chain validation successful.'

    # Check for weak algorithms unless allowed.
    if (! $AllowWeakAlgorithms) {
        $weakAlgorithms = @('md5RSA', 'sha1RSA', 'sha1ECDSA', 'RSA-1024')
        if ($Certificate.SignatureAlgorithm.FriendlyName -in $weakAlgorithms) {
            throw ($PodeLocale.certificateWeakAlgorithmExceptionMessage -f $Certificate.Subject, $Certificate.SignatureAlgorithm.FriendlyName)
        }
    }

    return $true
}

