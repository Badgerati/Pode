function Invoke-SHA256Encrypt
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

function Invoke-CookieSign
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

    return "$($Value).$(Invoke-SHA256Encrypt -Value $Value -Secret $Secret)"
}

function Invoke-CookieUnsign
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Signature,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Secret
    )

    $periodIndex = $Signature.LastIndexOf('.')
    $value = $Signature.Substring(0, $periodIndex)
    $sig = $Signature.Substring($periodIndex + 1)

    if ((Invoke-SHA256Encrypt -Value $value -Secret $Secret) -ne $sig) {
        return $null
    }

    return $value
}