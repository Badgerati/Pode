$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# or just:
# Import-Module Pode

# create a server, and start listening on port 8085
Start-PodeServer -EnablePool Schedules {

    Add-PodeEndpoint -Address * -Port 8081 -Protocol Http

    # create a new schdule via a route
    Add-PodeRoute -Method Get -Path '/api/schedule' -ScriptBlock {
        Add-PodeSchedule -Name 'example' -Cron '@minutely' -ScriptBlock {
            'hello there' | out-default
        }
    }

}
