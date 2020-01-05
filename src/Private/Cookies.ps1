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