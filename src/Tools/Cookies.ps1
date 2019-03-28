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
            elseif ($null -ne ($data = $PodeContext.Server.Cookies.Session.Store.Get($s.Session.Id))) {
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

function Flash
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet('add', 'clear', 'get', 'keys', 'remove')]
        [string]
        $Action,

        [Parameter()]
        [string]
        $Key,

        [Parameter()]
        [string]
        $Message
    )

    # if sessions haven't been setup, error
    if ($null -eq $PodeContext.Server.Cookies.Session) {
        throw 'Sessions are required to use Flash messages'
    }

    if (@('add', 'get', 'remove') -icontains $Action -and (Test-Empty $Key)) {
        throw "A Key is required for the Flash $($Action) action"
    }

    # run logic for the action
    switch ($Action.ToLowerInvariant())
    {
        'add' {
            # append the message against the key
            if ($null -eq $WebEvent.Session.Data.Flash) {
                $WebEvent.Session.Data.Flash = @{}
            }

            if ($null -eq $WebEvent.Session.Data.Flash[$Key]) {
                $WebEvent.Session.Data.Flash[$Key] = @($Message)
            }
            else {
                $WebEvent.Session.Data.Flash[$Key] += @($Message)
            }
        }

        'get' {
            # retrieve messages from session, then delete it
            if ($null -eq $WebEvent.Session.Data.Flash) {
                return @()
            }

            $v = @($WebEvent.Session.Data.Flash[$Key])
            $WebEvent.Session.Data.Flash.Remove($Key)

            if (Test-Empty $v) {
                return @()
            }

            return @($v)
        }

        'keys' {
            # return list of all current keys
            if ($null -eq $WebEvent.Session.Data.Flash) {
                return @()
            }

            return @($WebEvent.Session.Data.Flash.Keys)
        }

        'clear' {
            # clear all keys
            if ($null -ne $WebEvent.Session.Data.Flash) {
                $WebEvent.Session.Data.Flash = @{}
            }
        }

        'remove' {
            # remove key from flash messages
            if ($null -ne $WebEvent.Session.Data.Flash) {
                $WebEvent.Session.Data.Flash.Remove($Key)
            }
        }
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
    $cookie = $Request.Cookies[$PodeContext.Server.Cookies.Session.Name]
    if ((Test-Empty $cookie) -or (Test-Empty $cookie.Value)) {
        return $null
    }

    # ensure the session was signed
    $session = (Invoke-PodeCookieUnsign -Signature $cookie.Value -Secret $PodeContext.Server.Cookies.Session.SecretKey)
    if (Test-Empty $session) {
        return $null
    }

    # return session cookie data
    $data = @{
        'Name' = $cookie.Name;
        'Id' = $session;
        'Cookie' = $PodeContext.Server.Cookies.Session.Info;
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
    $signedValue = (Invoke-PodeCookieSign -Value $Session.Id -Secret $PodeContext.Server.Cookies.Session.SecretKey)

    # create a new cookie
    $cookie = [System.Net.Cookie]::new($Session.Name, $signedValue)
    $cookie.Secure = $Session.Cookie.Secure
    $cookie.Discard = $Session.Cookie.Discard

    # calculate the expiry
    $cookie.Expires = (Get-PodeSessionCookieExpiry -Session $Session)

    # assign cookie to response
    $Response.AppendCookie($cookie) | Out-Null
}

function Remove-PodeSessionCookie
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $Response,

        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $Session
    )

    # remove the cookie from the response, and reset it to expire
    $cookie = $Response.Cookies[$Session.Name]
    $cookie.Discard = $true
    $cookie.Expires = [DateTime]::UtcNow.AddDays(-2)
    $Response.AppendCookie($cookie) | Out-Null

    # remove session from store
    Invoke-ScriptBlock -ScriptBlock $Session.Delete -Arguments @($Session) -Splat

    # blank the session
    $Session.Clear()
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