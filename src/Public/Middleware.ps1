<#
.SYNOPSIS
Adds an access rule to allow or deny IP addresses.

.DESCRIPTION
Adds an access rule to allow or deny IP addresses.

.PARAMETER Access
The type of access to enable.

.PARAMETER Type
What type of request are we configuring?

.PARAMETER Values
A single, or an array of values.

.EXAMPLE
Add-PodeAccessRule -Access Allow -Type IP -Values '127.0.0.1'

.EXAMPLE
Add-PodeAccessRule -Access Deny -Type IP -Values @('192.168.1.1', '10.10.1.0/24')
#>
function Add-PodeAccessRule
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet('Allow', 'Deny')]
        [string]
        $Access,

        [Parameter(Mandatory=$true)]
        [ValidateSet('IP')]
        [string]
        $Type,

        [Parameter(Mandatory=$true)]
        [string[]]
        $Values
    )

    # error if serverless
    Test-PodeIsServerless -FunctionName 'Add-PodeAccessRule' -ThrowError

    # call the appropriate access method
    switch ($Type.ToLowerInvariant())
    {
        'ip' {
            foreach ($ip in $Values) {
                Add-PodeIPAccess -Access $Access -IP $ip
            }
        }
    }
}

<#
.SYNOPSIS
Adds rate limiting rules for an IP address.

.DESCRIPTION
Adds rate limiting rules for an IP address.

.PARAMETER Type
What type of request are we limiting?

.PARAMETER Values
A single, or an array of values.

.PARAMETER Limit
The maximum number of requests to allow.

.PARAMETER Seconds
The number of seconds to count requests before restarting the count.

.PARAMETER Group
If supplied, groups of IPs in a subnet will be concidered as one IP.

.EXAMPLE
Add-PodeLimitRule -Type IP -Values '127.0.0.1' -Limit 10 -Seconds 1

.EXAMPLE
Add-PodeLimitRule -Type IP -Values @('192.168.1.1', '10.10.1.0/24') -Limit 50 -Seconds 1 -Group
#>
function Add-PodeLimitRule
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet('IP')]
        [string]
        $Type,

        [Parameter(Mandatory=$true)]
        [string[]]
        $Values,

        [Parameter(Mandatory=$true)]
        [int]
        $Limit,

        [Parameter(Mandatory=$true)]
        [int]
        $Seconds,

        [switch]
        $Group
    )

    # error if serverless
    Test-PodeIsServerless -FunctionName 'Add-PodeLimitRule' -ThrowError

    # call the appropriate limit method
    switch ($Type.ToLowerInvariant())
    {
        'ip' {
            foreach ($ip in $Values) {
                Add-PodeIPLimit -IP $ip -Limit $Limit -Seconds $Seconds -Group:$Group
            }
        }
    }
}

<#
.SYNOPSIS
Enables Middleware for creating, retrieving and using Sessions within Pode.

.DESCRIPTION
Enables Middleware for creating, retrieving and using Sessions within Pode. With support for defining Session duration, and custom Storage.

.PARAMETER Secret
A secret to use when signing Session cookies.

.PARAMETER Name
The name of the cookie Sessions use.

.PARAMETER Duration
The duration a Session cookie should last for, before being expired.

.PARAMETER Generator
A custom ScriptBlock to generate a random unique SessionId. The value returned must be a String.

.PARAMETER Storage
A custom PSObject that defines methods for Delete, Get, and Set. This allow you to store Sessions in custom Storage such as Redis.

.PARAMETER Extend
If supplied, the Session's cookie will have its duration extended on each successful Request.

.PARAMETER HttpOnly
If supplied, the Session cookie will only be accessible to browsers.

.PARAMETER Secure
If supplied, the Session cookie will only be accessible over HTTPS Requests.

.EXAMPLE
Enable-PodeSessionMiddleware -Secret 'schwifty' -Duration 120

.EXAMPLE
Enable-PodeSessionMiddleware -Secret 'schwifty' -Duration 120 -Extend -Generator { return [System.IO.Path]::GetRandomFileName() }
#>
function Enable-PodeSessionMiddleware
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Secret,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name = 'pode.sid',

        [Parameter()]
        [ValidateScript({
            if ($_ -lt 0) {
                throw "Duration must be 0 or greater, but got: $($_)s"
            }

            return $true
        })]
        [int]
        $Duration = 0,

        [Parameter()]
        [scriptblock]
        $Generator,

        [Parameter()]
        [psobject]
        $Storage,

        [switch]
        $Extend,

        [switch]
        $HttpOnly,

        [switch]
        $Secure
    )

    # check that session logic hasn't already been initialised
    if (Test-PodeSessionsConfigured) {
        throw 'Session Middleware has already been intialised'
    }

    # ensure the override store has the required methods
    if (!(Test-IsEmpty $Storage)) {
        $members = @($Storage | Get-Member | Select-Object -ExpandProperty Name)
        @('delete', 'get', 'set') | ForEach-Object {
            if ($members -inotcontains $_) {
                throw "Custom session storage does not implement the required '$($_)()' method"
            }
        }
    }

    # if no custom storage, use the inmem one
    if (Test-IsEmpty $Storage) {
        $Storage = (Get-PodeSessionCookieInMemStore)
        Set-PodeSessionCookieInMemClearDown
    }

    # set options against server context
    $PodeContext.Server.Cookies.Session = @{
        Name = $Name
        Secret = $Secret
        GenerateId = (Protect-PodeValue -Value $Generator -Default { return (New-PodeGuid) })
        Store = $Storage
        Info = @{
            Duration = $Duration
            Extend = $Extend
            Secure = $Secure
            HttpOnly = $HttpOnly
        }
    }

    # return scriptblock for the session middleware
    $script = {
        param($e)

        # if session already set, return
        if ($e.Session) {
            return $true
        }

        try
        {
            # get the session cookie
            $_sessionInfo = $PodeContext.Server.Cookies.Session
            $e.Session = Get-PodeSessionCookie -Name $_sessionInfo.Name -Secret $_sessionInfo.Secret

            # if no session on browser, create a new one
            if (!$e.Session) {
                $e.Session = (New-PodeSessionCookie)
                $new = $true
            }

            # get the session's data
            elseif ($null -ne ($data = $_sessionInfo.Store.Get($e.Session.Id))) {
                $e.Session.Data = $data
                Set-PodeSessionCookieDataHash -Session $e.Session
            }

            # session not in store, create a new one
            else {
                $e.Session = (New-PodeSessionCookie)
                $new = $true
            }

            # add helper methods to session
            Set-PodeSessionCookieHelpers -Session $e.Session

            # add cookie to response if it's new or extendible
            if ($new -or $e.Session.Cookie.Extend) {
                Set-PodeSessionCookie -Session $e.Session
            }

            # assign endware for session to set cookie/storage
            $e.OnEnd += @{
                Logic = {
                    param($e)

                    # if auth is in use, then assign to session store
                    if (!(Test-IsEmpty $e.Auth) -and $e.Auth.Store) {
                        $e.Session.Data.Auth = $e.Auth
                    }

                    Invoke-PodeScriptBlock -ScriptBlock $e.Session.Save -Arguments @($e.Session, $true) -Splat
                }
            }
        }
        catch {
            $_ | Write-PodeErrorLog
            return $false
        }

        # move along
        return $true
    }

    (New-PodeMiddleware -ScriptBlock $script) | Add-PodeMiddleware -Name '__pode_mw_sessions__'
}

<#
.SYNOPSIS
Creates and returns a new secure token for use with CSRF.

.DESCRIPTION
Creates and returns a new secure token for use with CSRF.

.EXAMPLE
$token = New-PodeCsrfToken
#>
function New-PodeCsrfToken
{
    [CmdletBinding()]
    [OutputType([string])]
    param()

    # fail if the csrf logic hasn't been initialised
    if (!(Test-PodeCsrfConfigured)) {
        throw 'CSRF Middleware has not been initialised'
    }

    # generate a new secret and salt
    $Secret = New-PodeCsrfSecret
    $Salt = (New-PodeSalt -Length 8)

    # return a new token
    return "t:$($Salt).$(Invoke-PodeSHA256Hash -Value "$($Salt)-$($Secret)")"
}

<#
.SYNOPSIS
Returns adhoc CSRF CSRF verification Middleware, for use on Routes.

.DESCRIPTION
Returns adhoc CSRF CSRF verification Middleware, for use on Routes.

.EXAMPLE
$csrf = Get-PodeCsrfMiddleware
Add-PodeRoute -Method Get -Path '/cpu' -Middleware $csrf -ScriptBlock { /* logic */ }
#>
function Get-PodeCsrfMiddleware
{
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    # fail if the csrf logic hasn't been initialised
    if (!(Test-PodeCsrfConfigured)) {
        throw 'CSRF Middleware has not been initialised'
    }

    # return scriptblock for the csrf route middleware to test tokens
    $script = {
        param($e)

        # if there's not a secret, generate and store it
        $secret = New-PodeCsrfSecret

        # verify the token on the request, if invalid, throw a 403
        $token = Get-PodeCsrfToken

        if (!(Test-PodeCsrfToken -Secret $secret -Token $token)){
            Set-PodeResponseStatus -Code 403 -Description 'Invalid CSRF Token'
            return $false
        }

        # token is valid, move along
        return $true
    }

    return (New-PodeMiddleware -ScriptBlock $script)
}

<#
.SYNOPSIS
Initialises CSRF within Pode for adhoc usage.

.DESCRIPTION
Initialises CSRF within Pode for adhoc usage, with configurable HTTP methods to ignore verification.

.PARAMETER IgnoreMethods
An array of HTTP methods to ignore CSRF verification.

.PARAMETER Secret
A secret to use when signing cookies - for when using CSRF with cookies.

.PARAMETER UseCookies
If supplied, CSRF will used cookies rather than sessions.

.EXAMPLE
Initialize-PodeCsrf -IgnoreMethods @('Get', 'Trace')

.EXAMPLE
Initialize-PodeCsrf -Secret 'some-secret' -UseCookies
#>
function Initialize-PodeCsrf
{
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateSet('Delete', 'Get', 'Head', 'Merge', 'Options', 'Patch', 'Post', 'Put', 'Trace')]
        [string[]]
        $IgnoreMethods = @('Get', 'Head', 'Options', 'Trace'),

        [Parameter()]
        [string]
        $Secret,

        [switch]
        $UseCookies
    )

    # check that csrf logic hasn't already been intialised
    if (Test-PodeCsrfConfigured) {
        return
    }

    # if sessions haven't been setup and we're not using cookies, error
    if (!$UseCookies -and !(Test-PodeSessionsConfigured)) {
        throw 'Sessions are required to use CSRF unless you want to use cookies'
    }

    # if we're using cookies, ensure a global secret exists
    if ($UseCookies) {
        $Secret = (Protect-PodeValue -Value $Secret -Default (Get-PodeCookieSecret -Global))

        if (Test-IsEmpty $Secret) {
            throw "When using cookies for CSRF, a Secret is required. You can either supply a Secret, or set the Cookie global secret - (Set-PodeCookieSecret '<value>' -Global)"
        }
    }

    # set the options against the server context
    $PodeContext.Server.Cookies.Csrf = @{
        Name = 'pode.csrf'
        UseCookies = $UseCookies
        Secret = $Secret
        IgnoredMethods = $IgnoreMethods
    }
}

<#
.SYNOPSIS
Enables Middleware for verifying CSRF tokens on Requests.

.DESCRIPTION
Enables Middleware for verifying CSRF tokens on Requests, with configurable HTTP methods to ignore verification.

.PARAMETER IgnoreMethods
An array of HTTP methods to ignore CSRF verification.

.PARAMETER Secret
A secret to use when signing cookies - for when using CSRF with cookies.

.PARAMETER UseCookies
If supplied, CSRF will used cookies rather than sessions.

.EXAMPLE
Enable-PodeCsrfMiddleware -IgnoreMethods @('Get', 'Trace')

.EXAMPLE
Enable-PodeCsrfMiddleware -Secret 'some-secret' -UseCookies
#>
function Enable-PodeCsrfMiddleware
{
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateSet('Delete', 'Get', 'Head', 'Merge', 'Options', 'Patch', 'Post', 'Put', 'Trace')]
        [string[]]
        $IgnoreMethods = @('Get', 'Head', 'Options', 'Trace'),

        [Parameter(ParameterSetName='Cookies')]
        [string]
        $Secret,

        [Parameter(ParameterSetName='Cookies')]
        [switch]
        $UseCookies
    )

    Initialize-PodeCsrf -IgnoreMethods $IgnoreMethods -Secret $Secret -UseCookies:$UseCookies

    # return scriptblock for the csrf middleware
    $script = {
        param($e)

        # if the current route method is ignored, just return
        $ignored = @($PodeContext.Server.Cookies.Csrf.IgnoredMethods)
        if (!(Test-IsEmpty $ignored) -and ($ignored -icontains $e.Method)) {
            return $true
        }

        # if there's not a secret, generate and store it
        $secret = New-PodeCsrfSecret

        # verify the token on the request, if invalid, throw a 403
        $token = Get-PodeCsrfToken

        if (!(Test-PodeCsrfToken -Secret $secret -Token $token)){
            Set-PodeResponseStatus -Code 403 -Description 'Invalid CSRF Token'
            return $false
        }

        # token is valid, move along
        return $true
    }

    (New-PodeMiddleware -ScriptBlock $script) | Add-PodeMiddleware -Name '__pode_mw_csrf__'
}