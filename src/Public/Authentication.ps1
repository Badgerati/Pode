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
The ScriptBlock to retrieve user credentials.

.PARAMETER Options
Any custom Options to supply to a Custom Authentication type's ScriptBlock.

.EXAMPLE
$basic_auth = New-PodeAuthType -Basic

.EXAMPLE
$form_auth = New-PodeAuthType -Form -UsernameField 'Email'

.EXAMPLE
$custom_auth = New-PodeAuthType -Custom -ScriptBlock {
    $username = Get-PodeHeader -Name 'X-Username'
    $password = Get-PodeHeader -Name 'X-Password'
    return @($username, $password)
}
#>
function New-PodeAuthType
{
    [CmdletBinding(DefaultParameterSetName='Basic')]
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
        $Options
    )

    # configure the auth type
    switch ($PSCmdlet.ParameterSetName.ToLowerInvariant()) {
        'basic' {
            return @{
                ScriptBlock = (Get-PodeAuthBasicType)
                Options = @{
                    HeaderTag = (Protect-PodeValue -Value $HeaderTag -Default 'Basic')
                    Encoding = (Protect-PodeValue -Value $Encoding -Default 'ISO-8859-1')
                }
            }
        }

        'form' {
            return @{
                ScriptBlock = (Get-PodeAuthFormType)
                Options = @{
                    Fields = @{
                        Username = (Protect-PodeValue -Value $UsernameField -Default 'username')
                        Password = (Protect-PodeValue -Value $PasswordField -Default 'password')
                    }
                }
            }
        }

        'custom' {
            return @{
                ScriptBlock = $ScriptBlock
                Options = $Options
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
The Type to use for retrieving credentials (From New-PodeAuthType).

.PARAMETER ScriptBlock
The ScriptBlock defining logic that retrieves and verifys a user.

.PARAMETER Options
Any custom Options to supply to the ScriptBlock.

.EXAMPLE
New-PodeAuthType -Form | Add-PodeAuth -Name 'Main' -ScriptBlock {
    param($user, $pass, $opts)

    if ($user -eq 'morty' -and $pass -eq 'evil') {
        return @{
            User = @{
                Username = 'morty'
            }
        }
    }

    return @{ Message = 'Invalid details supplied' }
}
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
        [hashtable]
        $Options
    )

    # ensure the name doesn't already exist
    if ($PodeContext.Server.Authentications.ContainsKey($Name)) {
        throw "Authentication method already defined: $($Name)"
    }

    # ensure the Type contains a scriptblock
    if (Test-IsEmpty $Type.ScriptBlock) {
        throw "The supplied Type for the '$($Name)' authentication method requires a valid ScriptBlock"
    }

    # add auth method to server
    $PodeContext.Server.Authentications[$Name] = @{
        Type = $Type
        ScriptBlock = $ScriptBlock
        Options = $Options
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
The Type to use for retrieving credentials (From New-PodeAuthType).

.PARAMETER Fqdn
A custom FQDN for the DNS of the AD you wish to authenticate against.

.PARAMETER Groups
An array of Group names to only allow access.

.PARAMETER Users
An array of Usernames to only allow access.

.EXAMPLE
New-PodeAuthType -Form | Add-PodeAuthWindowsAd -Name 'WinAuth'

.EXAMPLE
New-PodeAuthType -Basic | Add-PodeAuthWindowsAd -Name 'WinAuth' -Groups @('Developers')
#>
function Add-PodeAuthWindowsAd
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Name,

        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [hashtable]
        $Type,

        [Parameter()]
        [string]
        $Fqdn = $env:USERDNSDOMAIN,

        [Parameter()]
        [string[]]
        $Groups,

        [Parameter()]
        [string[]]
        $Users
    )

    # Check PowerShell/OS version
    $version = $PSVersionTable.PSVersion
    if ((Test-IsUnix) -or ($version.Major -eq 6 -and $version.Minor -eq 0)) {
        throw 'Windows AD authentication is currently only supported on Windows PowerShell, and Windows PowerShell Core v6.1+'
    }

    # ensure the name doesn't already exist
    if ($PodeContext.Server.Authentications.ContainsKey($Name)) {
        throw "Windows AD Authentication method already defined: $($Name)"
    }

    # ensure the Type contains a scriptblock
    if (Test-IsEmpty $Type.ScriptBlock) {
        throw "The supplied Type for the '$($Name)' Windows AD authentication method requires a valid ScriptBlock"
    }

    # add Windows AD auth method to server
    $PodeContext.Server.Authentications[$Name] = @{
        Type = $Type
        ScriptBlock = (Get-PodeAuthInbuiltMethod -Type WindowsAd)
        Options = @{
            Fqdn = $Fqdn
            Users = $Users
            Groups = $Groups
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
Returns Authentication Middleware that can be used globally, or an Routes.

.DESCRIPTION
Returns Authentication Middleware that can be used globally, or an Routes.

.PARAMETER Name
The Name of the Authentication method.

.PARAMETER FailureUrl
The URL to redirect to when authentication fails.

.PARAMETER FailureMessage
An override Message to throw when authentication fails.

.PARAMETER SuccessUrl
The URL to redirect to when authentication succeeds.

.PARAMETER EnableFlash
If supplied, error messages will be added as Flash messages.

.PARAMETER Sessionless
If supplied, authenticated users will not be stored in sessions, and sessions will not be used.

.PARAMETER AutoLogin
If supplied, navigating to a login page with a valid session will redirect to the SuccessUrl. Otherwise the login page will be displayed.

.PARAMETER Logout
If supplied, the current session will be purged, and the user will be redirected to the FailureUrl.

.EXAMPLE
Add-PodeRoute -Method Get -Path '/' -Middleware (Get-PodeAuthMiddleware -Name 'Main') -ScriptBlock {
    param($e)
    $e.Auth.User | Out-Default
}

.EXAMPLE
Get-PodeAuthMiddleware -Name 'BasicAuth' -Sessionless | Add-PodeMiddeware -Name 'GlobalAuth'

.EXAMPLE
$login_check = Get-PodeAuthMiddleware -Name 'Main' -SuccessUrl '/' -AutoLogin

Add-PodeRoute -Method Get -Path '/login' -Middleware $login_check -ScriptBlock {
    Write-PodeViewResponse -Path 'login' -FlashMessages
}
#>
function Get-PodeAuthMiddleware
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
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

        [switch]
        $EnableFlash,

        [switch]
        $Sessionless,

        [switch]
        $AutoLogin,

        [switch]
        $Logout
    )

    # ensure the auth method exists
    if (!$PodeContext.Server.Authentications.ContainsKey($Name)) {
        throw "Authentication method does not exist: $($Name)"
    }

    # if we're using sessions, ensure sessions have been setup
    if (!$Sessionless -and !(Test-PodeSessionsConfigured)) {
        throw 'Sessions are required to use session persistent authentication'
    }

    # create the options
    $options = @{
        Name = $Name
        Failure = @{
            Url = $FailureUrl
            Message = $FailureMessage
            FlashEnabled = $EnableFlash
        }
        Success = @{
            Url = $SuccessUrl
        }
        Sessionless = $Sessionless
        AutoLogin = $AutoLogin
        Logout = $Logout
    }

    # return the middleware
    return (Get-PodeAuthMiddlewareScript | New-PodeMiddleware -Options $options)
}