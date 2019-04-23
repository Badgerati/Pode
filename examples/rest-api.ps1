$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# or just:
# Import-Module Pode

# create a server, and start listening on port 8086
Server {

    listen *:8086 http

    # can be hit by sending a GET request to "localhost:8086/api/test"
    route get '/api/test' {
        json @{ 'hello' = 'world'; }
    }

    # can be hit by sending a POST request to "localhost:8086/api/test"
    route post '/api/test' -type 'application/json' {
        param($e)
        json @{ 'hello' = 'world'; 'name' = $e.Data['name']; }
    }

    # returns details for an example user
    route get '/api/users/:userId' {
        param($e)
        $user = Get-DummyUser -UserId $e.Parameters['userId']
        json @{ 'user' = $user; }
    }

}