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
The name of the type of Basic Authentication.

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

.PARAMETER Scope
An optional array of Scopes for Bearer Authentication. (These are case-sensitive)

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
        [string]
        $HeaderTag = 'Basic',

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
            if (Test-IsEmpty $_) {
                throw "A non-empty ScriptBlock is required for the Custom authentication type"
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

        [Parameter(ParameterSetName='Bearer')]
        [string[]]
        $Scope
    )

    # default realm
    $_realm = 'User'

    # configure the auth type
    switch ($PSCmdlet.ParameterSetName.ToLowerInvariant()) {
        'basic' {
            return @{
                Name = (Protect-PodeValue -Value $HeaderTag -Default 'Basic')
                Realm = (Protect-PodeValue -Value $Realm -Default $_realm)
                ScriptBlock = (Get-PodeAuthBasicType)
                PostValidator = $null
                Scheme = 'http'
                Arguments = @{
                    HeaderTag = (Protect-PodeValue -Value $HeaderTag -Default 'Basic')
                    Encoding = (Protect-PodeValue -Value $Encoding -Default 'ISO-8859-1')
                }
            }
        }

        'digest' {
            return @{
                Name = 'Digest'
                Realm = (Protect-PodeValue -Value $Realm -Default $_realm)
                ScriptBlock = (Get-PodeAuthDigestType)
                PostValidator = (Get-PodeAuthDigestPostValidator)
                Scheme = 'http'
                Arguments = @{}
            }
        }

        'bearer' {
            return @{
                Name = 'Bearer'
                Realm = (Protect-PodeValue -Value $Realm -Default $_realm)
                ScriptBlock = (Get-PodeAuthBearerType)
                PostValidator = (Get-PodeAuthBearerPostValidator)
                Scheme = 'http'
                Arguments = @{
                    Scopes = $Scope
                }
            }
        }

        'form' {
            return @{
                Name = 'Form'
                Realm = (Protect-PodeValue -Value $Realm -Default $_realm)
                ScriptBlock = (Get-PodeAuthFormType)
                PostValidator = $null
                Scheme = 'http'
                Arguments = @{
                    Fields = @{
                        Username = (Protect-PodeValue -Value $UsernameField -Default 'username')
                        Password = (Protect-PodeValue -Value $PasswordField -Default 'password')
                    }
                }
            }
        }

        'custom' {
            return @{
                Name = $Name
                Realm = (Protect-PodeValue -Value $Realm -Default $_realm)
                Scheme = $Type.ToLowerInvariant()
                ScriptBlock = $ScriptBlock
                PostValidator = $PostValidator
                Arguments = $ArgumentList
            }
        }
    }
}

<#
.SYNOPSIS
Adds a custom Authentication method for verifying users.

.DESCRIPTION
Adds a custom Authentication method for verifying users.

.PARAMETER Name
A unique Name for the Authentication method.

.PARAMETER Type
The Type to use for retrieving credentials (From New-PodeAuthScheme).

.PARAMETER ScriptBlock
The ScriptBlock defining logic that retrieves and verifys a user.

.PARAMETER ArgumentList
An array of arguments to supply to the Custom Authentication's ScriptBlock.

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
        $Type,

        [Parameter(Mandatory=$true)]
        [ValidateScript({
            if (Test-IsEmpty $_) {
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
        $Sessionless
    )

    # ensure the name doesn't already exist
    if (Test-PodeAuth -Name $Name) {
        throw "Authentication method already defined: $($Name)"
    }

    # ensure the Type contains a scriptblock
    if (Test-IsEmpty $Type.ScriptBlock) {
        throw "The supplied Type for the '$($Name)' authentication method requires a valid ScriptBlock"
    }

    # if we're using sessions, ensure sessions have been setup
    if (!$Sessionless -and !(Test-PodeSessionsConfigured)) {
        throw 'Sessions are required to use session persistent authentication'
    }

    # add auth method to server
    $PodeContext.Server.Authentications[$Name] = @{
        Type = $Type
        ScriptBlock = $ScriptBlock
        Arguments = $ArgumentList
        Sessionless = $Sessionless
        Failure = @{
            Url = $FailureUrl
            Message = $FailureMessage
        }
        Success = @{
            Url = $SuccessUrl
        }
    }
}

<#
.SYNOPSIS
Adds the inbuilt Windows AD Authentication method for verifying users.

.DESCRIPTION
Adds the inbuilt Windows AD Authentication method for verifying users.

.PARAMETER Name
A unique Name for the Authentication method.

.PARAMETER Type
The Type to use for retrieving credentials (From New-PodeAuthScheme).

.PARAMETER Fqdn
A custom FQDN for the DNS of the AD you wish to authenticate against. (Alias: Server)

.PARAMETER Domain
(Unix Only) A custom domain name that is prepended onto usernames that are missing it (<Domain>\<Username>).

.PARAMETER Groups
An array of Group names to only allow access.

.PARAMETER Users
An array of Usernames to only allow access.

.PARAMETER NoGroups
If supplied, groups will not be retrieved for the user in AD.

.PARAMETER OpenLDAP
If supplied, and on Windows, OpenLDAP will be used instead.

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
        $Type,

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

        [switch]
        $Sessionless,

        [Parameter(ParameterSetName='NoGroups')]
        [switch]
        $NoGroups,

        [switch]
        $OpenLDAP
    )

    # ensure the name doesn't already exist
    if (Test-PodeAuth -Name $Name) {
        throw "Windows AD Authentication method already defined: $($Name)"
    }

    # ensure the Type contains a scriptblock
    if (Test-IsEmpty $Type.ScriptBlock) {
        throw "The supplied Type for the '$($Name)' Windows AD authentication method requires a valid ScriptBlock"
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

    # add Windows AD auth method to server
    $PodeContext.Server.Authentications[$Name] = @{
        Type = $Type
        ScriptBlock = (Get-PodeAuthWindowsADMethod)
        Arguments = @{
            Server = $Fqdn
            Domain = $Domain
            Users = $Users
            Groups = $Groups
            NoGroups = $NoGroups
            OpenLDAP = $OpenLDAP
        }
        Sessionless = $Sessionless
        Failure = @{
            Url = $FailureUrl
            Message = $FailureMessage
        }
        Success = @{
            Url = $SuccessUrl
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

    Set-PodeOAGlobalAuth -Name $Authentication
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

.PARAMETER NoGroups
If supplied, groups will not be retrieved for the user in AD.

.PARAMETER NoLocalCheck
If supplied, Pode will not at attempt to retrieve local User/Group information for the authenticated user.

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

        [switch]
        $Sessionless,

        [Parameter(ParameterSetName='NoGroups')]
        [switch]
        $NoGroups,

        [switch]
        $NoLocalCheck
    )

    # ensure we're on Windows!
    if (!(Test-IsWindows)) {
        throw "IIS Authentication support is for Windows only"
    }

    # ensure the name doesn't already exist
    if (Test-PodeAuth -Name $Name) {
        throw "IIS Authentication method already defined: $($Name)"
    }

    # create the auth tye for getting the token header
    $type = New-PodeAuthScheme -Custom -ScriptBlock {
        param($e, $options)

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

    $type | Add-PodeAuth `
        -Name $Name `
        -ScriptBlock $method `
        -FailureUrl $FailureUrl `
        -FailureMessage $FailureMessage `
        -SuccessUrl $SuccessUrl `
        -Sessionless:$Sessionless `
        -ArgumentList @{
            Users = $Users
            Groups = $Groups
            NoGroups = $NoGroups
            NoLocalCheck = $NoLocalCheck
        }
}

<#
.SYNOPSIS
Adds the inbuilt User File Authentication method for verifying users.

.DESCRIPTION
Adds the inbuilt User File Authentication method for verifying users.

.PARAMETER Name
A unique Name for the Authentication method.

.PARAMETER Type
The Type to use for retrieving credentials (From New-PodeAuthScheme).

.PARAMETER FilePath
A path to a users JSON file (Default: ./users.json)

.PARAMETER Groups
An array of Group names to only allow access.

.PARAMETER Users
An array of Usernames to only allow access.

.PARAMETER HmacSecret
An optional secret if the passwords are HMAC SHA256 hashed.

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
        $Type,

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

        [switch]
        $Sessionless
    )

    # ensure the name doesn't already exist
    if (Test-PodeAuth -Name $Name) {
        throw "User File Authentication method already defined: $($Name)"
    }

    # ensure the Type contains a scriptblock
    if (Test-IsEmpty $Type.ScriptBlock) {
        throw "The supplied Type for the '$($Name)' User File authentication method requires a valid ScriptBlock"
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

    # add Windows AD auth method to server
    $PodeContext.Server.Authentications[$Name] = @{
        Type = $Type
        ScriptBlock = (Get-PodeAuthUserFileMethod)
        Arguments = @{
            FilePath = $FilePath
            Users = $Users
            Groups = $Groups
            HmacSecret = $HmacSecret
        }
        Sessionless = $Sessionless
        Failure = @{
            Url = $FailureUrl
            Message = $FailureMessage
        }
        Success = @{
            Url = $SuccessUrl
        }
    }
}