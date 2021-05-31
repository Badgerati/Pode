<#
.SYNOPSIS
Create a new type of Authentication.

.DESCRIPTION
Create a new type of Authentication, which is used to parse the Request for user credentials for validating.

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

.PARAMETER Realm
The name of scope of the protected area.

.PARAMETER Type
The scheme type for custom Authentication types. Default is HTTP.

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
The Application Secret generated when registering a new app for OAuth2.

.PARAMETER RedirectUrl
An optional OAuth2 Redirect URL (default: <host>/oauth2/callback)

.PARAMETER AuthoriseUrl
The OAuth2 Authorisation URL to authenticate a User. This is optional if you're using an InnerScheme like Basic/Form.

.PARAMETER TokenUrl
The OAuth2 Token URL to acquire an access token.

.PARAMETER UserUrl
An optional User profile URL to retrieve a user's details - for OAuth2

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
function New-PodeAuthScheme
{
    [CmdletBinding(DefaultParameterSetName='Basic')]
    [OutputType([hashtable])]
    param (
        [Parameter(ParameterSetName='Basic')]
        [switch]
        $Basic,

        [Parameter(ParameterSetName='Basic')]
        [string]
        $Encoding = 'ISO-8859-1',

        [Parameter(ParameterSetName='Basic')]
        [Parameter(ParameterSetName='Bearer')]
        [Parameter(ParameterSetName='Digest')]
        [string]
        $HeaderTag,

        [Parameter(ParameterSetName='Form')]
        [switch]
        $Form,

        [Parameter(ParameterSetName='Form')]
        [string]
        $UsernameField = 'username',

        [Parameter(ParameterSetName='Form')]
        [string]
        $PasswordField = 'password',

        [Parameter(ParameterSetName='Custom')]
        [switch]
        $Custom,

        [Parameter(Mandatory=$true, ParameterSetName='Custom')]
        [ValidateScript({
            if (Test-PodeIsEmpty $_) {
                throw "A non-empty ScriptBlock is required for the Custom authentication scheme"
            }

            return $true
        })]
        [scriptblock]
        $ScriptBlock,

        [Parameter(ParameterSetName='Custom')]
        [hashtable]
        $ArgumentList,

        [Parameter(ParameterSetName='Custom')]
        [string]
        $Name,

        [Parameter()]
        [string]
        $Realm,

        [Parameter(ParameterSetName='Custom')]
        [ValidateSet('ApiKey', 'Http', 'OAuth2', 'OpenIdConnect')]
        [string]
        $Type = 'Http',

        [Parameter(ParameterSetName='Custom')]
        [scriptblock]
        $PostValidator,

        [Parameter(ParameterSetName='Digest')]
        [switch]
        $Digest,

        [Parameter(ParameterSetName='Bearer')]
        [switch]
        $Bearer,

        [Parameter(ParameterSetName='ClientCertificate')]
        [switch]
        $ClientCertificate,

        [Parameter(ParameterSetName='OAuth2', Mandatory=$true)]
        [string]
        $ClientId,

        [Parameter(ParameterSetName='OAuth2', Mandatory=$true)]
        [string]
        $ClientSecret,

        [Parameter(ParameterSetName='OAuth2')]
        [string]
        $RedirectUrl,

        [Parameter(ParameterSetName='OAuth2')]
        [string]
        $AuthoriseUrl,

        [Parameter(ParameterSetName='OAuth2', Mandatory=$true)]
        [string]
        $TokenUrl,

        [Parameter(ParameterSetName='OAuth2')]
        [string]
        $UserUrl,

        [Parameter(ParameterSetName='OAuth2')]
        [switch]
        $OAuth2,

        [Parameter(ParameterSetName='ApiKey')]
        [switch]
        $ApiKey,

        [Parameter(ParameterSetName='ApiKey')]
        [ValidateSet('Header', 'Query', 'Cookie')]
        [string]
        $Location = 'Header',

        [Parameter(ParameterSetName='ApiKey')]
        [string]
        $LocationName,

        [Parameter(ParameterSetName='Bearer')]
        [Parameter(ParameterSetName='OAuth2')]
        [string[]]
        $Scope,

        [Parameter(ValueFromPipeline=$true)]
        [hashtable]
        $InnerScheme,

        [Parameter(ParameterSetName='Basic')]
        [Parameter(ParameterSetName='Form')]
        [switch]
        $AsCredential,

        [Parameter(ParameterSetName='Bearer')]
        [Parameter(ParameterSetName='ApiKey')]
        [switch]
        $AsJWT,

        [Parameter(ParameterSetName='Bearer')]
        [Parameter(ParameterSetName='ApiKey')]
        [string]
        $Secret
    )

    # default realm
    $_realm = 'User'

    # configure the auth scheme
    switch ($PSCmdlet.ParameterSetName.ToLowerInvariant()) {
        'basic' {
            return @{
                Name = (Protect-PodeValue -Value $HeaderTag -Default 'Basic')
                Realm = (Protect-PodeValue -Value $Realm -Default $_realm)
                ScriptBlock = @{
                    Script = (Get-PodeAuthBasicType)
                    UsingVariables = $null
                }
                PostValidator = $null
                InnerScheme = $InnerScheme
                Scheme = 'http'
                Arguments = @{
                    HeaderTag = (Protect-PodeValue -Value $HeaderTag -Default 'Basic')
                    Encoding = (Protect-PodeValue -Value $Encoding -Default 'ISO-8859-1')
                    AsCredential = $AsCredential
                }
            }
        }

        'clientcertificate' {
            return @{
                Name = 'Mutual'
                Realm = (Protect-PodeValue -Value $Realm -Default $_realm)
                ScriptBlock = @{
                    Script = (Get-PodeAuthClientCertificateType)
                    UsingVariables = $null
                }
                PostValidator = $null
                InnerScheme = $InnerScheme
                Scheme = 'http'
                Arguments = @{}
            }
        }

        'digest' {
            return @{
                Name = 'Digest'
                Realm = (Protect-PodeValue -Value $Realm -Default $_realm)
                ScriptBlock = @{
                    Script = (Get-PodeAuthDigestType)
                    UsingVariables = $null
                }
                PostValidator = @{
                    Script = (Get-PodeAuthDigestPostValidator)
                    UsingVariables = $null
                }
                InnerScheme = $InnerScheme
                Scheme = 'http'
                Arguments = @{
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
                Name = 'Bearer'
                Realm = (Protect-PodeValue -Value $Realm -Default $_realm)
                ScriptBlock = @{
                    Script = (Get-PodeAuthBearerType)
                    UsingVariables = $null
                }
                PostValidator = @{
                    Script = (Get-PodeAuthBearerPostValidator)
                    UsingVariables = $null
                }
                Scheme = 'http'
                InnerScheme = $InnerScheme
                Arguments = @{
                    HeaderTag = (Protect-PodeValue -Value $HeaderTag -Default 'Bearer')
                    Scopes = $Scope
                    AsJWT = $AsJWT
                    Secret = $secretBytes
                }
            }
        }

        'form' {
            return @{
                Name = 'Form'
                Realm = (Protect-PodeValue -Value $Realm -Default $_realm)
                ScriptBlock = @{
                    Script = (Get-PodeAuthFormType)
                    UsingVariables = $null
                }
                PostValidator = $null
                InnerScheme = $InnerScheme
                Scheme = 'http'
                Arguments = @{
                    Fields = @{
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
                throw "OAuth2 requires an Authorise URL to be supplied"
            }

            return @{
                Name = 'OAuth2'
                Realm = (Protect-PodeValue -Value $Realm -Default $_realm)
                ScriptBlock = @{
                    Script = (Get-PodeAuthOAuth2Type)
                    UsingVariables = $null
                }
                PostValidator = $null
                Scheme = 'oauth2'
                InnerScheme = $InnerScheme
                Arguments = @{
                    Scopes = $Scope
                    Client = @{
                        ID = $ClientId
                        Secret = $ClientSecret
                    }
                    Urls = @{
                        Redirect = $RedirectUrl
                        Authorise = $AuthoriseUrl
                        Token = $TokenUrl
                        User = $UserUrl
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
                Name = 'ApiKey'
                Realm = (Protect-PodeValue -Value $Realm -Default $_realm)
                ScriptBlock = @{
                    Script = (Get-PodeAuthApiKeyType)
                    UsingVariables = $null
                }
                PostValidator = $null
                InnerScheme = $InnerScheme
                Scheme = 'apiKey'
                Arguments = @{
                    Location = $Location
                    LocationName = $LocationName
                    AsJWT = $AsJWT
                    Secret = $secretBytes
                }
            }
        }

        'custom' {
            $ScriptBlock, $usingScriptVars = Invoke-PodeUsingScriptConversion -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState

            if (!(Test-PodeIsEmpty $PostValidator)) {
                $PostValidator, $usingPostVars = Invoke-PodeUsingScriptConversion -ScriptBlock $PostValidator -PSSession $PSCmdlet.SessionState
            }

            return @{
                Name = $Name
                Realm = (Protect-PodeValue -Value $Realm -Default $_realm)
                InnerScheme = $InnerScheme
                Scheme = $Type.ToLowerInvariant()
                ScriptBlock = @{
                    Script = $ScriptBlock
                    UsingVariables = $usingScriptVars
                }
                PostValidator = @{
                    Script = $PostValidator
                    UsingVariables = $usingPostVars
                }
                Arguments = $ArgumentList
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
The Client Secret from registering a new app.

.PARAMETER RedirectUrl
An optional OAuth2 Redirect URL (default: <host>/oauth2/callback)

.PARAMETER InnerScheme
An optional authentication Scheme (from New-PodeAuthScheme) that will be called prior to this Scheme.

.EXAMPLE
New-PodeAuthAzureADScheme -Tenant 123-456-678 -ClientId abcdef -ClientSecret 1234.abc
#>
function New-PodeAuthAzureADScheme
{
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $Tenant = 'common',

        [Parameter(Mandatory=$true)]
        [string]
        $ClientId,

        [Parameter(Mandatory=$true)]
        [string]
        $ClientSecret,

        [Parameter()]
        [string]
        $RedirectUrl,

        [Parameter(ValueFromPipeline=$true)]
        [hashtable]
        $InnerScheme
    )

    return (New-PodeAuthScheme `
        -OAuth2 `
        -ClientId $ClientId `
        -ClientSecret $ClientSecret `
        -AuthoriseUrl "https://login.microsoftonline.com/$($Tenant)/oauth2/v2.0/authorize" `
        -TokenUrl "https://login.microsoftonline.com/$($Tenant)/oauth2/v2.0/token" `
        -UserUrl "https://graph.microsoft.com/oidc/userinfo" `
        -RedirectUrl $RedirectUrl `
        -InnerScheme $InnerScheme)
}

<#
.SYNOPSIS
Adds a custom Authentication method for verifying users.

.DESCRIPTION
Adds a custom Authentication method for verifying users.

.PARAMETER Name
A unique Name for the Authentication method.

.PARAMETER Scheme
The Scheme to use for retrieving credentials (From New-PodeAuthScheme).

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
function Add-PodeAuth
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Name,

        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [hashtable]
        $Scheme,

        [Parameter(Mandatory=$true)]
        [ValidateScript({
            if (Test-PodeIsEmpty $_) {
                throw "A non-empty ScriptBlock is required for the authentication method"
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
    if (Test-PodeAuth -Name $Name) {
        throw "Authentication method already defined: $($Name)"
    }

    # ensure the Scheme contains a scriptblock
    if (Test-PodeIsEmpty $Scheme.ScriptBlock) {
        throw "The supplied Scheme for the '$($Name)' authentication validator requires a valid ScriptBlock"
    }

    # if we're using sessions, ensure sessions have been setup
    if (!$Sessionless -and !(Test-PodeSessionsConfigured)) {
        throw 'Sessions are required to use session persistent authentication'
    }

    # check if the scriptblock has any using vars
    $ScriptBlock, $usingVars = Invoke-PodeUsingScriptConversion -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState

    # add auth method to server
    $PodeContext.Server.Authentications[$Name] = @{
        Scheme = $Scheme
        ScriptBlock = $ScriptBlock
        UsingVariables = $usingVars
        Arguments = $ArgumentList
        Sessionless = $Sessionless
        Failure = @{
            Url = $FailureUrl
            Message = $FailureMessage
        }
        Success = @{
            Url = $SuccessUrl
            UseOrigin = $SuccessUseOrigin
        }
    }

    # if the scheme is oauth2, and there's no redirect, set up a default one
    if (($Scheme.Name -ieq 'oauth2') -and ($null -eq $Scheme.InnerScheme)  -and [string]::IsNullOrWhiteSpace($Scheme.Arguments.Urls.Redirect)) {
        $path = '/oauth2/callback'
        $Scheme.Arguments.Urls.Redirect = $path
        Add-PodeRoute -Method Get -Path $path -Authentication $Name
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
function Get-PodeAuth
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Name
    )

    # ensure the name exists
    if (!(Test-PodeAuth -Name $Name)) {
        throw "Authentication method not defined: $($Name)"
    }

    # get auth method
    return $PodeContext.Server.Authentications[$Name]
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
(Unix Only) A custom domain name that is prepended onto usernames that are missing it (<Domain>\<Username>).

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

.PARAMETER OpenLDAP
If supplied, and on Windows, OpenLDAP will be used instead.

.PARAMETER SuccessUseOrigin
If supplied, successful authentication from a login page will redirect back to the originating page instead of the FailureUrl.

.EXAMPLE
New-PodeAuthScheme -Form | Add-PodeAuthWindowsAd -Name 'WinAuth'

.EXAMPLE
New-PodeAuthScheme -Basic | Add-PodeAuthWindowsAd -Name 'WinAuth' -Groups @('Developers')

.EXAMPLE
New-PodeAuthScheme -Form | Add-PodeAuthWindowsAd -Name 'WinAuth' -NoGroups

.EXAMPLE
New-PodeAuthScheme -Form | Add-PodeAuthWindowsAd -Name 'UnixAuth' -Server 'testdomain.company.com' -Domain 'testdomain'
#>
function Add-PodeAuthWindowsAd
{
    [CmdletBinding(DefaultParameterSetName='Groups')]
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Name,

        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [hashtable]
        $Scheme,

        [Parameter()]
        [Alias('Server')]
        [string]
        $Fqdn,

        [Parameter()]
        [string]
        $Domain,

        [Parameter(ParameterSetName='Groups')]
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

        [Parameter(ParameterSetName='NoGroups')]
        [switch]
        $NoGroups,

        [switch]
        $OpenLDAP,

        [switch]
        $SuccessUseOrigin
    )

    # ensure the name doesn't already exist
    if (Test-PodeAuth -Name $Name) {
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
        $ScriptBlock, $usingVars = Invoke-PodeUsingScriptConversion -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState
    }

    # add Windows AD auth method to server
    $PodeContext.Server.Authentications[$Name] = @{
        Scheme = $Scheme
        ScriptBlock = (Get-PodeAuthWindowsADMethod)
        Arguments = @{
            Server = $Fqdn
            Domain = $Domain
            Users = $Users
            Groups = $Groups
            NoGroups = $NoGroups
            OpenLDAP = $OpenLDAP
            ScriptBlock = @{
                Script = $ScriptBlock
                UsingVariables = $usingVars
            }
        }
        Sessionless = $Sessionless
        Failure = @{
            Url = $FailureUrl
            Message = $FailureMessage
        }
        Success = @{
            Url = $SuccessUrl
            UseOrigin = $SuccessUseOrigin
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
function Remove-PodeAuth
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string]
        $Name
    )

    $PodeContext.Server.Authentications.Remove($Name) | Out-Null
}

<#
.SYNOPSIS
Clear all defined Authentication methods.

.DESCRIPTION
Clear all defined Authentication methods.

.EXAMPLE
Clear-PodeAuth
#>
function Clear-PodeAuth
{
    [CmdletBinding()]
    param()

    $PodeContext.Server.Authentications.Clear()
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

.EXAMPLE
Add-PodeAuthMiddleware -Name 'GlobalAuth' -Authentication AuthName

.EXAMPLE
Add-PodeAuthMiddleware -Name 'GlobalAuth' -Authentication AuthName -Route '/api/*'
#>
function Add-PodeAuthMiddleware
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Name,

        [Parameter(Mandatory=$true)]
        [Alias('Auth')]
        [string]
        $Authentication,

        [Parameter()]
        [string]
        $Route
    )

    if (!(Test-PodeAuth -Name $Authentication)) {
        throw "Authentication method does not exist: $($Authentication)"
    }

    Get-PodeAuthMiddlewareScript |
        New-PodeMiddleware -ArgumentList @{ Name = $Authentication } |
        Add-PodeMiddleware -Name $Name -Route $Route

    Set-PodeOAGlobalAuth -Name $Authentication -Route $Route
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

.PARAMETER Sessionless
If supplied, authenticated users will not be stored in sessions, and sessions will not be used.

.PARAMETER NoGroups
If supplied, groups will not be retrieved for the user in AD.

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
function Add-PodeAuthIIS
{
    [CmdletBinding(DefaultParameterSetName='Groups')]
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Name,

        [Parameter(ParameterSetName='Groups')]
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

        [Parameter(ParameterSetName='NoGroups')]
        [switch]
        $NoGroups,

        [switch]
        $NoLocalCheck,

        [switch]
        $SuccessUseOrigin
    )

    # ensure we're on Windows!
    if (!(Test-PodeIsWindows)) {
        throw "IIS Authentication support is for Windows only"
    }

    # ensure the name doesn't already exist
    if (Test-PodeAuth -Name $Name) {
        throw "IIS Authentication method already defined: $($Name)"
    }

    # if we have a scriptblock, deal with using vars
    if ($null -ne $ScriptBlock) {
        $ScriptBlock, $usingVars = Invoke-PodeUsingScriptConversion -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState
    }

    # create the auth scheme for getting the token header
    $scheme = New-PodeAuthScheme -Custom -ScriptBlock {
        param($options)

        $header = 'MS-ASPNETCORE-WINAUTHTOKEN'

        # fail if no header
        if (!(Test-PodeHeader -Name $header)) {
            return @{
                Message = "No $($header) header found"
                Code = 401
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
            Users = $Users
            Groups = $Groups
            NoGroups = $NoGroups
            NoLocalCheck = $NoLocalCheck
            ScriptBlock = @{
                Script = $ScriptBlock
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
function Add-PodeAuthUserFile
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Name,

        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
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

        [Parameter(ParameterSetName='Hmac')]
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
    if (Test-PodeAuth -Name $Name) {
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
    }
    else {
        $FilePath = Get-PodeRelativePath -Path $FilePath -JoinRoot -Resolve
    }

    # ensure the user file exists
    if (!(Test-PodePath -Path $FilePath -NoStatus -FailOnDirectory)) {
        throw "The user file does not exist: $($FilePath)"
    }

    # if we have a scriptblock, deal with using vars
    if ($null -ne $ScriptBlock) {
        $ScriptBlock, $usingVars = Invoke-PodeUsingScriptConversion -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState
    }

    # add Windows AD auth method to server
    $PodeContext.Server.Authentications[$Name] = @{
        Scheme = $Scheme
        ScriptBlock = (Get-PodeAuthUserFileMethod)
        Arguments = @{
            FilePath = $FilePath
            Users = $Users
            Groups = $Groups
            HmacSecret = $HmacSecret
            ScriptBlock = @{
                Script = $ScriptBlock
                UsingVariables = $usingVars
            }
        }
        Sessionless = $Sessionless
        Failure = @{
            Url = $FailureUrl
            Message = $FailureMessage
        }
        Success = @{
            Url = $SuccessUrl
            UseOrigin = $SuccessUseOrigin
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
function Add-PodeAuthWindowsLocal
{
    [CmdletBinding(DefaultParameterSetName='Groups')]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Name,

        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [hashtable]
        $Scheme,

        [Parameter(ParameterSetName='Groups')]
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

        [Parameter(ParameterSetName='NoGroups')]
        [switch]
        $NoGroups,

        [switch]
        $SuccessUseOrigin
    )

    # ensure we're on Windows!
    if (!(Test-PodeIsWindows)) {
        throw "Windows Local Authentication support is for Windows only"
    }

    # ensure the name doesn't already exist
    if (Test-PodeAuth -Name $Name) {
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
        $ScriptBlock, $usingVars = Invoke-PodeUsingScriptConversion -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState
    }

    # add Windows Local auth method to server
    $PodeContext.Server.Authentications[$Name] = @{
        Scheme = $Scheme
        ScriptBlock = (Get-PodeAuthWindowsLocalMethod)
        Arguments = @{
            Users = $Users
            Groups = $Groups
            NoGroups = $NoGroups
            ScriptBlock = @{
                Script = $ScriptBlock
                UsingVariables = $usingVars
            }
        }
        Sessionless = $Sessionless
        Failure = @{
            Url = $FailureUrl
            Message = $FailureMessage
        }
        Success = @{
            Url = $SuccessUrl
            UseOrigin = $SuccessUseOrigin
        }
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
An Optional Secret for signing the JWT. This is mandatory if the Header algorithm isn't "none".

.EXAMPLE
ConvertTo-PodeJwt -Header @{ alg = 'none' } -Payload @{ sub = '123'; name = 'John' }

.EXAMPLE
ConvertTo-PodeJwt -Header @{ alg = 'hs256' } -Payload @{ sub = '123'; name = 'John' } -Secret 'abc'
#>
function ConvertTo-PodeJwt
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]
        $Header,

        [Parameter(Mandatory=$true)]
        [hashtable]
        $Payload,

        [Parameter()]
        [string]
        $Secret
    )

    # validate header
    if ([string]::IsNullOrWhiteSpace($Header.alg)) {
        throw "No algorithm supplied in JWT Header"
    }

    # convert the header
    $header64 = ConvertTo-PodeJwtBase64Value -Value ($Header | ConvertTo-Json -Compress)

    # convert the payload
    $payload64 = ConvertTo-PodeJwtBase64Value -Value ($Payload | ConvertTo-Json -Compress)

    # combine
    $jwt = "$($header64).$($payload64)"

    # convert secret to bytes
    $secretBytes = $null
    if (![string]::IsNullOrWhiteSpace($Secret)) {
        $secretBytes = [System.Text.Encoding]::UTF8.GetBytes($Secret)
    }

    # make the signature
    $sig = New-PodeJwtSignature -Algorithm $Header.alg -Token $jwt -SecretBytes $secretBytes

    # add the signature and return
    $jwt += ".$($sig)"
    return $jwt
}