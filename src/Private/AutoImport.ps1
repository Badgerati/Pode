function Import-PodeFunctionsIntoRunspaceState
{
    param(
        [Parameter(Mandatory=$true, ParameterSetName='Script')]
        [scriptblock]
        $ScriptBlock,

        [Parameter(Mandatory=$true, ParameterSetName='File')]
        [string]
        $FilePath
    )

    # do nothing if disabled
    if (!$PodeContext.Server.AutoImport.Functions.Enabled) {
        return
    }

    # if export only, and there are none, do nothing
    if ($PodeContext.Server.AutoImport.Functions.ExportOnly -and ($PodeContext.Server.AutoImport.Functions.ExportList.Length -eq 0)) {
        return
    }

    # script or file functions?
    switch ($PSCmdlet.ParameterSetName.ToLowerInvariant()) {
        'script' {
            $funcs = (Get-PodeFunctionsFromScriptBlock -ScriptBlock $ScriptBlock)
        }

        'file' {
            $funcs = (Get-PodeFunctionsFromFile -FilePath $FilePath)
        }
    }

    # looks like we have nothing!
    if (($null -eq $funcs) -or ($funcs.Length -eq 0)) {
        return
    }

    # groups funcs in case there or multiple definitions
    $funcs = ($funcs | Group-Object -Property { $_.Name })

    # import them, but also check if they're exported
    foreach ($func in $funcs) {
        # only exported funcs? is the func exported?
        if ($PodeContext.Server.AutoImport.Functions.ExportOnly -and ($PodeContext.Server.AutoImport.Functions.ExportList -inotcontains $func.Name)) {
            continue
        }

        # load the function
        $funcDef = [System.Management.Automation.Runspaces.SessionStateFunctionEntry]::new($func.Name, $func.Group[-1].Definition)
        $PodeContext.RunspaceState.Commands.Add($funcDef)
    }
}

function Import-PodeModulesIntoRunspaceState
{
    # do nothing if disabled
    if (!$PodeContext.Server.AutoImport.Modules.Enabled) {
        return
    }

    # if export only, and there are none, do nothing
    if ($PodeContext.Server.AutoImport.Modules.ExportOnly -and ($PodeContext.Server.AutoImport.Modules.ExportList.Length -eq 0)) {
        return
    }

    # get modules currently loaded in session
    $modules = Get-Module |
        Where-Object {
            ($_.Name -ine 'pode') -and ($_.Name -inotlike 'microsoft.powershell.*')
        } | Select-Object -Unique

    # work out which order the modules need to be loaded
    $modulesOrder = @(foreach ($module in $modules) {
        Get-PodeModuleDependencies -Module $module
    }) |
        Where-Object {
            ($_.Name -ine 'pode') -and ($_.Name -inotlike 'microsoft.powershell.*')
        } | Select-Object -Unique

    # load modules into runspaces, if allowed
    foreach ($module in $modulesOrder) {
        # only exported modules? is the module exported?
        if ($PodeContext.Server.AutoImport.Modules.ExportOnly -and ($PodeContext.Server.AutoImport.Modules.ExportList -inotcontains $module.Name)) {
            continue
        }

        # import the module
        $path = Find-PodeModuleFile -Module $module

        if (($module.ModuleType -ieq 'Manifest') -or ($path.EndsWith('.ps1'))) {
            $PodeContext.RunspaceState.ImportPSModule($path)
        }
        else {
            $PodeContext.Server.Modules[$module.Name] = $path
        }
    }
}

function Import-PodeSnapinsIntoRunspaceState
{
    # if non-windows or core, do nothing
    if ((Test-PodeIsPSCore) -or (Test-PodeIsUnix)) {
        return
    }

    # do nothing if disabled
    if (!$PodeContext.Server.AutoImport.Snapins.Enabled) {
        return
    }

    # if export only, and there are none, do nothing
    if ($PodeContext.Server.AutoImport.Snapins.ExportOnly -and ($PodeContext.Server.AutoImport.Snapins.ExportList.Length -eq 0)) {
        return
    }

    # load snapins into runspaces, if allowed
    $snapins = (Get-PSSnapin | Where-Object { !$_.IsDefault }).Name | Sort-Object -Unique

    foreach ($snapin in $snapins) {
        # only exported snapins? is the snapin exported?
        if ($PodeContext.Server.AutoImport.Snapins.ExportOnly -and ($PodeContext.Server.AutoImport.Snapins.ExportList -inotcontains $snapin)) {
            continue
        }

        $PodeContext.RunspaceState.ImportPSSnapIn($snapin, [ref]$null)
    }
}

function Initialize-PodeAutoImportConfiguration
{
    return @{
        Modules = @{
            Enabled = $true
            ExportList = @()
            ExportOnly = $false
        }
        Snapins = @{
            Enabled = $true
            ExportList = @()
            ExportOnly = $false
        }
        Functions = @{
            Enabled = $true
            ExportList = @()
            ExportOnly = $false
        }
        SecretVaults = @{
            Enabled = $true
            SecretManagement = @{
                Enabled = $false
                ExportList = @()
                ExportOnly = $false
            }
        }
    }
}

function Import-PodeSecretVaultsIntoRegistry
{
    # do nothing if disabled
    if (!$PodeContext.Server.AutoImport.SecretVaults.Enabled) {
        return
    }

    Import-PodeSecretManagementVaultsIntoRegistry
}

function Import-PodeSecretManagementVaultsIntoRegistry
{
    # do nothing if disabled
    if (!$PodeContext.Server.AutoImport.SecretVaults.SecretManagement.Enabled) {
        return
    }

    # if export only, and there are none, do nothing
    if ($PodeContext.Server.AutoImport.SecretVaults.SecretManagement.ExportOnly -and ($PodeContext.Server.AutoImport.SecretVaults.SecretManagement.ExportList.Length -eq 0)) {
        return
    }

    # error if SecretManagement module not installed
    if (!(Test-PodeModuleInstalled -Name Microsoft.PowerShell.SecretManagement)) {
        throw 'Microsoft.PowerShell.SecretManagement module not installed'
    }

    # import the module
    $null = Import-Module -Name Microsoft.PowerShell.SecretManagement -Force -DisableNameChecking -Scope Global -ErrorAction Stop -Verbose:$false

    # get the current secret vaults
    $vaults = @(Get-SecretVault -ErrorAction Stop)

    # register the vaults
    foreach ($vault in $vaults) {
        # only exported vaults? is the vault exported?
        if ($PodeContext.Server.AutoImport.SecretVaults.SecretManagement.ExportOnly -and ($PodeContext.Server.AutoImport.SecretVaults.SecretManagement.ExportList -inotcontains $vault.Name)) {
            continue
        }

        # is a vault with this name already registered?
        if (Test-PodeSecretVault -Name $vault.Name) {
            throw "A Secret Vault with the name '$($vault.Name)' has already been registered while auto-importing Secret Vaults"
        }

        # register the vault
        $PodeContext.Server.Secrets.Vaults[$vault.Name] = @{
            Name = $vault.Name
            Type = 'secretmanagement'
            Parameters = $vault.VaultParameters
            AutoImported = $true
            Unlock = $null
            Cache = $null
            SecretManagement = @{
                VaultName = $vault.Name
                ModuleName = $vault.ModulePath
            }
        }
    }
}

function Read-PodeAutoImportConfiguration
{
    param(
        [Parameter()]
        [hashtable]
        $Configuration
    )

    $impModules = $Configuration.AutoImport.Modules
    $impSnapins = $Configuration.AutoImport.Snapins
    $impFuncs = $Configuration.AutoImport.Functions
    $impSecretVaults = $Configuration.AutoImport.SecretVaults

    return @{
        Modules = @{
            Enabled = (($null -eq $impModules.Enable) -or [bool]$impModules.Enable)
            ExportList = @()
            ExportOnly = ([bool]$impModules.ExportOnly)
        }
        Snapins = @{
            Enabled = (($null -eq $impSnapins.Enable) -or [bool]$impSnapins.Enable)
            ExportList = @()
            ExportOnly = ([bool]$impSnapins.ExportOnly)
        }
        Functions = @{
            Enabled = (($null -eq $impFuncs.Enable) -or [bool]$impFuncs.Enable)
            ExportList = @()
            ExportOnly = ([bool]$impFuncs.ExportOnly)
        }
        SecretVaults = @{
            Enabled = (($null -eq $impSecretVaults.Enable) -or [bool]$impSecretVaults.Enable)
            SecretManagement = @{
                Enabled = ((($null -eq $impSecretVaults.Enable) -and (Test-PodeModuleInstalled -Name Microsoft.PowerShell.SecretManagement)) -or [bool]$impSecretVaults.Enable)
                ExportList = @()
                ExportOnly = ([bool]$impSecretVaults.SecretManagement.ExportOnly)
            }
        }
    }
}

function Reset-PodeAutoImportConfiguration
{
    $PodeContext.Server.AutoImport.Modules.ExportList = @()
    $PodeContext.Server.AutoImport.Snapins.ExportList = @()
    $PodeContext.Server.AutoImport.Functions.ExportList = @()
    $PodeContext.Server.AutoImport.SecretVaults.SecretManagement.ExportList = @()
}