# Custom

You can register custom secret vault logic in Pode, which lets you use vaults that either [SecretManagement](../SecretManagement) doesn't have extensions for, or that you want to have extra logic around.

!!! note
    An overview of general features can be [found here](../../Overview).

## Register

When registering a secret vault via [`Register-PodeSecretVault`](../../../../Functions/Secrets/Register-PodeSecretVault) using custom logic, besides a `-Name` and `-VaultParameters` the only other mandatory parameter is `-ScriptBlock`; this is the main scriptblock that will be used for retrieving secrets from the vault.

For example, this following registers a custom vault for HashiCorp Vault and uses the `vault` CLI to retrieve a secret. When the `-ScriptBlock` is invoked, it is passed the `-VaultParameters` and the key/path to the secret within the vault:

```powershell
# register a custom vault for HashiCorp Vault
Register-PodeSecretVault -Name 'HcpVault' `
    -VaultParameters @{
        Address = 'http://127.0.0.1:8200'
    } `
    -ScriptBlock {
        param($config, $key)
        return (vault kv get -format json -address $config.Address -mount secret $key | ConvertFrom-Json -AsHashtable).data.data
    }

# mount a secret using the above vault, and retrieve the "secret/data/tools/github"
Mount-PodeSecret -Name 'Github' -Vault 'HcpVault' -Key 'tools/github'

# reference this secret in a route to "release" something
Add-PodeRoute -Method Post -Path '/release' -ScriptBlock {
    Publish-Release -ApiToken $secret:Github.api_token
}
```

When registering a custom vault, you will also need to supply additional optional scriptblocks to enable other secret functionality:

* `-SetScriptBlock`
* `-RemoveScriptBlock`
* `-UnlockScriptBlock`
* `-UnregisterScriptBlock`

If you attempt to use the functionality without supplying a scriptblock for it, errors will be thrown.

### Set/Update

In order to be able to update and set/create secrets, you will need to supply a `-SetScriptBlock` parameter on [`Register-PodeSecretVault`](../../../../Functions/Secrets/Register-PodeSecretVault). Without this, the following will fail:

* `$secret:<NAME> = <VALUE>`
* [`Update-PodeSecret`](../../../../Functions/Secrets/Update-PodeSecret)
* [`Set-PodeSecret`](../../../../Functions/Secrets/Set-PodeSecret)

The `-SetScriptBlock` scriptblock, when invoked, will be passed the `-VaultParameters`; the key/path to the secret within in the vault; and the value to update/create the secret with.

Using the base HashiCorp Vault example from the top of the page, this can be extended to update secrets as follows:

```powershell
Register-PodeSecretVault -Name 'HcpVault' `
    -VaultParameters @{
        Address = 'http://127.0.0.1:8200'
    } `
    -ScriptBlock {
        param($config, $key)
        return (vault kv get -format json -address $config.Address -mount secret $key | ConvertFrom-Json -AsHashtable).data.data
    } `
    -SetScriptBlock {
        param($config, $key, $value)
        vault kv put -address $config.Address -mount secret $key "$($value.Keys[0])=$($value.Values[0])"
    }

# mount a secret using the above vault, and retrieve the "secret/data/tools/github"
Mount-PodeSecret -Name 'Github' -Vault 'HcpVault' -Key 'tools/github'

# reference this secret in a route to update the api token
Add-PodeRoute -Method Put -Path '/api-token' -ScriptBlock {
    $secret:Github = @{
        api_token = $WebEvent.Data.ApiToken
    }
}
```

### Remove

In order to be able to remove secrets, you will need to supply a `-RemoveScriptBlock` parameter on [`Register-PodeSecretVault`](../../../../Functions/Secrets/Register-PodeSecretVault). Without this, the following will fail:

* [`Remove-PodeSecret`](../../../../Functions/Secrets/Remove-PodeSecret)

The `-RemoveScriptBlock` scriptblock, when invoked, will be passed the `-VaultParameters` and the key/path to the secret within in the vault.

Using the base HashiCorp Vault example from the top of the page, this can be extended to remove secrets as follows:

```powershell
Register-PodeSecretVault -Name 'HcpVault' `
    -VaultParameters @{
        Address = 'http://127.0.0.1:8200'
    } `
    -ScriptBlock {
        param($config, $key)
        return (vault kv get -format json -address $config.Address -mount secret $key | ConvertFrom-Json -AsHashtable).data.data
    } `
    -RemoveScriptBlock {
        param($config, $key)
        vault kv destroy -address $config.Address -versions 1 -mount secret $key
    }

# mount a secret using the above vault, and retrieve the "secret/data/tools/github"
Mount-PodeSecret -Name 'Github' -Vault 'HcpVault' -Key 'tools/github'

# reference this secret in a route to delete it
Add-PodeRoute -Method Delete -Path '/api-token' -ScriptBlock {
    Dismount-PodeSecret -Name 'Github' -Remove
}
```

### Unlock

In order to be able to unlock the vault, you will need to supply an `-UnlockScriptBlock` parameter on [`Register-PodeSecretVault`](../../../../Functions/Secrets/Register-PodeSecretVault). Without this, the following will fail:

* Unlocking the vault with [`Register-PodeSecretVault`](../../../../Functions/Secrets/Register-PodeSecretVault)
* [`Unlock-PodeSecretVault`](../../../../Functions/Secrets/Unlock-PodeSecretVault)

The `-UnlockScriptBlock` scriptblock, when invoked, will be passed the `-VaultParameters` and the unlock secret supplied to [`Register-PodeSecretVault`](../../../../Functions/Secrets/Register-PodeSecretVault).

Using the base HashiCorp Vault example from the top of the page, this can be extended to unlock the vault:

```powershell
Register-PodeSecretVault -Name 'HcpVault' `
    -VaultParameters @{
        Address = 'http://127.0.0.1:8200'
    } `
    -ScriptBlock {
        param($config, $key)
        return (vault kv get -format json -address $config.Address -mount secret $key | ConvertFrom-Json -AsHashtable).data.data
    } `
    -UnlockSecret 'some-secret-vault' -UnlockScriptBlock {
        param($config, $secret)
        vault operator unseal -address $config.Address $secret
    }
```

!!! tip
    You can return a DateTime object from the `-UnlockScriptBlock` to specify a custom time for Pode to re-invoke the scriptblock again - rather than using the `-UnlockInterval` parameter. If no DateTime is returned, then `-UnlockInterval` will be used by default if it has been supplied.

### Unregister

You can still call [`Unregister-PodeSecretVault`](../../../../Functions/Secrets/Unregister-PodeSecretVault) for a custom vault without supplying an `-UnregisterScriptBlock`, but nothing will occur - other than the vault being removed from within Pode.

If you do supply an `-UnregisterScriptBlock`, then this will be called just before the vault is removed from within Pode. The scriptblock, when invoked, will be just supplied the `-VaultParameters`.

Using the base HashiCorp Vault example from the top of the page, this can be extended to run some custom logic when the vault is unregistered - in this case, as an example only(!), the vault will be locked:

```powershell
Register-PodeSecretVault -Name 'HcpVault' `
    -VaultParameters @{
        Address = 'http://127.0.0.1:8200'
    } `
    -ScriptBlock {
        param($config, $key)
        return (vault kv get -format json -address $config.Address -mount secret $key | ConvertFrom-Json -AsHashtable).data.data
    } `
    -UnregisterScriptBlock {
        param($config)
        vault operator seal -address $config.Address
    }
```

## Example

The following example is an aggregated example of everything mentioned above put together. It will register a custom vault for HashiCorp Vault, with Set, Remove, Unlock and Unregister support.

```powershell
Start-PodeServer {
    # listen on localhost:8080
    Add-PodeEndpoint -Address * -Port 8080 -Protocol Http

    # register a custom vault for HashiCorp Vault
    Register-PodeSecretVault -Name 'HcpVault' `
        -VaultParameters @{
            Address = 'http://127.0.0.1:8200'
        } `
        -ScriptBlock {
            param($config, $key)
            return (vault kv get -format json -address $config.Address -mount secret $key | ConvertFrom-Json -AsHashtable).data.data
        } `
        -SetScriptBlock {
            param($config, $key, $value)
            vault kv put -address $config.Address -mount secret $key "$($value.Keys[0])=$($value.Values[0])"
        } `
        -RemoveScriptBlock {
            param($config, $key)
            vault kv destroy -address $config.Address -versions 1 -mount secret $key
        } `
        -UnlockSecret 'some-secret-vault' -UnlockScriptBlock {
            param($config, $secret)
            vault operator unseal -address $config.Address $secret
        } `
        -UnregisterScriptBlock {
            param($config)
            vault operator seal -address $config.Address
        }

    # mount a secret using the above vault, and retrieve the "secret/data/tools/github"
    Mount-PodeSecret -Name 'Github' -Vault 'HcpVault' -Key 'tools/github'

    # reference this secret in a route to "release" something
    Add-PodeRoute -Method Post -Path '/release' -ScriptBlock {
        Publish-Release -ApiToken $secret:Github.api_token
    }

    # reference this secret in a route to update the api token
    Add-PodeRoute -Method Put -Path '/api-token' -ScriptBlock {
        $secret:Github = @{
            api_token = $WebEvent.Data.ApiToken
        }
    }

    # reference this secret in a route to delete it
    Add-PodeRoute -Method Delete -Path '/api-token' -ScriptBlock {
        Dismount-PodeSecret -Name 'Github' -Remove
    }
}
```
