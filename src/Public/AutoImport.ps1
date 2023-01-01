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

<#
.SYNOPSIS
Exports Secret Vaults that can be auto-imported by Pode, and into its runspaces.

.DESCRIPTION
Exports Secret Vaults that can be auto-imported by Pode, and into its runspaces.

.PARAMETER Name
The Name(s) of a Secret Vault to export.

.PARAMETER Type
The Type of the Secret Vault to import - only option currently is SecretManagement (default: SecretManagement)

.EXAMPLE
Export-PodeSecretVault -Name Vault1, Vault2
#>
function Export-PodeSecretVault
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string[]]
        $Name,

        [Parameter()]
        [ValidateSet('SecretManagement')]
        [string]
        $Type = 'SecretManagement'
    )

    $PodeContext.Server.AutoImport.SecretVaults[$Type].ExportList += @($Name)
}