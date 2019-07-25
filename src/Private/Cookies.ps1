function Invoke-PodeCookieSign
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

    return "s:$($Value).$(Invoke-PodeHMACSHA256Hash -Value $Value -Secret $Secret)"
}

function Invoke-PodeCookieUnsign
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

    # the signed cookie value must start with "s:"
    if (!$Signature.StartsWith('s:')) {
        return $null
    }

    $Signature = $Signature.Substring(2)
    $periodIndex = $Signature.LastIndexOf('.')
    if ($periodIndex -eq -1) {
        return $null
    }

    $value = $Signature.Substring(0, $periodIndex)
    $sig = $Signature.Substring($periodIndex + 1)

    if ((Invoke-PodeHMACSHA256Hash -Value $value -Secret $Secret) -ne $sig) {
        return $null
    }

    return $value
}

function ConvertTo-PodeCookie
{
    param (
        [Parameter()]
        [System.Net.Cookie]
        $Cookie
    )

    if ($null -eq $Cookie) {
        return @{}
    }

    return @{
        Name = $Cookie.Name
        Value = $Cookie.Value
        Expires = $Cookie.Expires
        Expired = $Cookie.Expired
        Discard = $Cookie.Discard
        HttpOnly = $Cookie.HttpOnly
        Secure = $Cookie.Secure
        Path = $Cookie.Path
        TimeStamp = $Cookie.TimeStamp
        Signed = $Cookie.Value.StartsWith('s:')
    }
}

function ConvertTo-PodeCookieString
{
    param (
        [Parameter(Mandatory=$true)]
        $Cookie
    )

    $str = "$($Cookie.Name)=$($Cookie.Value)"

    if ($Cookie.Discard) {
        $str += '; Discard'
    }

    if ($Cookie.HttpOnly) {
        $str += '; HttpOnly'
    }

    if ($Cookie.Secure) {
        $str += '; Secure'
    }

    if (![string]::IsNullOrWhiteSpace($Cookie.Domain)) {
        $str += "; Domain=$($Cookie.Domain)"
    }

    if (![string]::IsNullOrWhiteSpace($Cookie.Path)) {
        $str += "; Path=$($Cookie.Path)"
    }

    if ($null -ne $Cookie.Expires -and $Cookie.Expires -ne [datetime]::MinValue) {
        $secs = ($Cookie.Expires.ToLocalTime() - [datetime]::Now).TotalSeconds
        if ($secs -lt 0) {
            $secs = 0
        }

        $str += "; Max-Age=$($secs)"
    }

    if ($str -eq '=') {
        return $null
    }

    return $str
}