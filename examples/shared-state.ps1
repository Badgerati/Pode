if ((Get-Module -Name Pode | Measure-Object).Count -ne 0)
{
    Remove-Module -Name Pode
}

$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -ErrorAction Stop

# or just:
# Import-Module Pode

# create a basic server
Server -Port 8085 {

    # create timer to update a hashtable and make it globally accessible
    timer 'forever' 2 {
        if (($hash = (state get 'hash')) -eq $null) {
            $hash = (state set 'hash' @{})
            $hash['values'] = @()
        }

        $hash['values'] += (Get-Random -Minimum 0 -Maximum 10)
    }

    # route to retrieve and return the value of the hashtable from global state
    route get '/get-array' {
        param($session)
        $hash = (state get 'hash')
        json $hash
    }

    # route to remove the hashtable from global state
    route delete '/remove-array' {
        param($session)
        state remove 'hash' | Out-Null
    }

}