<#
.SYNOPSIS
Sets a cookie on the Response.

.DESCRIPTION
Sets a cookie on the Response using the "Set-Cookie" header. You can also set cookies to expire, or being signed.

.PARAMETER Name
The name of the cookie.

.PARAMETER Value
The value of the cookie.

.PARAMETER Secret
If supplied, the secret with which to sign the cookie.

.PARAMETER Duration
The duration, in seconds, before the cookie is expired.

.PARAMETER ExpiryDate
An explicit expiry date for the cookie.

.PARAMETER HttpOnly
Only allow the cookie to be used in browsers.

.PARAMETER Discard
Inform browsers to remove the cookie.

.PARAMETER Secure
Only allow the cookie on secure (HTTPS) connections.

.EXAMPLE
Set-PodeCookie -Name 'Views' -Value 2

.EXAMPLE
Set-PodeCookie -Name 'Views' -Value 2 -Secret 'hunter2'

.EXAMPLE
Set-PodeCookie -Name 'Views' -Value 2 -Duration 3600
#>
function Set-PodeCookie {
    [CmdletBinding(DefaultParameterSetName = 'Duration')]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [string]
        $Value,

        [Parameter()]
        [string]
        $Secret,

        [Parameter(ParameterSetName = 'Duration')]
        [int]
        $Duration = 0,

        [Parameter(ParameterSetName = 'ExpiryDate')]
        [datetime]
        $ExpiryDate,

        [switch]
        $HttpOnly,

        [switch]
        $Discard,

        [switch]
        $Secure,

        [switch]
        $Strict
    )

    # sign the value if we have a secret
    if (![string]::IsNullOrWhiteSpace($Secret)) {
        $Value = (Invoke-PodeValueSign -Value $Value -Secret $Secret -Strict:$Strict)
    }

    # create a new cookie
    $cookie = [System.Net.Cookie]::new($Name, $Value)
    $cookie.Secure = $Secure
    $cookie.Discard = $Discard
    $cookie.HttpOnly = $HttpOnly
    $cookie.Path = '/'

    if ($null -ne $ExpiryDate) {
        if ($ExpiryDate.Kind -eq [System.DateTimeKind]::Local) {
            $ExpiryDate = $ExpiryDate.ToUniversalTime()
        }

        $cookie.Expires = $ExpiryDate
    }
    elseif ($Duration -gt 0) {
        $cookie.Expires = [datetime]::UtcNow.AddSeconds($Duration)
    }

    # sets the cookie on the the response
    $WebEvent.PendingCookies[$cookie.Name] = $cookie
    Add-PodeHeader -Name 'Set-Cookie' -Value (ConvertTo-PodeCookieString -Cookie $cookie)
    return (ConvertTo-PodeCookie -Cookie $cookie)
}

<#
.SYNOPSIS
Retrieves a cookie from the Request.

.DESCRIPTION
Retrieves a cookie from the Request, with the option to supply a secret to unsign the cookie's value.

.PARAMETER Name
The name of the cookie to retrieve.

.PARAMETER Secret
The secret used to unsign the cookie's value.

.PARAMETER Raw
If supplied, the cookie returned will be the raw .NET Cookie object for manipulation.

.EXAMPLE
Get-PodeCookie -Name 'Views'

.EXAMPLE
Get-PodeCookie -Name 'Views' -Secret 'hunter2'
#>
function Get-PodeCookie {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [string]
        $Secret,

        [switch]
        $Strict,

        [switch]
        $Raw
    )

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
        $value = (Invoke-PodeValueUnsign -Value $cookie.Value -Secret $Secret -Strict:$Strict)
        if (![string]::IsNullOrWhiteSpace($value)) {
            $cookie.Value = $value
        }
    }

    return $cookie
}

<#
.SYNOPSIS
Retrieves the value of a cookie from the Request.

.DESCRIPTION
Retrieves the value of a cookie from the Request, with the option to supply a secret to unsign the cookie's value.

.PARAMETER Name
The name of the cookie to retrieve.

.PARAMETER Secret
The secret used to unsign the cookie's value.

.EXAMPLE
Get-PodeCookieValue -Name 'Views'

.EXAMPLE
Get-PodeCookieValue -Name 'Views' -Secret 'hunter2'
#>
function Get-PodeCookieValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [string]
        $Secret,

        [switch]
        $Strict
    )

    $cookie = Get-PodeCookie -Name $Name -Secret $Secret -Strict:$Strict
    if ($null -eq $cookie) {
        return $null
    }

    return $cookie.Value
}

<#
.SYNOPSIS
Tests if a cookie exists on the Request.

.DESCRIPTION
Tests if a cookie exists on the Request.

.PARAMETER Name
The name of the cookie to test for on the Request.

.EXAMPLE
Test-PodeCookie -Name 'Views'
#>
function Test-PodeCookie {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    $cookie = $WebEvent.Cookies[$Name]
    return (($null -ne $cookie) -and ![string]::IsNullOrWhiteSpace($cookie.Value))
}

<#
.SYNOPSIS
Removes a cookie from the Response.

.DESCRIPTION
Removes a cookie from the Response, this is done by immediately expiring the cookie and flagging it for discard.

.PARAMETER Name
The name of the cookie to be removed.

.EXAMPLE
Remove-PodeCookie -Name 'Views'
#>
function Remove-PodeCookie {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
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
        $cookie.Path = '/'
        $WebEvent.PendingCookies[$cookie.Name] = $cookie
        Add-PodeHeader -Name 'Set-Cookie' -Value (ConvertTo-PodeCookieString -Cookie $cookie)
    }
}

<#
.SYNOPSIS
Tests if a cookie on the Request is validly signed.

.DESCRIPTION
Tests if a cookie on the Request is validly signed, by attempting to unsign it using some secret.

.PARAMETER Name
The name of the cookie to test.

.PARAMETER Secret
A secret to use for attempting to unsign the cookie's value.

.EXAMPLE
Test-PodeCookieSigned -Name 'Views' -Secret 'hunter2'
#>
function Test-PodeCookieSigned {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [string]
        $Secret,

        [switch]
        $Strict
    )

    $cookie = $WebEvent.Cookies[$Name]
    if ($null -eq $cookie) {
        return $false
    }

    return Test-PodeValueSigned -Value $cookie.Value -Secret $Secret -Strict:$Strict
}

<#
.SYNOPSIS
Updates the exipry date of a cookie on the Response.

.DESCRIPTION
Updates the exipry date of a cookie on the Response. This can either be done by suppling a duration, or and explicit expiry date.

.PARAMETER Name
The name of the cookie to extend.

.PARAMETER Duration
The duration, in seconds, to extend the cookie's expiry.

.PARAMETER ExpiryDate
An explicit expiry date for the cookie.

.EXAMPLE
Update-PodeCookieExpiry -Name  'Views' -Duration 1800

.EXAMPLE
Update-PodeCookieExpiry -Name  'Views' -ExpiryDate ([datetime]::UtcNow.AddSeconds(1800))
#>
function Update-PodeCookieExpiry {
    [CmdletBinding(DefaultParameterSetName = 'Duration')]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(ParameterSetName = 'Duration')]
        [int]
        $Duration = 0,

        [Parameter(ParameterSetName = 'ExpiryDate')]
        [datetime]
        $ExpiryDate
    )

    # get the cookie from the response - if it's not found, get it from the request
    $cookie = $WebEvent.PendingCookies[$Name]
    if ($null -eq $cookie) {
        $cookie = Get-PodeCookie -Name $Name -Raw
    }

    # extends the expiry on the cookie
    if ($null -ne $ExpiryDate) {
        if ($ExpiryDate.Kind -eq [System.DateTimeKind]::Local) {
            $ExpiryDate = $ExpiryDate.ToUniversalTime()
        }

        $cookie.Expires = $ExpiryDate
    }
    elseif ($Duration -gt 0) {
        $cookie.Expires = [datetime]::UtcNow.AddSeconds($Duration)
    }

    $cookie.Path = '/'

    # sets the cookie on the the response
    $WebEvent.PendingCookies[$cookie.Name] = $cookie
    Add-PodeHeader -Name 'Set-Cookie' -Value (ConvertTo-PodeCookieString -Cookie $cookie)
    return (ConvertTo-PodeCookie -Cookie $cookie)
}

<#
.SYNOPSIS
Stores secrets that can be used to sign cookies.

.DESCRIPTION
Stores secrets that can be used to sign cookies. A global secret can be set for easier retrieval.

.PARAMETER Name
The name of the secret to store.

.PARAMETER Value
The value of the secret to store.

.PARAMETER Global
If flagged, the secret being stored will be set as the global secret.

.EXAMPLE
Set-PodeCookieSecret -Name 'my-secret' -Value 'shhhh!'

.EXAMPLE
Set-PodeCookieSecret -Value 'hunter2' -Global
#>
function Set-PodeCookieSecret {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'General')]
        [string]
        $Name,

        [Parameter(Mandatory = $true)]
        [string]
        $Value,

        [Parameter(ParameterSetName = 'Global')]
        [switch]
        $Global
    )

    if ($Global) {
        $Name = 'global'
    }

    $PodeContext.Server.Cookies.Secrets[$Name] = $Value
}

<#
.SYNOPSIS
Retrieves a stored secret value.

.DESCRIPTION
Retrieves a stored secret value.

.PARAMETER Name
The name of the secret to retrieve.

.PARAMETER Global
If flagged, will return the current global secret value.

.EXAMPLE
Get-PodeCookieSecret -Name 'my-secret'

.EXAMPLE
Get-PodeCookieSecret -Global
#>
function Get-PodeCookieSecret {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'General')]
        [string]
        $Name,

        [Parameter(ParameterSetName = 'Global')]
        [switch]
        $Global
    )

    if ($Global) {
        return ($PodeContext.Server.Cookies.Secrets['global'])
    }

    return ($PodeContext.Server.Cookies.Secrets[$Name])
}
