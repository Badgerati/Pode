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

    # Record the operation on the trace log
    Write-PodeTraceLog -Operation $MyInvocation.MyCommand.Name -Parameters $PSBoundParameters

    if (Test-PodeLockable -Name $Name) {
        $PodeContext.Threading.Lockables.Custom.Remove($Name)
    }
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

    # Record the operation on the trace log
    Write-PodeTraceLog -Operation $MyInvocation.MyCommand.Name -Parameters $PSBoundParameters

    if (Test-PodeIsEmpty $PodeContext.Threading.Lockables.Custom) {
        return
    }

    foreach ($name in $PodeContext.Threading.Lockables.Custom.Keys.Clone()) {
        Remove-PodeLockable -Name $name
    }
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

    # Record the operation on the trace log
    Write-PodeTraceLog -Operation $MyInvocation.MyCommand.Name -Parameters $PSBoundParameters

    if (Test-PodeMutex -Name $Name) {
        $PodeContext.Threading.Mutexes[$Name].Dispose()
        $PodeContext.Threading.Mutexes.Remove($Name)
    }
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

    # Record the operation on the trace log
    Write-PodeTraceLog -Operation $MyInvocation.MyCommand.Name -Parameters $PSBoundParameters

    if (Test-PodeIsEmpty $PodeContext.Threading.Mutexes) {
        return
    }

    foreach ($name in $PodeContext.Threading.Mutexes.Keys.Clone()) {
        Remove-PodeMutex -Name $name
    }
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

    # Record the operation on the trace log
    Write-PodeTraceLog -Operation $MyInvocation.MyCommand.Name -Parameters $PSBoundParameters

    if (Test-PodeSemaphore -Name $Name) {
        $PodeContext.Threading.Semaphores[$Name].Dispose()
        $PodeContext.Threading.Semaphores.Remove($Name)
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

    # Record the operation on the trace log
    Write-PodeTraceLog -Operation $MyInvocation.MyCommand.Name -Parameters $PSBoundParameters

    if (Test-PodeIsEmpty $PodeContext.Threading.Semaphores) {
        return
    }

    foreach ($name in $PodeContext.Threading.Semaphores.Keys.Clone()) {
        Remove-PodeSemaphore -Name $name
    }
}