if ((Get-Module -Name Pode | Measure-Object).Count -ne 0)
{
    Remove-Module -Name Pode
}

$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -ErrorAction Stop

# or just:
# Import-Module Pode

# create a server, and start listening on port 8086
Server {

    listen *:8086 http

    # can be hit by sending a POST request to "localhost:8086/api/test"
    route 'post' '/api/test' {
        param($session)
        json @{ 'hello' = 'world'; }
    }

    # can be hit by sending a GET request to "localhost:8086/api/test"
    route 'get' '/api/test' {
        param($session)
        json @{ 'hello' = 'world'; }
    }

    # returns details for an example user
    route 'get' '/api/users/:userId' {
        param($session)
        $user = Get-DummyUser -UserId $session.Parameters['userId']
        json @{ 'user' = $user; }
    }

}