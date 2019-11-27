$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# or just:
# Import-Module Pode

# create a basic server
Start-PodeServer {

    Add-PodeEndpoint -Address * -Port 8081 -Protocol Http

    # runs forever, looping every 5secs
    Add-PodeTimer -Name 'forever' -Interval 5 -ScriptBlock {
        'Hello, world' | Out-PodeHost
    } -Limit 5

    # runs forever, but skips the first 3 "loops" - is paused for 15secs then loops every 5secs
    Add-PodeTimer -Name 'pause-first-3' -Interval 5 -ScriptBlock {
        # logic
    } -Skip 3

    # runs every 5secs, but only runs for 10 "loops" (ie, 50secs)
    Add-PodeTimer -Name 'run-10-times' -Interval 5 -ScriptBlock {
        # logic
    } -Limit 10

    # skip the first 2 loops, then run for 15 loops
    Add-PodeTimer -Name 'pause-then-limit' -Interval 5 -ScriptBlock {
        # logic
    } -Skip 2 -Limit 15

    # run once after 2mins
    Add-PodeTimer -Name 'run-once' -Interval 120 -ScriptBlock {
        # logic
    } -Skip 1 -Limit 1

    # create a new timer via a route
    Add-PodeRoute -Method Get -Path '/api/timer' -ScriptBlock {
        param($event)
        $query = $event.Query

        Add-PodeTimer -Name $query['Name'] -Interval $query['Seconds'] -ScriptBlock {
            # logic
        }
    }

    # adhoc invoke a timer's logic
    Add-PodeRoute -Method Get -Path '/api/run' -ScriptBlock {
        Invoke-PodeTimer -Name 'forever'
    }

}
