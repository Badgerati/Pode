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
                    HeaderTag = $HeaderTag
                    Encoding = $Encoding
                }
            }
        }

        'form' {
            return @{
                ScriptBlock = (Get-PodeAuthFormType)
                Options = @{
                    Fields = @{
                        Username = $UsernameField
                        Password = $PasswordField
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