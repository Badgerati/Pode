$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# or just:
# Import-Module Pode

# create a server, and start listening on port 8085
Server {

    # listen on localhost:8085
    listen *:8085 http

    # schedule minutely using predefined cron
    schedule 'predefined' '@minutely' -Limit 2 {
        # logic
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