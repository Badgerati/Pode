<#
.SYNOPSIS
Exports modules that can be auto-imported by Pode, and into its runspaces.

.DESCRIPTION
Exports modules that can be auto-imported by Pode, and into its runspaces.

.PARAMETER Name
The Name(s) of modules to export.

.EXAMPLE
Export-PodeModule -Name Mod1, Mod2
#>
function Export-PodeModule
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string[]]
        $Name
    )

    $PodeContext.Server.AutoImport.Modules.ExportList += @($Name)
}

<#
.SYNOPSIS
Exports snapins that can be auto-imported by Pode, and into its runspaces.

.DESCRIPTION
Exports snapins that can be auto-imported by Pode, and into its runspaces.

.PARAMETER Name
The Name(s) of snapins to export.

.EXAMPLE
Export-PodeSnapin -Name Mod1, Mod2
#>
function Export-PodeSnapin
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string[]]
        $Name
    )

    # if non-windows or core, fail
    if ((Test-PodeIsPSCore) -or (Test-PodeIsUnix)) {
        throw 'Snapins are only supported on Windows PowerShell'
    }

    $PodeContext.Server.AutoImport.Snapins.ExportList += @($Name)
}

<#
.SYNOPSIS
Exports functions that can be auto-imported by Pode, and into its runspaces.

.DESCRIPTION
Exports functions that can be auto-imported by Pode, and into its runspaces.

.PARAMETER Name
The Name(s) of functions to export.

.EXAMPLE
Export-PodeFunction -Name Mod1, Mod2
#>
function Export-PodeFunction
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string[]]
        $Name
    )

    $PodeContext.Server.AutoImport.Functions.ExportList += @($Name)
}