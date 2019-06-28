$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# or just:
# Import-Module Pode

# create a basic server
Server {

    listen *:8085 http
    logger 'terminal'

    # re-initialise the state
    state restore './state.json'

    # initialise if there was no file
    if ($null -eq ($hash = (state get 'hash'))) {
        $hash = state set 'hash' @{}
        $hash['values'] = @()
    }

    # create timer to update a hashtable and make it globally accessible
    timer 'forever' 2 {
        param($session)
        $hash = $null

        lock $session.Lockable {
            $hash = (state get 'hash')
            $hash.values += (Get-Random -Minimum 0 -Maximum 10)
            state save './state.json'
        }
    }

    # route to retrieve and return the value of the hashtable from global state
    route get '/get-array' {
        param($session)

        lock $session.Lockable {
            $hash = (state get 'hash')
            json $hash
        }
    }

    # route to remove the hashtable from global state
    route delete '/remove-array' {
        param($session)

        lock $session.Lockable {
            $hash = (state set 'hash' @{})
            $hash.values = @()
        }
    }

}