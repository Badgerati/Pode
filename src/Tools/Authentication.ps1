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
        'Validator' = $Type.Validator;
    }

    $obj | Add-Member -MemberType ScriptMethod -Name Parse -Value $Type.Parser
    #$obj | Add-Member -MemberType ScriptMethod -Name Validate -Value $Type.Validator

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
    $logic ={
        param($s)

        # TODO: Route options for using sessions, and failure redirects
        $useSessions = ($s.Middleware.Options.Session -ne $false)

        # if the session already has a user/isAuth'd, then setup method and return
        if ($useSessions -and !(Test-Empty $s.Session.Data.Auth.User) -and $s.Session.Data.Auth.IsAuthenticated) {
            $s.Session.Auth = $s.Session.Data.Auth

            $s | Add-Member -MemberType ScriptMethod -Name User -Value {
                return $this.Session.Auth.User
            }

            return $true
        }

        # get the auth type
        $auth = $PodeSession.Server.Authentications[$s.Middleware.Options.AuthType]

        # validate the request and get a user
        $result = $auth.Parse($s, $auth)

        # if there is no result return false (failed auth)
        if ((Test-Empty $result) -or (Test-Empty $result.User)) {
            status 401 $result.Message
            return $false
        }

        # assign the user to the session, and wire up a quick method
        $s.Session.Auth = @{}
        $s.Session.Auth.User = $result.User
        $s.Session.Auth.IsAuthenticated = $true
        $s.Session.Auth.Store = $useSessions

        $s | Add-Member -MemberType ScriptMethod -Name User -Value {
            return $this.Session.Auth.User
        }

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

        # get the auth header and atoms
        $header = $s.Request.Headers['Authorization']
        $atoms = $header -isplit '\s+'

        # ensure the first atom is basic (or opt override)
        $authType = (coalesce $auth.Options.Name 'Basic')
        if ($atoms[0] -ine $authType) {
            return @{
                'User' = $null;
                'Message' = "Header is not $($authType) Authorization";
            }
        }

        # decode the aut header
        $encType = (coalesce $auth.Options.Encoding 'ISO-8859-1')
        $enc = [System.Text.Encoding]::GetEncoding($encType)
        $decoded = $enc.GetString([System.Convert]::FromBase64String($atoms[1]))
        
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