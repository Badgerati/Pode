function New-PodeSession
{
    $sid = @{
        Name = $PodeContext.Server.Sessions.Name
        Id = (Invoke-PodeScriptBlock -ScriptBlock $PodeContext.Server.Sessions.GenerateId -Return)
        Properties = $PodeContext.Server.Sessions.Info
        Data = @{}
    }

    Set-PodeSessionDataHash -Session $sid

    $sid.Properties.TimeStamp = [DateTime]::UtcNow
    return $sid
}

function ConvertTo-PodeSessionStrictSecret
{
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Secret
    )

    return "$($Secret);$($WebEvent.Request.UserAgent);$($WebEvent.Request.RemoteEndPoint.Address.IPAddressToString)"
}

function Set-PodeSession
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [hashtable]
        $Session
    )

    $secure = [bool]($Session.Properties.Secure)
    $strict = [bool]($Session.Properties.Strict)
    $discard = [bool]($Session.Properties.Discard)
    $httpOnly = [bool]($Session.Properties.HttpOnly)
    $useHeaders = [bool]($Session.Properties.UseHeaders)
    $secret = $PodeContext.Server.Sessions.Secret

    # covert secret to strict mode
    if ($strict) {
        $secret = ConvertTo-PodeSessionStrictSecret -Secret $secret
    }

    # set session on header
    if ($useHeaders) {
        Set-PodeHeader -Name $Session.Name -Value $Session.Id -Secret $secret
    }

    # set session as cookie
    else {
        (Set-PodeCookie `
            -Name $Session.Name `
            -Value $Session.Id `
            -Secret $secret `
            -ExpiryDate (Get-PodeSessionExpiry -Session $Session) `
            -HttpOnly:$httpOnly `
            -Discard:$discard `
            -Secure:$secure) | Out-Null
    }
}

function Get-PodeSession
{
    param (
        [Parameter(Mandatory=$true)]
        [hashtable]
        $Session
    )

    $secret = $Session.Secret
    $timestamp = [datetime]::UtcNow
    $value = $null
    $name = $Session.Name

    # covert secret to strict mode
    if ($Session.Info.Strict) {
        $secret = ConvertTo-PodeSessionStrictSecret -Secret $secret
    }

    # session from header
    if ($Session.Info.UseHeaders) {
        # check that the header is validly signed
        if (!(Test-PodeHeaderSigned -Name $Session.Name -Secret $secret)) {
            return $null
        }

        # get the header from the request
        $value = Get-PodeHeader -Name $Session.Name -Secret $secret
        if (Test-IsEmpty $value) {
            return $null
        }
    }

    # session from cookie
    else {
        # check that the cookie is validly signed
        if (!(Test-PodeCookieSigned -Name $Session.Name -Secret $secret)) {
            return $null
        }

        # get the cookie from the request
        $cookie = Get-PodeCookie -Name $Session.Name -Secret $secret
        if (Test-IsEmpty $cookie) {
            return $null
        }

        # get details from cookie
        $name = $cookie.Name
        $value = $cookie.Value
        $timestamp = $cookie.TimeStamp
    }

    # generate the session data
    $data = @{
        Name = $name
        Id = $value
        Properties = $Session.Info
        Data = @{}
    }

    $data.Properties.TimeStamp = $timeStamp
    return $data
}

function Revoke-PodeSession
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [hashtable]
        $Session
    )

    # remove from cookie
    if (!$Session.Properties.UseHeaders) {
        Remove-PodeCookie -Name $Session.Name
    }

    # remove session from store
    Invoke-PodeScriptBlock -ScriptBlock $Session.Delete -Arguments @($Session) -Splat

    # blank the session
    $Session.Clear()
}

function Set-PodeSessionDataHash
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [hashtable]
        $Session
    )

    $Session.Data = (Protect-PodeValue -Value $Session.Data -Default @{})
    $Session.DataHash = (Invoke-PodeSHA256Hash -Value ($Session.Data | ConvertTo-Json -Depth 10 -Compress))
}

function Test-PodeSessionDataHash
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [hashtable]
        $Session
    )

    if (Test-IsEmpty $Session.DataHash) {
        return $false
    }

    $Session.Data = (Protect-PodeValue -Value $Session.Data -Default @{})
    $hash = (Invoke-PodeSHA256Hash -Value ($Session.Data | ConvertTo-Json -Depth 10 -Compress))
    return ($Session.DataHash -eq $hash)
}

function Get-PodeSessionExpiry
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [hashtable]
        $Session
    )

    if ($null -eq $Session.Properties) {
        return [DateTime]::MinValue
    }

    $expiry = (Resolve-PodeValue -Check ([bool]$Session.Properties.Extend) -TrueValue ([DateTime]::UtcNow) -FalseValue $Session.Properties.TimeStamp)
    $expiry = $expiry.AddSeconds($Session.Properties.Duration)
    return $expiry
}

function Set-PodeSessionHelpers
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [hashtable]
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
        if ($check -and (Test-PodeSessionDataHash -Session $session)) {
            return
        }

        # generate the expiry
        $expiry = (Get-PodeSessionExpiry -Session $session)

        # save session data to store
        $PodeContext.Server.Sessions.Store.Set($session.Id, $session.Data, $expiry)

        # update session's data hash
        Set-PodeSessionDataHash -Session $session
    }

    # delete the current session
    $Session | Add-Member -MemberType NoteProperty -Name Delete -Value {
        param($session)

        # remove data from store
        $PodeContext.Server.Sessions.Store.Delete($session.Id)

        # clear session
        $session.Clear()
    }
}

function Get-PodeSessionInMemStore
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
        if (($null -ne $s) -and ($s.Expiry -lt [DateTime]::UtcNow)) {
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

function Set-PodeSessionInMemClearDown
{
    # don't setup if serverless - as memory is short lived anyway
    if ($PodeContext.Server.IsServerless) {
        return
    }

    # cleardown expired inmem session every 10 minutes
    Add-PodeSchedule -Name '__pode_session_inmem_cleanup__' -Cron '0/10 * * * *' -ScriptBlock {
        $store = $PodeContext.Server.Sessions.Store
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
    return (!(Test-IsEmpty $PodeContext.Server.Sessions))
}

function Get-PodeSessionMiddleware
{
    return {
        param($e)

        # if session already set, return
        if ($e.Session) {
            return $true
        }

        try
        {
            # get the session from cookie/header
            $e.Session = Get-PodeSession -Session $PodeContext.Server.Sessions

            # if no session found, create a new one on the current web event
            if (!$e.Session) {
                $e.Session = (New-PodeSession)
                $new = $true
            }

            # get the session's data
            elseif ($null -ne ($data = $PodeContext.Server.Sessions.Store.Get($e.Session.Id))) {
                $e.Session.Data = $data
                Set-PodeSessionDataHash -Session $e.Session
            }

            # session not in store, create a new one
            else {
                $e.Session = (New-PodeSession)
                $new = $true
            }

            # add helper methods to session
            Set-PodeSessionHelpers -Session $e.Session

            # add session to response if it's new or extendible
            if ($new -or $e.Session.Properties.Extend) {
                Set-PodeSession -Session $e.Session
            }

            # assign endware for session to set cookie/header
            $e.OnEnd += @{
                Logic = {
                    Save-PodeSession -Force
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
}