<#
.SYNOPSIS
    Creates a new authentication scheme in Pode.

.DESCRIPTION
    The `New-PodeAuthScheme` function defines different types of authentication schemes
    (Basic, Digest, OAuth2, API Key, etc.) that Pode can use to authenticate incoming
    requests. It allows configuring various authentication mechanisms, such as
    credential-based authentication, token authentication, and certificate-based authentication.

.PARAMETER Basic
    Enables Basic Authentication using the `Authorization` header with `Base64(username:password)` encoding.

.PARAMETER Encoding
    Specifies the encoding for decoding the Basic Authentication header.
    Default: `ISO-8859-1`.

.PARAMETER HeaderTag
    Defines the tag used in the `Authorization` header (e.g., `Basic`, `Bearer`, `Digest`).

.PARAMETER Form
    Enables Form-based authentication, allowing credentials to be retrieved from request payloads.

.PARAMETER UsernameField
    Specifies the key name for the username in Form authentication payloads.
    Default: `username`.

.PARAMETER PasswordField
    Specifies the key name for the password in Form authentication payloads.
    Default: `password`.

.PARAMETER Custom
    Enables a custom authentication scheme where the validation logic is implemented
    using a custom ScriptBlock.

.PARAMETER ScriptBlock
    A ScriptBlock that defines custom authentication logic for processing incoming requests.

.PARAMETER ArgumentList
    A hashtable of additional arguments that can be passed to the custom ScriptBlock.

.PARAMETER Name
    The name of the custom authentication scheme.

.PARAMETER Description
    A short description of the authentication scheme, with optional CommonMark syntax
    for rich text representation.

.PARAMETER Realm
    The authentication realm for the protected area.

.PARAMETER Type
    The authentication type for custom schemes. Default: `HTTP`.
    Valid options: `ApiKey`, `Http`, `OAuth2`, `OpenIdConnect`.

.PARAMETER Middleware
    An array of optional Middleware ScriptBlocks to be executed before the authentication process.

.PARAMETER PostValidator
    A script block that runs after user validation to perform additional checks or transformations.

.PARAMETER Digest
    Enables Digest Authentication, which secures credentials by hashing them before transmission.

.PARAMETER Algorithm
    Specifies the hashing algorithm(s) for Digest Authentication.
    Supported: `MD5`, `SHA-1`, `SHA-256`, `SHA-512`, `SHA-384`, `SHA-512/256`.
    Default: `MD5`.

.PARAMETER QualityOfProtection
    Defines the Quality of Protection (QoP) level for Digest Authentication.
    Options: `auth`, `auth-int`, `auth,auth-int`.
    Default: `auth` .

.PARAMETER Bearer
    Enables Bearer Authentication, commonly used for OAuth2/JWT-based authentication.

.PARAMETER ClientCertificate
    Enables authentication using client certificates.

.PARAMETER ClientId
    Specifies the Client ID for OAuth2 authentication (required for OAuth2 flows).

.PARAMETER ClientSecret
    The OAuth2 Client Secret. This is required unless using PKCE.

.PARAMETER RedirectUrl
    Specifies the OAuth2 Redirect URL (default: `<host>/oauth2/callback`).

.PARAMETER AuthoriseUrl
    Defines the OAuth2 authorization URL for user authentication.

.PARAMETER TokenUrl
    Specifies the OAuth2 token endpoint URL for retrieving access tokens.

.PARAMETER UserUrl
    Optional URL to retrieve user profile details from the OAuth2 provider.

.PARAMETER UserUrlMethod
    The HTTP method used when calling the OAuth2 user profile URL.
    Default: `POST`.

.PARAMETER CodeChallengeMethod
    The method for sending a PKCE code challenge during OAuth2 authorization.
    Default: `S256`.

.PARAMETER UsePKCE
    If specified, OAuth2 authentication will use PKCE (Proof Key for Code Exchange).

.PARAMETER OAuth2
    Enables OAuth2 authentication for handling authorization flows.

.PARAMETER Scope
    Specifies an array of scopes for Bearer/OAuth2 authentication (case-sensitive).

.PARAMETER ApiKey
    Enables API Key authentication, allowing keys to be passed in headers, query parameters, or cookies.

.PARAMETER ApiKeyLocation
    Defines where to look for the API key (`Header`, `Query`, or `Cookie`).
    Default: `Header`.
    Alias: Location

.PARAMETER LocationName
    Specifies the key name to retrieve the API key from (`X-API-KEY`, `api_key`, etc.).

.PARAMETER BearerLocation
    Defines where to look for the API key (`Header`, `Query`).
    Default: `Header`.

.PARAMETER InnerScheme
    Defines an optional nested authentication scheme that will run before this scheme.

.PARAMETER AsCredential
    If enabled, username/password credentials for Basic/Form authentication
    will be provided as a `pscredential` object instead of plain text.

.PARAMETER AsJWT
    If enabled, the token or API key for Bearer/API Key authentication
    will be parsed as a JWT, and the payload will be extracted.

.PARAMETER Secret
    A secret key used to sign or verify JWT signatures for Bearer/API Key authentication.

.PARAMETER PrivateKey
    The private key (PEM format) for RSA or ECDSA algorithms used to decode JWT.

.PARAMETER PublicKey
    The public key (PEM format) for RSA or ECDSA algorithms used to decode JWT.

.PARAMETER JwtVerificationMode
    Defines how aggressively JWT signatures are checked.
    - `Strict`: Full validation (signature, header, `kid`, algorithm enforcement).
    - `Moderate`: Signature check, but allows missing `kid`.
    - `Lenient`: Signature check, but ignores algorithm mismatches.

.EXAMPLE
    # Create a Basic Authentication scheme
    $basic_auth = New-PodeAuthScheme -Basic

.EXAMPLE
    # Create a Form Authentication scheme with a custom username field
    $form_auth = New-PodeAuthScheme -Form -UsernameField 'Email'

.EXAMPLE
    # Create a Digest Authentication scheme supporting SHA-256 and auth-int QoP
    $digest_auth = New-PodeAuthScheme -Digest -Algorithm 'SHA-256' -QualityOfProtection 'auth-int'

.EXAMPLE
    # Create a Bearer Authentication scheme for OAuth2
    $oauth_auth = New-PodeAuthScheme -OAuth2 -ClientId 'abc123' -TokenUrl 'https://auth.example.com/token' -AuthoriseUrl 'https://auth.example.com/auth'

.EXAMPLE
    # Create an API Key Authentication scheme, passing the key in the query string
    $api_auth = New-PodeAuthScheme -ApiKey -Location 'Query' -LocationName 'api_key'

.EXAMPLE
    # Create a custom authentication scheme
    $custom_auth = New-PodeAuthScheme -Custom -Name 'MyAuth' -ScriptBlock { param($req) return @{ User = "custom-user" } }

.NOTES
    **Authentication Types Supported:**
    - `Basic` (username/password over HTTP)
    - `Digest` (MD5/SHA-based authentication with QoP)
    - `OAuth2` (Bearer token-based authentication)
    - `ApiKey` (Key-based authentication via headers, query parameters, or cookies)
    - `ClientCertificate` (Mutual TLS authentication)
    - `Custom` (ScriptBlock-defined authentication logic)

    **Digest Authentication Notes:**
    - `MD5` is supported for legacy compatibility but is **not recommended** for security reasons.
    - Use `SHA-256` or `SHA-512/256` for stronger security.
    - `auth-int` should be used when message integrity verification is required.
    - **Windows Limitations:** Windows' built-in Digest authentication **only supports MD5** and **fails if multiple algorithms are listed** in the `WWW-Authenticate` header.
        Additionally, `auth-int` is **not supported**.
        However, you can implement custom Digest authentication using Pode; see `./examples/utilities/DigestClient.ps1` for an example.

    **OAuth2 Notes:**
    - PKCE is recommended for security (use `-UsePKCE`).
    - `InnerScheme` can be used for hybrid authentication (e.g., Basic + OAuth2).
    - The `Secret` parameter is required unless using PKCE.

    **API Key Notes:**
    - The default location for API keys is `Header`, using `X-API-KEY`.
    - The key can be extracted from headers, query parameters, or cookies.

    **JWT Handling:**
    - If `-AsJWT` is enabled, Pode will automatically parse JWTs and extract claims.
    - A `Secret` must be supplied for signed JWT verification.
#>
function New-PodeAuthScheme {
    [CmdletBinding(DefaultParameterSetName = 'Basic')]
    [OutputType([hashtable])]
    param(
        [Parameter(ParameterSetName = 'Basic')]
        [switch]
        $Basic,

        [Parameter(ParameterSetName = 'Basic')]
        [string]
        $Encoding = 'ISO-8859-1',

        [Parameter(ParameterSetName = 'Basic')]
        [Parameter(ParameterSetName = 'Bearer')]
        [Parameter(ParameterSetName = 'Digest')]
        [string]
        $HeaderTag,

        [Parameter(ParameterSetName = 'Form')]
        [switch]
        $Form,

        [Parameter(ParameterSetName = 'Form')]
        [string]
        $UsernameField = 'username',

        [Parameter(ParameterSetName = 'Form')]
        [string]
        $PasswordField = 'password',

        [Parameter(ParameterSetName = 'Custom')]
        [switch]
        $Custom,

        [Parameter(Mandatory = $true, ParameterSetName = 'Custom')]
        [ValidateScript({
                if (Test-PodeIsEmpty $_) {
                    # A non-empty ScriptBlock is required for the Custom authentication scheme
                    throw ($PodeLocale.nonEmptyScriptBlockRequiredForCustomAuthExceptionMessage)
                }

                return $true
            })]
        [scriptblock]
        $ScriptBlock,

        [Parameter(ParameterSetName = 'Custom')]
        [hashtable]
        $ArgumentList,

        [Parameter(ParameterSetName = 'Custom')]
        [string]
        $Name,

        [string]
        $Description,

        [Parameter()]
        [string]
        $Realm,

        [Parameter(ParameterSetName = 'Custom')]
        [ValidateSet('ApiKey', 'Http', 'OAuth2', 'OpenIdConnect')]
        [string]
        $Type = 'Http',

        [Parameter()]
        [object[]]
        $Middleware,

        [Parameter(ParameterSetName = 'Custom')]
        [scriptblock]
        $PostValidator = $null,

        [Parameter(ParameterSetName = 'Digest')]
        [switch]
        $Digest,

        [Parameter(ParameterSetName = 'Digest')]
        [ValidateSet('MD5', 'SHA-1', 'SHA-256', 'SHA-512', 'SHA-384', 'SHA-512/256')]
        [string[]]
        $Algorithm = 'MD5',


        [Parameter(ParameterSetName = 'Digest')]
        [ValidateSet('auth', 'auth-int', 'auth,auth-int'  )]
        [string[]]
        $QualityOfProtection = 'auth',

        [Parameter(ParameterSetName = 'Bearer')]
        [switch]
        $Bearer,

        [Parameter(ParameterSetName = 'ClientCertificate')]
        [switch]
        $ClientCertificate,

        [Parameter(ParameterSetName = 'OAuth2', Mandatory = $true)]
        [string]
        $ClientId,

        [Parameter(ParameterSetName = 'OAuth2')]
        [string]
        $ClientSecret,

        [Parameter(ParameterSetName = 'OAuth2')]
        [string]
        $RedirectUrl,

        [Parameter(ParameterSetName = 'OAuth2')]
        [string]
        $AuthoriseUrl,

        [Parameter(ParameterSetName = 'OAuth2', Mandatory = $true)]
        [string]
        $TokenUrl,

        [Parameter(ParameterSetName = 'OAuth2')]
        [string]
        $UserUrl,

        [Parameter(ParameterSetName = 'OAuth2')]
        [ValidateSet('Get', 'Post')]
        [string]
        $UserUrlMethod = 'Post',

        [Parameter(ParameterSetName = 'OAuth2')]
        [ValidateSet('plain', 'S256')]
        [string]
        $CodeChallengeMethod = 'S256',

        [Parameter(ParameterSetName = 'OAuth2')]
        [switch]
        $UsePKCE,

        [Parameter(ParameterSetName = 'OAuth2')]
        [switch]
        $OAuth2,

        [Parameter(ParameterSetName = 'ApiKey')]
        [switch]
        $ApiKey,

        [Parameter(ParameterSetName = 'ApiKey')]
        [ValidateSet('Header', 'Query', 'Cookie')]
        [Alias('Location')]
        [string]
        $ApiKeyLocation = 'Header',

        [Parameter(ParameterSetName = 'Bearer')]
        [ValidateSet('Header', 'Query' )]
        [string]
        $BearerLocation = 'Header',

        [Parameter(ParameterSetName = 'ApiKey')]
        [string]
        $LocationName,

        [Parameter(ParameterSetName = 'Bearer')]
        [Parameter(ParameterSetName = 'OAuth2')]
        [string[]]
        $Scope,

        [Parameter(ValueFromPipeline = $true)]
        [hashtable]
        $InnerScheme,

        [Parameter(ParameterSetName = 'Basic')]
        [Parameter(ParameterSetName = 'Form')]
        [switch]
        $AsCredential,

        [Parameter(ParameterSetName = 'Bearer')]
        [Parameter(ParameterSetName = 'ApiKey')]
        [switch]
        $AsJWT,

        [Parameter(ParameterSetName = 'Bearer')]
        [Parameter(ParameterSetName = 'ApiKey')]
        [object]$Secret,

        [Parameter(ParameterSetName = 'Bearer')]
        [Parameter(ParameterSetName = 'ApiKey')]
        [SecureString]
        $PrivateKey,

        [Parameter(ParameterSetName = 'Bearer')]
        [Parameter(ParameterSetName = 'ApiKey')]
        [String]
        $PublicKey,

        [Parameter(ParameterSetName = 'Bearer')]
        [Parameter(ParameterSetName = 'ApiKey')]
        [ValidateSet('Strict', 'Moderate', 'Lenient')]
        [string]
        $JwtVerificationMode = 'Lenient'
    )
    begin {
        $pipelineItemCount = 0
    }

    process {
        $pipelineItemCount++
    }

    end {
        if ($pipelineItemCount -gt 1) {
            throw ($PodeLocale.fnDoesNotAcceptArrayAsPipelineInputExceptionMessage -f $($MyInvocation.MyCommand.Name))
        }
        # default realm
        $_realm = 'User'

        # convert any middleware into valid hashtables
        $Middleware = @(ConvertTo-PodeMiddleware -Middleware $Middleware -PSSession $PSCmdlet.SessionState)

        # configure the auth scheme
        switch ($PSCmdlet.ParameterSetName.ToLowerInvariant()) {
            'basic' {
                return @{
                    Name          = (Protect-PodeValue -Value $HeaderTag -Default 'Basic')
                    Realm         = (Protect-PodeValue -Value $Realm -Default $_realm)
                    ScriptBlock   = @{
                        Script         = (Get-PodeAuthBasicType)
                        UsingVariables = $null
                    }
                    PostValidator = $null
                    Middleware    = $Middleware
                    InnerScheme   = $InnerScheme
                    Scheme        = 'http'
                    Arguments     = @{
                        Description  = $Description
                        HeaderTag    = (Protect-PodeValue -Value $HeaderTag -Default 'Basic')
                        Encoding     = (Protect-PodeValue -Value $Encoding -Default 'ISO-8859-1')
                        AsCredential = $AsCredential
                    }
                }
            }

            'clientcertificate' {
                return @{
                    Name          = 'Mutual'
                    Realm         = (Protect-PodeValue -Value $Realm -Default $_realm)
                    ScriptBlock   = @{
                        Script         = (Get-PodeAuthClientCertificateType)
                        UsingVariables = $null
                    }
                    PostValidator = $null
                    Middleware    = $Middleware
                    InnerScheme   = $InnerScheme
                    Scheme        = 'http'
                    Arguments     = @{}
                }
            }

            'digest' {
                return @{
                    Name          = 'Digest'
                    Realm         = (Protect-PodeValue -Value $Realm -Default $_realm)
                    ScriptBlock   = @{
                        Script         = (Get-PodeAuthDigestType)
                        UsingVariables = $null
                    }
                    PostValidator = @{
                        Script         = (Get-PodeAuthDigestPostValidator)
                        UsingVariables = $null
                    }
                    Middleware    = $Middleware
                    InnerScheme   = $InnerScheme
                    Scheme        = 'http'
                    Arguments     = @{
                        HeaderTag           = (Protect-PodeValue -Value $HeaderTag -Default 'Digest')
                        Algorithm           = $Algorithm
                        QualityOfProtection = $QualityOfProtection
                    }
                }
            }

            'bearer' {
                if ($Secret) {
                    if ($Secret -isnot [SecureString]) {
                        if ( $Secret -is [string]) {
                            # Convert plain string to SecureString
                            $secret = ConvertTo-SecureString -String secret  -AsPlainText -Force
                        }
                        else {
                            throw
                        }
                    }
                }
                return @{
                    Name          = 'Bearer'
                    Realm         = (Protect-PodeValue -Value $Realm -Default $_realm)
                    ScriptBlock   = @{
                        Script         = (Get-PodeAuthBearerType)
                        UsingVariables = $null
                    }
                    PostValidator = @{
                        Script         = (Get-PodeAuthBearerPostValidator)
                        UsingVariables = $null
                    }
                    Middleware    = $Middleware
                    Scheme        = 'http'
                    InnerScheme   = $InnerScheme
                    Arguments     = @{
                        Description         = $Description
                        HeaderTag           = (Protect-PodeValue -Value $HeaderTag -Default 'Bearer')
                        Scopes              = $Scope
                        AsJWT               = $AsJWT
                        Secret              = $Secret
                        PrivateKey          = $PrivateKey
                        PublicKey           = $PublicKey
                        Location            = $BearerLocation
                        JwtVerificationMode = $JwtVerificationMode
                    }
                }
            }

            'form' {
                return @{
                    Name          = 'Form'
                    Realm         = (Protect-PodeValue -Value $Realm -Default $_realm)
                    ScriptBlock   = @{
                        Script         = (Get-PodeAuthFormType)
                        UsingVariables = $null
                    }
                    PostValidator = $null
                    Middleware    = $Middleware
                    InnerScheme   = $InnerScheme
                    Scheme        = 'http'
                    Arguments     = @{
                        Description  = $Description
                        Fields       = @{
                            Username = (Protect-PodeValue -Value $UsernameField -Default 'username')
                            Password = (Protect-PodeValue -Value $PasswordField -Default 'password')
                        }
                        AsCredential = $AsCredential
                    }
                }
            }

            'oauth2' {
                if (($null -ne $InnerScheme) -and ($InnerScheme.Name -inotin @('basic', 'form'))) {
                    # OAuth2 InnerScheme can only be one of either Basic or Form authentication, but got: {0}
                    throw ($PodeLocale.oauth2InnerSchemeInvalidExceptionMessage -f $InnerScheme.Name)
                }

                if (($null -eq $InnerScheme) -and [string]::IsNullOrWhiteSpace($AuthoriseUrl)) {
                    # OAuth2 requires an Authorise URL to be supplied
                    throw ($PodeLocale.oauth2RequiresAuthorizeUrlExceptionMessage)
                }

                if ($UsePKCE -and !(Test-PodeSessionsEnabled)) {
                    # Sessions are required to use OAuth2 with PKCE
                    throw ($PodeLocale.sessionsRequiredForOAuth2WithPKCEExceptionMessage)
                }

                if (!$UsePKCE -and [string]::IsNullOrEmpty($ClientSecret)) {
                    # OAuth2 requires a Client Secret when not using PKCE
                    throw ($PodeLocale.oauth2ClientSecretRequiredExceptionMessage)
                }
                return @{
                    Name          = 'OAuth2'
                    Realm         = (Protect-PodeValue -Value $Realm -Default $_realm)
                    ScriptBlock   = @{
                        Script         = (Get-PodeAuthOAuth2Type)
                        UsingVariables = $null
                    }
                    PostValidator = $null
                    Middleware    = $Middleware
                    Scheme        = 'oauth2'
                    InnerScheme   = $InnerScheme
                    Arguments     = @{
                        Description = $Description
                        Scopes      = $Scope
                        PKCE        = @{
                            Enabled       = $UsePKCE
                            CodeChallenge = @{
                                Method = $CodeChallengeMethod
                            }
                        }
                        Client      = @{
                            ID     = $ClientId
                            Secret = $ClientSecret
                        }
                        Urls        = @{
                            Redirect  = $RedirectUrl
                            Authorise = $AuthoriseUrl
                            Token     = $TokenUrl
                            User      = @{
                                Url    = $UserUrl
                                Method = (Protect-PodeValue -Value $UserUrlMethod -Default 'Post')
                            }
                        }
                    }
                }
            }

            'apikey' {
                if ($Secret) {
                    if ($Secret -isnot [SecureString]) {
                        if ( $Secret -is [string]) {
                            # Convert plain string to SecureString
                            $Secret = ConvertTo-SecureString -String $Secret  -AsPlainText -Force
                        }
                        else {
                            throw
                        }
                    }
                }
                # set default location name
                if ([string]::IsNullOrWhiteSpace($LocationName)) {
                    $LocationName = (@{
                            Header = 'X-API-KEY'
                            Query  = 'api_key'
                            Cookie = 'X-API-KEY'
                        })[$ApiKeyLocation]
                }


                return @{
                    Name          = 'ApiKey'
                    Realm         = (Protect-PodeValue -Value $Realm -Default $_realm)
                    ScriptBlock   = @{
                        Script         = (Get-PodeAuthApiKeyType)
                        UsingVariables = $null
                    }
                    PostValidator = $null
                    Middleware    = $Middleware
                    InnerScheme   = $InnerScheme
                    Scheme        = 'apiKey'
                    Arguments     = @{
                        Description         = $Description
                        Location            = $ApiKeyLocation
                        LocationName        = $LocationName
                        AsJWT               = $AsJWT
                        Secret              = $Secret
                        PrivateKey          = $PrivateKey
                        PublicKey           = $PublicKey
                        JwtVerificationMode = $JwtVerificationMode
                    }
                }
            }

            'custom' {
                $ScriptBlock, $usingScriptVars = Convert-PodeScopedVariables -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState

                if ($null -ne $PostValidator) {
                    $PostValidator, $usingPostVars = Convert-PodeScopedVariables -ScriptBlock $PostValidator -PSSession $PSCmdlet.SessionState
                }

                return @{
                    Name          = $Name
                    Realm         = (Protect-PodeValue -Value $Realm -Default $_realm)
                    InnerScheme   = $InnerScheme
                    Scheme        = $Type.ToLowerInvariant()
                    ScriptBlock   = @{
                        Script         = $ScriptBlock
                        UsingVariables = $usingScriptVars
                    }
                    PostValidator = @{
                        Script         = $PostValidator
                        UsingVariables = $usingPostVars
                    }
                    Middleware    = $Middleware
                    Arguments     = $ArgumentList
                }
            }
        }
    }
}

<#
.SYNOPSIS
Create an OAuth2 auth scheme for Azure AD.

.DESCRIPTION
A wrapper for New-PodeAuthScheme and OAuth2, which builds an OAuth2 scheme for Azure AD.

.PARAMETER Tenant
The Directory/Tenant ID from registering a new app (default: common).

.PARAMETER ClientId
The Client ID from registering a new app.

.PARAMETER ClientSecret
The Client Secret from registering a new app (this is optional when using PKCE).

.PARAMETER RedirectUrl
An optional OAuth2 Redirect URL (default: <host>/oauth2/callback)

.PARAMETER InnerScheme
An optional authentication Scheme (from New-PodeAuthScheme) that will be called prior to this Scheme.

.PARAMETER Middleware
An array of ScriptBlocks for optional Middleware to run before the Scheme's scriptblock.

.PARAMETER UsePKCE
If supplied, OAuth2 authentication will use PKCE code verifiers.

.EXAMPLE
New-PodeAuthAzureADScheme -Tenant 123-456-678 -ClientId some_id -ClientSecret 1234.abc

.EXAMPLE
New-PodeAuthAzureADScheme -Tenant 123-456-678 -ClientId some_id -UsePKCE
#>
function New-PodeAuthAzureADScheme {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $Tenant = 'common',

        [Parameter(Mandatory = $true)]
        [string]
        $ClientId,

        [Parameter()]
        [string]
        $ClientSecret,

        [Parameter()]
        [string]
        $RedirectUrl,

        [Parameter(ValueFromPipeline = $true)]
        [hashtable]
        $InnerScheme,

        [Parameter()]
        [object[]]
        $Middleware,

        [switch]
        $UsePKCE
    )
    begin {
        $pipelineItemCount = 0
    }

    process {

        $pipelineItemCount++
    }

    end {
        if ($pipelineItemCount -gt 1) {
            throw ($PodeLocale.fnDoesNotAcceptArrayAsPipelineInputExceptionMessage -f $($MyInvocation.MyCommand.Name))
        }
        return New-PodeAuthScheme `
            -OAuth2 `
            -ClientId $ClientId `
            -ClientSecret $ClientSecret `
            -AuthoriseUrl "https://login.microsoftonline.com/$($Tenant)/oauth2/v2.0/authorize" `
            -TokenUrl "https://login.microsoftonline.com/$($Tenant)/oauth2/v2.0/token" `
            -UserUrl 'https://graph.microsoft.com/oidc/userinfo' `
            -RedirectUrl $RedirectUrl `
            -InnerScheme $InnerScheme `
            -Middleware $Middleware `
            -UsePKCE:$UsePKCE
    }
}

<#
.SYNOPSIS
Create an OAuth2 auth scheme for Twitter.

.DESCRIPTION
A wrapper for New-PodeAuthScheme and OAuth2, which builds an OAuth2 scheme for Twitter apps.

.PARAMETER ClientId
The Client ID from registering a new app.

.PARAMETER ClientSecret
The Client Secret from registering a new app (this is optional when using PKCE).

.PARAMETER RedirectUrl
An optional OAuth2 Redirect URL (default: <host>/oauth2/callback)

.PARAMETER Middleware
An array of ScriptBlocks for optional Middleware to run before the Scheme's scriptblock.

.PARAMETER UsePKCE
If supplied, OAuth2 authentication will use PKCE code verifiers.

.EXAMPLE
New-PodeAuthTwitterScheme -ClientId some_id -ClientSecret 1234.abc

.EXAMPLE
New-PodeAuthTwitterScheme -ClientId some_id -UsePKCE
#>
function New-PodeAuthTwitterScheme {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $ClientId,

        [Parameter()]
        [string]
        $ClientSecret,

        [Parameter()]
        [string]
        $RedirectUrl,

        [Parameter()]
        [object[]]
        $Middleware,

        [switch]
        $UsePKCE
    )

    return New-PodeAuthScheme `
        -OAuth2 `
        -ClientId $ClientId `
        -ClientSecret $ClientSecret `
        -AuthoriseUrl 'https://twitter.com/i/oauth2/authorize' `
        -TokenUrl 'https://api.twitter.com/2/oauth2/token' `
        -UserUrl 'https://api.twitter.com/2/users/me' `
        -UserUrlMethod 'Get' `
        -RedirectUrl $RedirectUrl `
        -Middleware $Middleware `
        -Scope 'tweet.read', 'users.read' `
        -UsePKCE:$UsePKCE
}

<#
.SYNOPSIS
Adds a custom Authentication method for verifying users.

.DESCRIPTION
Adds a custom Authentication method for verifying users.

.PARAMETER Name
A unique Name for the Authentication method.

.PARAMETER Scheme
The authentication Scheme to use for retrieving credentials (From New-PodeAuthScheme).

.PARAMETER ScriptBlock
The ScriptBlock defining logic that retrieves and verifys a user.

.PARAMETER ArgumentList
An array of arguments to supply to the Custom Authentication's ScriptBlock.

.PARAMETER FailureUrl
The URL to redirect to when authentication fails.

.PARAMETER FailureMessage
An override Message to throw when authentication fails.

.PARAMETER SuccessUrl
The URL to redirect to when authentication succeeds when logging in.

.PARAMETER Sessionless
If supplied, authenticated users will not be stored in sessions, and sessions will not be used.

.PARAMETER SuccessUseOrigin
If supplied, successful authentication from a login page will redirect back to the originating page instead of the FailureUrl.

.EXAMPLE
New-PodeAuthScheme -Form | Add-PodeAuth -Name 'Main' -ScriptBlock { /* logic */ }
#>
function Add-PodeAuth {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [hashtable]
        $Scheme,

        [Parameter(Mandatory = $true)]
        [ValidateScript({
                if (Test-PodeIsEmpty $_) {
                    # A non-empty ScriptBlock is required for the authentication method
                    throw ($PodeLocale.nonEmptyScriptBlockRequiredForAuthMethodExceptionMessage)
                }

                return $true
            })]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [object[]]
        $ArgumentList,

        [Parameter()]
        [string]
        $FailureUrl,

        [Parameter()]
        [string]
        $FailureMessage,

        [Parameter()]
        [string]
        $SuccessUrl,

        [switch]
        $Sessionless,

        [switch]
        $SuccessUseOrigin
    )
    begin {
        $pipelineItemCount = 0
    }

    process {

        $pipelineItemCount++
    }

    end {
        if ($pipelineItemCount -gt 1) {
            throw ($PodeLocale.fnDoesNotAcceptArrayAsPipelineInputExceptionMessage -f $($MyInvocation.MyCommand.Name))
        }
        # ensure the name doesn't already exist
        if (Test-PodeAuthExists -Name $Name) {
            # Authentication method already defined: {0}
            throw ($PodeLocale.authMethodAlreadyDefinedExceptionMessage -f $Name)
        }

        # ensure the Scheme contains a scriptblock
        if (Test-PodeIsEmpty $Scheme.ScriptBlock) {
            # The supplied scheme for the '{0}' authentication validator requires a valid ScriptBlock
            throw ($PodeLocale.schemeRequiresValidScriptBlockExceptionMessage -f $Name)
        }

        # if we're using sessions, ensure sessions have been setup
        if (!$Sessionless -and !(Test-PodeSessionsEnabled)) {
            # Sessions are required to use session persistent authentication
            throw ($PodeLocale.sessionsRequiredForSessionPersistentAuthExceptionMessage)
        }

        # check for scoped vars
        $ScriptBlock, $usingVars = Convert-PodeScopedVariables -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState

        # add auth method to server
        $PodeContext.Server.Authentications.Methods[$Name] = @{
            Name           = $Name
            Scheme         = $Scheme
            ScriptBlock    = $ScriptBlock
            UsingVariables = $usingVars
            Arguments      = $ArgumentList
            Sessionless    = $Sessionless.IsPresent
            Failure        = @{
                Url     = $FailureUrl
                Message = $FailureMessage
            }
            Success        = @{
                Url       = $SuccessUrl
                UseOrigin = $SuccessUseOrigin.IsPresent
            }
            Cache          = @{}
            Merged         = $false
            Parent         = $null
        }

        # if the scheme is oauth2, and there's no redirect, set up a default one
        if (($Scheme.Name -ieq 'oauth2') -and ($null -eq $Scheme.InnerScheme) -and [string]::IsNullOrWhiteSpace($Scheme.Arguments.Urls.Redirect)) {
            $path = '/oauth2/callback'
            $Scheme.Arguments.Urls.Redirect = $path
            Add-PodeRoute -Method Get -Path $path -Authentication $Name
        }
    }
}

<#
.SYNOPSIS
Lets you merge multiple Authentication methods together, into a "single" Authentication method.

.DESCRIPTION
Lets you merge multiple Authentication methods together, into a "single" Authentication method.
You can specify if only One or All of the methods need to pass to allow access, and you can also
merge other merged Authentication methods for more advanced scenarios.

.PARAMETER Name
A unique Name for the Authentication method.

.PARAMETER Authentication
Multiple Autentication method Names to be merged.

.PARAMETER Valid
How many of the Authentication methods are required to be valid, One or All. (Default: One)

.PARAMETER ScriptBlock
This is mandatory, and only used, when $Valid=All. A scriptblock to merge the mutliple users/headers returned by valid authentications into 1 user/header objects.
This scriptblock will receive a hashtable of all result objects returned from Authentication methods. The key for the hashtable will be the authentication names that passed.

.PARAMETER Default
The Default Authentication method to use as a fallback for Failure URLs and other settings.

.PARAMETER MergeDefault
The Default Authentication method's User details result object to use, when $Valid=All.

.PARAMETER FailureUrl
The URL to redirect to when authentication fails.
This will be used as fallback for the merged Authentication methods if not set on them.

.PARAMETER FailureMessage
An override Message to throw when authentication fails.
This will be used as fallback for the merged Authentication methods if not set on them.

.PARAMETER SuccessUrl
The URL to redirect to when authentication succeeds when logging in.
This will be used as fallback for the merged Authentication methods if not set on them.

.PARAMETER Sessionless
If supplied, authenticated users will not be stored in sessions, and sessions will not be used.
This will be used as fallback for the merged Authentication methods if not set on them.

.PARAMETER SuccessUseOrigin
If supplied, successful authentication from a login page will redirect back to the originating page instead of the FailureUrl.
This will be used as fallback for the merged Authentication methods if not set on them.

.EXAMPLE
Merge-PodeAuth -Name MergedAuth -Authentication ApiTokenAuth, BasicAuth -Valid All -ScriptBlock { ... }

.EXAMPLE
Merge-PodeAuth -Name MergedAuth -Authentication ApiTokenAuth, BasicAuth -Valid All -MergeDefault BasicAuth

.EXAMPLE
Merge-PodeAuth -Name MergedAuth -Authentication ApiTokenAuth, BasicAuth -FailureUrl 'http://localhost:8080/login'
#>
function Merge-PodeAuth {
    [CmdletBinding(DefaultParameterSetName = 'ScriptBlock')]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true)]
        [Alias('Auth')]
        [string[]]
        $Authentication,

        [Parameter()]
        [ValidateSet('One', 'All')]
        [string]
        $Valid = 'One',

        [Parameter(ParameterSetName = 'ScriptBlock')]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [string]
        $Default,

        [Parameter(ParameterSetName = 'MergeDefault')]
        [string]
        $MergeDefault,

        [Parameter()]
        [string]
        $FailureUrl,

        [Parameter()]
        [string]
        $FailureMessage,

        [Parameter()]
        [string]
        $SuccessUrl,

        [switch]
        $Sessionless,

        [switch]
        $SuccessUseOrigin
    )

    # ensure the name doesn't already exist
    if (Test-PodeAuthExists -Name $Name) {
        # Authentication method already defined: { 0 }
        throw ($PodeLocale.authMethodAlreadyDefinedExceptionMessage -f $Name)
    }

    # ensure all the auth methods exist
    foreach ($authName in $Authentication) {
        if (!(Test-PodeAuthExists -Name $authName)) {
            throw ($PodeLocale.authMethodNotExistForMergingExceptionMessage -f $authName) #"Authentication method does not exist for merging: $($authName)"
        }
    }

    # ensure the merge default is in the auth list
    if (![string]::IsNullOrEmpty($MergeDefault) -and ($MergeDefault -inotin @($Authentication))) {
        throw ($PodeLocale.mergeDefaultAuthNotInListExceptionMessage -f $MergeDefault) # "the MergeDefault Authentication '$($MergeDefault)' is not in the Authentication list supplied"
    }

    # ensure the default is in the auth list
    if (![string]::IsNullOrEmpty($Default) -and ($Default -inotin @($Authentication))) {
        throw ($PodeLocale.defaultAuthNotInListExceptionMessage -f $Default) # "the Default Authentication '$($Default)' is not in the Authentication list supplied"
    }

    # set default
    if ([string]::IsNullOrEmpty($Default)) {
        $Default = $Authentication[0]
    }

    # get auth for default
    $tmpAuth = $PodeContext.Server.Authentications.Methods[$Default]

    # check sessionless from default
    if (!$Sessionless) {
        $Sessionless = $tmpAuth.Sessionless
    }

    # if we're using sessions, ensure sessions have been setup
    if (!$Sessionless -and !(Test-PodeSessionsEnabled)) {
        # Sessions are required to use session persistent authentication
        throw ($PodeLocale.sessionsRequiredForSessionPersistentAuthExceptionMessage)
    }

    # check failure url from default
    if ([string]::IsNullOrEmpty($FailureUrl)) {
        $FailureUrl = $tmpAuth.Failure.Url
    }

    # check failure message from default
    if ([string]::IsNullOrEmpty($FailureMessage)) {
        $FailureMessage = $tmpAuth.Failure.Message
    }

    # check success url from default
    if ([string]::IsNullOrEmpty($SuccessUrl)) {
        $SuccessUrl = $tmpAuth.Success.Url
    }

    # check success use origin from default
    if (!$SuccessUseOrigin) {
        $SuccessUseOrigin = $tmpAuth.Success.UseOrigin
    }

    # deal with using vars in scriptblock
    if (($Valid -ieq 'all') -and [string]::IsNullOrEmpty($MergeDefault)) {
        if ($null -eq $ScriptBlock) {
            # A Scriptblock for merging multiple authenticated users into 1 object is required When Valid is All
            throw ($PodeLocale.scriptBlockRequiredForMergingUsersExceptionMessage)
        }

        $ScriptBlock, $usingVars = Convert-PodeScopedVariables -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState
    }
    else {
        if ($null -ne $ScriptBlock) {
            Write-Warning -Message 'The Scriptblock for merged authentications, when Valid=One, will be ignored'
        }
    }

    # set parent auth
    foreach ($authName in $Authentication) {
        $PodeContext.Server.Authentications.Methods[$authName].Parent = $Name
    }

    # add auth method to server
    $PodeContext.Server.Authentications.Methods[$Name] = @{
        Name            = $Name
        Authentications = @($Authentication)
        PassOne         = ($Valid -ieq 'one')
        ScriptBlock     = @{
            Script         = $ScriptBlock
            UsingVariables = $usingVars
        }
        Default         = $Default
        MergeDefault    = $MergeDefault
        Sessionless     = $Sessionless.IsPresent
        Failure         = @{
            Url     = $FailureUrl
            Message = $FailureMessage
        }
        Success         = @{
            Url       = $SuccessUrl
            UseOrigin = $SuccessUseOrigin.IsPresent
        }
        Cache           = @{}
        Merged          = $true
        Parent          = $null
    }
}

<#
.SYNOPSIS
Gets an Authentication method.

.DESCRIPTION
Gets an Authentication method.

.PARAMETER Name
The Name of an Authentication method.

.EXAMPLE
Get-PodeAuth -Name 'Main'
#>
function Get-PodeAuth {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    # ensure the name exists
    if (!(Test-PodeAuthExists -Name $Name)) {
        throw ($PodeLocale.authenticationMethodDoesNotExistExceptionMessage -f $Name) # "Authentication method not defined: $($Name)"
    }

    # get auth method
    return $PodeContext.Server.Authentications.Methods[$Name]
}

<#
.SYNOPSIS
Test if an Authentication method exists.

.DESCRIPTION
Test if an Authentication method exists.

.PARAMETER Name
The Name of the Authentication method.

.EXAMPLE
if (Test-PodeAuthExists -Name BasicAuth) { ... }
#>
function Test-PodeAuthExists {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    return $PodeContext.Server.Authentications.Methods.ContainsKey($Name)
}

<#
.SYNOPSIS
Test and invoke an Authentication method to verify a user.

.DESCRIPTION
Test and invoke an Authentication method to verify a user. This will verify a user's credentials on the request.
When testing OAuth2 methods, the first attempt will trigger a redirect to the provider and $false will be returned.

.PARAMETER Name
The Name of the Authentication method.

.PARAMETER IgnoreSession
If supplied, authentication will be re-verified on each call even if a valid session exists on the request.

.EXAMPLE
if (Test-PodeAuth -Name 'BasicAuth') { ... }

.EXAMPLE
if (Test-PodeAuth -Name 'FormAuth' -IgnoreSession) { ... }
#>
function Test-PodeAuth {
    [CmdletBinding()]
    [OutputType([boolean])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [switch]
        $IgnoreSession
    )

    # if the session already has a user/isAuth'd, then skip auth - or allow anon
    if (!$IgnoreSession -and (Test-PodeSessionsInUse) -and (Test-PodeAuthUser)) {
        return $true
    }

    try {
        $result = Invoke-PodeAuthValidation -Name $Name
    }
    catch {
        $_ | Write-PodeErrorLog
        return $false
    }

    # did the auth force a redirect?
    if ($result.Redirected) {
        return $false
    }

    # if auth failed, set appropriate response headers/redirects
    if (!$result.Success) {
        return $false
    }

    # successful auth
    return $true
}

<#
.SYNOPSIS
Adds the inbuilt Windows AD Authentication method for verifying users.

.DESCRIPTION
Adds the inbuilt Windows AD Authentication method for verifying users.

.PARAMETER Name
A unique Name for the Authentication method.

.PARAMETER Scheme
The Scheme to use for retrieving credentials (From New-PodeAuthScheme).

.PARAMETER Fqdn
A custom FQDN for the DNS of the AD you wish to authenticate against. (Alias: Server)

.PARAMETER Domain
(Unix Only) A custom NetBIOS domain name that is prepended onto usernames that are missing it (<Domain>\<Username>).

.PARAMETER SearchBase
(Unix Only) An optional searchbase to refine the LDAP query. This should be the full distinguished name.

.PARAMETER Groups
An array of Group names to only allow access.

.PARAMETER Users
An array of Usernames to only allow access.

.PARAMETER FailureUrl
The URL to redirect to when authentication fails.

.PARAMETER FailureMessage
An override Message to throw when authentication fails.

.PARAMETER SuccessUrl
The URL to redirect to when authentication succeeds when logging in.

.PARAMETER ScriptBlock
Optional ScriptBlock that is passed the found user object for further validation.

.PARAMETER Sessionless
If supplied, authenticated users will not be stored in sessions, and sessions will not be used.

.PARAMETER NoGroups
If supplied, groups will not be retrieved for the user in AD.

.PARAMETER DirectGroups
If supplied, only a user's direct groups will be retrieved rather than all groups recursively.

.PARAMETER OpenLDAP
If supplied, and on Windows, OpenLDAP will be used instead (this is the default for Linux/MacOS).

.PARAMETER ADModule
If supplied, and on Windows, the ActiveDirectory module will be used instead.

.PARAMETER SuccessUseOrigin
If supplied, successful authentication from a login page will redirect back to the originating page instead of the FailureUrl.

.PARAMETER KeepCredential
If suplied pode will save the AD credential as a PSCredential object in $WebEvent.Auth.User.Credential

.EXAMPLE
New-PodeAuthScheme -Form | Add-PodeAuthWindowsAd -Name 'WinAuth'

.EXAMPLE
New-PodeAuthScheme -Basic | Add-PodeAuthWindowsAd -Name 'WinAuth' -Groups @('Developers')

.EXAMPLE
New-PodeAuthScheme -Form | Add-PodeAuthWindowsAd -Name 'WinAuth' -NoGroups

.EXAMPLE
New-PodeAuthScheme -Form | Add-PodeAuthWindowsAd -Name 'UnixAuth' -Server 'testdomain.company.com' -Domain 'testdomain'
#>
function Add-PodeAuthWindowsAd {
    [CmdletBinding(DefaultParameterSetName = 'Groups')]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [hashtable]
        $Scheme,

        [Parameter()]
        [Alias('Server')]
        [string]
        $Fqdn,

        [Parameter()]
        [string]
        $Domain,

        [Parameter()]
        [string]
        $SearchBase,

        [Parameter(ParameterSetName = 'Groups')]
        [string[]]
        $Groups,

        [Parameter()]
        [string[]]
        $Users,

        [Parameter()]
        [string]
        $FailureUrl,

        [Parameter()]
        [string]
        $FailureMessage,

        [Parameter()]
        [string]
        $SuccessUrl,

        [Parameter()]
        [scriptblock]
        $ScriptBlock,

        [switch]
        $Sessionless,

        [Parameter(ParameterSetName = 'NoGroups')]
        [switch]
        $NoGroups,

        [Parameter(ParameterSetName = 'Groups')]
        [switch]
        $DirectGroups,

        [switch]
        $OpenLDAP,

        [switch]
        $ADModule,

        [switch]
        $SuccessUseOrigin,

        [switch]
        $KeepCredential
    )
    begin {
        $pipelineItemCount = 0
    }

    process {

        $pipelineItemCount++
    }

    end {
        if ($pipelineItemCount -gt 1) {
            throw ($PodeLocale.fnDoesNotAcceptArrayAsPipelineInputExceptionMessage -f $($MyInvocation.MyCommand.Name))
        }
        # ensure the name doesn't already exist
        if (Test-PodeAuthExists -Name $Name) {
            # Authentication method already defined: {0}
            throw ($PodeLocale.authMethodAlreadyDefinedExceptionMessage -f $Name)
        }

        # ensure the Scheme contains a scriptblock
        if (Test-PodeIsEmpty $Scheme.ScriptBlock) {
            # The supplied Scheme for the '$($Name)' Windows AD authentication validator requires a valid ScriptBlock
            throw ($PodeLocale.schemeRequiresValidScriptBlockExceptionMessage -f $Name)
        }

        # if we're using sessions, ensure sessions have been setup
        if (!$Sessionless -and !(Test-PodeSessionsEnabled)) {
            # Sessions are required to use session persistent authentication
            throw ($PodeLocale.sessionsRequiredForSessionPersistentAuthExceptionMessage)
        }

        # if AD module set, ensure we're on windows and the module is available, then import/export it
        if ($ADModule) {
            Import-PodeAuthADModule
        }

        # set server name if not passed
        if ([string]::IsNullOrWhiteSpace($Fqdn)) {
            $Fqdn = Get-PodeAuthDomainName

            if ([string]::IsNullOrWhiteSpace($Fqdn)) {
                # No domain server name has been supplied for Windows AD authentication
                throw ($PodeLocale.noDomainServerNameForWindowsAdAuthExceptionMessage)
            }
        }

        # set the domain if not passed
        if ([string]::IsNullOrWhiteSpace($Domain)) {
            $Domain = ($Fqdn -split '\.')[0]
        }

        # if we have a scriptblock, deal with using vars
        if ($null -ne $ScriptBlock) {
            $ScriptBlock, $usingVars = Convert-PodeScopedVariables -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState
        }

        # add Windows AD auth method to server
        $PodeContext.Server.Authentications.Methods[$Name] = @{
            Name        = $Name
            Scheme      = $Scheme
            ScriptBlock = (Get-PodeAuthWindowsADMethod)
            Arguments   = @{
                Server         = $Fqdn
                Domain         = $Domain
                SearchBase     = $SearchBase
                Users          = $Users
                Groups         = $Groups
                NoGroups       = $NoGroups
                DirectGroups   = $DirectGroups
                KeepCredential = $KeepCredential
                Provider       = (Get-PodeAuthADProvider -OpenLDAP:$OpenLDAP -ADModule:$ADModule)
                ScriptBlock    = @{
                    Script         = $ScriptBlock
                    UsingVariables = $usingVars
                }
            }
            Sessionless = $Sessionless
            Failure     = @{
                Url     = $FailureUrl
                Message = $FailureMessage
            }
            Success     = @{
                Url       = $SuccessUrl
                UseOrigin = $SuccessUseOrigin
            }
            Cache       = @{}
            Merged      = $false
            Parent      = $null
        }
    }
}

<#
.SYNOPSIS
Adds the inbuilt Session Authentication method for verifying an authenticated session is present on Requests.

.DESCRIPTION
Adds the inbuilt Session Authentication method for verifying an authenticated session is present on Requests.

.PARAMETER Name
A unique Name for the Authentication method.

.PARAMETER FailureUrl
The URL to redirect to when authentication fails.

.PARAMETER FailureMessage
An override Message to throw when authentication fails.

.PARAMETER SuccessUrl
The URL to redirect to when authentication succeeds when logging in.

.PARAMETER ScriptBlock
Optional ScriptBlock that is passed the found user object for further validation.

.PARAMETER Middleware
An array of ScriptBlocks for optional Middleware to run before the Scheme's scriptblock.

.PARAMETER SuccessUseOrigin
If supplied, successful authentication from a login page will redirect back to the originating page instead of the FailureUrl.

.EXAMPLE
Add-PodeAuthSession -Name 'SessionAuth' -FailureUrl '/login'
#>
function Add-PodeAuthSession {
    [CmdletBinding(DefaultParameterSetName = 'Groups')]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [string]
        $FailureUrl,

        [Parameter()]
        [string]
        $FailureMessage,

        [Parameter()]
        [string]
        $SuccessUrl,

        [Parameter()]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [object[]]
        $Middleware,

        [switch]
        $SuccessUseOrigin
    )

    # if sessions haven't been setup, error
    if (!(Test-PodeSessionsEnabled)) {
        # Sessions have not been configured
        throw ($PodeLocale.sessionsNotConfiguredExceptionMessage)
    }

    # ensure the name doesn't already exist
    if (Test-PodeAuthExists -Name $Name) {
        # Authentication method already defined: { 0 }
        throw ($PodeLocale.authMethodAlreadyDefinedExceptionMessage -f $Name)
    }

    # if we have a scriptblock, deal with using vars
    if ($null -ne $ScriptBlock) {
        $ScriptBlock, $usingVars = Convert-PodeScopedVariables -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState
    }

    # create the auth scheme for getting the session
    $scheme = New-PodeAuthScheme -Custom -Middleware $Middleware -ScriptBlock {
        param($options)

        # 401 if sessions not used
        if (!(Test-PodeSessionsInUse)) {
            Revoke-PodeSession
            return @{
                Message = 'Sessions are not being used'
                Code    = 401
            }
        }

        # 401 if no authenticated user
        if (!(Test-PodeAuthUser)) {
            Revoke-PodeSession
            return @{
                Message = 'Session not authenticated'
                Code    = 401
            }
        }

        # return user
        return @($WebEvent.Session.Data.Auth)
    }

    # add a custom auth method to return user back
    $method = {
        param($user, $options)
        $result = @{ User = $user }

        # call additional scriptblock if supplied
        if ($null -ne $options.ScriptBlock.Script) {
            $result = Invoke-PodeAuthInbuiltScriptBlock -User $result.User -ScriptBlock $options.ScriptBlock.Script -UsingVariables $options.ScriptBlock.UsingVariables
        }

        # return user back
        return $result
    }

    $scheme | Add-PodeAuth `
        -Name $Name `
        -ScriptBlock $method `
        -FailureUrl $FailureUrl `
        -FailureMessage $FailureMessage `
        -SuccessUrl $SuccessUrl `
        -SuccessUseOrigin:$SuccessUseOrigin `
        -ArgumentList @{
        ScriptBlock = @{
            Script         = $ScriptBlock
            UsingVariables = $usingVars
        }
    }
}

<#
.SYNOPSIS
Remove a specific Authentication method.

.DESCRIPTION
Remove a specific Authentication method.

.PARAMETER Name
The Name of the Authentication method.

.EXAMPLE
Remove-PodeAuth -Name 'Login'
#>
function Remove-PodeAuth {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]
        $Name
    )
    process {
        $null = $PodeContext.Server.Authentications.Methods.Remove($Name)
    }
}

<#
.SYNOPSIS
Clear all defined Authentication methods.

.DESCRIPTION
Clear all defined Authentication methods.

.EXAMPLE
Clear-PodeAuth
#>
function Clear-PodeAuth {
    [CmdletBinding()]
    param()

    $PodeContext.Server.Authentications.Methods.Clear()
}

<#
.SYNOPSIS
Adds an authentication method as global middleware.

.DESCRIPTION
Adds an authentication method as global middleware.

.PARAMETER Name
The Name of the Middleware.

.PARAMETER Authentication
The Name of the Authentication method to use.

.PARAMETER Route
A Route path for which Routes this Middleware should only be invoked against.

.PARAMETER OADefinitionTag
An array of string representing the unique tag for the API specification.
This tag helps in distinguishing between different versions or types of API specifications within the application.
Use this tag to reference the specific API documentation, schema, or version that your function interacts with.

.EXAMPLE
Add-PodeAuthMiddleware -Name 'GlobalAuth' -Authentication AuthName

.EXAMPLE
Add-PodeAuthMiddleware -Name 'GlobalAuth' -Authentication AuthName -Route '/api/*'
#>
function Add-PodeAuthMiddleware {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true)]
        [Alias('Auth')]
        [string]
        $Authentication,

        [Parameter()]
        [string]
        $Route,

        [string[]]
        $OADefinitionTag
    )

    $DefinitionTag = Test-PodeOADefinitionTag -Tag $OADefinitionTag

    if (!(Test-PodeAuthExists -Name $Authentication)) {
        throw ($PodeLocale.authenticationMethodDoesNotExistExceptionMessage -f $Authentication) # "Authentication method does not exist: $($Authentication)"
    }

    Get-PodeAuthMiddlewareScript |
        New-PodeMiddleware -ArgumentList @{ Name = $Authentication } |
        Add-PodeMiddleware -Name $Name -Route $Route

    Set-PodeOAGlobalAuth -DefinitionTag $DefinitionTag -Name $Authentication -Route $Route
}

<#
.SYNOPSIS
Adds the inbuilt IIS Authentication method for verifying users passed to Pode from IIS.

.DESCRIPTION
Adds the inbuilt IIS Authentication method for verifying users passed to Pode from IIS.

.PARAMETER Name
A unique Name for the Authentication method.

.PARAMETER Groups
An array of Group names to only allow access.

.PARAMETER Users
An array of Usernames to only allow access.

.PARAMETER FailureUrl
The URL to redirect to when authentication fails.

.PARAMETER FailureMessage
An override Message to throw when authentication fails.

.PARAMETER SuccessUrl
The URL to redirect to when authentication succeeds when logging in.

.PARAMETER ScriptBlock
Optional ScriptBlock that is passed the found user object for further validation.

.PARAMETER Middleware
An array of ScriptBlocks for optional Middleware to run before the Scheme's scriptblock.

.PARAMETER Sessionless
If supplied, authenticated users will not be stored in sessions, and sessions will not be used.

.PARAMETER NoGroups
If supplied, groups will not be retrieved for the user in AD.

.PARAMETER DirectGroups
If supplied, only a user's direct groups will be retrieved rather than all groups recursively.

.PARAMETER ADModule
If supplied, and on Windows, the ActiveDirectory module will be used instead.

.PARAMETER NoLocalCheck
If supplied, Pode will not at attempt to retrieve local User/Group information for the authenticated user.

.PARAMETER SuccessUseOrigin
If supplied, successful authentication from a login page will redirect back to the originating page instead of the FailureUrl.

.EXAMPLE
Add-PodeAuthIIS -Name 'IISAuth'

.EXAMPLE
Add-PodeAuthIIS -Name 'IISAuth' -Groups @('Developers')

.EXAMPLE
Add-PodeAuthIIS -Name 'IISAuth' -NoGroups
#>
function Add-PodeAuthIIS {
    [CmdletBinding(DefaultParameterSetName = 'Groups')]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(ParameterSetName = 'Groups')]
        [string[]]
        $Groups,

        [Parameter()]
        [string[]]
        $Users,

        [Parameter()]
        [string]
        $FailureUrl,

        [Parameter()]
        [string]
        $FailureMessage,

        [Parameter()]
        [string]
        $SuccessUrl,

        [Parameter()]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [object[]]
        $Middleware,

        [switch]
        $Sessionless,

        [Parameter(ParameterSetName = 'NoGroups')]
        [switch]
        $NoGroups,

        [Parameter(ParameterSetName = 'Groups')]
        [switch]
        $DirectGroups,

        [switch]
        $ADModule,

        [switch]
        $NoLocalCheck,

        [switch]
        $SuccessUseOrigin
    )

    # ensure we're on Windows!
    if (!(Test-PodeIsWindows)) {
        # IIS Authentication support is for Windows only
        throw ($PodeLocale.iisAuthSupportIsForWindowsOnlyExceptionMessage)
    }

    # ensure the name doesn't already exist
    if (Test-PodeAuthExists -Name $Name) {
        # Authentication method already defined: {0}
        throw ($PodeLocale.authMethodAlreadyDefinedExceptionMessage -f $Name)
    }

    # if AD module set, ensure we're on windows and the module is available, then import/export it
    if ($ADModule) {
        Import-PodeAuthADModule
    }

    # if we have a scriptblock, deal with using vars
    if ($null -ne $ScriptBlock) {
        $ScriptBlock, $usingVars = Convert-PodeScopedVariables -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState
    }

    # create the auth scheme for getting the token header
    $scheme = New-PodeAuthScheme -Custom -Middleware $Middleware -ScriptBlock {
        param($options)

        $header = 'MS-ASPNETCORE-WINAUTHTOKEN'

        # fail if no header
        if (!(Test-PodeHeader -Name $header)) {
            return @{
                Message = "No $($header) header found"
                Code    = 401
            }
        }

        # return the header for validation
        $token = Get-PodeHeader -Name $header
        return @($token)
    }

    # add a custom auth method to validate the user
    $method = Get-PodeAuthWindowsADIISMethod

    $scheme | Add-PodeAuth `
        -Name $Name `
        -ScriptBlock $method `
        -FailureUrl $FailureUrl `
        -FailureMessage $FailureMessage `
        -SuccessUrl $SuccessUrl `
        -Sessionless:$Sessionless `
        -SuccessUseOrigin:$SuccessUseOrigin `
        -ArgumentList @{
        Users        = $Users
        Groups       = $Groups
        NoGroups     = $NoGroups
        DirectGroups = $DirectGroups
        Provider     = (Get-PodeAuthADProvider -ADModule:$ADModule)
        NoLocalCheck = $NoLocalCheck
        ScriptBlock  = @{
            Script         = $ScriptBlock
            UsingVariables = $usingVars
        }
    }
}

<#
.SYNOPSIS
Adds the inbuilt User File Authentication method for verifying users.

.DESCRIPTION
Adds the inbuilt User File Authentication method for verifying users.

.PARAMETER Name
A unique Name for the Authentication method.

.PARAMETER Scheme
The Scheme to use for retrieving credentials (From New-PodeAuthScheme).

.PARAMETER FilePath
A path to a users JSON file (Default: ./users.json)

.PARAMETER Groups
An array of Group names to only allow access.

.PARAMETER Users
An array of Usernames to only allow access.

.PARAMETER HmacSecret
An optional secret if the passwords are HMAC SHA256 hashed.

.PARAMETER FailureUrl
The URL to redirect to when authentication fails.

.PARAMETER FailureMessage
An override Message to throw when authentication fails.

.PARAMETER SuccessUrl
The URL to redirect to when authentication succeeds when logging in.

.PARAMETER ScriptBlock
Optional ScriptBlock that is passed the found user object for further validation.

.PARAMETER Sessionless
If supplied, authenticated users will not be stored in sessions, and sessions will not be used.

.PARAMETER SuccessUseOrigin
If supplied, successful authentication from a login page will redirect back to the originating page instead of the FailureUrl.

.EXAMPLE
New-PodeAuthScheme -Form | Add-PodeAuthUserFile -Name 'Login'

.EXAMPLE
New-PodeAuthScheme -Form | Add-PodeAuthUserFile -Name 'Login' -FilePath './custom/path/users.json'
#>
function Add-PodeAuthUserFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [hashtable]
        $Scheme,

        [Parameter()]
        [string]
        $FilePath,

        [Parameter()]
        [string[]]
        $Groups,

        [Parameter()]
        [string[]]
        $Users,

        [Parameter(ParameterSetName = 'Hmac')]
        [string]
        $HmacSecret,

        [Parameter()]
        [string]
        $FailureUrl,

        [Parameter()]
        [string]
        $FailureMessage,

        [Parameter()]
        [string]
        $SuccessUrl,

        [Parameter()]
        [scriptblock]
        $ScriptBlock,

        [switch]
        $Sessionless,

        [switch]
        $SuccessUseOrigin
    )
    begin {
        $pipelineItemCount = 0
    }

    process {

        $pipelineItemCount++
    }

    end {
        if ($pipelineItemCount -gt 1) {
            throw ($PodeLocale.fnDoesNotAcceptArrayAsPipelineInputExceptionMessage -f $($MyInvocation.MyCommand.Name))
        }
        # ensure the name doesn't already exist
        if (Test-PodeAuthExists -Name $Name) {
            # Authentication method already defined: {0}
            throw ($PodeLocale.authMethodAlreadyDefinedExceptionMessage -f $Name)
        }

        # ensure the Scheme contains a scriptblock
        if (Test-PodeIsEmpty $Scheme.ScriptBlock) {
            # The supplied scheme for the '{0}' authentication validator requires a valid ScriptBlock.
            throw ($PodeLocale.schemeRequiresValidScriptBlockExceptionMessage -f $Name)
        }

        # if we're using sessions, ensure sessions have been setup
        if (!$Sessionless -and !(Test-PodeSessionsEnabled)) {
            # Sessions are required to use session persistent authentication
            throw ($PodeLocale.sessionsRequiredForSessionPersistentAuthExceptionMessage)
        }

        # set the file path if not passed
        if ([string]::IsNullOrWhiteSpace($FilePath)) {
            $FilePath = Join-PodeServerRoot -Folder '.' -FilePath 'users.json'
        }
        else {
            $FilePath = Get-PodeRelativePath -Path $FilePath -JoinRoot -Resolve
        }

        # ensure the user file exists
        if (!(Test-PodePath -Path $FilePath -NoStatus -FailOnDirectory)) {
            # The user file does not exist: {0}
            throw ($PodeLocale.userFileDoesNotExistExceptionMessage -f $FilePath)
        }

        # if we have a scriptblock, deal with using vars
        if ($null -ne $ScriptBlock) {
            $ScriptBlock, $usingVars = Convert-PodeScopedVariables -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState
        }

        # add Windows AD auth method to server
        $PodeContext.Server.Authentications.Methods[$Name] = @{
            Name        = $Name
            Scheme      = $Scheme
            ScriptBlock = (Get-PodeAuthUserFileMethod)
            Arguments   = @{
                FilePath    = $FilePath
                Users       = $Users
                Groups      = $Groups
                HmacSecret  = $HmacSecret
                ScriptBlock = @{
                    Script         = $ScriptBlock
                    UsingVariables = $usingVars
                }
            }
            Sessionless = $Sessionless
            Failure     = @{
                Url     = $FailureUrl
                Message = $FailureMessage
            }
            Success     = @{
                Url       = $SuccessUrl
                UseOrigin = $SuccessUseOrigin
            }
            Cache       = @{}
            Merged      = $false
            Parent      = $null
        }
    }
}

<#
.SYNOPSIS
Adds the inbuilt Windows Local User Authentication method for verifying users.

.DESCRIPTION
Adds the inbuilt Windows Local User Authentication method for verifying users.

.PARAMETER Name
A unique Name for the Authentication method.

.PARAMETER Scheme
The Scheme to use for retrieving credentials (From New-PodeAuthScheme).

.PARAMETER Groups
An array of Group names to only allow access.

.PARAMETER Users
An array of Usernames to only allow access.

.PARAMETER FailureUrl
The URL to redirect to when authentication fails.

.PARAMETER FailureMessage
An override Message to throw when authentication fails.

.PARAMETER SuccessUrl
The URL to redirect to when authentication succeeds when logging in.

.PARAMETER ScriptBlock
Optional ScriptBlock that is passed the found user object for further validation.

.PARAMETER Sessionless
If supplied, authenticated users will not be stored in sessions, and sessions will not be used.

.PARAMETER NoGroups
If supplied, groups will not be retrieved for the user.

.PARAMETER SuccessUseOrigin
If supplied, successful authentication from a login page will redirect back to the originating page instead of the FailureUrl.

.EXAMPLE
New-PodeAuthScheme -Form | Add-PodeAuthWindowsLocal -Name 'WinAuth'

.EXAMPLE
New-PodeAuthScheme -Basic | Add-PodeAuthWindowsLocal -Name 'WinAuth' -Groups @('Developers')

.EXAMPLE
New-PodeAuthScheme -Form | Add-PodeAuthWindowsLocal -Name 'WinAuth' -NoGroups
#>
function Add-PodeAuthWindowsLocal {
    [CmdletBinding(DefaultParameterSetName = 'Groups')]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [hashtable]
        $Scheme,

        [Parameter(ParameterSetName = 'Groups')]
        [string[]]
        $Groups,

        [Parameter()]
        [string[]]
        $Users,

        [Parameter()]
        [string]
        $FailureUrl,

        [Parameter()]
        [string]
        $FailureMessage,

        [Parameter()]
        [string]
        $SuccessUrl,

        [Parameter()]
        [scriptblock]
        $ScriptBlock,

        [switch]
        $Sessionless,

        [Parameter(ParameterSetName = 'NoGroups')]
        [switch]
        $NoGroups,

        [switch]
        $SuccessUseOrigin
    )
    begin {
        $pipelineItemCount = 0
    }

    process {

        $pipelineItemCount++
    }

    end {
        if ($pipelineItemCount -gt 1) {
            throw ($PodeLocale.fnDoesNotAcceptArrayAsPipelineInputExceptionMessage -f $($MyInvocation.MyCommand.Name))
        }
        # ensure we're on Windows!
        if (!(Test-PodeIsWindows)) {
            # Windows Local Authentication support is for Windows only
            throw ($PodeLocale.windowsLocalAuthSupportIsForWindowsOnlyExceptionMessage)
        }

        # ensure the name doesn't already exist
        if (Test-PodeAuthExists -Name $Name) {
            # Authentication method already defined: {0}
            throw ($PodeLocale.authMethodAlreadyDefinedExceptionMessage -f $Name)
        }

        # ensure the Scheme contains a scriptblock
        if (Test-PodeIsEmpty $Scheme.ScriptBlock) {
            # The supplied scheme for the '{0}' authentication validator requires a valid ScriptBlock.
            throw ($PodeLocale.schemeRequiresValidScriptBlockExceptionMessage -f $Name)
        }

        # if we're using sessions, ensure sessions have been setup
        if (!$Sessionless -and !(Test-PodeSessionsEnabled)) {
            # Sessions are required to use session persistent authentication
            throw ($PodeLocale.sessionsRequiredForSessionPersistentAuthExceptionMessage)
        }

        # if we have a scriptblock, deal with using vars
        if ($null -ne $ScriptBlock) {
            $ScriptBlock, $usingVars = Convert-PodeScopedVariables -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState
        }

        # add Windows Local auth method to server
        $PodeContext.Server.Authentications.Methods[$Name] = @{
            Name        = $Name
            Scheme      = $Scheme
            ScriptBlock = (Get-PodeAuthWindowsLocalMethod)
            Arguments   = @{
                Users       = $Users
                Groups      = $Groups
                NoGroups    = $NoGroups
                ScriptBlock = @{
                    Script         = $ScriptBlock
                    UsingVariables = $usingVars
                }
            }
            Sessionless = $Sessionless
            Failure     = @{
                Url     = $FailureUrl
                Message = $FailureMessage
            }
            Success     = @{
                Url       = $SuccessUrl
                UseOrigin = $SuccessUseOrigin
            }
            Cache       = @{}
            Merged      = $false
            Parent      = $null
        }
    }
}

<#
.SYNOPSIS
    Converts a Header/Payload into a signed or unsigned JWT.

.DESCRIPTION
    This function converts a hashtable-based JWT header and payload into a JWT string.
    It automatically includes registered claims such as `exp`, `iat`, `nbf`, `iss`, `sub`, and `jti` if not provided.
    Supports signing using HMAC, RSA, and ECDSA.

.PARAMETER Header
    A Hashtable containing the JWT header information, including the signing algorithm (`alg`).

.PARAMETER Algorithm
    Alternative way to pass the signing algorithm. Supported values: HS256, HS384, HS512, RS256, RS384, RS512, PS256, PS384, PS512, ES256, ES384, ES512.

.PARAMETER Payload
    A Hashtable containing the JWT payload information, including claims (`iss`, `sub`, `aud`, `exp`, `nbf`, `iat`, `jti`).

.PARAMETER Secret
    The secret key for HMAC algorithms. Must be a string or byte array.
    Required for `HS256`, `HS384`, `HS512`.

.PARAMETER PrivateKey
    The private key (PEM format) for RSA or ECDSA algorithms.
    Required for `RS256`, `RS384`, `RS512`, `PS256`, `PS384`, `PS512`, `ES256`, `ES384`, `ES512`.

.PARAMETER Expiration
    The expiration time for the JWT (in seconds from now). Defaults to 1 hour.

.PARAMETER NotBefore
    The `nbf` (Not Before) time for the JWT (in seconds from now). Defaults to 0 (immediate use).

.PARAMETER IssuedAt
    The `iat` (Issued At) time for the JWT. Defaults to the current Unix timestamp.

.PARAMETER Issuer
    The `iss` (Issuer) claim, identifying the entity that issued the JWT.

.PARAMETER Subject
    The `sub` (Subject) claim, identifying the principal of the JWT.

.PARAMETER Audience
    The `aud` (Audience) claim, specifying the intended recipient(s) of the JWT.

.PARAMETER JwtId
    The `jti` (JWT ID) claim, a unique identifier for the token.

.OUTPUTS
    [string] The generated JWT.

.EXAMPLE
    ConvertTo-PodeJwt -Header @{ alg = 'none' } -Payload @{ sub = '123'; name = 'John' }

.EXAMPLE
    ConvertTo-PodeJwt -Header @{ alg = 'HS256' } -Payload @{ sub = '123'; name = 'John' } -Secret 'abc'

.EXAMPLE
    ConvertTo-PodeJwt -Header @{ alg = 'RS256' } -Payload @{ sub = '123' } -PrivateKey (Get-Content "private.pem" -Raw) -Issuer "auth.example.com" -Audience "myapi.example.com"

.NOTES
    - If no `exp`, `iat`, or `jti` are provided, they will be automatically generated.
    - The function does not check claim validity. Use `Test-PodeJwt` to validate claims.
    - Custom claims can be included in the payload.
#>
function ConvertTo-PodeJwt {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [hashtable]$Header,

        [Parameter(Mandatory = $true)]
        [hashtable]$Payload,

        [ValidateSet('NONE', 'HS256', 'HS384', 'HS512', 'RS256', 'RS384', 'RS512', 'PS256', 'PS384', 'PS512', 'ES256', 'ES384', 'ES512')]
        [string]
        $Algorithm = 'HS256',

        [Parameter()]
        $Secret = $null,

        [Parameter()]
        [securestring]$PrivateKey,

        [Parameter()]
        [int]$Expiration = 3600, # Default: 1 hour

        [Parameter()]
        [int]$NotBefore = 0, # Default: Immediate use

        [Parameter()]
        [int]$IssuedAt = 0, # Default: Current time

        [Parameter()]
        [string]$Issuer,

        [Parameter()]
        [string]$Subject,

        [Parameter()]
        [string]$Audience,

        [Parameter()]
        [string]$JwtId
    )

    # Validate header
    if ([string]::IsNullOrWhiteSpace($Header.alg)) {
        if ([string]::IsNullOrWhiteSpace($Algorithm)) {
            throw ($PodeLocale.noAlgorithmInJwtHeaderExceptionMessage)
        }
        $Header['alg'] = $Algorithm.ToUpper()
    }
    elseif (( 'NONE', 'HS256', 'HS384', 'HS512', 'RS256', 'RS384', 'RS512', 'PS256', 'PS384', 'PS512', 'ES256', 'ES384', 'ES512' -contains $Header['alg'].ToUpper())) {
        $Header['alg'] = $Header['alg'].ToUpper()
    }
    else {
        $Header['alg'] = 'HS256'
    }

    $Header.typ = 'JWT'

    # Automatically add standard claims if missing
    $currentUnix = [int][Math]::Floor(([DateTimeOffset]::new([DateTime]::UtcNow)).ToUnixTimeSeconds())


    if (! $Payload.ContainsKey('iat')) { $Payload['iat'] = if ($IssuedAt -gt 0) { $IssuedAt } else { $currentUnix } }
    if (! $Payload.ContainsKey('nbf')) { $Payload['nbf'] = $currentUnix + $NotBefore }
    if (! $Payload.ContainsKey('exp')) { $Payload['exp'] = $currentUnix + $Expiration }
    if (! $Payload.ContainsKey('iss')) {
        if ($Issuer) {
            $Payload['iss'] = $Issuer
        }
        elseif ($PodeContext) {
            $Payload['iss'] = 'Pode'
        }

    }

    if ($Subject -and ! $Payload.ContainsKey('sub')) { $Payload['sub'] = $Subject }
    if (! $Payload.ContainsKey('aud')) {
        if ($Audience) {
            $Payload['aud'] = $Audience
        }
        elseif ($PodeContext.Server.Application) {
            $Payload['aud'] = $PodeContext.Server.Application
        }
    }
    if ($JwtId -and ! $Payload.ContainsKey('jti')) { $Payload['jti'] = $JwtId }
    elseif (! $Payload.ContainsKey('jti')) { $Payload['jti'] = [guid]::NewGuid().ToString() }

    # Convert header & payload to Base64 URL format
    $header64 = ConvertTo-PodeBase64UrlValue -Value ($Header | ConvertTo-Json -Compress)
    $payload64 = ConvertTo-PodeBase64UrlValue -Value ($Payload | ConvertTo-Json -Compress)

    # Combine header and payload
    $jwt = "$($header64).$($payload64)"

    # Convert secret to bytes if needed
    if (($null -ne $Secret) -and ($Secret -isnot [byte[]])) {
        $Secret = if ($Secret -is [SecureString]) {
            [System.Text.Encoding]::UTF8.GetBytes( [Runtime.InteropServices.Marshal]::PtrToStringUni([Runtime.InteropServices.Marshal]::SecureStringToGlobalAllocUnicode($PrivateKey)))
        }
        else {
            [System.Text.Encoding]::UTF8.GetBytes([string]$Secret)
        }
    }

    # Generate the signature
    $sig = New-PodeJwtSignature -Algorithm $Header.alg -Token $jwt -SecretBytes $Secret -PrivateKey $PrivateKey

    # Append the signature and return the JWT
    $jwt += ".$($sig)"
    return $jwt
}


<#
.SYNOPSIS
    Convert and return the payload of a JWT token.

.DESCRIPTION
    Convert and return the payload of a JWT token, verifying the signature by default with support to ignore the signature.

.PARAMETER Token
    The JWT token.

.PARAMETER Secret
    The Secret, as a string or byte[], to verify the token's signature.

.PARAMETER PrivateKey
    The private key (PEM format) for RSA or ECDSA algorithms used to decode JWT.

.PARAMETER IgnoreSignature
    Skip signature verification, and return the decoded payload.

.EXAMPLE
    ConvertFrom-PodeJwt -Token "eyJ0eXAiOiJKV1QiLCJhbGciOiJoczI1NiJ9.eyJleHAiOjE2MjI1NTMyMTQsIm5hbWUiOiJKb2huIERvZSIsInN1YiI6IjEyMyJ9.LP-O8OKwix91a-SZwVK35gEClLZQmsORbW0un2Z4RkY"
#>
function ConvertFrom-PodeJwt {
    [CmdletBinding(DefaultParameterSetName = 'Secret')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Token,

        [Parameter(ParameterSetName = 'Signed')]
        $Secret = $null,

        [Parameter(ParameterSetName = 'Ignore')]
        [switch]
        $IgnoreSignature,

        [Parameter(ParameterSetName = 'Signed')]
        [securestring]
        $PrivateKey
    )

    # get the parts
    $parts = ($Token -isplit '\.')

    # check number of parts (should be 3)
    if ($parts.Length -ne 3) {
        # Invalid JWT supplied
        throw ($PodeLocale.invalidJwtSuppliedExceptionMessage)
    }

    # convert to header
    $header = ConvertFrom-PodeJwtBase64Value -Value $parts[0]
    if ([string]::IsNullOrWhiteSpace($header.alg)) {
        # Invalid JWT header algorithm supplied
        throw ($PodeLocale.invalidJwtHeaderAlgorithmSuppliedExceptionMessage)
    }

    # convert to payload
    $payload = ConvertFrom-PodeJwtBase64Value -Value $parts[1]

    # get signature
    if ($IgnoreSignature) {
        return $payload
    }

    $signature = $parts[2]

    # check "none" signature, and return payload if no signature
    $isNoneAlg = ($header.alg -ieq 'none')

    if ([string]::IsNullOrWhiteSpace($signature) -and !$isNoneAlg) {
        # No JWT signature supplied for {0}
        throw  ($PodeLocale.noJwtSignatureForAlgorithmExceptionMessage -f $header.alg)
    }

    if (![string]::IsNullOrWhiteSpace($signature) -and $isNoneAlg) {
        # Expected no JWT signature to be supplied
        throw ($PodeLocale.expectedNoJwtSignatureSuppliedExceptionMessage)
    }

    if ($isNoneAlg -and ($null -ne $Secret) -and ($Secret.Length -gt 0)) {
        # Expected no JWT signature to be supplied
        throw ($PodeLocale.expectedNoJwtSignatureSuppliedExceptionMessage)
    }

    if ($isNoneAlg) {
        return $payload
    }

    # otherwise, we have an alg for the signature, so we need to validate it
    if (($null -ne $Secret) -and ($Secret -isnot [byte[]])) {
        $Secret = [System.Text.Encoding]::UTF8.GetBytes([string]$Secret)
    }

    $sig = "$($parts[0]).$($parts[1])"
    $sig = New-PodeJwtSignature -Algorithm $header.alg -Token $sig -SecretBytes $Secret -PrivateKey $PrivateKey

    if ($sig -ne $parts[2]) {
        # Invalid JWT signature supplied
        throw ($PodeLocale.invalidJwtSignatureSuppliedExceptionMessage)
    }

    # it's valid return the payload!
    return $payload
}
<#
.SYNOPSIS
    Validates a JWT payload by checking its registered claims as defined in RFC 7519.

.DESCRIPTION
    This function verifies the validity of a JWT payload by ensuring:
    - The `exp` (Expiration Time) has not passed.
    - The `nbf` (Not Before) time is not in the future.
    - The `iat` (Issued At) time is not in the future.
    - The `iss` (Issuer) claim is valid based on the verification mode.
    - The `sub` (Subject) claim is a valid string.
    - The `aud` (Audience) claim is valid based on the verification mode.
    - The `jti` (JWT ID) claim is a valid string.

.PARAMETER Payload
    The JWT payload as a [pscustomobject] containing registered claims such as `exp`, `nbf`, `iat`, `iss`, `sub`, `aud`, and `jti`.

.PARAMETER Issuer
    The expected JWT Issuer. If omitted, uses 'Pode'.

.PARAMETER JwtVerificationMode
    Defines how aggressively JWT claims should be checked:
    - `Strict`: Requires all standard claims to be valid (`exp`, `nbf`, `iat`, `iss`, `aud`, `jti`).
    - `Moderate`: Allows missing `iss` and `aud` but still checks expiration.
    - `Lenient`: Ignores missing `iss` and `aud`, only verifies `exp`, `nbf`, and `iat`.

.EXAMPLE
  $payload = [pscustomobject]@{
      iss = "auth.example.com"
      sub = "1234567890"
      aud = "myapi.example.com"
      exp = 1700000000
      nbf = 1690000000
      iat = 1690000000
      jti = "unique-token-id"
  }

  Test-PodeJwt -Payload $payload -JwtVerificationMode "Strict"

  This example validates a JWT payload with full claim verification.

.NOTES
  - This function does not verify the JWT signature. It only checks the payload claims.
  - Custom claims outside RFC 7519 are not validated by this function.
  - Throws an error if a claim is invalid or missing required values.
#>
function Test-PodeJwt {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Payload,

        [Parameter()]
        [string]$Issuer = 'Pode',

        [Parameter()]
        [ValidateSet('Strict', 'Moderate', 'Lenient')]
        [string]$JwtVerificationMode = 'Lenient'
    )

    # Get current Unix timestamp
    $currentUnix = [int][Math]::Floor(([DateTimeOffset]::new([DateTime]::UtcNow)).ToUnixTimeSeconds())

    # Validate Expiration (`exp`) - Applies to ALL modes
    if ($Payload.exp) {
        $expUnix = [long]$Payload.exp
        if ($currentUnix -ge $expUnix) {
            throw ($PodeLocale.jwtExpiredExceptionMessage)
        }
    }

    # Validate Not Before (`nbf`) - Applies to ALL modes
    if ($Payload.nbf) {
        $nbfUnix = [long]$Payload.nbf
        if ($currentUnix -lt $nbfUnix) {
            throw ($PodeLocale.jwtNotYetValidExceptionMessage)
        }
    }

    # Validate Issued At (`iat`) - Applies to ALL modes
    if ($Payload.iat) {
        $iatUnix = [long]$Payload.iat
        if ($iatUnix -gt $currentUnix) {
            throw ($PodeLocale.jwtIssuedInFutureExceptionMessage)
        }
    }

    # Validate Issuer (`iss`)
    if ($JwtVerificationMode -eq 'Strict' -or $JwtVerificationMode -eq 'Moderate') {
        if ($Payload.iss) {
            if (! $Payload.iss -or $Payload.iss -isnot [string] -or $Payload.iss -ne $Issuer) {
                throw ($PodeLocale.jwtInvalidIssuerExceptionMessage -f $Issuer)
            }
        }
        elseif ($JwtVerificationMode -eq 'Strict') {
            throw ($PodeLocale.jwtMissingIssuerExceptionMessage)
        }
    }

    # Validate Audience (`aud`)
    if ($JwtVerificationMode -eq 'Strict' -or $JwtVerificationMode -eq 'Moderate') {
        if ($Payload.aud) {
            if (! $Payload.aud -or ($Payload.aud -isnot [string] -and $Payload.aud -isnot [array])) {
                throw ($PodeLocale.jwtInvalidAudienceExceptionMessage -f $PodeContext.Server.Application)
            }

            # Enforce application audience check
            if ($Payload.aud -is [string]) {
                if ($Payload.aud -ne $PodeContext.Server.ApplicationName) {
                    throw ($PodeLocale.jwtInvalidAudienceExceptionMessage -f $PodeContext.Server.ApplicationName)
                }
            }
            elseif ($Payload.aud -is [array]) {
                if ($Payload.aud -notcontains $PodeContext.Server.Application) {
                    throw ($PodeLocale.jwtInvalidAudienceExceptionMessage -f $PodeContext.Server.ApplicationName)
                }
            }
        }
        elseif ($JwtVerificationMode -eq 'Strict') {
            throw ($PodeLocale.jwtMissingAudienceExceptionMessage)
        }
    }

    # Validate Subject (`sub`) - Applies to ALL modes
    if ($Payload.sub) {
        if (! $Payload.sub -or $Payload.sub -isnot [string]) {
            throw ($PodeLocale.jwtInvalidSubjectExceptionMessage)
        }
    }

    # Validate JWT ID (`jti`) - Only in Strict mode
    if ($JwtVerificationMode -eq 'Strict') {
        if ($Payload.jti) {
            if (! $Payload.jti -or $Payload.jti -isnot [string]) {
                throw ($PodeLocale.jwtInvalidJtiExceptionMessage)
            }
        }
        else {
            throw ($PodeLocale.jwtMissingJtiExceptionMessage)
        }
    }
}


<#
.SYNOPSIS
Automatically loads auth ps1 files

.DESCRIPTION
Automatically loads auth ps1 files from either a /auth folder, or a custom folder. Saves space dot-sourcing them all one-by-one.

.PARAMETER Path
Optional Path to a folder containing ps1 files, can be relative or literal.

.EXAMPLE
Use-PodeAuth

.EXAMPLE
Use-PodeAuth -Path './my-auth'
#>
function Use-PodeAuth {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Path
    )

    Use-PodeFolder -Path $Path -DefaultPath 'auth'
}

<#
.SYNOPSIS
Builds an OAuth2 scheme using an OpenID Connect Discovery URL.

.DESCRIPTION
Builds an OAuth2 scheme using an OpenID Connect Discovery URL.

.PARAMETER Url
The OpenID Connect Discovery URL, this must end with '/.well-known/openid-configuration' (if missing, it will be automatically appended).

.PARAMETER Scope
A list of optional Scopes to use during the OAuth2 request. (Default: the supported list returned)

.PARAMETER ClientId
The Client ID from registering a new app.

.PARAMETER ClientSecret
The Client Secret from registering a new app (this is optional when using PKCE).

.PARAMETER RedirectUrl
An optional OAuth2 Redirect URL (Default: <host>/oauth2/callback)

.PARAMETER InnerScheme
An optional authentication Scheme (from New-PodeAuthScheme) that will be called prior to this Scheme.

.PARAMETER Middleware
An array of ScriptBlocks for optional Middleware to run before the Scheme's scriptblock.

.PARAMETER UsePKCE
If supplied, OAuth2 authentication will use PKCE code verifiers.

.EXAMPLE
ConvertFrom-PodeOIDCDiscovery -Url 'https://accounts.google.com/.well-known/openid-configuration' -ClientId some_id -UsePKCE

.EXAMPLE
ConvertFrom-PodeOIDCDiscovery -Url 'https://accounts.google.com' -ClientId some_id -UsePKCE
#>
function ConvertFrom-PodeOIDCDiscovery {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Url,

        [Parameter()]
        [string[]]
        $Scope,

        [Parameter(Mandatory = $true)]
        [string]
        $ClientId,

        [Parameter()]
        [string]
        $ClientSecret,

        [Parameter()]
        [string]
        $RedirectUrl,

        [Parameter(ValueFromPipeline = $true)]
        [hashtable]
        $InnerScheme,

        [Parameter()]
        [object[]]
        $Middleware,

        [switch]
        $UsePKCE
    )
    begin {
        $pipelineItemCount = 0
    }

    process {

        $pipelineItemCount++
    }

    end {
        if ($pipelineItemCount -gt 1) {
            throw ($PodeLocale.fnDoesNotAcceptArrayAsPipelineInputExceptionMessage -f $($MyInvocation.MyCommand.Name))
        }
        # get the discovery doc
        if (!$Url.EndsWith('/.well-known/openid-configuration')) {
            $Url += '/.well-known/openid-configuration'
        }

        $config = Invoke-RestMethod -Method Get -Uri $Url

        # check it supports the code response_type
        if ($config.response_types_supported -inotcontains 'code') {
            # The OAuth2 provider does not support the 'code' response_type
            throw ($PodeLocale.oauth2ProviderDoesNotSupportCodeResponseTypeExceptionMessage)
        }

        # can we have an InnerScheme?
        if (($null -ne $InnerScheme) -and ($config.grant_types_supported -inotcontains 'password')) {
            # The OAuth2 provider does not support the 'password' grant_type required by using an InnerScheme
            throw ($PodeLocale.oauth2ProviderDoesNotSupportPasswordGrantTypeExceptionMessage)
        }

        # scopes
        $scopes = $config.scopes_supported

        if (($null -ne $Scope) -and ($Scope.Length -gt 0)) {
            $scopes = @(foreach ($s in $Scope) {
                    if ($s -iin $config.scopes_supported) {
                        $s
                    }
                })
        }

        # pkce code challenge method
        $codeMethod = 'S256'
        if ($config.code_challenge_methods_supported -inotcontains $codeMethod) {
            $codeMethod = 'plain'
        }

        return New-PodeAuthScheme `
            -OAuth2 `
            -ClientId $ClientId `
            -ClientSecret $ClientSecret `
            -AuthoriseUrl $config.authorization_endpoint `
            -TokenUrl $config.token_endpoint `
            -UserUrl $config.userinfo_endpoint `
            -RedirectUrl $RedirectUrl `
            -Scope $scopes `
            -InnerScheme $InnerScheme `
            -Middleware $Middleware `
            -CodeChallengeMethod $codeMethod `
            -UsePKCE:$UsePKCE
    }
}

<#
.SYNOPSIS
Test whether the current WebEvent or Session has an authenticated user.

.DESCRIPTION
Test whether the current WebEvent or Session has an authenticated user. Returns true if there is an authenticated user.

.PARAMETER IgnoreSession
If supplied, only the Auth object in the WebEvent will be checked and the Session will be skipped.

.EXAMPLE
if (Test-PodeAuthUser) { ... }
#>
function Test-PodeAuthUser {
    [CmdletBinding()]
    [OutputType([boolean])]
    param(
        [switch]
        $IgnoreSession
    )

    # auth middleware
    if (($null -ne $WebEvent.Auth) -and $WebEvent.Auth.IsAuthenticated) {
        $auth = $WebEvent.Auth
    }

    # session?
    elseif (!$IgnoreSession -and ($null -ne $WebEvent.Session.Data.Auth) -and $WebEvent.Session.Data.Auth.IsAuthenticated) {
        $auth = $WebEvent.Session.Data.Auth
    }

    # null?
    if (($null -eq $auth) -or ($null -eq $auth.User)) {
        return $false
    }

    return ($null -ne $auth.User)
}

<#
.SYNOPSIS
Get the authenticated user from the WebEvent or Session.

.DESCRIPTION
Get the authenticated user from the WebEvent or Session. This is similar to calling $Webevent.Auth.User.

.PARAMETER IgnoreSession
If supplied, only the Auth object in the WebEvent will be used and the Session will be skipped.

.EXAMPLE
$user = Get-PodeAuthUser
#>
function Get-PodeAuthUser {
    [CmdletBinding()]
    param(
        [switch]
        $IgnoreSession
    )

    # auth middleware
    if (($null -ne $WebEvent.Auth) -and $WebEvent.Auth.IsAuthenticated) {
        $auth = $WebEvent.Auth
    }

    # session?
    elseif (!$IgnoreSession -and ($null -ne $WebEvent.Session.Data.Auth) -and $WebEvent.Session.Data.Auth.IsAuthenticated) {
        $auth = $WebEvent.Session.Data.Auth
    }

    # null?
    if (($null -eq $auth) -or ($null -eq $auth.User)) {
        return $null
    }

    return $auth.User
}