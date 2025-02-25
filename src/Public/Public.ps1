using namespace Pode

<#
.SYNOPSIS
    Add an authorisation Access method.

.DESCRIPTION
    Add an authorisation Access method for use with Authentication methods, which will authorise access to Routes.
    Or they can be used independant of Authentication/Routes for custom scenarios.

.PARAMETER Name
    A unique Name for the Access method.

.PARAMETER Description
    A short description used by OpenAPI.

.PARAMETER Scheme
    The access Scheme to use for retrieving credentials (From New-PodeAccessScheme).

.PARAMETER ScriptBlock
    An optional Scriptblock, which can be used to invoke custom validation logic to verify authorisation.

.PARAMETER ArgumentList
    An optional array of arguments to supply to the ScriptBlock.

.PARAMETER Match
    An optional inbuilt Match method to use when verifying access to a Route, this only applies when no custom Validator scriptblock is supplied. (Default: One)
    "One" will allow access if the User has at least one of the Route's access values.
    "All" will allow access only if the User has all the values.
    "None" will allow access only if the User has none of the values.

.EXAMPLE
    New-PodeAccessScheme -Type Role | Add-PodeAccess -Name 'Example'

.EXAMPLE
    New-PodeAccessScheme -Type Group -Path 'Metadata.Groups' | Add-PodeAccess -Name 'Example' -Match All

.EXAMPLE
    New-PodeAccessScheme -Type Scope -Scriptblock { param($user) return @(Get-ExampleAccess -Username $user.Username) } | Add-PodeAccess -Name 'Example'

.EXAMPLE
    New-PodeAccessScheme -Custom -Path 'CustomProp' | Add-PodeAccess -Name 'Example' -ScriptBlock { param($userAccess, $customAccess) return $userAccess.Country -ieq $customAccess.Country }
#>
function Add-PodeAccess {
    [CmdletBinding(DefaultParameterSetName = 'Match')]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [string]
        $Description,

        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [hashtable]
        $Scheme,

        [Parameter(Mandatory = $true, ParameterSetName = 'ScriptBlock')]
        [scriptblock]
        $ScriptBlock,

        [Parameter(ParameterSetName = 'ScriptBlock')]
        [object[]]
        $ArgumentList,

        [Parameter(ParameterSetName = 'Match')]
        [ValidateSet('All', 'One', 'None')]
        [string]
        $Match = 'One'
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
        # check name unique
        if (Test-PodeAccessExists -Name $Name) {
            # Access method already defined: $($Name)
            throw ($PodeLocale.accessMethodAlreadyDefinedExceptionMessage -f $Name)
        }

        # parse using variables in validator scriptblock
        $scriptObj = $null
        if (!(Test-PodeIsEmpty $ScriptBlock)) {
            $ScriptBlock, $usingScriptVars = Convert-PodeScopedVariables -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState
            $scriptObj = @{
                Script         = $ScriptBlock
                UsingVariables = $usingScriptVars
            }
        }

        # add access object
        $PodeContext.Server.Authorisations.Methods[$Name] = @{
            Name        = $Name
            Description = $Description
            Scheme      = $Scheme
            ScriptBlock = $scriptObj
            Arguments   = $ArgumentList
            Match       = $Match.ToLowerInvariant()
            Cache       = @{}
            Merged      = $false
            Parent      = $null
        }
    }
}


<#
.SYNOPSIS
    Assigns Custom Access value(s) to a Route.

.DESCRIPTION
    Assigns Custom Access value(s) to a Route.

.PARAMETER Route
    The Route to assign the Custom Access value(s).

.PARAMETER Name
    The Name of the Access method the Custom Access value(s) are for.

.PARAMETER Value
    The Custom Access Value(s)

.EXAMPLE
    Add-PodeRoute -Method Get -Path '/users' -ScriptBlock {} -PassThru | Add-PodeAccessCustom -Name 'Example' -Value @{ Country = 'UK' }
#>
function Add-PodeAccessCustom {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [hashtable[]]
        $Route,

        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true)]
        [object[]]
        $Value
    )

    begin {
        $routes = @()
    }

    process {
        $routes += $Route
    }

    end {
        foreach ($r in $routes) {
            if ($r.AccessMeta.Custom.ContainsKey($Name)) {
                throw ($PodeLocale.routeAlreadyContainsCustomAccessExceptionMessage -f $r.Method, $r.Path, $Name) #"Route '[$($r.Method)] $($r.Path)' already contains Custom Access with name '$($Name)'"
            }

            $r.AccessMeta.Custom[$Name] = $Value
        }
    }
}


<#
.SYNOPSIS
    Adds an access method as global middleware.

.DESCRIPTION
    Adds an access method as global middleware.

.PARAMETER Name
    The Name of the Middleware.

.PARAMETER Access
    The Name of the Access method to use.

.PARAMETER Route
    A Route path for which Routes this Middleware should only be invoked against.

.EXAMPLE
    Add-PodeAccessMiddleware -Name 'GlobalAccess' -Access AccessName

.EXAMPLE
    Add-PodeAccessMiddleware -Name 'GlobalAccess' -Access AccessName -Route '/api/*'
#>
function Add-PodeAccessMiddleware {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true)]
        [string]
        $Access,

        [Parameter()]
        [string]
        $Route
    )

    if (!(Test-PodeAccessExists -Name $Access)) {
        throw ($PodeLocale.accessMethodNotExistExceptionMessage -f $Access) #"Access method does not exist: $($Access)"
    }

    Get-PodeAccessMiddlewareScript |
        New-PodeMiddleware -ArgumentList @{ Name = $Access } |
        Add-PodeMiddleware -Name $Name -Route $Route
}


<#
.SYNOPSIS
    Clear all defined Access methods.

.DESCRIPTION
    Clear all defined Access methods.

.EXAMPLE
    Clear-PodeAccess
#>
function Clear-PodeAccess {
    [CmdletBinding()]
    param()

    $PodeContext.Server.Authorisations.Methods.Clear()
}


<#
.SYNOPSIS
    Get one or more Access methods.

.DESCRIPTION
    Get one or more Access methods.

.PARAMETER Name
    The Name of the Access method. If no name supplied, all methods will be returned.

.EXAMPLE
    $methods = Get-PodeAccess

.EXAMPLE
    $methods = Get-PodeAccess -Name 'Example'

.EXAMPLE
    $methods = Get-PodeAccess -Name 'Example1', 'Example2'
#>
function Get-PodeAccess {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter()]
        [string[]]
        $Name
    )

    # return all if no Name
    if ([string]::IsNullOrEmpty($Name) -or ($Name.Length -eq 0)) {
        return $PodeContext.Server.Authorisations.Methods.Values
    }

    # return filtered
    return @(foreach ($n in $Name) {
            $PodeContext.Server.Authorisations.Methods[$n]
        })
}


<#
.SYNOPSIS
    Let's you merge multiple Access methods together, into a "single" Access method.

.DESCRIPTION
    Let's you merge multiple Access methods together, into a "single" Access method.
    You can specify if only One or All of the methods need to pass to allow access, and you can also
    merge other merged Access methods for more advanced scenarios.

.PARAMETER Name
    A unique Name for the Access method.

.PARAMETER Access
    Mutliple Access method Names to be merged.

.PARAMETER Valid
    How many of the Access methods are required to be valid, One or All. (Default: One)

.EXAMPLE
    Merge-PodeAccess -Name MergedAccess -Access RbacAccess, GbacAccess -Valid All
#>
function Merge-PodeAccess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true)]
        [string[]]
        $Access,

        [Parameter()]
        [ValidateSet('One', 'All')]
        [string]
        $Valid = 'One'
    )

    # ensure the name doesn't already exist
    if (Test-PodeAccessExists -Name $Name) {
        throw ($PodeLocale.accessMethodAlreadyDefinedExceptionMessage -f $Name) #"Access method already defined: $($Name)"
    }

    # ensure all the access methods exist
    foreach ($accName in $Access) {
        if (!(Test-PodeAccessExists -Name $accName)) {
            throw ($PodeLocale.accessMethodNotExistForMergingExceptionMessage -f $accName) #"Access method does not exist for merging: $($accName)"
        }
    }

    # set parent access
    foreach ($accName in $Access) {
        $PodeContext.Server.Authorisations.Methods[$accName].Parent = $Name
    }

    # add auth method to server
    $PodeContext.Server.Authorisations.Methods[$Name] = @{
        Name    = $Name
        Access  = @($Access)
        PassOne = ($Valid -ieq 'one')
        Cache   = @{}
        Merged  = $true
        Parent  = $null
    }
}


<#
.SYNOPSIS
    Create a new type of Access scheme.

.DESCRIPTION
    Create a new type of Access scheme, which retrieves the destination/resource's authorisation values which a user needs for access.

.PARAMETER Type
    The inbuilt Type of Access this method is for: Role, Group, Scope, User.

.PARAMETER Custom
    If supplied, the access Scheme will be flagged as using Custom logic.

.PARAMETER ScriptBlock
    An optional ScriptBlock for retrieving authorisation values for the authenticated user, useful if the values reside in an external data store.
    This, or Path, is mandatory if using a Custom scheme.

.PARAMETER ArgumentList
    An optional array of arguments to supply to the ScriptBlock.

.PARAMETER Path
    An optional property Path within the $WebEvent.Auth.User object to extract authorisation values.
    The default Path is based on the Access Type, either Roles; Groups; Scopes; or Username.
    This, or ScriptBlock, is mandatory if using a Custom scheme.

.EXAMPLE
    $role_access = New-PodeAccessScheme -Type Role

.EXAMPLE
    $group_access = New-PodeAccessScheme -Type Group -Path 'Metadata.Groups'

.EXAMPLE
    $scope_access = New-PodeAccessScheme -Type Scope -Scriptblock { param($user) return @(Get-ExampleAccess -Username $user.Username) }

.EXAMPLE
    $custom_access = New-PodeAccessScheme -Custom -Path 'CustomProp'
#>
function New-PodeAccessScheme {
    [CmdletBinding(DefaultParameterSetName = 'Type_Path')]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'Type_Scriptblock')]
        [Parameter(Mandatory = $true, ParameterSetName = 'Type_Path')]
        [ValidateSet('Role', 'Group', 'Scope', 'User')]
        [string]
        $Type,

        [Parameter(Mandatory = $true, ParameterSetName = 'Custom_Scriptblock')]
        [Parameter(Mandatory = $true, ParameterSetName = 'Custom_Path')]
        [switch]
        $Custom,

        [Parameter(Mandatory = $true, ParameterSetName = 'Custom_Scriptblock')]
        [Parameter(ParameterSetName = 'Type_Scriptblock')]
        [scriptblock]
        $ScriptBlock,

        [Parameter(ParameterSetName = 'Custom_Scriptblock')]
        [Parameter(ParameterSetName = 'Type_Scriptblock')]
        [object[]]
        $ArgumentList,

        [Parameter(Mandatory = $true, ParameterSetName = 'Custom_Path')]
        [Parameter(ParameterSetName = 'Type_Path')]
        [string]
        $Path
    )

    # for custom access a validator is mandatory
    if ($Custom) {
        if ([string]::IsNullOrWhiteSpace($Path) -and (Test-PodeIsEmpty $ScriptBlock)) {
            # A Path or ScriptBlock is required for sourcing the Custom access values
            throw ($PodeLocale.customAccessPathOrScriptBlockRequiredExceptionMessage)
        }
    }

    # parse using variables in scriptblock
    $scriptObj = $null
    if (!(Test-PodeIsEmpty $ScriptBlock)) {
        $ScriptBlock, $usingScriptVars = Convert-PodeScopedVariables -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState
        $scriptObj = @{
            Script         = $ScriptBlock
            UsingVariables = $usingScriptVars
        }
    }

    # default path
    if (!$Custom -and (Test-PodeIsEmpty $ScriptBlock) -and [string]::IsNullOrWhiteSpace($Path)) {
        if ($Type -ieq 'user') {
            $Path = 'Username'
        }
        else {
            $Path = "$($Type)s"
        }
    }

    # return scheme
    return @{
        Type        = $Type
        IsCustom    = $Custom.IsPresent
        ScriptBlock = $scriptObj
        Arguments   = $ArgumentList
        Path        = $Path
    }
}


<#
.SYNOPSIS
    Remove a specific Access method.

.DESCRIPTION
    Remove a specific Access method.

.PARAMETER Name
    The Name of the Access method.

.EXAMPLE
    Remove-PodeAccess -Name 'RBAC'
#>
function Remove-PodeAccess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]
        $Name
    )
    process {
        $null = $PodeContext.Server.Authorisations.Methods.Remove($Name)
    }
}


<#
.SYNOPSIS
    Test access values for a Source/Destination against an Access method.

.DESCRIPTION
    Test access values for a Source/Destination against an Access method.

.PARAMETER Name
    The Name of the Access method to use to verify the access.

.PARAMETER Source
    An array of Source access values to pass to the Access method for verification against the Destination access values. (ie: User)

.PARAMETER Destination
    An array of Destination access values to pass to the Access method for verification. (ie: Route)

.PARAMETER ArgumentList
    An optional array of arguments to supply to the Access Scheme's ScriptBlock for retrieving access values.

.EXAMPLE
    if (Test-PodeAccess -Name 'Example' -Source 'Developer' -Destination 'Admin') { }
#>
function Test-PodeAccess {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [object[]]
        $Source = $null,

        [Parameter()]
        [object[]]
        $Destination = $null,

        [Parameter()]
        [object[]]
        $ArgumentList = $null
    )

    # get the access method
    $access = $PodeContext.Server.Authorisations.Methods[$Name]

    # authorised if no destination values
    if (($null -eq $Destination) -or ($Destination.Length -eq 0)) {
        return $true
    }

    # if we have no source values, invoke the scriptblock
    if (($null -eq $Source) -or ($Source.Length -eq 0)) {
        if ($null -ne $access.Scheme.ScriptBlock) {
            $_args = $ArgumentList + @($access.Scheme.Arguments)
            $Source = Invoke-PodeScriptBlock -ScriptBlock $access.Scheme.Scriptblock.Script -Arguments $_args -UsingVariables $access.Scheme.Scriptblock.UsingVariables -Return -Splat
        }
    }

    # check for custom validator, or use default match logic
    if ($null -ne $access.ScriptBlock) {
        $_args = @(, $Source) + @(, $Destination) + @($access.Arguments)
        return [bool](Invoke-PodeScriptBlock -ScriptBlock $access.ScriptBlock.Script -Arguments $_args -UsingVariables $access.ScriptBlock.UsingVariables -Return -Splat)
    }

    # not authorised if no source values
    if (($access.Match -ne 'none') -and (($null -eq $Source) -or ($Source.Length -eq 0))) {
        return $false
    }

    # one or all match?
    else {
        switch ($access.Match) {
            'one' {
                foreach ($item in $Source) {
                    if ($item -iin $Destination) {
                        return $true
                    }
                }
            }

            'all' {
                foreach ($item in $Destination) {
                    if ($item -inotin $Source) {
                        return $false
                    }
                }

                return $true
            }

            'none' {
                foreach ($item in $Source) {
                    if ($item -iin $Destination) {
                        return $false
                    }
                }

                return $true
            }
        }
    }

    # default is not authorised
    return $false
}


<#
.SYNOPSIS
    Test if an Access method exists.

.DESCRIPTION
    Test if an Access method exists.

.PARAMETER Name
    The Name of the Access method.

.EXAMPLE
    if (Test-PodeAccessExists -Name 'Example') { }
#>
function Test-PodeAccessExists {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )
    return $PodeContext.Server.Authorisations.Methods.ContainsKey($Name)
}


<#
.SYNOPSIS
    Test the currently authenticated User's access against the access values supplied for the current Route.

.DESCRIPTION
    Test the currently authenticated User's access against the access values supplied for the current Route.

.PARAMETER Name
    The Name of the Access method to use to verify the access.

.EXAMPLE
    if (Test-PodeAccessRoute -Name 'Example') { }
#>
function Test-PodeAccessRoute {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    # get the access method
    $access = $PodeContext.Server.Authorisations.Methods[$Name]

    # get route access values
    if ($access.Scheme.IsCustom) {
        $routeAccess = $WebEvent.Route.AccessMeta.Custom[$access.Name]
    }
    else {
        $routeAccess = $WebEvent.Route.AccessMeta[$access.Scheme.Type]
    }

    # if no values then skip
    if (($null -eq $routeAccess) -or ($routeAccess.Length -eq 0)) {
        return $true
    }

    # tests values against user
    return (Test-PodeAccessUser -Name $Name -Value $routeAccess)
}


<#
.SYNOPSIS
    Test the currently authenticated User's access against the supplied values.

.DESCRIPTION
    Test the currently authenticated User's access against the supplied values. This will be the user in a WebEvent object.

.PARAMETER Name
    The Name of the Access method to use to verify the access.

.PARAMETER Value
    An array of access values to pass to the Access method for verification against the User.

.EXAMPLE
    if (Test-PodeAccessUser -Name 'Example' -Value 'Developer', 'QA') { }
#>
function Test-PodeAccessUser {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true)]
        [object[]]
        $Value
    )

    # get the access method
    $access = $PodeContext.Server.Authorisations.Methods[$Name]

    # get the user
    $user = $WebEvent.Auth.User

    # if there's no scriptblock, try the Path fallback
    if ($null -eq $access.Scheme.Scriptblock) {
        $userAccess = $user
        foreach ($atom in $access.Scheme.Path.Split('.')) {
            $userAccess = $userAccess.($atom)
        }
    }

    # otherwise, invoke scriptblock
    else {
        $_args = @($user) + @($access.Scheme.Arguments)
        $userAccess = Invoke-PodeScriptBlock -ScriptBlock $access.Scheme.Scriptblock.Script -Arguments $_args -UsingVariables $access.Scheme.Scriptblock.UsingVariables -Return -Splat
    }

    # is the user authorised?
    return (Test-PodeAccess -Name $Name -Source $userAccess -Destination $Value)
}


<#
.SYNOPSIS
    Automatically loads access ps1 files

.DESCRIPTION
    Automatically loads access ps1 files from either an /access folder, or a custom folder. Saves space dot-sourcing them all one-by-one.

.PARAMETER Path
    Optional Path to a folder containing ps1 files, can be relative or literal.

.EXAMPLE
    Use-PodeAccess

.EXAMPLE
    Use-PodeAccess -Path './my-access'
#>
function Use-PodeAccess {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Path
    )

    Use-PodeFolder -Path $Path -DefaultPath 'access'
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
    [OutputType([pscustomobject])]
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
    $sig = New-PodeJwtSignature -Algorithm $header.alg -Token $sig -SecretBytes $Secret

    if ($sig -ne $parts[2]) {
        # Invalid JWT signature supplied
        throw ($PodeLocale.invalidJwtSignatureSuppliedExceptionMessage)
    }

    # it's valid return the payload!
    return $payload
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
    [OutputType([string])]
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
        # No algorithm supplied in JWT Header
        throw ($PodeLocale.noAlgorithmInJwtHeaderExceptionMessage)
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
                        HeaderTag   = (Protect-PodeValue -Value $HeaderTag -Default 'Bearer')
                        Scopes      = $Scope
                        AsJWT       = $AsJWT
                        Secret      = $secretBytes
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
            # The JWT has expired
            throw ($PodeLocale.jwtExpiredExceptionMessage)
        }
    }

    # validate not-before
    if (![string]::IsNullOrWhiteSpace($Payload.nbf)) {
        if ($now -lt $unixStart.AddSeconds($Payload.nbf)) {
            # The JWT is not yet valid for use
            throw ($PodeLocale.jwtNotYetValidExceptionMessage)
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
    Exports functions that can be auto-imported by Pode, and into its runspaces.

.DESCRIPTION
    Exports functions that can be auto-imported by Pode, and into its runspaces.

.PARAMETER Name
    The Name(s) of functions to export.

.EXAMPLE
    Export-PodeFunction -Name Mod1, Mod2
#>
function Export-PodeFunction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]
        $Name
    )

    $PodeContext.Server.AutoImport.Functions.ExportList += @($Name)
    $PodeContext.Server.AutoImport.Functions.ExportList = @($PodeContext.Server.AutoImport.Functions.ExportList | Sort-Object -Unique)
}


<#
.SYNOPSIS
    Exports modules that can be auto-imported by Pode, and into its runspaces.

.DESCRIPTION
    Exports modules that can be auto-imported by Pode, and into its runspaces.

.PARAMETER Name
    The Name(s) of modules to export.

.EXAMPLE
    Export-PodeModule -Name Mod1, Mod2
#>
function Export-PodeModule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]
        $Name
    )

    $PodeContext.Server.AutoImport.Modules.ExportList += @($Name)
    $PodeContext.Server.AutoImport.Modules.ExportList = @($PodeContext.Server.AutoImport.Modules.ExportList | Sort-Object -Unique)
}


<#
.SYNOPSIS
    Exports Secret Vaults that can be auto-imported by Pode, and into its runspaces.

.DESCRIPTION
    Exports Secret Vaults that can be auto-imported by Pode, and into its runspaces.

.PARAMETER Name
    The Name(s) of a Secret Vault to export.

.PARAMETER Type
    The Type of the Secret Vault to import - only option currently is SecretManagement (default: SecretManagement)

.EXAMPLE
    Export-PodeSecretVault -Name Vault1, Vault2
#>
function Export-PodeSecretVault {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]
        $Name,

        [Parameter()]
        [ValidateSet('SecretManagement')]
        [string]
        $Type = 'SecretManagement'
    )

    $PodeContext.Server.AutoImport.SecretVaults[$Type].ExportList += @($Name)
    $PodeContext.Server.AutoImport.SecretVaults[$Type].ExportList = @($PodeContext.Server.AutoImport.SecretVaults[$Type].ExportList | Sort-Object -Unique)
}


<#
.SYNOPSIS
    Exports snapins that can be auto-imported by Pode, and into its runspaces.

.DESCRIPTION
    Exports snapins that can be auto-imported by Pode, and into its runspaces.

.PARAMETER Name
    The Name(s) of snapins to export.

.EXAMPLE
    Export-PodeSnapin -Name Mod1, Mod2
#>
function Export-PodeSnapin {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]
        $Name
    )

    # if non-windows or core, fail
    if ((Test-PodeIsPSCore) -or (Test-PodeIsUnix)) {
        # Snapins are only supported on Windows PowerShell
        throw ($PodeLocale.snapinsSupportedOnWindowsPowershellOnlyExceptionMessage)
    }

    $PodeContext.Server.AutoImport.Snapins.ExportList += @($Name)
    $PodeContext.Server.AutoImport.Snapins.ExportList = @($PodeContext.Server.AutoImport.Snapins.ExportList | Sort-Object -Unique)
}


<#
.SYNOPSIS
    Add a cache storage.

.DESCRIPTION
    Add a cache storage.

.PARAMETER Name
    The Name of the cache storage.

.PARAMETER Get
    A Get ScriptBlock, to retrieve a key's value from the cache, or the value plus metadata if required. Supplied parameters: Key, Metadata.

.PARAMETER Set
    A Set ScriptBlock, to set/create/update a key's value in the cache. Supplied parameters: Key, Value, TTL.

.PARAMETER Remove
    A Remove ScriptBlock, to remove a key from the cache. Supplied parameters: Key.

.PARAMETER Test
    A Test ScriptBlock, to test if a key exists in the cache. Supplied parameters: Key.

.PARAMETER Clear
    A Clear ScriptBlock, to remove all keys from the cache. Use an empty ScriptBlock if not supported.

.PARAMETER Default
    If supplied, this cache storage will be set as the default storage.

.EXAMPLE
    Add-PodeCacheStorage -Name 'ExampleStorage' -Get {} -Set {} -Remove {} -Test {} -Clear {}
#>
function Add-PodeCacheStorage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name,

        [Parameter(Mandatory = $true)]
        [scriptblock]
        $Get,

        [Parameter(Mandatory = $true)]
        [scriptblock]
        $Set,

        [Parameter(Mandatory = $true)]
        [scriptblock]
        $Remove,

        [Parameter(Mandatory = $true)]
        [scriptblock]
        $Test,

        [Parameter(Mandatory = $true)]
        [scriptblock]
        $Clear,

        [switch]
        $Default
    )

    # test if storage already exists
    if (Test-PodeCacheStorage -Name $Name) {
        # Cache Storage with name already exists
        throw ($PodeLocale.cacheStorageAlreadyExistsExceptionMessage -f $Name)
    }

    # add cache storage
    $PodeContext.Server.Cache.Storage[$Name] = @{
        Name    = $Name
        Get     = $Get
        Set     = $Set
        Remove  = $Remove
        Test    = $Test
        Clear   = $Clear
        Default = $Default.IsPresent
    }

    # is default storage?
    if ($Default) {
        $PodeContext.Server.Cache.DefaultStorage = $Name
    }
}


<#
.SYNOPSIS
    Clear all keys from the cache.

.DESCRIPTION
    Clear all keys from the cache.

.PARAMETER Storage
    An optional cache Storage name. (Default: in-memory)

.EXAMPLE
    Clear-PodeCache

.EXAMPLE
    Clear-PodeCache -Storage 'ExampleStorage'
#>
function Clear-PodeCache {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Storage = $null
    )

    # inmem or custom storage?
    if ([string]::IsNullOrEmpty($Storage)) {
        $Storage = $PodeContext.Server.Cache.DefaultStorage
    }

    # use inmem cache
    if ([string]::IsNullOrEmpty($Storage)) {
        Clear-PodeCacheInternal
    }

    # used custom storage
    elseif (Test-PodeCacheStorage -Name $Storage) {
        $null = Invoke-PodeScriptBlock -ScriptBlock $PodeContext.Server.Cache.Storage[$Storage].Clear
    }

    # storage not found!
    else {
        # Cache storage with name not found when attempting to clear the cache
        throw ($PodeLocale.cacheStorageNotFoundForClearExceptionMessage -f $Storage)
    }
}


<#
.SYNOPSIS
    Return the value of a key from the cache. You can use "$value = $cache:key" as well.

.DESCRIPTION
    Return the value of a key from the cache, or returns the value plus metadata such as expiry time if required. You can use "$value = $cache:key" as well.

.PARAMETER Key
    The Key to be retrieved.

.PARAMETER Storage
    An optional cache Storage name. (Default: in-memory)

.PARAMETER Metadata
    If supplied, and if supported by the cache storage, an metadata such as expiry times will also be returned.

.EXAMPLE
    $value = Get-PodeCache -Key 'ExampleKey'

.EXAMPLE
    $value = Get-PodeCache -Key 'ExampleKey' -Storage 'ExampleStorage'

.EXAMPLE
    $value = Get-PodeCache -Key 'ExampleKey' -Metadata

.EXAMPLE
    $value = $cache:ExampleKey
#>
function Get-PodeCache {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Key,

        [Parameter()]
        [string]
        $Storage = $null,

        [switch]
        $Metadata
    )

    # inmem or custom storage?
    if ([string]::IsNullOrEmpty($Storage)) {
        $Storage = $PodeContext.Server.Cache.DefaultStorage
    }

    # use inmem cache
    if ([string]::IsNullOrEmpty($Storage)) {
        return (Get-PodeCacheInternal -Key $Key -Metadata:$Metadata)
    }

    # used custom storage
    if (Test-PodeCacheStorage -Name $Storage) {
        return (Invoke-PodeScriptBlock -ScriptBlock $PodeContext.Server.Cache.Storage[$Storage].Get -Arguments @($Key, $Metadata.IsPresent) -Splat -Return)
    }

    # storage not found!
    # Cache storage with name not found when attempting to retrieve cached item
    throw ($PodeLocale.cacheStorageNotFoundForRetrieveExceptionMessage -f $Storage, $Key)
}


<#
.SYNOPSIS
    Returns the current default cache Storage name.

.DESCRIPTION
    Returns the current default cache Storage name. Empty/null if one isn't set.

.EXAMPLE
    $storageName = Get-PodeCacheDefaultStorage
#>
function Get-PodeCacheDefaultStorage {
    [CmdletBinding()]
    param()

    return $PodeContext.Server.Cache.DefaultStorage
}


<#
.SYNOPSIS
    Returns the current default cache TTL value.

.DESCRIPTION
    Returns the current default cache TTL value. 3600 seconds is the default TTL if not set.

.EXAMPLE
    $ttl = Get-PodeCacheDefaultTtl
#>
function Get-PodeCacheDefaultTtl {
    [CmdletBinding()]
    param()

    return $PodeContext.Server.Cache.DefaultTtl
}


<#
.SYNOPSIS
    Returns a cache storage.

.DESCRIPTION
    Returns a cache storage.

.PARAMETER Name
    The Name of the cache storage.

.EXAMPLE
    $storage = Get-PodeCacheStorage -Name 'ExampleStorage'
#>
function Get-PodeCacheStorage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    return $PodeContext.Server.Cache.Storage[$Name]
}


<#
.SYNOPSIS
    Remove a key from the cache.

.DESCRIPTION
    Remove a key from the cache.

.PARAMETER Key
    The Key to be removed.

.PARAMETER Storage
    An optional cache Storage name. (Default: in-memory)

.EXAMPLE
    Remove-PodeCache -Key 'ExampleKey'

.EXAMPLE
    Remove-PodeCache -Key 'ExampleKey' -Storage 'ExampleStorage'
#>
function Remove-PodeCache {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Key,

        [Parameter()]
        [string]
        $Storage = $null
    )

    # inmem or custom storage?
    if ([string]::IsNullOrEmpty($Storage)) {
        $Storage = $PodeContext.Server.Cache.DefaultStorage
    }

    # use inmem cache
    if ([string]::IsNullOrEmpty($Storage)) {
        Remove-PodeCacheInternal -Key $Key
    }

    # used custom storage
    elseif (Test-PodeCacheStorage -Name $Storage) {
        $null = Invoke-PodeScriptBlock -ScriptBlock $PodeContext.Server.Cache.Storage[$Storage].Remove -Arguments @($Key) -Splat
    }

    # storage not found!
    else {
        # Cache storage with name not found when attempting to remove cached item
        throw ($PodeLocale.cacheStorageNotFoundForRemoveExceptionMessage -f $Storage, $Key)
    }
}


<#
.SYNOPSIS
    Remove a cache storage.

.DESCRIPTION
    Remove a cache storage.

.PARAMETER Name
    The Name of the cache storage.

.EXAMPLE
    Remove-PodeCacheStorage -Name 'ExampleStorage'
#>
function Remove-PodeCacheStorage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    $null = $PodeContext.Server.Cache.Storage.Remove($Name)
}


<#
.SYNOPSIS
    Set (create/update) a key in the cache. You can use "$cache:key = 'value'" as well.

.DESCRIPTION
    Set (create/update) a key in the cache, with an optional TTL value. You can use "$cache:key = 'value'" as well.

.PARAMETER Key
    The Key to be set.

.PARAMETER InputObject
    The value of the key to be set, can be any object type.

.PARAMETER Ttl
    An optional TTL value, in seconds. The default is whatever "Get-PodeCacheDefaultTtl" retuns, which will be 3600 seconds when not set.

.PARAMETER Storage
    An optional cache Storage name. (Default: in-memory)

.EXAMPLE
    Set-PodeCache -Key 'ExampleKey' -InputObject 'ExampleValue'

.EXAMPLE
    Set-PodeCache -Key 'ExampleKey' -InputObject 'ExampleValue' -Storage 'ExampleStorage'

.EXAMPLE
    Set-PodeCache -Key 'ExampleKey' -InputObject 'ExampleValue' -Ttl 300

.EXAMPLE
    Set-PodeCache -Key 'ExampleKey' -InputObject @{ Value = 'ExampleValue' }

.EXAMPLE
    @{ Value = 'ExampleValue' } | Set-PodeCache -Key 'ExampleKey'

.EXAMPLE
    $cache:ExampleKey = 'ExampleValue'
#>
function Set-PodeCache {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Key,

        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [object]
        $InputObject,

        [Parameter()]
        [int]
        $Ttl = 0,

        [Parameter()]
        [string]
        $Storage = $null
    )

    begin {
        # Initialize an array to hold piped-in values
        $pipelineValue = @()
    }

    process {
        # Add the current piped-in value to the array
        $pipelineValue += $_
    }

    end {
        # If there are multiple piped-in values, set InputObject to the array of values
        if ($pipelineValue.Count -gt 1) {
            $InputObject = $pipelineValue
        }

        # use the global settable default here
        if ($Ttl -le 0) {
            $Ttl = $PodeContext.Server.Cache.DefaultTtl
        }

        # inmem or custom storage?
        if ([string]::IsNullOrEmpty($Storage)) {
            $Storage = $PodeContext.Server.Cache.DefaultStorage
        }

        # use inmem cache
        if ([string]::IsNullOrEmpty($Storage)) {
            Set-PodeCacheInternal -Key $Key -InputObject $InputObject -Ttl $Ttl
        }

        # used custom storage
        elseif (Test-PodeCacheStorage -Name $Storage) {
            $null = Invoke-PodeScriptBlock -ScriptBlock $PodeContext.Server.Cache.Storage[$Storage].Set -Arguments @($Key, $InputObject, $Ttl) -Splat
        }

        # storage not found!
        else {
            # Cache storage with name not found when attempting to set cached item
            throw ($PodeLocale.cacheStorageNotFoundForSetExceptionMessage -f $Storage, $Key)
        }
    }
}


<#
.SYNOPSIS
    Set a default cache storage.

.DESCRIPTION
    Set a default cache storage.

.PARAMETER Name
    The Name of the default storage to use for caching.

.EXAMPLE
    Set-PodeCacheDefaultStorage -Name 'ExampleStorage'
#>
function Set-PodeCacheDefaultStorage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    $PodeContext.Server.Cache.DefaultStorage = $Name
}


<#
.SYNOPSIS
    Set a default cache TTL.

.DESCRIPTION
    Set a default cache TTL.

.PARAMETER Value
    A default TTL value, in seconds, to use when setting cache key expiries.

.EXAMPLE
    Set-PodeCacheDefaultTtl -Value 3600
#>
function Set-PodeCacheDefaultTtl {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]
        $Value
    )

    if ($Value -le 0) {
        return
    }

    $PodeContext.Server.Cache.DefaultTtl = $Value
}


<#
.SYNOPSIS
    Test if a key exists in the cache.

.DESCRIPTION
    Test if a key exists in the cache, and isn't expired.

.PARAMETER Key
    The Key to test.

.PARAMETER Storage
    An optional cache Storage name. (Default: in-memory)

.EXAMPLE
    Test-PodeCache -Key 'ExampleKey'

.EXAMPLE
    Test-PodeCache -Key 'ExampleKey' -Storage 'ExampleStorage'
#>
function Test-PodeCache {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Key,

        [Parameter()]
        [string]
        $Storage = $null
    )

    # inmem or custom storage?
    if ([string]::IsNullOrEmpty($Storage)) {
        $Storage = $PodeContext.Server.Cache.DefaultStorage
    }

    # use inmem cache
    if ([string]::IsNullOrEmpty($Storage)) {
        return (Test-PodeCacheInternal -Key $Key)
    }

    # used custom storage
    if (Test-PodeCacheStorage -Name $Storage) {
        return (Invoke-PodeScriptBlock -ScriptBlock $PodeContext.Server.Cache.Storage[$Storage].Test -Arguments @($Key) -Splat -Return)
    }

    # storage not found!
    # Cache storage with name not found when attempting to check if cached item exists
    throw ($PodeLocale.cacheStorageNotFoundForExistsExceptionMessage -f $Storage, $Key)
}


<#
.SYNOPSIS
    Test if a cache storage has been added/exists.

.DESCRIPTION
    Test if a cache storage has been added/exists.

.PARAMETER Name
    The Name of the cache storage.

.EXAMPLE
    if (Test-PodeCacheStorage -Name 'ExampleStorage') { }
#>
function Test-PodeCacheStorage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    return $PodeContext.Server.Cache.Storage.ContainsKey($Name)
}


<#
.SYNOPSIS
    Retrieves a cookie from the Request.

.DESCRIPTION
    Retrieves a cookie from the Request, with the option to supply a secret to unsign the cookie's value.

.PARAMETER Name
    The name of the cookie to retrieve.

.PARAMETER Secret
    The secret used to unsign the cookie's value.

.PARAMETER Strict
    If supplied, the Secret will be extended using the client request's UserAgent and RemoteIPAddress.

.PARAMETER Raw
    If supplied, the cookie returned will be the raw .NET Cookie object for manipulation.

.EXAMPLE
    Get-PodeCookie -Name 'Views'

.EXAMPLE
    Get-PodeCookie -Name 'Views' -Secret 'hunter2'
#>
function Get-PodeCookie {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [string]
        $Secret,

        [switch]
        $Strict,

        [switch]
        $Raw
    )

    # get the cookie from the request
    $cookie = $WebEvent.Cookies[$Name]
    if (!$Raw) {
        $cookie = (ConvertTo-PodeCookie -Cookie $cookie)
    }

    if (($null -eq $cookie) -or [string]::IsNullOrWhiteSpace($cookie.Value)) {
        return $null
    }

    # if a secret was supplied, attempt to unsign the cookie
    if (![string]::IsNullOrWhiteSpace($Secret)) {
        $value = (Invoke-PodeValueUnsign -Value $cookie.Value -Secret $Secret -Strict:$Strict)
        if (![string]::IsNullOrWhiteSpace($value)) {
            $cookie.Value = $value
        }
    }

    return $cookie
}


<#
.SYNOPSIS
    Retrieves a stored secret value.

.DESCRIPTION
    Retrieves a stored secret value.

.PARAMETER Name
    The name of the secret to retrieve.

.PARAMETER Global
    If flagged, will return the current global secret value.

.EXAMPLE
    Get-PodeCookieSecret -Name 'my-secret'

.EXAMPLE
    Get-PodeCookieSecret -Global
#>
function Get-PodeCookieSecret {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'General')]
        [string]
        $Name,

        [Parameter(ParameterSetName = 'Global')]
        [switch]
        $Global
    )

    if ($Global) {
        return ($PodeContext.Server.Cookies.Secrets['global'])
    }

    return ($PodeContext.Server.Cookies.Secrets[$Name])
}


<#
.SYNOPSIS
    Retrieves the value of a cookie from the Request.

.DESCRIPTION
    Retrieves the value of a cookie from the Request, with the option to supply a secret to unsign the cookie's value.

.PARAMETER Name
    The name of the cookie to retrieve.

.PARAMETER Secret
    The secret used to unsign the cookie's value.

.PARAMETER Strict
    If supplied, the Secret will be extended using the client request's UserAgent and RemoteIPAddress.

.EXAMPLE
    Get-PodeCookieValue -Name 'Views'

.EXAMPLE
    Get-PodeCookieValue -Name 'Views' -Secret 'hunter2'
#>
function Get-PodeCookieValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [string]
        $Secret,

        [switch]
        $Strict
    )

    $cookie = Get-PodeCookie -Name $Name -Secret $Secret -Strict:$Strict
    if ($null -eq $cookie) {
        return $null
    }

    return $cookie.Value
}


<#
.SYNOPSIS
    Removes a cookie from the Response.

.DESCRIPTION
    Removes a cookie from the Response, this is done by immediately expiring the cookie and flagging it for discard.

.PARAMETER Name
    The name of the cookie to be removed.

.EXAMPLE
    Remove-PodeCookie -Name 'Views'
#>
function Remove-PodeCookie {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    # get the cookie from the response - if it's not found, get it from the request
    $cookie = $WebEvent.PendingCookies[$Name]
    if ($null -eq $cookie) {
        $cookie = Get-PodeCookie -Name $Name -Raw
    }

    # remove the cookie from the response, and reset it to expire
    if ($null -ne $cookie) {
        $cookie.Discard = $true
        $cookie.Expires = [DateTime]::UtcNow.AddDays(-2)
        $cookie.Path = '/'
        $WebEvent.PendingCookies[$cookie.Name] = $cookie
        Add-PodeHeader -Name 'Set-Cookie' -Value (ConvertTo-PodeCookieString -Cookie $cookie)
    }
}


<#
.SYNOPSIS
    Sets a cookie on the Response.

.DESCRIPTION
    Sets a cookie on the Response using the "Set-Cookie" header. You can also set cookies to expire, or being signed.

.PARAMETER Name
    The name of the cookie.

.PARAMETER Value
    The value of the cookie.

.PARAMETER Secret
    If supplied, the secret with which to sign the cookie.

.PARAMETER Duration
    The duration, in seconds, before the cookie is expired.

.PARAMETER ExpiryDate
    An explicit expiry date for the cookie.

.PARAMETER HttpOnly
    Only allow the cookie to be used in browsers.

.PARAMETER Discard
    Inform browsers to remove the cookie.

.PARAMETER Secure
    Only allow the cookie on secure (HTTPS) connections.

.PARAMETER Strict
    If supplied, the Secret will be extended using the client request's UserAgent and RemoteIPAddress.

.EXAMPLE
    Set-PodeCookie -Name 'Views' -Value 2

.EXAMPLE
    Set-PodeCookie -Name 'Views' -Value 2 -Secret 'hunter2'

.EXAMPLE
    Set-PodeCookie -Name 'Views' -Value 2 -Duration 3600
#>
function Set-PodeCookie {
    [CmdletBinding(DefaultParameterSetName = 'Duration')]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [string]
        $Value,

        [Parameter()]
        [string]
        $Secret,

        [Parameter(ParameterSetName = 'Duration')]
        [int]
        $Duration = 0,

        [Parameter(ParameterSetName = 'ExpiryDate')]
        [datetime]
        $ExpiryDate,

        [switch]
        $HttpOnly,

        [switch]
        $Discard,

        [switch]
        $Secure,

        [switch]
        $Strict
    )

    # sign the value if we have a secret
    if (![string]::IsNullOrWhiteSpace($Secret)) {
        $Value = (Invoke-PodeValueSign -Value $Value -Secret $Secret -Strict:$Strict)
    }

    # create a new cookie
    $cookie = [System.Net.Cookie]::new($Name, $Value)
    $cookie.Secure = $Secure
    $cookie.Discard = $Discard
    $cookie.HttpOnly = $HttpOnly
    $cookie.Path = '/'

    if ($null -ne $ExpiryDate) {
        if ($ExpiryDate.Kind -eq [System.DateTimeKind]::Local) {
            $ExpiryDate = $ExpiryDate.ToUniversalTime()
        }

        $cookie.Expires = $ExpiryDate
    }
    elseif ($Duration -gt 0) {
        $cookie.Expires = [datetime]::UtcNow.AddSeconds($Duration)
    }

    # sets the cookie on the the response
    $WebEvent.PendingCookies[$cookie.Name] = $cookie
    Add-PodeHeader -Name 'Set-Cookie' -Value (ConvertTo-PodeCookieString -Cookie $cookie)
    return (ConvertTo-PodeCookie -Cookie $cookie)
}


<#
.SYNOPSIS
    Stores secrets that can be used to sign cookies.

.DESCRIPTION
    Stores secrets that can be used to sign cookies. A global secret can be set for easier retrieval.

.PARAMETER Name
    The name of the secret to store.

.PARAMETER Value
    The value of the secret to store.

.PARAMETER Global
    If flagged, the secret being stored will be set as the global secret.

.EXAMPLE
    Set-PodeCookieSecret -Name 'my-secret' -Value 'shhhh!'

.EXAMPLE
    Set-PodeCookieSecret -Value 'hunter2' -Global
#>
function Set-PodeCookieSecret {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'General')]
        [string]
        $Name,

        [Parameter(Mandatory = $true)]
        [string]
        $Value,

        [Parameter(ParameterSetName = 'Global')]
        [switch]
        $Global
    )

    if ($Global) {
        $Name = 'global'
    }

    $PodeContext.Server.Cookies.Secrets[$Name] = $Value
}


<#
.SYNOPSIS
    Tests if a cookie exists on the Request.

.DESCRIPTION
    Tests if a cookie exists on the Request.

.PARAMETER Name
    The name of the cookie to test for on the Request.

.EXAMPLE
    Test-PodeCookie -Name 'Views'
#>
function Test-PodeCookie {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    $cookie = $WebEvent.Cookies[$Name]
    return (($null -ne $cookie) -and ![string]::IsNullOrWhiteSpace($cookie.Value))
}


<#
.SYNOPSIS
    Tests if a cookie on the Request is validly signed.

.DESCRIPTION
    Tests if a cookie on the Request is validly signed, by attempting to unsign it using some secret.

.PARAMETER Name
    The name of the cookie to test.

.PARAMETER Secret
    A secret to use for attempting to unsign the cookie's value.

.PARAMETER Strict
    If supplied, the Secret will be extended using the client request's UserAgent and RemoteIPAddress.

.EXAMPLE
    Test-PodeCookieSigned -Name 'Views' -Secret 'hunter2'
#>
function Test-PodeCookieSigned {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [string]
        $Secret,

        [switch]
        $Strict
    )

    $cookie = $WebEvent.Cookies[$Name]
    if (($null -eq $cookie) -or [string]::IsNullOrEmpty($cookie.Value)) {
        return $false
    }

    return Test-PodeValueSigned -Value $cookie.Value -Secret $Secret -Strict:$Strict
}


<#
.SYNOPSIS
    Updates the exipry date of a cookie on the Response.

.DESCRIPTION
    Updates the exipry date of a cookie on the Response. This can either be done by suppling a duration, or and explicit expiry date.

.PARAMETER Name
    The name of the cookie to extend.

.PARAMETER Duration
    The duration, in seconds, to extend the cookie's expiry.

.PARAMETER ExpiryDate
    An explicit expiry date for the cookie.

.EXAMPLE
    Update-PodeCookieExpiry -Name  'Views' -Duration 1800

.EXAMPLE
    Update-PodeCookieExpiry -Name  'Views' -ExpiryDate ([datetime]::UtcNow.AddSeconds(1800))
#>
function Update-PodeCookieExpiry {
    [CmdletBinding(DefaultParameterSetName = 'Duration')]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(ParameterSetName = 'Duration')]
        [int]
        $Duration = 0,

        [Parameter(ParameterSetName = 'ExpiryDate')]
        [datetime]
        $ExpiryDate
    )

    # get the cookie from the response - if it's not found, get it from the request
    $cookie = $WebEvent.PendingCookies[$Name]
    if ($null -eq $cookie) {
        $cookie = Get-PodeCookie -Name $Name -Raw
    }

    # extends the expiry on the cookie
    if ($null -ne $ExpiryDate) {
        if ($ExpiryDate.Kind -eq [System.DateTimeKind]::Local) {
            $ExpiryDate = $ExpiryDate.ToUniversalTime()
        }

        $cookie.Expires = $ExpiryDate
    }
    elseif ($Duration -gt 0) {
        $cookie.Expires = [datetime]::UtcNow.AddSeconds($Duration)
    }

    $cookie.Path = '/'

    # sets the cookie on the the response
    $WebEvent.PendingCookies[$cookie.Name] = $cookie
    Add-PodeHeader -Name 'Set-Cookie' -Value (ConvertTo-PodeCookieString -Cookie $cookie)
    return (ConvertTo-PodeCookie -Cookie $cookie)
}


<#
.SYNOPSIS
    Closes the Pode server.

.DESCRIPTION
    Closes the Pode server.

.EXAMPLE
    Close-PodeServer
#>
function Close-PodeServer {
    [CmdletBinding()]
    param()

    Close-PodeCancellationTokenRequest -Type Cancellation, Terminate
}


<#
.SYNOPSIS
    Blocks new incoming requests by adding middleware that returns a 503 Service Unavailable status when the Pode Watchdog client is active.

.DESCRIPTION
    This function integrates middleware into the Pode server, preventing new incoming requests while the Pode Watchdog client is active.
    All requests receive a 503 Service Unavailable response, including a 'Retry-After' header that specifies when the service will become available.

.PARAMETER RetryAfter
    Specifies the time in seconds clients should wait before retrying their requests. Default is 3600 seconds (1 hour).
#>
function Disable-PodeServer {
    param (
        [Parameter(Mandatory = $false)]
        [int]$RetryAfter = 3600
    )

    $PodeContext.Server.AllowedActions.DisableSettings.RetryAfter = $RetryAfter
    if (! (Test-PodeCancellationTokenRequest -Type Disable)) {
        Close-PodeCancellationTokenRequest -Type Disable
    }
}


<#
.SYNOPSIS
    Enables new incoming requests by removing the middleware that blocks requests when the Pode Watchdog client is active.

.DESCRIPTION
    This function resets the cancellation token for the Disable action, allowing the Pode server to accept new incoming requests.
#>
function Enable-PodeServer {
    if (Test-PodeCancellationTokenRequest -Type Disable) {
        Reset-PodeCancellationToken -Type Disable
    }
}


<#
.SYNOPSIS
    Retrieves the path of a specified default folder type from the Pode server context.

.DESCRIPTION
    This function returns the path for one of the Pode server's default folder types: Views, Public, or Errors. It accesses the server's configuration stored in the `$PodeContext` variable and retrieves the path for the specified folder type from the `DefaultFolders` dictionary. This function is useful for scripts or modules that need to dynamically access server resources based on the server's current configuration.

.PARAMETER Type
    The type of the default folder for which to retrieve the path. The valid options are 'Views', 'Public', or 'Errors'. This parameter determines which folder's path will be returned by the function.

.EXAMPLE
    $path = Get-PodeDefaultFolder -Type 'Views'

    This example retrieves the current path configured for the server's 'Views' folder and stores it in the `$path` variable.

.EXAMPLE
    $path = Get-PodeDefaultFolder -Type 'Public'

    This example retrieves the current path configured for the server's 'Public' folder.

.OUTPUTS
    String. The file system path of the specified default folder.
#>
function Get-PodeDefaultFolder {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter()]
        [ValidateSet('Views', 'Public', 'Errors')]
        [string]
        $Type
    )

    return $PodeContext.Server.DefaultFolders[$Type]
}


<#
.SYNOPSIS
    A default server secret that can be for signing values like Session, Cookies, or SSE IDs.

.DESCRIPTION
    A default server secret that can be for signing values like Session, Cookies, or SSE IDs. This secret is regenerated
    on every server start and restart.

.EXAMPLE
    $secret = Get-PodeServerDefaultSecret
#>
function Get-PodeServerDefaultSecret {
    [CmdletBinding()]
    param()

    return $PodeContext.Server.DefaultSecret
}


<#
.SYNOPSIS
    Retrieves the current state of the Pode server.

.DESCRIPTION
    The Get-PodeServerState function evaluates the internal state of the Pode server based on the cancellation tokens available
    in the $PodeContext. The function determines if the server is running, terminating, restarting, suspending, resuming, or
    in any other predefined state.

.OUTPUTS
    [string] - The state of the Pode server as one of the following values:
    'Terminated', 'Terminating', 'Resuming', 'Suspending', 'Suspended', 'Restarting', 'Starting', 'Running'.

.EXAMPLE
    Get-PodeServerState

    Retrieves the current state of the Pode server and returns it as a string.
#>
function Get-PodeServerState {
    [CmdletBinding()]
    [OutputType([Pode.PodeServerState])]
    param()
    # Check if PodeContext or its Tokens property is null; if so, consider the server terminated
    if ($null -eq $PodeContext -or $null -eq $PodeContext.Tokens) {
        return [Pode.PodeServerState]::Terminated
    }

    # Check if the server is in the process of terminating
    if (Test-PodeCancellationTokenRequest -Type Terminate) {
        return [Pode.PodeServerState]::Terminating
    }

    # Check if the server is resuming from a suspended state
    if (Test-PodeCancellationTokenRequest -Type Resume) {
        return [Pode.PodeServerState]::Resuming
    }

    # Check if the server is in the process of restarting
    if (Test-PodeCancellationTokenRequest -Type Restart) {
        return [Pode.PodeServerState]::Restarting
    }

    # Check if the server is suspending or already suspended
    if (Test-PodeCancellationTokenRequest -Type Suspend) {
        if (Test-PodeCancellationTokenRequest -Type Cancellation) {
            return [Pode.PodeServerState]::Suspending
        }
        return [Pode.PodeServerState]::Suspended
    }

    # Check if the server is starting
    if (!(Test-PodeCancellationTokenRequest -Type Start)) {
        return [Pode.PodeServerState]::Starting
    }

    # If none of the above, assume the server is running
    return [Pode.PodeServerState]::Running
}


<#
.SYNOPSIS
    The CLI for Pode, to initialise, build and start your Server.

.DESCRIPTION
    The CLI for Pode, to initialise, build and start your Server.

.PARAMETER Action
    The action to invoke on your Server.

.PARAMETER Dev
    Supply when running "pode install", this will install any dev packages defined in your package.json.

.EXAMPLE
    pode install -dev

.EXAMPLE
    pode build

.EXAMPLE
    pode start
#>
function Pode {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('init', 'test', 'start', 'install', 'build')]
        [Alias('a')]
        [string]
        $Action,

        [switch]
        [Alias('d')]
        $Dev
    )

    # default config file name and content
    $file = './package.json'
    $name = Split-Path -Leaf -Path $pwd
    $data = $null

    # default config data that's used to populate on init
    $map = @{
        'name'        = $name
        'version'     = '1.0.0'
        'description' = ''
        'main'        = './server.ps1'
        'scripts'     = @{
            'start'   = './server.ps1'
            'install' = 'yarn install --force --ignore-scripts --modules-folder pode_modules'
            'build'   = 'psake'
            'test'    = 'invoke-pester ./tests/*.ps1'
        }
        'author'      = ''
        'license'     = 'MIT'
    }

    # check and load config if already exists
    if (Test-Path $file) {
        $data = (Get-Content $file | ConvertFrom-Json)
    }

    # quick check to see if the data is required
    if ($Action -ine 'init') {
        if ($null -eq $data) {
            Write-PodeHost 'package.json file not found' -ForegroundColor Red
            return
        }
        else {
            $actionScript = $data.scripts.$Action

            if ([string]::IsNullOrWhiteSpace($actionScript) -and $Action -ieq 'start') {
                $actionScript = $data.main
            }

            if ([string]::IsNullOrWhiteSpace($actionScript) -and $Action -ine 'install') {
                Write-PodeHost "package.json does not contain a script for the $($Action) action" -ForegroundColor Yellow
                return
            }
        }
    }
    else {
        if ($null -ne $data) {
            Write-PodeHost 'package.json already exists' -ForegroundColor Yellow
            return
        }
    }

    switch ($Action.ToLowerInvariant()) {
        'init' {
            $v = Read-Host -Prompt "name ($($map.name))"
            if (![string]::IsNullOrWhiteSpace($v)) { $map.name = $v }

            $v = Read-Host -Prompt "version ($($map.version))"
            if (![string]::IsNullOrWhiteSpace($v)) { $map.version = $v }

            $map.description = Read-Host -Prompt 'description'

            $v = Read-Host -Prompt "entry point ($($map.main))"
            if (![string]::IsNullOrWhiteSpace($v)) { $map.main = $v; $map.scripts.start = $v }

            $map.author = Read-Host -Prompt 'author'

            $v = Read-Host -Prompt "license ($($map.license))"
            if (![string]::IsNullOrWhiteSpace($v)) { $map.license = $v }

            $map | ConvertTo-Json -Depth 10 | Out-File -FilePath $file -Encoding utf8 -Force
            Write-PodeHost 'Success, saved package.json' -ForegroundColor Green
        }

        'test' {
            Invoke-PodePackageScript -ActionScript $actionScript
        }

        'start' {
            Invoke-PodePackageScript -ActionScript $actionScript
        }

        'install' {
            if ($Dev) {
                Install-PodeLocalModule -Module $data.devModules
            }

            Install-PodeLocalModule -Module $data.modules
            Invoke-PodePackageScript -ActionScript $actionScript
        }

        'build' {
            Invoke-PodePackageScript -ActionScript $actionScript
        }
    }
}


<#
.SYNOPSIS
    Restarts the Pode server.

.DESCRIPTION
    Restarts the Pode server.

.EXAMPLE
    Restart-PodeServer
#>
function Restart-PodeServer {
    [CmdletBinding()]
    param()

    # Only if the Restart feature is anabled
    if ($PodeContext.Server.AllowedActions.Restart) {
        Close-PodeCancellationTokenRequest -Type Restart
    }
}


<#
.SYNOPSIS
    Resumes the Pode server from a suspended state.

.DESCRIPTION
    This function resumes the Pode server, ensuring all associated runspaces are restored to their normal execution state.
    It triggers the 'Resume' event, updates the server's suspended status, and clears the host for a refreshed console view.

.PARAMETER Timeout
    The maximum time, in seconds, to wait for each runspace to be recovered before timing out. Default is 30 seconds.

.EXAMPLE
    Resume-PodeServer
    # Resumes the Pode server after a suspension.

#>
function Resume-PodeServer {
    [CmdletBinding()]
    param(
        [int]
        $Timeout
    )
    # Only if the Suspend feature is anabled
    if ($PodeContext.Server.AllowedActions.Suspend) {
        if ($Timeout) {
            $PodeContext.Server.AllowedActions.Timeout.Resume = $Timeout
        }

        if ((Test-PodeServerState -State Suspended)) {
            Set-PodeResumeToken
        }
    }
}


<#
.SYNOPSIS
    Sets the path for a specified default folder type in the Pode server context.

.DESCRIPTION
    This function configures the path for one of the Pode server's default folder types: Views, Public, or Errors.
    It updates the server's configuration to reflect the new path for the specified folder type.
    The function first checks if the provided path exists and is a directory;
    if so, it updates the `Server.DefaultFolders` dictionary with the new path.
    If the path does not exist or is not a directory, the function throws an error.

    The purpose of this function is to allow dynamic configuration of the server's folder paths, which can be useful during server setup or when altering the server's directory structure at runtime.

.PARAMETER Type
    The type of the default folder to set the path for. Must be one of 'Views', 'Public', or 'Errors'.
    This parameter determines which default folder's path is being set.

.PARAMETER Path
    The new file system path for the specified default folder type. This path must exist and be a directory; otherwise, an exception is thrown.

.EXAMPLE
    Set-PodeDefaultFolder -Type 'Views' -Path 'C:\Pode\Views'

    This example sets the path for the server's default 'Views' folder to 'C:\Pode\Views', assuming this path exists and is a directory.

.EXAMPLE
    Set-PodeDefaultFolder -Type 'Public' -Path 'C:\Pode\Public'

    This example sets the path for the server's default 'Public' folder to 'C:\Pode\Public'.

#>
function Set-PodeDefaultFolder {

    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateSet('Views', 'Public', 'Errors')]
        [string]
        $Type,

        [Parameter()]
        [string]
        $Path
    )
    if (Test-Path -Path $Path -PathType Container) {
        $PodeContext.Server.DefaultFolders[$Type] = $Path
    }
    else {
        # Path does not exist
        throw ($PodeLocale.pathNotExistExceptionMessage -f $Path)
    }
}


<#
.SYNOPSIS
    Opens a Web Server up as a Desktop Application.

.DESCRIPTION
    Opens a Web Server up as a Desktop Application.

.PARAMETER Title
    The title of the Application's window.

.PARAMETER Icon
    A path to an icon image for the Application.

.PARAMETER WindowState
    The state the Application's window starts, such as Minimized.

.PARAMETER WindowStyle
    The border style of the Application's window.

.PARAMETER ResizeMode
    Specifies if the Application's window is resizable.

.PARAMETER Height
    The height of the window.

.PARAMETER Width
    The width of the window.

.PARAMETER EndpointName
    The specific endpoint name to use, if you are listening on multiple endpoints.

.PARAMETER HideFromTaskbar
    Stops the Application from appearing on the taskbar.

.EXAMPLE
    Show-PodeGui -Title 'MyApplication' -WindowState 'Maximized'
#>
function Show-PodeGui {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]
        $Title,

        [Parameter()]
        [string]
        $Icon,

        [Parameter()]
        [ValidateSet('Normal', 'Maximized', 'Minimized')]
        [string]
        $WindowState = 'Normal',

        [Parameter()]
        [ValidateSet('None', 'SingleBorderWindow', 'ThreeDBorderWindow', 'ToolWindow')]
        [string]
        $WindowStyle = 'SingleBorderWindow',

        [Parameter()]
        [ValidateSet('CanResize', 'CanMinimize', 'NoResize')]
        [string]
        $ResizeMode = 'CanResize',

        [Parameter()]
        [int]
        $Height = 0,

        [Parameter()]
        [int]
        $Width = 0,

        [Parameter()]
        [string]
        $EndpointName,

        [switch]
        $HideFromTaskbar
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
        # error if serverless
        Test-PodeIsServerless -FunctionName 'Show-PodeGui' -ThrowError

        # only valid for Windows PowerShell
        if ((Test-PodeIsPSCore) -and ($PSVersionTable.PSVersion.Major -eq 6)) {
            # Show-PodeGui is currently only available for Windows PowerShell and PowerShell 7+ on Windows
            throw ($PodeLocale.showPodeGuiOnlyAvailableOnWindowsExceptionMessage)
        }

        # enable the gui and set general settings
        $PodeContext.Server.Gui.Enabled = $true
        $PodeContext.Server.Gui.Title = $Title
        $PodeContext.Server.Gui.ShowInTaskbar = !$HideFromTaskbar
        $PodeContext.Server.Gui.WindowState = $WindowState
        $PodeContext.Server.Gui.WindowStyle = $WindowStyle
        $PodeContext.Server.Gui.ResizeMode = $ResizeMode

        # set the window's icon path
        if (![string]::IsNullOrWhiteSpace($Icon)) {
            $PodeContext.Server.Gui.Icon = Get-PodeRelativePath -Path $Icon -JoinRoot -Resolve
            if (!(Test-Path $PodeContext.Server.Gui.Icon)) {
                # Path to icon for GUI does not exist
                throw ($PodeLocale.pathToIconForGuiDoesNotExistExceptionMessage -f $PodeContext.Server.Gui.Icon)
            }
        }

        # set the height of the window
        $PodeContext.Server.Gui.Height = $Height
        if ($PodeContext.Server.Gui.Height -le 0) {
            $PodeContext.Server.Gui.Height = 'auto'
        }

        # set the width of the window
        $PodeContext.Server.Gui.Width = $Width
        if ($PodeContext.Server.Gui.Width -le 0) {
            $PodeContext.Server.Gui.Width = 'auto'
        }

        # set the gui to use a specific listener
        $PodeContext.Server.Gui.EndpointName = $EndpointName

        if (![string]::IsNullOrWhiteSpace($EndpointName)) {
            if (!$PodeContext.Server.Endpoints.ContainsKey($EndpointName)) {
                # Endpoint with name '$EndpointName' does not exist.
                throw ($PodeLocale.endpointNameNotExistExceptionMessage -f $EndpointName)
            }

            $PodeContext.Server.Gui.Endpoint = $PodeContext.Server.Endpoints[$EndpointName]
        }
    }
}


<#
.SYNOPSIS
    Starts a Pode server with the supplied script block or file containing the server logic.

.DESCRIPTION
    This function initializes and starts a Pode server based on the provided configuration.
    It supports both inline script blocks and external files for defining server logic.
    The server's behavior, console output, and various features can be customized using parameters.
    Additionally, it manages server termination, cancellation, and cleanup processes.

.PARAMETER ScriptBlock
    The main logic for the server, provided as a script block.

.PARAMETER FilePath
    A literal or relative path to a file containing the server's logic.
    The directory of this file will be used as the server's root path unless a specific -RootPath is supplied.

.PARAMETER Interval
    Specifies the interval in seconds for invoking the script block in 'Service' type servers.

.PARAMETER Name
    An optional name for the server, useful for identification in logs and future extensions.

.PARAMETER Threads
    The number of threads to allocate for Web, SMTP, and TCP servers. Defaults to 1.

.PARAMETER RootPath
    Overrides the server's root path. If not provided, the root path will be derived from the file path or the current working directory.

.PARAMETER Request
    Provides request details for serverless environments that Pode can parse and use.

.PARAMETER ServerlessType
    Specifies the serverless type for Pode. Valid values are:
    - AzureFunctions
    - AwsLambda

.PARAMETER StatusPageExceptions
    Controls the visibility of stack traces on status pages. Valid values are:
    - Show
    - Hide

.PARAMETER ListenerType
    Specifies a custom socket listener. Defaults to Pode's inbuilt listener.

.PARAMETER EnablePool
    Configures specific runspace pools (e.g., Timers, Schedules, Tasks, WebSockets, Files) for ad-hoc usage.

.PARAMETER Browse
    Opens the default web endpoint in the browser upon server start.

.PARAMETER CurrentPath
    Sets the server's root path to the current working directory. Only applicable when -FilePath is used.

.PARAMETER EnableBreakpoints
    Enables breakpoints created using `Wait-PodeDebugger`.

.PARAMETER DisableTermination
    Prevents termination, suspension, or resumption of the server via console commands.

.PARAMETER DisableConsoleInput
    Disables all console interactions for the server.

.PARAMETER ClearHost
    Clears the console screen whenever the server state changes (e.g., running → suspend → resume).

.PARAMETER Quiet
    Suppresses all output from the server.

.PARAMETER HideOpenAPI
    Hides OpenAPI details such as specification and documentation URLs from the console output.

.PARAMETER HideEndpoints
    Hides the list of active endpoints from the console output.

.PARAMETER ShowHelp
    Displays a help menu in the console with available control commands.

.PARAMETER IgnoreServerConfig
    Prevents the server from loading settings from the server.psd1 configuration file.

.PARAMETER ConfigFile
    Specifies a custom configuration file instead of using the default `server.psd1`.

.PARAMETER Daemon
    Configures the server to run as a daemon with minimal console interaction and output.

.EXAMPLE
    Start-PodeServer { /* server logic */ }
    Starts a Pode server using the supplied script block.

.EXAMPLE
    Start-PodeServer -FilePath './server.ps1' -Browse
    Starts a Pode server using the logic defined in an external file and opens the default endpoint in the browser.

.EXAMPLE
    Start-PodeServer -ServerlessType AwsLambda -Request $LambdaInput { /* server logic */ }
    Starts a Pode server in a serverless environment, using AWS Lambda input.

.EXAMPLE
    Start-PodeServer -HideOpenAPI -ClearHost { /* server logic */ }
    Starts a Pode server with console output configured to hide OpenAPI details and clear the console on state changes.

.NOTES
    This function is part of the Pode framework and is responsible for server initialization, configuration,
    request handling, and cleanup. It supports both standalone and serverless deployments, and provides
    extensive customization options for developers.
#>
function Start-PodeServer {
    [CmdletBinding(DefaultParameterSetName = 'Script')]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0, ParameterSetName = 'Script')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ScriptDaemon')]
        [scriptblock]
        $ScriptBlock,

        [Parameter(Mandatory = $true, ParameterSetName = 'File')]
        [Parameter(Mandatory = $true, ParameterSetName = 'FileDaemon')]
        [string]
        $FilePath,

        [Parameter()]
        [int]
        $Interval = 0,

        [Parameter()]
        [string]
        $Name,

        [Parameter()]
        [int]
        $Threads = 1,

        [Parameter()]
        [string]
        $RootPath,

        [Parameter()]
        $Request,

        [Parameter()]
        [ValidateSet('', 'AzureFunctions', 'AwsLambda')]
        [string]
        $ServerlessType = [string]::Empty,

        [Parameter()]
        [ValidateSet('', 'Hide', 'Show')]
        [string]
        $StatusPageExceptions = [string]::Empty,

        [Parameter()]
        [string]
        $ListenerType = [string]::Empty,

        [Parameter()]
        [ValidateSet('Timers', 'Schedules', 'Tasks', 'WebSockets', 'Files')]
        [string[]]
        $EnablePool,

        [Parameter(ParameterSetName = 'File')]
        [Parameter(ParameterSetName = 'Script')]
        [switch]
        $Browse,

        [Parameter(Mandatory = $true, ParameterSetName = 'FileDaemon')]
        [Parameter(ParameterSetName = 'File')]
        [switch]
        $CurrentPath,

        [Parameter(ParameterSetName = 'File')]
        [Parameter(ParameterSetName = 'Script')]
        [switch]
        $EnableBreakpoints,

        [Parameter(ParameterSetName = 'File')]
        [Parameter(ParameterSetName = 'Script')]
        [switch]
        $DisableTermination,

        [Parameter(ParameterSetName = 'File')]
        [Parameter(ParameterSetName = 'Script')]
        [switch]
        $Quiet,

        [Parameter(ParameterSetName = 'File')]
        [Parameter(ParameterSetName = 'Script')]
        [switch]
        $DisableConsoleInput,

        [switch]
        $ClearHost,

        [switch]
        $HideOpenAPI,

        [switch]
        $HideEndpoints,

        [switch]
        $ShowHelp,

        [switch]
        $IgnoreServerConfig,

        [string]
        $ConfigFile,

        [Parameter(Mandatory = $true, ParameterSetName = 'FileDaemon')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ScriptDaemon')]
        [switch]
        $Daemon
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
        }    # Store the name of the current runspace
        $previousRunspaceName = Get-PodeCurrentRunspaceName
        # Sets the name of the current runspace
        Set-PodeCurrentRunspaceName -Name 'PodeServer'

        # ensure the session is clean
        $Script:PodeContext = $null
        $ShowDoneMessage = $true

        try {
            # if we have a filepath, resolve it - and extract a root path from it
            if ($PSCmdlet.ParameterSetName -ieq 'file') {
                $FilePath = Get-PodeRelativePath -Path $FilePath -Resolve -TestPath -JoinRoot -RootPath $MyInvocation.PSScriptRoot

                # if not already supplied, set root path
                if ([string]::IsNullOrWhiteSpace($RootPath)) {
                    if ($CurrentPath) {
                        $RootPath = $PWD.Path
                    }
                    else {
                        $RootPath = Split-Path -Parent -Path $FilePath
                    }
                }
            }

            # configure the server's root path
            if (!(Test-PodeIsEmpty $RootPath)) {
                $RootPath = Get-PodeRelativePath -Path $RootPath -RootPath $MyInvocation.PSScriptRoot -JoinRoot -Resolve -TestPath
            }


            # Define parameters for the context creation
            $ContextParams = @{
                ScriptBlock          = $ScriptBlock
                FilePath             = $FilePath
                Threads              = $Threads
                Interval             = $Interval
                ServerRoot           = Protect-PodeValue -Value $RootPath -Default $MyInvocation.PSScriptRoot
                ServerlessType       = $ServerlessType
                ListenerType         = $ListenerType
                EnablePool           = $EnablePool
                StatusPageExceptions = $StatusPageExceptions
                Console              = Get-PodeDefaultConsole
                EnableBreakpoints    = $EnableBreakpoints
                IgnoreServerConfig   = $IgnoreServerConfig
                ConfigFile           = $ConfigFile
            }


            # Create main context object
            $PodeContext = New-PodeContext @ContextParams

            # Define parameter values with comments explaining each one
            $ConfigParameters = @{
                DisableTermination  = $DisableTermination   # Disable termination of the Pode server from the console
                DisableConsoleInput = $DisableConsoleInput  # Disable input from the console for the Pode server
                Quiet               = $Quiet                # Enable quiet mode, suppressing console output
                ClearHost           = $ClearHost            # Clear the host on startup
                HideOpenAPI         = $HideOpenAPI          # Hide the OpenAPI documentation display
                HideEndpoints       = $HideEndpoints        # Hide the endpoints list display
                ShowHelp            = $ShowHelp             # Show help information in the console
                Daemon              = $Daemon               # Enable daemon mode, combining multiple configurations
            }

            # Call the function using splatting
            Set-PodeConsoleOverrideConfiguration @ConfigParameters

            # start the file monitor for interally restarting
            Start-PodeFileMonitor

            # start the server
            Start-PodeInternalServer -Request $Request -Browse:$Browse

            # at this point, if it's just a one-one off script, return
            if (!(Test-PodeServerKeepOpen)) {
                return
            }

            # Sit in a loop waiting for server termination/cancellation or a restart request.
            while (!(Test-PodeCancellationTokenRequest -Type Terminate)) {

                # If console input is not disabled, invoke any actions based on console commands.
                if (!$PodeContext.Server.Console.DisableConsoleInput) {
                    Invoke-PodeConsoleAction
                }

                # Resolve cancellation token requests (e.g., Restart, Enable/Disable, Suspend/Resume).
                Resolve-PodeCancellationToken

                # Pause for 1 second before re-checking the state and processing the next action.
                Start-Sleep -Seconds 1
            }

            if ($PodeContext.Server.IsIIS -and $PodeContext.Server.IIS.Shutdown) {
                # (IIS Shutdown)
                Write-PodeHost $PodeLocale.iisShutdownMessage -NoNewLine -ForegroundColor Yellow
                Write-PodeHost ' ' -NoNewLine
            }

            # Terminating...
            Invoke-PodeEvent -Type Terminate
            Close-PodeServer
            Show-PodeConsoleInfo
        }
        catch {
            $_ | Write-PodeErrorLog

            Invoke-PodeEvent -Type Crash
            $ShowDoneMessage = $false
            throw
        }
        finally {
            Invoke-PodeEvent -Type Stop

            # set output values
            Set-PodeOutputVariable

            # unregister secret vaults
            Unregister-PodeSecretVaultsInternal

            # clean the runspaces and tokens
            Close-PodeServerInternal

            Show-PodeConsoleInfo

            # Restore the name of the current runspace
            Set-PodeCurrentRunspaceName -Name $previousRunspaceName

            if (($ShowDoneMessage -and ($PodeContext.Server.Types.Length -gt 0) -and !$PodeContext.Server.IsServerless)) {
                Write-PodeHost $PodeLocale.doneMessage -ForegroundColor Green
            }

            # clean the session
            $PodeContext = $null
            $PodeLocale = $null
        }
    }
}


<#
.SYNOPSIS
    Helper wrapper function to start a Pode web server for a static website at the current directory.

.DESCRIPTION
    Helper wrapper function to start a Pode web server for a static website at the current directory.

.PARAMETER Threads
    The numbers of threads to use for requests.

.PARAMETER RootPath
    An override for the Server's root path.

.PARAMETER Address
    The IP/Hostname of the endpoint.

.PARAMETER Port
    The Port number of the endpoint.

.PARAMETER Https
    Start the server using HTTPS, if no certificate details are supplied a self-signed certificate will be generated.

.PARAMETER Certificate
    The path to a certificate that can be use to enable HTTPS.

.PARAMETER CertificatePassword
    The password for the certificate referenced in CertificateFile.

.PARAMETER CertificateKey
    A key file to be paired with a PEM certificate referenced in CertificateFile

.PARAMETER X509Certificate
    The raw X509 certificate that can be use to enable HTTPS.

.PARAMETER Path
    The URI path for the static Route.

.PARAMETER Defaults
    An array of default pages to display, such as 'index.html'.

.PARAMETER DownloadOnly
    When supplied, all static content on this Route will be attached as downloads - rather than rendered.

.PARAMETER FileBrowser
    When supplied, If the path is a folder, instead of returning 404, will return A browsable content of the directory.

.PARAMETER Browse
    Open the web server's default endpoint in your default browser.

.EXAMPLE
    Start-PodeStaticServer

.EXAMPLE
    Start-PodeStaticServer -Address '127.0.0.3' -Port 8000

.EXAMPLE
    Start-PodeStaticServer -Path '/installers' -DownloadOnly
#>
function Start-PodeStaticServer {
    [CmdletBinding()]
    param(
        [Parameter()]
        [int]
        $Threads = 3,

        [Parameter()]
        [string]
        $RootPath = $PWD,

        [Parameter()]
        [string]
        $Address = 'localhost',

        [Parameter()]
        [int]
        $Port = 0,

        [Parameter()]
        [switch]
        $Https,

        [Parameter()]
        [string]
        $Certificate = $null,

        [Parameter()]
        [string]
        $CertificatePassword = $null,

        [Parameter()]
        [string]
        $CertificateKey = $null,

        [Parameter()]
        [X509Certificate]
        $X509Certificate = $null,

        [Parameter()]
        [string]
        $Path = '/',

        [Parameter()]
        [string[]]
        $Defaults,

        [switch]
        $DownloadOnly,

        [switch]
        $FileBrowser,

        [switch]
        $Browse
    )

    Start-PodeServer -RootPath $RootPath -Threads $Threads -Browse:$Browse -ScriptBlock {
        # add either an http or https endpoint
        if ($Https) {
            if ($null -ne $X509Certificate) {
                Add-PodeEndpoint -Address $Address -Port $Port -Protocol Https -X509Certificate $X509Certificate
            }
            elseif (![string]::IsNullOrWhiteSpace($Certificate)) {
                Add-PodeEndpoint -Address $Address -Port $Port -Protocol Https -Certificate $Certificate -CertificatePassword $CertificatePassword -CertificateKey $CertificateKey
            }
            else {
                Add-PodeEndpoint -Address $Address -Port $Port -Protocol Https -SelfSigned
            }
        }
        else {
            Add-PodeEndpoint -Address $Address -Port $Port -Protocol Http
        }

        # add the static route
        Add-PodeStaticRoute -Path $Path -Source (Get-PodeServerPath) -Defaults $Defaults -DownloadOnly:$DownloadOnly -FileBrowser:$FileBrowser
    }
}


<#
.SYNOPSIS
    Suspends the Pode server and its runspaces.

.DESCRIPTION
    This function suspends the Pode server by pausing all associated runspaces and ensuring they enter a debug state.
    It triggers the 'Suspend' event, updates the server's suspended status, and provides feedback during the suspension process.

.PARAMETER Timeout
    The maximum time, in seconds, to wait for each runspace to be suspended before timing out. Default is 30 seconds.

.EXAMPLE
    Suspend-PodeServer
    # Suspends the Pode server with a timeout of 60 seconds.

#>
function Suspend-PodeServer {
    [CmdletBinding()]
    param(
        [int]
        $Timeout
    )
    # Only if the Suspend feature is anabled
    if ($PodeContext.Server.AllowedActions.Suspend) {
        if ($Timeout) {
            $PodeContext.Server.AllowedActions.Timeout.Suspend = $Timeout
        }
        if (!(Test-PodeServerState -State Suspended)) {
            Set-PodeSuspendToken
        }
    }
}


<#
.SYNOPSIS
    Tests whether the Pode server is in a specified state.

.DESCRIPTION
    The `Test-PodeServerState` function checks the current state of the Pode server
    by calling `Get-PodeServerState` and comparing the result to the specified state.
    The function returns `$true` if the server is in the specified state and `$false` otherwise.

.PARAMETER State
    Specifies the server state to test. Allowed values are:
    - `Terminated`: The server is not running, and the context is null.
    - `Terminating`: The server is in the process of shutting down.
    - `Resuming`: The server is resuming from a suspended state.
    - `Suspending`: The server is in the process of entering a suspended state.
    - `Suspended`: The server is fully suspended.
    - `Restarting`: The server is restarting.
    - `Starting`: The server is in the process of starting up.
    - `Running`: The server is actively running.

.EXAMPLE
    Test-PodeServerState -State 'Running'

    Returns `$true` if the server is currently running, otherwise `$false`.

.EXAMPLE
    Test-PodeServerState -State 'Suspended'

    Returns `$true` if the server is fully suspended, otherwise `$false`.

.NOTES
    This function is part of Pode's server state management utilities.
    It relies on the `Get-PodeServerState` function to determine the current state.
#>
function Test-PodeServerState {
    param(
        [Parameter(Mandatory = $true)]
        [Pode.PodeServerState]
        $State
    )

    # Call Get-PodeServerState to retrieve the current server state
    $currentState = Get-PodeServerState

    # Return true if the current state matches the provided state, otherwise false
    return $currentState -eq $State
}


<#
.SYNOPSIS
    Attaches a breakpoint which can be used for debugging.

.DESCRIPTION
    Attaches a breakpoint which can be used for debugging.

.EXAMPLE
    Wait-PodeDebugger
#>
function Wait-PodeDebugger {
    [CmdletBinding()]
    param()

    if (!$PodeContext.Server.Debug.Breakpoints.Enabled) {
        return
    }

    Wait-Debugger
}


<#
.SYNOPSIS
    Bind an endpoint to listen for incoming Requests.

.DESCRIPTION
    Bind an endpoint to listen for incoming Requests. The endpoints can be HTTP, HTTPS, TCP or SMTP, with the option to bind certificates.

.PARAMETER Address
    The IP/Hostname of the endpoint (Default: localhost).

.PARAMETER Port
    The Port number of the endpoint.

.PARAMETER Hostname
    An optional hostname for the endpoint, specifying a hostname restricts access to just the hostname.

.PARAMETER Protocol
    The protocol of the supplied endpoint.

.PARAMETER Certificate
    The path to a certificate that can be use to enable HTTPS

.PARAMETER CertificatePassword
    The password for the certificate file referenced in Certificate

.PARAMETER CertificateKey
    A key file to be paired with a PEM certificate file referenced in Certificate

.PARAMETER CertificateThumbprint
    A certificate thumbprint to bind onto HTTPS endpoints (Windows).

.PARAMETER CertificateName
    A certificate subject name to bind onto HTTPS endpoints (Windows).

.PARAMETER CertificateStoreName
    The name of a certifcate store where a certificate can be found (Default: My) (Windows).

.PARAMETER CertificateStoreLocation
    The location of a certifcate store where a certificate can be found (Default: CurrentUser) (Windows).

.PARAMETER X509Certificate
    The raw X509 certificate that can be use to enable HTTPS

.PARAMETER TlsMode
    The TLS mode to use on secure connections, options are Implicit or Explicit (SMTP only) (Default: Implicit).

.PARAMETER Name
    An optional name for the endpoint, that can be used with other functions (Default: GUID).

.PARAMETER RedirectTo
    The Name of another Endpoint to automatically generate a redirect route for all traffic.

.PARAMETER Description
    A quick description of the Endpoint - normally used in OpenAPI.

.PARAMETER Acknowledge
    An optional Acknowledge message to send to clients when they first connect, for TCP and SMTP endpoints only.

.PARAMETER SslProtocol
    One or more optional SSL Protocols this endpoints supports. (Default: SSL3/TLS12 - Just TLS12 on MacOS).

.PARAMETER CRLFMessageEnd
    If supplied, TCP endpoints will expect incoming data to end with CRLF.

.PARAMETER Force
    Ignore Adminstrator checks for non-localhost endpoints.

.PARAMETER SelfSigned
    Create and bind a self-signed certifcate for HTTPS endpoints.

.PARAMETER AllowClientCertificate
    Allow for client certificates to be sent on requests.

.PARAMETER PassThru
    If supplied, the endpoint created will be returned.

.PARAMETER LookupHostname
    If supplied, a supplied Hostname will have its IP Address looked up from host file or DNS.

.PARAMETER DualMode
    If supplied, this endpoint will listen on both the IPv4 and IPv6 versions of the supplied -Address.
    For IPv6, this will only work if the IPv6 address can convert to a valid IPv4 address.

.PARAMETER Default
    If supplied, this endpoint will be the default one used for internally generating URLs.

.EXAMPLE
    Add-PodeEndpoint -Address localhost -Port 8090 -Protocol Http

.EXAMPLE
    Add-PodeEndpoint -Address localhost -Protocol Smtp

.EXAMPLE
    Add-PodeEndpoint -Address dev.pode.com -Port 8443 -Protocol Https -SelfSigned

.EXAMPLE
    Add-PodeEndpoint -Address 127.0.0.2 -Hostname dev.pode.com -Port 8443 -Protocol Https -SelfSigned

.EXAMPLE
    Add-PodeEndpoint -Address live.pode.com -Protocol Https -CertificateThumbprint '2A9467F7D3940243D6C07DE61E7FCCE292'
#>
function Add-PodeEndpoint {
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    [OutputType([hashtable])]
    param(
        [Parameter()]
        [string]
        $Address = 'localhost',

        [Parameter()]
        [int]
        $Port = 0,

        [Parameter()]
        [string]
        $Hostname,

        [Parameter()]
        [ValidateSet('Http', 'Https', 'Smtp', 'Smtps', 'Tcp', 'Tcps', 'Ws', 'Wss')]
        [string]
        $Protocol,

        [Parameter(Mandatory = $true, ParameterSetName = 'CertFile')]
        [string]
        $Certificate = $null,

        [Parameter(ParameterSetName = 'CertFile')]
        [string]
        $CertificatePassword = $null,

        [Parameter(ParameterSetName = 'CertFile')]
        [string]
        $CertificateKey = $null,

        [Parameter(Mandatory = $true, ParameterSetName = 'CertThumb')]
        [string]
        $CertificateThumbprint,

        [Parameter(Mandatory = $true, ParameterSetName = 'CertName')]
        [string]
        $CertificateName,

        [Parameter(ParameterSetName = 'CertName')]
        [Parameter(ParameterSetName = 'CertThumb')]
        [System.Security.Cryptography.X509Certificates.StoreName]
        $CertificateStoreName = 'My',

        [Parameter(ParameterSetName = 'CertName')]
        [Parameter(ParameterSetName = 'CertThumb')]
        [System.Security.Cryptography.X509Certificates.StoreLocation]
        $CertificateStoreLocation = 'CurrentUser',

        [Parameter(Mandatory = $true, ParameterSetName = 'CertRaw')]
        [X509Certificate]
        $X509Certificate = $null,

        [Parameter(ParameterSetName = 'CertFile')]
        [Parameter(ParameterSetName = 'CertThumb')]
        [Parameter(ParameterSetName = 'CertName')]
        [Parameter(ParameterSetName = 'CertRaw')]
        [Parameter(ParameterSetName = 'CertSelf')]
        [ValidateSet('Implicit', 'Explicit')]
        [string]
        $TlsMode = 'Implicit',

        [Parameter()]
        [string]
        $Name = $null,

        [Parameter()]
        [string]
        $RedirectTo = $null,

        [Parameter()]
        [string]
        $Description,

        [Parameter()]
        [string]
        $Acknowledge,

        [Parameter()]
        [ValidateSet('Ssl2', 'Ssl3', 'Tls', 'Tls11', 'Tls12', 'Tls13')]
        [string[]]
        $SslProtocol = $null,

        [switch]
        $CRLFMessageEnd,

        [switch]
        $Force,

        [Parameter(ParameterSetName = 'CertSelf')]
        [switch]
        $SelfSigned,

        [switch]
        $AllowClientCertificate,

        [switch]
        $PassThru,

        [switch]
        $LookupHostname,

        [switch]
        $DualMode,

        [switch]
        $Default
    )

    # error if serverless
    Test-PodeIsServerless -FunctionName 'Add-PodeEndpoint' -ThrowError

    # if RedirectTo is supplied, then a Name is mandatory
    if (![string]::IsNullOrWhiteSpace($RedirectTo) -and [string]::IsNullOrWhiteSpace($Name)) {
        # A Name is required for the endpoint if the RedirectTo parameter is supplied
        throw ($PodeLocale.nameRequiredForEndpointIfRedirectToSuppliedExceptionMessage)
    }

    # get the type of endpoint
    $type = Get-PodeEndpointType -Protocol $Protocol

    # are we running as IIS for HTTP/HTTPS? (if yes, force the port, address and protocol)
    $isIIS = ((Test-PodeIsIIS) -and (@('Http', 'Ws') -icontains $type))
    if ($isIIS) {
        $Port = [int]$env:ASPNETCORE_PORT
        $Address = '127.0.0.1'
        $Hostname = [string]::Empty
        $Protocol = $type
    }

    # are we running as Heroku for HTTP/HTTPS? (if yes, force the port, address and protocol)
    $isHeroku = ((Test-PodeIsHeroku) -and (@('Http') -icontains $type))
    if ($isHeroku) {
        $Port = [int]$env:PORT
        $Address = '0.0.0.0'
        $Hostname = [string]::Empty
        $Protocol = $type
    }

    # parse the endpoint for host/port info
    if (![string]::IsNullOrWhiteSpace($Hostname) -and !(Test-PodeHostname -Hostname $Hostname)) {
        # Invalid hostname supplied
        throw ($PodeLocale.invalidHostnameSuppliedExceptionMessage -f $Hostname)
    }

    if ((Test-PodeHostname -Hostname $Address) -and ($Address -inotin @('localhost', 'all'))) {
        $Hostname = $Address
        $Address = 'localhost'
    }

    if (![string]::IsNullOrWhiteSpace($Hostname) -and $LookupHostname) {
        $Address = (Get-PodeIPAddressesForHostname -Hostname $Hostname -Type All | Select-Object -First 1)
    }

    $_endpoint = Get-PodeEndpointInfo -Address "$($Address):$($Port)"

    # if no name, set to guid, then check uniqueness
    if ([string]::IsNullOrWhiteSpace($Name)) {
        $Name = New-PodeGuid -Secure
    }

    if ($PodeContext.Server.Endpoints.ContainsKey($Name)) {
        # An endpoint named has already been defined
        throw ($PodeLocale.endpointAlreadyDefinedExceptionMessage -f $Name)
    }

    # protocol must be https for client certs, or hosted behind a proxy like iis
    if (($Protocol -ine 'https') -and !(Test-PodeIsHosted) -and $AllowClientCertificate) {
        # Client certificates are only supported on HTTPS endpoints
        throw ($PodeLocale.clientCertificatesOnlySupportedOnHttpsEndpointsExceptionMessage)
    }

    # explicit tls is only supported for smtp/tcp
    if (($type -inotin @('smtp', 'tcp')) -and ($TlsMode -ieq 'explicit')) {
        # The Explicit TLS mode is only supported on SMTPS and TCPS endpoints
        throw ($PodeLocale.explicitTlsModeOnlySupportedOnSmtpsTcpsEndpointsExceptionMessage)
    }

    # ack message is only for smtp/tcp
    if (($type -inotin @('smtp', 'tcp')) -and ![string]::IsNullOrEmpty($Acknowledge)) {
        # The Acknowledge message is only supported on SMTP and TCP endpoints
        throw ($PodeLocale.acknowledgeMessageOnlySupportedOnSmtpTcpEndpointsExceptionMessage)
    }

    # crlf message end is only for tcp
    if (($type -ine 'tcp') -and $CRLFMessageEnd) {
        # The CRLF message end check is only supported on TCP endpoints
        throw ($PodeLocale.crlfMessageEndCheckOnlySupportedOnTcpEndpointsExceptionMessage)
    }

    # new endpoint object
    $obj = @{
        Name         = $Name
        Description  = $Description
        DualMode     = $DualMode
        Address      = $null
        RawAddress   = $null
        Port         = $null
        IsIPAddress  = $true
        HostName     = $Hostname
        FriendlyName = $Hostname
        Url          = $null
        Ssl          = @{
            Enabled   = (@('https', 'wss', 'smtps', 'tcps') -icontains $Protocol)
            Protocols = $PodeContext.Server.Sockets.Ssl.Protocols
        }
        Protocol     = $Protocol.ToLowerInvariant()
        Type         = $type.ToLowerInvariant()
        Runspace     = @{
            PoolName = (Get-PodeEndpointRunspacePoolName -Protocol $Protocol)
        }
        Default      = $Default.IsPresent
        Certificate  = @{
            Raw                    = $X509Certificate
            SelfSigned             = $SelfSigned
            AllowClientCertificate = $AllowClientCertificate
            TlsMode                = $TlsMode
        }
        Tcp          = @{
            Acknowledge    = $Acknowledge
            CRLFMessageEnd = $CRLFMessageEnd
        }
    }

    # set ssl protocols
    if (!(Test-PodeIsEmpty $SslProtocol)) {
        $obj.Ssl.Protocols = (ConvertTo-PodeSslProtocol -Protocol $SslProtocol)
    }

    # set the ip for the context (force to localhost for IIS)
    $obj.Address = Get-PodeIPAddress $_endpoint.Host -DualMode:$DualMode
    $obj.IsIPAddress = [string]::IsNullOrWhiteSpace($obj.HostName)

    if ($obj.IsIPAddress) {
        if (!(Test-PodeIPAddressLocalOrAny -IP $obj.Address)) {
            $obj.FriendlyName = "$($obj.Address)"
        }
        else {
            $obj.FriendlyName = 'localhost'
        }
    }

    # set the port for the context, if 0 use a default port for protocol
    $obj.Port = $_endpoint.Port
    if (([int]$obj.Port) -eq 0) {
        $obj.Port = Get-PodeDefaultPort -Protocol $Protocol -TlsMode $TlsMode
    }

    if ($obj.IsIPAddress) {
        $obj.RawAddress = "$($obj.Address):$($obj.Port)"
    }
    else {
        $obj.RawAddress = "$($obj.FriendlyName):$($obj.Port)"
    }

    # set the url of this endpoint
    if (($obj.Protocol -eq 'http') -or ($obj.Protocol -eq 'https')) {
        $obj.Url = "$($obj.Protocol)://$($obj.FriendlyName):$($obj.Port)/"
    }
    else {
        $obj.Url = "$($obj.Protocol)://$($obj.FriendlyName):$($obj.Port)"
    }
    # if the address is non-local, then check admin privileges
    if (!$Force -and !(Test-PodeIPAddressLocal -IP $obj.Address) -and !(Test-PodeIsAdminUser)) {
        # Must be running with administrator privileges to listen on non-localhost addresses
        throw ($PodeLocale.mustBeRunningWithAdminPrivilegesExceptionMessage)
    }

    # has this endpoint been added before? (for http/https we can just not add it again)
    $exists = ($PodeContext.Server.Endpoints.Values | Where-Object {
        ($_.FriendlyName -ieq $obj.FriendlyName) -and ($_.Port -eq $obj.Port) -and ($_.Ssl.Enabled -eq $obj.Ssl.Enabled) -and ($_.Type -ieq $obj.Type)
        } | Measure-Object).Count

    # if we're dealing with a certificate, attempt to import it
    if (!(Test-PodeIsHosted) -and ($PSCmdlet.ParameterSetName -ilike 'cert*')) {
        # fail if protocol is not https
        if (@('https', 'wss', 'smtps', 'tcps') -inotcontains $Protocol) {
            # Certificate supplied for non-HTTPS/WSS endpoint
            throw ($PodeLocale.certificateSuppliedForNonHttpsWssEndpointExceptionMessage)
        }

        switch ($PSCmdlet.ParameterSetName.ToLowerInvariant()) {
            'certfile' {
                $obj.Certificate.Raw = Get-PodeCertificateByFile -Certificate $Certificate -Password $CertificatePassword -Key $CertificateKey
            }

            'certthumb' {
                $obj.Certificate.Raw = Get-PodeCertificateByThumbprint -Thumbprint $CertificateThumbprint -StoreName $CertificateStoreName -StoreLocation $CertificateStoreLocation
            }

            'certname' {
                $obj.Certificate.Raw = Get-PodeCertificateByName -Name $CertificateName -StoreName $CertificateStoreName -StoreLocation $CertificateStoreLocation
            }

            'certself' {
                $obj.Certificate.Raw = New-PodeSelfSignedCertificate
            }
        }

        # fail if the cert is expired
        if ($obj.Certificate.Raw.NotAfter -lt [datetime]::Now) {
            # The certificate has expired
            throw ($PodeLocale.certificateExpiredExceptionMessage -f $obj.Certificate.Raw.Subject, $obj.Certificate.Raw.NotAfter)
        }
    }

    if (!$exists) {
        # set server type
        $_type = $type
        if ($_type -iin @('http', 'ws')) {
            $_type = 'http'
        }

        if ($PodeContext.Server.Types -inotcontains $_type) {
            $PodeContext.Server.Types += $_type
        }

        # add the new endpoint
        $PodeContext.Server.Endpoints[$Name] = $obj
        $PodeContext.Server.EndpointsMap["$($obj.Protocol)|$($obj.RawAddress)"] = $Name
    }

    # if RedirectTo is set, attempt to build a redirecting route
    if (!(Test-PodeIsHosted) -and ![string]::IsNullOrWhiteSpace($RedirectTo)) {
        $redir_endpoint = $PodeContext.Server.Endpoints[$RedirectTo]

        # ensure the name exists
        if (Test-PodeIsEmpty $redir_endpoint) {
            # An endpoint named has not been defined for redirecting
            throw ($PodeLocale.endpointNotDefinedForRedirectingExceptionMessage -f $RedirectTo)
        }

        # build the redirect route
        Add-PodeRoute -Method * -Path * -EndpointName $obj.Name -ArgumentList $redir_endpoint -ScriptBlock {
            param($endpoint)
            Move-PodeResponseUrl -EndpointName $endpoint.Name
        }
    }

    # return the endpoint?
    if ($PassThru) {
        return $obj
    }
}


<#
.SYNOPSIS
    Get an Endpoint(s).

.DESCRIPTION
    Get an Endpoint(s).

.PARAMETER Address
    An Address to filter the endpoints.

.PARAMETER Port
    A Port to filter the endpoints.

.PARAMETER Hostname
    A Hostname to filter the endpoints.

.PARAMETER Protocol
    A Protocol to filter the endpoints.

.PARAMETER Name
    Any endpoints Names to filter endpoints.

.EXAMPLE
    Get-PodeEndpoint -Address 127.0.0.1

.EXAMPLE
    Get-PodeEndpoint -Protocol Http

.EXAMPLE
    Get-PodeEndpoint -Name Admin, User
#>
function Get-PodeEndpoint {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Address,

        [Parameter()]
        [int]
        $Port = 0,

        [Parameter()]
        [string]
        $Hostname,

        [Parameter()]
        [ValidateSet('', 'Http', 'Https', 'Smtp', 'Smtps', 'Tcp', 'Tcps', 'Ws', 'Wss')]
        [string]
        $Protocol,

        [Parameter()]
        [string[]]
        $Name
    )

    if ((Test-PodeHostname -Hostname $Address) -and ($Address -inotin @('localhost', 'all'))) {
        $Hostname = $Address
        $Address = 'localhost'
    }

    $endpoints = $PodeContext.Server.Endpoints.Values

    # if we have an address, filter
    if (![string]::IsNullOrWhiteSpace($Address)) {
        if (($Address -eq '*') -or $PodeContext.Server.IsHeroku) {
            $Address = '0.0.0.0'
        }

        if ($PodeContext.Server.IsIIS -or ($Address -ieq 'localhost')) {
            $Address = '127.0.0.1'
        }

        $endpoints = @(foreach ($endpoint in $endpoints) {
                if ($endpoint.Address.ToString() -ine $Address) {
                    continue
                }

                $endpoint
            })
    }

    # if we have a hostname, filter
    if (![string]::IsNullOrWhiteSpace($Hostname)) {
        $endpoints = @(foreach ($endpoint in $endpoints) {
                if ($endpoint.Hostname.ToString() -ine $Hostname) {
                    continue
                }

                $endpoint
            })
    }

    # if we have a port, filter
    if ($Port -gt 0) {
        if ($PodeContext.Server.IsIIS) {
            $Port = [int]$env:ASPNETCORE_PORT
        }

        if ($PodeContext.Server.IsHeroku) {
            $Port = [int]$env:PORT
        }

        $endpoints = @(foreach ($endpoint in $endpoints) {
                if ($endpoint.Port -ne $Port) {
                    continue
                }

                $endpoint
            })
    }

    # if we have a protocol, filter
    if (![string]::IsNullOrWhiteSpace($Protocol)) {
        if ($PodeContext.Server.IsIIS -or $PodeContext.Server.IsHeroku) {
            $Protocol = 'Http'
        }

        $endpoints = @(foreach ($endpoint in $endpoints) {
                if ($endpoint.Protocol -ine $Protocol) {
                    continue
                }

                $endpoint
            })
    }

    # further filter by endpoint names
    if (($null -ne $Name) -and ($Name.Length -gt 0)) {
        $endpoints = @(foreach ($_name in $Name) {
                foreach ($endpoint in $endpoints) {
                    if ($endpoint.Name -ine $_name) {
                        continue
                    }

                    $endpoint
                }
            })
    }

    # return
    return $endpoints
}


<#
.SYNOPSIS
    Clears an event of all registered scripts.

.DESCRIPTION
    Clears an event of all registered scripts.

.PARAMETER Type
    The Type of event to clear.

.EXAMPLE
    Clear-PodeEvent -Type Start
#>
function Clear-PodeEvent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [Pode.PodeServerEventType]
        $Type
    )

    $null = $PodeContext.Server.Events[$Type.ToString()].Clear()
}


<#
.SYNOPSIS
    Retrieves an event.

.DESCRIPTION
    Retrieves an event.

.PARAMETER Type
    The Type of event to retrieve.

.PARAMETER Name
    The Name of the event to retrieve.

.EXAMPLE
    Get-PodeEvent -Type Start -Name 'Event1'
#>
function Get-PodeEvent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [Pode.PodeServerEventType]
        $Type,

        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    return $PodeContext.Server.Events[$Type.ToString()][$Name]
}


<#
.SYNOPSIS
    Registers a script to be run when a certain server event occurs within Pode

.DESCRIPTION
    Registers a script to be run when a certain server event occurs within Pode, such as Start, Terminate, and Restart.

.PARAMETER Type
    The Type of event to be registered.

.PARAMETER Name
    A unique Name for the registered event.

.PARAMETER ScriptBlock
    A ScriptBlock to invoke when the event is triggered.

.PARAMETER ArgumentList
    An array of arguments to supply to the ScriptBlock.

.EXAMPLE
    Register-PodeEvent -Type Start -Name 'Event1' -ScriptBlock { }
#>
function Register-PodeEvent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [Pode.PodeServerEventType]
        $Type,

        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [object[]]
        $ArgumentList
    )

    # error if already registered
    if (Test-PodeEvent -Type $Type -Name $Name) {
        throw ($PodeLocale.eventAlreadyRegisteredExceptionMessage -f $Type, $Name) # "$($Type) event already registered: $($Name)"
    }

    # check for scoped vars
    $ScriptBlock, $usingVars = Convert-PodeScopedVariables -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState

    # add event
    $PodeContext.Server.Events[$Type.ToString()][$Name] = @{
        Name           = $Name
        ScriptBlock    = $ScriptBlock
        UsingVariables = $usingVars
        Arguments      = $ArgumentList
    }
}


<#
.SYNOPSIS
    Tests if an event has been registered with the specified Name.

.DESCRIPTION
    Tests if an event has been registered with the specified Name.

.PARAMETER Type
    The Type of the event to test.

.PARAMETER Name
    The Name of the event to test.

.EXAMPLE
    Test-PodeEvent -Type Start -Name 'Event1'
#>
function Test-PodeEvent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [Pode.PodeServerEventType]
        $Type,

        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    return $PodeContext.Server.Events[$Type.ToString()].Contains($Name)
}


<#
.SYNOPSIS
    Unregisters an event that has been registered with the specified Name.

.DESCRIPTION
    Unregisters an event that has been registered with the specified Name.

.PARAMETER Type
    The Type of the event to unregister.

.PARAMETER Name
    The Name of the event to unregister.

.EXAMPLE
    Unregister-PodeEvent -Type Start -Name 'Event1'
#>
function Unregister-PodeEvent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [Pode.PodeServerEventType]
        $Type,

        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    # error if not registered
    if (!(Test-PodeEvent -Type $Type -Name $Name)) {
        throw ($PodeLocale.noEventRegisteredExceptionMessage -f $Type, $Name) # "No $($Type) event registered: $($Name)"
    }

    # remove event
    $null = $PodeContext.Server.Events[$Type.ToString()].Remove($Name)
}


<#
.SYNOPSIS
    Automatically loads event ps1 files

.DESCRIPTION
    Automatically loads event ps1 files from either a /events folder, or a custom folder. Saves space dot-sourcing them all one-by-one.

.PARAMETER Path
    Optional Path to a folder containing ps1 files, can be relative or literal.

.EXAMPLE
    Use-PodeEvents

.EXAMPLE
    Use-PodeEvents -Path './my-events'
#>
function Use-PodeEvents {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Path
    )

    Use-PodeFolder -Path $Path -DefaultPath 'events'
}


<#
.SYNOPSIS
    Adds a new File Watcher to monitor file changes in a directory.

.DESCRIPTION
    Adds a new File Watcher to monitor file changes in a directory.

.PARAMETER Name
    An optional Name for the File Watcher. (Default: GUID)

.PARAMETER EventName
    An optional EventName to be monitored. Note: '*' refers to all event names. (Default: Changed, Created, Deleted, Renamed)

.PARAMETER Path
    The Path to a directory which contains the files to be monitored.

.PARAMETER ScriptBlock
    The ScriptBlock defining logic to be run when events are triggered.

.PARAMETER FilePath
    A literal, or relative, path to a file containing a ScriptBlock for the File Watcher's logic.

.PARAMETER ArgumentList
    A hashtable of arguments to supply to the File Watcher's ScriptBlock.

.PARAMETER NotifyFilter
    The attributes on files to monitor and notify about. (Default: FileName, DirectoryName, LastWrite, CreationTime)

.PARAMETER Exclude
    An optional array of file patterns to be excluded.

.PARAMETER Include
    An optional array of file patterns to be included. (Default: *.*)

.PARAMETER InternalBufferSize
    The InternalBufferSize of the file monitor, used when temporarily storing events. (Default: 8kb)

.PARAMETER NoSubdirectories
    If supplied, the File Watcher will only monitor files in the specified directory path, and not in all sub-directories as well.

.PARAMETER PassThru
    If supplied, the File Watcher object registered will be returned.

.EXAMPLE
    Add-PodeFileWatcher -Path 'C:/Projects/:project/src' -Include '*.ps1' -ScriptBlock {}

.EXAMPLE
    Add-PodeFileWatcher -Path 'C:/Websites/:site' -Include '*.config' -EventName Changed -ScriptBlock {}

.EXAMPLE
    Add-PodeFileWatcher -Path '/temp/logs' -EventName Created -NotifyFilter CreationTime -ScriptBlock {}

.EXAMPLE
    $watcher = Add-PodeFileWatcher -Path '/temp/logs' -Exclude *.txt -ScriptBlock {} -PassThru
#>
function Add-PodeFileWatcher {
    [CmdletBinding(DefaultParameterSetName = 'Script')]
    param(
        [Parameter()]
        [string]
        $Name = $null,

        [Parameter()]
        [ValidateSet('Changed', 'Created', 'Deleted', 'Renamed', 'Existed', '*')]
        [string[]]
        $EventName = @('Changed', 'Created', 'Deleted', 'Renamed'),

        [Parameter(Mandatory = $true)]
        [string]
        $Path,

        [Parameter(Mandatory = $true, ParameterSetName = 'Script')]
        [scriptblock]
        $ScriptBlock,

        [Parameter(Mandatory = $true, ParameterSetName = 'File')]
        [string]
        $FilePath,

        [Parameter()]
        [object[]]
        $ArgumentList,

        [Parameter()]
        [System.IO.NotifyFilters[]]
        $NotifyFilter = @('FileName', 'DirectoryName', 'LastWrite', 'CreationTime'),

        [Parameter()]
        [string[]]
        $Exclude,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Include = '*.*',

        [Parameter()]
        [ValidateRange(4kb, 64kb)]
        [int]
        $InternalBufferSize = 8kb,

        [switch]
        $NoSubdirectories,

        [switch]
        $PassThru
    )

    # set random name
    if ([string]::IsNullOrEmpty($Name)) {
        $Name = New-PodeGuid -Secure
    }

    # set all for * event
    if ('*' -iin $EventName) {
        $EventName = @('Changed', 'Created', 'Deleted', 'Renamed', 'Existed')
    }

    # resolve path if relative
    if (!(Test-PodeIsPSCore)) {
        $Path = Convert-PodePlaceholder -Path $Path -Prepend '%' -Append '%'
    }

    $Path = Get-PodeRelativePath -Path $Path -JoinRoot -Resolve

    if (!(Test-PodeIsPSCore)) {
        $Path = Convert-PodePlaceholder -Path $Path -Pattern '\%(?<tag>[\w]+)\%' -Prepend ':' -Append ([string]::Empty)
    }

    # resolve path, and test it
    $hasPlaceholders = Test-PodePlaceholder -Path $Path
    if ($hasPlaceholders) {
        $rgxPath = Update-PodeRouteSlash -Path $Path -NoLeadingSlash
        $rgxPath = Resolve-PodePlaceholder -Path $rgxPath -Slashes
        $Path = $Path -ireplace (Get-PodePlaceholderRegex), '*'
    }

    # test path to make sure it exists
    if (!(Test-PodePath $Path -NoStatus)) {
        # Path does not exist
        throw ($PodeLocale.pathNotExistExceptionMessage -f $Path)
    }

    # test if we have the file watcher already
    if (Test-PodeFileWatcher -Name $Name) {
        # A File Watcher named has already been defined
        throw ($PodeLocale.fileWatcherAlreadyDefinedExceptionMessage -f $Name)
    }

    # if we have a file path supplied, load that path as a scriptblock
    if ($PSCmdlet.ParameterSetName -ieq 'file') {
        $ScriptBlock = Convert-PodeFileToScriptBlock -FilePath $FilePath
    }

    # check for scoped vars
    $ScriptBlock, $usingVars = Convert-PodeScopedVariables -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState

    # enable the file watcher threads
    $PodeContext.Fim.Enabled = $true

    # resolve the path's widacards if any
    $paths = @($Path)
    if ($Path.Contains('*')) {
        $paths = @(Get-ChildItem -Path $Path -Directory -Force | Select-Object -ExpandProperty FullName)
    }

    # add the file watcher
    $PodeContext.Fim.Items[$Name] = @{
        Name                  = $Name
        Events                = @($EventName)
        Path                  = $Path
        Placeholders          = @{
            Path  = $rgxPath
            Exist = $hasPlaceholders
        }
        Script                = $ScriptBlock
        UsingVariables        = $usingVars
        Arguments             = $ArgumentList
        NotifyFilters         = @($NotifyFilter)
        IncludeSubdirectories = !$NoSubdirectories.IsPresent
        InternalBufferSize    = $InternalBufferSize
        Exclude               = $Exclude
        Include               = $Include
        Paths                 = $paths
    }

    # return?
    if ($PassThru) {
        return $PodeContext.Fim.Items[$Name]
    }
}


<#
.SYNOPSIS
    Removes all File Watchers.

.DESCRIPTION
    Removes all File Watchers.

.EXAMPLE
    Clear-PodeFileWatchers
#>
function Clear-PodeFileWatchers {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    [CmdletBinding()]
    param()

    $PodeContext.Fim.Items.Clear()
}


<#
.SYNOPSIS
    Returns any defined File Watchers.

.DESCRIPTION
    Returns any defined File Watchers.

.PARAMETER Name
    An optional File Watcher Name(s) to be returned.

.EXAMPLE
    Get-PodeFileWatcher

.EXAMPLE
    Get-PodeFileWatcher -Name Name1, Name2
#>
function Get-PodeFileWatcher {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string[]]
        $Name
    )

    $watchers = $PodeContext.Fim.Items.Values

    # further filter by file watcher names
    if (($null -ne $Name) -and ($Name.Length -gt 0)) {
        $watchers = @(foreach ($_name in $Name) {
                foreach ($watcher in $watchers) {
                    if ($watcher.Name -ine $_name) {
                        continue
                    }

                    $watcher
                }
            })
    }

    # return
    return $watchers
}


<#
.SYNOPSIS
    Removes a specific File Watchers.

.DESCRIPTION
    Removes a specific File Watchers.

.PARAMETER Name
    The Name of the File Watcher to be removed.

.EXAMPLE
    Remove-PodeFileWatcher -Name 'Logs'
#>
function Remove-PodeFileWatcher {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    $null = $PodeContext.Fim.Items.Remove($Name)
}


<#
.SYNOPSIS
    Tests whether the passed File Watcher exists.

.DESCRIPTION
    Tests whether the passed File Watcher exists by its name.

.PARAMETER Name
    The Name of the File Watcher.

.EXAMPLE
    if (Test-PodeFileWatcher -Name WatcherName) { }
#>
function Test-PodeFileWatcher {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    return (($null -ne $PodeContext.Fim.Items) -and $PodeContext.Fim.Items.ContainsKey($Name))
}


<#
.SYNOPSIS
    Automatically loads File Watchers ps1 files

.DESCRIPTION
    Automatically loads File Watchers ps1 files from either a /filewatcher folder, or a custom folder. Saves space dot-sourcing them all one-by-one.

.PARAMETER Path
    Optional Path to a folder containing ps1 files, can be relative or literal.

.EXAMPLE
    Use-PodeFileWatchers

.EXAMPLE
    Use-PodeFileWatchers -Path './my-watchers'
#>
function Use-PodeFileWatchers {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Path
    )

    Use-PodeFolder -Path $Path -DefaultPath 'filewatchers'
}


<#
.SYNOPSIS
    Appends a message to the current flash messages stored in the session.

.DESCRIPTION
    Appends a message to the current flash messages stored in the session for the supplied name.
    The messages per name are stored as an array.

.PARAMETER Name
    The name of the flash message to be appended.

.PARAMETER Message
    The message to append.

.EXAMPLE
    Add-PodeFlashMessage -Name 'error' -Message 'There was an error'
#>
function Add-PodeFlashMessage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true)]
        [string]
        $Message
    )

    # if sessions haven't been setup, error
    if (!(Test-PodeSessionsEnabled)) {
        # Sessions are required to use Flash messages
        throw ($PodeLocale.sessionsRequiredForFlashMessagesExceptionMessage)
    }

    # append the message against the key
    if ($null -eq $WebEvent.Session.Data.Flash) {
        $WebEvent.Session.Data.Flash = @{}
    }

    if ($null -eq $WebEvent.Session.Data.Flash[$Name]) {
        $WebEvent.Session.Data.Flash[$Name] = @($Message)
    }
    else {
        $WebEvent.Session.Data.Flash[$Name] += @($Message)
    }
}


<#
.SYNOPSIS
    Clears all flash messages.

.DESCRIPTION
    Clears all of the flash messages currently stored in the session.

.EXAMPLE
    Clear-PodeFlashMessages
#>
function Clear-PodeFlashMessages {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    [CmdletBinding()]
    param()

    # if sessions haven't been setup, error
    if (!(Test-PodeSessionsEnabled)) {
        # Sessions are required to use Flash messages
        throw ($PodeLocale.sessionsRequiredForFlashMessagesExceptionMessage)
    }

    # clear all keys
    if ($null -ne $WebEvent.Session.Data.Flash) {
        $WebEvent.Session.Data.Flash = @{}
    }
}


<#
.SYNOPSIS
    Returns all flash messages stored against a name, and the clears the messages.

.DESCRIPTION
    Returns all of the flash messages, as an array, currently stored for the name within the session.
    Once retrieved, the messages are removed from storage.

.PARAMETER Name
    The name of the flash messages to return.

.EXAMPLE
    Get-PodeFlashMessage -Name 'error'
#>
function Get-PodeFlashMessage {
    [CmdletBinding()]
    [OutputType([System.Object[]])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    # if sessions haven't been setup, error
    if (!(Test-PodeSessionsEnabled)) {
        # Sessions are required to use Flash messages
        throw ($PodeLocale.sessionsRequiredForFlashMessagesExceptionMessage)
    }

    # retrieve messages from session, then delete it
    if ($null -eq $WebEvent.Session.Data.Flash) {
        return @()
    }

    $v = @($WebEvent.Session.Data.Flash[$Name])
    $WebEvent.Session.Data.Flash.Remove($Name)

    if (Test-PodeIsEmpty $v) {
        return @()
    }

    return @($v)
}


<#
.SYNOPSIS
    Returns all of the names for each of the messages currently being stored.

.DESCRIPTION
    Returns all of the names for each of the messages currently being stored. This does not clear the messages.

.EXAMPLE
    Get-PodeFlashMessageNames
#>
function Get-PodeFlashMessageNames {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    [CmdletBinding()]
    [OutputType([System.Object[]])]
    param()

    # if sessions haven't been setup, error
    if (!(Test-PodeSessionsEnabled)) {
        # Sessions are required to use Flash messages
        throw ($PodeLocale.sessionsRequiredForFlashMessagesExceptionMessage)
    }

    # return list of all current keys
    if ($null -eq $WebEvent.Session.Data.Flash) {
        return @()
    }

    return @($WebEvent.Session.Data.Flash.Keys)
}


<#
.SYNOPSIS
    Removes flash messages for the supplied name currently being stored.

.DESCRIPTION
    Removes flash messages for the supplied name currently being stored.

.PARAMETER Name
    The name of the flash messages to remove.

.EXAMPLE
    Remove-PodeFlashMessage -Name 'error'
#>
function Remove-PodeFlashMessage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    # if sessions haven't been setup, error
    if (!(Test-PodeSessionsEnabled)) {
        # Sessions are required to use Flash messages
        throw ($PodeLocale.sessionsRequiredForFlashMessagesExceptionMessage)
    }

    # remove key from flash messages
    if ($null -ne $WebEvent.Session.Data.Flash) {
        $WebEvent.Session.Data.Flash.Remove($Name)
    }
}


<#
.SYNOPSIS
    Tests if there are any flash messages currently being stored for a supplied name.

.DESCRIPTION
    Tests if there are any flash messages currently being stored for a supplied name.

.PARAMETER Name
    The name of the flash message to check.

.EXAMPLE
    Test-PodeFlashMessage -Name 'error'
#>
function Test-PodeFlashMessage {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    # if sessions haven't been setup, error
    if (!(Test-PodeSessionsEnabled)) {
        # Sessions are required to use Flash messages
        throw ($PodeLocale.sessionsRequiredForFlashMessagesExceptionMessage)
    }

    # return if a key exists as a flash message
    if ($null -eq $WebEvent.Session.Data.Flash) {
        return $false
    }

    return $WebEvent.Session.Data.Flash.ContainsKey($Name)
}


<#
.SYNOPSIS
    Adds a Handler of a specific Type.

.DESCRIPTION
    Adds a Handler of a specific Type.

.PARAMETER Type
    The Type of the Handler.

.PARAMETER Name
    The Name of the Handler.

.PARAMETER ScriptBlock
    The ScriptBlock for the Handler's main logic.

.PARAMETER FilePath
    A literal, or relative, path to a file containing a ScriptBlock for the Handler's main logic.

.PARAMETER ArgumentList
    An array of arguments to supply to the Handler's ScriptBlock.

.EXAMPLE
    Add-PodeHandler -Type Smtp -Name 'Main' -ScriptBlock { /* logic */ }

.EXAMPLE
    Add-PodeHandler -Type Service -Name 'Looper' -ScriptBlock { /* logic */ }

.EXAMPLE
    Add-PodeHandler -Type Smtp -Name 'Main' -ScriptBlock { /* logic */ } -ArgumentList 'arg1', 'arg2'
#>
function Add-PodeHandler {
    [CmdletBinding(DefaultParameterSetName = 'Script')]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Service', 'Smtp')]
        [string]
        $Type,

        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true, ParameterSetName = 'Script')]
        [scriptblock]
        $ScriptBlock,

        [Parameter(Mandatory = $true, ParameterSetName = 'File')]
        [string]
        $FilePath,

        [Parameter()]
        [object[]]
        $ArgumentList
    )

    # error if serverless
    Test-PodeIsServerless -FunctionName 'Add-PodeHandler' -ThrowError

    # ensure handler isn't already set
    if ($PodeContext.Server.Handlers[$Type].ContainsKey($Name)) {
        # [Type] Name: Handler already defined
        throw ($PodeLocale.handlerAlreadyDefinedExceptionMessage -f $Type, $Name)
    }

    # if we have a file path supplied, load that path as a scriptblock
    if ($PSCmdlet.ParameterSetName -ieq 'file') {
        $ScriptBlock = Convert-PodeFileToScriptBlock -FilePath $FilePath
    }

    # check for scoped vars
    $ScriptBlock, $usingVars = Convert-PodeScopedVariables -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState

    # add the handler
    Write-Verbose "Adding Handler: [$($Type)] $($Name)"
    $PodeContext.Server.Handlers[$Type][$Name] += @(@{
            Logic          = $ScriptBlock
            UsingVariables = $usingVars
            Arguments      = $ArgumentList
        })
}


<#
.SYNOPSIS
    Removes all added Handlers, or Handlers of a specific Type.

.DESCRIPTION
    Removes all added Handlers, or Handlers of a specific Type.

.PARAMETER Type
    The Type of Handlers to remove.

.EXAMPLE
    Clear-PodeHandlers -Type Smtp
#>
function Clear-PodeHandlers {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateSet('', 'Service', 'Smtp')]
        [string]
        $Type
    )

    if (![string]::IsNullOrWhiteSpace($Type)) {
        $PodeContext.Server.Handlers[$Type].Clear()
    }
    else {
        $PodeContext.Server.Handlers.Keys.Clone() | ForEach-Object {
            $PodeContext.Server.Handlers[$_].Clear()
        }
    }
}


<#
.SYNOPSIS
    Remove a specific Handler.

.DESCRIPTION
    Remove a specific Handler.

.PARAMETER Type
    The type of the Handler to be removed.

.PARAMETER Name
    The name of the Handler to be removed.

.EXAMPLE
    Remove-PodeHandler -Type Smtp -Name 'Main'
#>
function Remove-PodeHandler {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Service', 'Smtp')]
        [string]
        $Type,

        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    # ensure handler does exist
    if (!$PodeContext.Server.Handlers[$Type].ContainsKey($Name)) {
        return
    }

    # remove the handler
    $null = $PodeContext.Server.Handlers[$Type].Remove($Name)
}


<#
.SYNOPSIS
    Automatically loads handler ps1 files

.DESCRIPTION
    Automatically loads handler ps1 files from either a /handler folder, or a custom folder. Saves space dot-sourcing them all one-by-one.

.PARAMETER Path
    Optional Path to a folder containing ps1 files, can be relative or literal.

.EXAMPLE
    Use-PodeHandlers

.EXAMPLE
    Use-PodeHandlers -Path './my-handlers'
#>
function Use-PodeHandlers {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Path
    )

    Use-PodeFolder -Path $Path -DefaultPath 'handlers'
}


<#
.SYNOPSIS
    Appends a header against the Response.

.DESCRIPTION
    Appends a header against the Response. If the current context is serverless, then this function acts like Set-PodeHeader.

.PARAMETER Name
    The name of the header.

.PARAMETER Value
    The value to set against the header.

.PARAMETER Secret
    If supplied, the secret with which to sign the header's value.

.PARAMETER Strict
    If supplied, the Secret will be extended using the client request's UserAgent and RemoteIPAddress.

.EXAMPLE
    Add-PodeHeader -Name 'X-AuthToken' -Value 'AA-BB-CC-33'
#>
function Add-PodeHeader {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true)]
        [string]
        $Value,

        [Parameter()]
        [string]
        $Secret,

        [switch]
        $Strict
    )

    # sign the value if we have a secret
    if (![string]::IsNullOrWhiteSpace($Secret)) {
        $Value = (Invoke-PodeValueSign -Value $Value -Secret $Secret -Strict:$Strict)
    }

    # add the header to the response
    if ($PodeContext.Server.IsServerless) {
        $WebEvent.Response.Headers[$Name] = $Value
    }
    else {
        $WebEvent.Response.Headers.Add($Name, $Value)
    }
}


<#
.SYNOPSIS
    Appends multiple headers against the Response.

.DESCRIPTION
    Appends multiple headers against the Response. If the current context is serverless, then this function acts like Set-PodeHeaderBulk.

.PARAMETER Values
    A hashtable of headers to be appended.

.PARAMETER Secret
    If supplied, the secret with which to sign the header values.

.PARAMETER Strict
    If supplied, the Secret will be extended using the client request's UserAgent and RemoteIPAddress.

.EXAMPLE
    Add-PodeHeaderBulk -Values @{ Name1 = 'Value1'; Name2 = 'Value2' }
#>
function Add-PodeHeaderBulk {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]
        $Values,

        [Parameter()]
        [string]
        $Secret,

        [switch]
        $Strict
    )

    foreach ($key in $Values.Keys) {
        $value = $Values[$key]

        # sign the value if we have a secret
        if (![string]::IsNullOrWhiteSpace($Secret)) {
            $value = (Invoke-PodeValueSign -Value $value -Secret $Secret -Strict:$Strict)
        }

        # add the header to the response
        if ($PodeContext.Server.IsServerless) {
            $WebEvent.Response.Headers[$key] = $value
        }
        else {
            $WebEvent.Response.Headers.Add($key, $value)
        }
    }
}


<#
.SYNOPSIS
    Retrieves the value of a header from the Request.

.DESCRIPTION
    Retrieves the value of a header from the Request.

.PARAMETER Name
    The name of the header to retrieve.

.PARAMETER Secret
    The secret used to unsign the header's value.

.PARAMETER Strict
    If supplied, the Secret will be extended using the client request's UserAgent and RemoteIPAddress.

.EXAMPLE
    Get-PodeHeader -Name 'X-AuthToken'
#>
function Get-PodeHeader {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [string]
        $Secret,

        [switch]
        $Strict
    )

    # get the value for the header from the request
    $header = $WebEvent.Request.Headers.$Name

    # if a secret was supplied, attempt to unsign the header's value
    if (![string]::IsNullOrWhiteSpace($Secret)) {
        $header = (Invoke-PodeValueUnsign -Value $header -Secret $Secret -Strict:$Strict)
    }

    return $header
}


<#
.SYNOPSIS
    Sets a header on the Response, clearing all current values for the header.

.DESCRIPTION
    Sets a header on the Response, clearing all current values for the header.

.PARAMETER Name
    The name of the header.

.PARAMETER Value
    The value to set against the header.

.PARAMETER Secret
    If supplied, the secret with which to sign the header's value.

.PARAMETER Strict
    If supplied, the Secret will be extended using the client request's UserAgent and RemoteIPAddress.

.EXAMPLE
    Set-PodeHeader -Name 'X-AuthToken' -Value 'AA-BB-CC-33'
#>
function Set-PodeHeader {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true)]
        [string]
        $Value,

        [Parameter()]
        [string]
        $Secret,

        [switch]
        $Strict
    )

    # sign the value if we have a secret
    if (![string]::IsNullOrWhiteSpace($Secret)) {
        $Value = (Invoke-PodeValueSign -Value $Value -Secret $Secret -Strict:$Strict)
    }

    # set the header on the response
    if ($PodeContext.Server.IsServerless) {
        $WebEvent.Response.Headers[$Name] = $Value
    }
    else {
        $WebEvent.Response.Headers.Set($Name, $Value)
    }
}


<#
.SYNOPSIS
    Sets multiple headers on the Response, clearing all current values for the header.

.DESCRIPTION
    Sets multiple headers on the Response, clearing all current values for the header.

.PARAMETER Values
    A hashtable of headers to be set.

.PARAMETER Secret
    If supplied, the secret with which to sign the header values.

.PARAMETER Strict
    If supplied, the Secret will be extended using the client request's UserAgent and RemoteIPAddress.

.EXAMPLE
    Set-PodeHeaderBulk -Values @{ Name1 = 'Value1'; Name2 = 'Value2' }
#>
function Set-PodeHeaderBulk {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]
        $Values,

        [Parameter()]
        [string]
        $Secret,

        [switch]
        $Strict
    )

    foreach ($key in $Values.Keys) {
        $value = $Values[$key]

        # sign the value if we have a secret
        if (![string]::IsNullOrWhiteSpace($Secret)) {
            $value = (Invoke-PodeValueSign -Value $value -Secret $Secret -Strict:$Strict)
        }

        # set the header on the response
        if ($PodeContext.Server.IsServerless) {
            $WebEvent.Response.Headers[$key] = $value
        }
        else {
            $WebEvent.Response.Headers.Set($key, $value)
        }
    }
}


<#
.SYNOPSIS
    Tests if a header is present on the Request.

.DESCRIPTION
    Tests if a header is present on the Request.

.PARAMETER Name
    The name of the header to test.

.EXAMPLE
    Test-PodeHeader -Name 'X-AuthToken'
#>
function Test-PodeHeader {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    $header = (Get-PodeHeader -Name $Name)
    return (![string]::IsNullOrWhiteSpace($header))
}


<#
.SYNOPSIS
    Tests if a header on the Request is validly signed.

.DESCRIPTION
    Tests if a header on the Request is validly signed, by attempting to unsign it using some secret.

.PARAMETER Name
    The name of the header to test.

.PARAMETER Secret
    A secret to use for attempting to unsign the header's value.

.PARAMETER Strict
    If supplied, the Secret will be extended using the client request's UserAgent and RemoteIPAddress.

.EXAMPLE
    Test-PodeHeaderSigned -Name 'X-Header-Name' -Secret 'hunter2'
#>
function Test-PodeHeaderSigned {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [string]
        $Secret,

        [switch]
        $Strict
    )

    $header = Get-PodeHeader -Name $Name
    return Test-PodeValueSigned -Value $header -Secret $Secret -Strict:$Strict
}


<#
.SYNOPSIS
    Adds an access rule to allow or deny IP addresses. This is a legacy function, use Add-PodeLimitAccessRule instead.

.DESCRIPTION
    Adds an access rule to allow or deny IP addresses. This is a legacy function, use Add-PodeLimitAccessRule instead.

.PARAMETER Access
    The type of access to enable.

.PARAMETER Type
    What type of request are we configuring?

.PARAMETER Values
    A single, or an array of values.

.EXAMPLE
    Add-PodeAccessRule -Access Allow -Type IP -Values '127.0.0.1'

.EXAMPLE
    Add-PodeAccessRule -Access Deny -Type IP -Values @('192.168.1.1', '10.10.1.0/24')
#>
function Add-PodeAccessRule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Allow', 'Deny')]
        [string]
        $Access,

        [Parameter(Mandatory = $true)]
        [ValidateSet('IP')]
        [string]
        $Type,

        [Parameter(Mandatory = $true)]
        [string[]]
        $Values
    )

    Add-PodeLimitAccessRule `
        -Name (New-PodeGuid) `
        -Action $Access `
        -Component (New-PodeLimitIPComponent -IP $Values)
}


<#
.SYNOPSIS
    Adds an access limit rule.

.DESCRIPTION
    Adds an access limit rule.

.PARAMETER Name
    The name of the access rule.

.PARAMETER Component
    The component(s) to check. This can be a single, or an array of components.

.PARAMETER Action
    The action to take. Either 'Allow' or 'Deny'.

.PARAMETER StatusCode
    The status code to return. (Default: 403)

.PARAMETER Priority
    The priority of the rule. The higher the number, the higher the priority. (Default: [int]::MinValue)

.EXAMPLE
    # only allow localhost
    Add-PodeLimitAccessRule -Name 'rule1' -Action Allow -Component @(
    New-PodeLimitIPComponent -IP '127.0.0.1'
    )

.EXAMPLE
    # only allow localhost and the /downloads route
    Add-PodeLimitAccessRule -Name 'rule1' -Action Allow -Component @(
    New-PodeLimitIPComponent -IP '127.0.0.1'
    New-PodeLimitRouteComponent -Path '/downloads'
    )

.EXAMPLE
    # deny all requests
    Add-PodeLimitAccessRule -Name 'rule1' -Action Deny -Component @(
    New-PodeLimitIPComponent
    )

.EXAMPLE
    # deny all requests from a subnet, with a custom status code
    Add-PodeLimitAccessRule -Name 'rule1' -Action Deny -StatusCode 401 -Component @(
    New-PodeLimitIPComponent -IP '10.0.0.0/24'
    )

.EXAMPLE
    # deny all requests from a subnet, with a custom status code and priority
    Add-PodeLimitAccessRule -Name 'rule1' -Action Deny -StatusCode 401 -Priority 100 -Component @(
    New-PodeLimitIPComponent -IP '192.0.1.0/16'
    )
#>
function Add-PodeLimitAccessRule {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Name,

        [Parameter()]
        [hashtable[]]
        $Component,

        [Parameter()]
        [ValidateSet('Allow', 'Deny')]
        [string]
        $Action,

        [Parameter()]
        [int]
        $StatusCode = 403,

        [Parameter()]
        [int]
        $Priority = [int]::MinValue
    )

    if (Test-PodeLimitAccessRule -Name $Name) {
        # An access limit rule with the name '$($Name)' already exists
        throw ($PodeLocale.accessLimitRuleAlreadyExistsExceptionMessage -f $Name)
    }

    $PodeContext.Server.Limits.Access.Rules[$Name] = @{
        Name       = $Name
        Components = $Component
        Action     = $Action
        StatusCode = $StatusCode
        Priority   = $Priority
    }

    $PodeContext.Server.Limits.Access.RulesAltered = $true

    # set the flag if we have any allow rules
    if ($Action -eq 'Allow') {
        $PodeContext.Server.Limits.Access.HaveAllowRules = $true
    }
}


<#
.SYNOPSIS
    Adds a rate limit rule.

.DESCRIPTION
    Adds a rate limit rule.

.PARAMETER Name
    The name of the rate limit rule.

.PARAMETER Component
    The component(s) to check. This can be a single, or an array of components.

.PARAMETER Limit
    The limit for the rule - the maximum number of requests to allow within the duration.

.PARAMETER Duration
    The duration for the rule, in milliseconds. (Default: 60000)

.PARAMETER StatusCode
    The status code to return when the limit is reached. (Default: 429)

.PARAMETER Priority
    The priority of the rule. The higher the number, the higher the priority. (Default: [int]::MinValue)

.EXAMPLE
    # limit to 10 requests per minute for all IPs
    Add-PodeLimitRateRule -Name 'rule1' -Limit 10 -Component @(
    New-PodeLimitIPComponent
    )

.EXAMPLE
    # limit to 5 requests per minute for all IPs and the /downloads route
    Add-PodeLimitRateRule -Name 'rule1' -Limit 5 -Component @(
    New-PodeLimitIPComponent
    New-PodeLimitRouteComponent -Path '/downloads'
    )

.EXAMPLE
    # limit to 1 request, per 30 seconds, for all IPs in a subnet grouped, to the /downloads route
    Add-PodeLimitRateRule -Name 'rule1' -Limit 1 -Duration 30000 -Component @(
    New-PodeLimitIPComponent -IP '10.0.0.0/24' -Group
    New-PodeLimitRouteComponent -Path '/downloads'
    )

.EXAMPLE
    # limit to 10 requests per second, for specific IPs, with a custom status code and priority
    Add-PodeLimitRateRule -Name 'rule1' -Limit 10 -Duration 1000 -StatusCode 401 -Priority 100 -Component @(
    New-PodeLimitIPComponent -IP '127.0.0.1', '192.0.0.1', '10.0.0.1'
    )
#>
function Add-PodeLimitRateRule {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Name,

        [Parameter()]
        [hashtable[]]
        $Component,

        [Parameter()]
        [ValidateRange(0, [int]::MaxValue)]
        [int]
        $Limit,

        [Parameter()]
        [ValidateRange(1, [int]::MaxValue)]
        [int]
        $Duration = 60000,

        [Parameter()]
        [int]
        $StatusCode = 429,

        [Parameter()]
        [int]
        $Priority = [int]::MinValue
    )

    if (Test-PodeLimitRateRule -Name $Name) {
        # A rate limit rule with the name '$($Name)' already exists
        throw ($PodeLocale.rateLimitRuleAlreadyExistsExceptionMessage -f $Name)
    }

    $PodeContext.Server.Limits.Rate.Rules[$Name] = @{
        Name       = $Name
        Components = $Component
        Limit      = $Limit
        Duration   = $Duration
        StatusCode = $StatusCode
        Priority   = $Priority
        Active     = [System.Collections.Concurrent.ConcurrentDictionary[string, hashtable]]::new()
    }

    $PodeContext.Server.Limits.Rate.RulesAltered = $true
    Add-PodeLimitRateTimer
}


<#
.SYNOPSIS
    Adds rate limiting rules for an IP addresses, Routes, or Endpoints. This is a legacy function, use Add-PodeLimitRateRule instead.

.DESCRIPTION
    Adds rate limiting rules for an IP addresses, Routes, or Endpoints. This is a legacy function, use Add-PodeLimitRateRule instead.

.PARAMETER Type
    What type of request is being rate limited: IP, Route, or Endpoint?

.PARAMETER Values
    A single, or an array of values.

.PARAMETER Limit
    The maximum number of requests to allow.

.PARAMETER Seconds
    The number of seconds to count requests before restarting the count.

.PARAMETER Group
    If supplied, groups of IPs in a subnet will be considered as one IP.

.EXAMPLE
    Add-PodeLimitRule -Type IP -Values '127.0.0.1' -Limit 10 -Seconds 1

.EXAMPLE
    Add-PodeLimitRule -Type IP -Values @('192.168.1.1', '10.10.1.0/24') -Limit 50 -Seconds 1 -Group

.EXAMPLE
    Add-PodeLimitRule -Type Route -Values '/downloads' -Limit 5 -Seconds 1
#>
function Add-PodeLimitRule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('IP', 'Route', 'Endpoint')]
        [string]
        $Type,

        [Parameter(Mandatory = $true)]
        [string[]]
        $Values,

        [Parameter(Mandatory = $true)]
        [int]
        $Limit,

        [Parameter(Mandatory = $true)]
        [int]
        $Seconds,

        [switch]
        $Group
    )

    $component = $null

    switch ($Type.ToLowerInvariant()) {
        'ip' {
            $component = New-PodeLimitIPComponent -IP $Values -Group:$Group
        }

        'route' {
            $component = New-PodeLimitRouteComponent -Path $Values
        }

        'endpoint' {
            $component = New-PodeLimitEndpointComponent -Name $Values
        }
    }

    Add-PodeLimitRateRule `
        -Name (New-PodeGuid) `
        -Limit $Limit `
        -Duration ($Seconds * 1000) `
        -Component $component
}


<#
.SYNOPSIS
    Gets an access rule by name.

.DESCRIPTION
    Gets an access rule by name.

.PARAMETER Name
    The name(s) of the access rule.

.EXAMPLE
    $rules = Get-PodeLimitAccessRule -Name 'rule1'

.EXAMPLE
    $rules = Get-PodeLimitAccessRule -Name 'rule1', 'rule2'

.EXAMPLE
    $rules = Get-PodeLimitAccessRule

.OUTPUTS
    A hashtable array containing the access rule(s).
#>
function Get-PodeLimitAccessRule {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter()]
        [string[]]
        $Name
    )

    if ($Name) {
        return $Name | ForEach-Object { $PodeContext.Server.Limits.Access.Rules[$_] }
    }

    return $PodeContext.Server.Limits.Access.Rules.Values
}


<#
.SYNOPSIS
    Gets a rate limit rule by name.

.DESCRIPTION
    Gets a rate limit rule by name.

.PARAMETER Name
    The name(s) of the rate limit rule.

.EXAMPLE
    $rules = Get-PodeLimitRateRule -Name 'rule1'

.EXAMPLE
    $rules = Get-PodeLimitRateRule -Name 'rule1', 'rule2'

.EXAMPLE
    $rules = Get-PodeLimitRateRule

.OUTPUTS
    A hashtable array containing the rate limit rule(s).
#>
function Get-PodeLimitRateRule {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter()]
        [string[]]
        $Name
    )

    if ($Name) {
        return $Name | ForEach-Object { $PodeContext.Server.Limits.Rate.Rules[$_] }
    }

    return $PodeContext.Server.Limits.Rate.Rules.Values
}


<#
.SYNOPSIS
    Creates a new Limit Endpoint component.

.DESCRIPTION
    Creates a new Limit Endpoint component. This supports the WebEvent, SmtpEvent, and TcpEvent endpoints.

.PARAMETER Name
    The endpoint name(s) to check.

.EXAMPLE
    New-PodeLimitEndpointComponent

.EXAMPLE
    New-PodeLimitEndpointComponent -Name 'api'

.OUTPUTS
    A hashtable containing the options and scriptblock for the endpoint component.
    The scriptblock will return the endpoint name if found, or null if not.
#>
function New-PodeLimitEndpointComponent {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter()]
        [string[]]
        $Name
    )

    # convert endpoint names into a hashtable for easier lookup
    $htName = @{}
    foreach ($e in $Name) {
        $htName[$e] = $true
    }

    # pass back the endpoint component
    return @{
        Options     = @{
            EndpointName = $htName
            All          = (Test-PodeIsEmpty -Value $Name)
        }
        ScriptBlock = {
            param($options)

            # current request endpoint name - from webevent, smtpevent, or tcpevent
            $endpointName = $null
            if ($WebEvent) {
                $endpointName = $WebEvent.Endpoint.Name
            }
            elseif ($SmtpEvent) {
                $endpointName = $SmtpEvent.Endpoint.Name
            }
            elseif ($TcpEvent) {
                $endpointName = $TcpEvent.Endpoint.Name
            }

            if ($null -eq $endpointName) {
                return $null
            }

            # if the list is empty, or the list contains the endpoint name, then return the endpoint name
            if ($options.All -or $options.EndpointName.ContainsKey($endpointName)) {
                return $endpointName
            }

            # return null
            return $null
        }
    }
}


<#
.SYNOPSIS
    Creates a new Limit Header component.

.DESCRIPTION
    Creates a new Limit Header component. This support WebEvent and SmtpEvent headers.

.PARAMETER Name
    The name of the header(s) to check.

.PARAMETER Value
    The value of the header(s) to check.

.PARAMETER Group
    If supplied, the headers will be grouped by name, ignoring the value.
    For example, any headers matching "X-AuthToken" will be grouped as "X-AuthToken", and not "X-AuthToken=123".

.EXAMPLE
    New-PodeLimitHeaderComponent -Name 'X-AuthToken'

.EXAMPLE
    New-PodeLimitHeaderComponent -Name 'X-AuthToken', 'X-AuthKey'

.EXAMPLE
    New-PodeLimitHeaderComponent -Name 'X-AuthToken' -Value '12345'

.EXAMPLE
    New-PodeLimitHeaderComponent -Name 'X-AuthToken' -Group

.OUTPUTS
    A hashtable containing the options and scriptblock for the header component.
    The scriptblock will return the header name and value if found, or just the name if Group is supplied.
#>
function New-PodeLimitHeaderComponent {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Name,

        [Parameter()]
        [string[]]
        $Value,

        [switch]
        $Group
    )

    # convert header names into a hashtable for easier lookup
    $htHeaderName = @{}
    foreach ($h in $Name) {
        $htHeaderName[$h] = $true
    }

    # convert header values into a hashtable for easier lookup
    $htHeaderValue = @{}
    foreach ($h in $Value) {
        $htHeaderValue[$h] = $true
    }

    # pass back the header component
    return @{
        Options     = @{
            HeaderNames  = $htHeaderName
            HeaderValues = $htHeaderValue
            Group        = $Group.IsPresent
            AllValues    = (Test-PodeIsEmpty -Value $Value)
        }
        ScriptBlock = {
            param($options)

            # current request headers - from webevent or smtpevent
            $reqHeaders = @{}
            if ($WebEvent) {
                $reqHeaders = $WebEvent.Request.Headers
            }
            elseif ($SmtpEvent) {
                $reqHeaders = $SmtpEvent.Request.Headers
            }

            if ($reqHeaders.Count -eq 0) {
                return $null
            }

            # loop through each specified header
            foreach ($header in $options.HeaderNames.Keys) {
                # skip if the header is not in the request
                if (!$reqHeaders.ContainsKey($header)) {
                    continue
                }

                # are we checking any specific values - if not, return name/value or just name
                if ($options.AllValues) {
                    if ($options.Group) {
                        return $header
                    }
                    return "$($header)=$($reqHeaders[$header])"
                }

                # otherwise, check if the header value is in the list
                if ($options.HeaderValues.ContainsKey($reqHeaders[$header])) {
                    return "$($header)=$($reqHeaders[$header])"
                }
            }

            # return null
            return $null
        }
    }
}


<#
.SYNOPSIS
    Creates a new Limit IP component.

.DESCRIPTION
    Creates a new Limit IP component. This supports the WebEvent, SmtpEvent, and TcpEvent IPs.

.PARAMETER IP
    The IP address(es) to check. Supports raw IPs, subnets, local, and any.

.PARAMETER Location
    Where to get the IP from: RemoteAddress or XForwardedFor. (Default: RemoteAddress)

.PARAMETER XForwardedForType
    If the Location is XForwardedFor, which IP in the X-Forwarded-For header to use: Leftmost, Rightmost, or All. (Default: Leftmost)
    If Leftmost, the first IP in the X-Forwarded-For header will be used.
    If Rightmost, the last IP in the X-Forwarded-For header will be used.
    If All, all IPs in the X-Forwarded-For header will be used - at least one must match.

.PARAMETER Group
    If supplied, IPs in a subnet will be treated as a single entity.

.EXAMPLE
    New-PodeLimitIPComponent

.EXAMPLE
    New-PodeLimitIPComponent -IP '127.0.0.1'

.EXAMPLE
    New-PodeLimitIPComponent -IP '10.0.0.0/24'

.EXAMPLE
    New-PodeLimitIPComponent -IP 'localhost'

.EXAMPLE
    New-PodeLimitIPComponent -IP 'all'

.EXAMPLE
    New-PodeLimitIPComponent -IP '192.0.1.0/16' -Group

.EXAMPLE
    New-PodeLimitIPComponent -IP '10.0.0.1' -Location XForwardedFor

.EXAMPLE
    New-PodeLimitIPComponent -IP '192.0.1.0/16' -Group -Location XForwardedFor -XForwardedForType Rightmost

.OUTPUTS
    A hashtable containing the options and scriptblock for the IP component.
    The scriptblock will return the IP - or subnet for grouped - if found, or null if not.
#>
function New-PodeLimitIPComponent {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter()]
        [string[]]
        $IP,

        [Parameter()]
        [ValidateSet('RemoteAddress', 'XForwardedFor')]
        [string]
        $Location = 'RemoteAddress',

        [Parameter()]
        [ValidateSet('Leftmost', 'Rightmost', 'All')]
        [string]
        $XForwardedForType = 'Leftmost',

        [switch]
        $Group
    )

    # map of ip/subnet details
    $ipDetails = [ordered]@{
        Raw     = @{}
        Subnets = [ordered]@{}
        Any     = (Test-PodeIsEmpty -Value $IP)
        Local   = $false
    }

    # loop through each IP to parse details
    foreach ($_ip in $IP) {
        # is the ip valid?
        if (!(Test-PodeIPAddressLocal -IP $_ip) -and !(Test-PodeIPAddress -IP $_ip -IPOnly)) {
            # The IP address supplied is invalid: {0}
            throw ($PodeLocale.invalidIpAddressExceptionMessage -f $_ip)
        }

        # for any, just flag as any and continue
        if ([string]::IsNullOrWhiteSpace($_ip) -or (Test-PodeIPAddressAny -IP $_ip)) {
            $ipDetails.Any = $true
            continue
        }

        # for local, just flag as local and continue
        if (Test-PodeIPAddressLocal -IP $_ip) {
            $ipDetails.Local = $true
            continue
        }

        # for subnet, parse the subnet details
        if (Test-PodeIPAddressIsSubnetMask -IP $_ip) {
            $subnetRange = Get-PodeSubnetRange -SubnetMask $_ip
            $lowerDetails = Get-PodeIPAddress -IP $subnetRange.Lower
            $upperDetails = Get-PodeIPAddress -IP $subnetRange.Upper

            $ipDetails.Subnets[$_ip] = @{
                Family = $lowerDetails.Family
                Lower  = $lowerDetails.GetAddressBytes()
                Upper  = $upperDetails.GetAddressBytes()
            }
            continue
        }

        # for raw IP, just parse the IP details
        $details = Get-PodeIPAddress -IP $_ip
        $ipDetails.Raw[$_ip] = @{
            Family = $details.Family
        }
    }

    # pass back the IP component
    return @{
        Options     = @{
            IP                = $ipDetails
            Location          = $Location.ToLowerInvariant()
            XForwardedForType = $XForwardedForType.ToLowerInvariant()
            Group             = $Group.IsPresent
        }
        ScriptBlock = {
            param($options)

            # current request ip - for webevent, smtpevent, or tcpevent
            # for webevent, we can get the ip from the remote address or x-forwarded-for
            $ipAddresses = $null

            if ($WebEvent) {
                switch ($options.Location) {
                    'remoteaddress' {
                        $ipAddresses = @($WebEvent.Request.RemoteEndPoint.Address)
                    }
                    'xforwardedfor' {
                        $xForwardedFor = $WebEvent.Request.Headers['X-Forwarded-For']
                        if ([string]::IsNullOrEmpty($xForwardedFor)) {
                            return $null
                        }

                        $xffIps = $xForwardedFor.Split(',')
                        switch ($options.XForwardedForType) {
                            'leftmost' {
                                $ipAddresses = @(Get-PodeIPAddress -IP $xffIps[0].Trim() -ContainsPort)
                            }
                            'rightmost' {
                                $ipAddresses = @(Get-PodeIPAddress -IP $xffIps[-1].Trim() -ContainsPort)
                            }
                            'all' {
                                $ipAddresses = @(foreach ($ip in $xffIps) { Get-PodeIPAddress -IP $ip.Trim() -ContainsPort })
                            }
                        }
                    }
                }
            }
            elseif ($SmtpEvent) {
                $ipAddresses = @($SmtpEvent.Request.RemoteEndPoint.Address)
            }
            elseif ($TcpEvent) {
                $ipAddresses = @($TcpEvent.Request.RemoteEndPoint.Address)
            }

            # if we have no ip addresses, then return null
            if (($null -eq $ipAddresses) -or ($ipAddresses.Length -eq 0)) {
                return $null
            }

            # loop through each ip address
            for ($i = $ipAddresses.Length - 1; $i -ge 0; $i--) {
                $ip = $ipAddresses[$i]

                $ipDetails = @{
                    Value  = $ip.IPAddressToString
                    Family = $ip.AddressFamily
                    Bytes  = $ip.GetAddressBytes()
                }

                # is the ip in the Raw list?
                if ($options.IP.Raw.ContainsKey($ipDetails.Value)) {
                    return $ipDetails.Value
                }

                # is the ip in the Subnets list?
                foreach ($subnet in $options.IP.Subnets.Keys) {
                    $subnetDetails = $options.IP.Subnets[$subnet]
                    if ($subnetDetails.Family -ne $ipDetails.Family) {
                        continue
                    }

                    # if the ip is in the subnet range, then return the subnet
                    if (Test-PodeIPAddressInSubnet -IP $ipDetails.Bytes -Lower $subnetDetails.Lower -Upper $subnetDetails.Upper) {
                        if ($options.Group) {
                            return $subnet
                        }

                        return $ipDetails.Value
                    }
                }

                # is the ip local?
                if ($options.IP.Local) {
                    if ([System.Net.IPAddress]::IsLoopback($ip)) {
                        if ($options.Group) {
                            return 'local'
                        }

                        return $ipDetails.Value
                    }
                }

                # is any allowed?
                if ($options.IP.Any -and ($i -eq 0)) {
                    if ($options.Group) {
                        return '*'
                    }

                    return $ipDetails.Value
                }
            }

            # ip didn't match any rules
            return $null
        }
    }
}


<#
.SYNOPSIS
    Creates a new Limit HTTP Method component.

.DESCRIPTION
    Creates a new Limit HTTP Method component. This supports the WebEvent methods.

.PARAMETER Method
    The HTTP method(s) to check.

.EXAMPLE
    New-PodeLimitMethodComponent

.EXAMPLE
    New-PodeLimitMethodComponent -Method 'Get'

.EXAMPLE
    New-PodeLimitMethodComponent -Method 'Get', 'Post'

.OUTPUTS
    A hashtable containing the options and scriptblock for the method component.
    The scriptblock will return the method if found, or null if not.
#>
function New-PodeLimitMethodComponent {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter()]
        [ValidateSet('Connect', 'Delete', 'Get', 'Head', 'Merge', 'Options', 'Patch', 'Post', 'Put', 'Trace')]
        [string[]]
        $Method
    )

    # convert methods into a hashtable for easier lookup
    $htMethod = @{}
    foreach ($m in $Method) {
        $htMethod[$m] = $true
    }

    # pass back the method component
    return @{
        Options     = @{
            Method = $htMethod
            All    = (Test-PodeIsEmpty -Value $Method)
        }
        ScriptBlock = {
            param($options)

            # current request method
            $method = $WebEvent.Method
            if ([string]::IsNullOrEmpty($method)) {
                return $null
            }

            # if the list is empty, or the list contains the method, then return the method
            if ($options.All -or $options.Method.ContainsKey($method)) {
                return $method
            }

            # return null
            return $null
        }
    }
}


<#
.SYNOPSIS
    Creates a new Limit Route component.

.DESCRIPTION
    Creates a new Limit Route component. This supports the WebEvent routes.

.PARAMETER Path
    The route path(s) to check. This can be a full path, or a wildcard path.

.PARAMETER Group
    If supplied, the routes will be grouped by any wildcard, ignoring the full path.
    For example, any routes matching "/api/*" will be grouped as "/api/*", and not "/api/test" or "/api/test/hello".

.EXAMPLE
    New-PodeLimitRouteComponent -Path '/downloads'

.EXAMPLE
    New-PodeLimitRouteComponent -Path '/downloads', '/api/*'

.EXAMPLE
    New-PodeLimitRouteComponent -Path '/api/*' -Group

.OUTPUTS
    A hashtable containing the options and scriptblock for the route component.
    The scriptblock will return the route path if found, or null if not.
#>
function New-PodeLimitRouteComponent {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter()]
        [string[]]
        $Path,

        [switch]
        $Group
    )

    # convert paths into a hashtable for easier lookup
    $htPath = @{}
    foreach ($p in $Path) {
        $htPath[(ConvertTo-PodeRouteRegex -Path $p)] = $true
    }

    # pass back the route component
    return @{
        Options     = @{
            Path  = $htPath
            Group = $Group.IsPresent
            All   = (Test-PodeIsEmpty -Value $Path)
        }
        ScriptBlock = {
            param($options)

            # current request path
            $path = $WebEvent.Path
            if ([string]::IsNullOrEmpty($path)) {
                return $null
            }

            # if the list is empty, or the list contains the path, then return the path
            if ($options.All -or $options.Path.ContainsKey($path)) {
                return $path
            }

            # check if the path is a wildcard
            foreach ($key in $options.Path.Keys) {
                if ($path -imatch "^$($key)$") {
                    if ($options.Group) {
                        return $key
                    }

                    return $path
                }
            }

            # return null
            return $null
        }
    }
}


<#
.SYNOPSIS
    Removes an access rule.

.DESCRIPTION
    Removes an access rule.

.PARAMETER Name
    The name of the access rule.

.EXAMPLE
    Remove-PodeLimitAccessRule -Name 'rule1'
#>
function Remove-PodeLimitAccessRule {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Name
    )

    # remove the rule
    $null = $PodeContext.Server.Limits.Access.Rules.Remove($Name)
    $PodeContext.Server.Limits.Access.RulesAltered = $true

    # reset the flag if we have any allow rules
    $PodeContext.Server.Limits.Access.HaveAllowRules = ($PodeContext.Server.Limits.Access.Rules.Value |
            Where-Object { $_.Action -eq 'Allow' } |
            Measure-Object).Count -gt 0
}


<#
.SYNOPSIS
    Removes a rate limit rule.

.DESCRIPTION
    Removes a rate limit rule.

.PARAMETER Name
    The name of the rate limit rule.

.EXAMPLE
    Remove-PodeLimitRateRule -Name 'rule1'
#>
function Remove-PodeLimitRateRule {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Name
    )

    $null = $PodeContext.Server.Limits.Rate.Rules.Remove($Name)
    $PodeContext.Server.Limits.Rate.RulesAltered = $true
    Remove-PodeLimitRateTimer
}


<#
.SYNOPSIS
    Tests if an access rule exists.

.DESCRIPTION
    Tests if an access rule exists.

.PARAMETER Name
    The name of the access rule.

.EXAMPLE
    Test-PodeLimitAccessRule -Name 'rule1'

.OUTPUTS
    A boolean indicating if the access rule exists.
#>
function Test-PodeLimitAccessRule {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter()]
        [string]
        $Name
    )

    return $PodeContext.Server.Limits.Access.Rules.Contains($Name)
}


<#
.SYNOPSIS
    Tests if a rate limit rule exists.

.DESCRIPTION
    Tests if a rate limit rule exists.

.PARAMETER Name
    The name of the rate limit rule.

.EXAMPLE
    Test-PodeLimitRateRule -Name 'rule1'

.NOTES
    This function is used to test if a rate limit rule exists.
#>
function Test-PodeLimitRateRule {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter()]
        [string]
        $Name
    )

    return $PodeContext.Server.Limits.Rate.Rules.Contains($Name)
}


<#
.SYNOPSIS
    Updates an access rule.

.DESCRIPTION
    Updates an access rule.

.PARAMETER Name
    The name of the access rule.

.PARAMETER Action
    The action to take. Either 'Allow' or 'Deny'. If not supplied, the action will not be updated.

.PARAMETER StatusCode
    The status code to return. If not supplied, the status code will not be updated.

.EXAMPLE
    Update-PodeLimitAccessRule -Name 'rule1' -Action 'Deny'

.EXAMPLE
    Update-PodeLimitAccessRule -Name 'rule1' -StatusCode 404

.EXAMPLE
    Update-PodeLimitAccessRule -Name 'rule1' -Action 'Allow' -StatusCode 200
#>
function Update-PodeLimitAccessRule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [ValidateSet('Allow', 'Deny')]
        [string]
        $Action = $null,

        [Parameter()]
        [int]
        $StatusCode = -1
    )

    $rule = $PodeContext.Server.Limits.Access.Rules[$Name]
    if (!$rule) {
        # An access limit rule with the name '$($Name)' does not exist
        throw ($PodeLocale.accessLimitRuleDoesNotExistExceptionMessage -f $Name)
    }

    if (![string]::IsNullOrWhiteSpace($Action)) {
        $rule.Action = $Action
    }

    if ($StatusCode -gt 0) {
        $rule.StatusCode = $StatusCode
    }

    # reset the flag if we have any allow rules
    $PodeContext.Server.Limits.Access.HaveAllowRules = ($PodeContext.Server.Limits.Access.Rules.Value |
            Where-Object { $_.Action -eq 'Allow' } |
            Measure-Object).Count -gt 0
}


<#
.SYNOPSIS
    Updates a rate limit rule.

.DESCRIPTION
    Updates a rate limit rule.

.PARAMETER Name
    The name of the rate limit rule.

.PARAMETER Limit
    The new limit for the rule. If not supplied, the limit will not be updated.

.PARAMETER Duration
    The new duration for the rule, in milliseconds. If not supplied, the duration will not be updated.

.PARAMETER StatusCode
    The new status code for the rule. If not supplied, the status code will not be updated.

.EXAMPLE
    Update-PodeLimitRateRule -Name 'rule1' -Limit 10

.EXAMPLE
    Update-PodeLimitRateRule -Name 'rule1' -Duration 10000

.EXAMPLE
    Update-PodeLimitRateRule -Name 'rule1' -StatusCode 429

.EXAMPLE
    Update-PodeLimitRateRule -Name 'rule1' -Limit 10 -Duration 10000 -StatusCode 429
#>
function Update-PodeLimitRateRule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [int]
        $Limit = -1,

        [Parameter()]
        [int]
        $Duration = -1,

        [Parameter()]
        [int]
        $StatusCode = -1
    )

    $rule = $PodeContext.Server.Limits.Rate.Rules[$Name]
    if (!$rule) {
        # A rate limit rule with the name '$($Name)' does not exist
        throw ($PodeLocale.rateLimitRuleDoesNotExistExceptionMessage -f $Name)
    }

    if ($Limit -ge 0) {
        $rule.Limit = $Limit
    }

    if ($Duration -gt 0) {
        $rule.Duration = $Duration
    }

    if ($StatusCode -gt 0) {
        $rule.StatusCode = $StatusCode
    }
}


<#
.SYNOPSIS
    Adds a custom Logging method for parsing custom log items.

.DESCRIPTION
    Adds a custom Logging method for parsing custom log items.

.PARAMETER Name
    A unique Name for the Logging method.

.PARAMETER Method
    The Method to use for output the log entry (From New-PodeLoggingMethod).

.PARAMETER ScriptBlock
    The ScriptBlock defining logic that transforms an item, and returns it for outputting.

.PARAMETER ArgumentList
    An array of arguments to supply to the Custom Logger's ScriptBlock.

.EXAMPLE
    New-PodeLoggingMethod -Terminal | Add-PodeLogger -Name 'Main' -ScriptBlock { /* logic */ }
#>
function Add-PodeLogger {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [hashtable]
        $Method,

        [Parameter(Mandatory = $true)]
        [ValidateScript({
                if (Test-PodeIsEmpty $_) {
                    # A non-empty ScriptBlock is required for the logging method
                    throw ($PodeLocale.nonEmptyScriptBlockRequiredForLoggingMethodExceptionMessage)
                }

                return $true
            })]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [object[]]
        $ArgumentList
    )

    # ensure the name doesn't already exist
    if ($PodeContext.Server.Logging.Types.ContainsKey($Name)) {
        # Logging method already defined
        throw ($PodeLocale.loggingMethodAlreadyDefinedExceptionMessage -f $Name)
    }

    # ensure the Method contains a scriptblock
    if (Test-PodeIsEmpty $Method.ScriptBlock) {
        # The supplied output Method for the Logging method requires a valid ScriptBlock
        throw ($PodeLocale.loggingMethodRequiresValidScriptBlockExceptionMessage -f $Name)
    }

    # check for scoped vars
    $ScriptBlock, $usingVars = Convert-PodeScopedVariables -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState

    # add logging method to server
    $PodeContext.Server.Logging.Types[$Name] = @{
        Method         = $Method
        ScriptBlock    = $ScriptBlock
        UsingVariables = $usingVars
        Arguments      = $ArgumentList
    }
}


<#
.SYNOPSIS
    Clears all Logging methods that have been configured.

.DESCRIPTION
    Clears all Logging methods that have been configured.

.EXAMPLE
    Clear-PodeLoggers
#>
function Clear-PodeLoggers {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    [CmdletBinding()]
    param()

    $PodeContext.Server.Logging.Types.Clear()
}


<#
.SYNOPSIS
    Disables Error Logging.

.DESCRIPTION
    Disables Error Logging.

.EXAMPLE
    Disable-PodeErrorLogging
#>
function Disable-PodeErrorLogging {
    [CmdletBinding()]
    param()

    Remove-PodeLogger -Name (Get-PodeErrorLoggingName)
}


<#
.SYNOPSIS
    Disables Request Logging.

.DESCRIPTION
    Disables Request Logging.

.EXAMPLE
    Disable-PodeRequestLogging
#>
function Disable-PodeRequestLogging {
    [CmdletBinding()]
    param()

    Remove-PodeLogger -Name (Get-PodeRequestLoggingName)
}


<#
.SYNOPSIS
    Enables Error Logging using a supplied output method.

.DESCRIPTION
    Enables Error Logging using a supplied output method.

.PARAMETER Method
    The Method to use for output the log entry (From New-PodeLoggingMethod).

.PARAMETER Levels
    The Levels of errors that should be logged (default is Error).

.PARAMETER Raw
    If supplied, the log item returned will be the raw Error item as a hashtable and not a string (for Custom methods).

.EXAMPLE
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging
#>
function Enable-PodeErrorLogging {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [hashtable]
        $Method,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('Error', 'Warning', 'Informational', 'Verbose', 'Debug', '*')]
        [string[]]
        $Levels = @('Error'),

        [switch]
        $Raw
    )

    $name = Get-PodeErrorLoggingName

    # error if it's already enabled
    if ($PodeContext.Server.Logging.Types.Contains($name)) {
        # Error Logging has already been enabled
        throw ($PodeLocale.errorLoggingAlreadyEnabledExceptionMessage)
    }

    # ensure the Method contains a scriptblock
    if (Test-PodeIsEmpty $Method.ScriptBlock) {
        # The supplied output Method for Error Logging requires a valid ScriptBlock
        throw ($PodeLocale.loggingMethodRequiresValidScriptBlockExceptionMessage -f 'Error')
    }

    # all errors?
    if ($Levels -contains '*') {
        $Levels = @('Error', 'Warning', 'Informational', 'Verbose', 'Debug')
    }

    # add the error logger
    $PodeContext.Server.Logging.Types[$name] = @{
        Method      = $Method
        ScriptBlock = (Get-PodeLoggingInbuiltType -Type Errors)
        Arguments   = @{
            Raw    = $Raw
            Levels = $Levels
        }
    }
}


<#
.SYNOPSIS
    Enables Request Logging using a supplied output method.

.DESCRIPTION
    Enables Request Logging using a supplied output method.

.PARAMETER Method
    The Method to use for output the log entry (From New-PodeLoggingMethod).

.PARAMETER UsernameProperty
    An optional property path within the $WebEvent.Auth.User object for the user's Username. (Default: Username).

.PARAMETER Raw
    If supplied, the log item returned will be the raw Request item as a hashtable and not a string (for Custom methods).

.EXAMPLE
    New-PodeLoggingMethod -Terminal | Enable-PodeRequestLogging
#>
function Enable-PodeRequestLogging {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [hashtable]
        $Method,

        [Parameter()]
        [string]
        $UsernameProperty,

        [switch]
        $Raw
    )

    Test-PodeIsServerless -FunctionName 'Enable-PodeRequestLogging' -ThrowError

    $name = Get-PodeRequestLoggingName

    # error if it's already enabled
    if ($PodeContext.Server.Logging.Types.Contains($name)) {
        # Request Logging has already been enabled
        throw ($PodeLocale.requestLoggingAlreadyEnabledExceptionMessage)
    }

    # ensure the Method contains a scriptblock
    if (Test-PodeIsEmpty $Method.ScriptBlock) {
        # The supplied output Method for Request Logging requires a valid ScriptBlock
        throw ($PodeLocale.loggingMethodRequiresValidScriptBlockExceptionMessage -f 'Request')
    }

    # username property
    if ([string]::IsNullOrWhiteSpace($UsernameProperty)) {
        $UsernameProperty = 'Username'
    }

    # add the request logger
    $PodeContext.Server.Logging.Types[$name] = @{
        Method      = $Method
        ScriptBlock = (Get-PodeLoggingInbuiltType -Type Requests)
        Properties  = @{
            Username = $UsernameProperty
        }
        Arguments   = @{
            Raw = $Raw
        }
    }
}


<#
.SYNOPSIS
    Create a new method of outputting logs.

.DESCRIPTION
    Create a new method of outputting logs.

.PARAMETER Terminal
    If supplied, will use the inbuilt Terminal logging output method.

.PARAMETER File
    If supplied, will use the inbuilt File logging output method.

.PARAMETER Path
    The File Path of where to store the logs.

.PARAMETER Name
    The File Name to prepend new log files using.

.PARAMETER EventViewer
    If supplied, will use the inbuilt Event Viewer logging output method.

.PARAMETER EventLogName
    Optional Log Name for the Event Viewer (Default: Application)

.PARAMETER Source
    Optional Source for the Event Viewer (Default: Pode)

.PARAMETER EventID
    Optional EventID for the Event Viewer (Default: 0)

.PARAMETER Batch
    An optional batch size to write log items in bulk (Default: 1)

.PARAMETER BatchTimeout
    An optional batch timeout, in seconds, to send items off for writing if a log item isn't received (Default: 0)

.PARAMETER MaxDays
    The maximum number of days to keep logs, before Pode automatically removes them.

.PARAMETER MaxSize
    The maximum size of a log file, before Pode starts writing to a new log file.

.PARAMETER Custom
    If supplied, will allow you to create a Custom Logging output method.

.PARAMETER ScriptBlock
    The ScriptBlock that defines how to output a log item.

.PARAMETER ArgumentList
    An array of arguments to supply to the Custom Logging output method's ScriptBlock.

.EXAMPLE
    $term_logging = New-PodeLoggingMethod -Terminal

.EXAMPLE
    $file_logging = New-PodeLoggingMethod -File -Path ./logs -Name 'requests'

.EXAMPLE
    $custom_logging = New-PodeLoggingMethod -Custom -ScriptBlock { /* logic */ }
#>
function New-PodeLoggingMethod {
    [CmdletBinding(DefaultParameterSetName = 'Terminal')]
    [OutputType([hashtable])]
    param(
        [Parameter(ParameterSetName = 'Terminal')]
        [switch]
        $Terminal,

        [Parameter(ParameterSetName = 'File')]
        [switch]
        $File,

        [Parameter(ParameterSetName = 'File')]
        [string]
        $Path = './logs',

        [Parameter(Mandatory = $true, ParameterSetName = 'File')]
        [string]
        $Name,

        [Parameter(ParameterSetName = 'EventViewer')]
        [switch]
        $EventViewer,

        [Parameter(ParameterSetName = 'EventViewer')]
        [string]
        $EventLogName = 'Application',

        [Parameter(ParameterSetName = 'EventViewer')]
        [string]
        $Source = 'Pode',

        [Parameter(ParameterSetName = 'EventViewer')]
        [int]
        $EventID = 0,

        [Parameter()]
        [int]
        $Batch = 1,

        [Parameter()]
        [int]
        $BatchTimeout = 0,

        [Parameter(ParameterSetName = 'File')]
        [ValidateScript({
                if ($_ -lt 0) {
                    # MaxDays must be 0 or greater, but got
                    throw ($PodeLocale.maxDaysInvalidExceptionMessage -f $MaxDays)
                }

                return $true
            })]
        [int]
        $MaxDays = 0,

        [Parameter(ParameterSetName = 'File')]
        [ValidateScript({
                if ($_ -lt 0) {
                    # MaxSize must be 0 or greater, but got
                    throw ($PodeLocale.maxSizeInvalidExceptionMessage -f $MaxSize)
                }

                return $true
            })]
        [int]
        $MaxSize = 0,

        [Parameter(ParameterSetName = 'Custom')]
        [switch]
        $Custom,

        [Parameter(Mandatory = $true, ParameterSetName = 'Custom')]
        [ValidateScript({
                if (Test-PodeIsEmpty $_) {
                    # A non-empty ScriptBlock is required for the Custom logging output method
                    throw ($PodeLocale.nonEmptyScriptBlockRequiredForCustomLoggingExceptionMessage)
                }

                return $true
            })]
        [scriptblock]
        $ScriptBlock,

        [Parameter(ParameterSetName = 'Custom')]
        [object[]]
        $ArgumentList
    )

    # batch details
    $batchInfo = @{
        Size       = $Batch
        Timeout    = $BatchTimeout
        LastUpdate = $null
        Items      = @()
        RawItems   = @()
    }

    # return info on appropriate logging type
    switch ($PSCmdlet.ParameterSetName.ToLowerInvariant()) {
        'terminal' {
            return @{
                ScriptBlock = (Get-PodeLoggingTerminalMethod)
                Batch       = $batchInfo
                Arguments   = @{}
            }
        }

        'file' {
            $Path = (Protect-PodeValue -Value $Path -Default './logs')
            $Path = (Get-PodeRelativePath -Path $Path -JoinRoot)
            $null = New-Item -Path $Path -ItemType Directory -Force

            return @{
                ScriptBlock = (Get-PodeLoggingFileMethod)
                Batch       = $batchInfo
                Arguments   = @{
                    Name          = $Name
                    Path          = $Path
                    MaxDays       = $MaxDays
                    MaxSize       = $MaxSize
                    FileId        = 0
                    Date          = $null
                    NextClearDown = [datetime]::Now.Date
                }
            }
        }

        'eventviewer' {
            # only windows
            if (!(Test-PodeIsWindows)) {
                # Event Viewer logging only supported on Windows
                throw ($PodeLocale.eventViewerLoggingSupportedOnWindowsOnlyExceptionMessage)
            }

            # create source
            if (![System.Diagnostics.EventLog]::SourceExists($Source)) {
                $null = [System.Diagnostics.EventLog]::CreateEventSource($Source, $EventLogName)
            }

            return @{
                ScriptBlock = (Get-PodeLoggingEventViewerMethod)
                Batch       = $batchInfo
                Arguments   = @{
                    LogName = $EventLogName
                    Source  = $Source
                    ID      = $EventID
                }
            }
        }

        'custom' {
            $ScriptBlock, $usingVars = Convert-PodeScopedVariables -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState

            return @{
                ScriptBlock    = $ScriptBlock
                UsingVariables = $usingVars
                Batch          = $batchInfo
                Arguments      = $ArgumentList
            }
        }
    }
}


<#
.SYNOPSIS
    Masks values within a log item to protect sensitive information.

.DESCRIPTION
    Masks values within a log item, or any string, to protect sensitive information.
    Patterns, and the Mask, can be configured via the server.psd1 configuration file.

.PARAMETER Item
    The string Item to mask values.

.EXAMPLE
    $value = Protect-PodeLogItem -Item 'Username=Morty, Password=Hunter2'
#>
function Protect-PodeLogItem {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(ValueFromPipeline = $true)]
        [string]
        $Item
    )

    # do nothing if there are no masks
    if (Test-PodeIsEmpty $PodeContext.Server.Logging.Masking.Patterns) {
        return $item
    }

    # attempt to apply each mask
    foreach ($mask in $PodeContext.Server.Logging.Masking.Patterns) {
        if ($Item -imatch $mask) {
            # has both keep before/after
            if ($Matches.ContainsKey('keep_before') -and $Matches.ContainsKey('keep_after')) {
                $Item = ($Item -ireplace $mask, "`${keep_before}$($PodeContext.Server.Logging.Masking.Mask)`${keep_after}")
            }

            # has just keep before
            elseif ($Matches.ContainsKey('keep_before')) {
                $Item = ($Item -ireplace $mask, "`${keep_before}$($PodeContext.Server.Logging.Masking.Mask)")
            }

            # has just keep after
            elseif ($Matches.ContainsKey('keep_after')) {
                $Item = ($Item -ireplace $mask, "$($PodeContext.Server.Logging.Masking.Mask)`${keep_after}")
            }

            # normal mask
            else {
                $Item = ($Item -ireplace $mask, $PodeContext.Server.Logging.Masking.Mask)
            }
        }
    }

    return $Item
}


<#
.SYNOPSIS
    Removes a configured Logging method.

.DESCRIPTION
    Removes a configured Logging method.

.PARAMETER Name
    The Name of the Logging method.

.EXAMPLE
    Remove-PodeLogger -Name 'LogName'
#>
function Remove-PodeLogger {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]
        $Name
    )

    $null = $PodeContext.Server.Logging.Types.Remove($Name)
}


<#
.SYNOPSIS
    Automatically loads logging ps1 files

.DESCRIPTION
    Automatically loads logging ps1 files from either a /logging folder, or a custom folder. Saves space dot-sourcing them all one-by-one.

.PARAMETER Path
    Optional Path to a folder containing ps1 files, can be relative or literal.

.EXAMPLE
    Use-PodeLogging

.EXAMPLE
    Use-PodeLogging -Path './my-logging'
#>
function Use-PodeLogging {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Path
    )

    Use-PodeFolder -Path $Path -DefaultPath 'logging'
}


<#
.SYNOPSIS
    Writes and Exception or ErrorRecord using the inbuilt error logging.

.DESCRIPTION
    Writes and Exception or ErrorRecord using the inbuilt error logging.

.PARAMETER Exception
    An Exception to write.

.PARAMETER ErrorRecord
    An ErrorRecord to write.

.PARAMETER Level
    The Level of the error being logged.

.PARAMETER CheckInnerException
    If supplied, any exceptions are check for inner exceptions. If one is present, this is also logged.

.EXAMPLE
    try { /* logic */ } catch { $_ | Write-PodeErrorLog }

.EXAMPLE
    [System.Exception]::new('error message') | Write-PodeErrorLog
#>
function Write-PodeErrorLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = 'Exception')]
        [System.Exception]
        $Exception,

        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = 'Error')]
        [System.Management.Automation.ErrorRecord]
        $ErrorRecord,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('Error', 'Warning', 'Informational', 'Verbose', 'Debug')]
        [string]
        $Level = 'Error',

        [Parameter(ParameterSetName = 'Exception')]
        [switch]
        $CheckInnerException
    )

    # do nothing if logging is disabled, or error logging isn't setup
    $name = Get-PodeErrorLoggingName
    if (!(Test-PodeLoggerEnabled -Name $name)) {
        return
    }

    # do nothing if the error level isn't present
    $levels = @(Get-PodeErrorLoggingLevel)
    if ($levels -inotcontains $Level) {
        return
    }

    # build error object for what we need
    switch ($PSCmdlet.ParameterSetName.ToLowerInvariant()) {
        'exception' {
            $item = @{
                Category   = $Exception.Source
                Message    = $Exception.Message
                StackTrace = $Exception.StackTrace
            }
        }

        'error' {
            $item = @{
                Category   = $ErrorRecord.CategoryInfo.ToString()
                Message    = $ErrorRecord.Exception.Message
                StackTrace = $ErrorRecord.ScriptStackTrace
            }
        }
    }

    # add general info
    $item['Server'] = $PodeContext.Server.ComputerName
    $item['Level'] = $Level
    $item['Date'] = [datetime]::Now
    $item['ThreadId'] = [int]$ThreadId

    # add the item to be processed
    $null = $PodeContext.LogsToProcess.Add(@{
            Name = $name
            Item = $item
        })

    # for exceptions, check the inner exception
    if ($CheckInnerException -and ($null -ne $Exception.InnerException) -and ![string]::IsNullOrWhiteSpace($Exception.InnerException.Message)) {
        $Exception.InnerException | Write-PodeErrorLog
    }
}


<#
.SYNOPSIS
    Write an object to a configured custom Logging method.

.DESCRIPTION
    Write an object to a configured custom Logging method.

.PARAMETER Name
    The Name of the Logging method.

.PARAMETER InputObject
    The Object to write.

.EXAMPLE
    $object | Write-PodeLog -Name 'LogName'
#>
function Write-PodeLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [object]
        $InputObject
    )

    # do nothing if logging is disabled, or logger isn't setup
    if (!(Test-PodeLoggerEnabled -Name $Name)) {
        return
    }

    # add the item to be processed
    $null = $PodeContext.LogsToProcess.Add(@{
            Name = $Name
            Item = $InputObject
        })
}


<#
.SYNOPSIS
    Returns the count of active requests.

.DESCRIPTION
    Returns the count of all, processing, or queued active requests.

.PARAMETER CountType
    The count type to return. (Default: Total)

.EXAMPLE
    Get-PodeServerActiveRequestMetric

.EXAMPLE
    Get-PodeServerActiveRequestMetric -CountType Queued
#>
function Get-PodeServerActiveRequestMetric {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateSet('Total', 'Queued', 'Processing')]
        [string]
        $CountType = 'Total'
    )

    switch ($CountType.ToLowerInvariant()) {
        'total' {
            return $PodeContext.Server.Signals.Listener.Contexts.Count
        }

        'queued' {
            return $PodeContext.Server.Signals.Listener.Contexts.QueuedCount
        }

        'processing' {
            return $PodeContext.Server.Signals.Listener.Contexts.ProcessingCount
        }
    }
}


<#
.SYNOPSIS
    Returns the count of active signals.

.DESCRIPTION
    Returns the count of all, processing, or queued active signals; for either server or client signals.

.PARAMETER Type
    The type of signal to return. (Default: Total)

.PARAMETER CountType
    The count type to return. (Default: Total)

.EXAMPLE
    Get-PodeServerActiveSignalMetric

.EXAMPLE
    Get-PodeServerActiveSignalMetric -Type Client -CountType Queued
#>
function Get-PodeServerActiveSignalMetric {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateSet('Total', 'Server', 'Client')]
        [string]
        $Type = 'Total',

        [Parameter()]
        [ValidateSet('Total', 'Queued', 'Processing')]
        [string]
        $CountType = 'Total'
    )

    switch ($Type.ToLowerInvariant()) {
        'total' {
            switch ($CountType.ToLowerInvariant()) {
                'total' {
                    return $PodeContext.Server.Signals.Listener.ServerSignals.Count + $PodeContext.Server.Signals.Listener.ClientSignals.Count
                }

                'queued' {
                    return $PodeContext.Server.Signals.Listener.ServerSignals.QueuedCount + $PodeContext.Server.Signals.Listener.ClientSignals.QueuedCount
                }

                'processing' {
                    return $PodeContext.Server.Signals.Listener.ServerSignals.ProcessingCount + $PodeContext.Server.Signals.Listener.ClientSignals.ProcessingCount
                }
            }
        }

        'server' {
            switch ($CountType.ToLowerInvariant()) {
                'total' {
                    return $PodeContext.Server.Signals.Listener.ServerSignals.Count
                }

                'queued' {
                    return $PodeContext.Server.Signals.Listener.ServerSignals.QueuedCount
                }

                'processing' {
                    return $PodeContext.Server.Signals.Listener.ServerSignals.ProcessingCount
                }
            }
        }

        'client' {
            switch ($CountType.ToLowerInvariant()) {
                'total' {
                    return $PodeContext.Server.Signals.Listener.ClientSignals.Count
                }

                'queued' {
                    return $PodeContext.Server.Signals.Listener.ClientSignals.QueuedCount
                }

                'processing' {
                    return $PodeContext.Server.Signals.Listener.ClientSignals.ProcessingCount
                }
            }
        }
    }
}


<#
.SYNOPSIS
    Returns the total number of requests/per status code the Server has receieved.

.DESCRIPTION
    Returns the total number of requests/per status code the Server has receieved.

.PARAMETER StatusCode
    If supplied, will return the total number of requests for a specific StatusCode.

.PARAMETER Total
    If supplied, will return the Total number of Requests.

.EXAMPLE
    $totalReqs = Get-PodeServerRequestMetric -Total

.EXAMPLE
    $statusReqs = Get-PodeServerRequestMetric

.EXAMPLE
    $404Reqs = Get-PodeServerRequestMetric -StatusCode 404
#>
function Get-PodeServerRequestMetric {
    [CmdletBinding(DefaultParameterSetName = 'StatusCode')]
    [OutputType([long])]
    param(
        [Parameter(ParameterSetName = 'StatusCode')]
        [int]
        $StatusCode = 0,

        [Parameter(ParameterSetName = 'Total')]
        [switch]
        $Total
    )

    if ($Total) {
        return $PodeContext.Metrics.Requests.Total
    }

    if (($StatusCode -le 0)) {
        return $PodeContext.Metrics.Requests.StatusCodes
    }

    $strCode = "$($StatusCode)"
    if (!$PodeContext.Metrics.Requests.StatusCodes.ContainsKey($strCode)) {
        return 0L
    }

    return $PodeContext.Metrics.Requests.StatusCodes[$strCode]
}


<#
.SYNOPSIS
    Returns the number of times the server has restarted.

.DESCRIPTION
    Returns the number of times the server has restarted.

.EXAMPLE
    $restarts = Get-PodeServerRestartCount
#>
function Get-PodeServerRestartCount {
    [CmdletBinding()]
    param()

    return $PodeContext.Metrics.Server.RestartCount
}


<#
.SYNOPSIS
    Returns the total number of Signal requests the Server has receieved.

.DESCRIPTION
    Returns the total number of Signal requests the Server has receieved.

.EXAMPLE
    $totalReqs = Get-PodeServerSignalMetric
#>
function Get-PodeServerSignalMetric {
    [CmdletBinding()]
    param()

    return $PodeContext.Metrics.Signals.Total
}


<#
.SYNOPSIS
    Retrieves the server uptime in milliseconds or a human-readable format.

.DESCRIPTION
    The `Get-PodeServerUptime` function calculates the server's uptime since its last start or total uptime since initial load, depending on the `-Total` switch.
    By default, the uptime is returned in milliseconds. When the `-Format` parameter is used, the uptime can be returned in various human-readable styles:
    - `Milliseconds` (default): Raw uptime in milliseconds.
    - `Concise`: A short format like "1d 2h 3m".
    - `Compact`: A condensed format like "01:10:17:36".
    - `Verbose`: A detailed format like "1 day, 2 hours, 3 minutes, 5 seconds, 200 milliseconds".
    The `-ExcludeMilliseconds` switch allows removal of milliseconds from human-readable output.

.PARAMETER Total
    Retrieves the total server uptime since the initial load, regardless of any restarts.

.PARAMETER Format
    Specifies the desired output format for the uptime.
    Allowed values:
    - `Milliseconds` (default): Uptime in raw milliseconds.
    - `Concise`: Human-readable in a short form (e.g., "1d 2h 3m").
    - `Compact`: Condensed form (e.g., "01:10:17:36").
    - `Verbose`: Detailed format (e.g., "1 day, 2 hours, 3 minutes, 5 seconds").

.PARAMETER ExcludeMilliseconds
    Omits milliseconds from the human-readable output when `-Format` is not `Milliseconds`.

.EXAMPLE
    $currentUptime = Get-PodeServerUptime
    # Output: 123456789 (milliseconds)

.EXAMPLE
    $totalUptime = Get-PodeServerUptime -Total
    # Output: 987654321 (milliseconds)

.EXAMPLE
    $readableUptime = Get-PodeServerUptime -Format Concise
    # Output: "1d 10h 17m"

.EXAMPLE
    $verboseUptime = Get-PodeServerUptime -Format Verbose
    # Output: "1 day, 10 hours, 17 minutes, 36 seconds, 789 milliseconds"

.EXAMPLE
    $compactUptime = Get-PodeServerUptime -Format Compact
    # Output: "01:10:17:36"

.EXAMPLE
    $compactUptimeNoMs = Get-PodeServerUptime -Format Compact -ExcludeMilliseconds
    # Output: "01:10:17:36"

.NOTES
    This function is part of Pode's utility metrics to monitor server uptime.
#>
function Get-PodeServerUptime {
    [CmdletBinding()]
    [OutputType([long], [string])]
    param(
        [switch]
        $Total,

        [Parameter()]
        [ValidateSet('Milliseconds', 'Concise', 'Compact', 'Verbose')]
        [string]
        $Format = 'Milliseconds',

        [switch]
        $ExcludeMilliseconds
    )

    # Determine the start time based on the -Total switch
    # Default: Uses the last start time; -Total: Uses the initial load time
    $time = $PodeContext.Metrics.Server.StartTime
    if ($Total) {
        $time = $PodeContext.Metrics.Server.InitialLoadTime
    }

    # Calculate uptime in milliseconds
    $uptimeMilliseconds = [long]([datetime]::UtcNow - $time).TotalMilliseconds

    # Return uptime in milliseconds if no readable format is requested
    if ($Format -ieq 'Milliseconds') {
        return $uptimeMilliseconds
    }

    # Convert uptime to a human-readable format
    return Convert-PodeMillisecondsToReadable -Milliseconds $uptimeMilliseconds -Format $Format -ExcludeMilliseconds:$ExcludeMilliseconds
}


<#
.SYNOPSIS
    Adds a custom body parser middleware.

.DESCRIPTION
    Adds a custom body parser middleware script for a content-type, which will be used if a payload is sent with a Request.

.PARAMETER ContentType
    The ContentType of the custom body parser.

.PARAMETER ScriptBlock
    The ScriptBlock that will parse the body content, and return the result.

.EXAMPLE
    Add-PodeBodyParser -ContentType 'application/json' -ScriptBlock { param($body) /* parsing logic */ }
#>
function Add-PodeBodyParser {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidatePattern('^\w+\/[\w\.\+-]+$')]
        [string]
        $ContentType,

        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [scriptblock]
        $ScriptBlock
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
        # if a parser for the type already exists, fail
        if ($PodeContext.Server.BodyParsers.ContainsKey($ContentType)) {
            # A body-parser is already defined for the content-type
            throw ($PodeLocale.bodyParserAlreadyDefinedForContentTypeExceptionMessage -f $ContentType)
        }

        # check for scoped vars
        $ScriptBlock, $usingVars = Convert-PodeScopedVariables -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState

        $PodeContext.Server.BodyParsers[$ContentType] = @{
            ScriptBlock    = $ScriptBlock
            UsingVariables = $usingVars
        }
    }
}


<#
.SYNOPSIS
    Adds a new Middleware to be invoked before every Route, or certain Routes.

.DESCRIPTION
    Adds a new Middleware to be invoked before every Route, or certain Routes. ScriptBlock should return $true to continue execution, or $false to stop.

.PARAMETER Name
    The Name of the Middleware.

.PARAMETER ScriptBlock
    The Script defining the logic of the Middleware. Should return $true to continue execution, or $false to stop.

.PARAMETER InputObject
    A Middleware HashTable from New-PodeMiddleware, or from certain other functions that return Middleware as a HashTable.

.PARAMETER Route
    A Route path for which Routes this Middleware should only be invoked against.

.PARAMETER ArgumentList
    An array of arguments to supply to the Middleware's ScriptBlock.

.OUTPUTS
    Boolean. ScriptBlock should return $true to continue to the next middleware/route, or return $false to stop execution.

.EXAMPLE
    Add-PodeMiddleware -Name 'BlockAgents' -ScriptBlock { /* logic */ }

.EXAMPLE
    Add-PodeMiddleware -Name 'CheckEmailOnApi' -Route '/api/*' -ScriptBlock { /* logic */ }
#>
function Add-PodeMiddleware {
    [CmdletBinding(DefaultParameterSetName = 'Script')]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true, ParameterSetName = 'Script')]
        [scriptblock]
        $ScriptBlock,

        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ParameterSetName = 'Input')]
        [hashtable]
        $InputObject,

        [Parameter()]
        [string]
        $Route,

        [Parameter()]
        [object[]]
        $ArgumentList
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
        # ensure name doesn't already exist
        if (($PodeContext.Server.Middleware | Where-Object { $_.Name -ieq $Name } | Measure-Object).Count -gt 0) {
            # [Middleware] Name: Middleware already defined
            throw ($PodeLocale.middlewareAlreadyDefinedExceptionMessage -f $Name)

        }

        # if it's a script - call New-PodeMiddleware
        if ($PSCmdlet.ParameterSetName -ieq 'script') {
            $InputObject = (New-PodeMiddlewareInternal `
                    -ScriptBlock $ScriptBlock `
                    -Route $Route `
                    -ArgumentList $ArgumentList `
                    -PSSession $PSCmdlet.SessionState)
        }
        else {
            $Route = ConvertTo-PodeRouteRegex -Path $Route
            $InputObject.Route = Protect-PodeValue -Value $Route -Default $InputObject.Route
            $InputObject.Options = Protect-PodeValue -Value $Options -Default $InputObject.Options
        }

        # ensure we have a script to run
        if (Test-PodeIsEmpty $InputObject.Logic) {
            # [Middleware]: No logic supplied in ScriptBlock
            throw ($PodeLocale.middlewareNoLogicSuppliedExceptionMessage)
        }

        # set name, and override route/args
        $InputObject.Name = $Name

        # add the logic to array of middleware that needs to be run
        $PodeContext.Server.Middleware += $InputObject
    }
}


<#
.SYNOPSIS
    Removes all user defined Middleware.

.DESCRIPTION
    Removes all user defined Middleware.

.EXAMPLE
    Clear-PodeMiddleware
#>
function Clear-PodeMiddleware {
    [CmdletBinding()]
    param()

    $PodeContext.Server.Middleware = @()
}


<#
.SYNOPSIS
    Enables Middleware for verifying CSRF tokens on Requests.

.DESCRIPTION
    Enables Middleware for verifying CSRF tokens on Requests, with configurable HTTP methods to ignore verification.

.PARAMETER IgnoreMethods
    An array of HTTP methods to ignore CSRF verification.

.PARAMETER Secret
    A secret to use when signing cookies - for when using CSRF with cookies.

.PARAMETER UseCookies
    If supplied, CSRF will used cookies rather than sessions.

.EXAMPLE
    Enable-PodeCsrfMiddleware -IgnoreMethods @('Get', 'Trace')

.EXAMPLE
    Enable-PodeCsrfMiddleware -Secret 'some-secret' -UseCookies
#>
function Enable-PodeCsrfMiddleware {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateSet('Connect', 'Delete', 'Get', 'Head', 'Merge', 'Options', 'Patch', 'Post', 'Put', 'Trace')]
        [string[]]
        $IgnoreMethods = @('Get', 'Head', 'Options', 'Trace'),

        [Parameter(ParameterSetName = 'Cookies')]
        [string]
        $Secret,

        [Parameter(ParameterSetName = 'Cookies')]
        [switch]
        $UseCookies
    )

    Initialize-PodeCsrf -IgnoreMethods $IgnoreMethods -Secret $Secret -UseCookies:$UseCookies

    # return scriptblock for the csrf middleware
    $script = {
        # if the current route method is ignored, just return
        $ignored = @($PodeContext.Server.Cookies.Csrf.IgnoredMethods)
        if (!(Test-PodeIsEmpty $ignored) -and ($ignored -icontains $WebEvent.Method)) {
            return $true
        }

        # if there's not a secret, generate and store it
        $secret = New-PodeCsrfSecret

        # verify the token on the request, if invalid, throw a 403
        $token = Get-PodeCsrfToken

        if (!(Test-PodeCsrfToken -Secret $secret -Token $token)) {
            Set-PodeResponseStatus -Code 403 -Description 'Invalid CSRF Token'
            return $false
        }

        # token is valid, move along
        return $true
    }

    (New-PodeMiddleware -ScriptBlock $script) | Add-PodeMiddleware -Name '__pode_mw_csrf__'
}


<#
.SYNOPSIS
    Returns adhoc CSRF CSRF verification Middleware, for use on Routes.

.DESCRIPTION
    Returns adhoc CSRF CSRF verification Middleware, for use on Routes.

.EXAMPLE
    $csrf = Get-PodeCsrfMiddleware
    Add-PodeRoute -Method Get -Path '/cpu' -Middleware $csrf -ScriptBlock { /* logic */ }
#>
function Get-PodeCsrfMiddleware {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    # fail if the csrf logic hasn't been initialised
    if (!(Test-PodeCsrfConfigured)) {
        # CSRF Middleware has not been initialized
        throw ($PodeLocale.csrfMiddlewareNotInitializedExceptionMessage)
    }

    # return scriptblock for the csrf route middleware to test tokens
    $script = {
        # if there's not a secret, generate and store it
        $secret = New-PodeCsrfSecret

        # verify the token on the request, if invalid, throw a 403
        $token = Get-PodeCsrfToken

        if (!(Test-PodeCsrfToken -Secret $secret -Token $token)) {
            Set-PodeResponseStatus -Code 403 -Description 'Invalid CSRF Token'
            return $false
        }

        # token is valid, move along
        return $true
    }

    return (New-PodeMiddleware -ScriptBlock $script)
}


<#
.SYNOPSIS
    Initialises CSRF within Pode for adhoc usage.

.DESCRIPTION
    Initialises CSRF within Pode for adhoc usage, with configurable HTTP methods to ignore verification.

.PARAMETER IgnoreMethods
    An array of HTTP methods to ignore CSRF verification.

.PARAMETER Secret
    A secret to use when signing cookies - for when using CSRF with cookies.

.PARAMETER UseCookies
    If supplied, CSRF will used cookies rather than sessions.

.EXAMPLE
    Initialize-PodeCsrf -IgnoreMethods @('Get', 'Trace')

.EXAMPLE
    Initialize-PodeCsrf -Secret 'some-secret' -UseCookies
#>
function Initialize-PodeCsrf {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateSet('Connect', 'Delete', 'Get', 'Head', 'Merge', 'Options', 'Patch', 'Post', 'Put', 'Trace')]
        [string[]]
        $IgnoreMethods = @('Get', 'Head', 'Options', 'Trace'),

        [Parameter()]
        [string]
        $Secret,

        [switch]
        $UseCookies
    )

    # check that csrf logic hasn't already been intialised
    if (Test-PodeCsrfConfigured) {
        return
    }

    # if sessions haven't been setup and we're not using cookies, error
    if (!$UseCookies -and !(Test-PodeSessionsEnabled)) {
        # Sessions are required to use CSRF unless you want to use cookies
        throw ($PodeLocale.sessionsRequiredForCsrfExceptionMessage)
    }

    # if we're using cookies, ensure a global secret exists
    if ($UseCookies) {
        $Secret = (Protect-PodeValue -Value $Secret -Default (Get-PodeCookieSecret -Global))

        if (Test-PodeIsEmpty $Secret) {
            # When using cookies for CSRF, a Secret is required
            throw ($PodeLocale.csrfCookieRequiresSecretExceptionMessage)
        }
    }

    # set the options against the server context
    $PodeContext.Server.Cookies.Csrf = @{
        Name           = 'pode.csrf'
        UseCookies     = $UseCookies
        Secret         = $Secret
        IgnoredMethods = $IgnoreMethods
    }
}


<#
.SYNOPSIS
    Creates and returns a new secure token for use with CSRF.

.DESCRIPTION
    Creates and returns a new secure token for use with CSRF.

.EXAMPLE
    $token = New-PodeCsrfToken
#>
function New-PodeCsrfToken {
    [CmdletBinding()]
    [OutputType([string])]
    param()

    # fail if the csrf logic hasn't been initialised
    if (!(Test-PodeCsrfConfigured)) {
        # CSRF Middleware has not been initialized
        throw ($PodeLocale.csrfMiddlewareNotInitializedExceptionMessage)
    }

    # generate a new secret and salt
    $Secret = New-PodeCsrfSecret
    $Salt = (New-PodeSalt -Length 8)

    # return a new token
    return "t:$($Salt).$(Invoke-PodeSHA256Hash -Value "$($Salt)-$($Secret)")"
}


<#
.SYNOPSIS
    Creates a new Middleware HashTable object, that can be piped/used in Add-PodeMiddleware or in Routes.

.DESCRIPTION
    Creates a new Middleware HashTable object, that can be piped/used in Add-PodeMiddleware or in Routes. ScriptBlock should return $true to continue execution, or $false to stop.

.PARAMETER ScriptBlock
    The Script that defines the logic of the Middleware. Should return $true to continue execution, or $false to stop.

.PARAMETER Route
    A Route path for which Routes this Middleware should only be invoked against.

.PARAMETER ArgumentList
    An array of arguments to supply to the Middleware's ScriptBlock.

.OUTPUTS
    Boolean. ScriptBlock should return $true to continue to the next middleware/route, or return $false to stop execution.

.EXAMPLE
    New-PodeMiddleware -ScriptBlock { /* logic */ } -ArgumentList 'Email' | Add-PodeMiddleware -Name 'CheckEmail'
#>
function New-PodeMiddleware {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [string]
        $Route,

        [Parameter()]
        [object[]]
        $ArgumentList
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
        return New-PodeMiddlewareInternal `
            -ScriptBlock $ScriptBlock `
            -Route $Route `
            -ArgumentList $ArgumentList `
            -PSSession $PSCmdlet.SessionState
    }
}


<#
.SYNOPSIS
    Removes a custom body parser.

.DESCRIPTION
    Removes a custom body parser middleware script for a content-type.

.PARAMETER ContentType
    The ContentType of the custom body parser.

.EXAMPLE
    Remove-PodeBodyParser -ContentType 'application/json'
#>
function Remove-PodeBodyParser {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidatePattern('^\w+\/[\w\.\+-]+$')]
        [string]
        $ContentType
    )

    process {
        # if there's no parser for the type, return
        if (!$PodeContext.Server.BodyParsers.ContainsKey($ContentType)) {
            return
        }

        $null = $PodeContext.Server.BodyParsers.Remove($ContentType)
    }
}


<#
.SYNOPSIS
    Removes a specific user defined Middleware.

.DESCRIPTION
    Removes a specific user defined Middleware.

.PARAMETER Name
    The Name of the Middleware to be removed.

.EXAMPLE
    Remove-PodeMiddleware -Name 'Sessions'
#>
function Remove-PodeMiddleware {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    $PodeContext.Server.Middleware = @($PodeContext.Server.Middleware | Where-Object { $_.Name -ine $Name })
}


<#
.SYNOPSIS
    Checks if a specific middleware is registered in the Pode server.

.DESCRIPTION
    This function verifies whether a middleware with the specified name is registered in the Pode server by checking the `PodeContext.Server.Middleware` collection.
    It returns `$true` if the middleware exists, otherwise it returns `$false`.

.PARAMETER Name
    The name of the middleware to check for.

.OUTPUTS
    [boolean]
    Returns $true if the middleware with the specified name is found, otherwise returns $false.

.EXAMPLE
    Test-PodeMiddleware -Name 'BlockEverything'

    This command checks if a middleware named 'BlockEverything' is registered in the Pode server.
#>
function Test-PodeMiddleware {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    # Check if the middleware exists
    foreach ($middleware in $PodeContext.Server.Middleware) {
        if ($middleware.Name -ieq $Name) {
            return $true
        }
    }

    return $false
}


<#
.SYNOPSIS
    Automatically loads middleware ps1 files

.DESCRIPTION
    Automatically loads middleware ps1 files from either a /middleware folder, or a custom folder. Saves space dot-sourcing them all one-by-one.

.PARAMETER Path
    Optional Path to a folder containing ps1 files, can be relative or literal.

.EXAMPLE
    Use-PodeMiddleware

.EXAMPLE
    Use-PodeMiddleware -Path './my-middleware'
#>
function Use-PodeMiddleware {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Path
    )

    Use-PodeFolder -Path $Path -DefaultPath 'middleware'
}


<#
.SYNOPSIS
    Adds OpenAPI reusable callback configurations.

.DESCRIPTION
    The Add-PodeOACallBack function is used for defining OpenAPI callback configurations for routes in a Pode server.
    It enables setting up API specifications including detailed parameters, request body schemas, and response structures for various HTTP methods.

.PARAMETER Path
    Specifies the callback path, usually a relative URL.
    The key that identifies the Path Item Object is a runtime expression evaluated in the context of a runtime HTTP request/response to identify the URL for the callback request.
    A simple example is `$request.body#/url`.
    The runtime expression allows complete access to the HTTP message, including any part of a body that a JSON Pointer (RFC6901) can reference.
    More information on JSON Pointer can be found at [RFC6901](https://datatracker.ietf.org/doc/html/rfc6901).

.PARAMETER Name
    Alias for 'Name'. A unique identifier for the callback.
    It must be a valid string of alphanumeric characters, periods (.), hyphens (-), and underscores (_).

.PARAMETER Method
    Defines the HTTP method for the callback (e.g., GET, POST, PUT). Supports standard HTTP methods and a wildcard (*) for all methods.

.PARAMETER Parameters
    The Parameter definitions the request uses (from ConvertTo-PodeOAParameter).

.PARAMETER RequestBody
    Defines the schema of the request body. Can be set using New-PodeOARequestBody.

.PARAMETER Responses
    Defines the possible responses for the callback. Can be set using New-PodeOAResponse.

.PARAMETER DefinitionTag
    An Array of strings representing the unique tag for the API specification.
    This tag helps in distinguishing between different versions or types of API specifications within the application.
    You can use this tag to reference the specific API documentation, schema, or version that your function interacts with.

.EXAMPLE
    Add-PodeOAComponentCallBack -Title 'test' -Path '{$request.body#/id}' -Method Post `
    -RequestBody (New-PodeOARequestBody -Content @{'*/*' = (New-PodeOAStringProperty -Name 'id')}) `
    -Response (
    New-PodeOAResponse -StatusCode 200 -Description 'Successful operation'  -Content (New-PodeOAContentMediaType -ContentType 'application/json','application/xml' -Content 'Pet'  -Array)
    New-PodeOAResponse -StatusCode 400 -Description 'Invalid ID supplied' |
    New-PodeOAResponse -StatusCode 404 -Description 'Pet not found' |
    New-PodeOAResponse -Default -Description 'Something is wrong'
    )
    Add-PodeOACallBack -Reference 'test'
    This example demonstrates adding a POST callback to handle a request body and define various responses based on different status codes.


.NOTES
    Ensure that the provided parameters match the expected schema and formats of Pode and OpenAPI specifications.
    The function is useful for dynamically configuring and documenting API callbacks in a Pode server environment.
#>
function Add-PodeOAComponentCallBack {
    param (

        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[a-zA-Z0-9\.\-_]+$')]
        [string]
        $Name,

        [Parameter(Mandatory = $true)]
        [string]
        $Path,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Connect', 'Delete', 'Get', 'Head', 'Merge', 'Options', 'Patch', 'Post', 'Put', 'Trace', '*')]
        [string]
        $Method,

        [hashtable[]]
        $Parameters,

        [hashtable]
        $RequestBody,

        [hashtable]
        $Responses,

        [string[]]
        $DefinitionTag
    )
    $DefinitionTag = Test-PodeOADefinitionTag -Tag $DefinitionTag
    foreach ($tag in $DefinitionTag) {
        $PodeContext.Server.OpenAPI.Definitions[$tag].components.callbacks.$Name = New-PodeOAComponentCallBackInternal -Params $PSBoundParameters -DefinitionTag $tag
    }
}


<#
.SYNOPSIS
    Adds a reusable example component.

.DESCRIPTION
    Adds a reusable example component.

.PARAMETER Name
    The Name of the Example.


.PARAMETER Summary
    Short description for the example

.PARAMETER Description
    Long description for the example.

.PARAMETER Value
    Embedded literal example. The  value Parameter and ExternalValue parameter are mutually exclusive.
    To represent examples of media types that cannot naturally represented in JSON or YAML, use a string value to contain the example, escaping where necessary.

.PARAMETER ExternalValue
    A URL that points to the literal example. This provides the capability to reference examples that cannot easily be included in JSON or YAML documents.
    The -Value parameter and -ExternalValue parameter are mutually exclusive.

.PARAMETER DefinitionTag
    An Array of strings representing the unique tag for the API specification.
    This tag helps in distinguishing between different versions or types of API specifications within the application.
    You can use this tag to reference the specific API documentation, schema, or version that your function interacts with.                           |

.EXAMPLE
    Add-PodeOAComponentExample -name 'frog-example' -Summary "An example of a frog with a cat's name" -Value @{name = 'Jaguar'; petType = 'Panthera'; color = 'Lion'; gender = 'Male'; breed = 'Mantella Baroni' }

#>
function Add-PodeOAComponentExample {
    [CmdletBinding(DefaultParameterSetName = 'Value')]
    param(

        [Parameter(Mandatory = $true)]
        [Alias('Title')]
        [ValidatePattern('^[a-zA-Z0-9\.\-_]+$')]
        [string]
        $Name,

        [string]
        $Summary,

        [Parameter()]
        [string]
        $Description,

        [Parameter(Mandatory = $true, ParameterSetName = 'Value')]
        [object]
        $Value,

        [Parameter(Mandatory = $true, ParameterSetName = 'ExternalValue')]
        [string]
        $ExternalValue,

        [string[]]
        $DefinitionTag
    )
    $DefinitionTag = Test-PodeOADefinitionTag -Tag $DefinitionTag
    foreach ($tag in $DefinitionTag) {
        $Example = [ordered]@{ }
        if ($Summary) {
            $Example.summary = $Summary
        }
        if ($Description) {
            $Example.description = $Description
        }
        if ($Value) {
            $Example.value = $Value
        }
        elseif ($ExternalValue) {
            $Example.externalValue = $ExternalValue
        }

        $PodeContext.Server.OpenAPI.Definitions[$tag].components.examples[$Name] = $Example
    }
}


<#
.SYNOPSIS
    Adds a reusable component for a Header schema.

.DESCRIPTION
    Adds a reusable component for a Header schema.

.LINK
    https://swagger.io/docs/specification/basic-structure/

.LINK
    https://swagger.io/docs/specification/data-models/

.LINK
    https://swagger.io/docs/specification/serialization/

.LINK
    https://swagger.io/docs/specification/data-models/

.PARAMETER Name
    The reference Name of the schema.

.PARAMETER Schema
    The Schema definition (the schema is created using the Property functions).

.PARAMETER Description
    A description of the header

.PARAMETER DefinitionTag
    An Array of strings representing the unique tag for the API specification.
    This tag helps in distinguishing between different versions or types of API specifications within the application.
    You can use this tag to reference the specific API documentation, schema, or version that your function interacts with.

.EXAMPLE
    Add-PodeOAComponentHeader -Name 'UserIdSchema' -Schema (New-PodeOAIntProperty -Name 'userId' -Object)
#>
function Add-PodeOAComponentHeader {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[a-zA-Z0-9\.\-_]+$')]
        [string]
        $Name,

        [Parameter()]
        [string]
        $Description,

        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [hashtable]
        $Schema,

        [string[]]
        $DefinitionTag
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
        $DefinitionTag = Test-PodeOADefinitionTag -Tag $DefinitionTag

        foreach ($tag in $DefinitionTag) {
            $param = [ordered]@{
                'schema' = ($Schema | ConvertTo-PodeOASchemaProperty -NoDescription -DefinitionTag $tag)
            }
            if ( $Description) {
                $param['description'] = $Description
            }
            $PodeContext.Server.OpenAPI.Definitions[$tag].components.headers[$Name] = $param
        }
    }
}


<#
.SYNOPSIS
    Adds a reusable component for a request parameter.

.DESCRIPTION
    Adds a reusable component for a request parameter.

.LINK
    https://swagger.io/docs/specification/basic-structure/

.LINK
    https://swagger.io/docs/specification/data-models/

.LINK
    https://swagger.io/docs/specification/describing-parameters/

.PARAMETER Name
    The reference Name of the parameter.

.PARAMETER Parameter
    The Parameter to use for the component (from ConvertTo-PodeOAParameter)

.PARAMETER DefinitionTag
    An Array of strings representing the unique tag for the API specification.
    This tag helps in distinguishing between different versions or types of API specifications within the application.
    You can use this tag to reference the specific API documentation, schema, or version that your function interacts with.

.EXAMPLE
    New-PodeOAIntProperty -Name 'userId' | ConvertTo-PodeOAParameter -In Query | Add-PodeOAComponentParameter -Name 'UserIdParam'
#>
function Add-PodeOAComponentParameter {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidatePattern('^[a-zA-Z0-9\.\-_]+$')]
        [string]
        $Name,

        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [hashtable]
        $Parameter,

        [string[]]
        $DefinitionTag
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

        $DefinitionTag = Test-PodeOADefinitionTag -Tag $DefinitionTag

        foreach ($tag in $DefinitionTag) {
            if ([string]::IsNullOrWhiteSpace($Name)) {
                if ($Parameter.name) {
                    $Name = $Parameter.name
                }
                else {
                    # The Parameter has no name. Please provide a name to this component using the `Name` parameter
                    throw ($PodeLocale.parameterHasNoNameExceptionMessage)
                }
            }
            $PodeContext.Server.OpenAPI.Definitions[$tag].components.parameters[$Name] = $Parameter
        }
    }
}


<#
.SYNOPSIS
    Sets metadate for the supplied route.

.DESCRIPTION
    Sets metadate for the supplied route, such as Summary and Tags.

.LINK
    https://swagger.io/docs/specification/paths-and-operations/

.PARAMETER Name
    Alias for 'Name'. A unique identifier for the route.
    It must be a valid string of alphanumeric characters, periods (.), hyphens (-), and underscores (_).

.PARAMETER Path
    The URI path for the Route.

.PARAMETER Method
    The HTTP Method of this Route, multiple can be supplied.

.PARAMETER Servers
    A list of external endpoint. created with New-PodeOAServerEndpoint

.PARAMETER PassThru
    If supplied, the route passed in will be returned for further chaining.

.PARAMETER DefinitionTag
    An Array of strings representing the unique tag for the API specification.
    This tag helps in distinguishing between different versions or types of API specifications within the application.
    You can use this tag to reference the specific API documentation, schema, or version that your function interacts with.

.EXAMPLE
    Add-PodeOAExternalRoute -PassThru -Method Get -Path '/peta/:id' -Servers (
    New-PodeOAServerEndpoint -Url 'http://ext.server.com/api/v12' -Description 'ext test server' |
    New-PodeOAServerEndpoint -Url 'http://ext13.server.com/api/v12' -Description 'ext test server 13'
    ) |
    Set-PodeOARouteInfo -Summary 'Find pets by ID' -Description 'Returns pets based on ID'  -OperationId 'getPetsById' -PassThru |
    Set-PodeOARequest -PassThru -Parameters @(
    (New-PodeOAStringProperty -Name 'id' -Description 'ID of pet to use' -array | ConvertTo-PodeOAParameter -In Path -Style Simple -Required )) |
    Add-PodeOAResponse -StatusCode 200 -Description 'pet response'   -Content (@{ '*/*' = New-PodeOASchemaProperty   -ComponentSchema 'Pet' -array }) -PassThru |
    Add-PodeOAResponse -Default  -Description 'error payload' -Content (@{'text/html' = 'ErrorModel' }) -PassThru
.EXAMPLE
    Add-PodeOAComponentPathItem -PassThru -Method Get -Path '/peta/:id'  -ScriptBlock {
    Write-PodeJsonResponse -Value 'done' -StatusCode 200
    } | Add-PodeOAExternalRoute -PassThru   -Servers (
    New-PodeOAServerEndpoint -Url 'http://ext.server.com/api/v12' -Description 'ext test server' |
    New-PodeOAServerEndpoint -Url 'http://ext13.server.com/api/v12' -Description 'ext test server 13'
    ) |
    Set-PodeOARouteInfo -Summary 'Find pets by ID' -Description 'Returns pets based on ID'  -OperationId 'getPetsById' -PassThru |
    Set-PodeOARequest -PassThru -Parameters @(
    (New-PodeOAStringProperty -Name 'id' -Description 'ID of pet to use' -array | ConvertTo-PodeOAParameter -In Path -Style Simple -Required )) |
    Add-PodeOAResponse -StatusCode 200 -Description 'pet response'   -Content (@{ '*/*' = New-PodeOASchemaProperty   -ComponentSchema 'Pet' -array }) -PassThru |
    Add-PodeOAResponse -Default  -Description 'error payload' -Content (@{'text/html' = 'ErrorModel' }) -PassThru
#>
function Add-PodeOAComponentPathItem {
    param(

        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[a-zA-Z0-9\.\-_]+$')]
        [string]
        $Name,

        [Parameter(Mandatory = $true )]
        [ValidateSet('Connect', 'Delete', 'Get', 'Head', 'Merge', 'Options', 'Patch', 'Post', 'Put', 'Trace', '*')]
        [string]
        $Method,

        [switch]
        $PassThru,

        [string[]]
        $DefinitionTag
    )

    $_definitionTag = Test-PodeOADefinitionTag -Tag $DefinitionTag

    $refRoute = @{
        Method      = $Method.ToLower()
        NotPrepared = $true
        OpenApi     = @{
            Responses          = [ordered]@{}
            Parameters         = [ordered]@{}
            RequestBody        = [ordered]@{}
            callbacks          = [ordered]@{}
            Authentication     = @()
            Servers            = @()
            DefinitionTag      = $_definitionTag
            IsDefTagConfigured = ($null -ne $DefinitionTag) #Definition Tag has been configured (Not default)
        }
    }
    foreach ($tag in $_definitionTag) {
        if (Test-PodeOAVersion -Version 3.0 -DefinitionTag $tag  ) {
            # The 'pathItems' reusable component feature is not available in OpenAPI v3.0.
            throw ($PodeLocale.reusableComponentPathItemsNotAvailableInOpenApi30ExceptionMessage)
        }
        #add the default OpenApi responses
        if ( $PodeContext.Server.OpenAPI.Definitions[$tag].hiddenComponents.defaultResponses) {
            $refRoute.OpenApi.Responses = Copy-PodeObjectDeepClone -InputObject $PodeContext.Server.OpenAPI.Definitions[$tag].hiddenComponents.defaultResponses
        }
        $PodeContext.Server.OpenAPI.Definitions[$tag].components.pathItems[$Name] = $refRoute
    }

    if ($PassThru) {
        return $refRoute
    }
}


<#
.SYNOPSIS
    Adds a reusable component for a request body.

.DESCRIPTION
    Adds a reusable component for a request body.

.LINK
    https://swagger.io/docs/specification/basic-structure/

.LINK
    https://swagger.io/docs/specification/data-models/

.LINK
    https://swagger.io/docs/specification/describing-request-body/

.PARAMETER Name
    The reference Name of the request body.

.PARAMETER Content
    The content-types and schema the request body accepts (the schema is created using the Property functions).

.PARAMETER Description
    A Description of the request body.

.PARAMETER Required
    If supplied, the request body will be flagged as required.

.PARAMETER DefinitionTag
    An Array of strings representing the unique tag for the API specification.
    This tag helps in distinguishing between different versions or types of API specifications within the application.
    You can use this tag to reference the specific API documentation, schema, or version that your function interacts with.

.EXAMPLE
    Add-PodeOAComponentRequestBody -Name 'UserIdBody' -ContentSchemas @{ 'application/json' = (New-PodeOAIntProperty -Name 'userId' -Object) }

.EXAMPLE
    Add-PodeOAComponentRequestBody -Name 'UserIdBody' -ContentSchemas @{ 'application/json' = 'UserIdSchema' }
#>
function Add-PodeOAComponentRequestBody {
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[a-zA-Z0-9\.\-_]+$')]
        [string]
        $Name,

        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [Alias('ContentSchemas')]
        [ValidateScript({
            ($_ -is [hashtable]) -or ($_ -is [System.Collections.Specialized.OrderedDictionary])
            })]
        $Content,

        [Parameter()]
        [string]
        $Description  ,

        [Parameter()]
        [switch]
        $Required,

        [string[]]
        $DefinitionTag
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
        $DefinitionTag = Test-PodeOADefinitionTag -Tag $DefinitionTag

        if ($Content -is [hashtable]) {
            $orderedHashtable = [ordered]@{}

            foreach ($key in $Content.Keys | Sort-Object) {
                $orderedHashtable[$key] = $Content[$key]
            }
            $Content = $orderedHashtable
        }

        foreach ($tag in $DefinitionTag) {
            $param = [ordered]@{ content = ($Content | ConvertTo-PodeOAObjectSchema -DefinitionTag $tag) }

            if ($Required.IsPresent) {
                $param['required'] = $Required.IsPresent
            }

            if ( $Description) {
                $param['description'] = $Description
            }
            $PodeContext.Server.OpenAPI.Definitions[$tag].components.requestBodies[$Name] = $param
        }
    }

}


<#
.SYNOPSIS
    Adds a reusable component for responses.

.DESCRIPTION
    Adds a reusable component for responses.

.LINK
    https://swagger.io/docs/specification/basic-structure/

.LINK
    https://swagger.io/docs/specification/data-models/

.LINK
    https://swagger.io/docs/specification/serialization/

.PARAMETER Name
    The reference Name of the response.

.PARAMETER Content
    The content-types and schema the response returns (the schema is created using the Property functions).

.PARAMETER Headers
    The header name and schema the response returns (the schema is created using the Add-PodeOAComponentHeader cmdlet).

.PARAMETER Description
    The Description of the response.

.PARAMETER Reference
    A Reference Name of an existing component response to use.

.PARAMETER Links
    A Response link definition

.PARAMETER DefinitionTag
    An Array of strings representing the unique tag for the API specification.
    This tag helps in distinguishing between different versions or types of API specifications within the application.
    You can use this tag to reference the specific API documentation, schema, or version that your function interacts with.

.EXAMPLE
    Add-PodeOAComponentResponse -Name 'OKResponse' -Content @{ 'application/json' = (New-PodeOAIntProperty -Name 'userId' -Object) }

.EXAMPLE
    Add-PodeOAComponentResponse -Name 'ErrorResponse' -Content  @{ 'application/json' = 'ErrorSchema' }
#>
function Add-PodeOAComponentResponse {
    [CmdletBinding(DefaultParameterSetName = 'Schema')]
    param(
        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[a-zA-Z0-9\.\-_]+$')]
        [string]
        $Name,

        [Parameter(ParameterSetName = 'Schema')]
        [Alias('ContentSchemas')]
        [hashtable]
        $Content,

        [Parameter(ParameterSetName = 'Schema')]
        [Alias('HeaderSchemas')]
        [AllowEmptyString()]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ $_ -is [string] -or $_ -is [string[]] -or $_ -is [hashtable] })]
        $Headers,

        [Parameter(ParameterSetName = 'Schema')]
        [string]
        $Description,

        [Parameter(Mandatory = $true, ParameterSetName = 'Reference')]
        [string]
        $Reference,

        [Parameter(ParameterSetName = 'Schema')]
        [System.Collections.Specialized.OrderedDictionary ]
        $Links,

        [string[]]
        $DefinitionTag
    )
    $DefinitionTag = Test-PodeOADefinitionTag -Tag $DefinitionTag
    foreach ($tag in $DefinitionTag) {
        $PodeContext.Server.OpenAPI.Definitions[$tag].components.responses[$Name] = New-PodeOResponseInternal -DefinitionTag $tag -Params $PSBoundParameters
    }
}


<#
.SYNOPSIS
    Adds a reusable response link.

.DESCRIPTION
    The Add-PodeOAComponentResponseLink function is designed to add a new reusable response link

.PARAMETER Name
    Mandatory. A unique name for the response link.
    Must be a valid string composed of alphanumeric characters, periods (.), hyphens (-), and underscores (_).

.PARAMETER Description
    A brief description of the response link. CommonMark syntax may be used for rich text representation.
    For more information on CommonMark syntax, see [CommonMark Specification](https://spec.commonmark.org/).

.PARAMETER OperationId
    The name of an existing, resolvable OpenAPI Specification (OAS) operation, as defined with a unique `operationId`.
    This parameter is mandatory when using the 'OperationId' parameter set and is mutually exclusive of the `OperationRef` field. It is used to specify the unique identifier of the operation the link is associated with.

.PARAMETER OperationRef
    A relative or absolute URI reference to an OAS operation.
    This parameter is mandatory when using the 'OperationRef' parameter set and is mutually exclusive of the `OperationId` field.
    It MUST point to an Operation Object. Relative `operationRef` values MAY be used to locate an existing Operation Object in the OpenAPI specification.

.PARAMETER Parameters
    A map representing parameters to pass to an operation as specified with `operationId` or identified via `operationRef`.
    The key is the parameter name to be used, whereas the value can be a constant or an expression to be evaluated and passed to the linked operation.
    Parameter names can be qualified using the parameter location syntax `[{in}.]{name}` for operations that use the same parameter name in different locations (e.g., path.id).

.PARAMETER RequestBody
    A string representing the request body to use as a request body when calling the target.

.PARAMETER DefinitionTag
    An Array of strings representing the unique tag for the API specification.
    This tag helps in distinguishing between different versions or types of API specifications within the application.
    You can use this tag to reference the specific API documentation, schema, or version that your function interacts with.

.EXAMPLE
    Add-PodeOAComponentResponseLink   -Name 'address' -OperationId 'getUserByName' -Parameters @{'username' = '$request.path.username'}
    Add-PodeOAResponse -StatusCode 200 -Content @{'application/json' = 'User'} -Links 'address'
    This example demonstrates creating and adding a link named 'address' associated with the operation 'getUserByName' to an OrderedDictionary of links. The updated dictionary is then used in the 'Add-PodeOAResponse' function to define a response with a status code of 200.

.NOTES
    The function supports adding links either by specifying an 'OperationId' or an 'OperationRef', making it versatile for different OpenAPI specification needs.
    It's important to match the parameters and response structures as per the OpenAPI specification to ensure the correct functionality of the API documentation.
#>
function Add-PodeOAComponentResponseLink {
    [CmdletBinding(DefaultParameterSetName = 'OperationId')]
    param(

        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[a-zA-Z0-9\.\-_]+$')]
        [string]
        $Name,

        [Parameter()]
        [string]
        $Description,

        [Parameter(Mandatory = $true, ParameterSetName = 'OperationId')]
        [string]
        $OperationId,

        [Parameter(Mandatory = $true, ParameterSetName = 'OperationRef')]
        [string]
        $OperationRef,

        [Parameter()]
        [hashtable]
        $Parameters,

        [Parameter()]
        [string]
        $RequestBody,

        [string[]]
        $DefinitionTag

    )
    $DefinitionTag = Test-PodeOADefinitionTag -Tag $DefinitionTag
    foreach ($tag in $DefinitionTag) {
        $PodeContext.Server.OpenAPI.Definitions[$tag].components.links[$Name] = New-PodeOAResponseLinkInternal -Params $PSBoundParameters
    }
}


<#
.SYNOPSIS
    Adds a reusable component schema

.DESCRIPTION
    Adds a reusable component  schema.

.LINK
    https://swagger.io/docs/specification/basic-structure/

.LINK
    https://swagger.io/docs/specification/data-models/

.LINK
    https://swagger.io/docs/specification/serialization/

.LINK
    https://swagger.io/docs/specification/data-models/

.PARAMETER Name
    The reference Name of the schema.

.PARAMETER Component
    The Component definition (the schema is created using the Property functions).

.PARAMETER Description
    A description of the schema

.PARAMETER DefinitionTag
    An Array of strings representing the unique tag for the API specification.
    This tag helps in distinguishing between different versions or types of API specifications within the application.
    You can use this tag to reference the specific API documentation, schema, or version that your function interacts with.

.EXAMPLE
    Add-PodeOAComponentSchema -Name 'UserIdSchema' -Component (New-PodeOAIntProperty -Name 'userId' -Object)
#>
function Add-PodeOAComponentSchema {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[a-zA-Z0-9\.\-_]+$')]
        [string]
        $Name,

        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [Alias('Schema')]
        [hashtable]
        $Component,

        [string]
        $Description,

        [string[]]
        $DefinitionTag
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
        $DefinitionTag = Test-PodeOADefinitionTag -Tag $DefinitionTag

        foreach ($tag in $DefinitionTag) {
            $PodeContext.Server.OpenAPI.Definitions[$tag].components.schemas[$Name] = ($Component | ConvertTo-PodeOASchemaProperty -DefinitionTag $tag)
            if ($PodeContext.Server.OpenAPI.Definitions[$tag].hiddenComponents.schemaValidation) {
                try {
                    $modifiedComponent = ($Component | ConvertTo-PodeOASchemaProperty -DefinitionTag $tag) | Resolve-PodeOAReference -DefinitionTag $tag
                    $PodeContext.Server.OpenAPI.Definitions[$tag].hiddenComponents.schemaJson[$Name] = @{
                        'available' = $true
                        'schema'    = $modifiedComponent
                        'json'      = $modifiedComponent | ConvertTo-Json -Depth $PodeContext.Server.OpenAPI.Definitions[$tag].hiddenComponents.depth
                    }
                }
                catch {
                    if ($_.ToString().StartsWith('Validation of schema with')) {
                        $PodeContext.Server.OpenAPI.Definitions[$tag].hiddenComponents.schemaJson[$Name] = @{
                            'available' = $false
                        }
                    }
                }
            }

            if ($Description) {
                $PodeContext.Server.OpenAPI.Definitions[$tag].components.schemas[$Name].description = $Description
            }
        }
    }
}


<#
.SYNOPSIS
    Remove an OpenAPI component if exist

.DESCRIPTION
    Remove an OpenAPI component if exist

.PARAMETER Field
    The component type

.PARAMETER Name
    The component Name

.PARAMETER DefinitionTag
    An Array of strings representing the unique tag for the API specification.
    This tag helps in distinguishing between different versions or types of API specifications within the application.
    You can use this tag to reference the specific API documentation, schema, or version that your function interacts with.

.EXAMPLE
    Remove-PodeOAComponent -Field 'responses' -Name 'myresponse' -DefinitionTag 'default'
#>
function Remove-PodeOAComponent {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet( 'schemas' , 'responses' , 'parameters' , 'examples' , 'requestBodies' , 'headers' , 'securitySchemes' , 'links' , 'callbacks' , 'pathItems'  )]
        [string]
        $Field,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name,

        [string[]]
        $DefinitionTag
    )
    $DefinitionTag = Test-PodeOADefinitionTag -Tag $DefinitionTag
    foreach ($tag in $DefinitionTag) {
        if (!($PodeContext.Server.OpenAPI.Definitions[$tag].components[$field ].keys -ccontains $Name)) {
            $PodeContext.Server.OpenAPI.Definitions[$tag].components[$field ].remove($Name)
        }
    }
}


<#
.SYNOPSIS
    Check the OpenAPI component exist

.DESCRIPTION
    Check the OpenAPI component exist

.PARAMETER Field
    The component type

.PARAMETER Name
    The component Name

.PARAMETER DefinitionTag
    An Array of strings representing the unique tag for the API specification.
    This tag helps in distinguishing between different versions or types of API specifications within the application.
    You can use this tag to reference the specific API documentation, schema, or version that your function interacts with.

.EXAMPLE
    Test-PodeOAComponent -Field 'responses' -Name 'myresponse' -DefinitionTag 'default'
#>
function Test-PodeOAComponent {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet( 'schemas' , 'responses' , 'parameters' , 'examples' , 'requestBodies' , 'headers' , 'securitySchemes' , 'links' , 'callbacks' , 'pathItems' )]
        [string]
        $Field,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name,

        [string[]]
        $DefinitionTag
    )

    $DefinitionTag = Test-PodeOADefinitionTag -Tag $DefinitionTag

    foreach ($tag in $DefinitionTag) {
        if (!($PodeContext.Server.OpenAPI.Definitions[$tag].components[$field].keys -ccontains $Name)) {
            return $false
        }
    }
    if (!$ThrowException.IsPresent) {
        return $true
    }
}


<#
.SYNOPSIS
    Check the OpenAPI version

.DESCRIPTION
    Check the OpenAPI version for a specific OpenAPI Definition


.PARAMETER Version
    The version number to compare

.PARAMETER DefinitionTag
    An Array of strings representing the unique tag for the API specification.
    This tag helps in distinguishing between different versions or types of API specifications within the application.
    You can use this tag to reference the specific API documentation, schema, or version that your function interacts with.

.EXAMPLE
    Test-PodeOAVersion -Version 3.1 -DefinitionTag 'default'
#>
function Test-PodeOAVersion {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet( '3.1' , '3.0' )]
        [string]
        $Version,

        [Parameter(Mandatory = $true)]
        [string[] ]
        $DefinitionTag
    )

    return $PodeContext.Server.OpenAPI.Definitions[$DefinitionTag].hiddenComponents.version -eq $Version
}


<#
.SYNOPSIS
    Creates a new OpenAPI object combining schemas and properties.

.DESCRIPTION
    Creates a new OpenAPI object combining schemas and properties.

.LINK
    https://swagger.io/docs/specification/basic-structure/

.LINK
    https://swagger.io/docs/specification/data-models/

.PARAMETER ParamsList
    Used to pipeline an object definition

.PARAMETER Type
    Define the type of validation between the objects
    oneOf – validates the value against exactly one of the subschemas
    allOf – validates the value against all the subschemas
    anyOf – validates the value against any (one or more) of the subschemas

.PARAMETER ObjectDefinitions
    An array of object definitions that are used for independent validation but together compose a single object.

.PARAMETER DiscriminatorProperty
    If supplied, specifies the name of the property used to distinguish between different subtypes in a polymorphic schema in OpenAPI.
    This string value represents the property in the payload that indicates which specific subtype schema should be applied.
    It's essential in scenarios where an API endpoint handles data that conforms to one of several derived schemas from a common base schema.

.PARAMETER DiscriminatorMapping
    If supplied, defines a mapping between the values of the discriminator property and the corresponding subtype schemas.
    This parameter accepts a HashTable where each key-value pair maps a discriminator value to a specific subtype schema name.
    It's used in conjunction with the -DiscriminatorProperty to provide complete discrimination logic in polymorphic scenarios.

.PARAMETER NoObjectDefinitionsFromPipeline
    Prevents object definitions from being used in the computation but still passes them through the pipeline.

.PARAMETER Name
    Specifies the name of the OpenAPI object.

.PARAMETER Required
    Indicates if the object is required.

.PARAMETER Description
    Provides a description for the OpenAPI object.

.EXAMPLE
    Add-PodeOAComponentSchema -Name 'Pets' -Component (Merge-PodeOAProperty -Type OneOf -ObjectDefinitions @('Cat', 'Dog') -Discriminator "petType")

.EXAMPLE
    Add-PodeOAComponentSchema -Name 'Cat' -Component (
    Merge-PodeOAProperty -Type AllOf -ObjectDefinitions @(
    'Pet',
    (New-PodeOAObjectProperty -Properties @(
    (New-PodeOAStringProperty -Name 'huntingSkill' -Description 'The measured skill for hunting' -Enum @('clueless', 'lazy', 'adventurous', 'aggressive'))
    ))
    )
    )
#>
function Merge-PodeOAProperty {
    [CmdletBinding(DefaultParameterSetName = 'Inbuilt')]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param(

        [Parameter(ValueFromPipeline = $true, Position = 0, DontShow = $true )]
        [hashtable[]]
        $ParamsList,

        [Parameter(Mandatory)]
        [ValidateSet('OneOf', 'AnyOf', 'AllOf')]
        [string]
        $Type,

        [Parameter()]
        [System.Object[]]
        $ObjectDefinitions,

        [string]
        $DiscriminatorProperty,

        [hashtable]
        $DiscriminatorMapping,

        [switch]
        $NoObjectDefinitionsFromPipeline,

        [Parameter(Mandatory = $true, ParameterSetName = 'Name')]
        [string]
        $Name,

        [Parameter( ParameterSetName = 'Name')]
        [switch]
        $Required,

        [Parameter( ParameterSetName = 'Name')]
        [string]
        $Description
    )
    begin {
        # Initialize an ordered dictionary
        $param = [ordered]@{}

        # Set the type of validation
        switch ($type.ToLower()) {
            'oneof' {
                $param.type = 'oneOf'
            }
            'anyof' {
                $param.type = 'anyOf'
            }
            'allof' {
                $param.type = 'allOf'
            }
        }

        # Add name to the parameter dictionary if provided
        if ($Name) {
            $param.name = $Name
        }

        # Add description to the parameter dictionary if provided
        if ($Description) {
            $param.description = $Description
        }

        # Set the required field if the switch is present
        if ($Required.IsPresent) {
            $param.required = $Required.IsPresent
        }

        # Initialize schemas array
        $param.schemas = @()

        # Add object definitions to the schemas array
        if ($ObjectDefinitions) {
            foreach ($schema in $ObjectDefinitions) {
                if ($schema -is [System.Object[]] -or ($schema -is [hashtable] -and
                (($schema.type -ine 'object') -and !$schema.object))) {
                    # Only properties of type Object can be associated with $param.type
                    throw ($PodeLocale.propertiesTypeObjectAssociationExceptionMessage -f $param.type)
                }
                $param.schemas += $schema
            }
        }

        # Add discriminator property and mapping if provided
        if ($DiscriminatorProperty) {
            if ($type.ToLower() -eq 'allof' ) {
                # The parameter 'Discriminator' is incompatible with `allOf`
                throw ($PodeLocale.discriminatorIncompatibleWithAllOfExceptionMessage)
            }
            $param.discriminator = [ordered]@{
                'propertyName' = $DiscriminatorProperty
            }
            if ($DiscriminatorMapping) {
                $param.discriminator.mapping = $DiscriminatorMapping
            }
        }
        elseif ($DiscriminatorMapping) {
            # The parameter 'DiscriminatorMapping' can only be used when 'DiscriminatorProperty' is present
            throw ($PodeLocale.discriminatorMappingRequiresDiscriminatorPropertyExceptionMessage)
        }

        # Initialize a list to collect input from the pipeline
        $collectedInput = [System.Collections.Generic.List[hashtable]]::new()
    }
    process {
        if ($ParamsList) {
            if ($NoObjectDefinitionsFromPipeline) {
                # Add to collected input if the switch is present
                $collectedInput.AddRange($ParamsList)
            }
            else {
                # Add to schemas if the switch is not present
                $param.schemas += $ParamsList
            }
        }
    }

    end {
        if ($NoObjectDefinitionsFromPipeline) {
            # Return collected input and param dictionary if switch is present
            return $collectedInput + $param
        }
        else {
            # Return the param dictionary
            return $param
        }
    }
}


<#
.SYNOPSIS
    Creates a new OpenAPI boolean property.

.DESCRIPTION
    Creates a new OpenAPI boolean property, for Schemas or Parameters.

.LINK
    https://swagger.io/docs/specification/basic-structure/

.LINK
    https://swagger.io/docs/specification/data-models/

.PARAMETER ParamsList
    Used to pipeline multiple properties

.PARAMETER Name
    The Name of the property.

.PARAMETER Default
    The default value of the property. (Default: $false)

.PARAMETER Description
    A Description of the property.

.PARAMETER ExternalDoc
    If supplied, add an additional external documentation for this operation.
    The parameter is created by Add-PodeOAExternalDoc

.PARAMETER Example
    An example of a parameter value

.PARAMETER Enum
    An optional array of values that this property can only be set to.

.PARAMETER Required
    If supplied, the object will be treated as Required where supported.

.PARAMETER Deprecated
    If supplied, the object will be treated as Deprecated where supported.

.PARAMETER Object
    If supplied, the boolean will be automatically wrapped in an object.

.PARAMETER Nullable
    If supplied, the boolean will be treated as Nullable.

.PARAMETER ReadOnly
    If supplied, the boolean will be included in a response but not in a request

.PARAMETER WriteOnly
    If supplied, the boolean will be included in a request but not in a response

.PARAMETER NoAdditionalProperties
    If supplied, will configure the OpenAPI property additionalProperties to false.
    This means that the defined object will not allow any properties beyond those explicitly declared in its schema.
    If any additional properties are provided, they will be considered invalid.
    Use this switch to enforce a strict schema definition, ensuring that objects contain only the specified set of properties and no others.

.PARAMETER AdditionalProperties
    Define a set of additional properties for the OpenAPI schema. This parameter accepts a HashTable where each key-value pair represents a property name and its corresponding schema.
    The schema for each property can include type, format, description, and other OpenAPI specification attributes.
    When specified, these additional properties are included in the OpenAPI definition, allowing for more flexible and dynamic object structures.

.PARAMETER Array
    If supplied, the object will be treated as an array of objects.

.PARAMETER UniqueItems
    If supplied, specify that all items in the array must be unique

.PARAMETER MinItems
    If supplied, specify minimum length of an array

.PARAMETER MaxItems
    If supplied, specify maximum length of an array

.PARAMETER XmlName
    By default, XML elements get the same names that fields in the API declaration have. This property change the XML name of the property
    reflecting the 'xml.name' attribute in the OpenAPI specification.

.PARAMETER XmlNamespace
    Defines a specific XML namespace for the property, corresponding to the 'xml.namespace' attribute in OpenAPI.

.PARAMETER XmlPrefix
    Sets a prefix for the XML element name, aligning with the 'xml.prefix' attribute in OpenAPI.

.PARAMETER XmlAttribute
    Indicates whether the property should be serialized as an XML attribute, equivalent to the 'xml.attribute' attribute in OpenAPI.

.PARAMETER XmlItemName
    Specifically for properties treated as arrays, it defines the XML name for each item in the array. This parameter aligns with the 'xml.name' attribute under 'items' in OpenAPI.

.PARAMETER XmlWrapped
    Indicates whether array items should be wrapped in an XML element, similar to the 'xml.wrapped' attribute in OpenAPI.

.EXAMPLE
    New-PodeOABoolProperty -Name 'enabled' -Required
#>
function New-PodeOABoolProperty {
    [CmdletBinding(DefaultParameterSetName = 'Inbuilt')]
    param(

        [Parameter(ValueFromPipeline = $true, Position = 0, DontShow = $true)]
        [hashtable[]]
        $ParamsList,

        [Parameter()]
        [ValidatePattern('^[a-zA-Z0-9\.\-_]+$')]
        [Alias('Title')]
        [string]
        $Name,

        [Parameter()]
        [string]
        $Default,

        [Parameter()]
        [string]
        $Description,

        [Parameter()]
        [string]
        $ExternalDoc,

        [Parameter()]
        [object]
        $Example,

        [Parameter()]
        [string[]]
        $Enum,

        [switch]
        $Required,

        [switch]
        $Deprecated,

        [switch]
        $Object,

        [switch]
        $Nullable,

        [switch]
        $ReadOnly,

        [switch]
        $WriteOnly,

        [switch]
        $NoAdditionalProperties,

        [hashtable]
        $AdditionalProperties,

        [string]
        $XmlName,

        [string]
        $XmlNamespace,

        [string]
        $XmlPrefix,

        [switch]
        $XmlAttribute,

        [Parameter(  ParameterSetName = 'Array')]
        [string]
        $XmlItemName,

        [Parameter(  ParameterSetName = 'Array')]
        [switch]
        $XmlWrapped,

        [Parameter(Mandatory = $true, ParameterSetName = 'Array')]
        [switch]
        $Array,

        [Parameter(ParameterSetName = 'Array')]
        [switch]
        $UniqueItems,

        [Parameter(ParameterSetName = 'Array')]
        [int]
        $MinItems,

        [Parameter(ParameterSetName = 'Array')]
        [int]
        $MaxItems
    )
    begin {
        $param = New-PodeOAPropertyInternal -type 'boolean' -Params $PSBoundParameters

        if ($Default) {
            if ([bool]::TryParse($Default, [ref]$null) -or $Enum -icontains $Default) {
                $param.default = $Default
            }
            else {
                # The default value is not a boolean and is not part of the enum
                throw ($PodeLocale.defaultValueNotBooleanOrEnumExceptionMessage)
            }
        }

        $collectedInput = [System.Collections.Generic.List[hashtable]]::new()
    }
    process {
        if ($ParamsList) {
            $collectedInput.AddRange($ParamsList)
        }
    }

    end {
        if ($collectedInput) {
            return $collectedInput + $param
        }
        else {
            return $param
        }
    }
}


<#
.SYNOPSIS
    Creates a OpenAPI schema reference property.

.DESCRIPTION
    Creates a new OpenAPI component schema reference from another OpenAPI schema.

.LINK
    https://swagger.io/docs/specification/basic-structure/

.LINK
    https://swagger.io/docs/specification/data-models/

.PARAMETER ParamsList
    Used to pipeline multiple properties

.PARAMETER Name
    The Name of the property.

.PARAMETER Reference
    An component schema name.

.PARAMETER Description
    A Description of the property.

.PARAMETER Example
    An example of a parameter value

.PARAMETER Deprecated
    If supplied, the schema will be treated as Deprecated where supported.

.PARAMETER Required
    If supplied, the object will be treated as Required where supported.

.PARAMETER Array
    If supplied, the schema will be treated as an array of objects.

.PARAMETER Nullable
    If supplied, the schema will be treated as Nullable.

.PARAMETER ReadOnly
    If supplied, the schema will be included in a response but not in a request

.PARAMETER WriteOnly
    If supplied, the schema will be included in a request but not in a response

.PARAMETER Array
    If supplied, the schema will be treated as an array of objects.

.PARAMETER UniqueItems
    If supplied, specify that all items in the array must be unique

.PARAMETER MinItems
    If supplied, specify minimum length of an array

.PARAMETER MaxItems
    If supplied, specify maximum length of an array

.PARAMETER XmlName
    By default, XML elements get the same names that fields in the API declaration have. This property change the XML name of the property
    reflecting the 'xml.name' attribute in the OpenAPI specification.

.PARAMETER XmlNamespace
    Defines a specific XML namespace for the property, corresponding to the 'xml.namespace' attribute in OpenAPI.

.PARAMETER XmlPrefix
    Sets a prefix for the XML element name, aligning with the 'xml.prefix' attribute in OpenAPI.

.PARAMETER XmlAttribute
    Indicates whether the property should be serialized as an XML attribute, equivalent to the 'xml.attribute' attribute in OpenAPI.

.PARAMETER XmlItemName
    Specifically for properties treated as arrays, it defines the XML name for each item in the array. This parameter aligns with the 'xml.name' attribute under 'items' in OpenAPI.

.PARAMETER XmlWrapped
    Indicates whether array items should be wrapped in an XML element, similar to the 'xml.wrapped' attribute in OpenAPI.

.EXAMPLE
    New-PodeOAComponentSchemaProperty -Name 'Config' -Component "MyConfigSchema"
#>
function New-PodeOAComponentSchemaProperty {
    [CmdletBinding(DefaultParameterSetName = 'Inbuilt')]
    param(

        [Parameter(ValueFromPipeline = $true, DontShow = $true )]
        [hashtable[]]
        $ParamsList,

        [Parameter()]
        [ValidatePattern('^[a-zA-Z0-9\.\-_]+$')]
        [string]
        $Name,

        [Parameter(Mandatory = $true)]
        [string]
        $Reference,

        [Parameter(  ParameterSetName = 'Array')]
        [string]
        $Description,

        [string]
        $XmlName,

        [string]
        $XmlNamespace,

        [string]
        $XmlPrefix,

        [switch]
        $XmlAttribute,

        [object]
        $Example,

        [switch]
        $Deprecated,

        [switch]
        $Required,

        [switch]
        $Nullable,

        [switch]
        $ReadOnly,

        [switch]
        $WriteOnly,

        [Parameter(  ParameterSetName = 'Array')]
        [string]
        $XmlItemName,

        [Parameter(  ParameterSetName = 'Array')]
        [switch]
        $XmlWrapped,

        [Parameter(Mandatory = $true, ParameterSetName = 'Array')]
        [switch]
        $Array,

        [Parameter(ParameterSetName = 'Array')]
        [switch]
        $UniqueItems,

        [Parameter(ParameterSetName = 'Array')]
        [int]
        $MinItems,

        [Parameter(ParameterSetName = 'Array')]
        [int]
        $MaxItems
    )
    begin {
        $param = New-PodeOAPropertyInternal -type 'schema' -Params $PSBoundParameters
        if (! $param.Name) {
            $param.Name = $Reference
        }
        $param.schema = $Reference
        $collectedInput = [System.Collections.Generic.List[hashtable]]::new()
    }
    process {
        if ($ParamsList) {
            $collectedInput.AddRange($ParamsList)
        }
    }
    end {
        if ($collectedInput) {
            return $collectedInput + $param
        }
        else {
            return $param
        }
    }
}


<#
.SYNOPSIS
    Creates a new OpenAPI integer property.

.DESCRIPTION
    Creates a new OpenAPI integer property, for Schemas or Parameters.

.LINK
    https://swagger.io/docs/specification/basic-structure/

.LINK
    https://swagger.io/docs/specification/data-models/

.PARAMETER ParamsList
    Used to pipeline multiple properties

.PARAMETER Name
    The Name of the property.

.PARAMETER Format
    The inbuilt OpenAPI Format of the integer. (Default: Any)

.PARAMETER Default
    The default value of the property. (Default: 0)

.PARAMETER Minimum
    The minimum value of the integer. (Default: Int.Min)

.PARAMETER Maximum
    The maximum value of the integer. (Default: Int.Max)

.PARAMETER ExclusiveMaximum
    Specifies an exclusive upper limit for a numeric property in the OpenAPI schema.
    When this parameter is used, it sets the exclusiveMaximum attribute in the OpenAPI definition to true, indicating that the numeric value must be strictly less than the specified maximum value.
    This parameter is typically paired with a -Maximum parameter to define the upper bound.

.PARAMETER ExclusiveMinimum
    Specifies an exclusive lower limit for a numeric property in the OpenAPI schema.
    When this parameter is used, it sets the exclusiveMinimun attribute in the OpenAPI definition to true, indicating that the numeric value must be strictly less than the specified minimun value.
    This parameter is typically paired with a -Minimum parameter to define the lower bound.

.PARAMETER MultiplesOf
    The integer must be in multiples of the supplied value.

.PARAMETER Description
    A Description of the property.

.PARAMETER ExternalDoc
    If supplied, add an additional external documentation for this operation.
    The parameter is created by Add-PodeOAExternalDoc

.PARAMETER Example
    An example of a parameter value

.PARAMETER Enum
    An optional array of values that this property can only be set to.

.PARAMETER Required
    If supplied, the object will be treated as Required where supported.

.PARAMETER Deprecated
    If supplied, the object will be treated as Deprecated where supported.

.PARAMETER Object
    If supplied, the integer will be automatically wrapped in an object.

.PARAMETER Nullable
    If supplied, the integer will be treated as Nullable.

.PARAMETER ReadOnly
    If supplied, the integer will be included in a response but not in a request

.PARAMETER WriteOnly
    If supplied, the integer will be included in a request but not in a response

.PARAMETER NoAdditionalProperties
    If supplied, will configure the OpenAPI property additionalProperties to false.
    This means that the defined object will not allow any properties beyond those explicitly declared in its schema.
    If any additional properties are provided, they will be considered invalid.
    Use this switch to enforce a strict schema definition, ensuring that objects contain only the specified set of properties and no others.

.PARAMETER AdditionalProperties
    Define a set of additional properties for the OpenAPI schema. This parameter accepts a HashTable where each key-value pair represents a property name and its corresponding schema.
    The schema for each property can include type, format, description, and other OpenAPI specification attributes.
    When specified, these additional properties are included in the OpenAPI definition, allowing for more flexible and dynamic object structures.

.PARAMETER Array
    If supplied, the object will be treated as an array of objects.

.PARAMETER UniqueItems
    If supplied, specify that all items in the array must be unique

.PARAMETER MinItems
    If supplied, specify minimum length of an array

.PARAMETER MaxItems
    If supplied, specify maximum length of an array

.PARAMETER XmlName
    By default, XML elements get the same names that fields in the API declaration have. This property change the XML name of the property
    reflecting the 'xml.name' attribute in the OpenAPI specification.

.PARAMETER XmlNamespace
    Defines a specific XML namespace for the property, corresponding to the 'xml.namespace' attribute in OpenAPI.

.PARAMETER XmlPrefix
    Sets a prefix for the XML element name, aligning with the 'xml.prefix' attribute in OpenAPI.

.PARAMETER XmlAttribute
    Indicates whether the property should be serialized as an XML attribute, equivalent to the 'xml.attribute' attribute in OpenAPI.

.PARAMETER XmlItemName
    Specifically for properties treated as arrays, it defines the XML name for each item in the array. This parameter aligns with the 'xml.name' attribute under 'items' in OpenAPI.

.PARAMETER XmlWrapped
    Indicates whether array items should be wrapped in an XML element, similar to the 'xml.wrapped' attribute in OpenAPI.


.EXAMPLE
    New-PodeOAIntProperty -Name 'age' -Required
    Creates a required integer property named 'age'.

.EXAMPLE
    New-PodeOAIntProperty -Name 'count' -Minimum 0 -Maximum 10 -Default 5 -Description 'Item count'
    Creates an integer property 'count' with a minimum value of 0, maximum of 10, default value of 5, and a description.

.EXAMPLE
    New-PodeOAIntProperty -Name 'quantity' -XmlName 'Quantity' -XmlNamespace 'http://example.com/quantity' -XmlPrefix 'q'
    Creates an integer property 'quantity' with a custom XML element name 'Quantity', using a specified namespace and prefix.

.EXAMPLE
    New-PodeOAIntProperty -Array -XmlItemName 'unit' -XmlName 'units' | Add-PodeOAComponentSchema -Name 'Units'
    Generates a schema where the integer property is treated as an array, with each array item named 'unit' in XML, and the array itself represented with the XML name 'units'.


#>
function New-PodeOAIntProperty {
    [CmdletBinding(DefaultParameterSetName = 'Inbuilt')]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param(
        [Parameter(ValueFromPipeline = $true, Position = 0, DontShow = $true)]
        [hashtable[]]
        $ParamsList,

        [Parameter()]
        [ValidatePattern('^[a-zA-Z0-9\.\-_]+$')]
        [Alias('Title')]
        [string]
        $Name,

        [Parameter()]
        [ValidateSet('', 'Int32', 'Int64')]
        [string]
        $Format,

        [Parameter()]
        [int]
        $Default,

        [Parameter()]
        [int]
        $Minimum,

        [Parameter()]
        [int]
        $Maximum,

        [Parameter()]
        [switch]
        $ExclusiveMaximum,

        [Parameter()]
        [switch]
        $ExclusiveMinimum,

        [Parameter()]
        [int]
        $MultiplesOf,

        [Parameter()]
        [string]
        $Description,

        [Parameter()]
        [string]
        $ExternalDoc,

        [Parameter()]
        [object]
        $Example,

        [Parameter()]
        [int[]]
        $Enum,

        [switch]
        $Required,

        [switch]
        $Deprecated,

        [switch]
        $Object,

        [switch]
        $Nullable,

        [switch]
        $ReadOnly,

        [switch]
        $WriteOnly,

        [switch]
        $NoAdditionalProperties,

        [hashtable]
        $AdditionalProperties,

        [string]
        $XmlName,

        [string]
        $XmlNamespace,

        [string]
        $XmlPrefix,

        [switch]
        $XmlAttribute,

        [Parameter(  ParameterSetName = 'Array')]
        [string]
        $XmlItemName,

        [Parameter(  ParameterSetName = 'Array')]
        [switch]
        $XmlWrapped,

        [Parameter(Mandatory = $true, ParameterSetName = 'Array')]
        [switch]
        $Array,

        [Parameter(ParameterSetName = 'Array')]
        [switch]
        $UniqueItems,

        [Parameter(ParameterSetName = 'Array')]
        [int]
        $MinItems,

        [Parameter(ParameterSetName = 'Array')]
        [int]
        $MaxItems
    )
    begin {
        $param = New-PodeOAPropertyInternal -type 'integer' -Params $PSBoundParameters

        $collectedInput = [System.Collections.Generic.List[hashtable]]::new()
    }
    process {
        if ($ParamsList) {
            $collectedInput.AddRange($ParamsList)
        }
    }

    end {
        if ($collectedInput) {
            return $collectedInput + $param
        }
        else {
            return $param
        }
    }
}


<#
.SYNOPSIS
    Creates a new OpenAPI New-PodeOAMultiTypeProperty property.

.DESCRIPTION
    Creates a new OpenAPI multi type property, for Schemas or Parameters.
    OpenAPI version 3.1 is required to use this cmdlet.

.LINK
    https://swagger.io/docs/specification/basic-structure/

.LINK
    https://swagger.io/docs/specification/data-models/

.PARAMETER ParamsList
    Used to pipeline multiple properties

.PARAMETER Name
    The Name of the property.

.PARAMETER Type
    The parameter types

.PARAMETER Format
    The inbuilt OpenAPI Format  . (Default: Any)

.PARAMETER CustomFormat
    The name of a custom OpenAPI Format  . (Default: None)
    (String type only)

.PARAMETER Default
    The default value of the property. (Default: $null)

.PARAMETER Pattern
    A Regex pattern that the string must match.
    (String type only)

.PARAMETER Description
    A Description of the property.

.PARAMETER Minimum
    The minimum value of the number.
    (Integer,Number types only)

.PARAMETER Maximum
    The maximum value of the number.
    (Integer,Number types only)

.PARAMETER ExclusiveMaximum
    Specifies an exclusive upper limit for a numeric property in the OpenAPI schema.
    When this parameter is used, it sets the exclusiveMaximum attribute in the OpenAPI definition to true, indicating that the numeric value must be strictly less than the specified maximum value.
    This parameter is typically paired with a -Maximum parameter to define the upper bound.
    (Integer,Number types only)

.PARAMETER ExclusiveMinimum
    Specifies an exclusive lower limit for a numeric property in the OpenAPI schema.
    When this parameter is used, it sets the exclusiveMinimun attribute in the OpenAPI definition to true, indicating that the numeric value must be strictly less than the specified minimun value.
    This parameter is typically paired with a -Minimum parameter to define the lower bound.
    (Integer,Number types only)

.PARAMETER MultiplesOf
    The number must be in multiples of the supplied value.
    (Integer,Number types only)

.PARAMETER Properties
    An array of other int/string/etc properties wrap up as an object.
    (Object type only)

.PARAMETER ExternalDoc
    If supplied, add an additional external documentation for this operation.
    The parameter is created by Add-PodeOAExternalDoc

.PARAMETER Example
    An example of a parameter value

.PARAMETER Enum
    An optional array of values that this property can only be set to.

.PARAMETER Required
    If supplied, the string will be treated as Required where supported.

.PARAMETER Deprecated
    If supplied, the string will be treated as Deprecated where supported.

.PARAMETER Object
    If supplied, the string will be automatically wrapped in an object.

.PARAMETER Nullable
    If supplied, the string will be treated as Nullable.

.PARAMETER ReadOnly
    If supplied, the string will be included in a response but not in a request

.PARAMETER WriteOnly
    If supplied, the string will be included in a request but not in a response

.PARAMETER MinLength
    If supplied, the string will be restricted to minimal length of characters.

.PARAMETER  MaxLength
    If supplied, the string will be restricted to maximal length of characters.

.PARAMETER NoProperties
    If supplied, no properties are allowed in the object.
    If no properties are assigned to the object and the NoProperties parameter is not set the object accept any property.(Object type only)

.PARAMETER MinProperties
    If supplied, will restrict the minimun number of properties allowed in an object.
    (Object type only)

.PARAMETER MaxProperties
    If supplied, will restrict the maximum number of properties allowed in an object.
    (Object type only)

.PARAMETER NoAdditionalProperties
    If supplied, will configure the OpenAPI property additionalProperties to false.
    This means that the defined object will not allow any properties beyond those explicitly declared in its schema.
    If any additional properties are provided, they will be considered invalid.
    Use this switch to enforce a strict schema definition, ensuring that objects contain only the specified set of properties and no others.

.PARAMETER AdditionalProperties
    Define a set of additional properties for the OpenAPI schema. This parameter accepts a HashTable where each key-value pair represents a property name and its corresponding schema.
    The schema for each property can include type, format, description, and other OpenAPI specification attributes.
    When specified, these additional properties are included in the OpenAPI definition, allowing for more flexible and dynamic object structures.

.PARAMETER Array
    If supplied, the object will be treated as an array of objects.

.PARAMETER UniqueItems
    If supplied, specify that all items in the array must be unique

.PARAMETER MinItems
    If supplied, specify minimum length of an array

.PARAMETER MaxItems
    If supplied, specify maximum length of an array

.PARAMETER DiscriminatorProperty
    If supplied, specifies the name of the property used to distinguish between different subtypes in a polymorphic schema in OpenAPI.
    This string value represents the property in the payload that indicates which specific subtype schema should be applied.
    It's essential in scenarios where an API endpoint handles data that conforms to one of several derived schemas from a common base schema.

.PARAMETER DiscriminatorMapping
    If supplied, define a mapping between the values of the discriminator property and the corresponding subtype schemas.
    This parameter accepts a HashTable where each key-value pair maps a discriminator value to a specific subtype schema name.
    It's used in conjunction with the -DiscriminatorProperty to provide complete discrimination logic in polymorphic scenarios.

.PARAMETER XmlName
    By default, XML elements get the same names that fields in the API declaration have. This property change the XML name of the property
    reflecting the 'xml.name' attribute in the OpenAPI specification.

.PARAMETER XmlNamespace
    Defines a specific XML namespace for the property, corresponding to the 'xml.namespace' attribute in OpenAPI.

.PARAMETER XmlPrefix
    Sets a prefix for the XML element name, aligning with the 'xml.prefix' attribute in OpenAPI.

.PARAMETER XmlAttribute
    Indicates whether the property should be serialized as an XML attribute, equivalent to the 'xml.attribute' attribute in OpenAPI.

.PARAMETER XmlItemName
    Specifically for properties treated as arrays, it defines the XML name for each item in the array. This parameter aligns with the 'xml.name' attribute under 'items' in OpenAPI.

.PARAMETER XmlWrapped
    Indicates whether array items should be wrapped in an XML element, similar to the 'xml.wrapped' attribute in OpenAPI.

.EXAMPLE
    New-PodeOAMultiTypeProperty -Name 'userType' -type integer,boolean

.EXAMPLE
    New-PodeOAMultiTypeProperty -Name 'password' -type string,object -Format Password -Properties (New-PodeOAStringProperty -Name 'password' -Format Password)
#>
function New-PodeOAMultiTypeProperty {
    [CmdletBinding(DefaultParameterSetName = 'Inbuilt')]
    param(
        [Parameter(ValueFromPipeline = $true, Position = 0, DontShow = $true )]
        [hashtable[]]
        $ParamsList,

        [Parameter(Mandatory)]
        [ValidateSet( 'integer', 'number', 'string', 'object', 'boolean' )]
        [string]
        $Type,

        [Parameter()]
        [ValidatePattern('^[a-zA-Z0-9\.\-_]+$')]
        [Alias('Title')]
        [string]
        $Name,

        [Parameter( ParameterSetName = 'Array')]
        [Parameter(ParameterSetName = 'Inbuilt')]
        [ValidateSet('', 'Int32', 'Int64', 'Double', 'Float', 'Binary', 'Base64', 'Byte', 'Date', 'Date-Time', 'Password', 'Email', 'Uuid', 'Uri', 'Hostname', 'Ipv4', 'Ipv6')]
        [string]
        $Format,

        [Parameter( ParameterSetName = 'Array')]
        [Parameter(ParameterSetName = 'Custom')]
        [string]
        $CustomFormat,

        [Parameter()]
        $Default,

        [Parameter()]
        [string]
        $Pattern,

        [Parameter()]
        [hashtable[]]
        $Properties,

        [Parameter()]
        [string]
        $Description,

        [Parameter()]
        [double]
        $Minimum,

        [Parameter()]
        [double]
        $Maximum,

        [Parameter()]
        [switch]
        $ExclusiveMaximum,

        [Parameter()]
        [switch]
        $ExclusiveMinimum,

        [Parameter()]
        [double]
        $MultiplesOf,

        [Parameter()]
        [string]
        $ExternalDoc,

        [Parameter()]
        [object]
        $Example,

        [Parameter()]
        [object[]]
        $Enum,

        [switch]
        $Required,

        [switch]
        $Deprecated,

        [switch]
        $Object,

        [switch]
        $Nullable,

        [switch]
        $ReadOnly,

        [switch]
        $WriteOnly,

        [Parameter()]
        [int]
        $MinLength,

        [Parameter()]
        [int]
        $MaxLength,

        [switch]
        $NoProperties,

        [int]
        $MinProperties,

        [int]
        $MaxProperties,

        [switch]
        $NoAdditionalProperties,

        [hashtable]
        $AdditionalProperties,

        [string]
        $XmlName,

        [string]
        $XmlNamespace,

        [string]
        $XmlPrefix,

        [switch]
        $XmlAttribute,

        [Parameter(  ParameterSetName = 'Array')]
        [string]
        $XmlItemName,

        [Parameter(  ParameterSetName = 'Array')]
        [switch]
        $XmlWrapped,

        [Parameter(Mandatory = $true, ParameterSetName = 'Array')]
        [switch]
        $Array,

        [Parameter(ParameterSetName = 'Array')]
        [switch]
        $UniqueItems,

        [Parameter(ParameterSetName = 'Array')]
        [int]
        $MinItems,

        [Parameter(ParameterSetName = 'Array')]
        [int]
        $MaxItems,

        [string]
        $DiscriminatorProperty,

        [hashtable]
        $DiscriminatorMapping
    )
    begin {
        $param = New-PodeOAPropertyInternal   -Params $PSBoundParameters

        if ($type -contains 'string') {
            if (![string]::IsNullOrWhiteSpace($CustomFormat)) {
                $_format = $CustomFormat
            }
            elseif ($Format) {
                $_format = $Format
            }


            if ($Format -or $CustomFormat) {
                $param.format = $_format.ToLowerInvariant()
            }
        }
        if ($type -contains 'object') {
            if ($NoProperties) {
                if ($Properties -or $MinProperties -or $MaxProperties) {
                    # The parameter 'NoProperties' is mutually exclusive with 'Properties', 'MinProperties' and 'MaxProperties'
                    throw ($PodeLocale.noPropertiesMutuallyExclusiveExceptionMessage)
                }
                $param.properties = @($null)
            }
            elseif ($Properties) {
                $param.properties = $Properties
            }
            else {
                $param.properties = @()
            }
            if ($DiscriminatorProperty) {
                $param.discriminator = [ordered]@{
                    'propertyName' = $DiscriminatorProperty
                }
                if ($DiscriminatorMapping) {
                    $param.discriminator.mapping = $DiscriminatorMapping
                }
            }
            elseif ($DiscriminatorMapping) {
                # The parameter 'DiscriminatorMapping' can only be used when 'DiscriminatorProperty' is present
                throw ($PodeLocale.discriminatorMappingRequiresDiscriminatorPropertyExceptionMessage)
            }
        }
        if ($type -contains 'boolean') {
            if ($Default) {
                if ([bool]::TryParse($Default, [ref]$null) -or $Enum -icontains $Default) {
                    $param.default = $Default
                }
                else {
                    # The default value is not a boolean and is not part of the enum
                    throw ($PodeLocale.defaultValueNotBooleanOrEnumExceptionMessage)
                }
            }
        }
        $collectedInput = [System.Collections.Generic.List[hashtable]]::new()
    }
    process {
        if ($ParamsList) {
            $collectedInput.AddRange($ParamsList)
        }
    }

    end {
        if ($collectedInput) {
            return $collectedInput + $param
        }
        else {
            return $param
        }
    }
}


<#
.SYNOPSIS
    Creates a new OpenAPI number property.

.DESCRIPTION
    Creates a new OpenAPI number property, for Schemas or Parameters.

.LINK
    https://swagger.io/docs/specification/basic-structure/

.LINK
    https://swagger.io/docs/specification/data-models/

.PARAMETER ParamsList
    Used to pipeline multiple properties

.PARAMETER Name
    The Name of the property.

.PARAMETER Format
    The inbuilt OpenAPI Format of the number. (Default: Any)

.PARAMETER Default
    The default value of the property. (Default: 0)

.PARAMETER Minimum
    The minimum value of the number. (Default: Double.Min)

.PARAMETER Maximum
    The maximum value of the number. (Default: Double.Max)

.PARAMETER ExclusiveMaximum
    Specifies an exclusive upper limit for a numeric property in the OpenAPI schema.
    When this parameter is used, it sets the exclusiveMaximum attribute in the OpenAPI definition to true, indicating that the numeric value must be strictly less than the specified maximum value.
    This parameter is typically paired with a -Maximum parameter to define the upper bound.

.PARAMETER ExclusiveMinimum
    Specifies an exclusive lower limit for a numeric property in the OpenAPI schema.
    When this parameter is used, it sets the exclusiveMinimun attribute in the OpenAPI definition to true, indicating that the numeric value must be strictly less than the specified minimun value.
    This parameter is typically paired with a -Minimum parameter to define the lower bound.

.PARAMETER MultiplesOf
    The number must be in multiples of the supplied value.

.PARAMETER Description
    A Description of the property.

.PARAMETER ExternalDoc
    If supplied, add an additional external documentation for this operation.
    The parameter is created by Add-PodeOAExternalDoc

.PARAMETER Example
    An example of a parameter value

.PARAMETER Enum
    An optional array of values that this property can only be set to.

.PARAMETER Required
    If supplied, the object will be treated as Required where supported.

.PARAMETER Deprecated
    If supplied, the object will be treated as Deprecated where supported.

.PARAMETER Object
    If supplied, the number will be automatically wrapped in an object.

.PARAMETER Nullable
    If supplied, the number will be treated as Nullable.

.PARAMETER ReadOnly
    If supplied, the number will be included in a response but not in a request

.PARAMETER WriteOnly
    If supplied, the number will be included in a request but not in a response

.PARAMETER NoAdditionalProperties
    If supplied, will configure the OpenAPI property additionalProperties to false.
    This means that the defined object will not allow any properties beyond those explicitly declared in its schema.
    If any additional properties are provided, they will be considered invalid.
    Use this switch to enforce a strict schema definition, ensuring that objects contain only the specified set of properties and no others.

.PARAMETER AdditionalProperties
    Define a set of additional properties for the OpenAPI schema. This parameter accepts a HashTable where each key-value pair represents a property name and its corresponding schema.
    The schema for each property can include type, format, description, and other OpenAPI specification attributes.
    When specified, these additional properties are included in the OpenAPI definition, allowing for more flexible and dynamic object structures.

.PARAMETER Array
    If supplied, the object will be treated as an array of objects.

.PARAMETER UniqueItems
    If supplied, specify that all items in the array must be unique

.PARAMETER MinItems
    If supplied, specify minimum length of an array

.PARAMETER MaxItems
    If supplied, specify maximum length of an array

.PARAMETER XmlName
    By default, XML elements get the same names that fields in the API declaration have. This property change the XML name of the property
    reflecting the 'xml.name' attribute in the OpenAPI specification.

.PARAMETER XmlNamespace
    Defines a specific XML namespace for the property, corresponding to the 'xml.namespace' attribute in OpenAPI.

.PARAMETER XmlPrefix
    Sets a prefix for the XML element name, aligning with the 'xml.prefix' attribute in OpenAPI.

.PARAMETER XmlAttribute
    Indicates whether the property should be serialized as an XML attribute, equivalent to the 'xml.attribute' attribute in OpenAPI.

.PARAMETER XmlItemName
    Specifically for properties treated as arrays, it defines the XML name for each item in the array. This parameter aligns with the 'xml.name' attribute under 'items' in OpenAPI.

.PARAMETER XmlWrapped
    Indicates whether array items should be wrapped in an XML element, similar to the 'xml.wrapped' attribute in OpenAPI.

.EXAMPLE
    New-PodeOANumberProperty -Name 'gravity' -Default 9.8
#>
function New-PodeOANumberProperty {
    [CmdletBinding(DefaultParameterSetName = 'Inbuilt')]
    param(
        [Parameter(ValueFromPipeline = $true, Position = 0, DontShow = $true )]
        [hashtable[]]
        $ParamsList,

        [Parameter()]
        [ValidatePattern('^[a-zA-Z0-9\.\-_]+$')]
        [Alias('Title')]
        [string]
        $Name,

        [Parameter()]
        [ValidateSet('', 'Double', 'Float')]
        [string]
        $Format,

        [Parameter()]
        [double]
        $Default,

        [Parameter()]
        [double]
        $Minimum,

        [Parameter()]
        [double]
        $Maximum,

        [Parameter()]
        [switch]
        $ExclusiveMaximum,

        [Parameter()]
        [switch]
        $ExclusiveMinimum,

        [Parameter()]
        [double]
        $MultiplesOf,

        [Parameter()]
        [string]
        $Description,

        [Parameter()]
        [string]
        $ExternalDoc,

        [Parameter()]
        [object]
        $Example,

        [Parameter()]
        [double[]]
        $Enum,

        [switch]
        $Required,

        [switch]
        $Deprecated,

        [switch]
        $Object,

        [switch]
        $Nullable,

        [switch]
        $ReadOnly,

        [switch]
        $WriteOnly,

        [switch]
        $NoAdditionalProperties,

        [hashtable]
        $AdditionalProperties,

        [string]
        $XmlName,

        [string]
        $XmlNamespace,

        [string]
        $XmlPrefix,

        [switch]
        $XmlAttribute,

        [Parameter(  ParameterSetName = 'Array')]
        [string]
        $XmlItemName,

        [Parameter(  ParameterSetName = 'Array')]
        [switch]
        $XmlWrapped,

        [Parameter(Mandatory = $true, ParameterSetName = 'Array')]
        [switch]
        $Array,

        [Parameter(ParameterSetName = 'Array')]
        [switch]
        $UniqueItems,

        [Parameter(ParameterSetName = 'Array')]
        [int]
        $MinItems,

        [Parameter(ParameterSetName = 'Array')]
        [int]
        $MaxItems
    )
    begin {
        $param = New-PodeOAPropertyInternal -type 'number' -Params $PSBoundParameters

        $collectedInput = [System.Collections.Generic.List[hashtable]]::new()
    }
    process {
        if ($ParamsList) {
            $collectedInput.AddRange($ParamsList)
        }
    }

    end {
        if ($collectedInput) {
            return $collectedInput + $param
        }
        else {
            return $param
        }
    }
}


<#
.SYNOPSIS
    Creates a new OpenAPI object property from other properties.

.DESCRIPTION
    Creates a new OpenAPI object property from other properties, for Schemas or Parameters.

.LINK
    https://swagger.io/docs/specification/basic-structure/

.LINK
    https://swagger.io/docs/specification/data-models/

.PARAMETER ParamsList
    Used to pipeline multiple properties

.PARAMETER Name
    The Name of the property.

.PARAMETER Properties
    An array of other int/string/etc properties wrap up as an object.

.PARAMETER Description
    A Description of the property.

.PARAMETER ExternalDoc
    If supplied, add an additional external documentation for this operation.
    The parameter is created by Add-PodeOAExternalDoc

.PARAMETER Example
    An example of a parameter value

.PARAMETER Deprecated
    If supplied, the object will be treated as Deprecated where supported.

.PARAMETER Required
    If supplied, the object will be treated as Required where supported.

.PARAMETER Array
    If supplied, the object will be treated as an array of objects.

.PARAMETER Nullable
    If supplied, the object will be treated as Nullable.

.PARAMETER ReadOnly
    If supplied, the object will be included in a response but not in a request

.PARAMETER WriteOnly
    If supplied, the object will be included in a request but not in a response

.PARAMETER NoProperties
    If supplied, no properties are allowed in the object. If no properties are assigned to the object and the NoProperties parameter is not set the object accept any property

.PARAMETER MinProperties
    If supplied, will restrict the minimun number of properties allowed in an object.

.PARAMETER MaxProperties
    If supplied, will restrict the maximum number of properties allowed in an object.

.PARAMETER NoAdditionalProperties
    If supplied, will configure the OpenAPI property additionalProperties to false.
    This means that the defined object will not allow any properties beyond those explicitly declared in its schema.
    If any additional properties are provided, they will be considered invalid.
    Use this switch to enforce a strict schema definition, ensuring that objects contain only the specified set of properties and no others.

.PARAMETER AdditionalProperties
    Define a set of additional properties for the OpenAPI schema. This parameter accepts a HashTable where each key-value pair represents a property name and its corresponding schema.
    The schema for each property can include type, format, description, and other OpenAPI specification attributes.
    When specified, these additional properties are included in the OpenAPI definition, allowing for more flexible and dynamic object structures.

.PARAMETER Array
    If supplied, the object will be treated as an array of objects.

.PARAMETER UniqueItems
    If supplied, specify that all items in the array must be unique

.PARAMETER MinItems
    If supplied, specify minimum length of an array

.PARAMETER MaxItems
    If supplied, specify maximum length of an array

.PARAMETER DiscriminatorProperty
    If supplied, specifies the name of the property used to distinguish between different subtypes in a polymorphic schema in OpenAPI.
    This string value represents the property in the payload that indicates which specific subtype schema should be applied.
    It's essential in scenarios where an API endpoint handles data that conforms to one of several derived schemas from a common base schema.

.PARAMETER DiscriminatorMapping
    If supplied, define a mapping between the values of the discriminator property and the corresponding subtype schemas.
    This parameter accepts a HashTable where each key-value pair maps a discriminator value to a specific subtype schema name.
    It's used in conjunction with the -DiscriminatorProperty to provide complete discrimination logic in polymorphic scenarios.

.PARAMETER XmlName
    By default, XML elements get the same names that fields in the API declaration have. This property change the XML name of the property
    reflecting the 'xml.name' attribute in the OpenAPI specification.

.PARAMETER XmlNamespace
    Defines a specific XML namespace for the property, corresponding to the 'xml.namespace' attribute in OpenAPI.

.PARAMETER XmlPrefix
    Sets a prefix for the XML element name, aligning with the 'xml.prefix' attribute in OpenAPI.

.PARAMETER XmlAttribute
    Indicates whether the property should be serialized as an XML attribute, equivalent to the 'xml.attribute' attribute in OpenAPI.

.PARAMETER XmlItemName
    Specifically for properties treated as arrays, it defines the XML name for each item in the array. This parameter aligns with the 'xml.name' attribute under 'items' in OpenAPI.

.PARAMETER XmlWrapped
    Indicates whether array items should be wrapped in an XML element, similar to the 'xml.wrapped' attribute in OpenAPI.

.EXAMPLE
    New-PodeOAObjectProperty -Name 'user' -Properties @('<ARRAY_OF_PROPERTIES>')

.EXAMPLE
    New-PodeOABoolProperty -Name 'enabled' -Required|
    New-PodeOAObjectProperty  -Name 'extraProperties'  -AdditionalProperties [ordered]@{
    "property1" = [ordered]@{ "type" = "string"; "description" = "Description for property1" };
    "property2" = [ordered]@{ "type" = "integer"; "format" = "int32" }
    }
#>
function New-PodeOAObjectProperty {
    [CmdletBinding(DefaultParameterSetName = 'Inbuilt')]
    param(

        [Parameter(ValueFromPipeline = $true, Position = 0, DontShow = $true )]
        [hashtable[]]
        $ParamsList,

        [Parameter()]
        [ValidatePattern('^[a-zA-Z0-9\.\-_]+$')]
        [Alias('Title')]
        [string]
        $Name,

        [Parameter()]
        [hashtable[]]
        $Properties,

        [Parameter()]
        [string]
        $Description,

        [Parameter()]
        [string]
        $ExternalDoc,

        [Parameter()]
        [object]
        $Example,

        [switch]
        $Deprecated,

        [switch]
        $Required,

        [switch]
        $Nullable,

        [switch]
        $ReadOnly,

        [switch]
        $WriteOnly,

        [switch]
        $NoProperties,

        [int]
        $MinProperties,

        [int]
        $MaxProperties,

        [switch]
        $NoAdditionalProperties,

        [hashtable]
        $AdditionalProperties,

        [string]
        $XmlName,

        [string]
        $XmlNamespace,

        [string]
        $XmlPrefix,

        [switch]
        $XmlAttribute,

        [Parameter(  ParameterSetName = 'Array')]
        [string]
        $XmlItemName,

        [Parameter(  ParameterSetName = 'Array')]
        [switch]
        $XmlWrapped,

        [Parameter(  Mandatory, ParameterSetName = 'Array')]
        [switch]
        $Array,

        [Parameter(ParameterSetName = 'Array')]
        [switch]
        $UniqueItems,

        [Parameter(ParameterSetName = 'Array')]
        [int]
        $MinItems,

        [Parameter(ParameterSetName = 'Array')]
        [int]
        $MaxItems,

        [string]
        $DiscriminatorProperty,

        [hashtable]
        $DiscriminatorMapping
    )
    begin {
        $param = New-PodeOAPropertyInternal -type 'object' -Params $PSBoundParameters
        if ($NoProperties) {
            if ($Properties -or $MinProperties -or $MaxProperties) {
                # The parameter `NoProperties` is mutually exclusive with `Properties`, `MinProperties` and `MaxProperties`
                throw ($PodeLocale.noPropertiesMutuallyExclusiveExceptionMessage)
            }
            $PropertiesFromPipeline = $false
        }
        elseif ($Properties) {
            $param.properties = $Properties
            $PropertiesFromPipeline = $false
        }
        else {
            $param.properties = @()
            $PropertiesFromPipeline = $true
        }
        if ($DiscriminatorProperty) {
            $param.discriminator = [ordered]@{
                'propertyName' = $DiscriminatorProperty
            }
            if ($DiscriminatorMapping) {
                $param.discriminator.mapping = $DiscriminatorMapping
            }
        }
        elseif ($DiscriminatorMapping) {
            # The parameter 'DiscriminatorMapping' can only be used when 'DiscriminatorProperty' is present
            throw ($PodeLocale.discriminatorMappingRequiresDiscriminatorPropertyExceptionMessage)
        }
        $collectedInput = [System.Collections.Generic.List[hashtable]]::new()
    }
    process {
        if ($ParamsList) {
            if ($PropertiesFromPipeline) {
                $param.properties += $ParamsList

            }
            else {
                $collectedInput.AddRange($ParamsList)
            }
        }
    }

    end {
        if ($PropertiesFromPipeline) {
            return $param
        }
        elseif ($collectedInput) {
            return $collectedInput + $param
        }
        else {
            return $param
        }
    }
}


<#
.SYNOPSIS
    Creates a new OpenAPI string property.

.DESCRIPTION
    Creates a new OpenAPI string property, for Schemas or Parameters.

.LINK
    https://swagger.io/docs/specification/basic-structure/

.LINK
    https://swagger.io/docs/specification/data-models/

.PARAMETER ParamsList
    Used to pipeline multiple properties

.PARAMETER Name
    The Name of the property.

.PARAMETER Format
    The inbuilt OpenAPI Format of the string. (Default: Any)

.PARAMETER CustomFormat
    The name of a custom OpenAPI Format of the string. (Default: None)

.PARAMETER Default
    The default value of the property. (Default: $null)

.PARAMETER Pattern
    A Regex pattern that the string must match.

.PARAMETER Description
    A Description of the property.

.PARAMETER ExternalDoc
    If supplied, add an additional external documentation for this operation.
    The parameter is created by Add-PodeOAExternalDoc

.PARAMETER Example
    An example of a parameter value

.PARAMETER Enum
    An optional array of values that this property can only be set to.

.PARAMETER Required
    If supplied, the string will be treated as Required where supported.

.PARAMETER Deprecated
    If supplied, the string will be treated as Deprecated where supported.

.PARAMETER Object
    If supplied, the string will be automatically wrapped in an object.

.PARAMETER Nullable
    If supplied, the string will be treated as Nullable.

.PARAMETER ReadOnly
    If supplied, the string will be included in a response but not in a request

.PARAMETER WriteOnly
    If supplied, the string will be included in a request but not in a response

.PARAMETER MinLength
    If supplied, the string will be restricted to minimal length of characters.

.PARAMETER  MaxLength
    If supplied, the string will be restricted to maximal length of characters.

.PARAMETER NoAdditionalProperties
    If supplied, will configure the OpenAPI property additionalProperties to false.
    This means that the defined object will not allow any properties beyond those explicitly declared in its schema.
    If any additional properties are provided, they will be considered invalid.
    Use this switch to enforce a strict schema definition, ensuring that objects contain only the specified set of properties and no others.

.PARAMETER AdditionalProperties
    Define a set of additional properties for the OpenAPI schema. This parameter accepts a HashTable where each key-value pair represents a property name and its corresponding schema.
    The schema for each property can include type, format, description, and other OpenAPI specification attributes.
    When specified, these additional properties are included in the OpenAPI definition, allowing for more flexible and dynamic object structures.

.PARAMETER Array
    If supplied, the object will be treated as an array of objects.

.PARAMETER UniqueItems
    If supplied, specify that all items in the array must be unique

.PARAMETER MinItems
    If supplied, specify minimum length of an array

.PARAMETER MaxItems
    If supplied, specify maximum length of an array

.PARAMETER XmlName
    By default, XML elements get the same names that fields in the API declaration have. This property change the XML name of the property
    reflecting the 'xml.name' attribute in the OpenAPI specification.

.PARAMETER XmlNamespace
    Defines a specific XML namespace for the property, corresponding to the 'xml.namespace' attribute in OpenAPI.

.PARAMETER XmlPrefix
    Sets a prefix for the XML element name, aligning with the 'xml.prefix' attribute in OpenAPI.

.PARAMETER XmlAttribute
    Indicates whether the property should be serialized as an XML attribute, equivalent to the 'xml.attribute' attribute in OpenAPI.

.PARAMETER XmlItemName
    Specifically for properties treated as arrays, it defines the XML name for each item in the array. This parameter aligns with the 'xml.name' attribute under 'items' in OpenAPI.

.PARAMETER XmlWrapped
    Indicates whether array items should be wrapped in an XML element, similar to the 'xml.wrapped' attribute in OpenAPI.

.EXAMPLE
    New-PodeOAStringProperty -Name 'userType' -Default 'admin'

.EXAMPLE
    New-PodeOAStringProperty -Name 'password' -Format Password
#>
function New-PodeOAStringProperty {
    [CmdletBinding(DefaultParameterSetName = 'Inbuilt')]
    param(
        [Parameter(ValueFromPipeline = $true, Position = 0, DontShow = $true )]
        [hashtable[]]
        $ParamsList,

        [Parameter()]
        [ValidatePattern('^[a-zA-Z0-9\.\-_]+$')]
        [Alias('Title')]
        [string]
        $Name,

        [Parameter( ParameterSetName = 'Array')]
        [Parameter(ParameterSetName = 'Inbuilt')]
        [ValidateSet('', 'Binary', 'Base64', 'Byte', 'Date', 'Date-Time', 'Password', 'Email', 'Uuid', 'Uri', 'Hostname', 'Ipv4', 'Ipv6')]
        [string]
        $Format,

        [Parameter( ParameterSetName = 'Array')]
        [Parameter(ParameterSetName = 'Custom')]
        [string]
        $CustomFormat,

        [Parameter()]
        [string]
        $Default,

        [Parameter()]
        [string]
        $Pattern,

        [Parameter()]
        [string]
        $Description,

        [Parameter()]
        [string]
        $ExternalDoc,

        [Parameter()]
        [object]
        $Example,

        [Parameter()]
        [string[]]
        $Enum,

        [switch]
        $Required,

        [switch]
        $Deprecated,

        [switch]
        $Object,

        [switch]
        $Nullable,

        [switch]
        $ReadOnly,

        [switch]
        $WriteOnly,

        [Parameter()]
        [int]
        $MinLength,

        [Parameter()]
        [int]
        $MaxLength,

        [switch]
        $NoAdditionalProperties,

        [hashtable]
        $AdditionalProperties,

        [string]
        $XmlName,

        [string]
        $XmlNamespace,

        [string]
        $XmlPrefix,

        [switch]
        $XmlAttribute,

        [Parameter(  ParameterSetName = 'Array')]
        [string]
        $XmlItemName,

        [Parameter(  ParameterSetName = 'Array')]
        [switch]
        $XmlWrapped,

        [Parameter(Mandatory = $true, ParameterSetName = 'Array')]
        [switch]
        $Array,

        [Parameter(ParameterSetName = 'Array')]
        [switch]
        $UniqueItems,

        [Parameter(ParameterSetName = 'Array')]
        [int]
        $MinItems,

        [Parameter(ParameterSetName = 'Array')]
        [int]
        $MaxItems
    )
    begin {
        if (![string]::IsNullOrWhiteSpace($CustomFormat)) {
            $_format = $CustomFormat
        }
        elseif ($Format) {
            $_format = $Format
        }
        $param = New-PodeOAPropertyInternal -type 'string' -Params $PSBoundParameters

        if ($Format -or $CustomFormat) {
            $param.format = $_format.ToLowerInvariant()
        }

        $collectedInput = [System.Collections.Generic.List[hashtable]]::new()
    }
    process {
        if ($ParamsList) {
            $collectedInput.AddRange($ParamsList)
        }
    }

    end {
        if ($collectedInput) {
            return $collectedInput + $param
        }
        else {
            return $param
        }
    }
}


<#
.SYNOPSIS
    Adds OpenAPI callback configurations to routes in a Pode web application.

.PARAMETER Route
    The route to update info, usually from -PassThru on Add-PodeRoute.

.DESCRIPTION
    The Add-PodeOACallBack function is used for defining OpenAPI callback configurations for routes in a Pode server.
    It enables setting up API specifications including detailed parameters, request body schemas, and response structures for various HTTP methods.

.PARAMETER Path
    Specifies the callback path, usually a relative URL.
    The key that identifies the Path Item Object is a runtime expression evaluated in the context of a runtime HTTP request/response to identify the URL for the callback request.
    A simple example is `$request.body#/url`.
    The runtime expression allows complete access to the HTTP message, including any part of a body that a JSON Pointer (RFC6901) can reference.
    More information on JSON Pointer can be found at [RFC6901](https://datatracker.ietf.org/doc/html/rfc6901).

.PARAMETER Name
    Alias for 'Name'. A unique identifier for the callback.
    It must be a valid string of alphanumeric characters, periods (.), hyphens (-), and underscores (_).

.PARAMETER Reference
    A reference to a reusable CallBack component.

.PARAMETER Method
    Defines the HTTP method for the callback (e.g., GET, POST, PUT). Supports standard HTTP methods and a wildcard (*) for all methods.

.PARAMETER Parameters
    The Parameter definitions the request uses (from ConvertTo-PodeOAParameter).

.PARAMETER RequestBody
    Defines the schema of the request body. Can be set using New-PodeOARequestBody.

.PARAMETER Responses
    Defines the possible responses for the callback. Can be set using New-PodeOAResponse.

.PARAMETER DefinitionTag
    A array of string representing the unique tag for the API specification.
    This tag helps distinguish between different versions or types of API specifications within the application.
    You can use this tag to reference the specific API documentation, schema, or version that your function interacts with.

.PARAMETER PassThru
    If supplied, the route passed in will be returned for further chaining.

.EXAMPLE
    Add-PodeOACallBack -Title 'test' -Path '{$request.body#/id}' -Method Post `
    -RequestBody (New-PodeOARequestBody -Content @{'*/*' = (New-PodeOAStringProperty -Name 'id')}) `
    -Response (
    New-PodeOAResponse -StatusCode 200 -Description 'Successful operation'  -Content (New-PodeOAContentMediaType -ContentType 'application/json','application/xml' -Content 'Pet'  -Array)
    New-PodeOAResponse -StatusCode 400 -Description 'Invalid ID supplied' |
    New-PodeOAResponse -StatusCode 404 -Description 'Pet not found' |
    New-PodeOAResponse -Default -Description 'Something is wrong'
    )
    This example demonstrates adding a POST callback to handle a request body and define various responses based on different status codes.

.NOTES
    Ensure that the provided parameters match the expected schema and formats of Pode and OpenAPI specifications.
    The function is useful for dynamically configuring and documenting API callbacks in a Pode server environment.
#>
function Add-PodeOACallBack {
    [CmdletBinding(DefaultParameterSetName = 'inbuilt')]
    [OutputType([hashtable[]])]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [hashtable[]]
        $Route,

        [Parameter(Mandatory = $true , ParameterSetName = 'inbuilt')]
        [Parameter(Mandatory = $false, ParameterSetName = 'Reference')]
        [ValidatePattern('^[a-zA-Z0-9\.\-_]+$')]
        [string]
        $Name,

        [Parameter(Mandatory = $true, ParameterSetName = 'Reference')]
        [string]
        $Reference,

        [Parameter(Mandatory = $true , ParameterSetName = 'inbuilt')]
        [string]
        $Path,

        [Parameter(Mandatory = $true, ParameterSetName = 'inbuilt')]
        [ValidateSet('Connect', 'Delete', 'Get', 'Head', 'Merge', 'Options', 'Patch', 'Post', 'Put', 'Trace', '*')]
        [string]
        $Method,

        [Parameter(ParameterSetName = 'inbuilt')]
        [hashtable[]]
        $Parameters,

        [Parameter(ParameterSetName = 'inbuilt')]
        [hashtable]
        $RequestBody,

        [Parameter(ParameterSetName = 'inbuilt')]
        [hashtable]
        $Responses,

        [switch]
        $PassThru,

        [string[]]
        $DefinitionTag
    )
    begin {
        # Initialize an array to hold piped-in values
        $pipelineValue = @()
    }

    process {
        # Add the current piped-in value to the array
        $pipelineValue += $_
    }

    end {
        # Set Route to the array of values
        if ($pipelineValue.Count -gt 1) {
            $Route = $pipelineValue
        }


        foreach ($r in @($Route)) {
            $oaDefinitionTag = Test-PodeRouteOADefinitionTag -Route $r -DefinitionTag $DefinitionTag

            foreach ($tag in $oaDefinitionTag) {
                if ($Reference) {
                    Test-PodeOAComponentInternal -Field callbacks -DefinitionTag $tag -Name $Reference -PostValidation
                    if (!$Name) {
                        $Name = $Reference
                    }
                    if (! ($r.OpenApi.CallBacks.Keys -Contains $tag)) {
                        $r.OpenApi.CallBacks[$tag] = [ordered]@{}
                    }
                    $r.OpenApi.CallBacks[$tag].$Name = [ordered]@{
                        '$ref' = "#/components/callbacks/$Reference"
                    }
                }
                else {
                    if (! ($r.OpenApi.CallBacks.Keys -Contains $tag)) {
                        $r.OpenApi.CallBacks[$tag] = [ordered]@{}
                    }
                    $r.OpenApi.CallBacks[$tag].$Name = New-PodeOAComponentCallBackInternal -Params $PSBoundParameters -DefinitionTag $tag
                }
            }
        }

        if ($PassThru) {
            return $Route
        }
    }
}


<#
.SYNOPSIS
    Add an external docs reference to the OpenApi document.

.DESCRIPTION
    Add an external docs reference to the OpenApi document.

.PARAMETER ExternalDoc
    An externalDoc object


.PARAMETER Name
    The Name of the reference.

.PARAMETER url
    The link to the external documentation

.PARAMETER Description
    A Description of the external documentation.

.PARAMETER DefinitionTag
    An Array of strings representing the unique tag for the API specification.
    This tag helps distinguish between different versions or types of API specifications within the application.
    You can use this tag to reference the specific API documentation, schema, or version that your function interacts with.

.EXAMPLE
    Add-PodeOAExternalDoc  -Name 'SwaggerDocs' -Description 'Find out more about Swagger' -Url 'http://swagger.io'

.EXAMPLE
    $ExtDoc = New-PodeOAExternalDoc  -Name 'SwaggerDocs' -Description 'Find out more about Swagger' -Url 'http://swagger.io'
    $ExtDoc|Add-PodeOAExternalDoc
#>
function Add-PodeOAExternalDoc {
    [CmdletBinding(DefaultParameterSetName = 'Pipe')]
    param(
        [Parameter(ValueFromPipeline = $true, Position = 0, DontShow = $true, ParameterSetName = 'Pipe')]
        [System.Collections.Specialized.OrderedDictionary ]
        $ExternalDoc,

        [Parameter(Mandatory = $true, ParameterSetName = 'NewRef')]
        [ValidateScript({ $_ -imatch '^https?://.+' })]
        $Url,

        [Parameter(ParameterSetName = 'NewRef')]
        [string]
        $Description,

        [string[]]
        $DefinitionTag
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
        $DefinitionTag = Test-PodeOADefinitionTag -Tag $DefinitionTag

        foreach ($tag in $DefinitionTag) {
            if ($PSCmdlet.ParameterSetName -ieq 'NewRef') {
                $param = [ordered]@{url = $Url }
                if ($Description) {
                    $param.description = $Description
                }
                $PodeContext.Server.OpenAPI.Definitions[$tag].externalDocs = $param
            }
            else {
                $PodeContext.Server.OpenAPI.Definitions[$tag].externalDocs = $ExternalDoc
            }
        }
    }
}


<#
.SYNOPSIS
    Sets metadate for the supplied route.

.DESCRIPTION
    Sets metadate for the supplied route, such as Summary and Tags.

.PARAMETER Route
    The route to update info, usually from -PassThru on Add-PodeRoute.

.PARAMETER Path
    The URI path for the Route.

.PARAMETER Method
    The HTTP Method of this Route, multiple can be supplied.

.PARAMETER Servers
    A list of external endpoint. created with New-PodeOAServerEndpoint

.PARAMETER PassThru
    If supplied, the route passed in will be returned for further chaining.

.PARAMETER DefinitionTag
    An Array of strings representing the unique tag for the API specification.
    This tag helps distinguish between different versions or types of API specifications within the application.
    You can use this tag to reference the specific API documentation, schema, or version that your function interacts with.

.EXAMPLE
    Add-PodeOAExternalRoute -PassThru -Method Get -Path '/peta/:id' -Servers (
    New-PodeOAServerEndpoint -Url 'http://ext.server.com/api/v12' -Description 'ext test server' |
    New-PodeOAServerEndpoint -Url 'http://ext13.server.com/api/v12' -Description 'ext test server 13'
    ) |
    Set-PodeOARouteInfo -Summary 'Find pets by ID' -Description 'Returns pets based on ID'  -OperationId 'getPetsById' -PassThru |
    Set-PodeOARequest -PassThru -Parameters @(
    (New-PodeOAStringProperty -Name 'id' -Description 'ID of pet to use' -array | ConvertTo-PodeOAParameter -In Path -Style Simple -Required )) |
    Add-PodeOAResponse -StatusCode 200 -Description 'pet response'   -Content (@{ '*/*' = New-PodeOASchemaProperty   -ComponentSchema 'Pet' -array }) -PassThru |
    Add-PodeOAResponse -Default  -Description 'error payload' -Content (@{'text/html' = 'ErrorModel' }) -PassThru
.EXAMPLE
    Add-PodeRoute -PassThru -Method Get -Path '/peta/:id'  -ScriptBlock {
    Write-PodeJsonResponse -Value 'done' -StatusCode 200
    } | Add-PodeOAExternalRoute -PassThru   -Servers (
    New-PodeOAServerEndpoint -Url 'http://ext.server.com/api/v12' -Description 'ext test server' |
    New-PodeOAServerEndpoint -Url 'http://ext13.server.com/api/v12' -Description 'ext test server 13'
    ) |
    Set-PodeOARouteInfo -Summary 'Find pets by ID' -Description 'Returns pets based on ID'  -OperationId 'getPetsById' -PassThru |
    Set-PodeOARequest -PassThru -Parameters @(
    (New-PodeOAStringProperty -Name 'id' -Description 'ID of pet to use' -array | ConvertTo-PodeOAParameter -In Path -Style Simple -Required )) |
    Add-PodeOAResponse -StatusCode 200 -Description 'pet response'   -Content (@{ '*/*' = New-PodeOASchemaProperty   -ComponentSchema 'Pet' -array }) -PassThru |
    Add-PodeOAResponse -Default  -Description 'error payload' -Content (@{'text/html' = 'ErrorModel' }) -PassThru
#>
function Add-PodeOAExternalRoute {
    [CmdletBinding(DefaultParameterSetName = 'Pipeline')]
    [OutputType([hashtable[]], ParameterSetName = 'Pipeline')]
    [OutputType([hashtable], ParameterSetName = 'builtin')]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0, ParameterSetName = 'Pipeline')]
        [ValidateNotNullOrEmpty()]
        [hashtable[]]
        $Route,

        [Parameter(Mandatory = $true , ParameterSetName = 'BuiltIn')]
        [string]
        $Path,

        [Parameter(Mandatory = $true)]
        [ValidateScript({ $_.Count -gt 0 })]
        [hashtable[]]
        $Servers,

        [Parameter(Mandatory = $true, ParameterSetName = 'BuiltIn')]
        [ValidateSet('Connect', 'Delete', 'Get', 'Head', 'Merge', 'Options', 'Patch', 'Post', 'Put', 'Trace', '*')]
        [string]
        $Method,

        [switch]
        $PassThru,

        [Parameter( ParameterSetName = 'BuiltIn')]
        [string[]]
        $DefinitionTag
    )
    begin {
        # Initialize an array to hold piped-in values
        $pipelineValue = @()
    }

    process {
        if ($PSCmdlet.ParameterSetName -eq 'Pipeline') {
            # Add the current piped-in value to the array
            $pipelineValue += $_
        }
    }

    end {
        $DefinitionTag = Test-PodeOADefinitionTag -Tag $DefinitionTag

        switch ($PSCmdlet.ParameterSetName.ToLowerInvariant()) {
            'builtin' {

                # ensure the route has appropriate slashes
                $Path = Update-PodeRouteSlash -Path $Path
                $OpenApiPath = ConvertTo-PodeOARoutePath -Path $Path
                $Path = Resolve-PodePlaceholder -Path $Path
                $extRoute = @{
                    Method  = $Method.ToLower()
                    Path    = $Path
                    Local   = $false
                    OpenApi = @{
                        Path           = $OpenApiPath
                        Responses      = [ordered]@{}
                        Parameters     = [ordered]@{}
                        RequestBody    = [ordered]@{}
                        callbacks      = [ordered]@{}
                        Authentication = @()
                        Servers        = $Servers
                        DefinitionTag  = $DefinitionTag
                    }
                }
                foreach ($tag in $DefinitionTag) {
                    #add the default OpenApi responses
                    if ( $PodeContext.Server.OpenAPI.Definitions[$tag].hiddenComponents.defaultResponses) {
                        $extRoute.OpenApi.Responses = Copy-PodeObjectDeepClone -InputObject $PodeContext.Server.OpenAPI.Definitions[$tag].hiddenComponents.defaultResponses
                    }
                    if (! (Test-PodeOAComponentExternalPath -DefinitionTag $tag -Name $Path)) {
                        $PodeContext.Server.OpenAPI.Definitions[$tag].hiddenComponents.externalPath[$Path] = [ordered]@{}
                    }

                    $PodeContext.Server.OpenAPI.Definitions[$tag].hiddenComponents.externalPath.$Path[$Method] = $extRoute
                }

                if ($PassThru) {
                    return $extRoute
                }
            }

            'pipeline' {
                # Set Route to the array of values
                if ($pipelineValue.Count -gt 1) {
                    $Route = $pipelineValue
                }

                foreach ($r in $Route) {
                    $r.OpenApi.Servers = $Servers
                }
                if ($PassThru) {
                    return $Route
                }
            }
        }
    }
}


<#
.SYNOPSIS
    Creates an OpenAPI metadata.

.DESCRIPTION
    Creates an OpenAPI metadata like TermOfService, license and so on.
    The metadata MAY be used by the clients if needed, and MAY be presented in editing or documentation generation tools for convenience.

.PARAMETER Title
    The Title of the API.

.PARAMETER Version
    The Version of the API.
    The OpenAPI Specification is versioned using Semantic Versioning 2.0.0 (semver) and follows the semver specification.
    https://semver.org/spec/v2.0.0.html

.PARAMETER Description
    A short description of the API.
    CommonMark syntax MAY be used for rich text representation.
    https://spec.commonmark.org/

.PARAMETER TermsOfService
    A URL to the Terms of Service for the API. MUST be in the format of a URL.

.PARAMETER LicenseName
    The license name used for the API.

.PARAMETER LicenseUrl
    A URL to the license used for the API. MUST be in the format of a URL.

.PARAMETER ContactName
    The identifying name of the contact person/organization.

.PARAMETER ContactEmail
    The email address of the contact person/organization. MUST be in the format of an email address.

.PARAMETER ContactUrl
    The URL pointing to the contact information. MUST be in the format of a URL.

.PARAMETER DefinitionTag
    A string representing the unique tag for the API specification.
    This tag helps distinguish between different versions or types of API specifications within the application.
    You can use this tag to reference the specific API documentation, schema, or version that your function interacts with.

.EXAMPLE
    Add-PodeOAInfo -TermsOfService 'http://swagger.io/terms/' -License 'Apache 2.0' -LicenseUrl 'http://www.apache.org/licenses/LICENSE-2.0.html' -ContactName 'API Support' -ContactEmail 'apiteam@swagger.io' -ContactUrl 'http://example.com/support'
#>
function Add-PodeOAInfo {
    param(
        [string]
        $Title,

        [ValidatePattern('^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$')]
        [string]
        $Version ,

        [string]
        $Description,

        [ValidateScript({ $_ -imatch '^https?://.+' })]
        [string]
        $TermsOfService,

        [string]
        $LicenseName,

        [ValidateScript({ $_ -imatch '^https?://.+' })]
        [string]
        $LicenseUrl,

        [string]
        $ContactName,

        [ValidateScript({ $_ -imatch '^\w+([-+.]\w+)*@\w+([-.]\w+)*\.\w+([-.]\w+)*$' })]
        [string]
        $ContactEmail,

        [ValidateScript({ $_ -imatch '^https?://.+' })]
        [string]
        $ContactUrl,

        [string]
        $DefinitionTag
    )

    $DefinitionTag = Test-PodeOADefinitionTag -Tag $DefinitionTag

    $Info = [ordered]@{}

    if ($LicenseName) {
        $Info.license = [ordered]@{
            'name' = $LicenseName
        }
    }
    if ($LicenseUrl) {
        if ( $Info.license ) {
            $Info.license.url = $LicenseUrl
        }
        else {
            # The OpenAPI object 'license' required the property 'name'. Use -LicenseName parameter.
            throw ($PodeLocale.openApiLicenseObjectRequiresNameExceptionMessage)
        }
    }


    if ($Title) {
        $Info.title = $Title
    }
    elseif (  $PodeContext.Server.OpenAPI.Definitions[$DefinitionTag].info.title) {
        $Info.title = $PodeContext.Server.OpenAPI.Definitions[$DefinitionTag].info.title
    }

    if ($Version) {
        $Info.version = $Version
    }
    elseif ( $PodeContext.Server.OpenAPI.Definitions[$DefinitionTag].info.version) {
        $Info.version = $PodeContext.Server.OpenAPI.Definitions[$DefinitionTag].info.version
    }
    else {
        $Info.version = '1.0.0'
    }

    if ($Description ) {
        $Info.description = $Description
    }
    elseif ( $PodeContext.Server.OpenAPI.Definitions[$DefinitionTag].info.description) {
        $Info.description = $PodeContext.Server.OpenAPI.Definitions[$DefinitionTag].info.description
    }

    if ($TermsOfService) {
        $Info['termsOfService'] = $TermsOfService
    }

    if ($ContactName -or $ContactEmail -or $ContactUrl ) {
        $Info['contact'] = [ordered]@{}

        if ($ContactName) {
            $Info['contact'].name = $ContactName
        }

        if ($ContactEmail) {
            $Info['contact'].email = $ContactEmail
        }

        if ($ContactUrl) {
            $Info['contact'].url = $ContactUrl
        }
    }
    $PodeContext.Server.OpenAPI.Definitions[$DefinitionTag].info = $Info

}


<#
.SYNOPSIS
    Adds a response definition to the supplied route.

.DESCRIPTION
    Adds a response definition to the supplied route.

.PARAMETER Route
    The route to add the response definition, usually from -PassThru on Add-PodeRoute.

.PARAMETER StatusCode
    The HTTP StatusCode for the response.To define a range of response codes, this field MAY contain the uppercase wildcard character `X`.
    For example, `2XX` represents all response codes between `[200-299]`. Only the following range definitions are allowed: `1XX`, `2XX`, `3XX`, `4XX`, and `5XX`.
    If a response is defined using an explicit code, the explicit code definition takes precedence over the range definition for that code.

.PARAMETER Content
    The content-types and schema the response returns (the schema is created using the Property functions).
    Alias: ContentSchemas

.PARAMETER Headers
    The header name and schema the response returns (the schema is created using Add-PodeOAComponentHeader cmd-let).
    Alias: HeaderSchemas

.PARAMETER Description
    A Description of the response. (Default: the HTTP StatusCode description)

.PARAMETER Reference
    A Reference Name of an existing component response to use.

.PARAMETER Links
    A Response link definition

.PARAMETER Default
    If supplied, the response will be used as a default response - this overrides the StatusCode supplied.

.PARAMETER PassThru
    If supplied, the route passed in will be returned for further chaining.

.PARAMETER DefinitionTag
    An Array of strings representing the unique tag for the API specification.
    This tag helps distinguish between different versions or types of API specifications within the application.
    You can use this tag to reference the specific API documentation, schema, or version that your function interacts with.

.EXAMPLE
    Add-PodeRoute -PassThru | Add-PodeOAResponse -StatusCode 200 -Content @{ 'application/json' = (New-PodeOAIntProperty -Name 'userId' -Object) }

.EXAMPLE
    Add-PodeRoute -PassThru | Add-PodeOAResponse -StatusCode 200 -Content @{ 'application/json' = 'UserIdSchema' }

.EXAMPLE
    Add-PodeRoute -PassThru | Add-PodeOAResponse -StatusCode 200 -Reference 'OKResponse'
#>
function Add-PodeOAResponse {
    [CmdletBinding(DefaultParameterSetName = 'Schema')]
    [OutputType([hashtable[]])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [hashtable[]]
        $Route,

        [Parameter(Mandatory = $true, ParameterSetName = 'Schema')]
        [Parameter(Mandatory = $true, ParameterSetName = 'Reference')]
        [ValidatePattern('^([1-5][0-9][0-9]|[1-5]XX)$')]
        [string]
        $StatusCode,

        [Parameter(ParameterSetName = 'Schema')]
        [Parameter(ParameterSetName = 'SchemaDefault')]
        [Alias('ContentSchemas')]
        [hashtable]
        $Content,

        [Alias('HeaderSchemas')]
        [AllowEmptyString()]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ $_ -is [string] -or $_ -is [string[]] -or $_ -is [hashtable] -or $_ -is [System.Collections.Specialized.OrderedDictionary] })]
        $Headers,

        [Parameter(Mandatory = $false, ParameterSetName = 'Schema')]
        [Parameter(Mandatory = $false, ParameterSetName = 'SchemaDefault')]
        [string]
        $Description,

        [Parameter(Mandatory = $true, ParameterSetName = 'Reference')]
        [Parameter(ParameterSetName = 'ReferenceDefault')]
        [string]
        $Reference,

        [Parameter(Mandatory = $true, ParameterSetName = 'ReferenceDefault')]
        [Parameter(Mandatory = $true, ParameterSetName = 'SchemaDefault')]
        [switch]
        $Default,

        [Parameter(ParameterSetName = 'Schema')]
        [Parameter(ParameterSetName = 'SchemaDefault')]
        [System.Collections.Specialized.OrderedDictionary ]
        $Links,

        [switch]
        $PassThru,

        [string[]]
        $DefinitionTag
    )
    begin {
        # Initialize an array to hold piped-in values
        $pipelineValue = @()
    }

    process {
        # Add the current piped-in value to the array
        $pipelineValue += $_
    }

    end {
        # Set Route to the array of values
        if ($pipelineValue.Count -gt 1) {
            $Route = $pipelineValue
        }

        # override status code with default
        if ($Default) {
            $code = 'default'
        }
        else {
            $code = "$($StatusCode)"
        }

        # add the respones to the routes
        foreach ($r in @($Route)) {
            $oaDefinitionTag = Test-PodeRouteOADefinitionTag -Route $r -DefinitionTag $DefinitionTag

            foreach ($tag in $oaDefinitionTag) {
                if (! $r.OpenApi.Responses.$tag) {
                    $r.OpenApi.Responses.$tag = [ordered]@{}
                }
                $r.OpenApi.Responses.$tag[$code] = New-PodeOResponseInternal  -DefinitionTag $tag -Params $PSBoundParameters
            }
        }

        if ($PassThru) {
            return $Route
        }
    }
}


<#
.SYNOPSIS
    Creates an OpenAPI Server Object.

.DESCRIPTION
    Creates an OpenAPI Server Object.

.PARAMETER Url
    A URL to the target host.  This URL supports Server Variables and MAY be relative, to indicate that the host location is relative to the location where the OpenAPI document is being served.
    Variable substitutions will be made when a variable is named in `{`brackets`}`.

.PARAMETER Description
    An optional string describing the host designated by the URL. [CommonMark syntax](https://spec.commonmark.org/) MAY be used for rich text representation.

.PARAMETER Variables
    A map between a variable name and its value.  The value is used for substitution in the server's URL template.

.PARAMETER DefinitionTag
    An Array of strings representing the unique tag for the API specification.
    This tag helps distinguish between different versions or types of API specifications within the application.
    You can use this tag to reference the specific API documentation, schema, or version that your function interacts with.

.EXAMPLE
    Add-PodeOAServerEndpoint -Url 'https://myserver.io/api' -Description 'My test server'

.EXAMPLE
    Add-PodeOAServerEndpoint -Url '/api' -Description 'My local server'

.EXAMPLE
    Add-PodeOAServerEndpoint -Url "https://{username}.gigantic-server.com:{port}/{basePath}" -Description "The production API server" `
    -Variable   @{
    username = @{
    default = 'demo'
    description = 'this value is assigned by the service provider, in this example gigantic-server.com'
    }
    port = @{
    enum = @('System.Object[]') # Assuming 'System.Object[]' is a placeholder for actual values
    default = 8443
    }
    basePath = @{
    default = 'v2'
    }
    }
    }
#>
function Add-PodeOAServerEndpoint {
    param (
        [Parameter(Mandatory = $true)]
        [ValidatePattern('^(https?://|/).+')]
        [string]
        $Url,

        [string]
        $Description,

        [System.Collections.Specialized.OrderedDictionary]
        $Variables,

        [string[]]
        $DefinitionTag
    )


    # If the DefinitionTag is empty, use the selected tag from Pode's OpenAPI context
    if (Test-PodeIsEmpty -Value $DefinitionTag) {
        $DefinitionTag = @($PodeContext.Server.OpenAPI.SelectedDefinitionTag)
    }

    # Loop through each tag to add the server object to the corresponding OpenAPI definition
    foreach ($tag in $DefinitionTag) {
        # If the 'servers' array for the tag doesn't exist, initialize it as an empty array
        if (! $PodeContext.Server.OpenAPI.Definitions[$tag].servers) {
            $PodeContext.Server.OpenAPI.Definitions[$tag].servers = @()
        }

        # Create an ordered hashtable representing the server object with the URL
        $lUrl = [ordered]@{url = $Url }

        # If a description is provided, add it to the server object
        if ($Description) {
            $lUrl.description = $Description
        }

        # If variables are provided, add them to the server object
        if ($Variables) {
            $lUrl.variables = $Variables
        }

        # Check if the URL is a local endpoint (not starting with 'http(s)://')
        if ($lUrl.url -notmatch '^(?i)https?://') {
            # Loop through existing server URLs in the definition
            foreach ($srv in $PodeContext.Server.OpenAPI.Definitions[$tag].servers) {
                # If there's already a local endpoint, throw an exception, as only one local endpoint is allowed per definition
                # Both are defined as local OpenAPI endpoints, but only one local endpoint is allowed per API definition.
                if ($srv.url -notmatch '^(?i)https?://') {
                    throw ($PodeLocale.localEndpointConflictExceptionMessage -f $Url, $srv.url)
                }
            }
        }

        # Add the new server object to the OpenAPI definition for the current tag
        $PodeContext.Server.OpenAPI.Definitions[$tag].servers += $lUrl
    }
}


<#
.SYNOPSIS
    Creates a OpenAPI Tag reference property.

.DESCRIPTION
    Creates a new OpenAPI tag reference.

.PARAMETER Name
    The Name of the tag.

.PARAMETER Description
    A Description of the tag.

.PARAMETER ExternalDoc
    If supplied, the tag references an existing external documentation reference.
    The parameter is created by Add-PodeOAExternalDoc

.PARAMETER DefinitionTag
    An Array of strings representing the unique tag for the API specification.
    This tag helps distinguish between different versions or types of API specifications within the application.
    You can use this tag to reference the specific API documentation, schema, or version that your function interacts with.

.EXAMPLE
    Add-PodeOATag -Name 'store' -Description 'Access to Petstore orders' -ExternalDoc 'SwaggerDocs'
#>
function Add-PodeOATag {
    param(
        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[a-zA-Z0-9\.\-_]+$')]
        [string]
        $Name,

        [string]
        $Description,

        [System.Collections.Specialized.OrderedDictionary]
        $ExternalDoc,

        [string[]]
        $DefinitionTag
    )

    $DefinitionTag = Test-PodeOADefinitionTag -Tag $DefinitionTag

    foreach ($tag in $DefinitionTag) {
        $param = [ordered]@{
            'name' = $Name
        }

        if ($Description) {
            $param.description = $Description
        }

        if ($ExternalDoc) {
            $param.externalDocs = $ExternalDoc
        }

        $PodeContext.Server.OpenAPI.Definitions[$tag].tags[$Name] = $param
    }
}


<#
.SYNOPSIS
    Sets metadate for the supplied route.

.DESCRIPTION
    Sets metadate for the supplied route, such as Summary and Tags.

.PARAMETER Name
    Alias for 'Name'. A unique identifier for the webhook.
    It must be a valid string of alphanumeric characters, periods (.), hyphens (-), and underscores (_).

.PARAMETER Method
    The HTTP Method of this Route, multiple can be supplied.

.PARAMETER PassThru
    If supplied, the route passed in will be returned for further chaining.

.PARAMETER DefinitionTag
    An Array of strings representing the unique tag for the API specification.
    This tag helps distinguish between different versions or types of API specifications within the application.
    You can use this tag to reference the specific API documentation, schema, or version that your function interacts with.

.EXAMPLE
    Add-PodeOAWebhook -PassThru -Method Get    |
    Set-PodeOARouteInfo -Summary 'Find pets by ID' -Description 'Returns pets based on ID'  -OperationId 'getPetsById' -PassThru |
    Set-PodeOARequest -PassThru -Parameters @(
    (New-PodeOAStringProperty -Name 'id' -Description 'ID of pet to use' -array | ConvertTo-PodeOAParameter -In Path -Style Simple -Required )) |
    Add-PodeOAResponse -StatusCode 200 -Description 'pet response'   -Content (@{ '*/*' = New-PodeOASchemaProperty   -ComponentSchema 'Pet' -array }) -PassThru |
    Add-PodeOAResponse -Default  -Description 'error payload' -Content (@{'text/html' = 'ErrorModel' }) -PassThru
#>
function Add-PodeOAWebhook {
    param(

        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[a-zA-Z0-9\.\-_]+$')]
        [string]
        $Name,

        [Parameter(Mandatory = $true )]
        [ValidateSet('Connect', 'Delete', 'Get', 'Head', 'Merge', 'Options', 'Patch', 'Post', 'Put', 'Trace', '*')]
        [string]
        $Method,

        [switch]
        $PassThru,

        [string[]]
        $DefinitionTag
    )

    $_definitionTag = Test-PodeOADefinitionTag -Tag $DefinitionTag

    $refRoute = @{
        Method      = $Method.ToLower()
        NotPrepared = $true
        OpenApi     = @{
            Responses          = [ordered]@{}
            Parameters         = [ordered]@{}
            RequestBody        = [ordered]@{}
            callbacks          = [ordered]@{}
            Authentication     = @()
            DefinitionTag      = $_definitionTag
            IsDefTagConfigured = ($null -ne $DefinitionTag) #Definition Tag has been configured (Not default)
        }
    }
    foreach ($tag in $_definitionTag) {
        if (Test-PodeOAVersion -Version 3.0 -DefinitionTag $tag ) {
            # The Webhooks feature is not supported in OpenAPI v3.0.x
            throw ($PodeLocale.webhooksFeatureNotSupportedInOpenApi30ExceptionMessage)
        }
        $PodeContext.Server.OpenAPI.Definitions[$tag].webhooks[$Name] = $refRoute
    }

    if ($PassThru) {
        return $refRoute
    }
}


<#
.SYNOPSIS
    Converts an OpenAPI property into a Request Parameter.

.DESCRIPTION
    Converts an OpenAPI property (such as from New-PodeOAIntProperty) into a Request Parameter.

.PARAMETER In
    Where in the Request can the parameter be found?

.PARAMETER Property
    The Property that need converting (such as from New-PodeOAIntProperty).

.PARAMETER Reference
    The name of an existing component parameter to be reused.
    Alias: ComponentParameter

.PARAMETER Name
    Assign a name to the parameter

.PARAMETER ContentType
    The content-types to be use with  component schema

.PARAMETER Schema
    The component schema to use.

.PARAMETER Description
    A Description of the property.

.PARAMETER Explode
    If supplied, controls how arrays are serialized in query parameters

.PARAMETER AllowReserved
    If supplied, determines whether the parameter value SHOULD allow reserved characters, as defined by RFC3986 :/?#[]@!$&'()*+,;= to be included without percent-encoding.
    This property only applies to parameters with an in value of query. The default value is false.

.PARAMETER Required
    If supplied, the object will be treated as Required where supported.(Applicable only to ContentSchema)

.PARAMETER AllowEmptyValue
    If supplied, allow the parameter to be empty

.PARAMETER Style
    If supplied, defines how multiple values are delimited. Possible styles depend on the parameter location: path, query, header or cookie.

.PARAMETER Deprecated
    If supplied, specifies that a parameter is deprecated and SHOULD be transitioned out of usage. Default value is false.

.PARAMETER Example
    Example of the parameter's potential value. The example SHOULD match the specified schema and encoding properties if present.
    The Example parameter is mutually exclusive of the Examples parameter.
    Furthermore, if referencing a Schema  that contains an example, the Example value SHALL _override_ the example provided by the schema.
    To represent examples of media types that cannot naturally be represented in JSON or YAML, a string value can contain the example with escaping where necessary.

.PARAMETER Examples
    Examples of the parameter's potential value. Each example SHOULD contain a value in the correct format as specified in the parameter encoding.
    The Examples parameter is mutually exclusive of the Example parameter.
    Furthermore, if referencing a Schema that contains an example, the Examples value SHALL _override_ the example provided by the schema.

.PARAMETER DefinitionTag
    An Array of strings representing the unique tag for the API specification.
    This tag helps distinguish between different versions or types of API specifications within the application.
    You can use this tag to reference the specific API documentation, schema, or version that your function interacts with.

.EXAMPLE
    New-PodeOAIntProperty -Name 'userId' | ConvertTo-PodeOAParameter -In Query

.EXAMPLE
    ConvertTo-PodeOAParameter -Reference 'UserIdParam'

.EXAMPLE
    ConvertTo-PodeOAParameter  -In Header -ContentSchemas @{ 'application/json' = 'UserIdSchema' }

#>
function ConvertTo-PodeOAParameter {
    [CmdletBinding(DefaultParameterSetName = 'Reference')]
    param(
        [Parameter( Mandatory = $true, ParameterSetName = 'Schema')]
        [Parameter(Mandatory = $true, ParameterSetName = 'Properties')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ContentSchema')]
        [Parameter( Mandatory = $true, ParameterSetName = 'ContentProperties')]
        [ValidateSet('Cookie', 'Header', 'Path', 'Query')]
        [string]
        $In,

        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ParameterSetName = 'Properties')]
        [Parameter( Mandatory = $true, Position = 0, ValueFromPipeline = $true, ParameterSetName = 'ContentProperties')]
        [ValidateNotNull()]
        [hashtable]
        $Property,

        [Parameter(Mandatory = $true, ParameterSetName = 'Reference')]
        [Alias('ComponentParameter')]
        [string]
        $Reference,

        [Parameter( ParameterSetName = 'Schema')]
        [Parameter(ParameterSetName = 'Properties')]
        [Parameter(ParameterSetName = 'ContentSchema')]
        [Parameter(  ParameterSetName = 'ContentProperties')]
        [string]
        $Name,

        [Parameter(Mandatory = $true, ParameterSetName = 'Schema')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ContentSchema')]
        [Alias('ComponentSchema')]
        [String]
        $Schema,

        [Parameter( Mandatory = $true, ParameterSetName = 'ContentSchema')]
        [Parameter( Mandatory = $true, ParameterSetName = 'ContentProperties')]
        [String]
        $ContentType,

        [Parameter( ParameterSetName = 'Schema')]
        [Parameter( ParameterSetName = 'ContentSchema')]
        [Parameter( ParameterSetName = 'Properties')]
        [Parameter( ParameterSetName = 'ContentProperties')]
        [String]
        $Description,

        [Parameter( ParameterSetName = 'Schema')]
        [Parameter( ParameterSetName = 'Properties')]
        [Switch]
        $Explode,

        [Parameter( ParameterSetName = 'Schema')]
        [Parameter( ParameterSetName = 'ContentSchema')]
        [Parameter( ParameterSetName = 'Properties')]
        [Parameter( ParameterSetName = 'ContentProperties')]
        [Switch]
        $Required,

        [Parameter( ParameterSetName = 'ContentSchema')]
        [Parameter( ParameterSetName = 'Schema')]
        [Parameter( ParameterSetName = 'Properties')]
        [Switch]
        $AllowEmptyValue,

        [Parameter( ParameterSetName = 'Schema')]
        [Parameter( ParameterSetName = 'Properties')]
        [Switch]
        $AllowReserved,

        [Parameter( ParameterSetName = 'Schema')]
        [Parameter( ParameterSetName = 'ContentSchema')]
        [Parameter( ParameterSetName = 'Properties')]
        [Parameter( ParameterSetName = 'ContentProperties')]
        [object]
        $Example,

        [Parameter( ParameterSetName = 'Schema')]
        [Parameter( ParameterSetName = 'ContentSchema')]
        [Parameter( ParameterSetName = 'Properties')]
        [Parameter( ParameterSetName = 'ContentProperties')]
        [System.Collections.Specialized.OrderedDictionary]
        $Examples,

        [Parameter( ParameterSetName = 'Schema')]
        [Parameter( ParameterSetName = 'Properties')]
        [ValidateSet('Simple', 'Label', 'Matrix', 'Query', 'Form', 'SpaceDelimited', 'PipeDelimited', 'DeepObject' )]
        [string]
        $Style,

        [Parameter( ParameterSetName = 'Schema')]
        [Parameter( ParameterSetName = 'ContentSchema')]
        [Parameter( ParameterSetName = 'Properties')]
        [Parameter( ParameterSetName = 'ContentProperties')]
        [Switch]
        $Deprecated,

        [string[]]
        $DefinitionTag
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

        $DefinitionTag = Test-PodeOADefinitionTag -Tag $DefinitionTag

        if ($PSCmdlet.ParameterSetName -ieq 'ContentSchema' -or $PSCmdlet.ParameterSetName -ieq 'Schema') {
            if (Test-PodeIsEmpty $Schema) {
                return $null
            }
            Test-PodeOAComponentInternal -Field schemas -DefinitionTag $DefinitionTag -Name $Schema -PostValidation
            if (!$Name ) {
                $Name = $Schema
            }
            $prop = [ordered]@{
                in   = $In.ToLowerInvariant()
                name = $Name
            }
            if ($In -ieq 'Header' -and $PodeContext.Server.Security.autoHeaders) {
                Add-PodeSecurityHeader -Name 'Access-Control-Allow-Headers' -Value $Schema -Append
            }
            if ($AllowEmptyValue.IsPresent ) {
                $prop['allowEmptyValue'] = $AllowEmptyValue.IsPresent
            }
            if ($Required.IsPresent ) {
                $prop['required'] = $Required.IsPresent
            }
            if ($Description ) {
                $prop.description = $Description
            }
            if ($Deprecated.IsPresent ) {
                $prop.deprecated = $Deprecated.IsPresent
            }
            if ($ContentType ) {
                # ensure all content types are valid
                if ($ContentType -inotmatch '^[\w-]+\/[\w\.\+-]+$') {
                    # Invalid 'content-type' found for schema: $type
                    throw ($PodeLocale.invalidContentTypeForSchemaExceptionMessage -f $type)
                }
                $prop.content = [ordered]@{
                    $ContentType = [ordered]@{
                        schema = [ordered]@{
                            '$ref' = "#/components/schemas/$($Schema )"
                        }
                    }
                }
                if ($Example ) {
                    $prop.content.$ContentType.example = $Example
                }
                elseif ($Examples) {
                    $prop.content.$ContentType.examples = $Examples
                }
            }
            else {
                $prop.schema = [ordered]@{
                    '$ref' = "#/components/schemas/$($Schema )"
                }
                if ($Style) {
                    switch ($in.ToLower()) {
                        'path' {
                            if (@('Simple', 'Label', 'Matrix' ) -inotcontains $Style) {
                                # OpenApi request Style cannot be $Style for a $in parameter
                                throw ($PodeLocale.openApiRequestStyleInvalidForParameterExceptionMessage -f $Style, $in)
                            }
                            break
                        }
                        'query' {
                            if (@('Form', 'SpaceDelimited', 'PipeDelimited', 'DeepObject' ) -inotcontains $Style) {
                                # OpenApi request Style cannot be $Style for a $in parameter
                                throw ($PodeLocale.openApiRequestStyleInvalidForParameterExceptionMessage -f $Style, $in)
                            }
                            break
                        }
                        'header' {
                            if (@('Simple' ) -inotcontains $Style) {
                                # OpenApi request Style cannot be $Style for a $in parameter
                                throw ($PodeLocale.openApiRequestStyleInvalidForParameterExceptionMessage -f $Style, $in)
                            }
                            break
                        }
                        'cookie' {
                            if (@('Form' ) -inotcontains $Style) {
                                # OpenApi request Style cannot be $Style for a $in parameter
                                throw ($PodeLocale.openApiRequestStyleInvalidForParameterExceptionMessage -f $Style, $in)
                            }
                            break
                        }
                    }
                    $prop['style'] = $Style.Substring(0, 1).ToLower() + $Style.Substring(1)
                }

                if ($Explode.IsPresent ) {
                    $prop['explode'] = $Explode.IsPresent
                }

                if ($AllowEmptyValue.IsPresent ) {
                    $prop['allowEmptyValue'] = $AllowEmptyValue.IsPresent
                }

                if ($AllowReserved.IsPresent) {
                    $prop['allowReserved'] = $AllowReserved.IsPresent
                }

                if ($Example ) {
                    $prop.example = $Example
                }
                elseif ($Examples) {
                    $prop.examples = $Examples
                }
            }
        }
        elseif ($PSCmdlet.ParameterSetName -ieq 'Reference') {
            # return a reference
            Test-PodeOAComponentInternal -Field parameters  -DefinitionTag $DefinitionTag  -Name $Reference -PostValidation
            $prop = [ordered]@{
                '$ref' = "#/components/parameters/$Reference"
            }
            foreach ($tag in $DefinitionTag) {
                if ($PodeContext.Server.OpenAPI.Definitions[$tag].components.parameters.$Reference.In -eq 'Header' -and $PodeContext.Server.Security.autoHeaders) {
                    Add-PodeSecurityHeader -Name 'Access-Control-Allow-Headers' -Value $Reference -Append
                }
            }
        }
        else {

            if (!$Name ) {
                if ($Property.name) {
                    $Name = $Property.name
                }
                else {
                    # The OpenApi parameter requires a name to be specified
                    throw ($PodeLocale.openApiParameterRequiresNameExceptionMessage)
                }
            }
            if ($In -ieq 'Header' -and $PodeContext.Server.Security.autoHeaders -and $Name ) {
                Add-PodeSecurityHeader -Name 'Access-Control-Allow-Headers' -Value $Name -Append
            }

            # build the base parameter
            $prop = [ordered]@{
                in   = $In.ToLowerInvariant()
                name = $Name
            }
            $sch = [ordered]@{}
            if ($Property.array) {
                $sch.type = 'array'
                $sch.items = [ordered]@{
                    type = $Property.type
                }
                if ($Property.format) {
                    $sch.items.format = $Property.format
                }
            }
            else {
                $sch.type = $Property.type
                if ($Property.format) {
                    $sch.format = $Property.format
                }
            }
            if ($ContentType) {
                if ($ContentType -inotmatch '^[\w-]+\/[\w\.\+-]+$') {
                    # Invalid 'content-type' found for schema: $type
                    throw ($PodeLocale.invalidContentTypeForSchemaExceptionMessage -f $type)
                }
                $prop.content = [ordered]@{
                    $ContentType = [ordered] @{
                        schema = $sch
                    }
                }
            }
            else {
                $prop.schema = $sch
            }

            if ($Example -and $Examples) {
                # Parameters 'Examples' and 'Example' are mutually exclusive
                throw ($PodeLocale.parametersMutuallyExclusiveExceptionMessage -f 'Examples' , 'Example' )
            }
            if ($AllowEmptyValue.IsPresent ) {
                $prop['allowEmptyValue'] = $AllowEmptyValue.IsPresent
            }

            if ($Description ) {
                $prop.description = $Description
            }
            elseif ($Property.description) {
                $prop.description = $Property.description
            }

            if ($Required.IsPresent ) {
                $prop.required = $Required.IsPresent
            }
            elseif ($Property.required) {
                $prop.required = $Property.required
            }

            if ($Deprecated.IsPresent ) {
                $prop.deprecated = $Deprecated.IsPresent
            }
            elseif ($Property.deprecated) {
                $prop.deprecated = $Property.deprecated
            }

            if (!$ContentType) {
                if ($Style) {
                    switch ($in.ToLower()) {
                        'path' {
                            if (@('Simple', 'Label', 'Matrix' ) -inotcontains $Style) {
                                # OpenApi request Style cannot be $Style for a $in parameter
                                throw ($PodeLocale.openApiRequestStyleInvalidForParameterExceptionMessage -f $Style, $in)
                            }
                            break
                        }
                        'query' {
                            if (@('Form', 'SpaceDelimited', 'PipeDelimited', 'DeepObject' ) -inotcontains $Style) {
                                # OpenApi request Style cannot be $Style for a $in parameter
                                throw ($PodeLocale.openApiRequestStyleInvalidForParameterExceptionMessage -f $Style, $in)
                            }
                            break
                        }
                        'header' {
                            if (@('Simple' ) -inotcontains $Style) {
                                # OpenApi request Style cannot be $Style for a $in parameter
                                throw ($PodeLocale.openApiRequestStyleInvalidForParameterExceptionMessage -f $Style, $in)
                            }
                            break
                        }
                        'cookie' {
                            if (@('Form' ) -inotcontains $Style) {
                                # OpenApi request Style cannot be $Style for a $in parameter
                                throw ($PodeLocale.openApiRequestStyleInvalidForParameterExceptionMessage -f $Style, $in)
                            }
                            break
                        }
                    }
                    $prop['style'] = $Style.Substring(0, 1).ToLower() + $Style.Substring(1)
                }

                if ($Explode.IsPresent ) {
                    $prop['explode'] = $Explode.IsPresent
                }

                if ($AllowReserved.IsPresent) {
                    $prop['allowReserved'] = $AllowReserved.IsPresent
                }

                if ($Example ) {
                    $prop['example'] = $Example
                }
                elseif ($Examples) {
                    $prop['examples'] = $Examples
                }

                if ($Property.default -and !$prop.required ) {
                    $prop.schema['default'] = $Property.default
                }

                if ($Property.enum) {
                    if ($Property.array) {
                        $prop.schema.items['enum'] = $Property.enum
                    }
                    else {
                        $prop.schema['enum'] = $Property.enum
                    }
                }
            }
            else {
                if ($Example ) {
                    $prop.content.$ContentType.example = $Example
                }
                elseif ($Examples) {
                    $prop.content.$ContentType.examples = $Examples
                }
            }
        }

        if ($In -ieq 'Path' -and !$prop.required ) {
            # If the parameter location is 'Path', the switch parameter 'Required' is mandatory
            throw ($PodeLocale.pathParameterRequiresRequiredSwitchExceptionMessage)
        }

        return $prop
    }
}


<#
.SYNOPSIS
    Adds a route that enables a viewer to display OpenAPI docs, such as Swagger, ReDoc, RapiDoc, StopLight, Explorer, RapiPdf or Bookmarks.

.DESCRIPTION
    Adds a route that enables a viewer to display OpenAPI docs, such as Swagger, ReDoc, RapiDoc, StopLight, Explorer, RapiPdf  or Bookmarks.

.LINK
    https://github.com/mrin9/RapiPdf

.LINK
    https://github.com/Authress-Engineering/openapi-explorer

.LINK
    https://github.com/stoplightio/elements

.LINK
    https://github.com/rapi-doc/RapiDoc

.LINK
    https://github.com/Redocly/redoc

.LINK
    https://github.com/swagger-api/swagger-ui

.PARAMETER Type
    The Type of OpenAPI viewer to use.

.PARAMETER Path
    The route Path where the docs can be accessed. (Default: "/$Type")

.PARAMETER OpenApiUrl
    The URL where the OpenAPI definition can be retrieved. (Default is the OpenAPI path from Enable-PodeOpenApi)

.PARAMETER Middleware
    Like normal Routes, an array of Middleware that will be applied.

.PARAMETER Title
    The title of the web page. (Default is the OpenAPI title from Enable-PodeOpenApi)

.PARAMETER DarkMode
    If supplied, the page will be rendered using a dark theme (this is not supported for all viewers).

.PARAMETER EndpointName
    The EndpointName of an Endpoint(s) to bind the static Route against.This parameter is normally not required.
    The Endpoint is retrieved by the OpenAPI DefinitionTag
.PARAMETER Authentication
    The name of an Authentication method which should be used as middleware on this Route.

.PARAMETER Role
    One or more optional Roles that will be authorised to access this Route, when using Authentication with an Access method.

.PARAMETER Group
    One or more optional Groups that will be authorised to access this Route, when using Authentication with an Access method.

.PARAMETER Scope
    One or more optional Scopes that will be authorised to access this Route, when using Authentication with an Access method.

.PARAMETER Bookmarks
    If supplied, create a new documentation bookmarks page

.PARAMETER Editor
    If supplied, enable the Swagger-Editor

.PARAMETER NoAdvertise
    If supplied, it is not going to state the documentation URL at the startup of the server

.PARAMETER DefinitionTag
    A string representing the unique tag for the API specification.
    This tag helps distinguish between different versions or types of API specifications within the application.
    You can use this tag to reference the specific API documentation, schema, or version that your function interacts with.

.EXAMPLE
    Enable-PodeOAViewer -Type Swagger -DarkMode

.EXAMPLE
    Enable-PodeOAViewer -Type ReDoc -Title 'Some Title' -OpenApi 'http://some-url/openapi'

.EXAMPLE
    Enable-PodeOAViewer -Bookmarks

    Adds a route that enables a viewer to display with links to any documentation tool associated with the OpenApi.
#>
function Enable-PodeOAViewer {
    [CmdletBinding(DefaultParameterSetName = 'Doc')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'Doc')]
        [ValidateSet('Swagger', 'ReDoc', 'RapiDoc', 'StopLight', 'Explorer', 'RapiPdf' )]
        [string]
        $Type,

        [string]
        $Path,

        [string]
        $OpenApiUrl,

        [object[]]
        $Middleware,

        [string]
        $Title,

        [switch]
        $DarkMode,

        [string[]]
        $EndpointName,

        [Parameter()]
        [Alias('Auth')]
        [string]
        $Authentication,

        [Parameter()]
        [string[]]
        $Role,

        [Parameter()]
        [string[]]
        $Group,

        [Parameter()]
        [string[]]
        $Scope,

        [Parameter(Mandatory = $true, ParameterSetName = 'Bookmarks')]
        [switch]
        $Bookmarks,

        [Parameter( ParameterSetName = 'Bookmarks')]
        [switch]
        $NoAdvertise,

        [Parameter(Mandatory = $true, ParameterSetName = 'Editor')]
        [switch]
        $Editor,

        [string]
        $DefinitionTag
    )
    $DefinitionTag = Test-PodeOADefinitionTag -Tag $DefinitionTag

    # If no EndpointName try to reetrieve the EndpointName from the DefinitionTag if exist
    if ([string]::IsNullOrWhiteSpace($EndpointName) -and $PodeContext.Server.OpenAPI.Definitions[$DefinitionTag].hiddenComponents.EndpointName) {
        $EndpointName = $PodeContext.Server.OpenAPI.Definitions[$DefinitionTag].hiddenComponents.EndpointName
    }

    # error if there's no OpenAPI URL
    $OpenApiUrl = Protect-PodeValue -Value $OpenApiUrl -Default $PodeContext.Server.OpenAPI.Definitions[$DefinitionTag].Path
    if ([string]::IsNullOrWhiteSpace($OpenApiUrl)) {
        # No OpenAPI URL supplied for $Type
        throw ($PodeLocale.noOpenApiUrlSuppliedExceptionMessage -f $Type)

    }

    # fail if no title
    $Title = Protect-PodeValue -Value $Title -Default $PodeContext.Server.OpenAPI.Definitions[$DefinitionTag].info.Title
    if ([string]::IsNullOrWhiteSpace($Title)) {
        # No title supplied for $Type page
        throw ($PodeLocale.noTitleSuppliedForPageExceptionMessage -f $Type)
    }

    if ($Editor.IsPresent) {
        # set a default path
        $Path = Protect-PodeValue -Value $Path -Default '/editor'
        if ([string]::IsNullOrWhiteSpace($Title)) {
            # No route path supplied for $Type page
            throw ($PodeLocale.noRoutePathSuppliedForPageExceptionMessage -f $Type)
        }
        if (Test-PodeOAVersion -Version 3.1 -DefinitionTag $DefinitionTag) {
            # This version on Swagger-Editor doesn't support OpenAPI 3.1
            throw ($PodeLocale.swaggerEditorDoesNotSupportOpenApi31ExceptionMessage)
        }
        # setup meta info
        $meta = @{
            Title             = $Title
            OpenApi           = "$($OpenApiUrl)?format=yaml"
            DarkMode          = $DarkMode
            DefinitionTag     = $DefinitionTag
            SwaggerEditorDist = 'https://unpkg.com/swagger-editor-dist@4'
        }
        Add-PodeRoute -Method Get -Path $Path `
            -Middleware $Middleware -ArgumentList $meta `
            -EndpointName $EndpointName -Authentication $Authentication `
            -Role $Role -Scope $Scope -Group $Group `
            -ScriptBlock {
            param($meta)
            $Data = @{
                Title             = $meta.Title
                OpenApi           = $meta.OpenApi
                SwaggerEditorDist = $meta.SwaggerEditorDist
            }

            $podeRoot = Get-PodeModuleMiscPath
            Write-PodeFileResponseInternal -Path ([System.IO.Path]::Combine($podeRoot, 'default-swagger-editor.html.pode')) -Data $Data
        }

        $PodeContext.Server.OpenAPI.Definitions[$DefinitionTag].hiddenComponents.viewer['editor'] = $Path
    }
    elseif ($Bookmarks.IsPresent) {
        # set a default path
        $Path = Protect-PodeValue -Value $Path -Default '/bookmarks'
        if ([string]::IsNullOrWhiteSpace($Title)) {
            # No route path supplied for $Type page
            throw ($PodeLocale.noRoutePathSuppliedForPageExceptionMessage -f $Type)
        }
        # setup meta info
        $meta = @{
            Title         = $Title
            OpenApi       = $OpenApiUrl
            DarkMode      = $DarkMode
            DefinitionTag = $DefinitionTag
        }

        $route = Add-PodeRoute -Method Get -Path $Path `
            -Middleware $Middleware -ArgumentList $meta `
            -EndpointName $EndpointName -Authentication $Authentication `
            -Role $Role -Scope $Scope -Group $Group `
            -PassThru -ScriptBlock {
            param($meta)
            $Data = @{
                Title   = $meta.Title
                OpenApi = $meta.OpenApi
            }
            $DefinitionTag = $meta.DefinitionTag
            foreach ($type in $PodeContext.Server.OpenAPI.Definitions[$DefinitionTag].hiddenComponents.viewer.Keys) {
                $Data[$type] = $true
                $Data["$($type)_path"] = $PodeContext.Server.OpenAPI.Definitions[$DefinitionTag].hiddenComponents.viewer[$type]
            }

            $podeRoot = Get-PodeModuleMiscPath
            Write-PodeFileResponseInternal -Path ([System.IO.Path]::Combine($podeRoot, 'default-doc-bookmarks.html.pode')) -Data $Data
        }
        if (! $NoAdvertise.IsPresent) {
            $PodeContext.Server.OpenAPI.Definitions[$DefinitionTag].hiddenComponents.bookmarks = @{
                path       = $Path
                route      = @()
                openApiUrl = $OpenApiUrl
            }
            $PodeContext.Server.OpenAPI.Definitions[$DefinitionTag].hiddenComponents.bookmarks.route += $route
        }

    }
    else {
        if ($Type -ieq 'RapiPdf' -and (Test-PodeOAVersion -Version 3.1 -DefinitionTag $DefinitionTag)) {
            # The Document tool RapidPdf doesn't support OpenAPI 3.1
            throw ($PodeLocale.rapidPdfDoesNotSupportOpenApi31ExceptionMessage)
        }
        # set a default path
        $Path = Protect-PodeValue -Value $Path -Default "/$($Type.ToLowerInvariant())"
        if ([string]::IsNullOrWhiteSpace($Title)) {
            # No route path supplied for $Type page
            throw ($PodeLocale.noRoutePathSuppliedForPageExceptionMessage -f $Type)
        }
        # setup meta info
        $meta = @{
            Type     = $Type.ToLowerInvariant()
            Title    = $Title
            OpenApi  = $OpenApiUrl
            DarkMode = $DarkMode
        }
        $PodeContext.Server.OpenAPI.Definitions[$DefinitionTag].hiddenComponents.viewer[$($meta.Type)] = $Path
        # add the viewer route
        Add-PodeRoute -Method Get -Path $Path -Middleware $Middleware -ArgumentList $meta `
            -EndpointName $EndpointName -Authentication $Authentication `
            -Role $Role -Scope $Scope -Group $Group `
            -ScriptBlock {
            param($meta)
            $podeRoot = Get-PodeModuleMiscPath
            if ( $meta.DarkMode) { $Theme = 'dark' } else { $Theme = 'light' }
            Write-PodeFileResponseInternal -Path ([System.IO.Path]::Combine($podeRoot, "default-$($meta.Type).html.pode")) -Data @{
                Title    = $meta.Title
                OpenApi  = $meta.OpenApi
                DarkMode = $meta.DarkMode
                Theme    = $Theme
            }
        }
    }

}


<#
.SYNOPSIS
    Enables the OpenAPI default route in Pode.

.DESCRIPTION
    Enables the OpenAPI default route in Pode, as well as setting up details like Title and API Version.

.PARAMETER Path
    An optional custom route path to access the OpenAPI definition. (Default: /openapi)

.PARAMETER Title
    The Title of the API. (Deprecated -  Use Add-PodeOAInfo)

.PARAMETER Version
    The Version of the API.   (Deprecated -  Use Add-PodeOAInfo)
    The OpenAPI Specification is versioned using Semantic Versioning 2.0.0 (semver) and follows the semver specification.
    https://semver.org/spec/v2.0.0.html

.PARAMETER Description
    A short description of the API. (Deprecated -  Use Add-PodeOAInfo)
    CommonMark syntax MAY be used for rich text representation.
    https://spec.commonmark.org/

.PARAMETER OpenApiVersion
    Specify OpenApi Version (default: 3.0.3)

.PARAMETER RouteFilter
    An optional route filter for routes that should be included in the definition. (Default: /*)

.PARAMETER Middleware
    Like normal Routes, an array of Middleware that will be applied to the route.

.PARAMETER EndpointName
    The EndpointName of an Endpoint(s) to bind the static Route against.

.PARAMETER Authentication
    The name of an Authentication method which should be used as middleware on this Route.

.PARAMETER Role
    One or more optional Roles that will be authorised to access this Route, when using Authentication with an Access method.

.PARAMETER Group
    One or more optional Groups that will be authorised to access this Route, when using Authentication with an Access method.

.PARAMETER Scope
    One or more optional Scopes that will be authorised to access this Route, when using Authentication with an Access method.

.PARAMETER RestrictRoutes
    If supplied, only routes that are available on the Requests URI will be used to generate the OpenAPI definition.

.PARAMETER ServerEndpoint
    If supplied, will be used as URL base to generate the OpenAPI definition.
    The parameter is created by New-PodeOpenApiServerEndpoint

.PARAMETER Mode
    Define the way the OpenAPI definition file is accessed, the value can be View or Download. (Default: View)

.PARAMETER NoCompress
    If supplied, generate the OpenApi Json version in human readible form.

.PARAMETER MarkupLanguage
    Define the default markup language for the OpenApi spec ('Json', 'Json-Compress', 'Yaml')

.PARAMETER EnableSchemaValidation
    If supplied enable Test-PodeOAJsonSchemaCompliance  cmdlet that provide support for opeapi parameter schema validation

.PARAMETER Depth
    Define the default  depth used by any JSON,YAML OpenAPI conversion (default 20)

.PARAMETER DisableMinimalDefinitions
    If supplied the OpenApi decument will include only the route validated by Set-PodeOARouteInfo. Any other not OpenApi route will be excluded.

.PARAMETER NoDefaultResponses
    If supplied, it will disable the default OpenAPI response with the new provided.

.PARAMETER DefaultResponses
    If supplied, it will replace the default OpenAPI response with the new provided.(Default: @{'200' = @{ description = 'OK' };'default' = @{ description = 'Internal server error' }} )

.PARAMETER DefinitionTag
    A string representing the unique tag for the API specification.
    This tag helps distinguish between different versions or types of API specifications within the application.
    You can use this tag to reference the specific API documentation, schema, or version that your function interacts with.

.EXAMPLE
    Enable-PodeOpenApi -Title 'My API' -Version '1.0.0' -RouteFilter '/api/*'

.EXAMPLE
    Enable-PodeOpenApi -Title 'My API' -Version '1.0.0' -RouteFilter '/api/*' -RestrictRoutes

.EXAMPLE
    Enable-PodeOpenApi -Path '/docs/openapi'   -NoCompress -Mode 'Donwload' -DisableMinimalDefinitions
#>
function Enable-PodeOpenApi {
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [string]
        $Path = '/openapi',

        [Parameter(ParameterSetName = 'Deprecated')]
        [string]
        $Title,

        [Parameter(ParameterSetName = 'Deprecated')]
        [ValidatePattern('^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$')]
        [string]
        $Version,

        [Parameter(ParameterSetName = 'Deprecated')]
        [string]
        $Description,

        [ValidateSet('3.1.0', '3.0.3', '3.0.2', '3.0.1', '3.0.0')]
        [string]
        $OpenApiVersion = '3.0.3',

        [ValidateNotNullOrEmpty()]
        [string]
        $RouteFilter = '/*',

        [Parameter()]
        [string[]]
        $EndpointName,

        [Parameter()]
        [object[]]
        $Middleware,

        [Parameter()]
        [Alias('Auth')]
        [string]
        $Authentication,

        [Parameter()]
        [string[]]
        $Role,

        [Parameter()]
        [string[]]
        $Group,

        [Parameter()]
        [string[]]
        $Scope,

        [switch]
        $RestrictRoutes,

        [Parameter()]
        [ValidateSet('View', 'Download')]
        [String]
        $Mode = 'view',

        [Parameter()]
        [ValidateSet('Json', 'Json-Compress', 'Yaml')]
        [String]
        $MarkupLanguage = 'Json',

        [Parameter()]
        [switch]
        $EnableSchemaValidation,

        [Parameter()]
        [ValidateRange(1, 100)]
        [int]
        $Depth = 20,

        [Parameter()]
        [switch]
        $DisableMinimalDefinitions,

        [Parameter(Mandatory, ParameterSetName = 'DefaultResponses')]
        [hashtable]
        $DefaultResponses,

        [Parameter(Mandatory, ParameterSetName = 'NoDefaultResponses')]
        [switch]
        $NoDefaultResponses,

        [Parameter()]
        [string]
        $DefinitionTag

    )
    if (Test-PodeIsEmpty -Value $DefinitionTag) {
        $DefinitionTag = $PodeContext.Server.OpenAPI.SelectedDefinitionTag
    }
    if ($Description -or $Version -or $Title) {
        if (! $Version) {
            $Version = '0.0.0'
        }
        # WARNING: Title, Version, and Description on 'Enable-PodeOpenApi' are deprecated. Please use 'Add-PodeOAInfo' instead
        Write-PodeHost $PodeLocale.deprecatedTitleVersionDescriptionWarningMessage -ForegroundColor Yellow
    }
    if ( $DefinitionTag -ine $PodeContext.Server.Web.OpenApi.DefaultDefinitionTag) {
        $PodeContext.Server.OpenAPI.Definitions[$DefinitionTag] = Get-PodeOABaseObject
    }
    $PodeContext.Server.OpenAPI.Definitions[$DefinitionTag].hiddenComponents.enableMinimalDefinitions = !$DisableMinimalDefinitions.IsPresent


    # initialise openapi info
    $PodeContext.Server.OpenAPI.Definitions[$DefinitionTag].Version = $OpenApiVersion
    $PodeContext.Server.OpenAPI.Definitions[$DefinitionTag].Path = $Path
    if ($OpenApiVersion.StartsWith('3.0')) {
        $PodeContext.Server.OpenAPI.Definitions[$DefinitionTag].hiddenComponents.version = 3.0
    }
    elseif ($OpenApiVersion.StartsWith('3.1')) {
        $PodeContext.Server.OpenAPI.Definitions[$DefinitionTag].hiddenComponents.version = 3.1
    }

    $meta = @{
        RouteFilter    = $RouteFilter
        RestrictRoutes = $RestrictRoutes
        NoCompress     = ($MarkupLanguage -ine 'Json-Compress')
        Mode           = $Mode
        MarkupLanguage = $MarkupLanguage
        DefinitionTag  = $DefinitionTag
    }
    if ( $Title) {
        $PodeContext.Server.OpenAPI.Definitions[$DefinitionTag].info.title = $Title
    }
    if ($Version) {
        $PodeContext.Server.OpenAPI.Definitions[$DefinitionTag].info.version = $Version
    }

    if ($Description ) {
        $PodeContext.Server.OpenAPI.Definitions[$DefinitionTag].info.description = $Description
    }

    if ( $EnableSchemaValidation.IsPresent) {
        #Test-Json has been introduced with version 6.1.0
        if ($PSVersionTable.PSVersion -ge [version]'6.1.0') {
            $PodeContext.Server.OpenAPI.Definitions[$DefinitionTag].hiddenComponents.schemaValidation = $EnableSchemaValidation.IsPresent
        }
        else {
            # Schema validation required PowerShell version 6.1.0 or greater
            throw ($PodeLocale.schemaValidationRequiresPowerShell610ExceptionMessage)
        }
    }

    if ( $Depth) {
        $PodeContext.Server.OpenAPI.Definitions[$DefinitionTag].hiddenComponents.depth = $Depth
    }


    $openApiCreationScriptBlock = {
        param($meta)
        $format = $WebEvent.Query['format']
        $mode = $WebEvent.Query['mode']
        $DefinitionTag = $meta.DefinitionTag

        if (!$mode) {
            $mode = $meta.Mode
        }
        elseif (@('download', 'view') -inotcontains $mode) {
            Write-PodeHtmlResponse -Value "Mode $mode not valid" -StatusCode 400
            return
        }
        if ($WebEvent.path -ilike '*.json') {
            if ($format) {
                Show-PodeErrorPage -Code 400 -ContentType 'text/html' -Description 'Format query not valid when the file extension is used'
                return
            }
            $format = 'json'
        }
        elseif ($WebEvent.path -ilike '*.yaml') {
            if ($format) {
                Show-PodeErrorPage -Code 400 -ContentType 'text/html' -Description 'Format query not valid when the file extension is used'
                return
            }
            $format = 'yaml'
        }
        elseif (!$format) {
            $format = $meta.MarkupLanguage.ToLower()
        }
        elseif (@('yaml', 'json', 'json-Compress') -inotcontains $format) {
            Show-PodeErrorPage -Code 400 -ContentType 'text/html' -Description "Format $format not valid"
            return
        }

        if ($mode -ieq 'download') {
            # Set-PodeResponseAttachment -Path
            Add-PodeHeader -Name 'Content-Disposition' -Value "attachment; filename=openapi.$format"
        }

        # generate the openapi definition
        $def = Get-PodeOpenApiDefinitionInternal `
            -EndpointName $WebEvent.Endpoint.Name `
            -DefinitionTag $DefinitionTag `
            -MetaInfo $meta

        # write the openapi definition
        if ($format -ieq 'yaml') {
            if ($mode -ieq 'view') {
                Write-PodeTextResponse -Value (ConvertTo-PodeYaml -InputObject $def -depth $PodeContext.Server.OpenAPI.Definitions[$DefinitionTag].hiddenComponents.depth) -ContentType 'application/yaml; charset=utf-8' #Changed to be RFC 9512 compliant
            }
            else {
                Write-PodeYamlResponse -Value $def -Depth $PodeContext.Server.OpenAPI.Definitions[$DefinitionTag].hiddenComponents.depth
            }
        }
        else {
            Write-PodeJsonResponse -Value $def -Depth $PodeContext.Server.OpenAPI.Definitions[$DefinitionTag].hiddenComponents.depth -NoCompress:$meta.NoCompress
        }
    }

    # add the OpenAPI route
    Add-PodeRoute -Method Get -Path $Path -ArgumentList $meta -Middleware $Middleware `
        -ScriptBlock $openApiCreationScriptBlock -EndpointName $EndpointName `
        -Authentication $Authentication -Role $Role -Scope $Scope -Group $Group

    Add-PodeRoute -Method Get -Path "$Path.json" -ArgumentList $meta -Middleware $Middleware `
        -ScriptBlock $openApiCreationScriptBlock -EndpointName $EndpointName `
        -Authentication $Authentication -Role $Role -Scope $Scope -Group $Group

    Add-PodeRoute -Method Get -Path "$Path.yaml" -ArgumentList $meta -Middleware $Middleware `
        -ScriptBlock $openApiCreationScriptBlock -EndpointName $EndpointName `
        -Authentication $Authentication -Role $Role -Scope $Scope -Group $Group

    #set new DefaultResponses
    if ($NoDefaultResponses.IsPresent) {
        $PodeContext.Server.OpenAPI.Definitions[$DefinitionTag].hiddenComponents.defaultResponses = [ordered]@{}
    }
    elseif ($DefaultResponses) {
        $PodeContext.Server.OpenAPI.Definitions[$DefinitionTag].hiddenComponents.defaultResponses = $DefaultResponses
    }
    $PodeContext.Server.OpenAPI.Definitions[$DefinitionTag].hiddenComponents.enabled = $true

    if ($EndpointName) {
        $PodeContext.Server.OpenAPI.Definitions[$DefinitionTag].hiddenComponents.EndpointName = $EndpointName
    }
}


<#
.SYNOPSIS
    Gets the OpenAPI definition.

.DESCRIPTION
    Gets the OpenAPI definition for custom use in routes, or other functions.

.PARAMETER Format
    Return the definition  in a specific format 'Json', 'Json-Compress', 'Yaml', 'HashTable'

.PARAMETER Title
    The Title of the API. (Default: the title supplied in Enable-PodeOpenApi)

.PARAMETER Version
    The Version of the API. (Default: the version supplied in Enable-PodeOpenApi)

.PARAMETER Description
    A Description of the API. (Default: the description supplied into Enable-PodeOpenApi)

.PARAMETER RouteFilter
    An optional route filter for routes that should be included in the definition. (Default: /*)

.PARAMETER RestrictRoutes
    If supplied, only routes that are available on the Requests URI will be used to generate the OpenAPI definition.

.PARAMETER DefinitionTag
    A string representing the unique tag for the API specification.
    This tag helps distinguish between different versions or types of API specifications within the application.
    You can use this tag to reference the specific API documentation, schema, or version that your function interacts with.

.EXAMPLE
    $defInJson = Get-PodeOADefinition -Json
#>
function Get-PodeOADefinition {
    [CmdletBinding()]
    param(
        [ValidateSet('Json', 'Json-Compress', 'Yaml', 'HashTable')]
        [string]
        $Format = 'HashTable',

        [string]
        $Title,

        [string]
        $Version,

        [string]
        $Description,

        [ValidateNotNullOrEmpty()]
        [string]
        $RouteFilter = '/*',

        [switch]
        $RestrictRoutes,

        [string]
        $DefinitionTag
    )

    $DefinitionTag = Test-PodeOADefinitionTag -Tag $DefinitionTag

    $meta = @{
        RouteFilter    = $RouteFilter
        RestrictRoutes = $RestrictRoutes
    }
    if ($RestrictRoutes) {
        $meta = @{
            RouteFilter    = $RouteFilter
            RestrictRoutes = $RestrictRoutes
        }
    }
    else {
        $meta = @{}
    }
    if ($Title) {
        $meta.Title = $Title
    }
    if ($Version) {
        $meta.Version = $Version
    }
    if ($Description) {
        $meta.Description = $Description
    }

    $oApi = Get-PodeOpenApiDefinitionInternal -MetaInfo $meta -EndpointName $WebEvent.Endpoint.Name -DefinitionTag $DefinitionTag

    switch ($Format.ToLower()) {
        'json' {
            return ConvertTo-Json -InputObject $oApi -Depth $PodeContext.Server.OpenAPI.Definitions[$DefinitionTag].hiddenComponents.depth
        }
        'json-compress' {
            return ConvertTo-Json -InputObject $oApi -Depth $PodeContext.Server.OpenAPI.Definitions[$DefinitionTag].hiddenComponents.depth -Compress
        }
        'yaml' {
            return ConvertTo-PodeYaml -InputObject $oApi -depth $PodeContext.Server.OpenAPI.Definitions[$DefinitionTag].hiddenComponents.depth
        }
        Default {
            return $oApi
        }
    }
}


<#
.SYNOPSIS
    Creates media content type definitions for OpenAPI specifications.

.DESCRIPTION
    The New-PodeOAContentMediaType function generates media content type definitions suitable for use in OpenAPI specifications. It supports various media types and allows for the specification of content as either a single object or an array of objects.

.PARAMETER ContentType
    An array of strings specifying the media types to be defined. Media types should conform to standard MIME types (e.g., 'application/json', 'image/png'). The function validates these media types against a regular expression to ensure they are properly formatted.

    Alias: MediaType

.PARAMETER Content
    The content definition for the media type. This could be an object representing the structure of the content expected for the specified media types.

.PARAMETER Array
    A switch parameter, used in the 'Array' parameter set, to indicate that the content should be treated as an array.

.PARAMETER UniqueItems
    A switch parameter, used in the 'Array' parameter set, to specify that items in the array should be unique.

.PARAMETER MinItems
    Used in the 'Array' parameter set to specify the minimum number of items that should be present in the array.

.PARAMETER MaxItems
    Used in the 'Array' parameter set to specify the maximum number of items that should be present in the array.

.PARAMETER Title
    Used in the 'Array' parameter set to provide a title for the array content.

.PARAMETER Upload
    If provided configure the media for an upload changing the result based on the OpenApi version

.PARAMETER ContentEncoding
    Define the content encoding for upload (Default Binary)

.PARAMETER PartContentMediaType
    Define the content encoding for multipart upload

.EXAMPLE
    Add-PodeRoute -PassThru -Method get -Path '/pet/findByStatus' -Authentication 'Login-OAuth2' -Scope 'read' -ScriptBlock {
    Write-PodeJsonResponse -Value 'done' -StatusCode 200
    } | Set-PodeOARouteInfo -Summary 'Finds Pets by status' -Description 'Multiple status values can be provided with comma separated strings' -Tags 'pet' -OperationId 'findPetsByStatus' -PassThru |
    Set-PodeOARequest -PassThru -Parameters @(
    (New-PodeOAStringProperty -Name 'status' -Description 'Status values that need to be considered for filter' -Default 'available' -Enum @('available', 'pending', 'sold') | ConvertTo-PodeOAParameter -In Query)
    ) |
    Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -Content (New-PodeOAContentMediaType -ContentType 'application/json','application/xml' -Content 'Pet' -Array -UniqueItems) -PassThru |
    Add-PodeOAResponse -StatusCode 400 -Description 'Invalid status value'
    This example demonstrates the use of New-PodeOAContentMediaType in defining a GET route '/pet/findByStatus' in an OpenAPI specification. The route includes request parameters and responses with media content types for 'application/json' and 'application/xml'.

.EXAMPLE
    $content = [ordered]@{ type = 'string' }
    $mediaType = 'application/json'
    New-PodeOAContentMediaType -ContentType $mediaType -Content $content
    This example creates a media content type definition for 'application/json' with a simple string content type.

.EXAMPLE
    $content = [ordered]@{ type = 'object'; properties = [ordered]@{ name = @{ type = 'string' } } }
    $mediaTypes = 'application/json', 'application/xml'
    New-PodeOAContentMediaType -ContentType $mediaTypes -Content $content -Array -MinItems 1 -MaxItems 5 -Title 'UserList'
    This example demonstrates defining an array of objects for both 'application/json' and 'application/xml' media types, with a specified range for the number of items and a title.

.EXAMPLE
    Add-PodeRoute -PassThru -Method get -Path '/pet/findByStatus' -Authentication 'Login-OAuth2' -Scope 'read' -ScriptBlock {
    Write-PodeJsonResponse -Value 'done' -StatusCode 200
    } | Set-PodeOARouteInfo -Summary 'Finds Pets by status' -Description 'Multiple status values can be provided with comma separated strings' -Tags 'pet' -OperationId 'findPetsByStatus' -PassThru |
    Set-PodeOARequest -PassThru -Parameters @(
    (New-PodeOAStringProperty -Name 'status' -Description 'Status values that need to be considered for filter' -Default 'available' -Enum @('available', 'pending', 'sold') | ConvertTo-PodeOAParameter -In Query)
    ) |
    Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -Content (New-PodeOAContentMediaType -ContentType 'application/json','application/xml' -Content 'Pet' -Array -UniqueItems) -PassThru |
    Add-PodeOAResponse -StatusCode 400 -Description 'Invalid status value'
    This example demonstrates the use of New-PodeOAContentMediaType in defining a GET route '/pet/findByStatus' in an OpenAPI specification. The route includes request parameters and responses with media content types for 'application/json' and 'application/xml'.

.NOTES
    This function is useful for dynamically creating media type specifications in OpenAPI documentation, providing flexibility in defining the expected content structure for different media types.
#>
function New-PodeOAContentMediaType {
    [CmdletBinding(DefaultParameterSetName = 'inbuilt')]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param (
        [Parameter()]
        [Alias('MediaType')]
        [string[]]
        $ContentType = '*/*',

        [object]
        $Content,

        [Parameter(  Mandatory = $true, ParameterSetName = 'Array')]
        [switch]
        $Array,

        [Parameter(ParameterSetName = 'Array')]
        [switch]
        $UniqueItems,

        [Parameter(ParameterSetName = 'Array')]
        [int]
        $MinItems,

        [Parameter(ParameterSetName = 'Array')]
        [int]
        $MaxItems,

        [Parameter(ParameterSetName = 'Array')]
        [string]
        $Title,

        [Parameter(Mandatory = $true, ParameterSetName = 'Upload')]
        [switch]
        $Upload,

        [Parameter(  ParameterSetName = 'Upload')]
        [ValidateSet('Binary', 'Base64')]
        [string]
        $ContentEncoding = 'Binary',

        [Parameter(  ParameterSetName = 'Upload')]
        [string]
        $PartContentMediaType

    )

    $DefinitionTag = Test-PodeOADefinitionTag -Tag $DefinitionTag
    $props = [ordered]@{}
    foreach ($media in $ContentType) {
        if ($media -inotmatch '^(application|audio|image|message|model|multipart|text|video|\*)\/[\w\.\-\*]+(;[\s]*(charset|boundary)=[\w\.\-\*]+)*$') {
            # Invalid 'content-type' found for schema: $media
            throw ($PodeLocale.invalidContentTypeForSchemaExceptionMessage -f $media)
        }
        if ($Upload.IsPresent) {
            if ( $media -ieq 'multipart/form-data' -and $Content) {
                $Content = [ordered]@{'__upload' = [ordered]@{
                        'content'              = $Content
                        'partContentMediaType' = $PartContentMediaType
                    }
                }
            }
            else {
                $Content = [ordered]@{'__upload' = [ordered]@{
                        'contentEncoding' = $ContentEncoding
                    }
                }

            }
        }
        else {
            if ($null -eq $Content ) {
                $Content = [ordered]@{}
            }
        }
        if ($Array.IsPresent) {
            $props[$media] = @{
                __array   = $true
                __content = $Content
                __upload  = $Upload
            }
            if ($MinItems) {
                $props[$media].__minItems = $MinItems
            }
            if ($MaxItems) {
                $props[$media].__maxItems = $MaxItems
            }
            if ($Title) {
                $props[$media].__title = $Title
            }
            if ($UniqueItems.IsPresent) {
                $props[$media].__uniqueItems = $UniqueItems.IsPresent
            }

        }
        else {
            $props[$media] = $Content
        }
    }
    return $props
}


<#
.SYNOPSIS
    Adds a single encoding definition applied to a single schema property.

.DESCRIPTION
    A single encoding definition applied to a single schema property.

.PARAMETER EncodingList
    Used by pipe

.PARAMETER Title
    The Name of the associated encoded property .

.PARAMETER ContentType
    Content-Type for encoding a specific property. Default value depends on the property type: for `string` with `format` being `binary` – `application/octet-stream`;
    for other primitive types – `text/plain`; for `object` - `application/json`; for `array` – the default is defined based on the inner type.
    The value can be a specific media type (e.g. `application/json`), a wildcard media type (e.g. `image/*`), or a comma-separated list of the two types.

.PARAMETER Headers
    A map allowing additional information to be provided as headers, for example `Content-Disposition`.
    `Content-Type` is described separately and SHALL be ignored in this section.
    This property SHALL be ignored if the request body media type is not a `multipart`.

.PARAMETER Style
    Describes how a specific property value will be serialized depending on its type.  See [Parameter Object](#parameterObject) for details on the [`style`](#parameterStyle) property.
    The behavior follows the same values as `query` parameters, including default values.
    This property SHALL be ignored if the request body media type is not `application/x-www-form-urlencoded`.

.PARAMETER Explode
    When enabled, property values of type `array` or `object` generate separate parameters for each value of the array, or key-value-pair of the map.  For other types of properties this property has no effect.
    When [`style`](#encodingStyle) is `form`, the `Explode` is set to `true`.
    This property SHALL be ignored if the request body media type is not `application/x-www-form-urlencoded`.

.PARAMETER AllowReserved
    Determines whether the parameter value SHOULD allow reserved characters, as defined by [RFC3986](https://tools.ietf.org/html/rfc3986#section-2.2) `:/?#[]@!$&'()*+,;=` to be included without percent-encoding.
    This property SHALL be ignored if the request body media type is not `application/x-www-form-urlencoded`.

.EXAMPLE

    New-PodeOAEncodingObject -Name 'profileImage' -ContentType 'image/png, image/jpeg' -Headers (
    New-PodeOAIntProperty -name 'X-Rate-Limit-Limit' -Description 'The number of allowed requests in the current period' -Default 3 -Enum @(1,2,3) -Maximum 3
    )
#>
function New-PodeOAEncodingObject {
    param (
        [Parameter(ValueFromPipeline = $true, Position = 0, DontShow = $true )]
        [hashtable[]]
        $EncodingList,

        [Parameter(Mandatory = $true)]
        [Alias('Name')]
        [ValidatePattern('^[a-zA-Z0-9\.\-_]+$')]
        [string]
        $Title,

        [string]
        $ContentType,

        [hashtable[]]
        $Headers,

        [ValidateSet('Simple', 'Label', 'Matrix', 'Query', 'Form', 'SpaceDelimited', 'PipeDelimited', 'DeepObject' )]
        [string]
        $Style,

        [switch]
        $Explode,

        [switch]
        $AllowReserved
    )
    begin {

        $encoding = [ordered]@{
            $Title = [ordered]@{}
        }
        if ($ContentType) {
            $encoding.$Title.contentType = $ContentType
        }
        if ($Style) {
            $encoding.$Title.style = $Style
        }

        if ($Headers) {
            $encoding.$Title.headers = $Headers
        }

        if ($Explode.IsPresent ) {
            $encoding.$Title.explode = $Explode.IsPresent
        }
        if ($AllowReserved.IsPresent ) {
            $encoding.$Title.allowReserved = $AllowReserved.IsPresent
        }

        $collectedInput = [System.Collections.Generic.List[hashtable]]::new()
    }
    process {
        if ($EncodingList) {
            $collectedInput.AddRange($EncodingList)
        }
    }

    end {
        if ($collectedInput) {
            return $collectedInput + $encoding
        }
        else {
            return $encoding
        }
    }
}


<#
.SYNOPSIS
    Creates a new OpenAPI example.

.DESCRIPTION
    Creates a new OpenAPI example.

    .PARAMETER ParamsList
    Used to pipeline multiple properties

.PARAMETER ContentType
    The Media Content Type associated with the Example.

    Alias: MediaType

.PARAMETER Name
    The Name of the Example.

.PARAMETER Summary
    Short description for the example

    .PARAMETER Description
    Long description for the example.

.PARAMETER Reference
    A reference to a reusable component example

.PARAMETER Value
    Embedded literal example. The  value Parameter and ExternalValue parameter are mutually exclusive.
    To represent examples of media types that cannot naturally represented in JSON or YAML, use a string value to contain the example, escaping where necessary.

.PARAMETER ExternalValue
    A URL that points to the literal example. This provides the capability to reference examples that cannot easily be included in JSON or YAML documents.
    The -Value parameter and -ExternalValue parameter are mutually exclusive.                                |

.PARAMETER DefinitionTag
    An Array of strings representing the unique tag for the API specification.
    This tag helps distinguish between different versions or types of API specifications within the application.
    You can use this tag to reference the specific API documentation, schema, or version that your function interacts with.

.EXAMPLE
    New-PodeOAExample -ContentType 'text/plain' -Name 'user' -Summary = 'User Example in Plain text' -ExternalValue = 'http://foo.bar/examples/user-example.txt'
.EXAMPLE
    $example =
    New-PodeOAExample -ContentType 'application/json' -Name 'user' -Summary = 'User Example' -ExternalValue = 'http://foo.bar/examples/user-example.json'  |
    New-PodeOAExample -ContentType 'application/xml' -Name 'user' -Summary = 'User Example in XML' -ExternalValue = 'http://foo.bar/examples/user-example.xml'
#>
function New-PodeOAExample {
    [CmdletBinding(DefaultParameterSetName = 'Inbuilt')]
    [OutputType([System.Collections.Specialized.OrderedDictionary ])]

    param(
        [Parameter(ValueFromPipeline = $true, Position = 0, DontShow = $true, ParameterSetName = 'Inbuilt')]
        [Parameter(ValueFromPipeline = $true, Position = 0, DontShow = $true, ParameterSetName = 'Reference')]
        [System.Collections.Specialized.OrderedDictionary ]
        $ParamsList,

        [Parameter()]
        [Alias('MediaType')]
        [string]
        $ContentType,

        [Parameter(Mandatory = $true, ParameterSetName = 'Inbuilt')]
        [ValidatePattern('^[a-zA-Z0-9\.\-_]+$')]
        [string]
        $Name,

        [Parameter( ParameterSetName = 'Inbuilt')]
        [string]
        $Summary,

        [Parameter( ParameterSetName = 'Inbuilt')]
        [string]
        $Description,

        [Parameter(  ParameterSetName = 'Inbuilt')]
        [object]
        $Value,

        [Parameter(  ParameterSetName = 'Inbuilt')]
        [string]
        $ExternalValue,

        [Parameter(Mandatory = $true, ParameterSetName = 'Reference')]
        [ValidatePattern('^[a-zA-Z0-9\.\-_]+$')]
        [string]
        $Reference,

        [string[]]
        $DefinitionTag
    )
    begin {
        $pipelineValue = [ordered]@{}

        if (Test-PodeIsEmpty -Value $DefinitionTag) {
            $DefinitionTag = $PodeContext.Server.OpenAPI.SelectedDefinitionTag
        }
        if ($PSCmdlet.ParameterSetName -ieq 'Reference') {
            Test-PodeOAComponentInternal -Field examples -DefinitionTag $DefinitionTag -Name $Reference -PostValidation
            $Name = $Reference
            $Example = [ordered]@{'$ref' = "#/components/examples/$Reference" }
        }
        else {
            if ( $ExternalValue -and $Value) {
                # Parameters 'ExternalValue' and 'Value' are mutually exclusive
                throw ($PodeLocale.parametersMutuallyExclusiveExceptionMessage -f 'ExternalValue', 'Value')
            }
            $Example = [ordered]@{ }
            if ($Summary) {
                $Example.summary = $Summary
            }
            if ($Description) {
                $Example.description = $Description
            }
            if ($Value) {
                $Example.value = $Value
            }
            elseif ($ExternalValue) {
                $Example.externalValue = $ExternalValue
            }
            else {
                # Parameters 'Value' or 'ExternalValue' are mandatory
                throw ($PodeLocale.parametersValueOrExternalValueMandatoryExceptionMessage)
            }
        }
        $param = [ordered]@{}
        if ($ContentType) {
            $param.$ContentType = [ordered]@{
                $Name = $Example
            }
        }
        else {
            $param.$Name = $Example
        }

    }
    process {
        if ($_) {
            $pipelineValue += $_
        }
    }
    end {
        $examples = [ordered]@{}
        if ($pipelineValue.Count -gt 0) {
            #  foreach ($p in $pipelineValue) {
            $examples = $pipelineValue
            #  }
        }
        else {
            return $param
        }

        $key = [string]$param.Keys[0]
        if ($examples.Keys -contains $key) {
            $examples[$key] += $param[$key]
        }
        else {
            $examples += $param
        }
        return $examples
    }
}


<#
.SYNOPSIS
    Define an external docs reference.

.DESCRIPTION
    Define an external docs reference.

.PARAMETER url
    The link to the external documentation

.PARAMETER Description
    A Description of the external documentation.

.EXAMPLE
    $swaggerDoc = New-PodeOAExternalDoc  -Description 'Find out more about Swagger' -Url 'http://swagger.io'

    Add-PodeRoute -PassThru | Set-PodeOARouteInfo -Summary 'A quick summary' -Tags 'Admin' -ExternalDoc $swaggerDoc

.EXAMPLE
    $swaggerDoc = New-PodeOAExternalDoc    -Description 'Find out more about Swagger' -Url 'http://swagger.io'
    Add-PodeOATag -Name 'user' -Description 'Operations about user' -ExternalDoc $swaggerDoc
#>
function New-PodeOAExternalDoc {
    param(

        [Parameter(Mandatory = $true)]
        [ValidateScript({ $_ -imatch '^https?://.+' })]
        $Url,

        [string]
        $Description
    )
    $param = [ordered]@{}

    if ($Description) {
        $param.description = $Description
    }
    $param['url'] = $Url
    return $param
}


<#
.SYNOPSIS
    Creates a Request Body definition for routes.

.DESCRIPTION
    Creates a Request Body definition for routes from the supplied content-types and schemas.

.PARAMETER Reference
    A reference name from an existing component request body.
    Alias: Reference

.PARAMETER Content
    The content of the request body. The key is a media type or media type range and the value describes it.
    For requests that match multiple keys, only the most specific key is applicable. e.g. text/plain overrides text/*
    Alias: ContentSchemas

.PARAMETER Description
    A brief description of the request body. This could contain examples of use. CommonMark syntax MAY be used for rich text representation.

.PARAMETER Required
    Determines if the request body is required in the request. Defaults to false.

.PARAMETER Properties
    Use to force the use of the properties keyword under a schema. Commonly used to specify a multipart/form-data multi file

.PARAMETER Examples
    Supplied an Example of the media type.  The example object SHOULD be in the correct format as specified by the media type.
    The `example` field is mutually exclusive of the `examples` field.
    Furthermore, if referencing a `schema` which contains an example, the `example` value SHALL _override_ the example provided by the schema.

.PARAMETER Encoding
    This parameter give you control over the serialization of parts of multipart request bodies.
    This attribute is only applicable to multipart and application/x-www-form-urlencoded request bodies.
    Use New-PodeOAEncodingObject to define the encode

.PARAMETER DefinitionTag
    An Array of strings representing the unique tag for the API specification.
    This tag helps distinguish between different versions or types of API specifications within the application.
    You can use this tag to reference the specific API documentation, schema, or version that your function interacts with.

.EXAMPLE
    New-PodeOARequestBody -Content @{ 'application/json' = (New-PodeOAIntProperty -Name 'userId' -Object) }

.EXAMPLE
    New-PodeOARequestBody -Content @{ 'application/json' = 'UserIdSchema' }

.EXAMPLE
    New-PodeOARequestBody -Reference 'UserIdBody'

.EXAMPLE
    New-PodeOARequestBody -Content @{'multipart/form-data' =
    New-PodeOAStringProperty -name 'id' -format 'uuid' |
    New-PodeOAObjectProperty -name 'address' -NoProperties |
    New-PodeOAObjectProperty -name 'historyMetadata' -Description 'metadata in XML format' -NoProperties |
    New-PodeOAStringProperty -name 'profileImage' -Format Binary |
    New-PodeOAObjectProperty
    } -Encoding (
    New-PodeOAEncodingObject -Name 'historyMetadata' -ContentType 'application/xml; charset=utf-8' |
    New-PodeOAEncodingObject -Name 'profileImage' -ContentType 'image/png, image/jpeg' -Headers (
    New-PodeOAIntProperty -name 'X-Rate-Limit-Limit' -Description 'The number of allowed requests in the current period' -Default 3 -Enum @(1,2,3)
    )
    )
#>
function New-PodeOARequestBody {
    [CmdletBinding(DefaultParameterSetName = 'BuiltIn' )]
    [OutputType([hashtable])]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'Reference')]
        [string]
        $Reference,

        [Parameter(Mandatory = $true, ParameterSetName = 'BuiltIn')]
        [Alias('ContentSchemas')]
        [hashtable]
        $Content,

        [Parameter(ParameterSetName = 'BuiltIn')]
        [string]
        $Description,

        [Parameter(ParameterSetName = 'BuiltIn')]
        [switch]
        $Required,

        [Parameter(ParameterSetName = 'BuiltIn')]
        [switch]
        $Properties,

        [System.Collections.Specialized.OrderedDictionary]
        $Examples,

        [hashtable[]]
        $Encoding,

        [string[]]
        $DefinitionTag

    )

    $DefinitionTag = Test-PodeOADefinitionTag -Tag $DefinitionTag

    $result = [ordered]@{}
    foreach ($tag in $DefinitionTag) {
        switch ($PSCmdlet.ParameterSetName.ToLowerInvariant()) {
            'builtin' {
                $param = [ordered]@{content = ConvertTo-PodeOAObjectSchema -DefinitionTag $tag -Content $Content -Properties:$Properties }

                if ($Required.IsPresent) {
                    $param['required'] = $Required.IsPresent
                }

                if ( $Description) {
                    $param['description'] = $Description
                }
                if ($Examples) {
                    if ( $Examples.'*/*') {
                        $Examples['"*/*"'] = $Examples['*/*']
                        $Examples.Remove('*/*')
                    }
                    foreach ($k in  $Examples.Keys ) {
                        if (!($param.content.Keys -contains $k)) {
                            $param.content[$k] = [ordered]@{}
                        }
                        $param.content[$k].examples = $Examples.$k
                    }
                }
            }

            'reference' {
                Test-PodeOAComponentInternal -Field requestBodies -DefinitionTag $tag -Name $Reference -PostValidation
                $param = [ordered]@{
                    '$ref' = "#/components/requestBodies/$Reference"
                }
            }
        }
        if ($Encoding) {
            if (([string]$Content.keys[0]) -match '(?i)^(multipart.*|application\/x-www-form-urlencoded)$' ) {
                $r = [ordered]@{}
                foreach ( $e in $Encoding) {
                    $key = [string]$e.Keys
                    $elems = [ordered]@{}
                    foreach ($v in $e[$key].Keys) {
                        if ($v -ieq 'headers') {
                            $elems.headers = ConvertTo-PodeOAHeaderProperty -Headers $e[$key].headers
                        }
                        else {
                            $elems.$v = $e[$key].$v
                        }
                    }
                    $r.$key = $elems
                }
                $param.Content.$($Content.keys[0]).encoding = $r
            }
            else {
                # The encoding attribute only applies to multipart and application/x-www-form-urlencoded request bodies
                throw ($PodeLocale.encodingAttributeOnlyAppliesToMultipartExceptionMessage)
            }
        }
        $result[$tag] = $param
    }

    return $result
}


<#
.SYNOPSIS
    Adds a response definition to the Callback.

.DESCRIPTION
    Adds a response definition to the Callback.

.PARAMETER ResponseList
    Hidden parameter used to pipe multiple CallBacksResponses

.PARAMETER StatusCode
    The HTTP StatusCode for the response.To define a range of response codes, this field MAY contain the uppercase wildcard character `X`.
    For example, `2XX` represents all response codes between `[200-299]`. Only the following range definitions are allowed: `1XX`, `2XX`, `3XX`, `4XX`, and `5XX`.
    If a response is defined using an explicit code, the explicit code definition takes precedence over the range definition for that code.

.PARAMETER Content
    The content-types and schema the response returns (the schema is created using the Property functions).
    Alias: ContentSchemas

.PARAMETER Headers
    The header name and schema the response returns (the schema is created using Add-PodeOAComponentHeader cmd-let).
    Alias: HeaderSchemas

.PARAMETER Description
    A Description of the response. (Default: the HTTP StatusCode description)

.PARAMETER Reference
    A Reference Name of an existing component response to use.

.PARAMETER Links
    A Response link definition

.PARAMETER Default
    If supplied, the response will be used as a default response - this overrides the StatusCode supplied.

.PARAMETER DefinitionTag
    An Array of strings representing the unique tag for the API specification.
    This tag helps distinguish between different versions or types of API specifications within the application.
    You can use this tag to reference the specific API documentation, schema, or version that your function interacts with.

.EXAMPLE
    New-PodeOAResponse -StatusCode 200 -Content (  New-PodeOAContentMediaType -ContentType 'application/json' -Content(New-PodeOAIntProperty -Name 'userId' -Object) )

.EXAMPLE
    New-PodeOAResponse -StatusCode 200 -Content @{ 'application/json' = 'UserIdSchema' }

.EXAMPLE
    New-PodeOAResponse -StatusCode 200 -Reference 'OKResponse'

.EXAMPLE
    Add-PodeOACallBack -Title 'test' -Path '$request.body#/id' -Method Post  -RequestBody (
    New-PodeOARequestBody -Content (New-PodeOAContentMediaType -ContentType '*/*' -Content (New-PodeOAStringProperty -Name 'id'))
    ) `
    -Response (
    New-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -Content (New-PodeOAContentMediaType -ContentType 'application/json','application/xml' -Content 'Pet'  -Array) |
    New-PodeOAResponse -StatusCode 400 -Description 'Invalid ID supplied' |
    New-PodeOAResponse -StatusCode 404 -Description 'Pet not found' |
    New-PodeOAResponse -Default   -Description 'Something is wrong'
    )
#>
function New-PodeOAResponse {
    [CmdletBinding(DefaultParameterSetName = 'Schema')]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    [OutputType([hashtable])]
    param(
        [Parameter(ValueFromPipeline = $true , Position = 0, DontShow = $true )]
        [hashtable]
        $ResponseList,

        [Parameter(Mandatory = $true, ParameterSetName = 'Schema')]
        [Parameter(Mandatory = $true, ParameterSetName = 'Reference')]
        [ValidatePattern('^([1-5][0-9][0-9]|[1-5]XX)$')]
        [string]
        $StatusCode,

        [Parameter(ParameterSetName = 'Schema')]
        [Parameter(ParameterSetName = 'SchemaDefault')]
        [Alias('ContentSchemas')]
        [hashtable]
        $Content,

        [Alias('HeaderSchemas')]
        [AllowEmptyString()]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ $_ -is [string] -or $_ -is [string[]] -or $_ -is [hashtable] })]
        $Headers,

        [Parameter(Mandatory = $true, ParameterSetName = 'Schema')]
        [Parameter(Mandatory = $true, ParameterSetName = 'SchemaDefault')]
        [string]
        $Description  ,

        [Parameter(Mandatory = $true, ParameterSetName = 'Reference')]
        [Parameter(ParameterSetName = 'ReferenceDefault')]
        [string]
        $Reference,

        [Parameter(Mandatory = $true, ParameterSetName = 'ReferenceDefault')]
        [Parameter(Mandatory = $true, ParameterSetName = 'SchemaDefault')]
        [switch]
        $Default,

        [Parameter(ParameterSetName = 'Schema')]
        [Parameter(ParameterSetName = 'SchemaDefault')]
        [System.Collections.Specialized.OrderedDictionary ]
        $Links,

        [string[]]
        $DefinitionTag
    )
    begin {

        if (Test-PodeIsEmpty -Value $DefinitionTag) {
            $DefinitionTag = $PodeContext.Server.OpenAPI.SelectedDefinitionTag
        }

        # override status code with default
        if ($Default) {
            $code = 'default'
        }
        else {
            $code = "$($StatusCode)"
        }
        $response = [ordered]@{}
    }
    process {
        foreach ($tag in $DefinitionTag) {
            if (! $response.$tag) {
                $response.$tag = [ordered] @{}
            }
            $response[$tag][$code] = New-PodeOResponseInternal -DefinitionTag $tag -Params $PSBoundParameters
        }
    }
    end {
        if ($ResponseList) {
            foreach ($tag in $DefinitionTag) {
                if (! ($ResponseList.Keys -Contains $tag )) {
                    $ResponseList[$tag] = [ordered] @{}
                }
                $response[$tag].GetEnumerator() | ForEach-Object { $ResponseList[$tag][$_.Key] = $_.Value }
            }
            return $ResponseList
        }
        else {
            return  $response
        }
    }
}


<#
.SYNOPSIS
    Adds a response link to an existing list of OpenAPI response links.

.DESCRIPTION
    The New-PodeOAResponseLink function is designed to add a new response link to an existing OrderedDictionary of OpenAPI response links.
    It can be used to define complex response structures with links to other operations or references, and it supports adding multiple links through pipeline input.

.PARAMETER LinkList
    An OrderedDictionary of existing response links.
    This parameter is intended for use with pipeline input, allowing the function to add multiple links to the collection.
    It is hidden from standard help displays to emphasize its use primarily in pipeline scenarios.

.PARAMETER Name
    Mandatory. A unique name for the response link.
    Must be a valid string composed of alphanumeric characters, periods (.), hyphens (-), and underscores (_).

.PARAMETER Description
    A brief description of the response link. CommonMark syntax may be used for rich text representation.
    For more information on CommonMark syntax, see [CommonMark Specification](https://spec.commonmark.org/).

.PARAMETER OperationId
    The name of an existing, resolvable OpenAPI Specification (OAS) operation, as defined with a unique `operationId`.
    This parameter is mandatory when using the 'OperationId' parameter set and is mutually exclusive of the `OperationRef` field. It is used to specify the unique identifier of the operation the link is associated with.

.PARAMETER OperationRef
    A relative or absolute URI reference to an OAS operation.
    This parameter is mandatory when using the 'OperationRef' parameter set and is mutually exclusive of the `OperationId` field.
    It MUST point to an Operation Object. Relative `operationRef` values MAY be used to locate an existing Operation Object in the OpenAPI specification.

.PARAMETER Reference
    A Reference Name of an existing component link to use.

.PARAMETER Parameters
    A map representing parameters to pass to an operation as specified with `operationId` or identified via `operationRef`.
    The key is the parameter name to be used, whereas the value can be a constant or an expression to be evaluated and passed to the linked operation.
    Parameter names can be qualified using the parameter location syntax `[{in}.]{name}` for operations that use the same parameter name in different locations (e.g., path.id).

.PARAMETER RequestBody
    A string representing the request body to use as a request body when calling the target.

.PARAMETER DefinitionTag
    An Array of strings representing the unique tag for the API specification.
    This tag helps distinguish between different versions or types of API specifications within the application.
    You can use this tag to reference the specific API documentation, schema, or version that your function interacts with.

.EXAMPLE
    $links = New-PodeOAResponseLink -LinkList $links -Name 'address' -OperationId 'getUserByName' -Parameters @{'username' = '$request.path.username'}
    Add-PodeOAResponse -StatusCode 200 -Content @{'application/json' = 'User'} -Links $links
    This example demonstrates creating and adding a link named 'address' associated with the operation 'getUserByName' to an OrderedDictionary of links. The updated dictionary is then used in the 'Add-PodeOAResponse' function to define a response with a status code of 200.

.NOTES
    The function supports adding links either by specifying an 'OperationId' or an 'OperationRef', making it versatile for different OpenAPI specification needs.
    It's important to match the parameters and response structures as per the OpenAPI specification to ensure the correct functionality of the API documentation.
#>
function New-PodeOAResponseLink {
    [CmdletBinding(DefaultParameterSetName = 'OperationId')]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param(
        [Parameter(ValueFromPipeline = $true , Position = 0, DontShow = $true )]
        [System.Collections.Specialized.OrderedDictionary ]
        $LinkList,

        [Parameter( Mandatory = $false, ParameterSetName = 'Reference')]
        [Parameter( Mandatory = $true, ParameterSetName = 'OperationRef')]
        [Parameter( Mandatory = $true, ParameterSetName = 'OperationId')]
        [ValidatePattern('^[a-zA-Z0-9\.\-_]+$')]
        [string]
        $Name,

        [Parameter( ParameterSetName = 'OperationRef')]
        [Parameter( ParameterSetName = 'OperationId')]
        [string]
        $Description,

        [Parameter(Mandatory = $true, ParameterSetName = 'OperationId')]
        [string]
        $OperationId,

        [Parameter(Mandatory = $true, ParameterSetName = 'OperationRef')]
        [string]
        $OperationRef,

        [Parameter( ParameterSetName = 'OperationRef')]
        [Parameter( ParameterSetName = 'OperationId')]
        [hashtable]
        $Parameters,

        [Parameter( ParameterSetName = 'OperationRef')]
        [Parameter( ParameterSetName = 'OperationId')]
        [string]
        $RequestBody,

        [Parameter(Mandatory = $true, ParameterSetName = 'Reference')]
        [string]
        $Reference,

        [string[]]
        $DefinitionTag

    )
    begin {

        if (Test-PodeIsEmpty -Value $DefinitionTag) {
            $DefinitionTag = $PodeContext.Server.OpenAPI.SelectedDefinitionTag
        }
        if ($Reference) {
            Test-PodeOAComponentInternal -Field links -DefinitionTag $DefinitionTag -Name $Reference -PostValidation
            if (!$Name) {
                $Name = $Reference
            }
            $link = [ordered]@{
                $Name = [ordered]@{
                    '$ref' = "#/components/links/$Reference"
                }
            }
        }
        else {
            $link = [ordered]@{
                $Name = New-PodeOAResponseLinkInternal -Params $PSBoundParameters
            }
        }
    }
    process {
    }
    end {
        if ($LinkList) {
            $link.GetEnumerator() | ForEach-Object { $LinkList[$_.Key] = $_.Value }
            return $LinkList
        }
        else {
            return [System.Collections.Specialized.OrderedDictionary] $link
        }
    }

}


<#
.SYNOPSIS
    Creates an OpenAPI Server Object.

.DESCRIPTION
    Creates an OpenAPI Server Object to use with Add-PodeOAExternalRoute

.PARAMETER ServerEndpointList
    Used for piping

.PARAMETER Url
    A URL to the target host.  This URL supports Server Variables and MAY be relative, to indicate that the host location is relative to the location where the OpenAPI document is being served.
    Variable substitutions will be made when a variable is named in `{`brackets`}`.

.PARAMETER Description
    An optional string describing the host designated by the URL. [CommonMark syntax](https://spec.commonmark.org/) MAY be used for rich text representation.


.EXAMPLE
    New-PodeOAServerEndpoint -Url 'https://myserver.io/api' -Description 'My test server'

.EXAMPLE
    New-PodeOAServerEndpoint -Url '/api' -Description 'My local server'
#>
function New-PodeOAServerEndpoint {
    param (
        [Parameter(ValueFromPipeline = $true , Position = 0, DontShow = $true )]
        [hashtable[]]
        $ServerEndpointList,

        [Parameter(Mandatory = $true)]
        [ValidatePattern('^(https?://|/).+')]
        [string]
        $Url,

        [string]
        $Description
    )
    begin {
        $lUrl = [ordered]@{url = $Url }
        if ($Description) {
            $lUrl.description = $Description
        }
        $collectedInput = [System.Collections.Generic.List[hashtable]]::new()
    }
    process {
        if ($ServerEndpointList) {
            $collectedInput.AddRange($ServerEndpointList)
        }
    }
    end {
        if ($ServerEndpointList) {
            return $collectedInput + $lUrl
        }
        else {
            return $lUrl
        }
    }
}


<#
.SYNOPSIS
    Remove a response definition from the supplied route.

.DESCRIPTION
    Remove a response definition from the supplied route.

.PARAMETER Route
    The route to remove the response definition, usually from -PassThru on Add-PodeRoute.

.PARAMETER StatusCode
    The HTTP StatusCode for the response to remove.

.PARAMETER Default
    If supplied, the response will be used as a default response - this overrides the StatusCode supplied.

.PARAMETER PassThru
    If supplied, the route passed in will be returned for further chaining.

.EXAMPLE
    Add-PodeRoute -PassThru | Remove-PodeOAResponse -StatusCode 200

.EXAMPLE
    Add-PodeRoute -PassThru | Remove-PodeOAResponse -StatusCode 201 -Default
#>
function Remove-PodeOAResponse {
    [CmdletBinding()]
    [OutputType([hashtable[]])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [hashtable[]]
        $Route,

        [Parameter(Mandatory = $true)]
        [int]
        $StatusCode,

        [switch]
        $Default,

        [switch]
        $PassThru
    )
    begin {
        # Initialize an array to hold piped-in values
        $pipelineValue = @()
    }

    process {
        # Add the current piped-in value to the array
        $pipelineValue += $_
    }

    end {
        # Set Route to the array of values
        if ($pipelineValue.Count -gt 1) {
            $Route = $pipelineValue
        }

        # override status code with default
        $code = "$($StatusCode)"
        if ($Default) {
            $code = 'default'
        }
        # remove the respones from the routes
        foreach ($r in $Route) {
            if ($r.OpenApi.Responses.Keys -Contains $code) {
                $null = $r.OpenApi.Responses.Remove($code)
            }
        }

        if ($PassThru) {
            return $Route
        }
    }

}


<#
.SYNOPSIS
    Renames an existing OpenAPI definition tag in Pode.

.DESCRIPTION
    This function renames an existing OpenAPI definition tag to a new tag name.
    If the specified tag is the default definition tag, it updates the default tag as well.
    It ensures that the new tag name does not already exist and that the function is not used within a Select-PodeOADefinition ScriptBlock.

.PARAMETER Tag
    The current tag name of the OpenAPI definition. If not specified, the default definition tag is used.

.PARAMETER NewTag
    The new tag name for the OpenAPI definition. This parameter is mandatory.

.EXAMPLE
    Rename-PodeOADefinitionTag -Tag 'oldTag' -NewTag 'newTag'

    Rename a specific OpenAPI definition tag

.EXAMPLE
    Rename-PodeOADefinitionTag -NewTag 'newDefaultTag'

    Rename the default OpenAPI definition tag

.NOTES
    This function will throw an error if:
    - It is used inside a Select-PodeOADefinition ScriptBlock.
    - The new tag name already exists.
    - The current tag name does not exist.
#>
function Rename-PodeOADefinitionTag {
    param (
        [Parameter(Mandatory = $false)]
        [string]$Tag,
        [Parameter(Mandatory = $true)]
        [string]$NewTag
    )

    # Check if the function is being used inside a Select-PodeOADefinition ScriptBlock
    if ($PodeContext.Server.OpenApi.DefinitionTagSelectionStack.Count -gt 0) {
        throw ($PodeLocale.renamePodeOADefinitionTagExceptionMessage)
    }

    # Check if the new tag name already exists in the OpenAPI definitions
    if ($PodeContext.Server.OpenAPI.Definitions.ContainsKey($NewTag)) {
        throw ($PodeLocale.openApiDefinitionAlreadyExistsExceptionMessage -f $NewTag )
    }

    # If the Tag parameter is null or whitespace, use the default definition tag
    if ([string]::IsNullOrWhiteSpace($Tag)) {
        $Tag = $PodeContext.Server.Web.OpenApi.DefaultDefinitionTag
        $PodeContext.Server.Web.OpenApi.DefaultDefinitionTag = $NewTag # Update the default definition tag
    }
    else {
        # Test if the specified tag exists in the OpenAPI definitions
        Test-PodeOADefinitionTag -Tag $Tag
    }

    # Rename the definition tag in the OpenAPI definitions
    $PodeContext.Server.OpenAPI.Definitions[$NewTag] = $PodeContext.Server.OpenAPI.Definitions[$Tag]
    $PodeContext.Server.OpenAPI.Definitions.Remove($Tag)

    # Update the selected definition tag if it matches the old tag
    if ($PodeContext.Server.OpenAPI.SelectedDefinitionTag -eq $Tag) {
        $PodeContext.Server.OpenAPI.SelectedDefinitionTag = $NewTag
    }
}


<#
.SYNOPSIS
    Select a group of OpenAPI Definions for modification.

.DESCRIPTION
    Select a group of OpenAPI Definions for modification.

.PARAMETER Tag
    An Array of strings representing the unique tag for the API specification.
    This tag helps distinguish between different versions or types of API specifications within the application.
    You can use this tag to reference the specific API documentation, schema, or version that your function interacts with.
    If Tag is empty or null the default Definition is selected

.PARAMETER ScriptBlock
    The ScriptBlock that will modified the group.

.EXAMPLE
    Select-PodeOADefinition -Tag 'v3', 'v3.1'  -Script {
    New-PodeOAIntProperty -Name 'id'-Format Int64 -Example 10 -Required |
    New-PodeOAIntProperty -Name 'petId' -Format Int64 -Example 198772 -Required |
    New-PodeOAIntProperty -Name 'quantity' -Format Int32 -Example 7 -Required |
    New-PodeOAStringProperty -Name 'shipDate' -Format Date-Time |
    New-PodeOAStringProperty -Name 'status' -Description 'Order Status' -Required -Example 'approved' -Enum @('placed', 'approved', 'delivered') |
    New-PodeOABoolProperty -Name 'complete' |
    New-PodeOAObjectProperty -XmlName 'order' |
    Add-PodeOAComponentSchema -Name 'Order'

    New-PodeOAContentMediaType -ContentType 'application/json', 'application/xml' -Content 'Pet' |
    Add-PodeOAComponentRequestBody -Name 'Pet' -Description 'Pet object that needs to be added to the store'

    }
#>
function Select-PodeOADefinition {
    [CmdletBinding()]
    param(
        [string[]]
        $Tag,

        [Parameter(Mandatory = $true)]
        [scriptblock]
        $Scriptblock
    )

    if (Test-PodeIsEmpty $Scriptblock) {
        # No ScriptBlock supplied
        throw ($PodeLocale.noScriptBlockSuppliedExceptionMessage)
    }
    if (Test-PodeIsEmpty -Value $Tag) {
        $Tag = $PodeContext.Server.Web.OpenApi.DefaultDefinitionTag
    }
    else {
        $Tag = Test-PodeOADefinitionTag -Tag $Tag
    }
    # check for scoped vars
    $Scriptblock, $usingVars = Convert-PodeScopedVariables -ScriptBlock $Scriptblock -PSSession $PSCmdlet.SessionState
    $PodeContext.Server.OpenApi.DefinitionTagSelectionStack.Push($PodeContext.Server.OpenAPI.SelectedDefinitionTag)

    $PodeContext.Server.OpenAPI.SelectedDefinitionTag = $Tag

    $null = Invoke-PodeScriptBlock -ScriptBlock $Scriptblock -UsingVariables $usingVars -Splat
    $PodeContext.Server.OpenAPI.SelectedDefinitionTag = $PodeContext.Server.OpenApi.DefinitionTagSelectionStack.Pop()

}


<#
.SYNOPSIS
    Sets the OpenAPI request definition for a route.

.DESCRIPTION
    Configures the OpenAPI request properties for a specified route, including parameters and request body definition.
    This function defines how the route should handle incoming requests in accordance with OpenAPI standards.

.PARAMETER Route
    The route to set a request definition for. This is typically passed through from -PassThru on Add-PodeRoute.

.PARAMETER Parameters
    Defines the parameters for the request, provided by ConvertTo-PodeOAParameter.

.PARAMETER RequestBody
    Specifies the body schema for the request, provided by New-PodeOARequestBody.

.PARAMETER AllowNonStandardBody
    Allows methods like DELETE and GET to include a request body, which is generally discouraged by RFC 7231.
    This can be used to relax the default restriction and enable a body for HTTP methods that don’t typically support it.

.PARAMETER PassThru
    If specified, returns the original route object for additional chaining after setting the request properties.

.PARAMETER DefinitionTag
    An Array of strings representing the unique tag for the API specification.
    This tag helps distinguish between different versions or types of API specifications within the application.
    You can use this tag to reference the specific API documentation, schema, or version that your function interacts with.

.EXAMPLE
    Add-PodeRoute -PassThru | Set-PodeOARequest -RequestBody (New-PodeOARequestBody -Schema 'UserIdBody') -AllowNonStandardBody

    Sets the request body for a route and allows non-standard HTTP methods like DELETE to use a request body.
#>
function Set-PodeOARequest {
    [CmdletBinding()]
    [OutputType([hashtable[]])]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [hashtable[]]
        $Route,

        [hashtable[]]
        $Parameters,

        [hashtable]
        $RequestBody,

        [switch]
        $PassThru,

        [switch]
        $AllowNonStandardBody,

        [string[]]
        $DefinitionTag
    )
    begin {
        # Initialize an array to hold piped-in values
        $pipelineValue = @()
    }

    process {
        # Add the current piped-in value to the array
        $pipelineValue += $_
    }

    end {
        # Set Route to the array of values
        if ($pipelineValue.Count -gt 1) {
            $Route = $pipelineValue
        }

        foreach ($r in $Route) {

            $oaDefinitionTag = Test-PodeRouteOADefinitionTag -Route $r -DefinitionTag $DefinitionTag

            foreach ($tag in $oaDefinitionTag) {
                if (($null -ne $Parameters) -and ($Parameters.Length -gt 0)) {
                    $r.OpenApi.Parameters[$tag] = @($Parameters)
                }

                if ($null -ne $RequestBody) {
                    # Check if AllowNonStandardBody is used or if the method is typically allowed to have a body
                    if (! $AllowNonStandardBody -and ('POST', 'PUT', 'PATCH') -inotcontains $r.Method) {
                        #'{0}' operations cannot have a Request Body. Use -AllowNonStandardBody to override this restriction.
                        throw ($PodeLocale.getRequestBodyNotAllowedExceptionMessage -f $r.Method)
                    }
                    $r.OpenApi.RequestBody = $RequestBody
                }

            }
        }

        if ($PassThru) {
            return $Route
        }

    }
}


<#
.SYNOPSIS
    Sets metadate for the supplied route.

.DESCRIPTION
    Sets metadate for the supplied route, such as Summary and Tags.

.PARAMETER Route
    The route to update info, usually from -PassThru on Add-PodeRoute.

.PARAMETER Summary
    A quick Summary of the route.

.PARAMETER Description
    A longer Description of the route.

.PARAMETER ExternalDoc
    If supplied, add an additional external documentation for this operation.
    The parameter is created by Add-PodeOAExternalDoc

.PARAMETER OperationId
    Sets the OperationId of the route.

.PARAMETER Tags
    An array of Tags for the route, mostly for grouping.

.PARAMETER Deprecated
    If supplied, the route will be flagged as deprecated.

.PARAMETER PassThru
    If supplied, the route passed in will be returned for further chaining.

.PARAMETER DefinitionTag
    An Array of strings representing the unique tag for the API specification.
    This tag helps distinguish between different versions or types of API specifications within the application.
    You can use this tag to reference the specific API documentation, schema, or version that your function interacts with.

.EXAMPLE
    Add-PodeRoute -PassThru | Set-PodeOARouteInfo -Summary 'A quick summary' -Tags 'Admin'
#>
function Set-PodeOARouteInfo {
    [CmdletBinding()]
    [OutputType([hashtable[]])]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [hashtable[]]
        $Route,

        [string]
        $Summary,

        [string]
        $Description,

        [System.Collections.Specialized.OrderedDictionary]
        $ExternalDoc,

        [string]
        $OperationId,

        [string[]]
        $Tags,

        [switch]
        $Deprecated,

        [switch]
        $PassThru,

        [string[]]
        $DefinitionTag
    )
    begin {
        # Initialize an array to hold piped-in values
        $pipelineValue = @()
    }

    process {
        # Add the current piped-in value to the array
        $pipelineValue += $_
    }

    end {
        # Set Route to the array of values
        if ($pipelineValue.Count -gt 1) {
            $Route = $pipelineValue
        }

        $defaultTag = Test-PodeOADefinitionTag -Tag $DefinitionTag

        foreach ($r in @($Route)) {
            if ($DefinitionTag) {
                if ((Compare-Object -ReferenceObject $r.OpenApi.DefinitionTag -DifferenceObject  $DefinitionTag).Count -ne 0) {
                    if ($r.OpenApi.IsDefTagConfigured ) {
                        # Definition Tag for a Route cannot be changed.
                        throw ($PodeLocale.definitionTagChangeNotAllowedExceptionMessage)
                    }

                    $r.OpenApi.DefinitionTag = $defaultTag
                    $r.OpenApi.IsDefTagConfigured = $true
                }
            }
            else {
                if (! $r.OpenApi.IsDefTagConfigured ) {
                    $r.OpenApi.DefinitionTag = $defaultTag
                    $r.OpenApi.IsDefTagConfigured = $true
                }
            }

            if ($OperationId) {
                if ($Route.Count -gt 1) {
                    # OperationID:$OperationId has to be unique and cannot be applied to an array
                    throw ($PodeLocale.operationIdMustBeUniqueForArrayExceptionMessage -f $OperationId)
                }
                foreach ($tag in $defaultTag) {
                    if ($PodeContext.Server.OpenAPI.Definitions[$tag].hiddenComponents.operationId -ccontains $OperationId) {
                        # OperationID:$OperationId has to be unique
                        throw ($PodeLocale.operationIdMustBeUniqueExceptionMessage -f $OperationId)
                    }
                    $PodeContext.Server.OpenAPI.Definitions[$tag].hiddenComponents.operationId += $OperationId
                }
                $r.OpenApi.OperationId = $OperationId
            }

            if ($Summary) {
                $r.OpenApi.Summary = $Summary
            }

            if ($Description) {
                $r.OpenApi.Description = $Description
            }

            if ($Tags) {
                $r.OpenApi.Tags = $Tags
            }

            if ($ExternalDocs) {
                $r.OpenApi.ExternalDocs = $ExternalDoc
            }

            $r.OpenApi.Swagger = $true

            if ($Deprecated.IsPresent) {
                $r.OpenApi.Deprecated = $Deprecated.IsPresent
            }
        }

        if ($PassThru) {
            return $Route
        }
    }
}


<#
.SYNOPSIS
    Validate the OpenAPI definition if all Reference are satisfied

.DESCRIPTION
    Validate the OpenAPI definition if all Reference are satisfied

.PARAMETER DefinitionTag
    An Array of strings representing the unique tag for the API specification.
    This tag helps distinguish between different versions or types of API specifications within the application.
    You can use this tag to reference the specific API documentation, schema, or version that your function interacts with.

.EXAMPLE
    if ((Test-PodeOADefinition -DefinitionTag 'v3').count -eq 0){
    Write-PodeHost "The OpenAPI definition is valid"
    }
#>
function Test-PodeOADefinition {
    param (
        [string[]]
        $DefinitionTag
    )
    if (! ($DefinitionTag -and $DefinitionTag.Count -gt 0)) {
        $DefinitionTag = $PodeContext.Server.OpenAPI.Definitions.keys
    }

    $result = @{
        valid  = $true
        issues = @{
        }
    }

    foreach ($tag in $DefinitionTag) {
        if ($PodeContext.Server.OpenAPI.Definitions[$tag].hiddenComponents.enabled) {
            if ([string]::IsNullOrWhiteSpace(  $PodeContext.Server.OpenAPI.Definitions[$tag].info.title) -or [string]::IsNullOrWhiteSpace(  $PodeContext.Server.OpenAPI.Definitions[$tag].info.version)) {
                $result.valid = $false
            }
            $result.issues[$tag] = @{
                title      = [string]::IsNullOrWhiteSpace(  $PodeContext.Server.OpenAPI.Definitions[$tag].info.title)
                version    = [string]::IsNullOrWhiteSpace(  $PodeContext.Server.OpenAPI.Definitions[$tag].info.version)
                components = [ordered]@{}
                definition = ''
            }
            foreach ($field in $PodeContext.Server.OpenAPI.Definitions[$tag].hiddenComponents.postValidation.keys) {
                foreach ($name in $PodeContext.Server.OpenAPI.Definitions[$tag].hiddenComponents.postValidation[$field].keys) {
                    if (! (Test-PodeOAComponentInternal -DefinitionTag $tag -Field $field -Name $name)) {
                        $result.issues[$tag].components["#/components/$field/$name"] = $PodeContext.Server.OpenAPI.Definitions[$tag].hiddenComponents.postValidation[$field][$name]
                        $result.valid = $false
                    }
                }
            }
            try {
                Get-PodeOADefinition -DefinitionTag $tag | Out-Null
            }
            catch {
                $result.issues[$tag].definition = $_.Exception.Message
            }
        }
    }
    return  $result
}


<#
.SYNOPSIS
    Check if a Definition exist

.DESCRIPTION
    Check if a Definition exist. If the parameter Tag is empty or Null $PodeContext.Server.OpenAPI.SelectedDefinitionTag is returned

.PARAMETER Tag
    An Array of strings representing the unique tag for the API specification.
    This tag helps distinguish between different versions or types of API specifications within the application.
    You can use this tag to reference the specific API documentation, schema, or version that your function interacts with.

.EXAMPLE
    Test-PodeOADefinitionTag -Tag 'v3', 'v3.1'
#>
function Test-PodeOADefinitionTag {
    param (
        [Parameter(Mandatory = $false)]
        [string[]]
        $Tag
    )

    if ($Tag -and $Tag.Count -gt 0) {
        foreach ($t in $Tag) {
            if (! ($PodeContext.Server.OpenApi.Definitions.Keys -icontains $t)) {
                # DefinitionTag does not exist.
                throw ($PodeLocale.definitionTagNotDefinedExceptionMessage -f $t)
            }
        }
        return $Tag
    }
    else {
        return $PodeContext.Server.OpenAPI.SelectedDefinitionTag
    }
}


<#
.SYNOPSIS
    Checks if OpenAPI is enabled in the Pode server.

.DESCRIPTION
    The `Test-PodeOAEnabled` function iterates through the OpenAPI definitions in the Pode server to determine if any are enabled.
    It checks for the presence of `bookmarks` in the hidden components of each definition, which indicates an active OpenAPI configuration.

.RETURNS
    [bool] True if OpenAPI is enabled; otherwise, False.

.EXAMPLE
    Test-PodeOAEnabled

    Returns $true if OpenAPI is enabled for any definition in the Pode server, otherwise returns $false.
#>
function Test-PodeOAEnabled {
    # Iterate through each OpenAPI definition key
    foreach ($key in $PodeContext.Server.OpenAPI.Definitions.Keys) {
        # Retrieve the bookmarks from the hidden components
        $bookmarks = $PodeContext.Server.OpenAPI.Definitions[$key].hiddenComponents.bookmarks

        # If bookmarks exist, OpenAPI is enabled for this definition
        if ($bookmarks) {
            return $true
        }
    }

    # If no bookmarks are found, OpenAPI is not enabled
    return $false
}


<#
.SYNOPSIS
    Validate a parameter with a provided schema.

.DESCRIPTION
    Validate the parameter of a method against it's own schema

.PARAMETER Json
    The object in Json format to validate

.PARAMETER SchemaReference
    The schema name to use to validate the property.

.PARAMETER DefinitionTag
    A string representing the unique tag for the API specification.
    This tag helps distinguish between different versions or types of API specifications within the application.
    You can use this tag to reference the specific API documentation, schema, or version that your function interacts with.

.OUTPUTS
    result: true if the object is validate positively
    message: any validation issue

.EXAMPLE
    $UserInfo = Test-PodeOAJsonSchemaCompliance -Json $UserInfo -SchemaReference 'UserIdSchema'}

#>
function Test-PodeOAJsonSchemaCompliance {
    param (
        [Parameter(Mandatory = $true)]
        [System.Object]
        $Json,

        [Parameter(Mandatory = $true)]
        [string]
        $SchemaReference,

        [string]
        $DefinitionTag
    )
    if ($DefinitionTag) {
        if (! ($PodeContext.Server.OpenApi.Definitions.Keys -icontains $DefinitionTag)) {
            # DefinitionTag does not exist.
            throw ($PodeLocale.definitionTagNotDefinedExceptionMessage -f $DefinitionTag)
        }
    }
    else {
        $DefinitionTag = $PodeContext.Server.Web.OpenApi.DefaultDefinitionTag
    }

    # if Powershell edition is Desktop the test cannot be done. By default everything is good
    if ($PSVersionTable.PSEdition -eq 'Desktop') {
        return $true
    }

    if ($Json -isnot [string]) {
        $json = ConvertTo-Json -InputObject $Json -Depth $PodeContext.Server.OpenAPI.Definitions[$DefinitionTag].hiddenComponents.depth
    }

    if (!$PodeContext.Server.OpenAPI.Definitions[$DefinitionTag].hiddenComponents.schemaValidation) {
        # 'Test-PodeOAComponentchema' need to be enabled using 'Enable-PodeOpenApi -EnableSchemaValidation'
        throw ($PodeLocale.testPodeOAComponentSchemaNeedToBeEnabledExceptionMessage)
    }
    if (!(Test-PodeOAComponentSchemaJson -Name $SchemaReference -DefinitionTag $DefinitionTag)) {
        # The OpenApi component schema doesn't exist
        throw ($PodeLocale.openApiComponentSchemaDoesNotExistExceptionMessage -f $SchemaReference)
    }
    if ($PodeContext.Server.OpenAPI.Definitions[$DefinitionTag].hiddenComponents.schemaJson[$SchemaReference].available) {
        [string[]] $message = @()
        $result = Test-Json -Json $Json -Schema $PodeContext.Server.OpenAPI.Definitions[$DefinitionTag].hiddenComponents.schemaJson[$SchemaReference].json -ErrorVariable jsonValidationErrors -ErrorAction SilentlyContinue
        if ($jsonValidationErrors) {
            foreach ($item in $jsonValidationErrors) {
                $message += $item
            }
        }
    }
    else {
        $result = $false
        $message = 'Validation of schema with oneof or anyof is not supported'
    }

    return @{result = $result; message = $message }
}


<#
.SYNOPSIS
    Add a custom path that contains additional views.

.DESCRIPTION
    Add a custom path that contains additional views.

.PARAMETER Name
    The Name of the views folder.

.PARAMETER Source
    The literal, or relative, path to the directory that contains views.

.EXAMPLE
    Add-PodeViewFolder -Name 'assets' -Source './assets'
#>
function Add-PodeViewFolder {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true)]
        [string]
        $Source
    )

    # ensure the folder doesn't already exist
    if ($PodeContext.Server.Views.ContainsKey($Name)) {
        # The Views folder name already exists
        throw ($PodeLocale.viewsFolderNameAlreadyExistsExceptionMessage -f $Name)
    }

    # ensure the path exists at server root
    $Source = Get-PodeRelativePath -Path $Source -JoinRoot
    if (!(Test-PodePath -Path $Source -NoStatus)) {
        # The Views path does not exist
        throw ($PodeLocale.viewsPathDoesNotExistExceptionMessage -f $Source)
    }

    # setup a temp drive for the path
    $Source = New-PodePSDrive -Path $Source

    # add the route(s)
    Write-Verbose "Adding View Folder: [$($Name)] $($Source)"
    $PodeContext.Server.Views[$Name] = $Source
}


<#
.SYNOPSIS
    Close an open TCP client connection

.DESCRIPTION
    Close an open TCP client connection

.EXAMPLE
    Close-PodeTcpClient
#>
function Close-PodeTcpClient {
    [CmdletBinding()]
    param()

    $TcpEvent.Request.Close()
}


<#
.SYNOPSIS
    Redirecting a user to a new URL.

.DESCRIPTION
    Redirecting a user to a new URL, or the same URL as the Request but a different Protocol - or other components.

.PARAMETER Url
    Redirect the user to a new URL, or a relative path.

.PARAMETER EndpointName
    The Name of an Endpoint to redirect to.

.PARAMETER Port
    Change the port of the current Request before redirecting.

.PARAMETER Protocol
    Change the protocol of the current Request before redirecting.

.PARAMETER Address
    Change the domain address of the current Request before redirecting.

.PARAMETER Moved
    Set the Status Code as "301 Moved", rather than "302 Redirect".

.EXAMPLE
    Move-PodeResponseUrl -Url 'https://google.com'

.EXAMPLE
    Move-PodeResponseUrl -Url '/about'

.EXAMPLE
    Move-PodeResponseUrl -Protocol HTTPS

.EXAMPLE
    Move-PodeResponseUrl -Port 9000 -Moved
#>
function Move-PodeResponseUrl {
    [CmdletBinding(DefaultParameterSetName = 'Url')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'Url')]
        [string]
        $Url,

        [Parameter(ParameterSetName = 'Endpoint')]
        [string]
        $EndpointName,

        [Parameter(ParameterSetName = 'Components')]
        [int]
        $Port = 0,

        [Parameter(ParameterSetName = 'Components')]
        [ValidateSet('', 'Http', 'Https')]
        [string]
        $Protocol,

        [Parameter(ParameterSetName = 'Components')]
        [string]
        $Address,

        [switch]
        $Moved
    )

    # build the url
    if ($PSCmdlet.ParameterSetName -ieq 'components') {
        $uri = $WebEvent.Request.Url

        # set the protocol
        $Protocol = $Protocol.ToLowerInvariant()
        if ([string]::IsNullOrWhiteSpace($Protocol)) {
            $Protocol = $uri.Scheme
        }

        # set the domain
        if ([string]::IsNullOrWhiteSpace($Address)) {
            $Address = $uri.Host
        }

        # set the port
        if ($Port -le 0) {
            $Port = $uri.Port
        }

        $PortStr = [string]::Empty
        if (@(80, 443) -notcontains $Port) {
            $PortStr = ":$($Port)"
        }

        # combine to form the url
        $Url = "$($Protocol)://$($Address)$($PortStr)$($uri.PathAndQuery)"
    }

    # build the url from an endpoint
    elseif ($PSCmdlet.ParameterSetName -ieq 'endpoint') {
        $endpoint = Get-PodeEndpointByName -Name $EndpointName -ThrowError

        # set the port
        $PortStr = [string]::Empty
        if (@(80, 443) -notcontains $endpoint.Port) {
            $PortStr = ":$($endpoint.Port)"
        }

        $Url = "$($endpoint.Protocol)://$($endpoint.FriendlyName)$($PortStr)$($WebEvent.Request.Url.PathAndQuery)"
    }

    Set-PodeHeader -Name 'Location' -Value $Url

    if ($Moved) {
        Set-PodeResponseStatus -Code 301 -Description 'Moved'
    }
    else {
        Set-PodeResponseStatus -Code 302 -Description 'Redirect'
    }
}


<#
.SYNOPSIS
    Reads data from a TCP socket stream.

.DESCRIPTION
    Reads data from a TCP socket stream.

.PARAMETER Timeout
    An optional Timeout in milliseconds.

.PARAMETER CheckBytes
    An optional array of bytes to check at the end of a receievd data stream, to determine if the data is complete.

.PARAMETER CRLFMessageEnd
    If supplied, the CheckBytes will be set to 13 and 10 to make sure a message ends with CR and LF.

.EXAMPLE
    $data = Read-PodeTcpClient

.EXAMPLE
    $data = Read-PodeTcpClient -CRLFMessageEnd
#>
function Read-PodeTcpClient {
    [CmdletBinding(DefaultParameterSetName = 'default')]
    [OutputType([string])]
    param(
        [Parameter()]
        [int]
        $Timeout = 0,

        [Parameter(ParameterSetName = 'CheckBytes')]
        [byte[]]
        $CheckBytes = $null,

        [Parameter(ParameterSetName = 'CRLF')]
        [switch]
        $CRLFMessageEnd
    )

    $cBytes = $CheckBytes
    if ($CRLFMessageEnd) {
        $cBytes = [byte[]]@(13, 10)
    }

    return (Wait-PodeTask -Task $TcpEvent.Request.Read($cBytes, $PodeContext.Tokens.Cancellation.Token) -Timeout $Timeout)
}


<#
.SYNOPSIS
    Saves any uploaded files on the Request to the File System.

.DESCRIPTION
    Saves any uploaded files on the Request to the File System.

.PARAMETER Key
    The name of the key within the $WebEvent's Data HashTable that stores the file names.

.PARAMETER Path
    The path to save files. If this is a directory then the file name of the uploaded file will be used, but if this is a file path then that name is used instead.
    If the Request has multiple files in, and you specify a file path, then all files will be saved to that one file path - overwriting each other.

.PARAMETER FileName
    An optional FileName to save a specific files if multiple files were supplied in the Request. By default, every file is saved.

.EXAMPLE
    Save-PodeRequestFile -Key 'avatar'

.EXAMPLE
    Save-PodeRequestFile -Key 'avatar' -Path 'F:/Images'

.EXAMPLE
    Save-PodeRequestFile -Key 'avatar' -Path 'F:/Images' -FileName 'icon.png'
#>
function Save-PodeRequestFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Key,

        [Parameter()]
        [string]
        $Path = '.',

        [Parameter()]
        [string[]]
        $FileName
    )

    # if path is '.', replace with server root
    $Path = Get-PodeRelativePath -Path $Path -JoinRoot

    # ensure the parameter name exists in data
    if (!(Test-PodeRequestFile -Key $Key)) {
        # A parameter called was not supplied in the request or has no data available
        throw ($PodeLocale.parameterNotSuppliedInRequestExceptionMessage -f $Key)
    }

    # get the file names
    $files = @($WebEvent.Data[$Key])
    if (($null -ne $FileName) -and ($FileName.Length -gt 0)) {
        $files = @(foreach ($file in $files) {
                if ($FileName -icontains $file) {
                    $file
                }
            })
    }

    # ensure the file data exists
    foreach ($file in $files) {
        if (!$WebEvent.Files.ContainsKey($file)) {
            # No data for file was uploaded in the request
            throw ($PodeLocale.noDataForFileUploadedExceptionMessage -f $file)
        }
    }

    # save the files
    foreach ($file in $files) {
        # if the path is a directory, add the filename
        $filePath = $Path
        if (Test-Path -Path $filePath -PathType Container) {
            $filePath = [System.IO.Path]::Combine($filePath, $file)
        }

        # save the file
        $WebEvent.Files[$file].Save($filePath)
    }
}


<#
.SYNOPSIS
    Pre-emptively send an HTTP response back to the client. This can be dangerous, so only use this function if you know what you're doing.

.DESCRIPTION
    Pre-emptively send an HTTP response back to the client. This can be dangerous, so only use this function if you know what you're doing.

.EXAMPLE
    Send-PodeResponse
#>
function Send-PodeResponse {
    [CmdletBinding()]
    param()

    if ($null -ne $WebEvent.Response) {
        $null = Wait-PodeTask -Task $WebEvent.Response.Send()
    }
}


<#
.SYNOPSIS
    Broadcasts a message to connected WebSocket clients.

.DESCRIPTION
    Broadcasts a message to all, or some, connected WebSocket clients. You can specify a path to send messages to, or a specific ClientId.

.PARAMETER Value
    A String, PSObject, or HashTable value. For non-string values, they will be converted to JSON.

.PARAMETER Path
    The Path of connected clients to send the message.

.PARAMETER ClientId
    A specific ClientId of a connected client to send a message. Not currently used.

.PARAMETER Depth
    The Depth to generate the JSON document - the larger this value the worse performance gets.

.PARAMETER Mode
    The Mode to broadcast a message: Auto, Broadcast, Direct. (Default: Auto)

.PARAMETER IgnoreEvent
    If supplied, if a SignalEvent is available it's data, such as path/clientId, will be ignored.

.EXAMPLE
    Send-PodeSignal -Value @{ Message = 'Hello, world!' }

.EXAMPLE
    Send-PodeSignal -Value @{ Data = @(123, 100, 101) } -Path '/response-charts'
#>
function Send-PodeSignal {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true, Position = 0 )]
        $Value,

        [Parameter()]
        [string]
        $Path,

        [Parameter()]
        [string]
        $ClientId,

        [Parameter()]
        [int]
        $Depth = 10,

        [Parameter()]
        [ValidateSet('Auto', 'Broadcast', 'Direct')]
        [string]
        $Mode = 'Auto',

        [switch]
        $IgnoreEvent
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
        # error if not configured
        if (!$PodeContext.Server.Signals.Enabled) {
            # WebSockets have not been configured to send signal messages
            throw ($PodeLocale.websocketsNotConfiguredForSignalMessagesExceptionMessage)
        }

        # do nothing if no value
        if (($null -eq $Value) -or ([string]::IsNullOrEmpty($Value))) {
            return
        }

        # jsonify the value
        if ($Value -isnot [string]) {
            if ($Depth -le 0) {
                $Value = (ConvertTo-Json -InputObject $Value -Compress)
            }
            else {
                $Value = (ConvertTo-Json -InputObject $Value -Depth $Depth -Compress)
            }
        }

        # check signal event
        if (!$IgnoreEvent -and ($null -ne $SignalEvent)) {
            if ([string]::IsNullOrWhiteSpace($Path)) {
                $Path = $SignalEvent.Data.Path
            }

            if ([string]::IsNullOrWhiteSpace($ClientId)) {
                $ClientId = $SignalEvent.Data.ClientId
            }

            if (($Mode -ieq 'Auto') -and ($SignalEvent.Data.Direct -or ($SignalEvent.ClientId -ieq $SignalEvent.Data.ClientId))) {
                $Mode = 'Direct'
            }
        }

        # broadcast or direct?
        if ($Mode -iin @('Auto', 'Broadcast')) {
            $PodeContext.Server.Signals.Listener.AddServerSignal($Value, $Path, $ClientId)
        }
        else {
            $SignalEvent.Response.Write($Value)
        }
    }
}


<#
.SYNOPSIS
    Attaches a file onto the Response for downloading.

.DESCRIPTION
    Attaches a file from the "/public", and static Routes, onto the Response for downloading.
    If the supplied path is not in the Static Routes but is a literal/relative path, then this file is used instead.

.PARAMETER Path
    The Path to a static file relative to the "/public" directory, or a static Route.
    If the supplied Path doesn't match any custom static Route, then Pode will look in the "/public" directory.
    Failing this, if the file path exists as a literal/relative file, then this file is used as a fall back.

.PARAMETER ContentType
    Manually specify the content type of the response rather than inferring it from the attachment's file extension.
    The supplied value must match the valid ContentType format, e.g. application/json

.PARAMETER EndpointName
    Optional EndpointName that the static route was creating under.

.PARAMETER FileBrowser
    If the path is a folder, instead of returning 404, will return A browsable content of the directory.

.EXAMPLE
    Set-PodeResponseAttachment -Path 'downloads/installer.exe'

.EXAMPLE
    Set-PodeResponseAttachment -Path './image.png'

.EXAMPLE
    Set-PodeResponseAttachment -Path 'c:/content/accounts.xlsx'

.EXAMPLE
    Set-PodeResponseAttachment -Path './data.txt' -ContentType 'application/json'

.EXAMPLE
    Set-PodeResponseAttachment -Path '/assets/data.txt' -EndpointName 'Example'
#>
function Set-PodeResponseAttachment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [string]
        $Path,

        [ValidatePattern('^\w+\/[\w\.\+-]+$')]
        [string]
        $ContentType,

        [Parameter()]
        [string]
        $EndpointName,

        [switch]
        $FileBrowser

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

        # already sent? skip
        if ($WebEvent.Response.Sent) {
            return
        }

        # only attach files from public/static-route directories when path is relative
        $route = (Find-PodeStaticRoute -Path $Path -CheckPublic -EndpointName $EndpointName)
        if ($route) {
            $_path = $route.Content.Source
        }
        else {
            $_path = Get-PodeRelativePath -Path $Path -JoinRoot
        }

        #call internal Attachment function
        Write-PodeAttachmentResponseInternal -Path $_path -ContentType $ContentType -FileBrowser:$fileBrowser
    }
}


<#
.SYNOPSIS
    Sets the Status Code of the Response, and controls rendering error pages.

.DESCRIPTION
    Sets the Status Code of the Response, and controls rendering error pages.

.PARAMETER Code
    The Status Code to set on the Response.

.PARAMETER Description
    An optional Status Description.

.PARAMETER Exception
    An exception to use when detailing error information on error pages.

.PARAMETER ContentType
    The content type of the error page to use.

.PARAMETER NoErrorPage
    Don't render an error page when the Status Code is 400+.

.EXAMPLE
    Set-PodeResponseStatus -Code 404

.EXAMPLE
    Set-PodeResponseStatus -Code 500 -Exception $_.Exception

.EXAMPLE
    Set-PodeResponseStatus -Code 500 -Exception $_.Exception -ContentType 'application/json'
#>
function Set-PodeResponseStatus {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [int]
        $Code,

        [Parameter()]
        [string]
        $Description,

        [Parameter()]
        $Exception,

        [Parameter()]
        [string]
        $ContentType = $null,

        [switch]
        $NoErrorPage
    )

    # already sent? skip
    if ($WebEvent.Response.Sent) {
        return
    }

    # set the code
    $WebEvent.Response.StatusCode = $Code

    # set an appropriate description (mapping if supplied is blank)
    if ([string]::IsNullOrWhiteSpace($Description)) {
        $Description = (Get-PodeStatusDescription -StatusCode $Code)
    }

    if (!$PodeContext.Server.IsServerless -and ![string]::IsNullOrWhiteSpace($Description)) {
        $WebEvent.Response.StatusDescription = $Description
    }

    # if the status code is >=400 then attempt to load error page
    if (!$NoErrorPage -and ($Code -ge 400)) {
        Show-PodeErrorPage -Code $Code -Description $Description -Exception $Exception -ContentType $ContentType
    }
}


<#
.SYNOPSIS
    Short description

.DESCRIPTION
    Long description

.PARAMETER Type
    The type name of the view engine (inbuilt types are: Pode and HTML).

.PARAMETER ScriptBlock
    A ScriptBlock for specifying custom view engine rendering rules.

.PARAMETER Extension
    A custom extension for the engine's files.

.EXAMPLE
    Set-PodeViewEngine -Type HTML

.EXAMPLE
    Set-PodeViewEngine -Type Markdown

.EXAMPLE
    Set-PodeViewEngine -Type PSHTML -Extension PS1 -ScriptBlock { param($path, $data) /* logic */ }
#>
function Set-PodeViewEngine {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Type,

        [Parameter()]
        [scriptblock]
        $ScriptBlock = $null,

        [Parameter()]
        [string]
        $Extension
    )

    # truncate markdown
    if ($Type -ieq 'Markdown') {
        $Type = 'md'
    }

    # override extension with type
    if ([string]::IsNullOrWhiteSpace($Extension)) {
        $Extension = $Type
    }

    # check if the scriptblock has any using vars
    if ($null -ne $ScriptBlock) {
        $ScriptBlock, $usingVars = Convert-PodeScopedVariables -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState
    }

    # setup view engine config
    $PodeContext.Server.ViewEngine.Type = $Type.ToLowerInvariant()
    $PodeContext.Server.ViewEngine.Extension = $Extension.ToLowerInvariant()
    $PodeContext.Server.ViewEngine.ScriptBlock = $ScriptBlock
    $PodeContext.Server.ViewEngine.UsingVariables = $usingVars
    $PodeContext.Server.ViewEngine.IsDynamic = (@('html', 'md') -inotcontains $Type)
}


<#
.SYNOPSIS
    Test to see if the Request contains the key for any uploaded files.

.DESCRIPTION
    Test to see if the Request contains the key for any uploaded files.

.PARAMETER Key
    The name of the key within the $WebEvent's Data HashTable that stores the file names.

.PARAMETER FileName
    An optional FileName to test for a specific file within the list of uploaded files.

.EXAMPLE
    Test-PodeRequestFile -Key 'avatar'

.EXAMPLE
    Test-PodeRequestFile -Key 'avatar' -FileName 'icon.png'
#>
function Test-PodeRequestFile {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Key,

        [Parameter()]
        [string]
        $FileName
    )

    # ensure the parameter name exists in data
    if (!$WebEvent.Data.ContainsKey($Key)) {
        return $false
    }

    # ensure it has filenames
    if ([string]::IsNullOrEmpty($WebEvent.Data[$Key])) {
        return $false
    }

    # do we have any specific files?
    if (![string]::IsNullOrEmpty($FileName)) {
        return (@($WebEvent.Data[$Key]) -icontains $FileName)
    }

    # we have files
    return $true
}


<#
.SYNOPSIS
    Includes the contents of a partial View into another dynamic View.

.DESCRIPTION
    Includes the contents of a partial View into another dynamic View. The partial View can be static or dynamic.

.PARAMETER Path
    The path to a partial View, relative to the "/views" directory. (Extension is optional).

.PARAMETER Data
    Any dynamic data to supply to a dynamic partial View.

.PARAMETER Folder
    If supplied, a custom views folder will be used.

.EXAMPLE
    Use-PodePartialView -Path 'shared/footer'
#>
function Use-PodePartialView {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [string]
        $Path,

        [Parameter()]
        $Data = @{},

        [Parameter()]
        [string]
        $Folder
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
        # default data if null
        if ($null -eq $Data) {
            $Data = @{}
        }
        # add view engine extension
        $ext = Get-PodeFileExtension -Path $Path
        if ([string]::IsNullOrWhiteSpace($ext)) {
            $Path += ".$($PodeContext.Server.ViewEngine.Extension)"
        }

        # only look in the view directory
        $viewFolder = $PodeContext.Server.InbuiltDrives['views']
        if (![string]::IsNullOrWhiteSpace($Folder)) {
            $viewFolder = $PodeContext.Server.Views[$Folder]
        }

        $Path = [System.IO.Path]::Combine($viewFolder, $Path)

        # test the file path, and set status accordingly
        if (!(Test-PodePath $Path -NoStatus)) {
            # The Views path does not exist
            throw ($PodeLocale.viewsPathDoesNotExistExceptionMessage -f $Path)
        }

        # run any engine logic
        return (Get-PodeFileContentUsingViewEngine -Path $Path -Data $Data)
    }
}


<#
.SYNOPSIS
    Writes CSV data to the Response.

.DESCRIPTION
    Writes CSV data to the Response, setting the content type accordingly.

.PARAMETER Value
    A String, PSObject, or HashTable value.

.PARAMETER Path
    The path to a CSV file.

.PARAMETER StatusCode
    The status code to set against the response.

.EXAMPLE
    Write-PodeCsvResponse -Value "Name`nRick"

.EXAMPLE
    Write-PodeCsvResponse -Value @{ Name = 'Rick' }

.EXAMPLE
    Write-PodeCsvResponse -Path 'E:/Files/Names.csv'
#>
function Write-PodeCsvResponse {
    [CmdletBinding(DefaultParameterSetName = 'Value')]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'Value', ValueFromPipeline = $true, Position = 0)]
        $Value,

        [Parameter(Mandatory = $true, ParameterSetName = 'File')]
        [string]
        $Path,

        [Parameter()]
        [int]
        $StatusCode = 200
    )

    begin {
        $pipelineValue = @()
    }

    process {
        if ($PSCmdlet.ParameterSetName -eq 'Value') {
            $pipelineValue += $_
        }
    }

    end {
        switch ($PSCmdlet.ParameterSetName.ToLowerInvariant()) {
            'file' {
                if (Test-PodePath $Path) {
                    $Value = Get-PodeFileContent -Path $Path
                }
            }

            'value' {
                if ($pipelineValue.Count -gt 1) {
                    $Value = $pipelineValue
                }

                if ($Value -isnot [string]) {
                    $Value = Resolve-PodeObjectArray -Property $Value

                    if (Test-PodeIsPSCore) {
                        $Value = ($Value | ConvertTo-Csv -Delimiter ',' -IncludeTypeInformation:$false)
                    }
                    else {
                        $Value = ($Value | ConvertTo-Csv -Delimiter ',' -NoTypeInformation)
                    }

                    $Value = ($Value -join ([environment]::NewLine))
                }
            }
        }

        if ([string]::IsNullOrWhiteSpace($Value)) {
            $Value = [string]::Empty
        }

        Write-PodeTextResponse -Value $Value -ContentType 'text/csv' -StatusCode $StatusCode
    }
}


<#
.SYNOPSIS
    Serves a directory listing as a web page.

.DESCRIPTION
    The Write-PodeDirectoryResponse function generates an HTML response that lists the contents of a specified directory,
    allowing for browsing of files and directories. It supports both Windows and Unix-like environments by adjusting the
    display of file attributes accordingly. If the path is a directory, it generates a browsable HTML view; otherwise, it
    serves the file directly.

.PARAMETER Path
    The path to the directory that should be displayed. This path is resolved and used to generate a list of contents.

.EXAMPLE
    Write-PodeDirectoryResponse -Path './static'

    Generates and serves an HTML page that lists the contents of the './static' directory, allowing users to click through files and directories.
#>
function Write-PodeDirectoryResponse {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [ValidateNotNull()]
        [string]
        $Path
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

        # resolve for relative path
        $RelativePath = Get-PodeRelativePath -Path $Path -JoinRoot

        if (Test-Path -Path $RelativePath -PathType Container) {
            Write-PodeDirectoryResponseInternal -Path $RelativePath
        }
        else {
            Set-PodeResponseStatus -Code 404
        }
    }
}


<#
.SYNOPSIS
    Renders the content of a static, or dynamic, file on the Response.

.DESCRIPTION
    Renders the content of a static, or dynamic, file on the Response.
    You can set browser's to cache the content, and also override the file's content type.

.PARAMETER Path
    The path to a file.

.PARAMETER Data
    A HashTable of dynamic data to supply to a dynamic file.

.PARAMETER ContentType
    The content type of the file's contents - this overrides the file's extension.

.PARAMETER MaxAge
    The maximum age to cache the file's content on the browser, in seconds.

.PARAMETER StatusCode
    The status code to set against the response.

.PARAMETER Cache
    Should the file's content be cached by browsers, or not?

.PARAMETER FileBrowser
    If the path is a folder, instead of returning 404, will return A browsable content of the directory.

.EXAMPLE
    Write-PodeFileResponse -Path 'C:/Files/Stuff.txt'

.EXAMPLE
    Write-PodeFileResponse -Path 'C:/Files/Stuff.txt' -Cache -MaxAge 1800

.EXAMPLE
    Write-PodeFileResponse -Path 'C:/Files/Stuff.txt' -ContentType 'application/json'

.EXAMPLE
    Write-PodeFileResponse -Path 'C:/Views/Index.pode' -Data @{ Counter = 2 }

.EXAMPLE
    Write-PodeFileResponse -Path 'C:/Files/Stuff.txt' -StatusCode 201

.EXAMPLE
    Write-PodeFileResponse -Path 'C:/Files/' -FileBrowser
#>
function Write-PodeFileResponse {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [ValidateNotNull()]
        [string]
        $Path,

        [Parameter()]
        $Data = @{},

        [Parameter()]
        [string]
        $ContentType = $null,

        [Parameter()]
        [int]
        $MaxAge = 3600,

        [Parameter()]
        [int]
        $StatusCode = 200,

        [switch]
        $Cache,

        [switch]
        $FileBrowser
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
        # resolve for relative path
        $RelativePath = Get-PodeRelativePath -Path $Path -JoinRoot

        Write-PodeFileResponseInternal -Path $RelativePath -Data $Data -ContentType $ContentType -MaxAge $MaxAge `
            -StatusCode $StatusCode -Cache:$Cache -FileBrowser:$FileBrowser
    }
}


<#
.SYNOPSIS
    Writes HTML data to the Response.

.DESCRIPTION
    Writes HTML data to the Response, setting the content type accordingly.

.PARAMETER Value
    A String, PSObject, or HashTable value.

.PARAMETER Path
    The path to a HTML file.

.PARAMETER StatusCode
    The status code to set against the response.

.EXAMPLE
    Write-PodeHtmlResponse -Value "Raw HTML can be placed here"

.EXAMPLE
    Write-PodeHtmlResponse -Value @{ Message = 'Hello, all!' }

.EXAMPLE
    Write-PodeHtmlResponse -Path 'E:/Site/About.html'
#>
function Write-PodeHtmlResponse {
    [CmdletBinding(DefaultParameterSetName = 'Value')]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'Value', ValueFromPipeline = $true, Position = 0)]
        $Value,

        [Parameter(Mandatory = $true, ParameterSetName = 'File')]
        [string]
        $Path,

        [Parameter()]
        [int]
        $StatusCode = 200
    )

    begin {
        $pipelineValue = @()
    }

    process {
        if ($PSCmdlet.ParameterSetName -eq 'Value') {
            $pipelineValue += $_
        }
    }

    end {
        switch ($PSCmdlet.ParameterSetName.ToLowerInvariant()) {
            'file' {
                if (Test-PodePath $Path) {
                    $Value = Get-PodeFileContent -Path $Path
                }
            }

            'value' {
                if ($pipelineValue.Count -gt 1) {
                    $Value = $pipelineValue
                }
                if ($Value -isnot [string]) {
                    $Value = ($Value | ConvertTo-Html)
                    $Value = ($Value -join ([environment]::NewLine))
                }
            }
        }

        if ([string]::IsNullOrWhiteSpace($Value)) {
            $Value = [string]::Empty
        }

        Write-PodeTextResponse -Value $Value -ContentType 'text/html' -StatusCode $StatusCode
    }
}


<#
.SYNOPSIS
    Writes JSON data to the Response.

.DESCRIPTION
    Writes JSON data to the Response, setting the content type accordingly.

.PARAMETER Value
    A String, PSObject, or HashTable value. For non-string values, they will be converted to JSON.

.PARAMETER Path
    The path to a JSON file.

.PARAMETER ContentType
    Because JSON content has not yet an official content type. one custom can be specified here (Default: 'application/json' )
    https://www.rfc-editor.org/rfc/rfc8259

.PARAMETER Depth
    The Depth to generate the JSON document - the larger this value the worse performance gets.

.PARAMETER StatusCode
    The status code to set against the response.

.PARAMETER NoCompress
    The JSON document is not compressed (Human readable form)

.EXAMPLE
    Write-PodeJsonResponse -Value '{"name": "Rick"}'

.EXAMPLE
    Write-PodeJsonResponse -Value @{ Name = 'Rick' } -StatusCode 201

.EXAMPLE
    Write-PodeJsonResponse -Path 'E:/Files/Names.json'
#>
function Write-PodeJsonResponse {
    [CmdletBinding(DefaultParameterSetName = 'Value')]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'Value', ValueFromPipeline = $true, Position = 0)]
        [AllowNull()]
        $Value,

        [Parameter(Mandatory = $true, ParameterSetName = 'File')]
        [string]
        $Path,

        [Parameter()]
        [ValidatePattern('^\w+\/[\w\.\+-]+$')]
        [ValidateNotNullOrEmpty()]
        [string]
        $ContentType = 'application/json',

        [Parameter(ParameterSetName = 'Value')]
        [ValidateRange(0, 100)]
        [int]
        $Depth = 10,

        [Parameter()]
        [int]
        $StatusCode = 200,

        [Parameter(ParameterSetName = 'Value')]
        [switch]
        $NoCompress

    )
    begin {
        $pipelineValue = @()
    }

    process {
        if ($PSCmdlet.ParameterSetName -eq 'Value') {
            $pipelineValue += $_
        }
    }

    end {
        switch ($PSCmdlet.ParameterSetName.ToLowerInvariant()) {
            'file' {
                if (Test-PodePath $Path) {
                    $Value = Get-PodeFileContent -Path $Path
                }
                if ([string]::IsNullOrWhiteSpace($Value)) {
                    $Value = '{}'
                }
            }

            'value' {
                if ($pipelineValue.Count -gt 1) {
                    $Value = $pipelineValue
                }
                if ($Value -isnot [string]) {
                    $Value = (ConvertTo-Json -InputObject $Value -Depth $Depth -Compress:(!$NoCompress))
                }
            }
        }

        if ([string]::IsNullOrWhiteSpace($Value)) {
            $Value = '{}'
        }

        Write-PodeTextResponse -Value $Value -ContentType $ContentType -StatusCode $StatusCode
    }
}


<#
.SYNOPSIS
    Writes Markdown data to the Response.

.DESCRIPTION
    Writes Markdown data to the Response, with the option to render it as HTML.

.PARAMETER Value
    A String value.

.PARAMETER Path
    The path to a Markdown file.

.PARAMETER StatusCode
    The status code to set against the response.

.PARAMETER AsHtml
    If supplied, the Markdown will be converted to HTML. (This is only supported in PS7+)

.EXAMPLE
    Write-PodeMarkdownResponse -Value '# Hello, world!' -AsHtml

.EXAMPLE
    Write-PodeMarkdownResponse -Path 'E:/Site/About.md'
#>
function Write-PodeMarkdownResponse {
    [CmdletBinding(DefaultParameterSetName = 'Value')]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'Value', ValueFromPipeline = $true, Position = 0)]
        $Value,

        [Parameter(Mandatory = $true, ParameterSetName = 'File')]
        [string]
        $Path,

        [Parameter()]
        [int]
        $StatusCode = 200,

        [switch]
        $AsHtml
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
        switch ($PSCmdlet.ParameterSetName.ToLowerInvariant()) {
            'file' {
                if (Test-PodePath $Path) {
                    $Value = Get-PodeFileContent -Path $Path
                }
            }
        }

        if ([string]::IsNullOrWhiteSpace($Value)) {
            $Value = [string]::Empty
        }

        $mimeType = 'text/markdown'

        if ($AsHtml) {
            if ($PSVersionTable.PSVersion.Major -ge 7) {
                $mimeType = 'text/html'
                $Value = ($Value | ConvertFrom-Markdown).Html
            }
        }

        Write-PodeTextResponse -Value $Value -ContentType $mimeType -StatusCode $StatusCode
    }
}


<#
.SYNOPSIS
    Writes data to a TCP socket stream.

.DESCRIPTION
    Writes data to a TCP socket stream.

.PARAMETER Message
    The message to write

.EXAMPLE
    Write-PodeTcpClient -Message '250 OK'
#>
function Write-PodeTcpClient {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true)]
        [string]
        $Message
    )
    begin {
        # Initialize an array to hold piped-in values
        $pipelineValue = @()
    }

    process {
        # Add the current piped-in value to the array
        $pipelineValue += $_
    }

    end {
        # Set Route to the array of values
        if ($pipelineValue.Count -gt 1) {
            $Message = $pipelineValue -join "`n"
        }
        $TcpEvent.Response.WriteLine($Message, $true)
    }
}


<#
.SYNOPSIS
    Writes a String or a Byte[] to the Response.

.DESCRIPTION
    Writes a String or a Byte[] to the Response, as some specified content type. This value can also be cached.

.PARAMETER Value
    A String value to write.

.PARAMETER Bytes
    An array of Bytes to write.

.PARAMETER ContentType
    The content type of the data being written.

.PARAMETER MaxAge
    The maximum age to cache the value on the browser, in seconds.

.PARAMETER StatusCode
    The status code to set against the response.

.PARAMETER Cache
    Should the value be cached by browsers, or not?

.EXAMPLE
    Write-PodeTextResponse -Value 'Leeeeeerrrooooy Jeeeenkiiins!'

.EXAMPLE
    Write-PodeTextResponse -Value '{"name": "Rick"}' -ContentType 'application/json'

.EXAMPLE
    Write-PodeTextResponse -Bytes (Get-Content -Path ./some/image.png -Raw -AsByteStream) -Cache -MaxAge 1800

.EXAMPLE
    Write-PodeTextResponse -Value 'Untitled Text Response' -StatusCode 418
#>
function Write-PodeTextResponse {
    [CmdletBinding(DefaultParameterSetName = 'String')]
    param (
        [Parameter(ParameterSetName = 'String', ValueFromPipeline = $true, Position = 0)]
        [string]
        $Value,

        [Parameter(ParameterSetName = 'Bytes')]
        [byte[]]
        $Bytes,

        [Parameter()]
        [string]
        $ContentType = 'text/plain',

        [Parameter()]
        [int]
        $MaxAge = 3600,

        [Parameter()]
        [int]
        $StatusCode = 200,

        [switch]
        $Cache
    )
    begin {
        # Initialize an array to hold piped-in values
        $pipelineValue = @()
    }

    process {
        # Add the current piped-in value to the array
        $pipelineValue += $_
    }

    end {
        # Set Value to the array of values
        if ($pipelineValue.Count -gt 1) {
            $Value = $pipelineValue -join "`n"
        }

        $isStringValue = ($PSCmdlet.ParameterSetName -ieq 'string')
        $isByteValue = ($PSCmdlet.ParameterSetName -ieq 'bytes')

        # set the status code of the response, but only if it's not 200 (to prevent overriding)
        if ($StatusCode -ne 200) {
            Set-PodeResponseStatus -Code $StatusCode -NoErrorPage
        }

        # if there's nothing to write, return
        if ($isStringValue -and [string]::IsNullOrWhiteSpace($Value)) {
            return
        }

        if ($isByteValue -and (($null -eq $Bytes) -or ($Bytes.Length -eq 0))) {
            return
        }

        # if the response stream isn't writable or already sent, return
        $res = $WebEvent.Response
        if (($null -eq $res) -or ($WebEvent.Streamed -and (($null -eq $res.OutputStream) -or !$res.OutputStream.CanWrite -or $res.Sent))) {
            return
        }

        # set a cache value
        if ($Cache) {
            Set-PodeHeader -Name 'Cache-Control' -Value "max-age=$($MaxAge), must-revalidate"
            Set-PodeHeader -Name 'Expires' -Value ([datetime]::UtcNow.AddSeconds($MaxAge).ToString('r', [CultureInfo]::InvariantCulture))
        }

        # specify the content-type if supplied (adding utf-8 if missing)
        if (![string]::IsNullOrWhiteSpace($ContentType)) {
            $charset = 'charset=utf-8'
            if ($ContentType -inotcontains $charset) {
                $ContentType = "$($ContentType); $($charset)"
            }

            $res.ContentType = $ContentType
        }

        # if we're serverless, set the string as the body
        if (!$WebEvent.Streamed) {
            if ($isStringValue) {
                $res.Body = $Value
            }
            else {
                $res.Body = $Bytes
            }
        }

        else {
            # convert string to bytes
            if ($isStringValue) {
                $Bytes = [System.Text.Encoding]::UTF8.GetBytes($Value)
            }

            # check if we only need a range of the bytes
            if (($null -ne $WebEvent.Ranges) -and ($WebEvent.Response.StatusCode -eq 200) -and ($StatusCode -eq 200)) {
                $lengths = @()
                $size = $Bytes.Length

                $Bytes = @(foreach ($range in $WebEvent.Ranges) {
                        # ensure range not invalid
                        if (([int]$range.Start -lt 0) -or ([int]$range.Start -ge $size) -or ([int]$range.End -lt 0)) {
                            Set-PodeResponseStatus -Code 416 -NoErrorPage
                            return
                        }

                        # skip start bytes only
                        if ([string]::IsNullOrWhiteSpace($range.End)) {
                            $Bytes[$range.Start..($size - 1)]
                            $lengths += "$($range.Start)-$($size - 1)/$($size)"
                        }

                        # end bytes only
                        elseif ([string]::IsNullOrWhiteSpace($range.Start)) {
                            if ([int]$range.End -gt $size) {
                                $range.End = $size
                            }

                            if ([int]$range.End -gt 0) {
                                $Bytes[$($size - $range.End)..($size - 1)]
                                $lengths += "$($size - $range.End)-$($size - 1)/$($size)"
                            }
                            else {
                                $lengths += "0-0/$($size)"
                            }
                        }

                        # normal range
                        else {
                            if ([int]$range.End -ge $size) {
                                Set-PodeResponseStatus -Code 416 -NoErrorPage
                                return
                            }

                            $Bytes[$range.Start..$range.End]
                            $lengths += "$($range.Start)-$($range.End)/$($size)"
                        }
                    })

                Set-PodeHeader -Name 'Content-Range' -Value "bytes $($lengths -join ', ')"
                if ($StatusCode -eq 200) {
                    Set-PodeResponseStatus -Code 206 -NoErrorPage
                }
            }

            # check if we need to compress the response
            if ($PodeContext.Server.Web.Compression.Enabled -and ![string]::IsNullOrWhiteSpace($WebEvent.AcceptEncoding)) {
                # compress the bytes
                $Bytes = [PodeHelpers]::CompressBytes($Bytes, $WebEvent.AcceptEncoding)

                # set content encoding header
                Set-PodeHeader -Name 'Content-Encoding' -Value $WebEvent.AcceptEncoding
            }

            # write the content to the response stream
            $res.ContentLength64 = $Bytes.Length

            try {
                $ms = [System.IO.MemoryStream]::new()
                $ms.Write($Bytes, 0, $Bytes.Length)
                $ms.WriteTo($res.OutputStream)
            }
            catch {
                if ((Test-PodeValidNetworkFailure $_.Exception)) {
                    return
                }

                $_ | Write-PodeErrorLog
                throw
            }
            finally {
                if ($null -ne $ms) {
                    $ms.Close()
                }
            }
        }
    }
}


<#
.SYNOPSIS
    Renders a dynamic, or static, View on the Response.

.DESCRIPTION
    Renders a dynamic, or static, View on the Response; allowing for dynamic data to be supplied.

.PARAMETER Path
    The path to a View, relative to the "/views" directory. (Extension is optional).

.PARAMETER Data
    Any dynamic data to supply to a dynamic View.

.PARAMETER StatusCode
    The status code to set against the response.

.PARAMETER Folder
    If supplied, a custom views folder will be used.

.PARAMETER FlashMessages
    Automatically supply all Flash messages in the current session to the View.

.EXAMPLE
    Write-PodeViewResponse -Path 'index'

.EXAMPLE
    Write-PodeViewResponse -Path 'accounts/profile_page' -Data @{ Username = 'Morty' }

.EXAMPLE
    Write-PodeViewResponse -Path 'login' -FlashMessages
#>
function Write-PodeViewResponse {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [string]
        $Path,

        [Parameter()]
        [hashtable]
        $Data = @{},

        [Parameter()]
        [int]
        $StatusCode = 200,

        [Parameter()]
        [string]
        $Folder,

        [switch]
        $FlashMessages
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
        # default data if null
        if ($null -eq $Data) {
            $Data = @{}
        }

        # add path to data as "pagename" - unless key already exists
        if (!$Data.ContainsKey('pagename')) {
            $Data['pagename'] = $Path
        }

        # load all flash messages if needed
        if ($FlashMessages -and ($null -ne $WebEvent.Session.Data.Flash)) {
            $Data['flash'] = @{}

            foreach ($name in (Get-PodeFlashMessageNames)) {
                $Data.flash[$name] = (Get-PodeFlashMessage -Name $name)
            }
        }
        elseif ($null -eq $Data['flash']) {
            $Data['flash'] = @{}
        }

        # add view engine extension
        $ext = Get-PodeFileExtension -Path $Path
        if ([string]::IsNullOrWhiteSpace($ext)) {
            $Path += ".$($PodeContext.Server.ViewEngine.Extension)"
        }

        # only look in the view directories
        $viewFolder = $PodeContext.Server.InbuiltDrives['views']
        if (![string]::IsNullOrWhiteSpace($Folder)) {
            $viewFolder = $PodeContext.Server.Views[$Folder]
        }

        $Path = [System.IO.Path]::Combine($viewFolder, $Path)

        # test the file path, and set status accordingly
        if (!(Test-PodePath $Path)) {
            return
        }

        # run any engine logic and render it
        $engine = (Get-PodeViewEngineType -Path $Path)
        $value = (Get-PodeFileContentUsingViewEngine -Path $Path -Data $Data)

        switch ($engine.ToLowerInvariant()) {
            'md' {
                Write-PodeMarkdownResponse -Value $value -StatusCode $StatusCode -AsHtml
            }

            default {
                Write-PodeHtmlResponse -Value $value -StatusCode $StatusCode
            }
        }
    }
}


<#
.SYNOPSIS
    Writes XML data to the Response.

.DESCRIPTION
    Writes XML data to the Response, setting the content type accordingly.

.PARAMETER Value
    A String, PSObject, or HashTable value.

.PARAMETER Path
    The path to an XML file.

.PARAMETER ContentType
    Because XML content has not yet an official content type. one custom can be specified here (Default: 'application/xml' )
    https://www.rfc-editor.org/rfc/rfc3023

.PARAMETER Depth
    The Depth to generate the XML document - the larger this value the worse performance gets.

.PARAMETER StatusCode
    The status code to set against the response.

.EXAMPLE
    Write-PodeXmlResponse -Value '<root><name>Rick</name></root>'

.EXAMPLE
    Write-PodeXmlResponse -Value @{ Name = 'Rick' } -StatusCode 201

.EXAMPLE
    @(@{ Name = 'Rick' }, @{ Name = 'Don' }) | Write-PodeXmlResponse

.EXAMPLE
    $users = @([PSCustomObject]@{
    Name = 'Rick'
    }, [PSCustomObject]@{
    Name = 'Don'
    }
    )
    Write-PodeXmlResponse -Value $users

.EXAMPLE
    @([PSCustomObject]@{
    Name = 'Rick'
    }, [PSCustomObject]@{
    Name = 'Don'
    }
    ) | Write-PodeXmlResponse

.EXAMPLE
    Write-PodeXmlResponse -Path 'E:/Files/Names.xml'

#>
function Write-PodeXmlResponse {
    [CmdletBinding(DefaultParameterSetName = 'Value')]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'Value', ValueFromPipeline = $true, Position = 0)]
        [AllowNull()]
        $Value,

        [Parameter(Mandatory = $true, ParameterSetName = 'File')]
        [string]
        $Path,

        [Parameter(ParameterSetName = 'Value')]
        [ValidateRange(0, 100)]
        [int]
        $Depth = 10,

        [Parameter()]
        [ValidatePattern('^\w+\/[\w\.\+-]+$')]
        [ValidateNotNullOrEmpty()]
        [string]
        $ContentType = 'application/xml',

        [Parameter()]
        [int]
        $StatusCode = 200
    )
    begin {
        $pipelineValue = @()
    }

    process {
        if ($PSCmdlet.ParameterSetName -eq 'Value' -and $_) {
            $pipelineValue += $_
        }
    }

    end {

        switch ($PSCmdlet.ParameterSetName.ToLowerInvariant()) {
            'file' {
                if (Test-PodePath $Path) {
                    $Value = Get-PodeFileContent -Path $Path
                }
            }

            'value' {
                if ($pipelineValue.Count -gt 1) {
                    $Value = $pipelineValue
                }

                if ($Value -isnot [string]) {
                    $Value = Resolve-PodeObjectArray -Property $Value | ConvertTo-Xml -Depth $Depth -As String -NoTypeInformation
                }
            }
        }

        if ([string]::IsNullOrWhiteSpace($Value)) {
            $Value = [string]::Empty
        }

        Write-PodeTextResponse -Value $Value -ContentType $ContentType -StatusCode $StatusCode
    }
}


<#
.SYNOPSIS
    Writes YAML data to the Response.

.DESCRIPTION
    Writes YAML data to the Response, setting the content type accordingly.

.PARAMETER Value
    A String, PSObject, or HashTable value. For non-string values, they will be converted to YAML.

.PARAMETER Path
    The path to a YAML file.

.PARAMETER ContentType
    Because YAML content has not yet an official content type. one custom can be specified here (Default: 'application/yaml' )
    https://www.rfc-editor.org/rfc/rfc9512

.PARAMETER Depth
    The Depth to generate the YAML document - the larger this value the worse performance gets.

.PARAMETER StatusCode
    The status code to set against the response.

.EXAMPLE
    Write-PodeYamlResponse -Value 'name: "Rick"'

.EXAMPLE
    Write-PodeYamlResponse -Value @{ Name = 'Rick' } -StatusCode 201

.EXAMPLE
    Write-PodeYamlResponse -Path 'E:/Files/Names.yaml'
#>
function Write-PodeYamlResponse {
    [CmdletBinding(DefaultParameterSetName = 'Value')]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'Value', ValueFromPipeline = $true, Position = 0)]
        [AllowNull()]
        $Value,

        [Parameter(Mandatory = $true, ParameterSetName = 'File')]
        [string]
        $Path,

        [Parameter()]
        [ValidatePattern('^\w+\/[\w\.\+-]+$')]
        [ValidateNotNullOrEmpty()]
        [string]
        $ContentType = 'application/yaml',


        [Parameter(ParameterSetName = 'Value')]
        [ValidateRange(0, 100)]
        [int]
        $Depth = 10,

        [Parameter()]
        [int]
        $StatusCode = 200
    )

    begin {
        $pipelineValue = @()
    }

    process {
        if ($PSCmdlet.ParameterSetName -eq 'Value') {
            $pipelineValue += $_
        }
    }

    end {

        switch ($PSCmdlet.ParameterSetName.ToLowerInvariant()) {
            'file' {
                if (Test-PodePath $Path) {
                    $Value = Get-PodeFileContent -Path $Path
                }
            }

            'value' {
                if ($pipelineValue.Count -gt 1) {
                    $Value = $pipelineValue
                }

                if ($Value -isnot [string]) {
                    $Value = ConvertTo-PodeYaml -InputObject $Value -Depth $Depth

                }
            }
        }
        if ([string]::IsNullOrWhiteSpace($Value)) {
            $Value = '[]'
        }

        Write-PodeTextResponse -Value $Value -ContentType $ContentType -StatusCode $StatusCode
    }
}


<#
.SYNOPSIS
    Helper function to generate simple GET routes.

.DESCRIPTION
    Helper function to generate simple GET routes from ScritpBlocks, Files, and Views.
    The output is always rendered as HTML.

.PARAMETER Name
    A unique name for the page, that will be used in the Path for the route.

.PARAMETER ScriptBlock
    A ScriptBlock to invoke, where any results will be converted to HTML.

.PARAMETER FilePath
    A FilePath, literal or relative, to a valid HTML file.

.PARAMETER View
    The name of a View to render, this can be HTML or Dynamic.

.PARAMETER Data
    A hashtable of Data to supply to a Dynamic File/View, or to be splatted as arguments for the ScriptBlock.

.PARAMETER Path
    An optional Path for the Route, to prepend before the Name.

.PARAMETER Middleware
    Like normal Routes, an array of Middleware that will be applied to all generated Routes.

.PARAMETER Authentication
    The name of an Authentication method which should be used as middleware on this Route.

.PARAMETER Access
    The name of an Access method which should be used as middleware on this Route.

.PARAMETER AllowAnon
    If supplied, the Page will allow anonymous access for non-authenticated users.

.PARAMETER FlashMessages
    If supplied, Views will have any flash messages supplied to them for rendering.

.PARAMETER Role
    One or more optional Roles that will be authorised to access this Route, when using Authentication with an Access method.

.PARAMETER Group
    One or more optional Groups that will be authorised to access this Route, when using Authentication with an Access method.

.PARAMETER Scope
    One or more optional Scopes that will be authorised to access this Route, when using Authentication with an Access method.

.PARAMETER User
    One or more optional Users that will be authorised to access this Route, when using Authentication with an Access method.

.EXAMPLE
    Add-PodePage -Name Services -ScriptBlock { Get-Service }

.EXAMPLE
    Add-PodePage -Name Index -View 'index'

.EXAMPLE
    Add-PodePage -Name About -FilePath '.\views\about.pode' -Data @{ Date = [DateTime]::UtcNow }
#>
function Add-PodePage {
    [CmdletBinding(DefaultParameterSetName = 'ScriptBlock')]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name,

        [Parameter(Mandatory = $true, ParameterSetName = 'ScriptBlock')]
        [scriptblock]
        $ScriptBlock,

        [Parameter(Mandatory = $true, ParameterSetName = 'File')]
        [string]
        $FilePath,

        [Parameter(Mandatory = $true, ParameterSetName = 'View')]
        [string]
        $View,

        [Parameter()]
        [hashtable]
        $Data,

        [Parameter()]
        [string]
        $Path = '/',

        [Parameter()]
        [object[]]
        $Middleware,

        [Parameter()]
        [Alias('Auth')]
        [string]
        $Authentication,

        [Parameter()]
        [string]
        $Access,

        [Parameter()]
        [string[]]
        $Role,

        [Parameter()]
        [string[]]
        $Group,

        [Parameter()]
        [string[]]
        $Scope,

        [Parameter()]
        [string[]]
        $User,

        [switch]
        $AllowAnon,

        [Parameter(ParameterSetName = 'View')]
        [switch]
        $FlashMessages
    )

    $logic = $null
    $arg = $null

    # ensure the name is a valid alphanumeric
    if ($Name -inotmatch '^[a-z0-9\-_]+$') {
        # The Page name should be a valid AlphaNumeric value
        throw ($PodeLocale.pageNameShouldBeAlphaNumericExceptionMessage -f $Name)
    }

    # trim end trailing slashes from the path
    $Path = Protect-PodeValue -Value $Path -Default '/'
    $Path = $Path.TrimEnd('/')

    # define the appropriate logic
    switch ($PSCmdlet.ParameterSetName.ToLowerInvariant()) {
        'scriptblock' {
            if (Test-PodeIsEmpty $ScriptBlock) {
                # A non-empty ScriptBlock is required to create a Page Route
                throw ($PodeLocale.nonEmptyScriptBlockRequiredForPageRouteExceptionMessage)
            }

            $arg = @($ScriptBlock, $Data)
            $logic = {
                param($script, $data)

                # invoke the function (optional splat data)
                if (Test-PodeIsEmpty $data) {
                    $result = Invoke-PodeScriptBlock -ScriptBlock $script -Return
                }
                else {
                    $result = Invoke-PodeScriptBlock -ScriptBlock $script -Arguments $data -Return
                }

                # if we have a result, convert it to html
                if (!(Test-PodeIsEmpty $result)) {
                    Write-PodeHtmlResponse -Value $result
                }
            }
        }

        'file' {
            $FilePath = Get-PodeRelativePath -Path $FilePath -JoinRoot -TestPath
            $arg = @($FilePath, $Data)
            $logic = {
                param($file, $data)
                Write-PodeFileResponse -Path $file -ContentType 'text/html' -Data $data
            }
        }

        'view' {
            $arg = @($View, $Data, $FlashMessages)
            $logic = {
                param($view, $data, [bool]$flash)
                Write-PodeViewResponse -Path $view -Data $data -FlashMessages:$flash
            }
        }
    }

    # build the route's path
    $_path = ("$($Path)/$($Name)" -replace '[/]+', '/')

    # create the route
    $params = @{
        Method         = 'Get'
        Path           = $_path
        Middleware     = $Middleware
        Authentication = $Authentication
        Access         = $Access
        Role           = $Role
        Group          = $Group
        Scope          = $Scope
        User           = $User
        AllowAnon      = $AllowAnon
        ArgumentList   = $arg
        ScriptBlock    = $logic
    }

    Add-PodeRoute @params
}


<#
.SYNOPSIS
    Adds a Route for a specific HTTP Method(s).

.DESCRIPTION
    Adds a Route for a specific HTTP Method(s), with path, that when called with invoke any logic and/or Middleware.

.PARAMETER Method
    The HTTP Method of this Route, multiple can be supplied.

.PARAMETER Path
    The URI path for the Route.

.PARAMETER Middleware
    An array of ScriptBlocks for optional Middleware.

.PARAMETER ScriptBlock
    A ScriptBlock for the Route's main logic.

.PARAMETER EndpointName
    The EndpointName of an Endpoint(s) this Route should be bound against.

.PARAMETER ContentType
    The content type the Route should use when parsing any payloads.

.PARAMETER TransferEncoding
    The transfer encoding the Route should use when parsing any payloads.

.PARAMETER ErrorContentType
    The content type of any error pages that may get returned.

.PARAMETER FilePath
    A literal, or relative, path to a file containing a ScriptBlock for the Route's main logic.

.PARAMETER ArgumentList
    An array of arguments to supply to the Route's ScriptBlock.

.PARAMETER Authentication
    The name of an Authentication method which should be used as middleware on this Route.

.PARAMETER Access
    The name of an Access method which should be used as middleware on this Route.

.PARAMETER AllowAnon
    If supplied, the Route will allow anonymous access for non-authenticated users.

.PARAMETER Login
    If supplied, the Route will be flagged to Authentication as being a Route that handles user logins.

.PARAMETER Logout
    If supplied, the Route will be flagged to Authentication as being a Route that handles users logging out.

.PARAMETER PassThru
    If supplied, the route created will be returned so it can be passed through a pipe.

.PARAMETER IfExists
    Specifies what action to take when a Route already exists. (Default: Default)

.PARAMETER Role
    One or more optional Roles that will be authorised to access this Route, when using Authentication with an Access method.

.PARAMETER Group
    One or more optional Groups that will be authorised to access this Route, when using Authentication with an Access method.

.PARAMETER Scope
    One or more optional Scopes that will be authorised to access this Route, when using Authentication with an Access method.

.PARAMETER User
    One or more optional Users that will be authorised to access this Route, when using Authentication with an Access method.

.PARAMETER OAResponses
    An alternative way to associate OpenApi responses unsing New-PodeOAResponse instead of piping multiple Add-PodeOAResponse

.PARAMETER OAReference
    A reference to OpenAPI reusable pathItem component created with Add-PodeOAComponentPathItem

.PARAMETER OADefinitionTag
    An Array of strings representing the unique tag for the API specification.
    This tag helps in distinguishing between different versions or types of API specifications within the application.
    You can use this tag to reference the specific API documentation, schema, or version that your function interacts with.

.EXAMPLE
    Add-PodeRoute -Method Get -Path '/' -ScriptBlock { /* logic */ }

.EXAMPLE
    Add-PodeRoute -Method Post -Path '/users/:userId/message' -Middleware (Get-PodeCsrfMiddleware) -ScriptBlock { /* logic */ }

.EXAMPLE
    Add-PodeRoute -Method Post -Path '/user' -ContentType 'application/json' -ScriptBlock { /* logic */ }

.EXAMPLE
    Add-PodeRoute -Method Post -Path '/user' -ContentType 'application/json' -TransferEncoding gzip -ScriptBlock { /* logic */ }

.EXAMPLE
    Add-PodeRoute -Method Get -Path '/api/cpu' -ErrorContentType 'application/json' -ScriptBlock { /* logic */ }

.EXAMPLE
    Add-PodeRoute -Method Get -Path '/' -ScriptBlock { /* logic */ } -ArgumentList 'arg1', 'arg2'

.EXAMPLE
    Add-PodeRoute -Method Get -Path '/' -Role 'Developer', 'QA' -ScriptBlock { /* logic */ }

.EXAMPLE
    $Responses = New-PodeOAResponse -StatusCode 400 -Description 'Invalid username supplied' |
    New-PodeOAResponse -StatusCode 404 -Description 'User not found' |
    New-PodeOAResponse -StatusCode 405 -Description 'Invalid Input'

    Add-PodeRoute -PassThru -Method Put -Path '/user/:username' -OAResponses $Responses -ScriptBlock {
    #code is going here
    }
#>
function Add-PodeRoute {
    [CmdletBinding(DefaultParameterSetName = 'Script')]
    [OutputType([System.Object[]])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Connect', 'Delete', 'Get', 'Head', 'Merge', 'Options', 'Patch', 'Post', 'Put', 'Trace', '*')]
        [string[]]
        $Method,

        [Parameter(Mandatory = $true)]
        [string]
        $Path,

        [Parameter()]
        [object[]]
        $Middleware,

        [Parameter(ParameterSetName = 'Script')]
        [scriptblock]
        $ScriptBlock,

        [Parameter( )]
        [AllowNull()]
        [string[]]
        $EndpointName,

        [Parameter()]
        [string]
        $ContentType,

        [Parameter()]
        [ValidateSet('', 'gzip', 'deflate')]
        [string]
        $TransferEncoding,

        [Parameter()]
        [string]
        $ErrorContentType,

        [Parameter(Mandatory = $true, ParameterSetName = 'File')]
        [string]
        $FilePath,

        [Parameter()]
        [object[]]
        $ArgumentList,

        [Parameter()]
        [Alias('Auth')]
        [string]
        $Authentication,

        [Parameter()]
        [string]
        $Access,

        [Parameter()]
        [ValidateSet('Default', 'Error', 'Overwrite', 'Skip')]
        [string]
        $IfExists = 'Default',

        [Parameter()]
        [string[]]
        $Role,

        [Parameter()]
        [string[]]
        $Group,

        [Parameter()]
        [string[]]
        $Scope,

        [Parameter()]
        [string[]]
        $User,

        [switch]
        $AllowAnon,

        [switch]
        $Login,

        [switch]
        $Logout,

        [hashtable]
        $OAResponses,

        [string]
        $OAReference,

        [switch]
        $PassThru,

        [string[]]
        $OADefinitionTag
    )

    # check if we have any route group info defined
    if ($null -ne $RouteGroup) {
        if (![string]::IsNullOrWhiteSpace($RouteGroup.Path)) {
            $Path = "$($RouteGroup.Path)$($Path)"
        }

        if ($null -ne $RouteGroup.Middleware) {
            $Middleware = $RouteGroup.Middleware + $Middleware
        }

        if ([string]::IsNullOrWhiteSpace($EndpointName)) {
            $EndpointName = $RouteGroup.EndpointName
        }

        if ([string]::IsNullOrWhiteSpace($ContentType)) {
            $ContentType = $RouteGroup.ContentType
        }

        if ([string]::IsNullOrWhiteSpace($TransferEncoding)) {
            $TransferEncoding = $RouteGroup.TransferEncoding
        }

        if ([string]::IsNullOrWhiteSpace($ErrorContentType)) {
            $ErrorContentType = $RouteGroup.ErrorContentType
        }

        if ([string]::IsNullOrWhiteSpace($Authentication)) {
            $Authentication = $RouteGroup.Authentication
        }

        if ([string]::IsNullOrWhiteSpace($Access)) {
            $Access = $RouteGroup.Access
        }

        if ($RouteGroup.AllowAnon) {
            $AllowAnon = $RouteGroup.AllowAnon
        }

        if ($RouteGroup.IfExists -ine 'default') {
            $IfExists = $RouteGroup.IfExists
        }

        if ($null -ne $RouteGroup.AccessMeta.Role) {
            $Role = $RouteGroup.AccessMeta.Role + $Role
        }

        if ($null -ne $RouteGroup.AccessMeta.Group) {
            $Group = $RouteGroup.AccessMeta.Group + $Group
        }

        if ($null -ne $RouteGroup.AccessMeta.Scope) {
            $Scope = $RouteGroup.AccessMeta.Scope + $Scope
        }

        if ($null -ne $RouteGroup.AccessMeta.User) {
            $User = $RouteGroup.AccessMeta.User + $User
        }

        if ($null -ne $RouteGroup.AccessMeta.Custom) {
            $CustomAccess = $RouteGroup.AccessMeta.Custom
        }

        if ($null -ne $RouteGroup.OADefinitionTag ) {
            $OADefinitionTag = $RouteGroup.OADefinitionTag
        }
    }

    # var for new routes created
    $newRoutes = @()

    # store the original path
    $origPath = $Path

    # split route on '?' for query
    $Path = Split-PodeRouteQuery -Path $Path
    if ([string]::IsNullOrWhiteSpace($Path)) {
        # No Path supplied for the Route
        throw ($PodeLocale.noPathSuppliedForRouteExceptionMessage)
    }

    # ensure the route has appropriate slashes
    $Path = Update-PodeRouteSlash -Path $Path
    $OpenApiPath = ConvertTo-PodeOARoutePath -Path $Path
    $Path = Resolve-PodePlaceholder -Path $Path

    # get endpoints from name
    $endpoints = Find-PodeEndpoint -EndpointName $EndpointName

    # get default route IfExists state
    if ($IfExists -ieq 'Default') {
        $IfExists = Get-PodeRouteIfExistsPreference
    }

    # if middleware, scriptblock and file path are all null/empty, error
    if ((Test-PodeIsEmpty $Middleware) -and (Test-PodeIsEmpty $ScriptBlock) -and (Test-PodeIsEmpty $FilePath) -and (Test-PodeIsEmpty $Authentication)) {
        # [Method] Path: No logic passed
        throw ($PodeLocale.noLogicPassedForMethodRouteExceptionMessage -f ($Method -join ','), $Path)
    }

    # if we have a file path supplied, load that path as a scriptblock
    if ($PSCmdlet.ParameterSetName -ieq 'file') {
        $ScriptBlock = Convert-PodeFileToScriptBlock -FilePath $FilePath
    }

    # check for scoped vars
    $ScriptBlock, $usingVars = Convert-PodeScopedVariables -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState

    # convert any middleware into valid hashtables
    $Middleware = @(ConvertTo-PodeMiddleware -Middleware $Middleware -PSSession $PSCmdlet.SessionState)

    # if an access name was supplied, setup access as middleware first to it's after auth middleware
    if (![string]::IsNullOrWhiteSpace($Access)) {
        if ([string]::IsNullOrWhiteSpace($Authentication)) {
            # Access requires Authentication to be supplied on Routes
            throw ($PodeLocale.accessRequiresAuthenticationOnRoutesExceptionMessage)
        }

        if (!(Test-PodeAccessExists -Name $Access)) {
            # Access method does not exist
            throw ($PodeLocale.accessMethodDoesNotExistExceptionMessage -f $Access)
        }

        $options = @{
            Name = $Access
        }

        $Middleware = (@(Get-PodeAccessMiddlewareScript | New-PodeMiddleware -ArgumentList $options) + $Middleware)
    }

    # if an auth name was supplied, setup the auth as the first middleware
    if (![string]::IsNullOrWhiteSpace($Authentication)) {
        if (!(Test-PodeAuthExists -Name $Authentication)) {
            # Authentication method does not exist
            throw ($PodeLocale.authenticationMethodDoesNotExistExceptionMessage -f $Authentication)
        }

        $options = @{
            Name   = $Authentication
            Login  = $Login
            Logout = $Logout
            Anon   = $AllowAnon
        }

        $Middleware = (@(Get-PodeAuthMiddlewareScript | New-PodeMiddleware -ArgumentList $options) + $Middleware)
    }

    # custom access
    if ($null -eq $CustomAccess) {
        $CustomAccess = @{}
    }

    # workout a default content type for the route
    $ContentType = Find-PodeRouteContentType -Path $Path -ContentType $ContentType

    # workout a default transfer encoding for the route
    $TransferEncoding = Find-PodeRouteTransferEncoding -Path $Path -TransferEncoding $TransferEncoding

    # loop through each method
    foreach ($_method in $Method) {
        # ensure the route doesn't already exist for each endpoint
        $endpoints = @(foreach ($_endpoint in $endpoints) {
                $found = Test-PodeRouteInternal -Method $_method -Path $Path -Protocol $_endpoint.Protocol -Address $_endpoint.Address -ThrowError:($IfExists -ieq 'Error')

                if ($found) {
                    if ($IfExists -ieq 'Overwrite') {
                        Remove-PodeRoute -Method $_method -Path $origPath -EndpointName $_endpoint.Name
                    }

                    if ($IfExists -ieq 'Skip') {
                        continue
                    }
                }

                $_endpoint
            })

        if (($null -eq $endpoints) -or ($endpoints.Length -eq 0)) {
            continue
        }

        #add security header method if autoMethods is enabled
        if (  $PodeContext.Server.Security.autoMethods ) {
            Add-PodeSecurityHeader -Name 'Access-Control-Allow-Methods' -Value $_method.ToUpper() -Append
        }

        $DefinitionTag = Test-PodeOADefinitionTag -Tag $OADefinitionTag

        #add the default OpenApi responses
        if ( $PodeContext.Server.OpenAPI.Definitions[$DefinitionTag].hiddenComponents.defaultResponses) {
            $DefaultResponse = [ordered]@{}
            foreach ($tag in $DefinitionTag) {
                $DefaultResponse[$tag] = Copy-PodeObjectDeepClone -InputObject $PodeContext.Server.OpenAPI.Definitions[$tag].hiddenComponents.defaultResponses
            }
        }

        # add the route(s)
        Write-Verbose "Adding Route: [$($_method)] $($Path)"
        $methodRoutes = @(foreach ($_endpoint in $endpoints) {
                @{
                    Logic            = $ScriptBlock
                    UsingVariables   = $usingVars
                    Middleware       = $Middleware
                    Authentication   = $Authentication
                    Access           = $Access
                    AccessMeta       = @{
                        Role   = $Role
                        Group  = $Group
                        Scope  = $Scope
                        User   = $User
                        Custom = $CustomAccess
                    }
                    Endpoint         = @{
                        Protocol = $_endpoint.Protocol
                        Address  = $_endpoint.Address.Trim()
                        Name     = $_endpoint.Name
                    }
                    ContentType      = $ContentType
                    TransferEncoding = $TransferEncoding
                    ErrorType        = $ErrorContentType
                    Arguments        = $ArgumentList
                    Method           = $_method
                    Path             = $Path
                    OpenApi          = @{
                        Path               = $OpenApiPath
                        Responses          = $DefaultResponse
                        Parameters         = [ordered]@{}
                        RequestBody        = [ordered]@{}
                        CallBacks          = [ordered]@{}
                        Authentication     = @()
                        Servers            = @()
                        DefinitionTag      = $DefinitionTag
                        IsDefTagConfigured = ($null -ne $OADefinitionTag) #Definition Tag has been configured (Not default)
                    }
                    IsStatic         = $false
                    Metrics          = @{
                        Requests = @{
                            Total       = 0
                            StatusCodes = @{}
                        }
                    }
                }
            })


        if ($PodeContext.Server.OpenAPI.Routes -notcontains $Path ) {
            $PodeContext.Server.OpenAPI.Routes += $Path
        }


        if (![string]::IsNullOrWhiteSpace($Authentication)) {
            Set-PodeOAAuth -Route $methodRoutes -Name $Authentication -AllowAnon:$AllowAnon
        }

        $PodeContext.Server.Routes[$_method][$Path] += @($methodRoutes)
        if ($PassThru) {
            $newRoutes += $methodRoutes
        }
    }
    if ($OAReference) {
        Test-PodeOAComponentInternal -Field pathItems -DefinitionTag $DefinitionTag -Name $OAReference -PostValidation
        foreach ($r in @($newRoutes)) {
            $r.OpenApi = @{
                '$ref'        = "#/components/paths/$OAReference"
                DefinitionTag = $DefinitionTag
                Path          = $OpenApiPath
            }
        }
    }
    elseif ($OAResponses) {
        foreach ($r in @($newRoutes)) {
            $r.OpenApi.Responses = $OAResponses
        }
    }

    # return the routes?
    if ($PassThru) {
        return $newRoutes
    }
}


<#
.SYNOPSIS
    Add a Route Group for multiple Routes.

.DESCRIPTION
    Add a Route Group for sharing values between multiple Routes.

.PARAMETER Path
    The URI path to use as a base for the Routes, that should be prepended.

.PARAMETER Routes
    A ScriptBlock for adding Routes.

.PARAMETER Middleware
    An array of ScriptBlocks for optional Middleware to give each Route.

.PARAMETER EndpointName
    The EndpointName of an Endpoint(s) to use for the Routes.

.PARAMETER ContentType
    The content type to use for the Routes, when parsing any payloads.

.PARAMETER TransferEncoding
    The transfer encoding to use for the Routes, when parsing any payloads.

.PARAMETER ErrorContentType
    The content type of any error pages that may get returned.

.PARAMETER Authentication
    The name of an Authentication method which should be used as middleware on the Routes.

.PARAMETER Access
    The name of an Access method which should be used as middleware on this Route.

.PARAMETER IfExists
    Specifies what action to take when a Route already exists. (Default: Default)

.PARAMETER Role
    One or more optional Roles that will be authorised to access this Route, when using Authentication with an Access method.

.PARAMETER Group
    One or more optional Groups that will be authorised to access this Route, when using Authentication with an Access method.

.PARAMETER Scope
    One or more optional Scopes that will be authorised to access this Route, when using Authentication with an Access method.

.PARAMETER User
    One or more optional Users that will be authorised to access this Route, when using Authentication with an Access method.

.PARAMETER AllowAnon
    If supplied, the Routes will allow anonymous access for non-authenticated users.

.PARAMETER OADefinitionTag
    An Array of strings representing the unique tag for the API specification.
    This tag helps in distinguishing between different versions or types of API specifications within the application.
    You can use this tag to reference the specific API documentation, schema, or version that your function interacts with.

.EXAMPLE
    Add-PodeRouteGroup -Path '/api' -Routes { Add-PodeRoute -Path '/route1' -Etc }
#>
function Add-PodeRouteGroup {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Path,

        [Parameter(Mandatory = $true)]
        [scriptblock]
        $Routes,

        [Parameter()]
        [object[]]
        $Middleware,

        [Parameter()]
        [string[]]
        $EndpointName,

        [Parameter()]
        [string]
        $ContentType,

        [Parameter()]
        [ValidateSet('', 'gzip', 'deflate')]
        [string]
        $TransferEncoding,

        [Parameter()]
        [string]
        $ErrorContentType,

        [Parameter()]
        [Alias('Auth')]
        [string]
        $Authentication,

        [Parameter()]
        [string]
        $Access,

        [Parameter()]
        [ValidateSet('Default', 'Error', 'Overwrite', 'Skip')]
        [string]
        $IfExists = 'Default',

        [Parameter()]
        [string[]]
        $Role,

        [Parameter()]
        [string[]]
        $Group,

        [Parameter()]
        [string[]]
        $Scope,

        [Parameter()]
        [string[]]
        $User,

        [switch]
        $AllowAnon,

        [string[]]
        $OADefinitionTag
    )

    if (Test-PodeIsEmpty $Routes) {
        # The Route parameter needs a valid, not empty, scriptblock
        throw ($PodeLocale.routeParameterNeedsValidScriptblockExceptionMessage)
    }

    if ($Path -eq '/') {
        $Path = $null
    }

    # check for scoped vars
    $Routes, $usingVars = Convert-PodeScopedVariables -ScriptBlock $Routes -PSSession $PSCmdlet.SessionState

    # group details
    if ($null -ne $RouteGroup) {
        if (![string]::IsNullOrWhiteSpace($RouteGroup.Path)) {
            $Path = "$($RouteGroup.Path)$($Path)"
        }

        if ($null -ne $RouteGroup.Middleware) {
            $Middleware = $RouteGroup.Middleware + $Middleware
        }

        if ([string]::IsNullOrWhiteSpace($EndpointName)) {
            $EndpointName = $RouteGroup.EndpointName
        }

        if ([string]::IsNullOrWhiteSpace($ContentType)) {
            $ContentType = $RouteGroup.ContentType
        }

        if ([string]::IsNullOrWhiteSpace($TransferEncoding)) {
            $TransferEncoding = $RouteGroup.TransferEncoding
        }

        if ([string]::IsNullOrWhiteSpace($ErrorContentType)) {
            $ErrorContentType = $RouteGroup.ErrorContentType
        }

        if ([string]::IsNullOrWhiteSpace($Authentication)) {
            $Authentication = $RouteGroup.Authentication
        }

        if ([string]::IsNullOrWhiteSpace($Access)) {
            $Access = $RouteGroup.Access
        }

        if ($RouteGroup.AllowAnon) {
            $AllowAnon = $RouteGroup.AllowAnon
        }

        if ($RouteGroup.IfExists -ine 'default') {
            $IfExists = $RouteGroup.IfExists
        }

        if ($null -ne $RouteGroup.AccessMeta.Role) {
            $Role = $RouteGroup.AccessMeta.Role + $Role
        }

        if ($null -ne $RouteGroup.AccessMeta.Group) {
            $Group = $RouteGroup.AccessMeta.Group + $Group
        }

        if ($null -ne $RouteGroup.AccessMeta.Scope) {
            $Scope = $RouteGroup.AccessMeta.Scope + $Scope
        }

        if ($null -ne $RouteGroup.AccessMeta.User) {
            $User = $RouteGroup.AccessMeta.User + $User
        }

        if ($null -ne $RouteGroup.AccessMeta.Custom) {
            $CustomAccess = $RouteGroup.AccessMeta.Custom
        }

        if ($null -ne $RouteGroup.OADefinitionTag ) {
            $OADefinitionTag = $RouteGroup.OADefinitionTag
        }

    }

    $RouteGroup = @{
        Path             = $Path
        Middleware       = $Middleware
        EndpointName     = $EndpointName
        ContentType      = $ContentType
        TransferEncoding = $TransferEncoding
        ErrorContentType = $ErrorContentType
        Authentication   = $Authentication
        Access           = $Access
        AllowAnon        = $AllowAnon
        IfExists         = $IfExists
        OADefinitionTag  = $OADefinitionTag
        AccessMeta       = @{
            Role   = $Role
            Group  = $Group
            Scope  = $Scope
            User   = $User
            Custom = $CustomAccess
        }
    }

    # add routes
    $null = Invoke-PodeScriptBlock -ScriptBlock $Routes -UsingVariables $usingVars -Splat -NoNewClosure
}


<#
.SYNOPSIS
    Adds a Signal Route for WebSockets.

.DESCRIPTION
    Adds a Signal Route, with path, that when called with invoke any logic.

.PARAMETER Path
    The URI path for the Signal Route.

.PARAMETER ScriptBlock
    A ScriptBlock for the Signal Route's main logic.

.PARAMETER EndpointName
    The EndpointName of an Endpoint(s) this Signal Route should be bound against.

.PARAMETER FilePath
    A literal, or relative, path to a file containing a ScriptBlock for the Signal Route's main logic.

.PARAMETER ArgumentList
    An array of arguments to supply to the Signal Route's ScriptBlock.

.PARAMETER IfExists
    Specifies what action to take when a Signal Route already exists. (Default: Default)

.EXAMPLE
    Add-PodeSignalRoute -Path '/message' -ScriptBlock { /* logic */ }

.EXAMPLE
    Add-PodeSignalRoute -Path '/message' -ScriptBlock { /* logic */ } -ArgumentList 'arg1', 'arg2'
#>
function Add-PodeSignalRoute {
    [CmdletBinding(DefaultParameterSetName = 'Script')]
    [OutputType([System.Object[]])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Path,

        [Parameter(ParameterSetName = 'Script')]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [string[]]
        $EndpointName,

        [Parameter(Mandatory = $true, ParameterSetName = 'File')]
        [string]
        $FilePath,

        [Parameter()]
        [object[]]
        $ArgumentList,

        [Parameter()]
        [ValidateSet('Default', 'Error', 'Overwrite', 'Skip')]
        [string]
        $IfExists = 'Default'
    )

    # check if we have any route group info defined
    if ($null -ne $RouteGroup) {
        if (![string]::IsNullOrWhiteSpace($RouteGroup.Path)) {
            $Path = "$($RouteGroup.Path)$($Path)"
        }

        if ([string]::IsNullOrWhiteSpace($EndpointName)) {
            $EndpointName = $RouteGroup.EndpointName
        }

        if ($RouteGroup.IfExists -ine 'default') {
            $IfExists = $RouteGroup.IfExists
        }
    }

    $Method = 'Signal'

    # store the original path
    $origPath = $Path

    # ensure the route has appropriate slashes
    $Path = Update-PodeRouteSlash -Path $Path

    # get endpoints from name
    $endpoints = Find-PodeEndpoint -EndpointName $EndpointName

    # get default route IfExists state
    if ($IfExists -ieq 'Default') {
        $IfExists = Get-PodeRouteIfExistsPreference
    }

    # ensure the route doesn't already exist for each endpoint
    $endpoints = @(foreach ($_endpoint in $endpoints) {
            $found = Test-PodeRouteInternal -Method $Method -Path $Path -Protocol $_endpoint.Protocol -Address $_endpoint.Address -ThrowError:($IfExists -ieq 'Error')

            if ($found) {
                if ($IfExists -ieq 'Overwrite') {
                    Remove-PodeSignalRoute -Path $origPath -EndpointName $_endpoint.Name
                }

                if ($IfExists -ieq 'Skip') {
                    continue
                }
            }

            $_endpoint
        })

    if (($null -eq $endpoints) -or ($endpoints.Length -eq 0)) {
        return
    }

    # if scriptblock and file path are all null/empty, error
    if ((Test-PodeIsEmpty $ScriptBlock) -and (Test-PodeIsEmpty $FilePath)) {
        # [Method] Path: No logic passed
        throw ($PodeLocale.noLogicPassedForMethodRouteExceptionMessage -f $Method, $Path)
    }

    # if we have a file path supplied, load that path as a scriptblock
    if ($PSCmdlet.ParameterSetName -ieq 'file') {
        $ScriptBlock = Convert-PodeFileToScriptBlock -FilePath $FilePath
    }

    # check for scoped vars
    $ScriptBlock, $usingVars = Convert-PodeScopedVariables -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState

    # add the route(s)
    Write-Verbose "Adding Route: [$($Method)] $($Path)"
    $newRoutes = @(foreach ($_endpoint in $endpoints) {
            @{
                Logic          = $ScriptBlock
                UsingVariables = $usingVars
                Endpoint       = @{
                    Protocol = $_endpoint.Protocol
                    Address  = $_endpoint.Address.Trim()
                    Name     = $_endpoint.Name
                }
                Arguments      = $ArgumentList
                Method         = $Method
                Path           = $Path
                IsStatic       = $false
                Metrics        = @{
                    Requests = @{
                        Total = 0
                    }
                }
            }
        })

    $PodeContext.Server.Routes[$Method][$Path] += @($newRoutes)
}


<#
.SYNOPSIS
    Adds a Signal Route Group for multiple WebSockets.

.DESCRIPTION
    Adds a Signal Route Group for sharing values between multiple WebSockets.

.PARAMETER Path
    The URI path to use as a base for the Signal Routes, that should be prepended.

.PARAMETER Routes
    A ScriptBlock for adding Signal Routes.

.PARAMETER EndpointName
    The EndpointName of an Endpoint(s) to use for the Signal Routes.

.PARAMETER IfExists
    Specifies what action to take when a Signal Route already exists. (Default: Default)

.EXAMPLE
    Add-PodeSignalRouteGroup -Path '/signals' -Routes { Add-PodeSignalRoute -Path '/signal1' -Etc }
#>
function Add-PodeSignalRouteGroup {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Path,

        [Parameter(Mandatory = $true)]
        [scriptblock]
        $Routes,

        [Parameter()]
        [string[]]
        $EndpointName,

        [Parameter()]
        [ValidateSet('Default', 'Error', 'Overwrite', 'Skip')]
        [string]
        $IfExists = 'Default'
    )

    if (Test-PodeIsEmpty $Routes) {
        # The Route parameter needs a valid, not empty, scriptblock
        throw ($PodeLocale.routeParameterNeedsValidScriptblockExceptionMessage)
    }

    if ($Path -eq '/') {
        $Path = $null
    }

    # check for scoped vars
    $Routes, $usingVars = Convert-PodeScopedVariables -ScriptBlock $Routes -PSSession $PSCmdlet.SessionState

    # group details
    if ($null -ne $RouteGroup) {
        if (![string]::IsNullOrWhiteSpace($RouteGroup.Path)) {
            $Path = "$($RouteGroup.Path)$($Path)"
        }

        if ([string]::IsNullOrWhiteSpace($EndpointName)) {
            $EndpointName = $RouteGroup.EndpointName
        }

        if ($RouteGroup.IfExists -ine 'default') {
            $IfExists = $RouteGroup.IfExists
        }
    }

    $RouteGroup = @{
        Path         = $Path
        EndpointName = $EndpointName
        IfExists     = $IfExists
    }

    # add routes
    $null = Invoke-PodeScriptBlock -ScriptBlock $Routes -UsingVariables $usingVars -Splat -NoNewClosure
}


<#
.SYNOPSIS
    Add a static Route for rendering static content.

.DESCRIPTION
    Add a static Route for rendering static content. You can also define default pages to display.

.PARAMETER Path
    The URI path for the static Route.

.PARAMETER Source
    The literal, or relative, path to the directory that contains the static content.

.PARAMETER Middleware
    An array of ScriptBlocks for optional Middleware.

.PARAMETER EndpointName
    The EndpointName of an Endpoint(s) to bind the static Route against.

.PARAMETER ContentType
    The content type the static Route should use when parsing any payloads.

.PARAMETER TransferEncoding
    The transfer encoding the static Route should use when parsing any payloads.

.PARAMETER Defaults
    An array of default pages to display, such as 'index.html'.

.PARAMETER ErrorContentType
    The content type of any error pages that may get returned.

.PARAMETER Authentication
    The name of an Authentication method which should be used as middleware on this Route.

.PARAMETER Access
    The name of an Access method which should be used as middleware on this Route.

.PARAMETER AllowAnon
    If supplied, the static route will allow anonymous access for non-authenticated users.

.PARAMETER DownloadOnly
    When supplied, all static content on this Route will be attached as downloads - rather than rendered.

.PARAMETER PassThru
    If supplied, the static route created will be returned so it can be passed through a pipe.

.PARAMETER IfExists
    Specifies what action to take when a Static Route already exists. (Default: Default)

.PARAMETER Role
    One or more optional Roles that will be authorised to access this Route, when using Authentication with an Access method.

.PARAMETER Group
    One or more optional Groups that will be authorised to access this Route, when using Authentication with an Access method.

.PARAMETER Scope
    One or more optional Scopes that will be authorised to access this Route, when using Authentication with an Access method.

.PARAMETER User
    One or more optional Users that will be authorised to access this Route, when using Authentication with an Access method.

.PARAMETER FileBrowser
    If supplied, when the path is a folder, instead of returning 404, will return A browsable content of the directory.

.PARAMETER RedirectToDefault
    If supplied, the user will be redirected to the default page if found instead of the page being rendered as the folder path.

.EXAMPLE
    Add-PodeStaticRoute -Path '/assets' -Source './assets'

.EXAMPLE
    Add-PodeStaticRoute -Path '/assets' -Source './assets' -Defaults @('index.html')

.EXAMPLE
    Add-PodeStaticRoute -Path '/installers' -Source './exes' -DownloadOnly

.EXAMPLE
    Add-PodeStaticRoute -Path '/assets' -Source './assets' -Defaults @('index.html') -RedirectToDefault
#>
function Add-PodeStaticRoute {
    [CmdletBinding()]
    [OutputType([System.Object[]])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Path,

        [Parameter(Mandatory = $true)]
        [string]
        $Source,

        [Parameter()]
        [object[]]
        $Middleware,

        [Parameter()]
        [string[]]
        $EndpointName,

        [Parameter()]
        [string]
        $ContentType,

        [Parameter()]
        [ValidateSet('', 'gzip', 'deflate')]
        [string]
        $TransferEncoding,

        [Parameter()]
        [string[]]
        $Defaults,

        [Parameter()]
        [string]
        $ErrorContentType,

        [Parameter()]
        [Alias('Auth')]
        [string]
        $Authentication,

        [Parameter()]
        [string]
        $Access,

        [Parameter()]
        [ValidateSet('Default', 'Error', 'Overwrite', 'Skip')]
        [string]
        $IfExists = 'Default',

        [Parameter()]
        [string[]]
        $Role,

        [Parameter()]
        [string[]]
        $Group,

        [Parameter()]
        [string[]]
        $Scope,

        [Parameter()]
        [string[]]
        $User,

        [switch]
        $AllowAnon,

        [switch]
        $DownloadOnly,

        [switch]
        $FileBrowser,

        [switch]
        $PassThru,

        [switch]
        $RedirectToDefault
    )

    # check if we have any route group info defined
    if ($null -ne $RouteGroup) {
        if (![string]::IsNullOrWhiteSpace($RouteGroup.Path)) {
            $Path = "$($RouteGroup.Path)$($Path)"
        }

        if (![string]::IsNullOrWhiteSpace($RouteGroup.Source)) {
            $Source = [System.IO.Path]::Combine($Source, $RouteGroup.Source.TrimStart('\/'))
        }

        if ($null -ne $RouteGroup.Middleware) {
            $Middleware = $RouteGroup.Middleware + $Middleware
        }

        if ([string]::IsNullOrWhiteSpace($EndpointName)) {
            $EndpointName = $RouteGroup.EndpointName
        }

        if ([string]::IsNullOrWhiteSpace($ContentType)) {
            $ContentType = $RouteGroup.ContentType
        }

        if ([string]::IsNullOrWhiteSpace($TransferEncoding)) {
            $TransferEncoding = $RouteGroup.TransferEncoding
        }

        if ([string]::IsNullOrWhiteSpace($ErrorContentType)) {
            $ErrorContentType = $RouteGroup.ErrorContentType
        }

        if ([string]::IsNullOrWhiteSpace($Authentication)) {
            $Authentication = $RouteGroup.Authentication
        }

        if ([string]::IsNullOrWhiteSpace($Access)) {
            $Access = $RouteGroup.Access
        }

        if (Test-PodeIsEmpty $Defaults) {
            $Defaults = $RouteGroup.Defaults
        }

        if ($RouteGroup.AllowAnon) {
            $AllowAnon = $RouteGroup.AllowAnon
        }

        if ($RouteGroup.DownloadOnly) {
            $DownloadOnly = $RouteGroup.DownloadOnly
        }

        if ($RouteGroup.FileBrowser) {
            $FileBrowser = $RouteGroup.FileBrowser
        }

        if ($RouteGroup.RedirectToDefault) {
            $RedirectToDefault = $RouteGroup.RedirectToDefault
        }

        if ($RouteGroup.IfExists -ine 'default') {
            $IfExists = $RouteGroup.IfExists
        }

        if ($null -ne $RouteGroup.AccessMeta.Role) {
            $Role = $RouteGroup.AccessMeta.Role + $Role
        }

        if ($null -ne $RouteGroup.AccessMeta.Group) {
            $Group = $RouteGroup.AccessMeta.Group + $Group
        }

        if ($null -ne $RouteGroup.AccessMeta.Scope) {
            $Scope = $RouteGroup.AccessMeta.Scope + $Scope
        }

        if ($null -ne $RouteGroup.AccessMeta.User) {
            $User = $RouteGroup.AccessMeta.User + $User
        }

        if ($null -ne $RouteGroup.AccessMeta.Custom) {
            $CustomAccess = $RouteGroup.AccessMeta.Custom
        }
    }

    # store the route method
    $Method = 'Static'

    # store the original path
    $origPath = $Path

    # split route on '?' for query
    $Path = Split-PodeRouteQuery -Path $Path
    if ([string]::IsNullOrWhiteSpace($Path)) {
        # No Path supplied for the Route.
        throw ($PodeLocale.noPathSuppliedForRouteExceptionMessage)
    }

    # ensure the route has appropriate slashes
    $Path = Update-PodeRouteSlash -Path $Path -Static
    $OpenApiPath = ConvertTo-PodeOARoutePath -Path $Path
    $Path = Resolve-PodePlaceholder -Path $Path

    # get endpoints from name
    $endpoints = Find-PodeEndpoint -EndpointName $EndpointName

    # get default route IfExists state
    if ($IfExists -ieq 'Default') {
        $IfExists = Get-PodeRouteIfExistsPreference
    }

    # ensure the route doesn't already exist for each endpoint
    $endpoints = @(foreach ($_endpoint in $endpoints) {
            $found = Test-PodeRouteInternal -Method $Method -Path $Path -Protocol $_endpoint.Protocol -Address $_endpoint.Address -ThrowError:($IfExists -ieq 'Error')

            if ($found) {
                if ($IfExists -ieq 'Overwrite') {
                    Remove-PodeStaticRoute -Path $origPath -EndpointName $_endpoint.Name
                }

                if ($IfExists -ieq 'Skip') {
                    continue
                }
            }

            $_endpoint
        })

    if (($null -eq $endpoints) -or ($endpoints.Length -eq 0)) {
        return
    }

    # if static, ensure the path exists at server root
    $Source = Get-PodeRelativePath -Path $Source -JoinRoot
    if (!(Test-PodePath -Path $Source -NoStatus)) {
        # [Method)] Path: The Source path supplied for Static Route does not exist
        throw ($PodeLocale.sourcePathDoesNotExistForStaticRouteExceptionMessage -f $Path, $Source)
    }

    # setup a temp drive for the path
    $Source = New-PodePSDrive -Path $Source

    # setup default static files
    if ($null -eq $Defaults) {
        $Defaults = Get-PodeStaticRouteDefault
    }

    if (!$RedirectToDefault) {
        $RedirectToDefault = $PodeContext.Server.Web.Static.RedirectToDefault
    }

    # convert any middleware into valid hashtables
    $Middleware = @(ConvertTo-PodeMiddleware -Middleware $Middleware -PSSession $PSCmdlet.SessionState)

    # if an access name was supplied, setup access as middleware first to it's after auth middleware
    if (![string]::IsNullOrWhiteSpace($Access)) {
        if ([string]::IsNullOrWhiteSpace($Authentication)) {
            # Access requires Authentication to be supplied on Routes
            throw ($PodeLocale.accessRequiresAuthenticationOnRoutesExceptionMessage)
        }

        if (!(Test-PodeAccessExists -Name $Access)) {
            # Access method does not exist
            throw ($PodeLocale.accessMethodDoesNotExistExceptionMessage -f $Access)
        }

        $options = @{
            Name = $Access
        }

        $Middleware = (@(Get-PodeAccessMiddlewareScript | New-PodeMiddleware -ArgumentList $options) + $Middleware)
    }

    # if an auth name was supplied, setup the auth as the first middleware
    if (![string]::IsNullOrWhiteSpace($Authentication)) {
        if (!(Test-PodeAuthExists -Name $Authentication)) {
            # Authentication method does not exist
            throw ($PodeLocale.authenticationMethodDoesNotExistExceptionMessage)
        }

        $options = @{
            Name = $Authentication
            Anon = $AllowAnon
        }

        $Middleware = (@(Get-PodeAuthMiddlewareScript | New-PodeMiddleware -ArgumentList $options) + $Middleware)
    }

    # workout a default content type for the route
    $ContentType = Find-PodeRouteContentType -Path $Path -ContentType $ContentType

    # workout a default transfer encoding for the route
    $TransferEncoding = Find-PodeRouteTransferEncoding -Path $Path -TransferEncoding $TransferEncoding

    #The path use KleeneStar(Asterisk)
    $KleeneStar = $OrigPath.Contains('*')

    # add the route(s)
    Write-Verbose "Adding Route: [$($Method)] $($Path)"
    $newRoutes = @(foreach ($_endpoint in $endpoints) {
            @{
                Source            = $Source
                Path              = $Path
                KleeneStar        = $KleeneStar
                Method            = $Method
                Defaults          = $Defaults
                RedirectToDefault = $RedirectToDefault
                Middleware        = $Middleware
                Authentication    = $Authentication
                Access            = $Access
                AccessMeta        = @{
                    Role   = $Role
                    Group  = $Group
                    Scope  = $Scope
                    User   = $User
                    Custom = $CustomAccess
                }
                Endpoint          = @{
                    Protocol = $_endpoint.Protocol
                    Address  = $_endpoint.Address.Trim()
                    Name     = $_endpoint.Name
                }
                ContentType       = $ContentType
                TransferEncoding  = $TransferEncoding
                ErrorType         = $ErrorContentType
                Download          = $DownloadOnly
                IsStatic          = $true
                FileBrowser       = $FileBrowser.isPresent
                OpenApi           = @{
                    Path           = $OpenApiPath
                    Responses      = @{}
                    Parameters     = $null
                    RequestBody    = $null
                    CallBacks      = @{}
                    Authentication = @()
                    Servers        = @()
                    DefinitionTag  = $DefinitionTag
                }
                Metrics           = @{
                    Requests = @{
                        Total       = 0
                        StatusCodes = @{}
                    }
                }
            }
        })

    $PodeContext.Server.Routes[$Method][$Path] += @($newRoutes)

    # return the routes?
    if ($PassThru) {
        return $newRoutes
    }
}


<#
.SYNOPSIS
    Add a Static Route Group for multiple Static Routes.

.DESCRIPTION
    Add a Static Route Group for sharing values between multiple Static Routes.

.PARAMETER Path
    The URI path to use as a base for the Static Routes.

.PARAMETER Source
    A literal, or relative, base path to the directory that contains the static content, that should be prepended.

.PARAMETER Routes
    A ScriptBlock for adding Static Routes.

.PARAMETER Middleware
    An array of ScriptBlocks for optional Middleware to give each Static Route.

.PARAMETER EndpointName
    The EndpointName of an Endpoint(s) to use for the Static Routes.

.PARAMETER ContentType
    The content type to use for the Static Routes, when parsing any payloads.

.PARAMETER TransferEncoding
    The transfer encoding to use for the Static Routes, when parsing any payloads.

.PARAMETER Defaults
    An array of default pages to display, such as 'index.html', for each Static Route.

.PARAMETER ErrorContentType
    The content type of any error pages that may get returned.

.PARAMETER Authentication
    The name of an Authentication method which should be used as middleware on the Static Routes.

.PARAMETER Access
    The name of an Access method which should be used as middleware on this Route.

.PARAMETER IfExists
    Specifies what action to take when a Static Route already exists. (Default: Default)

.PARAMETER AllowAnon
    If supplied, the Static Routes will allow anonymous access for non-authenticated users.

.PARAMETER FileBrowser
    When supplied, If the path is a folder, instead of returning 404, will return A browsable content of the directory.

.PARAMETER DownloadOnly
    When supplied, all static content on the Routes will be attached as downloads - rather than rendered.

.PARAMETER Role
    One or more optional Roles that will be authorised to access this Route, when using Authentication with an Access method.

.PARAMETER Group
    One or more optional Groups that will be authorised to access this Route, when using Authentication with an Access method.

.PARAMETER Scope
    One or more optional Scopes that will be authorised to access this Route, when using Authentication with an Access method.

.PARAMETER User
    One or more optional Users that will be authorised to access this Route, when using Authentication with an Access method.

.PARAMETER RedirectToDefault
    If supplied, the user will be redirected to the default page if found instead of the page being rendered as the folder path.

.EXAMPLE
    Add-PodeStaticRouteGroup -Path '/static' -Routes { Add-PodeStaticRoute -Path '/images' -Etc }
#>
function Add-PodeStaticRouteGroup {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Path,

        [Parameter()]
        [string]
        $Source,

        [Parameter(Mandatory = $true)]
        [scriptblock]
        $Routes,

        [Parameter()]
        [object[]]
        $Middleware,

        [Parameter()]
        [string[]]
        $EndpointName,

        [Parameter()]
        [string]
        $ContentType,

        [Parameter()]
        [ValidateSet('', 'gzip', 'deflate')]
        [string]
        $TransferEncoding,

        [Parameter()]
        [string[]]
        $Defaults,

        [Parameter()]
        [string]
        $ErrorContentType,

        [Parameter()]
        [Alias('Auth')]
        [string]
        $Authentication,

        [Parameter()]
        [string]
        $Access,

        [Parameter()]
        [ValidateSet('Default', 'Error', 'Overwrite', 'Skip')]
        [string]
        $IfExists = 'Default',

        [Parameter()]
        [string[]]
        $Role,

        [Parameter()]
        [string[]]
        $Group,

        [Parameter()]
        [string[]]
        $Scope,

        [Parameter()]
        [string[]]
        $User,

        [switch]
        $AllowAnon,

        [switch]
        $FileBrowser,

        [switch]
        $DownloadOnly,

        [switch]
        $RedirectToDefault
    )

    if (Test-PodeIsEmpty $Routes) {
        # The Route parameter needs a valid, not empty, scriptblock
        throw ($PodeLocale.routeParameterNeedsValidScriptblockExceptionMessage)
    }

    if ($Path -eq '/') {
        $Path = $null
    }

    # check for scoped vars
    $Routes, $usingVars = Convert-PodeScopedVariables -ScriptBlock $Routes -PSSession $PSCmdlet.SessionState

    # group details
    if ($null -ne $RouteGroup) {
        if (![string]::IsNullOrWhiteSpace($RouteGroup.Path)) {
            $Path = "$($RouteGroup.Path)$($Path)"
        }

        if (![string]::IsNullOrWhiteSpace($RouteGroup.Source)) {
            $Source = [System.IO.Path]::Combine($Source, $RouteGroup.Source.TrimStart('\/'))
        }

        if ($null -ne $RouteGroup.Middleware) {
            $Middleware = $RouteGroup.Middleware + $Middleware
        }

        if ([string]::IsNullOrWhiteSpace($EndpointName)) {
            $EndpointName = $RouteGroup.EndpointName
        }

        if ([string]::IsNullOrWhiteSpace($ContentType)) {
            $ContentType = $RouteGroup.ContentType
        }

        if ([string]::IsNullOrWhiteSpace($TransferEncoding)) {
            $TransferEncoding = $RouteGroup.TransferEncoding
        }

        if ([string]::IsNullOrWhiteSpace($ErrorContentType)) {
            $ErrorContentType = $RouteGroup.ErrorContentType
        }

        if ([string]::IsNullOrWhiteSpace($Authentication)) {
            $Authentication = $RouteGroup.Authentication
        }

        if ([string]::IsNullOrWhiteSpace($Access)) {
            $Access = $RouteGroup.Access
        }

        if (Test-PodeIsEmpty $Defaults) {
            $Defaults = $RouteGroup.Defaults
        }

        if ($RouteGroup.AllowAnon) {
            $AllowAnon = $RouteGroup.AllowAnon
        }

        if ($RouteGroup.DownloadOnly) {
            $DownloadOnly = $RouteGroup.DownloadOnly
        }

        if ($RouteGroup.FileBrowser) {
            $FileBrowser = $RouteGroup.FileBrowser
        }

        if ($RouteGroup.RedirectToDefault) {
            $RedirectToDefault = $RouteGroup.RedirectToDefault
        }

        if ($RouteGroup.IfExists -ine 'default') {
            $IfExists = $RouteGroup.IfExists
        }

        if ($null -ne $RouteGroup.AccessMeta.Role) {
            $Role = $RouteGroup.AccessMeta.Role + $Role
        }

        if ($null -ne $RouteGroup.AccessMeta.Group) {
            $Group = $RouteGroup.AccessMeta.Group + $Group
        }

        if ($null -ne $RouteGroup.AccessMeta.Scope) {
            $Scope = $RouteGroup.AccessMeta.Scope + $Scope
        }

        if ($null -ne $RouteGroup.AccessMeta.User) {
            $User = $RouteGroup.AccessMeta.User + $User
        }

        if ($null -ne $RouteGroup.AccessMeta.Custom) {
            $CustomAccess = $RouteGroup.AccessMeta.Custom
        }
    }

    $RouteGroup = @{
        Path              = $Path
        Source            = $Source
        Middleware        = $Middleware
        EndpointName      = $EndpointName
        ContentType       = $ContentType
        TransferEncoding  = $TransferEncoding
        Defaults          = $Defaults
        RedirectToDefault = $RedirectToDefault
        ErrorContentType  = $ErrorContentType
        Authentication    = $Authentication
        Access            = $Access
        AllowAnon         = $AllowAnon
        DownloadOnly      = $DownloadOnly
        FileBrowser       = $FileBrowser
        IfExists          = $IfExists
        AccessMeta        = @{
            Role   = $Role
            Group  = $Group
            Scope  = $Scope
            User   = $User
            Custom = $CustomAccess
        }
    }

    # add routes
    $null = Invoke-PodeScriptBlock -ScriptBlock $Routes -UsingVariables $usingVars -Splat -NoNewClosure
}


<#
.SYNOPSIS
    Removes all added Routes, or Routes for a specific Method.

.DESCRIPTION
    Removes all added Routes, or Routes for a specific Method.

.PARAMETER Method
    The Method to from which to remove all Routes.

.EXAMPLE
    Clear-PodeRoutes

.EXAMPLE
    Clear-PodeRoutes -Method Get
#>
function Clear-PodeRoutes {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateSet('', 'Connect', 'Delete', 'Get', 'Head', 'Merge', 'Options', 'Patch', 'Post', 'Put', 'Trace', '*')]
        [string]
        $Method
    )

    if (![string]::IsNullOrWhiteSpace($Method)) {
        $PodeContext.Server.Routes[$Method].Clear()
    }
    else {
        $PodeContext.Server.Routes.Keys.Clone() | ForEach-Object {
            $PodeContext.Server.Routes[$_].Clear()
        }
    }
}


<#
.SYNOPSIS
    Removes all added Signal Routes.

.DESCRIPTION
    Removes all added Signal Routes.

.EXAMPLE
    Clear-PodeSignalRoutes
#>
function Clear-PodeSignalRoutes {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    [CmdletBinding()]
    param()

    $PodeContext.Server.Routes['Signal'].Clear()
}


<#
.SYNOPSIS
    Removes all added static Routes.

.DESCRIPTION
    Removes all added static Routes.

.EXAMPLE
    Clear-PodeStaticRoutes
#>
function Clear-PodeStaticRoutes {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    [CmdletBinding()]
    param()

    $PodeContext.Server.Routes['Static'].Clear()
}


<#
.SYNOPSIS
    Takes an array of Commands, or a Module, and converts them into Routes.

.DESCRIPTION
    Takes an array of Commands (Functions/Aliases), or a Module, and generates appropriate Routes for the commands.

.PARAMETER Commands
    An array of Commands to convert - if a Module is supplied, these Commands must be present within that Module.

.PARAMETER Module
    A Module whose exported commands will be converted.

.PARAMETER Method
    An override HTTP method to use when generating the Routes. If not supplied, Pode will make a best guess based on the Command's Verb.

.PARAMETER Path
    An optional Path for the Route, to prepend before the Command Name and Module.

.PARAMETER Middleware
    Like normal Routes, an array of Middleware that will be applied to all generated Routes.

.PARAMETER Authentication
    The name of an Authentication method which should be used as middleware on this Route.

.PARAMETER Access
    The name of an Access method which should be used as middleware on this Route.

.PARAMETER AllowAnon
    If supplied, the Route will allow anonymous access for non-authenticated users.

.PARAMETER NoVerb
    If supplied, the Command's Verb will not be included in the Route's path.

.PARAMETER NoOpenApi
    If supplied, no OpenAPI definitions will be generated for the routes created.

.PARAMETER Role
    One or more optional Roles that will be authorised to access this Route, when using Authentication with an Access method.

.PARAMETER Group
    One or more optional Groups that will be authorised to access this Route, when using Authentication with an Access method.

.PARAMETER Scope
    One or more optional Scopes that will be authorised to access this Route, when using Authentication with an Access method.

.PARAMETER User
    One or more optional Users that will be authorised to access this Route, when using Authentication with an Access method.

.EXAMPLE
    ConvertTo-PodeRoute -Commands @('Get-ChildItem', 'Get-Host', 'Invoke-Expression') -Middleware { ... }

.EXAMPLE
    ConvertTo-PodeRoute -Commands @('Get-ChildItem', 'Get-Host', 'Invoke-Expression') -Authentication AuthName

.EXAMPLE
    ConvertTo-PodeRoute -Module Pester -Path '/api'

.EXAMPLE
    ConvertTo-PodeRoute -Commands @('Invoke-Pester') -Module Pester
#>
function ConvertTo-PodeRoute {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true, Position = 0 )]
        [string[]]
        $Commands,

        [Parameter()]
        [string]
        $Module,

        [Parameter()]
        [ValidateSet('', 'Connect', 'Delete', 'Get', 'Head', 'Merge', 'Options', 'Patch', 'Post', 'Put', 'Trace')]
        [string]
        $Method,

        [Parameter()]
        [string]
        $Path = '/',

        [Parameter()]
        [object[]]
        $Middleware,

        [Parameter()]
        [Alias('Auth')]
        [string]
        $Authentication,

        [Parameter()]
        [string]
        $Access,

        [Parameter()]
        [string[]]
        $Role,

        [Parameter()]
        [string[]]
        $Group,

        [Parameter()]
        [string[]]
        $Scope,

        [Parameter()]
        [string[]]
        $User,

        [switch]
        $AllowAnon,

        [switch]
        $NoVerb,

        [switch]
        $NoOpenApi
    )
    begin {
        # Initialize an array to hold piped-in values
        $pipelineValue = @()
    }

    process {
        # Add the current piped-in value to the array
        $pipelineValue += $_
    }

    end {
        # Set InputObject to the array of values
        if ($pipelineValue.Count -gt 1) {
            $Commands = $pipelineValue
        }

        # if a module was supplied, import it - then validate the commands
        if (![string]::IsNullOrWhiteSpace($Module)) {
            Import-PodeModule -Name $Module

            Write-Verbose 'Getting exported commands from module'
            $ModuleCommands = (Get-Module -Name $Module | Sort-Object -Descending | Select-Object -First 1).ExportedCommands.Keys

            # if commands were supplied validate them - otherwise use all exported ones
            if (Test-PodeIsEmpty $Commands) {
                Write-Verbose "Using all commands in $($Module) for converting to routes"
                $Commands = $ModuleCommands
            }
            else {
                Write-Verbose "Validating supplied commands against module's exported commands"
                foreach ($cmd in $Commands) {
                    if ($ModuleCommands -inotcontains $cmd) {
                        # Module Module does not contain function cmd to convert to a Route
                        throw ($PodeLocale.moduleDoesNotContainFunctionExceptionMessage -f $Module, $cmd)
                    }
                }
            }
        }

        # if there are no commands, fail
        if (Test-PodeIsEmpty $Commands) {
            # No commands supplied to convert to Routes
            throw ($PodeLocale.noCommandsSuppliedToConvertToRoutesExceptionMessage)
        }

        # trim end trailing slashes from the path
        $Path = Protect-PodeValue -Value $Path -Default '/'
        $Path = $Path.TrimEnd('/')

        # create the routes for each of the commands
        foreach ($cmd in $Commands) {
            # get module verb/noun and comvert verb to HTTP method
            $split = ($cmd -split '\-')

            if ($split.Length -ge 2) {
                $verb = $split[0]
                $noun = $split[1..($split.Length - 1)] -join ([string]::Empty)
            }
            else {
                $verb = [string]::Empty
                $noun = $split[0]
            }

            # determine the http method, or use the one passed
            $_method = $Method
            if ([string]::IsNullOrWhiteSpace($_method)) {
                $_method = Convert-PodeFunctionVerbToHttpMethod -Verb $verb
            }

            # use the full function name, or remove the verb
            $name = $cmd
            if ($NoVerb) {
                $name = $noun
            }

            # build the route's path
            $_path = ("$($Path)/$($Module)/$($name)" -replace '[/]+', '/')

            # create the route
            $params = @{
                Method         = $_method
                Path           = $_path
                Middleware     = $Middleware
                Authentication = $Authentication
                Access         = $Access
                Role           = $Role
                Group          = $Group
                Scope          = $Scope
                User           = $User
                AllowAnon      = $AllowAnon
                ArgumentList   = $cmd
                PassThru       = $true
            }

            $route = Add-PodeRoute @params -ScriptBlock {
                param($cmd)

                # either get params from the QueryString or Payload
                if ($WebEvent.Method -ieq 'get') {
                    $parameters = $WebEvent.Query
                }
                else {
                    $parameters = $WebEvent.Data
                }

                # invoke the function
                $result = (. $cmd @parameters)

                # if we have a result, convert it to json
                if (!(Test-PodeIsEmpty $result)) {
                    Write-PodeJsonResponse -Value $result -Depth 1
                }
            }

            # set the openapi metadata of the function, unless told to skip
            if ($NoOpenApi) {
                continue
            }

            $help = Get-Help -Name $cmd
            $route = ($route | Set-PodeOARouteInfo -Summary $help.Synopsis -Tags $Module -PassThru)

            # set the routes parameters (get = query, everything else = payload)
            $params = (Get-Command -Name $cmd).Parameters
            if (($null -eq $params) -or ($params.Count -eq 0)) {
                continue
            }

            $props = @(foreach ($key in $params.Keys) {
                    $params[$key] | ConvertTo-PodeOAPropertyFromCmdletParameter
                })

            if ($_method -ieq 'get') {
                $route | Set-PodeOARequest -Parameters @(foreach ($prop in $props) { $prop | ConvertTo-PodeOAParameter -In Query })
            }

            else {
                $route | Set-PodeOARequest -RequestBody (
                    New-PodeOARequestBody -ContentSchemas @{ 'application/json' = (New-PodeOAObjectProperty -Array -Properties $props) }
                )
            }
        }
    }
}


<#
.SYNOPSIS
    Get a Route(s).

.DESCRIPTION
    Get a Route(s).

.PARAMETER Method
    A Method to filter the routes.

.PARAMETER Path
    A Path to filter the routes.

.PARAMETER EndpointName
    The name of an endpoint to filter routes.

.EXAMPLE
    Get-PodeRoute -Method Get -Path '/about'

.EXAMPLE
    Get-PodeRoute -Method Post -Path '/users/:userId' -EndpointName User
#>
function Get-PodeRoute {
    [CmdletBinding()]
    [OutputType([System.Object[]])]
    param(
        [Parameter()]
        [ValidateSet('', 'Connect', 'Delete', 'Get', 'Head', 'Merge', 'Options', 'Patch', 'Post', 'Put', 'Trace', '*')]
        [string]
        $Method,

        [Parameter()]
        [string]
        $Path,

        [Parameter()]
        [string[]]
        $EndpointName
    )

    # start off with every route
    $routes = @()
    foreach ($route in $PodeContext.Server.Routes.Values.Values) {
        $routes += $route
    }

    # if we have a method, filter
    if (![string]::IsNullOrWhiteSpace($Method)) {
        $routes = @(foreach ($route in $routes) {
                if ($route.Method -ine $Method) {
                    continue
                }

                $route
            })
    }

    # if we have a path, filter
    if (![string]::IsNullOrWhiteSpace($Path)) {
        $Path = Split-PodeRouteQuery -Path $Path
        $Path = Update-PodeRouteSlash -Path $Path
        $Path = Resolve-PodePlaceholder -Path $Path

        $routes = @(foreach ($route in $routes) {
                if ($route.Path -ine $Path) {
                    continue
                }

                $route
            })
    }

    # further filter by endpoint names
    if (($null -ne $EndpointName) -and ($EndpointName.Length -gt 0)) {
        $routes = @(foreach ($name in $EndpointName) {
                foreach ($route in $routes) {
                    if ($route.Endpoint.Name -ine $name) {
                        continue
                    }

                    $route
                }
            })
    }

    # return
    return $routes
}


<#
.SYNOPSIS
    Get a Signal Route(s).

.DESCRIPTION
    Get a Signal Route(s).

.PARAMETER Path
    A Path to filter the signal routes.

.PARAMETER EndpointName
    The name of an endpoint to filter signal routes.

.EXAMPLE
    Get-PodeSignalRoute -Path '/message'
#>
function Get-PodeSignalRoute {
    [CmdletBinding()]
    [OutputType([System.Object[]])]
    param(
        [Parameter()]
        [string]
        $Path,

        [Parameter()]
        [string[]]
        $EndpointName
    )

    # start off with every route
    $routes = @()
    foreach ($route in $PodeContext.Server.Routes['Signal'].Values) {
        $routes += $route
    }

    # if we have a path, filter
    if (![string]::IsNullOrWhiteSpace($Path)) {
        $Path = Update-PodeRouteSlash -Path $Path
        $routes = @(foreach ($route in $routes) {
                if ($route.Path -ine $Path) {
                    continue
                }

                $route
            })
    }

    # further filter by endpoint names
    if (($null -ne $EndpointName) -and ($EndpointName.Length -gt 0)) {
        $routes = @(foreach ($name in $EndpointName) {
                foreach ($route in $routes) {
                    if ($route.Endpoint.Name -ine $name) {
                        continue
                    }

                    $route
                }
            })
    }

    # return
    return $routes
}


<#
.SYNOPSIS
    Get a static Route(s).

.DESCRIPTION
    Get a static Route(s).

.PARAMETER Path
    A Path to filter the static routes.

.PARAMETER EndpointName
    The name of an endpoint to filter static routes.

.EXAMPLE
    Get-PodeStaticRoute -Path '/assets'

.EXAMPLE
    Get-PodeStaticRoute -Path '/assets' -EndpointName User
#>
function Get-PodeStaticRoute {
    [CmdletBinding()]
    [OutputType([System.Object[]])]
    param(
        [Parameter()]
        [string]
        $Path,

        [Parameter()]
        [string[]]
        $EndpointName
    )

    # start off with every route
    $routes = @()
    foreach ($route in $PodeContext.Server.Routes['Static'].Values) {
        $routes += $route
    }

    # if we have a path, filter
    if (![string]::IsNullOrWhiteSpace($Path)) {
        $Path = Update-PodeRouteSlash -Path $Path -Static
        $routes = @(foreach ($route in $routes) {
                if ($route.Path -ine $Path) {
                    continue
                }

                $route
            })
    }

    # further filter by endpoint names
    if (($null -ne $EndpointName) -and ($EndpointName.Length -gt 0)) {
        $routes = @(foreach ($name in $EndpointName) {
                foreach ($route in $routes) {
                    if ($route.Endpoint.Name -ine $name) {
                        continue
                    }

                    $route
                }
            })
    }

    # return
    return $routes
}


<#
.SYNOPSIS
    Remove a specific Route.

.DESCRIPTION
    Remove a specific Route.

.PARAMETER Method
    The method of the Route to remove.

.PARAMETER Path
    The path of the Route to remove.

.PARAMETER EndpointName
    The EndpointName of an Endpoint(s) bound to the Route to be removed.

.EXAMPLE
    Remove-PodeRoute -Method Get -Route '/about'

.EXAMPLE
    Remove-PodeRoute -Method Post -Route '/users/:userId' -EndpointName User
#>
function Remove-PodeRoute {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Connect', 'Delete', 'Get', 'Head', 'Merge', 'Options', 'Patch', 'Post', 'Put', 'Trace', '*')]
        [string]
        $Method,

        [Parameter(Mandatory = $true)]
        [string]
        $Path,

        [Parameter()]
        [string]
        $EndpointName
    )

    # split route on '?' for query
    $Path = Split-PodeRouteQuery -Path $Path

    # ensure the route has appropriate slashes and replace parameters
    $Path = Update-PodeRouteSlash -Path $Path
    $Path = Resolve-PodePlaceholder -Path $Path

    # ensure route does exist
    if (!$PodeContext.Server.Routes[$Method].Contains($Path)) {
        return
    }

    # select the candidate route for deletion
    $route = @($PodeContext.Server.Routes[$Method][$Path] | Where-Object {
            $_.Endpoint.Name -ieq $EndpointName
        })

    foreach ($r in $route) {
        # remove the operationId from the openapi operationId list
        if ($r.OpenAPI) {
            foreach ( $tag in $r.OpenAPI.DefinitionTag) {
                if ($tag -and ($PodeContext.Server.OpenAPI.Definitions[$tag].hiddenComponents.operationId -ccontains $route.OpenAPI.OperationId)) {
                    $PodeContext.Server.OpenAPI.Definitions[$tag].hiddenComponents.operationId = $PodeContext.Server.OpenAPI.Definitions[$tag].hiddenComponents.operationId | Where-Object { $_ -ne $route.OpenAPI.OperationId }
                }
            }
        }
    }

    # remove the route's logic
    $PodeContext.Server.Routes[$Method][$Path] = @($PodeContext.Server.Routes[$Method][$Path] | Where-Object {
            $_.Endpoint.Name -ine $EndpointName
        })

    # if the route has no more logic, just remove it
    if ((Get-PodeCount $PodeContext.Server.Routes[$Method][$Path]) -eq 0) {
        $null = $PodeContext.Server.Routes[$Method].Remove($Path)
    }
}


<#
.SYNOPSIS
    Remove a specific Signal Route.

.DESCRIPTION
    Remove a specific Signal Route.

.PARAMETER Path
    The path of the Signal Route to remove.

.PARAMETER EndpointName
    The EndpointName of an Endpoint(s) bound to the Signal Route to be removed.

.EXAMPLE
    Remove-PodeSignalRoute -Route '/message'
#>
function Remove-PodeSignalRoute {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Path,

        [Parameter()]
        [string]
        $EndpointName
    )

    $Method = 'Signal'

    # ensure the route has appropriate slashes and replace parameters
    $Path = Update-PodeRouteSlash -Path $Path

    # ensure route does exist
    if (!$PodeContext.Server.Routes[$Method].Contains($Path)) {
        return
    }

    # remove the route's logic
    $PodeContext.Server.Routes[$Method][$Path] = @($PodeContext.Server.Routes[$Method][$Path] | Where-Object {
            $_.Endpoint.Name -ine $EndpointName
        })

    # if the route has no more logic, just remove it
    if ((Get-PodeCount $PodeContext.Server.Routes[$Method][$Path]) -eq 0) {
        $null = $PodeContext.Server.Routes[$Method].Remove($Path)
    }
}


<#
.SYNOPSIS
    Remove a specific static Route.

.DESCRIPTION
    Remove a specific static Route.

.PARAMETER Path
    The path of the static Route to remove.

.PARAMETER EndpointName
    The EndpointName of an Endpoint(s) bound to the static Route to be removed.

.EXAMPLE
    Remove-PodeStaticRoute -Path '/assets'
#>
function Remove-PodeStaticRoute {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Path,

        [Parameter()]
        [string]
        $EndpointName
    )

    $Method = 'Static'

    # ensure the route has appropriate slashes and replace parameters
    $Path = Update-PodeRouteSlash -Path $Path -Static

    # ensure route does exist
    if (!$PodeContext.Server.Routes[$Method].Contains($Path)) {
        return
    }

    # remove the route's logic
    $PodeContext.Server.Routes[$Method][$Path] = @($PodeContext.Server.Routes[$Method][$Path] | Where-Object {
            $_.Endpoint.Name -ine $EndpointName
        })

    # if the route has no more logic, just remove it
    if ((Get-PodeCount $PodeContext.Server.Routes[$Method][$Path]) -eq 0) {
        $null = $PodeContext.Server.Routes[$Method].Remove($Path)
    }
}


<#
.SYNOPSIS
    Set the default IfExists preference for Routes.

.DESCRIPTION
    Set the default IfExists preference for Routes.

.PARAMETER Value
    Specifies what action to take when a Route already exists. (Default: Default)

.EXAMPLE
    Set-PodeRouteIfExistsPreference -Value Overwrite
#>
function Set-PodeRouteIfExistsPreference {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateSet('Default', 'Error', 'Overwrite', 'Skip')]
        [string]
        $Value = 'Default'
    )

    $PodeContext.Server.Preferences.Routes.IfExists = $Value
}


<#
.SYNOPSIS
    Test if a Route already exists.

.DESCRIPTION
    Test if a Route already exists for a given Method and Path.

.PARAMETER Method
    The HTTP Method of the Route.

.PARAMETER Path
    The URI path of the Route.

.PARAMETER EndpointName
    The EndpointName of an Endpoint the Route is bound against.

.PARAMETER CheckWildcard
    If supplied, Pode will check for the Route on the Method first, and then check for the Route on the '*' Method.

.EXAMPLE
    Test-PodeRoute -Method Post -Path '/example'

.EXAMPLE
    Test-PodeRoute -Method Post -Path '/example' -CheckWildcard

.EXAMPLE
    Test-PodeRoute -Method Get -Path '/example/:exampleId' -CheckWildcard
#>
function Test-PodeRoute {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Connect', 'Delete', 'Get', 'Head', 'Merge', 'Options', 'Patch', 'Post', 'Put', 'Trace', '*')]
        [string]
        $Method,

        [Parameter(Mandatory = $true)]
        [string]
        $Path,

        [Parameter()]
        [string]
        $EndpointName,

        [switch]
        $CheckWildcard
    )

    # split route on '?' for query
    $Path = Split-PodeRouteQuery -Path $Path
    if ([string]::IsNullOrWhiteSpace($Path)) {
        # No Path supplied for the Route
        throw ($PodeLocale.noPathSuppliedForRouteExceptionMessage)
    }

    # ensure the route has appropriate slashes
    $Path = Update-PodeRouteSlash -Path $Path
    $Path = Resolve-PodePlaceholder -Path $Path

    # get endpoint from name
    $endpoint = @(Find-PodeEndpoint -EndpointName $EndpointName)[0]

    # check for routes
    $found = (Test-PodeRouteInternal -Method $Method -Path $Path -Protocol $endpoint.Protocol -Address $endpoint.Address)
    if (!$found -and $CheckWildcard) {
        $found = (Test-PodeRouteInternal -Method '*' -Path $Path -Protocol $endpoint.Protocol -Address $endpoint.Address)
    }

    return $found
}


<#
.SYNOPSIS
    Test if a Signal Route already exists.

.DESCRIPTION
    Test if a Signal Route already exists for a given Path.

.PARAMETER Path
    The URI path of the Signal Route.

.PARAMETER EndpointName
    The EndpointName of an Endpoint the Signal Route is bound against.

.EXAMPLE
    Test-PodeSignalRoute -Path '/message'
#>
function Test-PodeSignalRoute {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Path,

        [Parameter()]
        [string]
        $EndpointName
    )

    $Method = 'Signal'

    # ensure the route has appropriate slashes
    $Path = Update-PodeRouteSlash -Path $Path

    # get endpoint from name
    $endpoint = @(Find-PodeEndpoint -EndpointName $EndpointName)[0]

    # check for routes
    return (Test-PodeRouteInternal -Method $Method -Path $Path -Protocol $endpoint.Protocol -Address $endpoint.Address)
}


<#
.SYNOPSIS
    Test if a Static Route already exists.

.DESCRIPTION
    Test if a Static Route already exists for a given Path.

.PARAMETER Path
    The URI path of the Static Route.

.PARAMETER EndpointName
    The EndpointName of an Endpoint the Static Route is bound against.

.EXAMPLE
    Test-PodeStaticRoute -Path '/assets'
#>
function Test-PodeStaticRoute {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Path,

        [Parameter()]
        [string]
        $EndpointName
    )

    # store the route method
    $Method = 'Static'

    # split route on '?' for query
    $Path = Split-PodeRouteQuery -Path $Path
    if ([string]::IsNullOrWhiteSpace($Path)) {
        # No Path supplied for the Route
        throw ($PodeLocale.noPathSuppliedForRouteExceptionMessage)
    }

    # ensure the route has appropriate slashes
    $Path = Update-PodeRouteSlash -Path $Path -Static
    $Path = Resolve-PodePlaceholder -Path $Path

    # get endpoint from name
    $endpoint = @(Find-PodeEndpoint -EndpointName $EndpointName)[0]

    # check for routes
    return (Test-PodeRouteInternal -Method $Method -Path $Path -Protocol $endpoint.Protocol -Address $endpoint.Address)
}


<#
.SYNOPSIS
    Automatically loads route ps1 files

.DESCRIPTION
    Automatically loads route ps1 files from either a /routes folder, or a custom folder. Saves space dot-sourcing them all one-by-one.

.PARAMETER Path
    Optional Path to a folder containing ps1 files, can be relative or literal.

.PARAMETER IfExists
    Specifies what action to take when a Route already exists. (Default: Default)

.EXAMPLE
    Use-PodeRoutes

.EXAMPLE
    Use-PodeRoutes -Path './my-routes' -IfExists Skip
#>
function Use-PodeRoutes {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Path,

        [Parameter()]
        [ValidateSet('Default', 'Error', 'Overwrite', 'Skip')]
        [string]
        $IfExists = 'Default'
    )

    if ($IfExists -ieq 'Default') {
        $IfExists = Get-PodeRouteIfExistsPreference
    }

    Use-PodeFolder -Path $Path -DefaultPath 'routes'
}


<#
.SYNOPSIS
    Retrieves the name of the current PowerShell runspace.

.DESCRIPTION
    The Get-PodeCurrentRunspaceName function retrieves the name of the current PowerShell runspace.
    This can be useful for debugging or logging purposes to identify the runspace in use.

.EXAMPLE
    Get-PodeCurrentRunspaceName
    Returns the name of the current runspace.

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function Get-PodeCurrentRunspaceName {
    [CmdletBinding()]
    param()

    # Get the current runspace
    $currentRunspace = [System.Management.Automation.Runspaces.Runspace]::DefaultRunspace

    # Get the name of the current runspace
    return $currentRunspace.Name
}


<#
.SYNOPSIS
    Sets the name of the current runspace.

.DESCRIPTION
    The Set-PodeCurrentRunspaceName function assigns a specified name to the current runspace.
    This can be useful for identifying and managing the runspace in scripts and during debugging.

.PARAMETER Name
    The name to assign to the current runspace. This parameter is mandatory.

.EXAMPLE
    Set-PodeCurrentRunspaceName -Name "MyRunspace"
    This command sets the name of the current runspace to "Pode_MyRunspace".

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function Set-PodeCurrentRunspaceName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    # Get the current runspace
    $currentRunspace = [System.Management.Automation.Runspaces.Runspace]::DefaultRunspace

    if (!$Name.StartsWith( 'Pode_' ) -and $Name -ne 'PodeServer') {
        $Name = 'Pode_' + $Name
    }

    # Set the name of the current runspace if the name is not already set
    if ( $currentRunspace.Name -ne $Name) {
        # Set the name of the current runspace
        $currentRunspace.Name = $Name
    }
}


<#
.SYNOPSIS
    Adds a new Schedule with logic to periodically invoke, defined using Cron Expressions.

.DESCRIPTION
    Adds a new Schedule with logic to periodically invoke, defined using Cron Expressions.

.PARAMETER Name
    The Name of the Schedule.

.PARAMETER Cron
    One, or an Array, of Cron Expressions to define when the Schedule should trigger.

.PARAMETER ScriptBlock
    The script defining the Schedule's logic.

.PARAMETER Limit
    The number of times the Schedule should trigger before being removed.

.PARAMETER StartTime
    A DateTime for when the Schedule should start triggering.

.PARAMETER EndTime
    A DateTime for when the Schedule should stop triggering, and be removed.

.PARAMETER ArgumentList
    A hashtable of arguments to supply to the Schedule's ScriptBlock.

.PARAMETER Timeout
    An optional timeout, in seconds, for the Schedule's logic. (Default: -1 [never timeout])

.PARAMETER TimeoutFrom
    An optional timeout from either 'Create' or 'Start'. (Default: 'Create')

.PARAMETER FilePath
    A literal, or relative, path to a file containing a ScriptBlock for the Schedule's logic.

.PARAMETER OnStart
    If supplied, the schedule will trigger when the server starts, regardless if the cron-expression matches the current time.

.EXAMPLE
    Add-PodeSchedule -Name 'RunEveryMinute' -Cron '@minutely' -ScriptBlock { /* logic */ }

.EXAMPLE
    Add-PodeSchedule -Name 'RunEveryTuesday' -Cron '0 0 * * TUE' -ScriptBlock { /* logic */ }

.EXAMPLE
    Add-PodeSchedule -Name 'StartAfter2days' -Cron '@hourly' -StartTime [DateTime]::Now.AddDays(2) -ScriptBlock { /* logic */ }

.EXAMPLE
    Add-PodeSchedule -Name 'Args' -Cron '@minutely' -ScriptBlock { /* logic */ } -ArgumentList @{ Arg1 = 'value' }
#>
function Add-PodeSchedule {
    [CmdletBinding(DefaultParameterSetName = 'Script')]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true)]
        [string[]]
        $Cron,

        [Parameter(Mandatory = $true, ParameterSetName = 'Script')]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [int]
        $Limit = 0,

        [Parameter()]
        [DateTime]
        $StartTime,

        [Parameter()]
        [DateTime]
        $EndTime,

        [Parameter(Mandatory = $true, ParameterSetName = 'File')]
        [string]
        $FilePath,

        [Parameter()]
        [hashtable]
        $ArgumentList,

        [Parameter()]
        [int]
        $Timeout = -1,

        [Parameter()]
        [ValidateSet('Create', 'Start')]
        [string]
        $TimeoutFrom = 'Create',

        [switch]
        $OnStart
    )

    # error if serverless
    Test-PodeIsServerless -FunctionName 'Add-PodeSchedule' -ThrowError

    # ensure the schedule doesn't already exist
    if ($PodeContext.Schedules.Items.ContainsKey($Name)) {
        # [Schedule] Name: Schedule already defined
        throw ($PodeLocale.scheduleAlreadyDefinedExceptionMessage -f $Name)
    }

    # ensure the limit is valid
    if ($Limit -lt 0) {
        # [Schedule] Name: Cannot have a negative limit
        throw ($PodeLocale.scheduleCannotHaveNegativeLimitExceptionMessage -f $Name)
    }

    # ensure the start/end dates are valid
    if (($null -ne $EndTime) -and ($EndTime -lt [DateTime]::Now)) {
        # [Schedule] Name: The EndTime value must be in the future
        throw ($PodeLocale.scheduleEndTimeMustBeInFutureExceptionMessage -f $Name)
    }

    if (($null -ne $StartTime) -and ($null -ne $EndTime) -and ($EndTime -le $StartTime)) {
        # [Schedule] Name: Cannot have a 'StartTime' after the 'EndTime'
        throw ($PodeLocale.scheduleStartTimeAfterEndTimeExceptionMessage -f $Name)
    }

    # if we have a file path supplied, load that path as a scriptblock
    if ($PSCmdlet.ParameterSetName -ieq 'file') {
        $ScriptBlock = Convert-PodeFileToScriptBlock -FilePath $FilePath
    }

    # check for scoped vars
    $ScriptBlock, $usingVars = Convert-PodeScopedVariables -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState

    # Modify the ScriptBlock to replace 'Start-Sleep' with 'Start-PodeSleep'
    $ScriptBlock = ConvertTo-PodeSleep -ScriptBlock $ScriptBlock

    # add the schedule
    $parsedCrons = ConvertFrom-PodeCronExpression -Expression @($Cron)
    $nextTrigger = Get-PodeCronNextEarliestTrigger -Expressions $parsedCrons -StartTime $StartTime -EndTime $EndTime

    $PodeContext.Schedules.Enabled = $true
    $PodeContext.Schedules.Items[$Name] = @{
        Name            = $Name
        StartTime       = $StartTime
        EndTime         = $EndTime
        Crons           = $parsedCrons
        CronsRaw        = @($Cron)
        Limit           = $Limit
        Count           = 0
        NextTriggerTime = $nextTrigger
        LastTriggerTime = $null
        Script          = $ScriptBlock
        UsingVariables  = $usingVars
        Arguments       = (Protect-PodeValue -Value $ArgumentList -Default @{})
        OnStart         = $OnStart
        Completed       = ($null -eq $nextTrigger)
        Timeout         = @{
            Value = $Timeout
            From  = $TimeoutFrom
        }
    }
}


<#
.SYNOPSIS
    Removes all Schedules.

.DESCRIPTION
    Removes all Schedules.

.EXAMPLE
    Clear-PodeSchedules
#>
function Clear-PodeSchedules {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    [CmdletBinding()]
    param()

    $PodeContext.Schedules.Items.Clear()
}


<#
.SYNOPSIS
    Edits an existing Schedule.

.DESCRIPTION
    Edits an existing Schedule's properties, such an cron expressions or scriptblock.

.PARAMETER Name
    The Name of the Schedule.

.PARAMETER Cron
    Any new Cron Expressions for the Schedule.

.PARAMETER ScriptBlock
    The new ScriptBlock for the Schedule.

.PARAMETER ArgumentList
    Any new Arguments for the Schedule.

.EXAMPLE
    Edit-PodeSchedule -Name 'Hello' -Cron '@minutely'

.EXAMPLE
    Edit-PodeSchedule -Name 'Hello' -Cron @('@hourly', '0 0 * * TUE')
#>
function Edit-PodeSchedule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]
        $Name,

        [Parameter()]
        [string[]]
        $Cron,

        [Parameter()]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [hashtable]
        $ArgumentList
    )

    # ensure the schedule exists
    if (!$PodeContext.Schedules.Items.ContainsKey($Name)) {
        # Schedule 'Name' does not exist
        throw ($PodeLocale.scheduleDoesNotExistExceptionMessage -f $Name)
    }

    $_schedule = $PodeContext.Schedules.Items[$Name]

    # edit cron if supplied
    if (!(Test-PodeIsEmpty $Cron)) {
        $_schedule.Crons = (ConvertFrom-PodeCronExpression -Expression @($Cron))
        $_schedule.CronsRaw = $Cron
        $_schedule.NextTriggerTime = Get-PodeCronNextEarliestTrigger -Expressions $_schedule.Crons -StartTime $_schedule.StartTime -EndTime $_schedule.EndTime
    }

    # edit scriptblock if supplied
    if (!(Test-PodeIsEmpty $ScriptBlock)) {
        $ScriptBlock, $usingVars = Convert-PodeScopedVariables -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState
        $_schedule.Script = $ScriptBlock
        $_schedule.UsingVariables = $usingVars
    }

    # edit arguments if supplied
    if (!(Test-PodeIsEmpty $ArgumentList)) {
        $_schedule.Arguments = $ArgumentList
    }
}


<#
.SYNOPSIS
    Returns any defined schedules.

.DESCRIPTION
    Returns any defined schedules, with support for filtering.

.PARAMETER Name
    Any schedule Names to filter the schedules.

.PARAMETER StartTime
    An optional StartTime to only return Schedules that will trigger after this date.

.PARAMETER EndTime
    An optional EndTime to only return Schedules that will trigger before this date.

.EXAMPLE
    Get-PodeSchedule

.EXAMPLE
    Get-PodeSchedule -Name Name1, Name2

.EXAMPLE
    Get-PodeSchedule -Name Name1, Name2 -StartTime [datetime]::new(2020, 3, 1) -EndTime [datetime]::new(2020, 3, 31)
#>
function Get-PodeSchedule {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string[]]
        $Name,

        [Parameter()]
        $StartTime = $null,

        [Parameter()]
        $EndTime = $null
    )

    $schedules = $PodeContext.Schedules.Items.Values

    # further filter by schedule names
    if (($null -ne $Name) -and ($Name.Length -gt 0)) {
        $schedules = @(foreach ($_name in $Name) {
                foreach ($schedule in $schedules) {
                    if ($schedule.Name -ine $_name) {
                        continue
                    }

                    $schedule
                }
            })
    }

    # filter by some start time
    if ($null -ne $StartTime) {
        $schedules = @(foreach ($schedule in $schedules) {
                if (($null -ne $schedule.StartTime) -and ($StartTime -lt $schedule.StartTime)) {
                    continue
                }

                $_end = $EndTime
                if ($null -eq $_end) {
                    $_end = $schedule.EndTime
                }

                if (($null -ne $schedule.EndTime) -and
                (($StartTime -gt $schedule.EndTime) -or
                    ((Get-PodeScheduleNextTrigger -Name $schedule.Name -DateTime $StartTime) -gt $_end))) {
                    continue
                }

                $schedule
            })
    }

    # filter by some end time
    if ($null -ne $EndTime) {
        $schedules = @(foreach ($schedule in $schedules) {
                if (($null -ne $schedule.EndTime) -and ($EndTime -gt $schedule.EndTime)) {
                    continue
                }

                $_start = $StartTime
                if ($null -eq $_start) {
                    $_start = $schedule.StartTime
                }

                if (($null -ne $schedule.StartTime) -and
                (($EndTime -lt $schedule.StartTime) -or
                    ((Get-PodeScheduleNextTrigger -Name $schedule.Name -DateTime $_start) -gt $EndTime))) {
                    continue
                }

                $schedule
            })
    }

    # return
    return $schedules
}


<#
.SYNOPSIS
    Get the next trigger time for a Schedule.

.DESCRIPTION
    Get the next trigger time for a Schedule, either from the Schedule's StartTime or from a defined DateTime.

.PARAMETER Name
    The Name of the Schedule.

.PARAMETER DateTime
    An optional specific DateTime to get the next trigger time after. This DateTime must be between the Schedule's StartTime and EndTime.

.EXAMPLE
    Get-PodeScheduleNextTrigger -Name Schedule1

.EXAMPLE
    Get-PodeScheduleNextTrigger -Name Schedule1 -DateTime [datetime]::new(2020, 3, 10)
#>
function Get-PodeScheduleNextTrigger {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]
        $Name,

        [Parameter()]
        $DateTime = $null
    )

    # ensure the schedule exists
    if (!$PodeContext.Schedules.Items.ContainsKey($Name)) {
        # Schedule 'Name' does not exist
        throw ($PodeLocale.scheduleDoesNotExistExceptionMessage -f $Name)
    }

    $_schedule = $PodeContext.Schedules.Items[$Name]

    # ensure date is after start/before end
    if (($null -ne $DateTime) -and ($null -ne $_schedule.StartTime) -and ($DateTime -lt $_schedule.StartTime)) {
        # Supplied date is before the start time of the schedule at $_schedule.StartTime
        throw ($PodeLocale.suppliedDateBeforeScheduleStartTimeExceptionMessage -f $_schedule.StartTime)
    }

    if (($null -ne $DateTime) -and ($null -ne $_schedule.EndTime) -and ($DateTime -gt $_schedule.EndTime)) {
        # Supplied date is after the end time of the schedule at $_schedule.EndTime
        throw ($PodeLocale.suppliedDateAfterScheduleEndTimeExceptionMessage -f $_schedule.EndTime)
    }

    # get the next trigger
    if ($null -eq $DateTime) {
        $DateTime = $_schedule.StartTime
    }

    return (Get-PodeCronNextEarliestTrigger -Expressions $_schedule.Crons -StartTime $DateTime -EndTime $_schedule.EndTime)
}


<#
.SYNOPSIS
    Get all Schedule Processes.

.DESCRIPTION
    Get all Schedule Processes, with support for filtering.

.PARAMETER Name
    An optional Name of the Schedule to filter by, can be one or more.

.PARAMETER Id
    An optional ID of the Schedule process to filter by, can be one or more.

.PARAMETER State
    An optional State of the Schedule process to filter by, can be one or more.

.EXAMPLE
    Get-PodeScheduleProcess

.EXAMPLE
    Get-PodeScheduleProcess -Name 'ScheduleName'

.EXAMPLE
    Get-PodeScheduleProcess -Id 'ScheduleId'

.EXAMPLE
    Get-PodeScheduleProcess -State 'Running'
#>
function Get-PodeScheduleProcess {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string[]]
        $Name,

        [Parameter()]
        [string[]]
        $Id,

        [Parameter()]
        [ValidateSet('All', 'Pending', 'Running', 'Completed', 'Failed')]
        [string[]]
        $State = 'All'
    )

    $processes = $PodeContext.Schedules.Processes.Values

    # filter processes by name
    if (($null -ne $Name) -and ($Name.Length -gt 0)) {
        $processes = @(foreach ($_name in $Name) {
                foreach ($process in $processes) {
                    if ($process.Schedule -ine $_name) {
                        continue
                    }

                    $process
                }
            })
    }

    # filter processes by id
    if (($null -ne $Id) -and ($Id.Length -gt 0)) {
        $processes = @(foreach ($_id in $Id) {
                foreach ($process in $processes) {
                    if ($process.ID -ine $_id) {
                        continue
                    }

                    $process
                }
            })
    }

    # filter processes by status
    if ($State -inotcontains 'All') {
        $processes = @(foreach ($process in $processes) {
                if ($State -inotcontains $process.State) {
                    continue
                }

                $process
            })
    }

    # return processes
    return $processes
}


<#
.SYNOPSIS
    Adhoc invoke a Schedule's logic.

.DESCRIPTION
    Adhoc invoke a Schedule's logic outside of its defined cron-expression. This invocation doesn't count towards the Schedule's limit.

.PARAMETER Name
    The Name of the Schedule.

.PARAMETER ArgumentList
    A hashtable of arguments to supply to the Schedule's ScriptBlock.

.EXAMPLE
    Invoke-PodeSchedule -Name 'schedule-name'
#>
function Invoke-PodeSchedule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]
        $Name,

        [Parameter()]
        [hashtable]
        $ArgumentList = $null
    )

    # ensure the schedule exists
    if (!$PodeContext.Schedules.Items.ContainsKey($Name)) {
        # Schedule 'Name' does not exist
        throw ($PodeLocale.scheduleDoesNotExistExceptionMessage -f $Name)
    }

    # run schedule logic
    Invoke-PodeInternalScheduleLogic -Schedule $PodeContext.Schedules.Items[$Name] -ArgumentList $ArgumentList
}


<#
.SYNOPSIS
    Removes a specific Schedule.

.DESCRIPTION
    Removes a specific Schedule.

.PARAMETER Name
    The Name of the Schedule to be removed.

.EXAMPLE
    Remove-PodeSchedule -Name 'RenewToken'
#>
function Remove-PodeSchedule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]
        $Name
    )

    $null = $PodeContext.Schedules.Items.Remove($Name)
}


<#
.SYNOPSIS
    Set the maximum number of concurrent schedules.

.DESCRIPTION
    Set the maximum number of concurrent schedules.

.PARAMETER Maximum
    The Maximum number of schedules to run.

.EXAMPLE
    Set-PodeScheduleConcurrency -Maximum 25
#>
function Set-PodeScheduleConcurrency {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]
        $Maximum
    )

    # error if <=0
    if ($Maximum -le 0) {
        # Maximum concurrent schedules must be >=1 but got
        throw ($PodeLocale.maximumConcurrentSchedulesInvalidExceptionMessage -f $Maximum)
    }

    # ensure max > min
    $_min = 1
    if ($null -ne $PodeContext.RunspacePools.Schedules) {
        $_min = $PodeContext.RunspacePools.Schedules.Pool.GetMinRunspaces()
    }

    if ($_min -gt $Maximum) {
        # Maximum concurrent schedules cannot be less than the minimum of $_min but got $Maximum
        throw ($PodeLocale.maximumConcurrentSchedulesLessThanMinimumExceptionMessage -f $_min, $Maximum)
    }

    # set the max schedules
    $PodeContext.Threads.Schedules = $Maximum
    if ($null -ne $PodeContext.RunspacePools.Schedules) {
        $PodeContext.RunspacePools.Schedules.Pool.SetMaxRunspaces($Maximum)
    }
}


<#
.SYNOPSIS
    Tests whether the passed Schedule exists.

.DESCRIPTION
    Tests whether the passed Schedule exists by its name.

.PARAMETER Name
    The Name of the Schedule.

.EXAMPLE
    if (Test-PodeSchedule -Name ScheduleName) { }
#>
function Test-PodeSchedule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    return (($null -ne $PodeContext.Schedules.Items) -and $PodeContext.Schedules.Items.ContainsKey($Name))
}


<#
.SYNOPSIS
    Automatically loads schedule ps1 files

.DESCRIPTION
    Automatically loads schedule ps1 files from either a /schedules folder, or a custom folder. Saves space dot-sourcing them all one-by-one.

.PARAMETER Path
    Optional Path to a folder containing ps1 files, can be relative or literal.

.EXAMPLE
    Use-PodeSchedules

.EXAMPLE
    Use-PodeSchedules -Path './my-schedules'
#>
function Use-PodeSchedules {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Path
    )

    Use-PodeFolder -Path $Path -DefaultPath 'schedules'
}


<#
.SYNOPSIS
    Adds a new Scoped Variable.

.DESCRIPTION
    Adds a new Scoped Variable, to make calling certain functions simpler.
    For example "$state:Name" instead of "Get-PodeState" and "Set-PodeState".

.PARAMETER Name
    The Name of the Scoped Variable.

.PARAMETER GetReplace
    A template to be used when converting "$var = $SV:<name>" to a "Get-SVValue -Name <name>" syntax.
    You can use the "{{name}}" placeholder to show where the <name> would be placed in the conversion. The result will also be automatically wrapped in brackets.
    For example, "$var = $state:<name>" to "Get-PodeState -Name <name>" would need a GetReplace value of "Get-PodeState -Name '{{name}}'".

.PARAMETER SetReplace
    An optional template to be used when converting "$SV:<name> = <value>" to a "Set-SVValue -Name <name> -Value <value>" syntax.
    You can use the "{{name}}" placeholder to show where the <name> would be placed in the conversion. The <value> will automatically be appended to the end.
    For example, "$state:<name> = <value>" to "Set-PodeState -Name <name> -Value <value>" would need a SetReplace value of "Set-PodeState -Name '{{name}}' -Value ".

.PARAMETER ScriptBlock
    For more advanced conversions, that aren't as simple as a simple find/replace, you can supply a ScriptBlock instead.
    This ScriptBlock will be supplied ScriptBlock to convert, followed by a SessionState object, and the Get/Set regex patterns, as parameters.
    The ScriptBlock should returned a converted ScriptBlock that works, plus an optional array of values that should be supplied to the ScriptBlock when invoked.

.EXAMPLE
    Add-PodeScopedVariable -Name 'cache' -SetReplace "Set-PodeCache -Key '{{name}}' -InputObject " -GetReplace "Get-PodeCache -Key '{{name}}'"

.EXAMPLE
    Add-PodeScopedVariable -Name 'config' -ScriptBlock {
    param($ScriptBlock, $SessionState, $GetPattern, $SetPattern)
    $strScriptBlock = "$($ScriptBlock)"
    $template = "(Get-PodeConfig).'{{name}}'"

    # allows "$port = $config:port" instead of "$port = (Get-PodeConfig).port"
    while ($strScriptBlock -imatch $GetPattern) {
    $getReplace = $template.Replace('{{name}}', $Matches['name'])
    $strScriptBlock = $strScriptBlock.Replace($Matches['full'], "($($getReplace))")
    }

    return [scriptblock]::Create($strScriptBlock)
    }
#>
function Add-PodeScopedVariable {
    [CmdletBinding(DefaultParameterSetName = 'Replace')]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true, ParameterSetName = 'Replace')]
        [string]
        $GetReplace,

        [Parameter(ParameterSetName = 'Replace')]
        [string]
        $SetReplace = $null,

        [Parameter(Mandatory = $true, ParameterSetName = 'ScriptBlock')]
        [scriptblock]
        $ScriptBlock
    )

    Add-PodeScopedVariableInternal @PSBoundParameters
}


<#
.SYNOPSIS
    Removes all Scoped Variables.

.DESCRIPTION
    Removes all Scoped Variables.

.EXAMPLE
    Clear-PodeScopedVariables
#>
function Clear-PodeScopedVariables {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    [CmdletBinding()]
    param()

    $null = $PodeContext.Server.ScopedVariables.Clear()
}


<#
.SYNOPSIS
    Converts a Scoped Variable within a given ScriptBlock.

.DESCRIPTION
    Converts a Scoped Variable within a given ScriptBlock, and returns the updated ScriptBlock back, including any
    other values that will need to be supplied as parameters to the ScriptBlock first.

.PARAMETER Name
    The Name of the Scoped Variable to convert. (ie: Session, Using, or a Name from Add-PodeScopedVariable)

.PARAMETER ScriptBlock
    The ScriptBlock to be converted.

.PARAMETER PSSession
    An optional SessionState object, used to retrieve using-variable values or other values where scope is required.

.EXAMPLE
    $ScriptBlock = Convert-PodeScopedVariable -Name State -ScriptBlock $ScriptBlock

.EXAMPLE
    $ScriptBlock, $otherResults = Convert-PodeScopedVariable -Name Using -ScriptBlock $ScriptBlock
#>
function Convert-PodeScopedVariable {
    [CmdletBinding()]
    [OutputType([scriptblock])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(ValueFromPipeline = $true)]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [System.Management.Automation.SessionState]
        $PSSession
    )

    # do nothing if no scriptblock
    if ($null -eq $ScriptBlock) {
        return $ScriptBlock
    }

    # check if scoped var defined
    if (!(Test-PodeScopedVariable -Name $Name)) {
        # Scoped Variable not found
        throw ($PodeLocale.scopedVariableNotFoundExceptionMessage -f $Name)
    }

    # get the scoped var metadata
    $scopedVar = $PodeContext.Server.ScopedVariables[$Name]

    # invoke the logic for the appropriate conversion type required - internal function map, custom scriptblock, or simple replace
    switch ($scopedVar.Type) {
        'internal' {
            switch ($scopedVar.Name) {
                'using' {
                    return Convert-PodeScopedVariableInbuiltUsing -ScriptBlock $ScriptBlock -PSSession $PSSession
                }
            }
        }

        'scriptblock' {
            return Invoke-PodeScriptBlock `
                -ScriptBlock $scopedVar.ScriptBlock `
                -Arguments $ScriptBlock, $PSSession, $scopedVar.Get.Pattern, $scopedVar.Set.Pattern `
                -Splat `
                -Return `
                -NoNewClosure
        }

        'replace' {
            # convert scriptblock to string
            $strScriptBlock = "$($ScriptBlock)"

            # see if the script contains any form of the scoped variable, and if not just return
            $found = $strScriptBlock -imatch "\`$$($Name)\:"
            if (!$found) {
                return $ScriptBlock
            }

            # loop and replace "set" syntax if replace template supplied
            if (![string]::IsNullOrEmpty($scopedVar.Set.Replace)) {
                while ($strScriptBlock -imatch $scopedVar.Set.Pattern) {
                    $setReplace = $scopedVar.Set.Replace.Replace('{{name}}', $Matches['name'])
                    $strScriptBlock = $strScriptBlock.Replace($Matches['full'], $setReplace)
                }
            }

            # loop and replace "get" syntax
            while ($strScriptBlock -imatch $scopedVar.Get.Pattern) {
                $getReplace = $scopedVar.Get.Replace.Replace('{{name}}', $Matches['name'])
                $strScriptBlock = $strScriptBlock.Replace($Matches['full'], "($($getReplace))")
            }

            # convert update scriptblock back
            return [scriptblock]::Create($strScriptBlock)
        }
    }
}


<#
.SYNOPSIS
    Converts Scoped Variables within a given ScriptBlock.

.DESCRIPTION
    Converts Scoped Variables within a given ScriptBlock, and returns the updated ScriptBlock back, including any
    using-variable values that will need to be supplied as parameters to the ScriptBlock first.

.PARAMETER ScriptBlock
    The ScriptBlock to be converted.

.PARAMETER PSSession
    An optional SessionState object, used to retrieve using-variable values.
    If not supplied, using-variable values will not be converted.

.PARAMETER Exclude
    An optional array of one or more Scoped Variable Names to Exclude from converting. (ie: Session, Using, or a Name from Add-PodeScopedVariable)

.EXAMPLE
    $ScriptBlock, $usingVars = Convert-PodeScopedVariables -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState

.EXAMPLE
    $ScriptBlock = Convert-PodeScopedVariables -ScriptBlock $ScriptBlock -Exclude Session, Using
#>
function Convert-PodeScopedVariables {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    [CmdletBinding()]
    [OutputType([System.Object[]])]
    [OutputType([scriptblock])]
    param(
        [Parameter(ValueFromPipeline = $true)]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [System.Management.Automation.SessionState]
        $PSSession,

        [Parameter()]
        [string[]]
        $Exclude
    )

    # do nothing if no scriptblock
    if ($null -eq $ScriptBlock) {
        return $ScriptBlock
    }

    # using vars
    $usingVars = $null

    # loop through each defined scoped variable and convert, unless excluded
    foreach ($key in $PodeContext.Server.ScopedVariables.Keys) {
        # excluded?
        if ($Exclude -icontains $key) {
            continue
        }

        # convert scoped var
        $ScriptBlock, $otherResults = Convert-PodeScopedVariable -Name $key -ScriptBlock $ScriptBlock -PSSession $PSSession

        # using vars?
        if (($null -ne $otherResults) -and ($key -ieq 'using')) {
            $usingVars = $otherResults
        }
    }

    # return just the scriptblock, or include using vars as well
    if ($null -ne $usingVars) {
        return $ScriptBlock, $usingVars
    }

    return $ScriptBlock
}


<#
.SYNOPSIS
    Get a Scoped Variable(s).

.DESCRIPTION
    Get a Scoped Variable(s).

.PARAMETER Name
    The Name of the Scoped Variable(s) to retrieve.

.EXAMPLE
    Get-PodeScopedVariable -Name State

.EXAMPLE
    Get-PodeScopedVariable -Name State, Using
#>
function Get-PodeScopedVariable {
    [CmdletBinding()]
    [OutputType([System.Object[]])]
    param(
        [Parameter()]
        [string[]]
        $Name
    )

    # return all if no Name
    if ([string]::IsNullOrEmpty($Name) -or ($Name.Length -eq 0)) {
        return $PodeContext.Server.ScopedVariables.Values
    }

    # return filtered
    return @(foreach ($n in $Name) {
            $PodeContext.Server.ScopedVariables[$n]
        })
}


<#
.SYNOPSIS
    Removes a Scoped Variable.

.DESCRIPTION
    Removes a Scoped Variable.

.PARAMETER Name
    The Name of a Scoped Variable to remove.

.EXAMPLE
    Remove-PodeScopedVariable -Name State
#>
function Remove-PodeScopedVariable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    $null = $PodeContext.Server.ScopedVariables.Remove($Name)
}


<#
.SYNOPSIS
    Tests if a Scoped Variable exists.

.DESCRIPTION
    Tests if a Scoped Variable exists.

.PARAMETER Name
    The Name of the Scoped Variable to check.

.EXAMPLE
    if (Test-PodeScopedVariable -Name $Name) { ... }
#>
function Test-PodeScopedVariable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    return $PodeContext.Server.ScopedVariables.Contains($Name)
}


<#
.SYNOPSIS
    Automatically loads Scoped Variable ps1 files

.DESCRIPTION
    Automatically loads Scoped Variable ps1 files from either a /scoped-vars folder, or a custom folder. Saves space dot-sourcing them all one-by-one.

.PARAMETER Path
    Optional Path to a folder containing ps1 files, can be relative or literal.

.EXAMPLE
    Use-PodeScopedVariables

.EXAMPLE
    Use-PodeScopedVariables -Path './my-vars'
#>
function Use-PodeScopedVariables {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Path
    )

    Use-PodeFolder -Path $Path -DefaultPath 'scoped-vars'
}


<#
.SYNOPSIS
    Dismount a previously mounted Secret.

.DESCRIPTION
    Dismount a previously mounted Secret.

.PARAMETER Name
    The friendly Name of the Secret.

.PARAMETER Remove
    If supplied, the Secret will also be removed from the Secret Vault as well.

.EXAMPLE
    Dismount-PodeSecret -Name 'SecretName'

.EXAMPLE
    Dismount-PodeSecret -Name 'SecretName' -Remove
#>
function Dismount-PodeSecret {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [switch]
        $Remove
    )

    # do nothing if the secret hasn't been mounted, unless Remove is specified
    if (!(Test-PodeSecret -Name $Name)) {
        if ($Remove) {
            # No Secret named has been mounted
            throw ($PodeLocale.noSecretNamedMountedExceptionMessage -f $Name)
        }

        return
    }

    # if "remove" switch passed, remove the secret from the vault as well
    if ($Remove) {
        $secret = $PodeContext.Server.Secrets.Keys[$Name]
        Remove-PodeSecret -Key $secret.Key -Vault $secret.Vault -ArgumentList $secret.Arguments
    }

    # remove reference
    $null = $PodeContext.Server.Secrets.Keys.Remove($Name)
}


<#
.SYNOPSIS
    Retrieve the value of a mounted Secret.

.DESCRIPTION
    Retrieve the value of a mounted Secret from a Secret Vault. You can also use "$value = $secret:<NAME>" syntax in certain places.

.PARAMETER Name
    The friendly Name of a Secret.

.EXAMPLE
    $value = Get-PodeSecret -Name 'SecretName'

.EXAMPLE
    $value = $secret:SecretName
#>
function Get-PodeSecret {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    # has the secret been mounted?
    if (!(Test-PodeSecret -Name $Name)) {
        # No Secret named has been mounted
        throw ($PodeLocale.noSecretNamedMountedExceptionMessage -f $Name)
    }

    # get the secret and vault
    $secret = $PodeContext.Server.Secrets.Keys[$Name]

    # is the value cached?
    if ($secret.Cache.Enabled -and ($null -ne $secret.Cache.Expiry) -and ($secret.Cache.Expiry -gt [datetime]::UtcNow)) {
        return $secret.Cache.Value
    }

    # fetch the secret depending on vault type
    $vault = $PodeContext.Server.Secrets.Vaults[$secret.Vault]
    $value = Lock-PodeObject -Name $vault.LockableName -Return -ScriptBlock {
        switch ($vault.Type) {
            'custom' {
                return Get-PodeSecretCustomKey -Vault $secret.Vault -Key $secret.Key -ArgumentList $secret.Arguments
            }

            'secretmanagement' {
                return Get-PodeSecretManagementKey -Vault $secret.Vault -Key $secret.Key
            }
        }
    }

    # filter the value by any properties
    if ($secret.Properties.Enabled) {
        if ($secret.Properties.Expand) {
            $value = Select-Object -InputObject $value -ExpandProperty $secret.Properties.Fields
        }
        else {
            $value = Select-Object -InputObject $value -Property $secret.Properties.Fields
        }
    }

    # cache the value if needed
    if ($secret.Cache.Enabled) {
        $secret.Cache.Value = $value
        $secret.Cache.Expiry = [datetime]::UtcNow.AddMinutes($secret.Cache.Ttl)
    }

    # return value
    return $value
}


<#
.SYNOPSIS
    Fetches and returns information of a Secret Vault.

.DESCRIPTION
    Fetches and returns information of a Secret Vault.

.PARAMETER Name
    The Name(s) of a Secret Vault to retrieve.

.EXAMPLE
    $vault = Get-PodeSecretVault -Name 'VaultName'

.EXAMPLE
    $vaults = Get-PodeSecretVault -Name 'VaultName1', 'VaultName2'
#>
function Get-PodeSecretVault {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]
        $Name
    )

    $vaults = $PodeContext.Server.Secrets.Vaults.Values

    # further filter by vault names
    if (($null -ne $Name) -and ($Name.Length -gt 0)) {
        $vaults = @(foreach ($_name in $Name) {
                foreach ($vault in $vaults) {
                    if ($vault.Name -ine $_name) {
                        continue
                    }

                    $vault
                }
            })
    }

    # return
    return $vaults
}


<#
.SYNOPSIS
    Mount a Secret from a Secret Vault.

.DESCRIPTION
    Mount a Secret from a Secret Vault, so it can be more easily referenced and support caching.

.PARAMETER Name
    A unique friendly Name for the Secret.

.PARAMETER Vault
    The friendly name of the Secret Vault this Secret can be found in.

.PARAMETER Property
    An optional array of Properties to be returned if the Secret contains multiple properties.

.PARAMETER ExpandProperty
    An optional Property to be expanded from the Secret and return if it contains multiple properties.

.PARAMETER Key
    The Key/Path of the Secret within the Secret Vault.

.PARAMETER ArgumentList
    An optional array of Arguments to be supplied to a custom Secret Vault's scriptblocks.

.PARAMETER CacheTtl
    An optional number of minutes to Cache the Secret's value for. You can use this parameter to override the Secret Vault's value. (Default: -1)
    If the value is -1 it uses the Secret Vault's CacheTtl. A value of 0 is to disable caching for this Secret. A value >0 overrides the Secret Vault.

.EXAMPLE
    Mount-PodeSecret -Name 'SecretName' -Vault 'VaultName' -Key 'path/to/secret' -ExpandProperty 'foo'

.EXAMPLE
    Mount-PodeSecret -Name 'SecretName' -Vault 'VaultName' -Key 'key_of_secret' -CacheTtl 5
#>
function Mount-PodeSecret {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true)]
        [string]
        $Vault,

        [Parameter()]
        [string[]]
        $Property,

        [Parameter()]
        [string]
        $ExpandProperty,

        [Parameter(Mandatory = $true)]
        [string]
        $Key,

        [Parameter()]
        [object[]]
        $ArgumentList,

        # in minutes (-1 means use the vault default, 0 is off, anything higher than 0 is an override)
        [Parameter()]
        [int]
        $CacheTtl = -1
    )

    # has the secret been mounted already?
    if (Test-PodeSecret -Name $Name) {
        # A Secret with the name has already been mounted
        throw ($PodeLocale.secretAlreadyMountedExceptionMessage -f $Name)
    }

    # does the vault exist?
    if (!(Test-PodeSecretVault -Name $Vault)) {
        # No Secret Vault with the name has been registered
        throw ($PodeLocale.noSecretVaultRegisteredExceptionMessage -f $Vault)
    }

    # check properties
    if (!(Test-PodeIsEmpty $Property) -and !(Test-PodeIsEmpty $ExpandProperty)) {
        # Parameters 'Property' and 'ExpandPropery' are mutually exclusive
        throw ($PodeLocale.parametersMutuallyExclusiveExceptionMessage -f 'Property' , 'ExpandPropery')
    }

    # which cache value?
    if ($CacheTtl -lt 0) {
        $CacheTtl = [int]$PodeContext.Server.Secrets.Vaults[$Vault].Cache.Ttl
    }

    # mount secret reference
    $props = $Property
    if (![string]::IsNullOrWhiteSpace($ExpandProperty)) {
        $props = $ExpandProperty
    }

    $PodeContext.Server.Secrets.Keys[$Name] = @{
        Key        = $Key
        Properties = @{
            Fields  = $props
            Expand  = (![string]::IsNullOrWhiteSpace($ExpandProperty))
            Enabled = (!(Test-PodeIsEmpty $props))
        }
        Vault      = $Vault
        Arguments  = $ArgumentList
        Cache      = @{
            Ttl     = $CacheTtl
            Enabled = ($CacheTtl -gt 0)
        }
    }
}


<#
.SYNOPSIS
    Read a Secret from a Secret Vault.

.DESCRIPTION
    Read a Secret from a Secret Vault.

.PARAMETER Key
    The Key/Path of the Secret within the Secret Vault.

.PARAMETER Vault
    The friendly name of the Secret Vault this Secret can be found in.

.PARAMETER Property
    An optional array of Properties to be returned if the Secret contains multiple properties.

.PARAMETER ExpandProperty
    An optional Property to be expanded from the Secret and return if it contains multiple properties.

.PARAMETER ArgumentList
    An optional array of Arguments to be supplied to a custom Secret Vault's scriptblocks.

.EXAMPLE
    $value = Read-PodeSecret -Key 'path/to/secret' -Vault 'VaultName'

.EXAMPLE
    $value = Read-PodeSecret -Key 'key_of_secret' -Vault 'VaultName' -Property prop1, prop2
#>
function Read-PodeSecret {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Key,

        [Parameter(Mandatory = $true)]
        [string]
        $Vault,

        [Parameter()]
        [string[]]
        $Property,

        [Parameter()]
        [string]
        $ExpandProperty,

        [Parameter()]
        [object[]]
        $ArgumentList
    )

    # has the vault been registered?
    if (!(Test-PodeSecretVault -Name $Vault)) {
        # No Secret Vault with the name has been registered
        throw ($PodeLocale.noSecretVaultRegisteredExceptionMessage -f $Vault)
    }

    # fetch the secret depending on vault type
    $_vault = $PodeContext.Server.Secrets.Vaults[$Vault]
    $value = Lock-PodeObject -Name $_vault.LockableName -Return -ScriptBlock {
        switch ($_vault.Type) {
            'custom' {
                return Get-PodeSecretCustomKey -Vault $Vault -Key $Key -ArgumentList $ArgumentList
            }

            'secretmanagement' {
                return Get-PodeSecretManagementKey -Vault $Vault -Key $Key
            }
        }
    }

    # filter the value by any properties
    if (![string]::IsNullOrWhiteSpace($ExpandProperty)) {
        $value = Select-Object -InputObject $value -ExpandProperty $ExpandProperty
    }
    elseif (![string]::IsNullOrEmpty($Property)) {
        $value = Select-Object -InputObject $value -Property $Property
    }

    # return value
    return $value
}


<#
.SYNOPSIS
    Register a Secret Vault.

.DESCRIPTION
    Register a Secret Vault, which is defined by either custom logic or using the SecretManagement module.

.PARAMETER Name
    The unique friendly Name of the Secret Vault within Pode.

.PARAMETER VaultParameters
    A hashtable of extra parameters that should be supplied to either the SecretManagement module, or custom scriptblocks.

.PARAMETER UnlockSecret
    An optional Secret to be used to unlock the Secret Vault if need.

.PARAMETER UnlockSecureSecret
    An optional Secret, as a SecureString, to be used to unlock the Secret Vault if need.

.PARAMETER UnlockInterval
    An optional number of minutes that Pode will periodically check/unlock the Secret Vault. (Default: 0)

.PARAMETER NoUnlock
    If supplied, the Secret Vault will not be unlocked after registration. To unlock you'll need to call Unlock-PodeSecretVault.

.PARAMETER CacheTtl
    An optional number of minutes that Secrets should be cached for. (Default: 0)

.PARAMETER InitScriptBlock
    An optional scriptblock to run before the Secret Vault is registered, letting you initialise any connection, contexts, etc.

.PARAMETER VaultName
    For SecretManagement module Secret Vaults, you can use thie parameter to specify the actual Vault name, and use the above Name parameter as a more friendly name if required.

.PARAMETER ModuleName
    For SecretManagement module Secret Vaults, this is the name/path of the extension module to be used.

.PARAMETER ScriptBlock
    For custom Secret Vaults, this is a scriptblock used to read the Secret from the Vault.

.PARAMETER UnlockScriptBlock
    For custom Secret Vaults, this is an optional scriptblock used to unlock the Secret Vault.

.PARAMETER RemoveScriptBlock
    For custom Secret Vaults, this is an optional scriptblock used to remove a Secret from the Vault.

.PARAMETER SetScriptBlock
    For custom Secret Vaults, this is an optional scriptblock used to create/update a Secret in the Vault.

.PARAMETER UnregisterScriptBlock
    For custom Secret Vaults, this is an optional scriptblock used unregister the Secret Vault with any custom clean-up logic.

.EXAMPLE
    Register-PodeSecretVault -Name 'VaultName' -ModuleName 'Az.KeyVault' -VaultParameters @{ AZKVaultName = $name; SubscriptionId = $subId }

.EXAMPLE
    Register-PodeSecretVault -Name 'VaultName' -VaultParameters @{ Address = 'http://127.0.0.1:8200' } -ScriptBlock { ... }
#>
function Register-PodeSecretVault {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [hashtable]
        $VaultParameters,

        [Parameter()]
        [string]
        $UnlockSecret,

        [Parameter()]
        [securestring]
        $UnlockSecureSecret,

        [Parameter()]
        [int]
        $UnlockInterval = 0,

        [switch]
        $NoUnlock,

        [Parameter()]
        [int]
        $CacheTtl = 0, # in minutes

        [Parameter()]
        [scriptblock]
        $InitScriptBlock,

        [Parameter(ParameterSetName = 'SecretManagement')]
        [string]
        $VaultName,

        [Parameter(Mandatory = $true, ParameterSetName = 'SecretManagement')]
        [Alias('Module')]
        [string]
        $ModuleName,

        [Parameter(Mandatory = $true, ParameterSetName = 'Custom')]
        [scriptblock]
        $ScriptBlock, # Read a secret

        [Parameter(ParameterSetName = 'Custom')]
        [Alias('Unlock')]
        [scriptblock]
        $UnlockScriptBlock,

        [Parameter(ParameterSetName = 'Custom')]
        [Alias('Remove')]
        [scriptblock]
        $RemoveScriptBlock,

        [Parameter(ParameterSetName = 'Custom')]
        [Alias('Set')]
        [scriptblock]
        $SetScriptBlock,

        [Parameter(ParameterSetName = 'Custom')]
        [Alias('Unregister')]
        [scriptblock]
        $UnregisterScriptBlock
    )

    # has the vault already been registered?
    if (Test-PodeSecretVault -Name $Name) {
        $autoImported = [string]::Empty
        if ($PodeContext.Server.Secrets.Vaults[$Name].AutoImported) {
            $autoImported = ' from auto-importing'
        }
        # A Secret Vault with the name {0} has already been registered{1}
        throw ($PodeLocale.secretVaultAlreadyRegisteredAutoImportExceptionMessage -f $Name, $autoImported)
    }

    # base vault config
    if (![string]::IsNullOrEmpty($UnlockSecret)) {
        $UnlockSecureSecret = $UnlockSecret | ConvertTo-SecureString -AsPlainText -Force
    }

    $vault = @{
        Name         = $Name
        Type         = $PSCmdlet.ParameterSetName.ToLowerInvariant()
        Parameters   = $VaultParameters
        AutoImported = $false
        LockableName = "__Pode_SecretVault_$($Name)__"
        Unlock       = @{
            Secret   = $UnlockSecureSecret
            Expiry   = $null
            Interval = $UnlockInterval
            Enabled  = (!(Test-PodeIsEmpty $UnlockSecureSecret))
        }
        Cache        = @{
            Ttl     = $CacheTtl
            Enabled = ($CacheTtl -gt 0)
        }
    }

    # initialise the secret vault
    if ($null -ne $InitScriptBlock) {
        $vault | Initialize-PodeSecretVault -ScriptBlock $InitScriptBlock
    }

    # set vault config depending on vault type
    switch ($vault.Type) {
        'custom' {
            $vault | Register-PodeSecretCustomVault `
                -ScriptBlock $ScriptBlock `
                -UnlockScriptBlock $UnlockScriptBlock `
                -RemoveScriptBlock $RemoveScriptBlock `
                -SetScriptBlock $SetScriptBlock `
                -UnregisterScriptBlock $UnregisterScriptBlock
        }

        'secretmanagement' {
            $vault | Register-PodeSecretManagementVault `
                -VaultName $VaultName `
                -ModuleName $ModuleName
        }
    }

    # create timer to clear cached secrets every minute
    Start-PodeSecretCacheHousekeeper

    # create a lockable so secrets are thread safe
    New-PodeLockable -Name $vault.LockableName

    # add vault config to context
    $PodeContext.Server.Secrets.Vaults[$Name] = $vault

    # unlock the vault?
    if (!$NoUnlock -and $vault.Unlock.Enabled) {
        Unlock-PodeSecretVault -Name $Name
    }
}


<#
.SYNOPSIS
    Remove a Secret from a Secret Vault.

.DESCRIPTION
    Remove a Secret from a Secret Vault. To remove a mounted Secret, you can pass the Remove switch to Dismount-PodeSecret.

.PARAMETER Key
    The Key/Path of the Secret within the Secret Vault.

.PARAMETER Vault
    The friendly name of the Secret Vault this Secret can be found in.

.PARAMETER ArgumentList
    An optional array of Arguments to be supplied to a custom Secret Vault's scriptblocks.

.EXAMPLE
    Remove-PodeSecret -Key 'path/to/secret' -Vault 'VaultName'
#>
function Remove-PodeSecret {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Key,

        [Parameter(Mandatory = $true)]
        [string]
        $Vault,

        [Parameter()]
        [object[]]
        $ArgumentList
    )

    # has the vault been registered?
    if (!(Test-PodeSecretVault -Name $Vault)) {
        # No Secret Vault with the name has been registered
        throw ($PodeLocale.noSecretVaultRegisteredExceptionMessage -f $Vault)
    }

    # remove the secret depending on vault type
    $_vault = $PodeContext.Server.Secrets.Vaults[$Vault]
    Lock-PodeObject -Name $_vault.LockableName -ScriptBlock {
        switch ($_vault.Type) {
            'custom' {
                Remove-PodeSecretCustomKey -Vault $Vault -Key $Key -ArgumentList $ArgumentList
            }

            'secretmanagement' {
                Remove-PodeSecretManagementKey -Vault $Vault -Key $Key
            }
        }
    }
}


<#
.SYNOPSIS
    Create/update a Secret in a Secret Vault.

.DESCRIPTION
    Create/update a Secret in a Secret Vault.

.PARAMETER Key
    The Key/Path of the Secret within the Secret Vault.

.PARAMETER Vault
    The friendly name of the Secret Vault this Secret should be created in.

.PARAMETER InputObject
    The value to use when updating the Secret.
    Only the following object types are supported: byte[], string, securestring, pscredential, hashtable.

.PARAMETER Metadata
    An optional Metadata hashtable.

.PARAMETER ArgumentList
    An optional array of Arguments to be supplied to a custom Secret Vault's scriptblocks.

.EXAMPLE
    Set-PodeSecret -Key 'path/to/secret' -Vault 'VaultName' -InputObject 'value'

.EXAMPLE
    Set-PodeSecret -Key 'key_of_secret' -Vault 'VaultName' -InputObject @{ key = value }
#>
function Set-PodeSecret {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Key,

        [Parameter(Mandatory = $true)]
        [string]
        $Vault,

        #> byte[], string, securestring, pscredential, hashtable
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [object]
        $InputObject,

        [Parameter()]
        [hashtable]
        $Metadata,

        [Parameter()]
        [object[]]
        $ArgumentList
    )
    begin {
        # has the vault been registered?
        if (!(Test-PodeSecretVault -Name $Vault)) {
            # No Secret Vault with the name has been registered
            throw ($PodeLocale.noSecretVaultRegisteredExceptionMessage -f $Vault)
        }

        $pipelineItemCount = 0  # Initialize counter to track items in the pipeline.
    }

    process {
        $pipelineItemCount++  # Increment the counter for each item in the pipeline.
    }

    end {
        # Throw an error if more than one item is passed in the pipeline.
        if ($pipelineItemCount -gt 1) {
            throw ($PodeLocale.fnDoesNotAcceptArrayAsPipelineInputExceptionMessage -f $($MyInvocation.MyCommand.Name))
        }

        # make sure the value type is correct
        $InputObject = Protect-PodeSecretValueType -Value $InputObject

        # set the secret depending on vault type
        $_vault = $PodeContext.Server.Secrets.Vaults[$Vault]
        Lock-PodeObject -Name $_vault.LockableName -ScriptBlock {
            switch ($_vault.Type) {
                'custom' {
                    Set-PodeSecretCustomKey -Vault $Vault -Key $Key -Value $InputObject -Metadata $Metadata -ArgumentList $ArgumentList
                }

                'secretmanagement' {
                    Set-PodeSecretManagementKey -Vault $Vault -Key $Key -Value $InputObject -Metadata $Metadata
                }
            }
        }
    }
}


<#
.SYNOPSIS
    Test if a Secret has been mounted.

.DESCRIPTION
    Test if a Secret has been mounted.

.PARAMETER Name
    The friendly Name of a Secret.

.EXAMPLE
    if (Test-PodeSecret -Name 'SecretName') { ... }
#>
function Test-PodeSecret {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    return (($null -ne $PodeContext.Server.Secrets.Keys) -and $PodeContext.Server.Secrets.Keys.ContainsKey($Name))
}


<#
.SYNOPSIS
    Tests if a Secret Vault has been registered.

.DESCRIPTION
    Tests if a Secret Vault has been registered.

.PARAMETER Name
    The Name of the Secret Vault to test.

.EXAMPLE
    if (Test-PodeSecretVault -Name 'VaultName') { ... }
#>
function Test-PodeSecretVault {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    return (($null -ne $PodeContext.Server.Secrets.Vaults) -and $PodeContext.Server.Secrets.Vaults.ContainsKey($Name))
}


<#
.SYNOPSIS
    Unlock the Secret Vault.

.DESCRIPTION
    Unlock the Secret Vault.

.PARAMETER Name
    The Name of the Secret Vault in Pode to be unlocked.

.EXAMPLE
    Unlock-PodeSecretVault -Name 'VaultName'
#>
function Unlock-PodeSecretVault {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    # has the vault been registered?
    if (!(Test-PodeSecretVault -Name $Name)) {
        # No Secret Vault with the name has been registered
        throw ($PodeLocale.noSecretVaultRegisteredExceptionMessage -f $Vault)
    }

    # get vault
    $vault = $PodeContext.Server.Secrets.Vaults[$Name]
    $expiry = $null

    # is unlocking even enabled?
    if (!$vault.Unlock.Enabled) {
        return
    }

    # unlock depending on vault type, and set expiry
    $expiry = Lock-PodeObject -Name $vault.LockableName -Return -ScriptBlock {
        switch ($vault.Type) {
            'custom' {
                return ($vault | Unlock-PodeSecretCustomVault)
            }

            'secretmanagement' {
                return ($vault | Unlock-PodeSecretManagementVault)
            }
        }
    }

    # if we have an expiry returned, set to UTC and configure unlock schedule
    if ($null -ne $expiry) {
        $expiry = ([datetime]$expiry).ToUniversalTime()
        if ($expiry -le [datetime]::UtcNow) {
            # Secret Vault unlock expiry date is in the past (UTC)
            throw ($PodeLocale.secretVaultUnlockExpiryDateInPastExceptionMessage -f $expiry)
        }

        $vault.Unlock.Expiry = $expiry
        Start-PodeSecretVaultUnlocker
    }
}


<#
.SYNOPSIS
    Unregister a Secret Vault.

.DESCRIPTION
    Unregister a Secret Vault. If the Vault was via the SecretManagement module it will also be unregistered there as well.

.PARAMETER Name
    The Name of the Secret Vault in Pode to unregister.

.EXAMPLE
    Unregister-PodeSecretVault -Name 'VaultName'
#>
function Unregister-PodeSecretVault {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    # has the vault been registered?
    if (!(Test-PodeSecretVault -Name $Name)) {
        return
    }

    # get vault
    $vault = $PodeContext.Server.Secrets.Vaults[$Name]

    # unlock depending on vault type, and set expiry
    switch ($vault.Type) {
        'custom' {
            $vault | Unregister-PodeSecretCustomVault
        }

        'secretmanagement' {
            $vault | Unregister-PodeSecretManagementVault
        }
    }

    # unregister from Pode
    $null = $PodeContext.Server.Secrets.Vaults.Remove($Name)
}


<#
.SYNOPSIS
    Update the value of a mounted Secret.

.DESCRIPTION
    Update the value of a mounted Secret in a Secret Vault. You can also use "$secret:<NAME> = $value" syntax in certain places.

.PARAMETER Name
    The friendly Name of a Secret.

.PARAMETER InputObject
    The value to use when updating the Secret.
    Only the following object types are supported: byte[], string, securestring, pscredential, hashtable.

.PARAMETER Metadata
    An optional Metadata hashtable.

.EXAMPLE
    Update-PodeSecret -Name 'SecretName' -InputObject @{ key = value }

.EXAMPLE
    Update-PodeSecret -Name 'SecretName' -InputObject 'value'

.EXAMPLE
    $secret:SecretName = 'value'
#>
function Update-PodeSecret {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        #> byte[], string, securestring, pscredential, hashtable
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true )]
        [object]
        $InputObject,

        [Parameter()]
        [hashtable]
        $Metadata
    )
    begin {
        # has the secret been mounted?
        if (!(Test-PodeSecret -Name $Name)) {
            # No Secret named has been mounted
            throw ($PodeLocale.noSecretNamedMountedExceptionMessage -f $Name)
        }

        $pipelineItemCount = 0  # Initialize counter to track items in the pipeline.
    }

    process {
        $pipelineItemCount++  # Increment the counter for each item in the pipeline.
    }

    end {
        # Throw an error if more than one item is passed in the pipeline.
        if ($pipelineItemCount -gt 1) {
            throw ($PodeLocale.fnDoesNotAcceptArrayAsPipelineInputExceptionMessage -f $($MyInvocation.MyCommand.Name))
        }

        # make sure the value type is correct
        $InputObject = Protect-PodeSecretValueType -Value $InputObject

        # get the secret and vault
        $secret = $PodeContext.Server.Secrets.Keys[$Name]

        # reset the cache if enabled
        if ($secret.Cache.Enabled) {
            $secret.Cache.Value = $InputObject
            $secret.Cache.Expiry = [datetime]::UtcNow.AddMinutes($secret.Cache.Ttl)
        }

        # if we're expanding a property, convert this to a hashtable
        if ($secret.Properties.Enabled -and $secret.Properties.Expand) {
            $InputObject = @{
                "$($secret.Properties.Fields)" = $InputObject
            }
        }

        # set the secret depending on vault type
        $vault = $PodeContext.Server.Secrets.Vaults[$secret.Vault]
        Lock-PodeObject -Name $vault.LockableName -ScriptBlock {
            switch ($vault.Type) {
                'custom' {
                    Set-PodeSecretCustomKey -Vault $secret.Vault -Key $secret.Key -Value $InputObject -Metadata $Metadata -ArgumentList $secret.Arguments
                }

                'secretmanagement' {
                    Set-PodeSecretManagementKey -Vault $secret.Vault -Key $secret.Key -Value $InputObject -Metadata $Metadata
                }
            }
        }
    }
}


<#
.SYNOPSIS
    Adds additional values to already defined values for the Content-Security-Policy header.

.DESCRIPTION
    Adds additional values to already defined values for the Content-Security-Policy header, instead of overriding them.

.PARAMETER Default
    The values to add for the Default portion of the header.

.PARAMETER Child
    The values to add for the Child portion of the header.

.PARAMETER Connect
    The values to add for the Connect portion of the header.

.PARAMETER Font
    The values to add for the Font portion of the header.

.PARAMETER Frame
    The values to add for the Frame portion of the header.

.PARAMETER Image
    The values to add for the Image portion of the header.

.PARAMETER Manifest
    The values to add for the Manifest portion of the header.

.PARAMETER Media
    The values to add for the Media portion of the header.

.PARAMETER Object
    The values to add for the Object portion of the header.

.PARAMETER Scripts
    The values to add for the Scripts portion of the header.

.PARAMETER Style
    The values to add for the Style portion of the header.

.PARAMETER BaseUri
    The values to add for the BaseUri portion of the header.

.PARAMETER FormAction
    The values to add for the FormAction portion of the header.

.PARAMETER FrameAncestor
    The values to add for the FrameAncestor portion of the header.

.PARAMETER FencedFrame
    The values to add for the FencedFrame portion of the header.

.PARAMETER Prefetch
    The values to add for the Prefetch portion of the header.

.PARAMETER ScriptAttr
    The values to add for the ScriptAttr portion of the header.

.PARAMETER ScriptElem
    The values to add for the ScriptElem portion of the header.

.PARAMETER StyleAttr
    The values to add for the StyleAttr portion of the header.

.PARAMETER StyleElem
    The values to add for the StyleElem portion of the header.

.PARAMETER Worker
    The values to add for the Worker portion of the header.

.PARAMETER Sandbox
    The value to use for the Sandbox portion of the header.

.PARAMETER ReportUri
    The value to use for the ReportUri portion of the header.

.PARAMETER UpgradeInsecureRequests
    If supplied, the header will have the upgrade-insecure-requests value added.

.PARAMETER ReportOnly
    If supplied, the header will be set as a report-only header.

.EXAMPLE
    Add-PodeSecurityContentSecurityPolicy -Default '*.twitter.com' -Image 'data'
#>
function Add-PodeSecurityContentSecurityPolicy {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string[]]
        $Default,

        [Parameter()]
        [string[]]
        $Child,

        [Parameter()]
        [string[]]
        $Connect,

        [Parameter()]
        [string[]]
        $Font,

        [Parameter()]
        [string[]]
        $Frame,

        [Parameter()]
        [string[]]
        $Image,

        [Parameter()]
        [string[]]
        $Manifest,

        [Parameter()]
        [string[]]
        $Media,

        [Parameter()]
        [string[]]
        $Object,

        [Parameter()]
        [string[]]
        $Scripts,

        [Parameter()]
        [string[]]
        $Style,

        [Parameter()]
        [string[]]
        $BaseUri,

        [Parameter()]
        [string[]]
        $FormAction,

        [Parameter()]
        [string[]]
        $FrameAncestor,

        [Parameter()]
        [string[]]
        $FencedFrame,

        [Parameter()]
        [string[]]
        $Prefetch,

        [Parameter()]
        [string[]]
        $ScriptAttr,

        [Parameter()]
        [string[]]
        $ScriptElem,

        [Parameter()]
        [string[]]
        $StyleAttr,

        [Parameter()]
        [string[]]
        $StyleElem,

        [Parameter()]
        [string[]]
        $Worker,

        [Parameter()]
        [ValidateSet('', 'Allow-Downloads', 'Allow-Downloads-Without-User-Activation', 'Allow-Forms', 'Allow-Modals', 'Allow-Orientation-Lock',
            'Allow-Pointer-Lock', 'Allow-Popups', 'Allow-Popups-To-Escape-Sandbox', 'Allow-Presentation', 'Allow-Same-Origin', 'Allow-Scripts',
            'Allow-Storage-Access-By-User-Activation', 'Allow-Top-Navigation', 'Allow-Top-Navigation-By-User-Activation', 'None')]
        [string]
        $Sandbox = 'None',

        [Parameter()]
        [string]
        $ReportUri,

        [switch]
        $UpgradeInsecureRequests,

        [switch]
        $ReportOnly
    )

    Set-PodeSecurityContentSecurityPolicyInternal -Params $PSBoundParameters -Append
}


<#
.SYNOPSIS
    Add definition for specified security header.

.DESCRIPTION
    Add definition for specified security header.

.PARAMETER Name
    The Name of the security header.

.PARAMETER Value
    The Value of the security header.

.PARAMETER Append
    Append the value to the header instead of replacing it

.EXAMPLE
    Add-PodeSecurityHeader -Name 'X-Header-Name' -Value 'SomeValue'
#>
function Add-PodeSecurityHeader {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [string]
        $Value,

        [Parameter()]
        [switch]
        $Append
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return
    }

    if ($Append -and $PodeContext.Server.Security.Headers.ContainsKey($Name)) {
        $Headers = @(($PodeContext.Server.Security.Headers[$Name].split(',')).trim())
        if ($Headers -inotcontains $Value) {
            $Headers += $Value
            $PodeContext.Server.Security.Headers[$Name] = (($Headers.trim() | Select-Object -Unique) -join ', ')
        }
        else {
            return
        }
    }
    else {
        $PodeContext.Server.Security.Headers[$Name] = $Value
    }
}


<#
.SYNOPSIS
    Adds additional values to already defined values for the Permissions-Policy header.

.DESCRIPTION
    Adds additional values to already defined values for the Permissions-Policy header, instead of overriding them.

.PARAMETER Accelerometer
    The values to add for the Accelerometer portion of the header.

.PARAMETER AmbientLightSensor
    The values to add for the AmbientLightSensor portion of the header.

.PARAMETER Autoplay
    The values to add for the Autoplay portion of the header.

.PARAMETER Battery
    The values to add for the Battery portion of the header.

.PARAMETER Camera
    The values to add for the Camera portion of the header.

.PARAMETER DisplayCapture
    The values to add for the DisplayCapture portion of the header.

.PARAMETER DocumentDomain
    The values to add for the DocumentDomain portion of the header.

.PARAMETER EncryptedMedia
    The values to add for the EncryptedMedia portion of the header.

.PARAMETER Fullscreen
    The values to add for the Fullscreen portion of the header.

.PARAMETER Gamepad
    The values to add for the Gamepad portion of the header.

.PARAMETER Geolocation
    The values to add for the Geolocation portion of the header.

.PARAMETER Gyroscope
    The values to add for the Gyroscope portion of the header.

.PARAMETER InterestCohort
    The values to use for the InterestCohort portal of the header.

.PARAMETER LayoutAnimations
    The values to add for the LayoutAnimations portion of the header.

.PARAMETER LegacyImageFormats
    The values to add for the LegacyImageFormats portion of the header.

.PARAMETER Magnetometer
    The values to add for the Magnetometer portion of the header.

.PARAMETER Microphone
    The values to add for the Microphone portion of the header.

.PARAMETER Midi
    The values to add for the Midi portion of the header.

.PARAMETER OversizedImages
    The values to add for the OversizedImages portion of the header.

.PARAMETER Payment
    The values to add for the Payment portion of the header.

.PARAMETER PictureInPicture
    The values to add for the PictureInPicture portion of the header.

.PARAMETER PublicKeyCredentials
    The values to add for the PublicKeyCredentials portion of the header.

.PARAMETER Speakers
    The values to add for the Speakers portion of the header.

.PARAMETER SyncXhr
    The values to add for the SyncXhr portion of the header.

.PARAMETER UnoptimisedImages
    The values to add for the UnoptimisedImages portion of the header.

.PARAMETER UnsizedMedia
    The values to add for the UnsizedMedia portion of the header.

.PARAMETER Usb
    The values to add for the Usb portion of the header.

.PARAMETER ScreenWakeLake
    The values to add for the ScreenWakeLake portion of the header.

.PARAMETER WebShare
    The values to add for the WebShare portion of the header.

.PARAMETER XrSpatialTracking
    The values to add for the XrSpatialTracking portion of the header.

.EXAMPLE
    Add-PodeSecurityPermissionsPolicy -AmbientLightSensor 'none'
#>
function Add-PodeSecurityPermissionsPolicy {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string[]]
        $Accelerometer,

        [Parameter()]
        [string[]]
        $AmbientLightSensor,

        [Parameter()]
        [string[]]
        $Autoplay,

        [Parameter()]
        [string[]]
        $Battery,

        [Parameter()]
        [string[]]
        $Camera,

        [Parameter()]
        [string[]]
        $DisplayCapture,

        [Parameter()]
        [string[]]
        $DocumentDomain,

        [Parameter()]
        [string[]]
        $EncryptedMedia,

        [Parameter()]
        [string[]]
        $Fullscreen,

        [Parameter()]
        [string[]]
        $Gamepad,

        [Parameter()]
        [string[]]
        $Geolocation,

        [Parameter()]
        [string[]]
        $Gyroscope,

        [Parameter()]
        [string[]]
        $InterestCohort,

        [Parameter()]
        [string[]]
        $LayoutAnimations,

        [Parameter()]
        [string[]]
        $LegacyImageFormats,

        [Parameter()]
        [string[]]
        $Magnetometer,

        [Parameter()]
        [string[]]
        $Microphone,

        [Parameter()]
        [string[]]
        $Midi,

        [Parameter()]
        [string[]]
        $OversizedImages,

        [Parameter()]
        [string[]]
        $Payment,

        [Parameter()]
        [string[]]
        $PictureInPicture,

        [Parameter()]
        [string[]]
        $PublicKeyCredentials,

        [Parameter()]
        [string[]]
        $Speakers,

        [Parameter()]
        [string[]]
        $SyncXhr,

        [Parameter()]
        [string[]]
        $UnoptimisedImages,

        [Parameter()]
        [string[]]
        $UnsizedMedia,

        [Parameter()]
        [string[]]
        $Usb,

        [Parameter()]
        [string[]]
        $ScreenWakeLake,

        [Parameter()]
        [string[]]
        $WebShare,

        [Parameter()]
        [string[]]
        $XrSpatialTracking
    )

    Set-PodeSecurityPermissionsPolicyInternal -Params $PSBoundParameters -Append
}


<#
.SYNOPSIS
    Hide the Server HTTP Header from Responses

.DESCRIPTION
    Hide the Server HTTP Header from Responses

.EXAMPLE
    Hide-PodeSecurityServer
#>
function Hide-PodeSecurityServer {
    [CmdletBinding()]
    param()

    $PodeContext.Server.Security.ServerDetails = $false
}


<#
.SYNOPSIS
    Removes definitions for all security headers.

.DESCRIPTION
    Removes definitions for all security headers.

.EXAMPLE
    Remove-PodeSecurity
#>
function Remove-PodeSecurity {
    [CmdletBinding()]
    param()

    $PodeContext.Server.Security.Headers.Clear()
    Show-PodeSecurityServer
}


<#
.SYNOPSIS
    Removes definitions for the Access-Control headers.

.DESCRIPTION
    Removes definitions for the Access-Control headers: Access-Control-Allow-Origin, Access-Control-Allow-Methods, Access-Control-Allow-Headers, Access-Control-Max-Age, Access-Control-Allow-Credentials

.EXAMPLE
    Remove-PodeSecurityAccessControl
#>
function Remove-PodeSecurityAccessControl {
    [CmdletBinding()]
    param()

    Remove-PodeSecurityHeader -Name 'Access-Control-Allow-Origin'
    Remove-PodeSecurityHeader -Name 'Access-Control-Allow-Methods'
    Remove-PodeSecurityHeader -Name 'Access-Control-Allow-Headers'
    Remove-PodeSecurityHeader -Name 'Access-Control-Max-Age'
    Remove-PodeSecurityHeader -Name 'Access-Control-Allow-Credentials'
}


<#
.SYNOPSIS
    Removes definition for the Content-Security-Policy and X-XSS-Protection headers.

.DESCRIPTION
    Removes definition for the Content-Security-Policy and X-XSS-Protection headers.

.EXAMPLE
    Remove-PodeSecurityContentSecurityPolicy
#>
function Remove-PodeSecurityContentSecurityPolicy {
    [CmdletBinding()]
    param()

    Remove-PodeSecurityHeader -Name 'Content-Security-Policy'
    Remove-PodeSecurityHeader -Name 'X-XSS-Protection'
}


<#
.SYNOPSIS
    Removes definition for the X-Content-Type-Options header.

.DESCRIPTION
    Removes definitions for the X-Content-Type-Options header.

.EXAMPLE
    Remove-PodeSecurityContentTypeOptions
#>
function Remove-PodeSecurityContentTypeOptions {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    [CmdletBinding()]
    param()

    Remove-PodeSecurityHeader -Name 'X-Content-Type-Options'
}


<#
.SYNOPSIS
    Removes definitions for the Cross-Origin headers.

.DESCRIPTION
    Removes definitions for the Cross-Origin headers: Cross-Origin-Embedder-Policy, Cross-Origin-Opener-Policy, Cross-Origin-Resource-Policy

.EXAMPLE
    Remove-PodeSecurityCrossOrigin
#>
function Remove-PodeSecurityCrossOrigin {
    [CmdletBinding()]
    param()

    Remove-PodeSecurityHeader -Name 'Cross-Origin-Embedder-Policy'
    Remove-PodeSecurityHeader -Name 'Cross-Origin-Opener-Policy'
    Remove-PodeSecurityHeader -Name 'Cross-Origin-Resource-Policy'
}


<#
.SYNOPSIS
    Removes definition for the X-Frame-Options header.

.DESCRIPTION
    Removes definition for the X-Frame-Options header.

.EXAMPLE
    Remove-PodeSecurityFrameOptions
#>
function Remove-PodeSecurityFrameOptions {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    [CmdletBinding()]
    param()

    Remove-PodeSecurityHeader -Name 'X-Frame-Options'
}


<#
.SYNOPSIS
    Removes definition for specified security header.

.DESCRIPTION
    Removes definition for specified security header.

.PARAMETER Name
    The Name of the security header.

.EXAMPLE
    Remove-PodeSecurityHeader -Name 'X-Header-Name'
#>
function Remove-PodeSecurityHeader {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    $PodeContext.Server.Security.Headers.Remove($Name)
}


<#
.SYNOPSIS
    Removes definition for the Permissions-Policy header.

.DESCRIPTION
    Removes definitions for the Permissions-Policy header.

.EXAMPLE
    Remove-PodeSecurityPermissionsPolicy
#>
function Remove-PodeSecurityPermissionsPolicy {
    [CmdletBinding()]
    param()

    Remove-PodeSecurityHeader -Name 'Permissions-Policy'
}


<#
.SYNOPSIS
    Removes definition for the Referrer-Policy header.

.DESCRIPTION
    Removes definitions for the Referrer-Policy header.

.EXAMPLE
    Remove-PodeSecurityReferrerPolicy
#>
function Remove-PodeSecurityReferrerPolicy {
    [CmdletBinding()]
    param()

    Remove-PodeSecurityHeader -Name 'Referrer-Policy'
}


<#
.SYNOPSIS
    Removes definition for the Strict-Transport-Security header.

.DESCRIPTION
    Removes definitions for the Strict-Transport-Security header.

.EXAMPLE
    Remove-PodeSecurityStrictTransportSecurity
#>
function Remove-PodeSecurityStrictTransportSecurity {
    [CmdletBinding()]
    param()

    Remove-PodeSecurityHeader -Name 'Strict-Transport-Security'
}


<#
.SYNOPSIS
    Sets inbuilt definitions for security headers.

.DESCRIPTION
    Sets inbuilt definitions for security headers, in either Simple or Strict types.

.PARAMETER Type
    The Type of security to use.

.PARAMETER UseHsts
    If supplied, the Strict-Transport-Security header will be set.

.PARAMETER XssBlock
    If supplied, the X-XSS-Protection header will be set to blocking mode. (Default: Off)

.PARAMETER CspReportOnly
    If supplied, the Content-Security-Policy header will be set as the Content-Security-Policy-Report-Only header.

.EXAMPLE
    Set-PodeSecurity -Type Simple

.EXAMPLE
    Set-PodeSecurity -Type Strict -UseHsts
#>
function Set-PodeSecurity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Simple', 'Strict')]
        [string]
        $Type,

        [switch]
        $UseHsts,

        [switch]
        $XssBlock,

        [switch]
        $CspReportOnly
    )

    # general headers
    Set-PodeSecurityContentTypeOptions

    Set-PodeSecurityPermissionsPolicy `
        -SyncXhr 'none' `
        -Fullscreen 'self' `
        -Camera 'none' `
        -Geolocation 'self' `
        -PictureInPicture 'self' `
        -Accelerometer 'none' `
        -Microphone 'none' `
        -Usb 'none' `
        -Autoplay 'self' `
        -Payment 'none' `
        -Magnetometer 'self' `
        -Gyroscope 'self' `
        -DisplayCapture 'self'

    Set-PodeSecurityCrossOrigin -Embed Require-Corp -Open Same-Origin -Resource Same-Origin
    Set-PodeSecurityAccessControl -Origin '*' -Methods '*' -Headers '*' -Duration 7200
    Set-PodeSecurityContentSecurityPolicy -Default 'self' -XssBlock:$XssBlock -ReportOnly:$CspReportOnly

    # only add hsts if specifiec
    if ($UseHsts) {
        Set-PodeSecurityStrictTransportSecurity -Duration 31536000 -IncludeSubDomains
    }

    # type specific headers
    switch ($Type.ToLowerInvariant()) {
        'simple' {
            Set-PodeSecurityFrameOptions -Type SameOrigin
            Set-PodeSecurityReferrerPolicy -Type Strict-Origin
        }

        'strict' {
            Set-PodeSecurityFrameOptions -Type Deny
            Set-PodeSecurityReferrerPolicy -Type No-Referrer
        }
    }

    # hide server info
    Hide-PodeSecurityServer
}


<#
.SYNOPSIS
    Set definitions for Access-Control headers.

.DESCRIPTION
    Removes definitions for the Access-Control headers: Access-Control-Allow-Origin, Access-Control-Allow-Methods, Access-Control-Allow-Headers, Access-Control-Max-Age, Access-Control-Allow-Credentials

.PARAMETER Origin
    Specifies a value for Access-Control-Allow-Origin.

.PARAMETER Methods
    Specifies a value for Access-Control-Allow-Methods.

.PARAMETER Headers
    Specifies a value for Access-Control-Allow-Headers.

.PARAMETER Duration
    Specifies a value for Access-Control-Max-Age in seconds. (Default: 7200)
    Use a value of one for debugging any CORS related issues

.PARAMETER Credentials
    Specifies a value for Access-Control-Allow-Credentials

.PARAMETER WithOptions
    If supplied, a global Options Route will be created.

.PARAMETER AuthorizationHeader
    Add 'Authorization' to the headers list

.PARAMETER AutoHeaders
    Automatically populate the list of allowed Headers based on the OpenApi definition.
    This parameter can works in conjuntion with CrossDomainXhrRequests,AuthorizationHeader and Headers (Headers cannot be '*').
    By default add  'content-type' to the headers

.PARAMETER AutoMethods
    Automatically populate the list of allowed Methods based on the defined Routes.
    This parameter can works in conjuntion with the parameter Methods, if Methods is not including '*'

.PARAMETER CrossDomainXhrRequests
    Add 'x-requested-with' to the list of allowed headers
    More info available here:
    https://fetch.spec.whatwg.org/
    https://learn.microsoft.com/en-us/aspnet/core/security/cors?view=aspnetcore-7.0#credentials-in-cross-origin-requests
    https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS

.EXAMPLE
    Set-PodeSecurityAccessControl -Origin '*' -Methods '*' -Headers '*' -Duration 7200
#>
function Set-PodeSecurityAccessControl {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Origin,

        [Parameter()]
        [ValidateSet('', 'Connect', 'Delete', 'Get', 'Head', 'Merge', 'Options', 'Patch', 'Post', 'Put', 'Trace', '*')]
        [string[]]
        $Methods = '',

        [Parameter()]
        [string[]]
        $Headers,

        [Parameter()]
        [int]
        $Duration = 7200,

        [switch]
        $Credentials,

        [switch]
        $WithOptions,

        [switch]
        $AuthorizationHeader,

        [switch]
        $AutoHeaders,

        [switch]
        $AutoMethods,

        [switch]
        $CrossDomainXhrRequests
    )

    # origin
    Add-PodeSecurityHeader -Name 'Access-Control-Allow-Origin' -Value $Origin

    # methods
    if (![string]::IsNullOrWhiteSpace($Methods)) {
        if ($Methods -icontains '*') {
            Add-PodeSecurityHeader -Name 'Access-Control-Allow-Methods' -Value '*'
        }
        else {
            Add-PodeSecurityHeader -Name 'Access-Control-Allow-Methods' -Value ($Methods -join ', ')
        }
    }

    # headers
    if (![string]::IsNullOrWhiteSpace($Headers) -or $AuthorizationHeader -or $CrossDomainXhrRequests) {
        if ($Headers -icontains '*') {
            if ($Credentials) {
                # When Credentials is passed, The * wildcard for Headers will be taken as a literal string and not a wildcard
                throw ($PodeLocale.credentialsPassedWildcardForHeadersLiteralExceptionMessage)
            }

            $Headers = @('*')
        }

        if ($AuthorizationHeader) {
            if ([string]::IsNullOrWhiteSpace($Headers)) {
                $Headers = @()
            }

            $Headers += 'Authorization'
        }

        if ($CrossDomainXhrRequests) {
            if ([string]::IsNullOrWhiteSpace($Headers)) {
                $Headers = @()
            }
            $Headers += 'x-requested-with'
        }
        Add-PodeSecurityHeader -Name 'Access-Control-Allow-Headers' -Value (($Headers | Select-Object -Unique) -join ', ')
    }

    if ($AutoHeaders) {
        if ($Headers -icontains '*') {
            # The * wildcard for Headers is incompatible with the AutoHeaders switch
            throw ($PodeLocale.wildcardHeadersIncompatibleWithAutoHeadersExceptionMessage)
        }

        Add-PodeSecurityHeader -Name 'Access-Control-Allow-Headers' -Value 'content-type' -Append
        $PodeContext.Server.Security.autoHeaders = $true
    }

    if ($AutoMethods) {
        if ($Methods -icontains '*') {
            # The * wildcard for Methods is incompatible with the AutoMethods switch
            throw ($PodeLocale.wildcardMethodsIncompatibleWithAutoMethodsExceptionMessage)
        }
        if ($WithOptions) {
            Add-PodeSecurityHeader -Name 'Access-Control-Allow-Methods' -Value 'Options' -Append
        }
        $PodeContext.Server.Security.autoMethods = $true
    }

    # duration
    if ($Duration -le 0) {
        # Invalid Access-Control-Max-Age duration supplied
        throw ($PodeLocale.invalidAccessControlMaxAgeDurationExceptionMessage -f $Duration)
    }

    Add-PodeSecurityHeader -Name 'Access-Control-Max-Age' -Value $Duration

    # creds
    if ($Credentials) {
        Add-PodeSecurityHeader -Name 'Access-Control-Allow-Credentials' -Value 'true'
    }

    # opts route
    if ($WithOptions) {
        Add-PodeRoute -Method Options -Path * -ScriptBlock {
            Set-PodeResponseStatus -Code 200
        }
    }
}


<#
.SYNOPSIS
    Set the value to use for the Content-Security-Policy and X-XSS-Protection headers.

.DESCRIPTION
    Set the value to use for the Content-Security-Policy and X-XSS-Protection headers.

.PARAMETER Default
    The values to use for the Default portion of the header.

.PARAMETER Child
    The values to use for the Child portion of the header.

.PARAMETER Connect
    The values to use for the Connect portion of the header.

.PARAMETER Font
    The values to use for the Font portion of the header.

.PARAMETER Frame
    The values to use for the Frame portion of the header.

.PARAMETER Image
    The values to use for the Image portion of the header.

.PARAMETER Manifest
    The values to use for the Manifest portion of the header.

.PARAMETER Media
    The values to use for the Media portion of the header.

.PARAMETER Object
    The values to use for the Object portion of the header.

.PARAMETER Scripts
    The values to use for the Scripts portion of the header.

.PARAMETER Style
    The values to use for the Style portion of the header.

.PARAMETER BaseUri
    The values to use for the BaseUri portion of the header.

.PARAMETER FormAction
    The values to use for the FormAction portion of the header.

.PARAMETER FrameAncestor
    The values to use for the FrameAncestor portion of the header.

.PARAMETER FencedFrame
    The values to use for the FencedFrame portion of the header.

.PARAMETER Prefetch
    The values to use for the Prefetch portion of the header.

.PARAMETER ScriptAttr
    The values to use for the ScriptAttr portion of the header.

.PARAMETER ScriptElem
    The values to use for the ScriptElem portion of the header.

.PARAMETER StyleAttr
    The values to use for the StyleAttr portion of the header.

.PARAMETER StyleElem
    The values to use for the StyleElem portion of the header.

.PARAMETER Worker
    The values to use for the Worker portion of the header.

.PARAMETER Sandbox
    The value to use for the Sandbox portion of the header.

.PARAMETER ReportUri
    The value to use for the ReportUri portion of the header.

.PARAMETER UpgradeInsecureRequests
    If supplied, the header will have the upgrade-insecure-requests value added.

.PARAMETER XssBlock
    If supplied, the X-XSS-Protection header will be set to blocking mode. (Default: Off)

.PARAMETER ReportOnly
    If supplied, the header will be set as a report-only header.

.EXAMPLE
    Set-PodeSecurityContentSecurityPolicy -Default 'self'
#>
function Set-PodeSecurityContentSecurityPolicy {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string[]]
        $Default,

        [Parameter()]
        [string[]]
        $Child,

        [Parameter()]
        [string[]]
        $Connect,

        [Parameter()]
        [string[]]
        $Font,

        [Parameter()]
        [string[]]
        $Frame,

        [Parameter()]
        [string[]]
        $Image,

        [Parameter()]
        [string[]]
        $Manifest,

        [Parameter()]
        [string[]]
        $Media,

        [Parameter()]
        [string[]]
        $Object,

        [Parameter()]
        [string[]]
        $Scripts,

        [Parameter()]
        [string[]]
        $Style,

        [Parameter()]
        [string[]]
        $BaseUri,

        [Parameter()]
        [string[]]
        $FormAction,

        [Parameter()]
        [string[]]
        $FrameAncestor,

        [Parameter()]
        [string[]]
        $FencedFrame,

        [Parameter()]
        [string[]]
        $Prefetch,

        [Parameter()]
        [string[]]
        $ScriptAttr,

        [Parameter()]
        [string[]]
        $ScriptElem,

        [Parameter()]
        [string[]]
        $StyleAttr,

        [Parameter()]
        [string[]]
        $StyleElem,

        [Parameter()]
        [string[]]
        $Worker,

        [Parameter()]
        [ValidateSet('', 'Allow-Downloads', 'Allow-Downloads-Without-User-Activation', 'Allow-Forms', 'Allow-Modals', 'Allow-Orientation-Lock',
            'Allow-Pointer-Lock', 'Allow-Popups', 'Allow-Popups-To-Escape-Sandbox', 'Allow-Presentation', 'Allow-Same-Origin', 'Allow-Scripts',
            'Allow-Storage-Access-By-User-Activation', 'Allow-Top-Navigation', 'Allow-Top-Navigation-By-User-Activation', 'None')]
        [string]
        $Sandbox = 'None',

        [Parameter()]
        [string]
        $ReportUri,

        [switch]
        $UpgradeInsecureRequests,

        [switch]
        $XssBlock,

        [switch]
        $ReportOnly
    )

    Set-PodeSecurityContentSecurityPolicyInternal -Params $PSBoundParameters
}


<#
.SYNOPSIS
    Set a value for the X-Content-Type-Options header.

.DESCRIPTION
    Set a value for the X-Content-Type-Options header to "nosniff".

.EXAMPLE
    Set-PodeSecurityContentTypeOptions
#>
function Set-PodeSecurityContentTypeOptions {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    [CmdletBinding()]
    param()

    Add-PodeSecurityHeader -Name 'X-Content-Type-Options' -Value 'nosniff'
}


<#
.SYNOPSIS
    Removes definitions for the Cross-Origin headers.

.DESCRIPTION
    Removes definitions for the Cross-Origin headers: Cross-Origin-Embedder-Policy, Cross-Origin-Opener-Policy, Cross-Origin-Resource-Policy

.PARAMETER Embed
    Specifies a value for Cross-Origin-Embedder-Policy.

.PARAMETER Open
    Specifies a value for Cross-Origin-Opener-Policy.

.PARAMETER Resource
    Specifies a value for Cross-Origin-Resource-Policy.

.EXAMPLE
    Set-PodeSecurityCrossOrigin -Embed Require-Corp -Open Same-Origin -Resource Same-Origin
#>
function Set-PodeSecurityCrossOrigin {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateSet('', 'Unsafe-None', 'Require-Corp')]
        [string]
        $Embed = '',

        [Parameter()]
        [ValidateSet('', 'Unsafe-None', 'Same-Origin-Allow-Popups', 'Same-Origin')]
        [string]
        $Open = '',

        [Parameter()]
        [ValidateSet('', 'Same-Site', 'Same-Origin', 'Cross-Origin')]
        [string]
        $Resource = ''
    )

    Add-PodeSecurityHeader -Name 'Cross-Origin-Embedder-Policy' -Value $Embed.ToLowerInvariant()
    Add-PodeSecurityHeader -Name 'Cross-Origin-Opener-Policy' -Value $Open.ToLowerInvariant()
    Add-PodeSecurityHeader -Name 'Cross-Origin-Resource-Policy' -Value $Resource.ToLowerInvariant()
}


<#
.SYNOPSIS
    Set a value for the X-Frame-Options header.

.DESCRIPTION
    Set a value for the X-Frame-Options header.

.PARAMETER Type
    The Type to use.

.EXAMPLE
    Set-PodeSecurityFrameOptions -Type SameOrigin
#>
function Set-PodeSecurityFrameOptions {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Deny', 'SameOrigin')]
        [string]
        $Type
    )

    Add-PodeSecurityHeader -Name 'X-Frame-Options' -Value $Type.ToUpperInvariant()
}


<#
.SYNOPSIS
    Set the value to use for the Permissions-Policy header.

.DESCRIPTION
    Set the value to use for the Permissions-Policy header.

.PARAMETER Accelerometer
    The values to use for the Accelerometer portion of the header.

.PARAMETER AmbientLightSensor
    The values to use for the AmbientLightSensor portion of the header.

.PARAMETER Autoplay
    The values to use for the Autoplay portion of the header.

.PARAMETER Battery
    The values to use for the Battery portion of the header.

.PARAMETER Camera
    The values to use for the Camera portion of the header.

.PARAMETER DisplayCapture
    The values to use for the DisplayCapture portion of the header.

.PARAMETER DocumentDomain
    The values to use for the DocumentDomain portion of the header.

.PARAMETER EncryptedMedia
    The values to use for the EncryptedMedia portion of the header.

.PARAMETER Fullscreen
    The values to use for the Fullscreen portion of the header.

.PARAMETER Gamepad
    The values to use for the Gamepad portion of the header.

.PARAMETER Geolocation
    The values to use for the Geolocation portion of the header.

.PARAMETER Gyroscope
    The values to use for the Gyroscope portion of the header.

.PARAMETER InterestCohort
    The values to use for the InterestCohort portal of the header.

.PARAMETER LayoutAnimations
    The values to use for the LayoutAnimations portion of the header.

.PARAMETER LegacyImageFormats
    The values to use for the LegacyImageFormats portion of the header.

.PARAMETER Magnetometer
    The values to use for the Magnetometer portion of the header.

.PARAMETER Microphone
    The values to use for the Microphone portion of the header.

.PARAMETER Midi
    The values to use for the Midi portion of the header.

.PARAMETER OversizedImages
    The values to use for the OversizedImages portion of the header.

.PARAMETER Payment
    The values to use for the Payment portion of the header.

.PARAMETER PictureInPicture
    The values to use for the PictureInPicture portion of the header.

.PARAMETER PublicKeyCredentials
    The values to use for the PublicKeyCredentials portion of the header.

.PARAMETER Speakers
    The values to use for the Speakers portion of the header.

.PARAMETER SyncXhr
    The values to use for the SyncXhr portion of the header.

.PARAMETER UnoptimisedImages
    The values to use for the UnoptimisedImages portion of the header.

.PARAMETER UnsizedMedia
    The values to use for the UnsizedMedia portion of the header.

.PARAMETER Usb
    The values to use for the Usb portion of the header.

.PARAMETER ScreenWakeLake
    The values to use for the ScreenWakeLake portion of the header.

.PARAMETER WebShare
    The values to use for the WebShare portion of the header.

.PARAMETER XrSpatialTracking
    The values to use for the XrSpatialTracking portion of the header.

#>
function Set-PodeSecurityPermissionsPolicy {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSPossibleIncorrectComparisonWithNull', '')]
    [CmdletBinding()]
    param(
        [Parameter()]
        [string[]]
        $Accelerometer,

        [Parameter()]
        [string[]]
        $AmbientLightSensor,

        [Parameter()]
        [string[]]
        $Autoplay,

        [Parameter()]
        [string[]]
        $Battery,

        [Parameter()]
        [string[]]
        $Camera,

        [Parameter()]
        [string[]]
        $DisplayCapture,

        [Parameter()]
        [string[]]
        $DocumentDomain,

        [Parameter()]
        [string[]]
        $EncryptedMedia,

        [Parameter()]
        [string[]]
        $Fullscreen,

        [Parameter()]
        [string[]]
        $Gamepad,

        [Parameter()]
        [string[]]
        $Geolocation,

        [Parameter()]
        [string[]]
        $Gyroscope,

        [Parameter()]
        [string[]]
        $InterestCohort,

        [Parameter()]
        [string[]]
        $LayoutAnimations,

        [Parameter()]
        [string[]]
        $LegacyImageFormats,

        [Parameter()]
        [string[]]
        $Magnetometer,

        [Parameter()]
        [string[]]
        $Microphone,

        [Parameter()]
        [string[]]
        $Midi,

        [Parameter()]
        [string[]]
        $OversizedImages,

        [Parameter()]
        [string[]]
        $Payment,

        [Parameter()]
        [string[]]
        $PictureInPicture,

        [Parameter()]
        [string[]]
        $PublicKeyCredentials,

        [Parameter()]
        [string[]]
        $Speakers,

        [Parameter()]
        [string[]]
        $SyncXhr,

        [Parameter()]
        [string[]]
        $UnoptimisedImages,

        [Parameter()]
        [string[]]
        $UnsizedMedia,

        [Parameter()]
        [string[]]
        $Usb,

        [Parameter()]
        [string[]]
        $ScreenWakeLake,

        [Parameter()]
        [string[]]
        $WebShare,

        [Parameter()]
        [string[]]
        $XrSpatialTracking
    )

    Set-PodeSecurityPermissionsPolicyInternal -Params $PSBoundParameters
}


<#
.SYNOPSIS
    Set a value for the Referrer-Policy header.

.DESCRIPTION
    Set a value for the Referrer-Policy header.

.PARAMETER Type
    The Type to use.

.EXAMPLE
    Set-PodeSecurityReferrerPolicy -Type No-Referrer
#>
function Set-PodeSecurityReferrerPolicy {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('No-Referrer', 'No-Referrer-When-Downgrade', 'Same-Origin', 'Origin', 'Strict-Origin',
            'Origin-When-Cross-Origin', 'Strict-Origin-When-Cross-Origin', 'Unsafe-Url')]
        [string]
        $Type
    )

    Add-PodeSecurityHeader -Name 'Referrer-Policy' -Value $Type.ToLowerInvariant()
}


<#
.SYNOPSIS
    Set a value for the Strict-Transport-Security header.

.DESCRIPTION
    Set a value for the Strict-Transport-Security header.

.PARAMETER Duration
    The Duration the browser to respect the header in seconds. (Default: 1 year)

.PARAMETER IncludeSubDomains
    If supplied, the header will have includeSubDomains.

.EXAMPLE
    Set-PodeSecurityStrictTransportSecurity -Duration 86400 -IncludeSubDomains
#>
function Set-PodeSecurityStrictTransportSecurity {
    [CmdletBinding()]
    param(
        [Parameter()]
        [int]
        $Duration = 31536000,

        [switch]
        $IncludeSubDomains
    )

    if ($Duration -le 0) {
        # Invalid Strict-Transport-Security duration supplied
        throw ($PodeLocale.invalidStrictTransportSecurityDurationExceptionMessage -f $Duration)
    }

    $value = "max-age=$($Duration)"

    if ($IncludeSubDomains) {
        $value += '; includeSubDomains'
    }

    Add-PodeSecurityHeader -Name 'Strict-Transport-Security' -Value $value
}


<#
.SYNOPSIS
    Show the Server HTTP Header on Responses

.DESCRIPTION
    Show the Server HTTP Header on Responses

.EXAMPLE
    Show-PodeSecurityServer
#>
function Show-PodeSecurityServer {
    [CmdletBinding()]
    param()

    $PodeContext.Server.Security.ServerDetails = $true
}


<#
.SYNOPSIS
    Enables Middleware for creating, retrieving and using Sessions within Pode.

.DESCRIPTION
    Enables Middleware for creating, retrieving and using Sessions within Pode; with support for defining Session duration, and custom Storage.
    If you're storing sessions outside of Pode, you must supply a Secret value so sessions aren't corrupted.

.PARAMETER Secret
    An optional Secret to use when signing Sessions (Default: random GUID).

.PARAMETER Name
    The name of the cookie/header used for the Session.

.PARAMETER Duration
    The duration a Session should last for, before being expired.

.PARAMETER Generator
    A custom ScriptBlock to generate a random unique SessionId. The value returned must be a String.

.PARAMETER Storage
    A custom PSObject that defines methods for Delete, Get, and Set. This allow you to store Sessions in custom Storage such as Redis. A Secret is required.

.PARAMETER Scope
    The Scope that the Session applies to, possible values are Browser and Tab (Default: Browser).
    The Browser scope is the default logic, where authentication and general data for the sessions are shared across all tabs.
    The Tab scope keep the authentication data shared across all tabs, but general data is separated across different tabs.
    For the Tab scope, the "Tab ID" required will be sourced from the "X-PODE-SESSION-TAB-ID" header.

.PARAMETER Extend
    If supplied, the Sessions will have their durations extended on each successful Request.

.PARAMETER HttpOnly
    If supplied, the Session cookie will only be accessible to browsers.

.PARAMETER Secure
    If supplied, the Session cookie will only be accessible over HTTPS Requests.

.PARAMETER Strict
    If supplied, the Secret will be extended using the client request's UserAgent and RemoteIPAddress.

.PARAMETER UseHeaders
    If supplied, Sessions will be sent back in a header on the Response with the Name supplied.

.EXAMPLE
    Enable-PodeSessionMiddleware -Duration 120

.EXAMPLE
    Enable-PodeSessionMiddleware -Duration 120 -Extend -Generator { return [System.IO.Path]::GetRandomFileName() }

.EXAMPLE
    Enable-PodeSessionMiddleware -Secret 'schwifty' -Duration 120 -UseHeaders -Strict
#>
function Enable-PodeSessionMiddleware {
    [CmdletBinding(DefaultParameterSetName = 'Cookies')]
    param(
        [Parameter()]
        [string]
        $Secret,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name = 'pode.sid',

        [Parameter()]
        [ValidateScript({
                if ($_ -lt 0) {
                    # Duration must be 0 or greater, but got
                    throw ($PodeLocale.durationMustBeZeroOrGreaterExceptionMessage -f $_)
                }

                return $true
            })]
        [int]
        $Duration = 0,

        [Parameter()]
        [scriptblock]
        $Generator,

        [Parameter()]
        [psobject]
        $Storage = $null,

        [Parameter()]
        [ValidateSet('Browser', 'Tab')]
        [string]
        $Scope = 'Browser',

        [switch]
        $Extend,

        [Parameter(ParameterSetName = 'Cookies')]
        [switch]
        $HttpOnly,

        [Parameter(ParameterSetName = 'Cookies')]
        [switch]
        $Secure,

        [switch]
        $Strict,

        [Parameter(ParameterSetName = 'Headers')]
        [switch]
        $UseHeaders
    )

    # check that session logic hasn't already been initialised
    if (Test-PodeSessionsEnabled) {
        # Session Middleware has already been initialized
        throw ($PodeLocale.sessionMiddlewareAlreadyInitializedExceptionMessage)
    }

    # ensure the override store has the required methods
    if (!(Test-PodeIsEmpty $Storage)) {
        $members = @($Storage | Get-Member | Select-Object -ExpandProperty Name)
        @('delete', 'get', 'set') | ForEach-Object {
            if ($members -inotcontains $_) {
                # The custom session storage does not implement the required '{0}()' method
                throw ($PodeLocale.customSessionStorageMethodNotImplementedExceptionMessage -f $_)
            }
        }
    }

    # verify the secret, set to guid if not supplied, or error if none and we have a storage
    if ([string]::IsNullOrEmpty($Secret)) {
        if (!(Test-PodeIsEmpty $Storage)) {
            # A Secret is required when using custom session storage
            throw ($PodeLocale.secretRequiredForCustomSessionStorageExceptionMessage)
        }

        $Secret = Get-PodeServerDefaultSecret
    }

    # if no custom storage, use the inmem one
    if (Test-PodeIsEmpty $Storage) {
        $Storage = (Get-PodeSessionInMemStore)
        Set-PodeSessionInMemClearDown
    }

    # set options against server context
    $PodeContext.Server.Sessions = @{
        Name       = $Name
        Secret     = $Secret
        GenerateId = (Protect-PodeValue -Value $Generator -Default { return (New-PodeGuid) })
        Store      = $Storage
        Info       = @{
            Duration   = $Duration
            Extend     = $Extend.IsPresent
            Secure     = $Secure.IsPresent
            Strict     = $Strict.IsPresent
            HttpOnly   = $HttpOnly.IsPresent
            UseHeaders = $UseHeaders.IsPresent
            Scope      = @{
                Type      = $Scope.ToLowerInvariant()
                IsBrowser = ($Scope -ieq 'Browser')
            }
        }
    }

    # return scriptblock for the session middleware
    Get-PodeSessionMiddleware |
        New-PodeMiddleware |
        Add-PodeMiddleware -Name '__pode_mw_sessions__'
}


<#
.SYNOPSIS
    Returns the defined Session duration.

.DESCRIPTION
    Returns the defined Session duration that all Session are created using.

.EXAMPLE
    $duration = Get-PodeSessionDuration
#>
function Get-PodeSessionDuration {
    [CmdletBinding()]
    [OutputType([int])]
    param()

    return [int]$PodeContext.Server.Sessions.Info.Duration
}


<#
.SYNOPSIS
    Returns the datetime on which the current Session's will expire.

.DESCRIPTION
    Returns the datetime on which the current Session's will expire.

.EXAMPLE
    $expiry = Get-PodeSessionExpiry
#>
function Get-PodeSessionExpiry {
    [CmdletBinding()]
    [OutputType([datetime])]
    param()

    # error if session is null
    if ($null -eq $WebEvent.Session) {
        # There is no session available to save
        throw ($PodeLocale.noSessionAvailableToSaveExceptionMessage)
    }

    # default min date
    if ($null -eq $WebEvent.Session.TimeStamp) {
        return [datetime]::MinValue
    }

    # use datetime.now or existing timestamp?
    $expiry = [DateTime]::UtcNow

    if (!$WebEvent.Session.Extend -and ($null -ne $WebEvent.Session.TimeStamp)) {
        $expiry = $WebEvent.Session.TimeStamp
    }

    # add session duration on
    $expiry = $expiry.AddSeconds($PodeContext.Server.Sessions.Info.Duration)

    # return expiry
    return $expiry
}


<#
.SYNOPSIS
    Returns the currently authenticated SessionId.

.DESCRIPTION
    Returns the currently authenticated SessionId. If there's no session, or it's not authenticated, then null is returned instead.
    You can also have the SessionId returned as signed as well.

.PARAMETER Signed
    If supplied, the returned SessionId will also be signed.

.PARAMETER Force
    If supplied, the sessionId will be returned regardless of authentication.

.EXAMPLE
    $sessionId = Get-PodeSessionId
#>
function Get-PodeSessionId {
    [CmdletBinding()]
    param(
        [switch]
        $Signed,

        [switch]
        $Force
    )

    $sessionId = $null

    # do nothing if not authenticated, or force passed
    if (!$Force -and ((Test-PodeIsEmpty $WebEvent.Session.Data.Auth.User) -or !$WebEvent.Session.Data.Auth.IsAuthenticated)) {
        return $sessionId
    }

    # get the sessionId
    $sessionId = $WebEvent.Session.FullId

    # do they want the session signed?
    if ($Signed) {
        $strict = $PodeContext.Server.Sessions.Info.Strict
        $secret = $PodeContext.Server.Sessions.Secret

        # sign the value if we have a secret
        $sessionId = (Invoke-PodeValueSign -Value $sessionId -Secret $secret -Strict:$strict)
    }

    # return the ID
    return $sessionId
}


function Get-PodeSessionInfo {
    return $PodeContext.Server.Sessions.Info
}


function Get-PodeSessionTabId {
    [CmdletBinding()]
    param()

    if ($PodeContext.Server.Sessions.Info.Scope.IsBrowser) {
        return $null
    }

    return Get-PodeHeader -Name 'X-PODE-SESSION-TAB-ID'
}


<#
.SYNOPSIS
    Remove the current Session, logging it out.

.DESCRIPTION
    Remove the current Session, logging it out. This will remove the session from Storage, and Cookies.

.EXAMPLE
    Remove-PodeSession
#>
function Remove-PodeSession {
    [CmdletBinding()]
    param()

    # if sessions haven't been setup, error
    if (!(Test-PodeSessionsEnabled)) {
        # The sessions have not been configured
        throw ($PodeLocale.sessionsNotConfiguredExceptionMessage)
    }

    # do nothing if session is null
    if ($null -eq $WebEvent.Session) {
        return
    }

    # remove the session, and from auth and cookies
    Remove-PodeAuthSession
}


<#
.SYNOPSIS
    Resets the current Session's expiry date.

.DESCRIPTION
    Resets the current Session's expiry date, to be from the current time plus the defined Session duration.

.EXAMPLE
    Reset-PodeSessionExpiry
#>
function Reset-PodeSessionExpiry {
    [CmdletBinding()]
    param()

    # if sessions haven't been setup, error
    if (!(Test-PodeSessionsEnabled)) {
        # The sessions have not been configured
        throw ($PodeLocale.sessionsNotConfiguredExceptionMessage)
    }

    # error if session is null
    if ($null -eq $WebEvent.Session) {
        # There is no session available to save
        throw ($PodeLocale.noSessionAvailableToSaveExceptionMessage)
    }

    # temporarily set this session to auto-extend
    $WebEvent.Session.Extend = $true

    # reset on response
    Set-PodeSession
}


<#
.SYNOPSIS
    Saves the current Session's data.

.DESCRIPTION
    Saves the current Session's data.

.PARAMETER Force
    If supplied, the data will be saved even if nothing has changed.

.EXAMPLE
    Save-PodeSession -Force
#>
function Save-PodeSession {
    [CmdletBinding()]
    param(
        [switch]
        $Force
    )

    # if sessions haven't been setup, error
    if (!(Test-PodeSessionsEnabled)) {
        # The sessions have not been configured
        throw ($PodeLocale.sessionsNotConfiguredExceptionMessage)
    }

    # error if session is null
    if ($null -eq $WebEvent.Session) {
        # There is no session available to save
        throw ($PodeLocale.noSessionAvailableToSaveExceptionMessage)
    }

    # if auth is in use, then assign to session store
    if (!(Test-PodeIsEmpty $WebEvent.Auth) -and $WebEvent.Auth.Store) {
        $WebEvent.Session.Data.Auth = $WebEvent.Auth
    }

    # save the session
    Save-PodeSessionInternal -Force:$Force
}


function Test-PodeSessionScopeIsBrowser {
    return [bool]$PodeContext.Server.Sessions.Info.Scope.IsBrowser
}


function Test-PodeSessionsEnabled {
    return (($null -ne $PodeContext.Server.Sessions) -and ($PodeContext.Server.Sessions.Count -gt 0))
}


<#
.SYNOPSIS
    Close one or more SSE connections.

.DESCRIPTION
    Close one or more SSE connections. Either all connections for an SSE connection Name, or specific ClientIds for a Name.

.PARAMETER Name
    The Name of the SSE connection which has the ClientIds for the connections to close. If supplied on its own, all connections will be closed.

.PARAMETER Group
    An optional array of 1 or more SSE connection Groups, that are for the SSE connection Name. If supplied without any ClientIds, then all connections for the Group(s) will be closed.

.PARAMETER ClientId
    An optional array of 1 or more SSE connection ClientIds, that are for the SSE connection Name.
    If not supplied, every SSE connection for the supplied Name will be closed.

.EXAMPLE
    Close-PodeSseConnection -Name 'Actions'

.EXAMPLE
    Close-PodeSseConnection -Name 'Actions' -Group 'admins'

.EXAMPLE
    Close-PodeSseConnection -Name 'Actions' -ClientId @('my-client-id', 'my-other'id')
#>
function Close-PodeSseConnection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [string[]]
        $Group = $null,

        [Parameter()]
        [string[]]
        $ClientId = $null
    )

    $PodeContext.Server.Http.Listener.CloseSseConnection($Name, $Group, $ClientId)
}


<#
.SYNOPSIS
    Converts the current HTTP request to a Route to be an SSE connection.

.DESCRIPTION
    Converts the current HTTP request to a Route to be an SSE connection, by sending the required headers back to the client.
    The connection can only be configured if the request's Accept header is "text/event-stream", unless Forced.

.PARAMETER Name
    The Name of the SSE connection, which ClientIds will be stored under.

.PARAMETER Group
    An optional Group for this SSE connection, to enable broadcasting events to all connections for an SSE connection name in a Group.

.PARAMETER Scope
    The Scope of the SSE connection, either Default, Local or Global (Default: Default).
    - If the Scope is Default, then it will be Global unless the default has been updated via Set-PodeSseDefaultScope.
    - If the Scope is Local, then the SSE connection will only be opened for the duration of the request to a Route that configured it.
    - If the Scope is Global, then the SSE connection will be cached internally so events can be sent to the connection from Tasks, Timers, and other Routes, etc.

.PARAMETER RetryDuration
    An optional RetryDuration, in milliseconds, for the period of time a browser should wait before reattempting a connection if lost (Default: 0).

.PARAMETER ClientId
    An optional ClientId to use for the SSE connection, this value will be signed if signing is enabled (Default: GUID).

.PARAMETER AllowAllOrigins
    If supplied, then Access-Control-Allow-Origin will be set to * on the response.

.PARAMETER Force
    If supplied, the Accept header of the request will be ignored; attempting to configure an SSE connection even if the header isn't "text/event-stream".

.EXAMPLE
    ConvertTo-PodeSseConnection -Name 'Actions'

.EXAMPLE
    ConvertTo-PodeSseConnection -Name 'Actions' -Scope Local

.EXAMPLE
    ConvertTo-PodeSseConnection -Name 'Actions' -Group 'admins'

.EXAMPLE
    ConvertTo-PodeSseConnection -Name 'Actions' -AllowAllOrigins

.EXAMPLE
    ConvertTo-PodeSseConnection -Name 'Actions' -ClientId 'my-client-id'
#>
function ConvertTo-PodeSseConnection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [string]
        $Group,

        [Parameter()]
        [ValidateSet('Default', 'Local', 'Global')]
        [string]
        $Scope = 'Default',

        [Parameter()]
        [int]
        $RetryDuration = 0,

        [Parameter()]
        [string]
        $ClientId,

        [switch]
        $AllowAllOrigins,

        [switch]
        $Force
    )

    # check Accept header - unless forcing
    if (!$Force -and ((Get-PodeHeader -Name 'Accept') -ine 'text/event-stream')) {
        # SSE can only be configured on requests with an Accept header value of text/event-stream
        throw ($PodeLocale.sseOnlyConfiguredOnEventStreamAcceptHeaderExceptionMessage)
    }

    # check for default scope, and set
    if ($Scope -ieq 'default') {
        $Scope = $PodeContext.Server.Sse.DefaultScope
    }

    # generate clientId
    $ClientId = New-PodeSseClientId -ClientId $ClientId

    # set and send SSE headers
    $ClientId = Wait-PodeTask -Task $WebEvent.Response.SetSseConnection($Scope, $ClientId, $Name, $Group, $RetryDuration, $AllowAllOrigins.IsPresent)

    # create SSE property on WebEvent
    $WebEvent.Sse = @{
        Name        = $Name
        Group       = $Group
        ClientId    = $ClientId
        LastEventId = Get-PodeHeader -Name 'Last-Event-ID'
        IsLocal     = ($Scope -ieq 'local')
    }
}


<#
.SYNOPSIS
    Disable the signing of SSE connection ClientIds.

.DESCRIPTION
    Disable the signing of SSE connection ClientIds.

.EXAMPLE
    Disable-PodeSseSigning
#>
function Disable-PodeSseSigning {
    [CmdletBinding()]
    param()

    # flag that we're not signing SSE connections
    $PodeContext.Server.Sse.Signed = $false
    $PodeContext.Server.Sse.Secret = $null
    $PodeContext.Server.Sse.Strict = $false
}


<#
.SYNOPSIS
    Enable the signing of SSE connection ClientIds.

.DESCRIPTION
    Enable the signing of SSE connection ClientIds.

.PARAMETER Secret
    A Secret to sign ClientIds, Get-PodeServerDefaultSecret can be used.

.PARAMETER Strict
    If supplied, the Secret will be extended using the client request's UserAgent and RemoteIPAddress.

.EXAMPLE
    Enable-PodeSseSigning

.EXAMPLE
    Enable-PodeSseSigning -Strict

.EXAMPLE
    Enable-PodeSseSigning -Secret 'Sup3rS3cr37!' -Strict

.EXAMPLE
    Enable-PodeSseSigning -Secret 'Sup3rS3cr37!'
#>
function Enable-PodeSseSigning {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Secret,

        [switch]
        $Strict
    )

    # flag that we're signing SSE connections
    $PodeContext.Server.Sse.Signed = $true
    $PodeContext.Server.Sse.Secret = $Secret
    $PodeContext.Server.Sse.Strict = $Strict.IsPresent
}


<#
.SYNOPSIS
    Retrieve the broadcast level for an SSE connection Name.

.DESCRIPTION
    Retrieve the broadcast level for an SSE connection Name. If one hasn't been set explicitly then the base level will be checked.
    If no broadcasting level have been set at all, then the "Name" level will be returned.

.PARAMETER Name
    The Name of an SSE connection.

.EXAMPLE
    $level = Get-PodeSseBroadcastLevel -Name 'Actions'
#>
function Get-PodeSseBroadcastLevel {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    # if no levels, return null
    if ($PodeContext.Server.Sse.BroadcastLevel.Count -eq 0) {
        return 'name'
    }

    # get level or default level
    $level = $PodeContext.Server.Sse.BroadcastLevel[$Name]
    if ([string]::IsNullOrEmpty($level)) {
        $level = $PodeContext.Server.Sse.BroadcastLevel['*']
    }

    if ([string]::IsNullOrEmpty($level)) {
        $level = 'name'
    }

    # return level
    return $level
}


<#
.SYNOPSIS
    Retrieves the default SSE connection scope for new SSE connections.

.DESCRIPTION
    Retrieves the default SSE connection scope for new SSE connections.

.EXAMPLE
    $scope = Get-PodeSseDefaultScope
#>
function Get-PodeSseDefaultScope {
    [CmdletBinding()]
    param()

    return $PodeContext.Server.Sse.DefaultScope
}


<#
.SYNOPSIS
    Generate a new SSE connection ClientId.

.DESCRIPTION
    Generate a new SSE connection ClientId, which will be signed if signing enabled.

.PARAMETER ClientId
    An optional SSE connection ClientId to use, if a custom ClientId is needed and required to be signed.

.EXAMPLE
    $clientId = New-PodeSseClientId

.EXAMPLE
    $clientId = New-PodeSseClientId -ClientId 'my-client-id'

.EXAMPLE
    $clientId = New-PodeSseClientId -ClientId 's:my-already-signed-client-id.uvG49LcojTMuJ0l4yzBzr6jCqEV8gGC/0YgsYU1QEuQ='
#>
function New-PodeSseClientId {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $ClientId
    )

    # if no clientId passed, generate a random guid
    if ([string]::IsNullOrEmpty($ClientId)) {
        $ClientId = New-PodeGuid -Secure
    }

    # if we're signing the clientId, and it's not already signed, then sign it
    if ($PodeContext.Server.Sse.Signed -and !$ClientId.StartsWith('s:')) {
        $ClientId = Invoke-PodeValueSign -Value $ClientId -Secret $PodeContext.Server.Sse.Secret -Strict:($PodeContext.Server.Sse.Strict)
    }

    # return the clientId
    return $ClientId
}


<#
.SYNOPSIS
    Send an Event to one or more SSE connections.

.DESCRIPTION
    Send an Event to one or more SSE connections. This can either be:
    - Every client for an SSE connection Name
    - Specific ClientIds for an SSE connection Name
    - The current SSE connection being referenced within $WebEvent.Sse

.PARAMETER Name
    An SSE connection Name.

.PARAMETER Group
    An optional array of 1 or more SSE connection Groups to send Events to, for the specified SSE connection Name.

.PARAMETER ClientId
    An optional array of 1 or more SSE connection ClientIds to send Events to, for the specified SSE connection Name.

.PARAMETER Id
    An optional ID for the Event being sent.

.PARAMETER EventType
    An optional EventType for the Event being sent.

.PARAMETER Data
    The Data for the Event being sent, either as a String or a Hashtable/PSObject. If the latter, it will be converted into JSON.

.PARAMETER Depth
    The Depth to generate the JSON document - the larger this value the worse performance gets.

.PARAMETER FromEvent
    If supplied, the SSE connection Name and ClientId will atttempt to be retrived from $WebEvent.Sse.
    These details will be set if ConvertTo-PodeSseConnection has just been called. Or if X-PODE-SSE-CLIENT-ID and X-PODE-SSE-NAME are set on an HTTP request.

.EXAMPLE
    Send-PodeSseEvent -FromEvent -Data 'This is an event'

.EXAMPLE
    Send-PodeSseEvent -FromEvent -Data @{ Message = 'A message' }

.EXAMPLE
    Send-PodeSseEvent -Name 'Actions' -Data @{ Message = 'A message' }

.EXAMPLE
    Send-PodeSseEvent -Name 'Actions' -Group 'admins' -Data @{ Message = 'A message' }

.EXAMPLE
    Send-PodeSseEvent -Name 'Actions' -Data @{ Message = 'A message' } -ID 123 -EventType 'action'
#>
function Send-PodeSseEvent {
    [CmdletBinding(DefaultParameterSetName = 'WebEvent')]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        $Data,

        [Parameter(Mandatory = $true, ParameterSetName = 'Name')]
        [string]
        $Name,

        [Parameter(ParameterSetName = 'Name')]
        [string[]]
        $Group = $null,

        [Parameter(ParameterSetName = 'Name')]
        [string[]]
        $ClientId = $null,

        [Parameter()]
        [string]
        $Id,

        [Parameter()]
        [string]
        $EventType,

        [Parameter()]
        [int]
        $Depth = 10,

        [Parameter(ParameterSetName = 'WebEvent')]
        [switch]
        $FromEvent
    )


    begin {
        $pipelineValue = @()
        # do nothing if no value
        if (($null -eq $Data) -or ([string]::IsNullOrEmpty($Data))) {
            return
        }
    }

    process {
        $pipelineValue += $_
    }

    end {
        if ($pipelineValue.Count -gt 1) {
            $Data = $pipelineValue
        }
        # jsonify the value
        if ($Data -isnot [string]) {
            if ($Depth -le 0) {
                $Data = (ConvertTo-Json -InputObject $Data -Compress)
            }
            else {
                $Data = (ConvertTo-Json -InputObject $Data -Depth $Depth -Compress)
            }
        }

        # send directly back to current connection
        if ($FromEvent -and $WebEvent.Sse.IsLocal) {
            $null = Wait-PodeTask -Task $WebEvent.Response.SendSseEvent($EventType, $Data, $Id)
            return
        }

        # from event and global?
        if ($FromEvent) {
            $Name = $WebEvent.Sse.Name
            $Group = $WebEvent.Sse.Group
            $ClientId = $WebEvent.Sse.ClientId
        }

        # error if no name
        if ([string]::IsNullOrEmpty($Name)) {
            # An SSE connection Name is required, either from -Name or $WebEvent.Sse.Name
            throw ($PodeLocale.sseConnectionNameRequiredExceptionMessage)
        }

        # check if broadcast level
        if (!(Test-PodeSseBroadcastLevel -Name $Name -Group $Group -ClientId $ClientId)) {
            # SSE failed to broadcast due to defined SSE broadcast level
            throw ($PodeLocale.sseFailedToBroadcastExceptionMessage -f $Name, (Get-PodeSseBroadcastLevel -Name $Name))
        }

        # send event
        $PodeContext.Server.Http.Listener.SendSseEvent($Name, $Group, $ClientId, $EventType, $Data, $Id)
    }
}


<#
.SYNOPSIS
    Set an allowed broadcast level for SSE connections.

.DESCRIPTION
    Set an allowed broadcast level for SSE connections, either for all SSE connection names or specific ones.

.PARAMETER Name
    An optional Name for an SSE connection (default: *).

.PARAMETER Type
    The broadcast level Type for the SSE connection.
    Name = Allow broadcasting at all levels, including broadcasting to all Groups and/or ClientIds for an SSE connection Name.
    Group = Allow broadcasting to only Groups or specific ClientIds. If neither Groups nor ClientIds are supplied, sending an event will fail.
    ClientId = Allow broadcasting to only ClientIds. If no ClientIds are supplied, sending an event will fail.

.EXAMPLE
    Set-PodeSseBroadcastLevel -Type Name

.EXAMPLE
    Set-PodeSseBroadcastLevel -Type Group

.EXAMPLE
    Set-PodeSseBroadcastLevel -Name 'Actions' -Type ClientId
#>
function Set-PodeSseBroadcastLevel {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name = '*',

        [Parameter()]
        [ValidateSet('Name', 'Group', 'ClientId')]
        [string]
        $Type
    )

    $PodeContext.Server.Sse.BroadcastLevel[$Name] = $Type.ToLowerInvariant()
}


<#
.SYNOPSIS
    Sets the default scope for new SSE connections.

.DESCRIPTION
    Sets the default scope for new SSE connections.

.PARAMETER Scope
    The default Scope for new SSE connections, either Local or Global.
    - If the Scope is Local, then new SSE connections will only be opened for the duration of the request to a Route that configured it.
    - If the Scope is Global, then new SSE connections will be cached internally so events can be sent to the connection from Tasks, Timers, and other Routes, etc.

.EXAMPLE
    Set-PodeSseDefaultScope -Scope Local

.EXAMPLE
    Set-PodeSseDefaultScope -Scope Global
#>
function Set-PodeSseDefaultScope {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Local', 'Global')]
        [string]
        $Scope
    )

    $PodeContext.Server.Sse.DefaultScope = $Scope
}


<#
.SYNOPSIS
    Test if an SSE connection can be broadcasted to, given the Name, Group, and ClientIds.

.DESCRIPTION
    Test if an SSE connection can be broadcasted to, given the Name, Group, and ClientIds.

.PARAMETER Name
    The Name of the SSE connection.

.PARAMETER Group
    An array of 1 or more Groups.

.PARAMETER ClientId
    An array of 1 or more ClientIds.

.EXAMPLE
    if (Test-PodeSseBroadcastLevel -Name 'Actions') { ... }

.EXAMPLE
    if (Test-PodeSseBroadcastLevel -Name 'Actions' -Group 'admins') { ... }

.EXAMPLE
    if (Test-PodeSseBroadcastLevel -Name 'Actions' -ClientId 'my-client-id') { ... }
#>
function Test-PodeSseBroadcastLevel {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [string[]]
        $Group,

        [Parameter()]
        [string[]]
        $ClientId
    )

    # get level, and if no level or level=name, return true
    $level = Get-PodeSseBroadcastLevel -Name $Name
    if ([string]::IsNullOrEmpty($level) -or ($level -ieq 'name')) {
        return $true
    }

    # if level=group, return false if no groups or clientIds
    # if level=clientId, return false if no clientIds
    switch ($level) {
        'group' {
            if ((($null -eq $Group) -or ($Group.Length -eq 0)) -and (($null -eq $ClientId) -or ($ClientId.Length -eq 0))) {
                return $false
            }
        }

        'clientid' {
            if (($null -eq $ClientId) -or ($ClientId.Length -eq 0)) {
                return $false
            }
        }
    }

    # valid, return true
    return $true
}


<#
.SYNOPSIS
    Test if an SSE connection ClientId exists or not.

.DESCRIPTION
    Test if an SSE connection ClientId exists or not.

.PARAMETER Name
    The Name of an SSE connection.

.PARAMETER ClientId
    The SSE connection ClientId to test.

.EXAMPLE
    if (Test-PodeSseClientId -Name 'Example' -ClientId 'my-client-id') { ... }
#>
function Test-PodeSseClientId {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true)]
        [string]
        $ClientId
    )

    return $PodeContext.Server.Http.Listener.TestSseConnectionExists($Name, $ClientId)
}


<#
.SYNOPSIS
    Test if an SSE connection ClientId is validly signed.

.DESCRIPTION
    Test if an SSE connection ClientId is validly signed.

.PARAMETER ClientId
    An optional SSE connection ClientId, if not supplied it will be retrieved from $WebEvent.

.EXAMPLE
    if (Test-PodeSseClientIdValid) { ... }

.EXAMPLE
    if (Test-PodeSseClientIdValid -ClientId 's:my-already-signed-client-id.uvG49LcojTMuJ0l4yzBzr6jCqEV8gGC/0YgsYU1QEuQ=') { ... }
#>
function Test-PodeSseClientIdSigned {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $ClientId
    )

    # get clientId from WebEvent if not passed
    if ([string]::IsNullOrEmpty($ClientId)) {
        $ClientId = $WebEvent.Request.SseClientId
    }

    # test if clientId is validly signed
    return Test-PodeValueSigned -Value $ClientId -Secret $PodeContext.Server.Sse.Secret -Strict:($PodeContext.Server.Sse.Strict)
}


<#
.SYNOPSIS
    Test if an SSE connection ClientId is valid.

.DESCRIPTION
    Test if an SSE connection ClientId, passed or from $WebEvent, is valid. A ClientId is valid if it's not signed and we're not signing ClientIds,
    or if we are signing ClientIds and the ClientId is validly signed.

.PARAMETER ClientId
    An optional SSE connection ClientId, if not supplied it will be retrieved from $WebEvent.

.EXAMPLE
    if (Test-PodeSseClientIdValid) { ... }

.EXAMPLE
    if (Test-PodeSseClientIdValid -ClientId 'my-client-id') { ... }
#>
function Test-PodeSseClientIdValid {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter()]
        [string]
        $ClientId
    )

    # get clientId from WebEvent if not passed
    if ([string]::IsNullOrEmpty($ClientId)) {
        $ClientId = $WebEvent.Request.SseClientId
    }

    # if no clientId, then it's not valid
    if ([string]::IsNullOrEmpty($ClientId)) {
        return $false
    }

    # if we're not signing, then valid if not signed, but invalid if signed
    if (!$PodeContext.Server.Sse.Signed) {
        return !$ClientId.StartsWith('s:')
    }

    # test if clientId is validly signed
    return Test-PodeSseClientIdSigned -ClientId $ClientId
}


<#
.SYNOPSIS
    Test if the name of an SSE connection exists or not.

.DESCRIPTION
    Test if the name of an SSE connection exists or not.

.PARAMETER Name
    The Name of an SSE connection to test.

.EXAMPLE
    if (Test-PodeSseName -Name 'Example') { ... }
#>
function Test-PodeSseName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    return $PodeContext.Server.Http.Listener.TestSseConnectionExists($Name)
}


<#
.SYNOPSIS
    Retrieves some state object from the shared state.

.DESCRIPTION
    Retrieves some state object from the shared state.

.PARAMETER Name
    The name of the state object.

.PARAMETER WithScope
    If supplied, the state's value and scope will be returned as a hashtable.

.EXAMPLE
    Get-PodeState -Name 'Data'
#>
function Get-PodeState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [switch]
        $WithScope
    )

    if ($null -eq $PodeContext.Server.State) {
        # Pode has not been initialized
        throw ($PodeLocale.podeNotInitializedExceptionMessage)
    }

    if ($WithScope) {
        return $PodeContext.Server.State[$Name]
    }
    else {
        return $PodeContext.Server.State[$Name].Value
    }
}


<#
.SYNOPSIS
    Returns the current names of state variables.

.DESCRIPTION
    Returns the current names of state variables that have been set. You can filter the result using Scope or a Pattern.

.PARAMETER Pattern
    An optional regex Pattern to filter the state names.

.PARAMETER Scope
    An optional Scope to filter the state names.

.EXAMPLE
    $names = Get-PodeStateNames -Scope '<scope>'

.EXAMPLE
    $names = Get-PodeStateNames -Pattern '^\w+[0-9]{0,2}$'
#>
function Get-PodeStateNames {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Pattern,

        [Parameter()]
        [string[]]
        $Scope
    )

    if ($null -eq $PodeContext.Server.State) {
        # Pode has not been initialized
        throw ($PodeLocale.podeNotInitializedExceptionMessage)
    }

    if ($null -eq $Scope) {
        $Scope = @()
    }

    $tempState = $PodeContext.Server.State.Clone()
    $keys = $tempState.Keys

    if ($Scope.Length -gt 0) {
        $keys = @(foreach ($key in $keys) {
                if ($tempState[$key].Scope -iin $Scope) {
                    $key
                }
            })
    }

    if (![string]::IsNullOrWhiteSpace($Pattern)) {
        $keys = @(foreach ($key in $keys) {
                if ($key -imatch $Pattern) {
                    $key
                }
            })
    }

    return $keys
}


<#
.SYNOPSIS
    Removes some state object from the shared state.

.DESCRIPTION
    Removes some state object from the shared state. After removal, the original object being stored is returned.

.PARAMETER Name
    The name of the state object.

.EXAMPLE
    Remove-PodeState -Name 'Data'
#>
function Remove-PodeState {
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    if ($null -eq $PodeContext.Server.State) {
        # Pode has not been initialized
        throw ($PodeLocale.podeNotInitializedExceptionMessage)
    }

    $value = $PodeContext.Server.State[$Name].Value
    $null = $PodeContext.Server.State.Remove($Name)
    return $value
}


<#
.SYNOPSIS
    Restores the shared state from some JSON file.

.DESCRIPTION
    Restores the shared state from some JSON file.

.PARAMETER Path
    The path to a JSON file that contains the state information.

.PARAMETER Merge
    If supplied, the state loaded from the JSON file will be merged with the current state, instead of overwriting it.

.PARAMETER Depth
    Saved JSON maximum depth. Will be passed to ConvertFrom-JSON's -Depth parameter (Powershell >=6). Default is 10.

.EXAMPLE
    Restore-PodeState -Path './state.json'
#>
function Restore-PodeState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Path,

        [switch]
        $Merge,

        [int16]
        $Depth = 10
    )

    # error if attempting to use outside of the pode server
    if ($null -eq $PodeContext.Server.State) {
        # Pode has not been initialized
        throw ($PodeLocale.podeNotInitializedExceptionMessage)
    }

    # get the full path to the state
    $Path = Get-PodeRelativePath -Path $Path -JoinRoot
    if (!(Test-Path $Path)) {
        return
    }

    # restore the state from file
    $state = @{}

    if (Test-PodeIsPSCore) {
        $state = (Get-Content $Path -Force | ConvertFrom-Json -AsHashtable -Depth $Depth)
    }
    else {
        $props = (Get-Content $Path -Force | ConvertFrom-Json).psobject.properties
        foreach ($prop in $props) {
            $state[$prop.Name] = $prop.Value
        }
    }

    # check for no scopes, and add for backwards compat
    $convert = $false
    foreach ($_key in $state.Clone().Keys) {
        if ($null -eq $state[$_key].Scope) {
            $convert = $true
            break
        }
    }

    if ($convert) {
        foreach ($_key in $state.Clone().Keys) {
            $state[$_key] = @{
                Value = $state[$_key]
                Scope = @()
            }
        }
    }

    # set the scope to the main context
    if ($Merge) {
        foreach ($_key in $state.Clone().Keys) {
            $PodeContext.Server.State[$_key] = $state[$_key]
        }
    }
    else {
        $PodeContext.Server.State = $state.Clone()
    }
}


<#
.SYNOPSIS
    Saves the current shared state to a supplied JSON file.

.DESCRIPTION
    Saves the current shared state to a supplied JSON file. When using this function, it's recommended to wrap it in a Lock-PodeObject block.

.PARAMETER Path
    The path to a JSON file which the current state will be saved to.

.PARAMETER Scope
    An optional array of scopes for state objects that should be saved. (This has a lower precedence than Exclude/Include)

.PARAMETER Exclude
    An optional array of state object names to exclude from being saved. (This has a higher precedence than Include)

.PARAMETER Include
    An optional array of state object names to only include when being saved.

.PARAMETER Depth
    Saved JSON maximum depth. Will be passed to ConvertTo-JSON's -Depth parameter. Default is 10.

.PARAMETER Compress
    If supplied, the saved JSON will be compressed.

.EXAMPLE
    Save-PodeState -Path './state.json'

.EXAMPLE
    Save-PodeState -Path './state.json' -Exclude Name1, Name2

.EXAMPLE
    Save-PodeState -Path './state.json' -Scope Users
#>
function Save-PodeState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Path,

        [Parameter()]
        [string[]]
        $Scope,

        [Parameter()]
        [string[]]
        $Exclude,

        [Parameter()]
        [string[]]
        $Include,

        [Parameter()]
        [int16]
        $Depth = 10,

        [switch]
        $Compress
    )

    # error if attempting to use outside of the pode server
    if ($null -eq $PodeContext.Server.State) {
        # Pode has not been initialized
        throw ($PodeLocale.podeNotInitializedExceptionMessage)
    }

    # get the full path to save the state
    $Path = Get-PodeRelativePath -Path $Path -JoinRoot

    # contruct the state to save (excludes, etc)
    $state = $PodeContext.Server.State.Clone()

    # scopes
    if (($null -ne $Scope) -and ($Scope.Length -gt 0)) {
        foreach ($_key in $state.Clone().Keys) {
            # remove if no scope
            if (($null -eq $state[$_key].Scope) -or ($state[$_key].Scope.Length -eq 0)) {
                $null = $state.Remove($_key)
                continue
            }

            # check scopes (only remove if none match)
            $found = $false

            foreach ($_scope in $state[$_key].Scope) {
                if ($Scope -icontains $_scope) {
                    $found = $true
                    break
                }
            }

            if ($found) {
                continue
            }

            # none matched, remove
            $null = $state.Remove($_key)
        }
    }

    # include keys
    if (($null -ne $Include) -and ($Include.Length -gt 0)) {
        foreach ($_key in $state.Clone().Keys) {
            if ($Include -inotcontains $_key) {
                $null = $state.Remove($_key)
            }
        }
    }

    # exclude keys
    if (($null -ne $Exclude) -and ($Exclude.Length -gt 0)) {
        foreach ($_key in $state.Clone().Keys) {
            if ($Exclude -icontains $_key) {
                $null = $state.Remove($_key)
            }
        }
    }

    # save the state
    $null = ConvertTo-Json -InputObject $state -Depth $Depth -Compress:$Compress | Out-File -FilePath $Path -Force
}


<#
.SYNOPSIS
    Sets an object within the shared state.

.DESCRIPTION
    Sets an object within the shared state.

.PARAMETER Name
    The name of the state object.

.PARAMETER Value
    The value to set in the state.

.PARAMETER Scope
    An optional Scope for the state object, used when saving the state.

.EXAMPLE
    Set-PodeState -Name 'Data' -Value @{ 'Name' = 'Rick Sanchez' }

.EXAMPLE
    Set-PodeState -Name 'Users' -Value @('user1', 'user2') -Scope General, Users
#>
function Set-PodeState {
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(ValueFromPipeline = $true, Position = 0)]
        [object]
        $Value,

        [Parameter()]
        [string[]]
        $Scope
    )

    begin {
        if ($null -eq $PodeContext.Server.State) {
            # Pode has not been initialized
            throw ($PodeLocale.podeNotInitializedExceptionMessage)
        }

        if ($null -eq $Scope) {
            $Scope = @()
        }

        # Initialize an array to hold piped-in values
        $pipelineValue = @()
    }

    process {
        # Add the current piped-in value to the array
        $pipelineValue += $_
    }

    end {
        # Set Value to the array of values
        if ($pipelineValue.Count -gt 1) {
            $Value = $pipelineValue
        }

        $PodeContext.Server.State[$Name] = @{
            Value = $Value
            Scope = $Scope
        }

        return $Value
    }
}


<#
.SYNOPSIS
    Tests if the shared state contains some state object.

.DESCRIPTION
    Tests if the shared state contains some state object.

.PARAMETER Name
    The name of the state object.

.EXAMPLE
    Test-PodeState -Name 'Data'
#>
function Test-PodeState {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    if ($null -eq $PodeContext.Server.State) {
        # Pode has not been initialized
        throw ($PodeLocale.podeNotInitializedExceptionMessage)
    }

    return $PodeContext.Server.State.ContainsKey($Name)
}


<#
.SYNOPSIS
    Adds a new Task.

.DESCRIPTION
    Adds a new Task, which can be asynchronously or synchronously invoked.

.PARAMETER Name
    The Name of the Task.

.PARAMETER ScriptBlock
    The script for the Task.

.PARAMETER FilePath
    A literal, or relative, path to a file containing a ScriptBlock for the Task's logic.

.PARAMETER ArgumentList
    A hashtable of arguments to supply to the Task's ScriptBlock.

.PARAMETER Timeout
    A Timeout, in seconds, to abort running the Task process. (Default: -1 [never timeout])

.PARAMETER TimeoutFrom
    Where to start the Timeout from, either 'Create', 'Start'. (Default: 'Create')

.PARAMETER MaxRetries
    The maximum number of retries to attempt if the Task fails. (Default: 0)

.PARAMETER RetryDelay
    The delay, in minutes, between automatically retrying failed task processes. (Default: 0)

.PARAMETER AutoRetry
    If supplied, the Task will automatically retry processes if they fail.

.EXAMPLE
    Add-PodeTask -Name 'Example1' -ScriptBlock { Invoke-SomeLogic }

.EXAMPLE
    Add-PodeTask -Name 'Example1' -ScriptBlock { return Get-SomeObject }

.EXAMPLE
    Add-PodeTask -Name 'Example1' -ScriptBlock { return Get-SomeObject } -MaxRetries 3 -RetryDelay 5 -AutoRetry
#>
function Add-PodeTask {
    [CmdletBinding(DefaultParameterSetName = 'Script')]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true, ParameterSetName = 'Script')]
        [scriptblock]
        $ScriptBlock,

        [Parameter(Mandatory = $true, ParameterSetName = 'File')]
        [string]
        $FilePath,

        [Parameter()]
        [hashtable]
        $ArgumentList,

        [Parameter()]
        [int]
        $Timeout = -1,

        [Parameter()]
        [ValidateSet('Create', 'Start')]
        [string]
        $TimeoutFrom = 'Create',

        [Parameter()]
        [ValidateRange(0, [int]::MaxValue)]
        [int]
        $MaxRetries = 0,

        [Parameter()]
        [ValidateRange(0, [int]::MaxValue)]
        [int]
        $RetryDelay = 0,

        [switch]
        $AutoRetry
    )

    # ensure the task doesn't already exist
    if ($PodeContext.Tasks.Items.ContainsKey($Name)) {
        # [Task] Task already defined
        throw ($PodeLocale.taskAlreadyDefinedExceptionMessage -f $Name)
    }

    # if we have a file path supplied, load that path as a scriptblock
    if ($PSCmdlet.ParameterSetName -ieq 'file') {
        $ScriptBlock = Convert-PodeFileToScriptBlock -FilePath $FilePath
    }

    # Modify the ScriptBlock to replace 'Start-Sleep' with 'Start-PodeSleep'
    $ScriptBlock = ConvertTo-PodeSleep -ScriptBlock $ScriptBlock

    # check for scoped vars
    $ScriptBlock, $usingVars = Convert-PodeScopedVariables -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState

    # add the task
    $PodeContext.Tasks.Enabled = $true
    $PodeContext.Tasks.Items[$Name] = @{
        Name           = $Name
        Script         = $ScriptBlock
        UsingVariables = $usingVars
        Arguments      = (Protect-PodeValue -Value $ArgumentList -Default @{})
        Timeout        = @{
            Value = $Timeout
            From  = $TimeoutFrom
        }
        Retry          = @{
            Max       = $MaxRetries
            Delay     = $RetryDelay
            AutoRetry = $AutoRetry.IsPresent
        }
    }
}


<#
.SYNOPSIS
    Removes all Tasks.

.DESCRIPTION
    Removes all Tasks.

.EXAMPLE
    Clear-PodeTasks
#>
function Clear-PodeTasks {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    [CmdletBinding()]
    param()

    $PodeContext.Tasks.Items.Clear()
}


<#
.SYNOPSIS
    Close and dispose of a Task.

.DESCRIPTION
    Close and dispose of a Task, even if still running.

.PARAMETER Process
    The Task to be closed.

.EXAMPLE
    Invoke-PodeTask -Name 'Example1' | Close-PodeTask
#>
function Close-PodeTask {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [Alias('Task')]
        [hashtable]
        $Process
    )

    process {
        Close-PodeTaskInternal -Process $Process
    }
}


<#
.SYNOPSIS
    Edits an existing Task.

.DESCRIPTION
    Edits an existing Task's properties, such as scriptblock.

.PARAMETER Name
    The Name of the Task.

.PARAMETER ScriptBlock
    The new ScriptBlock for the Task.

.PARAMETER ArgumentList
    Any new Arguments for the Task.

.EXAMPLE
    Edit-PodeTask -Name 'Example1' -ScriptBlock { Invoke-SomeNewLogic }
#>
function Edit-PodeTask {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [string]
        $Name,

        [Parameter()]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [hashtable]
        $ArgumentList
    )

    process {
        # ensure the task exists
        if (!$PodeContext.Tasks.Items.ContainsKey($Name)) {
            # Task does not exist
            throw ($PodeLocale.taskDoesNotExistExceptionMessage -f $Name)
        }

        $_task = $PodeContext.Tasks.Items[$Name]

        # edit scriptblock if supplied
        if (!(Test-PodeIsEmpty $ScriptBlock)) {
            $ScriptBlock, $usingVars = Convert-PodeScopedVariables -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState
            $_task.Script = $ScriptBlock
            $_task.UsingVariables = $usingVars
        }

        # edit arguments if supplied
        if (!(Test-PodeIsEmpty $ArgumentList)) {
            $_task.Arguments = $ArgumentList
        }
    }
}


<#
.SYNOPSIS
    Returns any defined Tasks.

.DESCRIPTION
    Returns any defined Tasks, with support for filtering.

.PARAMETER Name
    Any Task Names to filter the Tasks.

.EXAMPLE
    Get-PodeTask

.EXAMPLE
    Get-PodeTask -Name Example1, Example2
#>
function Get-PodeTask {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string[]]
        $Name
    )

    $tasks = $PodeContext.Tasks.Items.Values

    # further filter by task names
    if (($null -ne $Name) -and ($Name.Length -gt 0)) {
        $tasks = @(foreach ($_name in $Name) {
                foreach ($task in $tasks) {
                    if ($task.Name -ine $_name) {
                        continue
                    }

                    $task
                }
            })
    }

    # return
    return $tasks
}


<#
.SYNOPSIS
    Get all Task Processes.

.DESCRIPTION
    Get all Task Processes, with support for filtering. These are the processes created when using Invoke-PodeTask.

.PARAMETER Name
    An optional Name of the Task to filter by, can be one or more.

.PARAMETER Id
    An optional ID of the Task process to filter by, can be one or more.

.PARAMETER State
    An optional State of the Task process to filter by, can be one or more.

.EXAMPLE
    Get-PodeTaskProcess

.EXAMPLE
    Get-PodeTaskProcess -Name 'TaskName'

.EXAMPLE
    Get-PodeTaskProcess -Id 'TaskId'

.EXAMPLE
    Get-PodeTaskProcess -State 'Running'
#>
function Get-PodeTaskProcess {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string[]]
        $Name,

        [Parameter()]
        [string[]]
        $Id,

        [Parameter()]
        [ValidateSet('All', 'Pending', 'Running', 'Completed', 'Failed')]
        [string[]]
        $State = 'All'
    )

    $processes = $PodeContext.Tasks.Processes.Values

    # filter processes by name
    if (($null -ne $Name) -and ($Name.Length -gt 0)) {
        $processes = @(foreach ($_name in $Name) {
                foreach ($process in $processes) {
                    if ($process.Task -ine $_name) {
                        continue
                    }

                    $process
                }
            })
    }

    # filter processes by id
    if (($null -ne $Id) -and ($Id.Length -gt 0)) {
        $processes = @(foreach ($_id in $Id) {
                foreach ($process in $processes) {
                    if ($process.ID -ine $_id) {
                        continue
                    }

                    $process
                }
            })
    }

    # filter processes by status
    if ($State -inotcontains 'All') {
        $processes = @(foreach ($process in $processes) {
                if ($State -inotcontains $process.State) {
                    continue
                }

                $process
            })
    }

    # return processes
    return $processes
}


<#
.SYNOPSIS
    Invoke a Task.

.DESCRIPTION
    Invoke a Task either asynchronously or synchronously, with support for returning values.
    The function returns the Task process object which was triggered.

.PARAMETER Name
    The Name of the Task.

.PARAMETER ArgumentList
    A hashtable of arguments to supply to the Task's ScriptBlock.

.PARAMETER Timeout
    A Timeout, in seconds, to abort running the Task process. (Default: -1 [never timeout])

.PARAMETER TimeoutFrom
    Where to start the Timeout from, either 'Default', 'Create', or 'Start'. (Default: 'Default' - will use the value from Add-PodeTask)

.PARAMETER Wait
    If supplied, Pode will wait until the Task process has finished executing, and then return any values.

.OUTPUTS
    The triggered Task process.

.EXAMPLE
    Invoke-PodeTask -Name 'Example1' -Wait -Timeout 5

.EXAMPLE
    $task = Invoke-PodeTask -Name 'Example1'

.EXAMPLE
    Invoke-PodeTask -Name 'Example1' | Wait-PodeTask -Timeout 3
#>
function Invoke-PodeTask {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [string]
        $Name,

        [Parameter()]
        [hashtable]
        $ArgumentList = $null,

        [Parameter()]
        [int]
        $Timeout = -1,

        [Parameter()]
        [ValidateSet('Default', 'Create', 'Start')]
        [string]
        $TimeoutFrom = 'Default',

        [switch]
        $Wait
    )

    process {
        # ensure the task exists
        if (!$PodeContext.Tasks.Items.ContainsKey($Name)) {
            # Task does not exist
            throw ($PodeLocale.taskDoesNotExistExceptionMessage -f $Name)
        }

        # run task logic
        $task = Invoke-PodeTaskInternal -Task $PodeContext.Tasks.Items[$Name] -ArgumentList $ArgumentList -Timeout $Timeout -TimeoutFrom $TimeoutFrom

        # wait, and return result?
        if ($Wait) {
            return (Wait-PodeTask -Process $task -Timeout $Timeout)
        }

        # return task
        return $task
    }
}


<#
.SYNOPSIS
    Removes a specific Task.

.DESCRIPTION
    Removes a specific Task.

.PARAMETER Name
    The Name of Task to be removed.

.EXAMPLE
    Remove-PodeTask -Name 'Example1'
#>
function Remove-PodeTask {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [string]
        $Name
    )

    process {
        $null = $PodeContext.Tasks.Items.Remove($Name)
    }
}


<#
.SYNOPSIS
    Restart a Task process which has failed.

.DESCRIPTION
    Restart a Task process which has failed.

.PARAMETER Process
    The Task process to be restarted. The process returned by either Invoke-PodeTask or Get-PodeTaskProcess.

.PARAMETER Timeout
    A Timeout, in seconds, to abort running the Task process. (Default: -1 [never timeout])

.PARAMETER Wait
    If supplied, Pode will wait until the Task process has finished

.EXAMPLE
    $task = Invoke-PodeTask -Name 'Example1' -Wait
    if (Test-PodeTaskFailed -Process $task) {
    Restart-PodeTaskProcess -Process $task
    }

.EXAMPLE
    Get-PodeTaskProcess -State 'Failed' | ForEach-Object { Restart-PodeTaskProcess -Process $_ }
#>
function Restart-PodeTaskProcess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [Alias('Task')]
        [hashtable]
        $Process,

        [Parameter()]
        [int]
        $Timeout = -1,

        [switch]
        $Wait
    )

    process {
        $task = Restart-PodeTaskInternal -ProcessId $Process.ID

        if ($Wait) {
            return (Wait-PodeTask -Process $task -Timeout $Timeout)
        }

        return $task
    }
}


<#
.SYNOPSIS
    Set the maximum number of concurrent Tasks.

.DESCRIPTION
    Set the maximum number of concurrent Tasks.

.PARAMETER Maximum
    The Maximum number of Tasks to run.

.EXAMPLE
    Set-PodeTaskConcurrency -Maximum 10
#>
function Set-PodeTaskConcurrency {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]
        $Maximum
    )

    # error if <=0
    if ($Maximum -le 0) {
        # Maximum concurrent tasks must be >=1 but got
        throw ($PodeLocale.maximumConcurrentTasksInvalidExceptionMessage -f $Maximum)

    }

    # ensure max > min
    $_min = 1
    if ($null -ne $PodeContext.RunspacePools.Tasks) {
        $_min = $PodeContext.RunspacePools.Tasks.Pool.GetMinRunspaces()
    }

    if ($_min -gt $Maximum) {
        # Maximum concurrent tasks cannot be less than the minimum of $_min but got $Maximum
        throw ($PodeLocale.maximumConcurrentTasksLessThanMinimumExceptionMessage -f $_min, $Maximum)
    }

    # set the max tasks
    $PodeContext.Threads.Tasks = $Maximum
    if ($null -ne $PodeContext.RunspacePools.Tasks) {
        $PodeContext.RunspacePools.Tasks.Pool.SetMaxRunspaces($Maximum)
    }
}


<#
.SYNOPSIS
    Test if a running Task process has completed (including failed).

.DESCRIPTION
    Test if a running Task process has completed (including failed).

.PARAMETER Process
    The Task process to be check. The process returned by either Invoke-PodeTask or Get-PodeTaskProcess.

.EXAMPLE
    Invoke-PodeTask -Name 'Example1' | Test-PodeTaskCompleted
#>
function Test-PodeTaskCompleted {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [Alias('Task')]
        [hashtable]
        $Process
    )

    process {
        return ([bool]$Process.Runspace.Handler.IsCompleted) -or
            ($Process.State -ieq 'Completed') -or
            ($Process.State -ieq 'Failed')
    }
}


<#
.SYNOPSIS
    Test if a running Task process has failed.

.DESCRIPTION
    Test if a running Task process has failed.

.PARAMETER Process
    The Task process to be check. The process returned by either Invoke-PodeTask or Get-PodeTaskProcess.

.EXAMPLE
    Invoke-PodeTask -Name 'Example1' | Test-PodeTaskFailed
#>
function Test-PodeTaskFailed {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [Alias('Task')]
        [hashtable]
        $Process
    )

    process {
        return ($Process.State -ieq 'Failed')
    }
}


<#
.SYNOPSIS
    Automatically loads task ps1 files

.DESCRIPTION
    Automatically loads task ps1 files from either a /tasks folder, or a custom folder. Saves space dot-sourcing them all one-by-one.

.PARAMETER Path
    Optional Path to a folder containing ps1 files, can be relative or literal.

.EXAMPLE
    Use-PodeTasks

.EXAMPLE
    Use-PodeTasks -Path './my-tasks'
#>
function Use-PodeTasks {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Path
    )

    Use-PodeFolder -Path $Path -DefaultPath 'tasks'
}


<#
.SYNOPSIS
    Waits for a Task process to finish, and returns a result if there is one.

.DESCRIPTION
    Waits for a Task process to finish, and returns a result if there is one.

.PARAMETER Process
    The Task process to wait on. The process returned by either Invoke-PodeTask or Get-PodeTaskProcess.

.PARAMETER Timeout
    An optional Timeout in milliseconds.

.EXAMPLE
    $context = Wait-PodeTask -Task $listener.GetContextAsync()

.EXAMPLE
    $result = Invoke-PodeTask -Name 'Example1' | Wait-PodeTask
#>
function Wait-PodeTask {
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [Alias('Task')]
        $Process,

        [Parameter()]
        [int]
        $Timeout = -1
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

        if ($Process -is [System.Threading.Tasks.Task]) {
            return (Wait-PodeTaskNetInternal -Task $Process -Timeout $Timeout)
        }

        if ($Process -is [hashtable]) {
            return (Wait-PodeTaskProcessInternal -Process $Process -Timeout $Timeout)
        }

        # Task type is invalid, expected either [System.Threading.Tasks.Task] or [hashtable]
        throw ($PodeLocale.invalidTaskTypeExceptionMessage)
    }
}


<#
.SYNOPSIS
    Remove all Lockables.

.DESCRIPTION
    Remove all Lockables.

.EXAMPLE
    Clear-PodeLockables
#>
function Clear-PodeLockables {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    [CmdletBinding()]
    param()

    if (Test-PodeIsEmpty $PodeContext.Threading.Lockables.Custom) {
        return
    }

    foreach ($name in $PodeContext.Threading.Lockables.Custom.Keys.Clone()) {
        Remove-PodeLockable -Name $name
    }
}


<#
.SYNOPSIS
    Removes all Mutexes.

.DESCRIPTION
    Removes all Mutexes.

.EXAMPLE
    Clear-PodeMutexes
#>
function Clear-PodeMutexes {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    [CmdletBinding()]
    param()

    if (Test-PodeIsEmpty $PodeContext.Threading.Mutexes) {
        return
    }

    foreach ($name in $PodeContext.Threading.Mutexes.Keys.Clone()) {
        Remove-PodeMutex -Name $name
    }
}


<#
.SYNOPSIS
    Removes all Semaphores.

.DESCRIPTION
    Removes all Semaphores.

.EXAMPLE
    Clear-PodeSemaphores
#>
function Clear-PodeSemaphores {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    [CmdletBinding()]
    param()

    if (Test-PodeIsEmpty $PodeContext.Threading.Semaphores) {
        return
    }

    foreach ($name in $PodeContext.Threading.Semaphores.Keys.Clone()) {
        Remove-PodeSemaphore -Name $name
    }
}


<#
.SYNOPSIS
    Place a lock on an object or Lockable.

.DESCRIPTION
    Place a lock on an object or Lockable. This should eventually be followed by a call to Exit-PodeLockable.

.PARAMETER Object
    The Object, or Lockable, to lock. If no Object is supplied then the global lockable is used by default.

.PARAMETER Name
    The Name of a Lockable object in Pode to lock, if no Name is supplied then the global lockable is used by default.

.PARAMETER Timeout
    If supplied, a number of milliseconds to timeout after if a lock cannot be acquired. (Default: Infinite)

.PARAMETER CheckGlobal
    If supplied, will check the global Lockable object and wait until it's freed-up before locking the passed object.

.EXAMPLE
    Enter-PodeLockable -Object $SomeArray

.EXAMPLE
    Enter-PodeLockable -Name 'LockName' -Timeout 5000
#>
function Enter-PodeLockable {
    [CmdletBinding(DefaultParameterSetName = 'Object')]
    param(
        [Parameter(ValueFromPipeline = $true, Position = 0, ParameterSetName = 'Object')]
        [object]
        $Object,

        [Parameter(Mandatory = $true, ParameterSetName = 'Name')]
        [string]
        $Name,

        [Parameter()]
        [int]
        $Timeout = [System.Threading.Timeout]::Infinite,

        [switch]
        $CheckGlobal
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
        # get object by name if set
        if (![string]::IsNullOrEmpty($Name)) {
            $Object = Get-PodeLockable -Name $Name
        }

        # if object is null, default to global
        if ($null -eq $Object) {
            $Object = $PodeContext.Threading.Lockables.Global
        }

        # check if value type and throw
        if ($Object -is [valuetype]) {
            # Cannot lock a [ValueType]
            throw ($PodeLocale.cannotLockValueTypeExceptionMessage)
        }

        # check if null and throw
        if ($null -eq $Object) {
            # Cannot lock an object that is null
            throw ($PodeLocale.cannotLockNullObjectExceptionMessage)
        }

        # check if the global lockable is locked
        if ($CheckGlobal) {
            Lock-PodeObject -Object $PodeContext.Threading.Lockables.Global -ScriptBlock {} -Timeout $Timeout
        }

        # attempt to acquire lock
        $locked = $false
        [System.Threading.Monitor]::TryEnter($Object.SyncRoot, $Timeout, [ref]$locked)
        if (!$locked) {
            # Failed to acquire a lock on the object
            throw ($PodeLocale.failedToAcquireLockExceptionMessage)
        }
    }
}


<#
.SYNOPSIS
    Acquires a hold on a Mutex.

.DESCRIPTION
    Acquires a hold on a Mutex. This should eventually by followed by a call to Exit-PodeMutex.

.PARAMETER Name
    The Name of the Mutex.

.PARAMETER Timeout
    If supplied, a number of milliseconds to timeout after if a hold cannot be acquired on the Mutex. (Default: Infinite)

.EXAMPLE
    Enter-PodeMutex -Name 'SelfMutex' -Timeout 5000
#>
function Enter-PodeMutex {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [int]
        $Timeout = [System.Threading.Timeout]::Infinite
    )

    $mutex = Get-PodeMutex -Name $Name
    if ($null -eq $mutex) {
        # No mutex found called 'Name'
        throw ($PodeLocale.noMutexFoundExceptionMessage -f $Name)
    }

    if (!$mutex.WaitOne($Timeout)) {
        # Failed to acquire mutex ownership. Mutex name: Name
        throw ($PodeLocale.failedToAcquireMutexOwnershipExceptionMessage -f $Name)
    }
}


<#
.SYNOPSIS
    Acquires a hold on a Semaphore.

.DESCRIPTION
    Acquires a hold on a Semaphore. This should eventually by followed by a call to Exit-PodeSemaphore.

.PARAMETER Name
    The Name of the Semaphore.

.PARAMETER Timeout
    If supplied, a number of milliseconds to timeout after if a hold cannot be acquired on the Semaphore. (Default: Infinite)

.EXAMPLE
    Enter-PodeSemaphore -Name 'SelfSemaphore' -Timeout 5000
#>
function Enter-PodeSemaphore {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [int]
        $Timeout = [System.Threading.Timeout]::Infinite
    )

    $semaphore = Get-PodeSemaphore -Name $Name
    if ($null -eq $semaphore) {
        # No semaphore found called 'Name'
        throw ($PodeLocale.noSemaphoreFoundExceptionMessage -f $Name)
    }

    if (!$semaphore.WaitOne($Timeout)) {
        # Failed to acquire semaphore ownership. Semaphore name: Name
        throw ($PodeLocale.failedToAcquireSemaphoreOwnershipExceptionMessage -f $Name)
    }
}


<#
.SYNOPSIS
    Remove a lock from an object or Lockable.

.DESCRIPTION
    Remove a lock from an object or Lockable, that was originally locked via Enter-PodeLockable.

.PARAMETER Object
    The Object, or Lockable, to unlock. If no Object is supplied then the global lockable is used by default.

.PARAMETER Name
    The Name of a Lockable object in Pode to unlock, if no Name is supplied then the global lockable is used by default.

.EXAMPLE
    Exit-PodeLockable -Object $SomeArray

.EXAMPLE
    Exit-PodeLockable -Name 'LockName'
#>
function Exit-PodeLockable {
    [CmdletBinding(DefaultParameterSetName = 'Object')]
    param(
        [Parameter(ValueFromPipeline = $true, Position = 0, ParameterSetName = 'Object')]
        [object]
        $Object,

        [Parameter(Mandatory = $true, ParameterSetName = 'Name')]
        [string]
        $Name
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
        # get object by name if set
        if (![string]::IsNullOrEmpty($Name)) {
            $Object = Get-PodeLockable -Name $Name
        }

        # if object is null, default to global
        if ($null -eq $Object) {
            $Object = $PodeContext.Threading.Lockables.Global
        }

        # check if value type and throw
        if ($Object -is [valuetype]) {
            # Cannot unlock a [ValueType]
            throw ($PodeLocale.cannotUnlockValueTypeExceptionMessage)
        }

        # check if null and throw
        if ($null -eq $Object) {
            # Cannot unlock an object that is null
            throw ($PodeLocale.cannotUnlockNullObjectExceptionMessage)
        }

        if ([System.Threading.Monitor]::IsEntered($Object.SyncRoot)) {
            [System.Threading.Monitor]::Pulse($Object.SyncRoot)
            [System.Threading.Monitor]::Exit($Object.SyncRoot)
        }
    }
}


<#
.SYNOPSIS
    Release the hold on a Mutex.

.DESCRIPTION
    Release the hold on a Mutex, that was originally acquired by Enter-PodeMutex.

.PARAMETER Name
    The Name of the Mutex.

.EXAMPLE
    Exit-PodeMutex -Name 'SelfMutex'
#>
function Exit-PodeMutex {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    $mutex = Get-PodeMutex -Name $Name
    if ($null -eq $mutex) {
        # No mutex found called 'Name'
        throw ($PodeLocale.noMutexFoundExceptionMessage -f $Name)
    }

    $mutex.ReleaseMutex()
}


<#
.SYNOPSIS
    Release the hold on a Semaphore.

.DESCRIPTION
    Release the hold on a Semaphore, that was originally acquired by Enter-PodeSemaphore.

.PARAMETER Name
    The Name of the Semaphore.

.PARAMETER ReleaseCount
    The number of releases to release in one go. (Default: 1)

.EXAMPLE
    Exit-PodeSemaphore -Name 'SelfSemaphore'
#>
function Exit-PodeSemaphore {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [int]
        $ReleaseCount = 1
    )

    $semaphore = Get-PodeSemaphore -Name $Name
    if ($null -eq $semaphore) {
        # No semaphore found called 'Name'
        throw ($PodeLocale.noSemaphoreFoundExceptionMessage -f $Name)
    }

    if ($ReleaseCount -lt 1) {
        $ReleaseCount = 1
    }

    $semaphore.Release($ReleaseCount)
}


<#
.SYNOPSIS
    Get a custom Lockable object.

.DESCRIPTION
    Get a custom Lockable object for use with Lock-PodeObject, and Enter/Exit-PodeLockable.

.PARAMETER Name
    The Name of the Lockable object.

.EXAMPLE
    Get-PodeLockable -Name 'Lock1' | Lock-PodeObject -ScriptBlock {}
#>
function Get-PodeLockable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    return $PodeContext.Threading.Lockables.Custom[$Name]
}


<#
.SYNOPSIS
    Get a Mutex.

.DESCRIPTION
    Get a Mutex.

.PARAMETER Name
    The Name of the Mutex.

.EXAMPLE
    $mutex = Get-PodeMutex -Name 'SelfMutex'
#>
function Get-PodeMutex {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    return $PodeContext.Threading.Mutexes[$Name]
}


<#
.SYNOPSIS
    Get a Semaphore.

.DESCRIPTION
    Get a Semaphore.

.PARAMETER Name
    The Name of the Semaphore.

.EXAMPLE
    $semaphore = Get-PodeSemaphore -Name 'SelfSemaphore'
#>
function Get-PodeSemaphore {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    return $PodeContext.Threading.Semaphores[$Name]
}


<#
.SYNOPSIS
    Places a temporary lock on an object, or Lockable, while a ScriptBlock is invoked.

.DESCRIPTION
    Places a temporary lock on an object, or Lockable, while a ScriptBlock is invoked.

.PARAMETER Object
    The Object, or Lockable, to lock. If no Object is supplied then the global lockable is used by default.

.PARAMETER Name
    The Name of a Lockable object in Pode to lock, if no Name is supplied then the global lockable is used by default.

.PARAMETER ScriptBlock
    The ScriptBlock to invoke.

.PARAMETER Timeout
    If supplied, a number of milliseconds to timeout after if a lock cannot be acquired. (Default: Infinite)

.PARAMETER Return
    If supplied, any values from the ScriptBlock will be returned.

.PARAMETER CheckGlobal
    If supplied, will check the global Lockable object and wait until it's freed-up before locking the passed object.

.EXAMPLE
    Lock-PodeObject -ScriptBlock { /* logic */ }

.EXAMPLE
    Lock-PodeObject -Object $SomeArray -ScriptBlock { /* logic */ }

.EXAMPLE
    Lock-PodeObject -Name 'LockName' -Timeout 5000 -ScriptBlock { /* logic */ }

.EXAMPLE
    $result = (Lock-PodeObject -Return -Object $SomeArray -ScriptBlock { /* logic */ })
#>
function Lock-PodeObject {
    [CmdletBinding(DefaultParameterSetName = 'Object')]
    [OutputType([object])]
    param(
        [Parameter(ValueFromPipeline = $true, Position = 0, ParameterSetName = 'Object')]
        [object]
        $Object,

        [Parameter(Mandatory = $true, ParameterSetName = 'Name')]
        [string]
        $Name,

        [Parameter(Mandatory = $true)]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [int]
        $Timeout = [System.Threading.Timeout]::Infinite,

        [switch]
        $Return,

        [switch]
        $CheckGlobal
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
        try {
            if ([string]::IsNullOrEmpty($Name)) {
                Enter-PodeLockable -Object $Object -Timeout $Timeout -CheckGlobal:$CheckGlobal
            }
            else {
                Enter-PodeLockable -Name $Name -Timeout $Timeout -CheckGlobal:$CheckGlobal
            }

            if ($null -ne $ScriptBlock) {
                Invoke-PodeScriptBlock -ScriptBlock $ScriptBlock -NoNewClosure -Return:$Return
            }
        }
        catch {
            $_ | Write-PodeErrorLog
            throw $_.Exception
        }
        finally {
            if ([string]::IsNullOrEmpty($Name)) {
                Exit-PodeLockable -Object $Object
            }
            else {
                Exit-PodeLockable -Name $Name
            }
        }
    }
}


<#
.SYNOPSIS
    Creates a new custom Lockable object.

.DESCRIPTION
    Creates a new custom Lockable object for use with Lock-PodeObject, and Enter/Exit-PodeLockable.

.PARAMETER Name
    The Name of the Lockable object.

.EXAMPLE
    New-PodeLockable -Name 'Lock1'
#>
function New-PodeLockable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    if (Test-PodeLockable -Name $Name) {
        return
    }

    $PodeContext.Threading.Lockables.Custom[$Name] = [hashtable]::Synchronized(@{})
}


<#
.SYNOPSIS
    Create a new Mutex.

.DESCRIPTION
    Create a new Mutex.

.PARAMETER Name
    The Name of the Mutex.

.PARAMETER Scope
    The Scope of the Mutex, can be either Self, Local, or Global. (Default: Self)
    Self: The current process, or child processes.
    Local: All processes for the current login session on Windows, or the the same as Self on Unix.
    Global: All processes on the system, across every session.

.EXAMPLE
    New-PodeMutex -Name 'SelfMutex'

.EXAMPLE
    New-PodeMutex -Name 'LocalMutex' -Scope Local

.EXAMPLE
    New-PodeMutex -Name 'GlobalMutex' -Scope Global
#>
function New-PodeMutex {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [ValidateSet('Self', 'Local', 'Global')]
        [string]
        $Scope = 'Self'
    )

    if (Test-PodeMutex -Name $Name) {
        # A mutex with the following name already exists
        throw ($PodeLocale.mutexAlreadyExistsExceptionMessage -f $Name)
    }

    $mutex = $null

    switch ($Scope.ToLowerInvariant()) {
        'self' {
            $mutex = [System.Threading.Mutex]::new($false)
        }

        'local' {
            $mutex = [System.Threading.Mutex]::new($false, "Local\$($Name)")
        }

        'global' {
            $mutex = [System.Threading.Mutex]::new($false, "Global\$($Name)")
        }
    }

    $PodeContext.Threading.Mutexes[$Name] = $mutex
}


<#
.SYNOPSIS
    Create a new Semaphore.

.DESCRIPTION
    Create a new Semaphore.

.PARAMETER Name
    The Name of the Semaphore.

.PARAMETER Count
    The number of threads to allow a hold on the Semaphore. (Default: 1)

.PARAMETER Scope
    The Scope of the Semaphore, can be either Self, Local, or Global. (Default: Self)
    Self: The current process, or child processes.
    Local: All processes for the current login session on Windows, or the the same as Self on Unix.
    Global: All processes on the system, across every session.

.EXAMPLE
    New-PodeSemaphore -Name 'SelfSemaphore'

.EXAMPLE
    New-PodeSemaphore -Name 'LocalSemaphore' -Scope Local

.EXAMPLE
    New-PodeSemaphore -Name 'GlobalSemaphore' -Count 3 -Scope Global
#>
function New-PodeSemaphore {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [int]
        $Count = 1,

        [Parameter()]
        [ValidateSet('Self', 'Local', 'Global')]
        [string]
        $Scope = 'Self'
    )

    if (Test-PodeSemaphore -Name $Name) {
        # A semaphore with the following name already exists
        throw ($PodeLocale.semaphoreAlreadyExistsExceptionMessage -f $Name)
    }

    if ($Count -le 0) {
        $Count = 1
    }

    $semaphore = $null

    switch ($Scope.ToLowerInvariant()) {
        'self' {
            $semaphore = [System.Threading.Semaphore]::new($Count, $Count)
        }

        'local' {
            $semaphore = [System.Threading.Semaphore]::new($Count, $Count, "Local\$($Name)")
        }

        'global' {
            $semaphore = [System.Threading.Semaphore]::new($Count, $Count, "Global\$($Name)")
        }
    }

    $PodeContext.Threading.Semaphores[$Name] = $semaphore
}


<#
.SYNOPSIS
    Removes a custom Lockable object.

.DESCRIPTION
    Removes a custom Lockable object.

.PARAMETER Name
    The Name of the Lockable object to remove.

.EXAMPLE
    Remove-PodeLockable -Name 'Lock1'
#>
function Remove-PodeLockable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    if (Test-PodeLockable -Name $Name) {
        $PodeContext.Threading.Lockables.Custom.Remove($Name)
    }
}


<#
.SYNOPSIS
    Remove a Mutex.

.DESCRIPTION
    Remove a Mutex.

.PARAMETER Name
    The Name of the Mutex.

.EXAMPLE
    Remove-PodeMutex -Name 'GlobalMutex'
#>
function Remove-PodeMutex {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    if (Test-PodeMutex -Name $Name) {
        $PodeContext.Threading.Mutexes[$Name].Dispose()
        $PodeContext.Threading.Mutexes.Remove($Name)
    }
}


<#
.SYNOPSIS
    Remove a Semaphore.

.DESCRIPTION
    Remove a Semaphore.

.PARAMETER Name
    The Name of the Semaphore.

.EXAMPLE
    Remove-PodeSemaphore -Name 'GlobalSemaphore'
#>
function Remove-PodeSemaphore {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    if (Test-PodeSemaphore -Name $Name) {
        $PodeContext.Threading.Semaphores[$Name].Dispose()
        $PodeContext.Threading.Semaphores.Remove($Name)
    }
}


<#
.SYNOPSIS
    Test if a custom Lockable object exists.

.DESCRIPTION
    Test if a custom Lockable object exists.

.PARAMETER Name
    The Name of the Lockable object.

.EXAMPLE
    Test-PodeLockable -Name 'Lock1'
#>
function Test-PodeLockable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    return $PodeContext.Threading.Lockables.Custom.ContainsKey($Name)
}


<#
.SYNOPSIS
    Test if a Mutex exists.

.DESCRIPTION
    Test if a Mutex exists.

.PARAMETER Name
    The Name of the Mutex.

.EXAMPLE
    Test-PodeMutex -Name 'LocalMutex'
#>
function Test-PodeMutex {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    return $PodeContext.Threading.Mutexes.ContainsKey($Name)
}


<#
.SYNOPSIS
    Test if a Semaphore exists.

.DESCRIPTION
    Test if a Semaphore exists.

.PARAMETER Name
    The Name of the Semaphore.

.EXAMPLE
    Test-PodeSemaphore -Name 'LocalSemaphore'
#>
function Test-PodeSemaphore {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    return $PodeContext.Threading.Semaphores.ContainsKey($Name)
}


<#
.SYNOPSIS
    Places a temporary hold on a Mutex, invokes a ScriptBlock, then releases the Mutex.

.DESCRIPTION
    Places a temporary hold on a Mutex, invokes a ScriptBlock, then releases the Mutex.

.PARAMETER Name
    The Name of the Mutex.

.PARAMETER ScriptBlock
    The ScriptBlock to invoke.

.PARAMETER Timeout
    If supplied, a number of milliseconds to timeout after if a hold cannot be acquired on the Mutex. (Default: Infinite)

.PARAMETER Return
    If supplied, any values from the ScriptBlock will be returned.

.EXAMPLE
    Use-PodeMutex -Name 'SelfMutex' -Timeout 5000 -ScriptBlock {}

.EXAMPLE
    $result = Use-PodeMutex -Name 'LocalMutex' -Return -ScriptBlock {}
#>
function Use-PodeMutex {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true)]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [int]
        $Timeout = [System.Threading.Timeout]::Infinite,

        [switch]
        $Return
    )

    try {
        $acquired = $false
        Enter-PodeMutex -Name $Name -Timeout $Timeout
        $acquired = $true
        Invoke-PodeScriptBlock -ScriptBlock $ScriptBlock -NoNewClosure -Return:$Return
    }
    catch {
        $_ | Write-PodeErrorLog
        throw $_.Exception
    }
    finally {
        if ($acquired) {
            Exit-PodeMutex -Name $Name
        }
    }
}


<#
.SYNOPSIS
    Places a temporary hold on a Semaphore, invokes a ScriptBlock, then releases the Semaphore.

.DESCRIPTION
    Places a temporary hold on a Semaphore, invokes a ScriptBlock, then releases the Semaphore.

.PARAMETER Name
    The Name of the Semaphore.

.PARAMETER ScriptBlock
    The ScriptBlock to invoke.

.PARAMETER Timeout
    If supplied, a number of milliseconds to timeout after if a hold cannot be acquired on the Semaphore. (Default: Infinite)

.PARAMETER Return
    If supplied, any values from the ScriptBlock will be returned.

.EXAMPLE
    Use-PodeSemaphore -Name 'SelfSemaphore' -Timeout 5000 -ScriptBlock {}

.EXAMPLE
    $result = Use-PodeSemaphore -Name 'LocalSemaphore' -Return -ScriptBlock {}
#>
function Use-PodeSemaphore {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true)]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [int]
        $Timeout = [System.Threading.Timeout]::Infinite,

        [switch]
        $Return
    )

    try {
        $acquired = $false
        Enter-PodeSemaphore -Name $Name -Timeout $Timeout
        $acquired = $true
        Invoke-PodeScriptBlock -ScriptBlock $ScriptBlock -NoNewClosure -Return:$Return
    }
    catch {
        $_ | Write-PodeErrorLog
        throw $_.Exception
    }
    finally {
        if ($acquired) {
            Exit-PodeSemaphore -Name $Name
        }
    }
}


<#
.SYNOPSIS
    Adds a new Timer with logic to periodically invoke.

.DESCRIPTION
    Adds a new Timer with logic to periodically invoke, with options to only run a specific number of times.

.PARAMETER Name
    The Name of the Timer.

.PARAMETER Interval
    The number of seconds to periodically invoke the Timer's ScriptBlock.

.PARAMETER ScriptBlock
    The script for the Timer.

.PARAMETER Limit
    The number of times the Timer should be invoked before being removed. (If 0, it will run indefinitely)

.PARAMETER Skip
    The number of "invokes" to skip before the Timer actually runs.

.PARAMETER ArgumentList
    An array of arguments to supply to the Timer's ScriptBlock.

.PARAMETER FilePath
    A literal, or relative, path to a file containing a ScriptBlock for the Timer's logic.

.PARAMETER OnStart
    If supplied, the timer will trigger when the server starts.

.EXAMPLE
    Add-PodeTimer -Name 'Hello' -Interval 10 -ScriptBlock { 'Hello, world!' | Out-Default }

.EXAMPLE
    Add-PodeTimer -Name 'RunOnce' -Interval 1 -Limit 1 -ScriptBlock { /* logic */ }

.EXAMPLE
    Add-PodeTimer -Name 'RunAfter60secs' -Interval 10 -Skip 6 -ScriptBlock { /* logic */ }

.EXAMPLE
    Add-PodeTimer -Name 'Args' -Interval 2 -ScriptBlock { /* logic */ } -ArgumentList 'arg1', 'arg2'
#>
function Add-PodeTimer {
    [CmdletBinding(DefaultParameterSetName = 'Script')]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true)]
        [int]
        $Interval,

        [Parameter(Mandatory = $true, ParameterSetName = 'Script')]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [int]
        $Limit = 0,

        [Parameter()]
        [int]
        $Skip = 0,

        [Parameter(Mandatory = $true, ParameterSetName = 'File')]
        [string]
        $FilePath,

        [Parameter()]
        [object[]]
        $ArgumentList,

        [switch]
        $OnStart
    )

    # error if serverless
    Test-PodeIsServerless -FunctionName 'Add-PodeTimer' -ThrowError

    # ensure the timer doesn't already exist
    if ($PodeContext.Timers.Items.ContainsKey($Name)) {
        # [Timer] Name: Timer already defined
        throw ($PodeLocale.timerAlreadyDefinedExceptionMessage -f $Name)
    }

    # is the interval valid?
    if ($Interval -le 0) {
        # [Timer] Name: parameter must be greater than 0
        throw ($PodeLocale.timerParameterMustBeGreaterThanZeroExceptionMessage -f $Name, 'Interval')
    }

    # is the limit valid?
    if ($Limit -lt 0) {
        # [Timer] Name: parameter must be greater than 0
        throw ($PodeLocale.timerParameterMustBeGreaterThanZeroExceptionMessage -f $Name, 'Limit')
    }

    # is the skip valid?
    if ($Skip -lt 0) {
        # [Timer] Name: parameter must be greater than 0
        throw ($PodeLocale.timerParameterMustBeGreaterThanZeroExceptionMessage -f $Name, 'Skip')
    }

    # if we have a file path supplied, load that path as a scriptblock
    if ($PSCmdlet.ParameterSetName -ieq 'file') {
        $ScriptBlock = Convert-PodeFileToScriptBlock -FilePath $FilePath
    }

    # check for scoped vars
    $ScriptBlock, $usingVars = Convert-PodeScopedVariables -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState

    # calculate the next tick time (based on Skip)
    $NextTriggerTime = [DateTime]::Now.AddSeconds($Interval)
    if ($Skip -gt 1) {
        $NextTriggerTime = $NextTriggerTime.AddSeconds($Interval * $Skip)
    }

    # add the timer
    $PodeContext.Timers.Enabled = $true
    $PodeContext.Timers.Items[$Name] = @{
        Name            = $Name
        Interval        = $Interval
        Limit           = $Limit
        Count           = 0
        Skip            = $Skip
        NextTriggerTime = $NextTriggerTime
        LastTriggerTime = $null
        Script          = $ScriptBlock
        UsingVariables  = $usingVars
        Arguments       = $ArgumentList
        OnStart         = $OnStart
        Completed       = $false
    }
}


<#
.SYNOPSIS
    Removes all Timers.

.DESCRIPTION
    Removes all Timers.

.EXAMPLE
    Clear-PodeTimers
#>
function Clear-PodeTimers {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    [CmdletBinding()]
    param()

    $PodeContext.Timers.Items.Clear()
}


<#
.SYNOPSIS
    Edits an existing Timer.

.DESCRIPTION
    Edits an existing Timer's properties, such as interval or scriptblock.

.PARAMETER Name
    The Name of the Timer.

.PARAMETER Interval
    The new Interval for the Timer in seconds.

.PARAMETER ScriptBlock
    The new ScriptBlock for the Timer.

.PARAMETER ArgumentList
    Any new Arguments for the Timer.

.EXAMPLE
    Edit-PodeTimer -Name 'Hello' -Interval 10
#>
function Edit-PodeTimer {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [string]
        $Name,

        [Parameter()]
        [int]
        $Interval = 0,

        [Parameter()]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [object[]]
        $ArgumentList
    )
    process {
        # ensure the timer exists
        if (!$PodeContext.Timers.Items.ContainsKey($Name)) {
            # Timer 'Name' does not exist
            throw ($PodeLocale.timerDoesNotExistExceptionMessage -f $Name)
        }

        $_timer = $PodeContext.Timers.Items[$Name]

        # edit interval if supplied
        if ($Interval -gt 0) {
            $_timer.Interval = $Interval
        }

        # edit scriptblock if supplied
        if (!(Test-PodeIsEmpty $ScriptBlock)) {
            $ScriptBlock, $usingVars = Convert-PodeScopedVariables -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState
            $_timer.Script = $ScriptBlock
            $_timer.UsingVariables = $usingVars
        }

        # edit arguments if supplied
        if (!(Test-PodeIsEmpty $ArgumentList)) {
            $_timer.Arguments = $ArgumentList
        }
    }
}


<#
.SYNOPSIS
    Returns any defined timers.

.DESCRIPTION
    Returns any defined timers, with support for filtering.

.PARAMETER Name
    Any timer Names to filter the timers.

.EXAMPLE
    Get-PodeTimer

.EXAMPLE
    Get-PodeTimer -Name Name1, Name2
#>
function Get-PodeTimer {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string[]]
        $Name
    )

    $timers = $PodeContext.Timers.Items.Values

    # further filter by timer names
    if (($null -ne $Name) -and ($Name.Length -gt 0)) {
        $timers = @(foreach ($_name in $Name) {
                foreach ($timer in $timers) {
                    if ($timer.Name -ine $_name) {
                        continue
                    }

                    $timer
                }
            })
    }

    # return
    return $timers
}


<#
.SYNOPSIS
    Adhoc invoke a Timer's logic.

.DESCRIPTION
    Adhoc invoke a Timer's logic outside of its defined interval. This invocation doesn't count towards the Timer's limit.

.PARAMETER Name
    The Name of the Timer.

.PARAMETER ArgumentList
    An array of arguments to supply to the Timer's ScriptBlock.

.EXAMPLE
    Invoke-PodeTimer -Name 'timer-name'
#>
function Invoke-PodeTimer {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [string]
        $Name,

        [Parameter()]
        [object[]]
        $ArgumentList = $null
    )
    process {
        # ensure the timer exists
        if (!$PodeContext.Timers.Items.ContainsKey($Name)) {
            # Timer 'Name' does not exist
            throw ($PodeLocale.timerDoesNotExistExceptionMessage -f $Name)
        }

        # run timer logic
        Invoke-PodeInternalTimer -Timer $PodeContext.Timers.Items[$Name] -ArgumentList $ArgumentList
    }
}


<#
.SYNOPSIS
    Removes a specific Timer.

.DESCRIPTION
    Removes a specific Timer.

.PARAMETER Name
    The Name of Timer to be removed.

.EXAMPLE
    Remove-PodeTimer -Name 'SaveState'
#>
function Remove-PodeTimer {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [string]
        $Name
    )
    process {
        $null = $PodeContext.Timers.Items.Remove($Name)
    }
}


<#
.SYNOPSIS
    Tests whether the passed Timer exists.

.DESCRIPTION
    Tests whether the passed Timer exists by its name.

.PARAMETER Name
    The Name of the Timer.

.EXAMPLE
    if (Test-PodeTimer -Name TimerName) { }
#>
function Test-PodeTimer {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    return (($null -ne $PodeContext.Timers.Items) -and $PodeContext.Timers.Items.ContainsKey($Name))
}


<#
.SYNOPSIS
    Automatically loads timer ps1 files

.DESCRIPTION
    Automatically loads timer ps1 files from either a /timers folder, or a custom folder. Saves space dot-sourcing them all one-by-one.

.PARAMETER Path
    Optional Path to a folder containing ps1 files, can be relative or literal.

.EXAMPLE
    Use-PodeTimers

.EXAMPLE
    Use-PodeTimers -Path './my-timers'
#>
function Use-PodeTimers {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Path
    )

    Use-PodeFolder -Path $Path -DefaultPath 'timers'
}


<#
.SYNOPSIS
    Adds a ScriptBlock as Endware to run at the end of each web Request.

.DESCRIPTION
    Adds a ScriptBlock as Endware to run at the end of each web Request.

.PARAMETER ScriptBlock
    The ScriptBlock to add. It will be supplied the current web event.

.PARAMETER ArgumentList
    An array of arguments to supply to the Endware's ScriptBlock.

.EXAMPLE
    Add-PodeEndware -ScriptBlock { /* logic */ }
#>
function Add-PodeEndware {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [object[]]
        $ArgumentList
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
        # check for scoped vars
        $ScriptBlock, $usingVars = Convert-PodeScopedVariables -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState

        # add the scriptblock to array of endware that needs to be run
        $PodeContext.Server.Endware += @{
            Logic          = $ScriptBlock
            UsingVariables = $usingVars
            Arguments      = $ArgumentList
        }
    }
}


<#
.SYNOPSIS
    Dispose and close streams, tokens, and other Disposables.

.DESCRIPTION
    Dispose and close streams, tokens, and other Disposables.

.PARAMETER Disposable
    The Disposable object to dispose and close.

.PARAMETER Close
    Should the Disposable also be closed, as well as disposed?

.PARAMETER CheckNetwork
    If an error is thrown, check the reason - if it's network related ignore the error.

.EXAMPLE
    Close-PodeDisposable -Disposable $stream -Close
#>
function Close-PodeDisposable {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true)]
        [System.IDisposable]
        $Disposable,

        [switch]
        $Close,

        [switch]
        $CheckNetwork
    )
    process {
        if ($null -eq $Disposable) {
            return
        }

        try {
            if ($Close) {
                $Disposable.Close()
            }
        }
        catch [exception] {
            if ($CheckNetwork -and (Test-PodeValidNetworkFailure $_.Exception)) {
                return
            }

            $_ | Write-PodeErrorLog
            throw $_.Exception
        }
        finally {
            $Disposable.Dispose()
        }
    }
}


<#
.SYNOPSIS
    Converts an XML node to a PowerShell hashtable.

.DESCRIPTION
    The ConvertFrom-PodeXml function converts an XML node, including all its child nodes and attributes, into an ordered hashtable. This is useful for manipulating XML data in a more PowerShell-centric way.

.PARAMETER node
    The XML node to convert. This parameter takes an XML node and processes it, along with its child nodes and attributes.

.PARAMETER Prefix
    A string prefix used to indicate an attribute. Default is an empty string.

.PARAMETER ShowDocElement
    Indicates whether to show the document element. Default is false.

.PARAMETER KeepAttributes
    If set, the function keeps the attributes of the XML nodes in the resulting hashtable.

.EXAMPLE
    $node = [xml](Get-Content 'path\to\file.xml').DocumentElement
    ConvertFrom-PodeXml -node $node

    Converts the XML document's root node to a hashtable.

.INPUTS
    System.Xml.XmlNode
    You can pipe a XmlNode to ConvertFrom-PodeXml.

.OUTPUTS
    System.Collections.Hashtable
    Outputs an ordered hashtable representing the XML node structure.

.NOTES
    This cmdlet is useful for transforming XML data into a structure that's easier to manipulate in PowerShell scripts.
#>
function ConvertFrom-PodeXml {
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param
    (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [System.Xml.XmlNode]$node,

        [Parameter()]
        [string]
        $Prefix = '',

        [Parameter()]
        [switch]
        $ShowDocElement,

        [Parameter()]
        [switch]
        $KeepAttributes
    )
    process {
        #if option set, we skip the Document element
        if ($node.DocumentElement -and !($ShowDocElement.IsPresent))
        { $node = $node.DocumentElement }
        $oHash = [ordered] @{ } # start with an ordered hashtable.
        #The order of elements is always significant regardless of what they are
        if ($null -ne $node.Attributes  ) {
            #if there are elements
            # record all the attributes first in the ordered hash
            $node.Attributes | ForEach-Object {
                $oHash.$("$Prefix$($_.FirstChild.parentNode.LocalName)") = $_.FirstChild.value
            }
        }
        # check to see if there is a pseudo-array. (more than one
        # child-node with the same name that must be handled as an array)
        $node.ChildNodes | #we just group the names and create an empty
            #array for each
            Group-Object -Property LocalName | Where-Object { $_.count -gt 1 } | Select-Object Name |
            ForEach-Object {
                $oHash.($_.Name) = @() <# create an empty array for each one#>
            }
        foreach ($child in $node.ChildNodes) {
            #now we look at each node in turn.
            $childName = $child.LocalName
            if ($child -is [system.xml.xmltext]) {
                # if it is simple XML text
                $oHash.$childname += $child.InnerText
            }
            # if it has a #text child we may need to cope with attributes
            elseif ($child.FirstChild.Name -eq '#text' -and $child.ChildNodes.Count -eq 1) {
                if ($null -ne $child.Attributes -and $KeepAttributes ) {
                    #hah, an attribute
                    <#we need to record the text with the #text label and preserve all
					the attributes #>
                    $aHash = [ordered]@{ }
                    $child.Attributes | ForEach-Object {
                        $aHash.$($_.FirstChild.parentNode.LocalName) = $_.FirstChild.value
                    }
                    #now we add the text with an explicit name
                    $aHash.'#text' += $child.'#text'
                    $oHash.$childname += $aHash
                }
                else {
                    #phew, just a simple text attribute.
                    $oHash.$childname += $child.FirstChild.InnerText
                }
            }
            elseif ($null -ne $child.'#cdata-section' ) {
                # if it is a data section, a block of text that isnt parsed by the parser,
                # but is otherwise recognized as markup
                $oHash.$childname = $child.'#cdata-section'
            }
            elseif ($child.ChildNodes.Count -gt 1 -and
                        ($child | Get-Member -MemberType Property).Count -eq 1) {
                $oHash.$childname = @()
                foreach ($grandchild in $child.ChildNodes) {
                    $oHash.$childname += (ConvertFrom-PodeXml $grandchild)
                }
            }
            else {
                # create an array as a value  to the hashtable element
                $oHash.$childname += (ConvertFrom-PodeXml $child)
            }
        }
        return $oHash
    }
}


<#
.SYNOPSIS
    Returns the loaded configuration of the server.

.DESCRIPTION
    Returns the loaded configuration of the server.

.EXAMPLE
    $s = Get-PodeConfig
#>
function Get-PodeConfig {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    return $PodeContext.Server.Configuration
}


<#
.SYNOPSIS
    Returns the IIS application path.

.DESCRIPTION
    Returns the IIS application path, or null if not using IIS.

.EXAMPLE
    $path = Get-PodeIISApplicationPath
#>
function Get-PodeIISApplicationPath {
    [CmdletBinding()]
    param()

    if (!$PodeContext.Server.IsIIS) {
        return $null
    }

    return $PodeContext.Server.IIS.Path.Raw
}


<#
.SYNOPSIS
    Returns the literal path of the server.

.DESCRIPTION
    Returns the literal path of the server.

.EXAMPLE
    $path = Get-PodeServerPath
#>
function Get-PodeServerPath {
    [CmdletBinding()]
    [OutputType([string])]
    param()

    return $PodeContext.Server.Root
}


<#
.SYNOPSIS
    Gets the version of the Pode module.

.DESCRIPTION
    The Get-PodeVersion function checks the version of the Pode module specified in the module manifest. If the module version is not a placeholder value ('$version$'), it returns the actual version prefixed with 'v.'. If the module version is the placeholder value, indicating the development branch, it returns '[develop branch]'.

.PARAMETER None
    This function does not accept any parameters.

.OUTPUTS
    System.String
    Returns a string indicating the version of the Pode module or '[dev]' if on a development version.
#>
function Get-PodeVersion {
    if ($PodeManifest.ModuleVersion -ne '$version$') {
        return "v$($PodeManifest.ModuleVersion)"
    }
    else {
        return '[dev]'
    }
}


<#
.SYNOPSIS
    Imports a Module into the current, and all runspaces that Pode uses.

.DESCRIPTION
    Imports a Module into the current, and all runspaces that Pode uses. Modules can also be imported from the ps_modules directory.

.PARAMETER Name
    The name of a globally installed Module, or one within the ps_modules directory, to import.

.PARAMETER Path
    The path, literal or relative, to a Module to import.

.EXAMPLE
    Import-PodeModule -Name IISManager

.EXAMPLE
    Import-PodeModule -Path './modules/utilities.psm1'
#>
function Import-PodeModule {
    [CmdletBinding(DefaultParameterSetName = 'Name')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'Name')]
        [string]
        $Name,

        [Parameter(Mandatory = $true, ParameterSetName = 'Path')]
        [string]
        $Path
    )

    # script root path
    $rootPath = $null
    if ($null -eq $PodeContext) {
        $rootPath = (Protect-PodeValue -Value $MyInvocation.PSScriptRoot -Default $pwd.Path)
    }

    # get the path of a module, or import modules on mass
    switch ($PSCmdlet.ParameterSetName.ToLowerInvariant()) {
        'name' {
            $modulePath = Join-PodeServerRoot -Folder ([System.IO.Path]::Combine('ps_modules', $Name)) -Root $rootPath
            if (Test-PodePath -Path $modulePath -NoStatus) {
                $Path = (Get-ChildItem ([System.IO.Path]::Combine($modulePath, '*', "$($Name).ps*1")) -Recurse -Force | Select-Object -First 1).FullName
            }
            else {
                $Path = Find-PodeModuleFile -Name $Name -ListAvailable
            }
        }

        'path' {
            $Path = Get-PodeRelativePath -Path $Path -RootPath $rootPath -JoinRoot -Resolve
            $paths = Get-PodeWildcardFile -Path $Path -RootPath $rootPath -Wildcard '*.ps*1'
            if (!(Test-PodeIsEmpty $paths)) {
                foreach ($_path in $paths) {
                    Import-PodeModule -Path $_path
                }

                return
            }
        }
    }

    # if it's still empty, error
    if ([string]::IsNullOrWhiteSpace($Path)) {
        # Failed to import module
        throw ($PodeLocale.failedToImportModuleExceptionMessage -f (Protect-PodeValue -Value $Path -Default $Name))
    }

    # check if the path exists
    if (!(Test-PodePath $Path -NoStatus)) {
        # The module path does not exist
        throw ($PodeLocale.modulePathDoesNotExistExceptionMessage -f (Protect-PodeValue -Value $Path -Default $Name))
    }

    $null = Import-Module $Path -Force -DisableNameChecking -Scope Global -ErrorAction Stop
}


<#
.SYNOPSIS
    Imports a Snapin into the current, and all runspaces that Pode uses.

.DESCRIPTION
    Imports a Snapin into the current, and all runspaces that Pode uses.

.PARAMETER Name
    The name of a Snapin to import.

.EXAMPLE
    Import-PodeSnapin -Name 'WDeploySnapin3.0'
#>
function Import-PodeSnapin {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    # if non-windows or core, fail
    if ((Test-PodeIsPSCore) -or (Test-PodeIsUnix)) {
        # Snapins are only supported on Windows PowerShell
        throw ($PodeLocale.snapinsSupportedOnWindowsPowershellOnlyExceptionMessage)
    }

    # import the snap-in
    $null = Add-PSSnapin -Name $Name
}


<#
.SYNOPSIS
    Invokes the garbage collector.

.DESCRIPTION
    Invokes the garbage collector.

.EXAMPLE
    Invoke-PodeGC
#>
function Invoke-PodeGC {
    [CmdletBinding()]
    param()

    [System.GC]::Collect()
}


<#
.SYNOPSIS
    Invokes a ScriptBlock.

.DESCRIPTION
    Invokes a ScriptBlock, supplying optional arguments, splatting, and returning any optional values.

.PARAMETER ScriptBlock
    The ScriptBlock to invoke.

.PARAMETER Arguments
    Any arguments that should be supplied to the ScriptBlock.

.PARAMETER UsingVariables
    Optional array of "using-variable" values, which will be automatically prepended to any supplied Arguments when supplied to the ScriptBlock.

.PARAMETER Scoped
    Run the ScriptBlock in a scoped context.

.PARAMETER Return
    Return any values that the ScriptBlock may return.

.PARAMETER Splat
    Spat the argument onto the ScriptBlock.

.PARAMETER NoNewClosure
    Don't create a new closure before invoking the ScriptBlock.

.EXAMPLE
    Invoke-PodeScriptBlock -ScriptBlock { Write-PodeHost 'Hello!' }

.EXAMPLE
    Invoke-PodeScriptBlock -Arguments 'Morty' -ScriptBlock { /* logic */ }
#>
function Invoke-PodeScriptBlock {
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        $Arguments = $null,

        [Parameter()]
        [object[]]
        $UsingVariables = $null,

        [switch]
        $Scoped,

        [switch]
        $Return,

        [switch]
        $Splat,

        [switch]
        $NoNewClosure
    )

    # force no new closure if running serverless
    if ($PodeContext.Server.IsServerless) {
        $NoNewClosure = $true
    }

    # if new closure needed, create it
    if (!$NoNewClosure) {
        $ScriptBlock = ($ScriptBlock).GetNewClosure()
    }

    # merge arguments together, if we have using vars supplied
    if (($null -ne $UsingVariables) -and ($UsingVariables.Length -gt 0)) {
        $Arguments = @(Merge-PodeScriptblockArguments -ArgumentList $Arguments -UsingVariables $UsingVariables)
    }

    # invoke the scriptblock
    if ($Scoped) {
        if ($Splat) {
            $result = (& $ScriptBlock @Arguments)
        }
        else {
            $result = (& $ScriptBlock $Arguments)
        }
    }
    else {
        if ($Splat) {
            $result = (. $ScriptBlock @Arguments)
        }
        else {
            $result = (. $ScriptBlock $Arguments)
        }
    }

    # if needed, return the result
    if ($Return) {
        return $result
    }
}


<#
.SYNOPSIS
    Merges Arguments and Using Variables together.

.DESCRIPTION
    Merges Arguments and Using Variables together to be supplied to a ScriptBlock.
    The Using Variables will be prepended so then are supplied first to a ScriptBlock.

.PARAMETER ArgumentList
    And optional array of Arguments.

.PARAMETER UsingVariables
    And optional array of "using-variable" values to be prepended.

.EXAMPLE
    $Arguments = @(Merge-PodeScriptblockArguments -ArgumentList $Arguments -UsingVariables $UsingVariables)

.EXAMPLE
    $Arguments = @(Merge-PodeScriptblockArguments -UsingVariables $UsingVariables)
#>
function Merge-PodeScriptblockArguments {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter()]
        [object[]]
        $ArgumentList = $null,

        [Parameter()]
        [object[]]
        $UsingVariables = $null
    )

    if ($null -eq $ArgumentList) {
        $ArgumentList = @()
    }

    if (($null -eq $UsingVariables) -or ($UsingVariables.Length -le 0)) {
        return $ArgumentList
    }

    $_vars = @()
    foreach ($_var in $UsingVariables) {
        $_vars += , $_var.Value
    }

    return ($_vars + $ArgumentList)
}


<#
.SYNOPSIS
    A helper function to generate cron expressions.

.DESCRIPTION
    A helper function to generate cron expressions, which can be used for Schedules and other functions that use cron expressions.
    This helper function only covers simple cron use-cases, with some advanced use-cases. If you need further advanced cron
    expressions it would be best to write the expression by hand.

.PARAMETER Minute
    This is an array of Minutes that the expression should use between 0-59.

.PARAMETER Hour
    This is an array of Hours that the expression should use between 0-23.

.PARAMETER Date
    This is an array of Dates in the monnth that the expression should use between 1-31.

.PARAMETER Month
    This is an array of Months that the expression should use between January-December.

.PARAMETER Day
    This is an array of Days in the week that the expression should use between Monday-Sunday.

.PARAMETER Every
    This can be used to more easily specify "Every Hour" than writing out all the hours.

.PARAMETER Interval
    This can only be used when using the Every parameter, and will setup an interval on the "every" used.
    If you want "every 2 hours" then Every should be set to Hour and Interval to 2.

.EXAMPLE
    New-PodeCron -Every Day                                             # every 00:00

.EXAMPLE
    New-PodeCron -Every Day -Day Tuesday, Friday -Hour 1                # every tuesday and friday at 01:00

.EXAMPLE
    New-PodeCron -Every Month -Date 15                                  # every 15th of the month at 00:00

.EXAMPLE
    New-PodeCron -Every Date -Interval 2 -Date 2                        # every month, every other day from 2nd, at 00:00

.EXAMPLE
    New-PodeCron -Every Year -Month June                                # every 1st june, at 00:00

.EXAMPLE
    New-PodeCron -Every Hour -Hour 1 -Interval 1                        # every hour, starting at 01:00

.EXAMPLE
    New-PodeCron -Every Minute -Hour 1, 2, 3, 4, 5 -Interval 15         # every 15mins, starting at 01:00 until 05:00

.EXAMPLE
    New-PodeCron -Every Hour -Day Monday                                # every hour of every monday

.EXAMPLE
    New-PodeCron -Every Quarter                                         # every 1st jan, apr, jul, oct, at 00:00
#>
function New-PodeCron {
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Parameter()]
        [ValidateRange(0, 59)]
        [int[]]
        $Minute = $null,

        [Parameter()]
        [ValidateRange(0, 23)]
        [int[]]
        $Hour = $null,

        [Parameter()]
        [ValidateRange(1, 31)]
        [int[]]
        $Date = $null,

        [Parameter()]
        [ValidateSet('January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December')]
        [string[]]
        $Month = $null,

        [Parameter()]
        [ValidateSet('Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday')]
        [string[]]
        $Day = $null,

        [Parameter()]
        [ValidateSet('Minute', 'Hour', 'Day', 'Date', 'Month', 'Quarter', 'Year', 'None')]
        [string]
        $Every = 'None',

        [Parameter()]
        [int]
        $Interval = 0
    )

    # cant have None and Interval
    if (($Every -ieq 'none') -and ($Interval -gt 0)) {
        # Cannot supply an interval when the parameter `Every` is set to None
        throw ($PodeLocale.cannotSupplyIntervalWhenEveryIsNoneExceptionMessage)
    }

    # base cron
    $cron = @{
        Minute = '*'
        Hour   = '*'
        Date   = '*'
        Month  = '*'
        Day    = '*'
    }

    # convert month/day to numbers
    if ($Month.Length -gt 0) {
        $MonthInts = @(foreach ($item in $Month) {
            (@{
                    January   = 1
                    February  = 2
                    March     = 3
                    April     = 4
                    May       = 5
                    June      = 6
                    July      = 7
                    August    = 8
                    September = 9
                    October   = 10
                    November  = 11
                    December  = 12
                })[$item]
            })
    }

    if ($Day.Length -gt 0) {
        $DayInts = @(foreach ($item in $Day) {
            (@{
                    Sunday    = 0
                    Monday    = 1
                    Tuesday   = 2
                    Wednesday = 3
                    Thursday  = 4
                    Friday    = 5
                    Saturday  = 6
                })[$item]
            })
    }

    # set "every" defaults
    switch ($Every.ToUpperInvariant()) {
        'MINUTE' {
            if (Set-PodeCronInterval -Cron $cron -Type 'Minute' -Value $Minute -Interval $Interval) {
                $Minute = @()
            }
        }

        'HOUR' {
            $cron.Minute = '0'

            if (Set-PodeCronInterval -Cron $cron -Type 'Hour' -Value $Hour -Interval $Interval) {
                $Hour = @()
            }
        }

        'DAY' {
            $cron.Minute = '0'
            $cron.Hour = '0'

            if (Set-PodeCronInterval -Cron $cron -Type 'Day' -Value $DayInts -Interval $Interval) {
                $DayInts = @()
            }
        }

        'DATE' {
            $cron.Minute = '0'
            $cron.Hour = '0'

            if (Set-PodeCronInterval -Cron $cron -Type 'Date' -Value $Date -Interval $Interval) {
                $Date = @()
            }
        }

        'MONTH' {
            $cron.Minute = '0'
            $cron.Hour = '0'

            if ($DayInts.Length -eq 0) {
                $cron.Date = '1'
            }

            if (Set-PodeCronInterval -Cron $cron -Type 'Month' -Value $MonthInts -Interval $Interval) {
                $MonthInts = @()
            }
        }

        'QUARTER' {
            $cron.Minute = '0'
            $cron.Hour = '0'
            $cron.Date = '1'
            $cron.Month = '1,4,7,10'

            if ($Interval -gt 0) {
                # Cannot supply interval value for every quarter
                throw ($PodeLocale.cannotSupplyIntervalForQuarterExceptionMessage)
            }
        }

        'YEAR' {
            $cron.Minute = '0'
            $cron.Hour = '0'
            $cron.Date = '1'
            $cron.Month = '1'

            if ($Interval -gt 0) {
                # Cannot supply interval value for every year
                throw ($PodeLocale.cannotSupplyIntervalForYearExceptionMessage)
            }
        }
    }

    # set any custom overrides
    if ($Minute.Length -gt 0) {
        $cron.Minute = $Minute -join ','
    }

    if ($Hour.Length -gt 0) {
        $cron.Hour = $Hour -join ','
    }

    if ($DayInts.Length -gt 0) {
        $cron.Day = $DayInts -join ','
    }

    if ($Date.Length -gt 0) {
        $cron.Date = $Date -join ','
    }

    if ($MonthInts.Length -gt 0) {
        $cron.Month = $MonthInts -join ','
    }

    # build and return
    return "$($cron.Minute) $($cron.Hour) $($cron.Date) $($cron.Month) $($cron.Day)"
}


<#
.SYNOPSIS
    Outputs an object to the main Host.

.DESCRIPTION
    Due to Pode's use of runspaces, this will output a given object back to the main Host.
    It's advised to use this function, so that any output respects the -Quiet flag of the server.

.PARAMETER InputObject
    The object to output.

.EXAMPLE
    'Hello, world!' | Out-PodeHost

.EXAMPLE
    @{ Name = 'Rick' } | Out-PodeHost
#>
function Out-PodeHost {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [object]
        $InputObject
    )
    begin {
        # Initialize an array to hold piped-in values
        $pipelineValue = @()
    }

    process {
        # Add the current piped-in value to the array
        $pipelineValue += $_
    }

    end {
        if ($PodeContext.Server.Console.Quiet) {
            return
        }
        # Set InputObject to the array of values
        if ($pipelineValue.Count -gt 1) {
            $InputObject = $pipelineValue
            $InputObject | Out-Default
        }
        else {
            Out-Default -InputObject $InputObject
        }
    }

}


<#
.SYNOPSIS
    Defines variables to be created when the Pode server stops.

.DESCRIPTION
    Allows you to define a variable, with a value, that should be created on the in the main scope after the Pode server is stopped.

.PARAMETER Name
    The Name of the variable to be set

.PARAMETER Value
    The Value of the variable to be set

.EXAMPLE
    Out-PodeVariable -Name ExampleVar -Value @{ Name = 'Bob' }
#>
function Out-PodeVariable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Position = 0, ValueFromPipeline = $true)]
        [object]
        $Value
    )
    begin {
        # Initialize an array to hold piped-in values
        $pipelineValue = @()
    }

    process {
        # Add the current piped-in value to the array
        $pipelineValue += $_
    }

    end {
        # Set Value to the array of values
        if ($pipelineValue.Count -gt 1) {
            $Value = $pipelineValue
        }

        $PodeContext.Server.Output.Variables[$Name] = $Value
    }
}


<#
.SYNOPSIS
    Resolves and protects a value by ensuring it defaults to a specified fallback and optionally parses it as an enum.

.DESCRIPTION
    The `Protect-PodeValue` function ensures that a given value is resolved. If the value is empty, a default value is used instead.
    Additionally, the function can parse the resolved value as an enum type with optional case sensitivity.

.PARAMETER Value
    The input value to be resolved.

.PARAMETER Default
    The default value to fall back to if the input value is empty.

.PARAMETER EnumType
    The type of enum to parse the resolved value into. If specified, the resolved value must be a valid enum member.

.PARAMETER CaseSensitive
    Specifies whether the enum parsing should be case-sensitive. By default, parsing is case-insensitive.

.OUTPUTS
    [object]
    Returns the resolved value, either as the original value, the default value, or a parsed enum.

.EXAMPLE
    # Example 1: Resolve a value with a default fallback
    $resolved = Protect-PodeValue -Value $null -Default "Fallback"
    Write-Output $resolved  # Output: Fallback

.EXAMPLE
    # Example 2: Resolve and parse a value as a case-insensitive enum
    $resolvedEnum = Protect-PodeValue -Value "red" -Default "Blue" -EnumType ([type][System.ConsoleColor])
    Write-Output $resolvedEnum  # Output: Red

.EXAMPLE
    # Example 3: Resolve and parse a value as a case-sensitive enum
    $resolvedEnum = Protect-PodeValue -Value "red" -Default "Blue" -EnumType ([type][System.ConsoleColor]) -CaseSensitive
    # Throws an error if "red" does not match an enum member exactly (case-sensitive).

.NOTES
    This function resolves values using `Resolve-PodeValue` and validates enums using `[enum]::IsDefined`.

#>
function Protect-PodeValue {
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter()]
        $Value,

        [Parameter()]
        $Default,

        [Parameter()]
        [Type]
        $EnumType,

        [switch]
        $CaseSensitive
    )

    $resolvedValue = Resolve-PodeValue -Check (Test-PodeIsEmpty $Value) -TrueValue $Default -FalseValue $Value

    if ($null -ne $EnumType -and [enum]::IsDefined($EnumType, $resolvedValue)) {
        # Use $CaseSensitive to determine if case sensitivity should apply
        return [enum]::Parse($EnumType, $resolvedValue, !$CaseSensitive.IsPresent)
    }

    return $resolvedValue
}


<#
.SYNOPSIS
    Resolves a query, and returns a value based on the response.

.DESCRIPTION
    Resolves a query, and returns a value based on the response.

.PARAMETER Check
    The query, or variable, to evalulate.

.PARAMETER TrueValue
    The value to use if evaluated to True.

.PARAMETER FalseValue
    The value to use if evaluated to False.

.EXAMPLE
    $Port = Resolve-PodeValue -Check $AllowSsl -TrueValue 443 -FalseValue -80
#>
function Resolve-PodeValue {
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory = $true)]
        [bool]
        $Check,

        [Parameter()]
        $TrueValue,

        [Parameter()]
        $FalseValue
    )

    if ($Check) {
        return $TrueValue
    }

    return $FalseValue
}


<#
.SYNOPSIS
    A function to pause execution for a specified duration.
    This function should be used in Pode as replacement for Start-Sleep

.DESCRIPTION
    The `Start-PodeSleep` function pauses script execution for a given duration specified in seconds, milliseconds, or a TimeSpan.

.PARAMETER Seconds
    Specifies the duration to pause execution in seconds. Default is 1 second.

.PARAMETER Milliseconds
    Specifies the duration to pause execution in milliseconds.

.PARAMETER Duration
    Specifies the duration to pause execution using a TimeSpan object.

.PARAMETER Activity
    Specifies the activity name displayed in the progress bar. Default is "Sleeping...".

.PARAMETER ParentId
    Optional parameter to specify the ParentId for the progress bar, enabling hierarchical grouping.

.PARAMETER ShowProgress
    Switch to enable the progress bar during the sleep duration.

.OUTPUTS
    None.

.EXAMPLE
    Start-PodeSleep -Seconds 5

    Pauses execution for 5 seconds.

.NOTES
    This function is useful for scenarios where tracking the remaining wait time visually is helpful.
#>
function Start-PodeSleep {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, Mandatory = $false, ParameterSetName = 'Seconds')]
        [int]
        $Seconds = 1,

        [Parameter(Position = 0, Mandatory = $false, ParameterSetName = 'Milliseconds')]
        [int]
        $Milliseconds,

        [Parameter(Position = 0, Mandatory = $false, ParameterSetName = 'Duration')]
        [TimeSpan]
        $Duration
    )

    # Determine the total duration
    $totalDuration = switch ($PSCmdlet.ParameterSetName) {
        'Seconds' { [TimeSpan]::FromSeconds($Seconds) }
        'Milliseconds' { [TimeSpan]::FromMilliseconds($Milliseconds) }
        'Duration' { $Duration }
    }

    # Calculate end time
    $startTime = [DateTime]::UtcNow
    $endTime = $startTime.Add($totalDuration)

    # Precompute sleep interval (total duration divided by 100 - ie 100%)
    $sleepInterval = [math]::Max($totalDuration.TotalMilliseconds / 100, 10)

    # Main loop
    while ([DateTime]::UtcNow -lt $endTime) {
        # Sleep for the interval
        Start-Sleep -Milliseconds $sleepInterval
    }
}


<#
.SYNOPSIS
    Starts a Stopwatch on some ScriptBlock, and outputs the duration at the end.

.DESCRIPTION
    Starts a Stopwatch on some ScriptBlock, and outputs the duration at the end.

.PARAMETER Name
    The name of the Stopwatch.

.PARAMETER ScriptBlock
    The ScriptBlock to time.

.EXAMPLE
    Start-PodeStopwatch -Name 'ReadFile' -ScriptBlock { $content = Get-Content './file.txt' }
#>
function Start-PodeStopwatch {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [scriptblock]
        $ScriptBlock
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
        try {
            $watch = [System.Diagnostics.Stopwatch]::StartNew()
            . $ScriptBlock
        }
        catch {
            $_ | Write-PodeErrorLog
            throw $_.Exception
        }
        finally {
            $watch.Stop()
            "[Stopwatch]: $($watch.Elapsed) [$($Name)]" | Out-PodeHost
        }
    }
}


<#
.SYNOPSIS
    Tests if the scope you're in is currently within a Pode runspace.

.DESCRIPTION
    Tests if the scope you're in is currently within a Pode runspace.

.EXAMPLE
    If (Test-PodeInRunspace) { ... }
#>
function Test-PodeInRunspace {
    [CmdletBinding()]
    param()

    return ([bool]$PODE_SCOPE_RUNSPACE)
}


<#
.SYNOPSIS
    Tests if a value is empty - the value can be of any type.

.DESCRIPTION
    Tests if a value is empty - the value can be of any type.

.PARAMETER Value
    The value to test.

.EXAMPLE
    if (Test-PodeIsEmpty @{}) { /* logic */ }
#>
function Test-PodeIsEmpty {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter()]
        $Value
    )

    if ($null -eq $Value) {
        return $true
    }

    if ($Value -is [string]) {
        return [string]::IsNullOrWhiteSpace($Value)
    }

    if ($Value -is [array]) {
        return ($Value.Length -eq 0)
    }

    if (($Value -is [hashtable]) -or ($Value -is [System.Collections.Specialized.OrderedDictionary])) {
        return ($Value.Count -eq 0)
    }

    if ($Value -is [scriptblock]) {
        return ([string]::IsNullOrWhiteSpace($Value.ToString()))
    }

    if ($Value -is [valuetype]) {
        return $false
    }

    return ([string]::IsNullOrWhiteSpace($Value) -or ((Get-PodeCount $Value) -eq 0))
}


<#
.SYNOPSIS
    Returns whether or not the server is running via Heroku.

.DESCRIPTION
    Returns whether or not the server is running via Heroku.

.EXAMPLE
    if (Test-PodeIsHeroku) { }
#>
function Test-PodeIsHeroku {
    [CmdletBinding()]
    param()

    return $PodeContext.Server.IsHeroku
}


<#
.SYNOPSIS
    Returns whether or not the server is being hosted behind another application.

.DESCRIPTION
    Returns whether or not the server is being hosted behind another application, such as Heroku or IIS.

.EXAMPLE
    if (Test-PodeIsHosted) { }
#>
function Test-PodeIsHosted {
    [CmdletBinding()]
    param()

    return ((Test-PodeIsIIS) -or (Test-PodeIsHeroku))
}


<#
.SYNOPSIS
    Returns whether or not the server is running via IIS.

.DESCRIPTION
    Returns whether or not the server is running via IIS.

.EXAMPLE
    if (Test-PodeIsIIS) { }
#>
function Test-PodeIsIIS {
    [CmdletBinding()]
    param()

    return $PodeContext.Server.IsIIS
}


<#
.SYNOPSIS
    Tests if the current OS is MacOS.

.DESCRIPTION
    Tests if the current OS is MacOS.

.EXAMPLE
    if (Test-PodeIsMacOS) { /* logic */ }
#>
function Test-PodeIsMacOS {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return ([bool]$IsMacOS)
}


<#
.SYNOPSIS
    Tests if the the current session is running in PowerShell Core.

.DESCRIPTION
    Tests if the the current session is running in PowerShell Core.

.EXAMPLE
    if (Test-PodeIsPSCore) { /* logic */ }
#>
function Test-PodeIsPSCore {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return (Get-PodePSVersionTable).PSEdition -ieq 'core'
}


<#
.SYNOPSIS
    Tests if the current OS is Unix.

.DESCRIPTION
    Tests if the current OS is Unix.

.EXAMPLE
    if (Test-PodeIsUnix) { /* logic */ }
#>
function Test-PodeIsUnix {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return (Get-PodePSVersionTable).Platform -ieq 'unix'
}


<#
.SYNOPSIS
    Tests if the current OS is Windows.

.DESCRIPTION
    Tests if the current OS is Windows.

.EXAMPLE
    if (Test-PodeIsWindows) { /* logic */ }
#>
function Test-PodeIsWindows {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $v = Get-PodePSVersionTable
    return ($v.Platform -ilike '*win*' -or ($null -eq $v.Platform -and $v.PSEdition -ieq 'desktop'))
}


<#
.SYNOPSIS
    Automatically loads endware ps1 files

.DESCRIPTION
    Automatically loads endware ps1 files from either a /endware folder, or a custom folder. Saves space dot-sourcing them all one-by-one.

.PARAMETER Path
    Optional Path to a folder containing ps1 files, can be relative or literal.

.EXAMPLE
    Use-PodeEndware

.EXAMPLE
    Use-PodeEndware -Path './endware'
#>
function Use-PodeEndware {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Path
    )

    Use-PodeFolder -Path $Path -DefaultPath 'endware'
}


<#
.SYNOPSIS
    Loads a script, by dot-sourcing, at the supplied path.

.DESCRIPTION
    Loads a script, by dot-sourcing, at the supplied path. If the path is relative, the server's path is prepended.

.PARAMETER Path
    The path, literal or relative to the server, to some script.

.EXAMPLE
    Use-PodeScript -Path './scripts/tools.ps1'
#>
function Use-PodeScript {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Path
    )

    # if path is '.', replace with server root
    $_path = Get-PodeRelativePath -Path $Path -JoinRoot -Resolve

    # we have a path, if it's a directory/wildcard then loop over all files
    if (![string]::IsNullOrWhiteSpace($_path)) {
        $_paths = Get-PodeWildcardFile -Path $Path -Wildcard '*.ps1'
        if (!(Test-PodeIsEmpty $_paths)) {
            foreach ($_path in $_paths) {
                Use-PodeScript -Path $_path
            }

            return
        }
    }

    # check if the path exists
    if (!(Test-PodePath $_path -NoStatus)) {
        # The script path does not exist
        throw ($PodeLocale.scriptPathDoesNotExistExceptionMessage -f (Protect-PodeValue -Value $_path -Default $Path))
    }

    # dot-source the script
    . $_path

    # load any functions from the file into pode's runspaces
    Import-PodeFunctionsIntoRunspaceState -FilePath $_path
}


<#
.SYNOPSIS
    Like the "using" keyword in .NET. Allows you to use a Stream and then disposes of it.

.DESCRIPTION
    Like the "using" keyword in .NET. Allows you to use a Stream and then disposes of it.

.PARAMETER Stream
    The Stream to use and then dispose.

.PARAMETER ScriptBlock
    The ScriptBlock to invoke. It will be supplied the Stream.

.EXAMPLE
    $content = (Use-PodeStream -Stream $stream -ScriptBlock { return $args[0].ReadToEnd() })
#>
function Use-PodeStream {
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory = $true)]
        [System.IDisposable]
        $Stream,

        [Parameter(Mandatory = $true)]
        [scriptblock]
        $ScriptBlock
    )

    try {
        return (Invoke-PodeScriptBlock -ScriptBlock $ScriptBlock -Arguments $Stream -Return -NoNewClosure)
    }
    catch {
        $_ | Write-PodeErrorLog
        throw $_.Exception
    }
    finally {
        $Stream.Dispose()
    }
}


<#
.SYNOPSIS
    Writes an object to the Host.

.DESCRIPTION
    Writes an object to the Host.
    It's advised to use this function, so that any output respects the -Quiet flag of the server.

.PARAMETER Object
    The object to write.

.PARAMETER ForegroundColor
    An optional foreground colour.

.PARAMETER NoNewLine
    Whether or not to write a new line.

.PARAMETER Explode
    Show the object content

.PARAMETER ShowType
    Show the Object Type

.PARAMETER Label
    Show a label for the object

.PARAMETER Force
    Overrides the -Quiet flag of the server.

.EXAMPLE
    'Some output' | Write-PodeHost -ForegroundColor Cyan
#>
function Write-PodeHost {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '')]
    [CmdletBinding(DefaultParameterSetName = 'inbuilt')]
    param(
        [Parameter(Position = 0, ValueFromPipeline = $true)]
        [object]
        $Object,

        [Parameter()]
        [System.ConsoleColor]
        $ForegroundColor,

        [switch]
        $NoNewLine,

        [Parameter( Mandatory = $true, ParameterSetName = 'object')]
        [switch]
        $Explode,

        [Parameter( Mandatory = $false, ParameterSetName = 'object')]
        [switch]
        $ShowType,

        [Parameter( Mandatory = $false, ParameterSetName = 'object')]
        [string]
        $Label,

        [switch]
        $Force
    )
    begin {
        # Initialize an array to hold piped-in values
        $pipelineValue = @()
    }

    process {
        # Add the current piped-in value to the array
        $pipelineValue += $_
    }

    end {
        if ($PodeContext.Server.Console.Quiet -and !($Force.IsPresent)) {
            return
        }
        # Set Object to the array of values
        if ($pipelineValue.Count -gt 1) {
            $Object = $pipelineValue
        }

        if ($Explode.IsPresent ) {
            if ($null -eq $Object) {
                if ($ShowType) {
                    $Object = "`tNull Value"
                }
            }
            else {
                $type = $Object.gettype().FullName
                $Object = $Object | Out-String
                if ($ShowType) {
                    $Object = "`tTypeName: $type`n$Object"
                }
            }
            if ($Label) {
                $Object = "`tName: $Label $Object"
            }

        }

        if ($ForegroundColor) {
            if ($pipelineValue.Count -gt 1) {
                $Object | Write-Host -ForegroundColor $ForegroundColor -NoNewline:$NoNewLine
            }
            else {
                Write-Host -Object $Object -ForegroundColor $ForegroundColor -NoNewline:$NoNewLine
            }
        }
        else {
            if ($pipelineValue.Count -gt 1) {
                $Object | Write-Host -NoNewline:$NoNewLine
            }
            else {
                Write-Host -Object $Object -NoNewline:$NoNewLine
            }
        }
    }
}


<#
.SYNOPSIS
    Adds a Verb for a TCP data.

.DESCRIPTION
    Adds a Verb for a TCP data.

.PARAMETER Verb
    The Verb for the Verb.

.PARAMETER ScriptBlock
    A ScriptBlock for the Verb's main logic.

.PARAMETER EndpointName
    The EndpointName of an Endpoint(s) this Verb should be bound against.

.PARAMETER FilePath
    A literal, or relative, path to a file containing a ScriptBlock for the Verb's main logic.

.PARAMETER ArgumentList
    An array of arguments to supply to the Verb's ScriptBlock.

.PARAMETER UpgradeToSsl
    If supplied, the Verb will auto-upgrade the connection to use SSL.

.PARAMETER Close
    If supplied, the Verb will auto-close the connection.

.EXAMPLE
    Add-PodeVerb -Verb 'Hello' -ScriptBlock { /* logic */ }

.EXAMPLE
    Add-PodeVerb -Verb 'Hello' -ScriptBlock { /* logic */ } -ArgumentList 'arg1', 'arg2'

.EXAMPLE
    Add-PodeVerb -Verb 'Quit' -Close

.EXAMPLE
    Add-PodeVerb -Verb 'StartTls' -UpgradeToSsl
#>
function Add-PodeVerb {
    [CmdletBinding(DefaultParameterSetName = 'Script')]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Verb,

        [Parameter(ParameterSetName = 'Script')]
        [scriptblock]
        $ScriptBlock,

        [Parameter(Mandatory = $true, ParameterSetName = 'File')]
        [string]
        $FilePath,

        [Parameter()]
        [object[]]
        $ArgumentList,

        [Parameter()]
        [string[]]
        $EndpointName,

        [switch]
        $UpgradeToSsl,

        [switch]
        $Close
    )

    # find placeholder parameters in verb (ie: COMMAND :parameter)
    $Verb = Resolve-PodePlaceholder -Path $Verb

    # get endpoints from name
    $endpoints = Find-PodeEndpoint -EndpointName $EndpointName

    # ensure the verb doesn't already exist for each endpoint
    foreach ($_endpoint in $endpoints) {
        Test-PodeVerbAndError -Verb $Verb -Protocol $_endpoint.Protocol -Address $_endpoint.Address
    }

    # if scriptblock and file path are all null/empty, error
    if ((Test-PodeIsEmpty $ScriptBlock) -and (Test-PodeIsEmpty $FilePath) -and !$Close -and !$UpgradeToSsl) {
        # [Verb] Verb: No logic passed
        throw ($PodeLocale.verbNoLogicPassedExceptionMessage -f $Verb)
    }

    # if we have a file path supplied, load that path as a scriptblock
    if ($PSCmdlet.ParameterSetName -ieq 'file') {
        $ScriptBlock = Convert-PodeFileToScriptBlock -FilePath $FilePath
    }

    # check for scoped vars
    $ScriptBlock, $usingVars = Convert-PodeScopedVariables -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState

    # add the verb(s)
    Write-Verbose "Adding Verb: $($Verb)"
    $PodeContext.Server.Verbs[$Verb] += @(foreach ($_endpoint in $endpoints) {
            @{
                Logic          = $ScriptBlock
                UsingVariables = $usingVars
                Endpoint       = @{
                    Protocol = $_endpoint.Protocol
                    Address  = $_endpoint.Address.Trim()
                    Name     = $_endpoint.Name
                }
                Arguments      = $ArgumentList
                Verb           = $Verb
                Connection     = @{
                    UpgradeToSsl = $UpgradeToSsl
                    Close        = $Close
                }
            }
        })
}


<#
.SYNOPSIS
    Removes all added Verbs.

.DESCRIPTION
    Removes all added Verbs.

.EXAMPLE
    Clear-PodeVerbs
#>
function Clear-PodeVerbs {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    [CmdletBinding()]
    param()

    $PodeContext.Server.Verbs.Clear()
}


<#
.SYNOPSIS
    Get a Verb(s).

.DESCRIPTION
    Get a Verb(s).

.PARAMETER Verb
    A Verb to filter the verbs.

.PARAMETER EndpointName
    The name of an endpoint to filter verbs.

.EXAMPLE
    Get-PodeVerb -Verb 'Hello'

.EXAMPLE
    Get-PodeVerb -Verb 'Hello :username' -EndpointName User
#>
function Get-PodeVerb {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Verb,

        [Parameter()]
        [string[]]
        $EndpointName
    )

    # start off with every verb
    $verbs = @()

    # if we have a verb, filter
    if (![string]::IsNullOrWhiteSpace($Verb)) {
        $Verb = Resolve-PodePlaceholder -Path $Verb
        $verbs = $PodeContext.Server.Verbs[$Verb]
    }
    else {
        foreach ($v in $PodeContext.Server.Verbs.Values) {
            $verbs += $v
        }
    }

    # further filter by endpoint names
    if (($null -ne $EndpointName) -and ($EndpointName.Length -gt 0)) {
        $verbs = @(foreach ($name in $EndpointName) {
                foreach ($v in $verbs) {
                    if ($v.Endpoint.Name -ine $name) {
                        continue
                    }

                    $v
                }
            })
    }

    # return
    return $verbs
}


<#
.SYNOPSIS
    Remove a specific Verb.

.DESCRIPTION
    Remove a specific Verb.

.PARAMETER Verb
    The Verb of the Verb to remove.

.PARAMETER EndpointName
    The EndpointName of an Endpoint(s) bound to the Verb to be removed.

.EXAMPLE
    Remove-PodeVerb -Verb 'Hello'

.EXAMPLE
    Remove-PodeVerb -Verb 'Hello :username' -EndpointName User
#>
function Remove-PodeVerb {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Verb,

        [Parameter()]
        [string]
        $EndpointName
    )

    # ensure the verb placeholders are replaced
    $Verb = Resolve-PodePlaceholder -Path $Verb

    # ensure verb does exist
    if (!$PodeContext.Server.Verbs.Contains($Verb)) {
        return
    }

    # remove the verb's logic
    $PodeContext.Server.Verbs[$Verb] = @($PodeContext.Server.Verbs[$Verb] | Where-Object {
            $_.Endpoint.Name -ine $EndpointName
        })

    # if the verb has no more logic, just remove it
    if ((Get-PodeCount $PodeContext.Server.Verbs[$Verb]) -eq 0) {
        $null = $PodeContext.Server.Verbs.Remove($Verb)
    }
}


<#
.SYNOPSIS
    Automatically loads verb ps1 files

.DESCRIPTION
    Automatically loads verb ps1 files from either a /verbs folder, or a custom folder. Saves space dot-sourcing them all one-by-one.

.PARAMETER Path
    Optional Path to a folder containing ps1 files, can be relative or literal.

.EXAMPLE
    Use-PodeVerbs

.EXAMPLE
    Use-PodeVerbs -Path './my-verbs'
#>
function Use-PodeVerbs {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Path
    )

    Use-PodeFolder -Path $Path -DefaultPath 'verbs'
}


<#
.SYNOPSIS
    Connect to an external WebSocket.

.DESCRIPTION
    Connect to an external WebSocket.

.PARAMETER Name
    The Name of the WebSocket connection.

.PARAMETER Url
    The URL of the WebSocket. Should start with either ws:// or wss://.

.PARAMETER ScriptBlock
    The ScriptBlock to invoke for processing received messages from the WebSocket. The ScriptBlock will have access to a $WsEvent variable with details of the received message.

.PARAMETER FilePath
    A literal, or relative, path to a file containing a ScriptBlock for the WebSocket's logic.

.PARAMETER ContentType
    An optional ContentType for parsing/converting received/sent messages. (default: application/json)

.PARAMETER ArgumentList
    AN optional array of extra arguments, that will be passed to the ScriptBlock.

.EXAMPLE
    Connect-PodeWebSocket -Name 'Example' -Url 'ws://example.com/some/socket' -ScriptBlock { ... }

.EXAMPLE
    Connect-PodeWebSocket -Name 'Example' -Url 'ws://example.com/some/socket' -ScriptBlock { param($arg1, $arg2) ... } -ArgumentList 'arg1', 'arg2'

.EXAMPLE
    Connect-PodeWebSocket -Name 'Example' -Url 'ws://example.com/some/socket' -FilePath './some/path/file.ps1'

.EXAMPLE
    Connect-PodeWebSocket -Name 'Example' -Url 'ws://example.com/some/socket' -ScriptBlock { ... } -ContentType 'text/xml'
#>
function Connect-PodeWebSocket {
    [CmdletBinding(DefaultParameterSetName = 'Script')]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true)]
        [string]
        $Url,

        [Parameter(ParameterSetName = 'Script')]
        [scriptblock]
        $ScriptBlock,

        [Parameter(Mandatory = $true, ParameterSetName = 'File')]
        [string]
        $FilePath,

        [Parameter()]
        [string]
        $ContentType = 'application/json',

        [Parameter()]
        [object[]]
        $ArgumentList
    )

    # ensure we have a receiver
    New-PodeWebSocketReceiver

    # fail if already exists
    if (Test-PodeWebSocket -Name $Name) {
        # Already connected to websocket with name
        throw ($PodeLocale.alreadyConnectedToWebSocketExceptionMessage -f $Name)
    }

    # if we have a file path supplied, load that path as a scriptblock
    if ($PSCmdlet.ParameterSetName -ieq 'file') {
        $ScriptBlock = Convert-PodeFileToScriptBlock -FilePath $FilePath
    }

    # check for scoped vars
    $ScriptBlock, $usingVars = Convert-PodeScopedVariables -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState

    # connect
    try {
        $null = Wait-PodeTask -Task $PodeContext.Server.WebSockets.Receiver.ConnectWebSocket($Name, $Url, $ContentType)
    }
    catch {
        # Failed to connect to websocket
        throw ($PodeLocale.failedToConnectToWebSocketExceptionMessage -f $ErrorMessage)
    }

    $PodeContext.Server.WebSockets.Connections[$Name] = @{
        Name           = $Name
        Url            = $Url
        Logic          = $ScriptBlock
        UsingVariables = $usingVars
        Arguments      = $ArgumentList
    }
}


<#
.SYNOPSIS
    Disconnect from a WebSocket connection.

.DESCRIPTION
    Disconnect from a WebSocket connection. These connections can be reconnected later using Reset-PodeWebSocket

.PARAMETER Name
    The Name of the WebSocket connection (optional if in the scope where $WsEvent is available).

.EXAMPLE
    Disconnect-PodeWebSocket -Name 'Example'
#>
function Disconnect-PodeWebSocket {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Name
    )

    if ([string]::IsNullOrWhiteSpace($Name) -and ($null -ne $WsEvent)) {
        $Name = $WsEvent.Request.WebSocket.Name
    }

    if ([string]::IsNullOrWhiteSpace($Name)) {
        # No Name for a WebSocket to disconnect from supplied
        throw ($PodeLocale.noNameForWebSocketDisconnectExceptionMessage)
    }

    if (Test-PodeWebSocket -Name $Name) {
        $PodeContext.Server.WebSockets.Receiver.DisconnectWebSocket($Name)
    }
}


<#
.SYNOPSIS
    Remove a WebSocket connection.

.DESCRIPTION
    Disconnects and then removes a WebSocket connection.

.PARAMETER Name
    The Name of the WebSocket connection (optional if in the scope where $WsEvent is available).

.EXAMPLE
    Remove-PodeWebSocket -Name 'Example'
#>
function Remove-PodeWebSocket {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Name
    )

    if ([string]::IsNullOrWhiteSpace($Name) -and ($null -ne $WsEvent)) {
        $Name = $WsEvent.Request.WebSocket.Name
    }

    if ([string]::IsNullOrWhiteSpace($Name)) {
        # No Name for a WebSocket to remove supplied
        throw ($PodeLocale.noNameForWebSocketRemoveExceptionMessage)
    }

    $PodeContext.Server.WebSockets.Receiver.RemoveWebSocket($Name)
    $PodeContext.Server.WebSockets.Connections.Remove($Name)
}


<#
.SYNOPSIS
    Reset an existing WebSocket connection.

.DESCRIPTION
    Reset an existing WebSocket connection, either using it's current URL or a new one.

.PARAMETER Name
    The Name of the WebSocket connection (optional if in the scope where $WsEvent is available).

.PARAMETER Url
    An optional new URL to reset the connection to. If not supplied, the connection's original URL will be used.

.EXAMPLE
    Reset-PodeWebSocket -Name 'Example'

.EXAMPLE
    Reset-PodeWebSocket -Name 'Example' -Url 'ws://example.com/some/socket'
#>
function Reset-PodeWebSocket {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Name,

        [Parameter()]
        [string]
        $Url
    )

    if ([string]::IsNullOrWhiteSpace($Name) -and ($null -ne $WsEvent)) {
        $null = Wait-PodeTask -Task $WsEvent.Request.WebSocket.Reconnect($Url)
        return
    }

    if ([string]::IsNullOrWhiteSpace($Name)) {
        # No Name for a WebSocket to reset supplied
        throw ($PodeLocale.noNameForWebSocketResetExceptionMessage)
    }

    if (Test-PodeWebSocket -Name $Name) {
        $null = Wait-PodeTask -Task $PodeContext.Server.WebSockets.Receiver.GetWebSocket($Name).Reconnect($Url)
    }
}


<#
.SYNOPSIS
    Send a message back to a WebSocket connection.

.DESCRIPTION
    Send a message back to a WebSocket connection.

.PARAMETER Name
    The Name of the WebSocket connection (optional if in the scope where $WsEvent is available).

.PARAMETER Message
    The Message to send. Can either be a raw string, hashtable, or psobject. Non-strings will be parsed to JSON, or the WebSocket's ContentType.

.PARAMETER Depth
    An optional Depth to parse any JSON or XML messages. (default: 10)

.PARAMETER Type
    An optional message Type. (default: Text)

.EXAMPLE
    Send-PodeWebSocket -Name 'Example' -Message @{ message = 'Hello, there' }
#>
function Send-PodeWebSocket {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Name,

        [Parameter()]
        $Message,

        [Parameter()]
        [int]
        $Depth = 10,

        [Parameter()]
        [ValidateSet('Text', 'Binary')]
        [string]
        $Type = 'Text'
    )

    # get ws name
    if ([string]::IsNullOrWhiteSpace($Name) -and ($null -ne $WsEvent)) {
        $Name = $WsEvent.Request.WebSocket.Name
    }

    # do we have a name?
    if ([string]::IsNullOrWhiteSpace($Name)) {
        # No Name for a WebSocket to send message to supplied
        throw ($PodeLocale.noNameForWebSocketSendMessageExceptionMessage)
    }

    # do the socket exist?
    if (!(Test-PodeWebSocket -Name $Name)) {
        return
    }

    # get the websocket
    $ws = $PodeContext.Server.WebSockets.Receiver.GetWebSocket($Name)

    # parse message
    $Message = ConvertTo-PodeResponseContent -InputObject $Message -ContentType $ws.ContentType -Depth $Depth

    # send message
    $null = Wait-PodeTask -Task $ws.Send($Message, $Type)
}


<#
.SYNOPSIS
    Set the maximum number of concurrent WebSocket connection threads.

.DESCRIPTION
    Set the maximum number of concurrent WebSocket connection threads.

.PARAMETER Maximum
    The Maximum number of threads available to process WebSocket connection messages received.

.EXAMPLE
    Set-PodeWebSocketConcurrency -Maximum 5
#>
function Set-PodeWebSocketConcurrency {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]
        $Maximum
    )

    # error if <=0
    if ($Maximum -le 0) {
        # Maximum concurrent WebSocket threads must be >=1 but got
        throw ($PodeLocale.maximumConcurrentWebSocketThreadsInvalidExceptionMessage -f $Maximum)

    }

    # add 1, for the waiting script
    $Maximum++

    # ensure max > min
    $_min = 1
    if ($null -ne $PodeContext.RunspacePools.WebSockets) {
        $_min = $PodeContext.RunspacePools.WebSockets.Pool.GetMinRunspaces()
    }

    if ($_min -gt $Maximum) {
        # Maximum concurrent WebSocket threads cannot be less than the minimum of $_min but got $Maximum
        throw ($PodeLocale.maximumConcurrentWebSocketThreadsLessThanMinimumExceptionMessage -f $_min, $Maximum)
    }

    # set the max tasks
    $PodeContext.Threads.WebSockets = $Maximum
    if ($null -ne $PodeContext.RunspacePools.WebSockets) {
        $PodeContext.RunspacePools.WebSockets.Pool.SetMaxRunspaces($Maximum)
    }
}


<#
.SYNOPSIS
    Test whether an WebSocket connection exists.

.DESCRIPTION
    Test whether an WebSocket connection exists for the given Name.

.PARAMETER Name
    The Name of the WebSocket connection.

.EXAMPLE
    Test-PodeWebSocket -Name 'Example'
#>
function Test-PodeWebSocket {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    $found = ($null -ne $PodeContext.Server.WebSockets.Receiver.GetWebSocket($Name))
    if ($found) {
        return $true
    }

    if ($PodeContext.Server.WebSockets.Connections.ContainsKey($Name)) {
        Remove-PodeWebSocket -Name $Name
    }

    return $false
}
