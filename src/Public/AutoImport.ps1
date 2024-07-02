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
function Export-PodeModule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]
        $Name
    )

    $PodeContext.Server.AutoImport.Modules.ExportList += @($Name)
    $PodeContext.Server.AutoImport.Modules.ExportList = $PodeContext.Server.AutoImport.Modules.ExportList | Sort-Object -Unique
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
function Export-PodeSnapin {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]
        $Name
    )

    # if non-windows or core, fail
    if ((Test-PodeIsPSCore) -or (Test-PodeIsUnix)) {
        # Snapins are only supported on Windows PowerShell
        throw ($PodeLocale.snapinsSupportedOnWindowsPowershellOnlyExceptionMessage)
    }

    $PodeContext.Server.AutoImport.Snapins.ExportList += @($Name)
    $PodeContext.Server.AutoImport.Snapins.ExportList = $PodeContext.Server.AutoImport.Snapins.ExportList | Sort-Object -Unique
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
function Export-PodeFunction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]
        $Name
    )

    $PodeContext.Server.AutoImport.Functions.ExportList += @($Name)
    $PodeContext.Server.AutoImport.Functions.ExportList = $PodeContext.Server.AutoImport.Functions.ExportList | Sort-Object -Unique
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
function Export-PodeSecretVault {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]
        $Name,

        [Parameter()]
        [ValidateSet('SecretManagement')]
        [string]
        $Type = 'SecretManagement'
    )

    $PodeContext.Server.AutoImport.SecretVaults[$Type].ExportList += @($Name)
    $PodeContext.Server.AutoImport.SecretVaults[$Type].ExportList = $PodeContext.Server.AutoImport.SecretVaults[$Type].ExportList | Sort-Object -Unique
}