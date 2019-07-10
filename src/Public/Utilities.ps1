function Wait-PodeTask
{
    [CmdletBinding()]
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

        $Error[0] | Out-Default
        throw $_.Exception
    }
    finally {
        $Disposable.Dispose()
    }
}

function Lock-PodeObject
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [object]
        $Object,

        [Parameter(Mandatory=$true)]
        [scriptblock]
        $ScriptBlock
    )

    if ($null -eq $Object) {
        return
    }

    if ($Object -is 'ValueType') {
        throw 'Cannot lock value types'
    }

    $locked = $false

    try {
        [System.Threading.Monitor]::Enter($Object.SyncRoot)
        $locked = $true

        if ($null -ne $ScriptBlock) {
            Invoke-PodeScriptBlock -ScriptBlock $ScriptBlock -NoNewClosure
        }
    }
    catch {
        $Error[0] | Out-Default
        throw $_.Exception
    }
    finally {
        if ($locked) {
            [System.Threading.Monitor]::Pulse($Object.SyncRoot)
            [System.Threading.Monitor]::Exit($Object.SyncRoot)
        }
    }
}

function Get-PodeServerPath
{
    return $PodeContext.Server.Root
}

function Start-PodeStopwatch
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Name,

        [Parameter(Mandatory=$true)]
        [scriptblock]
        $ScriptBlock
    )

    try {
        $watch = [System.Diagnostics.Stopwatch]::StartNew()
        . $ScriptBlock
    }
    catch {
        $Error[0] | Out-Default
        throw $_.Exception
    }
    finally {
        $watch.Stop()
        Out-Default -InputObject "[Stopwatch]: $($watch.Elapsed) [$($Name)]"
    }
}

function Use-PodeStream
{
    [CmdletBinding()]
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
        $Error[0] | Out-Default
        throw $_.Exception
    }
    finally {
        $Stream.Dispose()
    }
}

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

function Get-PodeSettings
{
    return $PodeContext.Server.Settings
}

function Add-PodeEndware
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [scriptblock]
        $ScriptBlock
    )

    # add the scriptblock to array of endware that needs to be run
    $PodeContext.Server.Endware += $ScriptBlock
}

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

function Protect-PodeValue
{
    [CmdletBinding()]
    param (
        [Parameter()]
        $Value,

        [Parameter()]
        $Default
    )

    return (Resolve-PodeValue -Check (Test-IsEmpty $Value) -TrueValue $Default -FalseValue $Value)
}

function Resolve-PodeValue
{
    [CmdletBinding()]
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

function Invoke-PodeScriptBlock
{
    [CmdletBinding()]
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

function Test-IsEmpty
{
    [CmdletBinding()]
    param (
        [Parameter()]
        $Value
    )

    if ($null -eq $Value) {
        return $true
    }

    switch ($Value) {
        { $_ -is 'string' } {
            return [string]::IsNullOrWhiteSpace($Value)
        }

        { $_ -is 'array' } {
            return ($Value.Length -eq 0)
        }

        { $_ -is 'hashtable' } {
            return ($Value.Count -eq 0)
        }

        { $_ -is 'scriptblock' } {
            return ($null -eq $Value -or [string]::IsNullOrWhiteSpace($Value.ToString()))
        }

        { $_ -is 'valuetype' } {
            return $false
        }
    }

    return ([string]::IsNullOrWhiteSpace($Value) -or ((Get-PodeCount $Value) -eq 0))
}

function Test-IsPSCore
{
    return (Get-PodePSVersionTable).PSEdition -ieq 'core'
}

function Test-IsUnix
{
    return (Get-PodePSVersionTable).Platform -ieq 'unix'
}

function Test-IsWindows
{
    $v = Get-PodePSVersionTable
    return ($v.Platform -ilike '*win*' -or ($null -eq $v.Platform -and $v.PSEdition -ieq 'desktop'))
}