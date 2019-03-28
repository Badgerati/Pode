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

function Invoke-PodeAuthUse
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name,

        [Parameter(Mandatory=$true)]
        [object]
        $Validator,

        [Parameter()]
        [string]
        $Type,

        [Parameter()]
        [scriptblock]
        $Parser,

        [Parameter()]
        [hashtable]
        $Options,

        [switch]
        $Custom
    )

    # get the auth data
    $AuthData = (Get-PodeAuthMethod -Name $Name -Type $Type -Validator $Validator -Parser $Parser -Custom:$Custom)

    # ensure the name doesn't already exist
    if ($PodeContext.Server.Authentications.ContainsKey($AuthData.Name)) {
        throw "Authentication method '$($AuthData.Name)' already defined"
    }

    # ensure the parser/validators aren't just empty scriptblocks
    if (Test-Empty $AuthData.Parser) {
        throw "Authentication method '$($AuthData.Name)' is has no Parser ScriptBlock logic defined"
    }

    if (Test-Empty $AuthData.Validator) {
        throw "Authentication method '$($AuthData.Name)' is has no Validator ScriptBlock logic defined"
    }

    # setup object for auth method
    $obj = @{
        'Type' = $AuthData.Type;
        'Options' = $Options;
        'Parser' = $AuthData.Parser;
        'Validator' = $AuthData.Validator;
        'Custom' = $AuthData.Custom;
    }

    # apply auth method to session
    $PodeContext.Server.Authentications[$AuthData.Name] = $obj
}

function Invoke-PodeAuthCheck
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name,

        [Parameter()]
        [hashtable]
        $Options
    )

    # ensure the auth type exists
    if (!$PodeContext.Server.Authentications.ContainsKey($Name)) {
        throw "Authentication method '$($Name)' is not defined"
    }

    # coalesce the options, and set auth type for middleware
    $Options = (coalesce $Options @{})
    $Options.AuthType = $Name

    # setup the middleware logic
    $logic = {
        param($e)

        # Route options for using sessions
        $storeInSession = ($e.Middleware.Options.Session -ne $false)
        $usingSessions = (!(Test-Empty $e.Session))

        # check for logout command
        if ($e.Middleware.Options.Logout -eq $true) {
            Remove-PodeAuth -Event $e
            return (Set-PodeAuthStatus -StatusCode 302 -Options $e.Middleware.Options)
        }

        # if the session already has a user/isAuth'd, then setup method and return
        if ($usingSessions -and !(Test-Empty $e.Session.Data.Auth.User) -and $e.Session.Data.Auth.IsAuthenticated) {
            $e.Auth = $e.Session.Data.Auth
            return (Set-PodeAuthStatus -Options $e.Middleware.Options)
        }

        # check if the login flag is set, in which case just return
        if ($e.Middleware.Options.Login -eq $true) {
            if (!(Test-Empty $e.Session.Data.Auth)) {
                Remove-PodeSessionCookie -Response $e.Response -Session $e.Session
            }

            return $true
        }

        # get the auth type
        $auth = $PodeContext.Server.Authentications[$e.Middleware.Options.AuthType]

        # validate the request and get a user
        try {
            # if it's a custom type the parser will return the data for use to pass to the validator
            if ($auth.Custom) {
                $data = (Invoke-ScriptBlock -ScriptBlock $auth.Parser -Arguments @($e, $auth.Options) -Return -Splat)
                $data += $auth.Options

                $result = (Invoke-ScriptBlock -ScriptBlock $auth.Validator -Arguments $data -Return -Splat)
            }
            else {
                $result = (Invoke-ScriptBlock -ScriptBlock $auth.Parser -Arguments @($e, $auth) -Return -Splat)
            }
        }
        catch {
            $_.Exception | Out-Default
            return (Set-PodeAuthStatus -StatusCode 500 -Description $_.Exception.Message -Options $e.Middleware.Options)
        }

        # if there is no result return false (failed auth)
        if ((Test-Empty $result) -or (Test-Empty $result.User)) {
            return (Set-PodeAuthStatus -StatusCode (coalesce $result.Code 401) `
                -Description $result.Message -Options $e.Middleware.Options)
        }

        # assign the user to the session, and wire up a quick method
        $e.Auth = @{}
        $e.Auth.User = $result.User
        $e.Auth.IsAuthenticated = $true
        $e.Auth.Store = $storeInSession

        # continue
        return (Set-PodeAuthStatus -Options $e.Middleware.Options)
    }

    # return the middleware
    return @{
        'Logic' = $logic;
        'Options' = $Options;
    }
}

function Get-PodeAuthMethod
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name,

        [Parameter(Mandatory=$true)]
        [object]
        $Validator,

        [Parameter()]
        [string]
        $Type,

        [Parameter()]
        [scriptblock]
        $Parser,

        [switch]
        $Custom
    )

    # set type as name, if no type passed
    if ([string]::IsNullOrWhiteSpace($Type)) {
        $Type = $Name
    }

    # if the validator is a string - check and get an inbuilt validator
    if ((Get-PodeType $Validator).Name -ieq 'string') {
        $Validator = (Get-PodeAuthValidator -Validator $Validator)
    }

    # first, is it just a custom type?
    if ($Custom) {
        # if type supplied, re-use an already defined custom type's parser
        if ($PodeContext.Server.Authentications.ContainsKey($Type))
        {
            $Parser = $PodeContext.Server.Authentications[$Type].Parser
        }

        return @{
            'Name' = $Name;
            'Type' = $Type;
            'Custom' = $true;
            'Parser' = $Parser;
            'Validator' = $Validator;
        }
    }

    # otherwise, check the inbuilt ones
    switch ($Type.ToLowerInvariant())
    {
        'basic' {
            return (Get-PodeAuthBasic -Name $Name -ScriptBlock $Validator)
        }

        'form' {
            return (Get-PodeAuthForm -Name $Name -ScriptBlock $Validator)
        }
    }

    # if we get here, check if a parser was passed for custom type
    if (Test-Empty $Parser) {
        throw "Authentication method '$($Type)' does not exist as an inbuilt type, nor has a Parser been passed for a custom type"
    }

    # a parser was passed, it is a custom type
    return @{
        'Name' = $Name;
        'Type' = $Type;
        'Custom' = $true;
        'Parser' = $Parser;
        'Validator' = $Validator;
    }
}

function Remove-PodeAuth
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $Event
    )

    # blank out the auth
    $Event.Auth = @{}

    # if a session auth is found, blank it
    if (!(Test-Empty $Event.Session.Data.Auth)) {
        $Event.Session.Data.Remove('Auth')
    }

    # redirect to a failure url, or onto the current path?
    if (Test-Empty $Event.Middleware.Options.FailureUrl) {
        $Event.Middleware.Options.FailureUrl = $Event.Request.Url.AbsolutePath
    }

    # Delete the session (remove from store, blank it, and remove from Response)
    Remove-PodeSessionCookie -Response $Event.Response -Session $Event.Session
}

function Set-PodeAuthStatus
{
    param (
        [Parameter()]
        [int]
        $StatusCode = 0,

        [Parameter()]
        [string]
        $Description,

        [Parameter()]
        [hashtable]
        $Options
    )

    # if a statuscode supplied, assume failure
    if ($StatusCode -gt 0)
    {
        # override description with the failureMessage if supplied
        $Description = (coalesce $Options.FailureMessage $Description)

        # add error to flash if flagged
        if ([bool]$Options.FailureFlash) {
            flash add 'auth-error' $Description
        }

        # check if we have a failure url redirect
        if (!(Test-Empty $Options.FailureUrl)) {
            redirect $Options.FailureUrl
        }
        else {
            status $StatusCode $Description
        }

        return $false
    }

    # if no statuscode, success
    else
    {
        # check if we have a success url redirect
        if (!(Test-Empty $Options.SuccessUrl)) {
            redirect $Options.SuccessUrl
            return $false
        }

        return $true
    }
}

function Get-PodeAuthValidator
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Validator
    )

    # source the script for the validator
    switch ($Validator.ToLowerInvariant()) {
        'windows-ad' {
            # Check PowerShell/OS version
            $version = $PSVersionTable.PSVersion
            if ((Test-IsUnix) -or ($version.Major -eq 6 -and $version.Minor -eq 0)) {
                throw 'Windows AD authentication is currently only supported on Windows PowerShell, and Windows PowerShell Core v6.1+'
            }

            # setup the AD vaidator
            return {
                param($username, $password, $options)

                $fqdn = $options.Fqdn
                if (Test-Empty $fqdn) {
                    $fqdn = $env:USERDNSDOMAIN
                }

                $ad = (New-Object System.DirectoryServices.DirectoryEntry "LDAP://$($fqdn)", "$($username)", "$($password)")
                if (Test-Empty $ad.distinguishedName) {
                    return @{ 'Message' = 'Invalid credentials supplied' }
                }

                return @{ 'User' = @{
                    'Username' = $ad.psbase.username;
                    'FQDN' = $fqdn;
                } }
            }
        }

        default {
            throw "An inbuilt validator does not exist for '$($Validator)'"
        }
    }
}

function Get-PodeAuthBasic
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name,

        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [scriptblock]
        $ScriptBlock
    )

    $parser = {
        param($e, $auth)

        # get the auth header
        $header = $e.Request.Headers['Authorization']
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

        return (Invoke-ScriptBlock -ScriptBlock $auth.Validator -Arguments @($u, $p, $auth.Options) -Return -Splat)
    }

    return @{
        'Name' = $Name;
        'Type' = 'Basic';
        'Custom' = $false;
        'Parser' = $parser;
        'Validator' = $ScriptBlock;
    }
}

function Get-PodeAuthForm
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name,

        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [scriptblock]
        $ScriptBlock
    )

    $parser = {
        param($e, $auth)

        # get user/pass keys to get from payload
        $userField = (coalesce $auth.Options.UsernameField 'username')
        $passField = (coalesce $auth.Options.PasswordField 'password')

        # get the user/pass
        $username = $e.Data.$userField
        $password = $e.Data.$passField

        # if either are empty, deny
        if ((Test-Empty $username) -or (Test-Empty $password)) {
            return @{
                'User' = $null;
                'Message' = 'Username or Password not supplied';
                'Code' = 401;
            }
        }

        # validate and return
        return (Invoke-ScriptBlock -ScriptBlock $auth.Validator -Arguments @($username, $password, $auth.Options) -Return -Splat)
    }

    return @{
        'Name' = $Name;
        'Type' = 'Form';
        'Custom' = $false;
        'Parser' = $parser;
        'Validator' = $ScriptBlock;
    }
}