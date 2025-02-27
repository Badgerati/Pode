function Get-PodeAuthBasicType {
    return {
        param($options)

        # get the auth header
        $header = (Get-PodeHeader -Name 'Authorization')
        if ($null -eq $header) {
            return @{
                Message = 'No Authorization header found'
                Code    = 401
            }
        }

        # ensure the first atom is basic (or opt override)
        $atoms = $header -isplit '\s+'
        if ($atoms.Length -lt 2) {
            return @{
                Message = 'Invalid Authorization header'
                Code    = 400
            }
        }

        if ($atoms[0] -ine $options.HeaderTag) {
            return @{
                Message = "Header is not for $($options.HeaderTag) Authorization"
                Code    = 400
            }
        }

        # decode the auth header
        try {
            $enc = [System.Text.Encoding]::GetEncoding($options.Encoding)
        }
        catch {
            return @{
                Message = 'Invalid encoding specified for Authorization'
                Code    = 400
            }
        }

        try {
            $decoded = $enc.GetString([System.Convert]::FromBase64String($atoms[1]))
        }
        catch {
            return @{
                Message = 'Invalid Base64 string found in Authorization header'
                Code    = 400
            }
        }

        # validate and return user/result
        $index = $decoded.IndexOf(':')
        $username = $decoded.Substring(0, $index)
        $password = $decoded.Substring($index + 1)

        # build the result
        $result = @($username, $password)

        # convert to credential?
        if ($options.AsCredential) {
            $passSecure = ConvertTo-SecureString -String $password -AsPlainText -Force
            $creds = [pscredential]::new($username, $passSecure)
            $result = @($creds)
        }

        # return data for calling validator
        return $result
    }
}

function Get-PodeAuthOAuth2Type {
    return {
        param($options, $schemes)

        # set default scopes
        if (($null -eq $options.Scopes) -or ($options.Scopes.Length -eq 0)) {
            $options.Scopes = @('openid', 'profile', 'email')
        }

        $scopes = ($options.Scopes -join ' ')

        # if there's an error, fail
        if (![string]::IsNullOrWhiteSpace($WebEvent.Query['error'])) {
            return @{
                Message   = $WebEvent.Query['error']
                Code      = 401
                IsErrored = $true
            }
        }

        # set grant type
        $hasInnerScheme = (($null -ne $schemes) -and ($schemes.Length -gt 0))
        $grantType = 'authorization_code'
        if ($hasInnerScheme) {
            $grantType = 'password'
        }

        # if there's a code query param, or inner scheme, get access token
        if ($hasInnerScheme -or ![string]::IsNullOrWhiteSpace($WebEvent.Query['code'])) {
            try {
                # ensure the state is valid
                if ((Test-PodeSessionsInUse) -and ($WebEvent.Query['state'] -ne $WebEvent.Session.Data['__pode_oauth_state__'])) {
                    return @{
                        Message   = 'OAuth2 state returned is invalid'
                        Code      = 401
                        IsErrored = $true
                    }
                }

                # build tokenUrl query with client info
                $body = "client_id=$($options.Client.ID)"
                $body += "&grant_type=$($grantType)"

                if (![string]::IsNullOrEmpty($options.Client.Secret)) {
                    $body += "&client_secret=$([System.Web.HttpUtility]::UrlEncode($options.Client.Secret))"
                }

                # add PKCE code verifier
                if ($options.PKCE.Enabled) {
                    $body += "&code_verifier=$($WebEvent.Session.Data['__pode_oauth_code_verifier__'])"
                }

                # if there's an inner scheme, get the username/password, and set query
                if ($hasInnerScheme) {
                    $body += "&username=$($schemes[-1][0])"
                    $body += "&password=$($schemes[-1][1])"
                    $body += "&scope=$([System.Web.HttpUtility]::UrlEncode($scopes))"
                }

                # otherwise, set query for auth_code
                else {
                    $redirectUrl = Get-PodeOAuth2RedirectHost -RedirectUrl $options.Urls.Redirect
                    $body += "&code=$($WebEvent.Query['code'])"
                    $body += "&redirect_uri=$([System.Web.HttpUtility]::UrlEncode($redirectUrl))"
                }

                # POST the tokenUrl
                try {
                    $result = Invoke-RestMethod -Method Post -Uri $options.Urls.Token -Body $body -ContentType 'application/x-www-form-urlencoded' -ErrorAction Stop
                }
                catch [System.Net.WebException], [System.Net.Http.HttpRequestException] {
                    $response = Read-PodeWebExceptionInfo -ErrorRecord $_
                    $result = ($response.Body | ConvertFrom-Json)
                }

                # was there an error?
                if (![string]::IsNullOrWhiteSpace($result.error)) {
                    return @{
                        Message   = "$($result.error): $($result.error_description)"
                        Code      = 401
                        IsErrored = $true
                    }
                }

                # get user details - if url supplied
                if (![string]::IsNullOrWhiteSpace($options.Urls.User.Url)) {
                    try {
                        $user = Invoke-RestMethod -Method $options.Urls.User.Method -Uri $options.Urls.User.Url -Headers @{ Authorization = "Bearer $($result.access_token)" }
                    }
                    catch [System.Net.WebException], [System.Net.Http.HttpRequestException] {
                        $response = Read-PodeWebExceptionInfo -ErrorRecord $_
                        $user = ($response.Body | ConvertFrom-Json)
                    }

                    if (![string]::IsNullOrWhiteSpace($user.error)) {
                        return @{
                            Message   = "$($user.error): $($user.error_description)"
                            Code      = 401
                            IsErrored = $true
                        }
                    }
                }
                elseif (![string]::IsNullOrWhiteSpace($result.id_token)) {
                    try {
                        $user = ConvertFrom-PodeJwt -Token $result.id_token -IgnoreSignature
                    }
                    catch {
                        $user = @{ Provider = 'OAuth2' }
                    }
                }
                else {
                    $user = @{ Provider = 'OAuth2' }
                }

                # return the user for the validator
                return @($user, $result.access_token, $result.refresh_token, $result)
            }
            finally {
                if ($null -ne $WebEvent.Session.Data) {
                    # clear state
                    $WebEvent.Session.Data.Remove('__pode_oauth_state__')

                    # clear PKCE
                    if ($options.PKCE.Enabled) {
                        $WebEvent.Session.Data.Remove('__pode_oauth_code_verifier__')
                    }
                }
            }
        }

        # redirect to the authUrl - only if no inner scheme supplied
        if (!$hasInnerScheme) {
            # get the redirectUrl
            $redirectUrl = Get-PodeOAuth2RedirectHost -RedirectUrl $options.Urls.Redirect

            # add authUrl query params
            $query = "client_id=$($options.Client.ID)"
            $query += '&response_type=code'
            $query += "&redirect_uri=$([System.Web.HttpUtility]::UrlEncode($redirectUrl))"
            $query += '&response_mode=query'
            $query += "&scope=$([System.Web.HttpUtility]::UrlEncode($scopes))"

            # add csrf state
            if (Test-PodeSessionsInUse) {
                $guid = New-PodeGuid
                $WebEvent.Session.Data['__pode_oauth_state__'] = $guid
                $query += "&state=$($guid)"
            }

            # build a code verifier for PKCE, and add to query
            if ($options.PKCE.Enabled) {
                $guid = New-PodeGuid
                $codeVerifier = "$($guid)-$($guid)"
                $WebEvent.Session.Data['__pode_oauth_code_verifier__'] = $codeVerifier

                $codeChallenge = $codeVerifier
                if ($options.PKCE.CodeChallenge.Method -ieq 'S256') {
                    $codeChallenge = ConvertTo-PodeBase64UrlValue -Value (Invoke-PodeSHA256Hash -Value $codeChallenge) -NoConvert
                }

                $query += "&code_challenge=$($codeChallenge)"
                $query += "&code_challenge_method=$($options.PKCE.CodeChallenge.Method)"
            }

            # are custom parameters already on the URL?
            $url = $options.Urls.Authorise
            if (!$url.Contains('?')) {
                $url += '?'
            }
            else {
                $url += '&'
            }

            # redirect to OAuth2 endpoint
            Move-PodeResponseUrl -Url "$($url)$($query)"
            return @{ IsRedirected = $true }
        }

        # hmm, this is unexpected
        return @{
            Message   = 'Well, this is awkward...'
            Code      = 500
            IsErrored = $true
        }
    }
}

function Get-PodeOAuth2RedirectHost {
    param(
        [Parameter()]
        [string]
        $RedirectUrl
    )

    if ($RedirectUrl.StartsWith('/')) {
        if ($PodeContext.Server.IsIIS -or $PodeContext.Server.IsHeroku) {
            $protocol = Get-PodeHeader -Name 'X-Forwarded-Proto'
            if ([string]::IsNullOrWhiteSpace($protocol)) {
                $protocol = 'https'
            }

            $domain = "$($protocol)://$($WebEvent.Request.Host)"
        }
        else {
            $domain = Get-PodeEndpointUrl
        }

        $RedirectUrl = "$($domain.TrimEnd('/'))$($RedirectUrl)"
    }

    return $RedirectUrl
}

function Get-PodeAuthClientCertificateType {
    return {
        param($options)
        $cert = $WebEvent.Request.ClientCertificate

        # ensure we have a client cert
        if ($null -eq $cert) {
            return @{
                Message = 'No client certificate supplied'
                Code    = 401
            }
        }

        # ensure the cert has a thumbprint
        if ([string]::IsNullOrWhiteSpace($cert.Thumbprint)) {
            return @{
                Message = 'Invalid client certificate supplied'
                Code    = 401
            }
        }

        # ensure the cert hasn't expired, or has it even started
        $now = [datetime]::Now
        if (($cert.NotAfter -lt $now) -or ($cert.NotBefore -gt $now)) {
            return @{
                Message = 'Invalid client certificate supplied'
                Code    = 401
            }
        }

        # return data for calling validator
        return @($cert, $WebEvent.Request.ClientCertificateErrors)
    }
}

function Get-PodeAuthNegotiateType {
    return {
        param($options)

        # do we have an auth header?
        $header = Get-PodeHeader -Name 'Authorization'
        if ($null -eq $header) {
            return @{
                Message = 'No Authorization header found'
                Code    = 401
            }
        }

        # validate the supplied token
        try {
            $options.Authenticator.Validate($header)
        }
        catch {
            $_ | Write-PodeErrorLog -Level Debug
            return @{
                Message = 'Invalid Authorization header'
                Code    = 400
            }
        }

        # authenticate the user
        try {
            $claim = $options.Authenticator.Authenticate($header)
        }
        catch {
            $_ | Write-PodeErrorLog -Level Debug
            return @{
                Message = 'Authentication failed'
                Code    = 401
            }
        }

        return @($claim)
    }
}

function Get-PodeAuthApiKeyType {
    return {
        param($options)

        # get api key from appropriate location
        $apiKey = [string]::Empty

        switch ($options.Location.ToLowerInvariant()) {
            'header' {
                $apiKey = Get-PodeHeader -Name $options.LocationName
            }

            'query' {
                $apiKey = $WebEvent.Query[$options.LocationName]
            }

            'cookie' {
                $apiKey = Get-PodeCookieValue -Name $options.LocationName
            }
        }

        # 400 if no key
        if ([string]::IsNullOrWhiteSpace($apiKey)) {
            return @{
                Message = "No $($options.LocationName) $($options.Location) found"
                Code    = 400
            }
        }

        # build the result
        $apiKey = $apiKey.Trim()
        $result = @($apiKey)

        # convert as jwt?
        if ($options.AsJWT) {
            try {
                $payload = ConvertFrom-PodeJwt -Token $apiKey -Secret $options.Secret
                Test-PodeJwt -Payload $payload
            }
            catch {
                if ($_.Exception.Message -ilike '*jwt*') {
                    return @{
                        Message = $_.Exception.Message
                        Code    = 400
                    }
                }

                throw
            }

            $result = @($payload)
        }

        # return the result
        return $result
    }
}

function Get-PodeAuthBearerType {
    return {
        param($options)

        # get the auth header
        $header = (Get-PodeHeader -Name 'Authorization')
        if ($null -eq $header) {
            return @{
                Message   = 'No Authorization header found'
                Challenge = (New-PodeAuthBearerChallenge -Scopes $options.Scopes -ErrorType invalid_request)
                Code      = 400
            }
        }

        # ensure the first atom is bearer
        $atoms = $header -isplit '\s+'
        if ($atoms.Length -lt 2) {
            return @{
                Message   = 'Invalid Authorization header'
                Challenge = (New-PodeAuthBearerChallenge -Scopes $options.Scopes -ErrorType invalid_request)
                Code      = 400
            }
        }

        if ($atoms[0] -ine $options.HeaderTag) {
            return @{
                Message   = "Authorization header is not $($options.HeaderTag)"
                Challenge = (New-PodeAuthBearerChallenge -Scopes $options.Scopes -ErrorType invalid_request)
                Code      = 400
            }
        }

        # 400 if no token
        $token = $atoms[1]
        if ([string]::IsNullOrWhiteSpace($token)) {
            return @{
                Message = 'No Bearer token found'
                Code    = 400
            }
        }

        # build the result
        $token = $token.Trim()
        $result = @($token)

        # convert as jwt?
        if ($options.AsJWT) {
            try {
                $payload = ConvertFrom-PodeJwt -Token $token -Secret $options.Secret
                Test-PodeJwt -Payload $payload
            }
            catch {
                if ($_.Exception.Message -ilike '*jwt*') {
                    return @{
                        Message = $_.Exception.Message
                        #https://www.rfc-editor.org/rfc/rfc6750 Bearer token should return 401
                        Code    = 401
                    }
                }

                throw
            }

            $result = @($payload)
        }

        # return the result
        return $result
    }
}

function Get-PodeAuthBearerPostValidator {
    return {
        param($token, $result, $options)

        # if there's no user, fail with challenge
        if (($null -eq $result) -or ($null -eq $result.User)) {
            return @{
                Message   = 'User not found'
                Challenge = (New-PodeAuthBearerChallenge -Scopes $options.Scopes -ErrorType invalid_token)
                Code      = 401
            }
        }

        # check for an error and description
        if (![string]::IsNullOrWhiteSpace($result.Error)) {
            return @{
                Message   = 'Authorization failed'
                Challenge = (New-PodeAuthBearerChallenge -Scopes $options.Scopes -ErrorType $result.Error -ErrorDescription $result.ErrorDescription)
                Code      = 401
            }
        }

        # check the scopes
        $hasAuthScopes = (($null -ne $options.Scopes) -and ($options.Scopes.Length -gt 0))
        $hasTokenScope = ![string]::IsNullOrWhiteSpace($result.Scope)

        # 403 if we have auth scopes but no token scope
        if ($hasAuthScopes -and !$hasTokenScope) {
            return @{
                Message   = 'Invalid Scope'
                Challenge = (New-PodeAuthBearerChallenge -Scopes $options.Scopes -ErrorType insufficient_scope)
                Code      = 403
            }
        }

        # 403 if we have both, but token not in auth scope
        if ($hasAuthScopes -and $hasTokenScope -and ($options.Scopes -notcontains $result.Scope)) {
            return @{
                Message   = 'Invalid Scope'
                Challenge = (New-PodeAuthBearerChallenge -Scopes $options.Scopes -ErrorType insufficient_scope)
                Code      = 403
            }
        }

        # return result
        return $result
    }
}

function New-PodeAuthBearerChallenge {
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

function Get-PodeAuthDigestType {
    return {
        param($options)

        # get the auth header - send challenge if missing
        $header = (Get-PodeHeader -Name 'Authorization')
        if ($null -eq $header) {
            return @{
                Message   = 'No Authorization header found'
                Challenge = (New-PodeAuthDigestChallenge)
                Code      = 401
            }
        }

        # if auth header isn't digest send challenge
        $atoms = $header -isplit '\s+'
        if ($atoms.Length -lt 2) {
            return @{
                Message = 'Invalid Authorization header'
                Code    = 400
            }
        }

        if ($atoms[0] -ine $options.HeaderTag) {
            return @{
                Message   = "Authorization header is not $($options.HeaderTag)"
                Challenge = (New-PodeAuthDigestChallenge)
                Code      = 401
            }
        }

        # parse the other atoms of the header (after the scheme), return 400 if none
        $params = ConvertFrom-PodeAuthDigestHeader -Parts ($atoms[1..$($atoms.Length - 1)])
        if ($params.Count -eq 0) {
            return @{
                Message = 'Invalid Authorization header'
                Code    = 400
            }
        }

        # if no username then 401 and challenge
        if ([string]::IsNullOrWhiteSpace($params.username)) {
            return @{
                Message   = 'Authorization header is missing username'
                Challenge = (New-PodeAuthDigestChallenge)
                Code      = 401
            }
        }

        # return 400 if domain doesnt match request domain
        if ($WebEvent.Path -ine $params.uri) {
            return @{
                Message = 'Invalid Authorization header'
                Code    = 400
            }
        }

        # return data for calling validator
        return @($params.username, $params)
    }
}

function Get-PodeAuthDigestPostValidator {
    return {
        param($username, $params, $result, $options)

        # if there's no user or password, fail with challenge
        if (($null -eq $result) -or ($null -eq $result.User) -or [string]::IsNullOrWhiteSpace($result.Password)) {
            return @{
                Message   = 'User not found'
                Challenge = (New-PodeAuthDigestChallenge)
                Code      = 401
            }
        }

        # generate the first hash
        $hash1 = Invoke-PodeMD5Hash -Value "$($params.username):$($params.realm):$($result.Password)"

        # generate the second hash
        $hash2 = Invoke-PodeMD5Hash -Value "$($WebEvent.Method.ToUpperInvariant()):$($params.uri)"

        # generate final hash
        $final = Invoke-PodeMD5Hash -Value "$($hash1):$($params.nonce):$($params.nc):$($params.cnonce):$($params.qop):$($hash2)"

        # compare final hash to client response
        if ($final -ne $params.response) {
            return @{
                Message   = 'Hashes failed to match'
                Challenge = (New-PodeAuthDigestChallenge)
                Code      = 401
            }
        }

        # hashes are valid, remove password and return result
        $null = $result.Remove('Password')
        return $result
    }
}

function ConvertFrom-PodeAuthDigestHeader {
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

function New-PodeAuthDigestChallenge {
    $items = @('qop="auth"', 'algorithm="MD5"', "nonce=`"$(New-PodeGuid -Secure -NoDashes)`"")
    return ($items -join ', ')
}

function Get-PodeAuthFormType {
    return {
        param($options)

        # get user/pass keys to get from payload
        $userField = $options.Fields.Username
        $passField = $options.Fields.Password

        # get the user/pass
        $username = $WebEvent.Data.$userField
        $password = $WebEvent.Data.$passField

        # if either are empty, fail auth
        if ([string]::IsNullOrWhiteSpace($username) -or [string]::IsNullOrWhiteSpace($password)) {
            return @{
                Message = 'Username or Password not supplied'
                Code    = 401
            }
        }

        # build the result
        $result = @($username, $password)

        # convert to credential?
        if ($options.AsCredential) {
            $passSecure = ConvertTo-SecureString -String $password -AsPlainText -Force
            $creds = [pscredential]::new($username, $passSecure)
            $result = @($creds)
        }

        # return data for calling validator
        return $result
    }
}

<#
.SYNOPSIS
    Authenticates a user based on a username and password provided as parameters.

.DESCRIPTION
    This function finds a user whose username matches the provided username, and checks the user's password.
    If the password is correct, it converts the user into a hashtable and checks if the user is valid for any users/groups specified by the options parameter. If the user is valid, it returns a hashtable containing the user object. If the user is not valid, it returns a hashtable with a message indicating that the user is not authorized to access the website.

.PARAMETER username
    The username of the user to authenticate.

.PARAMETER password
    The password of the user to authenticate.

.PARAMETER options
    A hashtable containing options for the function. It can include the following keys:
    - FilePath: The path to the JSON file containing user data.
    - HmacSecret: The secret key for computing a HMAC-SHA256 hash of the password.
    - Users: A list of valid users.
    - Groups: A list of valid groups.
    - ScriptBlock: A script block for additional validation.

.EXAMPLE
    Get-PodeAuthUserFileMethod -username "admin" -password "password123" -options @{ FilePath = "C:\Users.json"; HmacSecret = "secret"; Users = @("admin"); Groups = @("Administrators"); ScriptBlock = { param($user) $user.Name -eq "admin" } }

    This example authenticates a user with username "admin" and password "password123". It reads user data from the JSON file at "C:\Users.json", computes a HMAC-SHA256 hash of the password using "secret" as the secret key, and checks if the user is in the "admin" user or "Administrators" group. It also performs additional validation using a script block that checks if the user's name is "admin".
#>
function Get-PodeAuthUserFileMethod {
    return {
        param($username, $password, $options)

        # using pscreds?
        if (($null -eq $options) -and ($username -is [pscredential])) {
            $_username = ([pscredential]$username).UserName
            $_password = ([pscredential]$username).GetNetworkCredential().Password
            $_options = [hashtable]$password
        }
        else {
            $_username = $username
            $_password = $password
            $_options = $options
        }

        # load the file
        $users = (Get-Content -Path $_options.FilePath -Raw | ConvertFrom-Json)

        # find the user by username - only use the first one
        $user = @(foreach ($_user in $users) {
                if ($_user.Username -ieq $_username) {
                    $_user
                    break
                }
            })[0]

        # fail if no user
        if ($null -eq $user) {
            return @{ Message = 'You are not authorised to access this website' }
        }

        # check the user's password
        if (![string]::IsNullOrWhiteSpace($_options.HmacSecret)) {
            $hash = Invoke-PodeHMACSHA256Hash -Value $_password -Secret $_options.HmacSecret
        }
        else {
            $hash = Invoke-PodeSHA256Hash -Value $_password
        }

        if ($user.Password -ne $hash) {
            return @{ Message = 'You are not authorised to access this website' }
        }

        # convert the user to a hashtable
        $user = @{
            Name     = $user.Name
            Username = $user.Username
            Email    = $user.Email
            Groups   = $user.Groups
            Metadata = $user.Metadata
        }

        # is the user valid for any users/groups?
        if (!(Test-PodeAuthUserGroup -User $user -Users $_options.Users -Groups $_options.Groups)) {
            return @{ Message = 'You are not authorised to access this website' }
        }

        $result = @{ User = $user }

        # call additional scriptblock if supplied
        if ($null -ne $_options.ScriptBlock.Script) {
            $result = Invoke-PodeAuthInbuiltScriptBlock -User $result.User -ScriptBlock $_options.ScriptBlock.Script -UsingVariables $_options.ScriptBlock.UsingVariables
        }

        # return final result, this could contain a user obj, or an error message from custom scriptblock
        return $result
    }
}

function Get-PodeAuthWindowsADMethod {
    return {
        param($username, $password, $options)

        # using pscreds?
        if (($null -eq $options) -and ($username -is [pscredential])) {
            $_username = ([pscredential]$username).UserName
            $_password = ([pscredential]$username).GetNetworkCredential().Password
            $_options = [hashtable]$password
        }
        else {
            $_username = $username
            $_password = $password
            $_options = $options
        }

        # parse username to remove domains
        $_username = (($_username -split '@')[0] -split '\\')[-1]

        # validate and retrieve the AD user
        $noGroups = $_options.NoGroups
        $directGroups = $_options.DirectGroups
        $keepCredential = $_options.KeepCredential

        $result = Get-PodeAuthADResult `
            -Server $_options.Server `
            -Domain $_options.Domain `
            -SearchBase $_options.SearchBase `
            -Username $_username `
            -Password $_password `
            -Provider $_options.Provider `
            -NoGroups:$noGroups `
            -DirectGroups:$directGroups `
            -KeepCredential:$keepCredential

        # if there's a message, fail and return the message
        if (![string]::IsNullOrWhiteSpace($result.Message)) {
            return $result
        }

        # if there's no user, then, err, oops
        if (Test-PodeIsEmpty $result.User) {
            return @{ Message = 'An unexpected error occured' }
        }

        # is the user valid for any users/groups - if not, error!
        if (!(Test-PodeAuthUserGroup -User $result.User -Users $_options.Users -Groups $_options.Groups)) {
            return @{ Message = 'You are not authorised to access this website' }
        }

        # call additional scriptblock if supplied
        if ($null -ne $_options.ScriptBlock.Script) {
            $result = Invoke-PodeAuthInbuiltScriptBlock -User $result.User -ScriptBlock $_options.ScriptBlock.Script -UsingVariables $_options.ScriptBlock.UsingVariables
        }

        # return final result, this could contain a user obj, or an error message from custom scriptblock
        return $result
    }
}

function Invoke-PodeAuthInbuiltScriptBlock {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]
        $User,

        [Parameter(Mandatory = $true)]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        $UsingVariables
    )

    return (Invoke-PodeScriptBlock -ScriptBlock $ScriptBlock -Arguments $User -UsingVariables $UsingVariables -Return)
}

function Get-PodeAuthWindowsLocalMethod {
    return {
        param($username, $password, $options)

        # using pscreds?
        if (($null -eq $options) -and ($username -is [pscredential])) {
            $_username = ([pscredential]$username).UserName
            $_password = ([pscredential]$username).GetNetworkCredential().Password
            $_options = [hashtable]$password
        }
        else {
            $_username = $username
            $_password = $password
            $_options = $options
        }

        $user = @{
            UserType           = 'Local'
            AuthenticationType = 'WinNT'
            Username           = $_username
            Name               = [string]::Empty
            Fqdn               = $PodeContext.Server.ComputerName
            Domain             = 'localhost'
            Groups             = @()
        }

        Add-Type -AssemblyName System.DirectoryServices.AccountManagement -ErrorAction Stop
        $context = [System.DirectoryServices.AccountManagement.PrincipalContext]::new('Machine', $PodeContext.Server.ComputerName)
        $valid = $context.ValidateCredentials($_username, $_password)

        if (!$valid) {
            return @{ Message = 'Invalid credentials supplied' }
        }

        try {
            $tmpUsername = $_username -replace '\\', '/'
            if ($_username -inotlike "$($PodeContext.Server.ComputerName)*") {
                $tmpUsername = "$($PodeContext.Server.ComputerName)/$($_username)"
            }

            $ad = [adsi]"WinNT://$($tmpUsername)"
            $user.Name = @($ad.FullName)[0]

            if (!$_options.NoGroups) {
                $cmd = "`$ad = [adsi]'WinNT://$($tmpUsername)'; @(`$ad.Groups() | Foreach-Object { `$_.GetType().InvokeMember('Name', 'GetProperty', `$null, `$_, `$null) })"
                $user.Groups = [string[]](powershell -c $cmd)
            }
        }
        finally {
            Close-PodeDisposable -Disposable $ad -Close
        }

        # is the user valid for any users/groups - if not, error!
        if (!(Test-PodeAuthUserGroup -User $user -Users $_options.Users -Groups $_options.Groups)) {
            return @{ Message = 'You are not authorised to access this website' }
        }

        $result = @{ User = $user }

        # call additional scriptblock if supplied
        if ($null -ne $_options.ScriptBlock.Script) {
            $result = Invoke-PodeAuthInbuiltScriptBlock -User $result.User -ScriptBlock $_options.ScriptBlock.Script -UsingVariables $_options.ScriptBlock.UsingVariables
        }

        # return final result, this could contain a user obj, or an error message from custom scriptblock
        return $result
    }
}

function Get-PodeAuthWindowsADIISMethod {
    return {
        param($token, $options)

        # get the close handler
        $win32Handler = Add-Type -Name Win32CloseHandle -PassThru -MemberDefinition @'
            [DllImport("kernel32.dll", SetLastError = true)]
            public static extern bool CloseHandle(IntPtr handle);
'@

        try {
            # parse the auth token and get the user
            $winAuthToken = [System.IntPtr][Int]"0x$($token)"
            $winIdentity = [System.Security.Principal.WindowsIdentity]::new($winAuthToken, 'Windows')

            # get user and domain
            $username = ($winIdentity.Name -split '\\')[-1]
            $domain = ($winIdentity.Name -split '\\')[0]

            # create base user object
            $user = @{
                UserType           = 'Domain'
                Identity           = @{
                    AccessToken = $winIdentity.AccessToken
                }
                AuthenticationType = $winIdentity.AuthenticationType
                DistinguishedName  = [string]::Empty
                Username           = $username
                Name               = [string]::Empty
                Email              = [string]::Empty
                Fqdn               = [string]::Empty
                Domain             = $domain
                Groups             = @()
            }

            # if the domain isn't local, attempt AD user
            if (![string]::IsNullOrWhiteSpace($domain) -and (@('.', $PodeContext.Server.ComputerName) -inotcontains $domain)) {
                # get the server's fdqn (and name/email)
                try {
                    # Open ADSISearcher and change context to given domain
                    $searcher = [adsisearcher]''
                    $searcher.SearchRoot = [adsi]"LDAP://$($domain)"
                    $searcher.Filter = "ObjectSid=$($winIdentity.User.Value.ToString())"

                    # Query the ADSISearcher for the above defined SID
                    $ad = $searcher.FindOne()

                    # Save it to our existing array for later usage
                    $user.DistinguishedName = @($ad.Properties.distinguishedname)[0]
                    $user.Name = @($ad.Properties.name)[0]
                    $user.Email = @($ad.Properties.mail)[0]
                    $user.Fqdn = (Get-PodeADServerFromDistinguishedName -DistinguishedName $user.DistinguishedName)
                }
                finally {
                    Close-PodeDisposable -Disposable $searcher
                }

                try {
                    if (!$options.NoGroups) {

                        # open a new connection
                        $result = (Open-PodeAuthADConnection -Server $user.Fqdn -Domain $domain -Provider $options.Provider)
                        if (!$result.Success) {
                            return @{ Message = "Failed to connect to Domain Server '$($user.Fqdn)' of $domain for $($user.DistinguishedName)." }
                        }

                        # get the connection
                        $connection = $result.Connection

                        # get the users groups
                        $directGroups = $options.DirectGroups
                        $user.Groups = (Get-PodeAuthADGroup -Connection $connection -DistinguishedName $user.DistinguishedName -Username $user.Username -Direct:$directGroups -Provider $options.Provider)
                    }
                }
                finally {
                    if ($null -ne $connection) {
                        Close-PodeDisposable -Disposable $connection.Searcher
                        Close-PodeDisposable -Disposable $connection.Entry -Close
                        $connection.Credential = $null
                    }
                }
            }

            # otherwise, get details of local user
            else {
                # get the user's name and groups
                try {
                    $user.UserType = 'Local'

                    if (!$options.NoLocalCheck) {
                        $localUser = $winIdentity.Name -replace '\\', '/'
                        $ad = [adsi]"WinNT://$($localUser)"
                        $user.Name = @($ad.FullName)[0]

                        # dirty, i know :/ - since IIS runs using pwsh, the InvokeMember part fails
                        # we can safely call windows powershell here, as IIS is only on windows.
                        if (!$options.NoGroups) {
                            $cmd = "`$ad = [adsi]'WinNT://$($localUser)'; @(`$ad.Groups() | Foreach-Object { `$_.GetType().InvokeMember('Name', 'GetProperty', `$null, `$_, `$null) })"
                            $user.Groups = [string[]](powershell -c $cmd)
                        }
                    }
                }
                finally {
                    Close-PodeDisposable -Disposable $ad -Close
                }
            }
        }
        catch {
            $_ | Write-PodeErrorLog
            return @{ Message = 'Failed to retrieve user using Authentication Token' }
        }
        finally {
            $win32Handler::CloseHandle($winAuthToken)
        }

        # is the user valid for any users/groups - if not, error!
        if (!(Test-PodeAuthUserGroup -User $user -Users $options.Users -Groups $options.Groups)) {
            return @{ Message = 'You are not authorised to access this website' }
        }

        $result = @{ User = $user }

        # call additional scriptblock if supplied
        if ($null -ne $options.ScriptBlock.Script) {
            $result = Invoke-PodeAuthInbuiltScriptBlock -User $result.User -ScriptBlock $options.ScriptBlock.Script -UsingVariables $options.ScriptBlock.UsingVariables
        }

        # return final result, this could contain a user obj, or an error message from custom scriptblock
        return $result
    }
}

<#
    .SYNOPSIS
    Authenticates a user based on group membership or specific user authorization.

    .DESCRIPTION
    This function checks if a given user is authorized based on supplied lists of users and groups. The user is considered authorized if their username is directly specified in the list of users, or if they are a member of any of the specified groups.

    .PARAMETER User
    A hashtable representing the user, expected to contain at least the 'Username' and 'Groups' keys.

    .PARAMETER Users
    An optional array of usernames. If specified, the function checks if the user's username exists in this list.

    .PARAMETER Groups
    An optional array of group names. If specified, the function checks if the user belongs to any of these groups.

    .EXAMPLE
    $user = @{ Username = 'john.doe'; Groups = @('Administrators', 'Users') }
    $authorizedUsers = @('john.doe', 'jane.doe')
    $authorizedGroups = @('Administrators')

    Test-PodeAuthUserGroup -User $user -Users $authorizedUsers -Groups $authorizedGroups
    # Returns true if John Doe is either listed as an authorized user or is a member of an authorized group.
#>
function Test-PodeAuthUserGroup {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]
        $User,

        [Parameter()]
        [string[]]
        $Users,

        [Parameter()]
        [string[]]
        $Groups
    )

    $haveUsers = (($null -ne $Users) -and ($Users.Length -gt 0))
    $haveGroups = (($null -ne $Groups) -and ($Groups.Length -gt 0))

    # if there are no groups/users supplied, return user is valid
    if (!$haveUsers -and !$haveGroups) {
        return $true
    }

    # before checking supplied groups, is the user in the supplied list of authorised users?
    if ($haveUsers -and (@($Users) -icontains $User.Username)) {
        return $true
    }

    # if there are groups supplied, check the user is a member of one
    if ($haveGroups) {
        foreach ($group in $Groups) {
            if (@($User.Groups) -icontains $group) {
                return $true
            }
        }
    }

    return $false
}

function Invoke-PodeAuthValidation {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    # get auth method
    $auth = $PodeContext.Server.Authentications.Methods[$Name]

    # if it's a merged auth, re-call this function and check against "succeed" value
    if ($auth.Merged) {
        $results = @{}
        foreach ($authName in $auth.Authentications) {
            $result = Invoke-PodeAuthValidation -Name $authName

            # if the auth is trying to redirect, we need to bubble the this back now
            if ($result.Redirected) {
                return $result
            }

            # if the auth passed, and we only need one auth to pass, return current result
            if ($result.Success -and $auth.PassOne) {
                return $result
            }

            # if the auth failed, but we need all to pass, return current result
            if (!$result.Success -and !$auth.PassOne) {
                return $result
            }

            # remember result if we need all to pass
            if (!$auth.PassOne) {
                $results[$authName] = $result
            }
        }
        # if the last auth failed, and we only need one auth to pass, set failure and return
        if (!$result.Success -and $auth.PassOne) {
            return $result
        }

        # if the last auth succeeded, and we need all to pass, merge users/headers and return result
        if ($result.Success -and !$auth.PassOne) {
            # invoke scriptblock, or use result of merge default
            if ($null -ne $auth.ScriptBlock.Script) {
                $result = Invoke-PodeAuthInbuiltScriptBlock -User $results -ScriptBlock $auth.ScriptBlock.Script -UsingVariables $auth.ScriptBlock.UsingVariables
            }
            else {
                $result = $results[$auth.MergeDefault]
            }

            # reset default properties and return
            $result.Success = $true
            $result.Auth = $results.Keys
            return $result
        }

        # default failure
        return @{
            Success    = $false
            StatusCode = 500
        }
    }

    # main auth validation logic
    $result = (Test-PodeAuthValidation -Name $Name)
    $result.Auth = $Name
    return $result
}

function Test-PodeAuthValidation {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    try {
        # get auth method
        $auth = $PodeContext.Server.Authentications.Methods[$Name]

        # auth result
        $result = $null

        # run pre-auth middleware
        if ($null -ne $auth.Scheme.Middleware) {
            if (!(Invoke-PodeMiddleware -Middleware $auth.Scheme.Middleware)) {
                return @{
                    Success = $false
                }
            }
        }

        # run auth scheme script to parse request for data
        $_args = @(Merge-PodeScriptblockArguments -ArgumentList $auth.Scheme.Arguments -UsingVariables $auth.Scheme.ScriptBlock.UsingVariables)

        # call inner schemes first
        if ($null -ne $auth.Scheme.InnerScheme) {
            $schemes = @()

            $_scheme = $auth.Scheme
            $_inner = @(while ($null -ne $_scheme.InnerScheme) {
                    $_scheme = $_scheme.InnerScheme
                    $_scheme
                })

            for ($i = $_inner.Length - 1; $i -ge 0; $i--) {
                $_tmp_args = @(Merge-PodeScriptblockArguments -ArgumentList $_inner[$i].Arguments -UsingVariables $_inner[$i].ScriptBlock.UsingVariables)

                $_tmp_args += , $schemes
                $result = (Invoke-PodeScriptBlock -ScriptBlock $_inner[$i].ScriptBlock.Script -Arguments $_tmp_args -Return -Splat)
                if ($result -is [hashtable]) {
                    break
                }

                $schemes += , $result
                $result = $null
            }

            $_args += , $schemes
        }

        if ($null -eq $result) {
            $result = (Invoke-PodeScriptBlock -ScriptBlock $auth.Scheme.ScriptBlock.Script -Arguments $_args -Return -Splat)
        }

        # if data is a hashtable, then don't call validator (parser either failed, or forced a success)
        if ($result -isnot [hashtable]) {
            $original = $result

            $_args = @($result) + @($auth.Arguments)
            $result = (Invoke-PodeScriptBlock -ScriptBlock $auth.ScriptBlock -Arguments $_args -UsingVariables $auth.UsingVariables -Return -Splat)

            # if we have user, then run post validator if present
            if ([string]::IsNullOrEmpty($result.Code) -and ($null -ne $auth.Scheme.PostValidator.Script)) {
                $_args = @($original) + @($result) + @($auth.Scheme.Arguments)
                $result = (Invoke-PodeScriptBlock -ScriptBlock $auth.Scheme.PostValidator.Script -Arguments $_args -UsingVariables $auth.Scheme.PostValidator.UsingVariables -Return -Splat)
            }
        }

        # is the auth trying to redirect ie: oauth?
        if ($result.IsRedirected) {
            return @{
                Success    = $false
                Redirected = $true
            }
        }

        # if there's no result, or no user, then the auth failed - but allow auth if anon enabled
        if (($null -eq $result) -or ($result.Count -eq 0) -or (Test-PodeIsEmpty $result.User)) {
            $code = (Protect-PodeValue -Value $result.Code -Default 401)

            # set the www-auth header
            $validCode = (($code -eq 401) -or ![string]::IsNullOrEmpty($result.Challenge))

            if ($validCode) {
                if ($null -eq $result) {
                    $result = @{}
                }

                if ($null -eq $result.Headers) {
                    $result.Headers = @{}
                }

                if (![string]::IsNullOrWhiteSpace($auth.Scheme.Name) -and !$result.Headers.ContainsKey('WWW-Authenticate')) {
                    $authHeader = Get-PodeAuthWwwHeaderValue -Name $auth.Scheme.Name -Realm $auth.Scheme.Realm -Challenge $result.Challenge
                    $result.Headers['WWW-Authenticate'] = $authHeader
                }
            }

            return @{
                Success         = $false
                StatusCode      = $code
                Description     = $result.Message
                Headers         = $result.Headers
                FailureRedirect = [bool]$result.IsErrored
            }
        }

        # authentication was successful
        return @{
            Success = $true
            User    = $result.User
            Headers = $result.Headers
        }
    }
    catch {
        $_ | Write-PodeErrorLog
        return @{
            Success    = $false
            StatusCode = 500
            Exception  = $_
        }
    }
}

function Get-PodeAuthMiddlewareScript {
    return {
        param($opts)

        return Test-PodeAuthInternal `
            -Name $opts.Name `
            -Login:($opts.Login) `
            -Logout:($opts.Logout) `
            -AllowAnon:($opts.Anon)
    }
}

function Test-PodeAuthInternal {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [switch]
        $Login,

        [switch]
        $Logout,

        [switch]
        $AllowAnon
    )

    # get the auth method
    $auth = $PodeContext.Server.Authentications.Methods[$Name]

    # check for logout command
    if ($Logout) {
        Remove-PodeAuthSession

        if ($PodeContext.Server.Sessions.Info.UseHeaders) {
            return Set-PodeAuthStatus `
                -StatusCode 401 `
                -Name $Name `
                -NoSuccessRedirect
        }
        else {
            $auth.Failure.Url = (Protect-PodeValue -Value $auth.Failure.Url -Default $WebEvent.Request.Url.AbsolutePath)
            return Set-PodeAuthStatus `
                -StatusCode 302 `
                -Name $Name `
                -NoSuccessRedirect
        }
    }

    # if the session already has a user/isAuth'd, then skip auth - or allow anon
    if (Test-PodeSessionsInUse) {
        # existing session auth'd
        if (Test-PodeAuthUser) {
            $WebEvent.Auth = $WebEvent.Session.Data.Auth
            return Set-PodeAuthStatus `
                -Name $Name `
                -LoginRoute:($Login) `
                -NoSuccessRedirect
        }

        # if we're allowing anon access, and using sessions, then stop here - as a session will be created from a login route for auth'ing users
        if ($AllowAnon) {
            if (!(Test-PodeIsEmpty $WebEvent.Session.Data.Auth)) {
                Revoke-PodeSession
            }

            return $true
        }
    }

    # check if the login flag is set, in which case just return and load a login get-page (allowing anon access)
    if ($Login -and !$PodeContext.Server.Sessions.Info.UseHeaders -and ($WebEvent.Method -ieq 'get')) {
        if (!(Test-PodeIsEmpty $WebEvent.Session.Data.Auth)) {
            Revoke-PodeSession
        }

        return $true
    }

    try {
        $result = Invoke-PodeAuthValidation -Name $Name
    }
    catch {
        $_ | Write-PodeErrorLog
        return Set-PodeAuthStatus `
            -StatusCode 500 `
            -Description $_.Exception.Message `
            -Name $Name
    }

    # did the auth force a redirect?
    if ($result.Redirected) {
        $success = Get-PodeAuthSuccessInfo -Name $Name
        Set-PodeAuthRedirectUrl -UseOrigin:($success.UseOrigin)
        return $false
    }

    # if auth failed, are we allowing anon access?
    if (!$result.Success -and $AllowAnon) {
        return $true
    }

    # if auth failed, set appropriate response headers/redirects
    if (!$result.Success) {
        return Set-PodeAuthStatus `
            -StatusCode $result.StatusCode `
            -Description $result.Description `
            -Headers $result.Headers `
            -Name $Name `
            -LoginRoute:$Login `
            -NoFailureRedirect:($result.FailureRedirect)
    }

    # if auth passed, assign the user to the session
    $WebEvent.Auth = [ordered]@{
        User            = $result.User
        IsAuthenticated = $true
        IsAuthorised    = $true
        Store           = !$auth.Sessionless
        Name            = $result.Auth
    }

    # successful auth
    $authName = $null
    if ($auth.Merged -and !$auth.PassOne) {
        $authName = $Name
    }
    else {
        $authName = @($result.Auth)[0]
    }

    return Set-PodeAuthStatus `
        -Headers $result.Headers `
        -Name $authName `
        -LoginRoute:$Login
}

function Get-PodeAuthWwwHeaderValue {
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

function Remove-PodeAuthSession {
    # blank out the auth
    $WebEvent.Auth = @{}

    # if a session auth is found, blank it
    if (!(Test-PodeIsEmpty $WebEvent.Session.Data.Auth)) {
        $WebEvent.Session.Data.Remove('Auth')
    }

    # Delete the current session (remove from store, blank it, and remove from Response)
    Revoke-PodeSession
}

function Get-PodeAuthFailureInfo {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [hashtable]
        $Info,

        [Parameter()]
        [string]
        $BaseName
    )

    # base name
    if ([string]::IsNullOrEmpty($BaseName)) {
        $BaseName = $Name
    }

    # get auth method
    $auth = $PodeContext.Server.Authentications.Methods[$Name]

    # cached failure?
    if ($null -ne $auth.Cache.Failure) {
        return $auth.Cache.Failure
    }

    # find failure info
    if ($null -eq $Info) {
        $Info = @{
            Url     = $auth.Failure.Url
            Message = $auth.Failure.Message
        }
    }

    if ([string]::IsNullOrEmpty($Info.Url)) {
        $Info.Url = $auth.Failure.Url
    }

    if ([string]::IsNullOrEmpty($Info.Message)) {
        $Info.Message = $auth.Failure.Message
    }

    if ((![string]::IsNullOrEmpty($Info.Url) -and ![string]::IsNullOrEmpty($Info.Message)) -or [string]::IsNullOrEmpty($auth.Parent)) {
        $PodeContext.Server.Authentications.Methods[$BaseName].Cache.Failure = $Info
        return $Info
    }

    return (Get-PodeAuthFailureInfo -Name $auth.Parent -Info $Info -BaseName $BaseName)
}

function Get-PodeAuthSuccessInfo {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [hashtable]
        $Info,

        [Parameter()]
        [string]
        $BaseName
    )

    # base name
    if ([string]::IsNullOrEmpty($BaseName)) {
        $BaseName = $Name
    }

    # get auth method
    $auth = $PodeContext.Server.Authentications.Methods[$Name]

    # cached success?
    if ($null -ne $auth.Cache.Success) {
        return $auth.Cache.Success
    }

    # find success info
    if ($null -eq $Info) {
        $Info = @{
            Url       = $auth.Success.Url
            UseOrigin = $auth.Success.UseOrigin
        }
    }

    if ([string]::IsNullOrEmpty($Info.Url)) {
        $Info.Url = $auth.Success.Url
    }

    if (!$Info.UseOrigin) {
        $Info.UseOrigin = $auth.Success.UseOrigin
    }

    if ((![string]::IsNullOrEmpty($Info.Url) -and $Info.UseOrigin) -or [string]::IsNullOrEmpty($auth.Parent)) {
        $PodeContext.Server.Authentications.Methods[$BaseName].Cache.Success = $Info
        return $Info
    }

    return (Get-PodeAuthSuccessInfo -Name $auth.Parent -Info $Info -BaseName $BaseName)
}

function Set-PodeAuthStatus {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [int]
        $StatusCode = 0,

        [Parameter()]
        [string]
        $Description,

        [Parameter()]
        [hashtable]
        $Headers,

        [switch]
        $LoginRoute,

        [switch]
        $NoSuccessRedirect,

        [switch]
        $NoFailureRedirect
    )

    # if we have any headers, set them
    if (($null -ne $Headers) -and ($Headers.Count -gt 0)) {
        foreach ($key in $Headers.Keys) {
            Set-PodeHeader -Name $key -Value $Headers[$key]
        }
    }

    # get auth method
    $auth = $PodeContext.Server.Authentications.Methods[$Name]

    # get Success object from auth
    $success = Get-PodeAuthSuccessInfo -Name $Name

    # if a statuscode supplied, assume failure
    if ($StatusCode -gt 0) {
        # get Failure object from auth
        $failure = Get-PodeAuthFailureInfo -Name $Name

        # override description with the failureMessage if supplied
        $Description = (Protect-PodeValue -Value $failure.Message -Default $Description)

        # add error to flash
        if ($LoginRoute -and !$auth.Sessionless -and ![string]::IsNullOrWhiteSpace($Description)) {
            Add-PodeFlashMessage -Name 'auth-error' -Message $Description
        }

        # check if we have a failure url redirect
        if (!$NoFailureRedirect -and ![string]::IsNullOrWhiteSpace($failure.Url)) {
            Set-PodeAuthRedirectUrl -UseOrigin:($success.UseOrigin)
            Move-PodeResponseUrl -Url $failure.Url
        }
        else {
            Set-PodeResponseStatus -Code $StatusCode -Description $Description
        }

        return $false
    }

    # if no statuscode, success, so check if we have a success url redirect (but only for auto-login routes)
    if (!$NoSuccessRedirect -or $LoginRoute) {
        $url = Get-PodeAuthRedirectUrl -Url $success.Url -UseOrigin:($success.UseOrigin)
        if (![string]::IsNullOrWhiteSpace($url)) {
            Move-PodeResponseUrl -Url $url
            return $false
        }
    }

    return $true
}

function Get-PodeADServerFromDistinguishedName {
    param(
        [Parameter()]
        [string]
        $DistinguishedName
    )

    if ([string]::IsNullOrWhiteSpace($DistinguishedName)) {
        return [string]::Empty
    }

    $parts = @($DistinguishedName -split ',')
    $name = @()

    foreach ($part in $parts) {
        if ($part -imatch '^DC=(?<name>.+)$') {
            $name += $Matches['name']
        }
    }

    return ($name -join '.')
}

function Get-PodeAuthADResult {
    param(
        [Parameter()]
        [string]
        $Server,

        [Parameter()]
        [string]
        $Domain,

        [Parameter()]
        [string]
        $SearchBase,

        [Parameter()]
        [string]
        $Username,

        [Parameter()]
        [string]
        $Password,

        [Parameter()]
        [ValidateSet('DirectoryServices', 'ActiveDirectory', 'OpenLDAP')]
        [string]
        $Provider,

        [switch]
        $NoGroups,

        [switch]
        $DirectGroups,

        [switch]
        $KeepCredential
    )

    try {
        # validate the user's AD creds
        $result = (Open-PodeAuthADConnection -Server $Server -Domain $Domain -Username $Username -Password $Password -Provider $Provider)
        if (!$result.Success) {
            return @{ Message = 'Invalid credentials supplied' }
        }

        # get the connection
        $connection = $result.Connection

        # get the user
        $user = (Get-PodeAuthADUser -Connection $connection -Username $Username -Provider $Provider)
        if ($null -eq $user) {
            return @{ Message = 'User not found in Active Directory' }
        }

        # get the users groups
        $groups = @()
        if (!$NoGroups) {
            $groups = (Get-PodeAuthADGroup -Connection $connection -DistinguishedName $user.DistinguishedName -Username $Username -Direct:$DirectGroups -Provider $Provider)
        }

        # check if we want to keep the credentials in the User object
        if ($KeepCredential) {
            $credential = [pscredential]::new($($Domain + '\' + $Username), (ConvertTo-SecureString -String $Password -AsPlainText -Force))
        }
        else {
            $credential = $null
        }

        # return the user
        return @{
            User = @{
                UserType           = 'Domain'
                AuthenticationType = 'LDAP'
                DistinguishedName  = $user.DistinguishedName
                Username           = ($Username -split '\\')[-1]
                Name               = $user.Name
                Email              = $user.Email
                Fqdn               = $Server
                Domain             = $Domain
                Groups             = $groups
                Credential         = $credential
            }
        }
    }
    finally {
        if ($null -ne $connection) {
            switch ($Provider.ToLowerInvariant()) {
                'openldap' {
                    $connection.Username = $null
                    $connection.Password = $null
                }

                'activedirectory' {
                    $connection.Credential = $null
                }

                'directoryservices' {
                    Close-PodeDisposable -Disposable $connection.Searcher
                    Close-PodeDisposable -Disposable $connection.Entry -Close
                }
            }
        }
    }
}

function Open-PodeAuthADConnection {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Server,

        [Parameter()]
        [string]
        $Domain,

        [Parameter()]
        [string]
        $SearchBase,

        [Parameter()]
        [string]
        $Username,

        [Parameter()]
        [string]
        $Password,

        [Parameter()]
        [ValidateSet('LDAP', 'WinNT')]
        [string]
        $Protocol = 'LDAP',

        [Parameter()]
        [ValidateSet('DirectoryServices', 'ActiveDirectory', 'OpenLDAP')]
        [string]
        $Provider
    )

    $result = $true
    $connection = $null

    # validate the user's AD creds
    switch ($Provider.ToLowerInvariant()) {
        'openldap' {
            if (![string]::IsNullOrWhiteSpace($SearchBase)) {
                $baseDn = $SearchBase
            }
            else {
                $baseDn = "DC=$(($Server -split '\.') -join ',DC=')"
            }

            $query = (Get-PodeAuthADQuery -Username $Username)
            $hostname = "$($Protocol)://$($Server)"

            $user = $Username
            if (!$Username.StartsWith($Domain)) {
                $user = "$($Domain)\$($Username)"
            }

            $null = (ldapsearch -x -LLL -H "$($hostname)" -D "$($user)" -w "$($Password)" -b "$($baseDn)" -o ldif-wrap=no "$($query)" dn)
            if (!$? -or ($LASTEXITCODE -ne 0)) {
                $result = $false
            }
            else {
                $connection = @{
                    Hostname = $hostname
                    Username = $user
                    BaseDN   = $baseDn
                    Password = $Password
                }
            }
        }

        'activedirectory' {
            try {
                $creds = [pscredential]::new($Username, (ConvertTo-SecureString -String $Password -AsPlainText -Force))
                $null = Get-ADUser -Identity $Username -Credential $creds -ErrorAction Stop
                $connection = @{
                    Credential = $creds
                }
            }
            catch {
                $result = $false
            }
        }

        'directoryservices' {
            if ([string]::IsNullOrWhiteSpace($Password)) {
                $ad = [System.DirectoryServices.DirectoryEntry]::new("$($Protocol)://$($Server)")
            }
            else {
                $ad = [System.DirectoryServices.DirectoryEntry]::new("$($Protocol)://$($Server)", "$($Username)", "$($Password)")
            }

            if (Test-PodeIsEmpty $ad.distinguishedName) {
                $result = $false
            }
            else {
                $connection = @{
                    Entry = $ad
                }
            }
        }
    }

    return @{
        Success    = $result
        Connection = $connection
    }
}

function Get-PodeAuthADQuery {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Username
    )

    return "(&(objectCategory=person)(samaccountname=$($Username)))"
}

function Get-PodeAuthADUser {
    param(
        [Parameter(Mandatory = $true)]
        $Connection,

        [Parameter(Mandatory = $true)]
        [string]
        $Username,

        [Parameter()]
        [ValidateSet('DirectoryServices', 'ActiveDirectory', 'OpenLDAP')]
        [string]
        $Provider
    )

    $query = (Get-PodeAuthADQuery -Username $Username)
    $user = $null

    # generate query to find user
    switch ($Provider.ToLowerInvariant()) {
        'openldap' {
            $result = (ldapsearch -x -LLL -H "$($Connection.Hostname)" -D "$($Connection.Username)" -w "$($Connection.Password)" -b "$($Connection.BaseDN)" -o ldif-wrap=no "$($query)" name mail)
            if (!$? -or ($LASTEXITCODE -ne 0)) {
                return $null
            }

            $user = @{
                DistinguishedName = (Get-PodeOpenLdapValue -Lines $result -Property 'dn')
                Name              = (Get-PodeOpenLdapValue -Lines $result -Property 'name')
                Email             = (Get-PodeOpenLdapValue -Lines $result -Property 'mail')
            }
        }

        'activedirectory' {
            $result = Get-ADUser -LDAPFilter $query -Credential $Connection.Credential -Properties mail
            $user = @{
                DistinguishedName = $result.DistinguishedName
                Name              = $result.Name
                Email             = $result.mail
            }
        }

        'directoryservices' {
            $Connection.Searcher = [System.DirectoryServices.DirectorySearcher]::new($Connection.Entry)
            $Connection.Searcher.filter = $query

            $result = $Connection.Searcher.FindOne().Properties
            if (Test-PodeIsEmpty $result) {
                return $null
            }

            $user = @{
                DistinguishedName = @($result.distinguishedname)[0]
                Name              = @($result.name)[0]
                Email             = @($result.mail)[0]
            }
        }
    }

    return $user
}

function Get-PodeOpenLdapValue {
    param(
        [Parameter()]
        [string[]]
        $Lines,

        [Parameter()]
        [string]
        $Property,

        [switch]
        $All
    )

    foreach ($line in $Lines) {
        if ($line -imatch "^$($Property)\:\s+(?<$($Property)>.+)$") {
            # return the first found
            if (!$All) {
                return $Matches[$Property]
            }

            # return array of all
            $Matches[$Property]
        }
    }
}
<#
.SYNOPSIS
    Retrieves Active Directory (AD) group information for a user.

.DESCRIPTION
    This function retrieves AD group information for a specified user. It supports two modes of operation:
    1. Direct: Retrieves groups directly associated with the user.
    2. All: Retrieves all groups within the specified distinguished name (DN).

.PARAMETER Connection
    The AD connection object or credentials for connecting to the AD server.

.PARAMETER DistinguishedName
    The distinguished name (DN) of the user or group. If not provided, the default DN is used.

.PARAMETER Username
    The username for which to retrieve group information.

.PARAMETER Provider
    The AD provider to use (e.g., 'DirectoryServices', 'ActiveDirectory', 'OpenLDAP').

.PARAMETER Direct
    Switch parameter. If specified, retrieves only direct group memberships for the user.

.OUTPUTS
    Returns AD group information as needed based on the mode of operation.

.EXAMPLE
    Get-PodeAuthADGroup -Connection $adConnection -Username "john.doe"
    # Retrieves all AD groups for the user "john.doe".

    Get-PodeAuthADGroup -Connection $adConnection -Username "jane.smith" -Direct
    # Retrieves only direct group memberships for the user "jane.smith".
#>
function Get-PodeAuthADGroup {
    param(
        [Parameter(Mandatory = $true)]
        $Connection,

        [Parameter()]
        [string]
        $DistinguishedName,

        [Parameter()]
        [string]
        $Username,

        [Parameter()]
        [ValidateSet('DirectoryServices', 'ActiveDirectory', 'OpenLDAP')]
        [string]
        $Provider,

        [switch]
        $Direct
    )

    if ($Direct) {
        return (Get-PodeAuthADGroupDirect -Connection $Connection -Username $Username -Provider $Provider)
    }

    return (Get-PodeAuthADGroupAll -Connection $Connection -DistinguishedName $DistinguishedName -Provider $Provider)
}

function Get-PodeAuthADGroupDirect {
    param(
        [Parameter(Mandatory = $true)]
        $Connection,

        [Parameter()]
        [string]
        $Username,

        [Parameter()]
        [ValidateSet('DirectoryServices', 'ActiveDirectory', 'OpenLDAP')]
        [string]
        $Provider
    )

    # create the query
    $query = "(&(objectCategory=person)(samaccountname=$($Username)))"
    $groups = @()

    # get the groups
    switch ($Provider.ToLowerInvariant()) {
        'openldap' {
            $result = (ldapsearch -x -LLL -H "$($Connection.Hostname)" -D "$($Connection.Username)" -w "$($Connection.Password)" -b "$($Connection.BaseDN)" -o ldif-wrap=no "$($query)" memberof)
            $groups = (Get-PodeOpenLdapValue -Lines $result -Property 'memberof' -All)
        }

        'activedirectory' {
            $groups = (Get-ADPrincipalGroupMembership -Identity $Username -Credential $Connection.Credential).distinguishedName
        }

        'directoryservices' {
            if ($null -eq $Connection.Searcher) {
                $Connection.Searcher = [System.DirectoryServices.DirectorySearcher]::new($Connection.Entry)
            }

            $Connection.Searcher.filter = $query
            $groups = @($Connection.Searcher.FindOne().Properties.memberof)
        }
    }

    $groups = @(foreach ($group in $groups) {
            if ($group -imatch '^CN=(?<group>.+?),') {
                $Matches['group']
            }
        })

    return $groups
}

function Get-PodeAuthADGroupAll {
    param(
        [Parameter(Mandatory = $true)]
        $Connection,

        [Parameter()]
        [string]
        $DistinguishedName,

        [Parameter()]
        [ValidateSet('DirectoryServices', 'ActiveDirectory', 'OpenLDAP')]
        [string]
        $Provider
    )

    # create the query
    $query = "(member:1.2.840.113556.1.4.1941:=$($DistinguishedName))"
    $groups = @()

    # get the groups
    switch ($Provider.ToLowerInvariant()) {
        'openldap' {
            $result = (ldapsearch -x -LLL -H "$($Connection.Hostname)" -D "$($Connection.Username)" -w "$($Connection.Password)" -b "$($Connection.BaseDN)" -o ldif-wrap=no "$($query)" samaccountname)
            $groups = (Get-PodeOpenLdapValue -Lines $result -Property 'sAMAccountName' -All)
        }

        'activedirectory' {
            $groups = (Get-ADObject -LDAPFilter $query -Credential $Connection.Credential).Name
        }

        'directoryservices' {
            if ($null -eq $Connection.Searcher) {
                $Connection.Searcher = [System.DirectoryServices.DirectorySearcher]::new($Connection.Entry)
            }

            $null = $Connection.Searcher.PropertiesToLoad.Add('samaccountname')
            $Connection.Searcher.filter = $query
            $groups = @($Connection.Searcher.FindAll().Properties.samaccountname)
        }
    }

    return $groups
}

function Get-PodeAuthDomainName {
    $domain = $null

    if (Test-PodeIsMacOS) {
        $domain = (scutil --dns | grep -m 1 'search domain\[0\]' | cut -d ':' -f 2)
    }
    elseif (Test-PodeIsUnix) {
        $domain = (dnsdomainname)
        if ([string]::IsNullOrWhiteSpace($domain)) {
            $domain = (/usr/sbin/realm list --name-only)
        }
    }
    else {
        $domain = $env:USERDNSDOMAIN
        if ([string]::IsNullOrWhiteSpace($domain)) {
            $domain = (Get-CimInstance -Class Win32_ComputerSystem -Verbose:$false).Domain
        }
    }

    if (![string]::IsNullOrEmpty($domain)) {
        $domain = $domain.Trim()
    }

    return $domain
}

function Find-PodeAuth {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name
    )

    return $PodeContext.Server.Authentications.Methods[$Name]
}

<#
.SYNOPSIS
  Expands a list of authentication names, including merged authentication methods.

.DESCRIPTION
  The Expand-PodeAuthMerge function takes an array of authentication names and expands it by resolving any merged authentication methods
  into their individual components. It is particularly useful in scenarios where authentication methods are combined or merged, and there
  is a need to process each individual method separately.

.PARAMETER Names
  An array of authentication method names. These names can include both discrete authentication methods and merged ones.

.EXAMPLE
  $expandedAuthNames = Expand-PodeAuthMerge -Names @('BasicAuth', 'CustomMergedAuth')

  Expands the provided authentication names, resolving 'CustomMergedAuth' into its constituent authentication methods if it's a merged one.
#>
function Expand-PodeAuthMerge {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Names
    )

    # Initialize a hashtable to store expanded authentication names
    $authNames = @{}

    # Iterate over each authentication name
    foreach ($authName in $Names) {
        # Handle the special case of anonymous access
        if ($authName -eq '%_allowanon_%') {
            $authNames[$authName] = $true
        }
        else {
            # Retrieve the authentication method from the Pode context
            $_auth = $PodeContext.Server.Authentications.Methods[$authName]

            # Check if the authentication is a merged one and expand it
            if ($_auth.merged) {
                foreach ($key in (Expand-PodeAuthMerge -Names $_auth.Authentications)) {
                    $authNames[$key] = $true
                }
            }
            else {
                # If not merged, add the authentication name to the list
                $authNames[$_auth.Name] = $true
            }
        }
    }

    # Return the keys of the hashtable, which are the expanded authentication names
    return $authNames.Keys
}


function Import-PodeAuthADModule {
    if (!(Test-PodeIsWindows)) {
        # Active Directory module only available on Windows
        throw ($PodeLocale.adModuleWindowsOnlyExceptionMessage)
    }

    if (!(Test-PodeModuleInstalled -Name ActiveDirectory)) {
        # Active Directory module is not installed
        throw ($PodeLocale.adModuleNotInstalledExceptionMessage)
    }

    Import-Module -Name ActiveDirectory -Force -ErrorAction Stop
    Export-PodeModule -Name ActiveDirectory
}

function Get-PodeAuthADProvider {
    param(
        [switch]
        $OpenLDAP,

        [switch]
        $ADModule
    )

    # openldap (literal, or not windows)
    if ($OpenLDAP -or !(Test-PodeIsWindows)) {
        return 'OpenLDAP'
    }

    # ad module
    if ($ADModule) {
        return 'ActiveDirectory'
    }

    # ds
    return 'DirectoryServices'
}

function Set-PodeAuthRedirectUrl {
    param(
        [switch]
        $UseOrigin
    )

    if ($UseOrigin -and ($WebEvent.Method -ieq 'get')) {
        $null = Set-PodeCookie -Name 'pode.redirecturl' -Value $WebEvent.Request.Url.PathAndQuery
    }
}

function Get-PodeAuthRedirectUrl {
    param(
        [Parameter()]
        [string]
        $Url,

        [switch]
        $UseOrigin
    )

    if (!$UseOrigin) {
        return $Url
    }

    $tmpUrl = Get-PodeCookieValue -Name 'pode.redirecturl'
    Remove-PodeCookie -Name 'pode.redirecturl'

    if (![string]::IsNullOrWhiteSpace($tmpUrl)) {
        $Url = $tmpUrl
    }

    return $Url
}