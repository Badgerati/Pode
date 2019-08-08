<#
.SYNOPSIS
Waits for a task to finish, and returns a result if there is one.

.DESCRIPTION
Waits for a task to finish, and returns a result if there is one.

.PARAMETER Task
The task to wait on.

.EXAMPLE
$context = Wait-PodeTask -Task $listener.GetContextAsync()
#>
function Wait-PodeTask
{
    [CmdletBinding()]
    [OutputType([object])]
    param (
        [Parameter(Mandatory=$true)]
        [System.Threading.Tasks.Task]
        $Task
    )

    # is there a cancel token to supply?
    if (($null -eq $PodeContext) -or ($null -eq $PodeContext.Tokens.Cancellation.Token)) {
        $Task.Wait()
    }
    else {
        $Task.Wait($PodeContext.Tokens.Cancellation.Token)
    }

    # only return a value if the result has one
    if ($null -ne $Task.Result) {
        return $Task.Result
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
function Close-PodeDisposable
{
    [CmdletBinding()]
    param (
        [Parameter()]
        [System.IDisposable]
        $Disposable,

        [switch]
        $Close,

        [switch]
        $CheckNetwork
    )

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

<#
.SYNOPSIS
Places a temporary lock on a object while a ScriptBlock is invoked.

.DESCRIPTION
Places a temporary lock on a object while a ScriptBlock is invoked.

.PARAMETER Object
The object to lock.

.PARAMETER ScriptBlock
The ScriptBlock to invoke.

.PARAMETER Return
If supplied, any values from the ScriptBlock will be returned.

.EXAMPLE
Lock-PodeObject -Object $SomeArray -ScriptBlock { /* logic */ }

.EXAMPLE
$result = (Lock-PodeObject -Return -Object $SomeArray -ScriptBlock { /* logic */ })
#>
function Lock-PodeObject
{
    [CmdletBinding()]
    [OutputType([object])]
    param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [object]
        $Object,

        [Parameter(Mandatory=$true)]
        [scriptblock]
        $ScriptBlock,

        [switch]
        $Return
    )

    if ($null -eq $Object) {
        return
    }

    if ($Object -is [valuetype]) {
        throw 'Cannot lock value types'
    }

    $locked = $false

    try {
        [System.Threading.Monitor]::Enter($Object.SyncRoot)
        $locked = $true

        if ($null -ne $ScriptBlock) {
            if ($Return) {
                return (Invoke-PodeScriptBlock -ScriptBlock $ScriptBlock -NoNewClosure -Return)
            }
            else {
                Invoke-PodeScriptBlock -ScriptBlock $ScriptBlock -NoNewClosure
            }
        }
    }
    catch {
        $_ | Write-PodeErrorLog
        throw $_.Exception
    }
    finally {
        if ($locked) {
            [System.Threading.Monitor]::Pulse($Object.SyncRoot)
            [System.Threading.Monitor]::Exit($Object.SyncRoot)
        }
    }
}

<#
.SYNOPSIS
Returns the literal path of the server.

.DESCRIPTION
Returns the literal path of the server.

.EXAMPLE
$path = Get-PodeServerPath
#>
function Get-PodeServerPath
{
    [CmdletBinding()]
    [OutputType([string])]
    param()

    return $PodeContext.Server.Root
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
function Start-PodeStopwatch
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Name,

        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [scriptblock]
        $ScriptBlock
    )

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
        Out-Default -InputObject "[Stopwatch]: $($watch.Elapsed) [$($Name)]"
    }
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
function Use-PodeStream
{
    [CmdletBinding()]
    [OutputType([object])]
    param (
        [Parameter(Mandatory=$true)]
        [System.IDisposable]
        $Stream,

        [Parameter(Mandatory=$true)]
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
Loads a script, by dot-sourcing, at the supplied path.

.DESCRIPTION
Loads a script, by dot-sourcing, at the supplied path. If the path is relative, the server's path is prepended.

.PARAMETER Path
The path, literal or relative to the server, to some script.

.EXAMPLE
Use-PodeScript -Path './scripts/tools.ps1'
#>
function Use-PodeScript
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Path
    )

    # if path is '.', replace with server root
    $_path = Get-PodeRelativePath -Path $Path -JoinRoot -Resolve

    # we have a path, if it's a directory/wildcard then loop over all files
    if (![string]::IsNullOrWhiteSpace($_path)) {
        $_paths = Get-PodeWildcardFiles -Path $Path -Wildcard '*.ps1'
        if (!(Test-IsEmpty $_paths)) {
            foreach ($_path in $_paths) {
                Use-PodeScript -Path $_path
            }

            return
        }
    }

    # check if the path exists
    if (!(Test-PodePath $_path -NoStatus)) {
        throw "The script path does not exist: $(Protect-PodeValue -Value $_path -Default $Path)"
    }

    # dot-source the script
    . $_path
}

<#
.SYNOPSIS
Returns the loaded configuration of the server.

.DESCRIPTION
Returns the loaded configuration of the server.

.EXAMPLE
$s = Get-PodeConfig
#>
function Get-PodeConfig
{
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    return $PodeContext.Server.Configuration
}

<#
.SYNOPSIS
Adds a ScriptBlock as Endware to run at the end of each web Request.

.DESCRIPTION
Adds a ScriptBlock as Endware to run at the end of each web Request.

.PARAMETER ScriptBlock
The ScriptBlock to add. It will be supplied the current web event.

.EXAMPLE
Add-PodeEndware -ScriptBlock { /* logic */ }
#>
function Add-PodeEndware
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [scriptblock]
        $ScriptBlock
    )

    # add the scriptblock to array of endware that needs to be run
    $PodeContext.Server.Endware += $ScriptBlock
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

.PARAMETER Now
Import the Module now, into the current runspace.

.EXAMPLE
Import-PodeModule -Name IISManager

.EXAMPLE
Import-PodeModule -Path './modules/utilities.psm1'
#>
function Import-PodeModule
{
    [CmdletBinding(DefaultParameterSetName='Name')]
    param (
        [Parameter(Mandatory=$true, ParameterSetName='Name')]
        [string]
        $Name,

        [Parameter(Mandatory=$true, ParameterSetName='Path')]
        [string]
        $Path,

        [switch]
        $Now
    )

    # get the path of a module, or import modules on mass
    switch ($PSCmdlet.ParameterSetName.ToLowerInvariant()) {
        'name' {
            $modulePath = Join-PodeServerRoot -Folder (Join-PodePaths @('ps_modules', $Name))
            if ([string]::IsNullOrWhiteSpace($modulePath)) {
                $Path = (Get-ChildItem (Join-PodePaths @($modulePath, '*', "$($Name).ps*1")) -Recurse -Force | Select-Object -First 1).FullName
            }
            else {
                $Path = (Get-Module -Name $Name -ListAvailable | Select-Object -First 1).Path
            }
        }

        'path' {
            $Path = Get-PodeRelativePath -Path $Path -JoinRoot -Resolve
            $paths = Get-PodeWildcardFiles -Path $Path -Wildcard '*.ps*1'
            if (!(Test-IsEmpty $paths)) {
                foreach ($_path in $paths) {
                    Import-PodeModule -Path $_path -Now:$Now
                }

                return
            }
        }
    }

    # if it's still empty, error
    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw "Failed to import module: $(Protect-PodeValue -Value $Path -Default $Name)"
    }

    # check if the path exists
    if (!(Test-PodePath $Path -NoStatus)) {
        throw "The module path does not exist: $(Protect-PodeValue -Value $Path -Default $Name)"
    }

    # import the module into the runspace state
    $PodeContext.RunspaceState.ImportPSModule($Path)

    # import the module now, if specified
    if ($Now) {
        Import-Module $Path -Force -DisableNameChecking -Scope Global -ErrorAction Stop | Out-Null
    }
}

<#
.SYNOPSIS
Imports a SnapIn into the current, and all runspaces that Pode uses.

.DESCRIPTION
Imports a SnapIn into the current, and all runspaces that Pode uses.

.PARAMETER Name
The name of a SnapIn to import.

.PARAMETER Now
Import the SnapIn now, into the current runspace.

.EXAMPLE
Import-PodeSnapIn -Name 'WDeploySnapin3.0'
#>
function Import-PodeSnapIn
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Name,

        [switch]
        $Now
    )

    # if non-windows or core, fail
    if ((Test-IsPSCore) -or (Test-IsUnix)) {
        throw 'SnapIns are only supported on Windows PowerShell'
    }

    # import the snap-in into the runspace state
    $exp = $null
    $PodeContext.RunspaceState.ImportPSSnapIn($Name, ([ref]$exp))

    # import the snap-in now, if specified
    if ($Now) {
        Add-PSSnapin -Name $Name | Out-Null
    }
}

<#
.SYNOPSIS
Protects a value, by returning a default value is the main one is null/empty.

.DESCRIPTION
Protects a value, by returning a default value is the main one is null/empty.

.PARAMETER Value
The main value to use.

.PARAMETER Default
A default value to return should the main value be null/empty.

.EXAMPLE
$Name = Protect-PodeValue -Value $Name -Default 'Rick'
#>
function Protect-PodeValue
{
    [CmdletBinding()]
    [OutputType([object])]
    param (
        [Parameter()]
        $Value,

        [Parameter()]
        $Default
    )

    return (Resolve-PodeValue -Check (Test-IsEmpty $Value) -TrueValue $Default -FalseValue $Value)
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
function Resolve-PodeValue
{
    [CmdletBinding()]
    [OutputType([object])]
    param (
        [Parameter(Mandatory=$true)]
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
Invokes a ScriptBlock.

.DESCRIPTION
Invokes a ScriptBlock, supplying optional arguments, splatting, and returning any optional values.

.PARAMETER ScriptBlock
The ScriptBlock to invoke.

.PARAMETER Arguments
Any arguments that should be supplied to the ScriptBlock.

.PARAMETER Scoped
Run the ScriptBlock in a scoped context.

.PARAMETER Return
Return any values that the ScriptBlock may return.

.PARAMETER Splat
Spat the argument onto the ScriptBlock.

.PARAMETER NoNewClosure
Don't create a new closure before invoking the ScriptBlock.

.EXAMPLE
Invoke-PodeScriptBlock -ScriptBlock { Write-Host 'Hello!' }

.EXAMPLE
Invoke-PodeScriptBlock -Arguments 'Morty' -ScriptBlock { /* logic */ }
#>
function Invoke-PodeScriptBlock
{
    [CmdletBinding()]
    [OutputType([object])]
    param (
        [Parameter(Mandatory=$true)]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        $Arguments = $null,

        [switch]
        $Scoped,

        [switch]
        $Return,

        [switch]
        $Splat,

        [switch]
        $NoNewClosure
    )

    if ($PodeContext.Server.IsServerless) {
        $NoNewClosure = $true
    }

    if (!$NoNewClosure) {
        $ScriptBlock = ($ScriptBlock).GetNewClosure()
    }

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

    if ($Return) {
        return $result
    }
}

<#
.SYNOPSIS
Tests if a value is empty - the value can be of any type.

.DESCRIPTION
Tests if a value is empty - the value can be of any type.

.PARAMETER Value
The value to test.

.EXAMPLE
if (Test-IsEmpty @{}) { /* logic */ }
#>
function Test-IsEmpty
{
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter()]
        $Value
    )

    if ($null -eq $Value) {
        return $true
    }

    switch ($Value) {
        { $_ -is [string] } {
            return [string]::IsNullOrWhiteSpace($Value)
        }

        { $_ -is [array] } {
            return ($Value.Length -eq 0)
        }

        { $_ -is [hashtable] } {
            return ($Value.Count -eq 0)
        }

        { $_ -is [scriptblock] } {
            return ($null -eq $Value -or [string]::IsNullOrWhiteSpace($Value.ToString()))
        }

        { $_ -is [valuetype] } {
            return $false
        }
    }

    return ([string]::IsNullOrWhiteSpace($Value) -or ((Get-PodeCount $Value) -eq 0))
}

<#
.SYNOPSIS
Tests if the the current session is running in PowerShell Core.

.DESCRIPTION
Tests if the the current session is running in PowerShell Core.

.EXAMPLE
if (Test-IsPSCore) { /* logic */ }
#>
function Test-IsPSCore
{
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
if (Test-IsUnix) { /* logic */ }
#>
function Test-IsUnix
{
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
if (Test-IsWindows) { /* logic */ }
#>
function Test-IsWindows
{
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $v = Get-PodePSVersionTable
    return ($v.Platform -ilike '*win*' -or ($null -eq $v.Platform -and $v.PSEdition -ieq 'desktop'))
}