# SecretStore

This page gives some brief details, and an example, of how to use the `Microsoft.PowerShell.SecretStore` PowerShell module secret vault provider.

This is a locally stored secret vault.

## Install

Before using the `Microsoft.PowerShell.SecretStore` provider, you will first need to install the module:

```powershell
Install-Module Microsoft.PowerShell.SecretManagement, Microsoft.PowerShell.SecretStore
```

## Register

When registering a new secret vault using `Microsoft.PowerShell.SecretStore`, via [`Register-PodeSecretVault`](../../../../Functions/Secrets/Register-PodeSecretVault), the `-UnlockSecret` parameter is **mandatory**. This will be used to assign the required default password for the secret vault and to periodically unlock the vault.

There are also some default values set for some parameters to make life a little easier, however, these can be overwritten if needed by directly supplying the parameter:

| Parameter                            | Default    | Description                                                                                                                      |
| ------------------------------------ | ---------- | -------------------------------------------------------------------------------------------------------------------------------- |
| `UnlockInterval`                     | 1 minute   | Used to assign an unlock period, as well as the PasswordTimeout to auto-lock the vault                                           |
| `VaultParameters['Authentication']`  | Password   | Used to tell the vault to to be locked/unlocked                                                                                  |
| `VaultParameters['Interaction']`     | None       | Used to tell the vault where it should be interactive or not                                                                     |
| `VaultParameters['PasswordTimeout']` | 70 seconds | Used to auto-lock the vault after being unlocked. The value if not supplied is based on the `-UnlockInterval` value + 10 seconds |

For example:

```powershell
Register-PodeSecretVault `
    -Name 'ExampleVault' `
    -ModuleName 'Microsoft.PowerShell.SecretStore' `
    -UnlockSecret 'Sup3rSecur3Pa$$word!'
```

## Secret Management

Creating, updating, and using secrets are all done in the usual manner, as outlined in the [Overview](../../Overview):

```powershell
# set a secret in the local vault
Set-PodeSecret -Key 'example' -Vault 'ExampleVault' -InputObject 'hello, world!'

# mount the "example" secret from local vault, making it accessible via $secret:example
Mount-PodeSecret -Name 'example' -Vault 'ExampleVault' -Key 'example'

# use the secret in a route
Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
    Write-PodeJsonResponse @{ Value = $secret:example }
}
```

## Example

The following is a smaller example of the example [found here](https://github.com/Badgerati/Pode/blob/develop/examples/web-secrets-local.ps1) and shows how to set up a server to register a local SecretStore vault, manage a secret within that vault, and return it via a Route.

```powershell
Start-PodeServer -Threads 2 {
    Add-PodeEndpoint -Address * -Port 8080 -Protocol Http

    # register the vault
    Register-PodeSecretVault `
        -Name 'ExampleVault' `
        -ModuleName 'Microsoft.PowerShell.SecretStore' `
        -UnlockSecret 'Sup3rSecur3Pa$$word!'

    # set a secret in the local vault
    Set-PodeSecret -Key 'example' -Vault 'ExampleVault' -InputObject 'hello, world!'

    # mount the "example" secret from local vault, making it accessible via $secret:example
    Mount-PodeSecret -Name 'example' -Vault 'ExampleVault' -Key 'example'

    # retrieve the secret in a route
    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        Write-PodeJsonResponse @{ Value = $secret:example }
    }

    # update the secret in a route
    Add-PodeRoute -Method Post -Path '/' -ScriptBlock {
        $secret:example = $WebEvent.Data.Value
    }
}
```
