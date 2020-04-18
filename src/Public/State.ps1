<#
.SYNOPSIS
Sets an object within the shared state.

.DESCRIPTION
Sets an object within the shared state.

.PARAMETER Name
The name of the state object.

.PARAMETER Value
The value to set in the state.

.EXAMPLE
Set-PodeState -Name 'Data' -Value @{ 'Name' = 'Rick Sanchez' }
#>
function Set-PodeState
{
    [CmdletBinding()]
    [OutputType([object])]
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Name,

        [Parameter(ValueFromPipeline=$true)]
        [object]
        $Value
    )

    if ($null -eq $PodeContext.Server.State) {
        throw "Pode has not been initialised"
    }

    $PodeContext.Server.State[$Name] = $Value
    return $Value
}

<#
.SYNOPSIS
Retrieves some state object from the shared state.

.DESCRIPTION
Retrieves some state object from the shared state.

.PARAMETER Name
The name of the state object.

.EXAMPLE
Get-PodeState -Name 'Data'
#>
function Get-PodeState
{
    [CmdletBinding()]
    [OutputType([object])]
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Name
    )

    if ($null -eq $PodeContext.Server.State) {
        throw "Pode has not been initialised"
    }

    return $PodeContext.Server.State[$Name]
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
function Remove-PodeState
{
    [CmdletBinding()]
    [OutputType([object])]
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Name
    )

    if ($null -eq $PodeContext.Server.State) {
        throw "Pode has not been initialised"
    }

    $value = $PodeContext.Server.State[$Name]
    $PodeContext.Server.State.Remove($Name) | Out-Null
    return $value
}

<#
.SYNOPSIS
Saves the current shared state to a supplied JSON file.

.DESCRIPTION
Saves the current shared state to a supplied JSON file. When using this function, it's recommended to wrap it in a Lock-PodeObject block.

.PARAMETER Path
The path to a JSON file which the current state will be saved to.

.PARAMETER Exclude
An optional array of state object names to exclude from being saved. (This has a higher precedence than Include)

.PARAMETER Include
An optional array of state object names to only include when being saved.

.EXAMPLE
Save-PodeState -Path './state.json'

.EXAMPLE
Save-PodeState -Path './state.json' -Exclude Name1, Name2
#>
function Save-PodeState
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Path,

        [Parameter()]
        [string[]]
        $Exclude,

        [Parameter()]
        [string[]]
        $Include
    )

    # error if attempting to use outside of the pode server
    if ($null -eq $PodeContext.Server.State) {
        throw "Pode has not been initialised"
    }

    # get the full path to save the state
    $Path = Get-PodeRelativePath -Path $Path -JoinRoot

    # contruct the state to save (excludes, etc)
    $state = @{}

    # include specific or all
    if (($null -eq $Include) -or ($Include.Length -eq 0)) {
        $state = $PodeContext.Server.State.Clone()
    }
    else {
        foreach ($key in $PodeContext.Server.State.Clone().Keys) {
            if ($Include -icontains $key) {
                $state[$key] = $PodeContext.Server.State[$key]
            }
        }
    }

    # exclude keys
    if (($null -ne $Exclude) -and ($Exclude.Length -gt 0)) {
        foreach ($key in $state.Clone().Keys) {
            if ($Exclude -icontains $key) {
                $state.Remove($key) | Out-Null
            }
        }
    }

    # save the state
    $state | ConvertTo-Json -Depth 10 | Out-File -FilePath $Path -Force | Out-Null
}

<#
.SYNOPSIS
Restores the shared state from some JSON file.

.DESCRIPTION
Restores the shared state from some JSON file.

.PARAMETER Path
The path to a JSON file that contains the state information.

.EXAMPLE
Restore-PodeState -Path './state.json'
#>
function Restore-PodeState
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Path
    )

    # error if attempting to use outside of the pode server
    if ($null -eq $PodeContext.Server.State) {
        throw "Pode has not been initialised"
    }

    # get the full path to the state
    $Path = Get-PodeRelativePath -Path $Path -JoinRoot
    if (!(Test-Path $Path)) {
        return
    }

    # restore the state from file
    if (Test-IsPSCore) {
        $PodeContext.Server.State = (Get-Content $Path -Force | ConvertFrom-Json -AsHashtable -Depth 10)
    }
    else {
        (Get-Content $Path -Force | ConvertFrom-Json).psobject.properties | ForEach-Object {
            $PodeContext.Server.State[$_.Name] = $_.Value
        }
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
function Test-PodeState
{
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Name
    )

    if ($null -eq $PodeContext.Server.State) {
        throw "Pode has not been initialised"
    }

    return $PodeContext.Server.State.ContainsKey($Name)
}