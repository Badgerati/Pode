function Session
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [hashtable]
        $Options
    )

    # assign secret to to active server
    if (Test-Empty $Options.Secret) {
        throw 'A secret key is required for session cookies'
    }

    $PodeSession.Server.Cookies.Session.SecretKey = $Options.Secret
    Add-PodeSessionFunctions -Options $Options

    # bind session middleware to attach session function
    middleware {
        param($s)

        $s.Session = $PodeSession.Server.Cookies.Session

        #$s.Session = @{}

        # get a session
        #$s.Session | Add-Member -MemberType ScriptMethod -Name Get -Value {
        #    param($req, $name)

        #    $cookie = $req.Cookies[$name]
        #    if ($null -eq $cookie -or !$cookie.Value) {
        #        return $null
        #    }

        #    return (Invoke-CookieUnsign -Signature $cookie.Value -Secret $PodeSession.Server.Cookies.Session.SecretKey)
        #}

        # set a session
        #$s.Session | Add-Member -MemberType ScriptMethod -Name Set -Value {
        #    param($res, $name, $sessionId, $expires)

        #    $signedValue = (Invoke-CookieSign -Value $sessionId -Secret $PodeSession.Server.Cookies.Session.SecretKey)

        #    $cookie = [System.Net.Cookie]::new($name, $signedValue)
        #    $cookie.Expires = $expires

        #    $res.AppendCookie($cookie) | Out-Null
        #}

        return $true
    }
}

function Add-PodeSessionFunctions
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [hashtable]
        $Options
    )

    # get a sessionId from cookie name (ensures cookie is signed), and returns the session/stored data
    $PodeSession.Server.Cookies.Session | Add-Member -MemberType ScriptMethod -Name GetSession -Value {
        param($req, $name)

        # get the session from cookie
        $cookie = $req.Cookies[$name]
        if ($null -eq $cookie -or !$cookie.Value) {
            return $null
        }

        # ensure the session was signed
        $session = (Invoke-CookieUnsign -Signature $cookie.Value -Secret $this.SecretKey)

        # get session data

        # return data
        return @{
            'SessionId' = $session;
            'Data' = $null;
        }
    }

    # set a sessionId on a cookie, and stores some data against it
    $PodeSession.Server.Cookies.Session | Add-Member -MemberType ScriptMethod -Name SetSession -Value {
        param($res, $name, $sessionId, $data, $expires)

        # ensure the session doesn't already exist

        # sign the session
        $signedValue = (Invoke-CookieSign -Value $sessionId -Secret $this.SecretKey)

        # create a new cookie, and set expiry
        $cookie = [System.Net.Cookie]::new($name, $signedValue)
        $cookie.Expires = $expires

        # store data against the session

        # assign cookie to response
        $res.AppendCookie($cookie) | Out-Null
    }

    # deletes the sessionId from the store
    $PodeSession.Server.Cookies.Session | Add-Member -MemberType ScriptMethod -Name RemoveSession -Value {
        param($res, $sessionId)

        # remove any data stored for the session
    }

    # returns any stored data for a sessionId
    $PodeSession.Server.Cookies.Session | Add-Member -MemberType ScriptMethod -Name GetSessionData -Value {
        param($res, $sessionId)

        # get any data stored for the session

        # return the data
        return @{
            'SessionId' = $sessionId;
            'Data' = $null;
        }
    }

    # set some data for a stored sessionId (overwrite existing data)
    $PodeSession.Server.Cookies.Session | Add-Member -MemberType ScriptMethod -Name SetSessionData -Value {
        param($res, $sessionId, $data)

        # store data against the session
    }

    # generate a new sessionId (overridable)
    $PodeSession.Server.Cookies.Session | Add-Member -MemberType ScriptMethod -Name GenerateSessionId -Value {
        return ([guid]::NewGuid()).ToString()
    }

    # checks that a session is stored in memory (returns true/false)
    $PodeSession.Server.Cookies.Session | Add-Member -MemberType ScriptMethod -Name IsSessionValid -Value {
        param($res, $sessionId, $data)

        # check if the session exists in the store

        return $true
    }
}