$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# or just:
# Import-Module Pode

# create a basic server
Start-PodeServer -EnablePool Timers {

    Add-PodeEndpoint -Address * -Port 8081 -Protocol Http

    # create a new timer via a route
    Add-PodeRoute -Method Get -Path '/api/timer' -ScriptBlock {
        Add-PodeTimer -Name 'example' -Interval 5 -ScriptBlock {
            'hello there' | out-default
        }
    }

}
