$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# or just:
# Import-Module Pode

# create a basic server
Start-PodeServer {

    Add-PodeEndpoint -Address * -Port 8090 -Protocol Http
    New-PodeLoggingMethod -Terminal | Enable-PodeRequestLogging
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging

    # re-initialise the state
    Restore-PodeState -Path './state.json'

    # initialise if there was no file
    if ($null -eq ($hash = (Get-PodeState -Name 'hash1'))) {
        $hash = Set-PodeState -Name 'hash1' -Value @{} -Scope Scope0, Scope1
        $hash['values'] = @()
    }

    if ($null -eq ($hash = (Get-PodeState -Name 'hash2'))) {
        $hash = Set-PodeState -Name 'hash2' -Value @{} -Scope Scope0, Scope2
        $hash['values'] = @()
    }

    if ($null -eq $state:hash3) {
        $state:hash3 = @{ values = @() }
    }

    # create timer to update a hashtable and make it globally accessible
    Add-PodeTimer -Name 'forever' -Interval 2 -ScriptBlock {
        $hash = $null

        Lock-PodeObject -ScriptBlock {
            $hash = (Get-PodeState -Name 'hash1')
            $hash.values += (Get-Random -Minimum 0 -Maximum 10)
            Save-PodeState -Path './state.json' -Scope Scope1 #-Exclude 'hash1'
        }

        Lock-PodeObject -ScriptBlock {
            $state:hash3.values += (Get-Random -Minimum 0 -Maximum 10)
        }
    }

    # route to retrieve and return the value of the hashtable from global state
    Add-PodeRoute -Method Get -Path '/array' -ScriptBlock {
        Lock-PodeObject -ScriptBlock {
            $hash = (Get-PodeState 'hash1')
            Write-PodeJsonResponse -Value $hash
        }
    }

    Add-PodeRoute -Method Get -Path '/array3' -ScriptBlock {
        Lock-PodeObject -ScriptBlock {
            Write-PodeJsonResponse -Value $state:hash3
        }
    }

    # route to remove the hashtable from global state
    Add-PodeRoute -Method Delete -Path '/array' -ScriptBlock {
        Lock-PodeObject -ScriptBlock {
            $hash = (Set-PodeState -Name 'hash1' -Value @{})
            $hash.values = @()
        }
    }

}