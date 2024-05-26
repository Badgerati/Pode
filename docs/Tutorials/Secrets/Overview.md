# Overview

You can register and mount secret values from secret vaults, like Azure KeyVault or HashiCorp Vault, into Pode for use in Routes, Middleware, etc.

Secrets can also be referenced from a vault in an adhoc manner, without needing to mount them first. You can also create, update, and remove secrets in vaults.

The values of mounted secrets may also be cached for a period of time, to reduce load on the vault as well as speed up lookups.

## Registering

To reference Secrets from a vault you first need to register that vault using [`Register-PodeSecretVault`](../../../Functions/Secrets/Register-PodeSecretVault). Registering a vault registers the vault within Pode, but will also call any logic needed by the registration type being used. For example, if using Secret Management then Pode will call `Register-SecretVault` for you.

A further example, as follows, will use the Secret Management PowerShell module to register an Azure KeyVault within Pode:

```powershell
Register-PodeSecretVault -Name 'FriendlyVaultName' -ModuleName 'Az.KeyVault' -VaultParameters @{
    AZKVaultName = 'VaultNameInAzure'
    SubscriptionId = $SubscriptionId
}
```

You can find more information on the [Secret Management](../Types/SecretManagement) page. The general parameters for all types are:

| Parameter       | Description                                                                      |
| --------------- | -------------------------------------------------------------------------------- |
| Name            | This is a friendly name for the vault within Pode that you can reference         |
| VaultParameters | This is a hashtable of options, for the vault, that is supplied to vault scripts |

!!! note
    You can unregister a vault via [`Unregister-PodeSecretVault`](../../../Functions/Secrets/Unregister-PodeSecretVault). All vaults are automatically unregistered when the server stops - unless it was auto-imported.

### Types

At present, there are just two registration types implemented for registering secret vaults:

* [Secret Management](../Types/SecretManagement) (PowerShell module)
* [Custom](../Types/Custom)

!!! tip
    For the SecretManagement module you can read a "getting started" [guide here](https://learn.microsoft.com/en-us/powershell/utility-modules/secretmanagement/how-to/using-secrets-in-automation?view=ps-modules) when using the module in automated scenarios.

### Vault Examples

You can find some quick examples for some vault providers below:

* [SecretStore](../Examples/SecretStore)


### Initialise

If there is any logic that needs to be invoked before a vault is registered, such as connecting to a cloud provider first (ie: `Connect-AzAccount`), this can be achieved via the `-InitScriptBlock` parameter on [`Register-PodeSecretVault`](../../../Functions/Secrets/Register-PodeSecretVault).

This scriptblock is run just before Pode invokes any registration logic, and applies to all registration types. The scriptblock is supplied the `-VaultParameters` hashtable as a parameter:

```powershell
Register-PodeSecretVault -Name 'VaultName' -ModuleName 'Az.KeyVault' `
    -VaultParameters @{
        AZKVaultName = 'VaultNameInAzure'
        SubscriptionId = $SubscriptionId
    } `
    -InitScriptBlock {
        param($config)
        Connect-AzAccount -Subscription $config.SubscriptionId
    }
```

### Auto-Import

Similar to modules and functions, Pode will auto-import any secret vaults registered outside of Pode. You can find more [information here](../../Scoping#secret-vaults)

### Unlock

Some vaults require unlocking first, or an authorization token to be acquired to access the vault. Unlocking applies to all registration types, and to configure unlocking for use you'll first need to supply either an `-UnlockSecret` or an `-UnlockSecureSecret` to [`Register-PodeSecretVault`](../../../Functions/Secrets/Register-PodeSecretVault).

!!! important
    If you're using a custom registration type, you'll also need to supply an `-UnlockScriptBlock`.

```powershell
Register-PodeSecretVault -Name 'VaultName' -ModuleName 'Az.KeyVault' -UnlockSecret 'some-vault-password' `
    -VaultParameters @{
        AZKVaultName = 'VaultNameInAzure'
        SubscriptionId = $SubscriptionId
    } `
    -UnlockScriptBlock {
        param($config, $secret)
        Unlock-SomeVault -Secret $secret
    }
```

Pode will automatically call the unlock logic after registration, but you can stop this from occurring by passing `-NoUnlock`. If you do, you'll need to call [`Unlock-PodeSecretVault`](../../../Functions/Secrets/Unlock-PodeSecretVault) to unlock the vault:

```powershell
Unlock-PodeSecretVault -Name 'VaultName'
```

If you need to periodically check/unlock your vault, then Pode can do this automatically for you. To achieve this you can supply a number of minutes for the `-UnlockInterval` parameter on [`Register-PodeSecretVault`](../../../Functions/Secrets/Register-PodeSecretVault), this will tell Pode to automatically check/unlock the vault after the first unlock has occurred.

## Mounting

After registering a secret vault, you can now mount secrets from that vault for use within Pode Routes, Middleware, etc. The logic for mounting a secret is the same regardless of vault type or registration type. A secret can be mounted via [`Mount-PodeSecret`](../../../Functions/Secrets/Mount-PodeSecret):

```powershell
Mount-PodeSecret -Name 'SecretName' -Vault 'VaultName' -Key 'SecretKeyNameInVault'
```

The `-Name` is the name of the secret you'll be using to reference the secret throughout Pode. The `-Vault` parameter is the name of the vault from [`Register-PodeSecretVault`](../../../Functions/Secrets/Register-PodeSecretVault), and the `-Key` is the path/name of the secret within the vault itself.

Some secrets will be returned as hashtables - such as from HashiCorp Vault. In some cases, you might only want certain properties to be returned from this secret, and you can limit the properties returned by using the `-Property` parameter. For example, if a secret has 5 keys named key1 to key5, you can limit this to just key2 and key4:

```powershell
Mount-PodeSecret -Name 'SecretName' -Vault 'VaultName' -Key 'SecretKeyNameInVault' -Property key2, key4
```

Or, you can limit the result to a single property, and expand on it - so now you get a string returned and not a hashtable:

```powershell
Mount-PodeSecret -Name 'SecretName' -Vault 'VaultName' -Key 'SecretKeyNameInVault' -ExpandProperty key3
```

!!! note
    When using `-ExpandProperty` and you want to update the value, just pass a raw string (or whatever the inner type is). Pode will automatically wrap the original property key back for you.

!!! note
    You can dismount a mounted secret via [`Dismount-PodeSecret`](../../../Functions/Secrets/Dismount-PodeSecret). If you also supply the `-Remove` switch the secret will be deleted within the vault as well.

### Secret Scope

To retrieve the values of mounted secrets you can use [`Get-PodeSecret`](../../../Functions/Secrets/Get-PodeSecret), and then to update the value of the secret you can use [`Update-PodeSecret`](../../../Functions/Secrets/Update-PodeSecret):

```powershell
# get secret
Add-PodeRoute -Method Get -Path '/secret' -ScriptBlock {
    Write-PodeJsonResponse @{ Value = (Get-PodeSecret -Name 'SecretName') }
}

# update secret
Add-PodeRoute -Method Post -Path '/secret' -ScriptBlock {
    $WebEvent.Data.Value | Update-PodeSecret -Name 'SecretName'
}
```

Or, you can do the same but using the `$secret:` scope:

```powershell
# get secret
Add-PodeRoute -Method Get -Path '/secret' -ScriptBlock {
    Write-PodeJsonResponse @{ Value = $secret:SecretName }
}

# update secret
Add-PodeRoute -Method Post -Path '/secret' -ScriptBlock {
    $secret:SecretName = $WebEvent.Data.Value
}
```

### Caching

!!! important
    The cache is an in-memory in-application cache, and is unencrypted. It is never stored on disk, and cached values are wiped once their expiry is up; the cache is also wiped when the server is stopped.

To reduce round-trip time by constantly going to a vault, as well as to reduce stress on a vault, you can optionally enable caching on secrets - the cache by default is disabled.

You can either supply a `-CacheTtl` as a number of minutes to [`Register-PodeSecretVault`](../../../Functions/Secrets/Register-PodeSecretVault) and all secrets mounted will be cached. Or you can supply a `-CacheTtl` only to specific mounted secrets - you can also use this option to disable caching for a secret, by supplying a value of 0, even if the vault itself is registered with a cache TTL.

To enable caching for all mounted secrets from a vault - but with one disabled, and one overriding:

```powershell
# register a vault with a secret cache TTL of 5 minutes
Register-PodeSecretVault -Name 'FriendlyVaultName' -ModuleName 'Az.KeyVault' -CacheTtl 5 -VaultParameters @{
    AZKVaultName = 'VaultNameInAzure'
    SubscriptionId = $SubscriptionId
}

# mount a secret, that will use the vault cache of 5mins
Mount-PodeSecret -Name 'SecretName1' -Vault 'VaultName' -Key 'SecretKeyNameInVault1'

# mount a secret, that will use a custom cache TTL of 10mins
Mount-PodeSecret -Name 'SecretName2' -Vault 'VaultName' -Key 'SecretKeyNameInVault2' -CacheTtl 10

# mount a secret, that uses no caching
Mount-PodeSecret -Name 'SecretName3' -Vault 'VaultName' -Key 'SecretKeyNameInVault3' -CacheTtl 0
```

And then to enable caching for just specific mounted secrets:

```powershell
# register a vault with no secret cache
Register-PodeSecretVault -Name 'FriendlyVaultName' -ModuleName 'Az.KeyVault' -VaultParameters @{
    AZKVaultName = 'VaultNameInAzure'
    SubscriptionId = $SubscriptionId
}

# mount a secret, that won't be cached
Mount-PodeSecret -Name 'SecretName1' -Vault 'VaultName' -Key 'SecretKeyNameInVault1'

# mount a secret, that will use a custom cache TTL of 10mins
Mount-PodeSecret -Name 'SecretName2' -Vault 'VaultName' -Key 'SecretKeyNameInVault2' -CacheTtl 10
```

## Adhoc

There is also support for creating/updating, retrieving, and removing secrets in an adhoc manner from registered vaults - without having to mount them.

### Create

To create a new secret, as well as update an existing value, you can use [`Set-PodeSecret`](../../../Functions/Secrets/Set-PodeSecret):

```powershell
Add-PodeRoute -Method Post -Path '/adhoc/:key' -ScriptBlock {
    Set-PodeSecret -Key $WebEvent.Parameters['key'] -Vault 'VaultName' -InputObject $WebEvent.Data['value']

    # if you needed to, afterwards, you could mount the secret as well
    Mount-PodeSecret -Name $WebEvent.Data['name'] -Vault 'VaultName' -Key $WebEvent.Parameters['key']
}
```

### Read

To retrieve the secret's value you can use [`Read-PodeSecret`](../../../Functions/Secrets/Read-PodeSecret):

```powershell
Add-PodeRoute -Method Get -Path '/adhoc/:key' -ScriptBlock {
    $value = Read-PodeSecret -Key $WebEvent.Parameters['key'] -Vault 'VaultName'
    Write-PodeJsonResponse @{ Value = $value }
}
```

### Remove

To remove the secret from the vault you can use [`Remove-PodeSecret`](../../../Functions/Secrets/Remove-PodeSecret):

```powershell
Add-PodeRoute -Method Delete -Path '/adhoc/:key' -ScriptBlock {
    # if the secret wasn't mounted, you can just call Remove-PodeSecret directly
    Remove-PodeSecret -Key $WebEvent.Parameters['key'] -Vault 'VaultName'

    # if the secret was mounted, you can dismount and remove from the vault via
    Dismount-PodeSecret -Name $WebEvent.Parameters['key'] -Remove
}
```
