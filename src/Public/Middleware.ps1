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
Adds rate limiting rules for an IP addresses, Routes, or Endpoints.

.DESCRIPTION
Adds rate limiting rules for an IP addresses, Routes, or Endpoints.

.PARAMETER Type
What type of request is being rate limited: IP, Route, or Endpoint?

.PARAMETER Values
A single, or an array of values.

.PARAMETER Limit
The maximum number of requests to allow.

.PARAMETER Seconds
The number of seconds to count requests before restarting the count.

.PARAMETER Group
If supplied, groups of IPs in a subnet will be considered as one IP.

.EXAMPLE
Add-PodeLimitRule -Type IP -Values '127.0.0.1' -Limit 10 -Seconds 1

.EXAMPLE
Add-PodeLimitRule -Type IP -Values @('192.168.1.1', '10.10.1.0/24') -Limit 50 -Seconds 1 -Group

.EXAMPLE
Add-PodeLimitRule -Type Route -Values '/downloads' -Limit 5 -Seconds 1
#>
function Add-PodeLimitRule
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet('IP', 'Route', 'Endpoint')]
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

    # call the appropriate limit method
    foreach ($value in $Values)
    {
        switch ($Type.ToLowerInvariant())
        {
            'ip' {
                Test-PodeIsServerless -FunctionName 'Add-PodeLimitRule' -ThrowError
                Add-PodeIPLimit -IP $value -Limit $Limit -Seconds $Seconds -Group:$Group
            }

            'route' {
                Add-PodeRouteLimit -Path $value -Limit $Limit -Seconds $Seconds -Group:$Group
            }

            'endpoint' {
                Add-PodeEndpointLimit -EndpointName $value -Limit $Limit -Seconds $Seconds -Group:$Group
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
A secret to use when signing Sessions.

.PARAMETER Name
The name of the cookie/header used for the Session.

.PARAMETER Duration
The duration a Session should last for, before being expired.

.PARAMETER Generator
A custom ScriptBlock to generate a random unique SessionId. The value returned must be a String.

.PARAMETER Storage
A custom PSObject that defines methods for Delete, Get, and Set. This allow you to store Sessions in custom Storage such as Redis.

.PARAMETER Extend
If supplied, the Sessions will have their durations extended on each successful Request.

.PARAMETER HttpOnly
If supplied, the Session cookie will only be accessible to browsers.

.PARAMETER Secure
If supplied, the Session cookie will only be accessible over HTTPS Requests.

.PARAMETER Strict
If supplied, the supplie Secret will be extended using the client request's UserAgent and RemoteIPAddress.

.PARAMETER UseHeaders
If supplied, Sessions will be sent back in a header on the Response with the Name supplied.

.EXAMPLE
Enable-PodeSessionMiddleware -Secret 'schwifty' -Duration 120

.EXAMPLE
Enable-PodeSessionMiddleware -Secret 'schwifty' -Duration 120 -Extend -Generator { return [System.IO.Path]::GetRandomFileName() }

.EXAMPLE
Enable-PodeSessionMiddleware -Secret 'schwifty' -Duration 120 -UseHeaders -Strict
#>
function Enable-PodeSessionMiddleware
{
    [CmdletBinding(DefaultParameterSetName='Cookies')]
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

        [Parameter(ParameterSetName='Cookies')]
        [switch]
        $HttpOnly,

        [Parameter(ParameterSetName='Cookies')]
        [switch]
        $Secure,

        [switch]
        $Strict,

        [Parameter(ParameterSetName='Headers')]
        [switch]
        $UseHeaders
    )

    # check that session logic hasn't already been initialised
    if (Test-PodeSessionsConfigured) {
        throw 'Session Middleware has already been intialised'
    }

    # ensure the override store has the required methods
    if (!(Test-PodeIsEmpty $Storage)) {
        $members = @($Storage | Get-Member | Select-Object -ExpandProperty Name)
        @('delete', 'get', 'set') | ForEach-Object {
            if ($members -inotcontains $_) {
                throw "Custom session storage does not implement the required '$($_)()' method"
            }
        }
    }

    # if no custom storage, use the inmem one
    if (Test-PodeIsEmpty $Storage) {
        $Storage = (Get-PodeSessionInMemStore)
        Set-PodeSessionInMemClearDown
    }

    # set options against server context
    $PodeContext.Server.Sessions = @{
        Name = $Name
        Secret = $Secret
        GenerateId = (Protect-PodeValue -Value $Generator -Default { return (New-PodeGuid) })
        Store = $Storage
        Info = @{
            Duration = $Duration
            Extend = $Extend
            Secure = $Secure
            Strict = $Strict
            HttpOnly = $HttpOnly
            UseHeaders = $UseHeaders
        }
    }

    # return scriptblock for the session middleware
    $script = Get-PodeSessionMiddleware
    (New-PodeMiddleware -ScriptBlock $script) | Add-PodeMiddleware -Name '__pode_mw_sessions__'
}

<#
.SYNOPSIS
Remove the current Session, logging it out.

.DESCRIPTION
Remove the current Session, logging it out. This will remove the session from Storage, and Cookies.

.EXAMPLE
Remove-PodeSession
#>
function Remove-PodeSession
{
    [CmdletBinding()]
    param()

    # if sessions haven't been setup, error
    if (!(Test-PodeSessionsConfigured)) {
        throw 'Sessions have not been configured'
    }

    # error if session is null
    if ($null -eq $WebEvent.Session) {
        return
    }

    # remove the session, and from auth and cookies
    Remove-PodeAuthSession -Event $WebEvent
}

<#
.SYNOPSIS
Saves the current Session's data.

.DESCRIPTION
Saves the current Session's data.

.PARAMETER Force
If supplied, the data will be saved even if nothing has changed.

.EXAMPLE
Save-PodeSession -Force
#>
function Save-PodeSession
{
    [CmdletBinding()]
    param(
        [switch]
        $Force
    )

    # if sessions haven't been setup, error
    if (!(Test-PodeSessionsConfigured)) {
        throw 'Sessions have not been configured'
    }

    # error if session is null
    if ($null -eq $WebEvent.Session) {
        throw 'There is no session available to save'
    }

    # if auth is in use, then assign to session store
    if (!(Test-PodeIsEmpty $WebEvent.Auth) -and $WebEvent.Auth.Store) {
        $WebEvent.Session.Data.Auth = $WebEvent.Auth
    }

    # save the session
    Invoke-PodeScriptBlock -ScriptBlock $WebEvent.Session.Save -Arguments @($WebEvent.Session, $Force) -Splat
}

<#
.SYNOPSIS
Returns the currently authenticated SessionId.

.DESCRIPTION
Returns the currently authenticated SessionId. If there's no session, or it's not authenticated, then null is returned instead.
You can also have the SessionId returned as signed as well.

.PARAMETER Signed
If supplied, the returned SessionId will also be signed.

.EXAMPLE
$sessionId = Get-PodeSessionId
#>
function Get-PodeSessionId
{
    [CmdletBinding()]
    param(
        [switch]
        $Signed
    )

    $sessionId = $null

    # only return session if authenticated
    if (!(Test-PodeIsEmpty $WebEvent.Session.Data.Auth.User) -and $WebEvent.Session.Data.Auth.IsAuthenticated) {
        $sessionId = $WebEvent.Session.Id

        # do they want the session signed?
        if ($Signed) {
            $strict = $PodeContext.Server.Sessions.Info.Strict
            $secret = $PodeContext.Server.Sessions.Secret

            # covert secret to strict mode
            if ($strict) {
                $secret = ConvertTo-PodeSessionStrictSecret -Secret $secret
            }

            # sign the value if we have a secret
            $sessionId = (Invoke-PodeValueSign -Value $sessionId -Secret $secret)
        }
    }

    return $sessionId
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

        if (Test-PodeIsEmpty $Secret) {
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
        if (!(Test-PodeIsEmpty $ignored) -and ($ignored -icontains $e.Method)) {
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

<#
.SYNOPSIS
Adds a custom body parser middleware.

.DESCRIPTION
Adds a custom body parser middleware script for a content-type, which will be used if a payload is sent with a Request.

.PARAMETER ContentType
The ContentType of the custom body parser.

.PARAMETER ScriptBlock
The ScriptBlock that will parse the body content, and return the result.

.EXAMPLE
Add-PodeBodyParser -ContentType 'application/json' -ScriptBlock { param($body) /* parsing logic */ }
#>
function Add-PodeBodyParser
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidatePattern('^\w+\/[\w\.\+-]+$')]
        [string]
        $ContentType,

        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [scriptblock]
        $ScriptBlock
    )

    # if a parser for the type already exists, fail
    if ($PodeContext.Server.BodyParsers.ContainsKey($ContentType)) {
        throw "There is already a body parser defined for the $($ContentType) content-type"
    }

    # check if the scriptblock has any using vars
    $ScriptBlock, $usingVars = Invoke-PodeUsingScriptConversion -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState

    $PodeContext.Server.BodyParsers[$ContentType] = @{
        ScriptBlock = $ScriptBlock
        UsingVariables = $usingVars
    }
}

<#
.SYNOPSIS
Removes a custom body parser.

.DESCRIPTION
Removes a custom body parser middleware script for a content-type.

.PARAMETER ContentType
The ContentType of the custom body parser.

.EXAMPLE
Remove-PodeBodyParser -ContentType 'application/json'
#>
function Remove-PodeBodyParser
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [ValidatePattern('^\w+\/[\w\.\+-]+$')]
        [string]
        $ContentType
    )

    # if there's no parser for the type, return
    if (!$PodeContext.Server.BodyParsers.ContainsKey($ContentType)) {
        return
    }

    $PodeContext.Server.BodyParsers.Remove($ContentType) | Out-Null
}