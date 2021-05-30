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

    # check number of parts (should be 2 or 3)
    if (($parts.Length -le 1) -or ($parts.Length -gt 3)) {
        throw "Invalid JWT supplied"
    }

    # convert to header
    $header = ConvertFrom-PodeJwtBase64Value -Value $parts[0]
    if ([string]::IsNullOrWhiteSpace($header.alg)) {
        throw "Invalid JWT header algorithm supplied"
    }

    # convert to payload
    $payload = ConvertFrom-PodeJwtBase64Value -Value $parts[1]

    # check "none" signature, and return payload if no signature
    $isNoneAlg = ($header.alg -ieq 'none')

    if (($parts.Length -eq 2) -and !$isNoneAlg) {
        throw "No JWT signature supplied for $($header.alg)"
    }

    if (($parts.Length -eq 3) -and $isNoneAlg) {
        throw "Expected no JWT signature to be supplied"
    }

    if ($isNoneAlg) {
        return $payload
    }

    # otherwise, we have an alg for the signature, so we need to validate it
    $sig = "$($parts[0]).$($parts[1])"

    if (($null -eq $Secret) -or ($Secret.Length -eq 0)) {
        throw "No JWT secret supplied for validating signature"
    }

    switch ($header.alg.ToUpperInvariant()) {
        'HS256' {
            $sig = Invoke-PodeHMACSHA256Hash -Value $sig -SecretBytes $Secret
            $sig = ConvertTo-PodeJwtBase64Value -Value $sig
        }

        'HS384' {
            $sig = Invoke-PodeHMACSHA384Hash -Value $sig -SecretBytes $Secret
            $sig = ConvertTo-PodeJwtBase64Value -Value $sig
        }

        'HS512' {
            $sig = Invoke-PodeHMACSHA512Hash -Value $sig -SecretBytes $Secret
            $sig = ConvertTo-PodeJwtBase64Value -Value $sig
        }

        default {
            throw "The JWT algorithm is not currently supported: $($header.alg)"
        }
    }

    if ($sig -ne $parts[2]) {
        throw "Invalid JWT signature supplied"
    }

    # it's valid return the payload!
    return $payload
}

function ConvertTo-PodeJwtBase64Value
{
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Value
    )

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
    $Value = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($Value))

    # return json
    if (Test-PodeIsPSCore) {
        return ($Value | ConvertFrom-Json -AsHashtable)
    }
    else {
        return ($Value | ConvertFrom-Json)
    }
}