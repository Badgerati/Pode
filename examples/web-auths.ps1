if ((Get-Module -Name Pode | Measure-Object).Count -ne 0)
{
    Remove-Module -Name Pode
}

$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -ErrorAction Stop

# or just:
# Import-Module Pode

# create a server, and start listening on port 8085
Server -Threads 2 {

    # listen on localhost:8085
    listen *:8085 http

    # setup session details
    middleware (session @{
        'Secret' = 'schwifty';  # secret-key used to sign session cookie
        'Name' = 'pode.sid';    # session cookie name (def: pode.sid)
        'Duration' = 120;       # duration of the cookie, in seconds
        'Extend' = $true;       # extend the duration of the cookie on each call
        'GenerateId' = {        # custom SessionId generator (def: guid)
            return [System.IO.Path]::GetRandomFileName()
        };
    })

    # setup basic auth
    auth use (get-authbasic {
        param($username, $password)

        # "Basic bW9ydHk6cGlja2xl"
        if ($username -eq 'morty' -and $password -eq 'pickle') {
            return @{ 'user' = @{
                'ID' ='M0R7Y302'
                'Name' = 'Morty';
                'Type' = 'Human';
            } }
        }

        return $null
    })

    # GET request for web page on "localhost:8085/"
    route 'get' '/' (auth check basic @{ 'session' = $true; 'failureUrl' = '/login' }) {
        param($s)
        #$s.Session.Data.Views++
        json @{ 'User' = $s.Auth.User; } # 'Views' = $s.Session.Data.Views }
    }

}