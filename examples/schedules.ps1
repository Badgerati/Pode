$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# or just:
# Import-Module Pode

# create a server, and start listening on port 8085
Start-PodeServer {

    # listen on localhost:8085
    Add-PodeEndpoint -Endpoint *:8085 -Protocol HTTP

    # schedule minutely using predefined cron
    schedule 'predefined' '@minutely' -Limit 2 {
        'hello, world!' | Out-Default
    }

    # schedule defined using two cron expressions
    schedule 'two-crons' @('0/3 * * * *', '0/5 * * * *') {
        'double cron' | Out-Default
    }

    # schedule to run every tuesday at midnight
    schedule 'tuesdays' '0 0 * * TUE' {
        # logic
    }

    # schedule to run every 5 past the hour, starting in 2hrs
    schedule 'hourly-start' '5 * * * *' {
        # logic
    } -StartTime ([DateTime]::Now.AddHours(2))

    # schedule to run every 10 minutes, and end in 2hrs
    schedule 'every-10mins-end' '0/10 * * * *' {
        # logic
    } -EndTime ([DateTime]::Now.AddHours(2))

}