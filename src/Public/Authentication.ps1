<#
.SYNOPSIS
Create a new type of Authentication scheme.

.DESCRIPTION
Create a new type of Authentication scheme, which is used to parse the Request for user credentials for validating.

.PARAMETER Basic
If supplied, will use the inbuilt Basic Authentication credentials retriever.

.PARAMETER Encoding
The Encoding to use when decoding the Basic Authorization header.

.PARAMETER HeaderTag
The Tag name used in the Authorization header, ie: Basic, Bearer, Digest.

.PARAMETER Form
If supplied, will use the inbuilt Form Authentication credentials retriever.

.PARAMETER UsernameField
The name of the Username Field in the payload to retrieve the username.

.PARAMETER PasswordField
The name of the Password Field in the payload to retrieve the password.

.PARAMETER Custom
If supplied, will allow you to create a Custom Authentication credentials retriever.

.PARAMETER ScriptBlock
The ScriptBlock is used to parse the request and retieve user credentials and other information.

.PARAMETER ArgumentList
An array of arguments to supply to the Custom Authentication type's ScriptBlock.

.PARAMETER Name
The Name of an Authentication type - such as Basic or NTLM.

.PARAMETER Description
A short description for security scheme. CommonMark syntax MAY be used for rich text representation

.PARAMETER Realm
The name of scope of the protected area.

.PARAMETER Type
The scheme type for custom Authentication types. Default is HTTP.

.PARAMETER Middleware
An array of ScriptBlocks for optional Middleware to run before the Scheme's scriptblock.

.PARAMETER PostValidator
The PostValidator is a scriptblock that is invoked after user validation.

.PARAMETER Digest
If supplied, will use the inbuilt Digest Authentication credentials retriever.

.PARAMETER Bearer
If supplied, will use the inbuilt Bearer Authentication token retriever.

.PARAMETER ClientCertificate
If supplied, will use the inbuilt Client Certificate Authentication scheme.

.PARAMETER ClientId
The Application ID generated when registering a new app for OAuth2.

.PARAMETER ClientSecret
The Application Secret generated when registering a new app for OAuth2 (this is optional when using PKCE).

.PARAMETER RedirectUrl
An optional OAuth2 Redirect URL (default: <host>/oauth2/callback)

.PARAMETER AuthoriseUrl
The OAuth2 Authorisation URL to authenticate a User. This is optional if you're using an InnerScheme like Basic/Form.

.PARAMETER TokenUrl
The OAuth2 Token URL to acquire an access token.

.PARAMETER UserUrl
An optional User profile URL to retrieve a user's details - for OAuth2

.PARAMETER UserUrlMethod
An optional HTTP method to use when calling the User profile URL - for OAuth2 (Default: Post)

.PARAMETER CodeChallengeMethod
An optional method for sending a PKCE code challenge when calling the Authorise URL - for OAuth2 (Default: S256)

.PARAMETER UsePKCE
If supplied, OAuth2 authentication will use PKCE code verifiers - for OAuth2

.PARAMETER OAuth2
If supplied, will use the inbuilt OAuth2 Authentication scheme.

.PARAMETER Scope
An optional array of Scopes for Bearer/OAuth2 Authentication. (These are case-sensitive)

.PARAMETER ApiKey
If supplied, will use the inbuilt API key Authentication scheme.

.PARAMETER Location
The Location to find an API key: Header, Query, or Cookie. (Default: Header)

.PARAMETER LocationName
The Name of the Header, Query, or Cookie to find an API key. (Default depends on Location. Header/Cookie: X-API-KEY, Query: api_key)

.PARAMETER InnerScheme
An optional authentication Scheme (from New-PodeAuthScheme) that will be called prior to this Scheme.

.PARAMETER AsCredential
If supplied, username/password credentials for Basic/Form authentication will instead be supplied as a pscredential object.

.PARAMETER AsJWT
If supplied, the token/key supplied for Bearer/API key authentication will be parsed as a JWT, and the payload supplied instead.

.PARAMETER Secret
An optional Secret, used to sign/verify JWT signatures.

.EXAMPLE
$basic_auth = New-PodeAuthScheme -Basic

.EXAMPLE
$form_auth = New-PodeAuthScheme -Form -UsernameField 'Email'

.EXAMPLE
$custom_auth = New-PodeAuthScheme -Custom -ScriptBlock { /* logic */ }
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
                    throw 'A non-empty ScriptBlock is required for the Custom authentication scheme'
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
        [string]
        $Location = 'Header',

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
        [string]
        $Secret
    )

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
                    Description = $Description
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
                    HeaderTag = (Protect-PodeValue -Value $HeaderTag -Default 'Digest')
                }
            }
        }

        'bearer' {
            $secretBytes = $null
            if (![string]::IsNullOrWhiteSpace($Secret)) {
                $secretBytes = [System.Text.Encoding]::UTF8.GetBytes($Secret)
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
                    Description = $Description
                    HeaderTag = (Protect-PodeValue -Value $HeaderTag -Default 'Bearer')
                    Scopes    = $Scope
                    AsJWT     = $AsJWT
                    Secret    = $secretBytes
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
                    Description = $Description
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
                throw "OAuth2 InnerScheme can only be one of either Basic or Form authentication, but got: $($InnerScheme.Name)"
            }

            if (($null -eq $InnerScheme) -and [string]::IsNullOrWhiteSpace($AuthoriseUrl)) {
                throw 'OAuth2 requires an Authorise URL to be supplied'
            }

            if ($UsePKCE -and !(Test-PodeSessionsConfigured)) {
                throw 'Sessions are required to use OAuth2 with PKCE'
            }

            if (!$UsePKCE -and [string]::IsNullOrEmpty($ClientSecret)) {
                throw 'OAuth2 requires a Client Secret when not using PKCE'
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
            # set default location name
            if ([string]::IsNullOrWhiteSpace($LocationName)) {
                $LocationName = (@{
                        Header = 'X-API-KEY'
                        Query  = 'api_key'
                        Cookie = 'X-API-KEY'
                    })[$Location]
            }

            $secretBytes = $null
            if (![string]::IsNullOrWhiteSpace($Secret)) {
                $secretBytes = [System.Text.Encoding]::UTF8.GetBytes($Secret)
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
                    Description = $Description
                    Location     = $Location
                    LocationName = $LocationName
                    AsJWT        = $AsJWT
                    Secret       = $secretBytes
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
                    throw 'A non-empty ScriptBlock is required for the authentication method'
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

    # ensure the name doesn't already exist
    if (Test-PodeAuthExists -Name $Name) {
        throw "Authentication method already defined: $($Name)"
    }

    # ensure the Scheme contains a scriptblock
    if (Test-PodeIsEmpty $Scheme.ScriptBlock) {
        throw "The supplied '$($Scheme.Name)' Scheme for the '$($Name)' authentication validator requires a valid ScriptBlock"
    }

    # if we're using sessions, ensure sessions have been setup
    if (!$Sessionless -and !(Test-PodeSessionsConfigured)) {
        throw 'Sessions are required to use session persistent authentication'
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
This is mandatory when Valid is All. A scriptblock to merge the mutliple users/headers returned by valid authentications into 1 user/header objects.
This scriptblock will receive a hashtable of all result objects returned from Authentication methods. The key for the hashtable will be the authentication names that passed.

.PARAMETER Default
The Default Authentication method to use as a fallback for Failure URLs and other settings.

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
Merge-PodeAuth -Name MergedAuth -Authentication ApiTokenAuth, BasicAuth -Valid All

.EXAMPLE
Merge-PodeAuth -Name MergedAuth -Authentication ApiTokenAuth, BasicAuth -FailureUrl 'http://localhost:8080/login'
#>
function Merge-PodeAuth {
    [CmdletBinding()]
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

        [Parameter()]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [string]
        $Default,

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
        throw "Authentication method already defined: $($Name)"
    }

    # ensure all the auth methods exist
    foreach ($authName in $Authentication) {
        if (!(Test-PodeAuthExists -Name $authName)) {
            throw "Authentication method does not exist for merging: $($authName)"
        }
    }

    # ensure the default is in the auth list
    if (![string]::IsNullOrEmpty($Default) -and ($Default -inotin @($Authentication))) {
        throw "the Default Authentication '$($Default)' is not in the Authentication list supplied"
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
    if (!$Sessionless -and !(Test-PodeSessionsConfigured)) {
        throw 'Sessions are required to use session persistent authentication'
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
    if ($Valid -ieq 'all') {
        if ($null -eq $ScriptBlock) {
            throw 'A Scriptblock for merging multiple authenticated users into 1 object is required When Valid is All'
        }

        $ScriptBlock, $usingVars = Convert-PodeScopedVariables -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState
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
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    # ensure the name exists
    if (!(Test-PodeAuthExists -Name $Name)) {
        throw "Authentication method not defined: $($Name)"
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
    [CmdletBinding()]
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
    } catch {
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

    # ensure the name doesn't already exist
    if (Test-PodeAuthExists -Name $Name) {
        throw "Windows AD Authentication method already defined: $($Name)"
    }

    # ensure the Scheme contains a scriptblock
    if (Test-PodeIsEmpty $Scheme.ScriptBlock) {
        throw "The supplied Scheme for the '$($Name)' Windows AD authentication validator requires a valid ScriptBlock"
    }

    # if we're using sessions, ensure sessions have been setup
    if (!$Sessionless -and !(Test-PodeSessionsConfigured)) {
        throw 'Sessions are required to use session persistent authentication'
    }

    # if AD module set, ensure we're on windows and the module is available, then import/export it
    if ($ADModule) {
        Import-PodeAuthADModule
    }

    # set server name if not passed
    if ([string]::IsNullOrWhiteSpace($Fqdn)) {
        $Fqdn = Get-PodeAuthDomainName

        if ([string]::IsNullOrWhiteSpace($Fqdn)) {
            throw 'No domain server name has been supplied for Windows AD authentication'
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
    if (!(Test-PodeSessionsConfigured)) {
        throw 'Sessions have not been configured'
    }

    # ensure the name doesn't already exist
    if (Test-PodeAuthExists -Name $Name) {
        throw "Authentication method already defined: $($Name)"
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

    $null = $PodeContext.Server.Authentications.Methods.Remove($Name)
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

.PARAMETER DefinitionTag
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
        $DefinitionTag = @('default')
    )

    if (!(Test-PodeAuthExists -Name $Authentication)) {
        throw "Authentication method does not exist: $($Authentication)"
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
        throw 'IIS Authentication support is for Windows only'
    }

    # ensure the name doesn't already exist
    if (Test-PodeAuthExists -Name $Name) {
        throw "IIS Authentication method already defined: $($Name)"
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

    # ensure the name doesn't already exist
    if (Test-PodeAuthExists -Name $Name) {
        throw "User File Authentication method already defined: $($Name)"
    }

    # ensure the Scheme contains a scriptblock
    if (Test-PodeIsEmpty $Scheme.ScriptBlock) {
        throw "The supplied Scheme for the '$($Name)' User File authentication validator requires a valid ScriptBlock"
    }

    # if we're using sessions, ensure sessions have been setup
    if (!$Sessionless -and !(Test-PodeSessionsConfigured)) {
        throw 'Sessions are required to use session persistent authentication'
    }

    # set the file path if not passed
    if ([string]::IsNullOrWhiteSpace($FilePath)) {
        $FilePath = Join-PodeServerRoot -Folder '.' -FilePath 'users.json'
    } else {
        $FilePath = Get-PodeRelativePath -Path $FilePath -JoinRoot -Resolve
    }

    # ensure the user file exists
    if (!(Test-PodePath -Path $FilePath -NoStatus -FailOnDirectory)) {
        throw "The user file does not exist: $($FilePath)"
    }

    # if we have a scriptblock, deal with using vars
    if ($null -ne $ScriptBlock) {
        $ScriptBlock, $usingVars = Convert-PodeScopedVariables -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState
    }

    # add Windows AD auth method to server
    $PodeContext.Server.Authentications.Methods[$Name] = @{
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

    # ensure we're on Windows!
    if (!(Test-PodeIsWindows)) {
        throw 'Windows Local Authentication support is for Windows only'
    }

    # ensure the name doesn't already exist
    if (Test-PodeAuthExists -Name $Name) {
        throw "Windows Local Authentication method already defined: $($Name)"
    }

    # ensure the Scheme contains a scriptblock
    if (Test-PodeIsEmpty $Scheme.ScriptBlock) {
        throw "The supplied Scheme for the '$($Name)' Windows Local authentication validator requires a valid ScriptBlock"
    }

    # if we're using sessions, ensure sessions have been setup
    if (!$Sessionless -and !(Test-PodeSessionsConfigured)) {
        throw 'Sessions are required to use session persistent authentication'
    }

    # if we have a scriptblock, deal with using vars
    if ($null -ne $ScriptBlock) {
        $ScriptBlock, $usingVars = Convert-PodeScopedVariables -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState
    }

    # add Windows Local auth method to server
    $PodeContext.Server.Authentications.Methods[$Name] = @{
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

<#
.SYNOPSIS
Convert a Header/Payload into a JWT.

.DESCRIPTION
Convert a Header/Payload hashtable into a JWT, with the option to sign it.

.PARAMETER Header
A Hashtable containing the Header information for the JWT.

.PARAMETER Payload
A Hashtable containing the Payload information for the JWT.

.PARAMETER Secret
An Optional Secret for signing the JWT, should be a string or byte[]. This is mandatory if the Header algorithm isn't "none".

.EXAMPLE
ConvertTo-PodeJwt -Header @{ alg = 'none' } -Payload @{ sub = '123'; name = 'John' }

.EXAMPLE
ConvertTo-PodeJwt -Header @{ alg = 'hs256' } -Payload @{ sub = '123'; name = 'John' } -Secret 'abc'
#>
function ConvertTo-PodeJwt {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]
        $Header,

        [Parameter(Mandatory = $true)]
        [hashtable]
        $Payload,

        [Parameter()]
        $Secret = $null
    )

    # validate header
    if ([string]::IsNullOrWhiteSpace($Header.alg)) {
        throw 'No algorithm supplied in JWT Header'
    }

    # convert the header
    $header64 = ConvertTo-PodeBase64UrlValue -Value ($Header | ConvertTo-Json -Compress)

    # convert the payload
    $payload64 = ConvertTo-PodeBase64UrlValue -Value ($Payload | ConvertTo-Json -Compress)

    # combine
    $jwt = "$($header64).$($payload64)"

    # convert secret to bytes
    if (($null -ne $Secret) -and ($Secret -isnot [byte[]])) {
        $Secret = [System.Text.Encoding]::UTF8.GetBytes([string]$Secret)
    }

    # make the signature
    $sig = New-PodeJwtSignature -Algorithm $Header.alg -Token $jwt -SecretBytes $Secret

    # add the signature and return
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

.PARAMETER IgnoreSignature
Skip signature verification, and return the decoded payload.

.EXAMPLE
ConvertFrom-PodeJwt -Token "eyJ0eXAiOiJKV1QiLCJhbGciOiJoczI1NiJ9.eyJleHAiOjE2MjI1NTMyMTQsIm5hbWUiOiJKb2huIERvZSIsInN1YiI6IjEyMyJ9.LP-O8OKwix91a-SZwVK35gEClLZQmsORbW0un2Z4RkY"
#>
function ConvertFrom-PodeJwt {
    [CmdletBinding(DefaultParameterSetName = 'Secret')]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Token,

        [Parameter(ParameterSetName = 'Signed')]
        $Secret = $null,

        [Parameter(ParameterSetName = 'Ignore')]
        [switch]
        $IgnoreSignature
    )

    # get the parts
    $parts = ($Token -isplit '\.')

    # check number of parts (should be 3)
    if ($parts.Length -ne 3) {
        throw 'Invalid JWT supplied'
    }

    # convert to header
    $header = ConvertFrom-PodeJwtBase64Value -Value $parts[0]
    if ([string]::IsNullOrWhiteSpace($header.alg)) {
        throw 'Invalid JWT header algorithm supplied'
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
        throw "No JWT signature supplied for $($header.alg)"
    }

    if (![string]::IsNullOrWhiteSpace($signature) -and $isNoneAlg) {
        throw 'Expected no JWT signature to be supplied'
    }

    if ($isNoneAlg -and ($null -ne $Secret) -and ($Secret.Length -gt 0)) {
        throw "Expected a signed JWT, 'none' algorithm is not allowed"
    }

    if ($isNoneAlg) {
        return $payload
    }

    # otherwise, we have an alg for the signature, so we need to validate it
    if (($null -ne $Secret) -and ($Secret -isnot [byte[]])) {
        $Secret = [System.Text.Encoding]::UTF8.GetBytes([string]$Secret)
    }

    $sig = "$($parts[0]).$($parts[1])"
    $sig = New-PodeJwtSignature -Algorithm $header.alg -Token $sig -SecretBytes $Secret

    if ($sig -ne $parts[2]) {
        throw 'Invalid JWT signature supplied'
    }

    # it's valid return the payload!
    return $payload
}

<#
.SYNOPSIS
Validates JSON Web Tokens (JWT) claims.

.DESCRIPTION
Validates JSON Web Tokens (JWT) claims. Checks time related claims: 'exp' and 'nbf'.

.PARAMETER Payload
Object containing JWT claims. Some of them are:
    - exp (expiration time)
    - nbf (not before)

.EXAMPLE
Test-PodeJwt @{exp = 2696258821 }

.EXAMPLE
Test-PodeJwt -Payload @{nbf = 1696258821 }
#>
function Test-PodeJwt {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]
        $Payload
    )

    $now = [datetime]::UtcNow
    $unixStart = [datetime]::new(1970, 1, 1, 0, 0, [DateTimeKind]::Utc)

    # validate expiry
    if (![string]::IsNullOrWhiteSpace($Payload.exp)) {
        if ($now -gt $unixStart.AddSeconds($Payload.exp)) {
            throw 'The JWT has expired'
        }
    }

    # validate not-before
    if (![string]::IsNullOrWhiteSpace($Payload.nbf)) {
        if ($now -lt $unixStart.AddSeconds($Payload.nbf)) {
            throw 'The JWT is not yet valid for use'
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

    # get the discovery doc
    if (!$Url.EndsWith('/.well-known/openid-configuration')) {
        $Url += '/.well-known/openid-configuration'
    }

    $config = Invoke-RestMethod -Method Get -Uri $Url

    # check it supports the code response_type
    if ($config.response_types_supported -inotcontains 'code') {
        throw "The OAuth2 provider does not support the 'code' response_type"
    }

    # can we have an InnerScheme?
    if (($null -ne $InnerScheme) -and ($config.grant_types_supported -inotcontains 'password')) {
        throw "The OAuth2 provider does not support the 'password' grant_type required by using an InnerScheme"
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