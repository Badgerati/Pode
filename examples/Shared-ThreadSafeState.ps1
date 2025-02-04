<#
.SYNOPSIS
    A sample PowerShell script to set up a Pode server with thread-safe state management and logging.

.DESCRIPTION
    This script sets up a Pode server that listens on port 8081, logs requests and errors to the terminal, and manages state using thread-safe collections such as `ConcurrentDictionary` and `ConcurrentBag`. The server initializes state from a JSON file, updates state periodically using timers, and provides routes to interact with the state.

.EXAMPLE
    To run the sample: ./Shared-ThreadSafeState.ps1

    Invoke-RestMethod -Uri http://localhost:8081/array -Method Get
    Invoke-RestMethod -Uri http://localhost:8081/array3 -Method Get
    Invoke-RestMethod -Uri http://localhost:8081/array -Method Delete

.LINK
    https://github.com/Badgerati/Pode/blob/develop/examples/Shared-ThreadSafeState.ps1

.NOTES
    Author: Pode Team
    License: MIT License
    This script uses `ConcurrentDictionary` and `ConcurrentBag` to ensure thread-safe state handling in a multi-threaded Pode environment.
#>

try {
    # Determine the script path and Pode module path
    $ScriptPath = (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
    $podePath = Split-Path -Parent -Path $ScriptPath

    # Import the Pode module from the source path if it exists, otherwise from installed modules
    if (Test-Path -Path "$($podePath)/src/Pode.psm1" -PathType Leaf) {
        Import-Module "$($podePath)/src/Pode.psm1" -Force -ErrorAction Stop
    }
    else {
        Import-Module -Name 'Pode' -MaximumVersion 2.99 -ErrorAction Stop
    }
}
catch { throw }

# or just:
# Import-Module Pode

# create a basic server
Start-PodeServer {

    Add-PodeEndpoint -Address localhost -Port 8081 -Protocol Http
    New-PodeLoggingMethod -Terminal | Enable-PodeRequestLogging
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging
    $Path = Get-PodeRelativePath -Path './State' -JoinRoot -Resolve

    if (!(Test-Path -Path $Path -PathType Container)) {
        New-Item -Path $Path -ItemType Directory

    }
    $stateScope1Path = Join-Path -Path $Path -ChildPath 'ThreadSafeStateScope1.json'
    $stateScope2Path = Join-Path -Path $Path -ChildPath 'ThreadSafeStateScope2.json'
    $stateScope0Path = Join-Path -Path $Path -ChildPath 'ThreadSafeStateScope0.json'
    $stateNoScopePath = Join-Path -Path $Path -ChildPath 'ThreadSafeStateNoScope.json'
    # re-initialise the state
    Restore-PodeState -Path $stateScope1Path
    Restore-PodeState -Path $stateScope2Path -Merge
    Save-PodeState -Path $stateNoScopePath
    # initialise if there was no file
    if (!(Test-PodeState -Name 'hash1')) {
        $hash = (Set-PodeState -Name 'hash1' -NewCollectionType ConcurrentDictionary  -Scope Scope0, Scope1 )
        $hash.bag = [System.Collections.Concurrent.ConcurrentBag[object]]::new()
        $hash.array = @()
        $hash.psCustomSum = [PSCustomObject]@{
            bag   = 0
            array = 0
        }
        $hash.string = 'Never deleted'
        $hash.deleted = 0
        # Assign a custom PsTypeName
        $hash.psCustomSum.PSTypeNames.Insert(0, 'Pode.StateSum')
    }

    if (!(Test-PodeState -Name 'hash2')) {
        $hash = Set-PodeState -Name 'hash2' -NewCollectionType Hashtable -Scope Scope0, Scope2
        $hash['values'] = @()
    }

    if ($null -eq $state:hash3) {
        $state:hash3 = @{ values = @() }
    }

    # create timer to update a hashtable and make it globally accessible
    Add-PodeTimer -Name 'forever' -Interval 2 -ArgumentList $stateScope1Path, $stateScope2Path, $stateScope0Path, $stateNoScopePath  -ScriptBlock {
        param([string]$stateScope1Path, [string]$stateScope2Path, [string]$stateScope0Path, [string]$stateNoScopePath)
        $hash = $null

        $hash = (Get-PodeState -Name 'hash1')
        $hash.bag.add((Get-Random -Minimum 0 -Maximum 10))
        $hash.array += (Get-Random -Minimum 0 -Maximum 10)

        $hash.psCustomSum.bag = $hash.bag.ToArray() | Measure-Object -Sum | Select-Object -ExpandProperty Sum
        $hash.psCustomSum.array = $hash.array | Measure-Object -Sum | Select-Object -ExpandProperty Sum


        $state:hash3.values += (Get-Random -Minimum 0 -Maximum 10)

        $hash2 = (Get-PodeState -Name 'hash2')
        $hash2.values += (Get-Random -Minimum 100 -Maximum 200)
        Save-PodeState -Path $stateScope1Path -Scope Scope1 #-Exclude 'hash2'
        Save-PodeState -Path $stateScope2Path -Scope Scope2
        Save-PodeState -Path $stateScope0Path -Scope Scope0
        Save-PodeState -Path $stateNoScopePath
    }

    # route to retrieve and return the value of the hashtable from global state
    Add-PodeRoute -Method Get -Path '/array' -ScriptBlock {
        $hash = (Get-PodeState 'hash1')
        Write-PodeJsonResponse -Value $hash
    }

    Add-PodeRoute -Method Get -Path '/array3' -ScriptBlock {
        Write-PodeJsonResponse -Value $state:hash3
    }

    # route to remove the hashtable from global state
    Add-PodeRoute -Method Delete -Path '/array' -ScriptBlock {
        $value = (Get-PodeState -Name 'hash1' )
        $hash = (Set-PodeState -Name 'hash1' -NewCollectionType ConcurrentDictionary  -Scope Scope0, Scope1 )
        $hash.bag = [System.Collections.Concurrent.ConcurrentBag[object]]::new()
        $hash.bag.add((Get-Random -Minimum 0 -Maximum 10))
        $hash.array = @((Get-Random -Minimum 0 -Maximum 10))

        $hash.psCustomSum = [PSCustomObject]@{
            bag   = $hash.bag.ToArray() | Measure-Object -Sum | Select-Object -ExpandProperty Sum
            array = $hash.array | Measure-Object -Sum | Select-Object -ExpandProperty Sum
        }
        # Assign a custom PsTypeName
        $hash.psCustomSum.PSTypeNames.Insert(0, 'Pode.StateSum')
        $hash.deleted = $value.number + 1
        $hash.string = "Deleted $($hash.number) times"

    }

}