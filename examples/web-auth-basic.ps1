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

    # setup basic auth (base64> username:password)
    auth use (Get-AuthBasic {
        param($username, $password)

        if ($username -eq 'morty' -and $password -eq 'pickle') {
            return @{ 'user' = @{
                'ID' ='M0R7Y302'
                'Name' = 'Morty';
                'Type' = 'Human';
            } }
        }

        return $null
    })

    # POST request for to get users
    route 'post' '/users' (auth check basic) {
        param($s)
        json @{ 'Users' = @(
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