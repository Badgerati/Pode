<#
.SYNOPSIS
Disables Pode's auto-import feature for modules.

.DESCRIPTION
Disables Pode's auto-import feature for modules into its runspaces.

.EXAMPLE
Disable-PodeModuleImport
#>
function Disable-PodeModuleImport
{
    [CmdletBinding()]
    param()

    $PodeContext.Server.AutoImporters.Modules.Enabled = $false
}

<#
.SYNOPSIS
Enables Pode's auto-import feature for modules.

.DESCRIPTION
Enables Pode's auto-import feature for modules, with option to only load exported modules.

.PARAMETER OnlyExported
If supplied, only modules exported via Export-PodeModule will be auto-imported.

.EXAMPLE
Enable-PodeModuleImport

.EXAMPLE
Enable-PodeModuleImport -OnlyExported
#>
function Enable-PodeModuleImport
{
    [CmdletBinding()]
    param(
        [switch]
        $OnlyExported
    )

    $PodeContext.Server.AutoImporters.Modules.Enabled = $true
    $PodeContext.Server.AutoImporters.Modules.OnlyExported = $OnlyExported
}

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

    $PodeContext.Server.AutoImporters.Modules.Exported += @($Name)
}

<#
.SYNOPSIS
Disables Pode's auto-import feature for snapins.

.DESCRIPTION
Disables Pode's auto-import feature for snapins into its runspaces.

.EXAMPLE
Disable-PodeSnapinImport
#>
function Disable-PodeSnapinImport
{
    $PodeContext.Server.AutoImporters.Snapins.Enabled = $false
}

<#
.SYNOPSIS
Enables Pode's auto-import feature for snapins.

.DESCRIPTION
Enables Pode's auto-import feature for snapins, with option to only load exported snapins.

.PARAMETER OnlyExported
If supplied, only snapins exported via Export-PodeSnapin will be auto-imported.

.EXAMPLE
Enable-PodeSnapinImport

.EXAMPLE
Enable-PodeSnapinImport -OnlyExported
#>
function Enable-PodeSnapinImport
{
    [CmdletBinding()]
    param(
        [switch]
        $OnlyExported
    )

    $PodeContext.Server.AutoImporters.Snapins.Enabled = $true
    $PodeContext.Server.AutoImporters.Snapins.OnlyExported = $OnlyExported
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

    $PodeContext.Server.AutoImporters.Snapins.Exported += @($Name)
}

<#
.SYNOPSIS
Disables Pode's auto-import feature for functions.

.DESCRIPTION
Disables Pode's auto-import feature for functions into its runspaces.

.EXAMPLE
Disable-PodeFunctionImport
#>
function Disable-PodeFunctionImport
{
    $PodeContext.Server.AutoImporters.Functions.Enabled = $false
}

<#
.SYNOPSIS
Enables Pode's auto-import feature for functions.

.DESCRIPTION
Enables Pode's auto-import feature for functions, with option to only load exported functions.

.PARAMETER OnlyExported
If supplied, only functions exported via Export-PodeFunction will be auto-imported.

.EXAMPLE
Enable-PodeFunctionImport

.EXAMPLE
Enable-PodeFunctionImport -OnlyExported
#>
function Enable-PodeFunctionImport
{
    [CmdletBinding()]
    param(
        [switch]
        $OnlyExported
    )

    $PodeContext.Server.AutoImporters.Functions.Enabled = $true
    $PodeContext.Server.AutoImporters.Functions.OnlyExported = $OnlyExported
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

    $PodeContext.Server.AutoImporters.Functions.Exported += @($Name)
}