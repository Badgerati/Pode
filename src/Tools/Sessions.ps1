function Session
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [hashtable]
        $Options
    )

    # check that session logic hasn't already been defined
    if (!(Test-Empty $PodeContext.Server.Cookies.Session)) {
        throw 'Session middleware logic has already been defined'
    }

    # ensure a secret was actually passed
    if (Test-Empty $Options.Secret) {
        throw 'A secret key is required for session cookies'
    }

    # ensure the override generator is a scriptblock
    if (!(Test-Empty $Options.GenerateId) -and (Get-PodeType $Options.GenerateId).Name -ine 'scriptblock') {
        throw "Session GenerateId should be a ScriptBlock, but got: $((Get-PodeType $Options.GenerateId).Name)"
    }

    # ensure the override store has the required methods
    if (!(Test-Empty $Options.Store)) {
        $members = @($Options.Store | Get-Member | Select-Object -ExpandProperty Name)
        @('delete', 'get', 'set') | ForEach-Object {
            if ($members -inotcontains $_) {
                throw "Custom session store does not implement the required '$($_)' method"
            }
        }
    }

    # ensure the duration is not <0
    $Options.Duration = [int]($Options.Duration)
    if ($Options.Duration -lt 0) {
        throw "Session duration must be 0 or greater, but got: $($Options.Duration)s"
    }

    # get the appropriate store
    $store = $Options.Store

    # if no custom store, use the inmem one
    if (Test-Empty $store) {
        $store = (Get-PodeSessionCookieInMemStore)
        Set-PodeSessionCookieInMemClearDown
    }

    # set options against session
    $PodeContext.Server.Cookies.Session = @{
        'Name' = (coalesce $Options.Name 'pode.sid');
        'SecretKey' = $Options.Secret;
        'GenerateId' = (coalesce $Options.GenerateId { return (Get-PodeNewGuid) });
        'Store' = $store;
        'Info' = @{
            'Duration' = [int]($Options.Duration);
            'Extend' = [bool]($Options.Extend);
            'Secure' = [bool]($Options.Secure);
            'Discard' = [bool]($Options.Discard);
            'HttpOnly' = [bool]($Options.HttpOnly);
        };
    }

    # bind session middleware to attach session function
    return {
        param($s)

        # if session already set, return
        if ($s.Session) {
            return $true
        }

        try
        {
            # get the session cookie
            $_sessionInfo = $PodeContext.Server.Cookies.Session
            $s.Session = Get-PodeSessionCookie -Name $_sessionInfo.Name -Secret $_sessionInfo.SecretKey

            # if no session on browser, create a new one
            if (!$s.Session) {
                $s.Session = (New-PodeSessionCookie)
                $new = $true
            }

            # get the session's data
            elseif ($null -ne ($data = $_sessionInfo.Store.Get($s.Session.Id))) {
                $s.Session.Data = $data
                Set-PodeSessionCookieDataHash -Session $s.Session
            }

            # session not in store, create a new one
            else {
                $s.Session = (New-PodeSessionCookie)
                $new = $true
            }

            # add helper methods to session
            Set-PodeSessionCookieHelpers -Session $s.Session

            # add cookie to response if it's new or extendible
            if ($new -or $s.Session.Cookie.Extend) {
                Set-PodeSessionCookie -Session $s.Session
            }

            # assign endware for session to set cookie/storage
            $s.OnEnd += {
                param($s)

                # if auth is in use, then assign to session store
                if (!(Test-Empty $s.Auth) -and $s.Auth.Store) {
                    $s.Session.Data.Auth = $s.Auth
                }

                Invoke-ScriptBlock -ScriptBlock $s.Session.Save -Arguments @($s.Session, $true) -Splat
            }
        }
        catch {
            $Error[0] | Out-Default
            return $false
        }

        # move along
        return $true
    }
}

function New-PodeSessionCookie
{
    $sid = @{
        'Name' = $PodeContext.Server.Cookies.Session.Name;
        'Id' = (Invoke-ScriptBlock -ScriptBlock $PodeContext.Server.Cookies.Session.GenerateId -Return);
        'Cookie' = $PodeContext.Server.Cookies.Session.Info;
        'Data' = @{};
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
        -Secret $PodeContext.Server.Cookies.Session.SecretKey `
        -Expiry (Get-PodeSessionCookieExpiry -Session $Session) `
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
    if (!(Test-PodeCookieIsSigned -Name $Name -Secret $Secret)) {
        return $null
    }

    # get the cookie from the request
    $cookie = Get-PodeCookie -Name $Name -Secret $Secret
    if (Test-Empty $cookie) {
        return $null
    }

    # generate the session from the cookie
    $data = @{
        'Name' = $cookie.Name;
        'Id' = $cookie.Value;
        'Cookie' = $PodeContext.Server.Cookies.Session.Info;
        'Data' = @{};
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
    Invoke-ScriptBlock -ScriptBlock $Session.Delete -Arguments @($Session) -Splat

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

    $Session.Data = (coalesce $Session.Data @{})
    $Session.DataHash = (Invoke-PodeSHA256Hash -Value ($Session.Data | ConvertTo-Json))
}

function Test-PodeSessionCookieDataHash
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $Session
    )

    if (Test-Empty $Session.DataHash) {
        return $false
    }

    $Session.Data = (coalesce $Session.Data @{})
    $hash = (Invoke-PodeSHA256Hash -Value ($Session.Data | ConvertTo-Json))
    return ($Session.DataHash -eq $hash)
}

function Get-PodeSessionCookieExpiry
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $Session
    )

    $expiry = (iftet $Session.Cookie.Extend ([DateTime]::UtcNow) $Session.Cookie.TimeStamp)
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
            'Data' = $data;
            'Expiry' = $expiry;
        }
    }

    return $store
}

function Set-PodeSessionCookieInMemClearDown
{
    # cleardown expired inmem session every 10 minutes
    Schedule -Name '__pode_session_inmem_cleanup__' -Cron '0/10 * * * *' -ScriptBlock {
        $store = $PodeContext.Server.Cookies.Session.Store
        if (Test-Empty $store.Memory) {
            return
        }

        # remove sessions that have expired
        $now = [DateTime]::UtcNow
        $store.Memory.Keys | ForEach-Object {
            if ($store.Memory[$_].Expiry -lt $now) {
                $store.Memory.Remove($_)
            }
        }
    }
}