function ConvertTo-PodeCookie
{
    param(
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
    param(
        [Parameter(Mandatory=$true)]
        $Cookie
    )

    try {
        $builder = [System.Text.StringBuilder]::new()
        $null = $builder.Append($Cookie.Name)
        $null = $builder.Append('=')
        $null = $builder.Append($Cookie.Value)

        if ($Cookie.Discard) {
            $null = $builder.Append('; Discard')
        }

        if ($Cookie.HttpOnly) {
            $null = $builder.Append('; HttpOnly')
        }

        if ($Cookie.Secure) {
            $null = $builder.Append('; Secure')
        }

        if (![string]::IsNullOrEmpty($Cookie.Domain)) {
            $null = $builder.Append('; Domain=')
            $null = $builder.Append($Cookie.Domain)
        }

        if (![string]::IsNullOrEmpty($Cookie.Path)) {
            $null = $builder.Append('; Path=')
            $null = $builder.Append($Cookie.Path)
        }

        if (($null -ne $Cookie.Expires) -and ($Cookie.Expires.Ticks -ne 0)) {
            $secs = ($Cookie.Expires.Subtract([datetime]::UtcNow)).TotalSeconds
            if ($secs -lt 0) {
                $secs = 0
            }

            $null = $builder.Append('; Max-Age=')
            $null = $builder.Append($secs)
        }

        if ($builder.Length -le 1) {
            return $null
        }

        return $builder.ToString()
    }
    finally {
        $builder = $null
    }
}