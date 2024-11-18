function New-PodeSession {
    # sessionId
    $sessionId = Invoke-PodeScriptBlock -ScriptBlock $PodeContext.Server.Sessions.GenerateId -Return

    # tabId
    $tabId = $null
    if (!$PodeContext.Server.Sessions.Info.Scope.IsBrowser) {
        $tabId = Get-PodeSessionTabId
    }

    # return new session data
    return @{
        Name      = $PodeContext.Server.Sessions.Name
        Id        = $sessionId
        TabId     = $tabId
        FullId    = (Get-PodeSessionFullId -SessionId $sessionId -TabId $tabId)
        Extend    = $PodeContext.Server.Sessions.Info.Extend
        TimeStamp = [datetime]::UtcNow
        Data      = @{}
    }
}

function Get-PodeSessionFullId {
    param(
        [Parameter()]
        [string]
        $SessionId,

        [Parameter()]
        [string]
        $TabId
    )

    if (!$PodeContext.Server.Sessions.Info.Scope.IsBrowser -and ![string]::IsNullOrEmpty($TabId)) {
        return "$($SessionId)-$($TabId)"
    }

    return $SessionId
}

function Set-PodeSession {
    if ($null -eq $WebEvent.Session) {
        # There is no session available to set on the response
        throw ($PodeLocale.noSessionToSetOnResponseExceptionMessage)
    }

    # convert secret to strict mode
    $strict = $PodeContext.Server.Sessions.Info.Strict
    $secret = $PodeContext.Server.Sessions.Secret

    # set session on header
    if ($PodeContext.Server.Sessions.Info.UseHeaders) {
        Set-PodeHeader -Name $WebEvent.Session.Name -Value $WebEvent.Session.Id -Secret $secret -Strict:$strict
    }

    # set session as cookie
    else {
        $null = Set-PodeCookie `
            -Name $WebEvent.Session.Name `
            -Value $WebEvent.Session.Id `
            -Secret $secret `
            -Strict:$strict `
            -ExpiryDate (Get-PodeSessionExpiry) `
            -HttpOnly:$PodeContext.Server.Sessions.Info.HttpOnly `
            -Secure:$PodeContext.Server.Sessions.Info.Secure
    }
}

function Get-PodeSession {
    $secret = $PodeContext.Server.Sessions.Secret
    $sessionId = $null
    $tabId = Get-PodeSessionTabId
    $name = $PodeContext.Server.Sessions.Name

    # convert secret to strict mode
    if ($PodeContext.Server.Sessions.Info.Strict) {
        $secret = ConvertTo-PodeStrictSecret -Secret $secret
    }

    # session from header
    if ($PodeContext.Server.Sessions.Info.UseHeaders) {
        # check that the header is validly signed
        if (!(Test-PodeHeaderSigned -Name $PodeContext.Server.Sessions.Name -Secret $secret)) {
            return $null
        }

        # get the header from the request
        $sessionId = Get-PodeHeader -Name $PodeContext.Server.Sessions.Name -Secret $secret
        if ([string]::IsNullOrEmpty($sessionId)) {
            return $null
        }
    }

    # session from cookie
    else {
        # check that the cookie is validly signed
        if (!(Test-PodeCookieSigned -Name $PodeContext.Server.Sessions.Name -Secret $secret)) {
            return $null
        }

        # get the cookie from the request
        $cookie = Get-PodeCookie -Name $PodeContext.Server.Sessions.Name -Secret $secret
        if ([string]::IsNullOrEmpty($cookie)) {
            return $null
        }

        # get details from cookie
        $name = $cookie.Name
        $sessionId = $cookie.Value
    }

    # generate the session data
    return @{
        Name      = $name
        Id        = $sessionId
        TabId     = $tabId
        FullId    = (Get-PodeSessionFullId -SessionId $sessionId -TabId $tabId)
        Extend    = $PodeContext.Server.Sessions.Info.Extend
        TimeStamp = $null
        Data      = @{}
    }
}

function Revoke-PodeSession {
    # do nothing if no current session
    if ($null -eq $WebEvent.Session) {
        return
    }

    # remove from cookie if being used
    if (!$PodeContext.Server.Sessions.Info.UseHeaders) {
        Remove-PodeCookie -Name $WebEvent.Session.Name
    }

    # remove session from store
    Remove-PodeSessionInternal
}

function Set-PodeSessionDataHash {
    if ($null -eq $WebEvent.Session) {
        # No session available to calculate data hash
        throw ($PodeLocale.noSessionToCalculateDataHashExceptionMessage)
    }

    if (($null -eq $WebEvent.Session.Data) -or ($WebEvent.Session.Data.Count -eq 0)) {
        $WebEvent.Session.Data = @{}
    }

    $WebEvent.Session.DataHash = (Invoke-PodeSHA256Hash -Value (ConvertTo-Json -InputObject $WebEvent.Session.Data.Clone() -Depth 10 -Compress))
}

function Test-PodeSessionDataHash {
    if ($null -eq $WebEvent.Session) {
        return $false
    }

    if ([string]::IsNullOrWhiteSpace($WebEvent.Session.DataHash)) {
        return $false
    }

    if (($null -eq $WebEvent.Session.Data) -or ($WebEvent.Session.Data.Count -eq 0)) {
        $WebEvent.Session.Data = @{}
    }

    $hash = (Invoke-PodeSHA256Hash -Value (ConvertTo-Json -InputObject $WebEvent.Session.Data -Depth 10 -Compress))
    return ($WebEvent.Session.DataHash -eq $hash)
}

function Save-PodeSessionInternal {
    param(
        [switch]
        $Force
    )

    # do nothing if session has no ID
    if ([string]::IsNullOrEmpty($WebEvent.Session.FullId)) {
        return
    }

    # only save if check and hashes different, but not if extending expiry or updated
    if (!$WebEvent.Session.Extend -and $Force -and (Test-PodeSessionDataHash)) {
        return
    }

    # generate the expiry
    $expiry = Get-PodeSessionExpiry

    # the data to save - which will be the data, and some extra metadata like timestamp
    $data = @{
        Version  = 3
        Metadata = @{
            TimeStamp = $WebEvent.Session.TimeStamp
        }
        Data     = $WebEvent.Session.Data
    }

    # save base session data to store
    if (!$PodeContext.Server.Sessions.Info.Scope.IsBrowser -and $WebEvent.Session.TabId) {
        $authData = @{
            Version  = 3
            Metadata = @{
                TimeStamp = $WebEvent.Session.TimeStamp
                Tabbed    = $true
            }
            Data     = @{
                Auth = $WebEvent.Session.Data.Auth
            }
        }

        $null = Invoke-PodeScriptBlock -ScriptBlock $PodeContext.Server.Sessions.Store.Set -Arguments @($WebEvent.Session.Id, $authData, $expiry) -Splat
        $data.Metadata['Parent'] = $WebEvent.Session.Id
    }

    # save session data to store
    $null = Invoke-PodeScriptBlock -ScriptBlock $PodeContext.Server.Sessions.Store.Set -Arguments @($WebEvent.Session.FullId, $data, $expiry) -Splat

    # update session's data hash
    Set-PodeSessionDataHash
}

function Remove-PodeSessionInternal {
    if ($null -eq $WebEvent.Session) {
        return
    }

    # remove data from store
    $null = Invoke-PodeScriptBlock -ScriptBlock $PodeContext.Server.Sessions.Store.Delete -Arguments $WebEvent.Session.Id

    # clear session
    $WebEvent.Session.Clear()
    $WebEvent.Session = $null
}

function Get-PodeSessionInMemStore {
    $store = [psobject]::new()

    # add in-mem storage
    $store | Add-Member -MemberType NoteProperty -Name Memory -Value @{}

    # delete a sessionId and data
    $store | Add-Member -MemberType NoteProperty -Name Delete -Value {
        param($sessionId)
        $null = $PodeContext.Server.Sessions.Store.Memory.Remove($sessionId)
        if (!$PodeContext.Server.Sessions.Info.Scope.IsBrowser) {
            Invoke-PodeSchedule -Name '__pode_session_inmem_cleanup__'
        }
    }

    # get a sessionId's data
    $store | Add-Member -MemberType NoteProperty -Name Get -Value {
        param($sessionId)

        $s = $PodeContext.Server.Sessions.Store.Memory[$sessionId]

        # if expire, remove
        if (($null -ne $s) -and ($s.Expiry -lt [DateTime]::UtcNow)) {
            $null = $PodeContext.Server.Sessions.Store.Memory.Remove($sessionId)
            return $null
        }

        return $s.Data
    }

    # update/insert a sessionId and data
    $store | Add-Member -MemberType NoteProperty -Name Set -Value {
        param($sessionId, $data, $expiry)

        $PodeContext.Server.Sessions.Store.Memory[$sessionId] = @{
            Data   = $data
            Expiry = $expiry
        }
    }

    return $store
}

function Set-PodeSessionInMemClearDown {
    # don't setup if serverless - as memory is short lived anyway
    if ($PodeContext.Server.IsServerless) {
        return
    }

    # cleardown expired inmem session every 10 minutes
    Add-PodeSchedule -Name '__pode_session_inmem_cleanup__' -Cron '0/10 * * * *' -ScriptBlock {
        # do nothing if no sessions
        $store = $PodeContext.Server.Sessions.Store
        if (($null -eq $store.Memory) -or ($store.Memory.Count -eq 0)) {
            return
        }

        # remove sessions that have expired, or where the parent is gone
        $now = [DateTime]::UtcNow
        foreach ($key in $store.Memory.Keys.Clone()) {
            # expired
            if ($store.Memory[$key].Expiry -lt $now) {
                $null = $store.Memory.Remove($key)
                continue
            }

            # parent check - gone/expired
            $parentKey = $store.Memory[$key].Data.Metadata.Parent
            if ($parentKey -and (!$store.Memory.ContainsKey($parentKey) -or ($store.Memory[$parentKey].Expiry -lt $now))) {
                $null = $store.Memory.Remove($key)
            }
        }
    }
}

function Test-PodeSessionsInUse {
    return (($null -ne $WebEvent.Session) -and ($WebEvent.Session.Count -gt 0))
}

function Get-PodeSessionData {
    param(
        [Parameter()]
        [string]
        $SessionId,

        [Parameter()]
        [string]
        $TabId = $null
    )

    $data = $null

    # try and get Tab session
    if (!$PodeContext.Server.Sessions.Info.Scope.IsBrowser -and ![string]::IsNullOrEmpty($TabId)) {
        $data = Invoke-PodeScriptBlock -ScriptBlock $PodeContext.Server.Sessions.Store.Get -Arguments "$($SessionId)-$($TabId)" -Return

        # now get the parent - but fail if it doesn't exist
        if ($data.Metadata.Parent) {
            $parent = Invoke-PodeScriptBlock -ScriptBlock $PodeContext.Server.Sessions.Store.Get -Arguments $data.Metadata.Parent -Return
            if (!$parent) {
                return $null
            }

            if (!$data.Data.Auth) {
                $data.Data.Auth = $parent.Data.Auth
            }
        }
    }

    # try and get normal session
    if (($null -eq $data) -and ![string]::IsNullOrEmpty($SessionId)) {
        $data = Invoke-PodeScriptBlock -ScriptBlock $PodeContext.Server.Sessions.Store.Get -Arguments $SessionId -Return
    }

    return $data
}

function Get-PodeSessionMiddleware {
    return {
        # if session already set, return
        if ($WebEvent.Session) {
            return $true
        }

        try {
            # retrieve the current session from cookie/header
            $WebEvent.Session = Get-PodeSession

            # if no session found, create a new one on the current web event
            if (!$WebEvent.Session) {
                $WebEvent.Session = New-PodeSession
                $new = $true
            }

            # get the session's data from store
            elseif ($null -ne ($data = (Get-PodeSessionData -SessionId $WebEvent.Session.Id -TabId $WebEvent.Session.TabId))) {
                if ($data.Version -lt 3) {
                    $WebEvent.Session.Data = $data
                    $WebEvent.Session.TimeStamp = [datetime]::UtcNow
                }
                else {
                    $WebEvent.Session.Data = $data.Data
                    if ($data.Metadata.Tabbed) {
                        $WebEvent.Session.TimeStamp = [datetime]::UtcNow
                    }
                    else {
                        $WebEvent.Session.TimeStamp = $data.Metadata.TimeStamp
                    }
                }
            }

            # session not in store, create a new one
            else {
                $WebEvent.Session = New-PodeSession
                $new = $true
            }

            # set data hash
            Set-PodeSessionDataHash

            # add session to response if it's new or extendible
            if ($new -or $WebEvent.Session.Extend) {
                Set-PodeSession
            }

            # assign endware for session to set cookie/header
            $WebEvent.OnEnd += @{
                Logic = {
                    if ($null -ne $WebEvent.Session) {
                        Save-PodeSession -Force
                    }
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