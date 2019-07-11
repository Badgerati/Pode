$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# or just:
# Import-Module Pode

<#
This example shows how to use sessionless authentication, which will mostly be for
REST APIs. The example used here is Basic authentication.

Calling the '[POST] http://localhost:8085/users' endpoint, with an Authorization
header of 'Basic bW9ydHk6cGlja2xl' will display the uesrs. Anything else and
you'll get a 401 status code back.
#>

# create a server, and start listening on port 8085
Start-PodeServer -Threads 2 {

    # listen on localhost:8085
    Add-PodeEndpoint -Address *:8085 -Protocol HTTP

    # setup basic auth (base64> username:password in header)
    auth use basic -v {
        param($username, $password)

        # here you'd check a real user storage, this is just for example
        if ($username -eq 'morty' -and $password -eq 'pickle') {
            return @{ 'user' = @{
                'ID' ='M0R7Y302'
                'Name' = 'Morty';
                'Type' = 'Human';
            } }
        }

        return $null
    }

    # POST request to get list of users (since there's no session, the auth check will always happen)
    route 'post' '/users' (auth check basic) {
        param($s)
        Write-PodeJsonResponse -Value @{ 'Users' = @(
            @{
                'Name' = 'Deep Thought';
                'Age' = 42;
            },
            @{
                'Name' = 'Leeroy Jenkins';
                'Age' = 1337;
            }
        ) }
    }

}