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