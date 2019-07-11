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
    if (Test-IsEmpty $AuthData.Parser) {
        throw "Authentication method '$($AuthData.Name)' is has no Parser ScriptBlock logic defined"
    }

    if (Test-IsEmpty $AuthData.Validator) {
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
    $Options = (Protect-PodeValue -Value $Options -Default @{})
    $Options.AuthType = $Name

    # setup the middleware logic
    $logic = {
        param($e)

        # Route options for using sessions
        $storeInSession = ($e.Middleware.Options.Session -ne $false)
        $usingSessions = (!(Test-IsEmpty $e.Session))

        # check for logout command
        if ($e.Middleware.Options.Logout -eq $true) {
            Remove-PodeAuth -Event $e
            return (Set-PodeAuthStatus -StatusCode 302 -Options $e.Middleware.Options)
        }

        # if the session already has a user/isAuth'd, then setup method and return
        if ($usingSessions -and !(Test-IsEmpty $e.Session.Data.Auth.User) -and $e.Session.Data.Auth.IsAuthenticated) {
            $e.Auth = $e.Session.Data.Auth
            return (Set-PodeAuthStatus -Options $e.Middleware.Options)
        }

        # check if the login flag is set, in which case just return
        if ($e.Middleware.Options.Login -eq $true) {
            if (!(Test-IsEmpty $e.Session.Data.Auth)) {
                Remove-PodeSessionCookie -Session $e.Session
            }

            return $true
        }

        # get the auth type
        $auth = $PodeContext.Server.Authentications[$e.Middleware.Options.AuthType]

        # validate the request and get a user
        try {
            # if it's a custom type the parser will return the data for use to pass to the validator
            if ($auth.Custom) {
                $data = (Invoke-PodeScriptBlock -ScriptBlock $auth.Parser -Arguments @($e, $auth.Options) -Return -Splat)
                $data += $auth.Options

                $result = (Invoke-PodeScriptBlock -ScriptBlock $auth.Validator -Arguments $data -Return -Splat)
            }
            else {
                $result = (Invoke-PodeScriptBlock -ScriptBlock $auth.Parser -Arguments @($e, $auth) -Return -Splat)
            }
        }
        catch {
            $_.Exception | Out-Default
            return (Set-PodeAuthStatus -StatusCode 500 -Description $_.Exception.Message -Options $e.Middleware.Options)
        }

        # if there is no result return false (failed auth)
        if ((Test-IsEmpty $result) -or (Test-IsEmpty $result.User)) {
            return (Set-PodeAuthStatus -StatusCode (Protect-PodeValue -Value $result.Code -Default 401) `
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
    if (Test-IsEmpty $Parser) {
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
    if (!(Test-IsEmpty $Event.Session.Data.Auth)) {
        $Event.Session.Data.Remove('Auth')
    }

    # redirect to a failure url, or onto the current path?
    if (Test-IsEmpty $Event.Middleware.Options.FailureUrl) {
        $Event.Middleware.Options.FailureUrl = $Event.Request.Url.AbsolutePath
    }

    # Delete the session (remove from store, blank it, and remove from Response)
    Remove-PodeSessionCookie -Session $Event.Session
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
        $Description = (Protect-PodeValue -Value $Options.FailureMessage -Default $Description)

        # add error to flash if flagged
        if ([bool]$Options.FailureFlash) {
            Add-PodeFlashMessage -Name 'auth-error' -Message $Description
        }

        # check if we have a failure url redirect
        if (!(Test-IsEmpty $Options.FailureUrl)) {
            Move-PodeResponseUrl -Url $Options.FailureUrl
        }
        else {
            Set-PodeResponseStatus -Code $StatusCode -Description $Description
        }

        return $false
    }

    # if no statuscode, success
    else
    {
        # check if we have a success url redirect
        if (!(Test-IsEmpty $Options.SuccessUrl)) {
            Move-PodeResponseUrl -Url $Options.SuccessUrl
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

                # validate and retrieve the AD user
                $result = Get-PodeAuthADUser -FQDN $options.Fqdn -Username $username -Password $password

                # if there's a message, fail and return the message
                if (!(Test-IsEmpty $result.Message)) {
                    return $result
                }

                # if there's no user, then, err, oops
                if (Test-IsEmpty $result.User) {
                    return @{ 'Message' = 'An unexpected error occured' }
                }

                # if there are no groups/users supplied, return the user
                if ((Test-IsEmpty $options.Users) -and (Test-IsEmpty $options.Groups)){
                    return $result
                }

                # before checking supplied groups, is the user in the supplied list of authorised users?
                if (!(Test-IsEmpty $options.Users) -and (@($options.Users) -icontains $result.User.Username)) {
                    return $result
                }

                # if there are groups supplied, check the user is a member of one
                if (!(Test-IsEmpty $options.Groups)) {
                    foreach ($group in $options.Groups) {
                        if (@($result.User.Groups) -icontains $group) {
                            return $result
                        }
                    }
                }

                # else, they shall not pass!
                return @{ 'Message' = 'You are not authorised to access this website' }
            }
        }

        default {
            throw "An inbuilt validator does not exist for '$($Validator)'"
        }
    }
}

function Get-PodeAuthADUser
{
    param (
        [Parameter()]
        [string]
        $FQDN,

        [Parameter()]
        [string]
        $Username,

        [Parameter()]
        [string]
        $Password
    )

    try
    {
        # setup the dns domain
        if (Test-IsEmpty $FQDN) {
            $FQDN = $env:USERDNSDOMAIN
        }

        # validate the user's AD creds
        $ad = (New-Object System.DirectoryServices.DirectoryEntry "LDAP://$($FQDN)", "$($Username)", "$($Password)")
        if (Test-IsEmpty $ad.distinguishedName) {
            return @{ 'Message' = 'Invalid credentials supplied' }
        }

        # generate query to find user/groups
        $query = New-Object System.DirectoryServices.DirectorySearcher $ad
        $query.filter = "(&(objectCategory=person)(samaccountname=$($Username)))"

        $user = $query.FindOne().Properties
        if (Test-IsEmpty $user) {
            return @{ 'Message' = 'User not found in Active Directory' }
        }

        # get the users groups
        $groups = Get-PodeAuthADGroups -Query $query -CategoryName $Username -CategoryType 'person'

        # return the user
        return @{ 'User' = @{
            'Username' = $Username;
            'Name' = @($user.name)[0];
            'FQDN' = $FQDN;
            'Groups' = $groups;
        } }
    }
    finally {
        if (!(Test-IsEmpty $ad.distinguishedName)) {
            Close-PodeDisposable -Disposable $query
            Close-PodeDisposable -Disposable $ad -Close
        }
    }
}

function Get-PodeAuthADGroups
{
    param (
        [Parameter(Mandatory=$true)]
        [System.DirectoryServices.DirectorySearcher]
        $Query,

        [Parameter(Mandatory=$true)]
        [string]
        $CategoryName,

        [Parameter(Mandatory=$true)]
        [ValidateSet('group', 'person')]
        [string]
        $CategoryType,

        [Parameter()]
        [hashtable]
        $GroupsFound = $null
    )

    # setup found groups
    if ($null -eq $GroupsFound) {
        $GroupsFound = @{}
    }

    # get the groups for the category
    $Query.filter = "(&(objectCategory=$($CategoryType))(samaccountname=$($CategoryName)))"

    $groups = @{}
    foreach ($member in $Query.FindOne().Properties.memberof) {
        if ($member -imatch '^CN=(?<group>.+?),') {
            $g = $Matches['group']
            $groups[$g] = ($member -imatch '=builtin,')
        }
    }

    foreach ($group in $groups.Keys) {
        # don't bother if we've already looked up the group
        if ($GroupsFound.ContainsKey($group)) {
            continue
        }

        # add group to checked groups
        $GroupsFound[$group] = $true

        # don't bother if it's inbuilt
        if ($groups[$group]) {
            continue
        }

        # get the groups
        Get-PodeAuthADGroups -Query $Query -CategoryName $group -CategoryType 'group' -GroupsFound $GroupsFound
    }

    if ($CategoryType -ieq 'person') {
        return $GroupsFound.Keys
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
        $header = (Get-PodeHeader -Name 'Authorization')
        if ($null -eq $header) {
            return @{
                'User' = $null;
                'Message' = 'No Authorization header found';
                'Code' = 401;
            }
        }

        # ensure the first atom is basic (or opt override)
        $atoms = $header -isplit '\s+'
        $authType = (Protect-PodeValue -Value $auth.Options.Name -Default 'Basic')

        if ($atoms[0] -ine $authType) {
            return @{
                'User' = $null;
                'Message' = "Header is not $($authType) Authorization";
            }
        }

        # decode the aut header
        $encType = (Protect-PodeValue -Value $auth.Options.Encoding -Default 'ISO-8859-1')

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

        return (Invoke-PodeScriptBlock -ScriptBlock $auth.Validator -Arguments @($u, $p, $auth.Options) -Return -Splat)
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
        $userField = (Protect-PodeValue -Value $auth.Options.UsernameField -Default 'username')
        $passField = (Protect-PodeValue -Value $auth.Options.PasswordField -Default 'password')

        # get the user/pass
        $username = $e.Data.$userField
        $password = $e.Data.$passField

        # if either are empty, deny
        if ((Test-IsEmpty $username) -or (Test-IsEmpty $password)) {
            return @{
                'User' = $null;
                'Message' = 'Username or Password not supplied';
                'Code' = 401;
            }
        }

        # validate and return
        return (Invoke-PodeScriptBlock -ScriptBlock $auth.Validator -Arguments @($username, $password, $auth.Options) -Return -Splat)
    }

    return @{
        'Name' = $Name;
        'Type' = 'Form';
        'Custom' = $false;
        'Parser' = $parser;
        'Validator' = $ScriptBlock;
    }
}