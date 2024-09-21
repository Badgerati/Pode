<#
.SYNOPSIS
    Sets the name of the current runspace.

.DESCRIPTION
    The Set-PodeCurrentRunspaceName function assigns a specified name to the current runspace.
    This can be useful for identifying and managing the runspace in scripts and during debugging.

.PARAMETER Name
    The name to assign to the current runspace. This parameter is mandatory.

.EXAMPLE
    Set-PodeCurrentRunspaceName -Name "MyRunspace"
    This command sets the name of the current runspace to "MyRunspace".

.NOTES
    This is an internal function and may change in future releases of Pode.
#>

function Set-PodeCurrentRunspaceName {
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    # Get the current runspace
    $currentRunspace = [System.Management.Automation.Runspaces.Runspace]::DefaultRunspace
     # Set the name of the current runspace if the name is not already set
    if ( $currentRunspace.Name -ne $Name) {
        # Set the name of the current runspace
        $currentRunspace.Name = $Name
    }
}

<#
.SYNOPSIS
    Retrieves the name of the current PowerShell runspace.

.DESCRIPTION
    The Get-PodeCurrentRunspaceName function retrieves the name of the current PowerShell runspace.
    This can be useful for debugging or logging purposes to identify the runspace in use.

.EXAMPLE
    Get-PodeCurrentRunspaceName
    Returns the name of the current runspace.

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function Get-PodeCurrentRunspaceName {
    # Get the current runspace
    $currentRunspace = [System.Management.Automation.Runspaces.Runspace]::DefaultRunspace

    # Get the name of the current runspace
    return $currentRunspace.Name
}
