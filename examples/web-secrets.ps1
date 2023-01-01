param(
    [Parameter(Mandatory=$true)]
    [string]
    $AzureSubscriptionId
)

$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# or just:
# Import-Module Pode

Start-PodeServer -Threads 2 {
    # listen
    Add-PodeEndpoint -Address * -Port 8085 -Protocol Http

    # logging
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging


    # secret manage azure keyvault - need to run "Connect-AzAccount" first!
    Register-PodeSecretVault -Name 'PodeTest_SMAZVault' -ModuleName 'Az.KeyVault' -VaultParameters @{
        AZKVaultName = 'pode-test-kv'
        SubscriptionId = $AzureSubscriptionId
    }

    # custom vault cli
    Register-PodeSecretVault -Name 'PodeTest_CustomVault' -CacheTtl 1 `
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
        }


    # mount a secret from vault cli
    Mount-PodeSecret -Name 'CustomCLI' -Vault 'PodeTest_CustomVault' -Key 'hello' -ExpandProperty 'foo'

    # mount a secret from az keyvault
    Mount-PodeSecret -Name 'ModuleAz' -Vault 'PodeTest_SMAZVault' -Key 'hello'


    # routes to get/update secret in vault cli
    Add-PodeRoute -Method Get -Path '/custom' -ScriptBlock {
        # $value = Get-PodeSecret -Name 'CustomCLI'
        # Write-PodeJsonResponse @{ Value = $value }
        Write-PodeJsonResponse @{ Value = $secret:CustomCLI }
    }

    Add-PodeRoute -Method Post -Path '/custom' -ScriptBlock {
        # $WebEvent.Data.Value | Update-PodeSecret -Name 'CustomCLI'
        $secret:CustomCLI = $WebEvent.Data.Value
    }


    # routes to get/update secret in az keyvault
    Add-PodeRoute -Method Get -Path '/module' -ScriptBlock {
        # $value = Get-PodeSecret -Name 'ModuleAz'
        # Write-PodeJsonResponse @{ Value = $value }
        Write-PodeJsonResponse @{ Value = $secret:ModuleAz }
    }

    Add-PodeRoute -Method Post -Path '/module' -ScriptBlock {
        # $WebEvent.Data.Value | Update-PodeSecret -Name 'ModuleAz'
        $secret:ModuleAz = $WebEvent.Data.Value
    }


    Add-PodeRoute -Method Get -Path '/adhoc/:key' -ScriptBlock {
        $value = Read-PodeSecret -Key $WebEvent.Parameters['key'] -Vault 'PodeTest_CustomVault'
        Write-PodeJsonResponse @{ Value = $value }
    }

    Add-PodeRoute -Method Get -Path '/custom/:name' -ScriptBlock {
        Write-PodeJsonResponse @{ Value = (Get-PodeSecret -Name $WebEvent.Parameters['name']) }
    }

    Add-PodeRoute -Method Post -Path '/adhoc/:key' -ScriptBlock {
        Set-PodeSecret -Key $WebEvent.Parameters['key'] -Vault 'PodeTest_CustomVault' -InputObject $WebEvent.Data['value']
        Mount-PodeSecret -Name $WebEvent.Data['name'] -Vault 'PodeTest_CustomVault' -Key $WebEvent.Parameters['key']
    }

    Add-PodeRoute -Method Delete -Path '/adhoc/:key' -ScriptBlock {
        Remove-PodeSecret -Key $WebEvent.Parameters['key'] -Vault 'PodeTest_CustomVault'
        Dismount-PodeSecret -Name $WebEvent.Parameters['key'] 
    }
}
