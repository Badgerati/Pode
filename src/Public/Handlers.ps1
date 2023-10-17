<#
.SYNOPSIS
Adds a Handler of a specific Type.

.DESCRIPTION
Adds a Handler of a specific Type.

.PARAMETER Type
The Type of the Handler.

.PARAMETER Name
The Name of the Handler.

.PARAMETER ScriptBlock
The ScriptBlock for the Handler's main logic.

.PARAMETER FilePath
A literal, or relative, path to a file containing a ScriptBlock for the Handler's main logic.

.PARAMETER ArgumentList
An array of arguments to supply to the Handler's ScriptBlock.

.EXAMPLE
Add-PodeHandler -Type Smtp -Name 'Main' -ScriptBlock { /* logic */ }

.EXAMPLE
Add-PodeHandler -Type Service -Name 'Looper' -ScriptBlock { /* logic */ }

.EXAMPLE
Add-PodeHandler -Type Smtp -Name 'Main' -ScriptBlock { /* logic */ } -ArgumentList 'arg1', 'arg2'
#>
function Add-PodeHandler {
    [CmdletBinding(DefaultParameterSetName = 'Script')]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Service', 'Smtp')]
        [string]
        $Type,

        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true, ParameterSetName = 'Script')]
        [scriptblock]
        $ScriptBlock,

        [Parameter(Mandatory = $true, ParameterSetName = 'File')]
        [string]
        $FilePath,

        [Parameter()]
        [object[]]
        $ArgumentList
    )

    # error if serverless
    Test-PodeIsServerless -FunctionName 'Add-PodeHandler' -ThrowError

    # ensure handler isn't already set
    if ($PodeContext.Server.Handlers[$Type].ContainsKey($Name)) {
        throw "[$($Type)] $($Name): Handler already defined"
    }

    # if we have a file path supplied, load that path as a scriptblock
    if ($PSCmdlet.ParameterSetName -ieq 'file') {
        $ScriptBlock = Convert-PodeFileToScriptBlock -FilePath $FilePath
    }

    # check for scoped vars
    $ScriptBlock, $usingVars = Convert-PodeScopedVariables -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState

    # add the handler
    Write-Verbose "Adding Handler: [$($Type)] $($Name)"
    $PodeContext.Server.Handlers[$Type][$Name] += @(@{
            Logic          = $ScriptBlock
            UsingVariables = $usingVars
            Arguments      = $ArgumentList
        })
}

<#
.SYNOPSIS
Remove a specific Handler.

.DESCRIPTION
Remove a specific Handler.

.PARAMETER Type
The type of the Handler to be removed.

.PARAMETER Name
The name of the Handler to be removed.

.EXAMPLE
Remove-PodeHandler -Type Smtp -Name 'Main'
#>
function Remove-PodeHandler {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Service', 'Smtp')]
        [string]
        $Type,

        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    # ensure handler does exist
    if (!$PodeContext.Server.Handlers[$Type].ContainsKey($Name)) {
        return
    }

    # remove the handler
    $null = $PodeContext.Server.Handlers[$Type].Remove($Name)
}

<#
.SYNOPSIS
Removes all added Handlers, or Handlers of a specific Type.

.DESCRIPTION
Removes all added Handlers, or Handlers of a specific Type.

.PARAMETER Type
The Type of Handlers to remove.

.EXAMPLE
Clear-PodeHandlers -Type Smtp
#>
function Clear-PodeHandlers {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateSet('', 'Service', 'Smtp')]
        [string]
        $Type
    )

    if (![string]::IsNullOrWhiteSpace($Type)) {
        $PodeContext.Server.Handlers[$Type].Clear()
    }
    else {
        $PodeContext.Server.Handlers.Keys.Clone() | ForEach-Object {
            $PodeContext.Server.Handlers[$_].Clear()
        }
    }
}

<#
.SYNOPSIS
Automatically loads handler ps1 files

.DESCRIPTION
Automatically loads handler ps1 files from either a /handler folder, or a custom folder. Saves space dot-sourcing them all one-by-one.

.PARAMETER Path
Optional Path to a folder containing ps1 files, can be relative or literal.

.EXAMPLE
Use-PodeHandlers

.EXAMPLE
Use-PodeHandlers -Path './my-handlers'
#>
function Use-PodeHandlers {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Path
    )

    Use-PodeFolder -Path $Path -DefaultPath 'handlers'
}