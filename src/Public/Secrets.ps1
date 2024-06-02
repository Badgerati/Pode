<#
.SYNOPSIS
Register a Secret Vault.

.DESCRIPTION
Register a Secret Vault, which is defined by either custom logic or using the SecretManagement module.

.PARAMETER Name
The unique friendly Name of the Secret Vault within Pode.

.PARAMETER VaultParameters
A hashtable of extra parameters that should be supplied to either the SecretManagement module, or custom scriptblocks.

.PARAMETER UnlockSecret
An optional Secret to be used to unlock the Secret Vault if need.

.PARAMETER UnlockSecureSecret
An optional Secret, as a SecureString, to be used to unlock the Secret Vault if need.

.PARAMETER UnlockInterval
An optional number of minutes that Pode will periodically check/unlock the Secret Vault. (Default: 0)

.PARAMETER NoUnlock
If supplied, the Secret Vault will not be unlocked after registration. To unlock you'll need to call Unlock-PodeSecretVault.

.PARAMETER CacheTtl
An optional number of minutes that Secrets should be cached for. (Default: 0)

.PARAMETER InitScriptBlock
An optional scriptblock to run before the Secret Vault is registered, letting you initialise any connection, contexts, etc.

.PARAMETER VaultName
For SecretManagement module Secret Vaults, you can use thie parameter to specify the actual Vault name, and use the above Name parameter as a more friendly name if required.

.PARAMETER ModuleName
For SecretManagement module Secret Vaults, this is the name/path of the extension module to be used.

.PARAMETER ScriptBlock
For custom Secret Vaults, this is a scriptblock used to read the Secret from the Vault.

.PARAMETER UnlockScriptBlock
For custom Secret Vaults, this is an optional scriptblock used to unlock the Secret Vault.

.PARAMETER RemoveScriptBlock
For custom Secret Vaults, this is an optional scriptblock used to remove a Secret from the Vault.

.PARAMETER SetScriptBlock
For custom Secret Vaults, this is an optional scriptblock used to create/update a Secret in the Vault.

.PARAMETER UnregisterScriptBlock
For custom Secret Vaults, this is an optional scriptblock used unregister the Secret Vault with any custom clean-up logic.

.EXAMPLE
Register-PodeSecretVault -Name 'VaultName' -ModuleName 'Az.KeyVault' -VaultParameters @{ AZKVaultName = $name; SubscriptionId = $subId }

.EXAMPLE
Register-PodeSecretVault -Name 'VaultName' -VaultParameters @{ Address = 'http://127.0.0.1:8200' } -ScriptBlock { ... }
#>
function Register-PodeSecretVault {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [hashtable]
        $VaultParameters,

        [Parameter()]
        [string]
        $UnlockSecret,

        [Parameter()]
        [securestring]
        $UnlockSecureSecret,

        [Parameter()]
        [int]
        $UnlockInterval = 0,

        [switch]
        $NoUnlock,

        [Parameter()]
        [int]
        $CacheTtl = 0, # in minutes

        [Parameter()]
        [scriptblock]
        $InitScriptBlock,

        [Parameter(ParameterSetName = 'SecretManagement')]
        [string]
        $VaultName,

        [Parameter(Mandatory = $true, ParameterSetName = 'SecretManagement')]
        [Alias('Module')]
        [string]
        $ModuleName,

        [Parameter(Mandatory = $true, ParameterSetName = 'Custom')]
        [scriptblock]
        $ScriptBlock, # Read a secret

        [Parameter(ParameterSetName = 'Custom')]
        [Alias('Unlock')]
        [scriptblock]
        $UnlockScriptBlock,

        [Parameter(ParameterSetName = 'Custom')]
        [Alias('Remove')]
        [scriptblock]
        $RemoveScriptBlock,

        [Parameter(ParameterSetName = 'Custom')]
        [Alias('Set')]
        [scriptblock]
        $SetScriptBlock,

        [Parameter(ParameterSetName = 'Custom')]
        [Alias('Unregister')]
        [scriptblock]
        $UnregisterScriptBlock
    )

    # has the vault already been registered?
    if (Test-PodeSecretVault -Name $Name) {
        $autoImported = [string]::Empty
        if ($PodeContext.Server.Secrets.Vaults[$Name].AutoImported) {
            $autoImported = ' from auto-importing'
        }
        # A Secret Vault with the name {0} has already been registered{1}
        throw ($PodeLocal.secretVaultAlreadyRegisteredAutoImportExceptionMessage -f $Name, $autoImported)
    }

    # base vault config
    if (![string]::IsNullOrEmpty($UnlockSecret)) {
        $UnlockSecureSecret = $UnlockSecret | ConvertTo-SecureString -AsPlainText -Force
    }

    $vault = @{
        Name         = $Name
        Type         = $PSCmdlet.ParameterSetName.ToLowerInvariant()
        Parameters   = $VaultParameters
        AutoImported = $false
        LockableName = "__Pode_SecretVault_$($Name)__"
        Unlock       = @{
            Secret   = $UnlockSecureSecret
            Expiry   = $null
            Interval = $UnlockInterval
            Enabled  = (!(Test-PodeIsEmpty $UnlockSecureSecret))
        }
        Cache        = @{
            Ttl     = $CacheTtl
            Enabled = ($CacheTtl -gt 0)
        }
    }

    # initialise the secret vault
    if ($null -ne $InitScriptBlock) {
        $vault | Initialize-PodeSecretVault -ScriptBlock $InitScriptBlock
    }

    # set vault config depending on vault type
    switch ($vault.Type) {
        'custom' {
            $vault | Register-PodeSecretCustomVault `
                -ScriptBlock $ScriptBlock `
                -UnlockScriptBlock $UnlockScriptBlock `
                -RemoveScriptBlock $RemoveScriptBlock `
                -SetScriptBlock $SetScriptBlock `
                -UnregisterScriptBlock $UnregisterScriptBlock
        }

        'secretmanagement' {
            $vault | Register-PodeSecretManagementVault `
                -VaultName $VaultName `
                -ModuleName $ModuleName
        }
    }

    # create timer to clear cached secrets every minute
    Start-PodeSecretCacheHousekeeper

    # create a lockable so secrets are thread safe
    New-PodeLockable -Name $vault.LockableName

    # add vault config to context
    $PodeContext.Server.Secrets.Vaults[$Name] = $vault

    # unlock the vault?
    if (!$NoUnlock -and $vault.Unlock.Enabled) {
        Unlock-PodeSecretVault -Name $Name
    }
}

<#
.SYNOPSIS
Unregister a Secret Vault.

.DESCRIPTION
Unregister a Secret Vault. If the Vault was via the SecretManagement module it will also be unregistered there as well.

.PARAMETER Name
The Name of the Secret Vault in Pode to unregister.

.EXAMPLE
Unregister-PodeSecretVault -Name 'VaultName'
#>
function Unregister-PodeSecretVault {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    # has the vault been registered?
    if (!(Test-PodeSecretVault -Name $Name)) {
        return
    }

    # get vault
    $vault = $PodeContext.Server.Secrets.Vaults[$Name]

    # unlock depending on vault type, and set expiry
    switch ($vault.Type) {
        'custom' {
            $vault | Unregister-PodeSecretCustomVault
        }

        'secretmanagement' {
            $vault | Unregister-PodeSecretManagementVault
        }
    }

    # unregister from Pode
    $null = $PodeContext.Server.Secrets.Vaults.Remove($Name)
}

<#
.SYNOPSIS
Unlock the Secret Vault.

.DESCRIPTION
Unlock the Secret Vault.

.PARAMETER Name
The Name of the Secret Vault in Pode to be unlocked.

.EXAMPLE
Unlock-PodeSecretVault -Name 'VaultName'
#>
function Unlock-PodeSecretVault {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    # has the vault been registered?
    if (!(Test-PodeSecretVault -Name $Name)) {
        # No Secret Vault with the name has been registered
        throw ($PodeLocal.noSecretVaultRegisteredExceptionMessage -f $Vault)
    }

    # get vault
    $vault = $PodeContext.Server.Secrets.Vaults[$Name]
    $expiry = $null

    # is unlocking even enabled?
    if (!$vault.Unlock.Enabled) {
        return
    }

    # unlock depending on vault type, and set expiry
    $expiry = Lock-PodeObject -Name $vault.LockableName -Return -ScriptBlock {
        switch ($vault.Type) {
            'custom' {
                return ($vault | Unlock-PodeSecretCustomVault)
            }

            'secretmanagement' {
                return ($vault | Unlock-PodeSecretManagementVault)
            }
        }
    }

    # if we have an expiry returned, set to UTC and configure unlock schedule
    if ($null -ne $expiry) {
        $expiry = ([datetime]$expiry).ToUniversalTime()
        if ($expiry -le [datetime]::UtcNow) {
            # Secret Vault unlock expiry date is in the past (UTC)
            throw ($PodeLocal.secretVaultUnlockExpiryDateInPastExceptionMessage -f $expiry)
        }

        $vault.Unlock.Expiry = $expiry
        Start-PodeSecretVaultUnlocker
    }
}

<#
.SYNOPSIS
Fetches and returns information of a Secret Vault.

.DESCRIPTION
Fetches and returns information of a Secret Vault.

.PARAMETER Name
The Name(s) of a Secret Vault to retrieve.

.EXAMPLE
$vault = Get-PodeSecretVault -Name 'VaultName'

.EXAMPLE
$vaults = Get-PodeSecretVault -Name 'VaultName1', 'VaultName2'
#>
function Get-PodeSecretVault {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]
        $Name
    )

    $vaults = $PodeContext.Server.Secrets.Vaults.Values

    # further filter by vault names
    if (($null -ne $Name) -and ($Name.Length -gt 0)) {
        $vaults = @(foreach ($_name in $Name) {
                foreach ($vault in $vaults) {
                    if ($vault.Name -ine $_name) {
                        continue
                    }

                    $vault
                }
            })
    }

    # return
    return $vaults
}

<#
.SYNOPSIS
Tests if a Secret Vault has been registered.

.DESCRIPTION
Tests if a Secret Vault has been registered.

.PARAMETER Name
The Name of the Secret Vault to test.

.EXAMPLE
if (Test-PodeSecretVault -Name 'VaultName') { ... }
#>
function Test-PodeSecretVault {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    return (($null -ne $PodeContext.Server.Secrets.Vaults) -and $PodeContext.Server.Secrets.Vaults.ContainsKey($Name))
}

<#
.SYNOPSIS
Mount a Secret from a Secret Vault.

.DESCRIPTION
Mount a Secret from a Secret Vault, so it can be more easily referenced and support caching.

.PARAMETER Name
A unique friendly Name for the Secret.

.PARAMETER Vault
The friendly name of the Secret Vault this Secret can be found in.

.PARAMETER Property
An optional array of Properties to be returned if the Secret contains multiple properties.

.PARAMETER ExpandProperty
An optional Property to be expanded from the Secret and return if it contains multiple properties.

.PARAMETER Key
The Key/Path of the Secret within the Secret Vault.

.PARAMETER ArgumentList
An optional array of Arguments to be supplied to a custom Secret Vault's scriptblocks.

.PARAMETER CacheTtl
An optional number of minutes to Cache the Secret's value for. You can use this parameter to override the Secret Vault's value. (Default: -1)
If the value is -1 it uses the Secret Vault's CacheTtl. A value of 0 is to disable caching for this Secret. A value >0 overrides the Secret Vault.

.EXAMPLE
Mount-PodeSecret -Name 'SecretName' -Vault 'VaultName' -Key 'path/to/secret' -ExpandProperty 'foo'

.EXAMPLE
Mount-PodeSecret -Name 'SecretName' -Vault 'VaultName' -Key 'key_of_secret' -CacheTtl 5
#>
function Mount-PodeSecret {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true)]
        [string]
        $Vault,

        [Parameter()]
        [string[]]
        $Property,

        [Parameter()]
        [string]
        $ExpandProperty,

        [Parameter(Mandatory = $true)]
        [string]
        $Key,

        [Parameter()]
        [object[]]
        $ArgumentList,

        # in minutes (-1 means use the vault default, 0 is off, anything higher than 0 is an override)
        [Parameter()]
        [int]
        $CacheTtl = -1
    )

    # has the secret been mounted already?
    if (Test-PodeSecret -Name $Name) {
        # A Secret with the name has already been mounted
        throw ($PodeLocal.secretAlreadyMountedExceptionMessage -f $Name)
    }

    # does the vault exist?
    if (!(Test-PodeSecretVault -Name $Vault)) {
        # No Secret Vault with the name has been registered
        throw ($PodeLocal.noSecretVaultRegisteredExceptionMessage -f $Vault)
    }

    # check properties
    if (!(Test-PodeIsEmpty $Property) -and !(Test-PodeIsEmpty $ExpandProperty)) {
        throw 'You can only provide one of either Property or ExpandPropery, but not both'
    }

    # which cache value?
    if ($CacheTtl -lt 0) {
        $CacheTtl = [int]$PodeContext.Server.Secrets.Vaults[$Vault].Cache.Ttl
    }

    # mount secret reference
    $props = $Property
    if (![string]::IsNullOrWhiteSpace($ExpandProperty)) {
        $props = $ExpandProperty
    }

    $PodeContext.Server.Secrets.Keys[$Name] = @{
        Key        = $Key
        Properties = @{
            Fields  = $props
            Expand  = (![string]::IsNullOrWhiteSpace($ExpandProperty))
            Enabled = (!(Test-PodeIsEmpty $props))
        }
        Vault      = $Vault
        Arguments  = $ArgumentList
        Cache      = @{
            Ttl     = $CacheTtl
            Enabled = ($CacheTtl -gt 0)
        }
    }
}

<#
.SYNOPSIS
Dismount a previously mounted Secret.

.DESCRIPTION
Dismount a previously mounted Secret.

.PARAMETER Name
The friendly Name of the Secret.

.PARAMETER Remove
If supplied, the Secret will also be removed from the Secret Vault as well.

.EXAMPLE
Dismount-PodeSecret -Name 'SecretName'

.EXAMPLE
Dismount-PodeSecret -Name 'SecretName' -Remove
#>
function Dismount-PodeSecret {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [switch]
        $Remove
    )

    # do nothing if the secret hasn't been mounted, unless Remove is specified
    if (!(Test-PodeSecret -Name $Name)) {
        if ($Remove) {
            # No Secret named has been mounted
            throw ($PodeLocal.noSecretNamedMountedExceptionMessage -f $Name)
        }

        return
    }

    # if "remove" switch passed, remove the secret from the vault as well
    if ($Remove) {
        $secret = $PodeContext.Server.Secrets.Keys[$Name]
        Remove-PodeSecret -Key $secret.Key -Vault $secret.Vault -ArgumentList $secret.Arguments
    }

    # remove reference
    $null = $PodeContext.Server.Secrets.Keys.Remove($Name)
}

<#
.SYNOPSIS
Retrieve the value of a mounted Secret.

.DESCRIPTION
Retrieve the value of a mounted Secret from a Secret Vault. You can also use "$value = $secret:<NAME>" syntax in certain places.

.PARAMETER Name
The friendly Name of a Secret.

.EXAMPLE
$value = Get-PodeSecret -Name 'SecretName'

.EXAMPLE
$value = $secret:SecretName
#>
function Get-PodeSecret {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    # has the secret been mounted?
    if (!(Test-PodeSecret -Name $Name)) {
        # No Secret named has been mounted
        throw ($PodeLocal.noSecretNamedMountedExceptionMessage -f $Name)
    }

    # get the secret and vault
    $secret = $PodeContext.Server.Secrets.Keys[$Name]

    # is the value cached?
    if ($secret.Cache.Enabled -and ($null -ne $secret.Cache.Expiry) -and ($secret.Cache.Expiry -gt [datetime]::UtcNow)) {
        return $secret.Cache.Value
    }

    # fetch the secret depending on vault type
    $vault = $PodeContext.Server.Secrets.Vaults[$secret.Vault]
    $value = Lock-PodeObject -Name $vault.LockableName -Return -ScriptBlock {
        switch ($vault.Type) {
            'custom' {
                return Get-PodeSecretCustomKey -Vault $secret.Vault -Key $secret.Key -ArgumentList $secret.Arguments
            }

            'secretmanagement' {
                return Get-PodeSecretManagementKey -Vault $secret.Vault -Key $secret.Key
            }
        }
    }

    # filter the value by any properties
    if ($secret.Properties.Enabled) {
        if ($secret.Properties.Expand) {
            $value = Select-Object -InputObject $value -ExpandProperty $secret.Properties.Fields
        }
        else {
            $value = Select-Object -InputObject $value -Property $secret.Properties.Fields
        }
    }

    # cache the value if needed
    if ($secret.Cache.Enabled) {
        $secret.Cache.Value = $value
        $secret.Cache.Expiry = [datetime]::UtcNow.AddMinutes($secret.Cache.Ttl)
    }

    # return value
    return $value
}

<#
.SYNOPSIS
Test if a Secret has been mounted.

.DESCRIPTION
Test if a Secret has been mounted.

.PARAMETER Name
The friendly Name of a Secret.

.EXAMPLE
if (Test-PodeSecret -Name 'SecretName') { ... }
#>
function Test-PodeSecret {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    return (($null -ne $PodeContext.Server.Secrets.Keys) -and $PodeContext.Server.Secrets.Keys.ContainsKey($Name))
}

<#
.SYNOPSIS
Update the value of a mounted Secret.

.DESCRIPTION
Update the value of a mounted Secret in a Secret Vault. You can also use "$secret:<NAME> = $value" syntax in certain places.

.PARAMETER Name
The friendly Name of a Secret.

.PARAMETER InputObject
The value to use when updating the Secret.
Only the following object types are supported: byte[], string, securestring, pscredential, hashtable.

.PARAMETER Metadata
An optional Metadata hashtable.

.EXAMPLE
Update-PodeSecret -Name 'SecretName' -InputObject @{ key = value }

.EXAMPLE
Update-PodeSecret -Name 'SecretName' -InputObject 'value'

.EXAMPLE
$secret:SecretName = 'value'
#>
function Update-PodeSecret {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        #> byte[], string, securestring, pscredential, hashtable
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [object]
        $InputObject,

        [Parameter()]
        [hashtable]
        $Metadata
    )

    # has the secret been mounted?
    if (!(Test-PodeSecret -Name $Name)) {
        # No Secret named has been mounted
        throw ($PodeLocal.noSecretNamedMountedExceptionMessage -f $Name)
    }

    # make sure the value type is correct
    $InputObject = Protect-PodeSecretValueType -Value $InputObject

    # get the secret and vault
    $secret = $PodeContext.Server.Secrets.Keys[$Name]

    # reset the cache if enabled
    if ($secret.Cache.Enabled) {
        $secret.Cache.Value = $InputObject
        $secret.Cache.Expiry = [datetime]::UtcNow.AddMinutes($secret.Cache.Ttl)
    }

    # if we're expanding a property, convert this to a hashtable
    if ($secret.Properties.Enabled -and $secret.Properties.Expand) {
        $InputObject = @{
            "$($secret.Properties.Fields)" = $InputObject
        }
    }

    # set the secret depending on vault type
    $vault = $PodeContext.Server.Secrets.Vaults[$secret.Vault]
    Lock-PodeObject -Name $vault.LockableName -ScriptBlock {
        switch ($vault.Type) {
            'custom' {
                Set-PodeSecretCustomKey -Vault $secret.Vault -Key $secret.Key -Value $InputObject -Metadata $Metadata -ArgumentList $secret.Arguments
            }

            'secretmanagement' {
                Set-PodeSecretManagementKey -Vault $secret.Vault -Key $secret.Key -Value $InputObject -Metadata $Metadata
            }
        }
    }
}

<#
.SYNOPSIS
Remove a Secret from a Secret Vault.

.DESCRIPTION
Remove a Secret from a Secret Vault. To remove a mounted Secret, you can pass the Remove switch to Dismount-PodeSecret.

.PARAMETER Key
The Key/Path of the Secret within the Secret Vault.

.PARAMETER Vault
The friendly name of the Secret Vault this Secret can be found in.

.PARAMETER ArgumentList
An optional array of Arguments to be supplied to a custom Secret Vault's scriptblocks.

.EXAMPLE
Remove-PodeSecret -Key 'path/to/secret' -Vault 'VaultName'
#>
function Remove-PodeSecret {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Key,

        [Parameter(Mandatory = $true)]
        [string]
        $Vault,

        [Parameter()]
        [object[]]
        $ArgumentList
    )

    # has the vault been registered?
    if (!(Test-PodeSecretVault -Name $Vault)) {
        throw "No Secret Vault with the name '$($Vault)' has been registered"
    }

    # remove the secret depending on vault type
    $_vault = $PodeContext.Server.Secrets.Vaults[$Vault]
    Lock-PodeObject -Name $_vault.LockableName -ScriptBlock {
        switch ($_vault.Type) {
            'custom' {
                Remove-PodeSecretCustomKey -Vault $Vault -Key $Key -ArgumentList $ArgumentList
            }

            'secretmanagement' {
                Remove-PodeSecretManagementKey -Vault $Vault -Key $Key
            }
        }
    }
}

<#
.SYNOPSIS
Read a Secret from a Secret Vault.

.DESCRIPTION
Read a Secret from a Secret Vault.

.PARAMETER Key
The Key/Path of the Secret within the Secret Vault.

.PARAMETER Vault
The friendly name of the Secret Vault this Secret can be found in.

.PARAMETER Property
An optional array of Properties to be returned if the Secret contains multiple properties.

.PARAMETER ExpandProperty
An optional Property to be expanded from the Secret and return if it contains multiple properties.

.PARAMETER ArgumentList
An optional array of Arguments to be supplied to a custom Secret Vault's scriptblocks.

.EXAMPLE
$value = Read-PodeSecret -Key 'path/to/secret' -Vault 'VaultName'

.EXAMPLE
$value = Read-PodeSecret -Key 'key_of_secret' -Vault 'VaultName' -Property prop1, prop2
#>
function Read-PodeSecret {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Key,

        [Parameter(Mandatory = $true)]
        [string]
        $Vault,

        [Parameter()]
        [string[]]
        $Property,

        [Parameter()]
        [string]
        $ExpandProperty,

        [Parameter()]
        [object[]]
        $ArgumentList
    )

    # has the vault been registered?
    if (!(Test-PodeSecretVault -Name $Vault)) {
        throw "No Secret Vault with the name '$($Vault)' has been registered"
    }

    # fetch the secret depending on vault type
    $_vault = $PodeContext.Server.Secrets.Vaults[$Vault]
    $value = Lock-PodeObject -Name $_vault.LockableName -Return -ScriptBlock {
        switch ($_vault.Type) {
            'custom' {
                return Get-PodeSecretCustomKey -Vault $Vault -Key $Key -ArgumentList $ArgumentList
            }

            'secretmanagement' {
                return Get-PodeSecretManagementKey -Vault $Vault -Key $Key
            }
        }
    }

    # filter the value by any properties
    if (![string]::IsNullOrWhiteSpace($ExpandProperty)) {
        $value = Select-Object -InputObject $value -ExpandProperty $ExpandProperty
    }
    elseif (![string]::IsNullOrEmpty($Property)) {
        $value = Select-Object -InputObject $value -Property $Property
    }

    # return value
    return $value
}

<#
.SYNOPSIS
Create/update a Secret in a Secret Vault.

.DESCRIPTION
Create/update a Secret in a Secret Vault.

.PARAMETER Key
The Key/Path of the Secret within the Secret Vault.

.PARAMETER Vault
The friendly name of the Secret Vault this Secret should be created in.

.PARAMETER InputObject
The value to use when updating the Secret.
Only the following object types are supported: byte[], string, securestring, pscredential, hashtable.

.PARAMETER Metadata
An optional Metadata hashtable.

.PARAMETER ArgumentList
An optional array of Arguments to be supplied to a custom Secret Vault's scriptblocks.

.EXAMPLE
Set-PodeSecret -Key 'path/to/secret' -Vault 'VaultName' -InputObject 'value'

.EXAMPLE
Set-PodeSecret -Key 'key_of_secret' -Vault 'VaultName' -InputObject @{ key = value }
#>
function Set-PodeSecret {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Key,

        [Parameter(Mandatory = $true)]
        [string]
        $Vault,

        #> byte[], string, securestring, pscredential, hashtable
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [object]
        $InputObject,

        [Parameter()]
        [hashtable]
        $Metadata,

        [Parameter()]
        [object[]]
        $ArgumentList
    )

    # has the vault been registered?
    if (!(Test-PodeSecretVault -Name $Vault)) {
        throw "No Secret Vault with the name '$($Vault)' has been registered"
    }

    # make sure the value type is correct
    $InputObject = Protect-PodeSecretValueType -Value $InputObject

    # set the secret depending on vault type
    $_vault = $PodeContext.Server.Secrets.Vaults[$Vault]
    Lock-PodeObject -Name $_vault.LockableName -ScriptBlock {
        switch ($_vault.Type) {
            'custom' {
                Set-PodeSecretCustomKey -Vault $Vault -Key $Key -Value $InputObject -Metadata $Metadata -ArgumentList $ArgumentList
            }

            'secretmanagement' {
                Set-PodeSecretManagementKey -Vault $Vault -Key $Key -Value $InputObject -Metadata $Metadata
            }
        }
    }
}