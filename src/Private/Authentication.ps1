function Get-PodeAuthBasicType {
    <#
    .SYNOPSIS
        Processes Basic Authentication from the Authorization header.

    .DESCRIPTION
        The `Get-PodeAuthBasicType` function extracts and validates the Basic Authorization header
        from an HTTP request. It verifies the header format, decodes Base64 credentials,
        and returns the extracted username and password. If any validation step fails,
        an appropriate HTTP response code and challenge are returned.

    .PARAMETER options
        A hashtable containing options for processing the authentication:
        - `HeaderTag` [string]: Expected header prefix (e.g., "Basic").
        - `Encoding` [string]: Character encoding for decoding the credentials (default: UTF-8).
        - `AsCredential` [bool]: If true, returns credentials as a [PSCredential] object.

    .OUTPUTS
        [array]
        Returns an array containing the extracted username and password.
        If `AsCredential` is set to `$true`, returns a `[PSCredential]` object.

    .EXAMPLE
        $options = @{ HeaderTag = 'Basic'; Encoding = 'UTF-8'; AsCredential = $false }
        $result = Get-PodeAuthBasicType -options $options

        Returns:
        @('username', 'password')

    .EXAMPLE
        $options = @{ HeaderTag = 'Basic'; Encoding = 'UTF-8'; AsCredential = $true }
        $result = Get-PodeAuthBasicType -options $options

        Returns:
        [PSCredential] object containing username and password.

    .NOTES
        This function is internal to Pode and subject to change in future releases.

        Possible response codes:
        - 401 Unauthorized: When the Authorization header is missing.
        - 400 Bad Request: For invalid format, encoding, or credential issues.

        Challenge responses include the following error types:
        - `invalid_request` for missing or incorrectly formatted headers.
        - `invalid_token` for improperly encoded or malformed credentials.
    #>
    return {
        param($options)

        # get the auth header
        $header = (Get-PodeHeader -Name 'Authorization')
        if ($null -eq $header) {
            $message = 'No Authorization header found'
            return @{
                Message   = $message
                Challenge = (New-PodeAuthChallenge -ErrorType invalid_request -ErrorDescription $message)
                Code      = 401
            }
        }

        # ensure the first atom is basic (or opt override)
        $atoms = $header -isplit '\s+'
        if ($atoms.Length -lt 2) {
            $message = 'Invalid Authorization header format'
            return @{
                Message   = $message
                Challenge = (New-PodeAuthChallenge -ErrorType invalid_request -ErrorDescription $message)
                Code      = 400
            }
        }

        if ($atoms[0] -ine $options.HeaderTag) {
            $message = "Header is not for $($options.HeaderTag) Authorization"
            return @{
                Message   = $message
                Challenge = (New-PodeAuthChallenge -ErrorType invalid_request -ErrorDescription $message)
                Code      = 400
            }
        }

        # decode the auth header
        try {
            $enc = [System.Text.Encoding]::GetEncoding($options.Encoding)
        }
        catch {
            $message = 'Invalid encoding specified for Authorization'
            return @{
                Message   = $message
                Challenge = (New-PodeAuthChallenge -ErrorType invalid_request -ErrorDescription $message)
                Code      = 400
            }
        }

        try {
            $decoded = $enc.GetString([System.Convert]::FromBase64String($atoms[1]))
        }
        catch {
            $message = 'Invalid Base64 string found in Authorization header'
            return @{
                Message   = $message
                Challenge = (New-PodeAuthChallenge -ErrorType invalid_token -ErrorDescription $message)
                Code      = 400
            }
        }

        # ensure the decoded string contains a colon separator
        $index = $decoded.IndexOf(':')
        if ($index -lt 0) {
            $message = 'Invalid Authorization credential format'
            return @{
                Message   = $message
                Challenge = (New-PodeAuthChallenge -ErrorType invalid_request -ErrorDescription $message)
                Code      = 400
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
    <#
    .SYNOPSIS
        Validates and extracts information from a client certificate in an HTTP request.

    .DESCRIPTION
        The `Get-PodeAuthClientCertificateType` function processes the client certificate
        from an incoming HTTP request. It validates whether the certificate is supplied,
        checks its validity, and ensures it's trusted. If any of these checks fail,
        appropriate response codes and challenges are returned.

    .PARAMETER options
        A hashtable containing options that can be used to extend the function in the future.

    .OUTPUTS
        [array]
        Returns an array containing the validated client certificate and any associated errors.

    .EXAMPLE
        $options = @{}
        $result = Get-PodeAuthClientCertificateType -options $options

        Returns:
        An array with the client certificate object and any certificate validation errors.

    .EXAMPLE
        $options = @{}
        $result = Get-PodeAuthClientCertificateType -options $options

        Example Output:
        @($cert, 0)

    .NOTES
        This function is internal to Pode and subject to change in future releases.

        Possible response codes:
        - 401 Unauthorized: When the client certificate is missing or invalid.
        - 403 Forbidden: When the client certificate is untrusted.

        Challenge responses include the following error types:
        - `invalid_request`: If no certificate is provided.
        - `invalid_token`: If the certificate is invalid, expired, or untrusted.

    #>
    return {
        param($options)
        $cert = $WebEvent.Request.ClientCertificate

        # ensure we have a client cert
        if ($null -eq $cert) {
            $message = 'No client certificate supplied'
            return @{
                Message   = $message
                Challenge = (New-PodeAuthChallenge -ErrorType invalid_request -ErrorDescription $message)
                Code      = 401
            }
        }

        # ensure the cert has a thumbprint
        if ([string]::IsNullOrWhiteSpace($cert.Thumbprint)) {
            $message = 'Invalid client certificate supplied'
            return @{
                Message   = $message
                Challenge = (New-PodeAuthChallenge -ErrorType invalid_token -ErrorDescription $message)
                Code      = 401
            }
        }

        # ensure the cert hasn't expired, or has it even started
        $now = [datetime]::Now
        if (($cert.NotAfter -lt $now) -or ($cert.NotBefore -gt $now)) {
            $message = 'Invalid client certificate supplied (expired or not yet valid)'
            return @{
                Message   = $message
                Challenge = (New-PodeAuthChallenge -ErrorType invalid_token -ErrorDescription $message)
                Code      = 401
            }
        }

        $errors = $WebEvent.Request.ClientCertificateErrors
        if ($errors -ne 0) {
            $message = 'Untrusted client certificate supplied'
            return @{
                Message   = $message
                Challenge = (New-PodeAuthChallenge -ErrorType invalid_token -ErrorDescription $message)
                Code      = 403
            }
        }

        # return data for calling validator
        return @($cert, $WebEvent.Request.ClientCertificateErrors)
    }
}


function Get-PodeAuthApiKeyType {
    <#
    .SYNOPSIS
        Handles API key authentication by retrieving the key from various locations.

    .DESCRIPTION
        The `Get-PodeAuthApiKeyType` function extracts and validates API keys
        from specified locations such as headers, query parameters, or cookies.
        If the API key is found, it is returned as a result; otherwise,
        an appropriate authentication challenge is issued.

    .PARAMETER $options
        A hashtable containing the following keys:
        - `Location`: Specifies where to retrieve the API key from (`header`, `query`, or `cookie`).
        - `LocationName`: The name of the header, query parameter, or cookie that holds the API key.
        - `AsJWT`: (Optional) If set to `$true`, the function will treat the API key as a JWT token.
        - `Secret`: (Required if `AsJWT` is `$true`) The secret used to validate the JWT token.

    .OUTPUTS
        [array]
        Returns an array containing the extracted API key or JWT payload if authentication is successful.

    .NOTES
        The function will return an HTTP 400 response code if the API key is not found.
        If `AsJWT` is enabled, the key will be decoded and validated using the provided secret.
        The challenge response is formatted to align with authentication best practices.

        Possible HTTP response codes:
        - 400 Bad Request: When the API key is missing or JWT validation fails.

    #>
    return {
        param($options)

        # Initialize API key variable
        $apiKey = [string]::Empty

        # Determine API key location and retrieve it
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
            default {
                $message = "Invalid API key location: $($options.Location)"
                return @{
                    Message   = $message
                    Challenge = (New-PodeAuthChallenge -ErrorType invalid_request -ErrorDescription $message)
                    Code      = 400
                }
            }
        }

        # If no API key found, return error
        if ([string]::IsNullOrWhiteSpace($apiKey)) {
            $message = "API key missing in $($options.Location) location: $($options.LocationName)"
            return @{
                Message   = $message
                Challenge = (New-PodeAuthChallenge -ErrorType invalid_request -ErrorDescription $message)
                Code      = 400
            }
        }

        # Trim and process the API key
        $apiKey = $apiKey.Trim()
        $result = @($apiKey)

        # Convert to JWT if required
        if ($options.AsJWT) {
            try {
                $payload = ConvertFrom-PodeJwt -Token $apiKey -Secret $options.Secret
                Test-PodeJwt -Payload $payload
                $result = @($payload)
            }
            catch {
                if ($_.Exception.Message -ilike '*jwt*') {
                    $message = "Invalid JWT token: $($_.Exception.Message)"
                    return @{
                        Message   = $message
                        Challenge = (New-PodeAuthChallenge -ErrorType invalid_request -ErrorDescription $message)
                        Code      = 400
                    }
                }

                throw
            }
        }

        # return the result
        return $result
    }
}

function Get-PodeAuthBearerType {
    <#
    .SYNOPSIS
        Validates the Bearer token in the Authorization header.

    .DESCRIPTION
        This function processes the Authorization header, verifies the presence of a Bearer token,
        and optionally decodes it as a JWT. It returns appropriate HTTP response codes
        as per RFC 6750 (OAuth 2.0 Bearer Token Usage).

    .PARAMETER $options
        A hashtable containing the following keys:
        - Realm: The authentication realm.
        - Scopes: Expected scopes for the token.
        - HeaderTag: The expected Authorization header tag (e.g., 'Bearer').
        - AsJWT: Boolean indicating if the token should be processed as a JWT.
        - Secret: Secret key for JWT verification.

    .OUTPUTS
        A hashtable containing the following keys based on the validation result:
        - Message: Error or success message.
        - Code: HTTP response code.
        - Header: HTTP response header for authentication challenges.
        - Challenge: Optional authentication challenge.

    .NOTES
        The function adheres to RFC 6750, which mandates:
        - 401 Unauthorized for missing or invalid authentication credentials.
        - 400 Bad Request for malformed requests.

        RFC 6750 HTTP Status Code Usage
        # | Scenario                                  | Recommended Status Code |
        # |-------------------------------------------|-------------------------|
        # | No Authorization header provided          | 401 Unauthorized        |
        # | Incorrect Authorization header format     | 401 Unauthorized        |
        # | Wrong authentication scheme used          | 401 Unauthorized        |
        # | Token is empty or malformed               | 400 Bad Request         |
        # | Invalid JWT signature                     | 401 Unauthorized        |
    #>
    return {
        param($options)

        # Get the Authorization header
        $header = (Get-PodeHeader -Name 'Authorization')

        # If no Authorization header is provided, return 401 Unauthorized
        if ($null -eq $header) {
            $message = 'No Authorization header found'
            return @{
                Message   = $message
                Challenge = New-PodeAuthChallenge -Scopes $options.Scopes -ErrorType invalid_request -ErrorDescription $message
                Code      = 401  # RFC 6750: Missing credentials should return 401
            }
        }

        # Ensure the first part of the header is 'Bearer'
        $atoms = $header -isplit '\s+'
        if ($atoms.Length -lt 2) {
            $message = 'Invalid Authorization header format'
            return @{
                Message   = $message
                Challenge = (New-PodeAuthChallenge -Scopes $options.Scopes -ErrorType invalid_request -ErrorDescription $message)
                Code      = 401  # RFC 6750: Invalid credentials format should return 401
            }
        }

        if ($atoms[0] -ine $options.HeaderTag) {
            $message = "Authorization header is not $($options.HeaderTag)"
            return @{
                Message   = $message
                Challenge = (New-PodeAuthChallenge -Scopes $options.Scopes -ErrorType invalid_request -ErrorDescription $message)
                Code      = 401  # RFC 6750: Wrong authentication scheme should return 401
            }
        }

        # 400 Bad Request if no token is provided
        $token = $atoms[1]
        if ([string]::IsNullOrWhiteSpace($token)) {
            $message = 'No Bearer token found'
            return @{
                Message   = $message
                Code      = 400  # RFC 6750: Malformed request should return 400
                Challenge = New-PodeAuthChallenge -Scopes $options.Scopes -ErrorType invalid_request -ErrorDescription $message
            }
        }

        # Trim and build the result
        $token = $token.Trim()
        $result = @($token)

        # Convert to JWT if required
        if ($options.AsJWT) {
            try {
                $payload = ConvertFrom-PodeJwt -Token $token -Secret $options.Secret
                Test-PodeJwt -Payload $payload
            }
            catch {
                if ($_.Exception.Message -ilike '*jwt*') {
                    return @{
                        Message   = $_.Exception.Message
                        Code      = 401  # RFC 6750: Invalid token should return 401
                        Challenge = New-PodeAuthChallenge -Scopes $options.Scopes -ErrorType invalid_token -ErrorDescription $_.Exception.Message
                    }
                }

                throw
            }

            $result = @($payload)
        }

        # Return the validated result
        return $result
    }
}

function Get-PodeAuthBearerPostValidator {
    <#
    .SYNOPSIS
        Validates the Bearer token and user authentication.

    .DESCRIPTION
        This function processes the Bearer token, checks for the presence of a valid user,
        and verifies token scopes against required scopes. It returns appropriate HTTP response codes
        as per RFC 6750 (OAuth 2.0 Bearer Token Usage).

    .PARAMETER token
        The Bearer token provided by the client.

    .PARAMETER result
        The decoded token result containing user and scope information.

    .PARAMETER options
        A hashtable containing the following keys:
        - Scopes: An array of required scopes for authorization.

    .OUTPUTS
        A hashtable containing the following keys based on the validation result:
        - Message: Error or success message.
        - Code: HTTP response code.
        - Challenge: HTTP response challenge in case of errors.

    .NOTES
        The function adheres to RFC 6750, which mandates:
        - 401 Unauthorized for missing or invalid authentication credentials.
        - 403 Forbidden for insufficient scopes.
    #>
    return {
        param($token, $result, $options)

        # Validate user presence in the token
        if (($null -eq $result) -or ($null -eq $result.User)) {
            $message = 'User authentication failed'
            return @{
                Message   = $message
                Challenge = (New-PodeAuthChallenge -Scopes $options.Scopes -ErrorType invalid_token -ErrorDescription $message )
                Code      = 401
            }
        }

        # Check for token error and return appropriate response
        if (![string]::IsNullOrWhiteSpace($result.Error)) {
            return @{
                Message   = $result.ErrorDescription
                Challenge = (New-PodeAuthChallenge -Scopes $options.Scopes -ErrorType $result.Error -ErrorDescription $result.ErrorDescription)
                Code      = 401
            }
        }

        # Scope validation
        $hasAuthScopes = (($null -ne $options.Scopes) -and ($options.Scopes.Length -gt 0))
        $hasTokenScope = (($null -ne $result.Scope) -and ($result.Scope.Length -gt 0))

        # Return 403 if authorization scopes exist but token lacks scopes
        if ($hasAuthScopes -and !$hasTokenScope) {
            $message = 'Token scope is missing or invalid'
            return @{
                Message   = $message
                Challenge = (New-PodeAuthChallenge -Scopes $options.Scopes -ErrorType insufficient_scope -ErrorDescription $message )
                Code      = 403
            }
        }

        # Return 403 if token scopes do not intersect with required auth scopes
        if ($hasAuthScopes -and $hasTokenScope -and (-not ($options.Scopes | Where-Object { $_ -in $result.Scope }))) {
            $message = 'Token scope is insufficient'
            return @{
                Message   = $message
                Challenge = (New-PodeAuthChallenge -Scopes $options.Scopes -ErrorType insufficient_scope -ErrorDescription $message )
                Code      = 403
            }
        }

        # Return the validated token result
        return $result
    }
}



function Get-PodeAuthDigestType {
    <#
    .SYNOPSIS
        Validates the Digest token in the Authorization header.

    .DESCRIPTION
        This function processes the Authorization header, verifies the presence of a Digest token,
        and optionally decodes it. It returns appropriate HTTP response codes
        as per RFC 7616 (HTTP Digest Access Authentication).

    .PARAMETER $options
        A hashtable containing the following keys:
        - Realm: The authentication realm.
        - Nonce: A unique value provided by the server to prevent replay attacks.
        - HeaderTag: The expected Authorization header tag (e.g., 'Digest').

    .OUTPUTS
        A hashtable containing the following keys based on the validation result:
        - Message: Error or success message.
        - Code: HTTP response code.
        - Challenge: Optional authentication challenge.

    .NOTES
        The function adheres to RFC 7616, which mandates:
        - 401 Unauthorized for missing or invalid authentication credentials.
        - 400 Bad Request for malformed requests.

        - RFC 7616 HTTP Status Code Usage
        | Scenario                                  | Recommended Status Code |
        |-------------------------------------------|-------------------------|
        | No Authorization header provided          | 401 Unauthorized         |
        | Incorrect Authorization header format     | 401 Unauthorized         |
        | Wrong authentication scheme used          | 401 Unauthorized         |
        | Token is empty or malformed               | 400 Bad Request          |
        | Invalid digest response                   | 401 Unauthorized         |

    #>
    return {
        param($options)
        $nonce = (New-PodeGuid -Secure -NoDashes)
        # get the auth header - send challenge if missing
        $header = (Get-PodeHeader -Name 'Authorization')
        if ($null -eq $header) {
            $message = 'No Authorization header found'
            return @{
                Message   = $message
                Challenge = (New-PodeAuthChallenge -ErrorDescription $message -Nonce $nonce -Algorithm ($options.algorithm -join ', '))
                Code      = 401
            }
        }

        # if auth header isn't digest send challenge
        $atoms = $header -isplit '\s+'
        if ($atoms.Length -lt 2) {
            $message = 'Invalid Authorization header format'
            return @{
                Message   = $message
                Challenge = (New-PodeAuthChallenge -ErrorDescription $message -Nonce $nonce -Algorithm ($options.algorithm -join ', ') )
                Code      = 401  # RFC 7616: Invalid credentials format should return 401
            }
        }

        if ($atoms[0] -ine $options.HeaderTag) {
            $message = "Authorization header is not $($options.HeaderTag)"
            return @{
                Message   = $message
                Challenge = (New-PodeAuthChallenge -ErrorDescription $message -Nonce $nonce -Algorithm ($options.algorithm -join ', '))
                Code      = 401
            }
        }

        # parse the other atoms of the header (after the scheme), return 400 if none
        $params = ConvertFrom-PodeAuthDigestHeader -Parts ($atoms[1..$($atoms.Length - 1)])
        if ($params.Count -eq 0) {
            $message = 'Invalid Authorization header'
            return @{
                Message   = $message
                Code      = 400
                Challenge = (New-PodeAuthChallenge -ErrorDescription $message -Nonce $nonce -Algorithm ($options.algorithm -join ', '))
            }
        }

        # if no username then 401 and challenge
        if ([string]::IsNullOrWhiteSpace($params.username)) {
            $message = 'Authorization header is missing username'
            return @{
                Message   = $message
                Challenge = (New-PodeAuthChallenge -ErrorDescription $message  -Nonce $nonce -Algorithm ($options.algorithm -join ', '))
                Code      = 401
            }
        }

        # return 400 if domain doesnt match request domain
        if ($WebEvent.Path -ine $params.uri) {
            $message = 'Invalid Authorization header'
            return @{
                Message   = $message
                Challenge = (New-PodeAuthChallenge -ErrorDescription $message -Nonce $nonce -Algorithm ($options.algorithm -join ', '))
                Code      = 400
            }
        }

        # return data for calling validator
        return @($params.username, $params)
    }
}

<#
.SYNOPSIS
    Validates digest authentication responses for incoming requests.

.DESCRIPTION
    The `Get-PodeAuthDigestPostValidator` function processes and validates HTTP digest
    authentication responses by comparing the computed hash with the client's provided response.
    It ensures the provided credentials are correct and returns appropriate challenges
    if validation fails.

.PARAMETER username
    The username extracted from the client's authentication request.

.PARAMETER params
    A hashtable containing digest authentication parameters, including:
    - `username`: The username provided in the request.
    - `realm`: The authentication realm.
    - `nonce`: A unique server-generated nonce value.
    - `uri`: The requested resource URI.
    - `nc`: Nonce count (tracking the number of requests).
    - `cnonce`: Client-generated nonce value.
    - `qop`: Quality of protection value.
    - `response`: The client's hashed response to be verified.

.PARAMETER result
    A hashtable containing the user data retrieved from the authentication source.
    This should include:
    - `User`: The username.
    - `Password`: The stored password or hash for verification.

.PARAMETER options
    Additional options for authentication processing, if required.

.OUTPUTS
    On successful validation, returns the user data with the password removed.
    If authentication fails, returns an error response with a challenge and HTTP status code.

.EXAMPLE
    $params = @{
        username = "morty"
        realm    = "PodeRealm"
        nonce    = "abc123"
        uri      = "/protected"
        nc       = "00000001"
        cnonce   = "xyz456"
        qop      = "auth"
        response = "expected-client-hash"
    }

    $result = @{
        User     = "morty"
        Password = "pickle"
    }

    Get-PodeAuthDigestPostValidator -username "morty" -params $params -result $result -options $null

    Returns:
    @{'User'='morty'}

.EXAMPLE
    Get-PodeAuthDigestPostValidator -username "unknown" -params $params -result $null -options $null

    Returns:
    @{
        Message   = "Invalid credentials"
        Challenge = "Digest realm=\"PodeRealm\", error_description=\"Invalid credentials\""
        Code      = 401
    }

.NOTES
    This function performs digest authentication validation by:
    - Generating an MD5 hash using the provided credentials and digest parameters.
    - Comparing the computed hash with the client's provided response.
    - Handling authentication failures by returning appropriate challenges.

    Possible HTTP response codes:
    - 401 Unauthorized: When credentials are missing, incorrect, or authentication fails.

    Digest authentication elements included:
    - `qop="auth"`
    - `algorithm="MD5"`
    - `nonce="<generated_nonce>"`

#>
function Get-PodeAuthDigestPostValidator {
    return {
        param($username, $params, $result, $options)

        # if there's no user or password, fail with challenge
        if (($null -eq $result) -or ($null -eq $result.User) -or [string]::IsNullOrWhiteSpace($result.Password)) {
            $message = 'Invalid credentials'
            return @{
                Message   = $message
                Challenge = (New-PodeAuthChallenge -ErrorType invalid_request -Nonce $params.nonce -Algorithm ($options.algorithm -join ', ') -ErrorDescription $message)
                Code      = 401
            }
        }
        # Extract the client's chosen algorithm
        $algorithm = $params.algorithm

        # Ensure the client-selected algorithm is supported
        if (-not ($options.algorithm -contains $algorithm)) {
            $message = "Unsupported algorithm: $algorithm"
            return @{
                Message   = $message
                Challenge = (New-PodeAuthChallenge -ErrorType invalid_request -Nonce $params.nonce -Algorithm ($options.algorithm -join ', ') -ErrorDescription $message)
                Code      = 400
            }
        }

        # Extract qop value
        $qop = $params.qop

        # Get the request method and URI
        $method = $WebEvent.Method.ToUpperInvariant()
        $uri = $params.uri

        # Compute HA1 (username:realm:password)
        $HA1 = ConvertTo-PodeDigestHash -Value "$($params.username):$($params.realm):$($result.Password)" -Algorithm $algorithm

        # Compute HA2 (handle `auth-int` case)
        if ($qop -eq 'auth-int') {
            # Retrieve and hash the entity body
            $entityBody = [System.Text.Encoding]::UTF8.GetString($WebEvent.Body)
            $entityHash = ConvertTo-PodeDigestHash -Value $entityBody -Algorithm $algorithm

            # HA2 with auth-int
            $HA2 = ConvertTo-PodeDigestHash -Value "$($method):$($uri):$($entityHash)" -Algorithm $algorithm
        }
        else {
            # Standard HA2
            $HA2 = ConvertTo-PodeDigestHash -Value "$($method):$($uri)" -Algorithm $algorithm
        }

        # Compute final response hash
        $final = ConvertTo-PodeDigestHash -Value "$($HA1):$($params.nonce):$($params.nc):$($params.cnonce):$($qop):$($HA2)" -Algorithm $algorithm

        # Compare final hash to client response
        if ($final -ne $params.response) {
            $message = 'Invalid authentication response'
            return @{
                Message   = $message
                Challenge = (New-PodeAuthChallenge -ErrorType invalid_request -Nonce $params.nonce -Algorithm ($options.algorithm -join ', ') -ErrorDescription $message)
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

function Get-PodeAuthFormType {
    <#
    .SYNOPSIS
        Processes form-based authentication requests.

    .DESCRIPTION
        The `Get-PodeAuthFormType` function extracts and validates user credentials from
        an incoming HTTP form submission. It verifies the presence and format of the
        provided username and password and optionally converts them to secure credentials.

    .PARAMETER $options
        A hashtable containing configuration options for the authentication process.
        Expected keys:
        - `Fields.Username`: The key used to extract the username from the request data.
        - `Fields.Password`: The key used to extract the password from the request data.
        - `AsCredential`: (Boolean) If true, converts credentials into a [PSCredential] object.

    .OUTPUTS
        [array]
        Returns an array containing the validated username and password.
        If `AsCredential` is set to `$true`, returns a `[PSCredential]` object.

    .EXAMPLE
        $options = @{
            Fields = @{ Username = 'user'; Password = 'pass' }
            AsCredential = $false
        }
        $result = Get-PodeAuthFormType -options $options

        Returns:
        @('user123', 'securePassword')

    .EXAMPLE
        $options = @{
            Fields = @{ Username = 'user'; Password = 'pass' }
            AsCredential = $true
        }
        $result = Get-PodeAuthFormType -options $options

        Returns:
        [PSCredential] object containing username and password.

    .NOTES
        This function performs several checks, including:
        - Ensuring both username and password are provided.
        - Validating the username format (only alphanumeric, dot, underscore, and dash allowed).
        - Returning HTTP status codes and error messages in case of validation failures.

        Possible HTTP response codes:
        - 401 Unauthorized: When credentials are missing or incomplete.
        - 400 Bad Request: When the username format is invalid.

    #>
    return {
        param($options)

        # get user/pass keys to get from payload
        $userField = $options.Fields.Username
        $passField = $options.Fields.Password

        # get the user/pass
        $username = $WebEvent.Data.$userField
        $password = $WebEvent.Data.$passField

        # Handle cases where fields are missing or empty
        if ([string]::IsNullOrWhiteSpace($username) -and [string]::IsNullOrWhiteSpace($password)) {
            $message = 'Username and password must be provided'
            return @{
                Message   = $message
                Challenge = (New-PodeAuthChallenge -ErrorType invalid_request -ErrorDescription $message)
                Code      = 401
            }
        }

        if ([string]::IsNullOrWhiteSpace($username)) {
            $message = 'Username is required'
            return @{
                Message   = $message
                Challenge = (New-PodeAuthChallenge -ErrorType invalid_request -ErrorDescription $message)
                Code      = 401
            }
        }

        if ([string]::IsNullOrWhiteSpace($password)) {
            $message = 'Password is required'
            return @{
                Message   = $message
                Challenge = (New-PodeAuthChallenge -ErrorType invalid_request -ErrorDescription $message)
                Code      = 401
            }
        }

        # Validate username format
        if ($username -notmatch '^[a-zA-Z0-9._-]{3,20}$') {
            $message = 'Invalid username format'
            return @{
                Message   = $message
                Challenge = (New-PodeAuthChallenge -ErrorType invalid_request -ErrorDescription $message)
                Code      = 400
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

<#
.SYNOPSIS
    Tests the authentication validation for a specified authentication method.

.DESCRIPTION
    The `Test-PodeAuthValidation` function processes an authentication method by its name,
    running the associated scripts, middleware, and validations to determine authentication success or failure.

.PARAMETER Name
    The name of the authentication method to validate. This parameter is mandatory.

.OUTPUTS
    A hashtable containing the authentication validation result, including success status, user details,
    headers, and redirection information if applicable.

.NOTES
    This is an internal function and is subject to change in future versions of Pode.
#>
function Test-PodeAuthValidation {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    try {
        # Retrieve authentication method configuration from Pode context
        $auth = $PodeContext.Server.Authentications.Methods[$Name]

        # Initialize authentication result variable
        $result = $null

        # Run pre-authentication middleware if defined
        if ($null -ne $auth.Scheme.Middleware) {
            if (!(Invoke-PodeMiddleware -Middleware $auth.Scheme.Middleware)) {
                return @{
                    Success = $false
                }
            }
        }

        # Prepare arguments for the authentication scheme script
        $_args = @(Merge-PodeScriptblockArguments -ArgumentList $auth.Scheme.Arguments -UsingVariables $auth.Scheme.ScriptBlock.UsingVariables)

        # Handle inner authentication schemes (if any)
        if ($null -ne $auth.Scheme.InnerScheme) {
            $schemes = @()
            $_scheme = $auth.Scheme

            # Traverse through the inner schemes to collect them
            $_inner = @(while ($null -ne $_scheme.InnerScheme) {
                    $_scheme = $_scheme.InnerScheme
                    $_scheme
                })

            # Process inner schemes in reverse order
            for ($i = $_inner.Length - 1; $i -ge 0; $i--) {
                $_tmp_args = @(Merge-PodeScriptblockArguments -ArgumentList $_inner[$i].Arguments -UsingVariables $_inner[$i].ScriptBlock.UsingVariables)
                $_tmp_args += , $schemes

                $result = (Invoke-PodeScriptBlock -ScriptBlock $_inner[$i].ScriptBlock.Script -Arguments $_tmp_args -Return -Splat)
                if ($result -is [hashtable]) {
                    break  # Exit if a valid result is returned
                }

                $schemes += , $result
                $result = $null
            }

            $_args += , $schemes
        }

        # Execute the primary authentication script if no result from inner schemes and not a route script
        if ($null -eq $result) {
            $result = (Invoke-PodeScriptBlock -ScriptBlock $auth.Scheme.ScriptBlock.Script -Arguments $_args -Return -Splat)
        }

        # If authentication script returns a non-hashtable, perform further validation
        if ($result -isnot [hashtable]) {
            $original = $result
            $_args = @($result) + @($auth.Arguments)

            # Run main authentication validation script
            $result = (Invoke-PodeScriptBlock -ScriptBlock $auth.ScriptBlock -Arguments $_args -UsingVariables $auth.UsingVariables -Return -Splat)

            # Run post-authentication validation if applicable
            if ([string]::IsNullOrEmpty($result.Code) -and ($null -ne $auth.Scheme.PostValidator.Script)) {
                $_args = @($original) + @($result) + @($auth.Scheme.Arguments)
                $result = (Invoke-PodeScriptBlock -ScriptBlock $auth.Scheme.PostValidator.Script -Arguments $_args -UsingVariables $auth.Scheme.PostValidator.UsingVariables -Return -Splat)
            }
        }

        # Handle authentication redirection scenarios (e.g., OAuth)
        if ($result.IsRedirected) {
            return @{
                Success    = $false
                Redirected = $true
            }
        }



        # Authentication failure handling
        if (($null -eq $result) -or ($result.Count -eq 0) -or (Test-PodeIsEmpty $result.User)) {
            $code = (Protect-PodeValue -Value $result.Code -Default 401)

            # Set WWW-Authenticate header for appropriate HTTP response
            $validCode = (($code -eq 401) -or ![string]::IsNullOrEmpty($result.Challenge))

            if ($validCode) {
                if ($null -eq $result) {
                    $result = @{}
                }

                if ($null -eq $result.Headers) {
                    $result.Headers = @{}
                }

                # Generate authentication challenge header
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

        # Authentication succeeded, return user and headers
        return @{
            Success = $true
            User    = $result.User
            Headers = $result.Headers
        }
    }
    catch {
        $_ | Write-PodeErrorLog

        # Handle unexpected errors and log them
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


<#
.SYNOPSIS
    Generates the WWW-Authenticate challenge header for failed authentication attempts.

.DESCRIPTION
    The `New-PodeAuthChallenge` function constructs a formatted authentication challenge
    string to be included in HTTP responses when authentication fails.
    It supports optional parameters such as scopes, error types, descriptions,
    and digest authentication mechanisms.

.PARAMETER Scopes
    An array of required scopes to be included in the challenge response.
    Scopes define the level of access required for the requested resource.

.PARAMETER ErrorType
    Specifies the type of error to include in the challenge response.
    Accepted values are:
      - 'invalid_request'     : The request is missing a required parameter.
      - 'invalid_token'       : The provided token is expired, revoked, or invalid.
      - 'insufficient_scope'  : The provided token lacks necessary privileges.

.PARAMETER ErrorDescription
    Provides a descriptive error message in the challenge response to explain
    the reason for the authentication failure.

.PARAMETER Digest
    A switch parameter that, when specified, includes digest authentication elements
    such as quality of protection (qop), algorithm, and a unique nonce value.

.OUTPUTS
    [string]
    Returns a formatted challenge string to be used in the HTTP response header.

.EXAMPLE
    New-PodeAuthChallenge -Scopes @('read', 'write') -ErrorType 'invalid_token' -ErrorDescription 'Token has expired'

    Returns:
    scope="read write", error="invalid_token", error_description="Token has expired"

.EXAMPLE
    New-PodeAuthChallenge -Digest

    Returns:
    qop="auth", algorithm="MD5", nonce="generated_nonce"

.EXAMPLE
    New-PodeAuthChallenge -Scopes @('admin') -ErrorType 'insufficient_scope'

    Returns:
    scope="admin", error="insufficient_scope"

.NOTES
    This function is used to generate the `WWW-Authenticate` response header
    when authentication attempts fail. It helps inform clients of the authentication
    requirements and reasons for failure.
#>

function New-PodeAuthChallenge {
    param(
        [Parameter()]
        [string[]]
        $Scopes,

        [Parameter()]
        [ValidateSet('invalid_request', 'invalid_token', 'insufficient_scope')]
        [string]
        $ErrorType = 'invalid_request',

        [Parameter()]
        [string]
        $ErrorDescription,

        [Parameter()]
        [string]
        $Nonce,

        [Parameter()]
        [string[]]
        $Algorithm = 'md5'

    )

    $items = @()

    if (![string]::IsNullOrWhiteSpace($Nonce)) {
        $items += 'qop="auth"', "algorithm=$Algorithm" , "nonce=`"$Nonce`""
    }

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