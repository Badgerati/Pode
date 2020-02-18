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
        if ($atoms.Length -lt 2) {
            return @{
                Message = 'Invalid Authorization header'
                Code = 400
            }
        }

        if ($atoms[0] -ine $options.HeaderTag) {
            return @{
                Message = "Header is not for $($options.HeaderTag) Authorization"
                Code = 401
            }
        }

        # decode the auth header
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

function Get-PodeAuthBearerType
{
    return {
        param($e, $options)

        # get the auth header
        $header = (Get-PodeHeader -Name 'Authorization')
        if ($null -eq $header) {
            return @{
                Message = 'No Authorization header found'
                Challenge = (New-PodeAuthBearerChallenge -Scopes $options.Scopes -ErrorType invalid_request)
                Code = 400
            }
        }

        # ensure the first atom is bearer
        $atoms = $header -isplit '\s+'
        if ($atoms.Length -lt 2) {
            return @{
                Message = 'Invalid Authorization header'
                Challenge = (New-PodeAuthBearerChallenge -Scopes $options.Scopes -ErrorType invalid_request)
                Code = 400
            }
        }

        if ($atoms[0] -ine 'Bearer') {
            return @{
                Message = 'Authorization header is not Bearer'
                Challenge = (New-PodeAuthBearerChallenge -Scopes $options.Scopes -ErrorType invalid_request)
                Code = 400
            }
        }

        # return token for calling validator
        return @($atoms[1].Trim())
    }
}

function Get-PodeAuthBearerPostValidator
{
    return {
        param($e, $token, $result, $options)

        # if there's no user, fail with challenge
        if (($null -eq $result) -or ($null -eq $result.User)) {
            return @{
                Message = 'User not found'
                Challenge = (New-PodeAuthBearerChallenge -Scopes $options.Scopes -ErrorType invalid_token)
                Code = 401
            }
        }

        # check for an error and description
        if (![string]::IsNullOrWhiteSpace($result.Error)) {
            return @{
                Message = 'Authorization failed'
                Challenge = (New-PodeAuthBearerChallenge -Scopes $options.Scopes -ErrorType $result.Error -ErrorDescription $result.ErrorDescription)
                Code = 401
            }
        }

        # check the scopes
        $hasAuthScopes = (($null -ne $options.Scopes) -and ($options.Scopes.Length -gt 0))
        $hasTokenScope = ![string]::IsNullOrWhiteSpace($result.Scope)

        # 403 if we have auth scopes but no token scope
        if ($hasAuthScopes -and !$hasTokenScope) {
            return @{
                Message = 'Invalid Scope'
                Challenge = (New-PodeAuthBearerChallenge -Scopes $options.Scopes -ErrorType insufficient_scope)
                Code = 403
            }
        }

        # 403 if we have both, but token not in auth scope
        if ($hasAuthScopes -and $hasTokenScope -and ($options.Scopes -notcontains $result.Scope)) {
            return @{
                Message = 'Invalid Scope'
                Challenge = (New-PodeAuthBearerChallenge -Scopes $options.Scopes -ErrorType insufficient_scope)
                Code = 403
            }
        }

        # return result
        return $result
    }
}

function New-PodeAuthBearerChallenge
{
    param(
        [Parameter()]
        [string[]]
        $Scopes,

        [Parameter()]
        [ValidateSet('', 'invalid_request', 'invalid_token', 'insufficient_scope')]
        [string]
        $ErrorType,

        [Parameter()]
        [string]
        $ErrorDescription
    )

    $items = @()
    if (($null -ne $Scopes) -and ($Scopes.Length -gt 0)) {
        $items += "scope=`"$($Scopes -join ' ')`""
    }

    if (![string]::IsNullOrWhiteSpace($ErrorType)) {
        $items += "error=`"$($ErrorType)`""
    }

    if (![string]::IsNullOrWhiteSpace($ErrorDescription)) {
        $items += "error_description=`"$($ErrorDescription)`""
    }

    return ($items -join ', ')
}

function Get-PodeAuthDigestType
{
    return {
        param($e, $options)

        # get the auth header - send challenge if missing
        $header = (Get-PodeHeader -Name 'Authorization')
        if ($null -eq $header) {
            return @{
                Message = 'No Authorization header found'
                Challenge = (New-PodeAuthDigestChallenge)
                Code = 401
            }
        }

        # if auth header isn't digest send challenge
        $atoms = $header -isplit '\s+'
        if ($atoms.Length -lt 2) {
            return @{
                Message = 'Invalid Authorization header'
                Code = 400
            }
        }

        if ($atoms[0] -ine 'Digest') {
            return @{
                Message = 'Authorization header is not Digest'
                Challenge = (New-PodeAuthDigestChallenge)
                Code = 401
            }
        }

        # parse the other atoms of the header (after the scheme), return 400 if none
        $params = ConvertFrom-PodeAuthDigestHeader -Parts ($atoms[1..$($atoms.Length - 1)])
        if ($params.Count -eq 0) {
            return @{
                Message = 'Invalid Authorization header'
                Code = 400
            }
        }

        # if no username then 401 and challenge
        if ([string]::IsNullOrWhiteSpace($params.username)) {
            return @{
                Message = 'Authorization header is missing username'
                Challenge = (New-PodeAuthDigestChallenge)
                Code = 401
            }
        }

        # return 400 if domain doesnt match request domain
        if ($e.Path -ine $params.uri) {
            return @{
                Message = 'Invalid Authorization header'
                Code = 400
            }
        }

        # return data for calling validator
        return @($params.username, $params)
    }
}

function Get-PodeAuthDigestPostValidator
{
    return {
        param($e, $username, $params, $result, $options)

        # if there's no user or password, fail with challenge
        if (($null -eq $result) -or ($null -eq $result.User) -or [string]::IsNullOrWhiteSpace($result.Password)) {
            return @{
                Message = 'User not found'
                Challenge = (New-PodeAuthDigestChallenge)
                Code = 401
            }
        }

        # generate the first hash
        $hash1 = Invoke-PodeMD5Hash -Value "$($params.username):$($params.realm):$($result.Password)"

        # generate the second hash
        $hash2 = Invoke-PodeMD5Hash -Value "$($e.Method.ToUpperInvariant()):$($params.uri)"

        # generate final hash
        $final = Invoke-PodeMD5Hash -Value "$($hash1):$($params.nonce):$($params.nc):$($params.cnonce):$($params.qop):$($hash2)"

        # compare final hash to client response
        if ($final -ne $params.response) {
            return @{
                Message = 'Hashes failed to match'
                Challenge = (New-PodeAuthDigestChallenge)
                Code = 401
            }
        }

        # hashes are valid, remove password and return result
        $result.Remove('Password') | Out-Null
        return $result
    }
}

function ConvertFrom-PodeAuthDigestHeader
{
    param(
        [Parameter()]
        [string[]]
        $Parts
    )

    if (($null -eq $Parts) -or ($Parts.Length -eq 0)) {
        return @{}
    }

    $obj = @{}
    $value = ($Parts -join ' ')

    @($value -isplit ',(?=(?:[^"]|"[^"]*")*$)') | ForEach-Object {
        if ($_ -imatch '(?<name>\w+)=["]?(?<value>[^"]+)["]?$') {
            $obj[$Matches['name']] = $Matches['value']
        }
    }

    return $obj
}

function New-PodeAuthDigestChallenge
{
    $items = @('qop="auth"', 'algorithm="MD5"', "nonce=`"$(New-PodeGuid -Secure -NoDashes)`"")
    return ($items -join ', ')
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
                if (!(Test-IsEmpty $result.Message)) {
                    return $result
                }

                # if there's no user, then, err, oops
                if (Test-IsEmpty $result.User) {
                    return @{ Message = 'An unexpected error occured' }
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
        $usingSessions = (!(Test-IsEmpty $e.Session))
        $useHeaders = [bool]($e.Session.Properties.UseHeaders)

        # check for logout command
        if ($opts.Logout) {
            Remove-PodeAuthSession -Event $e

            if ($useHeaders) {
                return (Set-PodeAuthStatus -StatusCode 401)
            }
            else {
                $opts.Failure.Url = (Protect-PodeValue -Value $opts.Failure.Url -Default $e.Request.Url.AbsolutePath)
                return (Set-PodeAuthStatus -StatusCode 302 -Options $opts)
            }
        }

        # if the session already has a user/isAuth'd, then skip auth
        if ($usingSessions -and !(Test-IsEmpty $e.Session.Data.Auth.User) -and $e.Session.Data.Auth.IsAuthenticated) {
            $e.Auth = $e.Session.Data.Auth
            return (Set-PodeAuthStatus -Options $opts)
        }

        # check if the auto-login flag is set, in which case just return
        if ($opts.AutoLogin -and !$useHeaders) {
            if (!(Test-IsEmpty $e.Session.Data.Auth)) {
                Revoke-PodeSession -Session $e.Session
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
                $original = $result
                $result = (Invoke-PodeScriptBlock -ScriptBlock $auth.ScriptBlock -Arguments (@($result) + @($auth.Arguments)) -Return -Splat)

                # if we have user, then run post validator if present
                if ([string]::IsNullOrWhiteSpace($result.Code) -and !(Test-IsEmpty $auth.Type.PostValidator)) {
                    $result = (Invoke-PodeScriptBlock -ScriptBlock $auth.Type.PostValidator -Arguments (@($e) + @($original) + @($result) + @($auth.Type.Arguments)) -Return -Splat)
                }
            }
        }
        catch {
            $_ | Write-PodeErrorLog
            return (Set-PodeAuthStatus -StatusCode 500 -Description $_.Exception.Message -Options $opts)
        }

        # if there is no result, return false (failed auth)
        if ((Test-IsEmpty $result) -or (Test-IsEmpty $result.User)) {
            $_code = (Protect-PodeValue -Value $result.Code -Default 401)

            # set the www-auth header
            $validCode = (($_code -eq 401) -or ![string]::IsNullOrWhiteSpace($result.Challenge))
            $validHeaders = (($null -eq $result.Headers) -or !$result.Headers.ContainsKey('WWW-Authenticate'))

            if ($validCode -and $validHeaders) {
                $_wwwHeader = Get-PodeAuthWwwHeaderValue -Name $auth.Type.Name -Realm $auth.Type.Realm -Challenge $result.Challenge
                if (![string]::IsNullOrWhiteSpace($_wwwHeader)) {
                    Set-PodeHeader -Name 'WWW-Authenticate' -Value $_wwwHeader
                }
            }

            return (Set-PodeAuthStatus `
                -StatusCode $_code `
                -Description $result.Message `
                -Headers $result.Headers `
                -Options $opts)
        }

        # assign the user to the session, and wire up a quick method
        $e.Auth = @{}
        $e.Auth.User = $result.User
        $e.Auth.IsAuthenticated = $true
        $e.Auth.Store = $storeInSession

        # continue
        return (Set-PodeAuthStatus -Headers $result.Headers -Options $opts)
    }
}

function Get-PodeAuthWwwHeaderValue
{
    param(
        [Parameter()]
        [string]
        $Name,

        [Parameter()]
        [string]
        $Realm,

        [Parameter()]
        [string]
        $Challenge
    )

    if ([string]::IsNullOrWhiteSpace($Name)) {
        return [string]::Empty
    }

    $header = $Name
    if (![string]::IsNullOrWhiteSpace($Realm)) {
        $header += " realm=`"$($Realm)`""
    }

    if (![string]::IsNullOrWhiteSpace($Challenge)) {
        $header += ", $($Challenge)"
    }

    return $header
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
    if (!(Test-IsEmpty $Event.Session.Data.Auth)) {
        $Event.Session.Data.Remove('Auth')
    }

    # Delete the session (remove from store, blank it, and remove from Response)
    Revoke-PodeSession -Session $Event.Session
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
        $Headers,

        [Parameter()]
        [hashtable]
        $Options
    )

    # if we have any headers, set them
    if (($null -ne $Headers) -and ($Headers.Count -gt 0)) {
        foreach ($name in $Headers.Keys) {
            Set-PodeHeader -Name $name -Value $Headers[$name]
        }
    }

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
        if (Test-IsEmpty $ad.distinguishedName) {
            return @{ Message = 'Invalid credentials supplied' }
        }

        # generate query to find user/groups
        $query = New-Object System.DirectoryServices.DirectorySearcher $ad
        $query.filter = "(&(objectCategory=person)(samaccountname=$($Username)))"

        $user = $query.FindOne().Properties
        if (Test-IsEmpty $user) {
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