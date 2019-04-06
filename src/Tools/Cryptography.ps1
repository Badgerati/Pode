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

function Get-PodeRandomBytes
{
    param (
        [Parameter()]
        [int]
        $Length = 16
    )

    return (stream ([System.Security.Cryptography.RandomNumberGenerator]::Create()) {
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

    $bytes = (Get-PodeRandomBytes -Length $Length)
    return [System.Convert]::ToBase64String($bytes)
}

function New-PodeGuid
{
    param (
        [Parameter()]
        [int]
        $Length = 16,

        [switch]
        $Secure
    )

    # generate a cryptographically secure guid
    if ($Secure) {
        $bytes = (Get-PodeRandomBytes -Length $Length)
        return ([guid]::new($bytes)).ToString()
    }

    # return a normal guid
    return ([guid]::NewGuid()).ToString()
}