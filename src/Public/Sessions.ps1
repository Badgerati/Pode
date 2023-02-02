<#
.SYNOPSIS
Enables Middleware for creating, retrieving and using Sessions within Pode.

.DESCRIPTION
Enables Middleware for creating, retrieving and using Sessions within Pode; with support for defining Session duration, and custom Storage.
If you're storing sessions outside of Pode, you must supply a Secret value so sessions aren't corrupted.

.PARAMETER Secret
An optional Secret to use when signing Sessions (Default: random GUID).

.PARAMETER Name
The name of the cookie/header used for the Session.

.PARAMETER Duration
The duration a Session should last for, before being expired.

.PARAMETER Generator
A custom ScriptBlock to generate a random unique SessionId. The value returned must be a String.

.PARAMETER Storage
A custom PSObject that defines methods for Delete, Get, and Set. This allow you to store Sessions in custom Storage such as Redis. A Secret is required.

.PARAMETER Extend
If supplied, the Sessions will have their durations extended on each successful Request.

.PARAMETER HttpOnly
If supplied, the Session cookie will only be accessible to browsers.

.PARAMETER Secure
If supplied, the Session cookie will only be accessible over HTTPS Requests.

.PARAMETER Strict
If supplied, the Secret will be extended using the client request's UserAgent and RemoteIPAddress.

.PARAMETER UseHeaders
If supplied, Sessions will be sent back in a header on the Response with the Name supplied.

.EXAMPLE
Enable-PodeSessionMiddleware  -Duration 120

.EXAMPLE
Enable-PodeSessionMiddleware -Duration 120 -Extend -Generator { return [System.IO.Path]::GetRandomFileName() }

.EXAMPLE
Enable-PodeSessionMiddleware -Secret 'schwifty' -Duration 120 -UseHeaders -Strict
#>
function Enable-PodeSessionMiddleware
{
    [CmdletBinding(DefaultParameterSetName='Cookies')]
    param (
        [Parameter()]
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

    # verify the secret, set to guid if not supplied, or error if none and we have a storage
    if ([string]::IsNullOrEmpty($Secret)) {
        if (!(Test-PodeIsEmpty $Storage)) {
            throw "A Secret is required when using custom session storage"
        }

        $Secret = New-PodeGuid -Secure
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
            Extend = $Extend.IsPresent
            Secure = $Secure.IsPresent
            Strict = $Strict.IsPresent
            HttpOnly = $HttpOnly.IsPresent
            UseHeaders = $UseHeaders.IsPresent
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

    # do nothin if session is null
    if ($null -eq $WebEvent.Session) {
        return
    }

    # remove the session, and from auth and cookies
    Remove-PodeAuthSession
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
    Invoke-PodeScriptBlock -ScriptBlock $WebEvent.Session.Save -Arguments @($Force.IsPresent) -Splat
}

<#
.SYNOPSIS
Returns the currently authenticated SessionId.

.DESCRIPTION
Returns the currently authenticated SessionId. If there's no session, or it's not authenticated, then null is returned instead.
You can also have the SessionId returned as signed as well.

.PARAMETER Signed
If supplied, the returned SessionId will also be signed.

.PARAMETER Force
If supplied, the sessionId will be returned regardless of authentication.

.EXAMPLE
$sessionId = Get-PodeSessionId
#>
function Get-PodeSessionId
{
    [CmdletBinding()]
    param(
        [switch]
        $Signed,

        [switch]
        $Force
    )

    $sessionId = $null

    # do nothing if not authenticated, or force passed
    if (!$Force -and ((Test-PodeIsEmpty $WebEvent.Session.Data.Auth.User) -or !$WebEvent.Session.Data.Auth.IsAuthenticated)) {
        return $sessionId
    }

    # get the sessionId
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

    # return the ID
    return $sessionId
}

<#
.SYNOPSIS
Resets the current Session's expiry date.

.DESCRIPTION
Resets the current Session's expiry date, to be from the current time plus the defined Session duration.

.EXAMPLE
Reset-PodeSessionExpiry
#>
function Reset-PodeSessionExpiry
{
    [CmdletBinding()]
    param()

    # if sessions haven't been setup, error
    if (!(Test-PodeSessionsConfigured)) {
        throw 'Sessions have not been configured'
    }

    # error if session is null
    if ($null -eq $WebEvent.Session) {
        throw 'There is no session available to save'
    }

    # temporarily set this session to auto-extend
    $WebEvent.Session.Extend = $true

    # reset on response
    Set-PodeSession
}

<#
.SYNOPSIS
Returns the defined Session duration.

.DESCRIPTION
Returns the defined Session duration that all Session are created using.

.EXAMPLE
$duration = Get-PodeSessionDuration
#>
function Get-PodeSessionDuration
{
    [CmdletBinding()]
    param()

    return [int]$PodeContext.Server.Sessions.Info.Duration
}

<#
.SYNOPSIS
Returns the datetime on which the current Session's will expire.

.DESCRIPTION
Returns the datetime on which the current Session's will expire.

.EXAMPLE
$expiry = Get-PodeSessionExpiry
#>
function Get-PodeSessionExpiry
{
    [CmdletBinding()]
    param()

    # error if session is null
    if ($null -eq $WebEvent.Session) {
        throw 'There is no session available to save'
    }

    # default min date
    if ($null -eq $WebEvent.Session.TimeStamp) {
        return [datetime]::MinValue
    }

    # use datetime.now or existing timestamp?
    $expiry = [DateTime]::UtcNow

    if (!$WebEvent.Session.Extend -and ($null -ne $WebEvent.Session.TimeStamp)) {
        $expiry = $WebEvent.Session.TimeStamp
    }

    # add session duration on
    $expiry = $expiry.AddSeconds($PodeContext.Server.Sessions.Info.Duration)

    # return expiry
    return $expiry
}