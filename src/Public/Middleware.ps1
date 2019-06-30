function Access
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet('Allow', 'Deny')]
        [Alias('p')]
        [string]
        $Permission,

        [Parameter(Mandatory=$true)]
        [ValidateSet('IP')]
        [Alias('t')]
        [string]
        $Type,

        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [Alias('v')]
        [object]
        $Value
    )

    # error if serverless
    Test-PodeIsServerless -FunctionName 'access' -ThrowError

    # if it's array add them all
    if ((Get-PodeType $Value).BaseName -ieq 'array') {
        $Value | ForEach-Object {
            access -Permission $Permission -Type $Type -Value $_
        }

        return
    }

    # call the appropriate access method
    switch ($Type.ToLowerInvariant())
    {
        'ip' {
            Add-PodeIPAccess -Permission $Permission -IP $Value
        }
    }
}

function Auth
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet('use', 'check')]
        [Alias('a')]
        [string]
        $Action,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [Alias('n')]
        [string]
        $Name,

        [Parameter()]
        [Alias('v')]
        [object]
        $Validator,

        [Parameter()]
        [Alias('p')]
        [scriptblock]
        $Parser,

        [Parameter()]
        [Alias('o')]
        [hashtable]
        $Options,

        [Parameter()]
        [Alias('t')]
        [string]
        $Type,

        [switch]
        [Alias('c')]
        $Custom
    )

    # for the 'use' action, ensure we have a validator. and a parser for custom types
    if ($Action -ieq 'use') {
        # was a validator passed
        if (Test-Empty $Validator) {
            throw "Authentication method '$($Name)' is missing required Validator script"
        }

        # is the validator a string/scriptblock?
        $vTypes = @('string', 'scriptblock')
        if ($vTypes -inotcontains (Get-PodeType $Validator).Name) {
            throw "Authentication method '$($Name)' has an invalid validator supplied, should be one of: $($vTypes -join ', ')"
        }

        # don't fail if custom and type supplied, and it's already defined
        if ($Custom)
        {
            $typeDefined = (![string]::IsNullOrWhiteSpace($Type) -and $PodeContext.Server.Authentications.ContainsKey($Type))
            if (!$typeDefined -and (Test-Empty $Parser)) {
                throw "Custom authentication method '$($Name)' is missing required Parser script"
            }
        }
    }

    # invoke the appropriate auth logic for the action
    switch ($Action.ToLowerInvariant())
    {
        'use' {
            Invoke-PodeAuthUse -Name $Name -Type $Type -Validator $Validator -Parser $Parser -Options $Options -Custom:$Custom
        }

        'check' {
            return (Invoke-PodeAuthCheck -Name $Name -Options $Options)
        }
    }
}

function Csrf
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet('Check', 'Middleware', 'Setup', 'Token')]
        [Alias('a')]
        [string]
        $Action,

        [Parameter()]
        [ValidateSet('DELETE', 'GET', 'HEAD', 'MERGE', 'OPTIONS', 'PATCH', 'POST', 'PUT', 'TRACE', 'STATIC')]
        [Alias('i')]
        [string[]]
        $IgnoreMethods = @('GET', 'HEAD', 'OPTIONS', 'TRACE', 'STATIC'),

        [Parameter()]
        [Alias('s')]
        [string]
        $Secret,

        [switch]
        [Alias('c')]
        $Cookie
    )

    switch ($Action.ToLowerInvariant())
    {
        'check' {
            return (Get-PodeCsrfCheck)
        }

        'middleware' {
            Set-PodeCsrfSetup -IgnoreMethods $IgnoreMethods -Secret $Secret -Cookie:$Cookie
            return (Get-PodeCsrfMiddleware)
        }

        'setup' {
            Set-PodeCsrfSetup -IgnoreMethods $IgnoreMethods -Secret $Secret -Cookie:$Cookie
        }

        'token' {
            return (New-PodeCsrfToken)
        }
    }
}

function Limit
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet('IP')]
        [Alias('t')]
        [string]
        $Type,

        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [Alias('v')]
        [object]
        $Value,

        [Parameter(Mandatory=$true)]
        [Alias('l')]
        [int]
        $Limit,

        [Parameter(Mandatory=$true)]
        [Alias('s')]
        [int]
        $Seconds,

        [switch]
        $Group
    )

    # error if serverless
    Test-PodeIsServerless -FunctionName 'limit' -ThrowError

    # if it's array add them all
    if ((Get-PodeType $Value).BaseName -ieq 'array') {
        $Value | ForEach-Object {
            limit -Type $Type -Value $_ -Limit $Limit -Seconds $Seconds -Group:$Group
        }

        return
    }

    # call the appropriate limit method
    switch ($Type.ToLowerInvariant())
    {
        'ip' {
            Add-PodeIPLimit -IP $Value -Limit $Limit -Seconds $Seconds -Group:$Group
        }
    }
}

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
        throw 'Session middleware has already been defined'
    }

    # ensure a secret was actually passed
    if (Test-Empty $Options.Secret) {
        throw 'A secret key is required for session cookies'
    }

    # ensure the override generator is a scriptblock
    if (!(Test-Empty $Options.GenerateId) -and ($Options.GenerateId -isnot 'scriptblock')) {
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

    # set options against server context
    $PodeContext.Server.Cookies.Session = @{
        'Name' = (coalesce $Options.Name 'pode.sid');
        'SecretKey' = $Options.Secret;
        'GenerateId' = (coalesce $Options.GenerateId { return (New-PodeGuid) });
        'Store' = $store;
        'Info' = @{
            'Duration' = [int]($Options.Duration);
            'Extend' = [bool]($Options.Extend);
            'Secure' = [bool]($Options.Secure);
            'Discard' = [bool]($Options.Discard);
            'HttpOnly' = [bool]($Options.HttpOnly);
        };
    }

    # return scriptblock for the session middleware
    return {
        param($e)

        # if session already set, return
        if ($e.Session) {
            return $true
        }

        try
        {
            # get the session cookie
            $_sessionInfo = $PodeContext.Server.Cookies.Session
            $e.Session = Get-PodeSessionCookie -Name $_sessionInfo.Name -Secret $_sessionInfo.SecretKey

            # if no session on browser, create a new one
            if (!$e.Session) {
                $e.Session = (New-PodeSessionCookie)
                $new = $true
            }

            # get the session's data
            elseif ($null -ne ($data = $_sessionInfo.Store.Get($e.Session.Id))) {
                $e.Session.Data = $data
                Set-PodeSessionCookieDataHash -Session $e.Session
            }

            # session not in store, create a new one
            else {
                $e.Session = (New-PodeSessionCookie)
                $new = $true
            }

            # add helper methods to session
            Set-PodeSessionCookieHelpers -Session $e.Session

            # add cookie to response if it's new or extendible
            if ($new -or $e.Session.Cookie.Extend) {
                Set-PodeSessionCookie -Session $e.Session
            }

            # assign endware for session to set cookie/storage
            $e.OnEnd += {
                param($e)

                # if auth is in use, then assign to session store
                if (!(Test-Empty $e.Auth) -and $e.Auth.Store) {
                    $e.Session.Data.Auth = $e.Auth
                }

                Invoke-ScriptBlock -ScriptBlock $e.Session.Save -Arguments @($e.Session, $true) -Splat
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