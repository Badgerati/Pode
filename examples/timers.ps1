$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# or just:
# Import-Module Pode

# create a basic server
Server {

    listen *:8081 http

    # runs forever, looping every 5secs
    timer 'forever' 5 {
        # logic
    }

    # runs forever, but skips the first 3 "loops" - is paused for 15secs then loops every 5secs
    timer 'pause-first-3' 5 {
        # logic
    } -skip 3

    # runs every 5secs, but only runs for 10 "loops" (ie, 50secs)
    timer 'run-10-times' 5 {
        # logic
    } -limit 10

    # skip the first 2 loops, then run for 15 loops
    timer 'pause-then-limit' 5 {
        # logic
    } -skip 2 -limit 15

    # run once after 2mins
    timer 'run-once' 120 {
        # logic
    } -skip 1 -limit 1

    # create a new timer via a route
    route 'get' '/api/timer' {
        param($session)
        $query = $session.Query

        timer $query['Name'] $query['Seconds'] {
            # logic
        }
    }

}
