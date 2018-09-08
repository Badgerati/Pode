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

    # set the view engine
    engine pode

    # setup session details
    middleware (session @{
        'Secret' = 'schwifty';
        'Duration' = 120;
        'Extend' = $true;
    })

    # setup basic auth
    auth use (Get-AuthForm {
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

    # home page
    route 'get' '/' (auth check form @{ 'failureUrl' = '/login' }) {
        param($s)

        $s.Session.Data.Views++

        view 'auth-home' -data @{
            'Username' = $s.Auth.User.Name;
            'Views' = $s.Session.Data.Views;
        }
    }

    # login
    route 'get' '/login' (auth check form @{ 'login' = $true; 'successUrl' = '/' }) {
        param($s)
        view 'auth-login'
    }

    route 'post' '/login' (auth check form @{
        'failureUrl' = '/login';
        'successUrl' = '/';
    }) {}

    # logout
    route 'post' '/logout' (auth check form @{
        'logout' = $true;
        'failureUrl' = '/login';
    }) {}

    route 'get' '/logout' {
        redirect '/login'
    }

}