function New-PodeSession {
    return @{
        Name      = $PodeContext.Server.Sessions.Name
        Id        = (Invoke-PodeScriptBlock -ScriptBlock $PodeContext.Server.Sessions.GenerateId -Return)
        Extend    = $PodeContext.Server.Sessions.Info.Extend
        TimeStamp = [datetime]::UtcNow
        Data      = @{}
    }
}

function ConvertTo-PodeSessionStrictSecret {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Secret
    )

    return "$($Secret);$($WebEvent.Request.UserAgent);$($WebEvent.Request.RemoteEndPoint.Address.IPAddressToString)"
}

function Set-PodeSession {
    if ($null -eq $WebEvent.Session) {
        throw 'there is no session available to set on the response'
    }

    $secret = $PodeContext.Server.Sessions.Secret

    # covert secret to strict mode
    if ($PodeContext.Server.Sessions.Info.Strict) {
        $secret = ConvertTo-PodeSessionStrictSecret -Secret $secret
    }

    # set session on header
    if ($PodeContext.Server.Sessions.Info.UseHeaders) {
        Set-PodeHeader -Name $WebEvent.Session.Name -Value $WebEvent.Session.Id -Secret $secret
    }

    # set session as cookie
    else {
        $null = Set-PodeCookie `
            -Name $WebEvent.Session.Name `
            -Value $WebEvent.Session.Id `
            -Secret $secret `
            -ExpiryDate (Get-PodeSessionExpiry) `
            -HttpOnly:$PodeContext.Server.Sessions.Info.HttpOnly `
            -Secure:$PodeContext.Server.Sessions.Info.Secure
    }
}

function Get-PodeSession {
    $secret = $PodeContext.Server.Sessions.Secret
    $value = $null
    $name = $PodeContext.Server.Sessions.Name

    # covert secret to strict mode
    if ($PodeContext.Server.Sessions.Info.Strict) {
        $secret = ConvertTo-PodeSessionStrictSecret -Secret $secret
    }

    # session from header
    if ($PodeContext.Server.Sessions.Info.UseHeaders) {
        # check that the header is validly signed
        if (!(Test-PodeHeaderSigned -Name $PodeContext.Server.Sessions.Name -Secret $secret)) {
            return $null
        }

        # get the header from the request
        $value = Get-PodeHeader -Name $PodeContext.Server.Sessions.Name -Secret $secret
        if ([string]::IsNullOrWhiteSpace($value)) {
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
        if ([string]::IsNullOrWhiteSpace($cookie)) {
            return $null
        }

        # get details from cookie
        $name = $cookie.Name
        $value = $cookie.Value
    }

    # generate the session data
    $data = @{
        Name      = $name
        Id        = $value
        Extend    = $PodeContext.Server.Sessions.Info.Extend
        TimeStamp = $null
        Data      = @{}
    }

    return $data
}

function Revoke-PodeSession {
    # do nothing if no current session
    if ($null -eq $WebEvent.Session) {
        return
    }

    # remove from cookie
    if (!$PodeContext.Server.Sessions.Info.UseHeaders) {
        Remove-PodeCookie -Name $WebEvent.Session.Name
    }

    # remove session from store
    $null = Invoke-PodeScriptBlock -ScriptBlock $WebEvent.Session.Delete

    # blank the session
    $WebEvent.Session.Clear()
}

function Set-PodeSessionDataHash {
    if ($null -eq $WebEvent.Session) {
        throw 'No session available to calculate data hash'
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

function Set-PodeSessionHelpers {
    if ($null -eq $WebEvent.Session) {
        throw 'No session available to set helpers'
    }

    # force save a session's data to the store
    $WebEvent.Session | Add-Member -MemberType NoteProperty -Name Save -Value {
        param($check)

        # the current session
        $session = $WebEvent.Session

        # do nothing if session has no ID
        if ([string]::IsNullOrWhiteSpace($session.Id)) {
            return
        }

        # only save if check and hashes different, but not if extending expiry or updated
        if (!$session.Extend -and $check -and (Test-PodeSessionDataHash)) {
            return
        }

        # generate the expiry
        $expiry = Get-PodeSessionExpiry

        # the data to save - which will be the data, some extra metadata
        $data = @{
            Metadata = @{
                TimeStamp = $session.TimeStamp
            }
            Data     = $session.Data
        }

        # save session data to store
        $null = Invoke-PodeScriptBlock -ScriptBlock $PodeContext.Server.Sessions.Store.Set -Arguments @($session.Id, $data, $expiry) -Splat

        # update session's data hash
        Set-PodeSessionDataHash
    }

    # delete the current session
    $WebEvent.Session | Add-Member -MemberType NoteProperty -Name Delete -Value {
        # the current session
        $session = $WebEvent.Session

        # remove data from store
        $null = Invoke-PodeScriptBlock -ScriptBlock $PodeContext.Server.Sessions.Store.Delete -Arguments $session.Id

        # clear session
        $session.Clear()
    }
}

function Get-PodeSessionInMemStore {
    $store = New-Object -TypeName psobject

    # add in-mem storage
    $store | Add-Member -MemberType NoteProperty -Name Memory -Value @{}

    # delete a sessionId and data
    $store | Add-Member -MemberType NoteProperty -Name Delete -Value {
        param($sessionId)
        $null = $PodeContext.Server.Sessions.Store.Memory.Remove($sessionId)
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
        $store = $PodeContext.Server.Sessions.Store
        if (Test-PodeIsEmpty $store.Memory) {
            return
        }

        # remove sessions that have expired
        $now = [DateTime]::UtcNow
        foreach ($key in $store.Memory.Keys) {
            if ($store.Memory[$key].Expiry -lt $now) {
                $null = $store.Memory.Remove($key)
            }
        }
    }
}

function Test-PodeSessionsConfigured {
    return (($null -ne $PodeContext.Server.Sessions) -and ($PodeContext.Server.Sessions.Count -gt 0))
}

function Test-PodeSessionsInUse {
    return (($null -ne $WebEvent.Session) -and ($WebEvent.Session.Count -gt 0))
}

function Get-PodeSessionData {
    param(
        [Parameter()]
        [string]
        $SessionId
    )

    return (Invoke-PodeScriptBlock -ScriptBlock $PodeContext.Server.Sessions.Store.Get -Arguments $SessionId -Return)
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
            elseif ($null -ne ($data = (Get-PodeSessionData -SessionId $WebEvent.Session.Id))) {
                if ($null -eq $data.Metadata) {
                    $WebEvent.Session.Data = $data
                    $WebEvent.Session.TimeStamp = [datetime]::UtcNow
                }
                else {
                    $WebEvent.Session.Data = $data.Data
                    $WebEvent.Session.TimeStamp = $data.Metadata.TimeStamp
                }
            }

            # session not in store, create a new one
            else {
                $WebEvent.Session = New-PodeSession
                $new = $true
            }

            # set data hash
            Set-PodeSessionDataHash

            # add helper methods to current session
            Set-PodeSessionHelpers

            # add session to response if it's new or extendible
            if ($new -or $WebEvent.Session.Extend) {
                Set-PodeSession
            }

            # assign endware for session to set cookie/header
            $WebEvent.OnEnd += @{
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