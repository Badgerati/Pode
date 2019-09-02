function New-PodeSessionCookie
{
    $sid = @{
        Name = $PodeContext.Server.Cookies.Session.Name
        Id = (Invoke-PodeScriptBlock -ScriptBlock $PodeContext.Server.Cookies.Session.GenerateId -Return)
        Cookie = $PodeContext.Server.Cookies.Session.Info
        Data = @{}
    }

    Set-PodeSessionCookieDataHash -Session $sid

    $sid.Cookie.TimeStamp = [DateTime]::UtcNow
    return $sid
}

function Set-PodeSessionCookie
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $Session
    )

    $secure = [bool]($Session.Cookie.Secure)
    $discard = [bool]($Session.Cookie.Discard)
    $httpOnly = [bool]($Session.Cookie.HttpOnly)

    (Set-PodeCookie `
        -Name $Session.Name `
        -Value $Session.Id `
        -Secret $PodeContext.Server.Cookies.Session.Secret `
        -ExpiryDate (Get-PodeSessionCookieExpiry -Session $Session) `
        -HttpOnly:$httpOnly `
        -Discard:$discard `
        -Secure:$secure) | Out-Null
}

function Get-PodeSessionCookie
{
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Name,

        [Parameter()]
        [string]
        $Secret
    )

    # check that the cookie is validly signed
    if (!(Test-PodeCookieSigned -Name $Name -Secret $Secret)) {
        return $null
    }

    # get the cookie from the request
    $cookie = Get-PodeCookie -Name $Name -Secret $Secret
    if (Test-IsEmpty $cookie) {
        return $null
    }

    # generate the session from the cookie
    $data = @{
        Name = $cookie.Name
        Id = $cookie.Value
        Cookie = $PodeContext.Server.Cookies.Session.Info
        Data = @{}
    }

    $data.Cookie.TimeStamp = $cookie.TimeStamp
    return $data
}

function Remove-PodeSessionCookie
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $Session
    )

    # remove the cookie from the response
    Remove-PodeCookie -Name $Session.Name

    # remove session from store
    Invoke-PodeScriptBlock -ScriptBlock $Session.Delete -Arguments @($Session) -Splat

    # blank the session
    $Session.Clear()
}

function Set-PodeSessionCookieDataHash
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $Session
    )

    $Session.Data = (Protect-PodeValue -Value $Session.Data -Default @{})
    $Session.DataHash = (Invoke-PodeSHA256Hash -Value ($Session.Data | ConvertTo-Json -Depth 10 -Compress))
}

function Test-PodeSessionCookieDataHash
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $Session
    )

    if (Test-IsEmpty $Session.DataHash) {
        return $false
    }

    $Session.Data = (Protect-PodeValue -Value $Session.Data -Default @{})
    $hash = (Invoke-PodeSHA256Hash -Value ($Session.Data | ConvertTo-Json -Depth 10 -Compress))
    return ($Session.DataHash -eq $hash)
}

function Get-PodeSessionCookieExpiry
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $Session
    )

    if ($null -eq $Session.Cookie) {
        return [DateTime]::MinValue
    }

    $expiry = (Resolve-PodeValue -Check ([bool]$Session.Cookie.Extend) -TrueValue ([DateTime]::UtcNow) -FalseValue $Session.Cookie.TimeStamp)
    $expiry = $expiry.AddSeconds($Session.Cookie.Duration)
    return $expiry
}

function Set-PodeSessionCookieHelpers
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $Session
    )

    # force save a session's data to the store
    $Session | Add-Member -MemberType NoteProperty -Name Save -Value {
        param($session, $check)

        # do nothing if session has no ID
        if ([string]::IsNullOrWhiteSpace($session.Id)) {
            return
        }

        # only save if check and hashes different
        if ($check -and (Test-PodeSessionCookieDataHash -Session $session)) {
            return
        }

        # generate the expiry
        $expiry = (Get-PodeSessionCookieExpiry -Session $session)

        # save session data to store
        $PodeContext.Server.Cookies.Session.Store.Set($session.Id, $session.Data, $expiry)

        # update session's data hash
        Set-PodeSessionCookieDataHash -Session $session
    }

    # delete the current session
    $Session | Add-Member -MemberType NoteProperty -Name Delete -Value {
        param($session)

        # remove data from store
        $PodeContext.Server.Cookies.Session.Store.Delete($session.Id)

        # clear session
        $session.Clear()
    }
}

function Get-PodeSessionCookieInMemStore
{
    $store = New-Object -TypeName psobject

    # add in-mem storage
    $store | Add-Member -MemberType NoteProperty -Name Memory -Value @{}

    # delete a sessionId and data
    $store | Add-Member -MemberType ScriptMethod -Name Delete -Value {
        param($sessionId)
        $this.Memory.Remove($sessionId) | Out-Null
    }

    # get a sessionId's data
    $store | Add-Member -MemberType ScriptMethod -Name Get -Value {
        param($sessionId)

        $s = $this.Memory[$sessionId]

        # if expire, remove
        if ($null -ne $s -and $s.Expiry -lt [DateTime]::UtcNow) {
            $this.Memory.Remove($sessionId) | Out-Null
            return $null
        }

        return $s.Data
    }

    # update/insert a sessionId and data
    $store | Add-Member -MemberType ScriptMethod -Name Set -Value {
        param($sessionId, $data, $expiry)

        $this.Memory[$sessionId] = @{
            Data = $data
            Expiry = $expiry
        }
    }

    return $store
}

function Set-PodeSessionCookieInMemClearDown
{
    # don't setup if serverless - as memory is short lived anyway
    if ($PodeContext.Server.IsServerless) {
        return
    }

    # cleardown expired inmem session every 10 minutes
    Add-PodeSchedule -Name '__pode_session_inmem_cleanup__' -Cron '0/10 * * * *' -ScriptBlock {
        $store = $PodeContext.Server.Cookies.Session.Store
        if (Test-IsEmpty $store.Memory) {
            return
        }

        # remove sessions that have expired
        $now = [DateTime]::UtcNow
        foreach ($key in $store.Memory.Keys) {
            if ($store.Memory[$key].Expiry -lt $now) {
                $store.Memory.Remove($key)
            }
        }
    }
}

function Test-PodeSessionsConfigured
{
    return (!(Test-IsEmpty $PodeContext.Server.Cookies.Session))
}