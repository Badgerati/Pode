function Invoke-PodeHMACSHA256Hash
{
    [CmdletBinding(DefaultParameterSetName='String')]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Value,

        [Parameter(Mandatory=$true, ParameterSetName='String')]
        [string]
        $Secret,

        [Parameter(Mandatory=$true, ParameterSetName='Bytes')]
        [byte[]]
        $SecretBytes
    )

    if (![string]::IsNullOrWhiteSpace($Secret)) {
        $SecretBytes = [System.Text.Encoding]::UTF8.GetBytes($Secret)
    }

    if ($SecretBytes.Length -eq 0) {
        throw "No secret supplied for HMAC256 hash"
    }

    $crypto = [System.Security.Cryptography.HMACSHA256]::new($SecretBytes)
    return [System.Convert]::ToBase64String($crypto.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Value)))
}

function Invoke-PodeHMACSHA384Hash
{
    [CmdletBinding(DefaultParameterSetName='String')]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Value,

        [Parameter(Mandatory=$true, ParameterSetName='String')]
        [string]
        $Secret,

        [Parameter(Mandatory=$true, ParameterSetName='Bytes')]
        [byte[]]
        $SecretBytes
    )

    if (![string]::IsNullOrWhiteSpace($Secret)) {
        $SecretBytes = [System.Text.Encoding]::UTF8.GetBytes($Secret)
    }

    if ($SecretBytes.Length -eq 0) {
        throw "No secret supplied for HMAC384 hash"
    }

    $crypto = [System.Security.Cryptography.HMACSHA384]::new($SecretBytes)
    return [System.Convert]::ToBase64String($crypto.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Value)))
}

function Invoke-PodeHMACSHA512Hash
{
    [CmdletBinding(DefaultParameterSetName='String')]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Value,

        [Parameter(Mandatory=$true, ParameterSetName='String')]
        [string]
        $Secret,

        [Parameter(Mandatory=$true, ParameterSetName='Bytes')]
        [byte[]]
        $SecretBytes
    )

    if (![string]::IsNullOrWhiteSpace($Secret)) {
        $SecretBytes = [System.Text.Encoding]::UTF8.GetBytes($Secret)
    }

    if ($SecretBytes.Length -eq 0) {
        throw "No secret supplied for HMAC512 hash"
    }

    $crypto = [System.Security.Cryptography.HMACSHA512]::new($SecretBytes)
    return [System.Convert]::ToBase64String($crypto.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Value)))
}

function Invoke-PodeSHA256Hash
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Value
    )

    $crypto = [System.Security.Cryptography.SHA256]::Create()
    return [System.Convert]::ToBase64String($crypto.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Value)))
}

function Invoke-PodeSHA1Hash
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Value
    )

    $crypto = [System.Security.Cryptography.SHA1]::Create()
    return [System.Convert]::ToBase64String($crypto.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Value)))
}

function ConvertTo-PodeBase64Auth
{
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Username,

        [Parameter(Mandatory=$true)]
        [string]
        $Password
    )

    return [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("$($Username):$($Password)"))
}

function Invoke-PodeMD5Hash
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Value
    )

    $crypto = [System.Security.Cryptography.MD5]::Create()
    return [System.BitConverter]::ToString($crypto.ComputeHash([System.Text.Encoding]::ASCII.GetBytes($Value))).Replace('-', '').ToLowerInvariant()
}

function Get-PodeRandomBytes
{
    param (
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

function New-PodeSalt
{
    param (
        [Parameter()]
        [int]
        $Length = 8
    )

    $bytes = [byte[]](Get-PodeRandomBytes -Length $Length)
    return [System.Convert]::ToBase64String($bytes)
}

function New-PodeGuid
{
    param (
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
        $bytes = [byte[]](Get-PodeRandomBytes -Length $Length)
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

function Invoke-PodeValueSign
{
    param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Value,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Secret
    )

    return "s:$($Value).$(Invoke-PodeHMACSHA256Hash -Value $Value -Secret $Secret)"
}

function Invoke-PodeValueUnsign
{
    param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Value,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Secret
    )

    # the signed value must start with "s:"
    if (!$Value.StartsWith('s:')) {
        return $null
    }

    # the signed value mised contain a dot - splitting value and signature
    $Value = $Value.Substring(2)
    $periodIndex = $Value.LastIndexOf('.')
    if ($periodIndex -eq -1) {
        return $null
    }

    # get the raw value and signature
    $raw = $Value.Substring(0, $periodIndex)
    $sig = $Value.Substring($periodIndex + 1)

    if ((Invoke-PodeHMACSHA256Hash -Value $raw -Secret $Secret) -ne $sig) {
        return $null
    }

    return $raw
}

function ConvertFrom-PodeJwt
{
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Token,

        [Parameter()]
        [byte[]]
        $Secret
    )

    # get the parts
    $parts = ($Token -isplit '\.')

    # check number of parts (should be 3)
    if ($parts.Length -ne 3) {
        throw "Invalid JWT supplied"
    }

    # convert to header
    $header = ConvertFrom-PodeJwtBase64Value -Value $parts[0]
    if ([string]::IsNullOrWhiteSpace($header.alg)) {
        throw "Invalid JWT header algorithm supplied"
    }

    # convert to payload
    $payload = ConvertFrom-PodeJwtBase64Value -Value $parts[1]

    # get signature
    $signature = $parts[2]

    # check "none" signature, and return payload if no signature
    $isNoneAlg = ($header.alg -ieq 'none')

    if ([string]::IsNullOrWhiteSpace($signature) -and !$isNoneAlg) {
        throw "No JWT signature supplied for $($header.alg)"
    }

    if (![string]::IsNullOrWhiteSpace($signature) -and $isNoneAlg) {
        throw "Expected no JWT signature to be supplied"
    }

    if ($isNoneAlg -and ($null -ne $Secret) -and ($Secret.Length -gt 0)) {
        throw "Expected a signed JWT, 'none' algorithm is not allowed"
    }

    if ($isNoneAlg) {
        return $payload
    }

    # otherwise, we have an alg for the signature, so we need to validate it
    $sig = "$($parts[0]).$($parts[1])"
    $sig = New-PodeJwtSignature -Algorithm $header.alg -Token $sig -SecretBytes $Secret

    if ($sig -ne $parts[2]) {
        throw "Invalid JWT signature supplied"
    }

    # it's valid return the payload!
    return $payload
}

function Test-PodeJwt
{
    param(
        [Parameter(Mandatory=$true)]
        [pscustomobject]
        $Payload
    )

    $now = [datetime]::Now
    $unixStart = [datetime]::new(1970, 1, 1)

    # validate expiry
    if (![string]::IsNullOrWhiteSpace($Payload.exp)) {
        if ($now -gt $unixStart.AddSeconds($Payload.exp)) {
            throw "The JWT has expired"
        }
    }

    # validate not-before
    if (![string]::IsNullOrWhiteSpace($Payload.nbf)) {
        if ($now -lt $unixStart.AddSeconds($Payload.nbf)) {
            throw "The JWT is not yet valid for use"
        }
    }
}

function New-PodeJwtSignature
{
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Algorithm,

        [Parameter(Mandatory=$true)]
        [string]
        $Token,

        [Parameter()]
        [byte[]]
        $SecretBytes
    )

    if (($Algorithm -ine 'none') -and (($null -eq $SecretBytes) -or ($SecretBytes.Length -eq 0))) {
        throw "No Secret supplied for JWT signature"
    }

    if (($Algorithm -ieq 'none') -and (($null -ne $secretBytes) -and ($SecretBytes.Length -gt 0))) {
        throw "Expected no secret to be supplied for no signature"
    }

    $sig = $null

    switch ($Algorithm.ToUpperInvariant()) {
        'HS256' {
            $sig = Invoke-PodeHMACSHA256Hash -Value $Token -SecretBytes $SecretBytes
            $sig = ConvertTo-PodeJwtBase64Value -Value $sig -NoConvert
        }

        'HS384' {
            $sig = Invoke-PodeHMACSHA384Hash -Value $Token -SecretBytes $SecretBytes
            $sig = ConvertTo-PodeJwtBase64Value -Value $sig -NoConvert
        }

        'HS512' {
            $sig = Invoke-PodeHMACSHA512Hash -Value $Token -SecretBytes $SecretBytes
            $sig = ConvertTo-PodeJwtBase64Value -Value $sig -NoConvert
        }

        'NONE' {
            $sig = [string]::Empty
        }

        default {
            throw "The JWT algorithm is not currently supported: $($Algorithm)"
        }
    }

    return $sig
}

function ConvertTo-PodeJwtBase64Value
{
    param(
        [Parameter(Mandatory=$true)]
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

function ConvertFrom-PodeJwtBase64Value
{
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Value
    )

    # map chars
    $Value = ($Value -ireplace '-', '+')
    $Value = ($Value -ireplace '_', '/')

    # add padding
    switch ($Value.Length % 4) {
        1 { $Value = $Value.Substring(0, $Value.Length - 1) }
        2 { $Value += '==' }
        3 { $Value += '=' }
    }

    # convert base64 to string
    try {
        $Value = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($Value))
    }
    catch {
        throw "Invalid Base64 encoded value found in JWT"
    }

    # return json
    try {
        return ($Value | ConvertFrom-Json)
    }
    catch {
        throw "Invalid JSON value found in JWT"
    }
}