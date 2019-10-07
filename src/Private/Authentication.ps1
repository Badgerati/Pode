function Get-PodeAuthBasicType
{
    return {
        param($e, $options)

        # get the auth header
        $header = (Get-PodeHeader -Name 'Authorization')
        if ($null -eq $header) {
            return @{
                Message = 'No Authorization header found'
                Code = 401
            }
        }

        # ensure the first atom is basic (or opt override)
        $atoms = $header -isplit '\s+'
        if ($atoms[0] -ine $options.HeaderTag) {
            return @{
                Message = "Header is not $($options.HeaderTag) Authorization"
                Code = 400
            }
        }

        # decode the aut header
        try {
            $enc = [System.Text.Encoding]::GetEncoding($options.Encoding)
        }
        catch {
            return @{
                Message = 'Invalid encoding specified for Authorization'
                Code = 400
            }
        }

        try {
            $decoded = $enc.GetString([System.Convert]::FromBase64String($atoms[1]))
        }
        catch {
            return @{
                Message = 'Invalid Base64 string found in Authorization header'
                Code = 400
            }
        }

        # validate and return user/result
        $index = $decoded.IndexOf(':')
        $username = $decoded.Substring(0, $index)
        $password = $decoded.Substring($index + 1)

        # return data for calling validator
        return @($username, $password)
    }
}

function Get-PodeAuthFormType
{
    return {
        param($e, $options)

        # get user/pass keys to get from payload
        $userField = $options.Fields.Username
        $passField = $options.Fields.Password

        # get the user/pass
        $username = $e.Data.$userField
        $password = $e.Data.$passField

        # if either are empty, fail auth
        if ([string]::IsNullOrWhiteSpace($username) -or [string]::IsNullOrWhiteSpace($password)) {
            return @{
                Message = 'Username or Password not supplied'
                Code = 401
            }
        }

        # return data for calling validator
        return @($username, $password)
    }
}

function Get-PodeAuthInbuiltMethod
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet('WindowsAd')]
        [string]
        $Type
    )

    switch ($Type.ToLowerInvariant())
    {
        'windowsad' {
            $script = {
                param($username, $password, $options)

                # validate and retrieve the AD user
                $noGroups = $options.NoGroups
                $result = Get-PodeAuthADUser -Fqdn $options.Fqdn -Username $username -Password $password -NoGroups:$noGroups

                # if there's a message, fail and return the message
                if (!(Test-PodeIsEmpty $result.Message)) {
                    return $result
                }

                # if there's no user, then, err, oops
                if (Test-PodeIsEmpty $result.User) {
                    return @{ Message = 'An unexpected error occured' }
                }

                # if there are no groups/users supplied, return the user
                if ((Test-PodeIsEmpty $options.Users) -and (Test-PodeIsEmpty $options.Groups)){
                    return $result
                }

                # before checking supplied groups, is the user in the supplied list of authorised users?
                if (!(Test-PodeIsEmpty $options.Users) -and (@($options.Users) -icontains $result.User.Username)) {
                    return $result
                }

                # if there are groups supplied, check the user is a member of one
                if (!(Test-PodeIsEmpty $options.Groups)) {
                    foreach ($group in $options.Groups) {
                        if (@($result.User.Groups) -icontains $group) {
                            return $result
                        }
                    }
                }

                # else, they shall not pass!
                return @{ Message = 'You are not authorised to access this website' }
            }
        }
    }

    return $script
}

function Get-PodeAuthMiddlewareScript
{
    return {
        param($e, $opts)

        # route options for using sessions
        $storeInSession = !$opts.Sessionless
        $usingSessions = (!(Test-PodeIsEmpty $e.Session))

        # check for logout command
        if ($opts.Logout) {
            Remove-PodeAuthSession -Event $e
            $opts.Failure.Url = (Protect-PodeValue -Value $opts.Failure.Url -Default $e.Request.Url.AbsolutePath)
            return (Set-PodeAuthStatus -StatusCode 302 -Options $opts)
        }

        # if the session already has a user/isAuth'd, then skip auth
        if ($usingSessions -and !(Test-PodeIsEmpty $e.Session.Data.Auth.User) -and $e.Session.Data.Auth.IsAuthenticated) {
            $e.Auth = $e.Session.Data.Auth
            return (Set-PodeAuthStatus -Options $opts)
        }

        # check if the auto-login flag is set, in which case just return
        if ($opts.AutoLogin) {
            if (!(Test-PodeIsEmpty $e.Session.Data.Auth)) {
                Remove-PodeSessionCookie -Session $e.Session
            }

            return $true
        }

        # get the auth method
        $auth = $PodeContext.Server.Authentications[$opts.Name]

        try {
            # run auth type script to parse request for data
            $result = (Invoke-PodeScriptBlock -ScriptBlock $auth.Type.ScriptBlock -Arguments (@($e) + @($auth.Type.Arguments)) -Return -Splat)

            # if data is a hashtable, then don't call validator (parser either failed, or forced a success)
            if ($result -isnot [hashtable]) {
                $result = (Invoke-PodeScriptBlock -ScriptBlock $auth.ScriptBlock -Arguments (@($result) + @($auth.Arguments)) -Return -Splat)
            }
        }
        catch {
            $_ | Write-PodeErrorLog
            return (Set-PodeAuthStatus -StatusCode 500 -Description $_.Exception.Message -Options $opts)
        }

        # if there is no result, return false (failed auth)
        if ((Test-PodeIsEmpty $result) -or (Test-PodeIsEmpty $result.User)) {
            return (Set-PodeAuthStatus `
                -StatusCode (Protect-PodeValue -Value $result.Code -Default 401) `
                -Description $result.Message `
                -Options $opts)
        }

        # assign the user to the session, and wire up a quick method
        $e.Auth = @{}
        $e.Auth.User = $result.User
        $e.Auth.IsAuthenticated = $true
        $e.Auth.Store = $storeInSession

        # continue
        return (Set-PodeAuthStatus -Options $opts)
    }
}

function Remove-PodeAuthSession
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $Event
    )

    # blank out the auth
    $Event.Auth = @{}

    # if a session auth is found, blank it
    if (!(Test-PodeIsEmpty $Event.Session.Data.Auth)) {
        $Event.Session.Data.Remove('Auth')
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
        $Description = (Protect-PodeValue -Value $Options.Failure.Message -Default $Description)

        # add error to flash if flagged
        if ($Options.Failure.FlashEnabled) {
            Add-PodeFlashMessage -Name 'auth-error' -Message $Description
        }

        # check if we have a failure url redirect
        if (![string]::IsNullOrWhiteSpace($Options.Failure.Url)) {
            Move-PodeResponseUrl -Url $Options.Failure.Url
        }
        else {
            Set-PodeResponseStatus -Code $StatusCode -Description $Description
        }

        return $false
    }

    # if no statuscode, success, so check if we have a success url redirect
    if (![string]::IsNullOrWhiteSpace($Options.Success.Url)) {
        Move-PodeResponseUrl -Url $Options.Success.Url
        return $false
    }

    return $true
}

function Get-PodeAuthADUser
{
    param (
        [Parameter()]
        [string]
        $Fqdn,

        [Parameter()]
        [string]
        $Username,

        [Parameter()]
        [string]
        $Password,

        [switch]
        $NoGroups
    )

    try
    {
        # setup the dns domain
        $Fqdn = Protect-PodeValue -Value $Fqdn -Default $env:USERDNSDOMAIN

        # validate the user's AD creds
        $ad = (New-Object System.DirectoryServices.DirectoryEntry "LDAP://$($Fqdn)", "$($Username)", "$($Password)")
        if (Test-PodeIsEmpty $ad.distinguishedName) {
            return @{ Message = 'Invalid credentials supplied' }
        }

        # generate query to find user/groups
        $query = New-Object System.DirectoryServices.DirectorySearcher $ad
        $query.filter = "(&(objectCategory=person)(samaccountname=$($Username)))"

        $user = $query.FindOne().Properties
        if (Test-PodeIsEmpty $user) {
            return @{ Message = 'User not found in Active Directory' }
        }

        # get the users groups
        $groups =@()
        if (!$NoGroups) {
            $groups = Get-PodeAuthADGroups -Query $query -CategoryName $Username -CategoryType 'person'
        }

        # return the user
        return @{
            User = @{
                Username = $Username
                Name = @($user.name)[0]
                Fqdn = $Fqdn
                Groups = $groups
            }
        }
    }
    finally {
        if (!(Test-PodeIsEmpty $ad.distinguishedName)) {
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