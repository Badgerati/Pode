function Session
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [hashtable]
        $Options
    )

    # check that session logic hasn't already been defined
    if (!(Test-Empty $PodeSession.Server.Cookies.Session)) {
        throw 'Session middleware logic has already been defined'
    }

    # ensure a secret was actually passed
    if (Test-Empty $Options.Secret) {
        throw 'A secret key is required for session cookies'
    }

    # ensure the override generator is a scriptblock
    if (!(Test-Empty $Options.GenerateId) -and (Get-Type $Options.GenerateId).Name -ine 'scriptblock') {
        throw "Session GenerateId should be a ScriptBlock, but got: $((Get-Type $Options.GenerateId).Name)"
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
    $PodeSession.Server.Cookies.Session = @{
        'Name' = (coalesce $Options.Name 'pode.sid');
        'SecretKey' = $Options.Secret;
        'GenerateId' = (coalesce $Options.GenerateId { return (Get-NewGuid) });
        'Store' = $store;
        'Info' = @{
            'Duration' = [int]($Options.Duration);
            'Extend' = [bool]($Options.Extend);
            'Secure' = [bool]($Options.Secure);
            'Discard' = [bool]($Options.Discard);
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
            $s.Session = Get-PodeSessionCookie -Request $s.Request

            # if no session on browser, create a new one
            if (!$s.Session) {
                $s.Session = (New-PodeSessionCookie)
                $new = $true
            }

            # get the session's data
            elseif (($data = $PodeSession.Server.Cookies.Session.Store.Get($s.Session.Id)) -ne $null) {
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
                Set-PodeSessionCookie -Response $s.Response -Session $s.Session
            }

            # assign endware for session to set cookie/storage
            $s.OnEnd += {
                param($s)
                $s.Session.Save()
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

function Get-PodeSessionCookie
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $Request
    )

    # get the session from cookie
    $cookie = $Request.Cookies[$PodeSession.Server.Cookies.Session.Name]
    if ((Test-Empty $cookie) -or (Test-Empty $cookie.Value)) {
        return $null
    }

    # ensure the session was signed
    $session = (Invoke-CookieUnsign -Signature $cookie.Value -Secret $PodeSession.Server.Cookies.Session.SecretKey)
    if (Test-Empty $session) {
        return $null
    }

    # return session cookie data
    $data = @{
        'Name' = $cookie.Name;
        'Id' = $session;
        'Cookie' = $PodeSession.Server.Cookies.Session.Info;
        'Data' = @{};
    }

    $data.Cookie.TimeStamp = $cookie.TimeStamp
    return $data
}

function Set-PodeSessionCookie
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $Response,

        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $Session
    )

    # sign the session
    $signedValue = (Invoke-CookieSign -Value $Session.Id -Secret $PodeSession.Server.Cookies.Session.SecretKey)

    # create a new cookie
    $cookie = [System.Net.Cookie]::new($Session.Name, $signedValue)
    $cookie.Secure = $Session.Cookie.Secure
    $cookie.Discard = $Session.Cookie.Discard

    # calculate the expiry
    $cookie.Expires = (Get-PodeSessionCookieExpiry -Session $Session)

    # assign cookie to response
    $Response.AppendCookie($cookie) | Out-Null
}

function New-PodeSessionCookie
{
    $sid = @{
        'Name' = $PodeSession.Server.Cookies.Session.Name;
        'Id' = (Invoke-ScriptBlock -ScriptBlock $PodeSession.Server.Cookies.Session.GenerateId -Return);
        'Cookie' = $PodeSession.Server.Cookies.Session.Info;
        'Data' = @{};
    }

    Set-PodeSessionCookieDataHash -Session $sid

    $sid.Cookie.TimeStamp = [DateTime]::UtcNow
    return $sid
}

function Set-PodeSessionCookieDataHash
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $Session
    )

    $Session.Data = (coalesce $Session.Data @{})
    $Session.DataHash = (Invoke-SHA256Hash -Value ($Session.Data | ConvertTo-Json))
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
    $hash = (Invoke-SHA256Hash -Value ($Session.Data | ConvertTo-Json))
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
    $Session | Add-Member -MemberType ScriptMethod -Name Save -Value {
        param($check)

        # only save if check and hashes different
        if ($check -and !(Test-PodeSessionCookieDataHash -Session $this)) {
            return
        }

        # generate the expiry
        $expiry = (Get-PodeSessionCookieExpiry -Session $this)

        # save session data to store
        $PodeSession.Server.Cookies.Session.Store.Set($this.Id, $this.Data, $expiry)

        # update session's data hash
        Set-PodeSessionCookieDataHash -Session $this
    }

    # delete the current session
    $Session | Add-Member -MemberType ScriptMethod -Name Delete -Value {
        # remove data from store
        $PodeSession.Server.Cookies.Session.Store.Delete($this.Id)

        # clear session
        $this.Clear()
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
    schedule '__pode_session_inmem_cleanup__' '0/10 * * * *' {
        $store = $PodeSession.Server.Cookies.Session.Store
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