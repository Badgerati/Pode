function Cookie
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet('add', 'check', 'exists', 'extend', 'get', 'remove')]
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
        [int]
        $Ttl = 0,

        [Parameter()]
        [Alias('o')]
        [hashtable]
        $Options = @{}
    )

    # run logic for the action
    switch ($Action.ToLowerInvariant())
    {
        # add/set a cookie against the response
        'add' {
            return (Set-PodeCookie -Name $Name -Value $Value -Secret $Secret -Ttl $Ttl -Options $Options)
        }

        # get a cookie from the request
        'get' {
            return (Get-PodeCookie -Name $Name -Secret $Secret)
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
            return (Test-PodeCookieIsSigned -Name $Name -Secret $Secret)
        }

        # extends a given cookies expiry
        'extend' {
            Update-PodeCookieExpiry -Name $Name -Ttl $Ttl
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

    $cookie = $WebEvent.Request.Cookies[$Name]
    return (!(Test-Empty $cookie) -and !(Test-Empty $cookie.Value))
}

function Test-PodeCookieIsSigned
{
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Name,

        [Parameter()]
        [string]
        $Secret
    )

    $cookie = $WebEvent.Request.Cookies[$Name]
    if ((Test-Empty $cookie) -or (Test-Empty $cookie.Value)) {
        return $false
    }

    $value = (Invoke-PodeCookieUnsign -Signature $cookie.Value -Secret $Secret)
    return (!(Test-Empty $value))
}

function Get-PodeCookie
{
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Name,

        [Parameter()]
        [string]
        $Secret
    )

    # get the from cookie
    $cookie = $WebEvent.Request.Cookies[$Name]
    if ((Test-Empty $cookie) -or (Test-Empty $cookie.Value)) {
        return $null
    }

    # if a secret was supplied, attempt to unsign the cookie
    if (!(Test-Empty $Secret)) {
        $value = (Invoke-PodeCookieUnsign -Signature $cookie.Value -Secret $Secret)
        if (!(Test-Empty $value)) {
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
        $Ttl = 0,

        [Parameter()]
        [datetime]
        $Expiry,

        [Parameter()]
        [hashtable]
        $Options = @{}
    )

    # sign the value if we have a secret
    if (!(Test-Empty $Secret)) {
        $Value = (Invoke-PodeCookieSign -Value $Value -Secret $Secret)
    }

    # create a new cookie
    $cookie = [System.Net.Cookie]::new($Name, $Value)
    $cookie.Secure = [bool]($Options.Secure)
    $cookie.Discard = [bool]($Options.Discard)
    $cookie.HttpOnly = [bool]($Options.HttpOnly)

    if (!(Test-Empty $Expiry)) {
        $cookie.Expires = $Expiry
    }
    elseif ($Ttl -gt 0) {
        $cookie.Expires = [datetime]::UtcNow.AddSeconds($Ttl)
    }

    # assign cookie to response
    $WebEvent.Response.AppendCookie($cookie) | Out-Null
    return $cookie
}

function Update-PodeCookieExpiry
{
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Name,

        [Parameter()]
        [int]
        $Ttl = 0,

        [Parameter()]
        [datetime]
        $Expiry
    )

    # extends the expiry on the cookie
    $cookie = $WebEvent.Response.Cookies[$Name]
    if (!(Test-Empty $Expiry)) {
        $cookie.Expires = $Expiry
    }
    elseif ($Ttl -gt 0) {
        $cookie.Expires = [datetime]::UtcNow.AddSeconds($Ttl)
    }

    $WebEvent.Response.AppendCookie($cookie) | Out-Null
    return $cookie
}

function Remove-PodeCookie
{
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Name
    )

    # remove the cookie from the response, and reset it to expire
    $cookie = $WebEvent.Response.Cookies[$Name]
    $cookie.Discard = $true
    $cookie.Expires = [DateTime]::UtcNow.AddDays(-2)
    $WebEvent.Response.AppendCookie($cookie) | Out-Null
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

    if (!$Signature.StartsWith('s:')) {
        return $null
    }

    $Signature = $Signature.Substring(2)
    $periodIndex = $Signature.LastIndexOf('.')
    $value = $Signature.Substring(0, $periodIndex)
    $sig = $Signature.Substring($periodIndex + 1)

    if ((Invoke-PodeHMACSHA256Hash -Value $value -Secret $Secret) -ne $sig) {
        return $null
    }

    return $value
}