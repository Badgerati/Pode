<#
.SYNOPSIS
    A sample PowerShell script to set up a Pode server with state management and logging.

.DESCRIPTION
    This script sets up a Pode server that listens on port 8081, logs requests and errors to the terminal,
    and manages state using timers and routes. The server initializes state from a JSON file, updates state
    periodically using timers, and provides routes to interact with the state.

    The state is setup using thread-safe collections.

.EXAMPLE
    To run the sample: ./Shared-State-Concurrent.ps1

    Invoke-RestMethod -Uri http://localhost:8081/array -Method Get
    Invoke-RestMethod -Uri http://localhost:8081/array3 -Method Get
    Invoke-RestMethod -Uri http://localhost:8081/array -Method Delete

.LINK
    https://github.com/Badgerati/Pode/blob/develop/examples/Shared-State-Concurrent.ps1

.NOTES
    Author: Pode Team
    License: MIT License
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
    New-PodeLogTerminalMethod | Enable-PodeLogRequestType
    New-PodeLogTerminalMethod | Enable-PodeLogErrorType

    # re-initialise the state
    Restore-PodeState -Path './state-concurrent.json'

    # initialise if there was no file
    if ($null -eq ($hash = (Get-PodeState -Name 'hash1'))) {
        $hash = Set-PodeState -Name 'hash1' -Value (New-PodeStateDictionary) -Scope Scope0, Scope1
        $null = $hash.values = New-PodeStateList
    }

    if ($null -eq ($hash = (Get-PodeState -Name 'hash2'))) {
        $hash = Set-PodeState -Name 'hash2' -Value (New-PodeStateDictionary) -Scope Scope0, Scope2
        $hash.values = New-PodeStateList
    }

    if ($null -eq $state:hash3) {
        $state:hash3 = (New-PodeStateDictionary)
        $state:hash3.values = New-PodeStateList
    }

    # create timer to update a hashtable and make it globally accessible
    Add-PodeTimer -Name 'forever' -Interval 2 -ScriptBlock {
        $hash = Get-PodeState -Name 'hash1'
        $null = $hash.values.TryAdd((Get-Random -Minimum 0 -Maximum 10))
        Save-PodeState -Path './state-concurrent.json' -Scope Scope1

        $null = $state:hash3.values.TryAdd((Get-Random -Minimum 0 -Maximum 10))
    }

    # route to retrieve and return the value of the hashtable from global state
    Add-PodeRoute -Method Get -Path '/array' -ScriptBlock {
        $hash = Get-PodeState 'hash1'
        Write-PodeJsonResponse -Value $hash
    }

    Add-PodeRoute -Method Get -Path '/array3' -ScriptBlock {
        Write-PodeJsonResponse -Value $state:hash3
    }

    # route to remove the hashtable from global state
    Add-PodeRoute -Method Delete -Path '/array' -ScriptBlock {
        $hash = Set-PodeState -Name 'hash1' -Value (New-PodeStateDictionary) -Scope Scope0, Scope1
        $hash['values'] = New-PodeStateList
    }

}