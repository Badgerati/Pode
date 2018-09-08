function Auth
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet('USE', 'CHECK')]
        [string]
        $Action,

        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $Type,

        [Parameter()]
        [hashtable]
        $Options
    )

    $_type = (Get-Type $Type).Name
    if ($Action -ieq 'USE' -and $_type -ine 'hashtable') {
        throw "When setting to use a new Authentication, the Type should be a Hashtable but got: $($_type)"
    }

    if ($Action -ieq 'CHECK' -and $_type -ine 'string') {
        throw "When checking an Authentication method, the Type should be a String but got: $($_type)"
    }

    switch ($Action.ToLowerInvariant())
    {
        'use' {
            Invoke-AuthUse -Type $Type -Options $Options
        }

        'check' {
            return (Invoke-AuthCheck -Type $Type -Options $Options)
        }
    }
}

function Invoke-AuthUse
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [hashtable]
        $Type,

        [Parameter()]
        [hashtable]
        $Options
    )

    # ensure that the hashtable has the required keys
    if (!$Type.ContainsKey('Name')) {
        throw "Type Hashtable from Authentication function is missing the Name key"
    }

    if (!$Type.ContainsKey('Parser')) {
        throw "Type Hashtable from Authentication function is missing the Parser key"
    }

    if (!$Type.ContainsKey('Validator')) {
        throw "Type Hashtable from Authentication function is missing the Validator key"
    }

    # ensure the name doesn't already exist
    if ($PodeSession.Server.Authentications.ContainsKey($Type.Name)) {
        throw "Authentication logic with name '$($Type.Name)' already defined"
    }

    # ensure the parser/validators aren't just empty scriptblocks
    if (Test-Empty $Type.Parser) {
        throw "Authentication method '$($Type.Name)' is has no Parser ScriptBlock logic defined"
    }

    if (Test-Empty $Type.Validator) {
        throw "Authentication method '$($Type.Name)' is has no Validator ScriptBlock logic defined"
    }

    # setup object for auth method
    $obj = @{
        'Options' = $Options;
        'Parser' = $Type.Parser;
        'Validator' = $Type.Validator;
    }

    # apply auth method to session
    $PodeSession.Server.Authentications[$Type.Name] = $obj
}

function Invoke-AuthCheck
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Type,

        [Parameter()]
        [hashtable]
        $Options
    )

    # ensure the auth type exists
    if (!$PodeSession.Server.Authentications.ContainsKey($Type)) {
        throw "Authentication type '$($Type.Name)' is not defined"
    }

    # coalesce the options, and set auth type for middleware
    $Options = (coalesce $Options @{})
    $Options.AuthType = $Type

    # setup the middleware logic
    $logic = {
        param($s)

        # TODO: Route options for using sessions, and failure redirects
        $storeInSession = ($s.Middleware.Options.Session -ne $false)
        $usingSessions = (!(Test-Empty $s.Session))

        # if the session already has a user/isAuth'd, then setup method and return
        if ($usingSessions -and !(Test-Empty $s.Session.Data.Auth.User) -and $s.Session.Data.Auth.IsAuthenticated) {
            $s.Auth = $s.Session.Data.Auth
            return $true
        }

        # get the auth type
        $auth = $PodeSession.Server.Authentications[$s.Middleware.Options.AuthType]

        # validate the request and get a user
        try {
            $result = (Invoke-ScriptBlock -ScriptBlock $auth.Parser -Arguments @($s, $auth) -Return -Splat)
        }
        catch {
            $_.Exception | Out-Default
            status 500
            return $false
        }

        # if there is no result return false (failed auth)
        if ((Test-Empty $result) -or (Test-Empty $result.User)) {
            if (Test-Empty $result) {
                'here' | Out-Default
            }

            status (coalesce $result.Code 401) $result.Message
            return $false
        }

        # assign the user to the session, and wire up a quick method
        $s.Auth = @{}
        $s.Auth.User = $result.User
        $s.Auth.IsAuthenticated = $true
        $s.Auth.Store = $storeInSession

        # continue
        return $true
    }

    # return the middleware
    return @{
        'Logic' = $logic;
        'Options' = $Options;
    }
}

function Get-AuthBasic
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [scriptblock]
        $ScriptBlock
    )

    $parser = {
        param($s, $auth)

        # get the auth header
        $header = $s.Request.Headers['Authorization']
        if ($null -eq $header) {
            return @{
                'User' = $null;
                'Message' = 'No Authorization header found';
                'Code' = 401;
            }
        }

        # ensure the first atom is basic (or opt override)
        $atoms = $header -isplit '\s+'
        $authType = (coalesce $auth.Options.Name 'Basic')

        if ($atoms[0] -ine $authType) {
            return @{
                'User' = $null;
                'Message' = "Header is not $($authType) Authorization";
            }
        }

        # decode the aut header
        $encType = (coalesce $auth.Options.Encoding 'ISO-8859-1')

        try {
            $enc = [System.Text.Encoding]::GetEncoding($encType)
        }
        catch {
            return @{
                'User' = $null;
                'Message' = 'Invalid encoding specified for Authorization';
                'Code' = 400;
            }
        }

        try {
            $decoded = $enc.GetString([System.Convert]::FromBase64String($atoms[1]))
        }
        catch {
            return @{
                'User' = $null;
                'Message' = 'Invalid Base64 string found in Authorization header';
                'Code' = 400;
            }
        }

        # validate and return user/result
        $index = $decoded.IndexOf(':')
        $u = $decoded.Substring(0, $index)
        $p = $decoded.Substring($index + 1)

        return (Invoke-ScriptBlock -ScriptBlock $auth.Validator -Arguments @($u, $p) -Return -Splat)
    }

    return @{
        'Name' = 'Basic';
        'Parser' = $parser;
        'Validator' = $ScriptBlock;
    }
}