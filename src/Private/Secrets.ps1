function Initialize-PodeSecretVault {
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [hashtable]
        $VaultConfig,

        [Parameter(Mandatory = $true)]
        [scriptblock]
        $ScriptBlock
    )
    Process {
        $null = Invoke-PodeScriptBlock -ScriptBlock $ScriptBlock -Splat -Arguments @($VaultConfig.Parameters)
    }
}

function Register-PodeSecretManagementVault {
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [hashtable]
        $VaultConfig,

        [Parameter()]
        [string]
        $VaultName,

        [Parameter(Mandatory = $true)]
        [string]
        $ModuleName
    )
    Begin {
        $pipelineItemCount = 0
    }

    Process {
        $pipelineItemCount++
    }

    End {
        if ($pipelineItemCount -gt 1) {
            throw "The function '$($MyInvocation.MyCommand.Name)' does not accept an array as pipeline input."
        }
        # use the Name for VaultName if not passed
        if ([string]::IsNullOrWhiteSpace($VaultName)) {
            $VaultName = $VaultConfig.Name
        }

        # import the modules
        $null = Import-Module -Name Microsoft.PowerShell.SecretManagement -Force -DisableNameChecking -Scope Global -ErrorAction Stop -Verbose:$false
        $null = Import-Module -Name $ModuleName -Force -DisableNameChecking -Scope Global -ErrorAction Stop -Verbose:$false

        # export the modules for pode
        Export-PodeModule -Name @('Microsoft.PowerShell.SecretManagement', $ModuleName)

        # is this the local SecretStore provider?
        $isSecretStore = ($ModuleName -ieq 'Microsoft.PowerShell.SecretStore')

    # check if we have an unlock password for local secret store
    if ($isSecretStore) {
        if ([string]::IsNullOrEmpty($VaultConfig.Unlock.Secret)) {
            # An 'UnlockSecret' is required when using Microsoft.PowerShell.SecretStore
            throw ($PodeLocale.unlockSecretRequiredExceptionMessage)
        }
    }

        # does the local secret store already exist?
        $secretStoreExists = ($isSecretStore -and (Test-PodeSecretVaultInternal -Name $VaultName))

        # do we have vault params?
        $hasVaultParams = ($null -ne $VaultConfig.Parameters)

        # attempt to register the vault
        $registerParams = @{
            Name         = $VaultName
            ModuleName   = $ModuleName
            Confirm      = $false
            AllowClobber = $true
            ErrorAction  = 'Stop'
        }

        if (!$isSecretStore -and $hasVaultParams) {
            $registerParams['VaultParameters'] = $VaultConfig.Parameters
        }

        $null = Register-SecretVault @registerParams

        # all is good, so set the config
        $VaultConfig['SecretManagement'] = @{
            VaultName  = $VaultName
            ModuleName = $ModuleName
        }

        # set local secret store config
        if ($isSecretStore) {
            if (!$hasVaultParams) {
                $VaultConfig.Parameters = @{}
            }

            $vaultParams = $VaultConfig.Parameters

            # remove the password
            $vaultParams.Remove('Password')

            # set default authentication and interaction flags
            if ([string]::IsNullOrEmpty($vaultParams.Authentication)) {
                $vaultParams['Authentication'] = 'Password'
            }

            if ([string]::IsNullOrEmpty($vaultParams.Interaction)) {
                $vaultParams['Interaction'] = 'None'
            }

            # set default password timeout and unlock interval to 1 minute
            if ($VaultConfig.Unlock.Interval -le 0) {
                $VaultConfig.Unlock.Interval = 1
            }

            # unlock the vault, and set password
            $VaultConfig | Unlock-PodeSecretManagementVault

            # set the password timeout for the vault
            if (!$secretStoreExists) {
                if ($VaultConfig.Parameters.PasswordTimeout -le 0) {
                    $vaultParams['PasswordTimeout'] = ($VaultConfig.Unlock.Interval * 60) + 10
                }
            }

            # set config
            $null = Set-SecretStoreConfiguration @vaultParams -Confirm:$false -ErrorAction Stop
        }
    }
}

function Register-PodeSecretCustomVault {
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [hashtable]
        $VaultConfig,

        [Parameter(Mandatory = $true)]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [scriptblock]
        $UnlockScriptBlock,

        [Parameter()]
        [scriptblock]
        $RemoveScriptBlock,

        [Parameter()]
        [scriptblock]
        $SetScriptBlock,

        [Parameter()]
        [scriptblock]
        $UnregisterScriptBlock
    )
    Process {
        # unlock secret with no script?
        if ($VaultConfig.Unlock.Enabled -and (Test-PodeIsEmpty $UnlockScriptBlock)) {
            # Unlock secret supplied for custom Secret Vault type, but not Unlock ScriptBlock supplied
        throw ($PodeLocale.unlockSecretButNoScriptBlockExceptionMessage)
        }

        # all is good, so set the config
        $VaultConfig['Custom'] = @{
            Read       = $ScriptBlock
            Unlock     = $UnlockScriptBlock
            Remove     = $RemoveScriptBlock
            Set        = $SetScriptBlock
            Unregister = $UnregisterScriptBlock
        }
    }
}

function Unlock-PodeSecretManagementVault {
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [hashtable]
        $VaultConfig
    )

    Process {
        # do we need to unlock the vault?
        if (!$VaultConfig.Unlock.Enabled) {
            return $null
        }

        # unlock the vault
        $null = Unlock-SecretVault -Name $VaultConfig.SecretManagement.VaultName -Password $VaultConfig.Unlock.Secret -ErrorAction Stop

        # interval?
        if ($VaultConfig.Unlock.Interval -gt 0) {
            return ([datetime]::UtcNow.AddMinutes($VaultConfig.Unlock.Interval))
        }

        return $null
    }
}

function Unlock-PodeSecretCustomVault {
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [hashtable]
        $VaultConfig
    )
    Process {
        # do we need to unlock the vault?
        if (!$VaultConfig.Unlock.Enabled) {
            return
        }

    # do we have an unlock scriptblock
    if ($null -eq $VaultConfig.Custom.Unlock) {
         # No Unlock ScriptBlock supplied for unlocking the vault '$($VaultConfig.Name)'
        throw ($PodeLocale.noUnlockScriptBlockForVaultExceptionMessage -f $VaultConfig.Name) 
    }

        # unlock the vault, and get back an expiry
        $expiry = Invoke-PodeScriptBlock -ScriptBlock $VaultConfig.Custom.Unlock -Splat -Return -Arguments @(
            $VaultConfig.Parameters,
        (ConvertFrom-SecureString -SecureString $VaultConfig.Unlock.Secret -AsPlainText)
        )

        # return expiry if given, otherwise check interval
        if ($null -ne $expiry) {
            return $expiry
        }

        if ($VaultConfig.Unlock.Interval -gt 0) {
            return ([datetime]::UtcNow.AddMinutes($VaultConfig.Unlock.Interval))
        }

        return $null
    }
}

function Unregister-PodeSecretManagementVault {
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [hashtable]
        $VaultConfig
    )
    Process {
        # do we need to unregister the vault?
        if ($VaultConfig.AutoImported) {
            return
        }

        # unregister the vault
        $null = Unregister-SecretVault -Name $VaultConfig.SecretManagement.VaultName -Confirm:$false -ErrorAction Stop
    }
}

function Unregister-PodeSecretCustomVault {
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [hashtable]
        $VaultConfig
    )
    Process {
        # do we need to unregister the vault?
        if ($VaultConfig.AutoImported) {
            return
        }

        # do we have an unregister scriptblock? if not, just do nothing
        if ($null -eq $VaultConfig.Custom.Unregister) {
            return
        }

        # unregister the vault
        $null = Invoke-PodeScriptBlock -ScriptBlock $VaultConfig.Custom.Unregister -Splat -Arguments @(
            $VaultConfig.Parameters
        )
    }
}

function Get-PodeSecretManagementKey {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Vault,

        [Parameter(Mandatory = $true)]
        [string]
        $Key
    )

    # get the vault
    $_vault = $PodeContext.Server.Secrets.Vaults[$Vault]

    # fetch the secret
    return (Get-Secret -Name $Key -Vault $_vault.SecretManagement.VaultName -AsPlainText -ErrorAction Stop)
}

function Get-PodeSecretCustomKey {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Vault,

        [Parameter(Mandatory = $true)]
        [string]
        $Key,

        [Parameter()]
        [object[]]
        $ArgumentList
    )

    # get the vault
    $_vault = $PodeContext.Server.Secrets.Vaults[$Vault]

    # fetch the secret
    return Invoke-PodeScriptBlock -ScriptBlock $_vault.Custom.Read -Splat -Return -Arguments (@(
            $_vault.Parameters,
            $Key
        ) + $ArgumentList)
}

function Set-PodeSecretManagementKey {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Vault,

        [Parameter(Mandatory = $true)]
        [string]
        $Key,

        [Parameter(Mandatory = $true)]
        [object]
        $Value,

        [Parameter()]
        [hashtable]
        $Metadata
    )

    # get the vault
    $_vault = $PodeContext.Server.Secrets.Vaults[$Vault]

    # set the secret
    $null = Set-Secret -Name $Key -Secret $Value -Vault $_vault.SecretManagement.VaultName -Metadata $Metadata -Confirm:$false -ErrorAction Stop
}

function Set-PodeSecretCustomKey {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Vault,

        [Parameter(Mandatory = $true)]
        [string]
        $Key,

        [Parameter(Mandatory = $true)]
        [object]
        $Value,

        [Parameter()]
        [hashtable]
        $Metadata,

        [Parameter()]
        [object[]]
        $ArgumentList
    )

    # get the vault
    $_vault = $PodeContext.Server.Secrets.Vaults[$Vault]

    # do we have a set scriptblock?
    if ($null -eq $_vault.Custom.Set) {
        throw ($PodeLocale.noSetScriptBlockForVaultExceptionMessage -f $_vault.Name) #"No Set ScriptBlock supplied for updating/creating secrets in the vault '$($_vault.Name)'"
    }

    # set the secret
    $null = Invoke-PodeScriptBlock -ScriptBlock $_vault.Custom.Set -Splat -Arguments (@(
            $_vault.Parameters,
            $Key,
            $Value,
            $Metadata
        ) + $ArgumentList)
}

function Remove-PodeSecretManagementKey {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Vault,

        [Parameter(Mandatory = $true)]
        [string]
        $Key
    )

    # get the vault
    $_vault = $PodeContext.Server.Secrets.Vaults[$Vault]

    # remove the secret
    $null = Remove-Secret -Name $Key -Vault $_vault.SecretManagement.VaultName -Confirm:$false -ErrorAction Stop
}

function Remove-PodeSecretCustomKey {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Vault,

        [Parameter(Mandatory = $true)]
        [string]
        $Key,

        [Parameter()]
        [object[]]
        $ArgumentList
    )

    # get the vault
    $_vault = $PodeContext.Server.Secrets.Vaults[$Vault]

    # do we have a remove scriptblock?
    if ($null -eq $_vault.Custom.Remove) {
        throw ($PodeLocale.noRemoveScriptBlockForVaultExceptionMessage -f $_vault.Name) #"No Remove ScriptBlock supplied for removing secrets from the vault '$($_vault.Name)'"
    }

    # remove the secret
    $null = Invoke-PodeScriptBlock -ScriptBlock $_vault.Custom.Remove -Splat -Arguments (@(
            $_vault.Parameters,
            $Key
        ) + $ArgumentList)
}

function Start-PodeSecretCacheHousekeeper {
    if (Test-PodeTimer -Name '__pode_secrets_cache_expiry__') {
        return
    }

    Add-PodeTimer -Name '__pode_secrets_cache_expiry__' -Interval 60 -ScriptBlock {
        $now = [datetime]::UtcNow

        foreach ($key in $PodeContext.Server.Secrets.Keys.Values) {
            if (!$key.Cache.Enabled -or ($null -eq $key.Cache.Expiry) -or ($key.Cache.Expiry -gt $now)) {
                continue
            }

            $key.Cache.Expiry = $null
            $key.Cache.Value = $null
        }
    }
}

function Start-PodeSecretVaultUnlocker {
    if (Test-PodeTimer -Name '__pode_secrets_vault_unlock__') {
        return
    }

    Add-PodeTimer -Name '__pode_secrets_vault_unlock__' -Interval 60 -ScriptBlock {
        $now = [datetime]::UtcNow

        foreach ($vault in $PodeContext.Server.Secrets.Vaults.Values) {
            if (!$vault.Unlock.Enabled -or ($null -eq $vault.Unlock.Expiry) -or ($vault.Unlock.Expiry -gt $now)) {
                continue
            }

            Unlock-PodeSecretVault -Name $vault.Name
        }
    }
}

<#
.SYNOPSIS
    Unregisters multiple secret vaults within Pode.

.DESCRIPTION
    The `Unregister-PodeSecretVaultsInternal` function iterates through the list of secret vaults
    stored in the PodeContext and unregisters each one. If an error occurs during unregistration,
    it can either throw an exception or log the error.

.PARAMETER ThrowError
    If specified, the function will throw an exception when an error occurs during unregistration.
    Otherwise, it will log the error and continue processing.

.INPUTS
    None. You cannot pipe objects to Unregister-PodeSecretVaultsInternal.

.OUTPUTS
    None. The function modifies the state of secret vaults in the PodeContext.

.EXAMPLE
    # Example usage:
    Unregister-PodeSecretVaultsInternal -ThrowError
    # All registered secret vaults are unregistered, and any errors are thrown as exceptions.

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function Unregister-PodeSecretVaultsInternal {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    param(
        [switch]
        $ThrowError
    )

    # Check if there are any secret vaults to unregister
    if (Test-PodeIsEmpty $PodeContext.Server.Secrets.Vaults) {
        return
    }

    # Iterate through each vault and attempt unregistration
    foreach ($vault in $PodeContext.Server.Secrets.Vaults.Values.Name) {
        if ([string]::IsNullOrEmpty($vault)) {
            continue
        }

        try {
            Unregister-PodeSecretVault -Name $vault
        }
        catch {
            if ($ThrowError) {
                throw
            }
            else {
                $_ | Write-PodeErrorLog
            }
        }
    }
}

function Protect-PodeSecretValueType {
    param(
        [Parameter(Mandatory = $true)]
        [object]
        $Value
    )

    if ($Value -is [System.ValueType]) {
        $Value = $Value.ToString()
    }

    if ([string]::IsNullOrEmpty($Value)) {
        $Value = [string]::Empty
    }

    if ($Value -is [ordered]) {
        $Value = [hashtable]$Value
    }

    if (!(
         ($Value -is [string]) -or
         ($Value -is [securestring]) -or
         ($Value -is [hashtable]) -or
         ($Value -is [byte[]]) -or
         ($Value -is [pscredential]) -or
         ($Value -is [System.Management.Automation.OrderedHashtable])
        )) {
        throw ($PodeLocale.invalidSecretValueTypeExceptionMessage -f $Value.GetType().Name) #"Value to set secret to is of an invalid type. Expected either String, SecureString, HashTable, Byte[], or PSCredential. But got: $($Value.GetType().Name)"
    }

    return $Value
}

function Test-PodeSecretVaultInternal {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    return ($null -ne (Get-SecretVault -Name $Name -ErrorAction Ignore))
}