<#
.SYNOPSIS
Waits for a task to finish, and returns a result if there is one.

.DESCRIPTION
Waits for a task to finish, and returns a result if there is one.

.PARAMETER Task
The task to wait on.

.PARAMETER Timeout
An optional Timeout in milliseconds.

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
        $Task,

        [Parameter()]
        [int]
        $Timeout = 0
    )

    # do we need a timeout?
    $timeoutTask = $null
    if ($Timeout -gt 0) {
        $timeoutTask = [System.Threading.Tasks.Task]::Delay($Timeout)
    }

    # set the check task
    if ($null -eq $timeoutTask) {
        $checkTask = $Task
    }
    else {
        $checkTask = [System.Threading.Tasks.Task]::WhenAny($Task, $timeoutTask)
    }

    # is there a cancel token to supply?
    if (($null -eq $PodeContext) -or ($null -eq $PodeContext.Tokens.Cancellation.Token)) {
        $checkTask.Wait()
    }
    else {
        $checkTask.Wait($PodeContext.Tokens.Cancellation.Token)
    }

    # if the main task isnt complete, it timed out
    if (($null -ne $timeoutTask) -and (!$Task.IsCompleted)) {
        throw [System.TimeoutException]::new("Task has timed out after $($Timeout)ms")
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
The object to lock, if no object is supplied then the global lockable is used by default.

.PARAMETER ScriptBlock
The ScriptBlock to invoke.

.PARAMETER Return
If supplied, any values from the ScriptBlock will be returned.

.PARAMETER CheckGlobal
If supplied, will check the global Lockable object and wait until it's freed-up before locking the passed object.

.EXAMPLE
Lock-PodeObject -ScriptBlock { /* logic */ }

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
        [Parameter(ValueFromPipeline=$true)]
        [object]
        $Object,

        [Parameter(Mandatory=$true)]
        [scriptblock]
        $ScriptBlock,

        [switch]
        $Return,

        [switch]
        $CheckGlobal
    )

    if ($null -eq $Object) {
        $Object = $PodeContext.Lockables.Global
    }

    if ($Object -is [valuetype]) {
        throw 'Cannot lock value types'
    }

    $locked = $false

    try {
        if ($CheckGlobal) {
            Lock-PodeObject -Object $PodeContext.Lockables.Global -ScriptBlock {}
        }

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
        "[Stopwatch]: $($watch.Elapsed) [$($Name)]" | Out-PodeHost
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
        if (!(Test-PodeIsEmpty $_paths)) {
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

    # load any functions from the file into pode's runspaces
    Import-PodeFunctionsIntoRunspaceState -FilePath $_path
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

.PARAMETER ArgumentList
An array of arguments to supply to the Endware's ScriptBlock.

.EXAMPLE
Add-PodeEndware -ScriptBlock { /* logic */ }
#>
function Add-PodeEndware
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [object[]]
        $ArgumentList
    )

    # check if the scriptblock has any using vars
    $ScriptBlock, $usingVars = Invoke-PodeUsingScriptConversion -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState

    # check for state/session vars
    $ScriptBlock = Invoke-PodeStateScriptConversion -ScriptBlock $ScriptBlock
    $ScriptBlock = Invoke-PodeSessionScriptConversion -ScriptBlock $ScriptBlock

    # add the scriptblock to array of endware that needs to be run
    $PodeContext.Server.Endware += @{
        Logic = $ScriptBlock
        UsingVariables = $usingVars
        Arguments = $ArgumentList
    }
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
function Use-PodeEndware
{
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
function Import-PodeModule
{
    [CmdletBinding(DefaultParameterSetName='Name')]
    param(
        [Parameter(Mandatory=$true, ParameterSetName='Name')]
        [string]
        $Name,

        [Parameter(Mandatory=$true, ParameterSetName='Path')]
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
                $Path = (Get-Module -Name $Name -ListAvailable | Select-Object -First 1).Path
            }
        }

        'path' {
            $Path = Get-PodeRelativePath -Path $Path -RootPath $rootPath -JoinRoot -Resolve
            $paths = Get-PodeWildcardFiles -Path $Path -RootPath $rootPath -Wildcard '*.ps*1'
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
        throw "Failed to import module: $(Protect-PodeValue -Value $Path -Default $Name)"
    }

    # check if the path exists
    if (!(Test-PodePath $Path -NoStatus)) {
        throw "The module path does not exist: $(Protect-PodeValue -Value $Path -Default $Name)"
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
function Import-PodeSnapin
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Name
    )

    # if non-windows or core, fail
    if ((Test-PodeIsPSCore) -or (Test-PodeIsUnix)) {
        throw 'Snapins are only supported on Windows PowerShell'
    }

    # import the snap-in
    $null = Add-PSSnapin -Name $Name
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

    return (Resolve-PodeValue -Check (Test-PodeIsEmpty $Value) -TrueValue $Default -FalseValue $Value)
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
if (Test-PodeIsEmpty @{}) { /* logic */ }
#>
function Test-PodeIsEmpty
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

    if ($Value -is [string]) {
        return [string]::IsNullOrWhiteSpace($Value)
    }

    if ($Value -is [array]) {
        return ($Value.Length -eq 0)
    }

    if ($Value -is [hashtable]) {
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
Tests if the the current session is running in PowerShell Core.

.DESCRIPTION
Tests if the the current session is running in PowerShell Core.

.EXAMPLE
if (Test-PodeIsPSCore) { /* logic */ }
#>
function Test-PodeIsPSCore
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
if (Test-PodeIsUnix) { /* logic */ }
#>
function Test-PodeIsUnix
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
if (Test-PodeIsWindows) { /* logic */ }
#>
function Test-PodeIsWindows
{
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $v = Get-PodePSVersionTable
    return ($v.Platform -ilike '*win*' -or ($null -eq $v.Platform -and $v.PSEdition -ieq 'desktop'))
}

<#
.SYNOPSIS
Tests if the current OS is MacOS.

.DESCRIPTION
Tests if the current OS is MacOS.

.EXAMPLE
if (Test-PodeIsMacOS) { /* logic */ }
#>
function Test-PodeIsMacOS
{
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return ([bool]$IsMacOS)
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
function Out-PodeHost
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [object]
        $InputObject
    )

    if (!$PodeContext.Server.Quiet) {
        $InputObject | Out-Default
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

.EXAMPLE
'Some output' | Write-PodeHost -ForegroundColor Cyan
#>
function Write-PodeHost
{
    [CmdletBinding()]
    param(
        [Parameter(Position=0, ValueFromPipeline=$true)]
        [object]
        $Object,

        [Parameter()]
        [System.ConsoleColor]
        $ForegroundColor,

        [switch]
        $NoNewLine
    )

    if ($PodeContext.Server.Quiet) {
        return
    }

    if ($ForegroundColor) {
        Write-Host -Object $Object -ForegroundColor $ForegroundColor -NoNewline:$NoNewLine
    }
    else {
        Write-Host -Object $Object -NoNewline:$NoNewLine
    }
}

<#
.SYNOPSIS
Returns whether or not the server is running via IIS.

.DESCRIPTION
Returns whether or not the server is running via IIS.

.EXAMPLE
if (Test-PodeIsIIS) { }
#>
function Test-PodeIsIIS
{
    [CmdletBinding()]
    param()

    return $PodeContext.Server.IsIIS
}

<#
.SYNOPSIS
Returns whether or not the server is running via Heroku.

.DESCRIPTION
Returns whether or not the server is running via Heroku.

.EXAMPLE
if (Test-PodeIsHeroku) { }
#>
function Test-PodeIsHeroku
{
    [CmdletBinding()]
    param()

    return $PodeContext.Server.IsHeroku
}

<#
.SYNOPSIS
Creates a new custom lockable object for use with Lock-PodeObject.

.DESCRIPTION
Creates a new custom lockable object for use with Lock-PodeObject.

.PARAMETER Name
The Name of the lockable object.

.EXAMPLE
New-PodeLockable -Name 'Lock1'
#>
function New-PodeLockable
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Name
    )

    if (Test-PodeLockable -Name $Name) {
        return
    }

    $PodeContext.Lockables.Custom[$Name] = [hashtable]::Synchronized(@{})
}

<#
.SYNOPSIS
Removes a custom lockable object.

.DESCRIPTION
Removes a custom lockable object.

.PARAMETER Name
The Name of the lockable object to remove.

.EXAMPLE
Remove-PodeLockable -Name 'Lock1'
#>
function Remove-PodeLockable
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Name
    )

    if (Test-PodeLockable -Name $Name) {
        $PodeContext.Lockables.Custom.Remove($Name)
    }
}

<#
.SYNOPSIS
Get a custom lockable object for use with Lock-PodeObject.

.DESCRIPTION
Get a custom lockable object for use with Lock-PodeObject.

.PARAMETER Name
The Name of the lockable object.

.EXAMPLE
Get-PodeLockable -Name 'Lock1' | Lock-PodeObject -ScriptBlock {}
#>
function Get-PodeLockable
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Name
    )

    return $PodeContext.Lockables.Custom[$Name]
}

<#
.SYNOPSIS
Test if a custom lockable object exists.

.DESCRIPTION
Test if a custom lockable object exists.

.PARAMETER Name
The Name of the lockable object.

.EXAMPLE
Test-PodeLockable -Name 'Lock1'
#>
function Test-PodeLockable
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Name
    )

    return $PodeContext.Lockables.Custom.ContainsKey($Name)
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
function Out-PodeVariable
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Name,

        [Parameter(ValueFromPipeline=$true)]
        [object]
        $Value
    )

    $PodeContext.Server.Output.Variables[$Name] = $Value
}