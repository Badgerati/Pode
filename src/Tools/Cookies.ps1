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

    # bind session middleware to attach session function
    middleware {
        param($s)

        $s.Session = @{}

        # get a session
        $s.Session | Add-Member -MemberType ScriptMethod -Name Get -Value {
            param($req, $name)

            $cookie = $req.Cookies[$name]
            if ($null -eq $cookie) {
                return $null
            }

            $signedValue = $cookie.Value
            if (!$signedValue -or !$signedValue.StartsWith('s|')) {
                return $null
            }

            $signedValue = $signedValue.Substring(2)
            return (Invoke-CookieUnsign -Signature $signedValue -Secret $PodeSession.Server.Cookies.Session.SecretKey)
        }

        # set a session
        $s.Session | Add-Member -MemberType ScriptMethod -Name Set -Value {
            param($res, $name, $sessionId)

            $signedValue = "s|$(Invoke-CookieSign -Value $sessionId -Secret $PodeSession.Server.Cookies.Session.SecretKey)"

            $cookie = [System.Net.Cookie]::new($name, $signedValue)
            $cookie.Expires = [datetime]::Now.AddDays(1)

            $res.AppendCookie($cookie) | Out-Null
        }

        return $true
    }
}