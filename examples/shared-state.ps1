$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# or just:
# Import-Module Pode

# create a basic server
Start-PodeServer {

    Add-PodeEndpoint -Address *:8085 -Protocol Http
    New-PodeLoggingMethod -Terminal | Enable-PodeRequestLogging

    # re-initialise the state
    Restore-PodeState -Path './state.json'

    # initialise if there was no file
    if ($null -eq ($hash = (Get-PodeState -Name 'hash'))) {
        $hash = Set-PodeState -Name 'hash' -Value @{}
        $hash['values'] = @()
    }

    # create timer to update a hashtable and make it globally accessible
    Add-PodeTimer -Name 'forever' -Interval 2 -ScriptBlock {
        param($session)
        $hash = $null

        Lock-PodeObject -Object $session.Lockable {
            $hash = (Get-PodeState -Name 'hash')
            $hash.values += (Get-Random -Minimum 0 -Maximum 10)
            Save-PodeState -Path './state.json'
        }
    }

    # route to retrieve and return the value of the hashtable from global state
    Add-PodeRoute -Method Get -Path '/array' -ScriptBlock {
        param($session)

        Lock-PodeObject -Object $session.Lockable {
            $hash = (Get-PodeState 'hash')
            Write-PodeJsonResponse -Value $hash
        }
    }

    # route to remove the hashtable from global state
    Add-PodeRoute -Method Delete -Path '/array' -ScriptBlock {
        param($session)

        Lock-PodeObject -Object $session.Lockable {
            $hash = (Set-PodeState -Name 'hash' -Value @{})
            $hash.values = @()
        }
    }

}