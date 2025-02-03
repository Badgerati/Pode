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
    $statePath = './ThreadSafeState.json'
    # re-initialise the state
    Restore-PodeState -Path $statePath

    # initialise if there was no file
    if ($null -eq ($hash = (Get-PodeState -Name 'hash1'))) {
        $hash = (Set-PodeState -Name 'hash1' -Value ([System.Collections.Concurrent.ConcurrentDictionary[string, object]]::new())  -Scope Scope0, Scope1 )
        $hash.bag = [System.Collections.Concurrent.ConcurrentBag[object]]::new()
        $hash.array = @()
        $hash.psCustomSum = [PSCustomObject]@{
            bag   = 0
            array = 0
        }
        $hash.string = 'standard string'
        $hash.number = 1
        # Assign a custom PsTypeName
        $hash.psCustomSum.PSTypeNames.Insert(0, 'Pode.StateSum')
    }

    if ($null -eq ($hash = (Get-PodeState -Name 'hash2'))) {
        $hash = Set-PodeState -Name 'hash2' -Value @{} -Scope Scope0, Scope2
        $hash['values'] = @()
    }

    if ($null -eq $state:hash3) {
        $state:hash3 = @{ values = @() }
    }

    # create timer to update a hashtable and make it globally accessible
    Add-PodeTimer -Name 'forever' -Interval 2 -ArgumentList $statePath  -ScriptBlock {
        param([string]$statePath)
        $hash = $null

        $hash = (Get-PodeState -Name 'hash1')
        $hash.bag.add((Get-Random -Minimum 0 -Maximum 10))
        $hash.array += (Get-Random -Minimum 0 -Maximum 10)

        $hash.psCustomSum.bag = $hash.bag.ToArray() | Measure-Object -Sum | Select-Object -ExpandProperty Sum
        $hash.psCustomSum.array = $hash.array | Measure-Object -Sum | Select-Object -ExpandProperty Sum

        write-podehost  $hash.psCustomSum -Explode -ShowType
        write-podehost      $hash.psCustomSum.PSTypeNames[0]
        Save-PodeState -Path $statePath -Scope Scope1 #-Exclude 'hash1'

        $state:hash3.values += (Get-Random -Minimum 0 -Maximum 10)

    }

    # route to retrieve and return the value of the hashtable from global state
    Add-PodeRoute -Method Get -Path '/array' -ScriptBlock {
        #   Lock-PodeObject -ScriptBlock {
        $hash = (Get-PodeState 'hash1')
        Write-PodeJsonResponse -Value $hash
        #    }
    }

    Add-PodeRoute -Method Get -Path '/array3' -ScriptBlock {
        #   Lock-PodeObject -ScriptBlock {
        Write-PodeJsonResponse -Value $state:hash3
        #     }
    }

    # route to remove the hashtable from global state
    Add-PodeRoute -Method Delete -Path '/array' -ScriptBlock {
        $hash = (Set-PodeState -Name 'hash1' -Value ([System.Collections.Concurrent.ConcurrentDictionary[string, object]]::new())  -Scope Scope0, Scope1 )
        $hash.bag = [System.Collections.Concurrent.ConcurrentBag[object]]::new()
        $hash.bag.add((Get-Random -Minimum 0 -Maximum 10))
        $hash.array = @((Get-Random -Minimum 0 -Maximum 10))

        $hash.psCustomSum = [PSCustomObject]@{
            bag   = $hash.bag.ToArray() | Measure-Object -Sum | Select-Object -ExpandProperty Sum
            array = $hash.array | Measure-Object -Sum | Select-Object -ExpandProperty Sum
        }
        # Assign a custom PsTypeName
        $hash.psCustomSum.PSTypeNames.Insert(0, 'Pode.StateSum')
        $hash.string = 'standard string'
        $hash.number = 1

    }

}