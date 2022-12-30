# Secret Management

Pode can register secret vaults using Microsoft's [SecretManagement](https://github.com/powershell/secretmanagement) PowerShell module, plus extensions.

!!! note
    An overview of general features can be [found here](../../Overview).

## Register

When registering a secret vault via [`Register-PodeSecretVault`](../../../../Functions/Secrets/Register-PodeSecretVault) using the SecretManagement module, besides a `-Name` and `-VaultParameters` the only other mandatory parameter is `-ModuleName`; this is the name of the extension module to use with the SecretManagement module. Besides calling the SecretManagement's `Register-SecretVault`, Pode will also automatically import the SecretManagement and extension modules into Pode's runspaces for you.

For example, if we were registering an Azure KeyVault this would be `Az.KeyVault`:

```powershell
Register-PodeSecretVault -Name 'FriendlyVaultName' -ModuleName 'Az.KeyVault' -VaultParameters @{
    AZKVaultName = 'VaultNameInAzure'
    SubscriptionId = $SubscriptionId
}
```

The only other SecretManagement specific parameter is `-VaultName`. This parameter can be used to give the actual name of the vault, while keeping the `-Name` parameter as a better more friendlier name. If no `-VaultName` is supplied then `-Name` is used instead. Using the same example as above, but this time we specify a specific vault name to pass to `Register-SecretVault`:

```powershell
Register-PodeSecretVault -Name 'FriendlyVaultName' -VaultName 'VaultNameInAzure' -ModuleName 'Az.KeyVault' -VaultParameters @{
    AZKVaultName = 'VaultNameInAzure'
    SubscriptionId = $SubscriptionId
}
```

If you use [`Unregister-PodeSecretVault`](../../../../Functions/Secrets/Unregister-PodeSecretVault), then Pode will also call the SecretManagement's `Unregister-SecretVault`.

## Auto-Import

More information can be [found here](../../../Scoping), but if the SecretManagement module is installed then Pode will automatically import/register any secret vaults already registered.

Any secret vaults registered this way will no be automatically unregistered when the server stops.

## Example

The following example registered an Azure KeyVault, mounts a secret from the vault into Pode, and then adds two Routes - one to retrieve the value, and another one to update the value:

```powershell
param(
    [Parameter(Mandatory=$true)]
    [string]
    $VaultName,

    [Parameter(Mandatory=$true)]
    [string]
    $SubscriptionId
)

Start-PodeServer {
    Add-PodeEndpoint -Address * -Port 8080 -Protocol Http

    # secret manage azure keyvault - need to run "Connect-AzAccount" first!
    Register-PodeSecretVault -Name 'FriendlyVaultName' -ModuleName 'Az.KeyVault' -VaultParameters @{
        AZKVaultName = $VaultName
        SubscriptionId = $SubscriptionId
    }

    # mount a secret from az keyvault
    Mount-PodeSecret -Name 'SecretName' -Vault 'FriendlyVaultName' -Key 'AKVSecretName'


    # routes to get/update secret in az keyvault
    Add-PodeRoute -Method Get -Path '/secret' -ScriptBlock {
        Write-PodeJsonResponse @{ Value = $secret:SecretName }
    }

    Add-PodeRoute -Method Post -Path '/secret' -ScriptBlock {
        $secret:SecretName = $WebEvent.Data.Value
    }
}
```

To retrieve the value:
```powershell
Invoke-RestMethod -Uri 'http://localhost:8080/secret'
```

And to update the value:
```powershell
Invoke-RestMethod -Uri 'http://localhost:8080/secret' -Method Post -Body @{
    Value = '<new_value>'
}
```
