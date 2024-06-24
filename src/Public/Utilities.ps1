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

        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
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
function Get-PodeConfig {
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
function Add-PodeEndware {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [object[]]
        $ArgumentList
    )

    # check for scoped vars
    $ScriptBlock, $usingVars = Convert-PodeScopedVariables -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState

    # add the scriptblock to array of endware that needs to be run
    $PodeContext.Server.Endware += @{
        Logic          = $ScriptBlock
        UsingVariables = $usingVars
        Arguments      = $ArgumentList
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
function Import-PodeSnapin {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
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
function Protect-PodeValue {
    [CmdletBinding()]
    [OutputType([object])]
    param(
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
Invoke-PodeScriptBlock -ScriptBlock { Write-Host 'Hello!' }

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
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
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

.PARAMETER Explode
Show the object content

.PARAMETER ShowType
Show the Object Type

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
        $ShowType
    )

    if ($PodeContext.Server.Quiet) {
        return
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
function Test-PodeIsIIS {
    [CmdletBinding()]
    param()

    return $PodeContext.Server.IsIIS
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

        [Parameter(ValueFromPipeline = $true)]
        [object]
        $Value
    )

    $PodeContext.Server.Output.Variables[$Name] = $Value
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
        throw 'Cannot supply an interval when -Every is set to None'
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
                throw 'Cannot supply interval value for every quarter'
            }
        }

        'YEAR' {
            $cron.Minute = '0'
            $cron.Hour = '0'
            $cron.Date = '1'
            $cron.Month = '1'

            if ($Interval -gt 0) {
                throw 'Cannot supply interval value for every year'
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
Gets the version of the Pode module.

.DESCRIPTION
The Get-PodeVersion function checks the version of the Pode module specified in the module manifest. If the module version is not a placeholder value ('$version$'), it returns the actual version prefixed with 'v.'. If the module version is the placeholder value, indicating the development branch, it returns '[develop branch]'.

.PARAMETER None
This function does not accept any parameters.

.OUTPUTS
System.String
Returns a string indicating the version of the Pode module or '[dev]' if on a development version.

.EXAMPLE
PS> $moduleManifest = @{ ModuleVersion = '1.2.3' }
PS> Get-PodeVersion

Returns 'v1.2.3'.

.EXAMPLE
PS> $moduleManifest = @{ ModuleVersion = '$version$' }
PS> Get-PodeVersion

Returns '[dev]'.

.NOTES
This function assumes that $moduleManifest is a hashtable representing the loaded module manifest, with a key of ModuleVersion.

#>
function Get-PodeVersion {
    $moduleManifest = Get-PodeModuleManifest
    if ($moduleManifest.ModuleVersion -ne '$version$') {
        return "v$($moduleManifest.ModuleVersion)"
    }
    else {
        return '[dev]'
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

.LINK
https://badgerati.github.io/Pode/Functions/Utility/ConvertFrom-PodeXml

#>
function ConvertFrom-PodeXml {
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline)]
        [System.Xml.XmlNode]$node, #we are working through the nodes
        [string]$Prefix = '', #do we indicate an attribute with a prefix?
        $ShowDocElement = $false, #Do we show the document element?,
        [switch]
        $KeepAttributes
    )
    #if option set, we skip the Document element
    if ($node.DocumentElement -and !($ShowDocElement))
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

<#
.SYNOPSIS
Sets the Pode server configuration.

.DESCRIPTION
This function allows you to set various configurations for the Pode server as an alternative to using the server.psd1 file or directly modifying the $PodeContext hashtable.

.PARAMETER SslProtocols
Indicates the SSL Protocols that should be used.
[link](https://badgerati.github.io/Pode/Tutorials/Certificates)

.PARAMETER RequestTimeout
Defines the request timeout in seconds.
[link](https://badgerati.github.io/Pode/Tutorials/RequestLimits/#timeout)

.PARAMETER ReceiveTimeout
Defines the receive timeout in seconds.
########################
DOCUMENTATION IS MISSING
########################

.PARAMETER RequestBodySize
Defines the maximum body size for a request in bytes.
[link](https://badgerati.github.io/Pode/Tutorials/RequestLimits/#body-size)

.PARAMETER AutoImport
Defines the AutoImport scoping rules for Modules, SnapIns and Functions.
[link](https://badgerati.github.io/Pode/Tutorials/Scoping)

.PARAMETER EnableAutoImportModules
Disables the AutoImport setting for Modules.
[link](https://badgerati.github.io/Pode/Tutorials/Scoping/#modules)

.PARAMETER AutoImportModulesExportOnly
Sets the AutoImport Modules ExportOnly option. Defaults to $false.
[link](https://badgerati.github.io/Pode/Tutorials/Scoping/#modules)

.PARAMETER EnableAutoImportSnapins
Disables the AutoImport setting for Snapins.
[link](https://badgerati.github.io/Pode/Tutorials/Scoping/#snapins)

.PARAMETER AutoImportSnapinsExportOnly
Sets the AutoImport Snapins ExportOnly option. Defaults to $false.
[link](https://badgerati.github.io/Pode/Tutorials/Scoping/#snapins)

.PARAMETER EnableAutoImportFunctions
Disables the AutoImport setting for Functions.
[link](https://badgerati.github.io/Pode/Tutorials/Scoping/#functions)

.PARAMETER AutoImportFunctionsExportOnly
Sets the AutoImport Functions ExportOnly option. Defaults to $false.
[link](https://badgerati.github.io/Pode/Tutorials/Scoping/#functions)

.PARAMETER EnableSecretManagement
Disables the AutoImport setting for SecretVault.
[link](https://badgerati.github.io/Pode/Tutorials/Scoping/#secret-vaults)

.PARAMETER SecretManagementExportOnly
Sets the AutoImport SecretVault ExportOnly option. Defaults to $false.
[link](https://badgerati.github.io/Pode/Tutorials/Scoping/#secret-vaults)

.PARAMETER Root
Overrides root path of the server.
[link](https://badgerati.github.io/Pode/Tutorials/Misc/ServerRoot)

.PARAMETER RestartPeriod
Sets the interval in minutes for automatically restarting the server.
[link](https://badgerati.github.io/Pode/Tutorials/Restarting/Types/AutoRestarting/#periodic)

.PARAMETER RestartCrons
Sets the cron schedules for automatically restarting the server.
[link](https://badgerati.github.io/Pode/Tutorials/Restarting/Types/AutoRestarting/#cron-expressions)

.PARAMETER RestartTimes
Sets the times for automatically restarting the server in the format "HH:mm".
[link](https://badgerati.github.io/Pode/Tutorials/Restarting/Types/AutoRestarting/#times)

.PARAMETER FileMonitorEnable
Enables or disables file monitoring for restarting the server.
[link](https://badgerati.github.io/Pode/Tutorials/Restarting/Types/FileMonitoring)

.PARAMETER FileMonitorInclude
Specifies the file patterns to include for monitoring.
[link](https://badgerati.github.io/Pode/Tutorials/Restarting/Types/FileMonitoring/#includeexclude)

.PARAMETER FileMonitorExclude
Specifies the file patterns to exclude from monitoring.
[link](https://badgerati.github.io/Pode/Tutorials/Restarting/Types/FileMonitoring/#includeexclude)

.PARAMETER FileMonitorShowFiles
Enables or disables showing monitored files.
[link](https://badgerati.github.io/Pode/Tutorials/Restarting/Types/FileMonitoring/#show-files)

.PARAMETER DefaultFoldersPublic
Sets the custom path for the Public folder.
[link](https://badgerati.github.io/Pode/Tutorials/Routes/Utilities/StaticContent/#changing-the-default-folders)

.PARAMETER DefaultFoldersViews
Sets the custom path for the Views folder.
[link](https://badgerati.github.io/Pode/Tutorials/Routes/Utilities/StaticContent/#changing-the-default-folders)

.PARAMETER DefaultFoldersErrors
Sets the custom path for the Errors folder.
[link](https://badgerati.github.io/Pode/Tutorials/Routes/Utilities/StaticContent/#changing-the-default-folders)

.PARAMETER OpenApiDefaultDefinitionTag
Defines the primary tag name for OpenAPI (default is 'default').
[link](https://badgerati.github.io/Pode/Tutorials/OpenAPI/Overview/#how-to-use-it)

.PARAMETER UsePodeYamlInternal
Force Pode to use the internal Yaml converter instead of PSYaml or powershell-yaml.
########################
DOCUMENTATION IS MISSING
########################

.PARAMETER StaticValidateLast
Changes the way routes are processed.
[link](https://badgerati.github.io/Pode/Tutorials/Routes/Utilities/StaticContent)

.PARAMETER TransferEncodingDefault
Sets the default transfer encoding.
[link](https://badgerati.github.io/Pode/Tutorials/Compression/Requests/#configuration)

.PARAMETER TransferEncodingRoutes
Sets the transfer encoding for specific routes.
[link](https://badgerati.github.io/Pode/Tutorials/Compression/Requests/#route-patterns)

.PARAMETER Compression
Sets any compression to use on the Response.
[link](https://badgerati.github.io/Pode/Tutorials/Compression/Responses)

.PARAMETER ContentTypeDefault
Sets the default transfer encoding.
[link](https://badgerati.github.io/Pode/Tutorials/Routes/Utilities/ContentTypes/#configuration)

.PARAMETER ContentTypeRoutes
Sets the transfer encoding for specific routes.
[link](https://badgerati.github.io/Pode/Tutorials/Routes/Utilities/ContentTypes/#route-patterns)

.PARAMETER ErrorPagesDefault
Sets the default transfer encoding.
[link](https://badgerati.github.io/Pode/Tutorials/Routes/Utilities/ErrorPages/#configuration)

.PARAMETER ErrorPagesRoutes
Sets the transfer encoding for specific routes.
[link](https://badgerati.github.io/Pode/Tutorials/Routes/Utilities/ErrorPages/#route-patterns)

.PARAMETER ErrorPagesShowExceptions
Enables or disables the viewing of exceptions on the error page.
[link](https://badgerati.github.io/Pode/Tutorials/Routes/Utilities/ErrorPages/#exceptions)

.PARAMETER ErrorPagesStrictContentTyping
Enables or disables generating an error page that matches the route/request's content type.
[link](https://badgerati.github.io/Pode/Tutorials/Routes/Utilities/ErrorPages/#strict-typing)

.PARAMETER StaticDefaults
Sets the default static files.
[link](https://badgerati.github.io/Pode/Tutorials/Routes/Utilities/StaticContent)

.PARAMETER StaticCacheEnable
Enables or disables caching for static content.
[link](https://badgerati.github.io/Pode/Tutorials/Routes/Utilities/StaticContent)

.PARAMETER StaticCacheExclude
Specifies the file patterns to exclude from caching.
[link](https://badgerati.github.io/Pode/Tutorials/Routes/Utilities/StaticContent)

.PARAMETER StaticCacheInclude
Specifies the file patterns to include for caching.
[link](https://badgerati.github.io/Pode/Tutorials/Routes/Utilities/StaticContent)

.PARAMETER StaticCacheMaxAge
Specifies the caching max cache TTL.
[link](https://badgerati.github.io/Pode/Tutorials/Routes/Utilities/StaticContent)

.PARAMETER LoggingMaskingPatterns
Defines the patterns for masking sensitive data in logs.
[link](https://badgerati.github.io/Pode/Tutorials/Logging/Overview/#masking-values)

.PARAMETER LoggingMask
Defines the mask to use for sensitive data in logs.
[link](https://badgerati.github.io/Pode/Tutorials/Logging/Overview/#masking-values)

.PARAMETER LoggingQueueLimit
Defines the maximum number of logs allowed in the queue before throwing an event.
[link](https://badgerati.github.io/Pode/Tutorials/Logging/Overview)

.PARAMETER DebugBreakpointsEnable
Enables or disables the breakpoints inside the code.
[link](https://badgerati.github.io/Pode/Getting-Started/Debug/#debugger)

.EXAMPLE
Set-PodeConfiguration -SslProtocols @('TLS12', 'TLS13')

.EXAMPLE
Set-PodeConfiguration -RequestTimeout 300 -RequestBodySize 1048576

.EXAMPLE
Set-PodeConfiguration -DisableAutoImportModules -AutoImportModulesExportOnly

.EXAMPLE
Set-PodeConfiguration -RestartPeriod 360

.EXAMPLE
Set-PodeConfiguration -RestartCrons @('0 12 * * TUE,FRI')

.EXAMPLE
Set-PodeConfiguration -RestartTimes @('09:45', '21:15')

.EXAMPLE
Set-PodeConfiguration -FileMonitorEnable -FileMonitorInclude @('*.txt', '*.ps1') -FileMonitorExclude @('public/*') -FileMonitorShowFiles

.EXAMPLE
Set-PodeConfiguration -TransferEncodingDefault 'gzip' -TransferEncodingRoutes @{'/api/*' = 'gzip'; '/status/*' = 'deflate'}

.EXAMPLE
Set-PodeConfiguration -ErrorPagesShowExceptions -ErrorPagesStrictContentTyping

.EXAMPLE
Set-PodeConfiguration -StaticDefaults @('home.html') -StaticCacheEnable -StaticCacheExclude @('*.exe') -StaticCacheInclude @('/images/*', '/assets/*.js')

.EXAMPLE
Set-PodeConfiguration -DefaultFoldersPublic 'c:\custom\public' -DefaultFoldersViews 'd:\shared\views' -DefaultFoldersErrors 'e:\logs\errors'

.EXAMPLE
Set-PodeConfiguration -LoggingMaskingPatterns @('(?<keep_before>Password=)\w+') -LoggingMask '--MASKED--' -LoggingQueueLimit 500
#>
function Set-PodeConfiguration {
    [CmdletBinding(DefaultParameterSetName = 'Server')]
    param (

        [Parameter(ParameterSetName = 'DefaultFolder')]
        [string]$DefaultFoldersPublic,

        [Parameter(ParameterSetName = 'DefaultFolder')]
        [string]$DefaultFoldersViews,

        [Parameter(ParameterSetName = 'DefaultFolder')]
        [string]$DefaultFoldersErrors,

        [Parameter(ParameterSetName = 'OpenAPI')]
        [string]$OpenApiDefaultDefinitionTag,

        [Parameter(ParameterSetName = 'OpenAPI')]
        [bool]$UsePodeYamlInternal,

        [Parameter(ParameterSetName = 'Compression')]
        [bool]$Compression,

        [Parameter(ParameterSetName = 'Server')]
        [string]$Root,

        [Parameter(ParameterSetName = 'Server')]
        [ValidateSet('SSL2', 'SSL3', 'TLS', 'TLS11', 'TLS12', 'TLS13')]
        [string[]]$SslProtocols,

        [Parameter(ParameterSetName = 'Server')]
        [int]$ReceiveTimeout,

        [Parameter(ParameterSetName = 'Server')]
        [int]$RequestTimeout,

        [Parameter(ParameterSetName = 'Server')]
        [int]$RequestBodySize,

        [Parameter(ParameterSetName = 'AutoImport')]
        [bool]$EnableAutoImportModules,

        [Parameter(ParameterSetName = 'AutoImport')]
        [bool]$AutoImportModulesExportOnly,

        [Parameter(ParameterSetName = 'AutoImport')]
        [bool]$EnableAutoImportSnapins,

        [Parameter(ParameterSetName = 'AutoImport')]
        [bool]$AutoImportSnapinsExportOnly,

        [Parameter(ParameterSetName = 'AutoImport')]
        [bool]$EnableAutoImportFunctions,

        [Parameter(ParameterSetName = 'AutoImport')]
        [bool]$AutoImportFunctionsExportOnly,

        [Parameter(ParameterSetName = 'AutoImport')]
        [bool]$EnableSecretManagement ,

        [Parameter(ParameterSetName = 'AutoImport')]
        [bool]$SecretManagementExportOnly,

        [Parameter(ParameterSetName = 'Restart')]
        [int]$RestartPeriod,

        [Parameter(ParameterSetName = 'Restart')]
        [ValidatePattern('^[0-5]?\d\s[0-5]?\d\s([0-1]?\d|2[0-3])\s([1-9]|1[0-9]|2[0-8]|3[01]|\*)\s([1-9]|1[0-2]|\*|JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)\s([0-7]|\*|SUN|MON|TUE|WED|THU|FRI|SAT)(\s[0-7])?$')]
        [string[]]$RestartCrons,

        [Parameter(ParameterSetName = 'Restart')]
        [ValidatePattern('^(?:[01]\d|2[0-3]):[0-5]\d$')]
        [string[]]$RestartTimes,

        [Parameter(ParameterSetName = 'FileMonitor')]
        [bool]$FileMonitorEnable,

        [Parameter(ParameterSetName = 'FileMonitor')]
        [string[]]$FileMonitorInclude,

        [Parameter(ParameterSetName = 'FileMonitor')]
        [string[]]$FileMonitorExclude,

        [Parameter(ParameterSetName = 'FileMonitor')]
        [bool]$FileMonitorShowFiles,

        [Parameter(ParameterSetName = 'ContentType')]
        [string]$ContentTypeDefault,

        [Parameter(ParameterSetName = 'ContentType')]
        [hashtable]$ContentTypeRoutes,

        [Parameter(ParameterSetName = 'Error')]
        [string]$ErrorPagesDefault,

        [Parameter(ParameterSetName = 'Error')]
        [hashtable]$ErrorPagesRoutes,

        [Parameter(ParameterSetName = 'Error')]
        [bool]$ErrorPagesShowExceptions,

        [Parameter(ParameterSetName = 'Error')]
        [bool]$ErrorPagesStrictContentTyping,

        [Parameter(ParameterSetName = 'Static')]
        [bool]$StaticValidateLast,

        [Parameter(ParameterSetName = 'Static')]
        [string[]]$StaticDefaults,

        [Parameter(ParameterSetName = 'Static')]
        [bool]$StaticCacheEnable,

        [Parameter(ParameterSetName = 'Static')]
        [string[]]$StaticCacheExclude,

        [Parameter(ParameterSetName = 'Static')]
        [string[]]$StaticCacheInclude,

        [Parameter(ParameterSetName = 'Static')]
        [string[]]$StaticCacheMaxAge,

        [Parameter(ParameterSetName = 'TransferEncoding')]
        [string]$TransferEncodingDefault,

        [Parameter(ParameterSetName = 'TransferEncoding')]
        [hashtable]$TransferEncodingRoutes,

        [Parameter(ParameterSetName = 'Logging')]
        [string[]]$LoggingMaskingPatterns,

        [Parameter(ParameterSetName = 'Logging')]
        [string]$LoggingMask,

        [Parameter(ParameterSetName = 'Logging')]
        [int]$LoggingQueueLimit,

        [Parameter(ParameterSetName = 'Debug')]
        [bool]$DebugBreakpointsEnable


    )
    switch ($PSCmdlet.ParameterSetName.ToLowerInvariant()) {
        'debug' {
            if ($DebugBreakpointsEnable) { $PodeContext.Server.Debug.Breakpoints.Enabled = $DebugBreakpointsEnable }
        }

        'static' {
            if ($StaticValidateLast ) { $PodeContext.Server.Web.Static.ValidateLast = $StaticValidateLast }
            if ($StaticDefaults) { $PodeContext.Server.Web.Static.Defaults = $StaticDefaults }
            if ($StaticCacheEnable) { $PodeContext.Server.Web.Static.Cache.Enabled = $StaticCacheEnable }
            if ($StaticCacheExclude) { $PodeContext.Server.Web.Static.Cache.Exclude = Convert-PodePathPatternsToRegex -Paths $StaticCacheExclude -NotSlashes }
            if ($StaticCacheInclude) { $PodeContext.Server.Web.Static.Cache.Include = Convert-PodePathPatternsToRegex -Paths $StaticCacheInclude -NotSlashes }
            if ($StaticCacheMaxAge) { $PodeContext.Server.Web.Static.Cache.MaxAge = $StaticCacheMaxAge }
        }

        'error' {
            if ($ErrorPagesDefault) { $PodeContext.Server.Web.ErrorPages.Default = $ErrorPagesDefault }
            if ($ErrorPagesRoutes) { $PodeContext.Server.Web.ErrorPages.Routes = $ErrorPagesRoutes }
            if ($ErrorPagesShowExceptions ) { $PodeContext.Server.Web.ErrorPages.ShowExceptions = $ErrorPagesShowExceptions }
            if ($ErrorPagesStrictContentTyping) { $PodeContext.Server.Web.ErrorPages.StrictContentTyping = $ErrorPagesStrictContentTyping }
        }

        'contenttype' {
            if ($ContentTypeDefault) { $PodeContext.Server.Web.ContentType.Default = $ContentTypeDefault }
            if ($ContentTypeRoutes) { $PodeContext.Server.Web.ContentType.Routes = $ContentTypeRoutes }
        }

        'transferencoding' {
            if ($TransferEncodingDefault) { $PodeContext.Server.Web.TransferEncoding.Default = $TransferEncodingDefault }
            if ($TransferEncodingRoutes) { $PodeContext.Server.Web.TransferEncoding.Routes = $TransferEncodingRoutes }
        }

        'compression' {
            if ($Compression) { $PodeContext.Server.Web.Compression = $Compression }
        }

        'openapi' {
            if ($OpenApiDefaultDefinitionTag) { $PodeContext.Server.Web.OpenApi.DefaultDefinitionTag = $OpenApiDefaultDefinitionTag }
            if ($UsePodeYamlInternal) { $PodeContext.Server.Web.OpenApi.UsePodeYamlInternal = $UsePodeYamlInternal }
        }

        'autoimport' {
            if ($EnableAutoImportModules) {
                $PodeContext.Server.AutoImport.Modules.Enabled = $EnableAutoImportModules
            }
            if ($AutoImportModulesExportOnly) {
                $PodeContext.Server.AutoImport.Modules.ExportOnly = $AutoImportModulesExportOnly
            }

            if ($EnableAutoImportSnapins ) {
                $PodeContext.Server.AutoImport.Snapins.Enabled = $EnableAutoImportSnapins
            }
            if ($AutoImportSnapinsExportOnly ) {
                $PodeContext.Server.AutoImport.Snapins.ExportOnly = $AutoImportSnapinsExportOnly
            }

            if ($EnableAutoImportFunctions) {
                $PodeContext.Server.AutoImport.Functions.Enabled = $EnableAutoImportFunctions
            }
            if ($AutoImportFunctionsExportOnly ) {
                $PodeContext.Server.AutoImport.Functions.ExportOnly = $AutoImportFunctionsExportOnly
            }

            if ($EnableSecretManagement) {
                $PodeContext.Server.AutoImport.SecretVaults.SecretManagement.Enabled = $EnableSecretManagement
            }

            if ($SecretManagementExportOnly ) {
                $PodeContext.Server.AutoImport.SecretVaults.SecretManagement.ExportOnly = $SecretManagementExportOnly
            }
        }

        'restart' {
            if ($RestartPeriod) { $PodeContext.Server.Restart.Period = $RestartPeriod }
            if ($RestartCrons) { $PodeContext.Server.Restart.Crons = $RestartCrons }
            if ($RestartTimes) { $PodeContext.Server.Restart.Times = $RestartTimes }
        }

        'filemonitor' {
            if ($FileMonitorEnable) { $PodeContext.Server.FileMonitor.Enabled = $FileMonitorEnable }
            if ($FileMonitorShowFiles ) { $PodeContext.Server.FileMonitor.ShowFiles = $FileMonitorShowFiles }
            if ($FileMonitorInclude) { $PodeContext.Server.FileMonitor.Include = Convert-PodePathPatternsToRegex -Paths $FileMonitorInclude -NotSlashes }
            if ($FileMonitorExclude) { $PodeContext.Server.FileMonitor.Exclude = Convert-PodePathPatternsToRegex -Paths $FileMonitorExclude -NotSlashes }

        }

        'server' {
            if ($RequestTimeout) { $PodeContext.Server.Request.Timeout = $RequestTimeout }
            if ($RequestBodySize) { $PodeContext.Server.Request.BodySize = $RequestBodySize }
            if ($SslProtocols) { $PodeContext.Server.Sockets.Ssl.Protocols = $SslProtocols }
            if ($ReceiveTimeout) { $PodeContext.Server.Sockets.ReceiveTimeout = $ReceiveTimeout }
            if ($Root) { $PodeContext.Server.Root = $Root }
        }

        'defaultfolder' {
            if ($DefaultFoldersPublic) { Set-PodeDefaultFolder -Type 'Public' -Path $DefaultFoldersPublic }
            if ($DefaultFoldersViews) { Set-PodeDefaultFolder -Type 'Views' -Path $DefaultFoldersViews }
            if ($DefaultFoldersErrors) { Set-PodeDefaultFolder -Type 'Errors' -Path$DefaultFoldersErrors }
        }

        'logging' {
            if (-not $PodeContext.Server.Logging.Masking) { $PodeContext.Server.Logging.Masking = @{} }
            if ($LoggingMaskingPatterns) { $PodeContext.Server.Logging.Masking.Patterns = $LoggingMaskingPatterns }
            if ($LoggingMask) { $PodeContext.Server.Logging.Masking.Mask = $LoggingMask }
            if ($LoggingQueueLimit) { $PodeContext.Server.Logging.QueueLimit = $LoggingQueueLimit }
        }
    }
}

<#
.SYNOPSIS
Retrieves the current Pode server configuration.

.DESCRIPTION
This function fetches the current configurations for the Pode server by reading from the `$PodeContext` hashtable. It can return the entire configuration or a specific section.

.PARAMETER Section
Specifies the section of the configuration to retrieve. Possible values include: 'Sockets', 'Request', 'AutoImport', 'Root', 'Restart', 'FileMonitor', 'DefaultFolders', 'OpenApi', 'Static', 'TransferEncoding', 'Compression', 'ContentType', 'ErrorPages', 'Logging', 'Debug', 'Web', 'Server', 'Context'. The default value is 'Context'.

.PARAMETER Save
If specified, saves the current configuration to a file. This switch requires the -FileName parameter.

.PARAMETER FileName
Specifies the name of the file to save the configuration. This parameter is required if -Save is specified.

.PARAMETER Force
If specified, overwrites the existing configuration file if it exists. This parameter is used with the -Save switch.

.EXAMPLE
Get-PodeConfiguration
Retrieves the entire current Pode server configuration.

.EXAMPLE
Get-PodeConfiguration -Section 'Sockets'
Retrieves the 'Sockets' section of the current Pode server configuration.

.EXAMPLE
Get-PodeConfiguration -Section 'RequestTimeout'
Retrieves the 'RequestTimeout' section of the current Pode server configuration.

.EXAMPLE
Get-PodeConfiguration -Save -FileName 'C:\Config\podeConfig.psd1' -Force
Saves the current Pode server configuration to 'C:\Config\podeConfig.psd1', overwriting it if it already exists.
#>
function Get-PodeConfiguration {
    [CmdletBinding(DefaultParameterSetName = 'Section')]
    param (
        [Parameter(Mandatory = $false, ParameterSetName = 'Section')]
        [ValidateSet('Sockets', 'Request', 'AutoImport', 'Root', 'Restart', 'FileMonitor', 'DefaultFolders', 'OpenApi', 'Static', 'TransferEncoding', 'Compression', 'ContentType', 'ErrorPages', 'Logging', 'Debug', 'Web', 'Server', 'Context')]
        [string]$Section = 'Context',

        [Parameter(Mandatory = $true, ParameterSetName = 'Save')]
        [switch]$Save,

        [Parameter(ParameterSetName = 'Save')]
        [string]$FileName,

        [Parameter(ParameterSetName = 'Save')]
        [switch]$Force
    )

    switch ($PSCmdlet.ParameterSetName.ToLowerInvariant()) {
        'save' {
            $export = @{}
            $export += Get-PodeConfiguration -Section Context

            if ($FileName) {
                $psd1FileName = $FileName
            }
            else {
                $psd1FileName = Join-Path -Path $PodeContext.Server.Root -ChildPath 'server.psd1'
            }

            if ((Test-Path -Path $psd1FileName) -and (! $Force.IsPresent)) {
                throw "$psd1FileName already present. Use -Force to overwrite."
            }

            $export | ConvertTo-PodePsd1 | Out-File $psd1FileName
            return
        }
        'section' {
            $export = @{}
            switch ($Section) {
                'OpenApi' {
                    if ($PodeContext.Server.Web.OpenApi) {
                        $export.OpenApi = @{}
                        if ($PodeContext.Server.Web.OpenApi.DefaultDefinitionTag) {
                            $export.OpenApi.DefaultDefinitionTag = $PodeContext.Server.Web.OpenApi.DefaultDefinitionTag
                        }
                        if ($PodeContext.Server.Web.OpenApi.UsePodeYamlInternal) {
                            $export.OpenApi.UsePodeYamlInternal = $PodeContext.Server.Web.OpenApi.UsePodeYamlInternal
                        }
                    }
                    break
                }
                'Static' {
                    if ($PodeContext.Server.Web.Static) {
                        $export.Static = @{}
                        if ($PodeContext.Server.Web.Static.ValidateLast) {
                            $export.Static.ValidateLast = $PodeContext.Server.Web.Static.ValidateLast
                        }
                        if ($PodeContext.Server.Web.Static.Defaults) {
                            $export.Static.Defaults = $PodeContext.Server.Web.Static.Defaults
                        }
                        if ($PodeContext.Server.Web.Static.Cache) {
                            $export.Static.Cache = @{}
                            if ($PodeContext.Server.Web.Static.Cache.Enabled) {
                                $export.Static.Cache.Enable = $PodeContext.Server.Web.Static.Cache.Enabled
                            }
                            if ($PodeContext.Server.Web.Static.Cache.Exclude) {
                                $export.Static.Cache.Exclude = $PodeContext.Server.Web.Static.Cache.Exclude.Replace('^(.*?\.', '*.').Replace(')$', '')
                            }
                            if ($PodeContext.Server.Web.Static.Cache.Include) {
                                $export.Static.Cache.Include = $PodeContext.Server.Web.Static.Cache.Include.Replace('^(.*?\.', '*.').Replace(')$', '')
                            }
                            if ($PodeContext.Server.Web.Static.Cache.MaxAge) {
                                $export.Static.Cache.MaxAge = $PodeContext.Server.Web.Static.Cache.MaxAge
                            }
                        }
                    }
                    break
                }
                'TransferEncoding' {
                    if ($PodeContext.Server.Web.TransferEncoding) {
                        $export.TransferEncoding = @{}
                        if ($PodeContext.Server.Web.TransferEncoding.Default) {
                            $export.TransferEncoding.Default = $PodeContext.Server.Web.TransferEncoding.Default
                        }
                        if ($PodeContext.Server.Web.TransferEncoding.Routes) {
                            $export.TransferEncoding.Routes = Convert-PodePathRegexToPattern -Route $PodeContext.Server.Web.TransferEncoding.Routes
                        }
                    }
                    break
                }
                'Compression' {
                    if ($PodeContext.Server.Web.Compression) {
                        $export.Compression = $PodeContext.Server.Web.Compression
                    }
                    break
                }
                'ContentType' {
                    if ($PodeContext.Server.Web.ContentType) {
                        $export.ContentType = @{}
                        if ($PodeContext.Server.Web.ContentType.Default) {
                            $export.ContentType.Default = $PodeContext.Server.Web.ContentType.Default
                        }
                        if ($PodeContext.Server.Web.ContentType.Routes) {
                            $export.ContentType.Routes = Convert-PodePathRegexToPattern -Route $PodeContext.Server.Web.ContentType.Routes
                        }
                    }
                }
                'ErrorPages' {
                    if ($PodeContext.Server.Web.ErrorPages) {
                        $export.ErrorPages = @{}
                        if ($PodeContext.Server.Web.ErrorPages.Default) {
                            $export.ErrorPages.Default = $PodeContext.Server.Web.ErrorPages.Default
                        }
                        if ($PodeContext.Server.Web.ErrorPages.Routes) {
                            $export.ErrorPages.Routes = Convert-PodePathRegexToPattern -Route $PodeContext.Server.Web.ErrorPages.Routes
                        }
                        if ($PodeContext.Server.Web.ErrorPages.ShowExceptions) {
                            $export.ErrorPages.ShowExceptions = $PodeContext.Server.Web.ErrorPages.ShowExceptions
                        }
                        if ($PodeContext.Server.Web.ErrorPages.StrictContentTyping) {
                            $export.ErrorPages.StrictContentTyping = $PodeContext.Server.Web.ErrorPages.StrictContentTyping
                        }
                    }
                }

                # Server part
                'Sockets' {
                    if ($PodeContext.Server.Sockets.Ssl) {
                        $export.Ssl = @{}
                        if ($PodeContext.Server.Sockets.Ssl.Protocols) {
                            $export.Ssl.Protocols = $PodeContext.Server.Sockets.Ssl.Protocols
                        }
                        if ($PodeContext.Server.Sockets.ReceiveTimeout) {
                            $export.ReceiveTimeout = $PodeContext.Server.Sockets.ReceiveTimeout
                        }
                    }
                    break
                }
                'Request' {
                    if ($PodeContext.Server.Request) {
                        $export.Request = @{}
                        if ($PodeContext.Server.Request.Timeout) {
                            $export.Request.Timeout = $PodeContext.Server.Request.Timeout
                        }
                        if ($PodeContext.Server.Request.BodySize) {
                            $export.Request.BodySize = $PodeContext.Server.Request.BodySize
                        }
                    }
                    break
                }

                'AutoImport' {
                    if ($PodeContext.Server.AutoImport) {
                        $export.AutoImport = @{}
                        if ($PodeContext.Server.AutoImport.Modules) {
                            $export.AutoImport.Modules = @{}
                            if ( $PodeContext.Server.AutoImport.Modules.Enabled) {
                                $export.AutoImport.Modules.Enable = $PodeContext.Server.AutoImport.Modules.Enabled
                            }
                            if ( $PodeContext.Server.AutoImport.Modules.ExportOnly) {
                                $export.AutoImport.Modules.ExportOnly = $PodeContext.Server.AutoImport.Modules.ExportOnly
                            }
                        }

                        if ($PodeContext.Server.AutoImport.Snapins) {
                            $export.AutoImport.Snapins = @{}
                            if ( $PodeContext.Server.AutoImport.Snapins.Enabled) {
                                $export.AutoImport.Snapins.Enable = $PodeContext.Server.AutoImport.Snapins.Enabled
                            }
                            if ( $PodeContext.Server.AutoImport.Snapins.ExportOnly) {
                                $export.AutoImport.Snapins.ExportOnly = $PodeContext.Server.AutoImport.Snapins.ExportOnly
                            }
                        }

                        if ($PodeContext.Server.AutoImport.Functions) {
                            $export.AutoImport.Functions = @{}
                            if ( $PodeContext.Server.AutoImport.Functions.Enabled) {
                                $export.AutoImport.Functions.Enable = $PodeContext.Server.AutoImport.Functions.Enabled
                            }
                            if ( $PodeContext.Server.AutoImport.Functions.ExportOnly) {
                                $export.AutoImport.Functions.ExportOnly = $PodeContext.Server.AutoImport.Functions.ExportOnly
                            }
                        }

                        if ($PodeContext.Server.AutoImport.SecretVaults) {
                            $export.AutoImport.SecretVaults = @{}
                            if ($PodeContext.Server.AutoImport.SecretVaults.SecretManagement) {
                                $export.AutoImport.SecretVaults.SecretManagement = @{}
                                if ( $PodeContext.Server.AutoImport.SecretVaults.SecretManagement.Enabled) {
                                    $export.AutoImport.SecretVaults.SecretManagement.Enable = $PodeContext.Server.AutoImport.SecretVaults.SecretManagement.Enabled
                                }
                                if ( $PodeContext.Server.AutoImport.SecretVaults.SecretManagement.ExportOnly) {
                                    $export.AutoImport.SecretVaults.SecretManagement.ExportOnly = $PodeContext.Server.AutoImport.SecretVaults.SecretManagement.ExportOnly
                                }
                            }
                        }
                    }
                    break
                }
                'Root' {
                    if ($PodeContext.Server.Root -ne $PodeContext.Server.InvocationPath ) {
                        $export.Root = $PodeContext.Server.Root
                    }
                    break

                }
                'Restart' {
                    if ($PodeContext.Server.Restart) {
                        $export.Restart = @{}
                        if ($PodeContext.Server.Restart.Period) {
                            $export.Restart.Period = $PodeContext.Server.Restart.Period
                        }
                        if ($PodeContext.Server.Restart.Crons) {
                            $export.Restart.Crons = $PodeContext.Server.Restart.Crons
                        }
                        if ($PodeContext.Server.Restart.Times) {
                            $export.Restart.Times = $PodeContext.Server.Restart.Times
                        }
                    }
                    break
                }
                'FileMonitor' {
                    if ($PodeContext.Server.FileMonitor) {
                        $export.FileMonitor = @{}
                        if ($PodeContext.Server.FileMonitor.Enabled) {
                            $export.FileMonitor.Enable = $PodeContext.Server.FileMonitor.Enabled
                        }
                        if ($PodeContext.Server.FileMonitor.ShowFiles) {
                            $export.FileMonitor.ShowFiles = $PodeContext.Server.FileMonitor.ShowFiles
                        }
                        if ($PodeContext.Server.FileMonitor.Include) {
                            $export.FileMonitor.Include = $PodeContext.Server.FileMonitor.Include.Replace('^(.*?\.', '*.').Replace(')$', '')
                        }
                        if ($PodeContext.Server.FileMonitor.Exclude) {
                            $export.FileMonitor.Exclude = $PodeContext.Server.FileMonitor.Exclude.Replace('^(.*?\.', '*.').Replace(')$', '')
                        }
                    }
                    break
                }

                'DefaultFolders' {
                    if ($PodeContext.Server.DefaultFolders) {
                        $export.DefaultFolders = @{}
                        if ($PodeContext.Server.DefaultFolders.Public) {
                            $export.DefaultFolders.Public = Get-PodeDefaultFolder -Type Public
                        }
                        if ($PodeContext.Server.DefaultFolders.Views ) {
                            $export.DefaultFolders.Views = Get-PodeDefaultFolder -Type Views
                        }
                        if ($PodeContext.Server.DefaultFolders.Errors) {
                            $export.DefaultFolders.Errors = Get-PodeDefaultFolder -Type Errors
                        }
                    }
                    break
                }

                'Logging' {
                    if ($PodeContext.Server.Logging) {
                        $export.Logging = @{}
                        if ($PodeContext.Server.Logging.Masking) {
                            $export.Logging.Masking = @{}
                            if ($PodeContext.Server.Logging.Masking.Patterns) {

                                $export.Logging.Masking.Patterns = $PodeContext.Server.Logging.Masking.Patterns
                            }
                            if ($PodeContext.Server.Logging.Masking.Mask) {
                                $export.Logging.Masking.Mask = $PodeContext.Server.Logging.Masking.Mask
                            }
                        }
                        if ($PodeContext.Server.Logging.QueueLimit) {
                            $export.Logging.QueueLimit = $PodeContext.Server.Logging.QueueLimit
                        }
                    }
                    break
                }
                'Debug' {
                    if ($PodeContext.Server.Debug) {
                        $export.Debug = @{}
                        if ($PodeContext.Server.Debug.Breakpoints) {
                            $export.Debug.Breakpoints = @{}
                            if ($PodeContext.Server.Debug.Breakpoints.Enabled) {
                                $export.Debug.Breakpoints.Enable = $PodeContext.Server.Debug.Breakpoints.Enabled
                            }
                        }
                    }
                    break
                }

                'Web' {
                    if ($PodeContext.Server.Web) {
                        $export.Web = @{}
                        $export.Web += Get-PodeConfiguration -Section OpenApi
                        $export.Web += Get-PodeConfiguration -Section 'Static'
                        $export.Web += Get-PodeConfiguration -Section TransferEncoding
                        $export.Web += Get-PodeConfiguration -Section ContentType
                        $export.Web += Get-PodeConfiguration -Section ErrorPages
                        $export.Web += Get-PodeConfiguration -Section Compression
                    }
                }
                'Server' {
                    if ($PodeContext.Server) {
                        $export.Server = @{}
                        $export.Server += Get-PodeConfiguration -Section Sockets
                        $export.Server += Get-PodeConfiguration -Section Request
                        $export.Server += Get-PodeConfiguration -Section AutoImport
                        $export.Server += Get-PodeConfiguration -Section Root
                        $export.Server += Get-PodeConfiguration -Section Restart
                        $export.Server += Get-PodeConfiguration -Section FileMonitor
                        $export.Server += Get-PodeConfiguration -Section DefaultFolders
                        $export.Server += Get-PodeConfiguration -Section Logging
                        $export.Server += Get-PodeConfiguration -Section Debug
                    }
                }
                default {
                    $export += Get-PodeConfiguration -Section Web
                    $export += Get-PodeConfiguration -Section Server
                }
            }
            return $export
        }
    }
}

<#
.SYNOPSIS
Converts a hashtable or PSCustomObject to a formatted .psd1 string.

.DESCRIPTION
This function converts a given hashtable or PSCustomObject to a .psd1 formatted string.
It ensures the correct formatting by handling JSON-specific characters and removing unwanted
characters, such as commas outside of quotes and quotes before the equals sign.

.PARAMETER InputObject
The hashtable or PSCustomObject to be converted to .psd1 format.

.EXAMPLE
$hashtable = @{
    Key1 = "Value1"
    Key2 = @{
        SubKey1 = "SubValue1"
        SubKey2 = "SubValue2"
    }
    Key3 = @("ArrayValue1", "ArrayValue2")
}

$psd1Content = $hashtable | ConvertTo-PodePsd1
$psd1Content | Set-Content -Path "output.psd1"
Write-Output $psd1Content

.EXAMPLE
$psCustomObject = [pscustomobject]@{
    Key1 = "Value1"
    Key2 = [pscustomobject]@{
        SubKey1 = "SubValue1"
        SubKey2 = "SubValue2"
    }
    Key3 = @("ArrayValue1", "ArrayValue2")
}

$psd1Content = $psCustomObject | ConvertTo-PodePsd1
$psd1Content | Set-Content -Path "output.psd1"
Write-Output $psd1Content

#>
function ConvertTo-PodePsd1 {
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [object]$InputObject
    )

    process {
        if ($InputObject -is [hashtable] -or $InputObject -is [pscustomobject]) {
            # Convert the input object to JSON
            $json = $InputObject | ConvertTo-Json -Depth 10

            # Replace JSON-specific characters with .psd1-specific characters
            $psd1Content = $json.Replace('":', '" =').Replace('{', '@{').Replace('[', '@(').Replace(']', ')').Replace('true', '$True').Replace('false', '$False')

            # Use a regex to remove commas outside of quotes
            $psd1Content = [regex]::Replace($psd1Content, ',(?=(?:[^"]*"[^"]*")*[^"]*$)', '')

            # Use a regex to remove quotes before the equals sign
            $psd1Content = [regex]::Replace($psd1Content, '"(\w+)"\s*=', '$1 =')

            # Use a regex to replace double backslashes inside quotes
            $psd1Content = [regex]::Replace($psd1Content, '"([^"]*)"', {
                    param($m)
                    $innerContent = $m.Groups[1].Value
                    # Replace double backslashes with a single backslash
                    $innerContent = $innerContent.replace('\\', '\')
                    return '"' + $innerContent + '"'
                })

            # Add the appropriate .psd1 header
            $header = @'
#
# .psd1 file auto-generated by Pode
#
'@

            # Combine the header and the content
            $psd1Formatted = $header + "`n" + $psd1Content.Trim()

            return $psd1Formatted
        }
        else {
            Write-Error 'Input must be a hashtable or a pscustomobject.'
        }
    }
}
