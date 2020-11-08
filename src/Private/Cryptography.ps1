function Invoke-PodeHMACSHA256Hash
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Value,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Secret
    )

    $crypto = [System.Security.Cryptography.HMACSHA256]::new([System.Text.Encoding]::UTF8.GetBytes($Secret))
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