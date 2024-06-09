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
            throw $PodeLocale.customAccessPathOrScriptBlockRequiredExceptionMessage
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

    # check name unique
    if (Test-PodeAccessExists -Name $Name) {
        throw ($PodeLocale.accessMethodAlreadyDefinedExceptionMessage -f $Name) #"Access method already defined: $($Name)"
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
Test if an Access method exists.

.DESCRIPTION
Test if an Access method exists.

.PARAMETER Name
The Name of the Access method.

.EXAMPLE
if (Test-PodeAccessExists -Name 'Example') { }
#>
function Test-PodeAccessExists {
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

    $null = $PodeContext.Server.Authorisations.Methods.Remove($Name)
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