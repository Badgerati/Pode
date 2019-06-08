function Cookie
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet('Check', 'Exists', 'Extend', 'Get', 'Remove', 'Secrets', 'Set')]
        [Alias('a')]
        [string]
        $Action,

        [Parameter(Mandatory=$true)]
        [Alias('n')]
        [string]
        $Name,

        [Parameter()]
        [Alias('v')]
        [string]
        $Value,

        [Parameter()]
        [Alias('s')]
        [string]
        $Secret,

        [Parameter()]
        [Alias('ttl')]
        [int]
        $Duration = 0,

        [switch]
        [Alias('http')]
        $HttpOnly,

        [switch]
        [Alias('d')]
        $Discard,

        [switch]
        [Alias('ssl')]
        $Secure,

        [switch]
        [Alias('gs')]
        $GlobalSecret
    )

    # run logic for the action
    switch ($Action.ToLowerInvariant())
    {
        # add/set a cookie against the response
        'set' {
            return (Set-PodeCookie -Name $Name -Value $Value -Secret $Secret -Duration $Duration `
                -HttpOnly:$HttpOnly -Discard:$Discard -Secure:$Secure -GlobalSecret:$GlobalSecret)
        }

        # get a cookie from the request
        'get' {
            return (Get-PodeCookie -Name $Name -Secret $Secret -GlobalSecret:$GlobalSecret)
        }

        # checks whether a given cookie exists on the request
        'exists' {
            return (Test-PodeCookieExists -Name $Name)
        }

        # removes a given cookie from the request/response
        'remove' {
            Remove-PodeCookie -Name $Name
        }

        # verifies whether a given cookie is signed
        'check' {
            return (Test-PodeCookieIsSigned -Name $Name -Secret $Secret -GlobalSecret:$GlobalSecret)
        }

        # extends a given cookies expiry (adding the cookie to the response)
        'extend' {
            return (Update-PodeCookieExpiry -Name $Name -Duration $Duration)
        }

        # set or get cookie secrets
        'secrets' {
            if ([string]::IsNullOrWhiteSpace($Value)) {
                return ($PodeContext.Server.Cookies.Secrets[$Name])
            }
            else {
                $PodeContext.Server.Cookies.Secrets[$Name] = $Value
            }
        }
    }
}

function Test-PodeCookieExists
{
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Name
    )

    $cookie = $WebEvent.Cookies[$Name]
    return (($null -ne $cookie) -and ![string]::IsNullOrWhiteSpace($cookie.Value))
}

function Test-PodeCookieIsSigned
{
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Name,

        [Parameter()]
        [string]
        $Secret,

        [switch]
        $GlobalSecret
    )

    # if the global secret flag is set, overwrite the passed secret
    if ($GlobalSecret) {
        $Secret = (Get-PodeCookieGlobalSecret)
    }

    $cookie = $WebEvent.Cookies[$Name]
    if (($null -eq $cookie) -or [string]::IsNullOrWhiteSpace($cookie.Value)) {
        return $false
    }

    $value = (Invoke-PodeCookieUnsign -Signature $cookie.Value -Secret $Secret)
    return (![string]::IsNullOrWhiteSpace($value))
}

function Get-PodeCookie
{
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Name,

        [Parameter()]
        [string]
        $Secret,

        [switch]
        $Raw,

        [switch]
        $GlobalSecret
    )

    # if the global secret flag is set, overwrite the passed secret
    if ($GlobalSecret) {
        $Secret = (Get-PodeCookieGlobalSecret)
    }

    # get the cookie from the request
    $cookie = $WebEvent.Cookies[$Name]
    if (!$Raw) {
        $cookie = (ConvertTo-PodeCookie -Cookie $cookie)
    }

    if (($null -eq $cookie) -or [string]::IsNullOrWhiteSpace($cookie.Value)) {
        return $null
    }

    # if a secret was supplied, attempt to unsign the cookie
    if (![string]::IsNullOrWhiteSpace($Secret)) {
        $value = (Invoke-PodeCookieUnsign -Signature $cookie.Value -Secret $Secret)
        if (![string]::IsNullOrWhiteSpace($value)) {
            $cookie.Value = $value
        }
    }

    return $cookie
}

function Set-PodeCookie
{
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Name,

        [Parameter()]
        [string]
        $Value,

        [Parameter()]
        [string]
        $Secret,

        [Parameter()]
        [int]
        $Duration = 0,

        [Parameter()]
        [datetime]
        $Expiry,

        [switch]
        $HttpOnly,

        [switch]
        $Discard,

        [switch]
        $Secure,

        [switch]
        $GlobalSecret
    )

    # if the global secret flag is set, overwrite the passed secret
    if ($GlobalSecret) {
        $Secret = (Get-PodeCookieGlobalSecret)
    }

    # sign the value if we have a secret
    if (![string]::IsNullOrWhiteSpace($Secret)) {
        $Value = (Invoke-PodeCookieSign -Value $Value -Secret $Secret)
    }

    # create a new cookie
    $cookie = [System.Net.Cookie]::new($Name, $Value)
    $cookie.Secure = $Secure
    $cookie.Discard = $Discard
    $cookie.HttpOnly = $HttpOnly

    if (!(Test-Empty $Expiry)) {
        $cookie.Expires = $Expiry
    }
    elseif ($Duration -gt 0) {
        $cookie.Expires = [datetime]::UtcNow.AddSeconds($Duration)
    }

    # sets the cookie on the the response
    $WebEvent.PendingCookies[$cookie.Name] = $cookie
    Add-PodeHeader -Name 'Set-Cookie' -Value (ConvertTo-PodeCookieString -Cookie $cookie)
    return (ConvertTo-PodeCookie -Cookie $cookie)
}

function Get-PodeCookieGlobalSecret
{
    return $PodeContext.Server.Cookies.Secrets['global']
}

function Update-PodeCookieExpiry
{
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Name,

        [Parameter()]
        [int]
        $Duration = 0,

        [Parameter()]
        [datetime]
        $Expiry
    )

    # get the cookie from the response - if it's not found, get it from the request
    $cookie = $WebEvent.PendingCookies[$Name]
    if ($null -eq $cookie) {
        $cookie = Get-PodeCookie -Name $Name -Raw
    }

    # extends the expiry on the cookie
    if (!(Test-Empty $Expiry)) {
        $cookie.Expires = $Expiry
    }
    elseif ($Duration -gt 0) {
        $cookie.Expires = [datetime]::UtcNow.AddSeconds($Duration)
    }

    # sets the cookie on the the response
    $WebEvent.PendingCookies[$cookie.Name] = $cookie
    Add-PodeHeader -Name 'Set-Cookie' -Value (ConvertTo-PodeCookieString -Cookie $cookie)
    return (ConvertTo-PodeCookie -Cookie $cookie)
}

function Remove-PodeCookie
{
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Name
    )

    # get the cookie from the response - if it's not found, get it from the request
    $cookie = $WebEvent.PendingCookies[$Name]
    if ($null -eq $cookie) {
        $cookie = Get-PodeCookie -Name $Name -Raw
    }

    # remove the cookie from the response, and reset it to expire
    if ($null -ne $cookie) {
        $cookie.Discard = $true
        $cookie.Expires = [DateTime]::UtcNow.AddDays(-2)
        $WebEvent.PendingCookies[$cookie.Name] = $cookie
        Add-PodeHeader -Name 'Set-Cookie' -Value (ConvertTo-PodeCookieString -Cookie $cookie)
    }
}

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
        'Name' = $Cookie.Name;
        'Value' = $Cookie.Value;
        'Expires' = $Cookie.Expires;
        'Expired' = $Cookie.Expired;
        'Discard' = $Cookie.Discard;
        'HttpOnly' = $Cookie.HttpOnly;
        'Secure' = $Cookie.Secure;
        'Path' = $Cookie.Path;
        'TimeStamp' = $Cookie.TimeStamp;
        'Signed' = $Cookie.Value.StartsWith('s:');
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