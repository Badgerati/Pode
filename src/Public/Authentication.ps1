using namespace Pode

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

.PARAMETER Negotiate
If supplied, will use the inbuilt Negotiate Authentication scheme (Kerberos/NTLM).

.PARAMETER KeytabPath
The path to the Keytab file for Negotiate authentication.

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

        [Parameter(ParameterSetName = 'Basic')]
        [Parameter(ParameterSetName = 'Bearer')]
        [Parameter(ParameterSetName = 'Digest')]
        [Parameter(ParameterSetName = 'Form')]
        [Parameter(ParameterSetName = 'Custom')]
        [Parameter(ParameterSetName = 'ClientCertificate')]
        [Parameter(ParameterSetName = 'OAuth2')]
        [Parameter(ParameterSetName = 'ApiKey')]
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

        [Parameter(Mandatory = $true, ParameterSetName = 'OAuth2')]
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

        [Parameter(Mandatory = $true, ParameterSetName = 'OAuth2')]
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
        $Secret,

        [Parameter(ParameterSetName = 'Negotiate')]
        [switch]
        $Negotiate,

        [Parameter(Mandatory = $true, ParameterSetName = 'Negotiate')]
        [string]
        $KeytabPath
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
                # Display a deprecation warning for the old function.
                # This ensures users are informed that the function is obsolete and should transition to the new function.
                Write-PodeDeprecationWarning -OldFunction 'New-PodeAuthScheme -Digest' -NewFunction 'New-PodeAuthDigestScheme'

                $params = @{
                    HeaderTag = $HeaderTag
                    Scope     = $Scope
                }
                return New-PodeAuthDigestScheme $params
            }

            'bearer' {
                # Display a deprecation warning for the old function.
                # This ensures users are informed that the function is obsolete and should transition to the new function.
                Write-PodeDeprecationWarning -OldFunction 'New-PodeAuthScheme -Bearer' -NewFunction 'New-PodeAuthBearerScheme'

                $params = @{
                    HeaderTag = $HeaderTag
                    Scope     = $Scope
                    AsJWT     = $AsJWT
                }

                if ($Secret) {
                    if ($Secret -isnot [SecureString]) {
                        if ( $Secret -is [string]) {
                            # Convert plain string to SecureString
                            $params['Secret'] = ConvertTo-SecureString -String $Secret  -AsPlainText -Force
                        }
                        else {
                            throw
                        }
                    }
                    else {
                        $params['Secret'] = $Secret
                    }
                }
                return New-PodeAuthBearerScheme @params
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
                # set default location name
                if ([string]::IsNullOrWhiteSpace($LocationName)) {
                    $LocationName = (@{
                            Header = 'X-API-KEY'
                            Query  = 'api_key'
                            Cookie = 'X-API-KEY'
                        })[$Location]
                }

                #    $secretBytes = $null
                #     if (![string]::IsNullOrWhiteSpace($Secret)) {
                #          $secretBytes = [System.Text.Encoding]::UTF8.GetBytes($Secret)
                #      }
                if (! ([string]::IsNullOrEmpty($Secret))) {
                    $SecretString = ConvertTo-SecureString -String $Secret  -AsPlainText -Force
                    $alg = @( 'HS256', 'HS384', 'HS512' )
                }
                else {
                    $SecretString = $null
                    $alg = 'NONE'
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
                        Description  = $Description
                        Location     = $Location
                        LocationName = $LocationName
                        AsJWT        = $AsJWT
                        Secret       = $secretBytes
                    }
                }
            }

            'negotiate' {
                return @{
                    Name          = 'Negotiate'
                    ScriptBlock   = @{
                        Script         = (Get-PodeAuthNegotiateType)
                        UsingVariables = $null
                    }
                    PostValidator = $null
                    Middleware    = $Middleware
                    InnerScheme   = $InnerScheme
                    Scheme        = 'http'
                    Arguments     = @{
                        Authenticator = [PodeKerberosAuth]::new($KeytabPath)
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
Converts a hashtable-based JWT header and payload into a JWT string. Automatically includes registered claims such as `exp`, `iat`, `nbf`, `iss`, `sub`, and `jti` if not provided. Supports signing using HMAC, RSA, and ECDSA.

.PARAMETER Header
  A hashtable containing JWT header information including the `alg` (algorithm).

.PARAMETER Payload
  A hashtable containing JWT payload information, including claims (`iss`, `sub`, `aud`, `exp`, `nbf`, `iat`, `jti`).

.PARAMETER Algorithm
  The signing algorithm. Supported values: NONE, HS256, HS384, HS512, RS256, RS384, RS512, PS256, PS384, PS512, ES256, ES384, ES512.

.PARAMETER Secret
  The secret key for HMAC algorithms, required for `HS256`, `HS384`, and `HS512`.

.PARAMETER X509Certificate
  The private key certificate for RSA or ECDSA algorithms.

.PARAMETER PfxPath
  Path to the PFX certificate file.

.PARAMETER PfxBytes
  PFX certificate in byte array format.

.PARAMETER PfxPassword
  Password for the PFX certificate if protected.

.PARAMETER RsaPaddingScheme
  RSA padding scheme to use, default is `Pkcs1V15`.

.PARAMETER Authentication
  Pode authentication method for signing the JWT.

.PARAMETER Expiration
  Expiration time for the JWT in seconds (default: 3600).

.PARAMETER NotBefore
  `nbf` claim in seconds (default: 0).

.PARAMETER IssuedAt
  `iat` claim as Unix timestamp.

.PARAMETER Issuer
  `iss` claim specifying the token issuer.

.PARAMETER Subject
  `sub` claim specifying the token subject.

.PARAMETER Audience
  `aud` claim specifying the token audience.

.PARAMETER JwtId
  `jti` claim as a unique identifier.

.PARAMETER NoStandardClaims
  If set, disables automatic inclusion of standard claims.

.OUTPUTS
  [string] - Returns the generated JWT string.

.EXAMPLE
ConvertTo-PodeJwt -Header @{ alg = 'none' } -Payload @{ sub = '123'; name = 'John' }

.EXAMPLE
ConvertTo-PodeJwt -Header @{ alg = 'HS256' } -Payload @{ sub = '123'; name = 'John' } -Secret 'abc'

.EXAMPLE
ConvertTo-PodeJwt -Header @{ alg = 'RS256' } -Payload @{ sub = '123' } -PrivateKey (Get-Content "private.pem" -Raw) -Issuer "auth.example.com" -Audience "myapi.example.com"

.NOTES
This function is an internal Pode function and is subject to change.
#>
function ConvertTo-PodeJwt {
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    [OutputType([string])]
    param(
        [Parameter()]
        [hashtable]$Header = @{},

        [Parameter(Mandatory = $true)]
        [hashtable]$Payload,

        [Parameter( ParameterSetName = 'Default')]
        [Parameter( ParameterSetName = 'SecretBytes')]
        [ValidateSet('NONE', 'HS256', 'HS384', 'HS512')]
        [string]
        $Algorithm ,

        [Parameter(Mandatory = $true, ParameterSetName = 'SecretBytes')]
        $Secret = $null,

        [Parameter( Mandatory = $true, ParameterSetName = 'X509Certificate')]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]
        $X509Certificate,

        [Parameter(Mandatory = $true, ParameterSetName = 'Certificate_PFX_File')]
        [string]
        $PfxPath,

        [Parameter(Mandatory = $true, ParameterSetName = 'Certificate_PFX_Memory')]
        [byte[]]
        $PfxBytes,

        [Parameter(Mandatory = $false, ParameterSetName = 'Certificate_PFX_File')]
        [Parameter(Mandatory = $false, ParameterSetName = 'Certificate_PFX_Memory')]
        [SecureString]
        $PfxPassword, # Password for PFX certificate

        [Parameter(Mandatory = $false, ParameterSetName = 'X509Certificate')]
        [Parameter(Mandatory = $false, ParameterSetName = 'Certificate_PFX_File')]
        [Parameter(Mandatory = $false, ParameterSetName = 'Certificate_PFX_Memory')]
        [ValidateSet('Pkcs1V15', 'Pss')]
        [string]
        $RsaPaddingScheme = 'Pkcs1V15',

        [Parameter(Mandatory = $true, ParameterSetName = 'AuthenticationMethod')]
        [string]
        $Authentication,

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
        [string]$JwtId,

        [Parameter()]
        [switch]
        $NoStandardClaims
    )

    # Validate header
    <#     if (![string]::IsNullOrWhiteSpace($Header.alg)) {
        if (![string]::IsNullOrWhiteSpace($Algorithm)   ) {
            $Algorithm = [string]::IsNullOrWhiteSpace($Header.alg .ToUpper()
        }
    }
          throw ($PodeLocale.noAlgorithmInJwtHeaderExceptionMessage)
        }
        $Header['alg'] = $Algorithm.ToUpper()
    }
    elseif (( 'NONE', 'HS256', 'HS384', 'HS512', 'RS256', 'RS384', 'RS512', 'PS256', 'PS384', 'PS512', 'ES256', 'ES384', 'ES512' -contains $Header['alg'].ToUpper())) {
        $Header['alg'] = $Header['alg'].ToUpper()
    }
    else {
        $Header['alg'] = 'HS256'
    }#>

    switch ($PSCmdlet.ParameterSetName) {
        'Certificate_PFX_File' {

            if (!(Test-Path -Path $PfxPath -PathType Leaf)) {
                throw ($PodeLocale.pathNotExistExceptionMessage -f $PfxPath)
            }

            $PfxBytes = [System.IO.File]::ReadAllBytes($PfxPath)

            $X509Certificate = if ($null -ne $PfxPassword) {
                [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($PfxBytes, (Convert-PodeSecureStringToPlainText -SecureString $PfxPassword), [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::EphemeralKeySet)
            }
            else {
                [System.Security.Cryptography.X509Certificates.X509Certificate2]::new(
                    $PfxBytes,
                    $null, # No password
                    [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::EphemeralKeySet
                )
            }
            break
        }

        'Certificate_PFX_Memory' {
            $X509Certificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new()
            if ($null -ne $PfxPassword) {
                $X509Certificate.Import($PfxBytes, (Convert-PodeSecureStringToPlainText -SecureString $PfxPassword), [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::EphemeralKeySet)
            }
            else {
                $X509Certificate.Import($PfxBytes, $null, [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::EphemeralKeySet)
            }
            break
        }

        'SecretBytes' {
            if (!([string]::IsNullOrWhiteSpace($Header.alg))) {
                if ([string]::IsNullOrWhiteSpace($Algorithm)   ) {
                    $Algorithm = $Header.alg.ToUpper()
                }
            }
            if (($Algorithm -ieq 'none')) {
                # Expected no secret to be supplied for no signature
                throw ($PodeLocale.noSecretExpectedForNoSignatureExceptionMessage)
            }
            # Convert secret to bytes if needed
            if (($null -ne $Secret) -and ($Secret -isnot [byte[]])) {
                $Secret = if ($Secret -is [SecureString]) {
                    Convert-PodeSecureStringToByteArray -SecureString $Secret
                }
                else {
                    [System.Text.Encoding]::UTF8.GetBytes([string]$Secret)
                }

                if ($null -eq $Secret) {
                    throw ($PodeLocale.missingKeyForAlgorithmExceptionMessage -f 'secret', 'HMAC', $Header['alg'])
                }
            }
            if ([string]::IsNullOrWhiteSpace($Algorithm)) {
                $Algorithm = 'HS256'
            }

            $Header['alg'] = $Algorithm.ToUpper()
            $params = @{
                Algorithm   = $Algorithm.ToUpper()
                SecretBytes = $Secret
            }
            break
        }

        'X509Certificate' {
            if ($null -eq $X509Certificate) {
                throw ($PodeLocale.missingKeyForAlgorithmExceptionMessage -f 'private', 'RSA/ECSDA', $Header['alg'])
            }
            break
        }
        'AuthenticationMethod' {
            if ($PodeContext -and $PodeContext.Server.Authentications.Methods.ContainsKey($Authentication)) {
                if (($Header['alg'] -ieq 'none') -and $PodeContext.Server.Authentications.Methods.ContainsKey($Authentication).Algorithm -notcontains 'none') {
                    # Expected no secret to be supplied for no signature
                    throw ($PodeLocale.noSecretExpectedForNoSignatureExceptionMessage)
                }
                $params = @{
                    Authentication = $Authentication
                }
            }
            else {
                throw ($PodeLocale.authenticationMethodDoesNotExistExceptionMessage)
            }
        }
    }

    if ( $X509Certificate) {
        $Header['alg'] = Get-PodeJwtSigningAlgorithm -X509Certificate $X509Certificate -RsaPaddingScheme $RsaPaddingScheme

        $params = @{
            X509Certificate  = $X509Certificate
            RsaPaddingScheme = $RsaPaddingScheme
        }
    }

    if (! $NoStandardClaims) {
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
    }

    # Convert header & payload to Base64 URL format
    $header64 = ConvertTo-PodeBase64UrlValue -Value ($Header | ConvertTo-Json -Compress)
    $payload64 = ConvertTo-PodeBase64UrlValue -Value ($Payload | ConvertTo-Json -Compress)

    # Combine header and payload
    $jwt = "$($header64).$($payload64)"

    $sig = if ($Header['alg'] -ne 'none') {
        $params['Token'] = $jwt
        # Generate the signature
        New-PodeJwtSignature @params
    }
    else {
        [string]::Empty
    }

    #  Append the signature and return the JWT
    $jwt += ".$($sig)"
    return $jwt
}


<#
.SYNOPSIS
    Converts and returns the payload of a JWT token.

.DESCRIPTION
    Converts and returns the payload of a JWT token, verifying the signature by default with an option to ignore the signature.

.PARAMETER Token
    The JWT token to be decoded.

.PARAMETER Secret
    The secret key used to verify the token's signature (string or byte array).

.PARAMETER X509Certificate
    The X509 certificate used for RSA or ECDSA verification.

.PARAMETER PfxPath
    The file path to the PFX certificate used for verification.

.PARAMETER PfxBytes
    The PFX certificate in byte array format used for verification.

.PARAMETER PfxPassword
    The password for the PFX certificate if protected.

.PARAMETER RsaPaddingScheme
    The RSA padding scheme to be used (default: Pkcs1V15).

.PARAMETER IgnoreSignature
    Skips signature verification and returns the decoded payload directly.

.PARAMETER Authentication
    The authentication method from Pode's context used for JWT verification.

.OUTPUTS
    [pscustomobject] - Returns the decoded JWT payload as a PowerShell object.

.EXAMPLE
    ConvertFrom-PodeJwt -Token "<JWT_TOKEN>" -Secret "MySecretKey"
    This example decodes a JWT token and verifies its signature using an HMAC secret.

.EXAMPLE
    ConvertFrom-PodeJwt -Token "<JWT_TOKEN>" -X509Certificate $Certificate
    This example decodes and verifies a JWT token using an X509 certificate.
#>
function ConvertFrom-PodeJwt {
    [CmdletBinding(DefaultParameterSetName = 'Secret')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Token,

        [Parameter(ParameterSetName = 'Ignore')]
        [switch]
        $IgnoreSignature,

        [Parameter(Mandatory = $true, ParameterSetName = 'SecretBytes')]
        $Secret = $null,

        [Parameter( Mandatory = $true, ParameterSetName = 'X509Certificate')]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]
        $X509Certificate,

        [Parameter(Mandatory = $true, ParameterSetName = 'Certificate_PFX_File')]
        [string]
        $PfxPath,

        [Parameter(Mandatory = $true, ParameterSetName = 'Certificate_PFX_Memory')]
        [byte[]]
        $PfxBytes,

        [Parameter(Mandatory = $false, ParameterSetName = 'Certificate_PFX_File')]
        [Parameter(Mandatory = $false, ParameterSetName = 'Certificate_PFX_Memory')]
        [SecureString]
        $PfxPassword, # Password for PFX certificate

        [Parameter(Mandatory = $false, ParameterSetName = 'X509Certificate')]
        [Parameter(Mandatory = $false, ParameterSetName = 'Certificate_PFX_File')]
        [Parameter(Mandatory = $false, ParameterSetName = 'Certificate_PFX_Memory')]
        [ValidateSet('Pkcs1V15', 'Pss')]
        [string]
        $RsaPaddingScheme = 'Pkcs1V15',

        [Parameter(Mandatory = $true, ParameterSetName = 'AuthenticationMethod')]
        [string]
        $Authentication
    )
    switch ($PSCmdlet.ParameterSetName) {
        'Certificate_PFX_File' {

            if (!(Test-Path -Path $PfxPath -PathType Leaf)) {
                throw ($PodeLocale.pathNotExistExceptionMessage -f $PfxPath)
            }

            $PfxBytes = [System.IO.File]::ReadAllBytes($PfxPath)

            $X509Certificate = if ($null -ne $PfxPassword) {
                [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($PfxBytes, (Convert-PodeSecureStringToPlainText -SecureString $PfxPassword), [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::EphemeralKeySet)
            }
            else {
                [System.Security.Cryptography.X509Certificates.X509Certificate2]::new(
                    $PfxBytes,
                    $null, # No password
                    [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::EphemeralKeySet
                )
            }
            break
        }

        'Certificate_PFX_Memory' {
            $X509Certificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new()
            if ($null -ne $PfxPassword) {
                $X509Certificate.Import($PfxBytes, (Convert-PodeSecureStringToPlainText -SecureString $PfxPassword), [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::EphemeralKeySet)
            }
            else {
                $X509Certificate.Import($PfxBytes, $null, [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::EphemeralKeySet)
            }
            break
        }

        'SecretBytes' {
            # Convert secret to bytes if needed
            if (($null -ne $Secret) -and ($Secret -isnot [byte[]])) {
                $Secret = if ($Secret -is [SecureString]) {
                    Convert-PodeSecureStringToByteArray -SecureString $Secret
                }
                else {
                    [System.Text.Encoding]::UTF8.GetBytes([string]$Secret)
                }

                if ($null -eq $Secret) {
                    throw ($PodeLocale.missingKeyForAlgorithmExceptionMessage -f 'secret', 'HMAC', $Header['alg'])
                }
            }

            $params = @{
                Secret = $Secret
            }
            break
        }

        'X509Certificate' {
            if ($null -eq $X509Certificate) {
                throw ($PodeLocale.missingKeyForAlgorithmExceptionMessage -f 'private', 'RSA/ECSDA', $Header['alg'])
            }
            if (($Header['alg'] -ieq 'none')) {
                # Expected no secret to be supplied for no signature
                throw ($PodeLocale.noSecretExpectedForNoSignatureExceptionMessage)
            }
            break
        }

        'AuthenticationMethod' {
            if ($PodeContext -and $PodeContext.Server.Authentications.Methods.ContainsKey($Authentication)) {
                if (($Header['alg'] -ieq 'none') -and $PodeContext.Server.Authentications.Methods.ContainsKey($Authentication).Algorithm -notcontains 'none') {
                    # Expected no secret to be supplied for no signature
                    throw ($PodeLocale.noSecretExpectedForNoSignatureExceptionMessage)
                }
                $params = @{
                    Authentication = $Authentication
                }
            }
            else {
                throw ($PodeLocale.authenticationMethodDoesNotExistExceptionMessage)
            }
        }
    }

    if ( $X509Certificate) {
        $params = @{
            X509Certificate = $X509Certificate
        }
    }
    $params['Token'] = $Token

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

    $params['Algorithm'] = $header.alg

    return Confirm-PodeJwt @params
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
                throw ($PodeLocale.jwtInvalidAudienceExceptionMessage -f $PodeContext.Server.ApplicationName)
            }

            # Enforce application audience check
            if ($Payload.aud -is [string]) {
                if ($Payload.aud -ne $PodeContext.Server.ApplicationName) {
                    throw ($PodeLocale.jwtInvalidAudienceExceptionMessage -f $PodeContext.Server.ApplicationName)
                }
            }
            elseif ($Payload.aud -is [array]) {
                if ($Payload.aud -notcontains $PodeContext.Server.ApplicationName) {
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

<#
.SYNOPSIS
A simple helper function, to help generate a new Keytab file for use with Kerberos authentication.

.DESCRIPTION
A simple helper function, to help generate a new Keytab file for use with Kerberos authentication.

.PARAMETER Hostname
The Hostname to use for the Keytab file.

.PARAMETER DomainName
The Domain Name to use for the Keytab file.

.PARAMETER Username
The Username to use for the Keytab file.

.PARAMETER Password
The Password to use for the Keytab file. (Default: * - this will prompt for a password)

.PARAMETER FilePath
The File Path to save the Keytab file. (Default: pode.keytab)

.PARAMETER Crypto
The Encryption type to use for the Keytab file. (Default: All)

.EXAMPLE
New-PodeAuthKeyTab -Hostname 'pode.example.com' -DomainName 'example.com' -Username 'example\pode_user'

.EXAMPLE
New-PodeAuthKeyTab -Hostname 'pode.example.com' -DomainName 'example.com' -Username 'example\pode_user' -Password 'pa$$word!'

.EXAMPLE
New-PodeAuthKeyTab -Hostname 'pode.example.com' -DomainName 'example.com' -Username 'example\pode_user' -FilePath 'custom_name.keytab'

.EXAMPLE
New-PodeAuthKeyTab -Hostname 'pode.example.com' -DomainName 'example.com' -Username 'example\pode_user' -Crypto 'AES256-SHA1'

.NOTES
This function uses the ktpass command to generate the Keytab file.
#>
function New-PodeAuthKeyTab {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Hostname,

        [Parameter(Mandatory = $true)]
        [string]
        $DomainName,

        [Parameter(Mandatory = $true)]
        [string]
        $Username,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $Password = '*',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $FilePath = 'pode.keytab',

        [Parameter()]
        [ValidateSet('All', 'DES-CBC-CRC', 'DES-CBC-MD5', 'RC4-HMAC-NT', 'AES256-SHA1', 'AES128-SHA1')]
        [string]
        $Crypto = 'All'
    )

    ktpass /princ HTTP/$Hostname@$DomainName /mapuser $Username /pass $Password /out $FilePath /crypto $Crypto /ptype KRB5_NT_PRINCIPAL /mapop set
}

<#
.SYNOPSIS
    Creates a new Bearer authentication scheme for Pode.

.DESCRIPTION
    Defines a Bearer authentication scheme that allows authentication using a raw Bearer token or JWT. Supports JWT validation with configurable security levels and token extraction from headers or query parameters.

.PARAMETER HeaderTag
    The header tag used for the Bearer token (default: "Bearer").

.PARAMETER Location
    Specifies the token extraction location: `Header` (default) or `Query`.

.PARAMETER Scope
    A list of required scopes for the authentication scheme.

.PARAMETER Algorithm
    Accepted JWT signing algorithms: NONE, HS256, HS384, HS512, RS256, RS384, RS512, PS256, PS384, PS512, ES256, ES384, ES512.

.PARAMETER AsJWT
    Indicates if the Bearer token should be treated and validated as a JWT.

.PARAMETER Secret
    The HMAC secret key for JWT validation (required for HS256, HS384, HS512).

.PARAMETER PfxPath
    Path to the PFX certificate for RSA/ECDSA JWT validation.

.PARAMETER PfxBytes
    PFX certificate as a byte array.

.PARAMETER PfxPassword
    Password for the PFX certificate if needed.

.PARAMETER RsaPaddingScheme
    RSA padding scheme: `Pkcs1V15` (default) or `Pss`.

.PARAMETER JwtVerificationMode
    JWT validation strictness: `Strict`, `Moderate`, or `Lenient` (default).

.OUTPUTS
    [hashtable] - Returns the Bearer authentication scheme configuration.

.EXAMPLE
    New-PodeAuthBearerScheme -AsJWT -Algorithm "HS256" -Secret (ConvertTo-SecureString "MySecretKey" -AsPlainText -Force)

.EXAMPLE
    New-PodeAuthBearerScheme -AsJWT -Algorithm "RS256" -PrivateKey (Get-Content "private.pem" -Raw) -PublicKey (Get-Content "public.pem" -Raw)

.NOTES
    This function is an internal Pode function and is subject to change.
#>
function New-PodeAuthBearerScheme {
    [CmdletBinding(DefaultParameterSetName = 'Basic')]
    [OutputType([hashtable])]
    param(
        [string]
        $HeaderTag,

        [ValidateSet('Header', 'Query')]
        [string]
        $Location = 'Header',

        [string[]]
        $Scope,

        [Parameter(Mandatory = $true, ParameterSetName = 'Bearer_PFX_File')]
        [Parameter(Mandatory = $true, ParameterSetName = 'Bearer_NONE')]
        [Parameter(Mandatory = $true, ParameterSetName = 'Bearer_PFX_Memory')]
        [Parameter(Mandatory = $true, ParameterSetName = 'Bearer_HS')]
        [switch]
        $AsJWT,

        [Parameter(Mandatory = $false, ParameterSetName = 'Bearer_HS')]
        [ValidateSet( 'HS256', 'HS384', 'HS512' )]
        [string[]]
        $Algorithm = @(),

        [Parameter(Mandatory = $true, ParameterSetName = 'Bearer_HS')]
        [SecureString]
        $Secret,

        [Parameter(Mandatory = $true, ParameterSetName = 'Bearer_PFX_File')]
        [string]
        $PfxPath, # Path to PFX certificate

        [Parameter(Mandatory = $true, ParameterSetName = 'Bearer_PFX_Memory')]
        [byte[]]
        $PfxBytes, # PFX as a byte array (for in-memory usage)

        [Parameter(Mandatory = $false, ParameterSetName = 'Bearer_PFX_File')]
        [Parameter(Mandatory = $false, ParameterSetName = 'Bearer_PFX_Memory')]
        [SecureString]
        $PfxPassword, # Password for PFX certificate

        [Parameter(Mandatory = $false, ParameterSetName = 'Bearer_PFX_File')]
        [Parameter(Mandatory = $false, ParameterSetName = 'Bearer_PFX_Memory')]
        [ValidateSet('Pkcs1V15', 'Pss')]
        [string]
        $RsaPaddingScheme = 'Pkcs1V15',

        [Parameter(Mandatory = $true, ParameterSetName = 'Bearer_PFX_File')]
        [Parameter(Mandatory = $true, ParameterSetName = 'Bearer_PFX_Memory')]
        [Parameter(Mandatory = $true, ParameterSetName = 'Bearer_HS')]
        [ValidateSet('Strict', 'Moderate', 'Lenient')]
        [string]
        $JwtVerificationMode = 'Lenient'
    )

    # Default realm
    $_realm = 'User'

    # Convert middleware into valid hashtables
    $Middleware = @(ConvertTo-PodeMiddleware -Middleware $Middleware -PSSession $PSCmdlet.SessionState)

    switch ($PSCmdlet.ParameterSetName) {
        'Bearer_PFX_File' {
            if (!(Test-Path -Path $PfxPath -PathType Leaf)) {
                throw ($PodeLocale.pathNotExistExceptionMessage -f $PfxPath)
            }

            $PfxBytes = [System.IO.File]::ReadAllBytes($PfxPath)

            $x509Certificate = if ($null -ne $PfxPassword) {
                [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($PfxBytes, (Convert-PodeSecureStringToPlainText -SecureString $PfxPassword), [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::EphemeralKeySet)
            }
            else {
                [System.Security.Cryptography.X509Certificates.X509Certificate2]::new(
                    $PfxBytes,
                    $null, # No password
                    [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::EphemeralKeySet
                )
            }
            $alg = @( Get-PodeJwtSigningAlgorithm -X509Certificate $x509Certificate -RsaPaddingScheme $RsaPaddingScheme  )
            break
        }
        'Bearer_PFX_Memory' {
            $x509Certificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new()
            if ($null -ne $PfxPassword) {
                $x509Certificate.Import($PfxBytes, (Convert-PodeSecureStringToPlainText -SecureString $PfxPassword), [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::EphemeralKeySet)
            }
            else {
                $x509Certificate.Import($PfxBytes, $null, [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::EphemeralKeySet)
            }
            $alg = @( Get-PodeJwtSigningAlgorithm -X509Certificate $x509Certificate -RsaPaddingScheme $RsaPaddingScheme  )
            break
        }
        'Bearer_HS' {
            $alg = if ( $Algorithm.Count -eq 0) {
                @('HS256')
            }
            else {
                $Algorithm
            }
            break
        }
        'Bearer_NONE' {
            $alg = @('NONE')
            break
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
            Location            = $Location
            JwtVerificationMode = $JwtVerificationMode
            Algorithm           = $alg
            X509Certificate     = $x509Certificate
        }
    }
}

<#
.SYNOPSIS
    Creates a new Digest authentication scheme for Pode.

.DESCRIPTION
    This function defines a Digest authentication scheme in Pode. It allows specifying
    parameters such as the authentication algorithm, quality of protection, and an optional
    header tag. The function ensures secure authentication by leveraging Pode’s built-in
    digest authentication mechanisms.

.PARAMETER HeaderTag
    An optional custom header tag for the authentication scheme. Defaults to 'Digest'.

.PARAMETER Algorithm
    Specifies the digest algorithm used for authentication. The default is 'MD5'.
    Other supported values include 'SHA-1', 'SHA-256', 'SHA-512', 'SHA-384', and 'SHA-512/256'.

.PARAMETER QualityOfProtection
    Determines the Quality of Protection (QoP) setting for authentication. The default is 'auth'.
    Available options are 'auth', 'auth-int', and 'auth,auth-int'.

.OUTPUTS
    Hashtable containing the defined Digest authentication scheme for Pode.

.EXAMPLE
    New-PodeAuthDigestScheme -Algorithm 'SHA-256' -QualityOfProtection 'auth-int'

    This example creates a new Digest authentication scheme using SHA-256 and sets
    the Quality of Protection to 'auth-int'.

.NOTES
    Internal function for Pode authentication schemes. Subject to change in future updates.
#>

function New-PodeAuthDigestScheme {
    [CmdletBinding(DefaultParameterSetName = 'Basic')]
    [OutputType([hashtable])]
    param(

        [Parameter(ParameterSetName = 'Digest')]
        [string]
        $HeaderTag,

        [Parameter(ParameterSetName = 'Digest')]
        [ValidateSet('MD5', 'SHA-1', 'SHA-256', 'SHA-512', 'SHA-384', 'SHA-512/256')]
        [string[]]
        $Algorithm = 'MD5',

        [Parameter(ParameterSetName = 'Digest')]
        [ValidateSet('auth', 'auth-int', 'auth,auth-int'  )]
        [string[]]
        $QualityOfProtection = 'auth'
    )
    # default realm
    $_realm = 'User'

    # convert any middleware into valid hashtables
    $Middleware = @(ConvertTo-PodeMiddleware -Middleware $Middleware -PSSession $PSCmdlet.SessionState)

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