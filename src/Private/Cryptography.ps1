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
    Write-Host "HMAC-SHA256 hash: $hash"

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
        throw 'No secret supplied for HMAC256 hash'
    }

    # Compute HMAC-SHA384 hash
    $crypto = [System.Security.Cryptography.HMACSHA256]::new($SecretBytes)
    return [System.Convert]::ToBase64String($crypto.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Value)))
}

<#
.SYNOPSIS
    Computes a private HMAC-SHA384 hash for a given value using a secret key.

.DESCRIPTION
    This function calculates a private HMAC-SHA384 hash for the specified value using either a secret provided as a string or as a byte array. It supports two parameter sets:
    1. String: The secret is provided as a string.
    2. Bytes: The secret is provided as a byte array.

.PARAMETER Value
    The value for which the private HMAC-SHA384 hash needs to be computed.

.PARAMETER Secret
    The secret key as a string. If this parameter is provided, it will be converted to a byte array.

.PARAMETER SecretBytes
    The secret key as a byte array. If this parameter is provided, it will be used directly.

.OUTPUTS
    Returns the computed private HMAC-SHA384 hash as a base64-encoded string.

.EXAMPLE
    $value = "MySecretValue"
    $secret = "MySecretKey"
    $hash = Invoke-PodeHMACSHA384Hash -Value $value -Secret $secret
    Write-Host "Private HMAC-SHA384 hash: $hash"

    This example computes the private HMAC-SHA384 hash for the value "MySecretValue" using the secret key "MySecretKey".

.NOTES
    - This function is intended for internal use.
#>
function Invoke-PodeHMACSHA384Hash {
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
        throw 'No secret supplied for HMAC384 hash'
    }

    # Compute private HMAC-SHA384 hash
    $crypto = [System.Security.Cryptography.HMACSHA384]::new($SecretBytes)
    return [System.Convert]::ToBase64String($crypto.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Value)))
}

<#
.SYNOPSIS
    Computes a private HMAC-SHA512 hash for a given value using a secret key.

.DESCRIPTION
    This function calculates a private HMAC-SHA512 hash for the specified value using either a secret provided as a string or as a byte array. It supports two parameter sets:
    1. String: The secret is provided as a string.
    2. Bytes: The secret is provided as a byte array.

.PARAMETER Value
    The value for which the private HMAC-SHA512 hash needs to be computed.

.PARAMETER Secret
    The secret key as a string. If this parameter is provided, it will be converted to a byte array.

.PARAMETER SecretBytes
    The secret key as a byte array. If this parameter is provided, it will be used directly.

.OUTPUTS
    Returns the computed private HMAC-SHA512 hash as a base64-encoded string.

.EXAMPLE
    $value = "MySecretValue"
    $secret = "MySecretKey"
    $hash = Invoke-PodeHMACSHA512Hash -Value $value -Secret $secret
    Write-Host "Private HMAC-SHA512 hash: $hash"

    This example computes the private HMAC-SHA512 hash for the value "MySecretValue" using the secret key "MySecretKey".

.NOTES
    - This function is intended for internal use.
#>
function Invoke-PodeHMACSHA512Hash {
    [CmdletBinding(DefaultParameterSetName = 'String')]
    [OutputType([string])]
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
        throw 'No secret supplied for HMAC512 hash'
    }

    # Compute private HMAC-SHA512 hash
    $crypto = [System.Security.Cryptography.HMACSHA512]::new($SecretBytes)
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

    if ($Strict) {
        $Secret = ConvertTo-PodeStrictSecret -Secret $Secret
    }

    return "s:$($Value).$(Invoke-PodeHMACSHA256Hash -Value $Value -Secret $Secret)"
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

    if ([string]::IsNullOrEmpty($Value)) {
        return $false
    }

    $result = Invoke-PodeValueUnsign -Value $Value -Secret $Secret -Strict:$Strict
    return ![string]::IsNullOrEmpty($result)
}

function ConvertTo-PodeStrictSecret {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Secret
    )

    return "$($Secret);$($WebEvent.Request.UserAgent);$($WebEvent.Request.RemoteEndPoint.Address.IPAddressToString)"
}

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
        $SecretBytes
    )

    if (($Algorithm -ine 'none') -and (($null -eq $SecretBytes) -or ($SecretBytes.Length -eq 0))) {
        throw 'No Secret supplied for JWT signature'
    }

    if (($Algorithm -ieq 'none') -and (($null -ne $secretBytes) -and ($SecretBytes.Length -gt 0))) {
        throw 'Expected no secret to be supplied for no signature'
    }

    $sig = $null

    switch ($Algorithm.ToUpperInvariant()) {
        'HS256' {
            $sig = Invoke-PodeHMACSHA256Hash -Value $Token -SecretBytes $SecretBytes
            $sig = ConvertTo-PodeBase64UrlValue -Value $sig -NoConvert
        }

        'HS384' {
            $sig = Invoke-PodeHMACSHA384Hash -Value $Token -SecretBytes $SecretBytes
            $sig = ConvertTo-PodeBase64UrlValue -Value $sig -NoConvert
        }

        'HS512' {
            $sig = Invoke-PodeHMACSHA512Hash -Value $Token -SecretBytes $SecretBytes
            $sig = ConvertTo-PodeBase64UrlValue -Value $sig -NoConvert
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
    [OutputType([string])]
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
        throw 'Invalid Base64 encoded value found in JWT'
    }

    # return json
    try {
        return ($Value | ConvertFrom-Json)
    }
    catch {
        throw 'Invalid JSON value found in JWT'
    }
}