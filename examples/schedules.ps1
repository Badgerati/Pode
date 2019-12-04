$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# or just:
# Import-Module Pode

# create a server, and start listening on port 8085
Start-PodeServer {

    # listen on localhost:8085
    Add-PodeEndpoint -Address * -Port 8085 -Protocol Http

    # schedule minutely using predefined cron
    Add-PodeSchedule -Name 'predefined' -Cron '@minutely' -Limit 2 -ScriptBlock {
        'hello, world!' | Out-Default
    }

    # schedule defined using two cron expressions
    Add-PodeSchedule -Name 'two-crons' -Cron @('0/3 * * * *', '0/5 * * * *') -ScriptBlock {
        'double cron' | Out-Default
    }

    # schedule to run every tuesday at midnight
    Add-PodeSchedule -Name 'tuesdays' -Cron '0 0 * * TUE' -ScriptBlock {
        # logic
    }

    # schedule to run every 5 past the hour, starting in 2hrs
    Add-PodeSchedule -Name 'hourly-start' -Cron '5 * * * *' -ScriptBlock {
        # logic
    } -StartTime ([DateTime]::Now.AddHours(2))

    # schedule to run every 10 minutes, and end in 2hrs
    Add-PodeSchedule -Name 'every-10mins-end' -Cron '0/10 * * * *' -ScriptBlock {
        # logic
    } -EndTime ([DateTime]::Now.AddHours(2))

    # adhoc invoke a schedule's logic
    Add-PodeRoute -Method Get -Path '/api/run' -ScriptBlock {
        Invoke-PodeSchedule -Name 'predefined'
    }

}