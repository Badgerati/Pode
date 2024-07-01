try {
    $ScriptPath = (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
    $podePath = Split-Path -Parent -Path $ScriptPath
    if (Test-Path -Path "$($podePath)/src/Pode.psm1" -PathType Leaf) {
        Import-Module "$($podePath)/src/Pode.psm1" -Force -ErrorAction Stop
    }
    else {
        Import-Module -Name 'Pode' -MaximumVersion 2.99 -ErrorAction Stop
    }
}
catch { throw }

# or just:
# Import-Module Pode

# make sure to install the Microsoft.PowerShell.SecretStore modules!
# Install-Module Microsoft.PowerShell.SecretManagement, Microsoft.PowerShell.SecretStore

Start-PodeServer -Threads 2 {
    # listen
    Add-PodeEndpoint -Address localhost -Port 8081 -Protocol Http

    # logging
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging


    # secret manage local vault
    $params = @{
        Name         = 'PodeTest_LocalVault'
        ModuleName   = 'Microsoft.PowerShell.SecretStore'
        UnlockSecret = 'Sup3rSecur3Pa$$word!'
    }

    Register-PodeSecretVault @params


    # set a secret in the local vault
    Set-PodeSecret -Key 'hello' -Vault 'PodeTest_LocalVault' -InputObject 'world'


    # mount a secret from local vault
    Mount-PodeSecret -Name 'hello' -Vault 'PodeTest_LocalVault' -Key 'hello'


    # routes to get/update secret in local vault
    Add-PodeRoute -Method Get -Path '/module' -ScriptBlock {
        Write-PodeJsonResponse @{ Value = $secret:hello }
    }

    Add-PodeRoute -Method Post -Path '/module' -ScriptBlock {
        $secret:hello = $WebEvent.Data.Value
    }


    Add-PodeRoute -Method Post -Path '/adhoc/:key' -ScriptBlock {
        Set-PodeSecret -Key $WebEvent.Parameters['key'] -Vault 'PodeTest_LocalVault' -InputObject $WebEvent.Data['value']
        Mount-PodeSecret -Name $WebEvent.Data['name'] -Vault 'PodeTest_LocalVault' -Key $WebEvent.Parameters['key']
    }

    Add-PodeRoute -Method Delete -Path '/adhoc/:key' -ScriptBlock {
        Remove-PodeSecret -Key $WebEvent.Parameters['key'] -Vault 'PodeTest_LocalVault'
        Dismount-PodeSecret -Name $WebEvent.Parameters['key']
    }
}
