$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# or just:
# Import-Module Pode

# create a server, and start listening on port 8085
Start-PodeServer {

    # listen on localhost:8085
    Add-PodeEndpoint -Address * -Port 8085 -Protocol Http

    # add lots of schedules that each sleep for a while
    1..30 | ForEach-Object {
        Add-PodeSchedule -Name "Schedule_$($_)" -Cron '@minutely' -ArgumentList @{ ID = $_ } -ScriptBlock {
            param($ID)

            $seconds = (Get-Random -Minimum 5 -Maximum 40)
            Start-Sleep -Seconds $seconds
            "ID: $($ID) [$($seconds)]" | Out-PodeHost
        }
    }

    Set-PodeScheduleConcurrency -Maximum 30

}